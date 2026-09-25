import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';

const Color _teal = AppColors.brand;
const Color _slate900 = AppColors.text;
const Color _slate600 = AppColors.textSub;
const Color _slate100 = AppColors.background;
const Color _white = Color(0xFFFFFFFF);

/// 한 번 꺾어 재 본 값으로 연신율(게인)을 잡아 주는 창.
///
/// 벤더나 관이 바뀌면 게인도 달라지는데, 표에서 베낀 값을 그대로 쓰면
/// 자를 길이가 벤드마다 어긋난다. 한 토막 꺾어서 재 본 값을 넣으면
/// 그 벤더의 실제 게인을 90° 기준으로 돌려준다.
class MobileGainCalibrationSheet extends StatefulWidget {
  /// 값을 잡았을 때 부른다(90° 기준 게인).
  final ValueChanged<double> onApply;

  const MobileGainCalibrationSheet({super.key, required this.onApply});

  static void show(
    BuildContext context, {
    required ValueChanged<double> onApply,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MobileGainCalibrationSheet(onApply: onApply),
    );
  }

  @override
  State<MobileGainCalibrationSheet> createState() =>
      _MobileGainCalibrationSheetState();
}

class _MobileGainCalibrationSheetState
    extends State<MobileGainCalibrationSheet> {
  final _legA = TextEditingController();
  final _legB = TextEditingController();
  final _cut = TextEditingController();
  final _angle = TextEditingController(text: '90');

  @override
  void dispose() {
    _legA.dispose();
    _legB.dispose();
    _cut.dispose();
    _angle.dispose();
    super.dispose();
  }

  double get _value => gainFromMeasured(
    legA: double.tryParse(_legA.text) ?? 0,
    legB: double.tryParse(_legB.text) ?? 0,
    cutLength: double.tryParse(_cut.text) ?? 0,
    angleDeg: double.tryParse(_angle.text) ?? 0,
  );

  @override
  Widget build(BuildContext context) {
    final v = _value;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        // 작은 화면에서도 칸이 다 보이도록 스크롤되게 한다.
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
              const Text(
                "한 번 꺾어 보고 연신율 잡기",
                style: TextStyle(
                  color: _slate900,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "한 토막 잘라 한 번 꺾고, 꺾인 점에서 양쪽 끝까지 재서 넣으십시오.\n"
                "표에서 베낀 값 대신 이 벤더의 실제 값을 씁니다.",
                style: TextStyle(color: _slate600, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              _field(_cut, "자른 길이 (mm)", "꺾기 전 토막 길이"),
              const SizedBox(height: 10),
              _field(_legA, "꺾인 점에서 한쪽 끝 (mm)", "도면 치수로 재는 자리"),
              const SizedBox(height: 10),
              _field(_legB, "꺾인 점에서 반대쪽 끝 (mm)", ""),
              const SizedBox(height: 10),
              _field(_angle, "꺾은 각도 (°)", "90°가 아니면 90° 기준으로 바꿔 줍니다"),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _slate100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "이 벤더의 연신율 (90° 기준)",
                      style: TextStyle(
                        color: _slate600,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      v > 0 ? "${v.toStringAsFixed(1)} mm" : "값을 넣으십시오",
                      key: const Key('calib_result'),
                      style: TextStyle(
                        color: v > 0 ? _teal : _slate600,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('calib_apply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: v > 0
                      ? () {
                          widget.onApply(v);
                          Navigator.pop(context);
                        }
                      : null,
                  child: const Text(
                    "제원에 넣기",
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
        helperText: hint.isEmpty ? null : hint,
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
