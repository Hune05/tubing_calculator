import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:tubing_calculator/src/core/database/database_helper.dart';
import 'package:tubing_calculator/src/data/bend_data_manager.dart';

// 💡 색상 상수 정의 (invalid_constant 에러 해결)
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

  // 🚀 기본 아이소메트릭 각도
  static const double _defaultRotX = math.pi / 6;
  static const double _defaultRotY = math.pi / 4;

  late double _rotationX;
  late double _rotationY;

  // 회전 제한(Clamp)
  final double _minRotX = _defaultRotX - 0.7;
  final double _maxRotX = _defaultRotX + 0.7;
  final double _minRotY = _defaultRotY - 1.2;
  final double _maxRotY = _defaultRotY + 1.2;

  double _zoomLevel = 1.0;
  double _baseZoom = 1.0;

  // 🚀 하이라이트 기능을 위한 인덱스 변수
  int? _selectedSegmentIndex;

  @override
  void initState() {
    super.initState();
    currentData = Map<String, dynamic>.from(widget.itemData);
    fittingDepth = BendDataManager().fittingDepth;

    _rotationX = _defaultRotX;
    _rotationY = _defaultRotY;

    _parsePtoP();
  }

  void _resetView() {
    setState(() {
      _rotationX = _defaultRotX;
      _rotationY = _defaultRotY;
      _zoomLevel = 1.0;
      _selectedSegmentIndex = null; // 원점 복귀 시 하이라이트 선택 해제
    });
  }

  void _zoomIn() =>
      setState(() => _zoomLevel = (_zoomLevel + 0.2).clamp(0.5, 5.0));
  void _zoomOut() =>
      setState(() => _zoomLevel = (_zoomLevel - 0.2).clamp(0.5, 5.0));

  void _onScaleStart(ScaleStartDetails details) => _baseZoom = _zoomLevel;

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // 1손가락 = 회전, 2손가락 = 줌
      if (details.scale == 1.0) {
        _rotationY -= details.focalPointDelta.dx * 0.008;
        _rotationX -= details.focalPointDelta.dy * 0.008;
        _rotationX = _rotationX.clamp(_minRotX, _maxRotX);
        _rotationY = _rotationY.clamp(_minRotY, _maxRotY);
      } else {
        _zoomLevel = (_baseZoom * details.scale).clamp(0.5, 5.0);
      }
    });
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

  // 💡 [복구 완료] 수정 팝업 기능 전체 포함
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
            // 1. 상단 정보 헤더
            Container(
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
                    flex: 2,
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
                          "$from  ➔  $to",
                          style: const TextStyle(
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
                          const Text(
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
                            style: const TextStyle(
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
                          const Text(
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
                            style: const TextStyle(
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
            ),

            Expanded(
              child: Row(
                children: [
                  // 2. 3D 아이솔 뷰어 패널
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
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return GestureDetector(
                                  onScaleStart: _onScaleStart,
                                  onScaleUpdate: _onScaleUpdate,
                                  onDoubleTap: _resetView,
                                  child: Container(
                                    color: Colors.transparent,
                                    child: CustomPaint(
                                      size: Size(
                                        constraints.maxWidth,
                                        constraints.maxHeight,
                                      ),
                                      painter: DetailedAutoFitIsoPainter(
                                        bendList: bendList,
                                        tail: tail,
                                        startFit: startFit,
                                        endFit: endFit,
                                        fittingDepth: fittingDepth,
                                        rotationX: _rotationX,
                                        rotationY: _rotationY,
                                        zoomLevel: _zoomLevel,
                                        selectedSegmentIndex:
                                            _selectedSegmentIndex, // 🚀 터치한 구간 번호 전달
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: slate900.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.touch_app,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      "화면을 드래그하여 3D 회전",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FloatingActionButton(
                                    mini: true,
                                    heroTag: "btn_dt_zoom_in",
                                    backgroundColor: makitaTeal,
                                    elevation: 2,
                                    onPressed: _zoomIn,
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FloatingActionButton(
                                    mini: true,
                                    heroTag: "btn_dt_zoom_out",
                                    backgroundColor: makitaTeal,
                                    elevation: 2,
                                    onPressed: _zoomOut,
                                    child: const Icon(
                                      Icons.remove,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FloatingActionButton.extended(
                                    heroTag: "reset_dt_view_btn",
                                    backgroundColor: makitaTeal,
                                    elevation: 4,
                                    onPressed: _resetView,
                                    icon: const Icon(
                                      Icons.home,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    label: const Text(
                                      "원점",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. 우측 마킹 포인트 리스트
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
                      child: bendList.isEmpty
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
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: bendList.length + 1,
                                    itemBuilder: (context, index) {
                                      bool isSelected =
                                          _selectedSegmentIndex == index;

                                      if (index < bendList.length) {
                                        final bend = bendList[index];
                                        final double rawLength =
                                            (bend['length'] ?? 0).toDouble();
                                        final double rotation =
                                            (bend['rotation'] ?? 0.0)
                                                .toDouble();
                                        final String angle =
                                            bend['angle']?.toString() ?? '0';

                                        if (index == 0) {
                                          lastMarkingPoint =
                                              bend['marking_point'] != null
                                              ? bend['marking_point'].toDouble()
                                              : rawLength;
                                        } else {
                                          lastMarkingPoint =
                                              bend['marking_point'] != null
                                              ? bend['marking_point'].toDouble()
                                              : (lastMarkingPoint + rawLength);
                                        }
                                        int displayLength = rawLength.round();
                                        int displayMarking = lastMarkingPoint
                                            .round();

                                        return GestureDetector(
                                          onTap: () => setState(
                                            () => _selectedSegmentIndex =
                                                isSelected ? null : index,
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.orange.withValues(
                                                      alpha: 0.15,
                                                    )
                                                  : Colors
                                                        .transparent, // 🚀 터치 시 배경색 하이라이트
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey.shade200,
                                                ),
                                              ),
                                            ),
                                            padding: const EdgeInsets.all(16),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  4,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: isSelected
                                                                  ? Colors
                                                                        .orange
                                                                        .shade700
                                                                  : makitaTeal,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                            child: Text(
                                                              "${index + 1}",
                                                              style: const TextStyle(
                                                                color:
                                                                    pureWhite,
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
                                                            style:
                                                                const TextStyle(
                                                                  color:
                                                                      slate900,
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Text(
                                                            "L: $displayLength mm",
                                                            style:
                                                                const TextStyle(
                                                                  color:
                                                                      slate600,
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            "${_getDirectionTextShort(rotation)} $angle°",
                                                            style: TextStyle(
                                                              color: isSelected
                                                                  ? Colors
                                                                        .orange
                                                                        .shade800
                                                                  : makitaTeal,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Text(
                                                  "$displayMarking",
                                                  style: const TextStyle(
                                                    color: slate900,
                                                    fontSize: 24,
                                                    fontFamily: 'monospace',
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      } else {
                                        // TAIL (꼬리) 영역
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
                                          if (lastAngle > 0)
                                            extraInfo =
                                                " (방향: ${_getDirectionTextShort(lastRot)} $lastAngle° 유지)";
                                        }

                                        return GestureDetector(
                                          onTap: () => setState(
                                            () => _selectedSegmentIndex =
                                                isSelected ? null : index,
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.orange.withValues(
                                                      alpha: 0.15,
                                                    )
                                                  : makitaTeal.withValues(
                                                      alpha: 0.05,
                                                    ),
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey.shade200,
                                                ),
                                              ),
                                            ),
                                            padding: const EdgeInsets.all(16),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
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
                                                            child: const Text(
                                                              "E",
                                                              style: TextStyle(
                                                                color:
                                                                    pureWhite,
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
                                                          const Text(
                                                            "TAIL (END)",
                                                            style: TextStyle(
                                                              color: slate900,
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
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
                                                              extraInfo
                                                                  .isNotEmpty
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                    .normal,
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
// 🔥 3D 물리엔진: 하이브리드 자동 계산 + 하이라이트 기능 (에러 완전 정복)
/// ============================================================================
class DetailedAutoFitIsoPainter extends CustomPainter {
  final List<dynamic> bendList;
  final double tail;
  final bool startFit;
  final bool endFit;
  final double fittingDepth;
  final double rotationX;
  final double rotationY;
  final double zoomLevel;
  final int? selectedSegmentIndex; // 🚀 터치한 인덱스

  DetailedAutoFitIsoPainter({
    required this.bendList,
    required this.tail,
    required this.startFit,
    required this.endFit,
    required this.fittingDepth,
    required this.rotationX,
    required this.rotationY,
    required this.zoomLevel,
    this.selectedSegmentIndex,
  });

  double _dotProduct(List<double> v1, List<double> v2) =>
      v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2];

  List<double> _normalize(List<double> v) {
    double mag = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    if (mag == 0) return [0, 0, 0];
    return [v[0] / mag, v[1] / mag, v[2] / mag];
  }

  List<double> _getTargetVector(double rot) {
    if (rot == 360) return [0, 0, 1];
    if (rot == 450) return [0, 0, -1];
    double rad = rot * math.pi / 180.0;
    return [math.sin(rad), -math.cos(rad), 0.0];
  }

  List<double> _rotate3D(List<double> point, double rx, double ry) {
    double x = point[0], y = point[1], z = point[2];
    double tx = x * math.cos(ry) + z * math.sin(ry);
    double tz = -x * math.sin(ry) + z * math.cos(ry);
    double ty = y * math.cos(rx) - tz * math.sin(rx);
    z = y * math.sin(rx) + tz * math.cos(rx);
    return [tx, ty, z];
  }

  String _getDirName(double rot) {
    if (rot == 0.0) return "UP";
    if (rot == 90.0) return "RIGHT";
    if (rot == 180.0) return "DOWN";
    if (rot == 270.0) return "LEFT";
    if (rot == 360.0) return "FRONT";
    if (rot == 450.0) return "BACK";
    return "${rot.toInt()}°";
  }

  String _getRollingText(double prevRot, double currRot) {
    if (prevRot == currRot) return "";
    List<double> v1 = _getTargetVector(prevRot);
    List<double> v2 = _getTargetVector(currRot);
    double dot = _dotProduct(v1, v2);
    if (dot > 1.0) dot = 1.0;
    if (dot < -1.0) dot = -1.0;
    int angleDeg = (math.acos(dot) * 180 / math.pi).round();

    if (angleDeg == 0) return "";
    if (angleDeg == 180) return "↻ 180° 파이프 반전 (뒤집기)";

    if (prevRot < 360 && currRot < 360) {
      double diff = currRot - prevRot;
      while (diff > 180) {
        diff -= 360;
      }
      while (diff <= -180) {
        diff += 360;
      }
      if (diff > 0) return "↻ 시계 ${diff.toInt()}° 롤링";
      if (diff < 0) return "↺ 반시계 ${diff.abs().toInt()}° 롤링";
    }
    return "⟳ $angleDeg° 롤링 ➔ ${_getDirName(currRot)}";
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (bendList.isEmpty && tail <= 0) return;

    // 1. 3D 좌표 및 방향 추출 (스마트 벤딩 로직)
    List<List<double>> pts3D = [];
    List<double> curP = [0, 0, 0];
    List<double> curD = [1, 0, 0];
    List<List<double>> segDirs = [];

    pts3D.add([...curP]);

    for (var bend in bendList) {
      double l = (bend['length'] ?? 0).toDouble();
      double a = (bend['angle'] ?? 0).toDouble();
      double? rot = bend['rotation']?.toDouble();

      if (a == 0 && rot != null) curD = _getTargetVector(rot);
      segDirs.add([...curD]);

      if (l > 0) {
        curP = [
          curP[0] + curD[0] * l,
          curP[1] + curD[1] * l,
          curP[2] + curD[2] * l,
        ];
      }
      pts3D.add([...curP]);

      if (a > 0 && rot != null) {
        double radA = a * math.pi / 180.0;
        List<double> tVec = _getTargetVector(rot);
        double dot = _dotProduct(tVec, curD);
        List<double> u = _normalize([
          tVec[0] - dot * curD[0],
          tVec[1] - dot * curD[1],
          tVec[2] - dot * curD[2],
        ]);
        if (u[0] != 0 || u[1] != 0 || u[2] != 0) {
          curD = _normalize([
            curD[0] * math.cos(radA) + u[0] * math.sin(radA),
            curD[1] * math.cos(radA) + u[1] * math.sin(radA),
            curD[2] * math.cos(radA) + u[2] * math.sin(radA),
          ]);
        }
      }
    }

    segDirs.add([...curD]);
    if (tail > 0) {
      curP = [
        curP[0] + curD[0] * tail,
        curP[1] + curD[1] * tail,
        curP[2] + curD[2] * tail,
      ];
      pts3D.add([...curP]);
    }

    // 2. 2D 화면 투영 및 자동 스케일 맞춤
    double minX = double.infinity,
        maxX = -double.infinity,
        minY = double.infinity,
        maxY = -double.infinity;
    List<Offset> pts2D = pts3D.map((p) {
      List<double> rp = _rotate3D(p, rotationX, rotationY);
      if (rp[0] < minX) minX = rp[0];
      if (rp[0] > maxX) maxX = rp[0];
      if (rp[1] < minY) minY = rp[1];
      if (rp[1] > maxY) maxY = rp[1];
      return Offset(rp[0], rp[1]);
    }).toList();

    double bW = maxX - minX == 0 ? 100 : maxX - minX;
    double bH = maxY - minY == 0 ? 100 : maxY - minY;
    double scale =
        math
            .min(size.width * 0.6 / bW, size.height * 0.6 / bH)
            .clamp(0.1, 5.0) *
        zoomLevel;

    Offset tr(Offset p) => Offset(
      (p.dx - (minX + maxX) / 2) * scale + size.width / 2,
      (p.dy - (minY + maxY) / 2) * scale + size.height / 2,
    );
    List<Offset> fPts = pts2D.map((p) => tr(p)).toList();

    // 그리기 페인트 설정
    final pPaint = Paint()
      ..color = slate900
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final hPaint = Paint()
      ..color = Colors.orange.shade500
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 🚀 [기능 2] 롤링 가이드 (Ghost Line)
    if (selectedSegmentIndex != null &&
        selectedSegmentIndex! > 0 &&
        selectedSegmentIndex! < bendList.length) {
      Offset startNode = fPts[selectedSegmentIndex!];
      List<double> prevDir = segDirs[selectedSegmentIndex! - 1];
      List<double> start3D = pts3D[selectedSegmentIndex!];
      List<double> ghost3D = [
        start3D[0] + prevDir[0] * 50,
        start3D[1] + prevDir[1] * 50,
        start3D[2] + prevDir[2] * 50,
      ];
      Offset ghostEnd = tr(
        Offset(
          _rotate3D(ghost3D, rotationX, rotationY)[0],
          _rotate3D(ghost3D, rotationX, rotationY)[1],
        ),
      );

      var dPaint = Paint()
        ..color = Colors.grey
        ..strokeWidth = 2;
      double dist = (ghostEnd - startNode).distance;
      for (double i = 0; i < dist; i += 8) {
        if (dist == 0) break;
        canvas.drawLine(
          startNode + (ghostEnd - startNode) * (i / dist),
          startNode + (ghostEnd - startNode) * ((i + 4) / dist),
          dPaint,
        );
      }
    }

    // 3. 파이프 라인 그리기 (하이라이트 적용)
    for (int i = 0; i < fPts.length - 1; i++) {
      bool isSelected = selectedSegmentIndex == i;
      canvas.drawLine(fPts[i], fPts[i + 1], isSelected ? hPaint : pPaint);

      // 🚀 [기능 1 & 3] 진입 화살표 & 치수 텍스트 표시
      double len = 0;
      if (i < bendList.length)
        len = (bendList[i]['length'] ?? 0).toDouble();
      else if (i == bendList.length && tail > 0)
        len = tail;

      if (len > 0) {
        Offset delta = fPts[i + 1] - fPts[i];
        if (delta.distance > 0.1) {
          Offset dir2D = Offset(
            delta.dx / delta.distance,
            delta.dy / delta.distance,
          );
          Offset mid = (fPts[i] + fPts[i + 1]) / 2;

          // 화살표 강조
          double aLen = isSelected ? 24.0 : 14.0;
          double aWid = isSelected ? 16.0 : 10.0;
          var aPaint = Paint()
            ..color = isSelected ? Colors.orange.shade900 : makitaTeal
            ..style = PaintingStyle.fill;
          double ang = math.atan2(dir2D.dy, dir2D.dx);
          Offset tip =
              mid +
              Offset(math.cos(ang) * (aLen / 2), math.sin(ang) * (aLen / 2));
          Offset bck =
              mid -
              Offset(math.cos(ang) * (aLen / 2), math.sin(ang) * (aLen / 2));
          Offset p2 =
              bck +
              Offset(
                math.cos(ang + math.pi / 2) * aWid,
                math.sin(ang + math.pi / 2) * aWid,
              );
          Offset p3 =
              bck +
              Offset(
                math.cos(ang - math.pi / 2) * aWid,
                math.sin(ang - math.pi / 2) * aWid,
              );
          canvas.drawPath(
            Path()
              ..moveTo(tip.dx, tip.dy)
              ..lineTo(p2.dx, p2.dy)
              ..lineTo(p3.dx, p3.dy)
              ..close(),
            aPaint,
          );

          // 치수 텍스트 강조
          Offset norm = Offset(-dir2D.dy, dir2D.dx);
          if (norm.dy > 0) norm = Offset(-norm.dx, -norm.dy);
          var textSpan = TextSpan(
            text: "${len.round()}",
            style: TextStyle(
              color: isSelected ? Colors.orange.shade900 : slate600,
              fontSize: isSelected ? 22 : 14,
              fontWeight: FontWeight.bold,
              backgroundColor: isSelected
                  ? Colors.orange.shade50
                  : pureWhite.withValues(alpha: 0.8),
            ),
          );
          var textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(
            canvas,
            mid +
                norm * (isSelected ? 30 : 20) -
                Offset(textPainter.width / 2, textPainter.height / 2),
          );
        }
      }
    }

    // 4. 노드 배지 및 롤링 텍스트 그리기
    for (int i = 0; i < fPts.length; i++) {
      if (i == 0) {
        _drawNodeBadge(canvas, "S", fPts[i], slate900, pureWhite);
      } else if (i <= bendList.length) {
        _drawNodeBadge(canvas, "$i", fPts[i], makitaTeal, pureWhite);
        if (i == 1) {
          _drawRollingBadge(
            canvas,
            "[기준 평면]",
            fPts[i] + const Offset(15, -25),
            slate600,
          );
        } else {
          double pRot = (bendList[i - 2]['rotation'] ?? 0.0).toDouble();
          double cRot = (bendList[i - 1]['rotation'] ?? 0.0).toDouble();
          String rollText = _getRollingText(pRot, cRot);
          if (rollText.isNotEmpty) {
            _drawRollingBadge(
              canvas,
              rollText,
              fPts[i] + const Offset(20, -25),
              Colors.orange.shade800,
            );
          }
        }
      } else if (i == fPts.length - 1) {
        _drawNodeBadge(canvas, "E", fPts[i], Colors.red.shade700, pureWhite);
      }
    }
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
          backgroundColor: pureWhite.withValues(alpha: 0.9),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    )..layout();
    textPainter.paint(canvas, center);
  }

  @override
  bool shouldRepaint(covariant DetailedAutoFitIsoPainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.selectedSegmentIndex != selectedSegmentIndex;
  }
}
