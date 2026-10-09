// 사진대지 PDF(10-10): 한국 현장 서류 관행대로 A4 세로 한 쪽에 사진 3장, 사진마다 오른쪽에
// 일자·공종·구분·내용 표를 둔다. 작업 일지에 붙인 사진과 그 태그(작업 전·중·후)·설명을 그대로 쓴다.
import 'dart:typed_data';

import 'package:pdf/pdf.dart' show PdfColor, PdfColors, PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/pdf_fonts.dart';
import 'report_tools.dart';

/// 한 번에 넣는 사진 수 상한(PDF가 너무 커지지 않게, 한 장 약 150KB).
const int kPhotoSheetMax = 150;

/// 한 쪽에 넣는 사진 수.
const int kPhotoSheetPerPage = 3;

class PhotoSheetItem {
  final String path;
  final DateTime date;
  final String workType; // 공종(일지 작업 유형)
  final String tag; // 구분(작업 전·중·후 등), 없으면 빈칸
  final String content; // 내용(사진 설명, 없으면 일지 작업 내용 첫 줄)

  const PhotoSheetItem({
    required this.path,
    required this.date,
    this.workType = '',
    this.tag = '',
    this.content = '',
  });
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// [from]~[to] 작업 일지의 사진을 날짜 순서(같은 날은 붙인 순서)로 모은다.
List<PhotoSheetItem> photoSheetItems(
  Map<String, dynamic> log,
  DateTime from,
  DateTime to,
) {
  final reports = <Map>[
    for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>())
      if (!reportDateOf(r).isBefore(from) && !reportDateOf(r).isAfter(to)) r,
  ]..sort((a, b) => reportDateOf(a).compareTo(reportDateOf(b)));
  final out = <PhotoSheetItem>[];
  for (final r in reports) {
    final paths = <String>[
      ...((r['image_paths'] as List?) ??
              (r['image_path'] != null ? [r['image_path']] : const []))
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty),
    ];
    if (paths.isEmpty) continue;
    final tags = Map<String, dynamic>.from((r['image_tags'] as Map?) ?? {});
    final caps = Map<String, dynamic>.from((r['image_captions'] as Map?) ?? {});
    final note = (r['note']?.toString() ?? '').trim();
    final noteLine = note == '특이사항 없음' ? '' : note.split('\n').first.trim();
    for (final p in paths) {
      final cap = (caps[p]?.toString() ?? '').trim();
      out.add(
        PhotoSheetItem(
          path: p,
          date: reportDateOf(r),
          workType: workTypesOf(r['work_type']).join('·'),
          tag: (tags[p]?.toString() ?? '').trim(),
          content: cap.isNotEmpty ? cap : noteLine,
        ),
      );
    }
  }
  return out;
}

String photoSheetFileName(String project, DateTime from, DateTime to) {
  final name = project.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  final f = _ymd(from).replaceAll('-', '');
  final t = _ymd(to).replaceAll('-', '');
  return '사진대지_${name.isEmpty ? '현장' : name}_${f == t ? f : '$f-$t'}.pdf';
}

const PdfColor _line = PdfColor.fromInt(0xFF555555);
const PdfColor _head = PdfColor.fromInt(0xFFEFF2F5);

pw.Widget _cell(String text, {bool head = false, int maxLines = 2}) =>
    pw.Container(
      color: head ? _head : null,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      alignment: head ? pw.Alignment.center : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        maxLines: maxLines,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: head ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

/// 표 한 줄(왼쪽 머리 칸 + 값). [grow]면 남는 높이를 다 쓰고 글을 위에서부터 놓는다(내용 줄).
pw.Widget _infoRow(String head, String value, {bool grow = false}) {
  final row = pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(
        width: 36,
        color: _head,
        alignment: pw.Alignment.center,
        child: pw.Text(
          head,
          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.Container(width: 0.5, color: _line),
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          alignment: grow ? pw.Alignment.topLeft : pw.Alignment.centerLeft,
          child: pw.Text(
            value,
            maxLines: grow ? 12 : 1,
            style: const pw.TextStyle(fontSize: 9.5),
          ),
        ),
      ),
    ],
  );
  return pw.Container(
    height: grow ? null : 22,
    decoration: grow
        ? null
        : const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
          ),
    child: row,
  );
}

pw.Widget _block(int no, PhotoSheetItem it, Uint8List? img) {
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _line, width: 0.7)),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Expanded(
          flex: 62,
          child: pw.Container(
            color: PdfColors.grey100,
            padding: const pw.EdgeInsets.all(3),
            alignment: pw.Alignment.center,
            child: img != null
                ? pw.Image(pw.MemoryImage(img), fit: pw.BoxFit.contain)
                : pw.Text(
                    '사진을 불러오지 못했습니다',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
          ),
        ),
        pw.Container(width: 0.7, color: _line),
        // 표가 칸 높이를 다 채우고 내용 줄이 남는 높이를 갖는다(10-10 태블릿: 표가 아래에 붙고 위가 비었다).
        pw.Expanded(
          flex: 38,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _infoRow('번호', '$no'),
              _infoRow('일자', _ymd(it.date)),
              _infoRow('공종', it.workType),
              _infoRow('구분', it.tag),
              pw.Expanded(child: _infoRow('내용', it.content, grow: true)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 사진대지 PDF. [load]는 사진 한 장을 PDF용으로 읽는다(못 읽으면 null → "불러오지 못했습니다" 칸).
/// [onProgress]는 읽은 장 수(화면의 "N/M장" 표시용).
Future<Uint8List> buildPhotoSheetPdf({
  required String project,
  required String period,
  required List<PhotoSheetItem> items,
  Future<Uint8List?> Function(String path)? load,
  void Function(int done, int total)? onProgress,
}) async {
  final list = items.take(kPhotoSheetMax).toList();
  final reader = load ?? loadPhotoBytes;
  final imgs = <Uint8List?>[];
  for (int i = 0; i < list.length; i++) {
    imgs.add(await reader(list[i].path));
    onProgress?.call(i + 1, list.length);
  }
  final fonts = await loadKoreanPdfFonts();
  final pdf = pw.Document(theme: fonts.theme);
  final pages = (list.length / kPhotoSheetPerPage).ceil();
  for (int pg = 0; pg < pages; pg++) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 22),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(
                '사 진 대 지',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: _line, width: 0.7),
              columnWidths: const {
                0: pw.FixedColumnWidth(50),
                1: pw.FlexColumnWidth(3),
                2: pw.FixedColumnWidth(40),
                3: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  children: [
                    _cell('공사명', head: true),
                    _cell(project, maxLines: 1),
                    _cell('기간', head: true),
                    _cell(period, maxLines: 1),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            for (int k = 0; k < kPhotoSheetPerPage; k++) ...[
              if (k > 0) pw.SizedBox(height: 8),
              pw.Expanded(
                child: pg * kPhotoSheetPerPage + k < list.length
                    ? _block(
                        pg * kPhotoSheetPerPage + k + 1,
                        list[pg * kPhotoSheetPerPage + k],
                        imgs[pg * kPhotoSheetPerPage + k],
                      )
                    : pw.SizedBox(),
              ),
            ],
            pw.SizedBox(height: 6),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '${pg + 1} / $pages',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ),
          ],
        ),
      ),
    );
  }
  return pdf.save();
}
