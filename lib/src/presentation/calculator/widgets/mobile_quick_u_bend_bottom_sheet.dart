import 'package:flutter/material.dart';

import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tubing_calculator/src/core/utils/settings_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/u_bend_plan.dart';
import 'package:tubing_calculator/src/core/engine/bend_path.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

/// U-Bend 조립 후 벽(피팅 면)에서 튀어나오는 최고점.
/// 시작 직관 + 반경 + 관 바깥지름의 반. 시작 직관이 없으면 0.
double uBendApex({
  required double startStraight,
  required double radius,
  required double odMm,
}) => startStraight > 0 ? startStraight + radius + odMm / 2 : 0.0;

class MobileQuickUBendBottomSheet extends StatefulWidget {
  /// 입력 목록에 넣을 때 부른다. null이면 값만 보는 계산기다.
  final void Function(List<Map<String, double>>)? onAddMultipleBends;

  /// 관 시작 방향(목록이 비었을 때 지금 진행 방향).
  final String startDir;

  const MobileQuickUBendBottomSheet({
    super.key,
    this.onAddMultipleBends,
    this.startDir = "RIGHT",
  });

  static void show(
    BuildContext context, {
    void Function(List<Map<String, double>>)? onAddMultipleBends,
    String startDir = "RIGHT",
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MobileQuickUBendBottomSheet(
        onAddMultipleBends: onAddMultipleBends,
        startDir: startDir,
      ),
    );
  }

  @override
  State<MobileQuickUBendBottomSheet> createState() =>
      _MobileQuickUBendBottomSheetState();
}

