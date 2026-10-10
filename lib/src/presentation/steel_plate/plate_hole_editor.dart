// 철판 구멍 배치 편집(10-10, 사용자: "철판 가공은 배치도처럼 홀 구멍 배치부터 회전까지 다 넣어줘").
// 판(꺾는 것은 전개도) 위에서 구멍을 눌러 놓고, 끌어 옮기고, 모눈·다른 구멍·판 가운데에 맞추고(안내선),
// 여러 개 골라 복제·지우기·줄 맞추기·같은 간격·대칭 복사·묶음 회전, 장공 각도 돌리기, 원형 배치(PCD),
// 판 90° 돌리기, 되돌리기·다시 하기, 두 손가락 확대·이동. 꺾는 판은 꺾이는 부분을 빗금으로 막아 두고,
// 놓은 구멍이 어느 면의 몇 mm인지 보여 준다(저장은 면 기준이라 면 치수를 바꿔도 따라간다).
// 바뀔 때마다 [PlateHoleEditorPage.onChanged]로 철판 가공 화면에 바로 넘긴다(따로 "저장" 단추 없음).
library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/swipe_to_delete.dart' show showDeleteUndo;
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import '../calculator/widgets/app_dialog.dart';
import '../electrical/busbar_punch_dies.dart' show punchDieLabel;
import 'plate_calc.dart';
import 'plate_painter.dart';

class PlateHoleEditorPage extends StatefulWidget {
  const PlateHoleEditorPage({
    super.key,
    required this.input,
    required this.holes,
    required this.rotQ,
    required this.dies,
    required this.onChanged,
  });

  /// 판 치수(구멍·돌림은 아래 값을 쓴다).
  final PlateInput input;
  final List<PlateHoleSpec> holes;
  final int rotQ;
  final List<double> dies;
  final void Function(List<PlateHoleSpec> holes, int rotQ) onChanged;

  static const gridKey = 'plate_editor_grid_v1';

  @override
  State<PlateHoleEditorPage> createState() => _PlateHoleEditorPageState();
}

String _f(double v, [int d = 1]) {
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  return s == '-0' ? '0' : s;
}

