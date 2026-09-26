// 전기 계산기(홈 "현장 작업" → 전기 계산기). 480V까지, 발전소·플랜트·시험 설비·제어반.
//
// 탭: 부하 전류(전동기 포함) → 전선 굵기(허용전류 + 전압강하, 차단기·보호도체) → 전압강하 →
// 역률 개선. 칸마다 "?"로 무슨 값을 어디서 보는지 알려 준다. 숫자는 elec_tables.dart의 출처 있는
// 표만 쓰고, 결과에 어느 표·조건으로 셈했는지 적는다. 최종 선정은 설계 도서·제조사 표로 확인한다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/field_view.dart';
import 'elec_calc.dart';
import 'elec_tables.dart';
import 'motor_tables.dart';

/// 전선 종류(현장 이름) → 절연체와 쓸 수 있는 공사 방법.
/// HFIX는 제조사(LS·대한전선) 카탈로그가 도체 90°C, 허용전류도 IEC XLPE 90°C 표 값이다.
/// 제어반 내부 배선은 IEC 60204-1 표 6(PVC, 반 안 40°C)으로 셈한다.
enum WireKind { fcv, hfix, pvcWire, panel }

extension on WireKind {
  String get label => switch (this) {
    WireKind.fcv => 'F-CV 케이블 (XLPE 90°C)',
    WireKind.hfix => 'HFIX 전선 (90°C)',
    WireKind.pvcWire => 'IV·PVC 전선 (70°C)',
    WireKind.panel => '제어반 내부 배선 (IEC 60204-1)',
  };
  Insulation get insulation => switch (this) {
    WireKind.fcv || WireKind.hfix => Insulation.xlpe90,
    _ => Insulation.pvc70,
  };
  AmpacityTable get table => this == WireKind.panel
      ? AmpacityTable.panel60204
      : AmpacityTable.iec60364;
  List<InstallMethod> get methods => switch (this) {
    WireKind.fcv => const [
      InstallMethod.e,
      InstallMethod.c,
      InstallMethod.b2,
      InstallMethod.d1,
      InstallMethod.d2,
    ],
    WireKind.panel => const [
      InstallMethod.b1,
      InstallMethod.b2,
      InstallMethod.c,
      InstallMethod.e,
    ],
    _ => const [InstallMethod.b1, InstallMethod.a1],
  };
}

String methodLabel(InstallMethod m) => switch (m) {
  InstallMethod.a1 => '단열벽 속 전선관 (A1)',
  InstallMethod.a2 => '단열벽 속 전선관, 다심 (A2)',
  InstallMethod.b1 => '전선관·덕트 속 절연전선 (B1)',
  InstallMethod.b2 => '전선관·덕트 속 케이블 (B2)',
  InstallMethod.c => '벽에 직접·무구멍 트레이 (C)',
  InstallMethod.d1 => '땅속 관로 (D1)',
  InstallMethod.d2 => '땅에 직접 묻음 (D2)',
  InstallMethod.e => '구멍 트레이·사다리 (E)',
};

GroupLayout layoutFor(InstallMethod m) => switch (m) {
  InstallMethod.c => GroupLayout.wallSingleLayer,
  InstallMethod.e => GroupLayout.perforatedTray,
  InstallMethod.d1 => GroupLayout.groundDuct,
  InstallMethod.d2 => GroupLayout.groundDirect,
  _ => GroupLayout.bunched,
};

String supplyLabel(SupplyType t) => switch (t) {
  SupplyType.lvOther => '저압 수전 · 동력 등 (5%)',
  SupplyType.lvLighting => '저압 수전 · 조명 (3%)',
  SupplyType.hvOther => '고압 이상 수전 · 동력 등 (8%)',
  SupplyType.hvLighting => '고압 이상 수전 · 조명 (6%)',
};

