// ignore_for_file: invalid_use_of_protected_member
part of 'project_detail_page.dart';

// 🚀 issues 부분(화면 클래스에서 옮겨 온 메서드들, 동작은 그대로).
extension _ProjectDetailPageState_issues on _ProjectDetailPageState {
  // ───────────────────────── 이슈 / 일지 탭 ─────────────────────────
  Widget _buildIssuesTab() {
    final punches = (log['punch_lists'] as List? ?? []);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (punches.isNotEmpty)
          Padding(
            padding: EdgeInsets.zero,
            child: OutlinedButton.icon(
              onPressed: _showIssueExport,
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text("이슈 보고서 내보내기"),
              style: OutlinedButton.styleFrom(foregroundColor: tossText),
            ),
          ),
        const SizedBox(height: 16),
        if (punches.isEmpty)
          _emptyText("등록된 이슈가 없습니다.")
        else
          PunchListSection(
            punchLists: punches,
            onOpenPunchDetail: (p) => _run(() => widget.actions.openPunch(p)),
            onBulkChanged: () {
              widget.actions.save();
              setState(() {});
            },
          ),
      ],
    );
  }

  void _showIssueExport() {
    bool onlyOpen = true;
    bool withMedia = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "이슈 보고서 내보내기",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text("미해결만"),
                      selected: onlyOpen,
                      onSelected: (_) => setS(() => onlyOpen = true),
                    ),
                    ChoiceChip(
                      label: const Text("전체"),
                      selected: !onlyOpen,
                      onSelected: (_) => setS(() => onlyOpen = false),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: withMedia,
                  onChanged: (v) => setS(() => withMedia = v == true),
                  title: const Text(
                    "PDF에 사진·도면 위치 포함",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await shareReportText(
                            buildIssueReportDoc(log, onlyOpen: onlyOpen),
                          );
                        },
                        icon: const Icon(Icons.chat_outlined, size: 18),
                        label: const Text("텍스트(카톡)"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await shareReportPdf(
                              buildIssueReportDoc(log, onlyOpen: onlyOpen),
                              withPhotos: withMedia,
                            );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(keepWords("PDF 생성 실패: $e")),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 18,
                        ),
                        label: const Text("PDF"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAsTemplate() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("템플릿 이름"),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: "예: 배관 신설 공사"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text("저장"),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == '표준') return;
    await savePhaseTemplate(
      templateFromPhases(
        name,
        phasesOf(log),
        workType: log['workType']?.toString(),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(keepWords("'$name' 템플릿을 저장했습니다. 단계 만들기에서 불러올 수 있습니다.")),
        ),
      );
    }
  }

  Future<void> _editReportHeader() async {
    final cur = (log['reportHeader'] as Map?) ?? {};
    final company = TextEditingController(
      text: cur['company']?.toString() ?? '',
    );
    final manager = TextEditingController(
      text: cur['manager']?.toString() ?? '',
    );
    String? logo = (cur['logoB64']?.toString() ?? '').isEmpty
        ? null
        : cur['logoB64'].toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(keepWords("이 프로젝트 보고서 머리말")),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  keepWords(
                    "발주처마다 다른 머리말·로고가 필요할 때 적습니다. 비워 두면 기본 보고서 양식을 사용합니다.",
                  ),
                  style: TextStyle(fontSize: 12, color: tossSubText),
                ),
                TextField(
                  controller: company,
                  decoration: InputDecoration(
                    labelText: "회사명 / 현장명",
                    hintText: ReportStyle.current.company,
                  ),
                ),
                TextField(
                  controller: manager,
                  decoration: InputDecoration(
                    labelText: "담당자",
                    hintText: ReportStyle.current.manager,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (logo != null)
                      Container(
                        width: 48,
                        height: 48,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.memory(
                          base64Decode(logo!),
                          fit: BoxFit.contain,
                        ),
                      ),
                    OutlinedButton(
                      onPressed: () async {
                        final path = await ImagePickerHelper.pickImage(ctx);
                        if (path == null) return;
                        final bytes =
                            await FlutterImageCompress.compressWithFile(
                              path,
                              minWidth: 300,
                              minHeight: 300,
                              quality: 80,
                              format: path.toLowerCase().endsWith('.png')
                                  ? CompressFormat.png
                                  : CompressFormat.jpeg,
                            );
                        if (bytes != null) {
                          setD(() => logo = base64Encode(bytes));
                        }
                      },
                      child: Text(logo == null ? "이 프로젝트 로고" : "로고 변경"),
                    ),
                    if (logo != null)
                      TextButton(
                        onPressed: () => setD(() => logo = null),
                        child: const Text("삭제"),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("저장"),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final c = company.text.trim(), m = manager.text.trim();
    if (c.isEmpty && m.isEmpty && logo == null) {
      log.remove('reportHeader');
    } else {
      log['reportHeader'] = {
        'company': c,
        'manager': m,
        if (logo != null) 'logoB64': logo,
      };
    }
    _changed();
  }

  Future<void> _shareSummaryImage() async {
    try {
      final f = await createSummaryImage(log);
      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(f.path),
      ], text: "${log['name'] ?? '프로젝트'} 현황");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(keepWords("이미지 만들기 실패: $e"))));
      }
    }
  }

  // ───────────────────────── 사진 용량 정리 ─────────────────────────
  Future<void> _optimizePhotos() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("사진 용량 정리"),
        content: Text(
          keepWords(
            "이 프로젝트에 올라간 큰 사진(400KB 이상)을 줄여서 다시 올립니다. "
            "새 사진으로 저장이 끝난 뒤에 옛 파일은 삭제됩니다. 사진 수에 따라 시간이 걸릴 수 있습니다.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("정리 시작"),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    final progress = ValueNotifier<String>("준비 중…");
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: progress,
                  builder: (_, v, _) => Text(v),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    String message;
    try {
      final res = await optimizeProjectPhotos(
        log,
        onProgress: (d, t) => progress.value = "사진 확인 중… $d / $t",
      );
      if (res.count > 0) {
        progress.value = "저장 대기 중…";
        widget.actions.save();
        // 서버에 새 URL이 반영된 뒤에만 옛 파일을 지운다(최대 20초 대기).
        for (int i = 0; i < 100; i++) {
          if (WorkProjectRepository.pendingWrites.value == 0) break;
          await Future.delayed(const Duration(milliseconds: 200));
        }
        if (WorkProjectRepository.pendingWrites.value == 0) {
          for (final r in res.oldRefs) {
            try {
              await r.delete();
            } catch (_) {}
          }
        }
        message =
            "${res.count}장을 줄였습니다. 약 ${(res.savedBytes / 1024 / 1024).toStringAsFixed(1)}MB 절약했습니다.";
      } else {
        message = "줄일 만한 큰 사진이 없습니다.";
      }
    } catch (e) {
      message = "정리 중 오류가 발생했습니다: $e";
    }
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // ───────────────────────── 연락처 ─────────────────────────
  static const _contactRoles = ['현장 담당', '협력사', '자재 업체', '발주처', '기타'];

  List<Map<String, dynamic>> get _contacts => (log['contacts'] as List? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  Future<void> _call(String phone, {bool sms = false}) async {
    final n = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (n.isEmpty) return;
    final ok = await launchUrl(Uri(scheme: sms ? 'sms' : 'tel', path: n));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sms ? "문자 앱을 열 수 없습니다." : "전화 앱을 열 수 없습니다.")),
      );
    }
  }

  Future<void> _editContact({int? index}) async {
    final list = _contacts;
    final cur = index == null ? <String, dynamic>{} : list[index];
    final name = TextEditingController(text: cur['name']?.toString() ?? '');
    final phone = TextEditingController(text: cur['phone']?.toString() ?? '');
    String role = cur['role']?.toString() ?? _contactRoles.first;
    bool saveToBook = index == null;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(index == null ? "연락처 추가" : "연락처 수정"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final picked = await _pickFromBook();
                    if (picked != null) {
                      setD(() {
                        name.text = picked['name']?.toString() ?? '';
                        phone.text = picked['phone']?.toString() ?? '';
                        role = picked['role']?.toString() ?? role;
                        saveToBook = false;
                      });
                    }
                  },
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text("주소록에서 선택"),
                ),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: "이름 / 업체명"),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: "전화번호"),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final r in _contactRoles)
                      ChoiceChip(
                        label: Text(r),
                        selected: role == r,
                        onSelected: (_) => setD(() => role = r),
                      ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: saveToBook,
                  onChanged: (v) => setD(() => saveToBook = v == true),
                  title: Text(
                    keepWords("주소록에도 저장 (다른 프로젝트에서 재사용)"),
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (index != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'delete'),
                child: const Text("삭제", style: TextStyle(color: warningRed)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text("저장"),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (action == 'delete' && index != null) {
      list.removeAt(index);
    } else if (action == 'save') {
      if (name.text.trim().isEmpty && phone.text.trim().isEmpty) return;
      final item = {
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'role': role,
      };
      if (saveToBook) saveAddress(item);
      if (index == null) {
        list.add(item);
      } else {
        list[index] = item;
      }
    }
    log['contacts'] = list;
    _changed();
  }

  Future<Map<String, dynamic>?> _pickFromBook() async {
    var book = await loadAddressBook();
    if (!mounted) return null;
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setB) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            child: book.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      keepWords("주소록이 비어 있습니다. 연락처를 저장할 때 '주소록에도 저장'을 체크하십시오."),
                      style: TextStyle(color: tossSubText),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: Text(
                          "주소록 (길게 누르면 삭제)",
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      for (final e in book)
                        ListTile(
                          title: Text("${e['name']}  ·  ${e['role']}"),
                          subtitle: Text(e['phone']?.toString() ?? ''),
                          onTap: () => Navigator.pop(ctx, e),
                          onLongPress: () async {
                            await removeAddress(e);
                            final nb = await loadAddressBook();
                            setB(() => book = nb);
                          },
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