class _PlateHoleEditorPageState extends State<PlateHoleEditorPage>
    with CalcFormParts<PlateHoleEditorPage> {
  late final List<PlateHoleSpec> _holes = List.of(widget.holes);
  late int _rot = widget.rotQ;
  final List<int> _sel = []; // 고른 구멍(고른 차례)
  bool _multi = false;
  bool _place = false;
  double _grid = 5;
  late double _tDia = widget.dies.contains(13.5) ? 13.5 : widget.dies.first;
  double _tSlot = 0;
  double _tAngle = 0;

  final List<(List<PlateHoleSpec>, int)> _undo = [], _redo = [];

  // 보기: 확대 배율과 화면 가운데에서 옮긴 거리
  double _zoom = 1;
  Offset _pan = Offset.zero;
  Size _size = Size.zero;

  // 끌기·확대 중 상태
  int? _lead;
  Map<int, Offset>? _dragFrom; // 구멍 번호 → 끌기 시작 때 화면 자리(mm)
  Offset _focal0 = Offset.zero;
  double _zoom0 = 1;
  Offset _pan0 = Offset.zero;
  bool _panning = false, _pinching = false;
  double? _guideX, _guideY;

  /// 손가락을 처음 댄 자리. 확대·끌기 인식은 조금 움직인 뒤에 시작하므로, 구멍 찾기와 끈 거리는 이 자리에서 잰다.
  Offset? _downAt;

  bool get _bent => plateShapeBends(widget.input.shape);

  PlatePlan get _plan => platePlan(widget.input.withHoles(_holes, rotQ: _rot));

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((p) {
          final g = p.getDouble(PlateHoleEditorPage.gridKey);
          if (g != null && mounted) setState(() => _grid = g);
        })
        .catchError((_) {});
  }

  // ── 좌표 ──

  double _baseScale(PlatePlan p) {
    const m = 40.0;
    final bw = math.max(p.maxX - p.minX, 1.0);
    final bh = math.max(p.maxY - p.minY, 1.0);
    return math.max(
      0.01,
      math.min((_size.width - 2 * m) / bw, (_size.height - 2 * m) / bh),
    );
  }

  double _s(PlatePlan p) => _baseScale(p) * _zoom;

  Offset _center(PlatePlan p) =>
      Offset((p.minX + p.maxX) / 2, (p.minY + p.maxY) / 2);

  Offset _toScreen(PlatePlan p, Offset mm) {
    final s = _s(p), c = _center(p);
    return Offset(_size.width / 2, _size.height / 2) +
        _pan +
        Offset((mm.dx - c.dx) * s, -(mm.dy - c.dy) * s);
  }

  Offset _toMm(PlatePlan p, Offset sc) {
    final s = _s(p), c = _center(p);
    final d = sc - Offset(_size.width / 2, _size.height / 2) - _pan;
    return Offset(d.dx / s + c.dx, -d.dy / s + c.dy);
  }

  double _snapGrid(double v, double origin) =>
      _grid <= 0 ? v : origin + ((v - origin) / _grid).round() * _grid;

  // ── 바꾸기·되돌리기 ──

  void _push() {
    _undo.add((List.of(_holes), _rot));
    if (_undo.length > 80) _undo.removeAt(0);
    _redo.clear();
  }

  void _commit() => widget.onChanged(List.of(_holes), _rot);

  void _change(VoidCallback f) {
    _push();
    setState(f);
    _commit();
  }

  void _undoOnce() {
    if (_undo.isEmpty) return;
    _redo.add((List.of(_holes), _rot));
    final (h, r) = _undo.removeLast();
    setState(() {
      _holes
        ..clear()
        ..addAll(h);
      _rot = r;
      _sel.removeWhere((i) => i >= _holes.length);
    });
    _commit();
  }

  void _redoOnce() {
    if (_redo.isEmpty) return;
    _undo.add((List.of(_holes), _rot));
    final (h, r) = _redo.removeLast();
    setState(() {
      _holes
        ..clear()
        ..addAll(h);
      _rot = r;
      _sel.removeWhere((i) => i >= _holes.length);
    });
    _commit();
  }

  /// 화면 자리(mm) → 저장 구멍(크기·각도는 [like]에서). [dispAngle]은 화면에서 본 장공 각도.
  PlateHoleSpec _specAt(
    PlatePlan p,
    Offset disp,
    PlateHoleSpec like, {
    double? dispAngle,
  }) {
    final (f, u, v) = p.specAt(disp);
    return like.copyWith(
      face: f,
      u: u,
      v: v,
      angle: dispAngle == null
          ? like.angle
          : dispAngle - (_bent ? 0 : 90.0 * _rot),
    );
  }

  // ── 손가락 ──

  int? _hit(PlatePlan p, Offset sc) {
    final s = _s(p);
    for (var i = p.holes.length - 1; i >= 0; i--) {
      final h = p.holes[i];
      final a = _toScreen(p, h.p1), b = _toScreen(p, h.p2);
      final r = math.max(h.r * s, 18.0);
      if (_distSeg(sc, a, b) <= r) return i;
    }
    return null;
  }

  static double _distSeg(Offset q, Offset a, Offset b) {
    final ab = b - a;
    final l2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (l2 == 0) return (q - a).distance;
    final t = (((q - a).dx * ab.dx + (q - a).dy * ab.dy) / l2).clamp(0.0, 1.0);
    return (q - (a + ab * t)).distance;
  }

  void _onTap(TapUpDetails d) {
    final p = _plan;
    final hit = _hit(p, d.localPosition);
    if (_place && hit == null) {
      final mm = _toMm(p, d.localPosition);
      final at = Offset(_snapGrid(mm.dx, p.minX), _snapGrid(mm.dy, p.minY));
      final spec = _specAt(
        p,
        at,
        PlateHoleSpec(
          u: 0,
          v: 0,
          dia: _tDia,
          slot: _tSlot > _tDia ? _tSlot : 0,
        ),
        dispAngle: _tAngle,
      );
      HapticFeedback.selectionClick();
      _change(() {
        _holes.add(spec);
        _sel
          ..clear()
          ..add(_holes.length - 1);
      });
      return;
    }
    setState(() {
      if (hit == null) {
        _sel.clear();
      } else if (_multi) {
        _sel.contains(hit) ? _sel.remove(hit) : _sel.add(hit);
      } else {
        _sel
          ..clear()
          ..add(hit);
      }
    });
  }

  void _onScaleStart(ScaleStartDetails d) {
    final p = _plan;
    _focal0 = d.pointerCount == 1 && _downAt != null
        ? _downAt!
        : d.localFocalPoint;
    _zoom0 = _zoom;
    _pan0 = _pan;
    _pinching = d.pointerCount >= 2;
    _panning = false;
    _lead = null;
    _dragFrom = null;
    if (_pinching) return;
    final hit = _hit(p, _focal0);
    if (hit == null) {
      _panning = true;
      return;
    }
    if (!_sel.contains(hit)) {
      if (!_multi) _sel.clear();
      _sel.add(hit);
    }
    _lead = hit;
    _dragFrom = {for (final i in _sel) i: p.holes[i].c};
    _push();
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final p = _plan;
    if (d.pointerCount >= 2 || _pinching) {
      _pinching = true;
      // 손가락 사이 점이 가리키는 자리를 그대로 두고 확대
      final mm = _toMmWith(p, _focal0, _zoom0, _pan0);
      final z = (_zoom0 * d.scale).clamp(0.5, 16.0);
      final s = _baseScale(p) * z, c = _center(p);
      setState(() {
        _zoom = z;
        _pan =
            d.localFocalPoint -
            Offset(_size.width / 2, _size.height / 2) -
            Offset((mm.dx - c.dx) * s, -(mm.dy - c.dy) * s);
      });
      return;
    }
    if (_panning) {
      setState(() => _pan = _pan0 + (d.localFocalPoint - _focal0));
      return;
    }
    final from = _dragFrom, lead = _lead;
    if (from == null || lead == null) return;
    final s = _s(p);
    final dv = d.localFocalPoint - _focal0;
    var target = from[lead]! + Offset(dv.dx / s, -dv.dy / s);
    target = Offset(_snapGrid(target.dx, p.minX), _snapGrid(target.dy, p.minY));
    // 안내선: 다른 구멍·판 가운데와 가로·세로가 맞으면(화면 8점 안) 붙인다.
    final tol = 8 / s;
    double? gx, gy;
    final xs = <double>[(p.minX + p.maxX) / 2];
    final ys = <double>[(p.minY + p.maxY) / 2];
    for (var i = 0; i < p.holes.length; i++) {
      if (from.containsKey(i)) continue;
      xs.add(p.holes[i].c.dx);
      ys.add(p.holes[i].c.dy);
    }
    for (final x in xs) {
      if ((target.dx - x).abs() <= tol &&
          (gx == null || (target.dx - x).abs() < (target.dx - gx).abs())) {
        gx = x;
      }
    }
    for (final y in ys) {
      if ((target.dy - y).abs() <= tol &&
          (gy == null || (target.dy - y).abs() < (target.dy - gy).abs())) {
        gy = y;
      }
    }
    target = Offset(gx ?? target.dx, gy ?? target.dy);
    final delta = target - from[lead]!;
    setState(() {
      _guideX = gx;
      _guideY = gy;
      for (final e in from.entries) {
        if (e.key >= _holes.length) continue;
        _holes[e.key] = _specAt(p, e.value + delta, _holes[e.key]);
      }
    });
  }

  Offset _toMmWith(PlatePlan p, Offset sc, double zoom, Offset pan) {
    final s = _baseScale(p) * zoom, c = _center(p);
    final d = sc - Offset(_size.width / 2, _size.height / 2) - pan;
    return Offset(d.dx / s + c.dx, -d.dy / s + c.dy);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    final dragged = _dragFrom != null;
    setState(() {
      _guideX = null;
      _guideY = null;
      _dragFrom = null;
      _lead = null;
      _panning = false;
      _pinching = false;
    });
    if (dragged) _commit();
  }

  // ── 고른 구멍 다루기 ──

  List<int> get _selSorted => [..._sel]..sort();

  void _delete() {
    if (_sel.isEmpty) return;
    final n = _sel.length;
    final del = _selSorted.reversed.toList();
    _change(() {
      for (final i in del) {
        _holes.removeAt(i);
      }
      _sel.clear();
    });
    showDeleteUndo(context, '구멍 $n개', onUndo: _undoOnce);
  }

  void _duplicate() {
    final p = _plan;
    final step = _grid > 0 ? math.max(_grid, 10.0) : 10.0;
    final adds = [
      for (final i in _selSorted)
        _specAt(p, p.holes[i].c + Offset(step, 0), _holes[i]),
    ];
    _change(() {
      final start = _holes.length;
      _holes.addAll(adds);
      _sel
        ..clear()
        ..addAll([for (var k = 0; k < adds.length; k++) start + k]);
    });
  }

  /// 고른 장공마다 제자리에서 [deg]만큼 돌린다.
  void _spin(double deg) => _change(() {
    for (final i in _sel) {
      final h = _holes[i];
      _holes[i] = h.copyWith(angle: ((h.angle + deg) % 360 + 360) % 360);
    }
  });

  /// 고른 구멍들을 묶음 가운데를 기준으로 [deg]만큼 돌린다(장공 각도도 같이).
  void _rotateGroup(double deg) {
    final p = _plan;
    final pts = [for (final i in _sel) p.holes[i].c];
    final c = pts.fold(Offset.zero, (a, b) => a + b) / pts.length.toDouble();
    final a = deg * math.pi / 180;
    final ca = math.cos(a), sa = math.sin(a);
    final next = <int, PlateHoleSpec>{};
    for (final i in _sel) {
      final d = p.holes[i].c - c;
      final q = c + Offset(d.dx * ca - d.dy * sa, d.dx * sa + d.dy * ca);
      final h = _holes[i];
      next[i] = _specAt(
        p,
        q,
        h,
      ).copyWith(angle: ((h.angle + deg) % 360 + 360) % 360);
    }
    _change(() => next.forEach((i, s) => _holes[i] = s));
  }

  /// 판 가운데 선을 기준으로 대칭 복사(좌우 = 세로 가운데 선, 상하 = 가로 가운데 선).
  void _mirror(bool leftRight) {
    final p = _plan;
    final cx = (p.minX + p.maxX) / 2, cy = (p.minY + p.maxY) / 2;
    final adds = <PlateHoleSpec>[];
    for (final i in _selSorted) {
      final h = p.holes[i];
      final q = leftRight
          ? Offset(2 * cx - h.c.dx, h.c.dy)
          : Offset(h.c.dx, 2 * cy - h.c.dy);
      final a = leftRight ? 180 - h.angle : -h.angle;
      adds.add(_specAt(p, q, _holes[i], dispAngle: a));
    }
    _change(() {
      final start = _holes.length;
      _holes.addAll(adds);
      _sel
        ..clear()
        ..addAll([for (var k = 0; k < adds.length; k++) start + k]);
    });
  }

  /// 줄 맞추기: 가로 줄(높이를 첫째로 고른 구멍에 맞춤) 또는 세로 줄(가로 자리를 맞춤).
  void _alignRow(bool horizontal) {
    final p = _plan;
    final first = p.holes[_sel.first].c;
    final next = <int, PlateHoleSpec>{};
    for (final i in _sel) {
      final c = p.holes[i].c;
      next[i] = _specAt(
        p,
        horizontal ? Offset(c.dx, first.dy) : Offset(first.dx, c.dy),
        _holes[i],
      );
    }
    _change(() => next.forEach((i, s) => _holes[i] = s));
  }

  /// 같은 간격: 양 끝 구멍은 그대로 두고 그 사이를 고르게(가로 또는 세로).
  void _distribute(bool horizontal) {
    final p = _plan;
    final ids = [..._sel]
      ..sort(
        (a, b) => horizontal
            ? p.holes[a].c.dx.compareTo(p.holes[b].c.dx)
            : p.holes[a].c.dy.compareTo(p.holes[b].c.dy),
      );
    final lo = horizontal ? p.holes[ids.first].c.dx : p.holes[ids.first].c.dy;
    final hi = horizontal ? p.holes[ids.last].c.dx : p.holes[ids.last].c.dy;
    final next = <int, PlateHoleSpec>{};
    for (var k = 0; k < ids.length; k++) {
      final v = lo + (hi - lo) * k / (ids.length - 1);
      final c = p.holes[ids[k]].c;
      next[ids[k]] = _specAt(
        p,
        horizontal ? Offset(v, c.dy) : Offset(c.dx, v),
        _holes[ids[k]],
      );
    }
    _change(() => next.forEach((i, s) => _holes[i] = s));
  }

  // ── 창: 자리·크기, 원형 배치 ──

  Future<void> _editOne() async {
    if (_sel.length != 1) return;
    final p = _plan;
    final i = _sel.first;
    final h = p.holes[i];
    final r = await _numbersDialog(
      title: '구멍 ${i + 1} 자리·크기',
      fields: [
        ('왼쪽 끝에서 (mm)', h.c.dx - p.minX),
        ('아래 끝에서 (mm)', h.c.dy - p.minY),
        ('지름 (mm)', h.dia),
        ('장공 길이 (mm, 0이면 둥근 구멍)', h.slot),
        ('장공 각도 (°, 0 = 가로)', ((h.angle % 360) + 360) % 360),
      ],
    );
    if (r == null || r[2] <= 0) return;
    final spec = _specAt(
      p,
      Offset(p.minX + r[0], p.minY + r[1]),
      _holes[i].copyWith(dia: r[2], slot: r[3] > r[2] ? r[3] : 0),
      dispAngle: r[4],
    );
    _change(() => _holes[i] = spec);
  }

  Future<void> _pcd() async {
    final p = _plan;
    final r = await _numbersDialog(
      title: '원형 배치 (PCD)',
      fields: [
        ('가운데: 왼쪽 끝에서 (mm)', (p.maxX - p.minX) / 2),
        ('가운데: 아래 끝에서 (mm)', (p.maxY - p.minY) / 2),
        ('원 지름 PCD (mm)', math.min(p.maxX - p.minX, p.maxY - p.minY) * 0.6),
        ('구멍 수', 4),
        ('첫 구멍 각도 (°, 0 = 오른쪽)', 45),
        ('구멍 지름 (mm)', _tDia),
      ],
    );
    if (r == null || r[2] <= 0 || r[5] <= 0) return;
    final list = platePcd(
      cu: p.minX + r[0],
      cv: p.minY + r[1],
      pcd: r[2],
      count: r[3].round().clamp(1, 72),
      startDeg: r[4],
      dia: r[5],
    );
    // platePcd는 화면 자리로 만든 것이라 저장 자리로 바꿔 넣는다.
    final adds = [
      for (final s in list)
        _specAt(p, Offset(s.u, s.v), PlateHoleSpec(u: 0, v: 0, dia: s.dia)),
    ];
    _change(() {
      final start = _holes.length;
      _holes.addAll(adds);
      _sel
        ..clear()
        ..addAll([for (var k = 0; k < adds.length; k++) start + k]);
    });
  }

  Future<List<double>?> _numbersDialog({
    required String title,
    required List<(String, double)> fields,
  }) => showDialog<List<double>>(
    context: context,
    builder: (_) => PlateNumbersDialog(title: title, fields: fields),
  );

  void _setGrid(double g) {
    setState(() => _grid = g);
    SharedPreferences.getInstance()
        .then((p) => p.setDouble(PlateHoleEditorPage.gridKey, g))
        .catchError((_) => false);
  }

  // ── 화면 ──

  String _status(PlatePlan p) {
    if (_sel.length == 1) {
      final h = p.holes[_sel.first];
      final face = p.isBent
          ? ' · ${p.faceNames[h.face]} ${_f(h.u)} · ${_f(h.v)}'
          : '';
      return '구멍 ${h.label} ${plateHoleKind(h)}: 왼쪽 ${_f(h.c.dx - p.minX)} · 아래 ${_f(h.c.dy - p.minY)} · 오른쪽 ${_f(p.maxX - h.c.dx)} · 위 ${_f(p.maxY - h.c.dy)}$face';
    }
    if (_sel.length > 1) return '구멍 ${_sel.length}개 고름';
    if (_place) {
      return '판을 누르면 그 자리에 ${_tSlot > _tDia ? '장공 ${_f(_tDia)}×${_f(_tSlot)}' : 'φ${_f(_tDia)}'}를 놓습니다.';
    }
    return '구멍을 눌러 고르고 끌어 옮깁니다. 빈 곳을 끌면 화면이 움직이고, 두 손가락으로 확대합니다.';
  }

  @override
  Widget build(BuildContext context) {
    final p = _plan;
    final bad = p.holes.where((h) => h.bad).length;
    final hasSlot = _sel.any((i) => i < p.holes.length && p.holes[i].slot > 0);
    return FieldViewTheme(
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: fc.background,
          appBar: AppBar(
            backgroundColor: fc.surface,
            foregroundColor: fc.text,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              '구멍 배치 편집',
              style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
            ),
            actions: [
              IconButton(
                key: const Key('ed_undo'),
                tooltip: '되돌리기',
                onPressed: _undo.isEmpty ? null : _undoOnce,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                key: const Key('ed_redo'),
                tooltip: '다시 하기',
                onPressed: _redo.isEmpty ? null : _redoOnce,
                icon: const Icon(Icons.redo),
              ),
              IconButton(
                key: const Key('ed_fit'),
                tooltip: '판 전체 보기',
                onPressed: () => setState(() {
                  _zoom = 1;
                  _pan = Offset.zero;
                }),
                icon: const Icon(Icons.fit_screen_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    _size = box.biggest;
                    return Listener(
                      onPointerDown: (e) => _downAt = e.localPosition,
                      child: GestureDetector(
                        key: const Key('ed_canvas'),
                        behavior: HitTestBehavior.opaque,
                        // 처음 손가락을 댄 자리를 시작점으로(끌 때 구멍이 손가락보다 뒤처지지 않게, 고르기도 그 자리에서)
                        dragStartBehavior: DragStartBehavior.down,
                        onTapUp: _onTap,
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        onScaleEnd: _onScaleEnd,
                        child: CustomPaint(
                          painter: _EditorPainter(
                            plan: p,
                            toScreen: (mm) => _toScreen(p, mm),
                            scale: _s(p),
                            grid: _grid,
                            selected: _sel.toSet(),
                            guideX: _guideX,
                            guideY: _guideY,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _panel(p, bad, hasSlot),
            ],
          ),
        ),
      ),
    );
  }

  // 아래 칸은 높이를 못박는다(고르기·놓기를 바꿀 때 칸 높이가 달라져 판 그림이 들썩이지 않게).
  Widget _panel(PlatePlan p, int bad, bool hasSlot) => Container(
    width: double.infinity,
    height: MediaQuery.of(context).size.height * 0.36,
    decoration: BoxDecoration(
      color: fc.surface,
      border: Border(top: BorderSide(color: fc.line)),
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _status(p),
            key: const Key('ed_status'),
            style: TextStyle(
              color: fc.text,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (bad > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '빨간 테두리 구멍 $bad개는 만들 수 없습니다(판 밖·꺾이는 부분·겹침). 노란 테두리는 꺾기선·판 끝에 가깝습니다.',
                key: const Key('ed_bad'),
                style: TextStyle(color: fc.danger, height: 1.35),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              calcChip(
                'ed_mode_sel',
                '고르기·옮기기',
                !_place,
                () => setState(() => _place = false),
              ),
              calcChip(
                'ed_mode_place',
                '구멍 놓기',
                _place,
                () => setState(() => _place = true),
              ),
              calcChip(
                'ed_multi',
                '여러 개 고르기',
                _multi,
                () => setState(() => _multi = !_multi),
              ),
              calcChip(
                'ed_all',
                '모두 고르기',
                false,
                () => setState(() {
                  _multi = true;
                  _sel
                    ..clear()
                    ..addAll([for (var i = 0; i < _holes.length; i++) i]);
                }),
              ),
            ],
          ),
          if (_place) ...[
            const SizedBox(height: 8),
            Text('놓을 구멍', style: TextStyle(color: fc.textSub)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in widget.dies)
                  calcChip(
                    'ed_tdia_${(d * 100).round()}',
                    punchDieLabel(d),
                    _tDia == d,
                    () => setState(() => _tDia = d),
                  ),
                for (final (key, label, len) in const [
                  ('ed_tslot_0', '둥근 구멍', 0.0),
                  ('ed_tslot_30', '장공 30', 30.0),
                  ('ed_tslot_40', '장공 40', 40.0),
                ])
                  calcChip(
                    key,
                    label,
                    _tSlot == len,
                    () => setState(() => _tSlot = len),
                  ),
                if (_tSlot > 0)
                  for (final a in const [0.0, 45.0, 90.0])
                    calcChip(
                      'ed_tang_${a.round()}',
                      a == 0 ? '가로' : (a == 90 ? '세로' : '45°'),
                      _tAngle == a,
                      () => setState(() => _tAngle = a),
                    ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final g in const [0.0, 1.0, 5.0, 10.0])
                calcChip(
                  'ed_grid_${g.round()}',
                  g == 0 ? '모눈 끔' : '모눈 ${_f(g)}',
                  _grid == g,
                  () => _setGrid(g),
                ),
            ],
          ),
          if (_sel.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('고른 구멍', style: TextStyle(color: fc.textSub)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_sel.length == 1)
                  calcChip('ed_edit', '자리·크기 고치기', false, _editOne),
                calcChip('ed_dup', '복제', false, _duplicate),
                calcChip('ed_del', '지우기', false, _delete),
                if (hasSlot) ...[
                  calcChip('ed_spin_m15', '장공 −15°', false, () => _spin(-15)),
                  calcChip('ed_spin_p15', '장공 +15°', false, () => _spin(15)),
                  calcChip('ed_spin_90', '장공 90°', false, () => _spin(90)),
                ],
                if (_sel.length > 1) ...[
                  calcChip(
                    'ed_grot_90',
                    '묶음 90° 돌리기',
                    false,
                    () => _rotateGroup(90),
                  ),
                  calcChip(
                    'ed_grot_m90',
                    '묶음 −90°',
                    false,
                    () => _rotateGroup(-90),
                  ),
                  calcChip(
                    'ed_align_h',
                    '가로 줄 맞추기',
                    false,
                    () => _alignRow(true),
                  ),
                  calcChip(
                    'ed_align_v',
                    '세로 줄 맞추기',
                    false,
                    () => _alignRow(false),
                  ),
                ],
                if (_sel.length > 2) ...[
                  calcChip(
                    'ed_dist_h',
                    '가로 같은 간격',
                    false,
                    () => _distribute(true),
                  ),
                  calcChip(
                    'ed_dist_v',
                    '세로 같은 간격',
                    false,
                    () => _distribute(false),
                  ),
                ],
                calcChip(
                  'ed_mirror_lr',
                  '좌우 대칭 복사',
                  false,
                  () => _mirror(true),
                ),
                calcChip(
                  'ed_mirror_ud',
                  '상하 대칭 복사',
                  false,
                  () => _mirror(false),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              calcChip('ed_pcd', '원형 배치(PCD)', false, _pcd),
              if (!_bent)
                calcChip(
                  'ed_rot',
                  '판 90° 돌리기',
                  false,
                  () => _change(() {
                    _rot = (_rot + 1) % 4;
                    _zoom = 1;
                    _pan = Offset.zero;
                  }),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// 숫자 칸 여러 개를 받는 창. 입력칸은 창이 다 닫힌 뒤 치운다(닫히는 동안 쓰이므로).
class PlateNumbersDialog extends StatefulWidget {
  const PlateNumbersDialog({
    super.key,
    required this.title,
    required this.fields,
  });
  final String title;
  final List<(String, double)> fields;

  @override
  State<PlateNumbersDialog> createState() => PlateNumbersDialogState();
}

class PlateNumbersDialogState extends State<PlateNumbersDialog> {
  late final List<TextEditingController> _c = [
    for (final (_, v) in widget.fields)
      TextEditingController(text: v.isFinite ? _f(v, 2) : ''),
  ];

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  // 앱 공용 창 모양(AppDialog: 흰 바탕·굵은 제목·회색 취소·청록 확인)과 입력칸 모양을 쓴다.
  @override
  Widget build(BuildContext context) => AppDialog(
    title: widget.title,
    okText: '적용',
    okKey: const Key('ed_num_ok'),
    onCancel: () => Navigator.pop(context),
    onOk: () => Navigator.pop(context, [
      for (var k = 0; k < _c.length; k++)
        double.tryParse(_c[k].text.trim().replaceAll(',', '.')) ??
            widget.fields[k].$2,
    ]),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var k = 0; k < widget.fields.length; k++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                key: Key('ed_num_$k'),
                controller: _c[k],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                style: appFieldTextStyle,
                decoration: appFieldDecoration(widget.fields[k].$1),
              ),
            ),
        ],
      ),
    ),
  );
}

class _EditorPainter extends CustomPainter {
  final PlatePlan plan;
  final Offset Function(Offset mm) toScreen;
  final double scale, grid;
  final Set<int> selected;
  final double? guideX, guideY;

  _EditorPainter({
    required this.plan,
    required this.toScreen,
    required this.scale,
    required this.grid,
    required this.selected,
    required this.guideX,
    required this.guideY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = plan;
    // 모눈 점(점 사이가 6점 이상일 때만)
    if (grid > 0 && grid * scale >= 6) {
      final nx = ((p.maxX - p.minX) / grid).floor();
      final ny = ((p.maxY - p.minY) / grid).floor();
      if ((nx + 1) * (ny + 1) <= 6000) {
        final dot = Paint()..color = fc.line;
        for (var i = 0; i <= nx; i++) {
          for (var j = 0; j <= ny; j++) {
            canvas.drawCircle(
              toScreen(Offset(p.minX + i * grid, p.minY + j * grid)),
              0.9,
              dot,
            );
          }
        }
      }
    }
    final pts = plateOutlinePoints(p.outline);
    if (pts.length >= 3) {
      final path = Path()
        ..moveTo(toScreen(pts.first).dx, toScreen(pts.first).dy);
      for (final q in pts.skip(1)) {
        final s = toScreen(q);
        path.lineTo(s.dx, s.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = kPlateFill.withValues(alpha: 0.75),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = kPlateEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    // 꺾기: 꺾이는 부분(진한 빗금)과 구멍을 피할 거리(옅은 띠), 가운데 점선
    for (final b in p.bends) {
      final lo = toScreen(Offset(b.start - p.bendClear, p.maxY));
      final hi = toScreen(Offset(b.end + p.bendClear, p.minY));
      canvas.drawRect(
        Rect.fromPoints(lo, hi),
        Paint()..color = kPlateBend.withValues(alpha: 0.12),
      );
      final z0 = toScreen(Offset(b.start, p.maxY));
      final z1 = toScreen(Offset(b.end, p.minY));
      final zone = Rect.fromPoints(z0, z1);
      canvas.drawRect(
        zone,
        Paint()..color = kPlateBend.withValues(alpha: 0.28),
      );
      canvas.save();
      canvas.clipRect(zone);
      final hatch = Paint()
        ..color = kPlateBend.withValues(alpha: 0.6)
        ..strokeWidth = 1;
      for (var x = zone.left - zone.height; x < zone.right; x += 7) {
        canvas.drawLine(
          Offset(x, zone.bottom),
          Offset(x + zone.height, zone.top),
          hatch,
        );
      }
      canvas.restore();
    }
    // 구멍
    final edge = Paint()
      ..color = kPlateEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < p.holes.length; i++) {
      final h = p.holes[i];
      final c = toScreen(h.c);
      final sel = selected.contains(i);
      plateDrawHole(
        canvas,
        h,
        c,
        scale,
        fill: sel ? fc.brandSoft : Colors.white,
        edge: h.bad
            ? fc.danger
            : (sel ? fc.brand : (h.caution ? fc.caution : null)),
        edgePaint: edge,
        minR: 4,
      );
      if (p.holes.length <= 40 || sel) {
        _label(
          canvas,
          h.label,
          c + Offset(math.max(h.halfX * scale, 4) + 8, -10),
          fc.textSub,
          10.5,
        );
      }
    }
    // 고른 구멍 하나: 왼쪽·아래 끝까지 치수
    if (selected.length == 1 && selected.first < p.holes.length) {
      final h = p.holes[selected.first];
      final c = toScreen(h.c);
      final dim = Paint()
        ..color = fc.brand
        ..strokeWidth = 1;
      final left = toScreen(Offset(p.minX, h.c.dy));
      final bottom = toScreen(Offset(h.c.dx, p.minY));
      canvas.drawLine(left, c, dim);
      canvas.drawLine(bottom, c, dim);
      _label(
        canvas,
        _f(h.c.dx - p.minX),
        Offset((left.dx + c.dx) / 2, c.dy - 10),
        fc.brand,
        11.5,
        bold: true,
      );
      _label(
        canvas,
        _f(h.c.dy - p.minY),
        Offset(c.dx + 6, (bottom.dy + c.dy) / 2),
        fc.brand,
        11.5,
        bold: true,
        alignLeft: true,
      );
    }
    // 안내선
    final guide = Paint()
      ..color = const Color(0xFF2F80ED)
      ..strokeWidth = 1;
    if (guideX != null) {
      final x = toScreen(Offset(guideX!, 0)).dx;
      for (var y = 0.0; y < size.height; y += 10) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 6), guide);
      }
    }
    if (guideY != null) {
      final y = toScreen(Offset(0, guideY!)).dy;
      for (var x = 0.0; x < size.width; x += 10) {
        canvas.drawLine(Offset(x, y), Offset(x + 6, y), guide);
      }
    }
  }

  void _label(
    Canvas canvas,
    String s,
    Offset at,
    Color color,
    double size, {
    bool bold = false,
    bool alignLeft = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final o = alignLeft
        ? at - Offset(0, tp.height / 2)
        : at - Offset(tp.width / 2, tp.height / 2);
    canvas.drawRect(
      Rect.fromLTWH(o.dx - 2, o.dy - 1, tp.width + 4, tp.height + 2),
      Paint()..color = fc.surface.withValues(alpha: 0.85),
    );
    tp.paint(canvas, o);
  }

  @override
  bool shouldRepaint(_EditorPainter old) => true;
}
