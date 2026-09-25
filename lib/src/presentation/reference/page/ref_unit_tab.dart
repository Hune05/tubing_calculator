// 단위 환산 탭: 표에 미리 계산해 둔 값만 병기돼 있고 계산기는 없던 것을 채운다
// (현장자료_보충제안_2026-09-25.md 3번). 정확한 물리 환산 상수만 쓰는 순수 계산이라
// 계산기처럼 새 설정값을 만들 필요가 없다. 어느 쪽에 넣어도 다른 쪽이 바로 바뀐다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'reference_widgets.dart';

// mm→inch: 1 inch = 25.4mm(정의값). kg→lb: 1 lb = 0.45359237kg(정의값).
// bar→psi: 1 psi = 6894.75729 Pa, 1 bar = 100000 Pa. Nm→lb-ft: 1 lbf = 4.4482216152605N,
// 1 ft = 0.3048m(정의값)이라 1 lb-ft = 1.3558179483314004 Nm.
const double _mmPerInch = 25.4;
const double _lbPerKg = 1 / 0.45359237;
const double _psiPerBar = 100000 / 6894.75729;
const double _lbFtPerNm = 1 / 1.3558179483314004;

class RefUnitTab extends StatelessWidget {
  const RefUnitTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        refIntroBadge(
          "숫자를 아무 쪽에나 넣으면 다른 쪽이 바로 바뀝니다. 정확한 환산 상수만 쓰는 계산이라, "
          "장비 매뉴얼·해외 규격표를 볼 때 그대로 씁니다(반올림은 소수 넷째 자리에서).",
          icon: LucideIcons.arrowLeftRight,
        ),
        const SizedBox(height: 16),
        const _ConverterCard(
          title: "길이 (mm ↔ inch)",
          labelA: "mm",
          labelB: "inch",
          aToB: 1 / _mmPerInch,
          icon: LucideIcons.ruler,
          iconColor: Colors.blueAccent,
        ),
        const SizedBox(height: 16),
        const _ConverterCard(
          title: "무게 (kg ↔ lb)",
          labelA: "kg",
          labelB: "lb",
          aToB: _lbPerKg,
          icon: LucideIcons.scale,
          iconColor: Colors.brown,
        ),
        const SizedBox(height: 16),
        const _ConverterCard(
          title: "압력 (bar ↔ psi)",
          labelA: "bar",
          labelB: "psi",
          aToB: _psiPerBar,
          icon: LucideIcons.gauge,
          iconColor: Colors.deepOrange,
        ),
        const SizedBox(height: 16),
        const _ConverterCard(
          title: "토크 (Nm ↔ lb-ft)",
          labelA: "Nm",
          labelB: "lb-ft",
          aToB: _lbFtPerNm,
          icon: LucideIcons.wrench,
          iconColor: Colors.indigo,
        ),
      ],
    );
  }
}

class _ConverterCard extends StatefulWidget {
  final String title;
  final String labelA;
  final String labelB;
  final double aToB; // A × aToB = B
  final IconData icon;
  final Color iconColor;

  const _ConverterCard({
    required this.title,
    required this.labelA,
    required this.labelB,
    required this.aToB,
    required this.icon,
    required this.iconColor,
  });

  @override
  State<_ConverterCard> createState() => _ConverterCardState();
}

class _ConverterCardState extends State<_ConverterCard> {
  final _ctrlA = TextEditingController();
  final _ctrlB = TextEditingController();
  final _focusA = FocusNode();
  final _focusB = FocusNode();

  @override
  void dispose() {
    _ctrlA.dispose();
    _ctrlB.dispose();
    _focusA.dispose();
    _focusB.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    if (v.isNaN || v.isInfinite) return '';
    return refNum(v, 4);
  }

  void _onAChanged(String s) {
    if (!_focusA.hasFocus) return;
    final v = double.tryParse(s);
    _ctrlB.text = v == null ? '' : _fmt(v * widget.aToB);
  }

  void _onBChanged(String s) {
    if (!_focusB.hasFocus) return;
    final v = double.tryParse(s);
    _ctrlA.text = v == null ? '' : _fmt(v / widget.aToB);
  }

  @override
  Widget build(BuildContext context) {
    return refCard(
      title: widget.title,
      icon: widget.icon,
      iconColor: widget.iconColor,
      children: [
        Row(
          children: [
            Expanded(
              child: _field(
                _ctrlA,
                _focusA,
                widget.labelA,
                _onAChanged,
                Key('unit_${widget.labelA}_${widget.labelB}_a'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "=",
                style: TextStyle(
                  color: refTextSub,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              child: _field(
                _ctrlB,
                _focusB,
                widget.labelB,
                _onBChanged,
                Key('unit_${widget.labelA}_${widget.labelB}_b'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    FocusNode focus,
    String label,
    ValueChanged<String> onChanged,
    Key key,
  ) {
    return TextField(
      key: key,
      controller: ctrl,
      focusNode: focus,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
      ],
      onChanged: onChanged,
      style: TextStyle(
        color: refTextMain,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        suffixText: label,
        suffixStyle: TextStyle(
          color: refTextSub,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: refBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
