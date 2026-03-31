import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

// 🚀 PDF 및 공유 관련 임포트
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// 🚀 모바일 전용 뷰어 및 DB 헬퍼 임포트
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_pipe_visualizer.dart';
import 'package:tubing_calculator/src/core/database/database_helper.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

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

      // 🚀 PDF 출력을 위해 마킹 번호와 직관 여부를 미리 계산해 둡니다.
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
      _fromTo = "${_pToP['from'] ?? '미상'} ➔ ${_pToP['to'] ?? '미상'}";
      _tailLength = double.tryParse(_pToP['tail']?.toString() ?? '0') ?? 0.0;
      _startDir = _pToP['start_dir']?.toString() ?? 'RIGHT';
      _memoText = _pToP['memo']?.toString() ?? "";

      _startFit =
          (_pToP['start_fit'] == true) || (_pToP['start_fit'] == 'true');
      _endFit = (_pToP['end_fit'] == true) || (_pToP['end_fit'] == 'true');
    } catch (e) {
      debugPrint("데이터 파싱 에러: $e");
    }
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

  // 🚀 3D 화면 캡처 기능
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

  String _compressBendData(List<Map<String, dynamic>> bends) {
    if (bends.isEmpty) return "";
    return bends
        .map((b) {
          int l = (b['length'] ?? 0).round();
          int a = double.tryParse(b['angle']?.toString() ?? '0')?.round() ?? 0;
          int r = (b['rotation'] ?? 0).round();
          String mStr = _extractValue(b, ['mark', 'marking', 'marking_point']);
          int m = double.tryParse(mStr)?.round() ?? 0;
          return "${l}_${a}_${r}_$m";
        })
        .join('-');
  }

  // 🚀 PDF 생성 및 공유 기능
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
    // 3D 뷰어가 라이트 모드로 전환되고 렌더링될 시간을 줍니다.
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      Uint8List? isoImageBytes = await _captureIsoImage();
      pw.MemoryImage? pdfIsoImage;
      if (isoImageBytes != null) {
        pdfIsoImage = pw.MemoryImage(isoImageBytes);
      }

      final fontData = await rootBundle.load(
        'assets/fonts/NotoSansKR-VariableFont_wght.ttf',
      );
      final ttf = pw.Font.ttf(fontData);

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

      // PDF 1페이지: ISO 도면
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

      // PDF 2페이지: 마킹 데이터 및 메모
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
                  _memoText.isNotEmpty ? _memoText : "(기재된 특이사항이 없습니다.)",
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

  // 🚀 도면 정보(P-to-P, Memo 등) 수정 모달
  Future<void> _editInfo() async {
    TextEditingController projCtrl = TextEditingController(text: _projectName);
    TextEditingController fromCtrl = TextEditingController(
      text: _pToP['from'] ?? '',
    );
    TextEditingController toCtrl = TextEditingController(
      text: _pToP['to'] ?? '',
    );
    TextEditingController memoCtrl = TextEditingController(text: _memoText);
    String selectedSize = _pipeSize;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 24,
          ),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: makitaTeal, width: 2),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "도면 정보 수정",
                  style: TextStyle(
                    color: slate900,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: projCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: "PROJECT",
                    filled: true,
                    fillColor: slate100,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fromCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: "FROM",
                          filled: true,
                          fillColor: slate100,
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: toCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: "TO",
                          filled: true,
                          fillColor: slate100,
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: memoCtrl,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: "특이사항 (MEMO)",
                    filled: true,
                    fillColor: slate100,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: makitaTeal,
                    ),
                    onPressed: () async {
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
                      await DatabaseHelper.instance.updateHistory(
                        widget.itemData['id'],
                        {
                          'p_to_p': jsonEncode(newPtoP),
                          'pipe_size': selectedSize,
                        },
                      );
                      setState(() {
                        widget.itemData['p_to_p'] = jsonEncode(newPtoP);
                        widget.itemData['pipe_size'] = selectedSize;
                        _parseData();
                      });
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "수정 완료",
                      style: TextStyle(
                        color: Colors.white,
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
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> displayMarks = _bendList
        .where((b) => b['is_hidden'] != true)
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: slate100,
        appBar: AppBar(
          backgroundColor: makitaTeal,
          foregroundColor: pureWhite,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _projectName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                _fromTo,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
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
                          color: pureWhite,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.share, size: 24),
                    tooltip: "PDF 공유",
                    onPressed: _exportToPDFAndShare,
                  ),
            IconButton(
              icon: const Icon(Icons.edit_note, size: 28),
              tooltip: "도면 정보 수정",
              onPressed: _editInfo,
            ),
          ],
        ),
        body: Column(
          children: [
            _buildSummaryPanel(),
            Container(
              color: pureWhite,
              child: const TabBar(
                labelColor: makitaTeal,
                unselectedLabelColor: slate600,
                indicatorColor: makitaTeal,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: "ISO DWG (3D)"),
                  Tab(text: "마킹 가이드"),
                ],
              ),
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
    String fittingStr = "";
    if (_startFit) fittingStr += "S ";
    if (_endFit) fittingStr += (fittingStr.isNotEmpty ? "& E" : "E");
    if (fittingStr.isEmpty) fittingStr = "None";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: pureWhite,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "총 컷팅 기장 (Total Cut)",
                  style: TextStyle(
                    color: slate600,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_totalLength.round()} mm",
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SIZE / FIT",
                    style: TextStyle(
                      color: slate600,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$_pipeSize / $fittingStr",
                    style: const TextStyle(
                      color: makitaTeal,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_tailLength > 0) ...[
            Container(width: 1, height: 40, color: Colors.grey.shade200),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "여유 기장",
                      style: TextStyle(
                        color: slate600,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "+${_tailLength.round()} mm",
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIsoPage() {
    return Container(
      width: double.infinity,
      color: slate900,
      // 🚀 PDF 캡처를 위한 RepaintBoundary 적용
      child: RepaintBoundary(
        key: _isoBoundaryKey,
        child: MobilePipeVisualizer(
          bendList: _bendList,
          tailLength: _tailLength,
          initialStartDir: _startDir,
          startFit: _startFit,
          endFit: _endFit,
          isLightMode: _isExporting, // 🚀 PDF 캡처 시 하얀 배경으로 자동 변경
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
    );
  }

  Widget _buildMarkingPage(List<Map<String, dynamic>> displayMarks) {
    if (displayMarks.isEmpty) {
      return const Center(
        child: Text("표시할 마킹 데이터가 없습니다.", style: TextStyle(color: slate600)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16).copyWith(bottom: 40),
      itemCount: displayMarks.length,
      itemBuilder: (context, index) {
        final item = displayMarks[index];

        int cumulativeMark = (item['marking_point'] as num?)?.round() ?? 0;
        int incrementalMark = (item['incremental_mark'] as num?)?.round() ?? 0;
        int originalLength = (item['length'] as num?)?.round() ?? 0;

        int realIndex = _bendList.indexOf(item);
        bool isSelected = _selectedSegmentIndex == realIndex;

        if (item['is_straight'] == true) {
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedSegmentIndex = isSelected ? null : realIndex;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.orange.shade50
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: Colors.orange.shade400, width: 2)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_downward,
                    color: isSelected ? Colors.orange.shade700 : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "직관 연장: +$originalLength mm",
                      style: TextStyle(
                        color: isSelected ? Colors.orange.shade900 : slate600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    "마킹: $cumulativeMark",
                    style: TextStyle(
                      color: isSelected ? Colors.orange.shade900 : makitaTeal,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        double rotationVal = (item['rotation'] as num?)?.toDouble() ?? 0.0;
        double angleVal = (item['angle'] as num?)?.toDouble() ?? 0.0;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _selectedSegmentIndex = isSelected ? null : realIndex;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.orange.shade50 : pureWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.orange.shade400
                    : makitaTeal.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.orange.shade500 : makitaTeal,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "${item['mark_num'] ?? '-'}",
                    style: const TextStyle(
                      color: pureWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "누적 마킹 지점",
                        style: TextStyle(
                          color: isSelected ? Colors.orange.shade800 : slate600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        "$cumulativeMark",
                        style: TextStyle(
                          color: isSelected ? Colors.orange.shade900 : slate900,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if ((item['mark_num'] as num?) != null &&
                          (item['mark_num'] as num) > 1)
                        Text(
                          "↳ 앞 마킹과의 거리: +$incrementalMark",
                          style: TextStyle(
                            color: isSelected
                                ? Colors.orange.shade600
                                : makitaTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "길이: $originalLength",
                      style: TextStyle(
                        color: isSelected ? Colors.orange.shade900 : slate900,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _getDirectionIcon(rotationVal),
                          size: 16,
                          color: isSelected
                              ? Colors.orange.shade700
                              : makitaTeal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${angleVal.round()}° / ${_getDirectionText(rotationVal)}",
                          style: TextStyle(
                            color: isSelected
                                ? Colors.orange.shade700
                                : makitaTeal,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
