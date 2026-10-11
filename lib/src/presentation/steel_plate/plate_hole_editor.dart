// 철판 구멍 배치 편집(10-10, 사용자: "철판 가공은 배치도처럼 홀 구멍 배치부터 회전까지 다 넣어줘").
// 판(꺾는 것은 전개도) 위에서 구멍을 눌러 놓고, 끌어 옮기고, 모눈·다른 구멍·판 가운데에 맞추고(안내선),
// 여러 개 골라 복제·지우기·줄 맞추기·같은 간격·대칭 복사·묶음 회전, 장공 각도 돌리기, 원형 배치(PCD),
// 판 90° 돌리기, 되돌리기·다시 하기, 두 손가락 확대·이동. 꺾는 판은 꺾이는 부분을 빗금으로 막아 두고,
// 놓은 구멍이 어느 면의 몇 mm인지 보여 준다(저장은 면 기준이라 면 치수를 바꿔도 따라간다).
// 바뀔 때마다 [PlateHoleEditorPage.onChanged]로 철판 가공 화면에 바로 넘긴다(따로 "저장" 단추 없음).
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/swipe_to_delete.dart' show showDeleteUndo;
import '../../core/theme/app_icon_set.dart';
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import '../electrical/busbar_punch_dies.dart' show punchDieLabel;
import 'plate_calc.dart';
import 'plate_hole_input.dart';
import 'plate_settings.dart' show kPlateGridKey;
import 'plate_painter.dart';
import 'plate_ui.dart';

class PlateHoleEditorPage extends StatefulWidget {
  const PlateHoleEditorPage({
    super.key,
    required this.input,
    required this.holes,
    required this.rotQ,
    required this.dies,
    required this.onChanged,
    this.embedded = false,
    this.footer,
    this.showCenter = true,
    this.defaultDia = 13.5,
    this.grid,
  });

  /// 홀 추가 기본 지름·그리드(철판 가공 설정). [grid]가 null이면 저장해 둔 값.
  final double defaultDia;
  final double? grid;

  /// 판 가운데 십자 중심선(철판 가공 화면의 켜고 끄기를 따른다).
  final bool showCenter;

  /// 탭 안에 있을 때 아래 칸 맨 밑에 붙이는 것(없으면 안 붙인다).
  final Widget? footer;

  /// 철판 가공 화면의 "구멍" 탭 안에 넣을 때(제목 줄 없이, 되돌리기·다시·전체 보기는 그림 위 작은 줄).
  final bool embedded;

  /// 판 치수(구멍·돌림은 아래 값을 쓴다).
  final PlateInput input;
  final List<PlateHoleSpec> holes;
  final int rotQ;
  final List<double> dies;
  final void Function(List<PlateHoleSpec> holes, int rotQ) onChanged;

  static const gridKey = kPlateGridKey;

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
  final List<int> _sel = []; // 선택한 홀(고른 차례)
  bool _multi = false;
  bool _place = false;
  late double _grid = widget.grid ?? 5;
  late double _tDia = widget.defaultDia > 0
      ? widget.defaultDia
      : (widget.dies.isEmpty ? 13.5 : widget.dies.first);
  double _tSlot = 0;
  double _tAngle = 0;

  final List<(List<PlateHoleSpec>, int)> _undo = [], _redo = [];

  // 보기: 확대 배율과 화면 가운데에서 옮긴 거리
  double _zoom = 1;
  Offset _pan = Offset.zero;
  Size _size = Size.zero;

  // 끌기·확대 중 상태
  int? _lead;
  Map<int, Offset>? _dragFrom; // 홀 번호 → 끌기 시작 때 화면 자리(mm)
  Offset _focal0 = Offset.zero;
  double _zoom0 = 1;
  Offset _pan0 = Offset.zero;
  bool _panning = false, _pinching = false;
  double? _guideX, _guideY;

  /// 손가락을 처음 댄 자리. 확대·끌기 인식은 조금 움직인 뒤에 시작하므로, 구멍 찾기와 끈 거리는 이 자리에서 잰다.
  Offset? _downAt;

  bool get _bent => plateShapeBends(widget.input.shape);

  PlatePlan get _plan => platePlan(widget.input.withHoles(_holes, rotQ: _rot));

