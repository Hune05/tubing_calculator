import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'cutting_diagram_view.dart';
import 'cutting_math.dart';

// 배치도를 PDF에 그린다. 화면(cutting_diagram_view.dart)과 같은 지점·구간 목록을 받아서
// 같은 모양(세로선 위의 점, 구간 길이에 비례한 선, 누적 위치, 요약)으로 만든다.
// 글꼴은 호출한 쪽 문서의 theme(한글 글꼴)을 그대로 쓴다.

const PdfColor _teal = PdfColor.fromInt(0xFF007580);
const PdfColor _danger = PdfColor.fromInt(0xFFE0432B);
const PdfColor _grey = PdfColor.fromInt(0xFFB0B7BF);
const PdfColor _textGrey = PdfColor.fromInt(0xFF6B7684);

const double _pointH = 34;
const double _nodeSize = 16;

PdfColor _segColor(SegmentState s) {
  switch (s) {
    case SegmentState.ok:
      return _teal;
    case SegmentState.interference:
      return _danger;
    case SegmentState.empty:
    case SegmentState.unreadable:
      return _grey;
  }
}

String _segText(DiagramSegment s) {
  switch (s.state) {
    case SegmentState.empty:
      return '치수 미입력';
    case SegmentState.unreadable:
      return '숫자로 읽을 수 없습니다';
    case SegmentState.ok:
      return cutBreakdownText(
        c2cMm: s.c2cMm,
        startDeduction: s.startDeduction,
        endDeduction: s.endDeduction,
      );
    case SegmentState.interference:
      return '간섭 발생! ${cutBreakdownText(c2cMm: s.c2cMm, startDeduction: s.startDeduction, endDeduction: s.endDeduction)}';
  }
}

// 문서에 바로 넣을 수 있는 위젯 목록(지점마다 하나, 맨 끝에 요약).
List<pw.Widget> buildDiagramPdfWidgets({
  required List<DiagramPoint> points,
  required List<DiagramSegment> segments,
  int setMultiplier = 1,
}) {
  var maxCut = 0.0;
  for (final s in segments) {
    if (s.state == SegmentState.ok && s.cutMm > maxCut) maxCut = s.cutMm;
  }
  final cum = cumulativePositions([
    for (final s in segments) s.hasLength ? s.c2cMm : null,
  ]);

  final out = <pw.Widget>[];
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    final hasNext = i < points.length - 1;
    final seg = hasNext ? segments[i] : null;
    final prev = i > 0 ? segments[i - 1] : null;
    final segH = seg == null
        ? 0.0
        : segmentHeight(
            seg.state == SegmentState.ok ? seg.cutMm : null,
            maxCut,
            min: 34,
            max: 84,
          );
    final h = _pointH + segH;

    final sub = <String>[
      if (i == 0) '시작점' else if (cum[i] != null) '시작에서 ${fmtMm(cum[i]!)}mm',
      if (p.specText != null) p.specText!,
    ].join(' · ');

    out.add(
      pw.SizedBox(
        height: h,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 30,
              height: h,
              child: pw.Stack(
                children: [
                  if (prev != null)
                    pw.Positioned(
                      left: _nodeSize / 2 - 1,
                      top: 0,
                      child: pw.Container(
                        width: 2,
                        height: _nodeSize / 2,
                        color: _segColor(prev.state),
                      ),
                    ),
                  if (seg != null)
                    pw.Positioned(
                      left: _nodeSize / 2 - 1,
                      top: _nodeSize / 2,
                      child: pw.Container(
                        width: 2,
                        height: h - _nodeSize / 2,
                        color: _segColor(seg.state),
                      ),
                    ),
                  pw.Positioned(
                    left: 0,
                    top: 0,
                    child: pw.Container(
                      width: _nodeSize,
                      height: _nodeSize,
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        color: p.isNone ? PdfColors.white : _teal,
                        border: pw.Border.all(
                          color: p.isNone ? _grey : _teal,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    height: _pointH,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          p.isNone ? 'PT${i + 1}' : 'PT${i + 1}  ${p.name}',
                          maxLines: 1,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (sub.isNotEmpty)
                          pw.Text(
                            sub,
                            maxLines: 1,
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: _textGrey,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (seg != null)
                    pw.SizedBox(
                      height: segH,
                      child: pw.Align(
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          _segText(seg),
                          maxLines: 2,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: _segColor(seg.state) == _grey
                                ? _textGrey
                                : _segColor(seg.state),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  final s = summarizeDiagram(points, segments, setMultiplier);
  final m = setMultiplier < 1 ? 1 : setMultiplier;
  final lines = <String>[
    '총 절단 길이 (${s.cutCount}구간): ${s.oneSetCutMm.toStringAsFixed(1)}mm',
    if (m > 1) '$m세트: ${s.totalCutMm.toStringAsFixed(1)}mm',
    if (s.lineLengthMm != null) '라인 전체 길이: ${fmtMm(s.lineLengthMm!)}mm',
    if (s.fittingText.isNotEmpty) '부속: ${s.fittingText}',
    if (s.emptyCount > 0) '치수 미입력 ${s.emptyCount}곳',
    if (s.unreadableCount > 0) '읽을 수 없는 값 ${s.unreadableCount}곳',
    if (s.interferenceCount > 0) '간섭 ${s.interferenceCount}곳',
  ];
  out.add(pw.SizedBox(height: 12));
  out.add(
    pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _teal, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '라인 요약',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          for (final l in lines)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(l, style: const pw.TextStyle(fontSize: 10)),
            ),
        ],
      ),
    ),
  );
  return out;
}
