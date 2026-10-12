// 부스바 가공(10-03): 구리 부스바를 현장에서 L·U·Z로 꺾을 때 절단 길이와 꺾기 시작선.
// 계산은 busbar_bend.dart. 10-12 화면 틀을 철판 가공처럼: 위 그림(꺾은 모양·마킹) + 아래 탭(모양·부스바·결과·보내기).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/theme/field_view.dart';
import '../../core/theme/app_icon_set.dart';
import '../calculator/widgets/swipe_delete.dart' show calcNavCompact;
import '../common/app_icons.dart';
import '../common/calc_form_parts.dart';
import '../common/preset_menu.dart';
import '../steel_plate/plate_ui.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'busbar_bend.dart';
import 'busbar_bend_painter.dart';
import 'busbar_bend_pdf.dart';
import 'busbar_bender_profile.dart';
import 'busbar_saved_specs.dart';
import 'elec_form_parts.dart';

Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

enum BusbarBendKind { l, u, z, free }

String busbarBendKindLabel(BusbarBendKind k) => switch (k) {
  BusbarBendKind.l => 'L 꺾기',
  BusbarBendKind.u => 'U 꺾기',
  BusbarBendKind.z => 'Z 꺾기 (오프셋)',
  BusbarBendKind.free => '자유 꺾기 (여러 번)',
};

/// 자유 꺾기에서 꺾을 수 있는 최대 곳 수.
const int kBusbarFreeMax = 6;

/// 꺾는 각도(°) — 각도 칸 ▼ 목록(자유 꺾기는 단추). 목록 밖 각도도 칸에 넣을 수 있다(10-12).
const List<double> kBusbarBendAngles = [15, 30, 45, 60, 90];

/// 부스바 두께·폭 칸 ▼ 목록(mm, 시중 동부스바에서 흔한 값). 목록 밖 값도 칸에 그대로 넣는다.
const List<double> kBusbarThicks = [3, 4, 5, 6, 8, 10, 12];
const List<double> kBusbarWidths = [
  15,
  20,
  25,
  30,
  40,
  50,
  60,
  75,
  80,
  100,
  120,
  150,
];

/// 중립선 위치 계수 칩. 구리 부스바 범위 0.33~0.5(두 자료가 같음).
const List<double> kBusbarK = [0.33, 0.4, 0.45, 0.5];

/// 눕혀 꺾기 최소 안쪽 반경(mm). CDA Pub.22 표 6(반경질·경질, 한 곳 자료): 두께 ≤10mm 1배, 11~25mm 1.5배, 26~50mm 2배.
double busbarMinRadius(double thickness) => thickness <= 10
    ? thickness
    : (thickness <= 25 ? 1.5 * thickness : 2 * thickness);

const List<String> kBusbarBendBasis = [
  '식: 중립선 반경 ρ = r + k·d, 셋백 s = ρ·tan(θ/2), 호 길이 = ρ·θ. 절단 길이 = 꼭짓점 사이 길이의 합 − Σ(2s − 호 길이). 90° L 한 번은 일반 굽힘 공제식 BD = 2(r + t) − (π/2)(r + k·t)와 같습니다.',
  'k: 구리 부스바는 0.33~0.5(Rittal·payapress 두 자료가 같은 범위)입니다. 기본 0.4는 그 가운데 값이라, 시험 조각을 꺾어 실측으로 맞추십시오.',
  '최소 안쪽 반경: CDA(Copper Development Association) Pub.22 표 6 한 곳 자료입니다. 두께 10mm 이하 1배, 11~25mm 1.5배, 26~50mm 2배. 재질(연질·경질)과 상관없이 같습니다.',
  '세워 꺾기(edgewise)는 값을 확인한 자료를 못 찾아 반경 경고를 하지 않습니다. 폭이 넓을수록 큰 반경이 필요하니 시험 조각으로 확인하십시오.',
  '스프링백·벤더별 보정: 시험 조각을 꺾어 측정한 값으로 벤더 프로필을 만들면 k와 스프링백 비율이 들어갑니다. 기계에서 꺾을 각도 = 목표 각도 × 스프링백 비율입니다. 프로필이 없으면 스프링백은 보정하지 않습니다.',
  '넣지 않은 것: 비틀기, 구멍 가공.',
];

class BusbarBendPage extends StatefulWidget {
  const BusbarBendPage({super.key, this.share = _defaultShare});

  /// 결과 글 보내기(시험에서 바꿔 끼운다).
  final Future<void> Function(String text) share;

  static const draftKey = 'busbar_bend_draft_v1';

  @override
  State<BusbarBendPage> createState() => _BusbarBendPageState();
}

