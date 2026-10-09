/// 전선관: 90°로 한 번 꺾어 보고 테이크업·게인 잡기.
///
/// 🚀 [추가] 예전에는 제조사 표 값만 쓸 수 있었다. 벤더·관·손 힘에 따라 실제
/// 값이 조금씩 달라서, 한 번 꺾어 잰 값으로 이 벤더의 값을 잡는다.
library;

import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';

const Color _teal = AppColors.brand;
const Color _slate900 = AppColors.text;
const Color _slate600 = AppColors.textSub;
const Color _slate100 = AppColors.background;
const Color _amber = AppColors.caution;

class ConduitCalibrationSheet extends StatefulWidget {
  /// 지금 설정의 값(견줘 보여 준다).
  final double currentTakeUp;
  final double currentGain;

  /// 값을 잡았을 때 부른다(90° 테이크업, 90° 게인). 유압이면 테이크업은 0.
  final void Function(double takeUp, double gain) onApply;

  /// 유압(가운데 미는 방식, 마킹을 슈 가운데에 맞춤): 게인만 잡고 슈 가운데 셈이 맞는지 보여 준다.
  final bool ramCenter;

  /// 치수 기준이 관 중심이면 다리를 관 중심(가상 중심선)까지 잰다(10-09).
  final bool centerRef;

  const ConduitCalibrationSheet({
    super.key,
    required this.currentTakeUp,
    required this.currentGain,
    required this.onApply,
    this.ramCenter = false,
    this.centerRef = false,
  });

  static void show(
    BuildContext context, {
    required double currentTakeUp,
    required double currentGain,
    required void Function(double takeUp, double gain) onApply,
    bool ramCenter = false,
    bool centerRef = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConduitCalibrationSheet(
        currentTakeUp: currentTakeUp,
        currentGain: currentGain,
        onApply: onApply,
        ramCenter: ramCenter,
        centerRef: centerRef,
      ),
    );
  }

  @override
  State<ConduitCalibrationSheet> createState() =>
      _ConduitCalibrationSheetState();
}

class _ConduitCalibrationSheetState extends State<ConduitCalibrationSheet> {
  final _cut = TextEditingController();
  final _mark = TextEditingController();
  final _stub = TextEditingController();
  final _other = TextEditingController();

  @override
  void dispose() {
    _cut.dispose();
    _mark.dispose();
    _stub.dispose();
    _other.dispose();
    super.dispose();
  }

  double _v(TextEditingController c) => double.tryParse(c.text) ?? 0;

  ({double takeUp, double gain})? get _result => conduitCalibration(
    cut: _v(_cut),
    mark: _v(_mark),
    stub: _v(_stub),
    otherLeg: _v(_other),
  );

  ({double gain, double centerOffset, double diff})? get _ram => ramCalibration(
    cut: _v(_cut),
    mark: _v(_mark),
    stub: _v(_stub),
    otherLeg: _v(_other),
  );

  /// 지금 값과 너무 다르면 잘못 쟀을 수 있다.
  bool _farFrom(double v, double current) =>
      current > 0 && (v - current).abs() > current * 0.2;

