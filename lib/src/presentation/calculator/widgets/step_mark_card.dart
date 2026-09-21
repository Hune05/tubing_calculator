/// STEP 마킹 카드(전선관 마킹 탭 카드와 같은 모양).
/// 튜브 마킹 탭과 보관함 "도면 보기"가 같이 쓴다.
library;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';

const Color _teal = Color(0xFF007580);
const Color _slate900 = Color(0xFF0F172A);
const Color _slate600 = Color(0xFF475569);
const Color _slate200 = Color(0xFFE2E8F0);
const Color _slate100 = Color(0xFFF1F5F9);
const Color _white = Color(0xFFFFFFFF);

/// 카드 아래 한 줄 안내(아이콘, 글, 색).
typedef StepNote = (IconData icon, String text, Color color);

/// 안내 색: 보통 회색, 앞 마킹과의 거리는 청록, 주의는 주황.
const Color stepNoteGrey = _slate600;
const Color stepNoteTeal = _teal;
const Color stepNoteAmber = Color(0xFFC77700);

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
    final Color selColor = Colors.orange.shade400;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.orange.shade50 : _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? selColor
                : (isStraight ? _slate200 : _teal.withValues(alpha: 0.2)),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _slate900.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 60,
                decoration: BoxDecoration(
                  color: selected ? selColor : (isStraight ? _slate200 : _teal),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14),
                  ),
                ),
                child: isStraight
                    ? Center(
                        child: AppIcon(
                          AppGlyph.straightPipe,
                          color: selected ? _white : _slate600,
                          size: 26,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "STEP",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: _white.withValues(alpha: 0.7),
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            "$markNum",
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: _white,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: _slate600,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!isStraight && dirText != null)
                            _DirChip(icon: dirIcon, text: dirText!),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _slate100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        // 6자리 넘는 값은 320 폭에서 넘쳤다. 칸 폭에 맞게 줄인다.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                "$mark",
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: _slate900,
                                  fontFamily: 'monospace',
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                "mm",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _slate600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      for (final (icon, text, color) in notes) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(icon, size: 14, color: color),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                text,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: _teal, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              color: _teal,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// 총 절단 길이 카드의 겉(흰 카드, 옅은 청록 테두리, 가위 아이콘·제목·큰 숫자).
/// 아래 칸([bottom])은 쓰는 곳마다 다르다.
class CutLengthCard extends StatelessWidget {
  final double totalCut;
  final Widget? under;
  final List<Widget> bottom;

  const CutLengthCard({
    super.key,
    required this.totalCut,
    this.under,
    this.bottom = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _teal.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _slate900.withValues(alpha: 0.02),
            blurRadius: 8,
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
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _teal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const AppIcon(
                  AppGlyph.tubeCut,
                  color: _white,
                  size: 18,
                  filled: false,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "총 절단 길이",
                style: TextStyle(
                  color: _teal,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "${totalCut.round()}",
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: _slate900,
                  letterSpacing: -1,
                  height: 1.0,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                "mm",
                style: TextStyle(
                  fontSize: 14,
                  color: _slate600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ?under,
          for (final b in bottom) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: _slate200),
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
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: cardLabelStyle),
        const SizedBox(height: 4),
        Text(value, style: cardValueStyle),
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
