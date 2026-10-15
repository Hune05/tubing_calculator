/// STEP 마킹 카드(전선관 마킹 탭 카드와 같은 모양).
/// 튜브 마킹 탭과 보관함 "도면 보기"가 같이 쓴다.
library;

import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';

const Color _teal = AppColors.brand;
const Color _slate900 = AppColors.text;
const Color _slate600 = AppColors.textSub;

/// 카드 아래 한 줄 안내(아이콘, 글, 색).
typedef StepNote = (IconData icon, String text, Color color);

/// 안내 색: 보통 회색, 앞 마킹과의 거리는 청록, 주의는 주황.
const Color stepNoteGrey = _slate600;
const Color stepNoteTeal = _teal;
const Color stepNoteAmber = AppColors.caution;

/// 안내 색(보통 보기의 이름 색)을 이 자리 보기(햇빛·야간) 색으로.
Color _noteColor(FieldPalette p, Color c) {
  if (c == stepNoteGrey) return p.textSub;
  if (c == stepNoteTeal) return p.brand;
  if (c == stepNoteAmber) return p.caution;
  return c;
}

class StepMarkCard extends StatelessWidget {
  /// 직관이면 번호 없이 회색 띠.
  final bool isStraight;

  /// 벤딩 번호(현장 탭·마킹지의 "N번 마킹"과 같은 번호).
  final int markNum;

  /// 줄자 0점 기준 마킹 위치(mm).
  final int mark;

  /// 위 제목("직관 연장 마킹", "21° 벤딩 (실제 23.0°)").
  final String title;

  /// 방향 칩(벤딩만).
  final IconData? dirIcon;
  final String? dirText;

  final List<StepNote> notes;

  /// 눌러 고른 카드(도면 보기에서 3D 그림에 표시할 때).
  final bool selected;
  final VoidCallback? onTap;

