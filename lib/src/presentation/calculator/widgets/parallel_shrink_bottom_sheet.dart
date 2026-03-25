import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:lucide_icons/lucide_icons.dart';

import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';

const Color makitaTeal = Color(0xFF007580);
const Color panelBg = Color(0xFF2A2A2A);
const Color pureWhite = Color(0xFFFFFFFF);

class ParallelShrinkBottomSheet extends StatefulWidget {
  final double? initialAngle;

  const ParallelShrinkBottomSheet({super.key, this.initialAngle});

  static void show(BuildContext context, {double? currentAngle}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ParallelShrinkBottomSheet(initialAngle: currentAngle),
    );
  }

  @override
  State<ParallelShrinkBottomSheet> createState() =>
      _ParallelShrinkBottomSheetState();
}

class _ParallelShrinkBottomSheetState extends State<ParallelShrinkBottomSheet> {
  // 🚀 모드 토글 상태
  bool _isParallelMode = true; // true: 나란히 평행, false: 축소값
  bool _is3DMode = false; // true: 3D 롤링, false: 2D 일반

  // 🚀 컨트롤러
  final TextEditingController _spacingCtrl = TextEditingController(
    text: "50",
  ); // 배관 간격
  final TextEditingController _riseCtrl = TextEditingController(text: "150");
  final TextEditingController _rollCtrl = TextEditingController(text: "200");
  late TextEditingController _angleCtrl;

  int _pipeIndex = 1;

