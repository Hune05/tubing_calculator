import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../models/layout_board_models.dart';
import '../models/skid_iso.dart';
import '../models/skid_route.dart';

// 🚀 스키드 입체 보기(보기 전용). 평면에 놓은 부품과 전선관 경로를 그대로 세워 한 화면에 보여 준다.
// 한 손가락으로 돌리고, 두 손가락으로 확대·이동하고, 부품을 누르면 이름과 크기가 나온다.
// 계산은 models/skid_iso.dart, 이 파일은 그리기와 손가락 움직임만 맡는다.

/// 그리는 동안 알아낸 "어디를 누르면 어느 부품인가". 그린 차례대로 쌓이고 마지막이 맨 앞이다.
class IsoHits {
  final List<(String, Path)> shapes = [];
  void clear() => shapes.clear();

  String? partAt(Offset p) {
    for (var i = shapes.length - 1; i >= 0; i--) {
      if (shapes[i].$2.contains(p)) return shapes[i].$1;
    }
    return null;
  }
}

Color _shade(Color c, double f) {
  int ch(double v) => (v * f).round().clamp(0, 255);
  return Color.fromARGB(
    255,
    ch((c.r * 255)),
    ch((c.g * 255)),
    ch((c.b * 255)),
  );
}

class _Chunk {
  final double near;
  final IsoBox? box;
  final IsoPipe? pipe;
  _Chunk(this.near, {this.box, this.pipe});
}

/// 긴 상자·관은 가려지는 차례가 틀어지지 않게 길이 방향으로 잘라 따로 줄 세운다.
const int _kSplitOffAbove = 700; // 조각이 이만큼 넘게 많으면 자르지 않는다(느려지지 않게).

class SkidIsoPainter extends CustomPainter {
  final IsoScene scene;
  final IsoView view;
  final double zoom;
  final Offset pan;
  final String? selectedId;
  final IsoHits hits;
  final Color floorColor;
  final Color gridColor;
  final Color edgeColor;
  final Color accent;

  SkidIsoPainter({
    required this.scene,
    required this.view,
    required this.zoom,
    required this.pan,
    required this.selectedId,
    required this.hits,
    required this.floorColor,
    required this.gridColor,
    required this.edgeColor,
    required this.accent,
  });

  /// 상자 하나를 길이 방향(가장 긴 수평 변)으로 조각낸다.
  List<IsoBox> _splitBox(IsoBox b, bool allow) {
    if (!allow) return [b];
    final double lx = b.x1 - b.x0, ly = b.y1 - b.y0;
    final bool alongX = lx >= ly;
    final double len = alongX ? lx : ly;
    final double other = alongX ? ly : lx;
    final double step = math.max(other * 2, 400);
    final int n = math.min(8, (len / step).ceil());
    if (n <= 1) return [b];
    return [
      for (var i = 0; i < n; i++)
        alongX
            ? IsoBox(
                b.x0 + len * i / n,
                b.y0,
                b.z0,
                b.x0 + len * (i + 1) / n,
                b.y1,
                b.z1,
                b.color,
                partId: b.partId,
                cutLo: i > 0,
                cutHi: i < n - 1,
                cutAlongX: true,
              )
            : IsoBox(
                b.x0,
                b.y0 + len * i / n,
                b.z0,
                b.x1,
                b.y0 + len * (i + 1) / n,
                b.z1,
                b.color,
                partId: b.partId,
                cutLo: i > 0,
                cutHi: i < n - 1,
                cutAlongX: false,
              ),
    ];
  }

