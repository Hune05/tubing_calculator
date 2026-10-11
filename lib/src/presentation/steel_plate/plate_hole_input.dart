// 홀 넣기·고치기 창(10-10, 사용자: "홀 입력창 싹 뜯어고쳐, 그냥 쳐 몰아넣기 한 거야, 상용 앱이랑 비교 후 다 고쳐").
// CAD·레이저 주문 앱의 "홀 패턴"처럼 창 하나에: 위 미리보기(새 홀 진하게, 판 밖·절곡부는 빨강) ·
// 홀(원형/장공, 지름·자주 쓰는 지름, 장공 길이·방향) · 면(절곡 판) · 놓는 방법(하나/줄/격자/네 코너/원형 배치) ·
// 위치(왼쪽 아래 기준/센터 기준) · 맨 아래 취소/넣기(개수). 넣을 수 없으면 이유를 글로.
// 자리는 모두 화면(전개도) mm로 주고받는다. 부른 쪽이 저장 자리(면·돌리기 전)로 바꾼다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/field_view.dart';
import '../electrical/busbar_punch_dies.dart' show punchDieLabel;
import 'plate_calc.dart' show plateSegSegDist;
import 'plate_painter.dart' show PlateTone;
import 'plate_ui.dart';

/// 놓는 방법.
enum PlateHolePattern { single, row, grid, corners, pcd }

/// 지름 단추 이름을 두 줄로: "φ13.5 (M12)" → ("φ13.5", "M12"). 볼트 이름이 없으면 둘째는 null.
(String, String?) plateDieLabel2(double d) {
  final s = punchDieLabel(d);
  final m = RegExp(r'^(.*?)\s*\((.+)\)$').firstMatch(s);
  return m == null ? (s, null) : (m.group(1)!, m.group(2));
}

const Map<PlateHolePattern, String> kPlateHolePatternNames = {
  PlateHolePattern.single: '하나',
  PlateHolePattern.row: '줄',
  PlateHolePattern.grid: '격자',
  PlateHolePattern.corners: '네 코너',
  PlateHolePattern.pcd: '원형 배치',
};

/// 홀 하나(화면 자리 mm, 지름, 장공 전체 길이 — 0이면 원형, 장공 각도 °).
class PlateHoleDraft {
  final Offset c;
  final double dia, slot, angle;
  const PlateHoleDraft(this.c, this.dia, {this.slot = 0, this.angle = 0});
}

/// 미리보기·위치 기준에 쓰는 판 정보(화면 자리 mm, y는 위가 +).
class PlateHoleCanvas {
  final List<Offset> outline;
  final List<(Offset, double)> cutouts; // 링 내경 등(가운데, 지름)
  final List<PlateHoleDraft> existing;
  final double minX, minY, maxX, maxY;
  final List<(double, double)> bendSpans; // 절곡부 x 범위
  final List<String> faces;
  final List<double> faceBase;
  const PlateHoleCanvas({
    required this.outline,
    this.cutouts = const [],
    this.existing = const [],
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    this.bendSpans = const [],
    this.faces = const [],
    this.faceBase = const [],
  });

  bool get bent => faceBase.isNotEmpty;
  Offset get center => Offset((minX + maxX) / 2, (minY + maxY) / 2);

  /// 이 자리에 홀을 뚫을 수 없는가(판 밖·외곽선에 걸림·링 안·절곡부·있던 홀과 겹침). 홀 지름·장공 길이·각도까지
  /// 본다(점검 50: 중심만 봐서 창에서는 괜찮은데 넣으면 "판 밖"·"절곡부" 오류가 떴다). 계산(platePlan)과 같은 기준.
  bool badAt(PlateHoleDraft h) {
    final (p1, p2, r) = _seg(h);
    if (!_inside(p1) || !_inside(p2)) return true;
    for (var i = 0; i < outline.length; i++) {
      final q1 = outline[i], q2 = outline[(i + 1) % outline.length];
      if (plateSegSegDist(p1, p2, q1, q2) < r - 1e-9) return true;
    }
    for (final (c, d) in cutouts) {
      if (plateSegSegDist(p1, p2, c, c) < d / 2 + r - 1e-9) return true;
    }
    final hx = (p2.dx - p1.dx).abs() / 2 + r;
    for (final (a, b) in bendSpans) {
      if (h.c.dx + hx > a && h.c.dx - hx < b) return true;
    }
    for (final e in existing) {
      final (q1, q2, er) = _seg(e);
      if (plateSegSegDist(p1, p2, q1, q2) < r + er - 1e-9) return true;
    }
    return false;
  }

