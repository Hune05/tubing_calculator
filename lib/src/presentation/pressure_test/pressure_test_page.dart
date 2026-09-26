// 압력 시험 계산기(홈 "현장 작업" → 압력 시험 계산기). ASME B31.3(공정 배관)·B31.1(동력 배관),
// 수압·공압. 탭: 시험 압력(절차까지) → 압력 강하(온도 보정·누설률, 수압은 물 온도 영향) →
// 공압 시험 저장 에너지·안전거리(ASME PCC-2) → 압축공기 구멍 누설.
// 칸마다 "?" 안내, 결과에 조항 번호. 계산은 pressure_calc.dart. 최종은 해당 규격 원문·절차서로 확인.
import 'package:flutter/material.dart';

import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import 'pressure_calc.dart';

/// 압력 단위와 kPa 환산.
enum PUnit { bar, mpa, kgfcm2, psi, kpa }

extension on PUnit {
  String get label => switch (this) {
    PUnit.bar => 'bar',
    PUnit.mpa => 'MPa',
    PUnit.kgfcm2 => 'kgf/cm²',
    PUnit.psi => 'psi',
    PUnit.kpa => 'kPa',
  };
  double get kpa => switch (this) {
    PUnit.bar => 100,
    PUnit.mpa => 1000,
    PUnit.kgfcm2 => 98.0665,
    PUnit.psi => 6.894757293168361,
    PUnit.kpa => 1,
  };
}

