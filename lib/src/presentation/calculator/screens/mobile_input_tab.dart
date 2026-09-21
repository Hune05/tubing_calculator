import 'package:tubing_calculator/src/presentation/calculator/segment_length_check.dart';
import 'package:flutter/material.dart';

import '../../../core/engine/bend_path.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_rolling_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_saddle_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_parallel_shrink_bottom_sheet.dart';
// 🚀 퀵 킥 및 퀵 U-Bend 바텀시트 임포트 추가
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_quick_kick_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_quick_u_bend_bottom_sheet.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileInputTab extends StatefulWidget {
  const MobileInputTab({super.key});
  @override
  State<MobileInputTab> createState() => _MobileInputTabState();
}

class _MobileInputTabState extends State<MobileInputTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _customAngleController = TextEditingController();

  String _bendType = "90";
  double _selectedAngle = 90.0;
  double? _selectedRotation;
  int? _editingIndex;

  final List<Map<String, dynamic>> _directions = [
    {"label": "UP (위)", "val": 0.0, "icon": Icons.arrow_upward},
    {"label": "FRONT (앞)", "val": 360.0, "icon": Icons.call_made},
    {"label": "LEFT (좌)", "val": 270.0, "icon": Icons.arrow_back},
    {"label": "RIGHT (우)", "val": 90.0, "icon": Icons.arrow_forward},
    {"label": "DOWN (아래)", "val": 180.0, "icon": Icons.arrow_downward},
    {"label": "BACK (뒤)", "val": 450.0, "icon": Icons.call_received},
  ];

  // 🚀 [수정] 이 탭이 자체적으로 SettingsManager/SharedPreferences를 읽어서
  // 로컬 캐시(_minStraight/_warnShoeInterference/_tubeOD)로 들고 있던 걸
  // 없애고, AppSettingsController를 직접 구독한다. 설정 탭에서 값을 바꾸면
  // 이 탭이 열려 있는 상태에서도 즉시 반영된다 (이전에는 탭을 나갔다 다시
  // 들어와야만 반영됐음).
  @override
  void initState() {
    super.initState();
    AppSettingsController().ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    AppSettingsController().addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppSettingsController().removeListener(_onSettingsChanged);
    _lengthController.dispose();
    _customAngleController.dispose();
    super.dispose();
  }

  // 파이프 외경(OD)에 따른 피팅 조립 최소 안전 직관 거리
  void _addSegment() {
    double length = double.tryParse(_lengthController.text) ?? 0.0;

    if (length <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("정확한 길이를 입력해 주십시오."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_bendType == "custom" && _selectedAngle <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("각도를 정확히 입력해 주십시오."),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    if (_selectedAngle > 0 && _selectedRotation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("벤딩 진행 방향(6축)을 먼저 선택해 주십시오!"),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    double finalRotation = _selectedAngle == 0.0 ? 0.0 : _selectedRotation!;

    final settings = AppSettingsController();

    // 🚀 [추가] 지금 진행 방향과 같은(또는 정반대) 방향은 꺾을 수 없다.
    // 예전에는 그냥 들어가서, 3D 그림은 안 꺾이는데 절단 길이에는 호가 더해지는
    // 어긋남이 생겼다(오프셋 뒤에 "우"로 90°를 붙이는 경우가 대표적이다).
    if (_selectedAngle > 0) {
      final bends = MobileBendDataManager().bendList;
      final current = directionAfter([
        for (final b in bends)
          PathSegment(
            length: (b['length'] as num?)?.toDouble() ?? 0.0,
            angle: (b['angle'] as num?)?.toDouble() ?? 0.0,
            rotation: (b['rotation'] as num?)?.toDouble() ?? 0.0,
          ),
      ], radius: settings.bendRadius > 0 ? settings.bendRadius : 1.0);
      if (!canBendToward(current, directionForRotation(finalRotation))) {
        final label = _directions.firstWhere(
          (d) => d['val'] == finalRotation,
          orElse: () => {'label': ''},
        )['label'];
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
                  "그 방향으로는 못 꺾습니다",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: slate900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: Text(
              "관이 이미 '$label' 쪽으로 가고 있거나 그 정반대입니다.\n"
              "방향은 '꺾고 나서 관이 향할 쪽'을 고르는 것이라, 지금 가는 쪽과"
              " 같으면 꺾을 수 없습니다. 다른 축(위·아래·앞·뒤 등)에서 고르십시오.",
              style: const TextStyle(color: slate900, fontSize: 14),
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
    }

    // 기계 간섭 & 누설 위험 이중 검사 로직.
    // 앞에 이어진 직관은 합쳐서 보고, 누설은 관 끝에서만 본다.
    final lengthCheck = checkSegmentLength(
      existing: MobileBendDataManager().bendList,
      length: length,
      angle: _selectedAngle,
      tubeOdMm: settings.isInch ? settings.tubeOD * 25.4 : settings.tubeOD,
      minStraight: settings.minStraight,
      warnShoeInterference: settings.warnShoeInterference,
    );
    final double minFittingStraight = lengthCheck.minFittingStraight;
    final bool isShoeInterference = lengthCheck.shoeInterference;
    final bool isLeakRisk = lengthCheck.leakRisk;

    // 만약 둘 중 하나라도 위험 요소가 발견되면 복합 경고창을 띄움
    if (isShoeInterference || isLeakRisk) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              const Text(
                "벤딩 및 누설 경고",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: slate900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lengthCheck.merged
                    ? "앞 직관과 이어서 곧은 길이가 ${lengthCheck.run.toStringAsFixed(1)}mm뿐이라 현장에서 문제가 생길 수 있습니다.\n"
                    : "입력하신 길이(${length.toStringAsFixed(1)}mm)가 너무 짧아 현장에서 문제가 생길 수 있습니다.\n",
                style: const TextStyle(color: slate900, fontSize: 13),
              ),
              if (isShoeInterference) ...[
                const SizedBox(height: 4),
                Text(
                  "❌ 기계 간섭 위험",
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  "장비 최소 물림 거리(${AppSettingsController().minStraight}mm) 부족",
                  style: const TextStyle(color: slate600, fontSize: 12),
                ),
              ],
              if (isLeakRisk) ...[
                const SizedBox(height: 8),
                Text(
                  "💧 피팅 누설(Leak) 위험",
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  "너트 체결을 위한 완벽한 원형 직관 거리(${minFittingStraight}mm) 부족 (타원형 변형 틈 발생 가능성)",
                  style: const TextStyle(color: slate600, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                "그래도 강제로 도면에 추가하시겠습니까?",
                style: TextStyle(
                  color: slate900,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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
                _executeAddSegment(length, _selectedAngle, finalRotation);
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

    _executeAddSegment(length, _selectedAngle, finalRotation);
  }

  void _executeAddSegment(double length, double angle, double rotation) {
    HapticFeedback.mediumImpact();

    final newBend = {'length': length, 'angle': angle, 'rotation': rotation};

    if (_editingIndex != null) {
      MobileBendDataManager().updateBend(_editingIndex!, newBend);
      setState(() => _editingIndex = null);
    } else {
      MobileBendDataManager().addBend(newBend);
    }

    setState(() {
      _lengthController.clear();
      _selectedRotation = null;
    });
  }

  void _cancelEdit() {
    HapticFeedback.lightImpact();
    setState(() {
      _editingIndex = null;
      _lengthController.clear();
      _selectedRotation = null;
      _bendType = "90";
      _selectedAngle = 90.0;
      _customAngleController.clear();
    });
  }

  void _removeSegment(int index) {
    HapticFeedback.lightImpact();
    MobileBendDataManager().removeBend(index);
    setState(() {
      if (_editingIndex == index) {
        _cancelEdit();
      } else if (_editingIndex != null && _editingIndex! > index) {
        _editingIndex = _editingIndex! - 1;
      }
    });
  }

  void _clearAll() {
    HapticFeedback.heavyImpact();
    MobileBendDataManager().clearBends();
    setState(() => _cancelEdit());
  }

  void _addMultipleBends(List<Map<String, double>> bends) {
    MobileBendDataManager().addMultipleBends(bends);
  }

  void _addSingleBend(double length, double angle, double rotation) {
    MobileBendDataManager().addBend({
      'length': length,
      'angle': angle,
      'rotation': rotation,
    });
  }

  void _showSpecialBendingMenu() {
    double currentRot = _selectedRotation ?? 90.0;
    if (MobileBendDataManager().bendList.isNotEmpty) {
      final lastRot = MobileBendDataManager().bendList.last['rotation'];
      currentRot = (lastRot as num?)?.toDouble() ?? (_selectedRotation ?? 90.0);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 🚀 높이가 오버플로우되지 않도록 허용
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          // 🚀 스크롤 가능하게 감싸서 픽셀 오버플로우 완벽 해결
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "특수 벤딩 계산 및 삽입",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: slate900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "현장 치수를 입력하면 벤딩 데이터가 자동으로 조립됩니다.",
                  style: TextStyle(fontSize: 13, color: slate600),
                ),
                const SizedBox(height: 24),

                // 🚀 1. 퀵 킥 (독립 실행형)
                _buildSpecialMenuBtn("퀵 킥 (단일 단차) 계산기", LucideIcons.zap, () {
                  Navigator.pop(context);
                  MobileQuickKickBottomSheet.show(context);
                }),

                // 🚀 2. 퀵 U-Bend (독립 실행형) 추가!
                _buildSpecialMenuBtn(
                  "퀵 U-Bend (180°) 계산기",
                  Icons.u_turn_right,
                  () {
                    Navigator.pop(context);
                    MobileQuickUBendBottomSheet.show(context);
                  },
                ),

                _buildSpecialMenuBtn("일반 오프셋 (Offset)", Icons.timeline, () {
                  Navigator.pop(context);
                  MobileOffsetBottomSheet.show(
                    context,
                    currentRotation: currentRot,
                    onAddMultipleBends: _addMultipleBends,
                  );
                }),

                _buildSpecialMenuBtn("롤링 오프셋 (Rolling Offset)", Icons.sync, () {
                  Navigator.pop(context);
                  MobileRollingOffsetBottomSheet.show(
                    context,
                    currentRotation: currentRot,
                    onAddBend: _addSingleBend,
                  );
                }),

                _buildSpecialMenuBtn("새들 벤딩 (Saddle)", Icons.architecture, () {
                  Navigator.pop(context);
                  MobileSaddleBottomSheet.show(
                    context,
                    currentRotation: currentRot,
                    onAddBend: _addSingleBend,
                  );
                }),

                _buildSpecialMenuBtn(
                  "평행 및 축소값 (Parallel & Shrink)",
                  Icons.grid_view,
                  () {
                    Navigator.pop(context);
                    MobileParallelShrinkBottomSheet.show(
                      context,
                      currentAngle: _selectedAngle,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialMenuBtn(String title, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: makitaTeal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: makitaTeal, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: slate900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 🚀 [수정] build()에서 매번 _loadSettings()를 호출하면 setState -> 재빌드 ->
    // _loadSettings() 재호출 이 반복되는 무한 루프가 생겨서 삭제함.
    // 설정값은 initState()에서 한 번만 불러온다.

    return ListenableBuilder(
      listenable: MobileBendDataManager(),
      builder: (context, child) {
        final bendList = MobileBendDataManager().bendList;

        return Column(
          children: [
            Expanded(
              flex: 4,
              child: Container(
                color: slate100,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      color: pureWhite,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "배관 라인 리스트",
                            style: TextStyle(
                              color: slate900,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (bendList.isNotEmpty)
                            InkWell(
                              onTap: _clearAll,
                              child: const Text(
                                "전체 삭제",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: bendList.isEmpty
                          ? const Center(
                              child: Text(
                                "아래에서 수치와 방향을 입력해\n배관을 조립해 주십시오.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: slate600, height: 1.5),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: bendList.length,
                              itemBuilder: (context, index) {
                                final item = bendList[index];
                                bool isStraight =
                                    (item['angle'] as num?)?.toDouble() == 0.0;
                                double rotValue =
                                    (item['rotation'] as num?)?.toDouble() ??
                                    0.0;
                                String dirLabel = _directions.firstWhere(
                                  (d) => d['val'] == rotValue,
                                  orElse: () => {"label": "N/A"},
                                )['label'];
                                IconData dirIcon = _directions.firstWhere(
                                  (d) => d['val'] == rotValue,
                                  orElse: () => {"icon": Icons.help},
                                )['icon'];
                                bool isEditingThis = _editingIndex == index;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isEditingThis
                                        ? Colors.orange.shade50
                                        : pureWhite,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isEditingThis
                                          ? Colors.orange.shade400
                                          : Colors.grey.shade300,
                                      width: isEditingThis ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.02,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _editingIndex = index;
                                        _lengthController.text = item['length']
                                            .toString();

                                        double editedAngle =
                                            (item['angle'] as num?)
                                                ?.toDouble() ??
                                            90.0;
                                        if (editedAngle == 90.0) {
                                          _bendType = "90";
                                          _selectedAngle = 90.0;
                                        } else if (editedAngle == 0.0) {
                                          _bendType = "0";
                                          _selectedAngle = 0.0;
                                        } else {
                                          _bendType = "custom";
                                          _selectedAngle = editedAngle;
                                          _customAngleController.text =
                                              editedAngle.toString();
                                        }

                                        _selectedRotation =
                                            _selectedAngle == 0.0
                                            ? null
                                            : (item['rotation'] as num?)
                                                  ?.toDouble();
                                      });
                                    },
                                    leading: CircleAvatar(
                                      backgroundColor: isStraight
                                          ? Colors.grey.shade200
                                          : makitaTeal.withValues(alpha: 0.1),
                                      child: Icon(
                                        isStraight ? Icons.straighten : dirIcon,
                                        color: isStraight
                                            ? slate600
                                            : makitaTeal,
                                      ),
                                    ),
                                    title: Text(
                                      isStraight
                                          ? "직관 (Straight)"
                                          : "${(item['angle'] as num?)?.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}° 벤딩 ($dirLabel)",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isStraight ? slate600 : slate900,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "길이: ${item['length']} mm",
                                      style: const TextStyle(
                                        color: makitaTeal,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      onPressed: () => _removeSegment(index),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: pureWhite,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "배관 형태",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: slate600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SegmentedButton<String>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                  value: "90",
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      "90° 벤딩",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                ButtonSegment(
                                  value: "custom",
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      "직관+각도",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                ButtonSegment(
                                  value: "0",
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      "0° 직관",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              selected: {_bendType},
                              onSelectionChanged: (Set<String> newSelection) {
                                setState(() {
                                  _bendType = newSelection.first;
                                  if (_bendType == "90") {
                                    _selectedAngle = 90.0;
                                  } else if (_bendType == "0") {
                                    _selectedAngle = 0.0;
                                    _selectedRotation = null;
                                  } else {
                                    _selectedAngle =
                                        double.tryParse(
                                          _customAngleController.text,
                                        ) ??
                                        0.0;
                                  }
                                });
                              },
                              style: ButtonStyle(
                                backgroundColor:
                                    WidgetStateProperty.resolveWith<Color>(
                                      (states) =>
                                          states.contains(WidgetState.selected)
                                          ? makitaTeal
                                          : Colors.grey.shade100,
                                    ),
                                foregroundColor:
                                    WidgetStateProperty.resolveWith<Color>(
                                      (states) =>
                                          states.contains(WidgetState.selected)
                                          ? pureWhite
                                          : slate600,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_bendType == "custom") ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            await MakitaNumpad.show(
                              context,
                              controller: _customAngleController,
                              title: "벤딩 각도 입력 (°)",
                            );
                            setState(() {
                              // 🚀 [수정] 음수/180° 초과 입력 방지 (0~180° 범위로 클램프).
                              // 180°에 가까운 값은 계산 엔진에서 별도로 에러 처리되며,
                              // U-Bend는 전용 계산기를 사용하도록 안내함.
                              _selectedAngle =
                                  (double.tryParse(
                                            _customAngleController.text,
                                          ) ??
                                          0.0)
                                      .clamp(0.0, 180.0);
                              if (_selectedAngle == 0.0) {
                                _selectedRotation = null;
                              }
                            });
                          },
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _customAngleController,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.deepOrange,
                                fontFamily: 'monospace',
                              ),
                              decoration: InputDecoration(
                                hintText: "원하는 각도를 입력하십시오 (예: 45)",
                                filled: true,
                                fillColor: Colors.orange.shade50,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.orange.shade200,
                                  ),
                                ),
                                suffixIcon: const Icon(
                                  Icons.edit,
                                  color: Colors.deepOrange,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_selectedAngle > 0) ...[
                        Row(
                          children: [
                            Text(
                              "진행 방향 (6축)",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedRotation == null
                                    ? Colors.redAccent
                                    : slate600,
                                fontSize: 13,
                              ),
                            ),
                            if (_selectedRotation == null)
                              const Text(
                                " *방향을 선택하십시오",
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
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
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
                              onTap: () => setState(
                                () => _selectedRotation = dir['val'],
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? makitaTeal.withValues(alpha: 0.1)
                                      : Colors.grey.shade50,
                                  border: Border.all(
                                    color: isSelected
                                        ? makitaTeal
                                        : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      dir['icon'],
                                      size: 16,
                                      color: isSelected ? makitaTeal : slate600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      dir['label'].split(' ')[0],
                                      style: TextStyle(
                                        color: isSelected
                                            ? makitaTeal
                                            : slate900,
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
                        const SizedBox(height: 16),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "길이 (mm)",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: slate600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    await MakitaNumpad.show(
                                      context,
                                      controller: _lengthController,
                                      title: "배관 길이 (mm)",
                                    );
                                    setState(() {});
                                  },
                                  child: AbsorbPointer(
                                    child: TextField(
                                      controller: _lengthController,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: makitaTeal,
                                        fontFamily: 'monospace',
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "0",
                                        filled: true,
                                        fillColor: Colors.grey.shade100,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        suffixIcon: const Icon(
                                          Icons.edit,
                                          color: slate600,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (_editingIndex != null) ...[
                            SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                onPressed: _cancelEdit,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: slate600,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                ),
                                child: const Icon(Icons.close, color: slate600),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _addSegment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _editingIndex != null
                                    ? Colors.orange.shade600
                                    : makitaTeal,
                                foregroundColor: pureWhite,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                              ),
                              icon: Icon(
                                _editingIndex != null
                                    ? Icons.check
                                    : Icons.add_circle,
                              ),
                              label: Text(
                                _editingIndex != null ? "수정" : "추가",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_editingIndex == null) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _showSpecialBendingMenu,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: makitaTeal,
                                width: 1.5,
                              ),
                              foregroundColor: makitaTeal,
                              backgroundColor: makitaTeal.withValues(
                                alpha: 0.05,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(
                              Icons.auto_awesome_mosaic,
                              size: 20,
                            ),
                            label: const Text(
                              "특수 벤딩 (오프셋 / 새들) 계산기",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
