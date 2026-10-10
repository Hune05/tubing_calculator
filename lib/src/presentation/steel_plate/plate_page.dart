// 철판 가공(10-10): 3t·4t 같은 철판을 레이저로 자르기만 하거나(평판·삼각 리브·자유 모양) 잘라서 꺾는(ㄱ·ㄷ·Z·모자)
// 브라켓의 전개도·꺾기선·구멍·무게를 계산하고, 레이저 업체에 보낼 DXF와 가공 지시서 PDF·카톡 글을 만든다.
// 계산은 plate_calc.dart, 꺾기는 부스바 절곡 계산을 그대로 쓴다. 화면 틀은 형강 브라켓·접지바와 같다.
// 10-10 나중: 첫 화면(plate_home_page.dart)에서 "레이저 절단"과 "절단 + 절곡"을 따로 연다(입력·저장도 따로).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/app_components.dart' show showAppSnack;
import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/theme/app_icon_set.dart';
import '../../core/theme/field_view.dart';
import '../calculator/widgets/swipe_delete.dart' show calcNavCompact;
import '../common/app_icons.dart';
import '../common/calc_form_parts.dart';
import '../electrical/busbar_bend_painter.dart' show BusbarShapePainter;
import '../electrical/busbar_punch_dies.dart';
import '../electrical/busbar_saved_specs.dart';
import '../electrical/elec_form_parts.dart';
import '../steel_bracket/bracket_pdf.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'plate_3d_view.dart';
import 'plate_calc.dart';
import 'plate_corner_dialog.dart';
import 'plate_dxf.dart';
import 'plate_hole_editor.dart';
import 'plate_painter.dart';
import 'plate_ui.dart';

Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

const List<String> kPlateBasis = [
  '가공: "레이저 절단"은 평판·삼각 리브·좌표 입력을 자르기만 하고, "절단 + 절곡"은 ㄱ·ㄷ·Z·모자로 절곡합니다. 절곡은 전개도(펴 놓은 모양)를 자른 뒤 절곡선에서 접습니다. 둘은 철판 가공 첫 화면에서 따로 들어가고 입력도 따로 남습니다.',
  '평판 코너: R은 둥글게, C는 코너에서 양쪽 변으로 같은 길이만큼 45°로 잘라 내고, 따내기는 코너에서 가로 × 세로 사각을 잘라 냅니다. 좌표 입력은 꼭짓점 줄 끝에 ,r10 · ,c5 · ,n20x15처럼 붙입니다. 코너 처리가 옆 변보다 크면 알립니다.',
  '절곡 치수는 모두 바깥 치수입니다. 전개 길이 = 바깥 치수 합 − 절곡마다 공제값. 공제값(90°) = 2 × (내R + 두께) − π/2 × (내R + K값 × 두께). K값을 모르면 일반값 0.33을 쓰고, 업체가 알려 준 공제값을 넣으면 그 값이 나오게 K값을 맞춥니다. 절곡 계산은 부스바 가공과 같은 식입니다.',
  '내R은 비우면 두께와 같게 봅니다. 레이저 업체·절곡기 금형마다 공제값이 다르니 처음 주문 때 업체 값으로 맞추고 "이 두께 값 저장"으로 남겨 두십시오.',
  '절곡선은 절곡부의 가운데 선입니다. "UP"은 DXF·전개도를 위에서 본 쪽으로 접는다는 뜻입니다. 모자는 발 → 다리 → 윗면 → 다리 → 발 차례로 UP·DOWN·DOWN·UP 절곡합니다.',
  '홀 위치: 평판·리브·좌표 입력은 판의 왼쪽 아래 모서리에서 잰 (가로, 세로)입니다. 그림·가공 도면·DXF에는 센터선(파란 쇄선, 그림 위 "센터선"으로 켜고 끔, DXF는 CL)을 긋습니다. 홀 탭에서 홀을 고르면 판 끝과 센터에서 몇 mm인지 나옵니다. 절곡 판은 면마다 잽니다: 가로는 그 면 시작(첫 면은 판 끝, 다른 면은 앞 면 바깥면)에서, 세로는 아래 가장자리에서. 전개도 자리로 바꿔 DXF에 넣습니다.',
  '홀은 절곡선에서 2 × 두께 + 내R 이상 떼라고 알립니다(일반 판금 규칙). 홀이 절곡부에 걸리거나 판 밖으로 나오거나 서로 겹치면 만들 수 없다고 알립니다.',
  '짧은 면: 바깥 치수가 두께의 5배보다 짧으면 절곡기 V홈(보통 두께의 6~8배)에 걸치지 못할 수 있다고 알립니다. 업체 금형에 따라 다릅니다.',
  'DXF: AutoCAD R12 형식, 단위 mm. CUT 층(외곽·홀·장공), BEND 층(절곡선), NOTE 층(절곡 방향 UP/DOWN), DIM 층(센터선 CL). 대부분의 레이저 업체 프로그램이 읽습니다.',
  '중량 = (외곽 넓이 − 홀 넓이) × 두께 × 밀도(철판 7.85 · SUS 7.93 · 알루미늄 2.70 g/cm³).',
  '이 화면은 제작 치수만 계산합니다. 하중·강도는 계산하지 않습니다.',
];

/// 가공 방식별 모양 칩(모양, 이름).
const List<(PlateShape, String)> kPlateCutShapes = [
  (PlateShape.flat, '평판'),
  (PlateShape.rib, '삼각 리브'),
  (PlateShape.free, '좌표 입력'),
];
const List<(PlateShape, String)> kPlateBendShapes = [
  (PlateShape.l, 'ㄱ자'),
  (PlateShape.u, 'ㄷ자'),
  (PlateShape.z, 'Z자'),
  (PlateShape.hat, '모자'),
];

String plateShapeName(PlateShape s) =>
    [...kPlateCutShapes, ...kPlateBendShapes].firstWhere((e) => e.$1 == s).$2;

class PlatePage extends StatefulWidget {
  const PlatePage({
    super.key,
    this.bend = false,
    this.share = _defaultShare,
    this.shareDxf,
    this.initial,
  });

  /// 손그림 읽기에서 넘겨 받은 모양(자유 모양·구멍·두께). 남아 있던 입력 위에 덮고, 알림으로 되돌릴 수 있다.
  final Map<String, Object?>? initial;

  /// true: 절단 + 절곡(ㄱ·ㄷ·Z·모자), false: 레이저 절단(평판·삼각 리브·자유 모양).
  final bool bend;

  final Future<void> Function(String text) share;

  /// DXF 보내기(시험에서 바꿔 끼운다). null이면 공유 창.
  final Future<void> Function(String dxf)? shareDxf;

  /// 10-10 전에는 두 방식이 칸 하나를 같이 썼다. 새 칸이 비어 있을 때 같은 방식 것만 옮겨 읽는다(옛 칸은 그대로 둔다).
  static const legacyDraftKey = 'steel_plate_draft_v1';
  static const legacySavedKey = 'steel_plate_saved_v1';
  static String draftKeyOf(bool bend) =>
      bend ? 'steel_plate_bend_draft_v1' : 'steel_plate_cut_draft_v1';
  static String savedKeyOf(bool bend) =>
      bend ? 'steel_plate_bend_saved_v1' : 'steel_plate_cut_saved_v1';
  static const bendTableKey = 'plate_bend_table_v1';

  @override
  State<PlatePage> createState() => _PlatePageState();
}