  /// 홀 가운데 선(장공은 두 반원 가운데를 잇는 선)과 반지름.
  static (Offset, Offset, double) _seg(PlateHoleDraft h) {
    final half = h.slot > h.dia ? (h.slot - h.dia) / 2 : 0.0;
    final a = h.angle * math.pi / 180;
    final d = Offset(math.cos(a), math.sin(a)) * half;
    return (h.c - d, h.c + d, h.dia / 2);
  }

  bool _inside(Offset p) {
    if (outline.length < 3) return false;
    var inside = false;
    for (var i = 0, j = outline.length - 1; i < outline.length; j = i++) {
      final a = outline[i], b = outline[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }
}

/// 넣기 결과: 홀들(화면 자리)과 고른 면.
class PlateHoleInputResult {
  final List<PlateHoleDraft> holes;
  final int face;
  const PlateHoleInputResult(this.holes, this.face);
}

Future<PlateHoleInputResult?> showPlateHoleInput(
  BuildContext context, {
  required String title,
  required PlateHoleCanvas canvas,
  required List<double> dias,
  double defaultDia = 13.5,
  PlateHolePattern pattern = PlateHolePattern.single,
  List<PlateHolePattern> patterns = PlateHolePattern.values,
  PlateHoleDraft? edit,
  bool slot = false,
  int face = 0,
  String okText = '넣기',
}) => showPlateSheet<PlateHoleInputResult>(
  context,
  (_) => PlateHoleInputSheet(
    title: title,
    canvas: canvas,
    dias: dias,
    defaultDia: defaultDia,
    pattern: pattern,
    patterns: patterns,
    edit: edit,
    slot: slot,
    face: face,
    okText: okText,
  ),
);

class PlateHoleInputSheet extends StatefulWidget {
  const PlateHoleInputSheet({
    super.key,
    required this.title,
    required this.canvas,
    required this.dias,
    this.defaultDia = 13.5,
    this.pattern = PlateHolePattern.single,
    this.patterns = PlateHolePattern.values,
    this.edit,
    this.slot = false,
    this.face = 0,
    this.okText = '넣기',
  });

  final String title;
  final PlateHoleCanvas canvas;
  final List<double> dias;
  final double defaultDia;
  final PlateHolePattern pattern;
  final List<PlateHolePattern> patterns;
  final PlateHoleDraft? edit;
  final bool slot;
  final int face;
  final String okText;

  @override
  State<PlateHoleInputSheet> createState() => _PlateHoleInputSheetState();
}

String _f(double v) {
  var s = v.toStringAsFixed(2);
  while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
    s = s.substring(0, s.length - 1);
  }
  return s == '-0' ? '0' : s;
}

class _PlateHoleInputSheetState extends State<PlateHoleInputSheet> {
  PlateHoleCanvas get cv => widget.canvas;
  late PlateHolePattern _pat = widget.patterns.contains(widget.pattern)
      ? widget.pattern
      : widget.patterns.first;
  late bool _slot = widget.edit != null
      ? widget.edit!.slot > widget.edit!.dia
      : widget.slot;

  /// 장공 방향: 0 가로, 90 세로, 45, null = 각도 칸.
  late double? _dir = () {
    final a = widget.edit == null
        ? 0.0
        : ((widget.edit!.angle % 180) + 180) % 180;
    return [0.0, 90.0, 45.0].contains(a) ? a : null;
  }();
  late int _face = widget.face.clamp(0, math.max(0, cv.faces.length - 1));
  bool _center = false; // 위치 기준: false 왼쪽 아래(절곡은 면 시작), true 센터
  bool _rowX = true;

