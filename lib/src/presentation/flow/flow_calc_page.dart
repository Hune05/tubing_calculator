// 유량 계산(배관·튜브 유속, 압력손실, 차압 유량계, 유량계 점검). 탭: 유속·관 굵기 → 압력손실 → 차압 유량계
// → 유량계 점검(명판 측정 범위·출력 방식으로 루프 mA와 지시값 대조, flow_meter_check.dart).
// 계산은 flow_calc.dart, 숫자 자료(물 성질·거칠기·피팅 3-K 값·권장 유속)와 출처는 flow_data.dart,
// 근거는 docs/유량계산_근거.md. 튜브 규격은 pressure_test/tube_rating.dart, 배관 외경은
// unit_converter/unit_defs.dart 표를 그대로 쓴다. 칸마다 "?" 안내.
// 넣은 값은 'flow_calc_draft_v1'에 저장해 다음에 열 때 되살린다.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import '../instrument/signal_calc.dart';
import '../pressure_test/tube_rating.dart';
import '../unit_converter/unit_defs.dart' show kPipeSizes, PipeSize;
import 'flow_calc.dart';
import 'flow_data.dart';
import 'flow_meter_check.dart';

part 'flow_dp_tab.dart';
part 'flow_meter_check_tab.dart';

/// 유체 종류.
enum FluidKind { water, air, n2, oil }

extension FluidKindLabel on FluidKind {
  String get label => switch (this) {
    FluidKind.water => '물',
    FluidKind.air => '공기',
    FluidKind.n2 => '질소',
    FluidKind.oil => '기름',
  };

  bool get gas => this == FluidKind.air || this == FluidKind.n2;
}

/// 관 종류: 튜브(외경×두께 목록) / 배관(호칭·외경 표 + 두께 입력) / 내경 직접 입력.
enum ConduitKind { tube, pipe, id }

/// 배관 외경 기준.
enum PipeOdStd { ks, asme }

String _fmt(double v, [int d = 2]) {
  if (!v.isFinite) return '-';
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  if (s == '-0') s = '0';
  return s;
}

/// 유효 숫자 4자리쯤(소수 0~6자리).
String _sig(double v) {
  if (v == 0 || !v.isFinite) return _fmt(v);
  final mag = (math.log(v.abs()) / math.ln10).floor();
  return _fmt(v, (3 - mag).clamp(0, 6));
}

/// 큰 수는 천 단위 쉼표(레이놀즈 수).
String _int(double v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i - 1] != '-') b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

class FlowCalcPage extends StatefulWidget {
  const FlowCalcPage({super.key});

  @override
  State<FlowCalcPage> createState() => _FlowCalcPageState();
}

