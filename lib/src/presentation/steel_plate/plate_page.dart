// 철판 가공(10-10): 3t·4t 같은 철판을 레이저로 자르기만 하거나(평판·삼각 리브·자유 모양) 잘라서 꺾는(ㄱ·ㄷ·Z·모자)
// 브라켓의 전개도·꺾기선·구멍·무게를 계산하고, 레이저 업체에 보낼 DXF와 가공 지시서 PDF·카톡 글을 만든다.
// 계산은 plate_calc.dart, 꺾기는 부스바 절곡 계산을 그대로 쓴다. 화면 틀은 형강 브라켓·접지바와 같다.
// 10-10 나중: 첫 화면(plate_home_page.dart)에서 "레이저 절단"과 "절단 + 절곡"을 따로 연다(입력·저장도 따로).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
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
import '../electrical/busbar_saved_specs.dart';
import '../electrical/elec_form_parts.dart';
import '../drawing_viewer/dxf_reader.dart' show dxfDecode;
import '../steel_bracket/bracket_pdf.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'plate_3d_view.dart';
import 'plate_bend_input.dart';
import 'plate_calc.dart';
import 'plate_corner_dialog.dart';
import 'plate_dxf.dart';
import 'plate_dxf_import.dart';
import 'plate_hole_editor.dart';
import 'plate_painter.dart';
import 'plate_settings.dart';
import 'plate_shape_card.dart';
import 'plate_side_painter.dart';
import 'plate_ui.dart';

Future<String?> _pickDxfText() async {
  final res = await FilePicker.pickFiles(type: FileType.any, withData: true);
  if (res == null || res.files.isEmpty) return null;
  final f = res.files.first;
  final bytes =
      f.bytes ?? (f.path == null ? null : await File(f.path!).readAsBytes());
  if (bytes == null) return null;
  return dxfDecode(Uint8List.fromList(bytes));
}

Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

