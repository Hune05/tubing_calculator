import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';

import '../../data/models/fitting_item.dart';
import 'cutting_math.dart';
import 'cutting_theme.dart';

// 튜브 컷팅 "배치도" 탭. 지점을 세로 선 위의 점으로 잇고, 부속은 아이콘으로, 구간은 길이에
// 비례한 선으로 그려서 라인 모양이 한눈에 보이게 한다. 각 지점에는 라인 시작에서의 누적 위치를,
// 맨 아래에는 총 절단 길이·부속 개수 요약을 붙인다. 지점을 누르면 [onTapPoint]로 알려서 입력
// 화면으로 넘어가 바로 고칠 수 있게 한다.
// 화면(CuttingMainScreen)의 값은 아래 두 목록으로 옮겨 받는다 — 그림과 계산이 화면 상태와 분리돼 있어서
// 따로 테스트할 수 있다.

enum SegmentState { empty, unreadable, ok, interference }

// 부속 이름·분류로 배치도 점 안에 넣을 아이콘을 고른다(영어·한글 이름 모두).
// 순서가 중요하다 — "Union Elbow"는 유니온이 아니라 엘보로, "Elbow Adapter"도 엘보로 본다.
AppGlyph iconForFitting(String name, String category) {
  final t = '${name.toLowerCase()} ${category.toLowerCase()}';
  bool has(List<String> keys) => keys.any(t.contains);
  if (has(['elbow', '엘보', '90도', '45도'])) return AppGlyph.fitElbow;
  if (has(['tee', '티자', 't자', '티'])) return AppGlyph.fitTee;
  if (has(['cross', '십자'])) return AppGlyph.fitCross;
  if (has(['valve', '밸브'])) return AppGlyph.fitValve;
  if (has(['reduc', '레듀', '리듀'])) return AppGlyph.fitReducer;
  if (has(['bulkhead', '벌크헤드'])) return AppGlyph.fitBulkhead;
  if (has(['plug', 'cap', '플러그', '캡'])) return AppGlyph.fitCap;
  if (has(['union', '유니온'])) return AppGlyph.fitUnion;
  if (has(['adapter', 'connector', '어댑터', '커넥터', '니플'])) {
    return AppGlyph.fitAdapter;
  }
  return AppGlyph.fitOther;
}

class DiagramPoint {
  final bool isNone; // 부속 없이 직관으로 이어지는 지점
  final String name;
  final String tubeOD;
  final AppGlyph icon;

  const DiagramPoint({
    required this.isNone,
    required this.name,
    required this.tubeOD,
    required this.icon,
  });

  factory DiagramPoint.fromFitting(FittingItem f) => DiagramPoint(
    isNone: f.id == 'none',
    name: f.name,
    tubeOD: f.tubeOD,
    icon: iconForFitting(f.name, f.category),
  );

  // 규격 글자로 쓸 수 있는 값이면 그 글자, 아니면 null.
  String? get specText {
    if (isNone) return null;
    final t = tubeOD.trim();
    if (t.isEmpty || t == 'ALL' || t == '미지정') return null;
    return t;
  }
}

class DiagramSegment {
  final SegmentState state;
  final double c2cMm; // 중심 간 거리(mm)
  final double cutMm; // 절단 길이(mm), 간섭이면 음수
  final double startDeduction;
  final double endDeduction;

  const DiagramSegment({
    required this.state,
    this.c2cMm = 0,
    this.cutMm = 0,
    this.startDeduction = 0,
    this.endDeduction = 0,
  });

  bool get hasLength =>
      state == SegmentState.ok || state == SegmentState.interference;
}

class DiagramSummary {
  final int cutCount; // 계산된 구간 수
  final double oneSetCutMm; // 1세트 절단 길이 합계
  final double totalCutMm; // 세트 수를 곱한 합계
  final double? lineLengthMm; // 라인 전체 길이(중심 간). 모르는 구간이 있으면 null
  final String fittingText;
  final int emptyCount;
  final int unreadableCount;
  final int interferenceCount;

  const DiagramSummary({
    required this.cutCount,
    required this.oneSetCutMm,
    required this.totalCutMm,
    required this.lineLengthMm,
    required this.fittingText,
    required this.emptyCount,
    required this.unreadableCount,
    required this.interferenceCount,
  });
}

