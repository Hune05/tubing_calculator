// PDF에 손가락 서명(획 좌표 글)을 선으로 그린다(10-14). TBM 서명부·작업 일지 확인 서명이 같이 쓴다.
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'signature_strokes.dart';

/// 서명 획을 PDF 칸에 선으로 그린다(PDF는 아래가 0이라 세로를 뒤집는다).
pw.Widget pdfSignatureBox(String sig, double w, double h) {
  final strokes = decodeSignature(sig);
  if (strokes.isEmpty) return pw.SizedBox(width: w, height: h);
  return pw.SizedBox(
    width: w,
    height: h,
    child: pw.CustomPaint(
      size: PdfPoint(w, h),
      painter: (PdfGraphics g, PdfPoint size) {
        final k = (size.x / kSigW) < (size.y / kSigH)
            ? size.x / kSigW
            : size.y / kSigH;
        final dx = (size.x - kSigW * k) / 2;
        final dy = (size.y - kSigH * k) / 2;
        g
          ..setStrokeColor(PdfColors.black)
          ..setLineWidth((9 * k).clamp(0.6, 2.0))
          ..setLineCap(PdfLineCap.round)
          ..setLineJoin(PdfLineJoin.round);
        for (final s in strokes) {
          final f = s.first;
          g.moveTo(dx + f.$1 * k, size.y - (dy + f.$2 * k));
          if (s.length == 1) {
            g.lineTo(dx + f.$1 * k + 0.1, size.y - (dy + f.$2 * k));
          }
          for (final p in s.skip(1)) {
            g.lineTo(dx + p.$1 * k, size.y - (dy + p.$2 * k));
          }
          g.strokePath();
        }
      },
    ),
  );
}
