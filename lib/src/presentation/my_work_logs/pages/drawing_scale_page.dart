import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/drawing_scale.dart';
import '../widgets/korean_text.dart';
import '../widgets/layout_board_ui.dart';

// 🚀 축척 맞추기: 배경 사진(카톡으로 받은 도면 등)에서 판 왼쪽 위·오른쪽 아래 모서리를 찍고
// 실제 가로·세로(mm)를 넣으면, 사진이 배치도에 실제 크기로 깔린다. 폰 안에서만 셈한다(통신 없음).

class DrawingScaleResult {
  /// 배치도 mm 좌표에서 사진이 차지할 네모.
  final Rect rect;
  final double widthMm;
  final double heightMm;
  const DrawingScaleResult(this.rect, this.widthMm, this.heightMm);
}

class DrawingScalePage extends StatefulWidget {
  final String imagePath;

  /// 처음 칸에 넣어 둘 판 크기(지금 배치도 크기).
  final double initialWidthMm;
  final double initialHeightMm;

  /// 안내 글에 쓰는 판 이름(캐비닛·스키드·측판…).
  final String targetName;

  /// 사진 픽셀 크기. 테스트에서만 넘긴다(넘기지 않으면 사진을 읽어 잰다).
  final Size? imageSize;

  const DrawingScalePage({
    super.key,
    required this.imagePath,
    required this.initialWidthMm,
    required this.initialHeightMm,
    required this.targetName,
    this.imageSize,
  });

  static Future<DrawingScaleResult?> open(
    BuildContext context, {
    required String imagePath,
    required double widthMm,
    required double heightMm,
    required String targetName,
  }) => Navigator.of(context).push<DrawingScaleResult>(
    MaterialPageRoute(
      builder: (_) => DrawingScalePage(
        imagePath: imagePath,
        initialWidthMm: widthMm,
        initialHeightMm: heightMm,
        targetName: targetName,
      ),
    ),
  );

  @override
  State<DrawingScalePage> createState() => _DrawingScalePageState();
}

class _DrawingScalePageState extends State<DrawingScalePage> {
  Size? _image;
  Offset? _topLeft;
  Offset? _bottomRight;
  final TransformationController _zoom = TransformationController();
  late final TextEditingController _w = TextEditingController(
    text: _fmt(widget.initialWidthMm),
  );
  late final TextEditingController _h = TextEditingController(
    text: _fmt(widget.initialHeightMm),
  );