  const StepMarkCard({
    super.key,
    required this.isStraight,
    required this.markNum,
    required this.mark,
    required this.title,
    this.dirIcon,
    this.dirText,
    this.notes = const [],
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = FieldPalette.ofContext(context);
    final Color selColor = p == FieldPalette.normal
        ? Colors.orange.shade400
        : p.caution;
    // 10-15 새 모양(사용자 고름): 왼쪽 가는 세로 순서 줄 + 벤드 번호 네모, 직관은 얇은 한 줄,
    // 벤드 카드는 마킹 숫자를 가장 크게. 색은 청록 하나(주의만 주황).
    final bool warn = notes.any((n) => n.$3 == stepNoteAmber);
    final rail = SizedBox(
      width: 30,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: Center(child: Container(width: 2, color: p.line)),
          ),
          Padding(
            padding: EdgeInsets.only(top: isStraight ? 16 : 14),
            child: isStraight
                ? Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: selected ? selColor : p.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? selColor : p.textFaint,
                        width: 2,
                      ),
                    ),
                  )
                : Container(
                    key: Key('step_badge_$markNum'),
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? selColor : p.brand,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "$markNum",
                      style: TextStyle(
                        color: p.onBrand,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
    Widget noteRow(StepNote n) {
      final (icon, text, color) = n;
      final c = color == stepNoteAmber
          ? p.caution
          : (color == stepNoteTeal ? p.text : _noteColor(p, color));
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 13, color: color == stepNoteAmber ? p.caution : p.textSub),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: c,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final Widget body;
    if (isStraight) {
      // 직관: 얇은 한 줄(무엇 · 값). 주의 글이 있으면 그 아래에.
      final first = notes.isEmpty ? null : notes.first;
      final lead = first == null || first.$3 == stepNoteAmber
          ? '직관'
          : (first.$2.startsWith('직관') ? first.$2 : '직관 · ${first.$2}');
      final rest = first == null || first.$3 == stepNoteAmber ? notes : notes.skip(1);
      body = Container(
        key: const Key('step_straight_row'),
        padding: const EdgeInsets.fromLTRB(4, 9, 6, 10),
        decoration: BoxDecoration(
          color: selected ? fieldSoftIn(p, Colors.orange.shade50, p.caution) : null,
          border: Border(bottom: BorderSide(color: p.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    lead,
                    style: TextStyle(
                      color: p.textSub,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  "$mark",
                  style: TextStyle(
                    color: p.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  "mm",
                  style: TextStyle(color: p.textSub, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            for (final n in rest) noteRow(n),
          ],
        ),
      );
    } else {
      // "90° 벤딩 (실제 93.0°)" → 굵은 "90° 벤딩" + 옅은 "· 실제 93.0°"
      final open = title.indexOf(' (');
      final head = open < 0 ? title : title.substring(0, open);
      final tail = open < 0
          ? null
          : title.substring(open + 2).replaceAll(')', '');
      body = Container(
        margin: const EdgeInsets.only(top: 6, bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: selected
              ? fieldSoftIn(p, Colors.orange.shade50, p.caution)
              : p.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? selColor
                : (warn ? Color.lerp(p.line, p.caution, 0.55)! : p.line),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: head,
                          style: TextStyle(color: p.text, fontWeight: FontWeight.w800),
                        ),
                        if (tail != null)
                          TextSpan(
                            text: ' · $tail',
                            style: TextStyle(color: p.textSub, fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (dirText != null) _DirChip(icon: dirIcon, text: dirText!),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "마킹 위치",
              style: TextStyle(color: p.textSub, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
            // 6자리 넘는 값은 320 폭에서 넘쳤다. 칸 폭에 맞게 줄인다.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    "$mark",
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: p.text,
                      height: 1.1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "mm",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: p.textSub),
                  ),
                ],
              ),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Divider(height: 1, color: p.line),
              const SizedBox(height: 2),
              for (final n in notes) noteRow(n),
            ],
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            rail,
            const SizedBox(width: 6),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _DirChip extends StatelessWidget {
  final IconData? icon;
  final String text;
  const _DirChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final p = FieldPalette.ofContext(context);
    // 10-15: 옅은 청록 알약 대신 회색 테두리 네모 + 청록 화살표 + 짙은 글자.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Color.lerp(p.line, p.textFaint, 0.45)!, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: p.brand, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: p.text,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// 총 절단 길이 카드(10-15 새 모양: 얇은 회색 테두리, 그림자 없음, 제목 옆 [tag]로 벤더 종류).
/// 아래 칸([bottom])은 쓰는 곳마다 다르다.
class CutLengthCard extends StatelessWidget {
  final double totalCut;
  final Widget? under;
  final List<Widget> bottom;

  /// 제목 오른쪽 작은 표시(예: "유압식"). 색 대신 글로 구분한다.
  final String? tag;

  const CutLengthCard({
    super.key,
    required this.totalCut,
    this.under,
    this.bottom = const [],
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final p = FieldPalette.ofContext(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "총 절단 길이",
                  style: TextStyle(
                    color: p.textSub,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Color.lerp(p.line, p.textFaint, 0.45)!),
                  ),
                  child: Text(
                    tag!,
                    style: TextStyle(color: p.text, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // 다섯 자리 길이·글자 크게에서 카드 밖으로 넘치지 않게(전선관 쪽과 같이 줄여 맞춘다).
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  "${totalCut.round()}",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: p.text,
                    height: 1.05,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "mm",
                  style: TextStyle(
                    fontSize: 14,
                    color: p.textSub,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ?under,
          for (final b in bottom) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: p.line),
            ),
            b,
          ],
        ],
      ),
    );
  }
}

/// 카드 안 작은 이름 + 값(예: "반경(R)" / "38 mm").
class CardLabelValue extends StatelessWidget {
  final String label;
  final String value;
  final CrossAxisAlignment align;
  const CardLabelValue(
    this.label,
    this.value, {
    super.key,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final p = FieldPalette.ofContext(context);
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: cardLabelStyle.copyWith(color: p.textSub)),
        const SizedBox(height: 4),
        Text(value, style: cardValueStyle.copyWith(color: p.text)),
      ],
    );
  }
}

const TextStyle cardLabelStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.bold,
  color: _slate600,
);
const TextStyle cardValueStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w900,
  color: _slate900,
);

/// 마킹 카드 목록: 늘 한 줄(위→아래). [build]는 0부터 [count]-1까지 부른다.
/// 10-13: 10-09에 폭 700 이상이면 두 줄로 나란히 놓게 했는데, 세로로 든 태블릿(폭 약 800)에서도 두 줄이 되어
/// 카드가 반쪽 폭으로 짜부라졌다(사용자: "완전 답답하게 짜부"). 09-29에 두 칸 화면을 뺀 결정과 같게 한 줄로 되돌림.
Widget markCardSliver({
  required int count,
  required Widget Function(int index) build,
}) => SliverList(
  delegate: SliverChildBuilderDelegate((_, i) => build(i), childCount: count),
);
