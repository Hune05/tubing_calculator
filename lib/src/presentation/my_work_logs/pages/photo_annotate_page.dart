import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/report_tools.dart';

// 🚀 [사진 표시 그리기] 사진 위에 화살표·직선·사각형·동그라미·자유선·글자(치수 등)를 넣어서
// "여기를 봐 주세요"를 표시한다. 원본은 그대로 두고, 표시가 들어간 사본(PNG)을 새 파일로 저장해 돌려준다.
enum AnnotateTool { arrow, line, rect, circle, pen, text }

/// 굵기 선택지(글자 크기에도 같은 배율을 쓴다).
const List<double> kAnnotateThickness = [0.6, 1.0, 1.8];
const List<String> kAnnotateThicknessLabels = ['가늘게', '보통', '굵게'];

/// 사진 위에 그린 것 하나. 좌표는 사진 크기에 대한 0~1 비율이다.
class AnnotateShape {
  final AnnotateTool tool;
  final Color color;
  final double thickness;
  final String? text;
  final List<Offset> pts;
  AnnotateShape(
    this.tool,
    this.color,
    this.pts, {
    this.thickness = 1.0,
    this.text,
  });
}

class PhotoAnnotatePage extends StatefulWidget {
  final String path;

  /// 시험용: 글자 넣기 창을 거치지 않고 이 글을 바로 쓴다.
  final Future<String?> Function(BuildContext context)? askText;

  /// 시험용: 사진 바이트를 읽는 방법(기본은 앱이 쓰는 방법).
  final Future<Uint8List?> Function(String path)? loader;
  const PhotoAnnotatePage({
    super.key,
    required this.path,
    this.askText,
    this.loader,
  });

  @override
  State<PhotoAnnotatePage> createState() => _PhotoAnnotatePageState();
}

class _PhotoAnnotatePageState extends State<PhotoAnnotatePage> {
  ui.Image? _img;
  bool _failed = false;
  final List<AnnotateShape> _shapes = [];
  AnnotateShape? _cur;
  AnnotateTool _tool = AnnotateTool.arrow;
  Color _color = Colors.red;
  double _thickness = 1.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await (widget.loader ?? loadPhotoBytes)(widget.path);
      if (bytes == null) throw 'no bytes';
      final codec = await ui.instantiateImageCodec(bytes);
      final fr = await codec.getNextFrame();
      if (mounted) setState(() => _img = fr.image);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Offset _norm(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    (local.dy / size.height).clamp(0.0, 1.0),
  );

