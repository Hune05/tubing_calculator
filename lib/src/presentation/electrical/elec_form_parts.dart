// 전기 설계 계산의 탭들이 같이 쓰는 화면 부품(탭 몸통·숫자 칸·이름표 칩·근거 보기)과 숫자 글꼴.
// 기존 탭은 electric_calculator_page.dart 안의 같은 모양 함수(_page·_field·_chipGroup·_basis)를 쓰고,
// 파일로 나눈 새 탭(부하 합산·단락 전류·발전기·축전지)은 이 mixin을 쓴다.
import 'package:flutter/material.dart';

import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';

/// 소수 [d]자리까지 쓰고 뒤의 0은 뗀다(12.50 → 12.5).
String fmt(double v, [int d = 1]) {
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// 칸의 글을 숫자로 읽는다. 비었거나 숫자가 아니면 null.
double? readNum(TextEditingController c) =>
    double.tryParse(c.text.trim().replaceAll(',', ''));

mixin ElecTabParts<W extends StatefulWidget> on CalcFormParts<W> {
  /// 탭 몸통: 위에 결과 요약 줄(고정), 아래 입력·결과 목록.
  Widget elecPage(
    List<Widget> children, {
    required String sumKey,
    String? summary,
    bool warn = false,
  }) => GestureDetector(
    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
    behavior: HitTestBehavior.translucent,
    child: Column(
      children: [
        if (summary != null)
          Container(
            key: Key(sumKey),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: warn
                  ? fieldSoft(Colors.red.shade50, (p) => p.danger)
                  : fc.brandSoft,
              border: Border(bottom: BorderSide(color: fc.line)),
            ),
            child: Text(
              summary,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: warn ? fc.danger : fc.brand,
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: children,
          ),
        ),
      ],
    ),
  );

  /// 숫자 칸(calcField와 같은 모양, 키보드 "다음"으로 다음 칸).
  Widget elecField(
    String key,
    String label,
    TextEditingController c,
    String guide, {
    VoidCallback? onEdit,
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
            textInputAction: TextInputAction.next,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: fc.text,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
            ),
            onChanged: (_) {
              onEdit?.call();
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
  );

  /// 이름표 + 칩 한 줄.
  Widget elecChipGroup(String label, String guide, List<Widget> chips) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            calcLabel(label, guide),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: chips),
          ],
        ),
      );

  /// 접었다 펴는 "근거 보기".
  Widget elecBasis(String key, List<String> lines) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      key: Key(key),
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      iconColor: fc.brand,
      collapsedIconColor: fc.textSub,
      title: Text(
        '근거 보기',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: fc.text,
        ),
      ),
      children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '· $l',
              style: TextStyle(fontSize: 13, color: fc.text, height: 1.4),
            ),
          ),
      ],
    ),
  );

  Widget elecSectionTitle(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: fc.text,
      ),
    ),
  );
}
