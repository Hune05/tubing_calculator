// 부스바 가공(10-03): 구리 부스바를 현장에서 L·U·Z로 꺾을 때 절단 길이와 꺾기 시작선.
// 계산은 busbar_bend.dart.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
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

/// 꺾는 각도(°) 칩.
const List<double> kBusbarBendAngles = [15, 30, 45, 60, 90];

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
  double _angle = 90;
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
    for (var i = 0; i <= kBusbarFreeMax; i++) TextEditingController(text: '100'),
  ];
  final List<double> _ft = [90, -90, 90, -90, 90, -90];

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
    for (final c in _fs) {
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
          if (a is num && kBusbarBendAngles.contains(a.toDouble())) {
            _angle = a.toDouble();
          }
          for (var i = 0; i < _fields.length; i++) {
            final v = m[_fieldKeys[i]];
            if (v is String) _fields[i].text = v;
          }
          final nb = m['nb'];
          if (nb is num && nb >= 1 && nb <= kBusbarFreeMax) _nBends = nb.toInt();
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
              if (v is num && kBusbarBendAngles.contains(v.abs().toDouble())) {
                _ft[i] = v.toDouble();
              }
            }
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
    if (_z != null && !_z!.feasible) {
      b.write('\n※ 이 높이는 반경 때문에 꺾을 수 없습니다. 최소 ${fmt(_z!.minHeight, 1)}mm');
    }
    return b.toString();
  }

  // ── 화면 ──

  Widget _drawing(Key key, double height, CustomPainter painter) => Container(
    key: key,
    height: height,
    decoration: BoxDecoration(
      color: fc.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: fc.line),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(painter: painter, child: const SizedBox.expand()),
    ),
  );

  Widget _markTile(BusbarBend b, int i) => calcBox(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
    ),
  );

  /// 자유 꺾기 입력: 곳 수 → 시작 직선 → (곳마다 각도·방향·다음 직선).
  List<Widget> _freeFields() => [
    elecChipGroup(
      '꺾는 곳 수',
      '곳 수를 고르면 그 수만큼 칸이 나옵니다(최대 $kBusbarFreeMax곳). 곧은 길이는 꺾기선 사이입니다: 꺾기 끝선에서 다음 꺾기 시작선까지(줄긋기 마킹과 같은 기준).',
      [
        for (var n = 1; n <= kBusbarFreeMax; n++)
          calcChip('bb_n_$n', '$n곳', _nBends == n, () => _set(() => _nBends = n)),
      ],
    ),
    elecField(
      'bb_fs_0',
      '시작 직선 (mm)',
      _fs[0],
      '부스바 끝에서 첫 꺾기 시작선까지 곧은 길이입니다.',
      onEdit: _saveSoon,
    ),
    for (var i = 0; i < _nBends; i++) ...[
      elecChipGroup(
        '꺾기 ${i + 1} 각도',
        '꺾은 뒤 진행 방향이 바뀐 각도입니다.',
        [
          for (final a in kBusbarBendAngles)
            calcChip(
              'bb_fa_${i}_${a.toInt()}',
              '${fmt(a)}°',
              _ft[i].abs() == a,
              () => _set(() => _ft[i] = _ft[i] < 0 ? -a : a),
            ),
        ],
      ),
      elecChipGroup(
        '꺾기 ${i + 1} 방향',
        '위로(청록)와 아래로(주황)는 그림의 옆모습에서 꺾이는 쪽입니다. 같은 쪽으로 이어 꺾으면 ㄷ자·계단, 번갈아 꺾으면 ㄹ자·오프셋입니다.',
        [
          calcChip('bb_fd_${i}_up', '위로', _ft[i] >= 0, () => _set(() => _ft[i] = _ft[i].abs())),
          calcChip('bb_fd_${i}_down', '아래로', _ft[i] < 0, () => _set(() => _ft[i] = -_ft[i].abs())),
        ],
      ),
      elecField(
        'bb_fs_${i + 1}',
        i == _nBends - 1 ? '끝 직선 (mm)' : '직선 ${i + 1} (mm)',
        _fs[i + 1],
        i == _nBends - 1
            ? '꺾기 ${i + 1} 끝선에서 부스바 끝까지 곧은 길이입니다.'
            : '꺾기 ${i + 1} 끝선에서 꺾기 ${i + 2} 시작선까지 곧은 길이입니다.',
        onEdit: _saveSoon,
      ),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final p = _plan();
    final z = _z;
    final warn = _radiusWarn;
    final bad = z != null && !z.feasible;
    final isU = _kind == BusbarBendKind.u;
    final isZ = _kind == BusbarBendKind.z;
    final isFree = _kind == BusbarBendKind.free;
    String? summary;

    final children = <Widget>[
      elecField(
        'bb_job',
        '작업 이름 (선택)',
        _jobName,
        '지시서 PDF 제목과 규격 저장 이름에 쓰입니다. 비워도 됩니다.',
        onEdit: _saveSoon,
      ),
      elecChipGroup(
        '꺾기 종류',
        'L: 한 번 꺾기. U: 같은 방향으로 두 번(ㄷ자). Z: 반대 방향으로 두 번(오프셋, 높이를 맞춰 비켜감). 자유: 꺾는 곳을 최대 6곳까지 곳마다 각도·방향을 골라 이어 꺾기(계단·ㄹ자 등).',
        [
          for (final k in BusbarBendKind.values)
            calcChip(
              'bb_k_${k.name}',
              busbarBendKindLabel(k),
              _kind == k,
              () => _set(() => _kind = k),
            ),
        ],
      ),
      elecChipGroup(
        '꺾는 방향',
        '눕혀 꺾기: 넓은 면이 꺾입니다(두께 방향). 세워 꺾기(edgewise): 폭 방향으로 꺾어 두께 면을 세웁니다. 세워 꺾기는 판 두께 자리에 폭을 씁니다.',
        [
          for (final pl in BusbarBendPlane.values)
            calcChip(
              'bb_p_${pl.name}',
              busbarBendPlaneLabel(pl),
              _plane == pl,
              () => _set(() => _plane = pl),
            ),
        ],
      ),
      elecSectionTitle('부스바'),
      elecField(
        'bb_t',
        '두께 (mm)',
        _thick,
        '구리 부스바 두께입니다(예 3·5·6·10).',
        onEdit: _saveSoon,
      ),
      elecField(
        'bb_w',
        '폭 (mm)',
        _width,
        '구리 부스바 폭입니다(예 30·50·100).',
        onEdit: _saveSoon,
      ),
      elecField(
        'bb_r',
        '안쪽 반경 (mm, 비우면 ${fmt(_d)})',
        _radius,
        '꺾는 곳 안쪽 반경입니다. 벤더 어댑터(예 8·15mm) 값을 넣습니다. 비우면 판 두께(${fmt(_d)}mm) 1배로 계산합니다.',
        onEdit: _saveSoon,
      ),
      elecChipGroup(
        '중립선 계수 k',
        '꺾을 때 길이가 변하지 않는 선이 안쪽 면에서 k × 두께만큼 떨어져 있다고 봅니다. 구리 부스바 범위 0.33~0.5. 시험 조각으로 맞춥니다.',
        [
          for (final k in kBusbarK)
            calcChip(
              'bb_kf_${(k * 100).round()}',
              fmt(k, 2),
              _k == k,
              () => _set(() => _k = k),
            ),
          if (!kBusbarK.contains(_k))
            calcChip('bb_kf_custom', fmt(_k, 3), true, () {}),
        ],
      ),
      elecChipGroup(
        '벤더 프로필',
        '시험 조각을 꺾어 측정한 값으로 k와 스프링백을 구해 벤더별로 보관합니다. 고르면 안쪽 반경·k·스프링백이 들어갑니다.',
        [
          calcChip(
            'bb_profile',
            _profileName == null ? '프로필 고르기·만들기' : '적용: $_profileName',
            _profileName != null,
            _openProfiles,
          ),
          if (_profileName != null)
            calcChip(
              'bb_profile_off',
              '해제',
              false,
              () => _set(() {
                _profileName = null;
                _spring = 1.0;
              }),
            ),
        ],
      ),
      elecSectionTitle('치수'),
      if (!isZ && !isFree)
        elecChipGroup('치수 기준', '바깥 치수: 꺾은 바깥 모서리까지. 안쪽 치수: 안쪽 모서리까지.', [
          for (final r in BusbarDimRef.values)
            calcChip(
              'bb_ref_${r.name}',
              busbarDimRefLabel(r),
              _ref == r,
              () => _set(() => _ref = r),
            ),
        ]),
      if (!isU && !isFree)
        elecChipGroup('꺾는 각도', '꺾은 뒤 진행 방향이 바뀐 각도입니다. 90°는 직각으로 꺾습니다.', [
          for (final a in kBusbarBendAngles)
            calcChip(
              'bb_a_${a.toInt()}',
              '${fmt(a)}°',
              _angle == a,
              () => _set(() => _angle = a),
            ),
        ]),
      if (isFree) ..._freeFields(),
      if (!isFree)
      elecField(
        'bb_ia',
        isZ ? '시작 직선 (mm)' : '다리 1 (mm)',
        _a,
        isZ ? '부스바 끝에서 첫 꺾기 시작선까지 곧은 길이입니다.' : '부스바 한쪽 끝에서 꺾인 모서리까지 길이입니다.',
        onEdit: _saveSoon,
      ),
      if (!isZ && !isFree)
        elecField(
          'bb_ib',
          isU ? '바닥 (mm)' : '다리 2 (mm)',
          _b,
          isU ? 'U의 바닥 길이(두 모서리 사이)입니다.' : '다른 쪽 끝에서 꺾인 모서리까지 길이입니다.',
          onEdit: _saveSoon,
        ),
      if ((isU || isZ) && !isFree)
        elecField(
          'bb_ic',
          isZ ? '끝 직선 (mm)' : '다리 2 (mm)',
          _c,
          isZ ? '두 번째 꺾기 끝선에서 부스바 끝까지 곧은 길이입니다.' : '다른 쪽 다리 길이입니다.',
          onEdit: _saveSoon,
        ),
      if (isZ && !isFree)
        elecField(
          'bb_ih',
          '오프셋 높이 (mm)',
          _h,
          '두 곧은 구간의 같은 쪽 면 사이 높이입니다.',
          onEdit: _saveSoon,
        ),
      const SizedBox(height: 8),
    ];

    if (p == null) {
      children.add(
        calcResult(solve: true, 
          key: const Key('bb_result'),
          big: '— mm',
          caption: '두께와 치수를 넣으면 계산합니다',
          lines: const [],
        ),
      );
    } else {
      summary =
          '${busbarBendKindLabel(_kind)} ${fmt(_t)}×${fmt(_w)} · 절단 길이 ${fmt(p.cutLength, 1)}mm';
      children.addAll([
        calcResult(solve: true, 
          key: const Key('bb_result'),
          big: '${fmt(p.cutLength, 1)} mm',
          caption: '절단 길이 · 꺾는 곳 ${p.bends.length}곳 · 안쪽 반경 ${fmt(_r)}mm',
          warn: warn != null || bad,
          lines: [
            if (bad)
              '이 높이는 반경 때문에 꺾을 수 없습니다. 이 각도·반경에서 최소 높이 ${fmt(z.minHeight, 1)}mm. 각도를 줄이거나 높이를 키우십시오.',
            ?warn,
            if (z != null && z.feasible)
              '비스듬한 곧은 길이 ${fmt(z.slope, 1)}mm · 꺾기 사이 진행 거리 ${fmt(z.run, 1)}mm',
            '직선 구간: ${p.straights.map((s) => fmt(s, 1)).join(' · ')}mm',
            ..._springLines(p.bends.map((b) => b.turn)),
            if (_plane == BusbarBendPlane.edge)
              '세워 꺾기는 최소 반경 자료를 못 찾아 확인하지 않았습니다. 시험 조각으로 먼저 꺾어 보십시오.',
          ],
        ),
        const SizedBox(height: 12),
        calcLabel(
          '꺾은 뒤 모양',
          '옆에서 본 실제 비율 그림입니다. 번호는 아래 마킹 번호와 같고, 청록은 위로 꺾기, 주황은 아래로 꺾기입니다.',
        ),
        const SizedBox(height: 4),
        _drawing(
          const Key('bb_shape_view'),
          200,
          BusbarShapePainter(
            plan: p,
            rho: busbarNeutralRadius(_d, _r, _k),
            thickness: _plane == BusbarBendPlane.flat ? _t : _w,
            text: fc.text,
            sub: fc.textSub,
            line: fc.line,
          ),
        ),
        const SizedBox(height: 12),
        calcLabel('자르기 전 마킹', '곧은 부스바 한쪽 끝 기준 꺾기 시작선·끝선 위치입니다.'),
        const SizedBox(height: 4),
        _drawing(
          const Key('bb_mark_view'),
          130,
          BusbarMarkPainter(
            plan: p,
            text: fc.text,
            sub: fc.textSub,
            line: fc.line,
          ),
        ),
        const SizedBox(height: 12),
        elecSectionTitle('마킹 (한쪽 끝에서)'),
        for (var i = 0; i < p.bends.length; i++) _markTile(p.bends[i], i),
        const SizedBox(height: 8),
        ...elecFold('bb_fold_notes', '작업 순서', [
        calcResult(solve: true, 
          key: const Key('bb_notes'),
          big: '작업 순서',
          caption: '현장에서 꺾을 때',
          lines: const [
            '절단 길이로 부스바를 자릅니다. 절단면 버(burr)를 갈아 냅니다.',
            '한쪽 끝에서 꺾기 시작선을 줄긋기로 표시합니다. 양면에 같이 긋습니다.',
            '벤더 꺾는 날(어댑터)의 시작 위치를 시작선에 맞춥니다.',
            '먼저 같은 규격 시험 조각을 꺾어 길이·각도를 확인하고 k와 반경을 맞춥니다.',
            '꺾은 뒤 스프링백이 있으니 목표 각도보다 조금 더 꺾고 되돌리며 맞춥니다.',
          ],
        ),
        ], subtitle: '자르기 → 시작선 → 시험 조각 → 꺾기'),
      ]);
    }
    children.addAll([
      const SizedBox(height: 12),
      elecBasis('bb_basis', kBusbarBendBasis),
    ]);

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
              '부스바 가공',
              style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
            ),
            actions: [
              if (p != null)
                IconButton(
                  key: const Key('bb_share'),
                  tooltip: '카톡으로 보내기',
                  icon: Icon(Icons.share_outlined, color: fc.text),
                  onPressed: () => widget.share(_shareText(p)),
                ),
              if (p != null)
                IconButton(
                  key: const Key('bb_pdf'),
                  tooltip: '절곡 지시서 PDF',
                  icon: Icon(Icons.picture_as_pdf_outlined, color: fc.text),
                  onPressed: () => openBendPdf(context, _pdfInput(p)),
                ),
              IconButton(
                key: const Key('bb_saved'),
                tooltip: '저장한 규격',
                icon: Icon(Icons.bookmarks_outlined, color: fc.text),
                onPressed: _openSaved,
              ),
              calcHistoryButton(),
            ],
          ),
          body: elecPage(
            children,
            sumKey: 'bb_sum',
            summary: summary,
            warn: warn != null || bad,
          ),
        ),
      ),
    );
  }
}
