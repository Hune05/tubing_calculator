import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // 🚀 캡처를 위한 패키지
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui; // 🚀 이미지 변환용
import 'dart:typed_data'; // 🚀 바이트 데이터용

import 'package:tubing_calculator/src/core/database/database_helper.dart';
import 'package:tubing_calculator/src/data/bend_data_manager.dart';

// 🚀 추가된 패키지 임포트
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// 🚀 독립된 아이소 엔진 임포트
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
  double fittingDepth = 0.0;

  String startDir = 'RIGHT';
  int? _selectedSegmentIndex;

  bool _isExporting = false;

  List<Map<String, dynamic>> parsedBendList = [];

  // 🚀 형상을 캡처하기 위한 GlobalKey 생성
  final GlobalKey _isoBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    currentData = Map<String, dynamic>.from(widget.itemData);
    fittingDepth = BendDataManager().fittingDepth;
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
    } catch (e) {
      project = "N/A";
      from = currentData['p_to_p'] ?? "N/A";
      to = "";
      startDir = 'RIGHT';
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

  String _getDirectionTextShort(double rot) {
    if (rot == 0.0) return "UP";
    if (rot == 90.0) return "RIGHT";
    if (rot == 180.0) return "DOWN";
    if (rot == 270.0) return "LEFT";
    if (rot == 360.0) return "FRONT";
    if (rot == 450.0) return "BACK";
    return "${rot.toInt()}°";
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

  // 🚀 형상 화면을 고화질 이미지(PNG)로 캡처하는 함수
  Future<Uint8List?> _captureIsoImage() async {
    try {
      // RepaintBoundary를 찾음
      RenderRepaintBoundary boundary =
          _isoBoundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      // pixelRatio를 3.0 이상으로 높여 아주 선명하게 캡처
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

  // 🚀 PDF 생성 및 공유 로직
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

    try {
      // 1. 아이소 도면 캡처
      Uint8List? isoImageBytes = await _captureIsoImage();
      pw.MemoryImage? pdfIsoImage;
      if (isoImageBytes != null) {
        pdfIsoImage = pw.MemoryImage(isoImageBytes);
      }

      final pdf = pw.Document();

      final double absoluteTotalCut =
          double.tryParse(currentData['total_length']?.toString() ?? '0') ??
          0.0;
      final int displayTotalCut = absoluteTotalCut.round();

      String fittingStr = "";
      if (startFit) fittingStr += "S ";
      if (endFit) fittingStr += (fittingStr.isNotEmpty ? "& E" : "E");
      if (fittingStr.isEmpty) fittingStr = "None";

      final String currentDate = DateTime.now().toString().split(' ')[0];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),

          header: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "TUBING FABRICATION REPORT",
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal800,
                      ),
                    ),
                    pw.Text(
                      "Date: $currentDate",
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 2, color: PdfColors.teal800),
                pw.SizedBox(height: 20),
              ],
            );
          },

          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            );
          },

          build: (pw.Context context) {
            return [
              // 1. 도면 정보
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                  border: pw.Border.all(color: PdfColors.teal200, width: 1.5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "PROJECT INFO",
                          style: pw.TextStyle(
                            color: PdfColors.teal700,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          "Project: $project",
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Line: $from  ->  $to",
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "SPECIFICATION",
                          style: pw.TextStyle(
                            color: PdfColors.teal700,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          "Pipe Size: ${currentData['pipe_size']}  |  Fit: $fittingStr",
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Total Cut: $displayTotalCut mm",
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // 🚀 2. 캡처된 3D 튜브 형상 삽입 (존재할 경우)
              if (pdfIsoImage != null) ...[
                pw.Text(
                  "ISO DRAWING",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  height: 250, // 이미지 높이
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white, // PDF 내부에서도 명시적으로 흰색 배경 지정
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Image(
                    pdfIsoImage,
                    fit: pw.BoxFit.contain,
                  ), // 캡처된 이미지 삽입
                ),
                pw.SizedBox(height: 30),
              ],

              // 3. 벤딩 데이터 타이틀
              pw.Text(
                "BENDING SEQUENCE",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.SizedBox(height: 10),

              // 4. 지브라 패턴(얼룩무늬) 표 디자인
              pw.TableHelper.fromTextArray(
                headers: [
                  'Mark No.',
                  'Length (mm)',
                  'Angle',
                  'Direction',
                  'Marking (mm)',
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 11,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.teal700,
                ),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey50,
                ),
                cellHeight: 32,
                cellAlignment: pw.Alignment.center,
                cellStyle: const pw.TextStyle(fontSize: 11),
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
              pw.SizedBox(height: 16),

              // 5. TAIL 정보
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "* Tail Length: ${tail.round()} mm / Start Dir: $startDir",
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final safeProject = project.replaceAll(' ', '_');
      final safeFrom = from.replaceAll(' ', '_');
      final file = File("${output.path}/ISO_${safeProject}_$safeFrom.pdf");
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([
        XFile(file.path),
      ], text: '[$project] $from 배관 튜빙 데이터 리포트입니다.');
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
                        textInputAction: TextInputAction.done,
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
                      // 🚀 캡처를 위해 RepaintBoundary로 감싸줌
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: RepaintBoundary(
                          key: _isoBoundaryKey, // 🚀 글로벌 키 연결
                          child: Container(
                            color:
                                pureWhite, // 🚀 여기서 무조건 순백색(White) 배경을 고정합니다!
                            child: PipeVisualizer(
                              bendList: parsedBendList,
                              tailLength: tail,
                              selectedSegmentIndex: _selectedSegmentIndex,
                              initialStartDir: startDir,
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
                          "MARKING (마킹 지점)",
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
                color: isSelected ? Colors.orange.withOpacity(0.05) : slate100,
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
