import 'package:flutter/material.dart';

import '../../../core/engine/bend_geometry.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;

import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/opposite_rotation.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileOffsetBottomSheet extends StatefulWidget {
  final double currentRotation;
  final Function(List<Map<String, double>> bends) onAddMultipleBends;

  /// 어느 계산기에서 열었는지에 따른 장비 값. 없으면 튜브 제원을 읽는다.
  final BendSheetSpecs? specs;

  const MobileOffsetBottomSheet({
    super.key,
    required this.currentRotation,
    required this.onAddMultipleBends,
    this.specs,
  });

  static void show(
    BuildContext context, {
    required double currentRotation,
    required Function(List<Map<String, double>>) onAddMultipleBends,
    BendSheetSpecs? specs,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MobileOffsetBottomSheet(
        currentRotation: currentRotation,
        onAddMultipleBends: onAddMultipleBends,
        specs: specs,
      ),
    );
  }

  @override
  State<MobileOffsetBottomSheet> createState() =>
      _MobileOffsetBottomSheetState();
}

class _MobileOffsetBottomSheetState extends State<MobileOffsetBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isInverted = false;
  double? _selectedRotation;

  double _machineRadius = 0.0;
  double _machineGain = 0.0;

  // 🚀 장비 최소 물림 길이 및 경고 스위치 상태 변수 추가
  double _minStraight = 0.0;
  bool _warnShoeInterference = true;

  // 어느 계산기에서 열었는지에 따른 장비 값 한 벌. 읽기 전에는 튜브처럼 셈한다.
  BendSheetSpecs? _specs;

  /// 첫 구간 길이. 마킹 화면이 도로 뺄 거리(튜브는 셋백, 전선관은 테이크업)를
  /// 더해야 1번 마킹이 "시작 거리 + 더할 축소값" 자리에 온다.
  /// 목록에 82.34100216…처럼 길게 찍히지 않게 0.1mm로 자른다.
  double _firstLength(double startDistance, double angle, double shrink) {
    final double raw =
        _specs?.firstLength(startDistance, angle, shrink) ??
        (startDistance + bendSetback(_machineRadius, angle));
    return double.parse(raw.toStringAsFixed(1));
  }

  /// 1번 마킹에 더할 축소값(전선관은 설정 스위치, 튜브는 설정의 여유).
  double _shrinkToAdd(double geometricShrink) =>
      _specs?.shrinkToAdd(geometricShrink) ?? 0.0;

  /// 넣고 나서 알려 줄 말.
  String _addedMessage(double startDistance, double shrink) {
    final double add = _shrinkToAdd(shrink);
    final double mark = startDistance + add;
    if (mark <= 0) {
      return "넣었습니다. 축소값 ${shrink.toStringAsFixed(1)}mm는 직진 거리가 줄어드는 몫입니다.";
    }
    if (add > 0) {
      return "1번 마킹이 ${mark.toStringAsFixed(0)}mm 자리에 찍힙니다"
          "(시작 거리 ${startDistance.toStringAsFixed(0)} + 축소값 ${add.toStringAsFixed(1)}).";
    }
    return "1번 마킹이 ${mark.toStringAsFixed(0)}mm 자리에 찍힙니다. "
        "축소값 ${shrink.toStringAsFixed(1)}mm는 직진 거리가 줄어드는 몫입니다.";
  }

  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _angleCtrl = TextEditingController();
  final TextEditingController _travelCtrl = TextEditingController();

  // 장애물까지의 시작 거리를 입력받는 컨트롤러
  final TextEditingController _startDistanceCtrl = TextEditingController(
    text: "0",
  );

  final List<Map<String, dynamic>> _directions = [
    {"label": "UP (위)", "val": 0.0, "icon": Icons.arrow_upward},
    {"label": "FRONT (앞)", "val": 360.0, "icon": Icons.call_made},
    {"label": "LEFT (좌)", "val": 270.0, "icon": Icons.arrow_back},
    {"label": "RIGHT (우)", "val": 90.0, "icon": Icons.arrow_forward},
    {"label": "DOWN (아래)", "val": 180.0, "icon": Icons.arrow_downward},
    {"label": "BACK (뒤)", "val": 450.0, "icon": Icons.call_received},
  ];

  String _formatNum(double val) {
    return val % 1 == 0 ? val.toInt().toString() : val.toString();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final dm = MobileBendDataManager();
    _heightCtrl.text = _formatNum(dm.offsetHeight);
    _angleCtrl.text = _formatNum(dm.offsetAngle);
    _travelCtrl.text = _formatNum(dm.offsetTravel);

    _heightCtrl.addListener(() {
      dm.offsetHeight = double.tryParse(_heightCtrl.text) ?? 0.0;
      setState(() {});
    });
    _angleCtrl.addListener(() {
      dm.offsetAngle = double.tryParse(_angleCtrl.text) ?? 0.0;
      setState(() {});
    });
    _travelCtrl.addListener(() {
      dm.offsetTravel = double.tryParse(_travelCtrl.text) ?? 0.0;
      setState(() {});
    });
    _startDistanceCtrl.addListener(() => setState(() {}));

    _loadMachineSettings();
  }

  Future<void> _loadMachineSettings() async {
    // 🚀 [고침] 어느 계산기에서 열었든 튜브 제원을 읽고 있었다. 넘겨받은
    // 한 벌(전선관이면 CLR·테이크업·게인)을 쓰고, 없으면 튜브 제원을 읽는다.
    final specs = widget.specs ?? await BendSheetSpecs.tube();
    if (mounted) {
      setState(() {
        _specs = specs;
        _machineRadius = specs.radius;
        _machineGain = specs.gain90;
        _minStraight = specs.minStraight;
        _warnShoeInterference = specs.warnShoeInterference;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _heightCtrl.dispose();
    _angleCtrl.dispose();
    _travelCtrl.dispose();
    _startDistanceCtrl.dispose();
    super.dispose();
  }

  void _adjustValue(TextEditingController ctrl, double amount) {
    double current = double.tryParse(ctrl.text) ?? 0;
    double next = current + amount;
    if (next < 0) next = 0;
    ctrl.text = next.toStringAsFixed(next % 1 == 0 ? 0 : 1);
  }

  // 🚀 실제로 리스트에 꽂아 넣는 기능을 밖으로 뺐습니다.
  void _executeAdd(
    double angle,
    double travel,
    double shrink,
    double startDistance,
  ) {
    // 1번 마킹이 "시작 거리 + 더할 축소값" 자리에 오도록 한다.
    final double firstLen = _firstLength(startDistance, angle, shrink);
    // 앞(360)·뒤(450)는 +180을 하면 아래·좌가 되므로 짝을 따로 짓는다.
    final (double r1, double r2) = offsetRotations(
      _selectedRotation!,
      inverted: _isInverted,
    );

    widget.onAddMultipleBends([
      {'length': firstLen, 'angle': angle, 'rotation': r1},
      {'length': travel, 'angle': angle, 'rotation': r2},
    ]);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_addedMessage(startDistance, shrink)),
        backgroundColor: makitaTeal,
      ),
    );

    Navigator.pop(context);
  }

  // 🚀 핵심 로직: 1번 마킹과 2번 마킹 검사 후 실행
  void _applyBending(double angle, double travel, double shrink) {
    if (_selectedRotation == null) {
      // 💡 모바일에서 가려지는 SnackBar 대신 확실한 중앙 팝업으로 변경!
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
              SizedBox(width: 8),
              Text(
                "경고",
                style: TextStyle(fontWeight: FontWeight.bold, color: slate900),
              ),
            ],
          ),
          content: const Text(
            "돌출 방향(Direction)을 먼저 선택해 주십시오!",
            style: TextStyle(color: slate900, fontSize: 15),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("확인", style: TextStyle(color: pureWhite)),
            ),
          ],
        ),
      );
      return;
    }
    if (angle <= 0 || travel <= 0) return;

    double roundedAngle = double.parse(angle.toStringAsFixed(1));
    double roundedTravel = double.parse(travel.toStringAsFixed(1));
    double roundedShrink = double.parse(shrink.toStringAsFixed(1));

    double startDistance = double.tryParse(_startDistanceCtrl.text) ?? 0.0;
    // 🚀 [고침] 예전에는 축소값을 더해서, 반경과 높이가 우연히 같을 때만
    // "시작 거리 = 1번 마킹"이 맞았다(3/8" 튜브 R38에 높이 100이면 26mm 늦게
    // 시작했다). 마킹 화면이 도로 뺄 거리를 더하면 1번 마킹이 정확히 맞는다.
    double firstSegmentLength = _firstLength(
      startDistance,
      roundedAngle,
      roundedShrink,
    );
    double secondSegmentLength = roundedTravel;

    // 🚀 [추가] 슈 간섭 경고 (Soft Warning)
    // 설정 스위치가 켜져있고 && 1구간이나 2구간이 최소물림길이보다 짧을 때 발동
    if (_warnShoeInterference &&
        ((firstSegmentLength < _minStraight && firstSegmentLength > 0) ||
            secondSegmentLength < _minStraight)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              const Text(
                "슈 간섭 경고",
                style: TextStyle(fontWeight: FontWeight.bold, color: slate900),
              ),
            ],
          ),
          content: Text(
            "현재 설정된 장비의 최소 물림 길이는 ${_minStraight}mm 입니다.\n\n"
            "• 1구간(시작~1번): ${firstSegmentLength.toStringAsFixed(1)}mm\n"
            "• 2구간(빗변): ${secondSegmentLength.toStringAsFixed(1)}mm\n\n"
            "길이가 너무 짧아 벤더기에 물리지 않을 수 있습니다. 그래도 강제로 추가하시겠습니까?",
            style: const TextStyle(color: slate900, fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "취소 (다시 입력)",
                style: TextStyle(color: slate600, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _executeAdd(
                  roundedAngle,
                  roundedTravel,
                  roundedShrink,
                  startDistance,
                ); // 🚀 고인물 강제 집어넣기
              },
              child: const Text(
                "무시하고 추가",
                style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // 정상이면 바로 실행
    _executeAdd(roundedAngle, roundedTravel, roundedShrink, startDistance);
  }

  Widget _buildDirectionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "돌출 방향 지정 (6축)",
              style: TextStyle(
                color: _selectedRotation == null ? Colors.redAccent : slate600,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_selectedRotation == null)
              const Text(
                " *필수",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _directions.length,
          itemBuilder: (context, index) {
            final dir = _directions[index];
            bool isSelected = _selectedRotation == dir['val'];
            return InkWell(
              onTap: () => setState(() => _selectedRotation = dir['val']),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? makitaTeal : slate100,
                  border: Border.all(
                    color: isSelected ? makitaTeal : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      dir['icon'],
                      size: 16,
                      color: isSelected ? pureWhite : slate600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dir['label'].split(' ')[0],
                      style: TextStyle(
                        color: isSelected ? pureWhite : slate900,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    double h = double.tryParse(_heightCtrl.text) ?? 0;
    double a = double.tryParse(_angleCtrl.text) ?? 0;
    double t = double.tryParse(_travelCtrl.text) ?? 0;

    double calcTravel = (a > 0 && a < 90)
        ? h / math.sin(a * math.pi / 180.0)
        : 0;
    double calcAngle = 0;
    bool inverseError = false;

    if (t > 0 && h > 0) {
      if (h > t) {
        inverseError = true;
      } else {
        calcAngle = math.asin(h / t) * 180.0 / math.pi;
      }
    }

    double targetAngle = _tabController.index == 0 ? a : calcAngle;
    double targetTravel = _tabController.index == 0 ? calcTravel : t;

    double calcRun = 0.0;
    double geometricShrink = 0.0;
    double totalGain = 0.0;

    if (targetAngle > 0 && targetAngle < 90 && h > 0 && targetTravel > 0) {
      double rad = targetAngle * math.pi / 180.0;

      calcRun = h / math.tan(rad);
      geometricShrink = targetTravel - calcRun;

      // 🚀 [버그 수정] 반경 기반 이론 게인이 사용자가 실측해서 입력한
      // "실측 연신율"보다 먼저 적용되고 있었다. 메인 마킹 엔진
      // (tube_bending_engine.dart)은 반대로 실측값을 항상 우선하는데,
      // 여기서는 반경까지 입력된 경우(거의 항상) 힘들게 현장에서 실측한
      // 값이 조용히 무시되고 있었다. 우선순위를 엔진과 동일하게 맞춘다.
      // 🚀 [고침] 실측 게인을 각도에 비례로 환산하던 것을 기하 비율로 바꿨다
      // (45°에서 벤드당 16mm 어긋났다). 공용 기하 함수 한 곳만 쓴다.
      final double gainPerBend = effectiveGain(
        radius: _machineRadius,
        angleDeg: targetAngle,
        measuredGain90: _machineGain,
      );
      totalGain = gainPerBend * 2;
    }
    // 1번 마킹에 더할 축소값(전선관 스위치·튜브 여유). 0이면 시작 거리 그대로.
    final double shrinkToAdd = _shrinkToAdd(geometricShrink);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.calculator, color: makitaTeal, size: 28),
                      SizedBox(width: 12),
                      Text(
                        "오프셋 계산기",
                        style: TextStyle(
                          color: slate900,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: slate600),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 장애물까지의 시작 거리 입력 박스
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "장애물 앞 시작 거리 (옵션)",
                            style: TextStyle(
                              color: slate900,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            shrinkToAdd > 0
                                ? "1번 마킹은 이 거리에 축소값 ${shrinkToAdd.toStringAsFixed(1)}mm를 더한 자리에 찍힙니다."
                                : "1번 마킹이 이 거리에 찍힙니다.",
                            style: const TextStyle(
                              color: slate600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: _buildTextField(_startDistanceCtrl, "거리 mm"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TabBar(
                controller: _tabController,
                indicatorColor: makitaTeal,
                labelColor: makitaTeal,
                unselectedLabelColor: slate600,
                tabs: const [
                  Tab(text: "정방향 (H+∠)"),
                  Tab(text: "역산 (H+Travel)"),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "장애물 높이/깊이 (H)",
                style: TextStyle(
                  color: slate600,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildTextField(_heightCtrl, "높이 mm")),
                  const SizedBox(width: 12),
                  _buildQuickBtn(_heightCtrl, -5.0, "-5"),
                  const SizedBox(width: 4),
                  _buildQuickBtn(_heightCtrl, 5.0, "+5"),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return _tabController.index == 0
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "각도 (∠)",
                              style: TextStyle(
                                color: slate600,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 좁은 폭에서는 빠른 각도 단추가 다음 줄로 내려간다.
                            Wrap(
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: _buildTextField(_angleCtrl, "각도 °"),
                                ),
                                const SizedBox(width: 12),
                                ...[22.5, 30.0, 45.0, 60.0].map(
                                  (val) => _buildQuickAngleBtn(_angleCtrl, val),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildDirectionSelector(),
                            const SizedBox(height: 12),
                            _buildInvertToggle(),
                            const SizedBox(height: 16),
                            _buildResultBox(
                              title: "계산된 빗변 (Travel)",
                              value: calcTravel,
                              runDistance: calcRun,
                              shrink: geometricShrink,
                              shrinkToAdd: shrinkToAdd,
                              gain: totalGain,
                              btnText: "적용",
                              onPressed: () =>
                                  _applyBending(a, calcTravel, geometricShrink),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "현장 빗변 (Travel)",
                              style: TextStyle(
                                color: slate600,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(_travelCtrl, "거리 mm"),
                                ),
                                const SizedBox(width: 12),
                                _buildQuickBtn(_travelCtrl, -10.0, "-10"),
                                const SizedBox(width: 4),
                                _buildQuickBtn(_travelCtrl, 10.0, "+10"),
                              ],
                            ),
                            if (inverseError)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  "오류: 빗변은 높이보다 커야함!",
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            _buildDirectionSelector(),
                            const SizedBox(height: 12),
                            _buildInvertToggle(),
                            const SizedBox(height: 16),
                            _buildResultBox(
                              title: "계산된 각도 (∠)",
                              value: calcAngle,
                              runDistance: calcRun,
                              shrink: geometricShrink,
                              shrinkToAdd: shrinkToAdd,
                              gain: totalGain,
                              btnText: "적용",
                              isError: inverseError,
                              isAngle: true,
                              onPressed: () =>
                                  _applyBending(calcAngle, t, geometricShrink),
                            ),
                          ],
                        );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvertToggle() {
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        onTap: () => setState(() => _isInverted = !_isInverted),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isInverted ? Colors.red.shade50 : slate100,
            border: Border.all(
              color: _isInverted ? Colors.red.shade300 : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.swap_vert,
                color: _isInverted ? Colors.red.shade700 : slate600,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                _isInverted ? "아래로 파기(Invert)" : "위로 넘기(Normal)",
                style: TextStyle(
                  color: _isInverted ? Colors.red.shade700 : slate600,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      readOnly: true,
      onTap: () =>
          MakitaNumpadGlass.show(context, controller: ctrl, title: hint),
      style: const TextStyle(
        color: makitaTeal,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        fontFamily: 'monospace',
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: pureWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: makitaTeal, width: 2),
        ),
      ),
    );
  }

  Widget _buildQuickBtn(
    TextEditingController ctrl,
    double amount,
    String label,
  ) {
    return InkWell(
      onTap: () => _adjustValue(ctrl, amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: const TextStyle(color: slate900, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildQuickAngleBtn(TextEditingController ctrl, double val) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        onTap: () => ctrl.text = val.toStringAsFixed(val % 1 == 0 ? 0 : 1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            val % 1 == 0 ? "${val.toInt()}°" : "$val°",
            style: const TextStyle(
              color: slate900,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultBox({
    required String title,
    required double value,
    required double runDistance,
    required double shrink,
    required double shrinkToAdd,
    required double gain,
    required String btnText,
    required VoidCallback onPressed,
    bool isError = false,
    bool isAngle = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: makitaTeal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: makitaTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: slate600,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value > 0 && !isError
                            ? "${value.toStringAsFixed(1)} ${isAngle ? "°" : "mm"}"
                            : "입력 대기",
                        style: TextStyle(
                          color: value > 0 && !isError
                              ? makitaTeal
                              : Colors.redAccent,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: makitaTeal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
                onPressed: onPressed,
                child: Text(
                  btnText,
                  style: const TextStyle(
                    color: pureWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          if (value > 0 && !isError) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.black12, height: 1),
            const SizedBox(height: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "직선 진행 거리 (Run)",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: slate600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${runDistance.toStringAsFixed(1)} mm",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: slate900,
                    fontFamily: 'monospace',
                  ),
                ),
                const Text(
                  "(바닥을 타고 앞으로 나아간 실제 직선 거리)",
                  style: TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: Colors.black12, height: 1),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "오프셋 축소량",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "+${shrink.toStringAsFixed(1)} mm",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        shrinkToAdd > 0
                            ? "(직진 거리가 줄어드는 몫 · 1번 마킹에 +${shrinkToAdd.toStringAsFixed(1)})"
                            : "(직진 거리가 이만큼 줄어듭니다)",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.black12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "2포인트 연신율 (Gain)",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "-${gain.toStringAsFixed(1)} mm",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Text(
                        "(절단 기장에서 뺌)",
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
