// 철판 입체(3D) 보기(10-10): plate_3d.dart가 만든 면들을 돌려 가며 본다. 한 손가락으로 끌면 돌아가고,
// 두 손가락으로 확대·이동, 두 번 누르면 처음 모습. 입체·위·앞·옆 칩. 먼 면부터 그리고(화가 순서),
// 뒤를 향한 면은 빼며, 빛 방향에 따라 면 밝기를 달리한다. 보기 전용(고치는 것은 다른 탭에서).
// 10-10 화면 정리: 따로 탭이 아니라 철판 화면 위 그림 칸 안에서 "3D"를 고르면 이것이 나온다(크기 글·칩은 그림 왼쪽 아래).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../../core/theme/field_view.dart';
import 'plate_3d.dart';
import 'plate_calc.dart';
import 'plate_ui.dart';

class Plate3dView extends StatefulWidget {
  const Plate3dView({super.key, required this.plan, required this.t})
    : mesh = null,
      info = null;

  /// 다른 화면이 만든 면들을 그대로 돌려 본다(형강 브라켓, 10-11). [info]는 크기 줄 대신 쓰는 글.
  const Plate3dView.mesh({
    super.key,
    required List<Plate3dFace> this.mesh,
    this.info,
  }) : plan = null,
       t = 0;

  final PlatePlan? plan;
  final double t;
  final List<Plate3dFace>? mesh;
  final String? info;

  @override
  State<Plate3dView> createState() => _Plate3dViewState();
}

/// 보기 방향(라디안): [yaw] z축 둘레, [pitch] 위에서 내려다보는 정도.
const _iso = (-0.65, 0.55);

/// 끄는 1px당 도는 각(라디안).
const _turn = 0.006;

/// 칩 네 방향(입체·위·앞·옆): 화면 맞춤 크기를 이 넷에서 정한다.
const _presets = [_iso, (0.0, math.pi / 2), (0.0, 0.0), (-math.pi / 2, 0.0)];

class _Plate3dViewState extends State<Plate3dView> {
  double _yaw = _iso.$1, _pitch = _iso.$2;
  double _zoom = 1, _zoom0 = 1;
  Offset _pan = Offset.zero;

  PlatePlan? _forPlan;
  double _forT = 0;
  List<Plate3dFace> _faces = const [];

  List<Plate3dFace> get _mesh {
    final given = widget.mesh;
    if (given != null) return given;
    if (!identical(_forPlan, widget.plan) || _forT != widget.t) {
      _forPlan = widget.plan;
      _forT = widget.t;
      _faces = plate3dMesh(widget.plan!, t: widget.t);
    }
    return _faces;
  }

  void _view(double yaw, double pitch) => setState(() {
    _yaw = yaw;
    _pitch = pitch;
    _zoom = 1;
    _pan = Offset.zero;
  });

  bool _is(double yaw, double pitch) =>
      (_yaw - yaw).abs() < 1e-3 && (_pitch - pitch).abs() < 1e-3;

  PlateOption _seg(String key, String label, double yaw, double pitch) =>
      PlateOption(
        key,
        label,
        _is(yaw, pitch) && _zoom == 1 && _pan == Offset.zero,
        () => _view(yaw, pitch),
      );

  @override
  Widget build(BuildContext context) {
    final faces = _mesh;
    final (lo, hi) = faces.isEmpty
        ? (vm.Vector3.zero(), vm.Vector3.zero())
        : plate3dBounds(faces);
    final size =
        widget.info ??
        '${_f(hi.x - lo.x)} × ${_f(hi.y - lo.y)} × ${_f(hi.z - lo.z)} mm (두께 ${_f(widget.t)})';
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const Key('p3_canvas'),
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () => _view(_iso.$1, _iso.$2),
            onScaleStart: (_) => _zoom0 = _zoom,
            onScaleUpdate: (d) => setState(() {
              if (d.pointerCount >= 2) {
                _zoom = (_zoom0 * d.scale).clamp(0.3, 8.0);
                _pan += d.focalPointDelta;
              } else {
                // 화면 폭만큼 끌면 한 바퀴 안팎
                _yaw += d.focalPointDelta.dx * _turn;
                _pitch = (_pitch + d.focalPointDelta.dy * _turn).clamp(
                  -math.pi / 2,
                  math.pi / 2,
                );
              }
            }),
            child: CustomPaint(
              painter: _Plate3dPainter(
                faces: faces,
                yaw: _yaw,
                pitch: _pitch,
                zoom: _zoom,
                pan: _pan,
                colors: fc,
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 52,
          child: IgnorePointer(
            child: Text(
              '$size\n끌어서 돌리기 · 두 손가락 확대·이동 · 두 번 누르면 처음',
              key: const Key('p3_info'),
              style: TextStyle(
                color: fc.textSub,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ),
        Positioned(
          left: 10,
          bottom: 10,
          child: PlateViewSwitch([
            _seg('p3_iso', '입체', _iso.$1, _iso.$2),
            _seg('p3_top', '위', 0, math.pi / 2),
            _seg('p3_front', '앞', 0, 0),
            _seg('p3_side', '옆', -math.pi / 2, 0),
          ]),
        ),
      ],
    );
  }
}

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s == '-0' ? '0' : s;
}

class _Plate3dPainter extends CustomPainter {
  _Plate3dPainter({
    required this.faces,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.pan,
    required this.colors,
  });