  /// 탭 안에 있을 때 다른 탭에서 구멍이 바뀌면(저장한 규격 불러오기 등) 따라간다.
  @override
  void didUpdateWidget(covariant PlateHoleEditorPage old) {
    super.didUpdateWidget(old);
    String sig(List<PlateHoleSpec> l, int r) =>
        jsonEncode([r, for (final h in l) h.toJson()]);
    if (widget.grid != null && widget.grid != old.grid) _grid = widget.grid!;
    if (sig(widget.holes, widget.rotQ) != sig(_holes, _rot)) {
      _holes
        ..clear()
        ..addAll(widget.holes);
      _rot = widget.rotQ;
      _sel.clear();
      _undo.clear();
      _redo.clear();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.grid == null) {
      SharedPreferences.getInstance()
          .then((p) {
            final g = p.getDouble(PlateHoleEditorPage.gridKey);
            if (g != null && mounted) setState(() => _grid = g);
          })
          .catchError((_) {});
    }
  }

  // ── 좌표 ──

  // 판을 맞춰 넣는 여백: 위는 오른쪽 위 단추 줄, 아래는 "홀 넣기"·고른 홀 단추 줄 자리(그 단추가 판 아래쪽
  // 홀을 가리던 것, 점검 31, 10-11).
  static const _side = 40.0, _top = 40.0, _bottom = 70.0;

  /// 판 가운데가 오는 화면 자리(아래 단추 줄 자리를 뺀 칸의 가운데).
  Offset get _mid =>
      Offset(_size.width / 2, _top + (_size.height - _top - _bottom) / 2);

  double _baseScale(PlatePlan p) {
    final bw = math.max(p.maxX - p.minX, 1.0);
    final bh = math.max(p.maxY - p.minY, 1.0);
    return math.max(
      0.01,
      math.min(
        (_size.width - 2 * _side) / bw,
        (_size.height - _top - _bottom) / bh,
      ),
    );
  }

  double _s(PlatePlan p) => _baseScale(p) * _zoom;

  Offset _center(PlatePlan p) =>
      Offset((p.minX + p.maxX) / 2, (p.minY + p.maxY) / 2);

  Offset _toScreen(PlatePlan p, Offset mm) {
    final s = _s(p), c = _center(p);
    return _mid + _pan + Offset((mm.dx - c.dx) * s, -(mm.dy - c.dy) * s);
  }

  Offset _toMm(PlatePlan p, Offset sc) {
    final s = _s(p), c = _center(p);
    final d = sc - _mid - _pan;
    return Offset(d.dx / s + c.dx, -d.dy / s + c.dy);
  }