class _PlatePageState extends State<PlatePage>
    with
        CalcFormParts<PlatePage>,
        RecentCalcHistoryMixin<PlatePage>,
        ElecTabParts<PlatePage> {
  @override
  String? get calcHistoryStorageKey =>
      'calc_history_steel_plate_${widget.bend ? 'bend' : 'cut'}';

  bool get _bend => widget.bend;
  late PlateShape _shape = _bend ? PlateShape.l : PlateShape.flat;
  PlateMaterial _mat = PlateMaterial.steel;
  final List<PlateHoleSpec> _holes = [];
  int _rotQ = 0; // 판을 반시계로 90° 돌린 횟수(평판·리브·자유)
  // 평판 네 귀(왼쪽 아래·오른쪽 아래·오른쪽 위·왼쪽 위 차례)
  List<PlateCorner> _corners = List.filled(4, PlateCorner.square);
  final _ca = TextEditingController(text: '10');
  final _cb = TextEditingController(text: '10');
  Map<String, (double, double)> _bendTable = {};
  List<double> _dies = const [];

  // 그림에서 치수를 누르면 갈 칸
  // 판 가운데 십자선 켜고 끄기(기억, 구멍 탭·지시서 그림도 따른다)
  bool _showCenter = true;
  static const _centerKey = 'plate_center_lines_v1';
  final _scroll = ScrollController();

  // 좌표 입력의 가로·세로(10-10 사용자: "판 크기 선택 못 하냐"): 넣으면 모양 전체와 홀 위치를 그 크기로 늘이거나 줄인다.
  // 고치기 시작할 때의 꼭짓점·홀을 잡아 두고 거기서 늘이므로, 한 자씩 칠 때 생기는 중간 값이 쌓이지 않는다.
  final _fw = TextEditingController(), _fh = TextEditingController();
  final _fwFocus = FocusNode(), _fhFocus = FocusNode();
  (String, List<PlateHoleSpec>)? _freeBase;
  final _lenFocus = FocusNode(), _widFocus = FocusNode();
  final _raFocus = FocusNode(), _rbFocus = FocusNode();

  final _job = TextEditingController();
  final _t = TextEditingController(text: '3');
  final _len = TextEditingController(text: '200');
  final _wid = TextEditingController(text: '100');

  final _l1 = TextEditingController(text: '50');
  final _l2 = TextEditingController(text: '50');
  final _l3 = TextEditingController(text: '50');
  final _angle = TextEditingController(text: '90');
  final _ribA = TextEditingController(text: '100');
  final _ribB = TextEditingController(text: '100');
  final _ribC = TextEditingController(text: '15');
  final _points = TextEditingController(
    text: '0,0\n200,0\n200,80\n120,150\n0,150',
  );
  final _r = TextEditingController();
  final _bd = TextEditingController();
  final _qty = TextEditingController(text: '1');

  Timer? _saveTimer;
  bool _draftReady = false;

  List<TextEditingController> get _fields => [
    _job,
    _t,
    _len,
    _wid,
    _l1,
    _l2,
    _l3,
    _angle,
    _ribA,
    _ribB,
    _ribC,
    _points,
    _r,
    _bd,
    _qty,
  ];
  static const _fieldKeys = [
    'jn',
    't',
    'len',
    'wid',
    'l1',
    'l2',
    'l3',
    'ang',
    'ra',
    'rb',
    'rc',
    'pts',
    'r',
    'bd',
    'n',
  ];

  @override
  void initState() {
    super.initState();
    _syncFreeSize();
    for (final n in [_fwFocus, _fhFocus]) {
      n.addListener(() {
        if (n.hasFocus) return;
        _freeBase = null;
        _syncFreeSize();
      });
    }
    _loadDraft();
    _loadBendTable();
    readPunchDies().then((d) {
      if (mounted && d.isNotEmpty) setState(() => _dies = d);
    });
    SharedPreferences.getInstance()
        .then((p) {
          final c = p.getBool(_centerKey);
          if (c != null && mounted) setState(() => _showCenter = c);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveNow();
    for (final c in _fields) {
      c.dispose();
    }
    _ca.dispose();
    _cb.dispose();
    _scroll.dispose();
    for (final n in [_lenFocus, _widFocus, _raFocus, _rbFocus]) {
      n.dispose();
    }
    _fw.dispose();
    _fh.dispose();
    _fwFocus.dispose();
    _fhFocus.dispose();
    super.dispose();
  }

  String _draft() => jsonEncode({
    'bend': _bend,
    'sh': _shape.name,
    'mat': _mat.name,
    'holes': [for (final h in _holes) h.toJson()],
    'rot': _rotQ,
    'corners': [for (final c in _corners) c.toJson()],
    for (var i = 0; i < _fields.length; i++) _fieldKeys[i]: _fields[i].text,
    // 첫 화면 "이어서" 줄에 쓰는 글(읽을 때는 안 쓴다)
    'lbl': _label(),
  });

  String _label() {
    final p = _plan();
    if (p == null) return '';
    return '${plateShapeName(_shape)} ${fmt(_num(_t))}T · ${fmt(p.flatLength, 1)} × ${fmt(p.flatWidth, 1)}';
  }

  @override
  Map<String, Object?>? historySnapshot() =>
      jsonDecode(_draft()) as Map<String, dynamic>;

  @override
  void applyHistorySnapshot(Map<String, dynamic> m) => _applyMap(m);

  void _applyMap(Map<String, dynamic> m) {
    _freeBase = null;
    final sh = PlateShape.values.where((s) => s.name == m['sh']);
    if (sh.isNotEmpty) _shape = sh.first;
    final mat = PlateMaterial.values.where((s) => s.name == m['mat']);
    if (mat.isNotEmpty) _mat = mat.first;
    // 가공 방식과 모양이 어긋나면 그 방식의 첫 모양으로
    if (plateShapeBends(_shape) != _bend) {
      _shape = _bend ? PlateShape.l : PlateShape.flat;
    }
    final rot = m['rot'];
    _rotQ = rot is int && rot >= 0 && rot <= 3 ? rot : 0;
    for (var i = 0; i < _fields.length; i++) {
      final v = m[_fieldKeys[i]];
      if (v is String) _fields[i].text = v;
    }
    final cs = m['corners'];
    if (cs is List && cs.length == 4) {
      _corners = [for (final c in cs) PlateCorner.fromJson(c)];
    } else if (m.containsKey('cr')) {
      // 10-10 전 "모서리 R"(네 귀 같음)
      final cr = double.tryParse('${m['cr'] ?? ''}'.trim()) ?? 0;
      _corners = List.filled(
        4,
        cr > 0 ? PlateCorner(PlateCornerKind.round, cr) : PlateCorner.square,
      );
    }
    _syncCornerFields();
    _syncFreeSize();
    final hs = m['holes'];
    if (hs is List) {
      _holes.clear();
      // 10-10 전 저장은 구멍 묶음(줄·네 귀)이었다 → 하나하나로 풀어 옮긴다(네 귀는 지금 판 크기로).
      final base = platePlan(_input().withHoles(const [], rotQ: 0));
      for (final o in hs) {
        final s = PlateHoleSpec.fromJson(o);
        if (s != null) {
          _holes.add(s);
          continue;
        }
        final g = PlateHoleGroup.fromJson(o);
        if (g != null) {
          _holes.addAll(
            g.expand(
              minX: base.minX,
              minY: base.minY,
              maxX: base.maxX,
              maxY: base.maxY,
            ),
          );
        }
      }
    }
  }

  Future<void> _loadDraft() async {
    try {
      final p = await SharedPreferences.getInstance();
      var raw = p.getString(PlatePage.draftKeyOf(_bend));
      if (raw == null) {
        final old = p.getString(PlatePage.legacyDraftKey);
        final m = old == null ? null : jsonDecode(old);
        if (m is Map && (m['bend'] ?? true) == _bend) raw = old;
      }
      await _moveOldSaved(p);
      if (raw != null && mounted) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        setState(() => _applyMap(m));
      }
    } catch (_) {}
    _draftReady = true;
    final init = widget.initial;
    if (init != null && mounted) {
      final before = _draft();
      _set(() => _applyMap(Map<String, dynamic>.from(init)));
      showAppSnack(
        context,
        '스케치에서 옮겨 왔습니다. 홀은 "홀 배치"에서 더 고칠 수 있습니다.',
        onUndo: () =>
            _set(() => _applyMap(jsonDecode(before) as Map<String, dynamic>)),
        duration: const Duration(seconds: 6),
      );
    }
  }

  /// 옛 "저장한 규격"(두 방식이 한 칸)에서 이 방식 것만 새 칸으로 옮긴다(한 번만, 옛 칸은 그대로).
  Future<void> _moveOldSaved(SharedPreferences p) async {
    final key = PlatePage.savedKeyOf(_bend);
    if (p.containsKey(key)) return;
    final old = p.getString(PlatePage.legacySavedKey);
    final l = old == null ? null : jsonDecode(old);
    if (l is! List) return;
    await p.setString(
      key,
      jsonEncode([
        for (final e in l)
          if (e is Map &&
              e['data'] is Map &&
              ((e['data'] as Map)['bend'] ?? true) == _bend)
            e,
      ]),
    );
  }

  Future<void> _loadBendTable() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(PlatePage.bendTableKey);
      if (raw == null) return;
      final m = jsonDecode(raw);
      if (m is! Map) return;
      final out = <String, (double, double)>{};
      m.forEach((k, v) {
        if (k is String && v is Map && v['r'] is num && v['bd'] is num) {
          out[k] = ((v['r'] as num).toDouble(), (v['bd'] as num).toDouble());
        }
      });
      if (mounted) setState(() => _bendTable = out);
    } catch (_) {}
  }

  Future<void> _saveBendTable() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        PlatePage.bendTableKey,
        jsonEncode({
          for (final e in _bendTable.entries)
            e.key: {'r': e.value.$1, 'bd': e.value.$2},
        }),
      );
    } catch (_) {}
  }

  void _saveSoon() {
    if (!_draftReady) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _saveNow);
  }

  void _saveNow() {
    if (!_draftReady) return;
    final d = _draft();
    SharedPreferences.getInstance()
        .then((p) => p.setString(PlatePage.draftKeyOf(_bend), d))
        .catchError((_) => false);
  }

  void _set(VoidCallback f) {
    setState(f);
    _saveSoon();
  }

  /// 좌표 입력 꼭짓점을 감싸는 상자(꼭짓점 3개 미만이면 null).
  Rect? _freeBounds(List<(Offset, PlateCorner)> vs) {
    if (vs.length < 3) return null;
    var l = double.infinity, b = double.infinity;
    var r = -double.infinity, t = -double.infinity;
    for (final (p, _) in vs) {
      if (p.dx < l) l = p.dx;
      if (p.dx > r) r = p.dx;
      if (p.dy < b) b = p.dy;
      if (p.dy > t) t = p.dy;
    }
    return Rect.fromLTRB(l, b, r, t);
  }

  /// 가로·세로 칸을 지금 꼭짓점 크기로(고치는 중인 칸은 그대로).
  void _syncFreeSize() {
    final b = _freeBounds(parsePlateVertices(_points.text));
    if (b == null) return;
    if (!_fwFocus.hasFocus) _fw.text = fmt(b.width);
    if (!_fhFocus.hasFocus) _fh.text = fmt(b.height);
  }

  /// 가로·세로 칸 값으로 모양 전체(꼭짓점)와 홀 위치를 늘이거나 줄인다. 홀 지름·코너 처리 크기는 그대로.
  void _scaleFree() => _set(() {
    final base = _freeBase ??= (_points.text, List.of(_holes));
    final vs = parsePlateVertices(base.$1);
    final b = _freeBounds(vs);
    if (b == null || b.width <= 0 || b.height <= 0) return;
    final w = readNum(_fw), h = readNum(_fh);
    final sx = w != null && w > 0 ? w / b.width : 1.0;
    final sy = h != null && h > 0 ? h / b.height : 1.0;
    double r1(double v) => (v * 10).round() / 10;
    Offset sc(Offset p) => Offset(
      r1(b.left + (p.dx - b.left) * sx),
      r1(b.top + (p.dy - b.top) * sy),
    );
    _points.text = platePointsText(
      [for (final v in vs) sc(v.$1)],
      [for (final v in vs) v.$2],
    );
    _holes
      ..clear()
      ..addAll([
        for (final h0 in base.$2)
          () {
            final q = sc(Offset(h0.u, h0.v));
            return h0.copyWith(u: q.dx, v: q.dy);
          }(),
      ]);
  });

  double _num(TextEditingController c) {
    final v = readNum(c);
    return v == null || v < 0 ? 0 : v;
  }

  String get _tKey => fmt(_num(_t));

  /// 두께를 바꾸면 저장한 그 두께의 반경·공제값을 채운다(없으면 비움 = 일반값).
  void _setThickness(String v) => _set(() {
    _t.text = v;
    final saved = _bendTable[_tKey];
    _r.text = saved == null ? '' : fmt(saved.$1);
    _bd.text = saved == null ? '' : fmt(saved.$2);
  });

  PlateInput _input() {
    final vs = parsePlateVertices(_points.text);
    return PlateInput(
      shape: _shape,
      material: _mat,
      t: _num(_t),
      length: _num(_len),
      width: _num(_wid),
      corners: List.of(_corners),
      legs: [_num(_l1), _num(_l2), _num(_l3)],
      angle: readNum(_angle) ?? 90,
      r: readNum(_r),
      bd90: readNum(_bd),
      ribA: _num(_ribA),
      ribB: _num(_ribB),
      ribC: _num(_ribC),
      points: [for (final (p, _) in vs) p],
      pointCorners: [for (final (_, c) in vs) c],
      holes: List.of(_holes),
      rotQ: _rotQ,
      qty: _num(_qty).round().clamp(1, 9999),
    );
  }

  bool get _ready => _num(_t) > 0;
  PlatePlan? _plan() => _ready ? platePlan(_input()) : null;
  int get _qtyN => _num(_qty).round().clamp(1, 9999);

  // ── 글 ──

  String _dimsText() => switch (_shape) {
    PlateShape.flat =>
      '${fmt(_num(_len))} × ${fmt(_num(_wid))}${_cornersText()}',
    PlateShape.rib =>
      '${fmt(_num(_ribA))} × ${fmt(_num(_ribB))}${_num(_ribC) > 0 ? ' · 모서리 따내기 ${fmt(_num(_ribC))}' : ''}',
    PlateShape.free => () {
      final vs = parsePlateVertices(_points.text);
      final k = vs.where((v) => !v.$2.isNone).length;
      return '꼭짓점 ${vs.length}개${k > 0 ? ' · 코너 처리 $k곳' : ''}';
    }(),
    PlateShape.l =>
      '1면 ${fmt(_num(_l1))} · 2면 ${fmt(_num(_l2))} · 폭 ${fmt(_num(_wid))} · ${fmt(readNum(_angle) ?? 90)}°',
    PlateShape.u || PlateShape.z =>
      '1면 ${fmt(_num(_l1))} · ${_shape == PlateShape.z ? '높이' : '2면'} ${fmt(_num(_l2))} · 3면 ${fmt(_num(_l3))} · 폭 ${fmt(_num(_wid))}',
    PlateShape.hat =>
      '발 ${fmt(_num(_l1))} · 높이 ${fmt(_num(_l2))} · 윗면 ${fmt(_num(_l3))} · 폭 ${fmt(_num(_wid))}',
  };

  /// 평판 귀 처리 글: " · 네 귀 R10" 또는 " · 왼쪽 아래 R10 · 오른쪽 위 C5". 다 직각이면 빈 글.
  String _cornersText() {
    final cs = _corners;
    if (cs.every((c) => c.isNone)) return '';
    if (cs.every((c) => c.label == cs.first.label)) {
      return ' · 네 코너 ${cs.first.label}';
    }
    return [
      for (var k = 0; k < 4; k++)
        if (!cs[k].isNone) ' · ${kPlateCornerNames[k]} ${cs[k].label}',
    ].join();
  }

  String _bendLine(PlatePlan p, int n) {
    final b = p.bends[n];
    return '절곡 ${n + 1}: 왼쪽 끝에서 ${fmt(b.center, 1)}mm(절곡부 ${fmt(b.start, 1)}~${fmt(b.end, 1)}) · ${b.turn >= 0 ? 'UP' : 'DOWN'} ${fmt(b.turn.abs())}°';
  }

  String _holeLine(PlatePlan p, PlateHole h) {
    final face = p.isBent
        ? '${p.faceNames[h.face.clamp(0, p.faceNames.length - 1)]} ${fmt(h.u, 1)}·${fmt(h.v, 1)} → '
        : '';
    return '홀 ${h.label} ${plateHoleKind(h)}: $face전개도 ${fmt(h.c.dx - p.minX, 1)} · ${fmt(h.c.dy - p.minY, 1)}';
  }

  String _bendCond(PlatePlan p) =>
      '내R ${fmt(p.rUsed)} · 공제값(90°) ${fmt(p.bd90Used, 2)}mm · K값 ${p.kUsed.toStringAsFixed(2)}${readNum(_bd) == null ? '(일반값)' : '(넣은 공제값)'}';

  String _shareText(PlatePlan p) {
    final b = StringBuffer(
      '[철판 가공] ${plateShapeName(_shape)} · ${kPlateMaterials[_mat]!.$1} ${fmt(_num(_t))}T · $_qtyN장',
    );
    if (_job.text.trim().isNotEmpty) b.write(' · ${_job.text.trim()}');
    b.write(
      '\n치수: ${_dimsText()} (mm${plateShapeBends(_shape) ? ', 바깥 치수' : ''})',
    );
    b.write(
      '\n${_bend ? '전개' : '판'} 크기: ${fmt(p.flatLength, 1)} × ${fmt(p.flatWidth, 1)}mm · 개당 약 ${fmt(p.kgEach, 2)}kg',
    );
    if (p.bends.isNotEmpty) {
      b.write('\n${_bendCond(p)}');
      for (var n = 0; n < p.bends.length; n++) {
        b.write('\n ${_bendLine(p, n)}');
      }
    }
    if (p.holes.isNotEmpty) {
      b.write('\n홀 ${p.holes.length}개(전개도 왼쪽 아래에서 가로 · 세로):');
      for (final h in p.holes) {
        b.write('\n ${_holeLine(p, h)}');
      }
    }
    for (final s in p.problems) {
      b.write('\n※ $s');
    }
    return b.toString();
  }

  Future<BracketPdfInput> _pdfInput(PlatePlan p) async {
    final flat = await renderPainterPng(
      PlatePainter(
        plan: p,
        text: const Color(0xFF1F2933),
        sub: const Color(0xFF55636D),
        bg: Colors.white,
        fontScale: 2.2,
        showCenter: _showCenter,
      ),
    );
    final more = <(String, Uint8List)>[];
    if (p.bendPlan != null) {
      final t = _num(_t);
      more.add((
        '측면도',
        await renderPainterPng(
          BusbarShapePainter(
            plan: p.bendPlan!,
            rho: p.rUsed + p.kUsed * t,
            thickness: t,
            text: const Color(0xFF1F2933),
            sub: const Color(0xFF55636D),
            line: const Color(0xFFD1D5DB),
            metal: kPlateSteelShade,
          ),
          width: 1200,
          height: 600,
        ),
      ));
    }
    return BracketPdfInput(
      title: _job.text,
      docTitle: '철판 가공 도면',
      drawingCaption: _bend ? '전개도 (mm, 주황 점선 = 절곡선)' : '판 모양 (mm)',
      drawingPng: flat,
      moreDrawings: more,
      summary: [
        ('가공', _bend ? '레이저 절단 + 절곡' : '레이저 절단만'),
        ('모양', '${plateShapeName(_shape)} · ${_dimsText()}'),
        ('재질', '${kPlateMaterials[_mat]!.$1} ${fmt(_num(_t))}T'),
        (
          _bend ? '전개 크기' : '판 크기',
          '${fmt(p.flatLength, 1)} × ${fmt(p.flatWidth, 1)} mm',
        ),
        (
          '수량',
          '$_qtyN장 · 개당 약 ${fmt(p.kgEach, 2)}kg · 모두 약 ${fmt(p.kgTotal, 1)}kg',
        ),
        if (p.bends.isNotEmpty) ('절곡 조건', _bendCond(p)),
      ],
      sections: [
        if (p.bends.isNotEmpty)
          BracketPdfSection(
            '절곡 (전개도 왼쪽 끝에서, mm)',
            const [],
            headers: const ['번호', '절곡선', '절곡부', '방향', '각도'],
            rows: [
              for (var n = 0; n < p.bends.length; n++)
                [
                  '${n + 1}',
                  fmt(p.bends[n].center, 1),
                  '${fmt(p.bends[n].start, 1)} ~ ${fmt(p.bends[n].end, 1)}',
                  p.bends[n].turn >= 0 ? 'UP' : 'DOWN',
                  '${fmt(p.bends[n].turn.abs())}°',
                ],
            ],
          ),
        if (p.holes.isNotEmpty)
          BracketPdfSection(
            '홀 (전개도 왼쪽 아래에서, mm)',
            const [],
            headers: const ['번호', '모양', '가로', '세로', '면 기준'],
            rows: [
              for (final h in p.holes)
                [
                  h.label,
                  plateHoleKind(h),
                  fmt(h.c.dx, 1),
                  fmt(h.c.dy, 1),
                  plateShapeBends(_shape)
                      ? '${p.faceNames[h.face.clamp(0, p.faceNames.length - 1)]} ${fmt(h.u, 1)} · ${fmt(h.v, 1)}'
                      : '-',
                ],
            ],
          ),
      ],
      notes: [...p.problems, ...p.notes],
    );
  }

  Future<void> _sendDxf(PlatePlan p) async {
    if (widget.shareDxf != null) {
      await widget.shareDxf!(plateDxf(p, thickness: _num(_t)));
      return;
    }
    await sharePlateDxf(
      p,
      thickness: _num(_t),
      title: _job.text.trim().isEmpty
          ? '${plateShapeName(_shape)}_${fmt(_num(_t))}T'
          : _job.text.trim(),
      message:
          '철판 가공 DXF · ${kPlateMaterials[_mat]!.$1} ${fmt(_num(_t))}T · $_qtyN장${p.bends.isNotEmpty ? ' · 절곡 ${p.bends.length}곳(BEND 층, 방향은 NOTE 층)' : ''}',
    );
  }

  Future<void> _openSaved() => openSavedSpecs(
    context,
    storageKey: PlatePage.savedKeyOf(_bend),
    current: () => jsonDecode(_draft()) as Map<String, dynamic>,
    summaryOf: (m) {
      final sh = PlateShape.values.where((s) => s.name == m['sh']);
      return '${sh.isEmpty ? '' : plateShapeName(sh.first)} · ${m['t'] ?? ''}T · 홀 ${m['holes'] is List ? (m['holes'] as List).length : 0}개';
    },
    defaultName: _job.text.trim().isNotEmpty
        ? _job.text.trim()
        : '${plateShapeName(_shape)} ${_t.text}T',
    onLoad: (m) => _set(() => _applyMap(m)),
    surface: fc.surface,
    text: fc.text,
    textSub: fc.textSub,
  );

  // ── 구멍 ──

  /// 구멍 요약: "구멍 6개 · φ13.5 4 · 장공 11×30 2".
  String _holeSummary() {
    if (_holes.isEmpty) {
      return '홀이 없습니다. 위 그림의 판이나 아래 단추를 눌러 넣습니다.';
    }
    final kinds = <String, int>{};
    for (final h in _holes) {
      final k = h.isSlot ? '장공 ${fmt(h.dia)}×${fmt(h.slot)}' : 'φ${fmt(h.dia)}';
      kinds[k] = (kinds[k] ?? 0) + 1;
    }
    return '홀 ${_holes.length}개 · ${kinds.entries.map((e) => '${e.key} ${e.value}').join(' · ')}${_rotQ != 0 ? ' · 판 ${_rotQ * 90}° 회전' : ''}';
  }

  // ── 탭(10-10 사용자: "벤딩 페이지처럼 순차적으로 다 나누어, 한 페이지에 때려 박지 말고", "탭으로 다 분리") ──
  // 모양 → (꺾기) → 구멍 → 결과 → 보내기. 10-10 화면 정리(사용자: "각 페이지 구성이 정리된 게 아니고 대충 뿌려 놓은 것"):
  // 탭마다 같은 자리의 위 그림 칸(판·전개도 / 옆모습 / 3D를 오른쪽 위에서 고름) + 아래 흰 작업판(제목 줄 · 묶음 · 맨 아래 이전/다음).

  int _tab = 0;

  /// 위 그림 칸 보기: 'flat' 판(전개도), 'side' 옆모습(꺾는 판만), '3d'.
  String _view = 'flat';

  List<(String, String)> get _tabs => [
    ('shape', '모양'),
    if (_bend) ('bend', '절곡'),
    ('holes', '홀'),
    ('result', '결과'),
    ('send', '보내기'),
  ];

  void _goTab(String id) {
    final i = _tabs.indexWhere((t) => t.$1 == id);
    if (i < 0) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _tab = i);
  }

  /// 예전 이름(그림에서 판을 누르면 구멍 탭으로).
  void _openEditor() => _goTab('holes');

  String _labelOf(String id) => _tabs.firstWhere((t) => t.$1 == id).$2;

  /// 맨 아래 고정 줄: 이전 · 다음(마지막 탭은 이전만).
  Widget _footer(String id) {
    final t = _tabs;
    final i = t.indexWhere((e) => e.$1 == id);
    final prev = i > 0 ? t[i - 1].$1 : null;
    final next = i >= 0 && i + 1 < t.length ? t[i + 1].$1 : null;
    return PlateFooter(
      backKey: prev == null ? null : 'pl_prev_$prev',
      onBack: prev == null ? null : () => _goTab(prev),
      nextKey: next == null ? null : 'pl_next_$next',
      nextLabel: next == null ? null : _labelOf(next),
      onNext: next == null ? null : () => _goTab(next),
    );
  }

  Widget _f(
    String key,
    String? label,
    TextEditingController c, {
    FocusNode? focus,
    String? unit = 'mm',
    String? hint,
  }) => PlateNumField(
    fieldKey: key,
    label: label,
    controller: c,
    focus: focus,
    unit: unit,
    hint: hint,
    onChanged: (_) => setState(_saveSoon),
  );

  // ── 위 그림 칸 ──

  String _viewOf(PlatePlan p) =>
      _view == 'side' && p.bendPlan == null ? 'flat' : _view;

  Widget _canvas(PlatePlan? p) {
    if (p == null) {
      return Center(
        child: Text(
          '두께와 치수를 넣으면 그림이 나옵니다.',
          style: TextStyle(color: fc.textSub, fontWeight: FontWeight.w700),
        ),
      );
    }
    switch (_viewOf(p)) {
      case '3d':
        return Plate3dView(plan: p, t: _num(_t));
      case 'side':
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 52, 12, 30),
          child: CustomPaint(
            key: const Key('pl_side'),
            painter: BusbarShapePainter(
              plan: p.bendPlan!,
              rho: p.rUsed + p.kUsed * _num(_t),
              thickness: _num(_t),
              text: fc.text,
              sub: fc.textSub,
              line: fc.line,
              metal: kPlateSteelShade,
            ),
            child: const SizedBox.expand(),
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.fromLTRB(6, 46, 6, 26),
          child: LayoutBuilder(
            builder: (context, box) => GestureDetector(
              key: const Key('pl_view'),
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _tapPreview(p, box.biggest, d.localPosition),
              child: CustomPaint(
                painter: PlatePainter(
                  plan: p,
                  text: fc.text,
                  sub: fc.textSub,
                  bg: fc.background,
                  showCenter: _showCenter,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
    }
  }

  List<Widget> _canvasTools(PlatePlan? p) {
    if (p == null) return const [];
    final mode = _viewOf(p);
    void pick(String v) => setState(() => _view = v);
    return [
      PlateViewSwitch([
        PlateOption(
          'pl_vm_flat',
          _bend ? '전개도' : '도면',
          mode == 'flat',
          () => pick('flat'),
        ),
        if (p.bendPlan != null)
          PlateOption('pl_vm_side', '측면도', mode == 'side', () => pick('side')),
        PlateOption('pl_vm_3d', '3D', mode == '3d', () => pick('3d')),
      ]),
      if (mode == 'flat')
        PlateCanvasButton(
          key: const Key('pl_center'),
          label: '센터선',
          selected: _showCenter,
          onTap: _toggleCenter,
        ),
    ];
  }

  String? _canvasHint(PlatePlan? p) {
    if (p == null) return null;
    return switch (_viewOf(p)) {
      'flat' => _previewHint(),
      _ => null,
    };
  }

  // ① 모양: 모양 · 재질·두께 · 치수 · 네 귀 · 수량·이름
  Widget _shapePanel(PlatePlan? p) {
    final shapes = _bend ? kPlateBendShapes : kPlateCutShapes;
    final bent = plateShapeBends(_shape);
    return PlatePanel(
      title: '모양',
      status: p == null
          ? '두께와 치수를 넣으십시오.'
          : '${plateShapeName(_shape)} · ${_dimsText()}',
      statusKey: const Key('pl_shape_status'),
      actions: [
        plateHelpButton(context, 'pl_help_shape', '모양 탭', _shapeHelp()),
      ],
      controller: _scroll,
      footer: _footer('shape'),
      children: [
        PlateSection(_bend ? '절곡 모양' : '자를 모양', [
          PlateSegments([
            for (final (s, name) in shapes)
              PlateOption(
                'pl_shape_${s.name}',
                name,
                _shape == s,
                () => _set(() => _shape = s),
              ),
          ]),
        ], first: true),
        PlateSection('재질·두께', [
          PlateSegments([
            for (final m in PlateMaterial.values)
              PlateOption(
                'pl_mat_${m.name}',
                kPlateMaterials[m]!.$1,
                _mat == m,
                () => _set(() => _mat = m),
              ),
          ]),
          plateRow(
            [
              PlateSegments([
                for (final v in const ['2', '3', '4', '6'])
                  PlateOption(
                    'pl_t_$v',
                    '${v}T',
                    _t.text.trim() == v,
                    () => _setThickness(v),
                  ),
              ]),
              _f('pl_t', null, _t),
            ],
            flex: const [3, 2],
          ),
        ]),
        PlateSection(bent ? '치수 (바깥 치수)' : '치수', _dimRows()),
        if (_shape == PlateShape.flat) PlateSection('네 코너', _cornerRows()),
        PlateSection('수량·이름', [
          plateRow(
            [
              _f('pl_qty', '수량', _qty, unit: '장'),
              PlateNumField(
                fieldKey: 'pl_job',
                label: '품명 (선택)',
                controller: _job,
                unit: null,
                text: true,
                hint: '도면·파일 이름',
                onChanged: (_) => _saveSoon(),
              ),
            ],
            flex: const [2, 5],
          ),
        ]),
      ],
    );
  }

  List<String> _shapeHelp() => [
    _shapeGuide(),
    ...switch (_shape) {
      PlateShape.flat => [
        '가로 · 세로: 판 크기입니다.',
        '네 코너: 단추를 누르면 네 코너에 같이 줍니다. 코너마다 다르게 하려면 위 그림에서 그 코너를 누르십시오. R은 둥글게, C는 코너에서 양쪽 변으로 같은 길이만큼 45°로 잘라 내고, 따내기는 코너에서 가로 × 세로 사각을 잘라 냅니다.',
      ],
      PlateShape.rib => [
        '가로 변 · 세로 변: 직각을 낀 두 변 길이입니다.',
        '모서리 따내기: ㄱ자 안쪽 모서리 용접 비드를 피하려고 직각 모서리를 45°로 따내는 길이입니다. 0이면 없습니다.',
      ],
      PlateShape.free => [
        '꼭짓점: 판 외곽 꼭짓점을 차례로 한 줄에 하나씩(가로,세로) 넣습니다. 예) 0,0 다음 줄 200,0. 마지막 점은 첫 점으로 저절로 이어집니다.',
        '코너 처리는 줄 끝에 붙입니다: ,r10(R10) · ,c5(C5 모따기) · ,n20x15(따내기: 앞 변 쪽 20 × 다음 변 쪽 15). 위 그림에서 꼭짓점을 눌러도 됩니다.',
      ],
      PlateShape.l => [
        '1면: 판 끝에서 2면 바깥면까지. 2면: 판 끝에서 1면 바깥면까지.',
        '폭: 절곡선 방향 길이. 각도: 90이면 직각입니다.',
      ],
      PlateShape.u => [
        '1면 · 3면: 판 끝에서 2면 바깥면까지. 2면: 양쪽 면 바깥면 사이.',
        '폭: 절곡선 방향 길이입니다.',
      ],
      PlateShape.z => [
        '1면 · 3면: 판 끝에서 세운 면 바깥면까지. 높이: 1면 아랫면에서 3면 윗면까지(바깥).',
        '폭: 절곡선 방향 길이입니다.',
      ],
      PlateShape.hat => [
        '발: 다리 바깥면에서 발 끝까지(양쪽 같음). 높이: 발 바닥면에서 윗면까지(바깥). 윗면: 양쪽 다리 바깥면 사이.',
        '폭: 절곡선 방향 길이입니다.',
      ],
    },
    if (_bend) '절곡 치수는 모두 바깥 치수입니다. 내R·공제값은 "절곡" 탭에서 정합니다.',
    '두께: 2T·3T·4T·6T를 누르거나 칸에 직접 넣습니다.${_bend ? ' 두께를 바꾸면 저장한 그 두께의 반경·공제값을 채웁니다.' : ''}',
    '재질은 중량 계산에만 씁니다.',
    '위 그림: 치수를 누르면 그 칸으로, 판을 누르면 홀 탭으로 갑니다. 오른쪽 위에서 ${_bend ? '측면도·' : ''}3D로 바꿔 볼 수 있습니다.',
    '품명은 가공 도면 PDF·DXF 파일 이름과 규격 저장 이름에 쓰입니다. 비워도 됩니다.',
  ];

  List<Widget> _dimRows() {
    const gap = SizedBox.shrink();
    return switch (_shape) {
      PlateShape.flat => [
        plateRow([
          _f('pl_len', '가로', _len, focus: _lenFocus),
          _f('pl_wid', '세로', _wid, focus: _widFocus),
        ]),
      ],
      PlateShape.rib => [
        plateRow([
          _f('pl_ra', '가로 변', _ribA, focus: _raFocus),
          _f('pl_rb', '세로 변', _ribB, focus: _rbFocus),
          _f('pl_rc', '모서리 따내기', _ribC, hint: '0 = 없음'),
        ]),
      ],
      PlateShape.free => [
        plateRow([
          PlateNumField(
            fieldKey: 'pl_fw',
            label: '가로 (전체)',
            controller: _fw,
            focus: _fwFocus,
            onChanged: (_) => _scaleFree(),
          ),
          PlateNumField(
            fieldKey: 'pl_fh',
            label: '세로 (전체)',
            controller: _fh,
            focus: _fhFocus,
            onChanged: (_) => _scaleFree(),
          ),
        ]),
        Text(
          '가로·세로를 바꾸면 모양 전체와 홀 위치가 그 크기로 늘거나 줄어듭니다(홀 지름·코너 크기는 그대로).',
          style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.35),
        ),
        Text(
          '꼭짓점 (가로,세로 한 줄에 하나 · 코너는 줄 끝에 ,r10 ,c5 ,n20x15)',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: fc.textSub,
          ),
        ),
        TextField(
          key: const Key('pl_points'),
          controller: _points,
          maxLines: 7,
          minLines: 4,
          keyboardType: TextInputType.multiline,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: fc.text,
            height: 1.35,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: fc.fill,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: fc.brand, width: 1.6),
            ),
          ),
          onChanged: (_) {
            _freeBase = null;
            _syncFreeSize();
            setState(_saveSoon);
          },
        ),
      ],
      PlateShape.l => [
        plateRow([_f('pl_l1', '1면', _l1), _f('pl_l2', '2면', _l2)]),
        plateRow([
          _f('pl_wid', '폭', _wid),
          _f('pl_ang', '절곡 각도', _angle, unit: '°'),
        ]),
      ],
      PlateShape.u => [
        plateRow([
          _f('pl_l1', '1면', _l1),
          _f('pl_l2', '2면', _l2),
          _f('pl_l3', '3면', _l3),
        ]),
        plateRow([_f('pl_wid', '폭', _wid), gap, gap]),
      ],
      PlateShape.z => [
        plateRow([
          _f('pl_l1', '1면', _l1),
          _f('pl_l2', '높이', _l2),
          _f('pl_l3', '3면', _l3),
        ]),
        plateRow([_f('pl_wid', '폭', _wid), gap, gap]),
      ],
      PlateShape.hat => [
        plateRow([
          _f('pl_l1', '발', _l1),
          _f('pl_l2', '높이', _l2),
          _f('pl_l3', '윗면', _l3),
        ]),
        plateRow([_f('pl_wid', '폭', _wid), gap, gap]),
      ],
    };
  }

  // ② 꺾기(절곡만): 반경·공제값 · 저장한 공제값 · 꺾기선
  Widget _bendPanel(PlatePlan? p) => PlatePanel(
    title: '절곡',
    status: p == null ? null : '지금: ${_bendCond(p)}',
    statusKey: const Key('pl_bendcond'),
    actions: [
      plateHelpButton(context, 'pl_help_bend', '절곡 탭', [
        '내R: 절곡기 금형의 내R입니다. 비우면 두께와 같게 봅니다.',
        '90° 공제값: 업체가 알려 준 공제값(바깥 치수 두 개 합 − 전개 길이)입니다. 넣으면 이 값이 나오게 K값을 맞춥니다. 비우면 일반값(K값 0.33)을 씁니다.',
        kPlateBasis[3],
        kPlateBasis[4],
        kPlateBasis[7],
      ]),
    ],
    footer: _footer('bend'),
    children: [
      PlateSection('절곡 조건', [
        plateRow([
          _f('pl_r', '내R', _r, hint: '비우면 ${fmt(_num(_t))}'),
          _f('pl_bd', '90° 공제값', _bd, hint: '비우면 일반값'),
        ]),
      ], first: true),
      PlateSection('저장한 공제값 (두께별)', [
        if (_bendTable.isEmpty)
          Text(
            '저장한 값이 없습니다. 업체 값을 넣고 "이 두께 값 저장"을 누르면 두께를 고를 때 채워집니다.',
            style: TextStyle(fontSize: 13.5, color: fc.textSub, height: 1.4),
          )
        else
          PlateLines([
            for (final e in _bendTable.entries)
              '${e.key}T: 내R ${fmt(e.value.$1)} · 공제값 ${fmt(e.value.$2)}',
          ], bullet: false),
        plateActions([
          PlateActionButton(
            key: const Key('pl_bd_save'),
            icon: AppIcons.save,
            label: '이 두께 값 저장',
            onTap: () {
              if (p == null) return;
              _set(() => _bendTable[_tKey] = (p.rUsed, p.bd90Used));
              _saveBendTable();
            },
          ),
          if (_bendTable.containsKey(_tKey))
            PlateActionButton(
              key: const Key('pl_bd_forget'),
              icon: AppIcons.delete,
              label: '이 두께 저장 지우기',
              danger: true,
              onTap: () {
                _set(() => _bendTable.remove(_tKey));
                _saveBendTable();
              },
            ),
        ]),
      ]),
      if (p != null && p.bends.isNotEmpty)
        PlateSection('절곡선 (왼쪽 끝에서)', [
          KeyedSubtree(
            key: const Key('pl_bends'),
            child: PlateLines([
              for (var n = 0; n < p.bends.length; n++) _bendLine(p, n),
            ], bullet: false),
          ),
        ]),
    ],
  );

  // ③ 구멍: 구멍 배치 편집(그림 칸·작업판을 같은 틀로 스스로 그린다)
  Widget _holesTab() => PlateHoleEditorPage(
    embedded: true,
    showCenter: _showCenter,
    footer: _footer('holes'),
    input: _input(),
    holes: List.of(_holes),
    rotQ: _rotQ,
    dies: _dies.isEmpty ? kDefaultPunchDies : _dies,
    onChanged: (h, r) => _set(() {
      _holes
        ..clear()
        ..addAll(h);
      _rotQ = r;
    }),
  );

  // ④ 결과: 무게 · 크기 · 확인할 것 · 꺾기선 · 구멍 자리
  Widget _resultPanel(PlatePlan? p, bool warn) {
    final help = plateHelpButton(context, 'pl_help_result', '결과 탭', [
      kPlateBasis[9],
      kPlateBasis[5],
      kPlateBasis[6],
      kPlateBasis[10],
    ]);
    if (p == null) {
      return PlatePanel(
        title: '결과',
        status: '두께와 치수를 넣으면 계산합니다.',
        actions: [help],
        footer: _footer('result'),
        children: const [],
      );
    }
    final bent = plateShapeBends(_shape);
    return PlatePanel(
      title: '결과',
      status:
          '${_bend ? '전개' : '판'} ${fmt(p.flatLength, 1)} × ${fmt(p.flatWidth, 1)} mm',
      actions: [help],
      footer: _footer('result'),
      children: [
        PlateSection('중량', [
          KeyedSubtree(
            key: const Key('pl_result'),
            child: PlateBigValue(
              value: '개당 약 ${fmt(p.kgEach, 2)}kg',
              caption:
                  '${kPlateMaterials[_mat]!.$1} ${fmt(_num(_t))}T · $_qtyN장 합계 약 ${fmt(p.kgTotal, 1)}kg',
              warn: warn,
            ),
          ),
        ], first: true),
        if (p.problems.isNotEmpty || p.notes.isNotEmpty)
          PlateSection('확인할 것', [
            if (p.problems.isNotEmpty) PlateLines(p.problems, color: fc.danger),
            if (p.notes.isNotEmpty) PlateLines(p.notes, color: fc.caution),
          ]),
        PlateSection('모양', [
          PlateInfoRow(plateShapeName(_shape), _dimsText()),
          if (p.bends.isNotEmpty) PlateInfoRow('절곡 조건', _bendCond(p)),
        ]),
        if (p.bends.isNotEmpty)
          PlateSection('절곡선 (왼쪽 끝에서)', [
            PlateLines([
              for (var n = 0; n < p.bends.length; n++) _bendLine(p, n),
            ], bullet: false),
          ]),
        PlateSection(bent ? '홀 위치 (면 기준 → 전개도)' : '홀 위치 (판 왼쪽 아래에서 가로 · 세로)', [
          Text(
            _holeSummary(),
            key: const Key('pl_hole_summary'),
            style: TextStyle(
              fontSize: 14,
              color: _holes.isEmpty ? fc.textSub : fc.text,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          if (p.holes.isNotEmpty)
            KeyedSubtree(
              key: const Key('pl_holes'),
              child: PlateLines([
                for (final h in p.holes) _holeLine(p, h),
              ], bullet: false),
            ),
        ]),
      ],
    );
  }

  // ⑤ 보내기: DXF·지시서 PDF·카톡, 주문할 때 알릴 것, 근거
  Widget _sendPanel(PlatePlan? p) {
    Widget item(String id, IconData icon, String title, String sub) => ListTile(
      key: Key('pl_send_$id'),
      enabled: p != null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Icon(icon, color: fc.brand, size: 26),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
      ),
      subtitle: Text(sub, style: TextStyle(color: fc.textSub)),
      trailing: Icon(AppIcons.forward, color: fc.textFaint),
      onTap: p == null ? null : () => _send(id, p),
    );
    return PlatePanel(
      title: '보내기',
      status: p == null
          ? '두께와 치수를 넣으면 보낼 수 있습니다.'
          : '${kPlateMaterials[_mat]!.$1} ${fmt(_num(_t))}T · $_qtyN장 · 레이저 업체에 보낼 파일과 글',
      actions: [
        plateHelpButton(context, 'pl_help_send', '보내기 탭', [
          kPlateBasis[8],
          '가공 도면 PDF: 그림·치수·홀 표·서명 칸이 들어갑니다.',
          '카톡 글: 치수·중량·절곡·홀 위치를 글로 보냅니다.',
        ]),
      ],
      footer: _footer('send'),
      children: [
        PlateSection('파일·글', [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: fc.line),
            ),
            child: Column(
              children: [
                item(
                  'dxf',
                  Icons.architecture_outlined,
                  'DXF 파일',
                  '레이저 업체 절단 프로그램용 · CUT·BEND·DIM 층',
                ),
                Divider(height: 1, color: fc.line),
                item(
                  'pdf',
                  Icons.picture_as_pdf_outlined,
                  '가공 도면 PDF',
                  '그림·치수·홀 표·서명 칸',
                ),
                Divider(height: 1, color: fc.line),
                item(
                  'kakao',
                  Icons.chat_bubble_outline,
                  '카톡 글',
                  '치수·중량·절곡을 글로 보냅니다',
                ),
              ],
            ),
          ),
        ], first: true),
        if (p != null)
          PlateSection('발주 메모', [
            KeyedSubtree(
              key: const Key('pl_order'),
              child: PlateLines([
                '재질·두께·수량: ${kPlateMaterials[_mat]!.$1} ${fmt(_num(_t))}T · $_qtyN장.',
                'CUT 층만 자르고 BEND 층(절곡선)·DIM 층(센터선)은 자르지 않는다고 알립니다.',
                if (p.bends.isNotEmpty)
                  '절곡 ${p.bends.length}곳: 방향은 DXF를 위에서 본 쪽 기준(NOTE 층 UP/DOWN), 내R ${fmt(p.rUsed)}mm. 업체 공제값이 다르면 그 값을 받아 "절곡" 탭에 넣고 다시 보냅니다.',
                '홀 둘레·외곽 버(찌꺼기)는 받은 뒤 갈아 냅니다. 녹 방지 도장은 현장 기준을 따릅니다.',
              ]),
            ),
          ]),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: fc.line)),
            ),
            child: elecBasis('pl_basis', kPlateBasis),
          ),
        ),
      ],
    );
  }

  Future<void> _send(String id, PlatePlan p) async {
    switch (id) {
      case 'dxf':
        await _sendDxf(p);
      case 'pdf':
        await openBracketPdf(
          context,
          () => _pdfInput(p),
          previewTitle: '철판 가공 도면 미리보기',
          filePrefix: 'steel_plate',
        );
      case 'kakao':
        await widget.share(_shareText(p));
    }
  }

  /// 아래 탭 줄(벤딩 화면과 같은 모양). 키보드가 떠 있으면 숨긴다.
  Widget? _navBar(int idx) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return null;
    final compact = calcNavCompact(context);
    BottomNavigationBarItem item(String id, String label, int i) {
      final on = i == idx;
      final Widget icon = switch (id) {
        'shape' => AppIcon(AppGlyph.navInput, size: 24, filled: on),
        'bend' => AppIcon(AppGlyph.plateBend, size: 24, filled: on),
        'holes' => const Icon(Icons.adjust, size: 24),
        'result' => AppIcon(AppGlyph.navMarking, size: 24, filled: on),
        _ => const Icon(AppIcons.send, size: 22),
      };
      return BottomNavigationBarItem(
        icon: Padding(
          padding: EdgeInsets.only(bottom: compact ? 0 : 4),
          child: KeyedSubtree(key: Key('pl_tab_$id'), child: icon),
        ),
        label: label,
      );
    }

    final tabs = _tabs;
    return Container(
      decoration: BoxDecoration(
        color: fc.surface,
        border: Border(top: BorderSide(color: fc.line)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 4,
            vertical: compact ? 0 : 4,
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            currentIndex: idx,
            selectedItemColor: fc.brand,
            unselectedItemColor: fc.textSub,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
            onTap: (i) {
              HapticFeedback.selectionClick();
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() => _tab = i);
            },
            items: [
              for (var i = 0; i < tabs.length; i++)
                item(tabs[i].$1, tabs[i].$2, i),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _plan();
    final warn = p != null && !p.ok;
    String? summary;
    if (p != null) {
      final size = '${fmt(p.flatLength, 1)} × ${fmt(p.flatWidth, 1)} mm';
      // 크기는 위 요약 줄에(결과 탭 큰 글은 무게)
      summary =
          '철판 ${plateShapeName(_shape)} · ${fmt(_num(_t))}T · ${_bend ? '전개 ' : ''}$size';
    }
    final tabs = _tabs;
    final idx = _tab.clamp(0, tabs.length - 1);
    final id = tabs[idx].$1;
    // 구멍 탭이 아닌 탭들은 위 그림 칸을 같이 쓰고 아래 작업판만 바뀐다.
    final others = [
      for (final t in tabs)
        if (t.$1 != 'holes') t.$1,
    ];

    // 뒤로 갈 때 바로 남긴다(첫 화면 "이어서" 줄이 방금 것을 읽게)
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveNow();
      },
      child: FieldViewTheme(
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: fc.background,
            appBar: AppBar(
              backgroundColor: fc.surface,
              foregroundColor: fc.text,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              // 요약은 제목 아래 작은 글로(요약 줄을 따로 두지 않아 휴대폰에서 한 줄 아낌)
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _bend ? '절단 + 절곡' : '레이저 절단',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: fc.text,
                    ),
                  ),
                  if (summary != null)
                    KeyedSubtree(
                      key: const Key('pl_sum'),
                      child: Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: warn ? fc.danger : fc.brand,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                IconButton(
                  key: const Key('pl_saved'),
                  tooltip: '저장한 규격',
                  icon: Icon(Icons.bookmarks_outlined, color: fc.text),
                  onPressed: _openSaved,
                ),
                calcHistoryButton(),
              ],
            ),
            body: elecPageFrame(
              sumKey: 'pl_sum',
              summary: summary,
              warn: warn,
              showBar: false,
              body: IndexedStack(
                index: id == 'holes' ? 1 : 0,
                children: [
                  PlateWorkspace(
                    canvasShare: switch (id) {
                      'shape' || 'bend' => 0.36,
                      _ => 0.46,
                    },
                    canvas: KeyedSubtree(
                      key: const ValueKey('pl_canvas'),
                      child: _canvas(p),
                    ),
                    tools: _canvasTools(p),
                    hint: _canvasHint(p),
                    panel: IndexedStack(
                      index: others.contains(id) ? others.indexOf(id) : 0,
                      children: [
                        for (final o in others)
                          KeyedSubtree(
                            key: ValueKey('pl_body_$o'),
                            child: switch (o) {
                              'shape' => _shapePanel(p),
                              'bend' => _bendPanel(p),
                              'result' => _resultPanel(p, warn),
                              _ => _sendPanel(p),
                            },
                          ),
                      ],
                    ),
                  ),
                  KeyedSubtree(
                    key: const ValueKey('pl_body_holes'),
                    child: _holesTab(),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: _navBar(idx),
          ),
        ),
      ),
    );
  }

  // ── 위 그림 ──

  void _toggleCenter() {
    setState(() => _showCenter = !_showCenter);
    final v = _showCenter;
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_centerKey, v))
        .catchError((_) => false);
  }

  String _previewHint() => switch (_shape) {
    PlateShape.flat => '코너·치수를 누르면 고치고, 판을 누르면 홀',
    PlateShape.free => '꼭짓점을 누르면 코너 처리, 판을 누르면 홀',
    PlateShape.rib => '치수를 누르면 그 칸, 판을 누르면 홀',
    _ => '주황 점선은 절곡선 · 판을 누르면 홀',
  };

  /// 그림을 눌렀을 때: 귀(평판)·꼭짓점(자유) → 귀 처리, 치수 숫자 → 그 칸, 판 안 → 구멍 넣기·고치기.
  void _tapPreview(PlatePlan p, Size size, Offset at) {
    final lay = PlatePainterLayout.of(p, size);
    if (lay == null) return;
    if (_shape == PlateShape.flat || _shape == PlateShape.free) {
      final w = _num(_len), h = _num(_wid);
      final base = _shape == PlateShape.flat
          ? [Offset.zero, Offset(w, 0), Offset(w, h), Offset(0, h)]
          : [for (final v in parsePlateVertices(_points.text)) v.$1];
      int? best;
      var bd = 30.0;
      for (var k = 0; k < base.length; k++) {
        final d = (lay.toScreen(p.toDisplay(base[k])) - at).distance;
        if (d < bd) {
          bd = d;
          best = k;
        }
      }
      if (best != null) {
        _shape == PlateShape.flat ? _editCorner(best) : _editPointCorner(best);
        return;
      }
    }
    final tl = lay.topLeft, br = lay.bottomRight;
    final inX = at.dx >= tl.dx - 10 && at.dx <= br.dx + 10;
    final inY = at.dy >= tl.dy - 10 && at.dy <= br.dy + 10;
    final swap = _rotQ.isOdd;
    FocusNode? f;
    if ((at.dy - lay.widthDimY).abs() < 18 && inX) {
      f = switch (_shape) {
        PlateShape.flat => swap ? _widFocus : _lenFocus,
        PlateShape.rib => swap ? _rbFocus : _raFocus,
        _ => null,
      };
    } else if ((at.dx - lay.heightDimX).abs() < 18 && inY) {
      f = switch (_shape) {
        PlateShape.flat => swap ? _lenFocus : _widFocus,
        PlateShape.rib => swap ? _raFocus : _rbFocus,
        _ => null,
      };
    }
    if (f != null) {
      _focusField(f);
      return;
    }
    if (inX && inY) _openEditor();
  }

  /// 목록에서 내려가 있어 칸이 안 그려졌으면 맨 위로 올린 뒤 그 칸에 커서를 둔다.
  void _focusField(FocusNode f) {
    if (f.context != null) {
      f.requestFocus();
      return;
    }
    if (_scroll.hasClients) _scroll.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) f.requestFocus();
    });
  }

  String _shapeGuide() => switch (_shape) {
    PlateShape.flat => '평판: 사각 판에 홀·장공. 네 코너를 따로 R·모따기(C)·따내기 할 수 있습니다.',
    PlateShape.rib => '삼각 리브: ㄱ자 안쪽에 용접하는 보강판. 직각 모서리를 따내 용접 자리를 비웁니다.',
    PlateShape.free => '좌표 입력: 외곽 꼭짓점 좌표를 차례로 넣어 모양을 만듭니다.',
    PlateShape.l => 'ㄱ자: 1회 절곡(각도를 바꿀 수 있습니다).',
    PlateShape.u => 'ㄷ자: 같은 방향으로 2회 절곡.',
    PlateShape.z => 'Z자: 반대 방향으로 2회 절곡해 단을 만듭니다.',
    PlateShape.hat => '모자: 발 → 다리 → 윗면 → 다리 → 발, 4회 절곡.',
  };

  // ── 평판 네 귀 ──
  // 화면 칸은 네 귀에 같이 주는 한 줄만 둔다. 귀마다 다르게 할 때는 위 그림에서 그 귀를 누른다(10-10 손봄).

  bool get _cornersSame => _corners.every(
    (c) =>
        c.kind == _corners[0].kind &&
        c.a == _corners[0].a &&
        (c.b <= 0 ? c.a : c.b) ==
            (_corners[0].b <= 0 ? _corners[0].a : _corners[0].b),
  );

  /// 네 귀가 같으면 그 값을 크기 칸에 옮긴다(직각이면 칸 값은 그대로).
  void _syncCornerFields() {
    final c = _corners[0];
    if (!_cornersSame || c.kind == PlateCornerKind.none) return;
    _ca.text = fmt(c.a);
    _cb.text = fmt(c.b <= 0 ? c.a : c.b);
  }

  void _setAllCorners(PlateCornerKind kind) => _set(() {
    var a = _num(_ca), b = _num(_cb);
    if (a <= 0) {
      a = 10;
      _ca.text = '10';
    }
    if (b <= 0) {
      b = a;
      _cb.text = fmt(a);
    }
    _corners = List.filled(
      4,
      kind == PlateCornerKind.none
          ? PlateCorner.square
          : PlateCorner(kind, a, kind == PlateCornerKind.notch ? b : 0),
    );
  });

  void _setCornerSize() => _set(() {
    final a = _num(_ca), b = _num(_cb);
    final k = _corners[0].kind;
    if (k == PlateCornerKind.none) return;
    _corners = List.filled(
      4,
      PlateCorner(k, a, k == PlateCornerKind.notch ? b : 0),
    );
  });

  /// 그림에서 귀 하나를 눌렀을 때.
  Future<void> _editCorner(int k) async {
    final c = await showPlateCornerDialog(
      context,
      title: '${kPlateCornerNames[k]} 코너',
      initial: _corners[k],
      flat: true,
    );
    if (c == null || !mounted) return;
    _set(() {
      _corners = List.of(_corners)..[k] = c;
      _syncCornerFields();
    });
  }

  /// 자유 모양 그림에서 꼭짓점 하나를 눌렀을 때(꼭짓점 줄의 꼬리표를 고친다).
  Future<void> _editPointCorner(int k) async {
    final vs = parsePlateVertices(_points.text);
    if (k >= vs.length) return;
    final c = await showPlateCornerDialog(
      context,
      title: '꼭짓점 ${k + 1} 코너',
      initial: vs[k].$2,
    );
    if (c == null || !mounted) return;
    _set(
      () => _points.text = platePointsText(
        [for (final v in vs) v.$1],
        [for (var i = 0; i < vs.length; i++) i == k ? c : vs[i].$2],
      ),
    );
  }

  List<Widget> _cornerRows() {
    final same = _cornersSame;
    final kind = same ? _corners[0].kind : null;
    Widget size(String key, String label, TextEditingController c) =>
        PlateNumField(
          fieldKey: key,
          label: label,
          controller: c,
          onChanged: (_) => _setCornerSize(),
        );
    const gap = SizedBox.shrink();
    return [
      PlateSegments([
        PlateOption(
          'pl_ck_none',
          '직각',
          kind == PlateCornerKind.none,
          () => _setAllCorners(PlateCornerKind.none),
        ),
        PlateOption(
          'pl_ck_round',
          '코너 R',
          kind == PlateCornerKind.round,
          () => _setAllCorners(PlateCornerKind.round),
        ),
        PlateOption(
          'pl_ck_chamfer',
          'C 모따기',
          kind == PlateCornerKind.chamfer,
          () => _setAllCorners(PlateCornerKind.chamfer),
        ),
        PlateOption(
          'pl_ck_notch',
          '따내기',
          kind == PlateCornerKind.notch,
          () => _setAllCorners(PlateCornerKind.notch),
        ),
      ]),
      if (kind == PlateCornerKind.round)
        plateRow([size('pl_ca', 'R', _ca), gap]),
      if (kind == PlateCornerKind.chamfer)
        plateRow([size('pl_ca', 'C', _ca), gap]),
      if (kind == PlateCornerKind.notch)
        plateRow([size('pl_ca', '따내기 가로', _ca), size('pl_cb', '따내기 세로', _cb)]),
      Text(
        same
            ? '네 코너에 같이 줍니다. 코너마다 다르게 하려면 위 그림에서 그 코너를 누르십시오.'
            : '코너마다 다릅니다:${_cornersText().replaceFirst(' · ', ' ')}. 단추를 누르면 네 코너가 같아집니다.',
        key: same ? null : const Key('pl_corner_mixed'),
        style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.35),
      ),
      if (_rotQ % 4 != 0 && !_corners.every((c) => c.isNone))
        Text(
          '판을 돌려 놓았습니다. 코너 이름은 돌리기 전(가로 ${fmt(_num(_len))} × 세로 ${fmt(_num(_wid))}) 기준입니다.',
          style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.35),
        ),
    ];
  }
}
