// 현장 자료·장비 사용법 화면이 같이 쓰는 카드·표·줄.
//
// 색은 고정 상수가 아니라 현장 보기(보통/햇빛/야간, field_view.dart)를 따르는
// getter다 - 이 화면도 벤더 옆에서, 야외에서 펴 보는 화면이라 D-D 팀에 넣었다.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/field_view.dart';

Color get refTeal => fc.brand;
Color get refOnTeal => fc.onBrand;
Color get refWhite => fc.surface;
Color get refBg => fc.background;
Color get refTextMain => fc.text;
Color get refTextSub => fc.textSub;
Color get refHighlight => fc.brandSoft;
Color get refWarnBg => fieldSoft(Colors.red.shade50, (p) => p.danger);
Color get refWarnBorder =>
    fieldPick(Colors.red.shade200, sunlight: fc.danger, night: fc.danger);
Color get refWarnIcon =>
    fieldPick(Colors.red.shade700, sunlight: fc.danger, night: fc.danger);
Color get refWarnText =>
    fieldPick(Colors.redAccent, sunlight: fc.danger, night: fc.danger);

/// 숫자를 소수 [digits]자리까지, 끝의 0은 떼고 보여 준다(12.70 → 12.7, 38.0 → 38).
String refNum(double v, [int digits = 1]) {
  var s = v.toStringAsFixed(digits);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// 맨 위 안내 글 상자.
Widget refIntroBadge(String text, {IconData icon = LucideIcons.info}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: refHighlight,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: refTeal.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: refTeal, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: refTextMain.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}

/// 빨간 주의 상자.
Widget refWarnBox(String text) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: refWarnBg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: refWarnBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, color: refWarnIcon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: refWarnText,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

/// 초록 확인 상자(앱 설정과 이어지는 안내).
Widget refTipBox(String text) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: refTeal.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: refTeal.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline_rounded, color: refTeal, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: refTeal,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

/// 둥근 카드(제목·아이콘·내용).
Widget refCard({
  required String title,
  String? subtitle,
  required IconData icon,
  required Color iconColor,
  required List<Widget> children,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: refWhite,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: refTextMain,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: refTextSub,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 20),
        ...children,
      ],
    ),
  );
}

/// 접었다 펴는 카드(긴 표용).
Widget refExpandCard({
  required String title,
  String? subtitle,
  required IconData icon,
  required Color iconColor,
  required List<Widget> children,
  bool initiallyExpanded = false,
}) {
  return Container(
    decoration: BoxDecoration(
      color: refWhite,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: refTextMain,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: refTextSub),
              ),
        children: children,
      ),
    ),
  );
}

/// 단추 이름 → 목적 → 조작 순서로 적는 장비 설명 한 덩어리.
Widget refButtonGuide({
  required String btnName,
  required String purpose,
  required String action,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: refTextMain,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            btnName,
            style: TextStyle(
              color: refBg,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "• 목적: ",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: refTextMain,
              ),
            ),
            Expanded(
              child: Text(
                purpose,
                style: TextStyle(fontSize: 13, color: refTextSub),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "• 조작: ",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: refTeal,
              ),
            ),
            Expanded(
              child: Text(
                action,
                style: TextStyle(
                  fontSize: 13,
                  color: refTextMain,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// 카드 안 항목 사이 옅은 선.
Widget refGap() => Divider(height: 24, color: refBg);

/// 왼쪽 제목, 오른쪽 설명.
Widget refDataRow(String title, String desc) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: refTextMain,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            desc,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: refTextSub,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

/// 번호 붙은 순서 한 줄("1  …").
Widget refStep(int n, String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: refTeal, shape: BoxShape.circle),
          child: Text(
            "$n",
            style: TextStyle(
              color: refOnTeal,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: refTextMain,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

/// 작은 제목 줄(카드 안 구분).
Widget refSectionTitle(String text) => Padding(
  padding: const EdgeInsets.only(top: 6, bottom: 8),
  child: Text(
    text,
    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: refTextMain),
  ),
);

/// 표. 열이 많으면 글자를 조금 줄인다. 첫 열은 왼쪽 정렬로 조금 넓게.
Widget refTable({
  required List<String> headers,
  required List<List<String>> rows,
  String? footer,
  List<int>? flex,
}) {
  final double font = headers.length >= 6
      ? 11
      : headers.length == 5
      ? 12
      : 13;
  int f(int i) => flex != null && i < flex.length ? flex[i] : 1;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: refBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            for (var i = 0; i < headers.length; i++)
              Expanded(
                flex: f(i),
                child: Text(
                  headers[i],
                  style: TextStyle(
                    fontSize: font - 1,
                    fontWeight: FontWeight.bold,
                    color: refTextSub,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      ...rows.map(
        (row) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          child: Row(
            children: [
              for (var i = 0; i < row.length; i++)
                Expanded(
                  flex: f(i),
                  child: Text(
                    row[i],
                    style: TextStyle(
                      fontSize: font,
                      fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w600,
                      color: refTextMain,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
      if (footer != null) ...[
        const SizedBox(height: 8),
        Text(
          footer,
          style: TextStyle(
            fontSize: 11,
            color: refWarnText,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ],
    ],
  );
}

/// 고르는 칩 줄(규격 고르기 등).
Widget refChips({
  required List<String> items,
  required String selected,
  required ValueChanged<String> onSelected,
}) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final it in items)
        ChoiceChip(
          label: Text(it),
          selected: it == selected,
          onSelected: (_) => onSelected(it),
          selectedColor: refTeal,
          labelStyle: TextStyle(
            color: it == selected ? refOnTeal : refTextMain,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          backgroundColor: refBg,
          side: BorderSide.none,
        ),
    ],
  );
}