  @override
  Widget build(BuildContext context) {
    final bool ram = widget.ramCenter;
    // 다리를 재는 자리(치수 기준).
    final String to = widget.centerRef ? "관 중심(가상 중심선)" : "관 바깥면(등)";
    final rr = ram ? _ram : null;
    // 유압이면 게인만 쓴다(테이크업 자리는 슈 가운데까지 거리로 보여 주기만 한다).
    final r = ram
        ? (rr == null ? null : (takeUp: rr.centerOffset, gain: rr.gain))
        : _result;
    final bool suspicious =
        r != null &&
        ((!ram && _farFrom(r.takeUp, widget.currentTakeUp)) ||
            _farFrom(r.gain, widget.currentGain));
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _slate100,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                ram ? "시험 벤딩으로 게인 잡기 (유압)" : "시험 벤딩으로 테이크업·게인 잡기",
                style: TextStyle(
                  color: _slate900,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ram
                    ? "한 토막 잘라 마킹하고 그 마킹을 슈 가운데에 맞춰 90°로 한 번 꺾은 뒤, "
                          "양쪽 끝에서 꺾인 $to까지 측정해 넣으십시오. 이 벤더의 게인을 잡고, "
                          "슈 가운데 셈(꺾이는 점에서 게인의 절반 앞)이 맞는지 같이 봅니다."
                    : "한 토막 잘라 마킹하고 90°로 한 번 꺾은 뒤, 양쪽 끝에서 꺾인 "
                          "$to까지 측정해 넣으십시오. 이 벤더의 테이크업과 게인을 "
                          "한 번에 잡습니다.",
                style: TextStyle(color: _slate600, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              _field(_cut, "자른 길이 (mm)", "꺾기 전 토막 길이"),
              const SizedBox(height: 10),
              _field(
                _mark,
                "마킹 자리 (mm)",
                ram ? "관 끝에서 슈 가운데에 맞춘 자리" : "관 끝에서 벤더 화살표를 맞춘 자리",
              ),
              const SizedBox(height: 10),
              _field(_stub, "짧은 쪽 다리 (mm)", "그 관 끝에서 꺾인 $to까지(스텁 높이)"),
              const SizedBox(height: 10),
              _field(_other, "긴 쪽 다리 (mm)", "반대쪽 끝에서 꺾인 $to까지"),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _slate100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: r == null
                    ? const Text(
                        "값을 넣으십시오",
                        key: Key('conduit_calib_result'),
                        style: TextStyle(
                          color: _slate600,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Column(
                        key: const Key('conduit_calib_result'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!ram) ...[
                            _resultRow(
                              "테이크업 (90°)",
                              r.takeUp,
                              widget.currentTakeUp,
                            ),
                            const SizedBox(height: 8),
                          ],
                          _resultRow("게인 (90°)", r.gain, widget.currentGain),
                          if (rr != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              "꺾이는 점 → 슈 가운데: ${rr.centerOffset.toStringAsFixed(1)} mm "
                              "(게인 ÷ 2 = ${(rr.gain / 2).toStringAsFixed(1)} mm)",
                              key: const Key('conduit_calib_center'),
                              style: const TextStyle(
                                color: _slate600,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (rr.diff.abs() > 5) ...[
                              const SizedBox(height: 6),
                              Text(
                                "슈 가운데 셈과 ${rr.diff.abs().toStringAsFixed(0)} mm 다릅니다. 마킹을 슈 가운데에 맞췄는지, "
                                "다리를 $to까지 쟀는지 확인하십시오. 계속 다르면 알려 주십시오.",
                                key: const Key('conduit_calib_center_warn'),
                                style: const TextStyle(
                                  color: _amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                          if (suspicious) ...[
                            const SizedBox(height: 10),
                            const Text(
                              "지금 값과 20% 넘게 다릅니다. 다리를 잰 자리와 마킹 자리를 다시 확인하십시오.",
                              style: TextStyle(
                                color: _amber,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('conduit_calib_apply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: r == null
                      ? null
                      : () {
                          widget.onApply(
                            ram ? 0 : double.parse(r.takeUp.toStringAsFixed(1)),
                            double.parse(r.gain.toStringAsFixed(1)),
                          );
                          Navigator.pop(context);
                        },
                  child: const Text(
                    "이 값으로 저장",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultRow(String label, double v, double current) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _slate600,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "${v.toStringAsFixed(1)} mm",
              style: const TextStyle(
                color: _teal,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        if (current > 0) ...[
          const SizedBox(width: 8),
          Text(
            "지금 ${current.toStringAsFixed(1)}",
            style: const TextStyle(color: _slate600, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _field(TextEditingController c, String label, String hint) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        color: _slate900,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        filled: true,
        fillColor: _slate100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