  final List<Plate3dFace> faces;
  final double yaw, pitch, zoom;
  final Offset pan;
  final FieldPalette colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty) return;
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final cp = math.cos(pitch), sp = math.sin(pitch);
    // z축 둘레로 yaw, x축 둘레로 pitch. 화면 x = 돌린 x, 화면 위 = 돌린 z, 깊이 = 돌린 y(클수록 멀다)
    vm.Vector3 rot(vm.Vector3 v) {
      final x1 = v.x * cy - v.y * sy, y1 = v.x * sy + v.y * cy, z1 = v.z;
      return vm.Vector3(x1, y1 * cp - z1 * sp, y1 * sp + z1 * cp);
    }

    // 화면에 맞추기: 입체·위·앞·옆 네 방향에서 본 크기 중 가장 큰 것에 맞춘다
    // (지금 방향으로 맞추면 돌릴 때마다 커졌다 작아졌다 하고, 감싸는 공으로 맞추면 평판이 작게 보인다)
    final (lo, hi) = plate3dBounds(faces);
    final mid0 = (lo + hi) * 0.5;
    var bw = 1e-6, bh = 1e-6;
    for (final (y0, p0) in _presets) {
      final cy0 = math.cos(y0), sy0 = math.sin(y0);
      final cp0 = math.cos(p0), sp0 = math.sin(p0);
      for (final f in faces) {
        for (final q in f.loop) {
          final v = q - mid0;
          final x1 = v.x * cy0 - v.y * sy0, y1 = v.x * sy0 + v.y * cy0;
          bw = math.max(bw, 2 * x1.abs());
          bh = math.max(bh, 2 * (y1 * sp0 + v.z * cp0).abs());
        }
      }
    }
    final c = rot(mid0);
    const margin = 20.0;
    final s =
        math.min(
          (size.width - 2 * margin) / bw,
          (size.height - 2 * margin - 70) / bh,
        ) *
        zoom;
    final mid = Offset(size.width / 2, size.height / 2 - 20) + pan;
    Offset scr(vm.Vector3 r) => mid + Offset((r.x - c.x) * s, (c.z - r.z) * s);

    // 빛: 보는 쪽 왼쪽 위에서
    final light = vm.Vector3(-0.35, -0.7, 0.62)..normalize();
    final items = <(double, Plate3dFace, vm.Vector3, List<vm.Vector3>)>[];
    for (final f in faces) {
      final n = rot(f.normal);
      if (n.y >= -1e-6) continue; // 뒤를 향한 면
      final pts = [for (final q in f.loop) rot(q)];
      var depth = 0.0;
      for (final r in pts) {
        depth += r.y;
      }
      items.add((depth / pts.length, f, n, pts));
    }
    items.sort((a, b) => b.$1.compareTo(a.$1)); // 먼 것부터

    final night = FieldColors.isNight;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = (night ? const Color(0xFFAEBCC6) : const Color(0xFF3E4C55))
          .withValues(alpha: night ? 0.4 : 0.55);
    for (final (_, f, n, pts) in items) {
      // 빛 쪽을 향할수록 밝게(빛 벡터는 면에서 빛 쪽)
      final lit = 0.45 + 0.55 * math.max(0.0, n.dot(light));
      // 야간 보기는 어두운 철 색(밤에 눈부심 줄임, 10-11)
      final base = night
          ? switch (f.kind) {
              0 => const Color(0xFF6E7C86),
              1 => const Color(0xFF5E6C76),
              _ => const Color(0xFF46525B),
            }
          : switch (f.kind) {
              0 => const Color(0xFFB4C2CB),
              1 => const Color(0xFF9AA9B3),
              _ => const Color(0xFF66747E),
            };
      final col = Color.lerp(
        const Color(0xFF26323A),
        base,
        lit.clamp(0.0, 1.0),
      )!;
      final path = Path()..fillType = PathFillType.evenOdd;
      path.addPolygon([for (final r in pts) scr(r)], true);
      for (final hl in f.holes) {
        path.addPolygon([for (final q in hl) scr(rot(q))], true);
      }
      canvas.drawPath(path, Paint()..color = col);
      if (f.kind != 2) canvas.drawPath(path, edge);
    }
  }

  @override
  bool shouldRepaint(covariant _Plate3dPainter old) =>
      old.faces != faces ||
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.zoom != zoom ||
      old.pan != pan ||
      old.colors != colors;
}
