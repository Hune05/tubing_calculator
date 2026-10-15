// 계산기 화면들이 같이 쓰는 입력 칸·"?" 안내·결과 상자(전기 계산기·압력 시험 계산기).
// 현장 보기(보통·햇빛·야간) 색(fc)을 따른다 — 화면을 FieldViewTheme로 감싸 쓴다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/field_view.dart';
import 'formula_card.dart';
import 'number_text.dart';

mixin CalcFormParts<W extends StatefulWidget> on State<W> {
  // 10-15 새 모양: 고르면 옅은 청록 + ✓ + 짙은 청록 글자(꽉 찬 청록·흰 글자는 주 단추에만). 색은 앱 테마(chipTheme).
  Widget calcChip(String key, String label, bool sel, VoidCallback onTap) =>
      ChoiceChip(
        key: Key(key),
        label: Text(label),
        selected: sel,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          onTap();
        },
      );

  Widget calcToggle(String key, String label, VoidCallback onTap) => TextButton(
    key: Key(key),
    onPressed: onTap,
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
  );

  Widget calcHelp(String title, String text) => InkWell(
    borderRadius: BorderRadius.circular(8),
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
    // 누르는 칸 36px(아이콘 20px + 둘레 8px): 맨손으로 누르기 쉽게. 장갑 크기(48px)까지는 키우지 않는다.
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(Icons.help_outline_rounded, size: 20, color: fc.brand),
    ),
  );

  Widget calcBox({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
    decoration: BoxDecoration(
      color: fc.surface,
      borderRadius: BorderRadius.circular(6),
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
      // 도움말이 비어 있으면(칸 이름으로 충분하면) "?"를 두지 않는다.
      if (guide.isNotEmpty) calcHelp(label, guide),
    ],
  );

  // 10-15 새 모양: 이름은 칸 위에 작게, 값은 네모 칸에 크게, 단위는 칸 안 오른쪽.
  // (예전: 한 상자 안에 이름 왼쪽·값 오른쪽 — 값이 누르는 칸인지 잘 안 보였다)
  Widget calcField(
    String key,
    String label,
    TextEditingController c,
    String guide, {
    Widget? trailing,
    bool signed = false,
  }) {
    final (name, unit) = splitFieldUnit(label);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fc.textSub),
                ),
              ),
              if (guide.isNotEmpty) calcHelp(label, guide),
            ],
          ),
          if (guide.isEmpty) const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: Key(key),
                  controller: c,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: true,
                    signed: signed,
                  ),
                  // 키보드 "다음"으로 다음 칸(앱 전체 순서 규칙이 "?" 도움말은 건너뛴다).
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: fc.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: ratioDecoration(label, c, unit: unit),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 6), trailing],
            ],
          ),
        ],
      ),
    );
  }

  /// 예전에 칸 아래에 붙이던 안내(지금은 칸 안 [ratioDecoration]으로 옮김). 칸 높이를 바꾸지 않는다.
  Widget ratioHinted(String label, TextEditingController c, Widget box) => box;

  /// 숫자 칸 꾸밈. 효율·역률 같은 % 칸에 1 이하를 넣으면 숫자 뒤에 실제로 계산에 쓰는 %("= 70%")를 붙인다.
  InputDecoration ratioDecoration(String label, TextEditingController c, {String? unit}) {
    final ratio = ratioSuffixText(label, c.text);
    final sfx = ratio == null ? unit : '$ratio  ${unit ?? ''}'.trim();
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: fc.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      suffixText: sfx,
      suffixStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: fc.textSub,
      ),
    );
  }


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
    Widget? extra,
    bool solve = false,
  }) => _calcResult(
    key: key,
    big: big,
    caption: caption,
    lines: lines,
    warn: warn,
    extra: extra,
    solve: solve,
  );

  /// [solve]가 true면 결과 줄 중 "식 = 대입 = 결과" 꼴을 풀이 카드(식·대입·결과)로 옮긴다.
  Widget _calcResult({
    Key? key,
    required String big,
    required String caption,
    required List<String> lines,
    bool warn = false,
    Widget? extra,
    bool solve = false,
  }) {
    var shown = lines;
    var card = extra;
    if (solve && extra == null) {
      final sp = splitFormulaLines(lines);
      if (sp.rows.isNotEmpty) {
        shown = sp.rest;
        final k = key is ValueKey<String> ? key.value : null;
        card = ElecFormulaCard(
          rows: sp.rows,
          symbols: k == null
              ? const []
              : legendFor(kSymbolLegend[k] ?? const [], sp.rows),
        );
      }
    }
    return Container(
    key: key,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: warn
          ? fieldSoft(Colors.red.shade50, (p) => p.danger)
          : fc.brandSoft,
      borderRadius: BorderRadius.circular(6),
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
        for (final l in shown)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '· $l',
              style: TextStyle(fontSize: 13, color: fc.text, height: 1.4),
            ),
          ),
        ?card,
      ],
    ),
  );
  }
}

/// "유지시간 (분)" → ("유지시간", "분"). 괄호 안이 단위일 때만 떼어 칸 안 오른쪽에 둔다.
/// "라인 번호 (선택)"처럼 한글 설명이면 이름에 그대로 둔다(10-15).
(String, String?) splitFieldUnit(String label) {
  final m = RegExp(r'^(.*\S)\s*\(([^()]+)\)$').firstMatch(label.trim());
  if (m == null) return (label, null);
  final inner = m.group(2)!.trim();
  const koUnits = {'분', '초', '시간', '개', '회', '일', '년', '바퀴', '대', '가닥', '줄'};
  final hasHangul = RegExp(r'[가-힣]').hasMatch(inner);
  if (inner.length > 12 || inner.contains(',') || (hasHangul && !koUnits.contains(inner))) {
    return (label, null);
  }
  return (m.group(1)!, inner);
}