String fmt(double v, [int d = 1]) {
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

class ElectricCalculatorPage extends StatefulWidget {
  const ElectricCalculatorPage({super.key});

  @override
  State<ElectricCalculatorPage> createState() => _ElectricCalculatorPageState();
}

class _ElectricCalculatorPageState extends State<ElectricCalculatorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  // 공통
  double _volts = 380;
  Phase _phase = Phase.three;

  // ① 부하 전류
  final _kw = TextEditingController();
  bool _hp = false;
  final _eff = TextEditingController(text: '90');
  final _pf = TextEditingController(text: '85');
  bool _motor = true;

  // ② 전선 굵기
  final _ib = TextEditingController();
  bool _cableMotor = false; // 차단기·허용전류에 ×1.25
  WireKind _kind = WireKind.fcv;
  InstallMethod _method = InstallMethod.e;
  final _ambient = TextEditingController(text: '30');
  final _circuits = TextEditingController(text: '1');
  final _length = TextEditingController(text: '50');
  final _pf2 = TextEditingController(text: '85');
  SupplyType _supply = SupplyType.lvOther;

  // ③ 전압강하
  double _vdSize = 4;
  WireKind _vdKind = WireKind.fcv;
  final _vdI = TextEditingController();
  final _vdLen = TextEditingController(text: '50');
  final _vdPf = TextEditingController(text: '85');

  // ④ 역률
  final _pcKw = TextEditingController();
  final _pcNow = TextEditingController(text: '80');
  final _pcTarget = TextEditingController(text: '95');

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [
      _kw, _eff, _pf, _ib, _ambient, _circuits, _length, _pf2, _vdI, _vdLen,
      _vdPf, _pcKw, _pcNow, _pcTarget,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', ''));
  double _pct(TextEditingController c, double dflt) {
    final v = _num(c);
    if (v == null || v <= 0) return dflt;
    return (v > 1 ? v / 100 : v).clamp(0.01, 1.0);
  }

  // ─────────────── 계산 ───────────────

  double? get _loadCurrent {
    final p = _num(_kw);
    if (p == null || p <= 0) return null;
    return loadCurrent(
      kw: _hp ? hpToKw(p) : p,
      volts: _volts,
      phase: _phase,
      pf: _pct(_pf, 0.85),
      eff: _pct(_eff, 0.9),
    );
  }

  /// 표 값 참고 줄: 440·480V·230V HP면 NEC 430.250, 380V 삼상 kW면 IE3 전동기 예시.
  String? _tableHint() {
    final p = _num(_kw);
    if (p == null || _phase != Phase.three) return null;
    if (_hp) {
      final r = necRow(p);
      if (r == null) return null;
      if (_volts >= 440) {
        return 'NEC 430.250 표 (460V) ${fmt(r.a460)} A — 미국 기준(NEC 430.6)은 전선·차단기를 이 표 값으로 고릅니다';
      }
      if (_volts == 220) {
        return 'NEC 430.250 표 (230V) ${fmt(r.a230)} A';
      }
      return null;
    }
    if (_volts == 380) {
      final r = ie3Row(p);
      if (r == null) return null;
      return 'IE3 4극 60Hz 380V 전동기 예 ${fmt(r.amps)} A (효율 ${fmt(r.eff)}%, 역률 ${fmt(r.pf * 100)}% — WEG W22 카탈로그)';
    }
    return null;
  }

  void _sendToCable() {
    final i = _loadCurrent;
    if (i == null) return;
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _ib.text = fmt(i, 1);
      _cableMotor = _motor;
      _pf2.text = _pf.text;
    });
    _tabs.animateTo(1);
  }

  // ─────────────── 그리기 ───────────────

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
            '전기 계산기',
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
              Tab(key: Key('ec_tab_load'), text: '부하 전류'),
              Tab(key: Key('ec_tab_cable'), text: '전선 굵기'),
              Tab(key: Key('ec_tab_vd'), text: '전압강하'),
              Tab(key: Key('ec_tab_pf'), text: '역률 개선'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            controller: _tabs,
            children: [_loadTab(), _cableTab(), _vdTab(), _pfTab()],
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

  // ① 부하 전류
  Widget _loadTab() {
    final i = _loadCurrent;
    return _page([
      _voltsPhase(),
      _field(
        'ec_kw',
        _hp ? '출력 (HP)' : '출력 (kW)',
        _kw,
        '전동기 명판의 정격 출력(축 출력)입니다. 히터·일반 부하는 소비 전력을 넣으십시오.\n'
            '미국식 명판(HP)이면 오른쪽 단추로 HP를 고르십시오.',
        trailing: _toggle(
          'ec_hp',
          _hp ? 'HP' : 'kW',
          () => setState(() => _hp = !_hp),
        ),
      ),
      _field(
        'ec_eff',
        '효율 (%)',
        _eff,
        '명판의 효율(EFF, η)입니다. 모르면 90으로 두십시오. 히터처럼 전부 열로 쓰는 부하는 100입니다.',
      ),
      _field(
        'ec_pf',
        '역률 (%)',
        _pf,
        '명판의 역률(P.F., cosφ)입니다. 모르면 85로 두십시오. 히터는 100입니다.',
      ),
      _switchRow(
        '전동기 (전선 고를 때 1.25배)',
        _motor,
        (v) => setState(() => _motor = v),
        '연속 운전 전동기는 정격전류의 1.25배로 전선을 고르는 것이 관례입니다(NEC 430.22, 예전 내선규정). '
            'KEC에는 이 배수가 없으니 설계 기준을 따르십시오.',
      ),
      const SizedBox(height: 12),
      _result(
        key: const Key('ec_load_result'),
        big: i == null ? '— A' : '${fmt(i, 1)} A',
        caption: '정격 전류(계산 값)',
        lines: [
          if (i != null && _motor) '차단기·전선은 ${fmt(i * 1.25, 1)} A (×1.25) 기준',
          ?_tableHint(),
          if (i != null) '명판에 전류(A)가 있으면 그 값을 먼저 쓰십시오.',
          '식: I = P ÷ (${_phase == Phase.three ? '√3 × ' : ''}V × 역률 × 효율)',
        ],
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        key: const Key('ec_to_cable'),
        onPressed: i == null ? null : _sendToCable,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('이 전류로 전선 굵기 고르기'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: fc.brand,
        ),
      ),
    ]);
  }

  // ② 전선 굵기
  Widget _cableTab() {
    final ib = _num(_ib);
    final len = _num(_length) ?? 0;
    final amb = _num(_ambient) ?? 30;
    final n = (_num(_circuits) ?? 1).round().clamp(1, 20);
    final CableChoice? c = ib == null || ib <= 0
        ? null
        : chooseCable(
            load: ib,
            margin: _cableMotor ? 1.25 : 1,
            volts: _volts,
            phase: _phase,
            ins: _kind.insulation,
            method: _method,
            lengthM: len,
            pf: _pct(_pf2, 0.85),
            ambientC: amb,
            circuits: n,
            layout: layoutFor(_method),
            supply: _supply,
            table: _kind.table,
          );
    final ground = isGround(_method);
    return _page([
      _voltsPhase(),
      _field(
        'ec_ib',
        '부하 전류 (A)',
        _ib,
        '이 회로에 실제로 흐르는 전류입니다. 명판 전류나 "부하 전류" 탭의 결과를 넣으십시오. '
            '전동기 여유는 아래 스위치로 넣습니다.',
      ),
      _switchRow(
        '전동기 (차단기·허용전류 ×1.25)',
        _cableMotor,
        (v) => setState(() => _cableMotor = v),
        '연속 운전 전동기는 차단기와 전선 허용전류를 정격전류의 1.25배로 잡는 것이 관례입니다(NEC 430.22, 예전 내선규정). '
            '전압강하는 실제 전류로 셉니다.',
        key: 'ec_cable_motor',
      ),
      _dropdown<WireKind>(
        'ec_kind',
        '전선 종류',
        _kind,
        WireKind.values,
        (k) => k.label,
        (k) => setState(() {
          final wasPanel = _kind == WireKind.panel;
          _kind = k;
          if (!k.methods.contains(_method)) _method = k.methods.first;
          // 제어반 표는 반 안 40°C가 기준이다.
          if (k == WireKind.panel && !wasPanel) _ambient.text = '40';
          if (k != WireKind.panel && wasPanel) _ambient.text = '30';
        }),
        'F-CV: 동력용 0.6/1kV 케이블(XLPE, 90°C).\n'
            'HFIX: 450/750V 저독성 난연 전선(KS C 3341). 도체 90°C(LS·대한전선 카탈로그). 전선관·덕트 속에 넣습니다.\n'
            'IV·PVC 전선: 도체 70°C. 전선 표시를 모르면 이것으로 셈하면 안전합니다.\n'
            '제어반 내부 배선: 반 안 배선 덕트·배선에 IEC 60204-1 표 6(PVC, 반 안 40°C)으로 셉니다. 0.75sq부터.',
      ),
      _dropdown<InstallMethod>(
        'ec_method',
        '공사 방법',
        _method,
        _kind.methods,
        methodLabel,
        (m) => setState(() => _method = m),
        '케이블이 어디에 어떻게 놓이는지입니다(KS C IEC 60364-5-52 기준 방법).\n'
            '· 구멍 트레이·사다리(E): 케이블 트레이 위\n· 벽에 직접(C): 새들로 벽·구조물에 고정\n'
            '· 전선관·덕트 속(B1·B2)\n· 땅속 관로(D1)·직매(D2)',
      ),
      _field(
        'ec_ambient',
        ground ? '땅 온도 (°C)' : '주위 온도 (°C)',
        _ambient,
        ground
            ? '케이블이 묻힌 땅의 온도입니다. 모르면 20으로 두십시오(표 기준).'
            : '케이블 둘레 공기 온도입니다. 표 기준은 30°C입니다. 보일러·터빈 건물처럼 더운 곳은 40~50을 넣으십시오.',
      ),
      _field(
        'ec_circuits',
        ground ? '같은 관로·도랑의 회로 수' : '같이 놓인 회로 수',
        _circuits,
        '같은 트레이 한 줄·같은 관·같은 묶음에 나란히 있는 회로(케이블) 수입니다. 많을수록 열이 빠지지 않아 허용전류가 줄어듭니다.',
      ),
      _field(
        'ec_length',
        '편도 길이 (m)',
        _length,
        '전원(분전반·MCC)에서 부하까지 케이블 한 가닥 길이입니다. 왕복이 아닙니다.',
      ),
      _field(
        'ec_pf2',
        '역률 (%)',
        _pf2,
        '전압강하 계산에 씁니다. 전동기 85, 히터·저항 부하 100을 넣으십시오.',
      ),
      _dropdown<SupplyType>(
        'ec_supply',
        '전압강하 한도',
        _supply,
        const [
          SupplyType.lvOther,
          SupplyType.lvLighting,
          SupplyType.hvOther,
          SupplyType.hvLighting,
        ],
        supplyLabel,
        (s) => setState(() => _supply = s),
        'KEC 232.3.9 표 232.3-1입니다. 발전소·플랜트처럼 자체 변압기(고압 수전)에서 받으면 "고압 이상 수전"을 고르십시오. '
            '100m를 넘는 만큼 1m에 0.005%씩(최대 0.5%) 더 허용됩니다.',
      ),
      const SizedBox(height: 12),
      if (c == null)
        _result(
          big: '—',
          caption: '부하 전류를 넣으면 굵기를 고릅니다',
          lines: const [],
        )
      else
        _cableResult(c, amb, n),
    ]);
  }

  Widget _cableResult(CableChoice c, double amb, int n) {
    final size = c.size;
    return _result(
      key: const Key('ec_cable_result'),
      big: size == null ? '검토 필요' : sqText(size),
      caption: size == null
          ? '표 안에서 고를 수 없습니다'
          : '${_kind == WireKind.fcv ? 'F-CV ' : ''}${_phase == Phase.three ? '3심' : '2심'} 기준 추천 굵기',
      warn: size == null,
      lines: [
        if (c.ib != c.load) '설계 전류 ${fmt(c.ib, 1)}A = 부하 ${fmt(c.load, 1)}A × 1.25',
        if (c.breaker != null) '차단기 ${c.breaker}A (${fmt(c.ib, 1)}A 이상 가장 작은 표준 정격)',
        if (c.sizeByAmpacity != null)
          '허용전류로 보면 ${sqText(c.sizeByAmpacity!)} (보정 후 ≥ ${c.breaker ?? fmt(c.ib)}A)',
        if (c.sizeByDrop != null)
          '전압강하로 보면 ${sqText(c.sizeByDrop!)} (한도 ${fmt(c.dropLimitPct, 2)}%)',
        if (size != null && c.iz != null)
          '${sqText(size)} 허용전류 ${fmt(c.iz!, 1)}A = 표 값 × 온도 ${fmt(c.tempFactor, 2)} × 회로 수 ${fmt(c.groupFactor, 2)}',
        if (c.dropV != null)
          '전압강하 ${fmt(c.dropV!, 2)}V (${fmt(c.dropPct!, 2)}%)',
        if (size != null) '보호도체(접지선) ${sqText(peConductorSize(size))} 이상 (KEC 142.3.2)',
        ...c.notes,
        _kind == WireKind.panel
            ? '기준: 부하 ≤ 차단기 ≤ 허용전류, IEC 60204-1 표 6 (PVC 70°C, 3상, ${methodLabel(_method)}, '
                  '반 안 ${fmt(amb)}°C — 표 D.1, $n회로 — 표 D.2)'
            : '기준: KEC 212.4.1(부하 ≤ 차단기 ≤ 허용전류), KS C IEC 60364-5-52 부속서 B '
                  '(${_kind.insulation == Insulation.xlpe90 ? 'XLPE 90°C' : 'PVC 70°C'}, ${methodLabel(_method)}, '
                  '${_phase == Phase.three ? '3' : '2'}가닥 통전, ${fmt(amb)}°C, $n회로)',
        if (_cableMotor)
          '전동기는 기동 전류 때문에 차단기를 더 크게 잡기도 합니다 — 역한시 차단기는 정격 전류의 '
              '${fmt(kNecInverseTimeBreakerMaxPct)}%(${fmt(c.load * kNecInverseTimeBreakerMaxPct / 100, 1)}A)까지(NEC 430.52). '
              'KEC에는 배수가 없으니 제조사 전동기용 선정표로 확인하십시오.',
      ],
    );
  }

  // ③ 전압강하
  Widget _vdTab() {
    final i = _num(_vdI);
    final len = _num(_vdLen);
    final ins = _vdKind.insulation;
    final dv = i == null || len == null
        ? null
        : voltageDrop(
            current: i,
            lengthM: len,
            size: _vdSize,
            phase: _phase,
            pf: _pct(_vdPf, 0.85),
            conductorTempC: conductorTemp(ins),
          );
    final simple = i == null || len == null
        ? null
        : voltageDropSimple(
            current: i,
            lengthM: len,
            size: _vdSize,
            phase: _phase,
          );
    final limit = voltageDropLimit(_supply, len ?? 0);
    final pct = dv == null ? null : dv / _volts * 100;
    return _page([
      _voltsPhase(),
      _dropdown<double>(
        'ec_vd_size',
        '전선 굵기',
        _vdSize,
        kCableSizes,
        sqText,
        (s) => setState(() => _vdSize = s),
        '지금 깔려 있거나 깔 전선의 굵기(sq = mm²)입니다.',
      ),
      _dropdown<WireKind>(
        'ec_vd_kind',
        '전선 종류',
        _vdKind,
        WireKind.values,
        (k) => k.label,
        (k) => setState(() => _vdKind = k),
        '도체 온도(70°C·90°C)에서의 저항으로 셉니다 — 운전 중 가장 불리한 값입니다.',
      ),
      _field('ec_vd_i', '전류 (A)', _vdI, '회로에 흐르는 전류입니다.'),
      _field('ec_vd_len', '편도 길이 (m)', _vdLen, '케이블 한 가닥 길이입니다(왕복 아님).'),
      _field('ec_vd_pf', '역률 (%)', _vdPf, '전동기 85, 히터 100.'),
      _dropdown<SupplyType>(
        'ec_vd_supply',
        '전압강하 한도',
        _supply,
        const [
          SupplyType.lvOther,
          SupplyType.lvLighting,
          SupplyType.hvOther,
          SupplyType.hvLighting,
        ],
        supplyLabel,
        (s) => setState(() => _supply = s),
        'KEC 232.3.9 표 232.3-1.',
      ),
      const SizedBox(height: 12),
      _result(
        key: const Key('ec_vd_result'),
        big: pct == null ? '— %' : '${fmt(pct, 2)} %',
        caption: dv == null ? '전류와 길이를 넣으십시오' : '전압강하 ${fmt(dv, 2)} V',
        warn: pct != null && pct > limit,
        lines: [
          if (pct != null)
            pct > limit
                ? '한도 ${fmt(limit, 2)}%를 넘습니다 — 굵기를 올리거나 길이를 줄이십시오.'
                : '한도 ${fmt(limit, 2)}% 안입니다.',
          if (simple != null)
            '참고: 현장 간이식(${_phase == Phase.three ? '30.8' : '35.6'}·L·I/1000A, 역률 1·20°C) ${fmt(simple, 2)}V',
          '식: ΔU = ${_phase == Phase.three ? '√3' : '2'} × I × L × (R cosφ + X sinφ), '
              'R은 ${fmt(conductorTemp(ins))}°C 저항(IEC 60228), X = 0.08 Ω/km',
        ],
      ),
    ]);
  }

  // ④ 역률
  Widget _pfTab() {
    final p = _num(_pcKw);
    final now = _pct(_pcNow, 0.8);
    final target = _pct(_pcTarget, 0.95);
    final q = p == null ? null : capacitorKvar(p, now, target);
    return _page([
      _field('ec_pc_kw', '유효 전력 (kW)', _pcKw, '역률을 올릴 부하의 전력(kW)입니다. 전력량계나 부하 목록에서 보십시오.'),
      _field('ec_pc_now', '지금 역률 (%)', _pcNow, '지금 측정한 역률입니다.'),
      _field('ec_pc_target', '목표 역률 (%)', _pcTarget, '보통 90~95%를 목표로 합니다. 100%에 가깝게 올리면 가벼운 부하 때 과보상이 됩니다.'),
      const SizedBox(height: 12),
      _result(
        key: const Key('ec_pf_result'),
        big: q == null ? '— kvar' : '${fmt(q, 1)} kvar',
        caption: '필요한 콘덴서 용량',
        lines: const ['식: Qc = P × (tanφ1 − tanφ2)'],
      ),
    ]);
  }

  // ─────────────── 부품 ───────────────

  Widget _voltsPhase() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            '전압',
            style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
          ),
          const SizedBox(width: 6),
          _help('전압', '회로의 선간 전압입니다. 단상 220V, 삼상 380·440·480V 중 고르십시오.'),
        ],
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final v in const [220.0, 380.0, 440.0, 480.0])
            _chip('ec_v_${v.toInt()}', '${v.toInt()}V', _volts == v, () {
              setState(() {
                _volts = v;
                if (v == 220) _phase = Phase.single;
              });
            }),
          const SizedBox(width: 8),
          _chip('ec_ph_1', '단상', _phase == Phase.single, () => setState(() => _phase = Phase.single)),
          _chip('ec_ph_3', '삼상', _phase == Phase.three, () => setState(() => _phase = Phase.three)),
        ],
      ),
      const SizedBox(height: 12),
    ],
  );

  Widget _chip(String key, String label, bool sel, VoidCallback onTap) =>
      ChoiceChip(
        key: Key(key),
        label: Text(label),
        selected: sel,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          onTap();
        },
        showCheckmark: false,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          color: sel ? fc.onBrand : fc.text,
        ),
        selectedColor: fc.brand,
        backgroundColor: fc.surface,
        side: BorderSide(color: sel ? fc.brand : fc.line),
      );

  Widget _toggle(String key, String label, VoidCallback onTap) => TextButton(
    key: Key(key),
    onPressed: onTap,
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
  );

  Widget _help(String title, String text) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: () => showModalBottomSheet<void>(
      context: context,
      backgroundColor: fc.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: fc.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                text,
                style: TextStyle(fontSize: 15, color: fc.text, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Icon(Icons.help_outline_rounded, size: 20, color: fc.brand),
    ),
  );

  Widget _box({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
    decoration: BoxDecoration(
      color: fc.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: fc.line),
    ),
    child: child,
  );

  Widget _label(String label, String guide) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: fc.text,
          ),
        ),
      ),
      _help(label, guide),
    ],
  );

  Widget _field(
    String key,
    String label,
    TextEditingController c,
    String guide, {
    Widget? trailing,
  }) => _box(
    child: Row(
      children: [
        Expanded(flex: 5, child: _label(label, guide)),
        Expanded(
          flex: 4,
          child: TextField(
            key: Key(key),
            controller: c,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: fc.text,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        ?trailing,
        if (trailing == null) const SizedBox(width: 8),
      ],
    ),
  );

  Widget _switchRow(
    String label,
    bool v,
    ValueChanged<bool> onChanged,
    String guide, {
    String key = 'ec_motor',
  }) => _box(
    child: Row(
      children: [
        Expanded(child: _label(label, guide)),
        Switch(
          key: Key(key),
          value: v,
          onChanged: onChanged,
        ),
      ],
    ),
  );

  Widget _dropdown<T>(
    String key,
    String label,
    T value,
    List<T> items,
    String Function(T) text,
    ValueChanged<T> onChanged,
    String guide,
  ) => _box(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _label(label, guide),
        ),
        DropdownButton<T>(
          key: Key(key),
          value: value,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          dropdownColor: fc.surface,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: fc.text,
          ),
          items: [
            for (final i in items)
              DropdownMenuItem<T>(value: i, child: Text(text(i))),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    ),
  );

  Widget _result({
    Key? key,
    required String big,
    required String caption,
    required List<String> lines,
    bool warn = false,
  }) => Container(
    key: key,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: warn ? fieldSoft(Colors.red.shade50, (p) => p.danger) : fc.brandSoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: fc.textSub,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          big,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: warn ? fc.danger : fc.brand,
          ),
        ),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '· $l',
              style: TextStyle(fontSize: 13, color: fc.text, height: 1.4),
            ),
          ),
      ],
    ),
  );
}
