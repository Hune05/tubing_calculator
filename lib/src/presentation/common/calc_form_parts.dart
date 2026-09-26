// 계산기 화면들이 같이 쓰는 입력 칸·"?" 안내·결과 상자(전기 계산기·압력 시험 계산기).
// 현장 보기(보통·햇빛·야간) 색(fc)을 따른다 — 화면을 FieldViewTheme로 감싸 쓴다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/field_view.dart';

mixin CalcFormParts<W extends StatefulWidget> on State<W> {
  Widget calcChip(String key, String label, bool sel, VoidCallback onTap) =>
      ChoiceChip(
        key: Key(key),
        label: Text(label),
        selected: sel,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          onTap();
        },
        showCheckmark: false,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          color: sel ? fc.onBrand : fc.text,
        ),
        selectedColor: fc.brand,
        backgroundColor: fc.surface,
        side: BorderSide(color: sel ? fc.brand : fc.line),
      );

  Widget calcToggle(String key, String label, VoidCallback onTap) => TextButton(
    key: Key(key),
    onPressed: onTap,
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
  );

  Widget calcHelp(String title, String text) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: () => showModalBottomSheet<void>(
      context: context,
      backgroundColor: fc.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: fc.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                text,
                style: TextStyle(fontSize: 15, color: fc.text, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Icon(Icons.help_outline_rounded, size: 20, color: fc.brand),
    ),
  );

  Widget calcBox({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
    decoration: BoxDecoration(
      color: fc.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: fc.line),
    ),
    child: child,
  );

  Widget calcLabel(String label, String guide) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: fc.text,
          ),
        ),
      ),
      calcHelp(label, guide),
    ],
  );

  Widget calcField(
    String key,
    String label,
    TextEditingController c,
    String guide, {
    Widget? trailing,
    bool signed = false,
  }) => calcBox(
    child: Row(
      children: [
        Expanded(flex: 5, child: calcLabel(label, guide)),
        Expanded(
          flex: 4,
          child: TextField(
            key: Key(key),
            controller: c,
            textAlign: TextAlign.right,
            keyboardType: TextInputType.numberWithOptions(
              decimal: true,
              signed: signed,
            ),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: fc.text,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        ?trailing,
        if (trailing == null) const SizedBox(width: 8),
      ],
    ),
  );

  Widget calcSwitch(
    String label,
    bool v,
    ValueChanged<bool> onChanged,
    String guide, {
    required String key,
  }) => calcBox(
    child: Row(
      children: [
        Expanded(child: calcLabel(label, guide)),
        Switch(key: Key(key), value: v, onChanged: onChanged),
      ],
    ),
  );

  Widget calcDropdown<T>(
    String key,
    String label,
    T value,
    List<T> items,
    String Function(T) text,
    ValueChanged<T> onChanged,
    String guide,
  ) => calcBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: calcLabel(label, guide),
        ),
        DropdownButton<T>(
          key: Key(key),
          value: value,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          dropdownColor: fc.surface,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: fc.text,
          ),
          items: [
            for (final i in items)
              DropdownMenuItem<T>(value: i, child: Text(text(i))),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    ),
  );

  Widget calcResult({
    Key? key,
    required String big,
    required String caption,
    required List<String> lines,
    bool warn = false,
  }) => Container(
    key: key,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: warn
          ? fieldSoft(Colors.red.shade50, (p) => p.danger)
          : fc.brandSoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: fc.textSub,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          big,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: warn ? fc.danger : fc.brand,
          ),
        ),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '· $l',
              style: TextStyle(fontSize: 13, color: fc.text, height: 1.4),
            ),
          ),
      ],
    ),
  );
}
