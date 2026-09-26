// 압력 시험 계산기(홈 "현장 작업" → 압력 시험 계산기). ASME B31.3(공정 배관)·B31.1(동력 배관),
// 수압·공압. 탭: 시험 압력(절차·압력계·최고점 높이까지) → 압력 강하(온도 보정·누설률·허용값 판정,
// 수압은 물 온도 영향) → 공압 안전거리(ASME PCC-2 저장 에너지·출입 통제 거리·질소 용기) → 에어 누설
// → 시험 기록(유지시간 타이머·알림, 측정 기록, 판정, 기록 저장·기록서 PDF: pressure_record_tab.dart).
// 칸마다 "?" 안내, 결과에 조항 번호. 계산은 pressure_calc.dart. 최종은 해당 규격 원문·절차서로 확인.
// 시험 대상은 튜브(기본, 계기용 정밀 튜브: tube_rating.dart 허용 사용압력)와 배관. 튜브 규격은 공압 안전거리 체적·
// 수압 온도 영향·시험 기록(기록서)에도 쓴다.
// 넣은 값은 'pressure_test_draft_v1'에 저장해 다음에 열 때 되살린다.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import 'hold_alarm.dart';
import 'pressure_calc.dart';
import 'pressure_units.dart';
import 'test_record.dart';
import 'test_record_pdf.dart';
import 'test_record_sheet.dart';
import 'test_records_page.dart';
import 'tube_rating.dart';

part 'pressure_record_tab.dart';

/// 공압 안전거리 탭에서 더한 튜브 구간(규격·길이).
class _TubeSeg {
  String id;
  final TextEditingController len;
  _TubeSeg(this.id, [String text = ''])
    : len = TextEditingController(text: text);
}

String _fmt(double v, [int d = 2]) {
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  if (s == '-0') s = '0';
  return s;
}

/// 단위를 바꿀 때 칸에 다시 쓰는 값: 유효 숫자 5자리쯤(소수 2~6자리).
String _fmtSig(double v) {
  if (v == 0 || !v.isFinite) return _fmt(v);
  final mag = (math.log(v.abs()) / math.ln10).floor();
  return _fmt(v, (4 - mag).clamp(2, 6));
}

class PressureTestPage extends StatefulWidget {
  /// 유지시간 완료 알림(시험에서 가짜로 바꿔 넣는다). 없으면 앱 알림 플러그인.
  final HoldAlarm? holdAlarm;

  /// 지금 시각(시험에서 바꿔 넣는다). 없으면 DateTime.now.
  final DateTime Function()? now;

  const PressureTestPage({super.key, this.holdAlarm, this.now});

  @override
  State<PressureTestPage> createState() => _PressureTestPageState();
}