  List<IsoPipe> _splitPipe(IsoPipe p, bool allow) {
    if (!allow) return [p];
    final vm.Vector3 d = p.b - p.a;
    final double len = d.length;
    final int n = math.min(8, (len / math.max(p.od * 8, 400)).ceil());
    if (n <= 1) return [p];
    return [
      for (var i = 0; i < n; i++)
        IsoPipe(
          p.a + d * (i / n),
          p.a + d * ((i + 1) / n),
          p.od,
          p.color,
          partId: p.partId,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    hits.clear();
    final b = scene.bounds;
    final vm.Vector3 c = (b.min + b.max) * 0.5;
    double r = (b.max - b.min).length / 2;
    if (r <= 0) r = 1;
    final double scale = math.min(size.width, size.height) / 2 * 0.9 / r * zoom;
    final Offset origin = Offset(size.width / 2, size.height / 2) + pan;
    Offset pt(double x, double y, double z) {
      final q = view.project(vm.Vector3(x, y, z), c);
      return Offset(origin.dx + q.sx * scale, origin.dy + q.sy * scale);
    }

    // ── 바닥 ──
    final double fl = scene.floorLength, fw = scene.floorWidth;
    if (fl > 0 && fw > 0) {
      final floor = Path()
        ..moveTo(pt(0, 0, 0).dx, pt(0, 0, 0).dy)
        ..lineTo(pt(fl, 0, 0).dx, pt(fl, 0, 0).dy)
        ..lineTo(pt(fl, fw, 0).dx, pt(fl, fw, 0).dy)
        ..lineTo(pt(0, fw, 0).dx, pt(0, fw, 0).dy)
        ..close();
      canvas.drawPath(floor, Paint()..color = floorColor);
      final grid = Paint()
        ..color = gridColor
        ..strokeWidth = 0.6
        ..style = PaintingStyle.stroke;
      final double step = niceGridStep(math.max(fl, fw));
      for (double x = step; x < fl - 1e-6; x += step) {
        canvas.drawLine(pt(x, 0, 0), pt(x, fw, 0), grid);
      }
      for (double y = step; y < fw - 1e-6; y += step) {
        canvas.drawLine(pt(0, y, 0), pt(fl, y, 0), grid);
      }
      canvas.drawPath(
        floor,
        Paint()
          ..color = edgeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // ── 조각 줄 세우기(먼 것부터) ──
    final bool allowSplit = scene.boxes.length + scene.pipes.length < _kSplitOffAbove;
    final chunks = <_Chunk>[];
    for (final box in scene.boxes) {
      for (final s in _splitBox(box, allowSplit)) {
        final q = view.project(vm.Vector3(s.cx, s.cy, s.cz), c);
        chunks.add(_Chunk(q.near, box: s));
      }
    }
    for (final pipe in scene.pipes) {
      for (final s in _splitPipe(pipe, allowSplit)) {
        final m = (s.a + s.b) * 0.5;
        chunks.add(_Chunk(view.project(m, c).near, pipe: s));
      }
    }
    chunks.sort((a, b) => a.near.compareTo(b.near));

    final double cyw = math.cos(view.yaw), syw = math.sin(view.yaw);
    final bool showTop = view.pitch > 0.01;

    // 상자 한 면을 그린다. [v]는 네 모서리(스키드 좌표). 길이 방향으로 자른 이음 자리의 테두리는 긋지 않는다.
    void drawFace(
      IsoBox bx,
      List<(double, double, double)> v,
      Color fill,
    ) {
      final pts = [for (final q in v) pt(q.$1, q.$2, q.$3)];
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = fill);
      // 조각 사이 틈이 비쳐 보이지 않게 같은 색으로 살짝 덮는다.
      canvas.drawPath(
        path,
        Paint()
          ..color = fill
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      final bool sel = bx.partId != null && bx.partId == selectedId;
      final edge = Paint()
        ..color = sel ? accent : edgeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = sel ? 1.8 : 0.6
        ..strokeCap = StrokeCap.round;
      bool onCut(double a, double b, double lo, double hi) =>
          (bx.cutLo && a == lo && b == lo) || (bx.cutHi && a == hi && b == hi);
      for (var i = 0; i < 4; i++) {
        final a = v[i], b = v[(i + 1) % 4];
        final bool seam = bx.cutAlongX
            ? onCut(a.$1, b.$1, bx.x0, bx.x1)
            : onCut(a.$2, b.$2, bx.y0, bx.y1);
        if (!seam) canvas.drawLine(pts[i], pts[(i + 1) % 4], edge);
      }
      if (bx.partId != null) hits.shapes.add((bx.partId!, path));
    }

    for (final ch in chunks) {
      final bx = ch.box;
      if (bx != null) {
        // 옆면: (법선 x, 법선 y, 네 모서리)
        final x0 = bx.x0, x1 = bx.x1, y0 = bx.y0, y1 = bx.y1;
        final z0 = bx.z0, z1 = bx.z1;
        final sides = <(double, double, List<(double, double, double)>)>[
          (-1, 0, [(x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1)]),
          (1, 0, [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)]),
          (0, -1, [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)]),
          (0, 1, [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)]),
        ];
        for (final s in sides) {
          // 잘린 이음 면은 안쪽이라 그리지 않는다.
          if (bx.cutAlongX) {
            if ((s.$1 == -1 && bx.cutLo) || (s.$1 == 1 && bx.cutHi)) continue;
          } else {
            if ((s.$2 == -1 && bx.cutLo) || (s.$2 == 1 && bx.cutHi)) continue;
          }
          final double nyr = s.$1 * syw + s.$2 * cyw;
          if (nyr <= 1e-6) continue;
          final double nxr = s.$1 * cyw - s.$2 * syw;
          drawFace(bx, s.$3, _shade(bx.color, 0.74 - 0.16 * nxr));
        }
        if (showTop) {
          drawFace(
            bx,
            [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
            _shade(bx.color, 1.0),
          );
        }
        continue;
      }
      final p = ch.pipe!;
      final Offset a = pt(p.a.x, p.a.y, p.a.z), e = pt(p.b.x, p.b.y, p.b.z);
      final double w = math.max(p.od * scale, 2.5);
      final bool sel = p.partId != null && p.partId == selectedId;
      if (sel) {
        canvas.drawLine(
          a,
          e,
          Paint()
            ..color = accent
            ..strokeWidth = w + 4
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawLine(
        a,
        e,
        Paint()
          ..color = _shade(p.color, 0.85)
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        a.translate(0, -w * 0.18),
        e.translate(0, -w * 0.18),
        Paint()
          ..color = const Color(0x59FFFFFF)
          ..strokeWidth = w * 0.3
          ..strokeCap = StrokeCap.round,
      );
      if (p.partId != null) {
        final Offset d = e - a;
        final double len = d.distance;
        final Offset nrm = len < 1e-6 ? Offset(0, w / 2) : Offset(-d.dy / len * w / 2, d.dx / len * w / 2);
        final quad = Path()
          ..moveTo((a + nrm).dx, (a + nrm).dy)
          ..lineTo((e + nrm).dx, (e + nrm).dy)
          ..lineTo((e - nrm).dx, (e - nrm).dy)
          ..lineTo((a - nrm).dx, (a - nrm).dy)
          ..close();
        hits.shapes.add((p.partId!, quad));
      }
    }
  }

  @override
  bool shouldRepaint(covariant SkidIsoPainter old) =>
      old.scene != scene ||
      old.view.yaw != view.yaw ||
      old.view.pitch != view.pitch ||
      old.zoom != zoom ||
      old.pan != pan ||
      old.selectedId != selectedId ||
      old.floorColor != floorColor;
}

class SkidIsoPage extends StatefulWidget {
  /// 평면 부품(메모 포함, 메모는 걸러서 그린다).
  final List<PlacedItem> plan;
  final List<ConduitRoute> routes;

  /// 스키드 평면 크기(길이 × 폭, mm).
  final double length;
  final double width;

  const SkidIsoPage({
    super.key,
    required this.plan,
    required this.routes,
    required this.length,
    required this.width,
  });

  @override
  State<SkidIsoPage> createState() => _SkidIsoPageState();
}

class _SkidIsoPageState extends State<SkidIsoPage> {
  late final IsoScene _scene = buildSkidIsoScene(
    widget.plan,
    widget.routes,
    length: widget.length,
    width: widget.width,
  );
  final IsoHits _hits = IsoHits();
  IsoView _view = IsoView.standard;
  double _zoom = 1;
  double _zoom0 = 1;
  Offset _pan = Offset.zero;
  String? _selected;

  static const _presets = <(String, String, IsoView)>[
    ('iso_standard', '입체', IsoView.standard),
    ('iso_front', '정면', IsoView.front),
    ('iso_right', '오른쪽', IsoView.right),
    ('iso_left', '왼쪽', IsoView.left),
    ('iso_back', '뒤', IsoView.back),
    ('iso_top', '위', IsoView.top),
  ];

  void _setView(IsoView v) => setState(() {
    _view = v;
    _zoom = 1;
    _pan = Offset.zero;
  });

  bool _isPreset(IsoView v) =>
      (_view.yaw - v.yaw).abs() < 1e-6 && (_view.pitch - v.pitch).abs() < 1e-6;

  PlacedItem? get _selectedItem {
    for (final it in widget.plan) {
      if (it.id == _selected) return it;
    }
    return null;
  }

  String _mm(double v) => v.round().toString();

  String _info() {
    final it = _selectedItem;
    if (it != null) {
      final double v = skidVerticalSize(it);
      final double zc = it.elevation ?? v / 2;
      return '${it.label}\n'
          '평면 ${_mm(it.width)} × ${_mm(it.height)}mm · 높이 ${_mm(v)}mm · 바닥에서 ${_mm(zc - v / 2)}~${_mm(zc + v / 2)}mm';
    }
    final b = _scene.bounds;
    final d = b.max - b.min;
    return '전체 ${_mm(d.x)} × ${_mm(d.y)} × 높이 ${_mm(b.max.z)}mm\n'
        '부품 ${_scene.partCount}개 · 전선관 경로 ${_scene.routeCount}줄';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('입체 보기')),
      body: SafeArea(
        child: _scene.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '스키드 평면에 놓은 부품이 없습니다.\n형강이나 전선관을 놓으면 여기에 입체로 보입니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                ),
              )
            : Column(
                children: [
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      children: [
                        for (final p in _presets)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              key: Key(p.$1),
                              label: Text(p.$2),
                              selected: _isPreset(p.$3),
                              onSelected: (_) => _setView(p.$3),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => GestureDetector(
                        key: const Key('iso_canvas'),
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: (_) => _zoom0 = _zoom,
                        onScaleUpdate: (d) => setState(() {
                          if (d.pointerCount >= 2) {
                            _zoom = (_zoom0 * d.scale).clamp(0.3, 30.0);
                            _pan += d.focalPointDelta;
                          } else {
                            _view = _view.copyWith(
                              yaw: _view.yaw + d.focalPointDelta.dx * 0.01,
                              pitch: (_view.pitch + d.focalPointDelta.dy * 0.006)
                                  .clamp(0.0, math.pi / 2),
                            );
                          }
                        }),
                        onTapUp: (d) => setState(
                          () => _selected = _hits.partAt(d.localPosition),
                        ),
                        child: CustomPaint(
                          size: Size(box.maxWidth, box.maxHeight),
                          painter: SkidIsoPainter(
                            scene: _scene,
                            view: _view,
                            zoom: _zoom,
                            pan: _pan,
                            selectedId: _selected,
                            hits: _hits,
                            floorColor: dark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFE2E8F0),
                            gridColor: dark
                                ? const Color(0x33FFFFFF)
                                : const Color(0x33000000),
                            edgeColor: dark
                                ? const Color(0x99FFFFFF)
                                : const Color(0x73000000),
                            accent: const Color(0xFFF97316),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    key: const Key('iso_info'),
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _info(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '한 손가락으로 돌리고, 두 손가락으로 키우고 옮깁니다. 보기 전용입니다.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
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
}