  late final _dia = TextEditingController(
    text: _f(widget.edit?.dia ?? widget.defaultDia),
  );
  late final _len = TextEditingController(
    text: _f(
      widget.edit != null && widget.edit!.slot > widget.edit!.dia
          ? widget.edit!.slot
          : 30,
    ),
  );
  late final _ang = TextEditingController(
    text: _f(
      widget.edit == null ? 0 : ((widget.edit!.angle % 180) + 180) % 180,
    ),
  );
  late final _x = TextEditingController(
    text: _f(widget.edit == null ? 25 : widget.edit!.c.dx - _ox(false)),
  );
  late final _y = TextEditingController(
    text: _f(widget.edit == null ? 25 : widget.edit!.c.dy - _oy(false)),
  );
  final _n = TextEditingController(text: '3');
  final _pitch = TextEditingController(text: '50');
  final _nx = TextEditingController(text: '2');
  final _ny = TextEditingController(text: '2');
  final _px = TextEditingController(text: '50');
  final _py = TextEditingController(text: '50');
  late final _pcd = TextEditingController(
    text: _f(
      (math.min(cv.maxX - cv.minX, cv.maxY - cv.minY) * 0.6).roundToDouble(),
    ),
  );
  final _pn = TextEditingController(text: '4');
  final _start = TextEditingController(text: '45');

  List<TextEditingController> get _all => [
    _dia,
    _len,
    _ang,
    _x,
    _y,
    _n,
    _pitch,
    _nx,
    _ny,
    _px,
    _py,
    _pcd,
    _pn,
    _start,
  ];