class _MobileQuickUBendBottomSheetState
    extends State<MobileQuickUBendBottomSheet> {
  // 비동기 로드용 장비 설정
  double _minStraight = 0.0;
  bool _warnShoeInterference = true;
  double _tubeOD = 12.7;
  double _bendRadius = 38.1;

  // U자가 튀어나가는 방향(0 위 · 90 우 · 180 아래 · 270 좌 · 360 앞 · 450 뒤).
  double? _turn;

  // 피팅 삽입 여부 토글 상태
  bool _isStartFitting = true;
  bool _isReturnFitting = false;

  final TextEditingController _startStraightCtrl = TextEditingController();
  final TextEditingController _returnStraightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAsyncSettings();
    _startStraightCtrl.addListener(() => setState(() {}));
    _returnStraightCtrl.addListener(() => setState(() {}));
  }

  Future<void> _loadAsyncSettings() async {
    final data = await SettingsManager.loadSettings();
    final prefs = await SharedPreferences.getInstance();

    if (mounted) {
      setState(() {
        _minStraight = data['minStraight'] ?? 0.0;
        // 🚀 [고침] 인치 설정이면 이 값은 인치(0.5 등)다. mm로 바꿔 쓴다.
        final double od = (data['tubeOD'] as num?)?.toDouble() ?? 12.7;
        _tubeOD = data['isInch'] == true ? od * 25.4 : od;
        // 마킹 탭 엔진과 같은 반경을 쓴다(목록에 넣었을 때 값이 같게).
        _bendRadius = MobileBendDataManager().radius;
        _warnShoeInterference = prefs.getBool('warnShoeInterference') ?? true;
      });
    }
  }

  @override
  void dispose() {
    _startStraightCtrl.dispose();
    _returnStraightCtrl.dispose();
    super.dispose();
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
        hintText: "0",
        filled: true,
        fillColor: slate100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final dm = MobileBendDataManager();
    final double fittingDepth = dm.fittingDepth;

    double startStraight = double.tryParse(_startStraightCtrl.text) ?? 0.0;
    double returnStraight = double.tryParse(_returnStraightCtrl.text) ?? 0.0;

    double cToCWidth = _bendRadius * 2;
    // U자가 먹는 길이. 실측 게인이 있으면 마킹 탭 엔진과 같게 그것으로 셈한다
    // (게인 없이 반경만 쓰면 호 길이 πR과 같다).
    final double gain90 = dm.gain90;
    double arcLength = uBendAllowance(
      radius: _bendRadius,
      measuredGain90: gain90,
    );

    double totalCutLength = 0.0;
    double startCutAdd = _isStartFitting ? fittingDepth : 0.0;
    double returnCutAdd = _isReturnFitting ? fittingDepth : 0.0;

    // 🚀 [고침] 예전에는 여기에 2×게인90을 "더했다". 게인은 교차점 기준 치수를
    // 실제 관 길이로 바꿀 때 "빼는" 값인데, 여기서 쓰는 앞 직관 + 호 + 뒤 직관은
    // 이미 펴 놓은 실제 길이라 게인을 더할 자리가 아니다. 3/8" 튜브(R≈38)에서
    // 33mm쯤 길게 잘리고 있었다. 기하 그대로 쓴다.
    // (소재가 늘어나는 양까지 보려면 180°로 한 번 꺾어 실측한 값을 따로 받아야 한다.)

    // 총 절단 기장 = 앞 직관 + 뒤 직관 + 호(Arc) 길이 + 연신율 보정 + 피팅 체결 여유분
    if (startStraight > 0 || returnStraight > 0) {
      totalCutLength =
          startStraight +
          returnStraight +
          arcLength +
          startCutAdd +
          returnCutAdd;
    }

    // 최고점(Apex)은 시작 다리 기준 하나다. 입력한 시작 직관은 피팅 면 밖으로
    // 보이는 길이다(피팅에 들어가는 깊이는 절단 길이에 따로 더한다).
    // 🚀 [고침] 예전에는 여기서 피팅 깊이를 한 번 더 빼서, 깊이 23이면
    // 최고점이 23mm 낮게 나왔다.
    final double apex = uBendApex(
      startStraight: startStraight,
      radius: _bendRadius,
      odMm: _tubeOD,
    );

    // 빨려들어감 간섭 계산 로직
    double requiredFittingStraight = fittingDepth + 15.0; // 15mm는 스패너 조작 여유
    double safeStartStraight = math.max(
      _minStraight,
      _isStartFitting ? requiredFittingStraight : 0,
    );
    double safeReturnStraight = math.max(
      _minStraight,
      _isReturnFitting ? requiredFittingStraight : 0,
    );

    bool isStartTooShort =
        _warnShoeInterference &&
        startStraight > 0 &&
        startStraight < safeStartStraight;
    bool isReturnTooShort =
        _warnShoeInterference &&
        returnStraight > 0 &&
        returnStraight < safeReturnStraight;

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
                  const Icon(Icons.u_turn_right, color: makitaTeal, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "퀵 U-Bend (180°) 계산기",
                      style: TextStyle(
                        color: slate900,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: slate600),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "호(Arc) 길이를 제외한 '앞뒤 순수 직관 길이'를 입력하여 절단 기장과 조립 후 최고점(Apex)을 산출합니다.",
                style: TextStyle(color: slate600, fontSize: 12),
              ),
              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.amber.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "• ${_tubeOD.toStringAsFixed(1)}mm 기준 180° 벤딩 폭(C-C): ${cToCWidth.toStringAsFixed(1)} mm (고정)",
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "• U자가 먹는 관 길이: ${arcLength.toStringAsFixed(1)} mm"
                            "${gain90 > 0 ? ' (실측 게인 ${gain90.toStringAsFixed(1)} 반영)' : ''}",
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "• 앞 직관 + U자 + 뒤 직관이 자를 길이입니다"
                            " (마킹 탭과 같은 셈)",
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 1. 시작 다리 입력
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      "1. 시작부 순수 직관 길이",
                      style: TextStyle(
                        color: slate600,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        "피팅 체결",
                        style: TextStyle(fontSize: 12, color: slate600),
                      ),
                      Switch(
                        value: _isStartFitting,
                        onChanged: (val) =>
                            setState(() => _isStartFitting = val),
                        activeThumbColor: makitaTeal,
                      ),
                    ],
                  ),
                ],
              ),
              _buildTextField(_startStraightCtrl, "시작 직관 길이 (mm)"),

              // 🚀 최고점(Apex) 표시: 오직 시작 다리 밑에만 딱 1번 띄움!
              if (startStraight > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Text(
                    "↳ 조립 후 벽에서 튀어나오는 최고점(Apex): ${apex.toStringAsFixed(1)} mm",
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // 2. 돌아오는 다리 입력
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      "2. 복귀부 순수 직관 길이",
                      style: TextStyle(
                        color: slate600,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        "피팅 체결",
                        style: TextStyle(fontSize: 12, color: slate600),
                      ),
                      Switch(
                        value: _isReturnFitting,
                        onChanged: (val) =>
                            setState(() => _isReturnFitting = val),
                        activeThumbColor: makitaTeal,
                      ),
                    ],
                  ),
                ],
              ),
              _buildTextField(_returnStraightCtrl, "돌아오는 직관 길이 (mm)"),
              // 🚀 복귀부 쓰레기 최고점 로직 완전히 삭제 완료.
              const SizedBox(height: 24),

              if (isStartTooShort || isReturnTooShort) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "⚠️ 직관이 너무 짧아 벤더기에 물리지 않습니다!",
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (isStartTooShort)
                              Text(
                                "• 시작 직관은 최소 ${safeStartStraight.toStringAsFixed(1)}mm 이상이어야 합니다.",
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 12,
                                ),
                              ),
                            if (isReturnTooShort)
                              Text(
                                "• 복귀 직관은 최소 ${safeReturnStraight.toStringAsFixed(1)}mm 이상이어야 합니다.",
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 최종 결과
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: makitaTeal.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: makitaTeal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "총 절단 원장 기장",
                            style: TextStyle(
                              color: slate600,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            totalCutLength > 0
                                ? "${totalCutLength.toStringAsFixed(1)} mm"
                                : "0.0 mm",
                            style: const TextStyle(
                              color: makitaTeal,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "직관 + U자(${arcLength.toStringAsFixed(1)}) + 피팅 깊이 합산",
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onAddMultipleBends != null) ...[
                const SizedBox(height: 20),
                _buildTurnSelector(),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: makitaTeal, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "닫기",
                          style: TextStyle(
                            color: makitaTeal,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.onAddMultipleBends != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          key: const Key('u_bend_apply'),
                          style: FilledButton.styleFrom(
                            backgroundColor: makitaTeal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () =>
                              _apply(startStraight, returnStraight),
                          child: const Text(
                            "목록에 넣기",
                            style: TextStyle(
                              color: pureWhite,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<(double, String)> _turnDirs = [
    (0.0, "UP"),
    (360.0, "FRONT"),
    (270.0, "LEFT"),
    (90.0, "RIGHT"),
    (180.0, "DOWN"),
    (450.0, "BACK"),
  ];

  // U자가 튀어나가는 방향. 목록에 넣을 때만 필요하다.
  Widget _buildTurnSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "U자 방향 (목록에 넣을 때)",
          style: TextStyle(
            color: slate600,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (val, label) in _turnDirs)
              ChoiceChip(
                key: Key('u_turn_$label'),
                label: Text(label),
                selected: _turn == val,
                showCheckmark: false,
                selectedColor: makitaTeal,
                // 폰 다크 모드에서도 밝게(테마 색을 따라가면 검게 나온다).
                backgroundColor: slate100,
                side: BorderSide(
                  color: _turn == val ? makitaTeal : Colors.grey.shade300,
                ),
                labelStyle: TextStyle(
                  color: _turn == val ? pureWhite : slate900,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (_) => setState(() => _turn = val),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _showMsg(String msg) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("확인"),
        ),
      ],
    ),
  );

  // U자를 90° 두 번으로 목록 끝에 넣는다.
  void _apply(double startStraight, double returnStraight) {
    final dm = MobileBendDataManager();
    final list = dm.bendList;
    if (startStraight <= 0 && list.isEmpty) {
      _showMsg("시작 직관 길이를 넣으십시오.");
      return;
    }
    if (_turn == null) {
      _showMsg("U자 방향을 고르십시오.");
      return;
    }
    final double? travel = travelRotation(
      list,
      startDir: widget.startDir,
      radius: _bendRadius,
    );
    if (travel == null) {
      _showMsg("지금 관이 비스듬히 가고 있어 U자를 넣을 수 없습니다. 축 방향으로 간 뒤에 넣으십시오.");
      return;
    }
    if (!canBendToward(
      directionForRotation(travel),
      directionForRotation(_turn!),
    )) {
      _showMsg("지금 관이 가는 방향과 나란한 쪽으로는 U자를 꺾을 수 없습니다. 다른 방향을 고르십시오.");
      return;
    }
    final bool wasEmpty = list.isEmpty;
    final segs = uBendSegments(
      startStraight: startStraight,
      returnStraight: returnStraight,
      radius: _bendRadius,
      turn: _turn!,
      travel: travel,
      prevSetback: lastSetback(list, _bendRadius),
    );
    // 마킹 카드가 U자 안내를 붙이도록 표시해 둔다.
    segs[0]['uBend'] = 1.0;
    segs[1]['uBend'] = 2.0;
    if (wasEmpty) dm.startFit = _isStartFitting;
    dm.endFit = _isReturnFitting;
    widget.onAddMultipleBends!(segs);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("U자를 넣었습니다. 한 번에 180°로 꺾으면 1번 마킹만 씁니다."),
        backgroundColor: makitaTeal,
      ),
    );
    Navigator.pop(context);
  }
}