const List<String> kPlateBasis = [
  '가공: "레이저 절단"은 평판·삼각 리브·좌표 입력을 자르기만 하고, "절단 + 절곡"은 ㄱ·ㄷ·Z·모자로 절곡합니다. 절곡은 전개도(펴 놓은 모양)를 자른 뒤 절곡선에서 접습니다. 둘은 철판 가공 첫 화면에서 따로 들어가고 입력도 따로 남습니다.',
  '평판 코너: R은 둥글게, C는 코너에서 양쪽 변으로 같은 길이만큼 45°로 잘라 내고, 따내기는 코너에서 가로 × 세로 사각을 잘라 냅니다. 좌표 입력은 꼭짓점 줄 끝에 ,r10 · ,c5 · ,n20x15처럼 붙입니다. 코너 처리가 옆 변보다 크면 알립니다.',
  '절곡 치수는 모두 바깥 치수입니다. 전개 길이 = 바깥 치수 합 − 절곡마다 공제값. 공제값(90°) = 2 × (내R + 두께) − π/2 × (내R + K값 × 두께). K값을 모르면 일반값 0.33을 쓰고, 업체가 알려 준 공제값을 넣으면 그 값이 나오게 K값을 맞춥니다. 절곡 계산은 부스바 가공과 같은 식입니다.',
  '내R은 일반값이면 두께와 같게 봅니다. 레이저 업체·절곡기 금형마다 공제값이 다르니 처음 주문 때 업체 값을 받아 절곡 탭 "직접 넣기"로 넣고 "업체 값 저장"으로 설정에 남겨 두십시오. 다음부터 그 두께를 고르면 업체 값을 씁니다.',
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
  (PlateShape.circle, '원형'),
  (PlateShape.ring, '링'),
  (PlateShape.rib, '삼각 리브'),
  (PlateShape.free, '좌표 입력'),
];
const List<(PlateShape, String)> kPlateBendShapes = [
  (PlateShape.l, 'ㄱ자'),
  (PlateShape.u, 'ㄷ자'),
  (PlateShape.z, 'Z자'),
  (PlateShape.hat, '모자'),
  (PlateShape.custom, '직접'),
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
    this.pickDxf,
  });

  /// DXF 파일 고르기(글을 돌려준다, 취소면 null). 시험에서 바꿔 끼운다.
  final Future<String?> Function()? pickDxf;

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
  static const bendTableKey = kPlateBendTableKey;

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

  /// 절곡 공제값 기준(10-11): 'auto' 일반값(내R = 두께, K 0.33) · 'saved' 설정에 저장한 이 두께 업체 값 · 'manual' 직접 넣기.
  String _bm = 'auto';

  /// 직접 절곡(10-11): 절곡선(바깥 치수 자리 차례대로)과 가로선인가. ㄱ·ㄷ·Z·모자: 절곡마다 방향 뒤집기.
  List<PlateBendSpec> _bls = [];
  bool _blH = false;
  List<bool> _flips = [];
  bool get _custom => _shape == PlateShape.custom;

  /// 레이저 절단 좌표 입력의 처음 모양, 절곡 화면 "직접"의 처음 모양(사각).
  static const _kCutPoints = '0,0\n200,0\n200,80\n120,150\n0,150';
  static const _kRectPoints = '0,0\n200,0\n200,100\n0,100';

  /// 철판 가공 설정(자주 쓰는 홀 지름·두께 단추·원판·간격) — 설정 화면에서 바꾼다.
  PlateSettings _cfg = PlateSettings.defaults;
  double _grid = 5;

  // 그림에서 치수를 누르면 갈 칸
  // 판 가운데 십자선 켜고 끄기(기억, 구멍 탭·지시서 그림도 따른다)
  bool _showCenter = true;
  static const _centerKey = kPlateCenterKey;
  final _scroll = ScrollController();

  // 좌표 입력의 가로·세로(10-10 사용자: "판 크기 선택 못 하냐"): 넣으면 모양 전체와 홀 위치를 그 크기로 늘이거나 줄인다.
  // 고치기 시작할 때의 꼭짓점·홀을 잡아 두고 거기서 늘이므로, 한 자씩 칠 때 생기는 중간 값이 쌓이지 않는다.
  final _fw = TextEditingController(), _fh = TextEditingController();
  final _fwFocus = FocusNode(), _fhFocus = FocusNode();
  (String, List<PlateHoleSpec>, List<PlateBendSpec>)? _freeBase;
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
  final _points = TextEditingController(text: _kCutPoints);
  final _r = TextEditingController();
  final _bd = TextEditingController();
  final _qty = TextEditingController(text: '1');
  // 원형·링 외경·내경
  final _cd = TextEditingController(text: '150');
  final _ci = TextEditingController(text: '60');

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
    _cd,
    _ci,
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
    'cd',
    'ci',
  ];

  @override
  void initState() {
    super.initState();
    if (_bend) _points.text = _kRectPoints;
    _syncFreeSize();
    for (final n in [_fwFocus, _fhFocus]) {
      n.addListener(() {
        if (n.hasFocus) return;
        _freeBase = null;
        _syncFreeSize();
      });
    }
    _loadDraft();
    _loadSettings();
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
    'bm': _bm,
    'bl': [for (final b in _bls) b.toJson()],
    'blh': _blH,
    'fl': _flips,
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
    // 절곡 기준: 없으면(10-11 전 저장) 칸이 비었으면 일반값, 아니면 직접
    final bm = m['bm'];
    _bm = bm is String && const ['auto', 'saved', 'manual'].contains(bm)
        ? bm
        : (_r.text.trim().isEmpty && _bd.text.trim().isEmpty
              ? 'auto'
              : 'manual');
    final bl = m['bl'];
    _bls = bl is List ? [for (final o in bl) ?PlateBendSpec.fromJson(o)] : [];
    _bls.sort((a, b) => a.at.compareTo(b.at));
    _blH = m['blh'] == true;
    final fl = m['fl'];
    _flips = fl is List ? [for (final v in fl) v == true] : [];
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
      _set(() {
        _applyMap(Map<String, dynamic>.from(init));
        if (_custom) {
          _tab = _tabs.indexWhere((t) => t.$1 == 'bend');
        }
      });
      showAppSnack(
        context,
        _custom
            ? '스케치에서 옮겨 왔습니다(바깥 치수로 펴 그린 판). 절곡선을 넣으십시오.'
            : '스케치에서 옮겨 왔습니다. 홀은 "홀 배치"에서 더 고칠 수 있습니다.',
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

  /// 설정·업체 공제값·그리드·센터선을 읽는다(처음과 설정 화면에서 돌아올 때).
  /// 설정에서 돌아오면 업체 값이 바뀌었을 수 있어 절곡 기준을 다시 맞춘다(직접 넣은 값은 그대로, 같은 값이 저장됐으면 업체 값으로).
  Future<void> _loadSettings({bool fromSettings = false}) async {
    final cfg = await PlateSettings.load();
    final bd = await readPlateBendTable();
    double? grid;
    bool? center;
    try {
      final p = await SharedPreferences.getInstance();
      grid = p.getDouble(kPlateGridKey);
      center = p.getBool(_centerKey);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _cfg = cfg;
      _bendTable = bd;
      if (grid != null) _grid = grid;
      if (center != null) _showCenter = center;
      final s = _bendTable[_tKey];
      if (_bm == 'saved' || (fromSettings && _bm == 'auto')) {
        _applyBendSource();
      } else if (fromSettings &&
          s != null &&
          readNum(_r) == s.$1 &&
          readNum(_bd) == s.$2) {
        _bm = 'saved';
      }
    });
    _saveSoon();
  }

  /// 설정 화면. [bend]면 업체 공제값 칸으로 가고, 직접 넣은 값이 있으면 그 값을 넣기 칸에 채워 둔다.
  Future<void> _openSettings({bool bend = false, PlatePlan? p}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final pre = bend && _bm == 'manual' && p != null
        ? (_tKey, p.rUsed, double.parse(p.bd90Used.toStringAsFixed(2)))
        : null;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlateSettingsPage(bendPrefill: pre, focusBend: bend),
      ),
    );
    if (mounted) await _loadSettings(fromSettings: true);
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
    final base = _freeBase ??= (_points.text, List.of(_holes), List.of(_bls));
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
    if (_custom) {
      // 펴 그린 판 자리(바깥 치수): 절곡선 방향 길이는 sA, 가로지르는 방향은 sB
      final sA = _blH ? sy : sx, sB = _blH ? sx : sy;
      final s0 = _faceStarts(base.$3);
      final nb = [for (final b0 in base.$3) b0.copyWith(at: r1(b0.at * sA))]
        ..sort((a, b) => a.at.compareTo(b.at));
      final s1 = _faceStarts(nb);
      _bls = nb;
      _holes
        ..clear()
        ..addAll([
          for (final h0 in base.$2)
            () {
              final x = r1(_outerX(s0, h0) * sA);
              final f = _faceIn(s1, x);
              return h0.copyWith(face: f, u: r1(x - s1[f]), v: r1(h0.v * sB));
            }(),
        ]);
      return;
    }
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

  // ── 직접 절곡: 홀은 펴 그린 판(바깥 치수) 위 자리로 두고 면·u만 다시 잡는다 ──

  /// 면 시작(바깥 치수): 0과 절곡선 자리들(작은 것부터).
  List<double> _faceStarts(List<PlateBendSpec> b) => [
    0,
    ...([for (final x in b) x.at]..sort()),
  ];
  double _outerX(List<double> starts, PlateHoleSpec h) =>
      starts[h.face.clamp(0, starts.length - 1)] + h.u;
  int _faceIn(List<double> starts, double x) {
    var f = 0;
    for (var k = 0; k < starts.length; k++) {
      if (starts[k] <= x + 1e-9) f = k;
    }
    return f;
  }

  List<PlateHoleSpec> _rebaseHoles(
    List<PlateBendSpec> from,
    List<PlateBendSpec> to, [
    List<PlateHoleSpec>? holes,
  ]) {
    final a = _faceStarts(from), b = _faceStarts(to);
    double r2(double v) => (v * 100).roundToDouble() / 100;
    return [
      for (final h in holes ?? _holes)
        () {
          final x = _outerX(a, h);
          final f = _faceIn(b, x);
          return h.copyWith(face: f, u: r2(x - b[f]));
        }(),
    ];
  }

  /// 절곡선 넣기([n] null)·고치기·지우기.
  Future<void> _editBendLine(int? n) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final (outer, width) = plateCustomOuter(_input());
    if (outer.length < 3 || width <= 0) {
      showAppSnack(context, '판 모양(가로·세로 또는 꼭짓점)을 먼저 넣으십시오.');
      return;
    }
    final r = await showPlateBendLineInput(
      context,
      title: n == null ? '절곡선 넣기' : '절곡선 ${n + 1} 고치기',
      outline: outer,
      width: width,
      others: [
        for (var k = 0; k < _bls.length; k++)
          if (k != n) _bls[k].at,
      ],
      edit: n == null ? null : _bls[n],
      axisH: _blH,
      okText: n == null ? '넣기' : '적용',
    );
    if (r == null || !mounted) return;
    final next = List.of(_bls);
    if (r.delete) {
      if (n != null) next.removeAt(n);
    } else if (n == null) {
      next.add(r.spec!);
    } else {
      next[n] = r.spec!;
    }
    next.sort((a, b) => a.at.compareTo(b.at));
    _set(() {
      final hs = _rebaseHoles(_bls, next);
      _holes
        ..clear()
        ..addAll(hs);
      _bls = next;
    });
  }

  /// 절곡선 방향(세로선 ↔ 가로선): 판을 돌려 계산하므로 넣은 절곡선은 지우고, 홀은 판 위 같은 자리로 옮긴다.
  void _setAxis(bool h) {
    if (h == _blH) return;
    final before = _draft();
    final had = _bls.isNotEmpty;
    final b = _freeBounds(parsePlateVertices(_points.text));
    _set(() {
      if (b != null) {
        final starts = _faceStarts(_bls);
        double r2(double v) => (v * 100).roundToDouble() / 100;
        // 지금 자리(바깥 치수) → 그린 자리 → 새 방향 자리
        Offset toSketch(double x, double y) => _blH
            ? Offset(b.right - y, x + b.top)
            : Offset(x + b.left, y + b.top);
        Offset toInner(Offset q) => h
            ? Offset(q.dy - b.top, b.right - q.dx)
            : Offset(q.dx - b.left, q.dy - b.top);
        final hs = [
          for (final h0 in _holes)
            () {
              final q = toInner(toSketch(_outerX(starts, h0), h0.v));
              return h0.copyWith(face: 0, u: r2(q.dx), v: r2(q.dy));
            }(),
        ];
        _holes
          ..clear()
          ..addAll(hs);
      }
      _blH = h;
      _bls = [];
    });
    if (had) {
      showAppSnack(
        context,
        '절곡선 방향을 바꿔 넣어 둔 절곡선을 지웠습니다.',
        onUndo: () =>
            _set(() => _applyMap(jsonDecode(before) as Map<String, dynamic>)),
      );
    }
  }

  /// ㄱ·ㄷ·Z·모자 절곡 [n]의 방향.
  void _setFlip(PlatePlan p, int n, bool up) {
    if (n >= p.bends.length || (p.bends[n].turn >= 0) == up) return;
    _set(() {
      final f = List<bool>.of(_flips);
      while (f.length <= n) {
        f.add(false);
      }
      f[n] = !f[n];
      _flips = f;
    });
  }

  // ── 직접 절곡: 전개도에서 절곡선을 눌러 고치고 옆으로 끌어 옮긴다(절곡 탭) ──
  int? _dragBl;
  double _dragX0 = 0;
  List<PlateBendSpec> _dragBls0 = const [];
  List<PlateHoleSpec> _dragHoles0 = const [];

  /// 화면 자리 가까이(24점)의 절곡선 차례(_bls). 판 밖 절곡선은 그림에 없으니 판 안 것만 센다.
  int? _blAt(PlatePlan p, Size size, Offset at) {
    final lay = PlatePainterLayout.of(p, size);
    if (lay == null) return null;
    final w = p.faceLengths.fold(0.0, (s, v) => s + v);
    final valid = [
      for (var k = 0; k < _bls.length; k++)
        if (_bls[k].at > 1e-6 && _bls[k].at < w - 1e-6) k,
    ];
    int? best;
    var bd = 24.0;
    for (var i = 0; i < p.bends.length && i < valid.length; i++) {
      final d = (lay.toScreen(Offset(p.bends[i].center, 0)).dx - at.dx).abs();
      if (d < bd) {
        bd = d;
        best = valid[i];
      }
    }
    return best;
  }

  void _dragStart(PlatePlan p, Size size, Offset at) {
    _dragBl = _blAt(p, size, at);
    _dragX0 = at.dx;
    _dragBls0 = List.of(_bls);
    _dragHoles0 = List.of(_holes);
  }

  void _dragUpdate(PlatePlan p, Size size, Offset at) {
    final k = _dragBl;
    if (k == null || k >= _dragBls0.length) return;
    final lay = PlatePainterLayout.of(p, size);
    if (lay == null) return;
    final w = p.faceLengths.fold(0.0, (s, v) => s + v);
    final x = ((_dragBls0[k].at + (at.dx - _dragX0) / lay.s) * 2).round() / 2;
    final next = List.of(_dragBls0)
      ..[k] = _dragBls0[k].copyWith(at: x.clamp(0.5, math.max(0.5, w - 0.5)));
    setState(() {
      _bls = next;
      _holes
        ..clear()
        ..addAll(_rebaseHoles(_dragBls0, next, _dragHoles0));
    });
  }

  void _dragEnd() {
    if (_dragBl == null) return;
    _dragBl = null;
    _set(() => _bls = List.of(_bls)..sort((a, b) => a.at.compareTo(b.at)));
  }

  double _num(TextEditingController c) {
    final v = readNum(c);
    return v == null || v < 0 ? 0 : v;
  }

  String get _tKey => fmt(_num(_t));

  /// 두께 단추: 그 두께의 업체 값이 있으면 채우고(업체 값), 없으면 비운다(일반값).
  void _setThickness(String v) => _set(() {
    _t.text = v;
    _applyBendSource();
  });

  /// 지금 두께에 맞춰 절곡 기준을 다시: 업체 값이 있으면 업체 값, 없으면 일반값.
  /// [keepManual]이면 직접 넣은 값은 건드리지 않는다(두께 칸에 직접 칠 때).
  void _applyBendSource({bool keepManual = false}) {
    if (keepManual && _bm == 'manual') return;
    final saved = _bendTable[_tKey];
    _r.text = saved == null ? '' : fmt(saved.$1);
    _bd.text = saved == null ? '' : fmt(saved.$2);
    _bm = saved == null ? 'auto' : 'saved';
  }

  void _setBendMode(String m, PlatePlan? p) => _set(() {
    switch (m) {
      case 'auto':
        _r.text = '';
        _bd.text = '';
      case 'saved':
        final s = _bendTable[_tKey];
        if (s == null) return;
        _r.text = fmt(s.$1);
        _bd.text = fmt(s.$2);
      case 'manual':
        if (_r.text.trim().isEmpty) _r.text = fmt(p?.rUsed ?? _num(_t));
    }
    _bm = m;
  });

  /// 중량 글: 1kg 밑은 소수 셋째 자리까지(작은 판이 "0.3"으로 뭉개지던 것, 10-11).
  String _kg(double v) => fmt(v, v < 1 ? 3 : (v < 10 ? 2 : 1));

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
      dia: _num(_cd),
      innerDia: _num(_ci),
      bendLines: List.of(_bls),
      bendAxisH: _blH,
      flips: List.of(_flips),
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
    PlateShape.custom => () {
      final b = _freeBounds(parsePlateVertices(_points.text));
      final size = b == null ? '' : '바깥 ${fmt(b.width)} × ${fmt(b.height)} · ';
      return '$size절곡선 ${_bls.length}개${_blH ? '(가로)' : ''}';
    }(),
    PlateShape.l =>
      '1면 ${fmt(_num(_l1))} · 2면 ${fmt(_num(_l2))} · 폭 ${fmt(_num(_wid))} · ${fmt(readNum(_angle) ?? 90)}°',
    PlateShape.u || PlateShape.z =>
      '1면 ${fmt(_num(_l1))} · ${_shape == PlateShape.z ? '높이' : '2면'} ${fmt(_num(_l2))} · 3면 ${fmt(_num(_l3))} · 폭 ${fmt(_num(_wid))}',
    PlateShape.hat =>
      '발 ${fmt(_num(_l1))} · 높이 ${fmt(_num(_l2))} · 윗면 ${fmt(_num(_l3))} · 폭 ${fmt(_num(_wid))}',
    PlateShape.circle => '외경 Ø${fmt(_num(_cd))}',
    PlateShape.ring => '외경 Ø${fmt(_num(_cd))} · 내경 Ø${fmt(_num(_ci))}',
  };

  /// 가공비 기준 글: "절단 길이 약 0.85 m · 피어싱 3곳".
  String _cutText(PlatePlan p) =>
      '절단 길이 약 ${(p.cutLength / 1000).toStringAsFixed(2)} m · 피어싱 ${p.pierces}곳';

  (double, double) get _sheetSize => _cfg.sheetSize;

  PlateNest _nest(PlatePlan p) {
    final (w, h) = _sheetSize;
    return plateNest(
      sheetW: w,
      sheetH: h,
      w: p.flatLength,
      h: p.flatWidth,
      gap: _cfg.gap,
      margin: _cfg.margin,
      partArea: p.areaMm2,
    );
  }

  String _sheetName() => _cfg.sheetName;

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
      '내R ${fmt(p.rUsed)} · 공제값(90°) ${fmt(p.bd90Used, 2)}mm · K값 ${p.kUsed.toStringAsFixed(2)}${readNum(_bd) == null ? '(일반값)' : (_bm == 'saved' ? '(업체 값)' : '(넣은 공제값)')}';

  String _shareText(PlatePlan p) {
    final b = StringBuffer(
      '[철판 가공] ${plateShapeName(_shape)} · ${kPlateMaterials[_mat]!.$1} ${fmt(_num(_t))}T · $_qtyN장',
    );
    if (_job.text.trim().isNotEmpty) b.write(' · ${_job.text.trim()}');
    b.write(
      '\n치수: ${_dimsText()} (mm${plateShapeBends(_shape) ? ', 바깥 치수' : ''})',
    );
    b.write(
      '\n${_bend ? '전개' : '판'} 크기: ${fmt(p.flatLength, 1)} × ${fmt(p.flatWidth, 1)}mm · 개당 약 ${_kg(p.kgEach)}kg',
    );
    b.write('\n${_cutText(p)} (1개)');
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
        showIssues: false,
        holeDims: true,
      ),
    );
    final more = <(String, Uint8List)>[];
    if (p.bendPlan != null) {
      more.add((
        '측면도 (바깥 치수, mm)',
        await renderPainterPng(
          PlateSidePainter.of(
            p,
            t: _num(_t),
            text: const Color(0xFF1F2933),
            sub: const Color(0xFF55636D),
            bg: Colors.white,
            fontScale: 1.8,
            hat: _shape == PlateShape.hat,
          ),
          width: 1200,
          height: 700,
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
        ('수량', '$_qtyN장 · 개당 약 ${_kg(p.kgEach)}kg · 모두 약 ${_kg(p.kgTotal)}kg'),
        ('가공비 기준', '${_cutText(p)} (1개)'),
        () {
          final n = _nest(p);
          return (
            '원판 배치',
            n.count == 0
                ? '${_sheetName()}보다 큼'
                : '${_sheetName()} 한 장에 ${n.count}개 · 수량 $_qtyN장에 원판 ${(_qtyN / n.count).ceil()}장',
          );
        }(),
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
  // 탭마다 같은 자리의 위 그림 칸(판·전개도 / 측면도 / 3D를 오른쪽 위에서 고름) + 아래 흰 작업판(제목 줄 · 묶음).
  // 10-11: 맨 아래 이전/다음 줄은 아래 탭 줄과 겹쳐 뺐다(탭 줄로만 옮겨 다닌다).

  int _tab = 0;

  /// 위 그림 칸 보기(탭을 옮겨도 그대로): 'flat' 판(전개도), 'side' 측면도(절곡 판만), '3d'.
  /// 한 번도 고르지 않았으면 절곡 탭만 측면도로 보인다(10-11).
  String _view = 'flat';
  bool _viewPicked = false;

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

  String _viewOf(PlatePlan p, String id) {
    // 직접 절곡은 절곡선을 눌러 고치므로 전개도로
    final v = !_viewPicked && id == 'bend'
        ? (_custom ? 'flat' : 'side')
        : _view;
    return v == 'side' && p.bendPlan == null ? 'flat' : v;
  }

  /// 결과·보내기 탭 판 그림에는 홀 위치 치수를 단다(10-11).
  bool _holeDimsOn(String id) => id == 'result' || id == 'send';

  Widget _canvas(PlatePlan? p, String id) {
    if (p == null) {
      return Center(
        child: Text(
          '두께와 치수를 넣으면 그림이 나옵니다.',
          style: TextStyle(color: fc.textSub, fontWeight: FontWeight.w700),
        ),
      );
    }
    final tone = PlateTone.now;
    switch (_viewOf(p, id)) {
      case '3d':
        return Plate3dView(plan: p, t: _num(_t));
      case 'side':
        return CustomPaint(
          key: const Key('pl_side'),
          painter: PlateSidePainter.of(
            p,
            t: _num(_t),
            text: fc.text,
            sub: fc.textSub,
            bg: fc.background,
            tone: tone,
            topInset: 46,
            hat: _shape == PlateShape.hat,
          ),
          child: const SizedBox.expand(),
        );
      default:
        return Padding(
          padding: const EdgeInsets.fromLTRB(6, 46, 6, 26),
          child: LayoutBuilder(
            builder: (context, box) {
              // 그림 칸이 낮으면(휴대폰 세로) 홀 치수를 빼서 판이 작아지지 않게(홀 자리는 아래 표에)
              final dims = _holeDimsOn(id) && box.maxHeight >= 260;
              final drag = id == 'bend' && _custom;
              return GestureDetector(
                key: const Key('pl_view'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _tapPreview(
                  p,
                  box.biggest,
                  d.localPosition,
                  holeDims: dims,
                ),
                // 손가락을 댄 자리부터(움직인 뒤 자리로 잡으면 절곡선이 손가락보다 뒤처진다)
                dragStartBehavior: DragStartBehavior.down,
                onHorizontalDragStart: drag
                    ? (d) => _dragStart(p, box.biggest, d.localPosition)
                    : null,
                onHorizontalDragUpdate: drag
                    ? (d) => _dragUpdate(p, box.biggest, d.localPosition)
                    : null,
                onHorizontalDragEnd: drag ? (_) => _dragEnd() : null,
                child: CustomPaint(
                  painter: PlatePainter(
                    plan: p,
                    text: fc.text,
                    sub: fc.textSub,
                    bg: fc.background,
                    showCenter: _showCenter,
                    holeDims: dims,
                    tone: tone,
                  ),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        );
    }
  }

  List<Widget> _canvasTools(PlatePlan? p, String id) {
    if (p == null) return const [];
    final mode = _viewOf(p, id);
    void pick(String v) => setState(() {
      _view = v;
      _viewPicked = true;
    });
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

  String? _canvasHint(PlatePlan? p, String id) {
    if (p == null) return null;
    return switch (_viewOf(p, id)) {
      'flat' =>
        id == 'bend' && _custom
            ? '주황 절곡선을 누르면 고치고, 옆으로 끌면 옮깁니다'
            : _previewHint(),
      'side' => '바깥 치수 (mm) · 번호는 절곡 차례',
      _ => null,
    };
  }

  /// 모양 그림 카드: 폭에 맞춰 한 줄(휴대폰에서 한 장만 둘째 줄로 떨어지던 것, 10-11).
  Widget _shapeCards(List<(PlateShape, String)> shapes) => LayoutBuilder(
    builder: (context, box) {
      final n = shapes.length;
      const gap = 8.0;
      final cols = (box.maxWidth - gap * (n - 1)) / n >= 60
          ? n
          : (n / 2).ceil();
      final w = math.min((box.maxWidth - gap * (cols - 1)) / cols, 112.0);
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final (s, name) in shapes)
            PlateShapeCard(
              key: Key('pl_shape_${s.name}'),
              shape: s,
              label: name,
              width: w,
              selected: _shape == s,
              onTap: () => _set(() {
                if (s != _shape) _flips = [];
                _shape = s;
                if (s == PlateShape.custom && _points.text == _kCutPoints) {
                  _points.text = _kRectPoints;
                  _freeBase = null;
                  _syncFreeSize();
                }
              }),
            ),
        ],
      );
    },
  );

  /// 두께: 단추(설정의 재질별 두께) 줄 끝에 작은 칸. 단추에 없는 두께를 넣으면 칸 테두리가 진해진다(10-11).
  Widget _thicknessRow() {
    final opts = _cfg.thick[_mat] ?? const <String>[];
    final cur = _t.text.trim();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final v in opts)
          PlateSegButton(
            key: Key('pl_t_$v'),
            label: '${v}T',
            selected: cur == v,
            onTap: () => _setThickness(v),
            pill: true,
          ),
        SizedBox(
          width: 104,
          child: PlateNumField(
            fieldKey: 'pl_t',
            label: null,
            controller: _t,
            unit: 'T',
            hint: '직접',
            highlight: cur.isNotEmpty && !opts.contains(cur),
            onChanged: (_) => _set(() {
              if (_bend) _applyBendSource(keepManual: true);
            }),
          ),
        ),
      ],
    );
  }

  // ① 모양: 모양 · 재질·두께 · 치수 · 네 귀 · 수량·이름
  Widget _shapePanel(PlatePlan? p) {
    final shapes = _bend ? kPlateBendShapes : kPlateCutShapes;
    final bent = plateShapeBends(_shape);
    final bad = p != null && p.problems.isNotEmpty;
    return PlatePanel(
      title: '모양',
      // 고른 값은 아래 칸에 다 보이므로 상태 줄은 안 되는 이유만
      status: p == null ? '두께와 치수를 넣으십시오.' : (bad ? p.problems.first : null),
      statusKey: const Key('pl_shape_status'),
      statusColor: bad ? fc.danger : null,
      actions: [
        plateHelpButton(context, 'pl_help_shape', '모양 탭', _shapeHelp()),
      ],
      controller: _scroll,
      children: [
        PlateSection(
          _bend ? '절곡 모양' : '자를 모양',
          [_shapeCards(shapes)],
          first: true,
          trailing: _bend
              ? null
              : TextButton.icon(
                  key: const Key('pl_dxf_import'),
                  style: TextButton.styleFrom(
                    foregroundColor: fc.brand,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _importDxf,
                  icon: const Icon(AppIcons.openFile, size: 18),
                  label: const Text(
                    'DXF 불러오기',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
        ),
        PlateSection(bent ? '치수 (바깥 치수)' : '치수', _dimRows()),
        if (_shape == PlateShape.flat) PlateSection('네 코너', _cornerRows()),
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
          _thicknessRow(),
        ]),
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
      PlateShape.circle => [
        '외경: 원 지름입니다. 홀 위치는 원을 감싸는 사각의 왼쪽 아래에서 잰 (가로, 세로)입니다(가운데 = 외경의 반, 반).',
      ],
      PlateShape.ring => [
        '외경·내경: 바깥 지름과 가운데 뚫린 지름입니다. 링 폭이 두께보다 좁으면 알립니다.',
        '홀 위치는 원을 감싸는 사각의 왼쪽 아래에서 잰 (가로, 세로)입니다.',
      ],
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
      PlateShape.custom => [
        '가로·세로 (전체): 바깥 치수로 펴 그린 판의 크기입니다. 바꾸면 모양·홀·절곡선 자리가 같이 늘거나 줄어듭니다.',
        '꼭짓점: 좌표 입력과 같습니다(가로,세로 한 줄에 하나, 코너는 ,r10 ,c5 ,n20x15). 스케치로 만들기에서 "절단 + 절곡으로"를 누르면 그린 모양이 여기로 옵니다.',
        '절곡선은 절곡 탭에서 넣습니다: 판 끝에서 그 절곡 바깥 꼭짓점까지 바깥 치수, UP/DOWN, 각도. 전개도는 절곡마다 공제값만큼 줄여 만듭니다.',
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
    '두께: 단추를 누르거나 단추 줄 끝 칸에 직접 넣습니다. 단추에 없는 두께를 넣으면 칸 테두리가 진해집니다.${_bend ? ' 그 두께의 업체 값을 설정에 저장해 두었으면 절곡 탭이 업체 값으로 바뀝니다.' : ''}',
    '재질은 중량 계산에 씁니다. 두께 단추는 설정에서 재질별로 바꿉니다(처음 값은 흔히 쓰는 두께, 업체 재고 확인). 없는 두께는 칸에 직접 넣습니다.',
    if (!_bend)
      'DXF 불러오기: 레이저 업체용 DXF를 읽어 좌표 입력(원이면 원형·링)으로 바꿉니다. 둥근 코너는 코너 R, 원은 홀, 장공은 장공으로 읽고, 다른 안쪽 따냄은 읽지 못합니다. CUT 층이 있으면 그 층만 읽습니다.',
    '위 그림: 치수를 누르면 그 칸으로, 판을 누르면 홀 탭으로 갑니다. 오른쪽 위에서 ${_bend ? '측면도·' : ''}3D로 바꿔 볼 수 있습니다.',
    '품명은 가공 도면 PDF·DXF 파일 이름과 규격 저장 이름에 쓰입니다. 비워도 됩니다.',
  ];

  List<Widget> _dimRows() {
    const gap = SizedBox.shrink();
    return switch (_shape) {
      PlateShape.circle => [
        plateRow([_f('pl_cd', '외경', _cd), gap]),
      ],
      PlateShape.ring => [
        plateRow([_f('pl_cd', '외경', _cd), _f('pl_ci', '내경', _ci)]),
      ],
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
      PlateShape.free || PlateShape.custom => [
        if (_custom)
          Text(
            '바깥 치수로 펴 그린 판입니다. 절곡선은 절곡 탭에서 넣습니다.',
            key: const Key('pl_custom_note'),
            style: TextStyle(
              fontSize: 13,
              color: fc.brand,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
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
          _custom
              ? '가로·세로를 바꾸면 모양·홀·절곡선 자리가 그 크기로 늘거나 줄어듭니다(홀 지름·코너 크기는 그대로).'
              : '가로·세로를 바꾸면 모양 전체와 홀 위치가 그 크기로 늘거나 줄어듭니다(홀 지름·코너 크기는 그대로).',
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
        PlateFieldGrid([
          _f('pl_l1', '1면', _l1),
          _f('pl_l2', '2면', _l2),
          _f('pl_wid', '폭', _wid),
          _f('pl_ang', '절곡 각도', _angle, unit: '°'),
        ]),
      ],
      PlateShape.u => [
        PlateFieldGrid([
          _f('pl_l1', '1면', _l1),
          _f('pl_l2', '2면', _l2),
          _f('pl_l3', '3면', _l3),
          _f('pl_wid', '폭', _wid),
        ]),
      ],
      PlateShape.z => [
        PlateFieldGrid([
          _f('pl_l1', '1면', _l1),
          _f('pl_l2', '높이', _l2),
          _f('pl_l3', '3면', _l3),
          _f('pl_wid', '폭', _wid),
        ]),
      ],
      PlateShape.hat => [
        PlateFieldGrid([
          _f('pl_l1', '발', _l1),
          _f('pl_l2', '높이', _l2),
          _f('pl_l3', '윗면', _l3),
          _f('pl_wid', '폭', _wid),
        ]),
      ],
    };
  }

  // ② 절곡(절곡만): 공제값 기준(일반값·업체 값·직접) · 쓰는 값 · 절곡선 표. 업체 값 저장·관리는 설정 화면(10-11).
  Widget _bendPanel(PlatePlan? p) {
    final saved = _bendTable[_tKey];
    final manual = _bm == 'manual';
    String v(double? x, [int d = 1]) => x == null ? '-' : fmt(x, d);
    return PlatePanel(
      title: '절곡',
      status: p == null ? '두께와 치수를 넣으십시오.' : null,
      statusKey: const Key('pl_bendcond'),
      actions: [
        plateHelpButton(context, 'pl_help_bend', '절곡 탭', [
          '일반값: 내R은 두께와 같게, K값 0.33으로 공제값을 계산합니다.',
          '업체 값: 설정에 저장해 둔 이 두께의 업체 내R·공제값입니다. 두께를 고르면 저절로 바뀝니다.',
          '직접 넣기: 업체가 알려 준 내R·90° 공제값(바깥 치수 두 개 합 − 전개 길이)을 넣습니다. 공제값을 넣으면 그 값이 나오게 K값을 맞추고, 비우면 일반값입니다. "업체 값 저장"을 누르면 설정에 남깁니다.',
          'UP·DOWN: 절곡마다 접는 쪽을 바꿉니다(전개도를 위에서 본 쪽이 UP).',
          if (_custom)
            '직접: 절곡선은 판 끝(세로선은 왼쪽, 가로선은 아래)에서 그 절곡 바깥 꼭짓점까지 바깥 치수로 넣습니다. 전개도는 절곡마다 공제값만큼 줄여 만들고, 홀은 펴 그린 판 위 자리를 지킵니다. 위 그림에서 절곡선을 누르면 고치고, 옆으로 끌면 옮깁니다.',
          kPlateBasis[4],
          kPlateBasis[7],
        ]),
      ],
      children: [
        PlateSection(
          '공제값 기준',
          [
            PlateSegments([
              PlateOption(
                'pl_bm_auto',
                '일반값',
                _bm == 'auto',
                () => _setBendMode('auto', p),
              ),
              if (saved != null)
                PlateOption(
                  'pl_bm_saved',
                  '업체 값 ${_tKey}T',
                  _bm == 'saved',
                  () => _setBendMode('saved', p),
                ),
              PlateOption(
                'pl_bm_manual',
                '직접 넣기',
                manual,
                () => _setBendMode('manual', p),
              ),
            ]),
            plateRow(
              manual
                  ? [
                      _f('pl_r', '내R', _r, hint: fmt(_num(_t))),
                      _f(
                        'pl_bd',
                        '90° 공제값',
                        _bd,
                        hint: p == null ? null : fmt(p.bd90Used, 2),
                      ),
                      PlateValueField(
                        key: const Key('pl_k'),
                        label: 'K값',
                        value: p == null ? '-' : p.kUsed.toStringAsFixed(2),
                      ),
                    ]
                  : [
                      PlateValueField(
                        key: const Key('pl_r_view'),
                        label: '내R',
                        value: v(p?.rUsed),
                        unit: 'mm',
                      ),
                      PlateValueField(
                        key: const Key('pl_bd_view'),
                        label: '90° 공제값',
                        value: v(p?.bd90Used, 2),
                        unit: 'mm',
                      ),
                      PlateValueField(
                        key: const Key('pl_k'),
                        label: 'K값',
                        value: p == null ? '-' : p.kUsed.toStringAsFixed(2),
                      ),
                    ],
            ),
            Text(
              switch (_bm) {
                'saved' => '설정에 저장한 ${_tKey}T 업체 값입니다. 고치거나 지우려면 "업체 값 관리".',
                'manual' =>
                  '업체가 알려 준 값을 넣습니다. 다음에도 쓰려면 "업체 값 저장"을 눌러 설정에 남기십시오.',
                _ =>
                  saved == null
                      ? '내R = 두께, K값 0.33으로 계산합니다. 업체 값을 받았으면 "직접 넣기".'
                      : '내R = 두께, K값 0.33으로 계산합니다.',
              },
              key: const Key('pl_bd_info'),
              style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.35),
            ),
          ],
          first: true,
          trailing: TextButton(
            key: const Key('pl_bd_manage'),
            style: TextButton.styleFrom(
              foregroundColor: fc.brand,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => _openSettings(bend: true, p: p),
            child: Text(
              manual ? '업체 값 저장' : '업체 값 관리',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        if (p != null && (p.bends.isNotEmpty || _custom))
          PlateSection(_custom ? '절곡선 (판 끝에서 바깥 치수)' : '절곡선 · 방향', [
            if (_custom)
              PlateSegments([
                PlateOption(
                  'pl_bax_v',
                  '세로선 (왼쪽 끝에서)',
                  !_blH,
                  () => _setAxis(false),
                ),
                PlateOption(
                  'pl_bax_h',
                  '가로선 (아래 끝에서)',
                  _blH,
                  () => _setAxis(true),
                ),
              ]),
            KeyedSubtree(
              key: const Key('pl_bends'),
              child: Column(
                children: _custom
                    ? [
                        for (var n = 0; n < _bls.length; n++)
                          _customBendRow(p, n),
                      ]
                    : [
                        for (var n = 0; n < p.bends.length; n++)
                          _bendItem(
                            n: n,
                            title: '${fmt(p.bends[n].turn.abs())}° 절곡',
                            sub:
                                '전개도 절곡선 ${fmt(p.bends[n].center, 1)} · 절곡부 ${fmt(p.bends[n].start, 1)} ~ ${fmt(p.bends[n].end, 1)}',
                            up: p.bends[n].turn >= 0,
                            onDir: (up) => _setFlip(p, n, up),
                          ),
                      ],
              ),
            ),
            if (_custom && _bls.isEmpty)
              Text(
                '절곡선이 없습니다. "절곡선 넣기"를 누르십시오. 넣은 뒤에는 위 그림에서 절곡선을 눌러 고치거나 옆으로 끌어 옮깁니다.',
                key: const Key('pl_bl_empty'),
                style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.35),
              ),
            if (_custom)
              plateActions([
                PlateActionButton(
                  key: const Key('pl_bl_add'),
                  icon: AppIcons.add,
                  label: '절곡선 넣기',
                  primary: true,
                  onTap: () => _editBendLine(null),
                ),
              ])
            else
              Text(
                'UP·DOWN은 전개도(DXF)를 위에서 본 쪽입니다. 바꾸면 측면도·3D·DXF가 따라 바뀝니다.',
                style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.35),
              ),
          ]),
      ],
    );
  }

  /// 절곡선 한 줄: 번호 · 글 두 줄 · UP/DOWN 단추 · (직접 절곡) 고치기.
  Widget _bendItem({
    required int n,
    required String title,
    required String sub,
    required bool up,
    required ValueChanged<bool> onDir,
    VoidCallback? onEdit,
    bool bad = false,
  }) => Container(
    key: Key('pl_bend_item_${n + 1}'),
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: fc.line)),
    ),
    child: Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bad ? fc.danger : kPlateBend,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${n + 1}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: bad ? fc.danger : fc.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 12.5,
                  color: fc.textSub,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 124,
          child: PlateSegments([
            PlateOption('pl_bdir_${n + 1}_up', 'UP', up, () => onDir(true)),
            PlateOption(
              'pl_bdir_${n + 1}_down',
              'DOWN',
              !up,
              () => onDir(false),
            ),
          ]),
        ),
        if (onEdit != null)
          IconButton(
            key: Key('pl_bl_edit_${n + 1}'),
            tooltip: '고치기',
            icon: Icon(Icons.edit_outlined, color: fc.textSub),
            onPressed: onEdit,
          ),
      ],
    ),
  );

  /// 직접 절곡 절곡선 한 줄(판 밖이면 빨강).
  Widget _customBendRow(PlatePlan p, int n) {
    final b = _bls[n];
    final w = p.faceLengths.fold(0.0, (s, v) => s + v);
    final ok = b.at > 1e-6 && b.at < w - 1e-6;
    var i = -1;
    for (var k = 0; k <= n; k++) {
      if (_bls[k].at > 1e-6 && _bls[k].at < w - 1e-6) i++;
    }
    final line = ok && i >= 0 && i < p.bends.length ? p.bends[i] : null;
    return _bendItem(
      n: n,
      title: '${fmt(b.at)}mm · ${fmt(b.angle)}°',
      sub: line == null
          ? '판 밖(판 끝에서 0 ~ ${fmt(w)}mm 사이로)'
          : '전개도 절곡선 ${fmt(line.center, 1)} · 절곡부 ${fmt(line.start, 1)} ~ ${fmt(line.end, 1)}',
      up: b.up,
      bad: line == null,
      onDir: (up) => _set(() => _bls = List.of(_bls)..[n] = b.copyWith(up: up)),
      onEdit: () => _editBendLine(n),
    );
  }

  /// 절곡선 표: 번호 · 절곡선(가운데) · 절곡부(시작 ~ 끝) · 방향·각도.
  Widget _bendsTable(PlatePlan p) => PlateTable(
    headers: const ['번호', '절곡선', '절곡부', '방향'],
    flex: const [2, 3, 5, 4],
    numeric: const [false, true, true, true],
    rowKeys: [
      for (var n = 0; n < p.bends.length; n++) Key('pl_bend_row_${n + 1}'),
    ],
    rows: [
      for (var n = 0; n < p.bends.length; n++)
        [
          '${n + 1}',
          fmt(p.bends[n].center, 1),
          '${fmt(p.bends[n].start, 1)} ~ ${fmt(p.bends[n].end, 1)}',
          '${p.bends[n].turn >= 0 ? 'UP' : 'DOWN'} ${fmt(p.bends[n].turn.abs())}°',
        ],
    ],
  );

  /// 홀 위치 표: 판(전개도) 왼쪽 아래에서 가로·세로. 절곡 판은 면 기준 자리도.
  Widget _holesTable(PlatePlan p) {
    final bent = p.isBent;
    return PlateTable(
      headers: bent
          ? const ['번호', '모양', '면 기준', '가로', '세로']
          : const ['번호', '모양', '가로', '세로'],
      flex: bent ? const [2, 5, 5, 3, 3] : const [2, 6, 3, 3],
      numeric: bent
          ? const [false, false, false, true, true]
          : const [false, false, true, true],
      rowKeys: [for (final h in p.holes) Key('pl_hole_row_${h.label}')],
      rows: [
        for (final h in p.holes)
          [
            h.label,
            plateHoleKind(h),
            if (bent)
              '${p.faceNames[h.face.clamp(0, p.faceNames.length - 1)]} ${fmt(h.u, 1)} · ${fmt(h.v, 1)}',
            fmt(h.c.dx - p.minX, 1),
            fmt(h.c.dy - p.minY, 1),
          ],
      ],
    );
  }

  // ③ 구멍: 구멍 배치 편집(그림 칸·작업판을 같은 틀로 스스로 그린다)
  Widget _holesTab() => PlateHoleEditorPage(
    embedded: true,
    showCenter: _showCenter,
    input: _input(),
    holes: List.of(_holes),
    rotQ: _rotQ,
    dies: _cfg.dias,
    defaultDia: _cfg.defaultDia,
    grid: _grid,
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
      '절단 길이 = 외곽 둘레 + 홀·장공·내경 둘레. 피어싱 = 외곽 1 + 안쪽 따냄마다 1. 레이저 가공비는 보통 재질·두께와 절단 길이·피어싱 수로 매깁니다(업체마다 다름).',
      '원판 배치: 부품을 감싸는 사각 기준으로 원판에 줄 맞춰 놓아 셉니다(바로·돌려 놓기·남는 띠 돌려 채우기). 원판 크기·부품 간격·가장자리 여유는 설정에서 바꿉니다. ㄱ·삼각·좌표 모양은 업체 네스팅이 더 많이 나올 수 있습니다.',
      kPlateBasis[5],
      kPlateBasis[6],
      kPlateBasis[10],
    ]);
    if (p == null) {
      return PlatePanel(
        title: '결과',
        status: '두께와 치수를 넣으면 계산합니다.',
        actions: [help],
        children: const [],
      );
    }
    final bent = plateShapeBends(_shape);
    return PlatePanel(
      title: '결과',
      actions: [help],
      children: [
        PlateSection('중량', [
          KeyedSubtree(
            key: const Key('pl_result'),
            child: PlateBigValue(
              value: '개당 약 ${_kg(p.kgEach)}kg',
              caption:
                  '${kPlateMaterials[_mat]!.$1} ${fmt(_num(_t))}T · $_qtyN장 합계 약 ${_kg(p.kgTotal)}kg',
              warn: warn,
            ),
          ),
        ], first: true),
        PlateSection('가공 정보 (가공비 기준)', [
          KeyedSubtree(
            key: const Key('pl_cut'),
            child: PlateInfoRow(
              '절단 길이',
              '1개 약 ${(p.cutLength / 1000).toStringAsFixed(2)} m${_qtyN > 1 ? ' · $_qtyN개 약 ${(p.cutLength * _qtyN / 1000).toStringAsFixed(2)} m' : ''}',
            ),
          ),
          PlateInfoRow(
            '피어싱',
            '1개 ${p.pierces}곳 (외곽 1 + 홀${p.cutouts.isEmpty ? '' : '·내경'})',
          ),
          PlateInfoRow(
            '넓이',
            '${(p.areaMm2 / 1e6).toStringAsFixed(4)} m² (홀 뺀 것)',
          ),
        ]),
        if (p.problems.isNotEmpty || p.notes.isNotEmpty)
          PlateSection('확인할 것', [
            if (p.problems.isNotEmpty) PlateLines(p.problems, color: fc.danger),
            if (p.notes.isNotEmpty) PlateLines(p.notes, color: fc.caution),
            if (p.holes.any((h) => h.bad || h.caution))
              Text(
                '위 그림에서 빨간 테두리 홀은 만들 수 없고, 노란 테두리 홀은 확인이 필요합니다.',
                key: const Key('pl_issue_legend'),
                style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.35),
              ),
          ]),
        if (p.bends.isNotEmpty)
          PlateSection('절곡선 (전개도 왼쪽 끝에서, mm)', [
            _bendsTable(p),
            Text(
              _bendCond(p),
              style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.35),
            ),
          ]),
        PlateSection(bent ? '홀 위치 (전개도 왼쪽 아래에서, mm)' : '홀 위치 (판 왼쪽 아래에서, mm)', [
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
            KeyedSubtree(key: const Key('pl_holes'), child: _holesTable(p)),
        ]),
        _nestSection(p),
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
      status: p == null ? '두께와 치수를 넣으면 보낼 수 있습니다.' : '레이저 업체에 보낼 파일과 글',
      actions: [
        plateHelpButton(context, 'pl_help_send', '보내기 탭', [
          kPlateBasis[8],
          '가공 도면 PDF: 그림·치수·홀 표·서명 칸이 들어갑니다.',
          '카톡 글: 치수·중량·절곡·홀 위치를 글로 보냅니다.',
        ]),
      ],
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
                '가공비 기준: ${_cutText(p)} (1개).',
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

  /// 결과 탭 "원판 배치": 원판 고르기 · 간격 · 한 장에 몇 개 · 원판 몇 장 · 배치 그림.
  Widget _nestSection(PlatePlan p) {
    final n = _nest(p);
    final need = n.count == 0 ? 0 : (_qtyN / n.count).ceil();
    return PlateSection(
      '원판 배치',
      [
        PlateInfoRow(
          '원판',
          '${_cfg.sheetName} · 간격 ${fmt(_cfg.gap)} · 여유 ${fmt(_cfg.margin)}',
        ),
        KeyedSubtree(
          key: const Key('pl_nest'),
          child: PlateInfoRow(
            '한 장에',
            n.count == 0
                ? '부품이 원판보다 큽니다'
                : '${n.count}개 · 사용률 ${(n.usage * 100).toStringAsFixed(0)}% · 수량 $_qtyN장에 원판 $need장',
            color: n.count == 0 ? fc.danger : null,
          ),
        ),
        if (n.count > 0)
          SizedBox(
            height: 150,
            child: CustomPaint(
              key: const Key('pl_nest_view'),
              painter: _NestPainter(
                sheet: _sheetSize,
                parts: n.parts,
                sheetColor: fc.fill,
                partColor: PlateTone.now.fill,
                edge: fc.textSub,
              ),
              child: const SizedBox.expand(),
            ),
          ),
      ],
      trailing: TextButton(
        key: const Key('pl_nest_settings'),
        style: TextButton.styleFrom(
          foregroundColor: fc.brand,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: _openSettings,
        child: const Text(
          '원판 바꾸기',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  /// DXF 불러오기(레이저 절단만): 파일을 골라 좌표 입력·원형·링으로. 알림에서 되돌릴 수 있다.
  Future<void> _importDxf() async {
    final text = await (widget.pickDxf ?? _pickDxfText)();
    if (text == null || !mounted) return;
    final PlateDxfImport r;
    try {
      r = importPlateDxf(text);
    } on FormatException catch (e) {
      if (mounted) showAppSnack(context, e.message);
      return;
    } catch (_) {
      if (mounted) showAppSnack(context, 'DXF를 읽지 못했습니다.');
      return;
    }
    final before = _draft();
    _set(() {
      _shape = r.shape;
      _rotQ = 0;
      if (r.shape == PlateShape.free) {
        _points.text = platePointsText(r.points, r.corners);
        _freeBase = null;
        _syncFreeSize();
      } else {
        _cd.text = fmt(r.dia);
        if (r.shape == PlateShape.ring) _ci.text = fmt(r.innerDia);
      }
      _holes
        ..clear()
        ..addAll(r.holes);
    });
    if (!mounted) return;
    final what = r.shape == PlateShape.free
        ? '꼭짓점 ${r.points.length}개'
        : '${plateShapeName(r.shape)} Ø${fmt(r.dia)}';
    showAppSnack(
      context,
      'DXF를 불러왔습니다: $what · 홀 ${r.holes.length}개${r.notes.isEmpty ? '' : '. ${r.notes.join(' ')}'}',
      onUndo: () =>
          _set(() => _applyMap(jsonDecode(before) as Map<String, dynamic>)),
      duration: const Duration(seconds: 6),
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
          // 재질 이름(철판·SUS·알루미늄) — 알루미늄을 골라도 "철판"으로 나오던 것(10-11 실기기)
          '${kPlateMaterials[_mat]!.$1} ${plateShapeName(_shape)} · ${fmt(_num(_t))}T · ${_bend ? '전개 ' : ''}$size';
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
              // 아이콘만 있어 뭔지 몰랐다(10-11): 자주 쓰는 "저장"은 이름 붙은 단추, 나머지는 더 보기 메뉴(이름 있음)
              actions: [
                PlateBarAction(
                  key: const Key('pl_saved'),
                  icon: Icons.bookmarks_outlined,
                  label: '저장',
                  onTap: _openSaved,
                ),
                PopupMenuButton<String>(
                  key: const Key('pl_more'),
                  tooltip: '더 보기',
                  icon: Icon(Icons.more_vert, color: fc.text),
                  color: fc.surface,
                  onSelected: (v) {
                    if (v == 'history') {
                      showCalcHistorySheet(
                        context,
                        calcHistory,
                        title: '최근 계산 기록',
                      );
                    } else if (v == 'settings') {
                      _openSettings();
                    }
                  },
                  itemBuilder: (_) => [
                    _menuItem(
                      'pl_history',
                      'history',
                      Icons.history_rounded,
                      '최근 계산 기록',
                    ),
                    _menuItem(
                      'pl_settings',
                      'settings',
                      AppIcons.settings,
                      '철판 가공 설정',
                    ),
                  ],
                ),
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
                      'bend' => 0.4,
                      _ => 0.36,
                    },
                    canvas: KeyedSubtree(
                      key: const ValueKey('pl_canvas'),
                      child: _canvas(p, id),
                    ),
                    tools: _canvasTools(p, id),
                    hint: _canvasHint(p, id),
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

  PopupMenuItem<String> _menuItem(
    String key,
    String value,
    IconData icon,
    String label,
  ) => PopupMenuItem<String>(
    key: Key(key),
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: fc.textSub),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w700, color: fc.text),
        ),
      ],
    ),
  );

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
    PlateShape.custom => '주황 점선은 절곡선 · 판을 누르면 홀',
    PlateShape.rib => '치수를 누르면 그 칸, 판을 누르면 홀',
    PlateShape.circle || PlateShape.ring => '판을 누르면 홀',
    _ => '주황 점선은 절곡선 · 판을 누르면 홀',
  };

  /// 그림을 눌렀을 때: 귀(평판)·꼭짓점(자유) → 귀 처리, 치수 숫자 → 그 칸, 판 안 → 구멍 넣기·고치기.
  void _tapPreview(PlatePlan p, Size size, Offset at, {bool holeDims = false}) {
    final lay = PlatePainterLayout.of(p, size, holeDims: holeDims);
    if (lay == null) return;
    if (_custom && _tabs[_tab.clamp(0, _tabs.length - 1)].$1 == 'bend') {
      final k = _blAt(p, size, at);
      if (k != null) _editBendLine(k);
      return;
    }
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
    PlateShape.circle => '원형: 둥근 판(외경). 받침판·덮개 등.',
    PlateShape.ring => '링: 가운데가 뚫린 둥근 판(외경·내경). 와셔·플랜지 등.',
    PlateShape.flat => '평판: 사각 판에 홀·장공. 네 코너를 따로 R·모따기(C)·따내기 할 수 있습니다.',
    PlateShape.rib => '삼각 리브: ㄱ자 안쪽에 용접하는 보강판. 직각 모서리를 따내 용접 자리를 비웁니다.',
    PlateShape.free => '좌표 입력: 외곽 꼭짓점 좌표를 차례로 넣어 모양을 만듭니다.',
    PlateShape.custom =>
      '직접: 바깥 치수로 펴 그린 판(좌표·스케치)에 절곡선을 넣어, 원하는 자리·방향·각도로 절곡합니다.',
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

/// 원판 배치 그림: 원판(회색)과 부품 자리(외곽 사각).
class _NestPainter extends CustomPainter {
  _NestPainter({
    required this.sheet,
    required this.parts,
    required this.sheetColor,
    required this.partColor,
    required this.edge,
  });

  final (double, double) sheet;
  final List<Rect> parts;
  final Color sheetColor, partColor, edge;

  @override
  void paint(Canvas canvas, Size size) {
    var (w, h) = sheet;
    if (w <= 0 || h <= 0) return;
    // 길쭉한 쪽을 가로로 눕혀 그린다
    final rotate = h > w;
    if (rotate) (w, h) = (h, w);
    final s = math.min((size.width - 2) / w, (size.height - 2) / h);
    final ox = (size.width - w * s) / 2, oy = (size.height - h * s) / 2;
    Rect tr(Rect r) {
      final rr = rotate ? Rect.fromLTWH(r.top, r.left, r.height, r.width) : r;
      return Rect.fromLTWH(
        ox + rr.left * s,
        oy + (h - rr.bottom) * s,
        rr.width * s,
        rr.height * s,
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(ox, oy, w * s, h * s),
      Paint()..color = sheetColor,
    );
    canvas.drawRect(
      Rect.fromLTWH(ox, oy, w * s, h * s),
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final fill = Paint()..color = partColor;
    final line = Paint()
      ..color = edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final r in parts) {
      final q = tr(r);
      canvas.drawRect(q, fill);
      canvas.drawRect(q, line);
    }
  }

  @override
  bool shouldRepaint(covariant _NestPainter old) =>
      old.sheet != sheet || old.parts != parts || old.sheetColor != sheetColor;
}
