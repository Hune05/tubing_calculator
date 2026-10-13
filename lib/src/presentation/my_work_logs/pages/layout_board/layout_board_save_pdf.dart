// 작업 배치도 화면 — 저장·PDF·일지 사진.
// layout_board_page.dart의 _LayoutBoardPageState를 역할별로 나눈 part(10-13). 동작은 같다.
// setState는 State 밖(확장)에서 부르면 보호 멤버 경고가 나지만, 이 확장은 그 State 자신이다.
// ignore_for_file: invalid_use_of_protected_member
part of '../layout_board_page.dart';

extension _LayoutBoardSavePdf on _LayoutBoardPageState {
  Future<Uint8List?> _capturePng() async {
    try {
      RenderRepaintBoundary boundary =
          _captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      // 큰 판은 3배로 찍으면 기기 그림 한계(8192px)를 넘어 실패하거나 메모리가 넘친다(10-08).
      ui.Image image = await boundary.toImage(
        pixelRatio: layoutCapturePixelRatio(boundary.size),
      );
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  // 🚀 [신규] 작업 일지 작성 화면에서 이 도구를 열었을 때, 완성된 배치도를
  // PNG로 캡처해서 그 파일 경로를 결과값으로 들고 화면을 닫는다 - 일지
  // 쪽에서는 이 경로를 "현장 사진 첨부" 목록에 그대로 추가하면 된다.
  Future<void> _attachToDailyReportPhoto() async {
    setState(() => _isSaving = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null) throw Exception("도면 캡처 실패");
      final dir = await getTemporaryDirectory();
      final file = File(
        "${dir.path}/layout_${DateTime.now().millisecondsSinceEpoch}.png",
      );
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      Navigator.pop(context, file.path);
    } catch (e) {
      if (!mounted) return;
      showSnackOnce(
        ScaffoldMessenger.of(context),
        SnackBar(
          content: Text(keepWords(failText("사진 저장 실패", e))),
          backgroundColor: warningRed,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  // 🚀 [신규] 최소 유지 간격을 설정해둔 치수 중, 저장/공유하는 지금
  // 시점에도 여전히 기준을 못 만족하는 것들을 모아서 알려준다.
  List<String> _collectMinGapViolations() {
    final List<String> violations = [];
    for (int i = 0; i < _dimensions.length; i++) {
      final dim = _dimensions[i];
      if (dim.minGapMm == null) continue;
      final endpoints = computeDimensionEndpoints(dim);
      if (endpoints.distance < dim.minGapMm!) {
        violations.add(
          "#${i + 1}: 현재 ${endpoints.distance.round()}mm (기준 ${dim.minGapMm!.toInt()}mm 이상)",
        );
      }
    }
    return violations;
  }

  // 🚀 위반 항목이 있으면 저장/공유 전에 한 번 더 확인시킨다. 위반이
  // 없으면 바로 true(계속 진행), 사용자가 "취소"를 누르면 false.
  Future<bool> _confirmMinGapViolationsIfAny() async {
    final violations = _collectMinGapViolations();
    if (violations.isEmpty) return true;
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "이격거리 미달 경고",
          style: TextStyle(color: warningRed, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              keepWords("최소 간격보다 좁은 치수선이 ${violations.length}건 있습니다:"),
              style: const TextStyle(color: tossText),
            ),
            const SizedBox(height: 8),
            ...violations.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  "• $v",
                  style: const TextStyle(color: warningRed, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소", style: TextStyle(color: tossSubText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "그래도 저장",
              style: TextStyle(color: warningRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  Future<bool> _confirmChangesBeforeSave() async {
    if (_currentProjectId == null) return true;
    try {
      // 통신이 약하면 끝없이 기다렸다(10-08). 5초 안에 못 읽으면 견주지 않고 저장한다.
      final doc = await FirebaseFirestore.instance
          .collection('layouts')
          .doc(_currentProjectId)
          .get()
          .timeout(const Duration(seconds: 5));
      final data = doc.data();
      if (data == null) return true;

      // 이 도면을 연 뒤 다른 기기가 저장했으면 먼저 묻는다(10-08: 나중에 저장한 쪽이 통째로 덮어
      // 다른 기기에서 고친 것이 사라졌다).
      final serverToken = data['saveToken'] as String?;
      if (serverToken != null && serverToken != _lastSaveToken && mounted) {
        final pick = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            key: const Key('layout_conflict'),
            title: const Text('다른 기기에서 고친 도면입니다'),
            content: Text(
              keepWords(
                '이 도면을 연 뒤 다른 기기에서 고쳐 저장했습니다. 지금 저장하면 그 고침이 사라집니다.\n'
                '"서버 판 다시 열기"를 고르면 지금 고친 것은 임시 저장에 남아, 다시 열 때 이어할지 묻습니다.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              TextButton(
                key: const Key('layout_conflict_reload'),
                onPressed: () => Navigator.pop(ctx, 'reload'),
                child: const Text('서버 판 다시 열기'),
              ),
              TextButton(
                key: const Key('layout_conflict_overwrite'),
                onPressed: () => Navigator.pop(ctx, 'overwrite'),
                child: const Text('덮어쓰기', style: TextStyle(color: warningRed)),
              ),
            ],
          ),
        );
        if (pick == null || !mounted) return false;
        if (pick == 'reload') {
          await _saveDraftToPrefs();
          await _loadProject(_currentProjectId!);
          return false;
        }
      }

      // 모든 탭(중판·측판·평면·정면)의 부품을 견준다(예전엔 지금 탭과 서버 중판만 견줘
      // 측판에서 저장하면 엉뚱한 추가·삭제 목록이 떴다).
      final List<PlacedItem> savedItems = [
        ...layoutItemsFromData(data),
        for (final p in ((data['sidePlates'] as Map?) ?? const {}).values)
          if (p is Map) ...layoutItemsFromData(Map<String, dynamic>.from(p)),
      ];
      final Map<String, PlacedItem> savedById = {
        for (final i in savedItems) i.id: i,
      };
      final Map<String, PlacedItem> currentById = {
        for (final p in _allPlates().values)
          for (final i in layoutItemsFromData(p)) i.id: i,
      };

      final List<String> added = [];
      final List<String> removed = [];
      final List<String> moved = [];

      for (final entry in currentById.entries) {
        final PlacedItem? prev = savedById[entry.key];
        if (prev == null) {
          added.add(entry.value.name);
        } else if (prev.position != entry.value.position ||
            prev.width != entry.value.width ||
            prev.height != entry.value.height) {
          moved.add(entry.value.name);
        }
      }
      for (final entry in savedById.entries) {
        if (!currentById.containsKey(entry.key)) removed.add(entry.value.name);
      }

      // 모든 판의 치수선을 견준다(10-08: 지금 판과 서버 중판만 견줘 측판에서 저장하면 틀리게 나왔다).
      int dimsOf(Map p) => (p['dimensions'] as List?)?.length ?? 0;
      final int savedDimCount =
          dimsOf(data) +
          [
            for (final p in ((data['sidePlates'] as Map?) ?? const {}).values)
              if (p is Map) dimsOf(p),
          ].fold(0, (a, b) => a + b);
      final int dimDelta =
          _allPlates().values.fold<int>(0, (a, p) => a + dimsOf(p)) -
          savedDimCount;

      if (added.isEmpty && removed.isEmpty && moved.isEmpty && dimDelta == 0) {
        return true; // 변경 사항 없음
      }

      if (!mounted) return true;
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "저장 전 변경 사항 확인",
            style: TextStyle(color: tossText, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (moved.isNotEmpty) _diffLine("이동됨", moved, tossBlue),
                  if (added.isNotEmpty) _diffLine("추가됨", added, tossBlue),
                  if (removed.isNotEmpty) _diffLine("삭제됨", removed, warningRed),
                  if (dimDelta != 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        dimDelta > 0
                            ? "치수선 $dimDelta개 추가됨"
                            : "치수선 ${-dimDelta}개 삭제됨",
                        style: const TextStyle(
                          color: tossSubText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("취소", style: TextStyle(color: tossSubText)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                "저장",
                style: TextStyle(color: tossBlue, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      return proceed ?? false;
    } catch (_) {
      return true; // 비교 실패 시 저장 자체는 막지 않는다.
    }
  }

  Widget _diffLine(String label, List<String> names, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label (${names.length})",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          Text(
            names.join(', '),
            style: const TextStyle(color: tossSubText, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<void> _shareAsPdf(String projectName) async {
    final opts = await _askPdfOptions();
    if (opts == null || !mounted) return;
    setState(() => _isSaving = true);
    try {
      // 🚀 [버그 수정] QR에 실제 존재하지 않는 이름+시간 조합 문자열을
      // 넣어서, 스캔해도 절대 못 찾는 죽은 링크였다. QR로 다시 이 도면을
      // 열 수 있으려면 서버에 저장된 실제 프로젝트여야 하므로, 아직
      // 저장 전이면 먼저 저장해서 진짜 문서 ID를 확보한다.
      if (_currentProjectId == null) {
        await _saveToFirebase(projectName);
        if (_currentProjectId == null) {
          throw Exception("배치도를 저장하지 못해 QR을 만들 수 없습니다");
        }
      }
      // 고른 부품의 파란 테두리·안내선이 같이 찍히지 않게 찍기 전에 정리한다.
      setState(() {
        _activeItem = null;
        _previewItem = null;
        _multiSelectedIds = {};
        for (final i in _placedItems) {
          i.isSelected = false;
        }
        _alignGuideX = null;
        _alignGuideY = null;
        _pdfCapture = true;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      setState(() => _isSaving = true);

      // 측판을 켰으면 좌측판·중판·우측판을 한 장씩 찍는다(판을 바꿔 그린 뒤 찍고 되돌린다).
      final String startPlate = _plateId;
      final Set<String> made = {..._plateStore.keys, _plateId};
      final List<String> plateIds = _isSkid
          ? _tabOrder
                .where((id) => id == kPlateMain || made.contains(id))
                .toList()
          // 캐비닛 측판은 뭔가 놓인 판만(예전엔 빈 측판도 빈 쪽으로 찍혔다).
          : (_sidePlatesOn
                ? kPlateOrder
                      .where(
                        (id) =>
                            id == kPlateMain ||
                            id == _plateId ||
                            _plateHasContent(id),
                      )
                      .toList()
                : [_plateId]);
      final shots =
          <
            (
              String,
              Uint8List,
              double,
              double,
              List<PlacedDimension>,
              List<PlacedItem>,
            )
          >[];
      // 찍다 실패해도 원래 보던 판으로 돌아온다(10-08: 다른 판에 머물렀다).
      try {
        for (final id in plateIds) {
          if (id != _plateId) {
            setState(() => _switchPlate(id));
            await WidgetsBinding.instance.endOfFrame;
            await WidgetsBinding.instance.endOfFrame;
          }
          final bytes = await _capturePng();
          if (bytes == null) throw Exception("도면 캡처 실패");
          shots.add((
            id,
            bytes,
            _panelWidth,
            _panelHeight,
            List.of(_dimensions),
            List.of(_placedItems),
          ));
        }
      } finally {
        if (_plateId != startPlate && mounted) {
          setState(() => _switchPlate(startPlate));
        }
      }

      // 한글 글꼴을 넣는다(예전엔 기본 글꼴이라 한글 프로젝트 이름·메모가 네모로 나왔다).
      final fonts = await loadKoreanPdfFonts();
      final pdf = pw.Document(theme: fonts.theme);
      String qrData = "tubingcalc://layout?project=$_currentProjectId";
      // 용지·방향(표제란·축척은 표준 축척 중 들어가는 가장 큰 것).
      final PdfPageFormat baseFmt =
          (opts.paper == 'A3' ? PdfPageFormat.a3 : PdfPageFormat.a4).copyWith(
            marginLeft: 1.2 * PdfPageFormat.cm,
            marginRight: 1.2 * PdfPageFormat.cm,
            marginTop: 1.2 * PdfPageFormat.cm,
            marginBottom: 1.0 * PdfPageFormat.cm,
          );
      final PdfPageFormat pageFmt = opts.landscape
          ? baseFmt.landscape
          : baseFmt;
      final String author = (await loadLayoutOwner()).name ?? "";
      final String today = DateTime.now().toString().split(' ')[0];
      const double ptPerMm = 72 / 25.4;
      for (final (plateId, imageBytes, plateW, plateH, plateDims, plateItems)
          in shots) {
        final image = pw.MemoryImage(imageBytes);
        // 머리글(약 78pt)·표제란(약 46pt)·사이 여백을 뺀 자리에 들어가는 표준 축척.
        final double availW = pageFmt.availableWidth;
        final double availH = pageFmt.availableHeight - 78 - 46 - 24;
        final double scaleN = pdfStandardScale(plateW, plateH, availW, availH);
        final double imgW = plateW / scaleN * ptPerMm;
        final double imgH = plateH / scaleN * ptPerMm;
        // 자 눈금: 1:20까지는 100mm, 더 작으면 1000mm.
        final double rulerMm = scaleN <= 20 ? 100 : 1000;
        final double rulerPt = rulerMm / scaleN * ptPerMm;
        final String scaleText =
            "1:${scaleN == scaleN.roundToDouble() ? scaleN.toInt() : scaleN}";
        pw.Widget titleCell(String head, String body) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                head,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                body.isEmpty ? "-" : body,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        );
        final String plateName = _isSkid
            ? switch (plateId) {
                kSkidViewFront => "정면",
                kPlateLeft => "왼쪽 측면",
                kPlateRight => "오른쪽 측면",
                _ => "평면",
              }
            : switch (plateId) {
                kPlateLeft => "왼쪽 측판",
                kPlateRight => "오른쪽 측판",
                _ => _sidePlatesOn ? "중판" : "",
              };

        pdf.addPage(
          pw.Page(
            pageFormat: pageFmt,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            _isSkid ? "스키드 배치도" : "캐비닛 배치도",
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            "배치도 이름: $projectName",
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                          pw.Text(
                            "${plateName.isEmpty ? "" : "$plateName · "}${_isSkid ? "스키드" : "판"} 크기: ${plateW.toInt()} × ${plateH.toInt()}mm",
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                          pw.Text(
                            "* QR 코드를 찍으면 앱에서 이 배치도가 열립니다.",
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ],
                      ),
                      pw.Container(
                        width: 64,
                        height: 64,
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: qrData,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  // 그림은 표준 축척 크기 그대로(맞춰 늘리지 않는다).
                  pw.Expanded(
                    child: pw.Center(
                      child: pw.Container(
                        width: imgW,
                        height: imgH,
                        child: pw.Image(image, fit: pw.BoxFit.fill),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  // 표제란: 도면 번호·리비전·작성자·날짜·축척·자 눈금.
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.grey700,
                        width: 0.8,
                      ),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: titleCell("도면 번호", _drawingNo),
                        ),
                        pw.Expanded(child: titleCell("리비전", _revision)),
                        pw.Expanded(flex: 2, child: titleCell("작성자", author)),
                        pw.Expanded(flex: 2, child: titleCell("날짜", today)),
                        pw.Expanded(
                          child: titleCell(
                            "축척",
                            "$scaleText ${opts.paper}${opts.landscape ? " 가로" : ""}",
                          ),
                        ),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Text(
                                  "자 ${rulerMm.toInt()}mm",
                                  style: const pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.grey600,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Container(
                                  width: rulerPt,
                                  height: 6,
                                  decoration: pw.BoxDecoration(
                                    border: pw.Border.all(
                                      color: PdfColors.black,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: pw.Row(
                                    children: [
                                      for (var i = 0; i < 10; i++)
                                        pw.Expanded(
                                          child: pw.Container(
                                            color: i.isEven
                                                ? PdfColors.black
                                                : PdfColors.white,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );

        // 태그 번호를 적은 부품이 있으면 부품 목록표를 한 장 붙인다(태그·이름·크기·자리).
        if (plateItems.any((it) => it.tag != null)) {
          final listed =
              plateItems
                  .where((it) => it.shape != InstrumentShape.note)
                  .toList()
                ..sort((a, b) => (a.tag ?? "￿").compareTo(b.tag ?? "￿"));
          pdf.addPage(
            pw.MultiPage(
              pageFormat: pageFmt,
              build: (pw.Context context) => [
                pw.Text(
                  "부품 목록${plateName.isEmpty ? "" : " · $plateName"}",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(70),
                    1: const pw.FlexColumnWidth(),
                    2: const pw.FixedColumnWidth(80),
                    3: const pw.FixedColumnWidth(90),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        _pdfCell("태그", bold: true),
                        _pdfCell("이름", bold: true),
                        _pdfCell("가로×세로", bold: true),
                        _pdfCell("위치 (왼쪽·위)", bold: true),
                      ],
                    ),
                    for (final it in listed)
                      pw.TableRow(
                        children: [
                          _pdfCell(it.tag ?? ""),
                          _pdfCell(it.name),
                          _pdfCell("${it.width.toInt()}×${it.height.toInt()}"),
                          _pdfCell(
                            "${it.position.dx.toInt()} · ${it.position.dy.toInt()}",
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          );
        }

        // 🚀 [신규] 치수선이 있으면 도면 사진 뒤에 번호별 치수 목록표를
        // 추가 페이지로 붙여서, 도면이 복잡해도 사진 속 번호 배지와
        // 대조해가며 확인할 수 있게 한다.
        // 10-09: 한 장(pw.Page)에 넣어서 치수가 A4 세로 26개·가로 17개를 넘으면 표가 통째로
        // 빠지고 제목만 남았다. 부품 목록처럼 여러 장으로 이어지게(MultiPage) 한다.
        if (plateDims.isNotEmpty) {
          pdf.addPage(
            pw.MultiPage(
              pageFormat: pageFmt,
              build: (pw.Context context) {
                return [
                  pw.Text(
                    "치수 목록표",
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColors.grey400,
                      width: 0.5,
                    ),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(40),
                      1: const pw.FixedColumnWidth(70),
                      2: const pw.FixedColumnWidth(80),
                      3: const pw.FlexColumnWidth(),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey200,
                        ),
                        children: [
                          _pdfCell("번호", bold: true),
                          _pdfCell("기준", bold: true),
                          _pdfCell("거리(mm)", bold: true),
                          _pdfCell("메모", bold: true),
                        ],
                      ),
                      ...plateDims.asMap().entries.map((entry) {
                        final int i = entry.key;
                        final PlacedDimension dim = entry.value;
                        final endpoints = computeDimensionEndpoints(dim);
                        return pw.TableRow(
                          children: [
                            _pdfCell("${i + 1}"),
                            _pdfCell(
                              dim.type == DimensionType.center ? "센터" : "측면",
                            ),
                            _pdfCell(endpoints.distance.round().toString()),
                            _pdfCell(dim.note ?? ""),
                          ],
                        );
                      }),
                    ],
                  ),
                ];
              },
            ),
          );
        }
      }

      final output = await getTemporaryDirectory();
      // 이름의 / 같은 글자는 파일 이름에 못 쓴다(10-08: "A동/1층"이면 PDF를 만들지 못했다).
      final safeName = projectName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File("${output.path}/${safeName}_Layout.pdf");
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: '$projectName 배치도입니다.');
    } catch (e) {
      if (!mounted) return;
      showSnackOnce(
        ScaffoldMessenger.of(context),
        SnackBar(content: Text(keepWords(failText("PDF를 만들지 못했습니다", e)))),
      );
    } finally {
      _pdfCapture = false;
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 🚀 [수정] 예전엔 저장할 때마다 새 문서를 만들어서, 같은 프로젝트를
  // 다시 열어 고치고 저장하면 서버에 중복 문서가 계속 쌓이고 "불러오기"로
  // 되돌아갈 방법도 없었다. 이제 이미 저장/불러온 적 있는 프로젝트면
  // (_currentProjectId) 그 문서를 그대로 갱신(update)하고, 처음 저장하는
  // 새 도면일 때만 새 문서를 만든다.
  Future<void> _saveToFirebase(String projectName) async {
    setState(() => _isSaving = true);
    try {
      final bool isNew = _currentProjectId == null;
      // 새 문서일 때만 만든 사람 칸을 붙인다(예전 배치도는 고쳐 저장해도 칸을 붙이지 않는다).
      final LayoutOwner owner = isNew
          ? await loadLayoutOwner()
          : const LayoutOwner();
      final docRef = isNew
          ? FirebaseFirestore.instance.collection('layouts').doc()
          : FirebaseFirestore.instance
                .collection('layouts')
                .doc(_currentProjectId);
      _dropOrphanViewDims();
      final plates = _allPlates();
      // 저장하는 사이(배경 올리기 최대 8초) 고친 것이 있는지 견주려고 시작 모양을 적어 둔다.
      final startSnap = _editFingerprint();
      // 배경 사진은 폰 안 경로라 다른 폰에서 안 보였다. 아직 안 올린 것은 올리고 주소를
      // 같이 저장한다(통신 없으면 이번엔 건너뛰고 다음 저장 때 다시).
      // 판마다 차례로 20초씩 기다리면 통신이 없을 때 판 4개에 1분 넘게 묶였다(10-07).
      // 같이 올리고 8초까지만 기다린다. 못 올린 것은 다음 저장 때 다시.
      await Future.wait([
        for (final e in plates.entries)
          if (e.value['backgroundImagePath'] is String &&
              ((e.value['backgroundImageUrl'] as String?) ?? '').isEmpty)
            uploadLayoutBackground(
              docRef.id,
              e.value['backgroundImagePath'] as String,
            ).timeout(const Duration(seconds: 8), onTimeout: () => null).then((
              up,
            ) {
              if (up == null) return;
              e.value['backgroundImageUrl'] = up;
              if (e.key == _plateId) _backgroundImageUrl = up;
            }),
      ]);
      final main = plates[kPlateMain]!;
      final saveToken = newLayoutId();
      final fields = {
        ...layoutSaveFields(
          projectId: docRef.id,
          projectName: projectName,
          panelWidth: (main['panelWidth'] as num).toDouble(),
          panelHeight: (main['panelHeight'] as num).toDouble(),
          items: layoutItemsFromData(main),
          dimensions: layoutDimensionsFromData(main),
          backgroundImagePath: main['backgroundImagePath'] as String?,
          backgroundOpacity:
              (main['backgroundOpacity'] as num?)?.toDouble() ?? 0.5,
        ),
        'backgroundRect': main['backgroundRect'],
        'backgroundImageUrl': main['backgroundImageUrl'],
        'backgroundBrightness': main['backgroundBrightness'],
        'backgroundGray': main['backgroundGray'],
        'drawingNo': _drawingNo,
        'revision': _revision,
        ..._sidePlateFields(plates),
        if (isNew) ...layoutOwnerFields(owner),
        if (isNew) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'saveToken': saveToken,
      };
      // 예전엔 merge 저장이라 지운 경로·측판이 서버에 남았다. 있는 문서는 칸을 통째로 바꾼다.
      // 통신이 없으면 폰에 적히고 나중에 올라가므로 10초 넘으면 그냥 진행한다.
      Future<void> write() =>
          isNew ? docRef.set(fields) : docRef.update(fields);
      try {
        await write().timeout(const Duration(seconds: 10), onTimeout: () {});
      } on FirebaseException catch (e) {
        if (e.code != 'not-found') rethrow;
        await docRef
            .set(fields)
            .timeout(const Duration(seconds: 10), onTimeout: () {});
      }
      _currentProjectId = docRef.id;
      _projectName = projectName;
      _lastSaveToken = saveToken;
      _captureSavedBaseline(fields);
      // 저장하는 사이 고친 것이 있으면 임시 저장을 지우지 않고 남긴다(10-08: 서버에는 고치기 전 판이
      // 올라가고 임시 저장까지 지워, 그 뒤 앱이 꺼지면 고친 것이 사라졌다).
      if (_editFingerprint() == startSnap) {
        await _clearDraftPrefs();
      } else {
        // 새 도면이었으면 "새 도면" 칸의 임시 저장은 지운다(남기면 다음 새 도면에서 이어하기로
        // 떠, 이어 저장하면 같은 도면이 하나 더 생겼다). 고친 것은 이 도면 칸에 남긴다.
        if (isNew) {
          try {
            await (await SharedPreferences.getInstance()).remove(
              _draftPrefsKey,
            );
          } catch (_) {}
        }
        await _saveDraftToPrefs();
      }
      if (!mounted) return;
      showSnackOnce(
        ScaffoldMessenger.of(context),
        SnackBar(
          content: Text(keepWords("배치도를 저장했습니다.")),
          backgroundColor: tossBlue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showSnackOnce(
        ScaffoldMessenger.of(context),
        SnackBar(
          content: Text(keepWords("저장하지 못했습니다. 통신을 확인하십시오.")),
          backgroundColor: warningRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSaveActionSheet() {
    // 🚀 [수정] 기존에 불러온 프로젝트를 다시 저장할 땐 그 프로젝트 이름을
    // 그대로 채워줘서, 실수로 다른 이름을 입력해 새 문서로 갈라지는 걸 방지.
    final TextEditingController projectCtrl = TextEditingController(
      text: _projectName.isNotEmpty
          ? _projectName
          : "배치도_${DateTime.now().day}일",
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 16,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBottomSheetHandle(),
                const Text(
                  "저장·공유",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: tossText,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: projectCtrl,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tossText,
                  ),
                  decoration: InputDecoration(
                    labelText: "배치도 이름 (현장명)",
                    labelStyle: const TextStyle(
                      color: tossSubText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    floatingLabelStyle: const TextStyle(
                      color: tossBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    filled: true,
                    fillColor: tossBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      if (!await _confirmChangesBeforeSave()) return;
                      if (!await _confirmMinGapViolationsIfAny()) return;
                      _saveToFirebase(projectCtrl.text);
                    },
                    icon: const Icon(
                      Icons.cloud_upload_rounded,
                      color: pureWhite,
                    ),
                    label: const Text(
                      "서버에 저장",
                      style: TextStyle(
                        color: pureWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      backgroundColor: tossBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      if (!await _confirmMinGapViolationsIfAny()) return;
                      _shareAsPdf(projectCtrl.text);
                    },
                    icon: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: tossText,
                    ),
                    label: const Text(
                      "QR 도면 PDF로 공유",
                      style: TextStyle(
                        color: tossText,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      side: const BorderSide(color: layoutLine, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                if (widget.attachToReport) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _attachToDailyReportPhoto();
                      },
                      icon: const Icon(
                        Icons.add_photo_alternate_rounded,
                        color: tossBlue,
                      ),
                      label: const Text(
                        "배치도를 작업 일지 사진으로 추가",
                        style: TextStyle(
                          color: tossBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        side: const BorderSide(color: tossBlue, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  pw.Widget _pdfCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// PDF 용지·방향·도면 번호·리비전을 묻는다. 용지·방향은 폰에 기억한다. 취소하면 null.
  Future<({String paper, bool landscape})?> _askPdfOptions() async {
    String paper = _pdfPaper;
    bool landscape = _pdfLandscape;
    final noCtrl = TextEditingController(text: _drawingNo);
    final revCtrl = TextEditingController(text: _revision);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "PDF 만들기",
            style: TextStyle(color: tossText, fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panelLabel("용지"),
                const SizedBox(height: 6),
                // 폰 폭에서는 넷이 한 줄에 안 들어가 줄을 바꾼다(예전엔 오른쪽이 잘렸다).
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final p in const ['A4', 'A3'])
                      ChoiceChip(
                        key: ValueKey("pdf_paper_$p"),
                        label: Text(p),
                        selected: paper == p,
                        selectedColor: tossBlue,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: paper == p ? pureWhite : tossText,
                          fontWeight: FontWeight.w800,
                        ),
                        onSelected: (_) => setDlg(() => paper = p),
                      ),
                    for (final (v, t) in const [(false, "세로"), (true, "가로")])
                      ChoiceChip(
                        key: ValueKey("pdf_land_$v"),
                        label: Text(t),
                        selected: landscape == v,
                        selectedColor: tossBlue,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: landscape == v ? pureWhite : tossText,
                          fontWeight: FontWeight.w800,
                        ),
                        onSelected: (_) => setDlg(() => landscape = v),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCoordinateInput(
                  "도면 번호 (비워도 됨)",
                  noCtrl.text,
                  (_) {},
                  controller: noCtrl,
                ),
                const SizedBox(height: 8),
                _buildCoordinateInput(
                  "리비전 (예: 0, A, 1)",
                  revCtrl.text,
                  (_) {},
                  controller: revCtrl,
                ),
                const SizedBox(height: 8),
                Text(
                  keepWords(
                    "그림은 1:5·1:10·1:20 같은 표준 축척 중 용지에 들어가는 가장 큰 것으로 찍고, 표제란에 축척과 자 눈금을 넣습니다.",
                  ),
                  style: const TextStyle(fontSize: 13, color: tossSubText),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("취소", style: TextStyle(color: tossSubText)),
            ),
            TextButton(
              key: const ValueKey("pdf_go"),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                "만들기",
                style: TextStyle(color: tossBlue, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return null;
    _drawingNo = noCtrl.text.trim();
    _revision = revCtrl.text.trim();
    _pdfPaper = paper;
    _pdfLandscape = landscape;
    SharedPreferences.getInstance()
        .then((p) async {
          await p.setString(_pdfPaperPrefsKey, paper);
          await p.setBool(_pdfLandscapePrefsKey, landscape);
        })
        .catchError((_) {});
    _saveDraftToPrefs();
    return (paper: paper, landscape: landscape);
  }
}