DiagramSummary summarizeDiagram(
  List<DiagramPoint> points,
  List<DiagramSegment> segments,
  int setMultiplier,
) {
  var cutCount = 0, empty = 0, unreadable = 0, interference = 0;
  var oneSet = 0.0;
  for (final s in segments) {
    switch (s.state) {
      case SegmentState.ok:
        cutCount++;
        oneSet += s.cutMm;
      case SegmentState.empty:
        empty++;
      case SegmentState.unreadable:
        unreadable++;
      case SegmentState.interference:
        interference++;
    }
  }
  final cum = cumulativePositions([
    for (final s in segments) s.hasLength ? s.c2cMm : null,
  ]);
  final m = setMultiplier < 1 ? 1 : setMultiplier;
  return DiagramSummary(
    cutCount: cutCount,
    oneSetCutMm: oneSet,
    totalCutMm: oneSet * m,
    lineLengthMm: cum.last,
    fittingText: fittingCountsText([
      for (final p in points)
        if (!p.isNone) p.name,
    ]),
    emptyCount: empty,
    unreadableCount: unreadable,
    interferenceCount: interference,
  );
}

class CuttingDiagramView extends StatelessWidget {
  final List<DiagramPoint> points;
  final List<DiagramSegment> segments; // points.length - 1개
  final int? focusedIndex;
  final ValueChanged<int> onTapPoint;
  // 지점을 길게 누르면(부속 바꾸기). 없으면 길게 눌러도 아무 일도 없다.
  final ValueChanged<int>? onLongPressPoint;
  final ScrollController? controller;
  final int setMultiplier;

  const CuttingDiagramView({
    super.key,
    required this.points,
    required this.segments,
    required this.onTapPoint,
    this.onLongPressPoint,
    this.focusedIndex,
    this.controller,
    this.setMultiplier = 1,
  });

  static const double pointHeight = 52;
  static const double _nodeSize = 36;
  static const double _timelineWidth = 48;
  static const double _nodeCenter = _nodeSize / 2;

  static double _maxCut(List<DiagramSegment> segments) {
    var m = 0.0;
    for (final s in segments) {
      if (s.state == SegmentState.ok && s.cutMm > m) m = s.cutMm;
    }
    return m;
  }

  static double _segHeight(
    int i,
    List<DiagramSegment> segments,
    double maxCut,
  ) {
    final s = segments[i];
    return segmentHeight(s.state == SegmentState.ok ? s.cutMm : null, maxCut);
  }

  // 지점 [index]가 시작되는 세로 위치(목록 맨 위 기준). 지점으로 스크롤할 때 쓴다.
  static double offsetOf(
    int index,
    List<DiagramSegment> segments, {
    double scale = 1.0,
  }) {
    final maxCut = _maxCut(segments);
    var y = 0.0;
    for (var i = 0; i < index && i < segments.length; i++) {
      y += (pointHeight + _segHeight(i, segments, maxCut)) * scale;
    }
    return y;
  }

  static double _scaleOf(BuildContext context) =>
      (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 1.8);

  Color _lineColor(SegmentState s) {
    switch (s) {
      case SegmentState.ok:
        return CuttingColors.primary;
      case SegmentState.interference:
        return CuttingColors.danger;
      case SegmentState.empty:
      case SegmentState.unreadable:
        return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = _scaleOf(context);
    final maxCut = _maxCut(segments);
    final cum = cumulativePositions([
      for (final s in segments) s.hasLength ? s.c2cMm : null,
    ]);
    final summary = summarizeDiagram(points, segments, setMultiplier);

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: points.length + 1,
      itemBuilder: (context, i) {
        if (i == points.length) {
          return _SummaryCard(summary: summary, setMultiplier: setMultiplier);
        }
        return _item(context, i, scale, maxCut, cum);
      },
    );
  }