  @override
  void initState() {
    super.initState();
    // 원형 배치는 센터 기준이 알기 쉽다(가운데 0, 0)
    if (_pat == PlateHolePattern.pcd) {
      _setRef(true);
      _x.text = '0';
      _y.text = '0';
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  double? _v(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  /// 위치 기준점(화면 자리): 센터 또는 왼쪽 아래(절곡 판은 고른 면 시작).
  double _ox(bool center) => center ? cv.center.dx : _baseX;
  double _oy(bool center) => center ? cv.center.dy : cv.minY;

  /// 기준을 바꾸면 같은 자리가 되게 칸 값을 옮긴다.
  void _setRef(bool center) {
    if (center == _center) return;
    final x = _v(_x), y = _v(_y);
    final dx = _ox(_center) - _ox(center), dy = _oy(_center) - _oy(center);
    _center = center;
    if (x != null) _x.text = _f(x + dx);
    if (y != null) _y.text = _f(y + dy);
  }

  void _pick(PlateHolePattern p) => setState(() {
    final was = _pat;
    _pat = p;
    if (p == PlateHolePattern.pcd && was != p) {
      // 원형 배치는 판 센터에서 시작(가운데 0, 0)
      _setRef(true);
      _x.text = '0';
      _y.text = '0';
    }
    if (p == PlateHolePattern.corners) {
      if ((_v(_x) ?? 0) <= 0) _x.text = '20';
      if ((_v(_y) ?? 0) <= 0) _y.text = '20';
    }
  });

  double get _angle => _dir ?? (_v(_ang) ?? 0);

  /// 지금 칸 값으로 만든 홀들과, 안 되면 이유.
  (List<PlateHoleDraft>, String?) _build() {
    final d = _v(_dia);
    if (d == null || d <= 0) return (const [], '홀 지름을 넣으십시오.');
    var slot = 0.0;
    if (_slot) {
      final l = _v(_len);
      if (l == null || l <= d) {
        return (const [], '장공 길이는 폭(${_f(d)})보다 커야 합니다.');
      }
      slot = l;
    }
    PlateHoleDraft h(Offset c) =>
        PlateHoleDraft(c, d, slot: slot, angle: slot > 0 ? _angle : 0);
    final x = _v(_x), y = _v(_y);
    if (x == null || y == null) return (const [], '위치를 넣으십시오.');
    final o = Offset(_ox(_center) + x, _oy(_center) + y);
    switch (_pat) {
      case PlateHolePattern.single:
        return ([h(o)], null);
      case PlateHolePattern.row:
        final n = (_v(_n) ?? 0).round();
        final p = _v(_pitch) ?? 0;
        if (n < 1) return (const [], '개수를 넣으십시오.');
        if (n > 1 && p <= 0) return (const [], '피치(다음 홀까지)를 넣으십시오.');
        if (n > 200) return (const [], '한 번에 200개까지 넣습니다.');
        return (
          [
            for (var k = 0; k < n; k++)
              h(o + (_rowX ? Offset(k * p, 0) : Offset(0, k * p))),
          ],
          null,
        );
      case PlateHolePattern.grid:
        final nx = (_v(_nx) ?? 0).round(), ny = (_v(_ny) ?? 0).round();
        final px = _v(_px) ?? 0, py = _v(_py) ?? 0;
        if (nx < 1 || ny < 1) return (const [], '가로·세로 개수를 넣으십시오.');
        if ((nx > 1 && px <= 0) || (ny > 1 && py <= 0)) {
          return (const [], '가로·세로 피치를 넣으십시오.');
        }
        if (nx * ny > 400) return (const [], '한 번에 400개까지 넣습니다.');
        return (
          [
            for (var j = 0; j < ny; j++)
              for (var i = 0; i < nx; i++) h(o + Offset(i * px, j * py)),
          ],
          null,
        );
      case PlateHolePattern.corners:
        if (x <= 0 || y <= 0) return (const [], '가장자리에서 거리를 넣으십시오.');
        return (
          [
            h(Offset(cv.minX + x, cv.minY + y)),
            h(Offset(cv.maxX - x, cv.minY + y)),
            h(Offset(cv.maxX - x, cv.maxY - y)),
            h(Offset(cv.minX + x, cv.maxY - y)),
          ],
          null,
        );
      case PlateHolePattern.pcd:
        final pcd = _v(_pcd) ?? 0, n = (_v(_pn) ?? 0).round();
        final s = (_v(_start) ?? 0) * math.pi / 180;
        if (pcd <= 0) return (const [], 'PCD(홀을 놓는 원 지름)를 넣으십시오.');
        if (n < 1 || n > 72) return (const [], '홀 수는 1~72개입니다.');
        return (
          [
            for (var k = 0; k < n; k++)
              h(
                o +
                    Offset(
                          math.cos(s + 2 * math.pi * k / n),
                          math.sin(s + 2 * math.pi * k / n),
                        ) *
                        (pcd / 2),
              ),
          ],
          null,
        );
    }
  }

  /// 왼쪽 아래 기준의 가로 0(절곡 판은 고른 면 시작).
  double get _baseX =>
      cv.bent && _face < cv.faceBase.length ? cv.faceBase[_face] : cv.minX;

  Widget _num(
    String key,
    String label,
    TextEditingController c, {
    String? unit = 'mm',
    String? hint,
  }) => PlateNumField(
    fieldKey: key,
    label: label,
    controller: c,
    unit: unit,
    hint: hint,
    onChanged: (_) => setState(() {}),
  );

  @override
  Widget build(BuildContext context) {
    final (holes, err) = _build();
    final bad = holes.where(cv.badAt).length;
    final editing = widget.edit != null;
    final xName = _center
        ? '센터에서 가로 (+오른쪽)'
        : (cv.bent ? '면 시작에서 가로' : '왼쪽 끝에서');
    final yName = _center ? '센터에서 세로 (+위)' : '아래 끝에서';
    return PlateSheetFrame(
      title: widget.title,
      preview: CustomPaint(
        key: const Key('hi_preview'),
        painter: _HolePreviewPainter(
          canvas: cv,
          holes: holes,
          bad: cv.badAt,
          origin: Offset(
            _center ? cv.center.dx : _baseX,
            _center ? cv.center.dy : cv.minY,
          ),
          colors: fc,
        ),
        child: const SizedBox.expand(),
      ),
      info: Text(
        holes.isEmpty
            ? '칸을 채우면 위 그림에 홀이 보입니다.'
            : '${editing ? '고친 홀' : '새 홀 ${holes.length}개'}${bad > 0 ? ' · 판 밖·절곡부 $bad개(빨강)' : ''} · 점은 위치 기준',
        key: const Key('hi_info'),
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: bad > 0 ? fc.danger : fc.textSub,
        ),
      ),
      okText: editing
          ? widget.okText
          : (holes.length > 1
                ? '${widget.okText} (${holes.length}개)'
                : widget.okText),
      okKey: const Key('hs_ok'),
      error: err,
      onOk: err != null || holes.isEmpty
          ? null
          : () {
              // 누르는 순간 칸 값으로 다시 만든다
              final (now, e) = _build();
              if (e != null || now.isEmpty) return;
              Navigator.pop(
                context,
                PlateHoleInputResult(now, cv.bent ? _face : 0),
              );
            },
      children: [
        if (widget.patterns.length > 1)
          PlateSection('놓는 방법', [
            PlateSegments(joined: widget.patterns.length <= 5 ? true : false, [
              for (final p in widget.patterns)
                PlateOption(
                  'hp_${p.name}',
                  kPlateHolePatternNames[p]!,
                  _pat == p,
                  () => _pick(p),
                ),
            ]),
          ], first: true),
        PlateSection('홀', [
          PlateSegments([
            PlateOption(
              'hs_round',
              '원형 홀',
              !_slot,
              () => setState(() => _slot = false),
            ),
            PlateOption(
              'hs_slot',
              '장공',
              _slot,
              () => setState(() => _slot = true),
            ),
          ]),
          plateRow([
            _num('hs_dia', _slot ? '장공 폭' : '지름', _dia),
            if (_slot)
              _num('hs_slotlen', '장공 길이 (전체)', _len)
            else
              const SizedBox.shrink(),
          ]),
          if (widget.dias.isNotEmpty)
            PlateSegments(joined: widget.dias.length <= 5, [
              for (final d in widget.dias)
                PlateOption(
                  'hs_die_${(d * 100).round()}',
                  plateDieLabel2(d).$1,
                  _v(_dia) == d,
                  () => setState(() => _dia.text = _f(d)),
                  sub: plateDieLabel2(d).$2,
                ),
            ]),
          if (_slot) ...[
            PlateSegments([
              PlateOption(
                'hs_slotx',
                '가로',
                _dir == 0,
                () => setState(() => _dir = 0),
              ),
              PlateOption(
                'hs_sloty',
                '세로',
                _dir == 90,
                () => setState(() => _dir = 90),
              ),
              PlateOption(
                'hs_slot45',
                '45°',
                _dir == 45,
                () => setState(() => _dir = 45),
              ),
              PlateOption(
                'hs_slota',
                '각도',
                _dir == null,
                () => setState(() => _dir = null),
              ),
            ]),
            if (_dir == null)
              plateRow([
                _num('hs_angle', '장공 각도 (가로 0)', _ang, unit: '°'),
                const SizedBox.shrink(),
              ]),
          ],
        ], first: widget.patterns.length <= 1),
        if (cv.bent && cv.faces.isNotEmpty)
          PlateSection('홀이 있는 면', [
            PlateSegments(joined: cv.faces.length <= 4 ? null : false, [
              for (var k = 0; k < cv.faces.length; k++)
                PlateOption(
                  'hs_face_$k',
                  cv.faces[k],
                  _face == k,
                  () => setState(() => _face = k),
                ),
            ]),
          ]),
        PlateSection(
          _pat == PlateHolePattern.pcd
              ? '원 가운데 위치'
              : (_pat == PlateHolePattern.single ? '위치' : '첫 홀 위치'),
          [
            if (_pat != PlateHolePattern.corners)
              PlateSegments([
                PlateOption(
                  'hi_ref_corner',
                  cv.bent ? '면 시작·아래 끝 기준' : '왼쪽 아래 기준',
                  !_center,
                  () => setState(() => _setRef(false)),
                ),
                PlateOption(
                  'hi_ref_center',
                  '센터 기준',
                  _center,
                  () => setState(() => _setRef(true)),
                ),
              ]),
            plateRow(
              _pat == PlateHolePattern.corners
                  ? [
                      _num('hs_x', '가장자리에서 가로', _x),
                      _num('hs_y', '가장자리에서 세로', _y),
                    ]
                  : [_num('hs_x', xName, _x), _num('hs_y', yName, _y)],
            ),
            if (_pat == PlateHolePattern.row) ...[
              plateRow([
                _num('hs_n', '개수', _n, unit: '개'),
                _num('hs_pitch', '피치 (다음 홀까지)', _pitch),
              ]),
              PlateSegments([
                PlateOption(
                  'hs_rowx',
                  '가로로',
                  _rowX,
                  () => setState(() => _rowX = true),
                ),
                PlateOption(
                  'hs_rowy',
                  '세로로',
                  !_rowX,
                  () => setState(() => _rowX = false),
                ),
              ]),
            ],
            if (_pat == PlateHolePattern.grid) ...[
              plateRow([
                _num('hs_nx', '가로 개수', _nx, unit: '개'),
                _num('hs_ny', '세로 개수', _ny, unit: '개'),
              ]),
              plateRow([
                _num('hs_px', '가로 피치', _px),
                _num('hs_py', '세로 피치', _py),
              ]),
            ],
            if (_pat == PlateHolePattern.pcd) ...[
              plateRow([
                _num('hs_pcd', 'PCD (홀을 놓는 원 지름)', _pcd),
                _num('hs_pn', '홀 수', _pn, unit: '개'),
              ]),
              plateRow([
                _num('hs_start', '첫 홀 각도 (오른쪽 0)', _start, unit: '°'),
                const SizedBox.shrink(),
              ]),
            ],
          ],
        ),
      ],
    );
  }
}

/// 미리보기: 판(회색), 절곡부(주황 빗금 띠), 있던 홀(흰색), 새 홀(진하게, 못 뚫으면 빨강), 위치 기준점.
class _HolePreviewPainter extends CustomPainter {
  _HolePreviewPainter({
    required this.canvas,
    required this.holes,
    required this.bad,
    required this.origin,
    required this.colors,
  });

  final PlateHoleCanvas canvas;
  final List<PlateHoleDraft> holes;
  final bool Function(PlateHoleDraft) bad;
  final Offset origin;
  final FieldPalette colors;
  final PlateTone tone = PlateTone.now;

  @override
  void paint(Canvas c, Size size) {
    final cv = canvas;
    var x0 = cv.minX, x1 = cv.maxX, y0 = cv.minY, y1 = cv.maxY;
    for (final h in holes) {
      final r = math.max(h.dia, h.slot) / 2;
      x0 = math.min(x0, h.c.dx - r);
      x1 = math.max(x1, h.c.dx + r);
      y0 = math.min(y0, h.c.dy - r);
      y1 = math.max(y1, h.c.dy + r);
    }
    final w = math.max(x1 - x0, 1e-6), hgt = math.max(y1 - y0, 1e-6);
    const m = 14.0;
    final s = math.min((size.width - 2 * m) / w, (size.height - 2 * m) / hgt);
    final ox = (size.width - w * s) / 2, oy = (size.height - hgt * s) / 2;
    Offset sc(Offset p) => Offset(ox + (p.dx - x0) * s, oy + (y1 - p.dy) * s);

    if (cv.outline.length >= 3) {
      final path = Path()
        ..addPolygon([for (final p in cv.outline) sc(p)], true);
      c.drawPath(path, Paint()..color = tone.fill);
      c.drawPath(
        path,
        Paint()
          ..color = tone.edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    for (final (cc, d) in cv.cutouts) {
      c.drawCircle(sc(cc), d / 2 * s, Paint()..color = colors.background);
      c.drawCircle(
        sc(cc),
        d / 2 * s,
        Paint()
          ..color = tone.edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    for (final (a, b) in cv.bendSpans) {
      final r = Rect.fromPoints(sc(Offset(a, cv.maxY)), sc(Offset(b, cv.minY)));
      c.drawRect(r, Paint()..color = const Color(0x33E08A1E));
    }
    void hole(PlateHoleDraft h, Paint fill, Paint edge) {
      final r = math.max(h.dia / 2 * s, 2.5);
      if (h.slot <= h.dia) {
        c.drawCircle(sc(h.c), r, fill);
        c.drawCircle(sc(h.c), r, edge);
        return;
      }
      c.save();
      c.translate(sc(h.c).dx, sc(h.c).dy);
      c.rotate(-h.angle * math.pi / 180);
      final rr = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: math.max(h.slot * s, 2 * r),
          height: 2 * r,
        ),
        Radius.circular(r),
      );
      c.drawRRect(rr, fill);
      c.drawRRect(rr, edge);
      c.restore();
    }

    final white = Paint()..color = colors.background;
    final gray = Paint()
      ..color = tone.edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final h in cv.existing) {
      hole(h, white, gray);
    }
    for (final h in holes) {
      final b = bad(h);
      final col = b ? colors.danger : colors.brand;
      hole(
        h,
        Paint()..color = col.withValues(alpha: 0.35),
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
    // 위치 기준점
    final o = sc(origin);
    final dot = Paint()..color = colors.brand;
    c.drawCircle(o, 4, dot);
    c.drawCircle(
      o,
      7,
      Paint()
        ..color = colors.brand
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _HolePreviewPainter old) => true;
}