class _BusbarBendPageState extends State<BusbarBendPage>
    with
        CalcFormParts<BusbarBendPage>,
        RecentCalcHistoryMixin<BusbarBendPage>,
        ElecTabParts<BusbarBendPage> {
  /// 최근 계산 기록을 폰에 이틀 동안 남기는 칸.
  @override
  String? get calcHistoryStorageKey => 'calc_history_busbar_bend';

  BusbarBendKind _kind = BusbarBendKind.l;
  BusbarBendPlane _plane = BusbarBendPlane.flat;
  BusbarDimRef _ref = BusbarDimRef.outside;
  double _k = 0.4;
  double _spring = 1.0; // 스프링백 비율(기계 세팅 ÷ 목표), 1이면 보정 없음
  String? _profileName; // 적용 중인 벤더 프로필 이름
  /// 꺾는 각도 칸(L·Z). 0 < 각 < 180만 계산.
  final _angleC = TextEditingController(text: '90');
  double get _angle => readNum(_angleC) ?? 0;
  bool get _angleOk => _angle > 0 && _angle < 180;
  final _thick = TextEditingController(text: '5');
  final _width = TextEditingController(text: '50');
  final _radius = TextEditingController(); // 비우면 판 두께 1배
  final _a = TextEditingController(text: '100');
  final _b = TextEditingController(text: '100'); // L: 다리 b, U: 바닥
  final _c = TextEditingController(text: '100'); // U: 다리 c, Z: 끝 직선
  final _h = TextEditingController(text: '40'); // Z 높이
  final _jobName = TextEditingController(); // 작업 이름(지시서·저장 이름)

  // 자유 꺾기: 꺾는 곳 수, 곧은 길이(곳 수 + 1개), 곳마다 부호 있는 각(+ 위로, − 아래로).
  int _nBends = 3;
  final List<TextEditingController> _fs = [
    for (var i = 0; i <= kBusbarFreeMax; i++)
      TextEditingController(text: '100'),
  ];
  final List<double> _ft = [90, -90, 90, -90, 90, -90];

  /// 자유 꺾기 꺾기마다 각도 칸(10-12, 단추 대신). 방향(부호)은 [_ft], 크기는 칸 글이 맞을 때(0 < 각 < 180) [_ft]에 넣는다.
  final List<TextEditingController> _fa = [
    for (var i = 0; i < kBusbarFreeMax; i++) TextEditingController(text: '90'),
  ];
  static bool _okFreeAngle(double? v) => v != null && v > 0 && v < 180;
  void _readFreeAngle(int i) {
    final v = readNum(_fa[i]);
    if (_okFreeAngle(v)) _ft[i] = _ft[i] < 0 ? -v! : v!;
  }

  Timer? _saveTimer;
  bool _draftReady = false;

  List<TextEditingController> get _fields => [
    _thick,
    _width,
    _radius,
    _a,
    _b,
    _c,
    _h,
    _jobName,
  ];
  static const _fieldKeys = ['t', 'w', 'r', 'a', 'b', 'c', 'h', 'jn'];

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveNow();
    for (final c in _fields) {
      c.dispose();
    }
    _angleC.dispose();
    for (final c in _fs) {
      c.dispose();
    }
    for (final c in _fa) {
      c.dispose();
    }
    super.dispose();
  }

  String _draft() => jsonEncode({
    'kind': _kind.name,
    'plane': _plane.name,
    'ref': _ref.name,
    'k': _k,
    'sp': _spring,
    'pn': _profileName,
    'ang': _angle,
    'nb': _nBends,
    'fs': [for (final c in _fs) c.text],
    'ft': _ft,
    for (var i = 0; i < _fields.length; i++) _fieldKeys[i]: _fields[i].text,
  });

  Future<void> _loadDraft() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(BusbarBendPage.draftKey);
      if (raw != null && mounted) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        setState(() => _applyMap(m));
      }
    } catch (_) {}
    _draftReady = true;
  }

  /// 저장된 값을 화면 상태에 넣는다. setState 안에서 부른다.
  // "최근 계산 기록"을 눌러 되돌릴 때 저장 칸과 같은 모양을 쓴다.
  @override
  Map<String, Object?>? historySnapshot() =>
      jsonDecode(_draft()) as Map<String, dynamic>;

  @override
  void applyHistorySnapshot(Map<String, dynamic> m) => _applyMap(m);

  void _applyMap(Map<String, dynamic> m) {
    {
      {
        {
          final kd = BusbarBendKind.values.where((x) => x.name == m['kind']);
          if (kd.isNotEmpty) _kind = kd.first;
          final pl = BusbarBendPlane.values.where((x) => x.name == m['plane']);
          if (pl.isNotEmpty) _plane = pl.first;
          final rf = BusbarDimRef.values.where((x) => x.name == m['ref']);
          if (rf.isNotEmpty) _ref = rf.first;
          final k = m['k'], a = m['ang'];
          if (k is num && k >= kBenderKMin && k <= kBenderKMax) {
            _k = k.toDouble();
          }
          final sp = m['sp'], pn = m['pn'];
          _spring = sp is num && sp >= 0.8 && sp <= 1.5 ? sp.toDouble() : 1.0;
          _profileName = pn is String ? pn : null;
          if (a is num && a > 0 && a < 180) {
            _angleC.text = fmt(a.toDouble(), 3);
          }
          for (var i = 0; i < _fields.length; i++) {
            final v = m[_fieldKeys[i]];
            if (v is String) _fields[i].text = v;
          }
          final nb = m['nb'];
          if (nb is num && nb >= 1 && nb <= kBusbarFreeMax) {
            _nBends = nb.toInt();
          }
          final fsv = m['fs'];
          if (fsv is List) {
            for (var i = 0; i < _fs.length && i < fsv.length; i++) {
              if (fsv[i] is String) _fs[i].text = fsv[i] as String;
            }
          }
          final ftv = m['ft'];
          if (ftv is List) {
            for (var i = 0; i < _ft.length && i < ftv.length; i++) {
              final v = ftv[i];
              if (v is num && _okFreeAngle(v.abs().toDouble())) {
                _ft[i] = v.toDouble();
              }
            }
          }
          for (var i = 0; i < _fa.length; i++) {
            _fa[i].text = fmt(_ft[i].abs(), 3);
          }
        }
      }
    }
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
        .then((p) => p.setString(BusbarBendPage.draftKey, d))
        .catchError((_) => false);
  }

  /// 칸 안 ▼ 목록에서 고르면 칸에 넣는다(10-12).
  Future<void> _pickPreset(
    BuildContext btn,
    TextEditingController c,
    List<double> values,
    String keyPrefix,
    String Function(double) label, {
    String Function(double)? keyOf,
    VoidCallback? then,
  }) async {
    final v = await showPresetMenu(
      btn,
      current: presetKey(readNum(c) ?? -1),
      items: [
        for (final x in values)
          PresetItem(
            presetKey(x),
            label(x),
            key: Key('$keyPrefix${keyOf == null ? presetKey(x) : keyOf(x)}'),
          ),
      ],
    );
    if (v == null || !mounted) return;
    _set(() {
      c.text = v;
      then?.call();
    });
    _saveSoon();
  }

  void _set(VoidCallback f) {
    setState(f);
    _saveSoon();
  }

  double _num(TextEditingController c) {
    final v = readNum(c);
    return v == null || v < 0 ? 0 : v;
  }

  // ── 계산 ──

  double get _t => _num(_thick);
  double get _w => _num(_width);

  /// 꺾는 방향의 판 두께.
  double get _d => busbarBendDepth(_t, _w, _plane);

  /// 안쪽 반경: 비우면 판 두께 1배.
  double get _r => readNum(_radius) ?? _d;

  bool get _ready {
    if (_d <= 0 || _r < 0) return false;
    return switch (_kind) {
      BusbarBendKind.l => _num(_a) > 0 && _num(_b) > 0,
      BusbarBendKind.u => _num(_a) > 0 && _num(_b) > 0 && _num(_c) > 0,
      BusbarBendKind.z => _num(_h) > 0,
      BusbarBendKind.free => [
        for (var i = 0; i <= _nBends; i++) readNum(_fs[i]),
      ].every((v) => v != null && v >= 0),
    };
  }

  BusbarZ? _z;

  BusbarBendPlan? _plan() {
    if (!_ready) return null;
    _z = null;
    // 각도 칸이 비었거나 0·180 이상이면 계산하지 않는다(L·Z만 각도를 쓴다)
    if ((_kind == BusbarBendKind.l || _kind == BusbarBendKind.z) && !_angleOk) {
      return null;
    }
    switch (_kind) {
      case BusbarBendKind.l:
        return busbarL(
          d: _d,
          r: _r,
          k: _k,
          a: _num(_a),
          b: _num(_b),
          deg: _angle,
          ref: _ref,
        );
      case BusbarBendKind.u:
        return busbarU(
          d: _d,
          r: _r,
          k: _k,
          a: _num(_a),
          web: _num(_b),
          c: _num(_c),
          ref: _ref,
        );
      case BusbarBendKind.z:
        final z = busbarZ(
          d: _d,
          r: _r,
          k: _k,
          a: _num(_a),
          c: _num(_c),
          h: _num(_h),
          deg: _angle,
        );
        _z = z;
        return z.plan;
      case BusbarBendKind.free:
        return busbarFree(
          d: _d,
          r: _r,
          k: _k,
          straights: [for (var i = 0; i <= _nBends; i++) _num(_fs[i])],
          turns: [for (var i = 0; i < _nBends; i++) _ft[i]],
        );
    }
  }

  /// 반경 경고. 눕혀 꺾기만 값이 있다.
  String? get _radiusWarn {
    if (_plane != BusbarBendPlane.flat) return null;
    final min = busbarMinRadius(_t);
    if (_r + 1e-9 >= min) return null;
    return '안쪽 반경 ${fmt(_r)}mm가 최소 반경 ${fmt(min)}mm(CDA, 두께 ${fmt(_t)}mm 기준)보다 작습니다. 모서리가 갈라질 수 있습니다.';
  }

  String get _dimText => switch (_kind) {
    BusbarBendKind.l =>
      '${busbarDimRefLabel(_ref)} ${fmt(_num(_a))} × ${fmt(_num(_b))}mm, ${fmt(_angle)}°',
    BusbarBendKind.u =>
      '${busbarDimRefLabel(_ref)} 다리 ${fmt(_num(_a))} · 바닥 ${fmt(_num(_b))} · 다리 ${fmt(_num(_c))}mm, 90°',
    BusbarBendKind.z =>
      '직선 ${fmt(_num(_a))} · 높이 ${fmt(_num(_h))} · 직선 ${fmt(_num(_c))}mm, ${fmt(_angle)}°',
    BusbarBendKind.free => '${_freeDimParts().join(' · ')}mm',
  };

  List<String> _freeDimParts() => [
    '직선 ${fmt(_num(_fs[0]))}',
    for (var i = 0; i < _nBends; i++) ...[
      '${_ft[i] >= 0 ? '위' : '아래'} ${fmt(_ft[i].abs())}°',
      '직선 ${fmt(_num(_fs[i + 1]))}',
    ],
  ];

  String _bendLine(BusbarBend b, int i) =>
      '${i + 1}. 시작선 ${fmt(b.start, 1)}mm · 끝선 ${fmt(b.end, 1)}mm  (${b.turn >= 0 ? '위로' : '아래로'} ${fmt(b.turn.abs())}°)';

  void _applyProfile(BenderProfile p) => _set(() {
    _radius.text = fmt(p.radius, 2);
    _k = p.k;
    _spring = p.spring;
    _profileName = p.name;
  });

  Future<void> _openProfiles() => openBenderProfiles(
    context,
    thickness: _d,
    radius: _r,
    onApply: _applyProfile,
    surface: fc.surface,
    text: fc.text,
    textSub: fc.textSub,
  );

  /// 기계에서 꺾을 각도 안내(스프링백 비율이 1이 아닐 때). 같은 각도는 한 줄로 묶는다.
  List<String> _springLines(Iterable<double> turns) {
    if (_spring == 1.0) return const [];
    final seen = <double>{};
    return [
      for (final tdeg in turns)
        if (seen.add(tdeg.abs()))
          '스프링백 보정(×${fmt(_spring, 3)}): 목표 ${fmt(tdeg.abs())}° → 기계에서 ${fmt(benderMachineAngle(tdeg.abs(), _spring), 1)}°로 꺾기',
    ];
  }

  String _savedSummary(Map<String, dynamic> d) {
    final kd = switch (d['kind']) {
      'u' => 'U 꺾기',
      'z' => 'Z 꺾기',
      'free' => '자유 꺾기 ${d['nb'] ?? ''}곳',
      _ => 'L 꺾기',
    };
    final pl = d['plane'] == 'edge' ? '세워' : '눕혀';
    return '${d['t'] ?? ''}×${d['w'] ?? ''} · $kd · $pl';
  }

  Future<void> _openSaved() => openSavedSpecs(
    context,
    storageKey: 'busbar_bend_saved_v1',
    current: () => jsonDecode(_draft()) as Map<String, dynamic>,
    summaryOf: _savedSummary,
    defaultName: _jobName.text.trim().isNotEmpty
        ? _jobName.text.trim()
        : '${_thick.text}×${_width.text} ${busbarBendKindLabel(_kind)}',
    onLoad: (m) => _set(() => _applyMap(m)),
    surface: fc.surface,
    text: fc.text,
    textSub: fc.textSub,
  );

  BendPdfInput _pdfInput(BusbarBendPlan p) => BendPdfInput(
    title: _jobName.text,
    plan: p,
    thickness: _d,
    rho: busbarNeutralRadius(_d, _r, _k),
    innerRadius: _r,
    edge: _plane == BusbarBendPlane.edge,
    summary: [
      ('재료', '구리 평강 ${fmt(_t)} × ${fmt(_w)} mm'),
      (
        '꺾는 방법',
        '${busbarBendKindLabel(_kind)} · ${busbarBendPlaneLabel(_plane)}',
      ),
      ('치수', _dimText),
      ('꺾기 조건', '안쪽 반경 ${fmt(_r)}mm · k ${fmt(_k, 2)}'),
      ('절단 길이', '${fmt(p.cutLength, 1)} mm'),
      if (_z != null)
        (
          '오프셋',
          '비스듬한 곧은 길이 ${fmt(_z!.slope, 1)}mm · 꺾기 사이 진행 ${fmt(_z!.run, 1)}mm',
        ),
    ],
    notes: [
      ?_radiusWarn,
      ..._springLines(p.bends.map((b) => b.turn)),
      if ((_z == null || _z!.feasible) && _busbarTooShort(p))
        kBusbarShortLegMsg,
      if (_z != null && !_z!.feasible)
        '이 높이는 반경 때문에 꺾을 수 없습니다. 최소 높이 ${fmt(_z!.minHeight, 1)}mm.',
      if (_plane == BusbarBendPlane.edge)
        '세워 꺾기는 최소 반경 자료를 못 찾아 확인하지 않았습니다. 시험 조각으로 먼저 꺾어 보십시오.',
      _spring == 1.0
          ? '스프링백(꺾은 뒤 되돌아오는 각)은 보정하지 않았습니다. 벤더 프로필을 만들거나 같은 규격 시험 조각으로 길이·각도를 확인하십시오.'
          : '스프링백은 벤더 프로필 값으로 보정했습니다. 첫 작업은 같은 규격 시험 조각으로 길이·각도를 확인하십시오.',
    ],
  );

  String _shareText(BusbarBendPlan p) {
    final b = StringBuffer(
      '[부스바 절곡] ${busbarBendKindLabel(_kind)} ${fmt(_t)}×${fmt(_w)}mm ${busbarBendPlaneLabel(_plane)}',
    );
    b.write('\n$_dimText');
    b.write(
      '\n안쪽 반경 ${fmt(_r)}mm · k ${fmt(_k, 3)}${_profileName == null ? "" : " (벤더 프로필 $_profileName)"}',
    );
    b.write('\n절단 길이: ${fmt(p.cutLength, 1)}mm');
    b.write('\n마킹 (한쪽 끝에서):');
    for (var i = 0; i < p.bends.length; i++) {
      b.write('\n ${_bendLine(p.bends[i], i)}');
    }
    for (final l in _springLines(p.bends.map((b) => b.turn))) {
      b.write('\n$l');
    }
    final warn = _radiusWarn;
    if (warn != null) b.write('\n※ $warn');
    if ((_z == null || _z!.feasible) && _busbarTooShort(p)) {
      b.write('\n※ $kBusbarShortLegMsg');
    }
    if (_z != null && !_z!.feasible) {
      b.write('\n※ 이 높이는 반경 때문에 꺾을 수 없습니다. 최소 ${fmt(_z!.minHeight, 1)}mm');
    }
    return b.toString();
  }

  // ── 화면(10-12: 철판 가공처럼 위 그림 + 아래 탭 — 사용자 "화면을 철판 가공처럼 분할") ──

  static const _tabs = [
    ('shape', '모양'),
    ('bar', '부스바'),
    ('result', '결과'),
    ('send', '보내기'),
  ];
  int _tab = 0;

  /// 위 그림: shape 꺾은 뒤 모양, mark 자르기 전 마킹.
  String _view = 'shape';

  Widget _canvas(BusbarBendPlan? p) {
    if (p == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _t <= 0 || _w <= 0
                ? '두께와 폭을 넣으면 그림이 나옵니다(부스바 탭).'
                : '치수를 넣으면 그림이 나옵니다.',
            key: const Key('bb_canvas_empty'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: fc.textSub),
          ),
        ),
      );
    }
    final mark = _view == 'mark';
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 52, 10, 30),
      child: CustomPaint(
        key: Key(mark ? 'bb_mark_view' : 'bb_shape_view'),
        painter: mark
            ? BusbarMarkPainter(
                plan: p,
                text: fc.text,
                sub: fc.textSub,
                line: fc.line,
              )
            : BusbarShapePainter(
                plan: p,
                rho: busbarNeutralRadius(_d, _r, _k),
                thickness: _d,
                innerRadius: _r,
                edge: _plane == BusbarBendPlane.edge,
                text: fc.text,
                sub: fc.textSub,
                line: fc.line,
              ),
        child: const SizedBox.expand(),
      ),
    );
  }

  List<Widget> _canvasTools(BusbarBendPlan? p) => p == null
      ? const []
      : [
          PlateViewSwitch([
            PlateOption(
              'bb_vm_shape',
              '꺾은 모양',
              _view == 'shape',
              () => setState(() => _view = 'shape'),
            ),
            PlateOption(
              'bb_vm_mark',
              '마킹',
              _view == 'mark',
              () => setState(() => _view = 'mark'),
            ),
          ]),
        ];

  String? _canvasHint(BusbarBendPlan? p) => p == null
      ? null
      // 직선 구간이 0보다 짧으면 그림이 겹쳐 보인다: 그림 아래에도 알린다(10-12, 세워 꺾기는 반경이 커서 자주 난다)
      : (_z == null || _z!.feasible) && _busbarTooShort(p)
      ? '다리·바닥이 짧아 이 반경으로는 못 꺾습니다(그림이 겹침). 치수를 늘리거나 반경을 줄이십시오.'
      : _view == 'mark'
      ? '곧은 부스바 한쪽 끝 기준 꺾기 시작선·끝선'
      : _plane == BusbarBendPlane.edge
      ? '넓은 면을 위에서 본 실제 비율 · 청록 = 위로, 주황 = 아래로 꺾기'
      : '옆에서 본 실제 비율 · 청록 = 위로, 주황 = 아래로 꺾기';

  Widget _markTile(BusbarBend b, int i) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: busbarBendColor(b.turn),
          child: Text(
            '${i + 1}',
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
                '${fmt(b.start, 1)} mm · ${b.turn >= 0 ? '위로' : '아래로'} ${fmt(b.turn.abs())}°',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: fc.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '꺾기 시작선 ${fmt(b.start, 1)} → 끝선 ${fmt(b.end, 1)} (호 ${fmt(b.end - b.start, 1)}mm). 시작선에 벤더 꺾는 날을 맞춥니다.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: fc.textSub,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _f(
    String key,
    String label,
    TextEditingController c, {
    String? unit = 'mm',
    String? hint,
    Widget? trailing,
    VoidCallback? onEdit,
  }) => PlateNumField(
    fieldKey: key,
    label: label,
    controller: c,
    unit: unit,
    hint: hint,
    trailing: trailing,
    onChanged: (_) {
      onEdit?.call();
      _set(() {});
    },
  );

  Widget _bad(String key, String msg) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      msg,
      key: Key(key),
      style: TextStyle(fontSize: 13, color: fc.danger, height: 1.35),
    ),
  );

  /// 자유 꺾기 입력: 곳 수 → 시작 직선 → (곳마다 각도·방향·다음 직선).
  List<Widget> _freeFields() => [
    PlateSegments([
      for (var n = 1; n <= kBusbarFreeMax; n++)
        PlateOption(
          'bb_n_$n',
          '$n곳',
          _nBends == n,
          () => _set(() => _nBends = n),
        ),
    ]),
    plateRow([_f('bb_fs_0', '시작 직선', _fs[0]), const SizedBox.shrink()]),
    for (var i = 0; i < _nBends; i++) ...[
      const SizedBox(height: 12),
      Text(
        '꺾기 ${i + 1}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: busbarBendColor(_ft[i]),
        ),
      ),
      const SizedBox(height: 6),
      plateRow([
        _f(
          'bb_fa_$i',
          '각도',
          _fa[i],
          unit: '°',
          onEdit: () => _readFreeAngle(i),
          trailing: PresetMenuButton(
            buttonKey: Key('bb_fa_${i}_menu'),
            tooltip: '자주 쓰는 각도',
            onOpen: (btn) => _pickPreset(
              btn,
              _fa[i],
              kBusbarBendAngles,
              'bb_fa_${i}_',
              (a) => '${fmt(a)}°',
              keyOf: (a) => '${a.toInt()}',
              then: () => _readFreeAngle(i),
            ),
          ),
        ),
        _f(
          'bb_fs_${i + 1}',
          i == _nBends - 1 ? '끝 직선' : '직선 ${i + 1}',
          _fs[i + 1],
        ),
      ]),
      if (!_okFreeAngle(readNum(_fa[i])))
        _bad(
          'bb_fa_${i}_bad',
          '0°보다 크고 180°보다 작은 각도를 넣으십시오. 지금 계산은 ${fmt(_ft[i].abs())}°입니다.',
        ),
      PlateSegments([
        PlateOption(
          'bb_fd_${i}_up',
          '위로',
          _ft[i] >= 0,
          () => _set(() => _ft[i] = _ft[i].abs()),
        ),
        PlateOption(
          'bb_fd_${i}_down',
          '아래로',
          _ft[i] < 0,
          () => _set(() => _ft[i] = -_ft[i].abs()),
        ),
      ]),
    ],
  ];

  // ① 모양: 꺾기 종류 · 꺾는 방향 · 치수(기준·각도·길이)
  Widget _shapePanel(BusbarBendPlan? p) {
    final isU = _kind == BusbarBendKind.u;
    final isZ = _kind == BusbarBendKind.z;
    final isFree = _kind == BusbarBendKind.free;
    final z = _z;
    final bad = z != null && !z.feasible;
    return PlatePanel(
      title: '모양',
      status: p == null
          ? (_t <= 0 || _w <= 0 ? '부스바 탭에서 두께와 폭을 넣으십시오.' : '치수를 넣으십시오.')
          : (bad
                ? '이 높이는 반경 때문에 꺾을 수 없습니다(최소 ${fmt(z.minHeight, 1)}mm).'
                : null),
      statusColor: bad ? fc.danger : null,
      actions: [
        plateHelpButton(context, 'bb_help_shape', '모양 탭', [
          'L: 한 번 꺾기. U: 같은 방향으로 두 번(ㄷ자). Z: 반대 방향으로 두 번(오프셋, 높이를 맞춰 비켜감). 자유: 꺾는 곳을 최대 6곳까지 곳마다 각도·방향을 골라 이어 꺾기(계단·ㄹ자 등).',
          '눕혀 꺾기: 넓은 면이 꺾입니다(두께 방향). 세워 꺾기(edgewise): 폭 방향으로 꺾어 두께 면을 세웁니다. 세워 꺾기는 판 두께 자리에 폭을 씁니다.',
          '치수 기준은 둘입니다. 바깥 치수는 꺾은 바깥 모서리까지, 안쪽 치수는 안쪽 모서리까지 잽니다.',
          '꺾는 각도: 꺾은 뒤 진행 방향이 바뀐 각도입니다. 90°는 직각. 숫자를 바로 넣거나 ▼에서 고릅니다.',
          '자유 꺾기 곧은 길이는 꺾기선 사이입니다: 꺾기 끝선에서 다음 꺾기 시작선까지(줄긋기 마킹과 같은 기준). 위로(청록)·아래로(주황)는 그림 옆모습에서 꺾이는 쪽입니다.',
        ]),
      ],
      children: [
        PlateSection('꺾기 종류', [
          PlateSegments([
            for (final k in BusbarBendKind.values)
              PlateOption(
                'bb_k_${k.name}',
                busbarBendKindLabel(k),
                _kind == k,
                () => _set(() => _kind = k),
              ),
          ]),
          PlateSegments([
            for (final pl in BusbarBendPlane.values)
              PlateOption(
                'bb_p_${pl.name}',
                busbarBendPlaneLabel(pl),
                _plane == pl,
                () => _set(() => _plane = pl),
              ),
          ]),
        ], first: true),
        PlateSection(isFree ? '꺾기 (곳 수 · 곳마다)' : '치수', [
          if (!isZ && !isFree) ...[
            PlateSegments([
              for (final r in BusbarDimRef.values)
                PlateOption(
                  'bb_ref_${r.name}',
                  busbarDimRefLabel(r),
                  _ref == r,
                  () => _set(() => _ref = r),
                ),
            ]),
          ],
          if (isFree)
            ..._freeFields()
          else ...[
            if (!isU) ...[
              plateRow([
                _f(
                  'bb_ang',
                  '꺾는 각도',
                  _angleC,
                  unit: '°',
                  trailing: PresetMenuButton(
                    buttonKey: const Key('bb_a_menu'),
                    tooltip: '자주 쓰는 각도',
                    onOpen: (btn) => _pickPreset(
                      btn,
                      _angleC,
                      kBusbarBendAngles,
                      'bb_a_',
                      (a) => '${fmt(a)}°',
                      keyOf: (a) => '${a.toInt()}',
                    ),
                  ),
                ),
                const SizedBox.shrink(),
              ]),
              if (!_angleOk) _bad('bb_ang_bad', '0°보다 크고 180°보다 작은 각도를 넣으십시오.'),
            ],
            PlateFieldGrid([
              _f('bb_ia', isZ ? '시작 직선' : '다리 1', _a),
              if (!isZ) _f('bb_ib', isU ? '바닥' : '다리 2', _b),
              if (isU || isZ) _f('bb_ic', isZ ? '끝 직선' : '다리 2', _c),
              if (isZ) _f('bb_ih', '오프셋 높이', _h),
            ]),
          ],
        ]),
      ],
    );
  }

  // ② 부스바: 두께·폭 · 안쪽 반경 · k · 벤더 프로필
  Widget _barPanel(BusbarBendPlan? p) => PlatePanel(
    title: '부스바',
    status:
        '구리 평강 ${fmt(_t)} × ${fmt(_w)} · 안쪽 반경 ${fmt(_r)} · k ${fmt(_k, 2)}${_profileName == null ? '' : ' · $_profileName'}',
    actions: [
      plateHelpButton(context, 'bb_help_bar', '부스바 탭', [
        '두께·폭: 숫자를 바로 넣거나 ▼에서 고릅니다(목록에 없는 값도 됩니다).',
        '안쪽 반경: 꺾는 곳 안쪽 반경입니다. 벤더 어댑터(예 8·15mm) 값을 넣습니다. 비우면 판 두께 1배로 계산합니다.',
        '중립선 계수 k: 꺾을 때 길이가 변하지 않는 선이 안쪽 면에서 k × 두께만큼 떨어져 있다고 봅니다. 구리 부스바 범위 0.33~0.5. 시험 조각으로 맞춥니다.',
        '벤더 프로필: 시험 조각을 꺾어 측정한 값으로 k와 스프링백을 구해 벤더별로 보관합니다. 고르면 안쪽 반경·k·스프링백이 들어갑니다.',
      ]),
    ],
    children: [
      PlateSection('부스바 (구리 평강)', [
        PlateFieldGrid([
          _f(
            'bb_t',
            '두께',
            _thick,
            trailing: PresetMenuButton(
              buttonKey: const Key('bb_t_menu'),
              tooltip: '자주 쓰는 두께',
              onOpen: (btn) =>
                  _pickPreset(btn, _thick, kBusbarThicks, 'bb_tv_', fmt),
            ),
          ),
          _f(
            'bb_w',
            '폭',
            _width,
            trailing: PresetMenuButton(
              buttonKey: const Key('bb_w_menu'),
              tooltip: '자주 쓰는 폭',
              onOpen: (btn) =>
                  _pickPreset(btn, _width, kBusbarWidths, 'bb_wv_', fmt),
            ),
          ),
        ]),
      ], first: true),
      PlateSection('꺾기 조건', [
        plateRow([
          _f('bb_r', '안쪽 반경', _radius, hint: '비우면 ${fmt(_d)}'),
          const SizedBox.shrink(),
        ]),
        Text(
          '중립선 계수 k',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: fc.textSub,
          ),
        ),
        const SizedBox(height: 6),
        PlateSegments([
          for (final k in kBusbarK)
            PlateOption(
              'bb_kf_${(k * 100).round()}',
              fmt(k, 2),
              _k == k,
              () => _set(() => _k = k),
            ),
          if (!kBusbarK.contains(_k))
            PlateOption('bb_kf_custom', fmt(_k, 3), true, () {}),
        ]),
        plateActions([
          PlateActionButton(
            key: const Key('bb_profile'),
            icon: Icons.tune_rounded,
            label: _profileName == null
                ? '벤더 프로필 고르기·만들기'
                : '적용: $_profileName',
            primary: _profileName != null,
            onTap: _openProfiles,
          ),
          if (_profileName != null)
            PlateActionButton(
              key: const Key('bb_profile_off'),
              icon: Icons.close_rounded,
              label: '해제',
              onTap: () => _set(() {
                _profileName = null;
                _spring = 1.0;
              }),
            ),
        ]),
      ]),
    ],
  );

  // ③ 결과: 절단 길이 · 알림 · 마킹 · 작업 순서 · 근거
  Widget _resultPanel(BusbarBendPlan? p) {
    final z = _z;
    final warn = _radiusWarn;
    final bad = z != null && !z.feasible;
    final short = p != null && !bad && _busbarTooShort(p);
    return PlatePanel(
      title: '결과',
      status: p == null
          ? '두께와 치수를 넣으면 계산합니다.'
          : '꺾는 곳 ${p.bends.length}곳 · 안쪽 반경 ${fmt(_r)}mm',
      children: [
        PlateSection('절단 길이', [
          KeyedSubtree(
            key: const Key('bb_result'),
            child: PlateBigValue(
              value: p == null ? '— mm' : '${fmt(p.cutLength, 1)} mm',
              caption: p == null ? '두께와 치수를 넣으면 계산합니다' : '자르기 전 곧은 부스바 길이',
              warn: warn != null || bad || short,
            ),
          ),
          if (p != null)
            PlateLines([
              if (short) kBusbarShortLegMsg,
              if (bad)
                '이 높이는 반경 때문에 꺾을 수 없습니다. 이 각도·반경에서 최소 높이 ${fmt(z.minHeight, 1)}mm. 각도를 줄이거나 높이를 키우십시오.',
              ?warn,
              if (z != null && z.feasible)
                '비스듬한 곧은 길이 ${fmt(z.slope, 1)}mm · 꺾기 사이 진행 거리 ${fmt(z.run, 1)}mm',
              '직선 구간: ${p.straights.map((s) => fmt(s, 1)).join(' · ')}mm',
              ..._springLines(p.bends.map((b) => b.turn)),
              if (_plane == BusbarBendPlane.edge)
                '세워 꺾기는 최소 반경 자료를 못 찾아 확인하지 않았습니다. 시험 조각으로 먼저 꺾어 보십시오.',
            ]),
        ], first: true),
        if (p != null)
          PlateSection('마킹 (한쪽 끝에서)', [
            for (var i = 0; i < p.bends.length; i++) _markTile(p.bends[i], i),
          ]),
        PlateSection('작업 순서', [
          const KeyedSubtree(
            key: Key('bb_notes'),
            child: PlateLines([
              '절단 길이로 부스바를 자릅니다. 절단면 버(burr)를 갈아 냅니다.',
              '한쪽 끝에서 꺾기 시작선을 줄긋기로 표시합니다. 양면에 같이 긋습니다.',
              '벤더 꺾는 날(어댑터)의 시작 위치를 시작선에 맞춥니다.',
              '먼저 같은 규격 시험 조각을 꺾어 길이·각도를 확인하고 k와 반경을 맞춥니다.',
              '꺾은 뒤 스프링백이 있으니 목표 각도보다 조금 더 꺾고 되돌리며 맞춥니다.',
            ]),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: elecBasis('bb_basis', kBusbarBendBasis),
        ),
      ],
    );
  }

  // ④ 보내기: 작업 이름 · 카톡 글 · 절곡 지시서 PDF
  Widget _sendPanel(BusbarBendPlan? p) => PlatePanel(
    title: '보내기',
    status: p == null ? '두께와 치수를 넣으면 보낼 수 있습니다.' : '카톡 글 · 절곡 지시서 PDF',
    children: [
      PlateSection('지시서', [
        PlateNumField(
          fieldKey: 'bb_job',
          label: '작업 이름 (선택)',
          controller: _jobName,
          unit: null,
          text: true,
          hint: '지시서 PDF 제목·저장 이름',
          onChanged: (_) => _saveSoon(),
        ),
      ], first: true),
      if (p != null)
        PlateSection('보내기', [
          plateActions([
            PlateActionButton(
              key: const Key('bb_share'),
              icon: Icons.chat_bubble_outline_rounded,
              label: '카톡 글',
              primary: true,
              onTap: () => widget.share(_shareText(p)),
            ),
            PlateActionButton(
              key: const Key('bb_pdf'),
              icon: Icons.picture_as_pdf_outlined,
              label: '절곡 지시서 PDF',
              onTap: () => openBendPdf(context, _pdfInput(p)),
            ),
          ]),
        ]),
    ],
  );

  Widget? _navBar(int idx) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return null;
    final compact = calcNavCompact(context);
    BottomNavigationBarItem item(String id, String label, int i) {
      final on = i == idx;
      final Widget icon = switch (id) {
        'shape' => AppIcon(AppGlyph.navInput, size: 24, filled: on),
        'bar' => AppIcon(AppGlyph.busbarBend, size: 24, filled: on),
        'result' => AppIcon(AppGlyph.navMarking, size: 24, filled: on),
        _ => const Icon(AppIcons.send, size: 22),
      };
      return BottomNavigationBarItem(
        icon: Padding(
          padding: EdgeInsets.only(bottom: compact ? 0 : 4),
          child: KeyedSubtree(key: Key('bb_tab_$id'), child: icon),
        ),
        label: label,
      );
    }

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
              for (var i = 0; i < _tabs.length; i++)
                item(_tabs[i].$1, _tabs[i].$2, i),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _plan();
    final z = _z;
    final warn =
        _radiusWarn != null ||
        (z != null && !z.feasible) ||
        (p != null && (z == null || z.feasible) && _busbarTooShort(p));
    final summary = p == null
        ? null
        : '${busbarBendKindLabel(_kind)} ${fmt(_t)}×${fmt(_w)} · 절단 길이 ${fmt(p.cutLength, 1)}mm';
    final idx = _tab.clamp(0, _tabs.length - 1);
    return FieldViewTheme(
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: fc.background,
          appBar: AppBar(
            backgroundColor: fc.surface,
            foregroundColor: fc.text,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '부스바 가공',
                  style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
                ),
                if (summary != null)
                  Text(
                    summary,
                    key: const Key('bb_head'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: warn ? fc.danger : fc.brand,
                    ),
                  ),
              ],
            ),
            actions: [
              PlateBarAction(
                key: const Key('bb_saved'),
                icon: Icons.bookmarks_outlined,
                label: '저장',
                onTap: _openSaved,
              ),
              calcHistoryButton(),
            ],
          ),
          body: elecPageFrame(
            sumKey: 'bb_sum',
            summary: summary,
            warn: warn,
            showBar: false,
            body: PlateWorkspace(
              canvasShare: 0.38,
              canvas: KeyedSubtree(
                key: const ValueKey('bb_canvas'),
                child: _canvas(p),
              ),
              tools: _canvasTools(p),
              hint: _canvasHint(p),
              panel: IndexedStack(
                index: idx,
                children: [
                  for (final t in _tabs)
                    KeyedSubtree(
                      key: ValueKey('bb_body_${t.$1}'),
                      child: switch (t.$1) {
                        'shape' => _shapePanel(p),
                        'bar' => _barPanel(p),
                        'result' => _resultPanel(p),
                        _ => _sendPanel(p),
                      },
                    ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _navBar(idx),
        ),
      ),
    );
  }
}

const kBusbarShortLegMsg =
    '다리가 짧아 이 반경으로는 꺾을 수 없습니다(직선 구간이 0보다 짧음). 다리를 늘리거나 반경을 줄이십시오.';

bool _busbarTooShort(BusbarBendPlan p) => p.straights.any((s) => s < -0.05);
