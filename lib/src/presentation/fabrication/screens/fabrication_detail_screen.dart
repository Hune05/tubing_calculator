import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:tubing_calculator/src/core/database/database_helper.dart';
import 'package:tubing_calculator/src/data/bend_data_manager.dart';

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

  final TransformationController _viewController = TransformationController();

  final Color makitaTeal = const Color(0xFF007580);
  final Color slate900 = const Color(0xFF0F172A);
  final Color slate600 = const Color(0xFF475569);
  final Color slate100 = const Color(0xFFF1F5F9);
  final Color pureWhite = const Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    currentData = Map<String, dynamic>.from(widget.itemData);
    fittingDepth = BendDataManager().fittingDepth;
    _parsePtoP();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final dx = 1000.0 - (screenWidth * 0.7 / 2);
      final dy = 1000.0 - (screenHeight / 2) + 100;
      _viewController.value = Matrix4.identity()
        ..translate(-dx, -dy)
        ..scale(1.0);
    });
  }

  @override
  void dispose() {
    _viewController.dispose();
    super.dispose();
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
    } catch (e) {
      project = "N/A";
      from = currentData['p_to_p'] ?? "N/A";
      to = "";
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

  String _getFittingStatusText() {
    if (startFit && endFit) return "양쪽 적용 (BOTH)";
    if (startFit) return "시작점만 적용 (START ONLY)";
    if (endFit) return "종료점만 적용 (END ONLY)";
    return "적용 안함 (NONE)";
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
                Text(
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
                  decoration: InputDecoration(
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
                        decoration: InputDecoration(
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
                        decoration: InputDecoration(
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
                      if (!mounted) return;
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
    List<dynamic> bendList = [];
    try {
      bendList = jsonDecode(currentData['bend_data']);
    } catch (e) {
      bendList = [];
    }

    double lastMarkingPoint = 0.0;
    final double absoluteTotalCut =
        double.tryParse(currentData['total_length']?.toString() ?? '0') ?? 0.0;
    final int displayTotalCut = absoluteTotalCut.round();

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
          IconButton(
            icon: const Icon(Icons.edit_note, size: 28),
            onPressed: _editInfo,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 정보 패널
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: pureWhite,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "LINE",
                          style: TextStyle(
                            color: slate600,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$from  ➔  $to",
                          style: TextStyle(
                            color: slate900,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TUBE SIZE",
                            style: TextStyle(
                              color: slate600,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${currentData['pipe_size']}",
                            style: TextStyle(
                              color: makitaTeal,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "FITTING",
                            style: TextStyle(
                              color: slate600,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getFittingStatusText(),
                            style: TextStyle(
                              color: slate900,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
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
            ),

            Expanded(
              child: Row(
                children: [
                  // 🎨 [왼쪽] 3D 형상도 (화가 녀석 수술 완료)
                  Expanded(
                    flex: 7,
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: pureWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: InteractiveViewer(
                          transformationController: _viewController,
                          boundaryMargin: const EdgeInsets.all(3000),
                          minScale: 0.1,
                          maxScale: 5.0,
                          constrained: false,
                          child: Container(
                            width: 2000,
                            height: 2000,
                            color: pureWhite,
                            child: CustomPaint(
                              size: const Size(2000, 2000),
                              painter: DetailedAutoFitIsoPainter(
                                bendList: bendList,
                                tail: tail,
                                startFit: startFit,
                                endFit: endFit,
                                fittingDepth: fittingDepth,
                                makitaTeal: makitaTeal,
                                slate900: slate900,
                                slate600: slate600,
                                pureWhite: pureWhite,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 📝 [오른쪽] 구간 및 마킹 리스트
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
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: bendList.isEmpty
                          ? Center(
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
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "구간 정보",
                                        style: TextStyle(
                                          color: slate600,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "마킹 포인트",
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
                                  child: ListView.separated(
                                    padding: EdgeInsets.zero,
                                    itemCount: bendList.length + 1,
                                    separatorBuilder: (context, index) =>
                                        Divider(
                                          color: Colors.grey.shade200,
                                          height: 1,
                                        ),
                                    itemBuilder: (context, index) {
                                      if (index < bendList.length) {
                                        final bend = bendList[index];
                                        final double rawLength =
                                            (bend['length'] ?? 0).toDouble();
                                        final double rotation =
                                            (bend['rotation'] ?? 0.0)
                                                .toDouble();
                                        final String angle =
                                            bend['angle']?.toString() ?? '0';

                                        lastMarkingPoint =
                                            bend['marking_point'] != null
                                            ? bend['marking_point'].toDouble()
                                            : (lastMarkingPoint + rawLength);
                                        int displayLength = rawLength.round();
                                        int displayMarking = lastMarkingPoint
                                            .round();

                                        return Container(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                4,
                                                              ),
                                                          decoration:
                                                              BoxDecoration(
                                                                color:
                                                                    makitaTeal,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                          child: Text(
                                                            "${index + 1}",
                                                            style: TextStyle(
                                                              color: pureWhite,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Text(
                                                          "MK-${(index + 1).toString().padLeft(2, '0')}",
                                                          style: TextStyle(
                                                            color: slate900,
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          "L: $displayLength mm",
                                                          style: TextStyle(
                                                            color: slate600,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          "${_getDirectionTextShort(rotation)} $angle°",
                                                          style: TextStyle(
                                                            color: makitaTeal,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                "$displayMarking",
                                                style: TextStyle(
                                                  color: slate900,
                                                  fontSize: 24,
                                                  fontFamily: 'monospace',
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      } else {
                                        // 🚀 UI 수정: 기장이 0이라도 마지막 각도가 살아있으면 방향 표기!
                                        int displayTail = tail.round();
                                        String extraInfo = "";
                                        if (displayTail == 0 &&
                                            bendList.isNotEmpty) {
                                          double lastAngle =
                                              (bendList.last['angle'] ?? 0)
                                                  .toDouble();
                                          double lastRot =
                                              (bendList.last['rotation'] ?? 0)
                                                  .toDouble();
                                          if (lastAngle > 0) {
                                            extraInfo =
                                                " (방향: ${_getDirectionTextShort(lastRot)} $lastAngle° 유지)";
                                          }
                                        }

                                        return Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: makitaTeal.withOpacity(0.05),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                4,
                                                              ),
                                                          decoration:
                                                              BoxDecoration(
                                                                color: Colors
                                                                    .red
                                                                    .shade700,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                          child: Text(
                                                            "E",
                                                            style: TextStyle(
                                                              color: pureWhite,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Text(
                                                          "TAIL (END)",
                                                          style: TextStyle(
                                                            color: slate900,
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      "L: $displayTail mm ${endFit ? '(+Fit: ${fittingDepth.round()})' : ''}$extraInfo",
                                                      style: TextStyle(
                                                        color: slate600,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            extraInfo.isNotEmpty
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                "$displayTotalCut",
                                                style: TextStyle(
                                                  color: Colors.red.shade700,
                                                  fontSize: 26,
                                                  fontFamily: 'monospace',
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
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
}

/// ============================================================================
// 🔥 3D 물리엔진 최종 진화: 3D 공간 롤링(회전각) 완벽 계산 탑재
// ============================================================================
class DetailedAutoFitIsoPainter extends CustomPainter {
  final List<dynamic> bendList;
  final double tail;
  final bool startFit;
  final bool endFit;
  final double fittingDepth;
  final Color makitaTeal;
  final Color slate900;
  final Color slate600;
  final Color pureWhite;

  DetailedAutoFitIsoPainter({
    required this.bendList,
    required this.tail,
    required this.startFit,
    required this.endFit,
    required this.fittingDepth,
    required this.makitaTeal,
    required this.slate900,
    required this.slate600,
    required this.pureWhite,
  });

  double _dotProduct(List<double> v1, List<double> v2) =>
      v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2];
  List<double> _normalize(List<double> v) {
    double mag = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    if (mag == 0) return [0, 0, 0];
    return [v[0] / mag, v[1] / mag, v[2] / mag];
  }

  List<double> _getTargetVector(double rot) {
    if (rot == 360.0) return [0, 0, 1];
    if (rot == 450.0) return [0, 0, -1];
    double rad = rot * math.pi / 180.0;
    return [math.sin(rad), -math.cos(rad), 0.0];
  }

  Offset _projectTo2D(List<double> p) {
    const double isoAngle = math.pi / 6;
    double screenX = (p[0] - p[2]) * math.cos(isoAngle);
    double screenY = (p[0] + p[2]) * math.sin(isoAngle) + p[1];
    return Offset(screenX, screenY);
  }

  // 방향 텍스트 헬퍼
  String _getDirName(double rot) {
    if (rot == 0.0) return "UP";
    if (rot == 90.0) return "RIGHT";
    if (rot == 180.0) return "DOWN";
    if (rot == 270.0) return "LEFT";
    if (rot == 360.0) return "FRONT";
    if (rot == 450.0) return "BACK";
    return "${rot.toInt()}°";
  }

  // 🚀 벤더 작업자용 롤링 지시 계산기 (핵심 수술 부위)
  String _getRollingText(double prevRot, double currRot) {
    if (prevRot == currRot) return ""; // 방향 같으면 회전 없음

    // 1. 3D 벡터를 이용해 정확한 회전 각도(이면각) 추출
    List<double> v1 = _getTargetVector(prevRot);
    List<double> v2 = _getTargetVector(currRot);

    double dot = _dotProduct(v1, v2);
    if (dot > 1.0) dot = 1.0;
    if (dot < -1.0) dot = -1.0;
    int angleDeg = (math.acos(dot) * 180 / math.pi).round(); // 두 평면 사이의 절대 각도

    if (angleDeg == 0) return "";
    if (angleDeg == 180) return "↻ 180° 파이프 반전 (뒤집기)";

    // 2. 평면 내부(UP, DOWN, LEFT, RIGHT) 회전은 시계/반시계로 명확하게!
    if (prevRot < 360 && currRot < 360) {
      double diff = currRot - prevRot;
      while (diff > 180) diff -= 360;
      while (diff <= -180) diff += 360;
      if (diff > 0) return "↻ 시계 ${diff.toInt()}° 롤링";
      if (diff < 0) return "↺ 반시계 ${diff.abs().toInt()}° 롤링";
    }

    // 3. FRONT, BACK 등 입체(Z축)로 틀어질 때는 각도와 목표 방향을 함께 제시
    return "⟳ ${angleDeg}° 롤링 ➔ ${_getDirName(currRot)}";
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    var path = Path();
    double dashWidth = 8.0, dashSpace = 6.0, distance = (p2 - p1).distance;
    double dx = (p2.dx - p1.dx) / distance, dy = (p2.dy - p1.dy) / distance;
    double i = 0;
    while (i < distance) {
      path.moveTo(p1.dx + dx * i, p1.dy + dy * i);
      i += dashWidth;
      if (i > distance) i = distance;
      path.lineTo(p1.dx + dx * i, p1.dy + dy * i);
      i += dashSpace;
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (bendList.isEmpty && tail <= 0) return;

    List<List<double>> points3D = [];
    List<double> currPos = [0.0, 0.0, 0.0];
    List<double> currDir = [1.0, 0.0, 0.0];

    List<double>? startFit3D;
    if (startFit && fittingDepth > 0) {
      startFit3D = [
        currPos[0] - currDir[0] * fittingDepth,
        currPos[1] - currDir[1] * fittingDepth,
        currPos[2] - currDir[2] * fittingDepth,
      ];
    }
    points3D.add([...currPos]);

    for (var bend in bendList) {
      double l = (bend['length'] ?? 0).toDouble();
      double a = (bend['angle'] ?? 0).toDouble();
      double rot = (bend['rotation'] ?? 0.0).toDouble();

      if (l > 0) {
        currPos[0] += currDir[0] * l;
        currPos[1] += currDir[1] * l;
        currPos[2] += currDir[2] * l;
      }
      points3D.add([...currPos]);

      if (a > 0) {
        double radA = a * math.pi / 180.0;
        List<double> targetVec = _getTargetVector(rot);
        double dot = _dotProduct(targetVec, currDir);
        List<double> u = _normalize([
          targetVec[0] - dot * currDir[0],
          targetVec[1] - dot * currDir[1],
          targetVec[2] - dot * currDir[2],
        ]);
        if (u[0] != 0 || u[1] != 0 || u[2] != 0) {
          currDir = _normalize([
            currDir[0] * math.cos(radA) + u[0] * math.sin(radA),
            currDir[1] * math.cos(radA) + u[1] * math.sin(radA),
            currDir[2] * math.cos(radA) + u[2] * math.sin(radA),
          ]);
        }
      }
    }

    List<double>? tail3D, endFit3D, phantom3D;
    if (tail > 0) {
      currPos[0] += currDir[0] * tail;
      currPos[1] += currDir[1] * tail;
      currPos[2] += currDir[2] * tail;
      tail3D = [...currPos];
    } else if (bendList.isNotEmpty &&
        (bendList.last['angle'] ?? 0).toDouble() > 0) {
      phantom3D = [
        currPos[0] + currDir[0] * 50.0,
        currPos[1] + currDir[1] * 50.0,
        currPos[2] + currDir[2] * 50.0,
      ];
    }

    if (endFit && fittingDepth > 0) {
      endFit3D = [
        currPos[0] + currDir[0] * fittingDepth,
        currPos[1] + currDir[1] * fittingDepth,
        currPos[2] + currDir[2] * fittingDepth,
      ];
    }

    double minX = double.infinity,
        maxX = -double.infinity,
        minY = double.infinity,
        maxY = -double.infinity;
    void updateBounds(Offset p) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    Offset? startFit2D = startFit3D != null ? _projectTo2D(startFit3D) : null;
    List<Offset> pts2D = points3D.map((p) => _projectTo2D(p)).toList();
    Offset? tail2D = tail3D != null ? _projectTo2D(tail3D) : null;
    Offset? endFit2D = endFit3D != null ? _projectTo2D(endFit3D) : null;
    Offset? phantom2D = phantom3D != null ? _projectTo2D(phantom3D) : null;

    if (startFit2D != null) updateBounds(startFit2D);
    for (var p in pts2D) updateBounds(p);
    if (tail2D != null) updateBounds(tail2D);
    if (endFit2D != null) updateBounds(endFit2D);
    if (phantom2D != null) updateBounds(phantom2D);

    double bWidth = maxX - minX, bHeight = maxY - minY;
    if (bWidth == 0) bWidth = 100;
    if (bHeight == 0) bHeight = 100;
    double drawScale = math
        .min(size.width * 0.7 / bWidth, size.width * 0.7 / bHeight)
        .clamp(0.1, 5.0);
    double centerX = minX + (bWidth / 2), centerY = minY + (bHeight / 2);
    Offset transform(Offset p) => Offset(
      (p.dx - centerX) * drawScale + size.width / 2,
      (p.dy - centerY) * drawScale + size.height / 2,
    );

    List<Offset> finalPts2D = pts2D.map((p) => transform(p)).toList();
    Offset? finalStartFit2D = startFit2D != null ? transform(startFit2D) : null;
    Offset? finalTail2D = tail2D != null ? transform(tail2D) : null;
    Offset? finalEndFit2D = endFit2D != null ? transform(endFit2D) : null;
    Offset? finalPhantom2D = phantom2D != null ? transform(phantom2D) : null;

    final pipePaint = Paint()
      ..color = slate900
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fittingPaint = Paint()
      ..color = makitaTeal.withOpacity(0.6)
      ..strokeWidth = 14.0
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    // ==========================================
    // LAYER 1: 선 먼저 그리기
    // ==========================================
    if (startFit && finalStartFit2D != null)
      canvas.drawLine(finalStartFit2D, finalPts2D[0], fittingPaint);

    for (int i = 0; i < bendList.length; i++) {
      double l = (bendList[i]['length'] ?? 0).toDouble();
      if (l > 0) {
        canvas.drawLine(finalPts2D[i], finalPts2D[i + 1], pipePaint);
        Offset delta = finalPts2D[i + 1] - finalPts2D[i];
        if (delta.distance > 0.1) {
          Offset dir2D = Offset(
            delta.dx / delta.distance,
            delta.dy / delta.distance,
          );
          Offset mid = Offset(
            (finalPts2D[i].dx + finalPts2D[i + 1].dx) / 2,
            (finalPts2D[i].dy + finalPts2D[i + 1].dy) / 2,
          );
          _drawDirectionArrow(canvas, mid, dir2D, makitaTeal);
        }
      }
    }

    Offset lastPt = finalPts2D.last;
    if (tail > 0 && finalTail2D != null) {
      canvas.drawLine(lastPt, finalTail2D, pipePaint);
      Offset delta = finalTail2D - lastPt;
      if (delta.distance > 0.1) {
        Offset mid = Offset(
          (lastPt.dx + finalTail2D.dx) / 2,
          (lastPt.dy + finalTail2D.dy) / 2,
        );
        _drawDirectionArrow(
          canvas,
          mid,
          Offset(delta.dx / delta.distance, delta.dy / delta.distance),
          slate600,
        );
      }
      lastPt = finalTail2D;
    } else if (finalPhantom2D != null) {
      _drawDashedLine(
        canvas,
        lastPt,
        finalPhantom2D,
        makitaTeal.withOpacity(0.5),
      );
      _drawDirectionArrow(
        canvas,
        Offset(
          (lastPt.dx + finalPhantom2D.dx) / 2,
          (lastPt.dy + finalPhantom2D.dy) / 2,
        ),
        finalPhantom2D - lastPt,
        makitaTeal,
      );
    }

    if (endFit && finalEndFit2D != null)
      canvas.drawLine(lastPt, finalEndFit2D, fittingPaint);

    // ==========================================
    // LAYER 2: 길이, 마커, 롤링 텍스트 그리기 (선 위로 올라옴)
    // ==========================================
    for (int i = 0; i < bendList.length; i++) {
      double l = (bendList[i]['length'] ?? 0).toDouble();
      if (l > 0) {
        Offset delta = finalPts2D[i + 1] - finalPts2D[i];
        Offset dir2D = Offset(
          delta.dx / delta.distance,
          delta.dy / delta.distance,
        );
        Offset mid = Offset(
          (finalPts2D[i].dx + finalPts2D[i + 1].dx) / 2,
          (finalPts2D[i].dy + finalPts2D[i + 1].dy) / 2,
        );
        Offset normal = Offset(-dir2D.dy, dir2D.dx);
        if (normal.dy > 0) normal = Offset(-normal.dx, -normal.dy);
        _drawSimpleLength(
          canvas,
          "${l.toInt()}",
          mid + Offset(normal.dx * 20, normal.dy * 20),
          slate600,
        );
      }
    }
    if (tail > 0 && finalTail2D != null) {
      Offset delta = finalTail2D - finalPts2D.last;
      Offset dir2D = Offset(
        delta.dx / delta.distance,
        delta.dy / delta.distance,
      );
      Offset mid = Offset(
        (finalPts2D.last.dx + finalTail2D.dx) / 2,
        (finalPts2D.last.dy + finalTail2D.dy) / 2,
      );
      Offset normal = Offset(-dir2D.dy, dir2D.dx);
      if (normal.dy > 0) normal = Offset(-normal.dx, -normal.dy);
      _drawSimpleLength(
        canvas,
        "${tail.toInt()}",
        mid + Offset(normal.dx * 20, normal.dy * 20),
        slate600,
      );
    }

    if (startFit && finalStartFit2D != null)
      _drawNodeBadge(canvas, "S", finalStartFit2D, slate900, pureWhite);
    else
      _drawNodeBadge(canvas, "S", finalPts2D[0], slate900, pureWhite);

    for (int i = 0; i < bendList.length; i++) {
      Offset nodePos = finalPts2D[i + 1];
      _drawNodeBadge(canvas, "${i + 1}", nodePos, makitaTeal, pureWhite);

      // 💡 여기서 FRONT, BACK 롤링 계산 결과가 표시됩니다!
      if (i == 0) {
        _drawRollingBadge(
          canvas,
          "[기준 평면]",
          nodePos + const Offset(15, -25),
          slate600,
        );
      } else {
        double prevRot = bendList[i - 1]['rotation'] ?? 0.0;
        double currRot = bendList[i]['rotation'] ?? 0.0;
        String rollText = _getRollingText(prevRot, currRot);
        if (rollText.isNotEmpty) {
          _drawRollingBadge(
            canvas,
            rollText,
            nodePos + const Offset(20, -25),
            Colors.orange.shade800,
          );
        }
      }
    }

    if (endFit && finalEndFit2D != null)
      _drawNodeBadge(
        canvas,
        "E",
        finalEndFit2D,
        Colors.red.shade700,
        pureWhite,
      );
    else
      _drawNodeBadge(canvas, "E", lastPt, Colors.red.shade700, pureWhite);
  }

  void _drawDirectionArrow(
    Canvas canvas,
    Offset center,
    Offset direction,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final double arrowLength = 16.0, arrowWidth = 10.0;
    final angle = math.atan2(direction.dy, direction.dx);
    final tip =
        center +
        Offset(
          math.cos(angle) * (arrowLength * 0.5),
          math.sin(angle) * (arrowLength * 0.5),
        );
    final back =
        center -
        Offset(
          math.cos(angle) * (arrowLength * 0.5),
          math.sin(angle) * (arrowLength * 0.5),
        );
    final p2 =
        back +
        Offset(
          math.cos(angle + math.pi / 2) * arrowWidth,
          math.sin(angle + math.pi / 2) * arrowWidth,
        );
    final p3 =
        back +
        Offset(
          math.cos(angle - math.pi / 2) * arrowWidth,
          math.sin(angle - math.pi / 2) * arrowWidth,
        );
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close(),
      paint,
    );
  }

  void _drawSimpleLength(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          backgroundColor: pureWhite.withOpacity(0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _drawNodeBadge(
    Canvas canvas,
    String text,
    Offset center,
    Color bgColor,
    Color textColor,
  ) {
    canvas.drawCircle(center, 14, Paint()..color = pureWhite);
    canvas.drawCircle(center, 11, Paint()..color = bgColor);
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _drawRollingBadge(
    Canvas canvas,
    String text,
    Offset center,
    Color textColor,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          backgroundColor: pureWhite.withOpacity(0.9),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    )..layout();
    textPainter.paint(canvas, center);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