class _PressureTestPageState extends State<PressureTestPage>
    with
        SingleTickerProviderStateMixin,
        CalcFormParts<PressureTestPage>,
        WidgetsBindingObserver,
        _PtRecordTab {
  static const _draftKey = 'pressure_test_draft_v1';

  late final TabController _tabs = TabController(length: 5, vsync: this);

  PUnit _unit = PUnit.bar;

  // 시험 대상: 튜브(기본, 계기용 정밀 튜브) / 배관(파이프). 튜브 규격은 다른 탭(체적·수압 온도 영향·기록)도 쓴다.
  bool _tube = true;
  TubeMaterial _tubeMat = TubeMaterial.ss316;
  TubeSystem _tubeSys = TubeSystem.inch;
  String _tubeId = kTubeDefaultInch;
  final _tubeTemp = TextEditingController(); // 설계 온도(°C). 비우면 38°C 이하
  final _tubeLen = TextEditingController(); // 공압 안전거리: 구간 1(시험 압력 탭 규격) 길이(m)
  List<_TubeSeg> _segs = []; // 공압 안전거리: 더한 구간
  bool _restrained = false; // 압력 강하(수압): 매설·축 구속

  TubeSize get _tubeSize =>
      tubeById(_tubeId) ??
      tubeById(
        _tubeSys == TubeSystem.inch ? kTubeDefaultInch : kTubeDefaultMetric,
      )!;

  String get _tubeDefault =>
      _tubeSys == TubeSystem.inch ? kTubeDefaultInch : kTubeDefaultMetric;

  /// 기록·기록서에 적는 튜브 규격 글.
  String get _tubeSpec => tubeSpecText(_tubeSize, _tubeMat);

  /// 튜브 재질 → 수압 온도 영향 계산 재질.
  PipeMaterial get _tubePipeMat => _tubeMat == TubeMaterial.ss316
      ? PipeMaterial.stainless
      : PipeMaterial.carbon;

  /// 시험 압력 탭의 튜브 허용 사용압력(표 범위 밖이면 null).
  TubeRating? get _tubeRating =>
      tubeRating(size: _tubeSize, material: _tubeMat, designC: _num(_tubeTemp));

  // ① 시험 압력
  PipingCode _code = PipingCode.b313;
  TestMedium _medium = TestMedium.hydro;
  final _design = TextEditingController();
  final _ratio = TextEditingController(text: '1');
  final _actual = TextEditingController();
  final _head = TextEditingController();

  // ② 압력 강하
  TestMedium _decayMedium = TestMedium.pneumatic;
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  final _allow = TextEditingController();
  final _t1 = TextEditingController(text: '20');
  final _t2 = TextEditingController(text: '20');
  final _minutes = TextEditingController(text: '60');
  final _volume = TextEditingController();
  final _waterT = TextEditingController(text: '20');
  final _dT = TextEditingController(text: '1');
  final _od = TextEditingController(text: '60.5');
  final _wall = TextEditingController(text: '3.9');
  PipeMaterial _mat = PipeMaterial.carbon;

  // ③ 공압 안전거리
  TestGas _gas = TestGas.airN2;
  final _sePt = TextEditingController();
  final _seId = TextEditingController();
  final _seLen = TextEditingController();
  final _seVol = TextEditingController();

  // ④ 에어 누설
  final _hole = TextEditingController(text: '3');
  final _supply = TextEditingController(text: '7');
  bool _sharp = false;
  final _hours = TextEditingController(text: '8760');
  final _price = TextEditingController();

  /// 단위를 바꿔 다시 쓴 칸: (쓴 글, 정확한 kPa). 글이 그대로면 kPa를 그대로 쓴다(반올림 누적 방지).
  final Map<TextEditingController, (String, double)> _exact = {};

  /// 단위가 바뀌면 같이 환산하는 압력 칸(모든 탭).
  List<TextEditingController> get _pressureFields => [
    _design,
    _actual,
    _p1,
    _p2,
    _allow,
    _sePt,
    _supply,
    _rAllow,
  ];

  Map<String, TextEditingController> get _fields => {
    'design': _design,
    'ratio': _ratio,
    'actual': _actual,
    'head': _head,
    'p1': _p1,
    'p2': _p2,
    'allow': _allow,
    't1': _t1,
    't2': _t2,
    'minutes': _minutes,
    'volume': _volume,
    'waterT': _waterT,
    'dT': _dT,
    'od': _od,
    'wall': _wall,
    'sePt': _sePt,
    'seId': _seId,
    'seLen': _seLen,
    'seVol': _seVol,
    'hole': _hole,
    'supply': _supply,
    'hours': _hours,
    'price': _price,
    'tubeTemp': _tubeTemp,
    'tubeLen': _tubeLen,
    ..._recordFields,
  };

  // ─── 임시 저장 ───
  bool _loaded = false; // 저장된 값을 읽기 전에는 저장하지 않는다
  bool _touched = false; // 읽기 전에 사용자가 이미 고쳤으면 되살리지 않는다
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recordInit();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    var restored = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      final editing = raw == null ? null : await _draftEditing(raw);
      if (raw != null && mounted && !_touched) {
        super.setState(() {
          _applyDraft(raw);
          _rEditing = editing;
        });
        restored = true;
      }
    } catch (_) {
      // 읽지 못하면 기본값으로 시작한다.
    } finally {
      _loaded = true;
    }
    // 진행 중인 시험이면 완료 알림을 다시 예약한다(같은 번호라 한 번만 울린다).
    if (restored && mounted && _rRunning) await _syncAlarm();
  }

  void _applyDraft(String raw) {
    final m = jsonDecode(raw);
    if (m is! Map) return;
    T pick<T extends Enum>(List<T> values, Object? name, T now) =>
        values.firstWhere((v) => v.name == name, orElse: () => now);
    _unit = pick(PUnit.values, m['unit'], _unit);
    _code = pick(PipingCode.values, m['code'], _code);
    _medium = pick(TestMedium.values, m['medium'], _medium);
    _decayMedium = pick(TestMedium.values, m['decayMedium'], _decayMedium);
    _mat = pick(PipeMaterial.values, m['mat'], _mat);
    _gas = pick(TestGas.values, m['gas'], _gas);
    if (m['sharp'] is bool) _sharp = m['sharp'] as bool;
    // 튜브·배관을 적지 않은 이전 임시 저장은 배관 기준으로 넣은 값이라 배관으로 되살린다.
    _tube = m['tube'] is bool ? m['tube'] as bool : false;
    _tubeMat = pick(TubeMaterial.values, m['tubeMat'], _tubeMat);
    _tubeSys = pick(TubeSystem.values, m['tubeSys'], _tubeSys);
    final t = tubeById(m['tubeId']?.toString());
    _tubeId = t != null && t.system == _tubeSys ? t.id : _tubeDefault;
    if (m['restrained'] is bool) _restrained = m['restrained'] as bool;
    final segs = m['segs'];
    if (segs is List) {
      for (final s in _segs) {
        s.len.dispose();
      }
      _segs = [
        for (final s in segs)
          if (s is Map)
            _TubeSeg(
              tubeById(s['id']?.toString())?.system == _tubeSys
                  ? s['id'].toString()
                  : _tubeDefault,
              s['len'] is String ? s['len'] as String : '',
            ),
      ];
    }
    final f = m['fields'];
    if (f is Map) {
      for (final e in _fields.entries) {
        final v = f[e.key];
        if (v is String) e.value.text = v;
      }
    }
    _applyRecordDraft(m['record']);
  }

  String _draftJson() => jsonEncode({
    'unit': _unit.name,
    'code': _code.name,
    'medium': _medium.name,
    'decayMedium': _decayMedium.name,
    'mat': _mat.name,
    'gas': _gas.name,
    'sharp': _sharp,
    'tube': _tube,
    'tubeMat': _tubeMat.name,
    'tubeSys': _tubeSys.name,
    'tubeId': _tubeId,
    'restrained': _restrained,
    'segs': [
      for (final s in _segs) {'id': s.id, 'len': s.len.text},
    ],
    'fields': {for (final e in _fields.entries) e.key: e.value.text},
    'record': _recordDraftJson(),
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
    // 폰 설정(정확한 알람 허용)에서 돌아오면 다시 확인하고, 켜졌으면 알림을 다시 예약한다.
    if (state == AppLifecycleState.resumed) _recordResumed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveNow(); // 칸을 버리기 전에 글을 읽어 둔다
    _recordDispose();
    _tabs.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    for (final s in _segs) {
      s.len.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', ''));

  double? _kpaIn(TextEditingController c, PUnit unit) {
    final e = _exact[c];
    if (e != null && e.$1 == c.text) return e.$2;
    final v = _num(c);
    return v == null ? null : v * unit.kpa;
  }

  /// 화면 단위 → kPa.
  double? _kpa(TextEditingController c) => _kpaIn(c, _unit);

  /// 칸에 kPa 값을 화면 단위로 쓴다.
  void _putKpa(TextEditingController c, double kpa) {
    final t = _fmtSig(kpa / _unit.kpa);
    c.text = t;
    _exact[c] = (t, kpa);
  }

  /// 단위를 바꾸면 모든 탭에 넣어 둔 압력을 새 단위로 환산해 뜻이 바뀌지 않게 한다.
  void _setUnit(PUnit u) {
    if (u == _unit) return;
    setState(() {
      final values = {for (final c in _pressureFields) c: _kpaIn(c, _unit)};
      _unit = u;
      for (final e in values.entries) {
        if (e.value != null) _putKpa(e.key, e.value!);
      }
    });
  }

  String _p(double kpa) => '${_fmt(kpa / _unit.kpa)} ${_unit.label}';
  String _pAll(double kpa) => [
    for (final u in PUnit.values)
      if (u != _unit) '${_fmt(kpa / u.kpa)} ${u.label}',
  ].join(' · ');

  /// 압력 변화: 내려가면 "X bar", 올라가면 "X bar 상승".
  String _drop(double kpa) {
    final shown = _fmt(kpa.abs() / _unit.kpa);
    return kpa < 0 && shown != '0'
        ? '$shown ${_unit.label} 상승'
        : '$shown ${_unit.label}';
  }

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
            '압력 시험 계산기',
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
              Tab(key: Key('pt_tab_plan'), text: '시험 압력'),
              Tab(key: Key('pt_tab_decay'), text: '압력 강하'),
              Tab(key: Key('pt_tab_energy'), text: '공압 안전거리'),
              Tab(key: Key('pt_tab_leak'), text: '에어 누설'),
              Tab(key: Key('pt_tab_record'), text: '시험 기록'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            controller: _tabs,
            children: [
              _planTab(),
              _decayTab(),
              _energyTab(),
              _leakTab(),
              _recordTab(),
            ],
          ),
        ),
      ),
    ),
  );

  /// "시험 압력" 탭 값으로 정한 시험압력·절차(설계압력이 없으면 null). 시험 기록 탭이 쓴다.
  TestPlan? get _currentPlan {
    final d = _kpa(_design);
    if (d == null || d <= 0) return null;
    return testPlan(
      code: _code,
      medium: _medium,
      designKpa: d,
      stressRatio: _num(_ratio) ?? 1,
      actualKpa: _kpa(_actual),
    );
  }

  /// 저장한 압력시험 기록을 불러올 때 "시험 압력" 탭 값(규격·시험 종류·단위·설계압력·시험압력)을 되살린다.
  /// 단위가 바뀌면 다른 탭에 넣어 둔 압력도 새 단위로 환산해 뜻이 바뀌지 않게 한다.
  void _loadPlanFrom(PtRecord r) {
    final values = {for (final c in _pressureFields) c: _kpaIn(c, _unit)};
    _unit = r.unit;
    for (final e in values.entries) {
      if (e.value != null) _putKpa(e.key, e.value!);
    }
    _code = r.code;
    _medium = r.medium;
    // 튜브로 저장한 기록이면 튜브 재질·규격까지, 아니면(이전 기록·배관) 배관으로.
    final t = tubeById(r.tubeId);
    _tube = t != null;
    if (t != null) {
      _tubeSys = t.system;
      _tubeId = t.id;
      _tubeMat = TubeMaterial.values.firstWhere(
        (m) => m.name == r.tubeMat,
        orElse: () => _tubeMat,
      );
      for (final s in _segs) {
        if (tubeById(s.id)?.system != _tubeSys) s.id = _tubeDefault;
      }
    }
    if (r.designKpa == null) {
      _design.clear();
    } else {
      _putKpa(_design, r.designKpa!);
    }
    if (r.testKpa == null) {
      _actual.clear();
    } else {
      _putKpa(_actual, r.testKpa!);
    }
  }

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
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
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

  Widget _unitChips() => _chips(
    '압력 단위',
    '압력계에 적힌 단위를 고르십시오. 모든 압력은 게이지 압력(대기압 = 0)으로 넣습니다. '
        '단위를 바꾸면 모든 탭에 넣어 둔 압력도 새 단위로 환산됩니다.',
    [
      for (final u in PUnit.values)
        calcChip('pt_u_${u.name}', u.label, _unit == u, () => _setUnit(u)),
    ],
  );

  // ① 시험 압력
  Widget _planTab() {
    final d = _kpa(_design);
    final ratio = _num(_ratio) ?? 1;
    final actual = _kpa(_actual);
    final actualGiven = actual != null && actual > 0;
    final plan = d == null || d <= 0
        ? null
        : testPlan(
            code: _code,
            medium: _medium,
            designKpa: d,
            stressRatio: ratio,
            actualKpa: actual,
          );
    final inRange = plan?.actualInRange(actualGiven ? actual : null);
    final hydro = _medium == TestMedium.hydro;
    final h = hydro ? _num(_head) : null;
    final headKpa = h != null && h > 0 ? waterHeadKpa(h) : null;
    final highOk = plan == null || headKpa == null
        ? null
        : plan.usedKpa - headKpa >= plan.minKpa - 1e-9;
    return _page([
      _chips(
        '시험 대상',
        '튜브: 외경으로 부르는 계기용 정밀 튜브(인치 1/8"~1", mm 6~25mm)입니다. '
            '규격을 고르면 허용 사용압력과 시험압력 한도를 같이 확인합니다. '
            '배관: 호칭 지름·스케줄로 부르는 파이프입니다. 시험압력 계산은 둘이 같습니다.',
        [
          calcChip('pt_kind_tube', '튜브', _tube, () {
            setState(() => _tube = true);
          }),
          calcChip('pt_kind_pipe', '배관', !_tube, () {
            setState(() => _tube = false);
          }),
        ],
      ),
      _chips(
        '규격',
        'B31.3: 공정(플랜트) 배관. B31.1: 동력(발전소) 배관으로 보일러·증기·급수 계통 등입니다. '
            '어느 것을 따르는지는 설계 도서·배관 등급표(Line class)에 적혀 있습니다.',
        [
          calcChip('pt_b313', 'B31.3 공정 배관', _code == PipingCode.b313, () {
            setState(() => _code = PipingCode.b313);
          }),
          calcChip('pt_b311', 'B31.1 동력 배관', _code == PipingCode.b311, () {
            setState(() => _code = PipingCode.b311);
          }),
        ],
      ),
      _chips(
        '시험 종류',
        '두 규격 모두 수압이 기본입니다. 공압은 수압이 어려울 때 발주처가 정하거나 허락할 때만 합니다.',
        [
          calcChip('pt_hydro', '수압', hydro, () {
            setState(() => _medium = TestMedium.hydro);
          }),
          calcChip('pt_pneu', '공압', !hydro, () {
            setState(() => _medium = TestMedium.pneumatic);
          }),
        ],
      ),
      if (_tube) ..._tubeInputs(),
      _unitChips(),
      calcField(
        'pt_design',
        '설계압력 (${_unit.label})',
        _design,
        '배관 등급표·P&ID·아이소 도면에 적힌 설계압력(Design Pressure, 게이지)입니다. 운전 압력이 아닙니다.',
      ),
      if (_code == PipingCode.b313 && hydro)
        calcField(
          'pt_ratio',
          'ST/S (모르면 1)',
          _ratio,
          '설계 온도가 시험 온도보다 높을 때: 시험 온도에서의 허용 응력(ST) ÷ 설계 온도에서의 허용 응력(S). '
              'B31.3 부록 A 표 A-1에서 봅니다. 재질이 여럿이면 가장 작은 값을 씁니다. 1보다 작으면 1로 계산합니다.',
        ),
      calcField(
        'pt_actual',
        '실제 시험압력 (${_unit.label}, 선택)',
        _actual,
        '실제로 올릴 시험압력입니다. 입력하면 안전밸브 설정압력과 예비 점검 압력을 이 압력으로 계산합니다. '
            '비우면 최소 시험압력으로 계산합니다.',
      ),
      if (hydro)
        calcField(
          'pt_head',
          '압력계 위 최고점 높이 (m, 선택)',
          _head,
          '압력계보다 가장 높은 곳이 몇 m 위에 있는지 넣습니다. 압력계는 보통 낮은 곳에 둡니다. '
              '물은 1m 높아질 때마다 압력이 9.81kPa씩 낮아집니다. '
              '최고점에서도 최소 시험압력 이상이어야 하므로, 압력계에서 올려야 할 압력을 계산합니다.',
        ),
      const SizedBox(height: 12),
      if (plan == null)
        calcResult(big: '—', caption: '설계압력을 넣으십시오', lines: const [])
      else ...[
        calcResult(
          key: const Key('pt_plan_result'),
          big: plan.maxKpa == null
              ? '${_p(plan.minKpa)} 이상'
              : '${_fmt(plan.minKpa / _unit.kpa)} ~ ${_p(plan.maxKpa!)}',
          caption:
              '${_code == PipingCode.b313 ? 'B31.3' : 'B31.1'} ${hydro ? '수압' : '공압'} 시험압력',
          warn: inRange == false || (actualGiven && highOk == false),
          lines: [
            if (inRange == true) '실제 시험압력 ${_p(plan.usedKpa)}: 범위 이내',
            if (inRange == false)
              plan.usedKpa < plan.minKpa
                  ? '실제 시험압력 ${_p(plan.usedKpa)}: 최소 시험압력 미만'
                  : '실제 시험압력 ${_p(plan.usedKpa)}: 최대 시험압력 초과',
            '다른 단위: ${_pAll(plan.minKpa)}',
            '유지시간: ${_fmt(plan.holdMin, 0)}분 이상',
            if (plan.prelimKpa != null)
              plan.prelimOptional
                  ? '예비 점검(선택): ${_p(plan.prelimKpa!)} 이하'
                  : '예비 점검: ${_p(plan.prelimKpa!)}',
            if (plan.stepKpa.isNotEmpty)
              '단계 압력(½PT 뒤 PT/10씩): ${plan.stepKpa.map((k) => _fmt(k / _unit.kpa)).join(' → ')} ${_unit.label}',
            if (plan.examKpa != null) '누설 확인 압력: ${_p(plan.examKpa!)}',
            if (plan.reliefMaxKpa != null)
              '안전밸브 설정압력: ${_p(plan.reliefMaxKpa!)} 이하 (시험압력 ${_p(plan.usedKpa)} 기준)',
            if (plan.reliefRecKpa != null)
              '안전밸브 권장 설정압력: ${_p(plan.reliefRecKpa!)} (시험압력 ${_p(plan.usedKpa)}의 1⅓배, '
                  '137.1.4·137.4.5 한도를 넘지 않는 범위에서)',
            if (plan.reliefCapKpa != null)
              '안전밸브 설정압력: ${_p(plan.reliefCapKpa!)}(최대 시험압력 1.5P) 이하, 격리하지 않은 기기 한도 이내 (137.2.6)',
            if (headKpa != null) ...[
              '최고점 압력: ${_p(plan.usedKpa - headKpa)} (물 높이 ${_fmt(h!, 1)}m = ${_p(headKpa)})',
              if (!actualGiven)
                '최고점까지 최소 시험압력이 되려면 압력계에서 ${_p(plan.minKpa + headKpa)} 이상이어야 합니다.'
              else if (highOk == true)
                '최고점 압력이 최소 시험압력 이상입니다.'
              else
                '최고점 압력이 최소 시험압력 미만입니다. 압력계에서 ${_p(plan.minKpa + headKpa)} 이상으로 올리십시오.',
            ],
          ],
        ),
        if (_tube) ...[const SizedBox(height: 12), ..._tubeResult(plan, d)],
        const SizedBox(height: 12),
        _gaugeCard(plan.usedKpa),
        const SizedBox(height: 12),
        _listCard('pt_steps', '절차', plan.steps, numbered: true),
        const SizedBox(height: 12),
        _listCard('pt_notes', '주의 사항', plan.notes),
      ],
      if (_tube && plan == null) ...[
        const SizedBox(height: 12),
        ..._tubeResult(null, null),
      ],
      if (_tube) ...[const SizedBox(height: 12), _tubeNotes()],
    ]);
  }

  // ── 튜브 ──

  List<Widget> _tubeInputs() {
    final sizes = tubeSizes(_tubeSys);
    return [
      _chips(
        '튜브 재질',
        'SS316: ASTM A269·A213 이음매 없는 스테인리스 튜브입니다. '
            '탄소강: ASTM A179 이음매 없는 냉간 인발 튜브로, 최소 두께로 주문하는 관입니다.',
        [
          for (final m in TubeMaterial.values)
            calcChip('pt_tm_${m.name}', m.label, _tubeMat == m, () {
              setState(() => _tubeMat = m);
            }),
        ],
      ),
      _chips('치수 단위', '인치 튜브(1/8"~1")와 mm 튜브(6~25mm) 목록을 바꿉니다.', [
        calcChip(
          'pt_ts_inch',
          '인치',
          _tubeSys == TubeSystem.inch,
          () => _setTubeSys(TubeSystem.inch),
        ),
        calcChip(
          'pt_ts_mm',
          'mm',
          _tubeSys == TubeSystem.metric,
          () => _setTubeSys(TubeSystem.metric),
        ),
      ]),
      calcDropdown<String>(
        'pt_tube_size',
        '튜브 규격 (외경 × 두께)',
        sizes.any((t) => t.id == _tubeId) ? _tubeId : _tubeDefault,
        [for (final t in sizes) t.id],
        (id) => tubeById(id)!.label,
        (v) => setState(() => _tubeId = v),
        '허용 사용압력은 B31.3 304.1.2 식으로 계산한 값과 제조사 값(Swagelok MS-01-107) 중 작은 것입니다. '
            '계산은 최대 외경(공칭 + 0.13mm)과 최소 두께로 합니다. '
            'SS316은 A269 허용차(외경 12.7mm 미만 −15%, 이상 −10%)를 빼고, 탄소강 A179는 적힌 두께가 최소 두께입니다. '
            'S는 B31.3 부록 A 표 A-1 값을 설계 온도로 보간합니다. 제조사 값은 −28~37°C 값이라 그 온도에서만 비교합니다.',
      ),
      calcField(
        'pt_tube_temp',
        '설계 온도 (°C, 선택)',
        _tubeTemp,
        '설계 도서·배관 등급표의 설계 온도입니다. 비우면 38°C 이하로 계산합니다. '
            '허용 응력 S를 이 온도로 정합니다. 표 A-1에 넣은 범위(SS316 −254~427°C, 탄소강 −29~427°C) 밖이면 계산하지 않습니다.',
        signed: true,
      ),
    ];
  }

  void _setTubeSys(TubeSystem s) {
    if (s == _tubeSys) return;
    setState(() {
      _tubeSys = s;
      _tubeId = _tubeDefault;
      for (final g in _segs) {
        g.id = _tubeDefault;
      }
    });
  }

  /// 튜브 치수 글: 외경·두께·내경.
  String _tubeDims(TubeSize t) => t.inch
      ? '외경 ${t.odText}" (${_fmt(t.odMm)} mm) · 두께 ${t.wall.toStringAsFixed(3)}" (${_fmt(t.wallMm)} mm) · '
            '내경 ${(t.od - 2 * t.wall).toStringAsFixed(3)}" (${_fmt(t.idMm)} mm)'
      : '외경 ${_fmt(t.odMm)} mm · 두께 ${_fmt(t.wallMm)} mm · 내경 ${_fmt(t.idMm)} mm';

  List<Widget> _tubeResult(TestPlan? plan, double? designKpa) {
    final t = _tubeSize;
    final r = _tubeRating;
    final tIn = _num(_tubeTemp);
    final tempText = tIn == null ? '38°C 이하' : '${_fmt(tIn, 1)}°C';
    if (r == null) {
      return [
        calcResult(
          key: const Key('pt_tube_result'),
          big: '—',
          caption: '튜브 허용 사용압력 (설계 온도 $tempText)',
          warn: true,
          lines: [
            _tubeDims(t),
            '설계 온도 $tempText: 표 A-1에 넣은 범위(${tubeTempRangeText(_tubeMat)}) 밖이라 계산하지 않습니다.',
          ],
        ),
      ];
    }
    final designOver =
        designKpa != null && designKpa > 0 && designKpa > r.allowKpa + 1e-9;
    final b313 = _code == PipingCode.b313;
    final hydro = _medium == TestMedium.hydro;
    // 튜브 한도: B31.3 수압은 항복(345.2.1(a)), B31.3 공압은 항복의 90%(345.5.4),
    // B31.1은 항복의 90%(137.1.4 → 102.3.3(b)).
    final limit = b313 && hydro ? r.yieldKpa : r.yield90Kpa;
    final testOver = plan != null && plan.usedKpa > limit + 1e-9;
    final maker = r.makerKpa;
    final table = r.makerTableKpa;
    final ratio = r.stRatio;
    final showRatio = b313 && hydro && ratio > 1 + 1e-9;
    return [
      calcResult(
        key: const Key('pt_tube_result'),
        big: _p(r.allowKpa),
        caption: '튜브 허용 사용압력 (설계 온도 $tempText)',
        warn: designOver || testOver,
        lines: [
          '${_tubeMat.label} ${t.label}: ${_tubeDims(t)}',
          if (designKpa != null && designKpa > 0)
            designOver
                ? '설계압력 ${_p(designKpa)}: 허용 사용압력 초과'
                : '설계압력 ${_p(designKpa)}: 허용 사용압력 이내',
          '계산값 ${_p(r.calcKpa)}: B31.3 304.1.2, S ${_fmt(r.sKsi, 2)} ksi, '
              '최대 외경 ${_fmt(r.maxOdMm)} mm, 최소 두께 ${_fmt(r.minWallMm, 3)} mm',
          '최소 두께: ${tubeWallTolText(t, _tubeMat)}',
          '공칭 두께로 계산하면 ${_p(r.nominalKpa)} (참고)',
          if (maker != null)
            '제조사 값 ${_p(maker)}: ${t.makerText(_tubeMat)}, ${t.makerSource(_tubeMat)}, −28~37°C'
          else if (table != null)
            '제조사 값 ${t.makerText(_tubeMat)}은 −28~37°C 값이라 이 설계 온도에서는 계산값만 씁니다.'
          else
            '제조사 값 없음: Swagelok mm 탄소강 표는 EN 10305-1 관 기준이라 넣지 않았습니다.',
          '허용 사용압력은 계산값과 제조사 값 중 작은 것입니다(${r.makerGoverns ? '제조사 값' : '계산값'}).',
          if (r.thick)
            '두께가 외경의 1/6 이상이라 Y = d/(D + d)로 계산했습니다(표 304.1.1 주, 304.1.2(b) 검토 대상).',
          if (plan != null) ...[
            if (b313 && hydro)
              testOver
                  ? '시험압력 ${_p(plan.usedKpa)}: 튜브 항복 압력 ${_p(r.yieldKpa)} 초과. '
                        '항복 압력 이하로 낮출 수 있습니다(345.2.1(a)).'
                  : '시험압력 ${_p(plan.usedKpa)}: 튜브 항복 압력 ${_p(r.yieldKpa)} 이내 '
                        '(345.2.1(a), 최소 항복강도 ${_fmt(_tubeMat.syKsi, 0)} ksi)',
            if (b313 && !hydro) ...[
              '공압 최대 시험압력: ${_p(math.min(plan.maxKpa ?? r.yield90Kpa, r.yield90Kpa))} '
                  '(1.33P와 튜브 항복 압력의 90% ${_p(r.yield90Kpa)} 중 작은 것, 345.5.4)',
              testOver
                  ? '시험압력 ${_p(plan.usedKpa)}: 튜브 항복 압력의 90% 초과'
                  : '시험압력 ${_p(plan.usedKpa)}: 튜브 항복 압력의 90% 이내',
            ],
            if (!b313)
              testOver
                  ? '시험압력 ${_p(plan.usedKpa)}: 튜브 응력 한도(항복강도의 90%) ${_p(r.yield90Kpa)} 초과 (137.1.4·102.3.3(b))'
                  : '시험압력 ${_p(plan.usedKpa)}: 튜브 응력 한도(항복강도의 90%) ${_p(r.yield90Kpa)} 이내 (137.1.4·102.3.3(b))',
          ],
          if (showRatio)
            'ST/S = ${_fmt(r.sTestKsi, 2)} ÷ ${_fmt(r.sKsi, 2)} = ${_fmt(ratio, 3)} '
                '(시험 온도 38°C 이하 기준). B31.3 수압 시험압력에 곱합니다(345.4.2).',
          if (!b313)
            'B31.1 배관이면 B31.1 허용 응력으로 다시 확인하십시오. '
                '탄소강 A179는 B31.3 값의 0.85배입니다(Swagelok MS-01-107 표 1 주).',
        ],
      ),
      if (showRatio && (_num(_ratio) ?? 1) != double.parse(_fmt(ratio, 3)))
        Align(
          alignment: Alignment.centerRight,
          child: calcToggle(
            'pt_tube_ratio',
            'ST/S 칸에 넣기 (${_fmt(ratio, 3)})',
            () => setState(() => _ratio.text = _fmt(ratio, 3)),
          ),
        ),
    ];
  }

  Widget _tubeNotes() => _listCard('pt_tube_notes', '튜브 확인 사항', [
    '계통 허용 압력은 튜브·피팅·밸브 중 가장 낮은 것입니다. 피팅·밸브 제조사의 압력 등급을 확인하십시오.',
    '시험압력이 부품 등급의 1.5배를 초과하면 낮출 수 있습니다(345.2.1(a)). 공압은 1.35배까지입니다(345.5.4).',
    '누설 시험을 마친 배관에 계기를 잇는 나사 이음·튜브 이음은 다시 누설 시험하지 않아도 됩니다(345.2.3(d)).',
    '제조사 값은 참고값입니다(Swagelok 표 머리말). 최종은 설계 도서와 규격 식으로 확인하십시오.',
  ]);

  Widget _gaugeCard(double testKpa) {
    final g = gaugeRange(testKpa);
    return _listCard('pt_gauge', '압력계', [
      '눈금 범위: 약 ${_p(g.recKpa)} (시험압력 ${_p(testKpa)}의 1.5~4배: ${_fmt(g.lowKpa / _unit.kpa)} ~ ${_p(g.highKpa)})',
      if (g.fitBar.isNotEmpty)
        '맞는 표준 눈금(EN 837): ${g.fitBar.map((b) => '0~${_fmt(b)}').join(' · ')} bar',
      if (g.bestBar != null) '2배에 가장 가까운 눈금: 0~${_fmt(g.bestBar!)} bar',
      kGaugeDialNote,
      kGaugeCalNote,
    ]);
  }

  Widget _listCard(
    String key,
    String title,
    List<String> items, {
    bool numbered = false,
  }) => Container(
    key: Key(key),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: fc.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: fc.text,
          ),
        ),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${numbered ? '${i + 1}.' : '·'} ${items[i]}',
              style: TextStyle(fontSize: 14, color: fc.text, height: 1.45),
            ),
          ),
      ],
    ),
  );

  // ② 압력 강하
  Widget _decayTab() {
    return _page([
      _chips(
        '시험 종류',
        '공압: 기체라 온도와 절대압력으로 보정합니다. 수압: 물은 거의 압축되지 않아 온도 1°C에도 압력이 크게 바뀝니다.',
        [
          calcChip('pt_d_pneu', '공압', _decayMedium == TestMedium.pneumatic, () {
            setState(() => _decayMedium = TestMedium.pneumatic);
          }),
          calcChip('pt_d_hydro', '수압', _decayMedium == TestMedium.hydro, () {
            setState(() => _decayMedium = TestMedium.hydro);
          }),
        ],
      ),
      _unitChips(),
      if (_decayMedium == TestMedium.pneumatic)
        ..._pneuDecay()
      else
        ..._hydroDecay(),
    ]);
  }

  List<Widget> _pneuDecay() {
    final p1 = _kpa(_p1);
    final p2 = _kpa(_p2);
    final t1 = _num(_t1);
    final t2 = _num(_t2);
    final allow = _kpa(_allow);
    final r =
        p1 == null ||
            p2 == null ||
            t1 == null ||
            t2 == null ||
            t1 <= -273.15 ||
            t2 <= -273.15
        ? null
        : pressureDecay(
            p1Kpa: p1,
            p2Kpa: p2,
            t1C: t1,
            t2C: t2,
            volumeL: _num(_volume),
            minutes: _num(_minutes),
          );
    final pass = r?.passes(allow != null && allow >= 0 ? allow : null);
    return [
      calcField(
        'pt_p1',
        '시작 압력 (${_unit.label})',
        _p1,
        '유지시간을 시작할 때 읽은 게이지 압력입니다.',
      ),
      calcField(
        'pt_p2',
        '종료 압력 (${_unit.label})',
        _p2,
        '유지시간을 마칠 때 읽은 게이지 압력입니다.',
      ),
      calcField(
        'pt_allow',
        '허용 압력강하 (${_unit.label}, 선택)',
        _allow,
        '절차서나 발주처가 정한 허용 압력강하입니다. 규격에는 수치 기준이 없습니다. '
            '입력하면 온도를 보정한 압력강하로 합격·불합격을 판정합니다.',
      ),
      calcField(
        'pt_t1',
        '시작 온도 (°C)',
        _t1,
        '시작할 때 배관 안 기체 온도입니다. 알 수 없으면 배관 표면 온도나 주위 온도를 측정해 넣으십시오.',
        signed: true,
      ),
      calcField(
        'pt_t2',
        '종료 온도 (°C)',
        _t2,
        '종료할 때 같은 자리에서 측정한 온도입니다. 해가 들거나 밤이 되면 크게 바뀝니다.',
        signed: true,
      ),
      calcField('pt_min', '유지시간 (분)', _minutes, '누설률 계산에만 씁니다.'),
      calcField(
        'pt_vol',
        '시험 구간 체적 (L, 선택)',
        _volume,
        '누설률(mbar·L/s)을 보려면 넣습니다. "공압 안전거리" 탭에서 관 내경·길이로 계산할 수 있습니다.',
      ),
      const SizedBox(height: 12),
      if (r == null)
        calcResult(big: '—', caption: '압력과 온도를 넣으십시오', lines: const [])
      else
        calcResult(
          key: const Key('pt_decay_result'),
          big: _drop(r.correctedDropKpa),
          caption: '온도를 보정한 실제 압력강하',
          warn: pass == false,
          lines: [
            if (pass == true) '허용 압력강하 ${_p(allow!)} 이내: 합격',
            if (pass == false) '허용 압력강하 ${_p(allow!)} 초과: 불합격',
            '측정값 차이 ${_drop(r.rawDropKpa)}, 온도 영향 ${_drop(r.tempEffectKpa)}',
            if (r.leakMbarLs != null && r.leakMbarLs! > 0)
              '누설률 ${_fmt(r.leakMbarLs!, 4)} mbar·L/s (${_fmt(r.leakSccm!, 2)} mL/min, 20°C·1기압 기준)',
            '식: 종료 절대압을 시작 온도 기준으로 환산해 비교 (P₂·T₁/T₂). 온도는 절대 온도(K).',
            '판정 기준은 절차서가 정합니다. 규격에는 공압 압력강하의 수치 기준이 없습니다.',
            '참고: B31.1 137.4.6(d)의 "대기 변화로 설명되지 않는 강하는 찾아 고친다"는 수압 시험 조항입니다. '
                '매설 이음부를 육안 점검에서 뺄 때 발주처 승인과 용접부 100% 체적 검사가 함께 필요합니다.',
          ],
        ),
    ];
  }

  List<Widget> _hydroDecay() {
    final wt = _num(_waterT);
    final dt = _num(_dT) ?? 1;
    final t = _tubeSize;
    final od = _tube ? t.odMm : _num(_od);
    final w = _tube ? t.wallMm : _num(_wall);
    final mat = _tube ? _tubePipeMat : _mat;
    final per = wt == null || od == null || w == null || w <= 0 || od <= w
        ? null
        : hydroBarPerDegC(
            waterC: wt,
            odMm: od,
            wallMm: w,
            material: mat,
            restrained: _restrained,
          );
    final low = wt != null && wt < kWaterMinC;
    final high = wt != null && wt > kWaterMaxC;
    return [
      calcField(
        'pt_wt',
        '물 온도 (°C)',
        _waterT,
        '배관 안 물 온도입니다. 0~100°C 이내에서 계산합니다(Kell 1975 식).',
        signed: true,
      ),
      calcField(
        'pt_dt',
        '온도 변화 (°C)',
        _dT,
        '시험 중 물 온도가 얼마나 바뀌었는지입니다. 오르면 +, 내리면 −로 넣습니다.',
        signed: true,
      ),
      if (_tube)
        _tubeLine(
          'pt_d_tube',
          '튜브: ${_tubeMat.label} ${t.label} (${_tubeDims(t)})',
        )
      else ...[
        calcField('pt_od', '관 외경 (mm)', _od, '관 외경입니다. 예: 50A = 60.5mm.'),
        calcField(
          'pt_wall',
          '관 두께 (mm)',
          _wall,
          '관 두께(스케줄)입니다. 예: 50A SCH40 = 3.9mm.',
        ),
        _chips('재질', '탄소강·스테인리스에 따라 팽창이 달라 결과가 조금 바뀝니다.', [
          calcChip(
            'pt_cs',
            '탄소강',
            _mat == PipeMaterial.carbon,
            () => setState(() => _mat = PipeMaterial.carbon),
          ),
          calcChip(
            'pt_ss',
            '스테인리스',
            _mat == PipeMaterial.stainless,
            () => setState(() => _mat = PipeMaterial.stainless),
          ),
        ]),
      ],
      calcSwitch(
        '매설(축 구속)',
        _restrained,
        (v) => setState(() => _restrained = v),
        '땅에 묻혔거나 양 끝이 고정돼 축 방향으로 늘어나지 못하는 관입니다. '
            '이때는 dP/dT = (β − 2α) / (κ + D(1 − ν²)/(E·t))로 계산합니다. '
            '강관(D/t 20)은 약 7%, 두꺼운 튜브는 약 10% 커집니다.',
        key: 'pt_restrained',
      ),
      if (per == null)
        calcResult(big: '—', caption: '물 온도와 관 치수를 넣으십시오', lines: const [])
      else
        calcResult(
          key: const Key('pt_hydro_result'),
          big: _p(per * 100 * dt),
          caption: '물 온도 ${_fmt(dt, 1)}°C 변화에 따른 압력 변화(추정)',
          warn: low || high,
          lines: [
            if (low)
              '물 온도 ${_fmt(wt, 1)}°C: ${_fmt(kWaterMinC, 0)}°C 미만이라 ${_fmt(kWaterMinC, 0)}°C 값으로 계산했습니다.',
            if (high)
              '물 온도 ${_fmt(wt, 1)}°C: ${_fmt(kWaterMaxC, 0)}°C 초과라 ${_fmt(kWaterMaxC, 0)}°C 값으로 계산했습니다.',
            '1°C당 ${_p(per * 100)}',
            _restrained
                ? '공기 없이 물로 가득 찬 막힌 관, 매설되거나 축 방향으로 구속된 관으로 가정했습니다. 공기가 남아 있으면 훨씬 작아집니다.'
                : '공기 없이 물로 가득 찬 막힌 관, 축 방향으로 자유로운 지상 배관으로 가정했습니다. 공기가 남아 있으면 훨씬 작아집니다.',
            '물 온도 약 6°C 미만에서는 온도가 올라도 압력이 오르지 않거나 내려갑니다.',
            _restrained
                ? '식: dP/dT = (β − 2α) / (κ + D(1 − ν²)/(E·t)), D = 외경, 물 성질 Kell(1975) 식.'
                : '식: dP/dT = (β − 3α) / (κ + D/(t·E)·(5/4 − ν)), D = 평균 지름, 물 성질 Kell(1975) 식.',
          ],
        ),
    ];
  }

  /// "시험 압력" 탭에서 가져올 공압 시험압력: 공압이고 실제 시험압력을 넣었으면 그 값,
  /// 아니면 같은 규격 공압 최대 시험압력(안전 쪽).
  double? _planPressureForEnergy() {
    final a = _kpa(_actual);
    if (_medium == TestMedium.pneumatic && a != null && a > 0) return a;
    final d = _kpa(_design);
    if (d == null || d <= 0) return null;
    return testPlan(
      code: _code,
      medium: TestMedium.pneumatic,
      designKpa: d,
    ).maxKpa;
  }

  String _waterMass(double litres) =>
      litres >= 1000 ? '${_fmt(litres / 1000, 2)} t' : '${_vol(litres)} kg';

  /// 다른 탭에 보이는 튜브 규격 줄(시험 압력 탭에서 고른 것)과 "시험 압력 탭에서 바꾸기".
  Widget _tubeLine(String key, String text) => calcBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 8, 0),
          child: Text(
            text,
            key: Key(key),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: fc.text,
              height: 1.4,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: calcToggle(
            '${key}_goto',
            '시험 압력 탭에서 바꾸기',
            () => _tabs.animateTo(0),
          ),
        ),
      ],
    ),
  );

  /// 튜브 구간(구간 1 = 시험 압력 탭 규격, 더한 구간)의 체적(L). 길이를 하나도 넣지 않았으면 null.
  double? get _tubeVolume {
    final parts = <(TubeSize, double)>[];
    final l0 = _num(_tubeLen);
    if (l0 != null && l0 > 0) parts.add((_tubeSize, l0));
    for (final s in _segs) {
      final l = _num(s.len);
      final t = tubeById(s.id);
      if (l != null && l > 0 && t != null) parts.add((t, l));
    }
    return parts.isEmpty ? null : tubeVolumeL(parts);
  }

  /// 체적 글: 작은 튜브 체적도 보이게 자릿수를 늘린다.
  String _vol(double l) => _fmt(l, l < 1 ? 3 : (l < 10 ? 2 : 1));

  List<Widget> _tubeSegFields() {
    final t = _tubeSize;
    final sizes = tubeSizes(_tubeSys);
    return [
      _tubeLine(
        'pt_se_tube',
        '구간 1: ${_tubeMat.label} ${t.label}, 내경 ${_fmt(t.idMm)} mm (시험 압력 탭 규격)',
      ),
      calcField('pt_se_tlen', '구간 1 길이 (m)', _tubeLen, '구간 1 튜브의 전체 길이입니다.'),
      for (var i = 0; i < _segs.length; i++) ...[
        calcDropdown<String>(
          'pt_seg_size_$i',
          '구간 ${i + 2} 규격',
          sizes.any((x) => x.id == _segs[i].id) ? _segs[i].id : _tubeDefault,
          [for (final x in sizes) x.id],
          (id) => tubeById(id)!.label,
          (v) => setState(() => _segs[i].id = v),
          '규격이 다른 튜브가 섞였으면 구간을 더해 각각 넣습니다. 체적은 공칭 내경으로 계산합니다.',
        ),
        calcField(
          'pt_seg_len_$i',
          '구간 ${i + 2} 길이 (m)',
          _segs[i].len,
          '이 구간 튜브의 전체 길이입니다.',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: calcToggle('pt_seg_del_$i', '구간 ${i + 2} 지우기', () {
            setState(() => _segs.removeAt(i).len.dispose());
          }),
        ),
      ],
      Align(
        alignment: Alignment.centerRight,
        child: calcToggle('pt_seg_add', '구간 추가', () {
          setState(() => _segs = [..._segs, _TubeSeg(_tubeId)]);
        }),
      ),
    ];
  }

  // ③ 공압 안전거리
  Widget _energyTab() {
    final pt = _kpa(_sePt);
    final id = _num(_seId);
    final len = _num(_seLen);
    final direct = _num(_seVol);
    final vol =
        direct ??
        (_tube
            ? _tubeVolume
            : (id != null && len != null
                  ? pipeVolumeL(idMm: id, lengthM: len)
                  : null));
    final e = pt == null || vol == null || pt <= 0 || vol <= 0
        ? null
        : storedEnergy(testKpa: pt, volumeL: vol, gas: _gas);
    final src = _planPressureForEnergy();
    final n2 = e != null && _gas == TestGas.airN2
        ? nitrogenNeed(testKpa: pt!, volumeL: vol!)
        : null;
    return _page([
      _unitChips(),
      _chips(
        '시험 가스',
        '공기·질소는 k = 1.4(PCC-2 식 II-2), 헬륨·아르곤은 k = 1.67(단원자 기체, 식 II-1)로 계산합니다.',
        [
          calcChip(
            'pt_gas_air',
            '공기·질소',
            _gas == TestGas.airN2,
            () => setState(() => _gas = TestGas.airN2),
          ),
          calcChip(
            'pt_gas_mono',
            '헬륨·아르곤',
            _gas == TestGas.monatomic,
            () => setState(() => _gas = TestGas.monatomic),
          ),
        ],
      ),
      calcField(
        'pt_se_pt',
        '공압 시험압력 (${_unit.label})',
        _sePt,
        '공압 시험압력(게이지)입니다. 아래 단추로 "시험 압력" 탭 값을 가져올 수 있습니다. '
            '실제 시험압력이 없으면 공압 최대 시험압력을 가져옵니다.',
      ),
      if (src != null)
        Align(
          alignment: Alignment.centerRight,
          child: calcToggle(
            'pt_se_import',
            '시험 압력 탭 값 가져오기 (${_p(src)})',
            () => setState(() => _putKpa(_sePt, src)),
          ),
        ),
      if (_tube)
        ..._tubeSegFields()
      else ...[
        calcField(
          'pt_se_id',
          '관 내경 (mm)',
          _seId,
          '관 내경 = 외경 − 2 × 두께입니다. 예: 50A SCH40 = 60.5 − 7.8 = 52.7mm.',
        ),
        calcField('pt_se_len', '관 길이 (m)', _seLen, '시험 구간 전체 길이입니다.'),
      ],
      calcField(
        'pt_se_vol',
        '체적 직접 입력 (L)',
        _seVol,
        '용기·여러 관경이 섞였으면 합친 체적을 직접 넣으십시오. 입력하면 위 관 치수 대신 이 값으로 계산합니다.',
      ),
      if (vol != null && vol > 0)
        Padding(
          key: const Key('pt_se_volume'),
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(
            '시험 구간 체적 ${_vol(vol)} L · 수압 시험이면 물 약 ${_vol(vol)} L(약 ${_waterMass(vol)})',
            style: TextStyle(fontSize: 14, color: fc.textSub, height: 1.4),
          ),
        ),
      const SizedBox(height: 12),
      if (e == null)
        calcResult(big: '—', caption: '시험압력과 체적을 넣으십시오', lines: const [])
      else ...[
        calcResult(
          key: const Key('pt_energy_result'),
          big: '${_fmt(e.distanceM, 0)} m',
          caption: '출입 통제 거리',
          warn: e.beyondFixed,
          lines: [
            '저장 에너지 ${e.joules >= 1e6 ? '${_fmt(e.joules / 1e6, 2)} MJ' : '${_fmt(e.joules / 1000, 1)} kJ'} (체적 ${_vol(vol!)} L, k = ${_fmt(_gas.k, 2)})',
            'TNT 환산 ${_fmt(e.tntKg, 3)} kg',
            '거리: 최소 거리(135.5MJ까지 30m, 271MJ까지 60m)와 R = 20·(2·TNT)^(1/3) = ${_fmt(e.scaledM, 1)}m 중 큰 것',
            if (e.beyondFixed)
              '271MJ 초과: 식으로 계산한 거리를 씁니다. 방호벽이나 시험 구간 분할을 검토하십시오.',
            if (n2 != null) ...[
              '질소로 채우면 약 ${_fmt(n2.nm3, 1)} Nm³ (체적 × 절대 시험압력 ÷ 대기압)',
              n2.cylinders == null
                  ? '시험압력이 용기 압력(150bar) 이상이라 용기만으로는 채울 수 없습니다.'
                  : '47L·150bar 용기 약 ${n2.cylinders}병. 1병은 약 7Nm³이고, 시험압력까지만 비울 수 있어 1병 ${_fmt(n2.perCylNm3, 1)}Nm³로 계산했습니다.',
            ],
            '근거: ASME PCC-2-2022 Article 501, 부록 501-II 식 II-1·II-2, 501-III 식 III-1.',
          ],
        ),
        Padding(
          key: const Key('pt_energy_fragment'),
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            '파편 거리는 계산하지 않았습니다. 실제 출입 통제 거리는 더 길 수 있습니다.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: fc.danger,
              height: 1.4,
            ),
          ),
        ),
      ],
    ]);
  }

  // ④ 에어 누설
  Widget _leakTab() {
    final d = _num(_hole);
    final p = _kpa(_supply);
    final lps = d == null || p == null || d <= 0 || p <= 0
        ? null
        : holeLeakLps(holeMm: d, supplyKpa: p, cd: _sharp ? 0.61 : 0.97);
    final lowP = p != null && p < kLeakMinKpa - 1e-9;
    final kw = lps == null ? null : leakCompressorKw(lps);
    final hours = _num(_hours) ?? 8760;
    final price = _num(_price);
    final kwh = kw == null ? null : kw * hours;
    return _page([
      _unitChips(),
      calcField(
        'pt_hole',
        '구멍 지름 (mm)',
        _hole,
        '새는 구멍(틈)의 지름입니다. 크기를 모르면 1~3mm로 대략 넣으십시오.',
      ),
      calcField(
        'pt_supply',
        '공급 압력 (${_unit.label})',
        _supply,
        '압축공기 배관 압력(게이지)입니다. 0.9bar 미만에서는 이 식이 맞지 않습니다.',
      ),
      _chips('구멍 모양', '둥근 구멍은 0.97, 날카로운 틈은 0.61을 곱합니다(DOE).', [
        calcChip(
          'pt_round',
          '둥근 구멍',
          !_sharp,
          () => setState(() => _sharp = false),
        ),
        calcChip(
          'pt_sharp',
          '날카로운 틈',
          _sharp,
          () => setState(() => _sharp = true),
        ),
      ]),
      calcField(
        'pt_hours',
        '연간 가동 시간 (h)',
        _hours,
        '압축기 가동 시간입니다. 연중 계속이면 8760입니다.',
      ),
      calcField(
        'pt_price',
        '전기 요금 (원/kWh, 선택)',
        _price,
        '한전 요금표나 전기요금 고지서의 kWh당 단가입니다.',
      ),
      const SizedBox(height: 12),
      if (lps == null)
        calcResult(big: '—', caption: '구멍 지름과 압력을 넣으십시오', lines: const [])
      else
        calcResult(
          key: const Key('pt_leak_result'),
          big: '${_fmt(lps * 60, 1)} L/min',
          caption: '누설 공기량(대기압 기준)',
          warn: lowP,
          lines: [
            if (lowP) '공급 압력이 0.9bar 미만이라 이 식이 맞지 않습니다. 참고로만 보십시오.',
            '${_fmt(lps * 60 / 1000, 3)} m³/min · ${_fmt(lps * 2.11888, 2)} cfm',
            '압축기 전력 ${_fmt(kw!, 2)} kW (100cfm당 18kW, DOE)',
            '연간 ${_fmt(kwh!, 0)} kWh${price == null ? '' : ' · ${_fmt(kwh * price / 10000, 1)}만 원'}',
            '식: Q ≈ 0.154 × Cd × d² × P₀(절대 bar) L/s. 초크 흐름 기준이며 DOE 표와 3% 이내입니다.',
          ],
        ),
    ]);
  }
}