String _fmt(double v, [int d = 2]) {
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

class PressureTestPage extends StatefulWidget {
  const PressureTestPage({super.key});

  @override
  State<PressureTestPage> createState() => _PressureTestPageState();
}

class _PressureTestPageState extends State<PressureTestPage>
    with SingleTickerProviderStateMixin, CalcFormParts {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  PUnit _unit = PUnit.bar;

  // ① 시험 압력
  PipingCode _code = PipingCode.b313;
  TestMedium _medium = TestMedium.hydro;
  final _design = TextEditingController();
  final _ratio = TextEditingController(text: '1');
  final _actual = TextEditingController();

  // ② 압력 강하
  TestMedium _decayMedium = TestMedium.pneumatic;
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  final _t1 = TextEditingController(text: '20');
  final _t2 = TextEditingController(text: '20');
  final _minutes = TextEditingController(text: '60');
  final _volume = TextEditingController();
  final _waterT = TextEditingController(text: '20');
  final _dT = TextEditingController(text: '1');
  final _od = TextEditingController(text: '60.5');
  final _wall = TextEditingController(text: '3.9');
  PipeMaterial _mat = PipeMaterial.carbon;

  // ③ 저장 에너지
  final _sePt = TextEditingController();
  final _seId = TextEditingController();
  final _seLen = TextEditingController();
  final _seVol = TextEditingController();

  // ④ 구멍 누설
  final _hole = TextEditingController(text: '3');
  final _supply = TextEditingController(text: '7');
  bool _sharp = false;
  final _hours = TextEditingController(text: '8760');
  final _price = TextEditingController();

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [
      _design,
      _ratio,
      _actual,
      _p1,
      _p2,
      _t1,
      _t2,
      _minutes,
      _volume,
      _waterT,
      _dT,
      _od,
      _wall,
      _sePt,
      _seId,
      _seLen,
      _seVol,
      _hole,
      _supply,
      _hours,
      _price,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', ''));

  /// 화면 단위 → kPa.
  double? _kpa(TextEditingController c) {
    final v = _num(c);
    return v == null ? null : v * _unit.kpa;
  }

  String _p(double kpa) => '${_fmt(kpa / _unit.kpa)} ${_unit.label}';
  String _pAll(double kpa) => [
    for (final u in PUnit.values)
      if (u != _unit) '${_fmt(kpa / u.kpa)} ${u.label}',
  ].join(' · ');

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
              Tab(key: Key('pt_tab_energy'), text: '저장 에너지'),
              Tab(key: Key('pt_tab_leak'), text: '구멍 누설'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            controller: _tabs,
            children: [_planTab(), _decayTab(), _energyTab(), _leakTab()],
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

  Widget _unitChips() =>
      _chips('압력 단위', '압력계에 적힌 단위를 고르십시오. 모든 압력은 게이지 압력(대기압 = 0)으로 넣습니다.', [
        for (final u in PUnit.values)
          calcChip('pt_u_${u.name}', u.label, _unit == u, () {
            setState(() => _unit = u);
          }),
      ]);

  // ① 시험 압력
  Widget _planTab() {
    final d = _kpa(_design);
    final ratio = _num(_ratio) ?? 1;
    final actual = _kpa(_actual);
    final plan = d == null || d <= 0
        ? null
        : testPlan(
            code: _code,
            medium: _medium,
            designKpa: d,
            stressRatio: ratio,
            actualKpa: actual,
          );
    final inRange = plan?.actualInRange(
      actual != null && actual > 0 ? actual : null,
    );
    return _page([
      _chips(
        '규격',
        'B31.3: 공정(플랜트) 배관. B31.1: 동력(발전소) 배관 — 보일러·증기·급수 계통 등. '
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
        '시험 매체',
        '두 규격 모두 수압이 기본입니다. 공압은 수압이 어려울 때 발주처가 정하거나 허락할 때만 합니다.',
        [
          calcChip('pt_hydro', '수압', _medium == TestMedium.hydro, () {
            setState(() => _medium = TestMedium.hydro);
          }),
          calcChip('pt_pneu', '공압', _medium == TestMedium.pneumatic, () {
            setState(() => _medium = TestMedium.pneumatic);
          }),
        ],
      ),
      _unitChips(),
      calcField(
        'pt_design',
        '설계 압력 (${_unit.label})',
        _design,
        '배관 등급표·P&ID·아이소 도면에 적힌 설계 압력(Design Pressure, 게이지)입니다. 운전 압력이 아닙니다.',
      ),
      if (_code == PipingCode.b313 && _medium == TestMedium.hydro)
        calcField(
          'pt_ratio',
          'ST/S (모르면 1)',
          _ratio,
          '설계 온도가 시험 온도보다 높을 때: 시험 온도에서의 허용 응력(ST) ÷ 설계 온도에서의 허용 응력(S). '
              'B31.3 부록 A 표 A-1에서 봅니다. 재질이 여럿이면 가장 작은 값. 1보다 작으면 1로 셉니다.',
        ),
      calcField(
        'pt_actual',
        '실제 시험 압력 (${_unit.label}, 선택)',
        _actual,
        '실제로 올릴 시험 압력입니다. 넣으면 안전밸브 설정과 사전 점검 압력을 이 압력으로 셉니다. '
            '비우면 최소 시험 압력으로 셉니다.',
      ),
      const SizedBox(height: 12),
      if (plan == null)
        calcResult(big: '—', caption: '설계 압력을 넣으십시오', lines: const [])
      else ...[
        calcResult(
          key: const Key('pt_plan_result'),
          big: plan.maxKpa == null
              ? '${_p(plan.minKpa)} 이상'
              : '${_fmt(plan.minKpa / _unit.kpa)} ~ ${_p(plan.maxKpa!)}',
          caption:
              '${_code == PipingCode.b313 ? 'B31.3' : 'B31.1'} ${_medium == TestMedium.hydro ? '수압' : '공압'} 시험 압력',
          warn: inRange == false,
          lines: [
            if (inRange == true) '실제 시험 압력 ${_p(plan.usedKpa)} — 범위 안입니다.',
            if (inRange == false)
              plan.usedKpa < plan.minKpa
                  ? '실제 시험 압력 ${_p(plan.usedKpa)} — 최소 시험 압력보다 낮습니다.'
                  : '실제 시험 압력 ${_p(plan.usedKpa)} — 최대 시험 압력을 넘습니다.',
            '다른 단위: ${_pAll(plan.minKpa)}',
            '유지: ${_fmt(plan.holdMin, 0)}분 이상',
            if (plan.prelimKpa != null) '사전 점검: ${_p(plan.prelimKpa!)}',
            if (plan.examKpa != null) '누설 점검 압력: ${_p(plan.examKpa!)}',
            if (plan.reliefMaxKpa != null)
              '안전밸브 설정: ${_p(plan.reliefMaxKpa!)} 이하 (시험 압력 ${_p(plan.usedKpa)} 기준)',
            if (plan.reliefRecKpa != null)
              '안전밸브 권장 설정: ${_p(plan.reliefRecKpa!)} (시험 압력 ${_p(plan.usedKpa)} 기준)',
          ],
        ),
        const SizedBox(height: 12),
        _listCard('pt_steps', '절차', plan.steps, numbered: true),
        const SizedBox(height: 12),
        _listCard('pt_notes', '주의·조건', plan.notes),
      ],
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
        '시험 매체',
        '공압: 기체라 온도와 절대 압력으로 보정합니다. 수압: 물은 거의 안 줄어들어 온도 1°C에도 압력이 크게 바뀝니다.',
        [
          calcChip('pt_d_pneu', '공압', _decayMedium == TestMedium.pneumatic, () {
            setState(() => _decayMedium = TestMedium.pneumatic);
          }),
          calcChip('pt_d_hydro', '수압', _decayMedium == TestMedium.hydro, () {
            setState(() => _decayMedium = TestMedium.hydro);
          }),
        ],
      ),
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
    final r = p1 == null || p2 == null || t1 == null || t2 == null
        ? null
        : pressureDecay(
            p1Kpa: p1,
            p2Kpa: p2,
            t1C: t1,
            t2C: t2,
            volumeL: _num(_volume),
            minutes: _num(_minutes),
          );
    return [
      _unitChips(),
      calcField(
        'pt_p1',
        '시작 압력 (${_unit.label})',
        _p1,
        '유지를 시작할 때 읽은 게이지 압력입니다.',
      ),
      calcField(
        'pt_p2',
        '끝 압력 (${_unit.label})',
        _p2,
        '유지를 마칠 때 읽은 게이지 압력입니다.',
      ),
      calcField(
        'pt_t1',
        '시작 온도 (°C)',
        _t1,
        '시작할 때 배관 안 기체 온도입니다. 알 수 없으면 배관 표면 온도나 주위 온도를 재서 넣으십시오.',
      ),
      calcField(
        'pt_t2',
        '끝 온도 (°C)',
        _t2,
        '끝날 때 같은 자리에서 잰 온도입니다. 해가 들거나 밤이 되면 크게 바뀝니다.',
      ),
      calcField('pt_min', '유지 시간 (분)', _minutes, '누설률을 셀 때만 씁니다.'),
      calcField(
        'pt_vol',
        '계통 체적 (L, 선택)',
        _volume,
        '누설률(mbar·L/s)을 보려면 넣습니다. "저장 에너지" 탭에서 관 안지름·길이로 셀 수 있습니다.',
      ),
      const SizedBox(height: 12),
      if (r == null)
        calcResult(big: '—', caption: '압력과 온도를 넣으십시오', lines: const [])
      else
        calcResult(
          key: const Key('pt_decay_result'),
          big: _p(r.correctedDropKpa),
          caption: '온도를 보정한 실제 압력 강하',
          warn: r.correctedDropKpa > 0.005 * (p1! + kAtmKpa),
          lines: [
            '읽은 강하 ${_p(r.rawDropKpa)} 중 온도 때문에 바뀐 몫 ${_p(r.tempEffectKpa)}',
            if (r.leakMbarLs != null)
              '누설률 ${_fmt(r.leakMbarLs!, 4)} mbar·L/s (${_fmt(r.leakSccm!, 2)} mL/min, 0°C·1기압 기준)',
            '식: 끝 절대압을 시작 온도로 되돌려 비교 (P₂·T₁/T₂). 온도는 절대 온도(K).',
            '판정 기준은 규격·절차서가 정합니다 — B31.1 137.4.6(d): 대기 변화로 설명 안 되는 강하가 있으면 찾아 고치고 다시 시험.',
          ],
        ),
    ];
  }

  List<Widget> _hydroDecay() {
    final wt = _num(_waterT);
    final dt = _num(_dT);
    final od = _num(_od);
    final w = _num(_wall);
    final per = wt == null || od == null || w == null || w <= 0 || od <= w
        ? null
        : hydroBarPerDegC(waterC: wt, odMm: od, wallMm: w, material: _mat);
    return [
      calcField(
        'pt_wt',
        '물 온도 (°C)',
        _waterT,
        '배관 안 물 온도입니다. 5~50°C 사이에서 셉니다.',
      ),
      calcField(
        'pt_dt',
        '온도 변화 (°C)',
        _dT,
        '시험 중 물 온도가 얼마나 바뀌었는지입니다(오르면 +, 내리면 −).',
      ),
      calcField('pt_od', '관 바깥지름 (mm)', _od, '관 바깥지름입니다. 예: 50A = 60.5mm.'),
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
      if (per == null)
        calcResult(big: '—', caption: '물 온도와 관 치수를 넣으십시오', lines: const [])
      else
        calcResult(
          key: const Key('pt_hydro_result'),
          big: '${_fmt(per * (dt ?? 1), 2)} bar',
          caption: '물 온도 ${_fmt(dt ?? 1, 1)}°C 변화에 따른 압력 변화(추정)',
          lines: [
            '1°C당 ${_fmt(per, 2)} bar (${_fmt(per * 100 / _unit.kpa, 3)} ${_unit.label})',
            '공기 없이 물로 가득 찬 막힌 관, 축 방향으로 자유로운 지상 배관 가정. 공기가 남아 있으면 훨씬 작아집니다.',
            '물 온도 약 6°C 아래에서는 방향이 뒤집힙니다(물이 거의 안 늘어남).',
            '식: dP/dT = (β − 3α) / (κ + D/(t·E)·(5/4 − ν)), 물 성질 Kell(1975).',
          ],
        ),
    ];
  }

  // ③ 저장 에너지
  Widget _energyTab() {
    final pt = _kpa(_sePt);
    final id = _num(_seId);
    final len = _num(_seLen);
    final direct = _num(_seVol);
    final vol =
        direct ??
        (id != null && len != null
            ? pipeVolumeL(idMm: id, lengthM: len)
            : null);
    final e = pt == null || vol == null || pt <= 0 || vol <= 0
        ? null
        : storedEnergy(testKpa: pt, volumeL: vol);
    return _page([
      _unitChips(),
      calcField(
        'pt_se_pt',
        '공압 시험 압력 (${_unit.label})',
        _sePt,
        '공압 시험 압력(게이지)입니다. "시험 압력" 탭의 결과를 넣으십시오.',
      ),
      calcField(
        'pt_se_id',
        '관 안지름 (mm)',
        _seId,
        '관 안지름 = 바깥지름 − 2 × 두께입니다. 예: 50A SCH40 = 60.5 − 7.8 = 52.7mm.',
      ),
      calcField('pt_se_len', '관 길이 (m)', _seLen, '시험 구간 전체 길이입니다.'),
      calcField(
        'pt_se_vol',
        '또는 체적 직접 (L)',
        _seVol,
        '용기·여러 관경이 섞였으면 합친 체적을 직접 넣으십시오. 넣으면 위 관 값보다 먼저 씁니다.',
      ),
      const SizedBox(height: 12),
      if (e == null)
        calcResult(big: '—', caption: '시험 압력과 체적을 넣으십시오', lines: const [])
      else
        calcResult(
          key: const Key('pt_energy_result'),
          big: '${_fmt(e.distanceM, 0)} m',
          caption: '안전거리(사람 접근 금지)',
          warn: e.beyondFixed,
          lines: [
            '저장 에너지 ${e.joules >= 1e6 ? '${_fmt(e.joules / 1e6, 2)} MJ' : '${_fmt(e.joules / 1000, 1)} kJ'} (체적 ${_fmt(vol!, 1)} L)',
            'TNT 환산 ${_fmt(e.tntKg, 3)} kg',
            '거리: 고정 거리(135.5MJ까지 30m, 271MJ까지 60m)와 R = 20·TNT^(1/3) = ${_fmt(e.scaledM, 1)}m 중 큰 것',
            if (e.beyondFixed) '271MJ를 넘습니다 — 규격대로 따로 계산하고 공압 시험을 다시 검토하십시오.',
            '근거: ASME PCC-2(2008) 부록 II 식 II-2(공기·질소), 부록 III. 최신판은 식이 바뀌었을 수 있으니(2·TNT) 원문을 확인하십시오.',
          ],
        ),
    ]);
  }

  // ④ 구멍 누설
  Widget _leakTab() {
    final d = _num(_hole);
    final p = _kpa(_supply);
    final lps = d == null || p == null || d <= 0 || p <= 0
        ? null
        : holeLeakLps(holeMm: d, supplyKpa: p, cd: _sharp ? 0.61 : 0.97);
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
        '새는 구멍(틈)의 지름입니다. 크기를 모르면 1~3mm로 어림하십시오.',
      ),
      calcField(
        'pt_supply',
        '공급 압력 (${_unit.label})',
        _supply,
        '압축공기 배관 압력(게이지)입니다. 0.9bar 아래는 식이 맞지 않습니다.',
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
        '1년 운전 시간 (h)',
        _hours,
        '압축기가 도는 시간입니다. 연중 계속이면 8760.',
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
          caption: '새는 공기량(대기 상태)',
          lines: [
            '${_fmt(lps * 60 / 1000, 3)} m³/min · ${_fmt(lps * 2.11888, 2)} cfm',
            '압축기 전력 ${_fmt(kw!, 2)} kW (100cfm당 18kW, DOE)',
            '1년 ${_fmt(kwh!, 0)} kWh${price == null ? '' : ' · ${_fmt(kwh * price / 10000, 1)}만 원'}',
            '식: Q ≈ 0.154 × Cd × d² × P₀(절대 bar) L/s — 초크 흐름, DOE 표와 3% 안.',
          ],
        ),
    ]);
  }
}
