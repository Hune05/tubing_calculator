// 도면 보관: 폰 안 앱 폴더(drawings/<id>/)에 원본을 그대로 복사해 두고, 쪽마다 그림(PNG)을 만들어 둔다.
// 표시는 marks.json에 따로 둔다(원본은 건드리지 않는다). 통신 없이 된다.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'drawing_models.dart';
import 'dxf_reader.dart';

/// 쪽 그림 긴 변(px). 폰 메모리와 선명함의 타협(A1 도면이면 약 120 dpi).
const int kPageLongSide = 4000;

class DrawingStore {
  static const String indexKey = 'drawing_library_v1';

  /// 시험에서 바꾼다.
  static Future<Directory> Function() baseDir = () async => Directory('${(await getApplicationSupportDirectory()).path}/drawings');

  static Future<Directory> dirOf(String id) async {
    final d = Directory('${(await baseDir()).path}/$id');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<String> pagePath(String id, int page) async => '${(await dirOf(id)).path}/page_$page.png';
  static Future<String> thumbPath(String id) async => '${(await dirOf(id)).path}/thumb.png';
  static Future<String> originalPath(DrawingDoc d) async => '${(await dirOf(d.id)).path}/original.${d.ext}';

  static Future<List<DrawingDoc>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(indexKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final out = <DrawingDoc>[];
      for (final e in jsonDecode(raw) as List) {
        try {
          out.add(DrawingDoc.fromJson(Map<String, dynamic>.from(e as Map)));
        } catch (_) {}
      }
      out.sort((a, b) => b.openedAt.compareTo(a.openedAt));
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(List<DrawingDoc> list) async {
    await (await SharedPreferences.getInstance()).setString(indexKey, jsonEncode([for (final d in list) d.toJson()]));
  }

  static Future<void> put(DrawingDoc d) async {
    final list = await load();
    list.removeWhere((e) => e.id == d.id);
    list.insert(0, d);
    await _write(list);
  }

  static Future<DrawingDoc?> get(String id) async {
    for (final d in await load()) {
      if (d.id == id) return d;
    }
    return null;
  }

  static Future<void> delete(String id) async {
    final list = await load();
    list.removeWhere((e) => e.id == id);
    await _write(list);
    try {
      final d = Directory('${(await baseDir()).path}/$id');
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }

  // ── 표시 ──

  static Future<List<DrawingMark>> loadMarks(String id) async {
    final f = File('${(await dirOf(id)).path}/marks.json');
    if (!await f.exists()) return [];
    try {
      return [
        for (final e in jsonDecode(await f.readAsString()) as List)
          if (e is Map) DrawingMark.fromJson(Map<String, dynamic>.from(e)),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _marksQueue = Future.value();

  /// 표시 저장은 차례로 하고, 임시 파일에 다 쓴 뒤 바꿔 넣는다(10-07: 겹쳐 쓰거나 쓰는 중 꺼지면
  /// marks.json이 깨져 읽기가 빈 목록이 되고, 다음 저장이 그 도면의 표시를 모두 지웠다).
  static Future<void> saveMarks(DrawingDoc doc, List<DrawingMark> marks) {
    final body = jsonEncode([for (final m in marks) m.toJson()]);
    final next = _marksQueue.catchError((_) {}).then((_) async {
      final path = '${(await dirOf(doc.id)).path}/marks.json';
      final tmp = File('$path.tmp');
      await tmp.writeAsString(body, flush: true);
      await tmp.rename(path);
      await put(doc.copyWith(openIssues: openIssueCount(marks)));
    });
    _marksQueue = next;
    return next;
  }

  // ── 가져오기 ──

  /// 파일을 가져와 보관함에 넣는다. DWG·모르는 형식은 DxfError로 알려 준다.
  static Future<DrawingDoc> importFile(String srcPath, {String? name, DateTime? now}) async {
    final fileName = name ?? srcPath.split(RegExp(r'[\\/]')).last;
    if (isDwgName(fileName)) throw const DxfError(kDwgHelp);
    final kind = kindForName(fileName);
    if (kind == null) throw const DxfError('이 파일은 열 수 없습니다. PDF·사진(JPG·PNG)·DXF 도면만 엽니다.');
    final at = now ?? DateTime.now();
    final id = at.microsecondsSinceEpoch.toString();
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'bin';
    final dir = await dirOf(id);
    final orig = File('${dir.path}/original.$ext');
    await File(srcPath).copy(orig.path);
    try {
      final sizes = <(int, int)>[];
      final dpis = <double>[];
      var pages = 1;
      switch (kind) {
        case DrawingKind.pdf:
          final bytes = await orig.readAsBytes();
          // 먼저 낮은 해상도로 쪽 수와 크기만 본다.
          final inches = <(double, double)>[];
          await for (final r in Printing.raster(bytes, dpi: 12)) {
            inches.add((r.width / 12, r.height / 12));
          }
          if (inches.isEmpty) throw const DxfError('PDF를 읽지 못했습니다.');
          pages = inches.length;
          for (final (w, h) in inches) {
            final dpi = pdfDpiFor(w, h);
            sizes.add(((w * dpi).round(), (h * dpi).round()));
            dpis.add(dpi);
          }
          await _renderPdfPage(bytes, 0, dpis[0], await pagePath(id, 0));
        case DrawingKind.image:
          final bytes = await orig.readAsBytes();
          final img = await _decode(bytes);
          sizes.add((img.width, img.height));
          img.dispose();
          await orig.copy(await pagePath(id, 0));
        case DrawingKind.dxf:
          final text = dxfDecode(await orig.readAsBytes());
          final dxf = readDxf(text);
          if (dxf.isEmpty) throw const DxfError('DXF 안에 그릴 선이 없습니다.');
          final png = await renderDxfPng(dxf);
          await File(await pagePath(id, 0)).writeAsBytes(png.$1);
          sizes.add((png.$2, png.$3));
      }
      await _makeThumb(id);
      final doc = DrawingDoc(id: id, name: fileName, kind: kind, ext: ext, pages: pages, pageSizes: sizes, pageDpi: dpis, addedAt: at, openedAt: at);
      await put(doc);
      return doc;
    } catch (e) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
      if (e is DxfError) rethrow;
      throw DxfError('도면을 열지 못했습니다: $e');
    }
  }

  static double pdfDpiFor(double wInch, double hInch) => (kPageLongSide / math.max(wInch, hInch)).clamp(72.0, 220.0);

  /// 쪽 그림이 없으면 만든다(PDF는 보려는 쪽만 그때 그린다).
  static Future<String> ensurePage(DrawingDoc doc, int page) async {
    final path = await pagePath(doc.id, page);
    if (await File(path).exists()) return path;
    if (doc.kind != DrawingKind.pdf) return path;
    final bytes = await File(await originalPath(doc)).readAsBytes();
    final dpi = page < doc.pageDpi.length ? doc.pageDpi[page] : 150.0;
    await _renderPdfPage(bytes, page, dpi, path);
    return path;
  }

  static Future<void> _renderPdfPage(Uint8List bytes, int page, double dpi, String outPath) async {
    await for (final r in Printing.raster(bytes, pages: [page], dpi: dpi)) {
      await File(outPath).writeAsBytes(await r.toPng());
      return;
    }
    throw const DxfError('PDF 쪽을 그리지 못했습니다.');
  }

  static Future<ui.Image> _decode(Uint8List bytes, {int? width}) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
    return (await codec.getNextFrame()).image;
  }

  static Future<void> _makeThumb(String id) async {
    try {
      final img = await _decode(await File(await pagePath(id, 0)).readAsBytes(), width: 320);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (data != null) await File(await thumbPath(id)).writeAsBytes(data.buffer.asUint8List());
    } catch (_) {}
  }
}

/// DXF를 흰 바탕 그림으로 그린다. (PNG, 가로, 세로)
Future<(Uint8List, int, int)> renderDxfPng(DxfDrawing d, {int longSide = kPageLongSide}) async {
  const margin = 0.03;
  final w0 = d.width * (1 + 2 * margin), h0 = d.height * (1 + 2 * margin);
  final s = longSide / math.max(w0, h0);
  final w = math.max(1, (w0 * s).round()), h = math.max(1, (h0 * s).round());
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = Colors.white);
  final ox = d.minX - d.width * margin, oy = d.maxY + d.height * margin;
  Offset map(double x, double y) => Offset((x - ox) * s, (oy - y) * s);
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.0, longSide / 2600)
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  for (final p in d.paths) {
    final path = Path();
    final f = map(p.points.first.$1, p.points.first.$2);
    path.moveTo(f.dx, f.dy);
    for (var k = 1; k < p.points.length; k++) {
      final q = map(p.points[k].$1, p.points[k].$2);
      path.lineTo(q.dx, q.dy);
    }
    if (p.closed) path.close();
    c.drawPath(path, paint..color = Color(0xFF000000 | p.color));
  }
  for (final t in d.texts) {
    final px = t.height * s;
    if (px < 2) continue; // 너무 작은 글자는 점으로도 안 보인다
    final tp = TextPainter(
      text: TextSpan(text: t.text, style: TextStyle(fontSize: px, color: Color(0xFF000000 | t.color), height: 1.0)),
      textDirection: TextDirection.ltr,
    )..layout();
    final o = map(t.x, t.y);
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(-t.rotation);
    tp.paint(c, Offset(0, -tp.height));
    c.restore();
  }
  final pic = rec.endRecording();
  final img = await pic.toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return (data!.buffer.asUint8List(), w, h);
}
