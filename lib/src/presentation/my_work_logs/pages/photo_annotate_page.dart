import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/report_tools.dart';

// 🚀 [사진 표시 그리기] 사진 위에 화살표·동그라미·자유선을 그려서 "여기를 봐 주세요"를 표시한다.
// 원본은 그대로 두고, 표시가 들어간 사본(PNG)을 새 파일로 저장해 돌려준다.
enum _Tool { arrow, circle, pen }

class _Shape {
  final _Tool tool;
  final Color color;
  final List<Offset> pts; // 0~1 비율 좌표
  _Shape(this.tool, this.color, this.pts);
}

class PhotoAnnotatePage extends StatefulWidget {
  final String path;
  const PhotoAnnotatePage({super.key, required this.path});

  @override
  State<PhotoAnnotatePage> createState() => _PhotoAnnotatePageState();
}

class _PhotoAnnotatePageState extends State<PhotoAnnotatePage> {
  ui.Image? _img;
  bool _failed = false;
  final List<_Shape> _shapes = [];
  _Shape? _cur;
  _Tool _tool = _Tool.arrow;
  Color _color = Colors.red;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await loadPhotoBytes(widget.path);
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

  Future<void> _save() async {
    final img = _img;
    if (img == null) return;
    final size = Size(img.width.toDouble(), img.height.toDouble());
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Offset.zero & size);
    _AnnPainter(img, _shapes, null).paint(c, size);
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
            icon: const Icon(Icons.undo_rounded),
            onPressed: _shapes.isEmpty
                ? null
                : () => setState(_shapes.removeLast),
          ),
          TextButton(
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
                            onPanStart: (d) => setState(() {
                              _cur = _Shape(_tool, _color, [
                                _norm(d.localPosition, size),
                              ]);
                            }),
                            onPanUpdate: (d) => setState(() {
                              final p = _norm(d.localPosition, size);
                              final s = _cur;
                              if (s == null) return;
                              if (s.tool == _Tool.pen) {
                                s.pts.add(p);
                              } else if (s.pts.length == 1) {
                                s.pts.add(p);
                              } else {
                                s.pts[1] = p;
                              }
                            }),
                            onPanEnd: (_) => setState(() {
                              final s = _cur;
                              if (s != null && s.pts.length > 1) {
                                _shapes.add(s);
                              }
                              _cur = null;
                            }),
                            child: CustomPaint(
                              painter: _AnnPainter(img, _shapes, _cur),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final t in _Tool.values)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(switch (t) {
                                        _Tool.arrow => "화살표",
                                        _Tool.circle => "동그라미",
                                        _Tool.pen => "자유선",
                                      }),
                                      selected: _tool == t,
                                      showCheckmark: false,
                                      onSelected: (_) =>
                                          setState(() => _tool = t),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        for (final col in [
                          Colors.red,
                          Colors.yellow,
                          Colors.lightBlueAccent,
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
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
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

class _AnnPainter extends CustomPainter {
  final ui.Image img;
  final List<_Shape> shapes;
  final _Shape? cur;
  _AnnPainter(this.img, this.shapes, this.cur);

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: img,
      fit: BoxFit.fill,
    );
    final stroke = math.max(3.0, size.width * 0.007);
    for (final s in [...shapes, ?cur]) {
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final pts = [
        for (final p in s.pts) Offset(p.dx * size.width, p.dy * size.height),
      ];
      if (pts.length < 2) continue;
      switch (s.tool) {
        case _Tool.pen:
          final path = Path()..moveTo(pts.first.dx, pts.first.dy);
          for (final p in pts.skip(1)) {
            path.lineTo(p.dx, p.dy);
          }
          canvas.drawPath(path, paint);
        case _Tool.circle:
          canvas.drawOval(Rect.fromPoints(pts.first, pts.last), paint);
        case _Tool.arrow:
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
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AnnPainter old) => true;
}
