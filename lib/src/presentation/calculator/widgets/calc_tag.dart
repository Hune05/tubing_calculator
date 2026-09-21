/// 지금 어느 계산기인지 알리는 작은 이름표("튜브" / "전선관").
/// 두 계산기 모양을 맞춘 뒤에도 헷갈리지 않게, 탭마다 제목 옆 같은 자리에 단다.
library;

import 'package:flutter/material.dart';

const Color _teal = Color(0xFF007580);

enum CalcKind { tube, conduit }

class CalcTag extends StatelessWidget {
  final CalcKind kind;

  /// 어두운 바탕(아이소 3D 그림) 위에 올릴 때.
  final bool onDark;

  const CalcTag(this.kind, {super.key, this.onDark = false});

  const CalcTag.tube({super.key, this.onDark = false}) : kind = CalcKind.tube;
  const CalcTag.conduit({super.key, this.onDark = false})
    : kind = CalcKind.conduit;

  String get label => kind == CalcKind.tube ? "튜브" : "전선관";
  IconData get icon => kind == CalcKind.tube
      ? Icons.plumbing_rounded
      : Icons.electrical_services_rounded;

  @override
  Widget build(BuildContext context) {
    final Color fg = onDark ? const Color(0xFF7FD3DB) : _teal;
    return Container(
      key: ValueKey('calc_tag_${kind.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: onDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// 제목 글 뒤에 이름표를 붙인 줄. 좁으면 제목이 줄어든다.
class TitleWithTag extends StatelessWidget {
  final Widget title;
  final CalcKind kind;
  const TitleWithTag({super.key, required this.title, required this.kind});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: title),
        const SizedBox(width: 8),
        CalcTag(kind),
      ],
    );
  }
}