  /// 가로 그리드 원점: 절곡 판은 그 자리 면의 시작(u = 0)에서 재야 "2면 55"처럼 끊어진다
  /// (점검 54: 전개도 왼쪽 끝에서 재서 "2면 55.7"처럼 끝수가 붙었다). 평판은 판 왼쪽 끝.
  double _gridX(PlatePlan p, double x) =>
      p.isBent ? _snapGrid(x, p.faceBase[p.faceAt(x)]) : _snapGrid(x, p.minX);

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
      final at = Offset(_gridX(p, mm.dx), _snapGrid(mm.dy, p.minY));
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
            _mid -
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
    target = Offset(_gridX(p, target.dx), _snapGrid(target.dy, p.minY));
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
    final d = sc - _mid - pan;
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
    showDeleteUndo(context, '홀 $n개', onUndo: _undoOnce);
  }

  /// 홀 입력 창에 넘길 판 정보(화면 자리). [except] 홀은 "있던 홀"에서 뺀다(고칠 때).
  PlateHoleCanvas _canvasOf(PlatePlan p, {int? except}) => PlateHoleCanvas(
    outline: plateOutlinePoints(p.outline),
    cutouts: [for (final c in p.cutouts) (c.c, c.dia)],
    existing: [
      for (var i = 0; i < p.holes.length; i++)
        if (i != except)
          PlateHoleDraft(
            p.holes[i].c,
            p.holes[i].dia,
            slot: p.holes[i].slot,
            angle: p.holes[i].angle,
          ),
    ],
    minX: p.minX,
    minY: p.minY,
    maxX: p.maxX,
    maxY: p.maxY,
    bendSpans: [for (final b in p.bends) (b.start, b.end)],
    faces: p.isBent ? p.faceNames : const [],
    faceBase: p.faceBase,
  );

  List<PlateHolePattern> get _patterns => [
    PlateHolePattern.single,
    PlateHolePattern.row,
    PlateHolePattern.grid,
    if (widget.input.shape == PlateShape.flat) PlateHolePattern.corners,
    PlateHolePattern.pcd,
  ];

  /// 숫자로 홀 넣기(하나·줄·격자·네 코너·원형 배치): 새 홀 입력 창. 넣은 홀은 골라 둔다.
  Future<void> _addHoles(PlateHolePattern pattern, {bool slot = false}) async {
    final p = _plan;
    final r = await showPlateHoleInput(
      context,
      title: '홀 넣기',
      canvas: _canvasOf(p),
      dias: widget.dies,
      defaultDia: _tDia,
      pattern: pattern,
      patterns: _patterns,
      slot: slot,
    );
    if (r == null || !mounted) return;
    final adds = [
      for (final d in r.holes)
        _specAt(
          p,
          d.c,
          PlateHoleSpec(
            u: 0,
            v: 0,
            dia: d.dia,
            slot: d.slot > d.dia ? d.slot : 0,
          ),
          dispAngle: d.angle,
        ),
    ];
    _change(() {
      final start = _holes.length;
      _holes.addAll(adds);
      _sel
        ..clear()
        ..addAll([for (var k = 0; k < adds.length; k++) start + k]);
    });
  }

  void _clearAll() {
    final n = _holes.length;
    if (n == 0) return;
    _change(() {
      _holes.clear();
      _sel.clear();
    });
    showDeleteUndo(context, '홀 $n개', onUndo: _undoOnce);
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

  // ── 창: 위치·크기 수정 ──

  Future<void> _editOne() async {
    if (_sel.length != 1) return;
    final p = _plan;
    final i = _sel.first;
    final h = p.holes[i];
    final r = await showPlateHoleInput(
      context,
      title: '홀 ${h.label} 수정',
      canvas: _canvasOf(p, except: i),
      dias: widget.dies,
      defaultDia: h.dia,
      patterns: const [PlateHolePattern.single],
      edit: PlateHoleDraft(h.c, h.dia, slot: h.slot, angle: h.angle),
      face: h.face,
      okText: '적용',
    );
    if (r == null || r.holes.isEmpty || !mounted) return;
    final d = r.holes.first;
    final spec = _specAt(
      p,
      d.c,
      _holes[i].copyWith(dia: d.dia, slot: d.slot > d.dia ? d.slot : 0),
      dispAngle: d.angle,
    );
    _change(() => _holes[i] = spec);
  }

  // ── 화면 ──

  String _status(PlatePlan p) {
    if (_sel.length == 1) {
      final h = p.holes[_sel.first];
      final face = p.isBent
          ? ' · ${p.faceNames[h.face]} ${_f(h.u)} · ${_f(h.v)}'
          : '';
      // 판 가운데(빨간 쇄선)에서: 오른쪽·위가 +
      final gx = h.c.dx - (p.minX + p.maxX) / 2;
      final gy = h.c.dy - (p.minY + p.maxY) / 2;
      String sg(double v) =>
          v.abs() < 0.05 ? '0' : '${v > 0 ? '+' : '−'}${_f(v.abs())}';
      return '홀 ${h.label} ${plateHoleKind(h)}: 왼쪽 ${_f(h.c.dx - p.minX)} · 아래 ${_f(h.c.dy - p.minY)} · 오른쪽 ${_f(p.maxX - h.c.dx)} · 위 ${_f(p.maxY - h.c.dy)} · 센터에서 가로 ${sg(gx)} · 세로 ${sg(gy)}$face';
    }
    if (_sel.length > 1) return '홀 ${_sel.length}개 선택';
    if (_place) {
      return '판을 누르면 그 자리에 ${_tSlot > _tDia ? '장공 ${_f(_tDia)}×${_f(_tSlot)}' : 'φ${_f(_tDia)}'}를 놓습니다.';
    }
    return '홀을 눌러 선택하고 끌어 옮깁니다. 빈 곳을 끌면 화면이 움직이고, 두 손가락으로 확대합니다.';
  }

  @override
  Widget build(BuildContext context) {
    final p = _plan;
    final bad = p.holes.where((h) => h.bad).length;
    final hasSlot = _sel.any((i) => i < p.holes.length && p.holes[i].slot > 0);
    // 그림 오른쪽 위: 되돌리기 · 다시 하기 · 판 전체 보기
    final tools = [
      PlateCanvasButton(
        key: const Key('ed_undo'),
        tooltip: '되돌리기',
        icon: AppIcons.undo,
        onTap: _undo.isEmpty ? null : _undoOnce,
      ),
      PlateCanvasButton(
        key: const Key('ed_redo'),
        tooltip: '다시 하기',
        icon: AppIcons.redo,
        onTap: _redo.isEmpty ? null : _redoOnce,
      ),
      PlateCanvasButton(
        key: const Key('ed_fit'),
        tooltip: '판 전체 보기',
        icon: Icons.fit_screen_outlined,
        onTap: () => setState(() {
          _zoom = 1;
          _pan = Offset.zero;
        }),
      ),
    ];
    // 색(fc)은 현장 보기 테마 안에서 읽어야 하므로 바로 만들지 않고 함수로
    Widget body() => PlateWorkspace(
      canvasShare: 0.56,
      tools: tools,
      overlay: [
        if (_sel.isNotEmpty)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Center(child: _selBar(p)),
          )
        else
          Positioned(
            right: 12,
            bottom: 12,
            child: FilledButton.icon(
              key: const Key('ed_fab_add'),
              style: FilledButton.styleFrom(
                backgroundColor: fc.brand,
                foregroundColor: fc.onBrand,
                elevation: 3,
                shadowColor: fc.text.withValues(alpha: 0.3),
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _addHoles(PlateHolePattern.single),
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                '홀 넣기',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
      canvas: LayoutBuilder(
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
                  showCenter: widget.showCenter,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          );
        },
      ),
      panel: _panel(p, bad, hasSlot),
    );
    if (widget.embedded) return body();
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
              '홀 배치',
              style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
            ),
          ),
          body: body(),
        ),
      ),
    );
  }

  /// 홀을 고르면 그림 아래에 뜨는 단추 줄(점검 27, 10-11): 휴대폰에서는 작업판의 "선택한 홀" 단추가
  /// 화면 아래로 밀려 안 보였다. 자주 쓰는 수정·복사·지우기와 고르기 풀기만 그림 위에 둔다.
  Widget _selBar(PlatePlan p) {
    Widget b(
      String key,
      IconData icon,
      String label,
      VoidCallback onTap, {
      bool danger = false,
    }) => TextButton.icon(
      key: Key(key),
      style: TextButton.styleFrom(
        foregroundColor: danger ? fc.danger : fc.text,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
    final one = _sel.length == 1 && _sel.first < p.holes.length;
    return Material(
      key: const Key('ed_selbar'),
      color: fc.surface,
      elevation: 3,
      shadowColor: fc.text.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: fc.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 2),
                child: Text(
                  one ? '홀 ${p.holes[_sel.first].label}' : '홀 ${_sel.length}개',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: fc.brand,
                  ),
                ),
              ),
              if (one) b('ed_fl_edit', Icons.tune, '수정', _editOne),
              b('ed_fl_dup', AppIcons.copy, '복사', _duplicate),
              b('ed_fl_del', AppIcons.delete, '지우기', _delete, danger: true),
              IconButton(
                key: const Key('ed_fl_clear'),
                tooltip: '고르기 풀기',
                color: fc.textSub,
                onPressed: () => setState(_sel.clear),
                icon: const Icon(AppIcons.close, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 아래 작업판: 판을 누르면(고르기·놓기) · 놓을 구멍 · 고른 구멍 · 모눈·한꺼번에 넣기·판 돌리기(접힘)
  Widget _panel(PlatePlan p, int bad, bool hasSlot) {
    Widget act(
      String key,
      IconData icon,
      String label,
      VoidCallback onTap, {
      bool danger = false,
    }) => PlateActionButton(
      key: Key(key),
      icon: icon,
      label: label,
      onTap: onTap,
      danger: danger,
    );
    return PlatePanel(
      title: '홀',
      status: _status(p),
      statusKey: const Key('ed_status'),
      statusColor: fc.text,
      below: [
        if (bad > 0)
          Text(
            '빨간 테두리 홀 $bad개는 만들 수 없습니다(판 밖·절곡부·겹침). 노란 테두리는 절곡선·판 끝에 가깝습니다.',
            key: const Key('ed_bad'),
            style: TextStyle(fontSize: 13, color: fc.danger, height: 1.35),
          ),
      ],
      actions: [
        plateHelpButton(context, 'ed_help', '홀 탭', [
          '판을 누르면: "선택·이동"은 홀을 눌러 선택하고 끌어 옮깁니다. 빈 곳을 끌면 화면이 움직이고, 두 손가락으로 확대합니다. "홀 추가"는 판을 누른 자리에 고른 크기의 홀을 놓습니다.',
          '홀을 끌면 그리드·다른 홀·센터선에 맞춰 안내선이 나옵니다. 그리드 간격은 설정에서 바꿉니다.',
          '숫자로 넣기(그림 오른쪽 아래 "홀 넣기"도 같음): 하나·줄·격자·네 코너·원형 배치를 창에서 그림을 보며 넣습니다. 위치는 왼쪽 아래 기준이나 센터 기준으로 잽니다.',
          '홀을 고르면 그림 아래에 수정·복사·지우기 단추 줄이 뜹니다(×는 고르기 풀기). 대칭 복사·줄 맞추기·같은 간격·묶음 회전은 아래 "선택한 홀"에 있습니다.',
          '빨간 테두리 홀은 만들 수 없고(판 밖·절곡부·겹침), 노란 테두리는 절곡선·판 끝에 가깝습니다.',
          if (_bent)
            '절곡 판은 절곡부를 빗금으로 막아 두었습니다. 홀 위치는 면 기준으로 남겨 면 치수를 바꿔도 따라갑니다.',
        ]),
      ],
      footer: widget.footer,
      children: [
        PlateSection('판을 누르면', [
          PlateSegments([
            PlateOption(
              'ed_mode_sel',
              '선택·이동',
              !_place,
              () => setState(() => _place = false),
            ),
            PlateOption(
              'ed_mode_place',
              '홀 추가',
              _place,
              () => setState(() => _place = true),
            ),
          ]),
          PlateSegments(joined: false, [
            PlateOption(
              'ed_multi',
              '다중 선택',
              _multi,
              () => setState(() => _multi = !_multi),
            ),
            PlateOption(
              'ed_all',
              '전체 선택',
              false,
              () => setState(() {
                _multi = true;
                _sel
                  ..clear()
                  ..addAll([for (var i = 0; i < _holes.length; i++) i]);
              }),
            ),
          ]),
        ], first: true),
        PlateSection('숫자로 넣기', [
          plateActions([
            act(
              'ed_add_row',
              Icons.add_circle_outline,
              '홀 넣기 (하나·줄·격자)',
              () => _addHoles(PlateHolePattern.single),
            ),
            if (widget.input.shape == PlateShape.flat)
              act(
                'ed_add_corners',
                Icons.crop_free,
                '네 코너',
                () => _addHoles(PlateHolePattern.corners),
              ),
            act(
              'ed_pcd',
              Icons.radio_button_unchecked,
              '원형 배치(PCD)',
              () => _addHoles(PlateHolePattern.pcd),
            ),
          ]),
        ]),
        if (_place)
          PlateSection('추가할 홀', [
            PlateSegments(joined: false, [
              for (final d in widget.dies)
                PlateOption(
                  'ed_tdia_${(d * 100).round()}',
                  punchDieLabel(d),
                  _tDia == d,
                  () => setState(() => _tDia = d),
                ),
            ]),
            PlateSegments([
              for (final (key, label, len) in const [
                ('ed_tslot_0', '원형 홀', 0.0),
                ('ed_tslot_30', '장공 30', 30.0),
                ('ed_tslot_40', '장공 40', 40.0),
              ])
                PlateOption(
                  key,
                  label,
                  _tSlot == len,
                  () => setState(() => _tSlot = len),
                ),
            ]),
            if (_tSlot > 0)
              PlateSegments([
                for (final a in const [0.0, 45.0, 90.0])
                  PlateOption(
                    'ed_tang_${a.round()}',
                    a == 0 ? '장공 가로' : (a == 90 ? '장공 세로' : '45°'),
                    _tAngle == a,
                    () => setState(() => _tAngle = a),
                  ),
              ]),
          ]),
        if (_sel.isNotEmpty)
          PlateSection(_sel.length == 1 ? '선택한 홀' : '선택한 홀 ${_sel.length}개', [
            plateActions([
              if (_sel.length == 1)
                act('ed_edit', Icons.tune, '위치·크기 수정', _editOne),
              act('ed_dup', AppIcons.copy, '복사', _duplicate),
              act('ed_del', AppIcons.delete, '지우기', _delete, danger: true),
            ]),
            plateActions([
              act('ed_mirror_lr', Icons.flip, '좌우 대칭 복사', () => _mirror(true)),
              act(
                'ed_mirror_ud',
                Icons.swap_vert,
                '상하 대칭 복사',
                () => _mirror(false),
              ),
            ]),
            if (hasSlot)
              plateActions([
                act(
                  'ed_spin_m15',
                  Icons.rotate_left,
                  '장공 −15°',
                  () => _spin(-15),
                ),
                act(
                  'ed_spin_p15',
                  Icons.rotate_right,
                  '장공 +15°',
                  () => _spin(15),
                ),
                act(
                  'ed_spin_90',
                  Icons.rotate_90_degrees_cw_outlined,
                  '장공 90°',
                  () => _spin(90),
                ),
              ]),
            if (_sel.length > 1)
              plateActions([
                act(
                  'ed_align_h',
                  Icons.align_vertical_center,
                  '가로 줄 맞추기',
                  () => _alignRow(true),
                ),
                act(
                  'ed_align_v',
                  Icons.align_horizontal_center,
                  '세로 줄 맞추기',
                  () => _alignRow(false),
                ),
                if (_sel.length > 2)
                  act(
                    'ed_dist_h',
                    Icons.horizontal_distribute,
                    '가로 같은 간격',
                    () => _distribute(true),
                  ),
                if (_sel.length > 2)
                  act(
                    'ed_dist_v',
                    Icons.vertical_distribute,
                    '세로 같은 간격',
                    () => _distribute(false),
                  ),
                act(
                  'ed_grot_90',
                  Icons.rotate_left,
                  '묶음 90° 회전',
                  () => _rotateGroup(90),
                ),
                act(
                  'ed_grot_m90',
                  Icons.rotate_right,
                  '묶음 −90°',
                  () => _rotateGroup(-90),
                ),
              ]),
          ]),
        if (!_bent || _holes.isNotEmpty)
          PlateSection('판', [
            plateActions([
              if (!_bent)
                act(
                  'ed_rot',
                  Icons.rotate_90_degrees_ccw_outlined,
                  '판 90° 회전',
                  () => _change(() {
                    _rot = (_rot + 1) % 4;
                    _zoom = 1;
                    _pan = Offset.zero;
                  }),
                ),
              if (_holes.isNotEmpty)
                act(
                  'ed_clear',
                  AppIcons.delete,
                  '홀 모두 지우기',
                  _clearAll,
                  danger: true,
                ),
            ]),
          ]),
      ],
    );
  }
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
    this.showCenter = true,
  });
  final bool showCenter;
  final PlateTone tone = PlateTone.now;

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
      canvas.drawPath(path, Paint()..color = tone.fill.withValues(alpha: 0.75));
      canvas.drawPath(
        path,
        Paint()
          ..color = tone.edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    // 꺾기: 꺾이는 부분(진한 빗금)과 구멍을 피할 거리(옅은 띠), 가운데 점선 — 판 안만(L·T자 판)
    canvas.save();
    if (pts.length >= 3) {
      canvas.clipPath(
        Path()..addPolygon([for (final q in pts) toScreen(q)], true),
      );
    }
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
    canvas.restore();
    // 구멍
    final edge = Paint()
      ..color = tone.edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final h in p.cutouts) {
      plateDrawHole(
        canvas,
        h,
        toScreen(h.c),
        scale,
        fill: fc.background,
        edgePaint: edge,
        minR: 4,
      );
    }
    for (var i = 0; i < p.holes.length; i++) {
      final h = p.holes[i];
      final c = toScreen(h.c);
      final sel = selected.contains(i);
      plateDrawHole(
        canvas,
        h,
        c,
        scale,
        fill: sel ? fc.brandSoft : fc.background,
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
    // 판 가운데 십자 중심선(꺾기선과 같은 자리면 세로선 옅게)
    if (showCenter) {
      plateDrawCenterLines(
        canvas,
        toScreen: toScreen,
        minX: p.minX,
        minY: p.minY,
        maxX: p.maxX,
        maxY: p.maxY,
        ext: 14,
        faintVertical: p.bends.any(
          (b) => (b.center - (p.minX + p.maxX) / 2).abs() < 1,
        ),
      );
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