  static const TextStyle _fieldStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: tossText,
  );

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  void initState() {
    super.initState();
    _image = widget.imageSize;
    if (_image == null) _readImageSize();
    _zoom.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _readImageSize() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final img = await decodeImageFromList(bytes);
      if (mounted) {
        setState(
          () => _image = Size(img.width.toDouble(), img.height.toDouble()),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _image = Size.zero);
    }
  }

  @override
  void dispose() {
    _zoom.dispose();
    _w.dispose();
    _h.dispose();
    super.dispose();
  }

  String get _guide {
    final n = widget.targetName;
    if (_topLeft == null) return "도면에서 $n 왼쪽 위 모서리를 누르십시오.";
    if (_bottomRight == null) return "이제 $n 오른쪽 아래 모서리를 누르십시오.";
    return "실제 가로·세로를 확인하고 맞추기를 누르십시오.";
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim());

  Rect? get _result {
    final img = _image;
    final w = _num(_w), h = _num(_h);
    if (img == null || _topLeft == null || _bottomRight == null) return null;
    if (w == null || h == null) return null;
    return drawingRectFromCorners(
      topLeft: _topLeft!,
      bottomRight: _bottomRight!,
      image: img,
      widthMm: w,
      heightMm: h,
    );
  }

  void _onTap(Offset imagePx) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_topLeft == null) {
        _topLeft = imagePx;
      } else if (_bottomRight == null) {
        _bottomRight = imagePx;
      } else {
        // 둘 다 찍은 뒤 다시 누르면 오른쪽 아래를 고친다.
        _bottomRight = imagePx;
      }
    });
  }

  void _apply() {
    final r = _result;
    if (r == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(keepWords("왼쪽 위를 먼저, 오른쪽 아래를 나중에 찍었는지 확인하십시오.")),
        ),
      );
      return;
    }
    Navigator.of(context).pop(DrawingScaleResult(r, _num(_w)!, _num(_h)!));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossBg,
      appBar: AppBar(
        backgroundColor: pureWhite,
        foregroundColor: tossText,
        elevation: 0,
        title: const Text(
          "축척 맞추기",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: pureWhite,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                keepWords(_guide),
                key: const ValueKey("scale_guide"),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: tossBlue,
                ),
              ),
            ),
            Expanded(child: _buildImage()),
            _buildBottom(),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    final img = _image;
    if (img == null) return const Center(child: CircularProgressIndicator());
    if (img.isEmpty) {
      return Center(
        child: Text(
          keepWords("사진을 읽을 수 없습니다."),
          style: const TextStyle(fontSize: 15, color: tossSubText),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final double k = math.min(
          box.maxWidth / img.width,
          box.maxHeight / img.height,
        );
        final Size shown = Size(img.width * k, img.height * k);
        final double zoom = _zoom.value.getMaxScaleOnAxis();
        return InteractiveViewer(
          transformationController: _zoom,
          minScale: 1,
          maxScale: 20,
          child: Center(
            child: GestureDetector(
              key: const ValueKey("scale_image"),
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _onTap(d.localPosition / k),
              child: SizedBox(
                width: shown.width,
                height: shown.height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.fill,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: pureWhite),
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CornerPainter(
                          topLeft: _topLeft == null ? null : _topLeft! * k,
                          bottomRight: _bottomRight == null
                              ? null
                              : _bottomRight! * k,
                          // 점·글씨는 확대해도 화면에서 같은 크기로.
                          unit: 1 / (zoom <= 0 ? 1 : zoom),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottom() {
    final bool ready = _result != null;
    // 앱 테마가 어두운 테마라 글자색을 밝은 칸에 맞게 직접 준다.
    InputDecoration deco(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: tossSubText),
      suffixText: "mm",
      suffixStyle: const TextStyle(color: tossSubText),
      filled: true,
      fillColor: tossBg,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
    return Container(
      color: pureWhite,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            keepWords("두 손가락으로 벌려 키우면 모서리를 정확히 찍을 수 있습니다."),
            style: const TextStyle(fontSize: 14, color: tossSubText),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey("scale_width"),
                  controller: _w,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: _fieldStyle,
                  decoration: deco("실제 가로"),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const ValueKey("scale_height"),
                  controller: _h,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: _fieldStyle,
                  decoration: deco("실제 세로"),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey("scale_retry"),
                  onPressed: _topLeft == null
                      ? null
                      : () => setState(() {
                          _topLeft = null;
                          _bottomRight = null;
                        }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tossBlue,
                    side: const BorderSide(color: tossBlue),
                    minimumSize: const Size(40, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "다시 찍기",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: const ValueKey("scale_apply"),
                  onPressed: ready ? _apply : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: tossBlue,
                    foregroundColor: pureWhite,
                    disabledBackgroundColor: layoutLine,
                    disabledForegroundColor: tossSubText,
                    minimumSize: const Size(40, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "맞추기",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 찍은 모서리 표시: 십자선 + 동그라미 + 번호(1 왼쪽 위, 2 오른쪽 아래), 두 점을 이은 네모.
class _CornerPainter extends CustomPainter {
  final Offset? topLeft;
  final Offset? bottomRight;
  final double unit;
  const _CornerPainter({this.topLeft, this.bottomRight, required this.unit});

  static const Color _c = Color(0xFFF04438);

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = _c
      ..strokeWidth = 1.5 * unit
      ..style = PaintingStyle.stroke;
    if (topLeft != null && bottomRight != null) {
      canvas.drawRect(
        Rect.fromPoints(topLeft!, bottomRight!),
        Paint()
          ..color = _c.withValues(alpha: 0.6)
          ..strokeWidth = 1.5 * unit
          ..style = PaintingStyle.stroke,
      );
    }
    void mark(Offset p, String n) {
      canvas.drawLine(p - Offset(18 * unit, 0), p + Offset(18 * unit, 0), line);
      canvas.drawLine(p - Offset(0, 18 * unit), p + Offset(0, 18 * unit), line);
      canvas.drawCircle(p, 9 * unit, line);
      final tp = TextPainter(
        text: TextSpan(
          text: n,
          style: TextStyle(
            color: pureWhite,
            fontSize: 12 * unit,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final Offset c = p + Offset(20 * unit, -20 * unit);
      canvas.drawCircle(c, 10 * unit, Paint()..color = _c);
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }

    if (topLeft != null) mark(topLeft!, "1");
    if (bottomRight != null) mark(bottomRight!, "2");
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) =>
      old.topLeft != topLeft ||
      old.bottomRight != bottomRight ||
      old.unit != unit;
}
