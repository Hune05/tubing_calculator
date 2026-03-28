import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:tubing_calculator/src/core/database/database_helper.dart';
import 'package:tubing_calculator/src/data/bend_data_manager.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:tubing_calculator/src/presentation/calculator/widgets/pipe_visualizer.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class FabricationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> itemData;
  const FabricationDetailScreen({super.key, required this.itemData});

  @override
  State<FabricationDetailScreen> createState() =>
      _FabricationDetailScreenState();
}

class _FabricationDetailScreenState extends State<FabricationDetailScreen> {
  late Map<String, dynamic> currentData;
  late String project;
  late String from;
  late String to;

  bool startFit = false;
  bool endFit = false;
  double tail = 0.0;

  String startDir = 'RIGHT';
  int? _selectedSegmentIndex;

  bool _isExporting = false;

  String memoText = "";

  List<Map<String, dynamic>> parsedBendList = [];

  final GlobalKey _isoBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    currentData = Map<String, dynamic>.from(widget.itemData);
    _parsePtoP();
    _parseBendData();
  }

  void _parsePtoP() {
    try {
      var pData = jsonDecode(currentData['p_to_p']);
      project = pData['project'] ?? "N/A";
      from = pData['from'] ?? "N/A";
      to = pData['to'] ?? "N/A";
      startFit = (pData['start_fit'] == true) || (pData['start_fit'] == 'true');
      endFit = (pData['end_fit'] == true) || (pData['end_fit'] == 'true');
      tail = double.tryParse(pData['tail']?.toString() ?? '0.0') ?? 0.0;
      startDir = pData['start_dir'] ?? 'RIGHT';
      memoText = pData['memo'] ?? "";
    } catch (e) {
      project = "N/A";
      from = currentData['p_to_p'] ?? "N/A";
      to = "";
      startDir = 'RIGHT';
      memoText = "";
    }
  }

  void _parseBendData() {
    try {
      List<dynamic> rawList = jsonDecode(currentData['bend_data']);
      parsedBendList = rawList
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      int markNumber = 1;
      for (int i = 0; i < parsedBendList.length; i++) {
        bool isStraight =
            (parsedBendList[i]['angle']?.toDouble() ?? 0.0) == 0.0;
        parsedBendList[i]['is_straight'] = isStraight;
        parsedBendList[i]['display_mark_num'] = isStraight ? 0 : markNumber;
        if (!isStraight) markNumber++;
      }
    } catch (e) {
      parsedBendList = [];
    }
  }

  // 🚀 벤딩기 실무 맞춤형: 시계(CW) / 반시계(CCW) 회전 각도 표시
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

  // 🚀🚀 [수정됨] 마킹값(Marking)도 압축 문자열에 포함시키도록 변경 🚀🚀
  String _compressBendData(List<Map<String, dynamic>> bends) {
    if (bends.isEmpty) return "";
    return bends
        .map((b) {
          int l = (b['length'] ?? 0).round();
          int a = double.tryParse(b['angle']?.toString() ?? '0')?.round() ?? 0;
          int r = (b['rotation'] ?? 0).round();

          // 마킹값 추출 후 정수로 변환 (없으면 0)
          String mStr = _extractValue(b, ['mark', 'marking', 'marking_point']);
          int m = double.tryParse(mStr)?.round() ?? 0;

          // 길이_각도_회전각_마킹값 형태로 반환
          return "${l}_${a}_${r}_$m";
        })
        .join('-');
  }

  Future<void> _exportToPDFAndShare() async {
    if (parsedBendList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("공유할 데이터가 없습니다."),
          backgroundColor: slate600,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    await Future.delayed(const Duration(milliseconds: 150));

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

      final double absoluteTotalCut =
          double.tryParse(currentData['total_length']?.toString() ?? '0') ??
          0.0;
      final int displayTotalCut = absoluteTotalCut.round();
      final String currentDate = DateTime.now().toString().split(' ')[0];

      String fittingStr = "";
      if (startFit) fittingStr += "S ";
      if (endFit) fittingStr += (fittingStr.isNotEmpty ? "& E" : "E");
      if (fittingStr.isEmpty) fittingStr = "None";

      String compressedBends = _compressBendData(parsedBendList);

      // 🚀🚀 [수정됨] 시작 방향(startDir)을 d 파라미터로 추가 🚀🚀
      String qrDataUrl =
          "tubingapp://view?p=${Uri.encodeComponent(project)}&s=${Uri.encodeComponent(currentData['pipe_size'] ?? '')}&b=$compressedBends&sf=$startFit&ef=$endFit&t=$tail&d=$startDir";
      if (qrDataUrl.isEmpty) qrDataUrl = "tubingapp://error";

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
                data: qrDataUrl,
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
                  ['PROJECT', project, 'DATE', currentDate],
                  [
                    'LINE',
                    '$from -> $to',
                    'SPEC/FIT',
                    '${currentData['pipe_size']} / $fittingStr',
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
                data: parsedBendList.map((bend) {
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
                  "* 여유 기장(Tail): ${tail.round()} mm   |   시작 방향(Start Dir): $startDir",
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
                  memoText.isNotEmpty ? memoText : "(기재된 특이사항이 없습니다.)",
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: memoText.isNotEmpty
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
      ], text: '[$project] $from 작업 지시서 리포트입니다.');
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

  Future<void> _editInfo() async {
    TextEditingController projCtrl = TextEditingController(text: project);
    TextEditingController fromCtrl = TextEditingController(text: from);
    TextEditingController toCtrl = TextEditingController(text: to);
    TextEditingController memoCtrl = TextEditingController(text: memoText);
    String selectedSize = currentData['pipe_size'] ?? '1/2"';

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
                        "start_fit": startFit,
                        "end_fit": endFit,
                        "tail": tail,
                        "start_dir": startDir,
                        "memo": memoCtrl.text,
                      };
                      await DatabaseHelper.instance.updateHistory(
                        currentData['id'],
                        {
                          'p_to_p': jsonEncode(newPtoP),
                          'pipe_size': selectedSize,
                        },
                      );
                      setState(() {
                        currentData['p_to_p'] = jsonEncode(newPtoP);
                        currentData['pipe_size'] = selectedSize;
                        _parsePtoP();
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
    final double absoluteTotalCut =
        double.tryParse(currentData['total_length']?.toString() ?? '0') ?? 0.0;
    final int displayTotalCut = absoluteTotalCut.round();

    String fittingStr = "";
    if (startFit) fittingStr += "S ";
    if (endFit) fittingStr += (fittingStr.isNotEmpty ? "& E" : "E");
    if (fittingStr.isEmpty) fittingStr = "None";

    return Scaffold(
      backgroundColor: slate100,
      appBar: AppBar(
        title: Text(
          'ISO DWG: $project',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: makitaTeal,
        foregroundColor: pureWhite,
        elevation: 0,
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
      body: SafeArea(
        child: Column(
          children: [
            _buildTopInfoPanel(displayTotalCut, fittingStr),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 7,
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: pureWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: RepaintBoundary(
                          key: _isoBoundaryKey,
                          child: Container(
                            color: pureWhite,
                            child: PipeVisualizer(
                              isLightMode: _isExporting,
                              bendList: parsedBendList,
                              tailLength: tail,
                              selectedSegmentIndex: _selectedSegmentIndex,
                              initialStartDir: startDir,
                              startFit: startFit,
                              endFit: endFit,
                              onStartDirChanged: (newDir) async {
                                setState(() {
                                  startDir = newDir;
                                });
                                try {
                                  Map<String, dynamic> newPtoP = {
                                    "project": project,
                                    "from": from,
                                    "to": to,
                                    "start_fit": startFit,
                                    "end_fit": endFit,
                                    "tail": tail,
                                    "start_dir": newDir,
                                    "memo": memoText,
                                  };
                                  String newPtoPJson = jsonEncode(newPtoP);
                                  await DatabaseHelper.instance.updateHistory(
                                    currentData['id'],
                                    {'p_to_p': newPtoPJson},
                                  );
                                  currentData['p_to_p'] = newPtoPJson;
                                } catch (e) {
                                  debugPrint("방향 저장 실패: $e");
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.only(
                        top: 12,
                        bottom: 12,
                        right: 12,
                      ),
                      decoration: BoxDecoration(
                        color: pureWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: parsedBendList.isEmpty
                          ? const Center(
                              child: Text(
                                "NO DATA",
                                style: TextStyle(color: slate600),
                              ),
                            )
                          : Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: slate100,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "상세 작업 구간",
                                        style: TextStyle(
                                          color: slate600,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount:
                                        parsedBendList.length +
                                        (tail > 0 ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      bool isSelected =
                                          _selectedSegmentIndex == index;
                                      if (index < parsedBendList.length) {
                                        return _buildSegmentListItem(
                                          index: index,
                                          isSelected: isSelected,
                                          bendData: parsedBendList[index],
                                          onTap: () => setState(
                                            () => _selectedSegmentIndex =
                                                isSelected ? null : index,
                                          ),
                                        );
                                      } else {
                                        return _buildSegmentListItem(
                                          index: index,
                                          isSelected: isSelected,
                                          isTail: true,
                                          tailLength: tail,
                                          onTap: () => setState(
                                            () => _selectedSegmentIndex =
                                                isSelected ? null : index,
                                          ),
                                        );
                                      }
                                    },
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
        ),
      ),
    );
  }

  Widget _buildTopInfoPanel(int displayTotalCut, String fittingStr) {
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
                  "LINE",
                  style: TextStyle(
                    color: slate600,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$from ➔ $to",
                  style: const TextStyle(
                    color: slate900,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                  overflow: TextOverflow.ellipsis,
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
                    "${currentData['pipe_size']} / $fittingStr",
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
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "TOTAL CUT",
                    style: TextStyle(
                      color: slate600,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$displayTotalCut mm",
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentListItem({
    required int index,
    required bool isSelected,
    Map<String, dynamic>? bendData,
    required VoidCallback onTap,
    bool isTail = false,
    double? tailLength,
  }) {
    String lengthText = "";
    String directionText = "";
    String markText = "";
    String baText = "";
    String sbText = "";

    bool isStraight = false;
    int displayMarkNum = 0;

    if (isTail) {
      lengthText = tailLength?.round().toString() ?? "0";
      directionText = "TAIL";
    } else if (bendData != null) {
      double rawLength = (bendData['length'] ?? 0).toDouble();
      double rotation = (bendData['rotation'] ?? 0.0).toDouble();

      double rawAngle =
          double.tryParse(bendData['angle']?.toString() ?? '0') ?? 0.0;
      String angle = rawAngle.round().toString();

      isStraight = bendData['is_straight'] ?? false;
      displayMarkNum = bendData['display_mark_num'] ?? 0;

      lengthText = rawLength.round().toString();
      directionText = "$angle° ${_getDirectionTextShort(rotation)}";

      if (!isStraight) {
        markText = _extractValue(bendData, [
          'mark',
          'marking',
          'marking_point',
        ]);
        baText = _extractValue(bendData, ['bend_allowance', 'ba']);
        sbText = _extractValue(bendData, ['springback', 'sb']);
      }
    }

    if (isTail || isStraight) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.orange.withValues(alpha: 0.15)
                : slate100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(
                isTail ? Icons.straighten : Icons.arrow_downward,
                color: Colors.grey.shade500,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isTail ? "여유 기장 (TAIL)" : "직관 연장 (L: $lengthText mm)",
                  style: const TextStyle(
                    color: slate600,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (isTail)
                Text(
                  "+$lengthText mm",
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    bool hasExtraInfo = baText.isNotEmpty || sbText.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.orange.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.orange.shade700 : makitaTeal,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "$displayMarkNum",
                    style: const TextStyle(
                      color: pureWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                if (markText.isNotEmpty)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "마킹 지점 (MARKING)",
                          style: TextStyle(
                            color: slate600,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "$markText mm",
                          style: TextStyle(
                            color: isSelected
                                ? Colors.orange.shade800
                                : slate900,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.orange.withValues(alpha: 0.05)
                    : slate100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Colors.orange.shade200
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "입력 기장(L)",
                        style: TextStyle(
                          color: slate600,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "$lengthText mm",
                        style: const TextStyle(
                          color: slate900,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 24, color: Colors.grey.shade300),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "벤딩 각도/방향",
                        style: TextStyle(
                          color: slate600,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        directionText,
                        style: const TextStyle(
                          color: makitaTeal,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasExtraInfo) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (baText.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(
                        "BA: $baText",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (sbText.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.purple.shade100),
                      ),
                      child: Text(
                        "SB: $sbText°",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
