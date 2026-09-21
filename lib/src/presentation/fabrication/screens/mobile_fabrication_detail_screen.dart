import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/app_dialog.dart';
import '../../../core/utils/pdf_fonts.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:tubing_calculator/src/core/utils/pipe_size.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';

// 🚀 PDF 및 공유 관련 임포트
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// 🚀 모바일 전용 뷰어 및 DB 헬퍼 임포트
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_pipe_visualizer.dart';
import 'package:tubing_calculator/src/core/database/database_helper.dart';
import 'package:tubing_calculator/src/core/engine/tube_bending_engine.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/step_mark_card.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);
const Color _slate200 = Color(0xFFE2E8F0);

class MobileFabricationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> itemData;

  const MobileFabricationDetailScreen({super.key, required this.itemData});

  @override
  State<MobileFabricationDetailScreen> createState() =>
      _MobileFabricationDetailScreenState();
}

class _MobileFabricationDetailScreenState
    extends State<MobileFabricationDetailScreen> {
  Map<String, dynamic> _pToP = {};
  List<Map<String, dynamic>> _bendList = [];
  double _totalLength = 0.0;
  String _pipeSize = "";
  String _projectName = "";
  String _fromTo = "";
  double _tailLength = 0.0;
  String _startDir = "RIGHT";
  String _memoText = "";

  bool _startFit = false;
  bool _endFit = false;

  int? _selectedSegmentIndex;

  // 🚀 PDF 캡처 및 내보내기 상태
  bool _isExporting = false;

  /// 저장된 마킹 값이 없어 지금 장비 설정으로 셈했는지(안내 글에 쓴다).
  bool _marksFromCurrentSpecs = false;
  final GlobalKey _isoBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _parseData();
  }

  void _parseData() {
    try {
      _pToP = jsonDecode(widget.itemData['p_to_p']?.toString() ?? '{}');
      List<dynamic> rawBends = jsonDecode(
        widget.itemData['bend_data']?.toString() ?? '[]',
      );

      _bendList = List<Map<String, dynamic>>.from(rawBends);

      int markNumber = 1;
      for (int i = 0; i < _bendList.length; i++) {
        bool isStraight = (_bendList[i]['angle']?.toDouble() ?? 0.0) == 0.0;
        _bendList[i]['is_straight'] = isStraight;
        _bendList[i]['display_mark_num'] = isStraight ? 0 : markNumber;
        if (!isStraight) markNumber++;
      }

      double dbTotal =
          double.tryParse(widget.itemData['total_length']?.toString() ?? '0') ??
          0.0;

      double pToPTotal =
          double.tryParse(
            _pToP['total_length']?.toString() ??
                _pToP['total_cut']?.toString() ??
                '0',
          ) ??
          0.0;

      double bendListTotal = 0.0;
      if (_bendList.isNotEmpty) {
        bendListTotal =
            double.tryParse(_bendList[0]['total_length']?.toString() ?? '0') ??
            0.0;
      }

      double maxTotal = dbTotal;
      if (pToPTotal > maxTotal) maxTotal = pToPTotal;
      if (bendListTotal > maxTotal) maxTotal = bendListTotal;
      _totalLength = maxTotal;

      _pipeSize = widget.itemData['pipe_size']?.toString() ?? 'Unknown';
      _projectName = _pToP['project']?.toString() ?? '미지정 프로젝트';
      _fromTo = "${_pToP['from'] ?? '모름'} ➔ ${_pToP['to'] ?? '모름'}";
      _tailLength = double.tryParse(_pToP['tail']?.toString() ?? '0') ?? 0.0;
      _startDir = _pToP['start_dir']?.toString() ?? 'RIGHT';
      _memoText = _pToP['memo']?.toString() ?? "";

      _startFit =
          (_pToP['start_fit'] == true) || (_pToP['start_fit'] == 'true');
      _endFit = (_pToP['end_fit'] == true) || (_pToP['end_fit'] == 'true');
      _fillMarks();
    } catch (e) {
      debugPrint("데이터 파싱 에러: $e");
    }
  }

  /// 🚀 [고침] 요즘 저장한 도면에는 입력 값(길이·각도·방향)만 들어 있고
  /// 마킹 값이 없어서, 도면 보기의 마킹 가이드와 PDF에 마킹이 0으로 나왔다.
  /// 마킹 값이 없으면 마킹 탭과 같은 셈(지금 장비 설정)으로 채운다.
  /// 저장된 마킹 값이 있으면 그대로 둔다.
  void _fillMarks() {
    _marksFromCurrentSpecs = false;
    final bool missing = _bendList.any(
      (b) => b['is_straight'] != true && b['marking_point'] == null,
    );
    if (!missing || _bendList.isEmpty) return;

    final specs = MachineSpecs();
    final engine = TubeBendingEngine(
      radius: specs.radius,
      userGain90: specs.gain90,
      springbackDeg: specs.springback,
    );
    final instructions = <BendInstruction>[];
    for (int i = 0; i < _bendList.length; i++) {
      double l = (_bendList[i]['length'] as num?)?.toDouble() ?? 0.0;
      if (i == 0 && _startFit) l += specs.fittingDepth;
      if (i == _bendList.length - 1 && _endFit) l += specs.fittingDepth;
      instructions.add(
        BendInstruction(
          length: l,
          angle: (_bendList[i]['angle'] as num?)?.toDouble() ?? 0.0,
          rotation: (_bendList[i]['rotation'] as num?)?.toDouble() ?? 0.0,
        ),
      );
    }
    final List<StepResult> steps;
    try {
      steps = engine.calculate(
        instructions,
        specs.benderOffset,
        tail: _tailLength,
      )['steps'];
    } catch (e) {
      debugPrint("마킹 셈 실패: $e");
      return;
    }

    // 마킹 탭과 같이: 직관 사이의 간격은 다음 벤딩 간격에 합친다.
    int markNumber = 1;
    double carried = 0.0;
    for (int i = 0; i < _bendList.length; i++) {
      final b = _bendList[i];
      b['marking_point'] = steps[i].markingPoint;
      if (b['is_straight'] == true) {
        carried += steps[i].incrementalMark;
        b['incremental_mark'] = 0.0;
        b['mark_num'] = 0;
      } else {
        b['incremental_mark'] = steps[i].incrementalMark + carried;
        b['mark_num'] = markNumber++;
        b['target_angle'] = steps[i].targetAngle;
        carried = 0.0;
      }
    }
    _marksFromCurrentSpecs = true;
  }

  /// 이 도면을 벤딩 마킹 계산기 입력 목록으로 불러온다.
  /// 🚀 [추가] 예전에는 보관함 도면을 보기만 할 수 있고 다시 고쳐 쓸 수 없었다.
  /// 목록은 입력 탭의 ↶로 되돌릴 수 있다. 피팅·꼬리·시작 방향도 저장 때로 맞춘다.
  Future<void> _loadToCalculator() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: "계산기로 불러오기",
        okText: "불러오기",
        onCancel: () => Navigator.pop(ctx, false),
        onOk: () => Navigator.pop(ctx, true),
        content: AppDialog.message(
          "'$_fromTo'을(를) 불러오면 지금 입력 목록이 이 도면으로 바뀝니다.\n"
          "시작·끝 피팅과 꼬리 길이도 저장할 때 값으로 맞춥니다.\n"
          "(입력 탭의 ↶로 목록을 되돌릴 수 있습니다)",
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final m = MobileBendDataManager();
    m.replaceAll([
      for (final b in _bendList)
        {
          'length': (b['length'] as num?)?.toDouble() ?? 0.0,
          'angle': (b['angle'] as num?)?.toDouble() ?? 0.0,
          'rotation': (b['rotation'] as num?)?.toDouble() ?? 0.0,
        },
    ]);
    m.startFit = _startFit;
    m.endFit = _endFit;
    m.tail = _tailLength;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mobile_saved_start_dir', _startDir);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop({'loaded': true, 'startDir': _startDir});
  }

  String _getDirectionText(double rot) {
    if (rot == 0.0) return "UP";
    if (rot == 90.0) return "RIGHT";
    if (rot == 180.0) return "DOWN";
    if (rot == 270.0) return "LEFT";
    if (rot == 360.0) return "FRONT";
    if (rot == 450.0) return "BACK";
    return "${rot.toInt()}°";
  }

  String _getDirectionTextShort(double rot) {
    double normalizedRot = rot % 360.0;
    if (normalizedRot < 0) normalizedRot += 360.0;
    if (normalizedRot == 0.0) return "0° (유지)";
    if (normalizedRot <= 180.0) {
      return "CW ${normalizedRot.round()}°";
    } else {
      return "CCW ${(360.0 - normalizedRot).round()}°";
    }
  }

  IconData _getDirectionIcon(double rot) {
    if (rot == 0.0) return Icons.arrow_upward;
    if (rot == 90.0) return Icons.arrow_forward;
    if (rot == 180.0) return Icons.arrow_downward;
    if (rot == 270.0) return Icons.arrow_back;
    if (rot == 360.0) return Icons.call_made;
    if (rot == 450.0) return Icons.call_received;
    return Icons.rotate_right;
  }

  String _extractValue(Map<String, dynamic> map, List<String> keys) {
    for (String key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        var val = map[key];
        if (val is num) {
          return val.round().toString();
        } else if (val is String && val.isNotEmpty) {
          double? parsed = double.tryParse(val);
          return parsed != null ? parsed.round().toString() : val;
        }
      }
    }
    return "";
  }

  // 🚀 [추가] _extractValue는 화면 표시용으로 정수 반올림을 하기 때문에,
  // 소수점을 보존해야 하는 QR 압축 데이터에는 이 버전을 대신 쓴다.
  double _extractRawValue(Map<String, dynamic> map, List<String> keys) {
    for (String key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        var val = map[key];
        if (val is num) return val.toDouble();
        if (val is String) return double.tryParse(val) ?? 0.0;
      }
    }
    return 0.0;
  }

  Future<Uint8List?> _captureIsoImage() async {
    try {
      RenderRepaintBoundary boundary =
          _isoBoundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("이미지 캡처 에러: $e");
      return null;
    }
  }

  // 🚀 [버그 수정] 예전엔 전부 정수로 반올림해서 QR/공유 링크에 넣는
  // 바람에 소수점 이하 길이·각도가 잘려나가, 스캔해서 불러온 도면
  // 형상이 원본과 미묘하게 달라지는 원인이 됐다. 소수점 둘째 자리까지
  // 보존한다 (디코더는 이미 double.tryParse라 그대로 호환됨).
  String _formatCompressed(double v) {
    return v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);
  }

  String _compressBendData(List<Map<String, dynamic>> bends) {
    if (bends.isEmpty) return "";
    return bends
        .map((b) {
          double l = (b['length'] as num?)?.toDouble() ?? 0.0;
          double a = double.tryParse(b['angle']?.toString() ?? '0') ?? 0.0;
          double r = (b['rotation'] as num?)?.toDouble() ?? 0.0;
          double m = _extractRawValue(b, ['mark', 'marking', 'marking_point']);
          return "${_formatCompressed(l)}_${_formatCompressed(a)}_"
              "${_formatCompressed(r)}_${_formatCompressed(m)}";
        })
        .join('-');
  }

  Future<void> _exportToPDFAndShare() async {
    if (_bendList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("공유할 데이터가 없습니다."),
          backgroundColor: slate600,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      Uint8List? isoImageBytes = await _captureIsoImage();
      pw.MemoryImage? pdfIsoImage;
      if (isoImageBytes != null) {
        pdfIsoImage = pw.MemoryImage(isoImageBytes);
      }

      final pdfFonts = await loadKoreanPdfFonts();
      final ttf = pdfFonts.regular;

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
          fontFallback: [ttf],
        ),
      );

      final int displayTotalCut = _totalLength.round();
      final String currentDate = DateTime.now().toString().split(' ')[0];

      String fittingStr = "";
      if (_startFit) fittingStr += "S ";
      if (_endFit) fittingStr += (fittingStr.isNotEmpty ? "& E" : "E");
      if (fittingStr.isEmpty) fittingStr = "None";

      String compressedBends = _compressBendData(_bendList);

      String qrDataUrl =
          "tubingapp://view?p=${Uri.encodeComponent(_projectName)}&s=${Uri.encodeComponent(_pipeSize)}&b=$compressedBends&sf=$_startFit&ef=$_endFit&t=$_tailLength&d=$_startDir";

      pw.Widget buildQRCodeWidget() {
        return pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(
              width: 50,
              height: 50,
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrDataUrl.isEmpty ? "tubingapp://error" : qrDataUrl,
                color: PdfColors.black,
                drawText: false,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              "3D VIEWER",
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            ),
          ],
        );
      }

      pw.Widget buildTitleBlock() {
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                width: double.infinity,
                alignment: pw.Alignment.center,
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
                  ),
                ),
                child: pw.Text(
                  "TUBE FABRICATION REPORT",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              pw.TableHelper.fromTextArray(
                cellPadding: const pw.EdgeInsets.all(5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(2),
                },
                data: [
                  ['PROJECT', _projectName, 'DATE', currentDate],
                  [
                    'LINE',
                    '${_pToP['from'] ?? '-'} -> ${_pToP['to'] ?? '-'}',
                    'SPEC/FIT',
                    '$_pipeSize / $fittingStr',
                  ],
                  ['TOTAL CUT', '$displayTotalCut mm', 'DWG NO.', '-'],
                ],
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerLeft,
                },
                border: const pw.TableBorder(
                  verticalInside: pw.BorderSide(
                    color: PdfColors.black,
                    width: 0.5,
                  ),
                  horizontalInside: pw.BorderSide(
                    color: PdfColors.black,
                    width: 0.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                buildTitleBlock(),
                pw.Text(
                  "[ ISO DRAWING ]",
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Expanded(
                  child: pw.Container(
                    width: double.infinity,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.black, width: 1),
                    ),
                    padding: const pw.EdgeInsets.all(10),
                    child: pdfIsoImage != null
                        ? pw.Center(
                            child: pw.Image(
                              pdfIsoImage,
                              fit: pw.BoxFit.contain,
                            ),
                          )
                        : pw.Center(
                            child: pw.Text(
                              "도면 이미지가 없습니다.",
                              style: const pw.TextStyle(color: PdfColors.grey),
                            ),
                          ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      '- PAGE 1 -',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    buildQRCodeWidget(),
                  ],
                ),
              ],
            );
          },
        ),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          header: (context) => buildTitleBlock(),
          footer: (context) => pw.Container(
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  '- PAGE ${context.pageNumber} -',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
                buildQRCodeWidget(),
              ],
            ),
          ),
          build: (pw.Context context) {
            return [
              pw.Text(
                "[ BENDING SEQUENCE ]",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: [
                  'NO.',
                  'LENGTH (mm)',
                  'ANGLE',
                  'DIRECTION',
                  'MARK (mm)',
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellHeight: 28,
                cellAlignment: pw.Alignment.center,
                cellStyle: const pw.TextStyle(fontSize: 10),
                data: _bendList.map((bend) {
                  bool isStraight = bend['is_straight'] ?? false;
                  String markNum = isStraight
                      ? "-"
                      : "${bend['display_mark_num']}";
                  String length = "${(bend['length'] ?? 0).toDouble().round()}";
                  String angle = isStraight
                      ? "-"
                      : "${(double.tryParse(bend['angle']?.toString() ?? '0') ?? 0).round()}°";
                  String direction = isStraight
                      ? "-"
                      : _getDirectionTextShort(
                          (bend['rotation'] ?? 0.0).toDouble(),
                        );
                  String marking = isStraight
                      ? "-"
                      : _extractValue(bend, [
                          'mark',
                          'marking',
                          'marking_point',
                        ]);
                  return [markNum, length, angle, direction, marking];
                }).toList(),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "* 여유 기장(Tail): ${_tailLength.round()} mm   |   시작 방향(Start Dir): $_startDir",
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                "[ REMARKS (특이사항) ]",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                width: double.infinity,
                constraints: const pw.BoxConstraints(minHeight: 80),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.5),
                ),
                child: pw.Text(
                  _memoText.isNotEmpty ? _memoText : "(적어 둔 특이사항이 없습니다.)",
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _memoText.isNotEmpty
                        ? PdfColors.black
                        : PdfColors.grey600,
                    lineSpacing: 1.5,
                  ),
                ),
              ),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File("${output.path}/ISO_REPORT_$timestamp.pdf");
      await file.writeAsBytes(await pdf.save());

      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: '[$_projectName] ${_pToP['from'] ?? ''} 작업 지시서 리포트입니다.');
    } catch (e) {
      debugPrint("PDF 생성 실패: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("PDF 생성 중 오류가 발생했습니다."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // 🚀 도면 정보 수정 모달 (토스 감성 + 안정성/알림 + 데이터 변경 감지 활성화)
  Future<void> _editInfo() async {
    // 현재 데이터 초기값 저장 (비교용)
    String initialProj = _projectName;
    String initialFrom = _pToP['from'] ?? '';
    String initialTo = _pToP['to'] ?? '';
    String initialMemo = _memoText;
    String selectedSize = _pipeSize; // Size는 현재 수정 UI에 없으므로 기본 유지

    TextEditingController projCtrl = TextEditingController(text: initialProj);
    TextEditingController fromCtrl = TextEditingController(text: initialFrom);
    TextEditingController toCtrl = TextEditingController(text: initialTo);
    TextEditingController memoCtrl = TextEditingController(text: initialMemo);

    // 내부 헬퍼 위젯: 입력할 때마다 UI(버튼)를 업데이트하도록 onChanged 추가
    Widget buildTossTextField({
      required TextEditingController controller,
      required String label,
      int maxLines = 1,
      TextInputAction textInputAction = TextInputAction.next,
      void Function(String)? onChanged,
    }) {
      return TextField(
        controller: controller,
        maxLines: maxLines,
        textInputAction: textInputAction,
        onChanged: onChanged, // 입력 변경 감지
        style: const TextStyle(
          color: slate900,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: slate600, fontSize: 14),
          filled: true,
          fillColor: slate100,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: makitaTeal, width: 2),
          ),
        ),
      );
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // 🚀 데이터가 초기값과 다른지 실시간으로 비교
            bool hasChanges =
                projCtrl.text != initialProj ||
                fromCtrl.text != initialFrom ||
                toCtrl.text != initialTo ||
                memoCtrl.text != initialMemo;

            // 텍스트 필드에 글자가 입력될 때마다 State를 갱신해 버튼 색상을 바꿉니다.
            void onTextChanged(String _) {
              setModalState(() {});
            }

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 12,
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
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const Text(
                      "도면 정보 수정",
                      style: TextStyle(
                        color: slate900,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    buildTossTextField(
                      controller: projCtrl,
                      label: "프로젝트 명 (PROJECT)",
                      onChanged: onTextChanged,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: buildTossTextField(
                            controller: fromCtrl,
                            label: "시작점 (FROM)",
                            onChanged: onTextChanged,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildTossTextField(
                            controller: toCtrl,
                            label: "도착점 (TO)",
                            onChanged: onTextChanged,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    buildTossTextField(
                      controller: memoCtrl,
                      label: "특이사항 (MEMO)",
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                      onChanged: onTextChanged,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          // 🚀 변경사항이 있으면 마키타 틸(활성), 없으면 슬레이트600(닫기 버튼 느낌)
                          backgroundColor: hasChanges ? makitaTeal : slate600,
                          foregroundColor: pureWhite,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                // 🚀 변경된 게 없으면 DB 안 건드리고 그냥 조용히 닫음!
                                if (!hasChanges) {
                                  Navigator.pop(context);
                                  return;
                                }

                                // 1. 메신저 객체 미리 확보 (context deactivate 버그 방지)
                                final messenger = ScaffoldMessenger.of(context);

                                setModalState(() => isSaving = true);
                                FocusScope.of(context).unfocus();

                                try {
                                  Map<String, dynamic> newPtoP = {
                                    "project": projCtrl.text,
                                    "from": fromCtrl.text,
                                    "to": toCtrl.text,
                                    "start_fit": _startFit,
                                    "end_fit": _endFit,
                                    "tail": _tailLength,
                                    "start_dir": _startDir,
                                    "memo": memoCtrl.text,
                                  };

                                  await DatabaseHelper.instance
                                      .updateHistory(widget.itemData['id'], {
                                        'p_to_p': jsonEncode(newPtoP),
                                        'pipe_size': selectedSize,
                                      });

                                  // 부모 위젯 데이터 갱신
                                  setState(() {
                                    widget.itemData['p_to_p'] = jsonEncode(
                                      newPtoP,
                                    );
                                    widget.itemData['pipe_size'] = selectedSize;
                                    _parseData();
                                  });

                                  // 2. 모달 닫기
                                  if (!context.mounted) return;
                                  Navigator.pop(context);

                                  // 3. 미리 빼둔 messenger로 알림 띄우기 (에러 안 남!)
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        "도면 정보를 수정했습니다.",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor: makitaTeal,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                } catch (e) {
                                  debugPrint("저장 에러: $e");
                                  setModalState(() => isSaving = false);
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text("저장 중 오류가 발생했습니다."),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        child: isSaving
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: pureWhite,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    "저장 중...",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            // 🚀 텍스트도 상태에 맞게 분기 (변경 있음: 수정 완료 / 변경 없음: 닫기)
                            : Text(
                                hasChanges ? "수정 완료" : "닫기",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> displayMarks = _bendList
        .where((b) => b['is_hidden'] != true)
        .toList();

    // 🚀 전선관·튜브 계산기와 같은 모양: 밝은 머리, 총 절단 길이 카드,
    // STEP 카드. 기능(공유·정보 수정·계산기로 불러오기)은 그대로.
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: slate100,
        appBar: AppBar(
          backgroundColor: slate100,
          foregroundColor: slate900,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _projectName,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: slate900,
                ),
              ),
              Text(
                _fromTo,
                style: const TextStyle(
                  fontSize: 12,
                  color: slate600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            _isExporting
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: slate900,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.share_rounded, color: slate900),
                    tooltip: "PDF 공유",
                    onPressed: _exportToPDFAndShare,
                  ),
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: slate900),
              tooltip: "도면 정보 수정",
              onPressed: _editInfo,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                key: const Key('load_to_calculator'),
                icon: const Icon(Icons.file_open_outlined, color: slate900),
                tooltip: "계산기로 불러오기",
                onPressed: _loadToCalculator,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildSummaryPanel(),
            const TabBar(
              labelColor: makitaTeal,
              unselectedLabelColor: slate600,
              indicatorColor: makitaTeal,
              indicatorWeight: 3,
              dividerColor: _slate200,
              labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: [
                Tab(text: "아이소 (3D)"),
                Tab(text: "마킹 가이드"),
              ],
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [_buildIsoPage(), _buildMarkingPage(displayMarks)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPanel() {
    final String fitText = _startFit && _endFit
        ? "시작·종료"
        : _startFit
        ? "시작"
        : _endFit
        ? "종료"
        : "없음";

    return CutLengthCard(
      totalCut: _totalLength,
      bottom: [
        Row(
          children: [
            Expanded(child: CardLabelValue("규격", _pipeSize)),
            Container(width: 1, height: 24, color: _slate200),
            const SizedBox(width: 12),
            Expanded(child: CardLabelValue("피팅", fitText)),
            if (_tailLength > 0) ...[
              Container(width: 1, height: 24, color: _slate200),
              const SizedBox(width: 12),
              Expanded(
                child: CardLabelValue("꼬리 길이", "${_tailLength.round()} mm"),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildIsoPage() {
    return SizedBox(
      width: double.infinity,
      child: RepaintBoundary(
        key: _isoBoundaryKey,
        child: Container(
          color: _isExporting ? pureWhite : slate900,
          child: MobilePipeVisualizer(
            bendList: _bendList,
            tailLength: _tailLength,
            // 🚀 [고침] 보관함에 저장해 둔 도면을 열면 제원이 안 넘어가서
            // 곡선부가 그려지지 않았다. 도면에 적힌 규격으로 관 굵기를 잡고,
            // 반경·피팅 깊이는 지금 제원을 쓴다(도면에 제원은 안 남아 있다).
            bendRadius: MachineSpecs().radius,
            outerDiameter: pipeSizeToMm(_pipeSize),
            fittingDepth: MachineSpecs().fittingDepth,
            initialStartDir: _startDir,
            startFit: _startFit,
            endFit: _endFit,
            isLightMode: _isExporting,
            selectedSegmentIndex: _selectedSegmentIndex,
            onStartDirChanged: (newDir) async {
              setState(() {
                _startDir = newDir;
              });
              try {
                Map<String, dynamic> newPtoP = {
                  "project": _projectName,
                  "from": _pToP['from'] ?? '',
                  "to": _pToP['to'] ?? '',
                  "start_fit": _startFit,
                  "end_fit": _endFit,
                  "tail": _tailLength,
                  "start_dir": newDir,
                  "memo": _memoText,
                };
                String newPtoPJson = jsonEncode(newPtoP);
                await DatabaseHelper.instance.updateHistory(
                  widget.itemData['id'],
                  {'p_to_p': newPtoPJson},
                );
                widget.itemData['p_to_p'] = newPtoPJson;
              } catch (e) {
                debugPrint("방향 저장 실패: $e");
              }
            },
            totalCutLength: _totalLength,
          ),
        ),
      ),
    );
  }

  Widget _buildMarkingPage(List<Map<String, dynamic>> displayMarks) {
    if (displayMarks.isEmpty) {
      return const Center(
        child: Text("표시할 마킹 데이터가 없습니다.", style: TextStyle(color: slate600)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      itemCount: displayMarks.length + (_marksFromCurrentSpecs ? 1 : 0),
      itemBuilder: (context, index) {
        if (_marksFromCurrentSpecs) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: slate600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "지금 장비 설정(반경 ${MachineSpecs().radius.round()}mm)으로 "
                      "셈한 마킹입니다.",
                      style: const TextStyle(
                        color: slate600,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          index -= 1;
        }
        final item = displayMarks[index];
        final bool isStraight = item['is_straight'] == true;
        final int mark = (item['marking_point'] as num?)?.round() ?? 0;
        final int incremental =
            (item['incremental_mark'] as num?)?.round() ?? 0;
        final int length = (item['length'] as num?)?.round() ?? 0;
        final int markNum =
            (item['mark_num'] as num?)?.toInt() ??
            (item['display_mark_num'] as num?)?.toInt() ??
            0;
        final double rotation = (item['rotation'] as num?)?.toDouble() ?? 0.0;
        final double angle =
            double.tryParse(item['angle']?.toString() ?? '0') ?? 0.0;
        final double target =
            (item['target_angle'] as num?)?.toDouble() ?? angle;
        final bool hasSpringback = (target - angle).abs() > 0.05;

        final int realIndex = _bendList.indexOf(item);
        final bool isSelected = _selectedSegmentIndex == realIndex;

        return StepMarkCard(
          isStraight: isStraight,
          markNum: markNum,
          mark: mark,
          title: isStraight
              ? "직관 연장 마킹"
              : hasSpringback
              ? "${angle.round()}° 벤딩 (실제 ${target.toStringAsFixed(1)}°)"
              : "${angle.round()}° 벤딩",
          dirIcon: _getDirectionIcon(rotation),
          dirText: _getDirectionText(rotation),
          selected: isSelected,
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _selectedSegmentIndex = isSelected ? null : realIndex;
            });
          },
          notes: [
            if (isStraight)
              (Icons.info_outline_rounded, "직관 +$length mm", stepNoteGrey)
            else ...[
              if (markNum > 1)
                (
                  Icons.info_outline_rounded,
                  "앞 마킹과의 거리 +$incremental mm",
                  stepNoteTeal,
                ),
              (Icons.info_outline_rounded, "배관 $length mm", stepNoteGrey),
            ],
          ],
        );
      },
    );
  }
}