class _FlowCalcPageState extends State<FlowCalcPage>
    with
        SingleTickerProviderStateMixin,
        CalcFormParts<FlowCalcPage>,
        WidgetsBindingObserver,
        _FlowDpTab,
        _FlowMeterCheckTab {
  static const _draftKey = 'flow_calc_draft_v1';

  late final TabController _tabs = TabController(length: 4, vsync: this);

  // ─── 유량·유체 ───
  FlowUnit _flowUnit = FlowUnit.lpm;
  final _flow = TextEditingController();
  FluidKind _fluid = FluidKind.water;
  final _waterT = TextEditingController(text: '20');
  GaugeUnit _pUnit = GaugeUnit.bar;
  final _gasP = TextEditingController(text: '7');
  final _gasT = TextEditingController(text: '20');
  final _oilRho = TextEditingController();
  final _oilCst = TextEditingController();
  String _service = kVelocityGuides.first.id;

  // ─── 관 ───
  ConduitKind _conduit = ConduitKind.tube;
  TubeSystem _tubeSys = TubeSystem.inch;
  String _tubeId = 'i1/2x049';
  String _pipeA = '25A';
  PipeOdStd _odStd = PipeOdStd.ks;
  final _pipeWall = TextEditingController();
  final _directId = TextEditingController();

  // ─── 압력손실 ───
  final _length = TextEditingController(text: '10');
  String? _roughId; // null이면 관 종류에 따라(튜브: 인발 튜브, 배관: 상용 강관)
  final _roughMm = TextEditingController();
  final Map<String, int> _fitCount = {for (final f in kFittings) f.id: 0};
  final _extraK = TextEditingController();
  final _dz = TextEditingController();

  Map<String, TextEditingController> get _fields => {
    'flow': _flow,
    'waterT': _waterT,
    'gasP': _gasP,
    'gasT': _gasT,
    'oilRho': _oilRho,
    'oilCst': _oilCst,
    'pipeWall': _pipeWall,
    'directId': _directId,
    'length': _length,
    'roughMm': _roughMm,
    'extraK': _extraK,
    'dz': _dz,
    ..._dpFields,
    ..._mcFields,
  };

  // ─── 임시 저장 ───
  bool _loaded = false;
  bool _touched = false;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw != null && mounted && !_touched) {
        super.setState(() => _applyDraft(raw));
      }
    } catch (_) {
      // 읽지 못하면 기본값으로 시작한다.
    } finally {
      _loaded = true;
    }
  }

  void _applyDraft(String raw) {
    final m = jsonDecode(raw);
    if (m is! Map) return;
    T pick<T extends Enum>(List<T> values, Object? name, T now) =>
        values.firstWhere((v) => v.name == name, orElse: () => now);
    _flowUnit = pick(FlowUnit.values, m['flowUnit'], _flowUnit);
    _fluid = pick(FluidKind.values, m['fluid'], _fluid);
    _pUnit = pick(GaugeUnit.values, m['pUnit'], _pUnit);
    _conduit = pick(ConduitKind.values, m['conduit'], _conduit);
    _tubeSys = pick(TubeSystem.values, m['tubeSys'], _tubeSys);
    _odStd = pick(PipeOdStd.values, m['odStd'], _odStd);
    final t = tubeById(m['tubeId']?.toString());
    _tubeId = t != null && t.system == _tubeSys ? t.id : _tubeDefault;
    final a = m['pipeA']?.toString();
    if (kPipeSizes.any((p) => p.a == a)) _pipeA = a!;
    final r = m['roughId']?.toString();
    _roughId = kRoughness.any((x) => x.id == r) ? r : null;
    final s = m['service']?.toString();
    if (kVelocityGuides.any((g) => g.id == s)) _service = s!;
    final fc = m['fits'];
    if (fc is Map) {
      for (final f in kFittings) {
        final n = fc[f.id];
        if (n is int && n >= 0 && n <= 999) _fitCount[f.id] = n;
      }
    }
    final f = m['fields'];
    if (f is Map) {
      for (final e in _fields.entries) {
        final v = f[e.key];
        if (v is String) e.value.text = v;
      }
    }
    _applyDpDraft(m['dp']);
    _applyMcDraft(m['mc']);
    _fixService(_fluid);
  }

  String _draftJson() => jsonEncode({
    'flowUnit': _flowUnit.name,
    'fluid': _fluid.name,
    'pUnit': _pUnit.name,
    'conduit': _conduit.name,
    'tubeSys': _tubeSys.name,
    'tubeId': _tubeId,
    'pipeA': _pipeA,
    'odStd': _odStd.name,
    'roughId': _roughId,
    'service': _service,
    'fits': _fitCount,
    'fields': {for (final e in _fields.entries) e.key: e.value.text},
    'dp': _dpDraftJson(),
    'mc': _mcDraftJson(),
  });

  static Future<void> _write(String json) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftKey, json);
    } catch (_) {
      // 저장하지 못해도 계산은 그대로 된다.
    }
  }

  void _saveNow() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_loaded) _write(_draftJson());
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (!_loaded) {
      _touched = true;
      return;
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _saveNow);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _saveNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveNow();
    _tabs.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', ''));

  // ─────────────── 입력에서 나오는 값 ───────────────

  String get _tubeDefault =>
      _tubeSys == TubeSystem.inch ? 'i1/2x049' : 'm12x1.5';

  TubeSize get _tube => tubeById(_tubeId) ?? tubeById(_tubeDefault)!;

  PipeSize get _pipe => kPipeSizes.firstWhere(
    (p) => p.a == _pipeA,
    orElse: () => kPipeSizes.first,
  );

  double _pipeOd(PipeSize p) => _odStd == PipeOdStd.ks ? p.ksOd : p.asmeOd;

  /// 관 내경(mm). 계산할 수 없으면 null.
  double? get _idMm {
    switch (_conduit) {
      case ConduitKind.tube:
        return _tube.idMm;
      case ConduitKind.pipe:
        final t = _num(_pipeWall);
        final od = _pipeOd(_pipe);
        if (t == null || t <= 0 || 2 * t >= od) return null;
        return od - 2 * t;
      case ConduitKind.id:
        final d = _num(_directId);
        return d == null || d <= 0 ? null : d;
    }
  }

  String get _conduitText => switch (_conduit) {
    ConduitKind.tube => '튜브 ${_tube.label}',
    ConduitKind.pipe =>
      '배관 ${_pipe.a}(${_pipe.b}B) 외경 ${_fmt(_pipeOd(_pipe), 1)}mm'
          '${_num(_pipeWall) == null ? '' : ' × ${_fmt(_num(_pipeWall)!)}mm'}',
    ConduitKind.id => '내경 직접 입력',
  };

  /// 유체 상태. 입력이 모자라거나 범위 밖이면 null.
  FluidState? get _state {
    switch (_fluid) {
      case FluidKind.water:
        final t = _num(_waterT);
        return t == null ? null : waterState(t);
      case FluidKind.air:
      case FluidKind.n2:
        final p = _num(_gasP);
        final t = _num(_gasT);
        if (p == null || t == null) return null;
        return gasState(
          _fluid == FluidKind.air ? kAir : kN2,
          p * _pUnit.kpa,
          t,
        );
      case FluidKind.oil:
        final r = _num(_oilRho);
        final v = _num(_oilCst);
        if (r == null || v == null) return null;
        return oilState(r, v);
    }
  }

  /// 유체 입력이 없거나 범위 밖일 때 안내.
  String get _stateMissing => switch (_fluid) {
    FluidKind.water =>
      '물 온도를 ${_fmt(kWaterTable.first.$1, 0)}~${_fmt(kWaterTable.last.$1, 0)}°C로 넣으십시오',
    FluidKind.air || FluidKind.n2 =>
      '운전 압력과 온도(${_fmt(kGasMinC, 0)}~${_fmt(kGasMaxC, 0)}°C)를 넣으십시오',
    FluidKind.oil => '기름 밀도와 동점도를 넣으십시오',
  };

  /// 운전 상태 부피 유량(m³/s).
  double? _q(FluidState? s) {
    final v = _num(_flow);
    if (v == null || v <= 0) return null;
    return flowToM3s(v, _flowUnit, rho: s?.rho, rhoNormal: s?.rhoNormal);
  }

  List<FlowUnit> get _units => [
    FlowUnit.lpm,
    FlowUnit.m3h,
    FlowUnit.gpm,
    FlowUnit.kgh,
    if (_fluid.gas) FlowUnit.nm3h,
  ];

  List<VelocityGuide> _guidesFor(FluidKind k) => [
    for (final g in kVelocityGuides)
      if (g.fluids.contains(k.name)) g,
  ];

  /// 고른 용도의 권장 유속. 이 유체의 자료가 없으면(기름) null.
  VelocityGuide? get _guide {
    final list = _guidesFor(_fluid);
    if (list.isEmpty) return null;
    return list.firstWhere((g) => g.id == _service, orElse: () => list.first);
  }

  /// 유체를 바꾸면 그 유체의 첫 용도로(고른 용도가 그 유체에 없을 때만).
  void _fixService(FluidKind k) {
    final list = _guidesFor(k);
    if (list.isNotEmpty && !list.any((g) => g.id == _service)) {
      _service = list.first.id;
    }
  }

  void _setFluid(FluidKind k) => setState(() {
    _fluid = k;
    if (!k.gas && _flowUnit == FlowUnit.nm3h) _flowUnit = FlowUnit.m3h;
    _fixService(k);
  });

  // ─────────────── 화면 ───────────────

  @override
  Widget build(BuildContext context) => FieldViewTheme(
    child: Builder(
      builder: (context) => Scaffold(
        backgroundColor: fc.background,
        appBar: AppBar(
          backgroundColor: fc.surface,
          foregroundColor: fc.text,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            '유량 계산',
            style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
          ),
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: fc.brand,
            unselectedLabelColor: fc.textSub,
            indicatorColor: fc.brand,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
            tabs: const [
              Tab(key: Key('fl_tab_vel'), text: '유속·관 굵기'),
              Tab(key: Key('fl_tab_dp'), text: '압력손실'),
              Tab(key: Key('fl_tab_meter'), text: '차압 유량계'),
              Tab(key: Key('fl_tab_check'), text: '유량계 점검'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            controller: _tabs,
            children: [_velTab(), _lossTab(), _meterTab(), _meterCheckTab()],
          ),
        ),
      ),
    ),
  );

  Widget _page(List<Widget> children) => GestureDetector(
    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
    behavior: HitTestBehavior.translucent,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: children,
    ),
  );

  Widget _chips(String title, String guide, List<Widget> chips) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
            ),
          ),
          const SizedBox(width: 6),
          calcHelp(title, guide),
        ],
      ),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: chips),
      const SizedBox(height: 12),
    ],
  );

  Widget _note(String text, {Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.only(top: 10),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.45),
    ),
  );

  /// 두 탭(유속·압력손실)이 같이 쓰는 유량·유체·관 칸. [tab]은 키 앞머리.
  List<Widget> _conditionFields(String tab) => [
    _chips(
      '유체',
      '물: 온도에 따라 밀도·점도를 표(IAPWS, 1기압)에서 읽습니다.\n'
          '공기·질소: 운전 압력·온도로 밀도를 이상기체 식으로 계산합니다.\n'
          '기름: 밀도와 동점도를 직접 넣습니다. 제품 자료(TDS)에 있습니다.\n'
          '증기는 넣지 않았습니다.',
      [
        for (final k in FluidKind.values)
          calcChip('${tab}_fluid_${k.name}', k.label, _fluid == k, () {
            _setFluid(k);
          }),
      ],
    ),
    ..._fluidFields(tab),
    _chips(
      '유량 단위',
      'L/min·m³/h·GPM(US)은 운전 상태(관 속 압력·온도)의 부피 유량입니다. '
          'kg/h는 질량 유량으로, 밀도로 나누어 부피 유량을 구합니다. '
          'Nm³/h(기체)는 0°C, 101.325kPa 기준 부피 유량입니다. 압축기·유량계 명판의 기준 상태를 확인하십시오.',
      [
        for (final u in _units)
          calcChip('${tab}_fu_${u.name}', u.label, _flowUnit == u, () {
            setState(() => _flowUnit = u);
          }),
      ],
    ),
    calcField(
      '${tab}_flow',
      '유량 (${_flowUnit.label})',
      _flow,
      '흐르는 양입니다. 유량계 지시값, 펌프·압축기 정격, 설계 도서(P&ID·계산서)의 값을 넣습니다.',
    ),
    _chips(
      '관 종류',
      '튜브: 외경 × 두께로 부르는 계기용 튜브입니다(인치 1/8"~1", mm 6~25mm). 내경 = 외경 − 2 × 두께.\n'
          '배관: 호칭(A·B)으로 부르는 파이프입니다. 외경은 표에서 읽고 두께를 넣습니다.\n'
          '내경 직접: 내경을 알고 있을 때 넣습니다.',
      [
        calcChip('${tab}_cd_tube', '튜브', _conduit == ConduitKind.tube, () {
          setState(() => _conduit = ConduitKind.tube);
        }),
        calcChip('${tab}_cd_pipe', '배관', _conduit == ConduitKind.pipe, () {
          setState(() => _conduit = ConduitKind.pipe);
        }),
        calcChip('${tab}_cd_id', '내경 직접', _conduit == ConduitKind.id, () {
          setState(() => _conduit = ConduitKind.id);
        }),
      ],
    ),
    ..._conduitFields(tab),
  ];

  List<Widget> _fluidFields(String tab) => switch (_fluid) {
    FluidKind.water => [
      calcField(
        '${tab}_waterT',
        '물 온도 (°C)',
        _waterT,
        '관 속 물의 온도입니다. 온도계·DCS 값을 넣습니다. 온도가 오르면 점도가 줄어 압력손실이 조금 줄어듭니다. '
            '표는 1기압 값이며 ${_fmt(kWaterTable.first.$1, 0)}~${_fmt(kWaterTable.last.$1, 0)}°C까지입니다.',
      ),
    ],
    FluidKind.air || FluidKind.n2 => [
      _chips(
        '압력 단위',
        '운전 압력은 게이지 압력(대기압 = 0)으로 넣습니다. 절대 압력은 표준 대기압 101.325kPa를 더해 계산합니다.',
        [
          for (final u in GaugeUnit.values)
            calcChip('${tab}_pu_${u.name}', u.label, _pUnit == u, () {
              setState(() {
                final v = _num(_gasP);
                if (v != null) _gasP.text = _sig(v * _pUnit.kpa / u.kpa);
                _pUnit = u;
              });
            }),
        ],
      ),
      calcField(
        '${tab}_gasP',
        '운전 압력 (${_pUnit.label}, 게이지)',
        _gasP,
        '관 입구(공급 쪽) 압력입니다. 레귤레이터 2차 압력계·헤더 압력계 값을 넣습니다. '
            '압력이 높을수록 밀도가 커져 같은 질량을 보내도 유속이 느려집니다.',
      ),
      calcField(
        '${tab}_gasT',
        '기체 온도 (°C)',
        _gasT,
        '관 속 기체 온도입니다. 모르면 주위 온도를 넣으십시오.',
        signed: true,
      ),
    ],
    FluidKind.oil => [
      calcField(
        '${tab}_oilRho',
        '밀도 (kg/m³)',
        _oilRho,
        '운전 온도에서의 밀도입니다. 제품 자료(TDS)에 15°C 밀도가 있습니다. 비중이면 1000을 곱하십시오(비중 0.87 → 870).',
      ),
      calcField(
        '${tab}_oilCst',
        '동점도 (cSt = mm²/s)',
        _oilCst,
        '운전 온도에서의 동점도입니다. 제품 자료에 40°C·100°C 값이 있습니다(ISO VG 46이면 40°C에서 약 46cSt). '
            '온도가 내려가면 점도가 크게 오르므로 운전 온도 값을 넣으십시오.',
      ),
    ],
  };

  List<Widget> _conduitFields(String tab) => switch (_conduit) {
    ConduitKind.tube => [
      _chips(
        '튜브 단위',
        '인치 튜브(1/4" 등)와 mm 튜브(12mm 등)입니다. 튜브 표면이나 납품 서류에 외경 × 두께가 적혀 있습니다.',
        [
          calcChip('${tab}_ts_inch', '인치', _tubeSys == TubeSystem.inch, () {
            setState(() {
              _tubeSys = TubeSystem.inch;
              _tubeId = _tubeDefault;
            });
          }),
          calcChip('${tab}_ts_mm', 'mm', _tubeSys == TubeSystem.metric, () {
            setState(() {
              _tubeSys = TubeSystem.metric;
              _tubeId = _tubeDefault;
            });
          }),
        ],
      ),
      calcDropdown<String>(
        '${tab}_tube',
        '튜브 규격 (외경 × 두께)',
        _tube.id,
        [for (final t in tubeSizes(_tubeSys)) t.id],
        (id) {
          final t = tubeById(id)!;
          return '${t.label} (내경 ${_fmt(t.idMm)}mm)';
        },
        (id) => setState(() => _tubeId = id),
        '튜브 외경과 두께입니다. 내경은 공칭 치수로 계산합니다.',
      ),
    ],
    ConduitKind.pipe => [
      _chips(
        '외경 기준',
        'KS: KS D 3507(배관용 탄소강관, SPP) 외경입니다. '
            'ASME: B36.10M(NPS) 외경입니다. 15A는 KS 21.7mm, ASME 21.3mm처럼 조금 다릅니다. 도면·자재 명세의 기준을 따르십시오.',
        [
          calcChip('${tab}_od_ks', 'KS', _odStd == PipeOdStd.ks, () {
            setState(() => _odStd = PipeOdStd.ks);
          }),
          calcChip('${tab}_od_asme', 'ASME', _odStd == PipeOdStd.asme, () {
            setState(() => _odStd = PipeOdStd.asme);
          }),
        ],
      ),
      calcDropdown<String>(
        '${tab}_pipe',
        '배관 호칭',
        _pipe.a,
        [for (final p in kPipeSizes) p.a],
        (a) {
          final p = kPipeSizes.firstWhere((x) => x.a == a);
          return '${p.a} · ${p.b}B (외경 ${_fmt(_pipeOd(p), 1)}mm)';
        },
        (a) => setState(() => _pipeA = a),
        '호칭 지름입니다. 외경은 고른 외경 기준 표에서 읽습니다.',
      ),
      calcField(
        '${tab}_wall',
        '두께 (mm)',
        _pipeWall,
        '관 두께입니다. 배관 등급표(Line class)·자재 명세의 스케줄(Sch 40 등)에 맞는 두께를 '
            'KS D 3562·ASME B36.10M 표에서 찾아 넣으십시오. 관 표면 각인에도 있습니다.',
      ),
    ],
    ConduitKind.id => [
      calcField(
        '${tab}_id',
        '내경 (mm)',
        _directId,
        '관 안쪽 지름입니다. 외경 − 2 × 두께로 계산하거나 도면·자재 명세에서 찾습니다.',
      ),
    ],
  };

  // ─────────────── ① 유속·관 굵기 ───────────────

  Widget _velTab() {
    final s = _state;
    final id = _idMm;
    final q = _q(s);
    final guides = _guidesFor(_fluid);
    final g = _guide;
    Widget result;
    if (s == null) {
      result = calcResult(big: '—', caption: _stateMissing, lines: const []);
    } else if (q == null) {
      result = calcResult(big: '—', caption: '유량을 넣으십시오', lines: const []);
    } else if (id == null) {
      result = calcResult(
        big: '—',
        caption: _conduit == ConduitKind.pipe ? '두께를 넣으십시오' : '내경을 넣으십시오',
        lines: const [],
      );
    } else {
      final v = velocity(q, id);
      final re = reynolds(v, id, s);
      final regime = regimeOf(re);
      final over = g != null && v > g.max + 1e-12;
      final under = g != null && g.min != null && v < g.min! - 1e-12;
      result = calcResult(
        key: const Key('fl_vel_result'),
        big: '${_fmt(v)} m/s',
        caption: '유속 (내경 ${_fmt(id)}mm)',
        warn: over,
        lines: [
          '레이놀즈 수 Re = ${_int(re)}: ${regime.label}',
          if (g != null)
            '권장 유속(${g.label}) ${g.rangeText}: '
                '${over ? '초과' : (under ? '미만' : '이내')}',
          '유량: ${_flowAll(q, s)}',
          '밀도 ${_sig(s.rho)} kg/m³ · 점도 ${_sig(s.mu * 1000)} mPa·s',
          ?_idealGasWarn(s),
          if (g != null) ...[
            '최소 내경(${_fmt(g.max)} m/s 이하): '
                '${_fmt(minIdForVelocity(q, g.max))}mm',
            _smallestText(q, g),
          ],
        ],
      );
    }
    return _page([
      ..._conditionFields('fv'),
      if (g != null)
        _chips(
          '용도 (권장 유속)',
          '관 용도에 따라 권장 유속이 다릅니다. 펌프 흡입은 공동 현상(캐비테이션)을 막으려고 낮게 잡습니다. '
              '값과 출처는 결과 아래에 있습니다. 설계 기준서가 따로 있으면 그 값을 따르십시오.',
          [
            for (final x in guides)
              calcChip('fv_sv_${x.id}', x.label, x.id == g.id, () {
                setState(() => _service = x.id);
              }),
          ],
        ),
      const SizedBox(height: 4),
      result,
      _note(
        '${g == null ? '기름 권장 유속은 두 출처가 맞는 값을 찾지 못해 넣지 않았습니다.' : '권장 유속 출처: ${g.source}'}\n'
        'Re 2300 미만 층류, 4000 이상 난류, 그 사이는 천이 구간입니다. '
        '${_fluid.gas ? '기체 유속은 입구 압력 기준입니다. 압력이 내려가는 하류에서는 더 빨라집니다.' : ''}',
        key: const Key('fl_vel_note'),
      ),
    ]);
  }

  /// 절대 압력 100bar를 넘는 기체: 이상기체 밀도 오차 안내.
  String? _idealGasWarn(FluidState s) =>
      s.gas && s.pAbsKpa! > kIdealGasLimitKpa + 1e-9
      ? '절대 압력 100bar를 넘어 이상기체 밀도 오차가 커집니다(질소 20°C 200bar에서 약 5%).'
      : null;

  /// 유량을 다른 단위로(질량 유량 포함).
  String _flowAll(double q, FluidState s) => [
    for (final u in _units)
      if (u != _flowUnit)
        '${_sig(m3sToFlow(q, u, rho: s.rho, rhoNormal: s.rhoNormal)!)} ${u.label}',
  ].join(' · ');

  /// 권장 유속(최대)을 만족하는 가장 작은 규격.
  String _smallestText(double q, VelocityGuide g) {
    switch (_conduit) {
      case ConduitKind.tube:
        final list = tubeSizes(_tubeSys);
        for (final t in list) {
          if (velocity(q, t.idMm) <= g.max + 1e-12) {
            final walls = [
              for (final x in list)
                if (x.odText == t.odText &&
                    velocity(q, x.idMm) <= g.max + 1e-12)
                  x,
            ];
            final w = walls
                .map(
                  (x) => x.inch
                      ? '${x.wall.toStringAsFixed(3)}"'
                      : '${_fmt(x.wall)}mm',
                )
                .join('·');
            final od = t.inch ? '${t.odText}"' : '${t.odText}mm';
            return '권장 유속을 만족하는 가장 작은 튜브: $od (두께 $w)';
          }
        }
        return '목록의 튜브(${list.last.inch ? '${list.last.odText}"' : '${list.last.odText}mm'})로는 권장 유속을 만족하지 않습니다. 배관을 검토하십시오.';
      case ConduitKind.pipe:
        final t = _num(_pipeWall);
        if (t == null || t <= 0) return '두께를 넣으면 가장 작은 배관 호칭을 찾습니다.';
        for (final p in kPipeSizes) {
          final id = _pipeOd(p) - 2 * t;
          if (id > 0 && velocity(q, id) <= g.max + 1e-12) {
            return '권장 유속을 만족하는 가장 작은 배관: ${p.a}(${p.b}B), '
                '두께를 ${_fmt(t)}mm로 같게 보았습니다';
          }
        }
        return '표의 배관(500A)으로는 권장 유속을 만족하지 않습니다.';
      case ConduitKind.id:
        return '내경을 직접 넣어 규격 목록은 찾지 않습니다.';
    }
  }

  // ─────────────── ② 압력손실 ───────────────

  /// 3-K 식의 호칭 지름(인치): 배관은 호칭, 튜브·내경 입력은 내경.
  double _dnInch(double idMm) {
    if (_conduit == ConduitKind.pipe) {
      final n = nominalInch(_pipe.b);
      if (n != null) return n;
    }
    return idMm / 25.4;
  }

  RoughData get _rough {
    final id = _roughId ?? (_conduit == ConduitKind.pipe ? 'steel' : 'drawn');
    return kRoughness.firstWhere((r) => r.id == id);
  }

  double? get _roughValue {
    final r = _rough;
    if (r.mm != null) return r.mm;
    final v = _num(_roughMm);
    return v == null || v < 0 ? null : v;
  }

  String _dpAll(double kpa) =>
      '${_sig(kpa)} kPa · ${_sig(kpa / 100)} bar · ${_sig(kpa / kPsiKpaFlow)} psi';

  Widget _lossTab() {
    final s = _state;
    final id = _idMm;
    final q = _q(s);
    final len = _num(_length);
    final rough = _roughValue;
    final dz = _num(_dz) ?? 0;
    final extraK = _num(_extraK) ?? 0;
    Widget result;
    if (s == null) {
      result = calcResult(big: '—', caption: _stateMissing, lines: const []);
    } else if (q == null) {
      result = calcResult(big: '—', caption: '유량을 넣으십시오', lines: const []);
    } else if (id == null) {
      result = calcResult(
        big: '—',
        caption: _conduit == ConduitKind.pipe ? '두께를 넣으십시오' : '내경을 넣으십시오',
        lines: const [],
      );
    } else if (len == null || len < 0) {
      result = calcResult(big: '—', caption: '직관 길이를 넣으십시오', lines: const []);
    } else if (rough == null) {
      result = calcResult(big: '—', caption: '거칠기를 넣으십시오', lines: const []);
    } else {
      final r = pressureDrop(
        qM3s: q,
        idMm: id,
        fluid: s,
        lengthM: len,
        roughMm: rough,
        fittings: [for (final f in kFittings) (f, _fitCount[f.id] ?? 0)],
        dnInch: _dnInch(id),
        extraK: extraK,
        dzM: dz,
      );
      final check = s.gas ? gasDropCheck(r.totalKpa, s.pAbsKpa!) : null;
      final pct = s.gas ? r.totalKpa / s.pAbsKpa! * 100 : 0.0;
      result = calcResult(
        key: const Key('fl_dp_result'),
        big: '${_sig(r.totalKpa)} kPa',
        caption: '전체 압력손실 (직관 + 피팅 + 높이)',
        warn: check == GasDropCheck.invalid,
        lines: [
          '다른 단위: ${_sig(r.totalKpa / 100)} bar · ${_sig(r.totalKpa / kPsiKpaFlow)} psi',
          '$_conduitText (내경 ${_fmt(id)}mm)',
          '직관 ${_fmt(len, 1)}m: ${_dpAll(r.straightKpa)}',
          '직관 100m당: ${_dpAll(r.per100mKpa)}',
          '피팅·밸브(K 합 ${_fmt(r.sumK)}): ${_dpAll(r.fittingKpa)}',
          '높이 차 ${_fmt(dz, 1)}m: ${_dpAll(r.elevKpa)}',
          '유속 ${_fmt(r.v)} m/s · Re ${_int(r.re)}: ${r.regime.label}',
          r.regime == FlowRegime.laminar
              ? '마찰 계수 f = 64/Re = ${_fmt(r.f, 4)}'
              : '마찰 계수 f = ${_fmt(r.f, 4)} (Colebrook–White 반복 계산, ε = ${_sig(rough)}mm)',
          if (r.regime == FlowRegime.transition)
            '천이 구간은 마찰 계수가 불안정합니다. 난류 식으로 계산한 값이라 실제는 이보다 작을 수 있습니다.',
          ?_idealGasWarn(s),
          if (check != null) ...[
            '입구 절대 압력 ${_sig(s.pAbsKpa!)} kPa 대비 ${_fmt(pct, 1)}%',
            switch (check) {
              GasDropCheck.ok =>
                '10% 미만이라 밀도를 일정하게 보고 계산한 값을 쓸 수 있습니다(Crane TP-410).',
              GasDropCheck.useAverage =>
                '10~40%입니다. 입구·출구 평균 밀도로 다시 계산해야 정확합니다(Crane TP-410). 이 값은 입구 밀도 기준입니다.',
              GasDropCheck.invalid =>
                '40%를 넘어 이 계산(밀도 일정)은 맞지 않습니다. 압축성 유동 계산을 하십시오(Crane TP-410).',
            },
            if (check != GasDropCheck.invalid)
              '출구 압력(게이지): 약 ${_sig((s.pAbsKpa! - r.totalKpa - kAtmKpa) / _pUnit.kpa)} ${_pUnit.label}',
          ],
        ],
      );
    }
    return _page([
      ..._conditionFields('dp'),
      calcField(
        'dp_len',
        '직관 길이 (m)',
        _length,
        '관의 전체 길이입니다. 아이소 도면·배치도에서 구간 길이를 더합니다. 피팅은 아래에서 따로 넣습니다.',
      ),
      _chips(
        '관 안쪽 거칠기',
        '관 안쪽 면의 거칠기(ε)입니다. 비우면 튜브는 인발 튜브, 배관은 상용 강관 값을 씁니다.\n'
            '${[for (final r in kRoughness)
              if (r.mm != null) '${r.label}: ${_sig(r.mm!)}mm'].join('\n')}\n'
            '출처: $kRoughSource',
        [
          for (final r in kRoughness)
            calcChip('dp_rough_${r.id}', r.label, _rough.id == r.id, () {
              setState(() => _roughId = r.id);
            }),
        ],
      ),
      if (_rough.mm == null)
        calcField(
          'dp_rough_mm',
          '거칠기 ε (mm)',
          _roughMm,
          '관 제조사 자료의 절대 거칠기를 mm로 넣습니다.',
        ),
      _fittingCard(),
      calcField(
        'dp_extraK',
        '기타 K 합 (선택)',
        _extraK,
        '목록에 없는 부품(스트레이너·계기 밸브 등)의 저항 계수 K를 더해 넣습니다. 제조사 자료의 K를 쓰십시오. '
            'Cv만 있으면 K = 0.00214 × d⁴ / Cv² (d는 내경 mm)로 바꿀 수 있습니다.',
      ),
      calcField(
        'dp_dz',
        '높이 차 (m, 출구가 높으면 +)',
        _dz,
        '입구보다 출구가 높으면 양수, 낮으면 음수로 넣습니다. 올라가는 만큼 ρgh의 압력이 더 필요합니다.',
        signed: true,
      ),
      const SizedBox(height: 4),
      result,
      _note(
        '피팅 K = K1/Re + Ki × (1 + Kd/Dn^0.3) (3-K 식). Dn은 배관이면 호칭(인치), 튜브·내경 입력이면 내경(인치)입니다. '
        '튜브 이음(압축 피팅)은 공개된 K가 없어 같은 모양의 나사 피팅 값으로 계산한 대략의 값입니다.\n'
        'K 출처: $kFittingSource',
        key: const Key('fl_dp_note'),
      ),
    ]);
  }

  Widget _fittingCard() {
    final id = _idMm;
    final s = _state;
    final q = _q(s);
    final re = id == null || s == null || q == null
        ? null
        : reynolds(velocity(q, id), id, s);
    return Container(
      key: const Key('dp_fittings'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          calcLabel(
            '피팅·밸브 개수',
            '관로에 있는 엘보·티·밸브 개수를 넣습니다. 아이소 도면의 자재 목록(BOM)에서 확인합니다. '
                '괄호 안은 지금 유량·관에서의 K입니다. 밸브는 완전히 열린 상태 값입니다. '
                '관 입구는 탱크에서 관으로 들어가는 곳, 관 출구는 관에서 탱크로 나가는 곳입니다.',
          ),
          for (final f in kFittings)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${f.label}${re == null ? '' : ' (K ${_fmt(f.k(re, _dnInch(id!)))})'}',
                      style: TextStyle(fontSize: 14, color: fc.text),
                    ),
                  ),
                  _stepBtn('dp_fit_${f.id}_minus', Icons.remove_rounded, () {
                    final n = _fitCount[f.id] ?? 0;
                    if (n > 0) setState(() => _fitCount[f.id] = n - 1);
                  }),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${_fitCount[f.id] ?? 0}',
                      key: Key('dp_fit_${f.id}_n'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: fc.text,
                      ),
                    ),
                  ),
                  _stepBtn('dp_fit_${f.id}_plus', Icons.add_rounded, () {
                    final n = _fitCount[f.id] ?? 0;
                    if (n < 999) setState(() => _fitCount[f.id] = n + 1);
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepBtn(String key, IconData icon, VoidCallback onTap) => InkWell(
    key: Key(key),
    borderRadius: BorderRadius.circular(18),
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(icon, size: 20, color: fc.brand),
    ),
  );
}