  @override
  void initState() {
    super.initState();
    double initAng =
        (widget.initialAngle != null &&
            widget.initialAngle! > 0 &&
            widget.initialAngle! <= 90)
        ? widget.initialAngle!
        : 45.0;

    _angleCtrl = TextEditingController(
      text: initAng.toStringAsFixed(initAng % 1 == 0 ? 0 : 1),
    );

    // 실시간 업데이트 리스너 연결
    _spacingCtrl.addListener(() => setState(() {}));
    _riseCtrl.addListener(() => setState(() {}));
    _rollCtrl.addListener(() => setState(() {}));
    _angleCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _spacingCtrl.dispose();
    _riseCtrl.dispose();
    _rollCtrl.dispose();
    _angleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    // 1. 공통 입력값 파싱
    double angle = double.tryParse(_angleCtrl.text) ?? 0.0;
    double spacing = double.tryParse(_spacingCtrl.text) ?? 0.0; // 🚀 배관 간격 파싱

    // 2. 수학 로직 계산
    double trueRise = 0;
    double finalResult = 0;

    // 공통 롤링 높이 계산 (3D 롤링 모드일 때)
    if (_is3DMode) {
      double r = double.tryParse(_riseCtrl.text) ?? 0;
      double rl = double.tryParse(_rollCtrl.text) ?? 0;
      trueRise = math.sqrt((r * r) + (rl * rl));
    } else {
      trueRise = double.tryParse(_riseCtrl.text) ?? 0;
    }

    if (_isParallelMode) {
      // --- 평행 보정(Stagger) 계산 ---
      // 🚀 배관 간격(spacing)과 각도만 있으면 보정치를 구할 수 있음!
      if (angle > 0 && spacing > 0) {
        if (angle == 90.0) {
          finalResult = spacing * _pipeIndex * 1.5708;
        } else {
          finalResult =
              spacing * _pipeIndex * math.tan((angle / 2) * (math.pi / 180));
        }
      }
    } else {
      // --- 축소값(Shrink) 계산 ---
      if (angle > 0 && angle < 90.0 && trueRise > 0) {
        double rad = angle * (math.pi / 180);
        finalResult = trueRise * ((1 / math.sin(rad)) - (1 / math.tan(rad)));
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: makitaTeal, width: 3)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.layoutGrid, color: makitaTeal, size: 28),
                      SizedBox(width: 12),
                      Text(
                        "평행 & 축소 계산기",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 메인 토글
              _buildToggleBox(
                "평행 계산기",
                "축소값 계산기",
                _isParallelMode,
                () => setState(() => _isParallelMode = true),
                () => setState(() => _isParallelMode = false),
              ),
              const SizedBox(height: 12),

              // 서브 토글
              _buildToggleBox(
                "2D 평면 (일반)",
                "3D 입체 (롤링)",
                !_is3DMode,
                () => setState(() => _is3DMode = false),
                () => setState(() => _is3DMode = true),
              ),
              const SizedBox(height: 24),

              // 🚀 동적 입력 필드
              if (_isParallelMode) ...[
                // 평행 모드에서는 '배관 간격'이 제일 위
                _buildCompactInputRow(_spacingCtrl, "배관 간격 (Spacing)"),

                if (_is3DMode) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactInputRow(
                          _riseCtrl,
                          "장애물 수직 높이 (Rise)",
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCompactInputRow(
                          _rollCtrl,
                          "장애물 수평 이동 (Roll)",
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                // 축소값 모드
                if (!_is3DMode)
                  _buildCompactInputRow(_riseCtrl, "목표 높이 (Rise)")
                else
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactInputRow(_riseCtrl, "수직 높이 (Rise)"),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCompactInputRow(_rollCtrl, "수평 이동 (Roll)"),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 12),

              // 공통 각도 입력 및 퀵버튼
              _buildCompactInputRow(_angleCtrl, "벤딩 각도 (∠)"),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text(
                      "빠른 각도:",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    ...[
                      22.5,
                      30.0,
                      45.0,
                      60.0,
                      90.0,
                    ].map((val) => _buildQuickAngleBtn(_angleCtrl, val)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 평행 모드일 때만 보이는 가닥수 선택기
              if (_isParallelMode) ...[
                const Text(
                  "옆 가닥 번호",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    1,
                    2,
                    3,
                    4,
                    5,
                  ].map((idx) => _buildPipeIndexBtn(idx)).toList(),
                ),
              ],

              const SizedBox(height: 32),

              // 최종 결과창
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 좌측 보조 결과창
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_is3DMode)
                          _buildResultText(
                            "True 오프셋",
                            "${trueRise.toStringAsFixed(1)} mm",
                          ),
                        if (_isParallelMode)
                          _buildResultText("마킹 가이드", "진입(+) 탈출(-)"),
                        if (!_isParallelMode)
                          _buildResultText("마킹 가이드", "기존 길이 + 미루기"),
                      ],
                    ),
                  ),
                  // 우측 메인 결과창
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _isParallelMode
                            ? "$_pipeIndex번 보정치 (Stagger)"
                            : "첫 벤딩 미루기 (Shrink)",
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        finalResult > 0
                            ? "+${finalResult.toStringAsFixed(1)} mm"
                            : "계산 대기중",
                        style: TextStyle(
                          color: finalResult > 0
                              ? makitaTeal
                              : Colors.redAccent,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 🚀 재사용 위젯들
  // ==========================================

  Widget _buildToggleBox(
    String leftLabel,
    String rightLabel,
    bool isLeftActive,
    VoidCallback onLeft,
    VoidCallback onRight,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: isLeftActive ? makitaTeal : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    leftLabel,
                    style: TextStyle(
                      color: isLeftActive ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: !isLeftActive ? makitaTeal : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    rightLabel,
                    style: TextStyle(
                      color: !isLeftActive ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInputRow(TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hint,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          readOnly: true,
          onTap: () =>
              MakitaNumpadGlass.show(context, controller: ctrl, title: hint),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black45,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: makitaTeal, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAngleBtn(TextEditingController ctrl, double val) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        onTap: () => ctrl.text = val.toStringAsFixed(val % 1 == 0 ? 0 : 1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            val % 1 == 0 ? "${val.toInt()}°" : "$val°",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPipeIndexBtn(int idx) {
    bool isActive = _pipeIndex == idx;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () => setState(() => _pipeIndex = idx),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? makitaTeal : Colors.black45,
            border: Border.all(
              color: isActive ? makitaTeal : Colors.white12,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "$idx",
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white54,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