  Future<String?> _askText() async {
    final custom = widget.askText;
    if (custom != null) return custom(context);
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사진에 넣을 글자'),
        content: TextField(
          key: const Key('annotate_text_field'),
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 150mm, 여기 누설'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            key: const Key('annotate_text_ok'),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('넣기'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  /// 글자 도구: 누른 자리에 글자를 놓는다.
  Future<void> _placeText(Offset local, Size size) async {
    final p = _norm(local, size);
    final text = (await _askText())?.trim() ?? '';
    if (text.isEmpty || !mounted) return;
    setState(
      () => _shapes.add(
        AnnotateShape(
          AnnotateTool.text,
          _color,
          [p],
          thickness: _thickness,
          text: text,
        ),
      ),
    );
  }

  Future<void> _save() async {
    final img = _img;
    if (img == null) return;
    final size = Size(img.width.toDouble(), img.height.toDouble());
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Offset.zero & size);
    AnnotationPainter(img, _shapes, null).paint(c, size);
    final out = await rec.endRecording().toImage(img.width, img.height);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    // 임시 폴더는 정리되므로, 작업 일지에 연결될 파일은 앱 문서 폴더에 둔다.
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/annot_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(data!.buffer.asUint8List());
    if (mounted) Navigator.pop(context, file.path);
  }

  String _toolLabel(AnnotateTool t) => switch (t) {
    AnnotateTool.arrow => '화살표',
    AnnotateTool.line => '직선',
    AnnotateTool.rect => '사각형',
    AnnotateTool.circle => '동그라미',
    AnnotateTool.pen => '자유선',
    AnnotateTool.text => '글자',
  };

  @override
  Widget build(BuildContext context) {
    final img = _img;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("표시하기"),
        actions: [
          IconButton(
            tooltip: "되돌리기",
            icon: const Icon(AppIcons.undo),
            onPressed: _shapes.isEmpty
                ? null
                : () => setState(_shapes.removeLast),
          ),
          TextButton(
            key: const Key('annotate_save'),
            onPressed: img == null ? null : _save,
            child: const Text(
              "저장",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _failed
          ? const Center(
              child: Text(
                "사진을 불러오지 못했습니다.",
                style: TextStyle(color: Colors.white70),
              ),
            )
          : img == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: img.width / img.height,
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final size = Size(box.maxWidth, box.maxHeight);
                          return GestureDetector(
                            key: const Key('annotate_canvas'),
                            onTapUp: _tool == AnnotateTool.text
                                ? (d) => _placeText(d.localPosition, size)
                                : null,
                            onPanStart: _tool == AnnotateTool.text
                                ? null
                                : (d) => setState(() {
                                    _cur = AnnotateShape(
                                      _tool,
                                      _color,
                                      [_norm(d.localPosition, size)],
                                      thickness: _thickness,
                                    );
                                  }),
                            onPanUpdate: _tool == AnnotateTool.text
                                ? null
                                : (d) => setState(() {
                                    final p = _norm(d.localPosition, size);
                                    final s = _cur;
                                    if (s == null) return;
                                    if (s.tool == AnnotateTool.pen) {
                                      s.pts.add(p);
                                    } else if (s.pts.length == 1) {
                                      s.pts.add(p);
                                    } else {
                                      s.pts[1] = p;
                                    }
                                  }),
                            onPanEnd: _tool == AnnotateTool.text
                                ? null
                                : (_) => setState(() {
                                    final s = _cur;
                                    if (s != null && s.pts.length > 1) {
                                      _shapes.add(s);
                                    }
                                    _cur = null;
                                  }),
                            child: CustomPaint(
                              painter: AnnotationPainter(img, _shapes, _cur),
                              size: size,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    color: const Color(0xFF1B1F24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final t in AnnotateTool.values)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    key: Key('annotate_tool_${t.name}'),
                                    label: Text(_toolLabel(t)),
                                    selected: _tool == t,
                                    showCheckmark: false,
                                    onSelected: (_) =>
                                        setState(() => _tool = t),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (var i = 0; i < kAnnotateThickness.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  key: Key('annotate_thick_$i'),
                                  label: Text(kAnnotateThicknessLabels[i]),
                                  selected: _thickness == kAnnotateThickness[i],
                                  showCheckmark: false,
                                  onSelected: (_) => setState(
                                    () => _thickness = kAnnotateThickness[i],
                                  ),
                                ),
                              ),
                            const Spacer(),
                            for (final col in [
                              Colors.red,
                              Colors.yellow,
                              Colors.lightBlueAccent,
                              Colors.white,
                              Colors.black,
                            ])
                              GestureDetector(
                                onTap: () => setState(() => _color = col),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: col,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _color == col
                                          ? Colors.grey.shade400
                                          : Colors.white24,
                                      width: _color == col ? 3 : 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// 사진과 그 위의 표시를 그린다(화면·저장 둘 다 이걸 쓴다).
class AnnotationPainter extends CustomPainter {
  final ui.Image img;
  final List<AnnotateShape> shapes;
  final AnnotateShape? cur;
  AnnotationPainter(this.img, this.shapes, this.cur);

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: img,
      fit: BoxFit.fill,
    );
    final baseStroke = math.max(3.0, size.width * 0.007);
    for (final s in [...shapes, ?cur]) {
      final stroke = baseStroke * s.thickness;
      final pts = [
        for (final p in s.pts) Offset(p.dx * size.width, p.dy * size.height),
      ];
      if (s.tool == AnnotateTool.text) {
        if (pts.isNotEmpty && (s.text ?? '').isNotEmpty) {
          _paintText(canvas, size, s, pts.first);
        }
        continue;
      }
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (pts.length < 2) continue;
      switch (s.tool) {
        case AnnotateTool.pen:
          final path = Path()..moveTo(pts.first.dx, pts.first.dy);
          for (final p in pts.skip(1)) {
            path.lineTo(p.dx, p.dy);
          }
          canvas.drawPath(path, paint);
        case AnnotateTool.circle:
          canvas.drawOval(Rect.fromPoints(pts.first, pts.last), paint);
        case AnnotateTool.rect:
          canvas.drawRect(Rect.fromPoints(pts.first, pts.last), paint);
        case AnnotateTool.line:
          canvas.drawLine(pts.first, pts.last, paint);
        case AnnotateTool.arrow:
          final a = pts.first, b = pts.last;
          canvas.drawLine(a, b, paint);
          final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
          final head = stroke * 5;
          for (final da in [math.pi * 5 / 6, -math.pi * 5 / 6]) {
            canvas.drawLine(
              b,
              Offset(
                b.dx + head * math.cos(ang + da),
                b.dy + head * math.sin(ang + da),
              ),
              paint,
            );
          }
        case AnnotateTool.text:
          break;
      }
    }
  }

  // 글자는 사진 위에서 잘 읽히도록 반대색 테두리를 두른다.
  void _paintText(Canvas canvas, Size size, AnnotateShape s, Offset at) {
    final fontSize = math.max(14.0, size.width * 0.045) * s.thickness;
    final outline = s.color.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
    TextPainter tp(Paint? foreground, Color? color) => TextPainter(
      text: TextSpan(
        text: s.text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          foreground: foreground,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.9);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = fontSize * 0.18
      ..strokeJoin = StrokeJoin.round
      ..color = outline;
    final back = tp(stroke, null);
    final front = tp(null, s.color);
    // 누른 곳이 글자 가운데가 되게 놓고, 사진 밖으로 나가지 않게 안으로 밀어 넣는다.
    var x = at.dx - front.width / 2;
    var y = at.dy - front.height / 2;
    x = x.clamp(0.0, math.max(0.0, size.width - front.width));
    y = y.clamp(0.0, math.max(0.0, size.height - front.height));
    back.paint(canvas, Offset(x, y));
    front.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter old) => true;
}