  Widget _item(
    BuildContext context,
    int i,
    double scale,
    double maxCut,
    List<double?> cum,
  ) {
    final p = points[i];
    final hasPrev = i > 0;
    final hasNext = i < points.length - 1;
    final seg = hasNext ? segments[i] : null;
    final prevSeg = hasPrev ? segments[i - 1] : null;
    final segH = hasNext ? _segHeight(i, segments, maxCut) * scale : 0.0;
    final pointH = pointHeight * scale;
    final focused = focusedIndex == i;

    final specParts = <String>[
      if (i == 0) '시작점' else if (cum[i] != null) '시작에서 ${fmtMm(cum[i]!)}mm',
      ?p.specText,
    ];

    Widget bar(Color c) => Container(width: 4, color: c);

    return Material(
      color: focused
          ? CuttingColors.primarySoft.withValues(alpha: 0.5)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: Key('diagram_point_$i'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => onTapPoint(i),
        onLongPress: onLongPressPoint == null
            ? null
            : () => onLongPressPoint!(i),
        child: SizedBox(
          height: pointH + segH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _timelineWidth,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    if (prevSeg != null)
                      Positioned(
                        top: 0,
                        height: _nodeCenter,
                        child: bar(_lineColor(prevSeg.state)),
                      ),
                    if (seg != null)
                      Positioned(
                        top: _nodeCenter,
                        bottom: 0,
                        child: bar(_lineColor(seg.state)),
                      ),
                    Positioned(top: 0, child: _node(p, focused, i)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: pointH,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'PT${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: CuttingColors.textPrimary,
                                  ),
                                ),
                                if (!p.isNone) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: CuttingColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (specParts.isNotEmpty)
                              Text(
                                specParts.join(' · '),
                                key: Key('diagram_pos_$i'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: CuttingColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (seg != null)
                      SizedBox(
                        height: segH,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _segmentInfo(i, seg),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _node(DiagramPoint p, bool focused, int i) {
    return Container(
      key: Key('diagram_node_$i'),
      width: _nodeSize,
      height: _nodeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.isNone ? Colors.white : CuttingColors.primary,
        border: Border.all(
          color: focused
              ? CuttingColors.primaryDark
              : (p.isNone ? Colors.grey.shade400 : CuttingColors.primary),
          width: focused ? 3 : 2,
        ),
      ),
      child: p.isNone
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade400,
              ),
            )
          : AppIcon(p.icon, size: 20, color: Colors.white, filled: false),
    );
  }

  Widget _segmentInfo(int i, DiagramSegment s) {
    switch (s.state) {
      case SegmentState.empty:
        return Text(
          '치수 미입력',
          key: Key('diagram_seg_$i'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: CuttingColors.textSecondary,
          ),
        );
      case SegmentState.unreadable:
        return Text(
          '숫자로 읽을 수 없습니다',
          key: Key('diagram_seg_$i'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: CuttingColors.danger,
          ),
        );
      case SegmentState.ok:
        return Text(
          cutBreakdownText(
            c2cMm: s.c2cMm,
            startDeduction: s.startDeduction,
            endDeduction: s.endDeduction,
          ),
          key: Key('diagram_seg_$i'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: CuttingColors.primary,
          ),
        );
      case SegmentState.interference:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '간섭 발생! 치수를 확인하십시오',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: CuttingColors.danger,
              ),
            ),
            Text(
              cutBreakdownText(
                c2cMm: s.c2cMm,
                startDeduction: s.startDeduction,
                endDeduction: s.endDeduction,
              ),
              key: Key('diagram_seg_$i'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: CuttingColors.danger,
              ),
            ),
          ],
        );
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final DiagramSummary summary;
  final int setMultiplier;

  const _SummaryCard({required this.summary, required this.setMultiplier});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final m = setMultiplier < 1 ? 1 : setMultiplier;

    Widget row(String label, String value, {Color? color, Key? key}) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: CuttingColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              key: key,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color ?? CuttingColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    final warnings = <String>[
      if (s.emptyCount > 0) '치수 미입력 ${s.emptyCount}곳',
      if (s.unreadableCount > 0) '읽을 수 없는 값 ${s.unreadableCount}곳',
      if (s.interferenceCount > 0) '간섭 ${s.interferenceCount}곳',
    ];

    return Container(
      key: const Key('diagram_summary'),
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: CuttingColors.primarySoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CuttingColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '라인 요약',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: CuttingColors.textPrimary,
            ),
          ),
          row(
            '총 절단 길이 (${s.cutCount}구간)',
            '${s.oneSetCutMm.toStringAsFixed(1)}mm',
            color: CuttingColors.primary,
            key: const Key('diagram_total_cut'),
          ),
          if (m > 1)
            row(
              '$m세트',
              '${s.totalCutMm.toStringAsFixed(1)}mm',
              color: CuttingColors.primary,
              key: const Key('diagram_total_sets'),
            ),
          if (s.lineLengthMm != null)
            row(
              '라인 전체 길이',
              '${fmtMm(s.lineLengthMm!)}mm',
              key: const Key('diagram_line_length'),
            ),
          if (s.fittingText.isNotEmpty)
            row('부속', s.fittingText, key: const Key('diagram_fittings')),
          if (warnings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                warnings.join(' · '),
                key: const Key('diagram_warnings'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: CuttingColors.danger,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
