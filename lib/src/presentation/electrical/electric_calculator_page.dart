// 전기 계산기(홈 "현장 작업" → 전기 계산기). 480V까지, 발전소·플랜트·시험 설비·제어반.
//
// 탭: 부하 전류(전동기 포함, 전류↔전력 환산) → 전선 굵기(굵기 선정·기존 회로 점검, 차단기·보호도체) →
// 전압강하(교류·직류, 기동 시, 최대 길이) → 전선관(점유율·최소 전선관, elec_conduit_tab.dart) →
// 역률 개선(kvar·μF·전류) → 기초 계산(옴의 법칙·교류 전력·
// Y·Δ·전력량·도체 저항·주파수, elec_basic_tab.dart) → 부스바(DIN 43671 허용전류·굵기 선정,
// elec_busbar_tab.dart). 교류/직류 선택은 부하 전류·전선 굵기·전압강하·부스바 탭이 같이 쓴다.
// 전선 굵기·전압강하 탭은 SQ(mm²)/AWG·kcmil을 고른다(AWG는 NEC 방식, elec_awg_tab.dart).
// 칸마다 "?"로 무슨 값을 어디서 보는지 알려 준다. 숫자는 elec_tables.dart·motor_tables.dart·
// busbar_tables.dart의 출처 있는 표만 쓰고, 결과 아래 "근거 보기"에 어느 표·조건으로 계산했는지 적는다.
// 최종 선정은 설계 도서·제조사 표로 확인한다.
// 넣은 값은 폰에 저장해 두었다가(electric_calc_draft_v1) 다시 열면 채운다.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import 'awg_tables.dart';
import 'basic_calc.dart';
import 'busbar_tables.dart';
import 'conduit_tables.dart';
import 'elec_calc.dart';
import 'elec_tables.dart';
import 'motor_tables.dart';

part 'elec_awg_tab.dart';
part 'elec_basic_tab.dart';
part 'elec_busbar_tab.dart';
part 'elec_conduit_tab.dart';

/// 전선 종류(현장 이름) → 절연체와 쓸 수 있는 공사 방법.
/// HFIX는 제조사(LS·대한전선) 카탈로그가 도체 90°C, 허용전류도 IEC XLPE 90°C 표 값이다.
/// 제어반 내부 배선은 IEC 60204-1 표 6(PVC, 반 내부 40°C)으로 계산한다.
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
  List<double> get sizes => this == WireKind.panel ? kPanelSizes : kCableSizes;
}

/// 부하 종류: 효율·역률 기본값과 전동기 여유를 정한다.
enum LoadType { motor, heater, general }

/// 전류 ↔ 전력 환산 방향.
enum ConvMode { ampToPower, kvaToAmp }

String methodLabel(InstallMethod m) => switch (m) {
  InstallMethod.a1 => '단열벽 속 전선관 (A1)',
  InstallMethod.a2 => '단열벽 속 전선관, 다심 (A2)',
  InstallMethod.b1 => '전선관·덕트 속 절연전선 (B1)',
  InstallMethod.b2 => '전선관·덕트 속 케이블 (B2)',
  InstallMethod.c => '벽에 직접·바닥밀폐형 트레이 (C)',
  InstallMethod.d1 => '지중 관로 (D1)',
  InstallMethod.d2 => '지중 직매 (D2)',
  InstallMethod.e => '펀칭형·사다리형 트레이 (E)',
};

/// 공사 방법 → 다조 포설 보정 행. 트레이(C·E)는 [stacked]면 B.52.17 1행(묶음), 아니면 한 줄 행.
GroupLayout layoutFor(InstallMethod m, {bool stacked = true}) => switch (m) {
  InstallMethod.c =>
    stacked ? GroupLayout.bunched : GroupLayout.wallSingleLayer,
  InstallMethod.e => stacked ? GroupLayout.bunched : GroupLayout.perforatedTray,
  InstallMethod.d1 => GroupLayout.groundDuct,
  InstallMethod.d2 => GroupLayout.groundDirect,
  _ => GroupLayout.bunched,
};

bool isTray(InstallMethod m) => m == InstallMethod.c || m == InstallMethod.e;

String supplyLabel(SupplyType t) => switch (t) {
  SupplyType.lvOther => '저압 수전 · 동력 등 (5%)',
  SupplyType.lvLighting => '저압 수전 · 조명 (3%)',
  SupplyType.hvOther => '고압 이상 수전 · 동력 등 (전체 8%)',
  SupplyType.hvLighting => '고압 이상 수전 · 조명 (전체 6%)',
};

String fmt(double v, [int d = 1]) {
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// 전압강하 탭에서 고를 수 있는 굵기(저항 표에 있는 굵기, 0.75sq부터).
final List<double> kVdSizes = kCuR20.keys.toList()..sort();

/// 교류: 110·220V 단상, 380·440·480V 삼상. 직류: 125VDC(발전소 축전지·제어 전원)가 기본.
const List<double> kAcVolts = [110, 220, 380, 440, 480];
const List<double> kDcVolts = [24, 48, 110, 125, 220];
const double kDcVoltsDefault = 125;

const String _motorSwitchLabel = '전동기 부하 (×1.25, 50A 초과 ×1.1)';
const String _motorSwitchGuide =
    '연속 운전 전동기는 전선 허용전류와 차단기를 정격전류의 1.25배(정격전류가 50A를 넘으면 1.1배)로 '
    '선정하는 것이 관례입니다(구 내선규정 방식, LS ELECTRIC MCCB 선정 자료). 미국 NEC 430.22는 늘 1.25배입니다.\n'
    'KEC에는 이 배수가 없으니 설계 기준을 따르십시오. 전압강하는 실제 전류로 계산합니다.';

class ElectricCalculatorPage extends StatefulWidget {
  const ElectricCalculatorPage({super.key});

  /// 넣은 값을 저장하는 폰 저장 칸.
  static const draftKey = 'electric_calc_draft_v1';

  @override
  State<ElectricCalculatorPage> createState() => _ElectricCalculatorPageState();
}

class _ElectricCalculatorPageState extends State<ElectricCalculatorPage>
    with SingleTickerProviderStateMixin, CalcFormParts {
  late final TabController _tabs = TabController(length: 7, vsync: this);

  // 공통
  double _volts = 380;
  Phase _phase = Phase.three;
  SupplyType _supply = SupplyType.lvOther;
  // 교류/직류: 부하 전류·전선 굵기·전압강하·부스바 탭이 같이 쓴다.
  bool _dc = false;
  double _dcVolts = kDcVoltsDefault;
  // 굵기 단위 SQ/AWG: 전선 굵기·전압강하 탭이 같이 쓴다(AWG는 elec_awg_tab.dart).
  bool _awg = false;
  NecColumn _awgCol = NecColumn.c90;
  NecTerminal _awgTerm = NecTerminal.auto;
  final _awgAmb = TextEditingController(text: '30');
  final _awgCcc = TextEditingController(text: '3');
  String _awgChk = '12 AWG';
  String _vdAwg = '12 AWG';

  // ① 부하 전류
  LoadType _loadType = LoadType.motor;
  final _kw = TextEditingController();
  bool _hp = false;
  final _eff = TextEditingController(text: '90');
  final _pf = TextEditingController(text: '85');
  bool _motor = true;
  ConvMode _conv = ConvMode.ampToPower;
  final _convVal = TextEditingController();

  // ② 전선 굵기
  bool _checkMode = false;
  final _ib = TextEditingController();
  bool _cableMotor = true; // 차단기·허용전류에 ×1.25(50A 초과 ×1.1)
  WireKind _kind = WireKind.fcv;
  InstallMethod _method = InstallMethod.e;
  bool _stacked = true; // 트레이에 겹쳐 쌓음(묶음): 안전 쪽 기본
  final _ambient = TextEditingController(text: '30');
  bool _ambientEdited = false;
  final _circuits = TextEditingController(text: '1');
  int _parallel = 1;
  final _length = TextEditingController(text: '50');
  final _pf2 = TextEditingController(text: '85');
  double _chkSize = 2.5;
  final _chkBreaker = TextEditingController();

  // ③ 전압강하
  double _vdSize = 4;
  WireKind _vdKind = WireKind.fcv;
  final _vdI = TextEditingController();
  final _vdLen = TextEditingController(text: '50');
  final _vdPf = TextEditingController(text: '85');
  bool _vdStart = false;
  final _vdMult = TextEditingController(text: fmt(kMotorStartMultipleDefault));

  // 전선관(elec_conduit_tab.dart)
  ConduitKind _cdKind = ConduitKind.thick;
  FillRule _cdRule = FillRule.naesun;
  int _cdSize = 22;
  bool _cdEasy = false; // 내선규정 48%(같은 굵기 절연전선, 굴곡이 적어 쉽게 인출)
  final List<_CdRow> _cdRows = [_CdRow(CableKind.hfix, 2.5, '3')];

  // ④ 역률
  final _pcKw = TextEditingController();
  final _pcNow = TextEditingController(text: '80');
  final _pcTarget = TextEditingController(text: '95');

  // ⑤ 기초 계산
  BasicSection _bsSec = BasicSection.ohm;
  final _ohmV = TextEditingController();
  final _ohmI = TextEditingController();
  final _ohmR = TextEditingController();
  final _ohmP = TextEditingController();
  bool _acThree = true;
  bool _acFromKw = false;
  final _acV = TextEditingController(text: '380');
  final _acI = TextEditingController();
  final _acKw = TextEditingController();
  final _acPf = TextEditingController(text: '85');
  bool _ydStar = true;
  bool _ydFromLine = true;
  final _ydV = TextEditingController();
  final _ydI = TextEditingController();
  final _enKw = TextEditingController();
  final _enHours = TextEditingController(text: '24');
  final _enDays = TextEditingController(text: '30');
  final _enPrice = TextEditingController();
  ConductorMetal _rsMetal = ConductorMetal.copper;
  final _rsArea = TextEditingController();
  final _rsLen = TextEditingController();
  final _rsTemp = TextEditingController(text: '20');
  final _rs1 = TextEditingController();
  final _rs2 = TextEditingController();
  final _rs3 = TextEditingController();
  final _hzF = TextEditingController(text: '60');
  final _hzPoles = TextEditingController(text: '4');
  final _hzRpm = TextEditingController();
  final _hzL = TextEditingController();
  final _hzC = TextEditingController();

  // ⑥ 부스바
  bool _busPick = false;
  bool _busPainted = false; // 도장 안 함이 기본(값이 작은 쪽)
  int _busBars = 1;
  BusbarRow _busRow = kBusbars.firstWhere((r) => r.label == '40×10');
  final _busI = TextEditingController();
  final _busMargin = TextEditingController(text: '0');

  // 저장
  Timer? _saveTimer;
  bool _draftReady = false;
  String? _lastDraft;
  String? _pendingDraft;

  /// 숫자 칸과 저장 이름.
  late final List<(TextEditingController, String)> _texts = [
    (_kw, 'kw'),
    (_eff, 'eff'),
    (_pf, 'pf'),
    (_convVal, 'convVal'),
    (_ib, 'ib'),
    (_ambient, 'amb'),
    (_circuits, 'circ'),
    (_length, 'len'),
    (_pf2, 'pf2'),
    (_chkBreaker, 'chkBrk'),
    (_vdI, 'vdI'),
    (_vdLen, 'vdLen'),
    (_vdPf, 'vdPf'),
    (_vdMult, 'vdMult'),
    (_pcKw, 'pcKw'),
    (_pcNow, 'pcNow'),
    (_pcTarget, 'pcTarget'),
    (_ohmV, 'ohmV'),
    (_ohmI, 'ohmI'),
    (_ohmR, 'ohmR'),
    (_ohmP, 'ohmP'),
    (_acV, 'acV'),
    (_acI, 'acI'),
    (_acKw, 'acKw'),
    (_acPf, 'acPf'),
    (_ydV, 'ydV'),
    (_ydI, 'ydI'),
    (_enKw, 'enKw'),
    (_enHours, 'enH'),
    (_enDays, 'enD'),
    (_enPrice, 'enPrice'),
    (_rsArea, 'rsA'),
    (_rsLen, 'rsL'),
    (_rsTemp, 'rsT'),
    (_rs1, 'rs1'),
    (_rs2, 'rs2'),
    (_rs3, 'rs3'),
    (_hzF, 'hzF'),
    (_hzPoles, 'hzP'),
    (_hzRpm, 'hzN'),
    (_hzL, 'hzL'),
    (_hzC, 'hzC'),
    (_busI, 'busI'),
    (_busMargin, 'busM'),
    (_awgAmb, 'awgAmb'),
    (_awgCcc, 'awgCcc'),
  ];

  List<TextEditingController> get _controllers => [
    for (final (c, _) in _texts) c,
  ];

  /// 탭 파일(elec_basic_tab.dart·elec_busbar_tab.dart)에서 화면을 다시 그릴 때 쓴다.
  void _set(VoidCallback f) => setState(f);

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _flushDraft();
    _tabs.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    _disposeConduitRows();
    super.dispose();
  }

  // ─────────────── 저장(넣은 값 남기기) ───────────────

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(ElectricCalculatorPage.draftKey);
      if (raw != null && mounted) {
        final m = jsonDecode(raw);
        if (m is Map<String, dynamic>) setState(() => _applyDraft(m));
      }
      _lastDraft = raw;
    } catch (_) {
      // 저장 칸을 못 읽어도 계산기는 기본값으로 쓴다.
    }
    _draftReady = true;
  }

  Map<String, Object?> _draft() => {
    'v': _volts,
    'ph': _phase.name,
    'sup': _supply.name,
    'dc': _dc,
    'dcV': _dcVolts,
    'lt': _loadType.name,
    'hp': _hp,
    'motor': _motor,
    'conv': _conv.name,
    'check': _checkMode,
    'cm': _cableMotor,
    'kind': _kind.name,
    'method': _method.name,
    'stacked': _stacked,
    'ambEd': _ambientEdited,
    'par': _parallel,
    'chkSize': _chkSize,
    'vdSize': _vdSize,
    'vdKind': _vdKind.name,
    'vdStart': _vdStart,
    'bsSec': _bsSec.name,
    'acThree': _acThree,
    'acFromKw': _acFromKw,
    'ydStar': _ydStar,
    'ydLine': _ydFromLine,
    'rsMetal': _rsMetal.name,
    'busPick': _busPick,
    'busPainted': _busPainted,
    'busBars': _busBars,
    'busSize': _busRow.label,
    'awg': _awg,
    'awgCol': _awgCol.name,
    'awgTerm': _awgTerm.name,
    'awgChk': _awgChk,
    'vdAwg': _vdAwg,
    ..._conduitDraft(),
    for (final (c, k) in _texts) k: c.text,
  };

  void _applyDraft(Map<String, dynamic> m) {
    T en<T extends Enum>(List<T> vs, String k, T d) =>
        vs.firstWhere((v) => v.name == m[k], orElse: () => d);
    bool b(String k, bool d) => m[k] is bool ? m[k] as bool : d;
    double n(String k, double d) => m[k] is num ? (m[k] as num).toDouble() : d;
    void t(TextEditingController c, String k) {
      if (m[k] is String) c.text = m[k] as String;
    }

    final v = n('v', _volts);
    if (kAcVolts.contains(v)) _volts = v;
    _phase = en([Phase.single, Phase.three], 'ph', _phase);
    _supply = en(SupplyType.values, 'sup', _supply);
    _loadType = en(LoadType.values, 'lt', _loadType);
    _hp = b('hp', _hp);
    _motor = b('motor', _motor);
    _conv = en(ConvMode.values, 'conv', _conv);
    _checkMode = b('check', _checkMode);
    _cableMotor = b('cm', _cableMotor);
    _kind = en(WireKind.values, 'kind', _kind);
    final method = en(InstallMethod.values, 'method', _method);
    _method = _kind.methods.contains(method) ? method : _kind.methods.first;
    _stacked = b('stacked', _stacked);
    _ambientEdited = b('ambEd', _ambientEdited);
    final par = n('par', 1).round();
    _parallel = par.clamp(1, 4);
    final chk = n('chkSize', _chkSize);
    _chkSize = _kind.sizes.contains(chk) ? chk : _chkSize;
    // 교류/직류: 예전 저장 칸(전압강하 탭 vdDc·vdDcV)도 읽는다.
    _dc = b('dc', b('vdDc', _dc));
    final dcv = n('dcV', n('vdDcV', _dcVolts));
    if (kDcVolts.contains(dcv)) _dcVolts = dcv;
    final vds = n('vdSize', _vdSize);
    if (kVdSizes.contains(vds)) _vdSize = vds;
    _vdKind = en(WireKind.values, 'vdKind', _vdKind);
    _vdStart = b('vdStart', _vdStart);
    _bsSec = en(BasicSection.values, 'bsSec', _bsSec);
    _acThree = b('acThree', _acThree);
    _acFromKw = b('acFromKw', _acFromKw);
    _ydStar = b('ydStar', _ydStar);
    _ydFromLine = b('ydLine', _ydFromLine);
    _rsMetal = en(ConductorMetal.values, 'rsMetal', _rsMetal);
    _busPick = b('busPick', _busPick);
    _busPainted = b('busPainted', _busPainted);
    _busBars = n('busBars', _busBars.toDouble()).round().clamp(1, 4);
    _busRow = kBusbars.firstWhere(
      (r) => r.label == m['busSize'],
      orElse: () => _busRow,
    );
    _awg = b('awg', _awg);
    _awgCol = en(NecColumn.values, 'awgCol', _awgCol);
    _awgTerm = en(NecTerminal.values, 'awgTerm', _awgTerm);
    if (awgByLabel(m['awgChk'] as String?)?.a60 != null) {
      _awgChk = m['awgChk'] as String;
    }
    if (awgByLabel(m['vdAwg'] as String?) != null) {
      _vdAwg = m['vdAwg'] as String;
    }
    _applyConduitDraft(m);
    for (final (c, k) in _texts) {
      t(c, k);
    }
  }

  /// 값이 바뀌었으면 잠시 뒤 저장한다(build 끝에서 부른다).
  void _scheduleSave() {
    if (!_draftReady) return;
    final raw = jsonEncode(_draft());
    if (raw == _lastDraft || raw == _pendingDraft) return;
    _pendingDraft = raw;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _flushDraft);
  }

  void _flushDraft() {
    final raw = _pendingDraft;
    if (raw == null) return;
    _pendingDraft = null;
    _lastDraft = raw;
    _writeDraft(raw);
  }

  static Future<void> _writeDraft(String raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ElectricCalculatorPage.draftKey, raw);
    } catch (_) {
      // 저장을 못 해도 계산에는 지장이 없다.
    }
  }

  // ─────────────── 입력 읽기 ───────────────

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', ''));

  /// % 칸 읽기. 비었거나 0이면 기본값과 알림 글.
  double _pctOf(
    TextEditingController c,
    double dflt,
    String name,
    List<String> notes,
  ) {
    final v = _num(c);
    if (v == null || v <= 0) {
      notes.add('$name 값이 없어 ${fmt(dflt * 100)}%로 계산했습니다.');
      return dflt;
    }
    return (v > 1 ? v / 100 : v).clamp(0.01, 1.0);
  }

  bool _anyNegative(List<TextEditingController> cs) =>
      cs.any((c) => (_num(c) ?? 0) < 0);

  Widget _negativeResult(String key) => calcResult(
    key: Key(key),
    big: '입력 확인',
    caption: '음수는 넣을 수 없습니다',
    warn: true,
    lines: const ['0보다 큰 값을 넣으십시오.'],
  );

  double get _defaultAmbient => _kind == WireKind.panel
      ? 40
      : isGround(_method)
      ? 20
      : 30;

  /// 사용자가 온도를 직접 넣지 않았으면 표 기준 온도로 맞춘다(지중 20°C, 반 내부 40°C, 공기 30°C).
  void _syncAmbient() {
    if (!_ambientEdited) _ambient.text = fmt(_defaultAmbient);
  }

  /// 전동기면 50A 이하 1.25배, 넘으면 1.1배. 아니면 여유 없음.
  double _marginFor(double load, bool motor) => motor ? motorMargin(load) : 1;

  String _marginText(double load) {
    final m = motorMargin(load);
    return m == 1.25 ? '×1.25' : '×1.1, 50A 초과';
  }

  /// 부하 전류·전선 굵기·전압강하 탭의 회로(직류면 Phase.dc)와 전압.
  Phase get _cph => _dc ? Phase.dc : _phase;
  double get _cv => _dc ? _dcVolts : _volts;

  // ─────────────── 계산: 부하 전류 ───────────────

  double? _loadCurrent(List<String> notes) {
    final p = _num(_kw);
    if (p == null || p <= 0) return null;
    return loadCurrent(
      kw: _hp ? hpToKw(p) : p,
      volts: _cv,
      phase: _cph,
      // 직류는 역률이 없다: I = P ÷ (V × 효율).
      pf: _dc ? 1 : _pctOf(_pf, 0.85, '역률', notes),
      eff: _pctOf(_eff, 0.9, '효율', notes),
    );
  }

  /// 표 값 참고 줄: 440·480V·230V HP면 NEC 430.250, 380·440V 삼상 kW면 IE3 전동기 예시.
  String? _tableHint() {
    final p = _num(_kw);
    if (p == null ||
        _dc ||
        _phase != Phase.three ||
        _loadType != LoadType.motor) {
      return null;
    }
    if (_hp) {
      final r = necRow(p);
      if (r == null) return null;
      if (_volts >= 440) {
        return 'NEC 430.250 표 (460V) ${fmt(r.a460)} A. 미국 기준(NEC 430.6)은 전선·차단기를 이 표 값으로 선정합니다.';
      }
      if (_volts == 220) {
        return 'NEC 430.250 표 (230V) ${fmt(r.a230)} A';
      }
      return null;
    }
    if (_volts == 380 || _volts == 440) {
      final r = ie3Row(p);
      if (r == null) return null;
      final a = _volts == 380 ? r.a380 : r.a440;
      return '참고: HD현대일렉트릭 IE3 4극 ${_volts.toInt()}V 전동기 ${fmt(a, 2)} A '
          '(효율 ${fmt(r.eff)}%, 역률 ${fmt(r.pf * 100)}%)';
    }
    return null;
  }

  void _setLoadType(LoadType t) => setState(() {
    _loadType = t;
    switch (t) {
      case LoadType.motor:
        _eff.text = '90';
        _pf.text = '85';
        _motor = true;
      case LoadType.heater:
        _eff.text = '100';
        _pf.text = '100';
        _motor = false;
        _hp = false;
      case LoadType.general:
        _eff.text = '100';
        _pf.text = '85';
        _motor = false;
        _hp = false;
    }
  });

  void _sendToCable() {
    final i = _loadCurrent([]);
    if (i == null) return;
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _ib.text = fmt(i, 1);
      _cableMotor = _motor;
      _pf2.text = _pf.text;
      _checkMode = false;
    });
    _tabs.animateTo(1);
  }

  // ─────────────── 그리기 ───────────────

  @override
  Widget build(BuildContext context) {
    _scheduleSave();
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
              '전기 설계 계산',
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
                Tab(key: Key('ec_tab_conduit'), text: '전선관'),
                Tab(key: Key('ec_tab_pf'), text: '역률 개선'),
                Tab(key: Key('ec_tab_basic'), text: '기초 계산'),
                Tab(key: Key('ec_tab_bus'), text: '부스바'),
              ],
            ),
          ),
          body: SafeArea(
            child: TabBarView(
              controller: _tabs,
              children: [
                _loadTab(),
                _cableTab(),
                _vdTab(),
                _conduitTab(),
                _pfTab(),
                _basicTab(),
                _busTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 탭 몸통: 위에 결과 요약 줄(고정), 아래 입력·결과 목록.
  Widget _page(
    List<Widget> children, {
    required String sumKey,
    String? summary,
    bool warn = false,
  }) => GestureDetector(
    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
    behavior: HitTestBehavior.translucent,
    child: Column(
      children: [
        if (summary != null)
          Container(
            key: Key(sumKey),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: warn
                  ? fieldSoft(Colors.red.shade50, (p) => p.danger)
                  : fc.brandSoft,
              border: Border(bottom: BorderSide(color: fc.line)),
            ),
            child: Text(
              summary,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: warn ? fc.danger : fc.brand,
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: children,
          ),
        ),
      ],
    ),
  );

  /// 숫자 칸(calcField와 같은 모양, 키보드 "다음"으로 다음 칸).
  Widget _field(
    String key,
    String label,
    TextEditingController c,
    String guide, {
    VoidCallback? onEdit,
    bool signed = false,
  }) => calcBox(
    child: Row(
      children: [
        Expanded(flex: 5, child: calcLabel(label, guide)),
        Expanded(
          flex: 4,
          child: TextField(
            key: Key(key),
            controller: c,
            textAlign: TextAlign.right,
            keyboardType: TextInputType.numberWithOptions(
              decimal: true,
              signed: signed,
            ),
            textInputAction: TextInputAction.next,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: fc.text,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
            ),
            onChanged: (_) {
              onEdit?.call();
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
  );

  /// 이름표 + 칩 한 줄.
  Widget _chipGroup(String label, String guide, List<Widget> chips) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        calcLabel(label, guide),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 6, children: chips),
      ],
    ),
  );

  /// 접었다 펴는 "근거 보기".
  Widget _basis(String key, List<String> lines) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      key: Key(key),
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      iconColor: fc.brand,
      collapsedIconColor: fc.textSub,
      title: Text(
        '근거 보기',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: fc.text,
        ),
      ),
      children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '· $l',
              style: TextStyle(fontSize: 13, color: fc.text, height: 1.4),
            ),
          ),
      ],
    ),
  );

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: fc.text,
      ),
    ),
  );

  // ① 부하 전류
  Widget _loadTab() {
    final negative = _anyNegative([_kw, _eff, _pf, _convVal]);
    final notes = <String>[];
    final i = negative ? null : _loadCurrent(notes);
    final margin = i == null ? 1.0 : _marginFor(i, _motor);
    String? summary;
    if (i != null) {
      summary = _motor
          ? '${fmt(i, 1)} A · 설계전류 ${fmt(i * margin, 1)} A (${_marginText(i)})'
          : '${fmt(i, 1)} A';
    }
    return _page(sumKey: 'ec_sum_load', summary: summary, [
      _systemPicker('ec_load'),
      _chipGroup(
        '부하 종류',
        '전동기: 효율 90%·역률 85%로 두고 전동기 여유를 켭니다.\n'
            '히터·저항: 효율·역률 100%로 둡니다. 전부 열로 쓰는 부하입니다.\n'
            '일반: 소비 전력(kW)을 넣는 부하입니다. 효율 100%·역률 85%로 둡니다.\n'
            '직류 회로는 역률을 쓰지 않습니다. 직류 전동기도 효율은 계산에 넣습니다.\n'
            '명판 값이 있으면 칸에 직접 넣으십시오.',
        [
          calcChip('ec_lt_motor', '전동기', _loadType == LoadType.motor, () {
            _setLoadType(LoadType.motor);
          }),
          calcChip('ec_lt_heater', '히터·저항', _loadType == LoadType.heater, () {
            _setLoadType(LoadType.heater);
          }),
          calcChip('ec_lt_general', '일반', _loadType == LoadType.general, () {
            _setLoadType(LoadType.general);
          }),
        ],
      ),
      _chipGroup(
        '출력 단위',
        '명판 출력의 단위입니다. 미국식 명판(HP)이면 HP를 누르십시오. 1 HP = 0.746 kW로 계산합니다.',
        [
          calcChip('ec_unit_kw', 'kW', !_hp, () => setState(() => _hp = false)),
          calcChip('ec_hp', 'HP', _hp, () => setState(() => _hp = true)),
        ],
      ),
      _field(
        'ec_kw',
        _hp ? '출력 (HP)' : '출력 (kW)',
        _kw,
        '전동기 명판의 정격 출력(축 출력)입니다. 히터·일반 부하는 소비 전력을 넣으십시오.',
      ),
      _field(
        'ec_eff',
        '효율 (%)',
        _eff,
        '명판의 효율(EFF, η)입니다. 모르면 90으로 두십시오. 히터처럼 전부 열로 쓰는 부하는 100입니다.',
      ),
      if (!_dc)
        _field(
          'ec_pf',
          '역률 (%)',
          _pf,
          '명판의 역률(P.F., cosφ)입니다. 모르면 85로 두십시오. 히터는 100입니다.',
        ),
      calcSwitch(
        _motorSwitchLabel,
        _motor,
        (v) => setState(() => _motor = v),
        _motorSwitchGuide,
        key: 'ec_motor',
      ),
      const SizedBox(height: 12),
      if (negative)
        _negativeResult('ec_load_result')
      else
        calcResult(
          key: const Key('ec_load_result'),
          big: i == null ? '— A' : '${fmt(i, 1)} A',
          caption: _dc ? '정격전류(계산값, 직류)' : '정격전류(계산값)',
          lines: [
            if (i != null && _motor)
              '차단기·전선은 ${fmt(i * margin, 1)} A (${_marginText(i)}) 기준',
            ?_tableHint(),
            if (i != null) '명판 정격전류가 있으면 그 값을 우선 적용하십시오.',
            ...notes,
          ],
        ),
      _basis('ec_load_basis', [
        _dc
            ? '식: I = P ÷ (V × 효율) (직류, 역률 없음)'
            : '식: I = P ÷ (${_phase == Phase.three ? '√3 × ' : ''}V × 역률 × 효율)',
        if (_hp) '1 HP = 0.7457 kW',
        if (_motor)
          '전동기 여유: 정격전류 50A 이하 1.25배, 50A 초과 1.1배(LS ELECTRIC MCCB 선정 자료 A1-124, 구 내선규정 방식). '
              'NEC 430.22는 1.25배. KEC에는 없습니다.',
      ]),
      const SizedBox(height: 8),
      FilledButton.icon(
        key: const Key('ec_to_cable'),
        onPressed: i == null ? null : _sendToCable,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('이 전류로 전선 굵기 선정'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: fc.brand,
        ),
      ),
      const SizedBox(height: 24),
      _sectionTitle('전류 ↔ 전력 환산'),
      _chipGroup(
        '환산 방향',
        _dc
            ? '전류(A) → 전력: 직류는 P = V × I입니다.\n'
                  '전력(kW) → 전류: 직류 부하·충전기 용량으로 전류를 계산합니다.\n'
                  '전압은 맨 위 선택을 따릅니다.'
            : '전류(A) → 전력: 측정한 전류로 피상전력(kVA)과 유효전력(kW)을 계산합니다. 역률은 위 칸 값을 씁니다.\n'
                  '피상전력(kVA) → 전류: 변압기·발전기 용량으로 정격전류를 계산합니다.\n'
                  '전압·단상·삼상은 맨 위 선택을 따릅니다.',
        [
          calcChip(
            'ec_conv_a',
            '전류 → 전력',
            _conv == ConvMode.ampToPower,
            () => setState(() => _conv = ConvMode.ampToPower),
          ),
          calcChip(
            'ec_conv_kva',
            _dc ? 'kW → 전류' : 'kVA → 전류',
            _conv == ConvMode.kvaToAmp,
            () => setState(() => _conv = ConvMode.kvaToAmp),
          ),
        ],
      ),
      _field(
        'ec_conv_val',
        _conv == ConvMode.ampToPower
            ? '전류 (A)'
            : (_dc ? '전력 (kW)' : '피상전력 (kVA)'),
        _convVal,
        _conv == ConvMode.ampToPower
            ? '클램프 미터로 측정한 전류나 명판 전류입니다.'
            : (_dc
                  ? '직류 부하의 소비 전력이나 충전기 출력(kW)입니다.'
                  : '변압기·발전기·UPS 명판의 용량(kVA)입니다.'),
      ),
      _convResult(negative),
    ]);
  }

  Widget _convResult(bool negative) {
    if (negative) return _negativeResult('ec_conv_result');
    final v = _num(_convVal);
    if (_dc) return _convResultDc(v);
    final k = _phase == Phase.three ? '√3 × ' : '';
    if (_conv == ConvMode.ampToPower) {
      final notes = <String>[];
      final pf = _pctOf(_pf, 0.85, '역률', notes);
      final kva = v == null || v <= 0
          ? null
          : kvaFromCurrent(current: v, volts: _volts, phase: _phase);
      final eff = _pctOf(_eff, 0.9, '효율', []);
      return calcResult(
        key: const Key('ec_conv_result'),
        big: kva == null ? '— kVA' : '${fmt(kva, 1)} kVA',
        caption: '피상전력',
        lines: [
          if (kva != null) '유효전력 ${fmt(kva * pf, 1)} kW (역률 ${fmt(pf * 100)}%)',
          if (kva != null && _loadType == LoadType.motor)
            '전동기 축 출력 약 ${fmt(kva * pf * eff, 1)} kW (효율 ${fmt(eff * 100)}%)',
          if (kva != null) ...notes,
          '식: S = ${k}V × I ÷ 1000, P = S × 역률',
        ],
      );
    }
    final a = v == null || v <= 0
        ? null
        : currentFromKva(kva: v, volts: _volts, phase: _phase);
    return calcResult(
      key: const Key('ec_conv_result'),
      big: a == null ? '— A' : '${fmt(a, 1)} A',
      caption: '정격전류',
      lines: ['식: I = S × 1000 ÷ (${k}V)'],
    );
  }

  /// 직류 전류 ↔ 전력: P = V × I.
  Widget _convResultDc(double? v) {
    final ok = v != null && v > 0;
    if (_conv == ConvMode.ampToPower) {
      final kw = ok ? _dcVolts * v / 1000 : null;
      final eff = _pctOf(_eff, 0.9, '효율', []);
      return calcResult(
        key: const Key('ec_conv_result'),
        big: kw == null ? '— kW' : '${fmt(kw, 2)} kW',
        caption: '전력(직류 ${_dcVolts.toInt()}V)',
        lines: [
          if (kw != null && _loadType == LoadType.motor)
            '전동기 축 출력 약 ${fmt(kw * eff, 2)} kW (효율 ${fmt(eff * 100)}%)',
          '식: P = V × I ÷ 1000 (직류)',
        ],
      );
    }
    final a = ok ? v * 1000 / _dcVolts : null;
    return calcResult(
      key: const Key('ec_conv_result'),
      big: a == null ? '— A' : '${fmt(a, 1)} A',
      caption: '전류(직류 ${_dcVolts.toInt()}V)',
      lines: const ['식: I = P × 1000 ÷ V (직류)'],
    );
  }

  // ② 전선 굵기: 굵기 선정 / 기존 회로 점검
  Widget _cableTab() {
    if (_awg) return _awgCableTab();
    final negative = _anyNegative([
      _ib,
      _ambient,
      _circuits,
      _length,
      _pf2,
      _chkBreaker,
    ]);
    final notes = <String>[];
    final ibIn = _num(_ib);
    final load = ibIn == null || ibIn <= 0 ? null : ibIn;
    final ambIn = _num(_ambient);
    final amb = ambIn ?? _defaultAmbient;
    if (ambIn == null) {
      notes.add('${_ambientLabel()} 값이 없어 ${fmt(amb)}°C로 계산했습니다.');
    }
    final nIn = _num(_circuits);
    final n = nIn == null || nIn < 1 ? 1 : nIn.round();
    final lenIn = _num(_length);
    final len = lenIn == null || lenIn <= 0 ? null : lenIn;
    final pfNotes = <String>[];
    final pf = _dc ? 1.0 : _pctOf(_pf2, 0.85, '역률', pfNotes);
    if (len != null && load != null) notes.addAll(pfNotes);
    final layout = layoutFor(_method, stacked: _stacked);
    final margin = load == null ? 1.0 : _marginFor(load, _cableMotor);

    Widget result;
    String? summary;
    var warn = false;
    List<String> basis;
    if (negative) {
      result = _negativeResult('ec_cable_result');
      basis = const [];
    } else if (_checkMode) {
      final brIn = _num(_chkBreaker);
      final k = checkCircuit(
        size: _chkSize,
        load: load,
        margin: margin,
        breaker: brIn == null || brIn <= 0 ? null : brIn.round(),
        volts: _cv,
        phase: _cph,
        ins: _kind.insulation,
        method: _method,
        lengthM: len,
        pf: pf,
        ambientC: amb,
        circuits: n,
        parallel: _parallel,
        layout: layout,
        supply: _supply,
        table: _kind.table,
        motor: _cableMotor,
      );
      final r = _checkResult(k, notes, amb, n);
      result = r.$1;
      summary = r.$2;
      warn = r.$3;
      basis = r.$4;
    } else if (load == null) {
      result = calcResult(
        key: const Key('ec_cable_result'),
        big: '—',
        caption: '부하 전류를 넣으면 굵기를 선정합니다',
        lines: const [],
      );
      basis = const [];
    } else {
      final c = chooseCable(
        load: load,
        margin: margin,
        volts: _cv,
        phase: _cph,
        ins: _kind.insulation,
        method: _method,
        lengthM: len,
        pf: pf,
        ambientC: amb,
        circuits: n,
        parallel: _parallel,
        layout: layout,
        supply: _supply,
        table: _kind.table,
        motor: _cableMotor,
      );
      final r = _cableResult(c, notes, amb, n);
      result = r.$1;
      summary = r.$2;
      warn = r.$3;
      basis = r.$4;
    }
    final ground = isGround(_method);
    return _page(sumKey: 'ec_sum_cable', summary: summary, warn: warn, [
      _systemPicker('ec_cable'),
      _unitPicker('ec_cable'),
      _chipGroup(
        '할 일',
        '굵기 선정: 부하 전류로 전선 굵기·차단기를 선정합니다. 직류는 차단기 정격을 선정하지 않고 '
            '허용전류 ≥ 설계전류로 굵기를 선정합니다.\n'
            '기존 회로 점검: 포설되어 있는 전선 굵기와 차단기로 보정 후 허용전류를 계산하고 '
            'IB ≤ In ≤ IZ(KEC 212.4.1)를 점검합니다.',
        [
          calcChip('ec_mode_select', '굵기 선정', !_checkMode, () {
            setState(() => _checkMode = false);
          }),
          calcChip('ec_mode_check', '기존 회로 점검', _checkMode, () {
            setState(() => _checkMode = true);
          }),
        ],
      ),
      if (_checkMode)
        calcDropdown<double>(
          'ec_chk_size',
          '전선 굵기',
          _chkSize,
          _kind.sizes,
          sqText,
          (s) => setState(() => _chkSize = s),
          '포설되어 있거나 포설할 전선의 굵기(sq = mm²)입니다. 병렬이면 한 가닥의 굵기입니다.',
        ),
      _field(
        'ec_ib',
        _checkMode ? '부하 전류 (A, 선택)' : '부하 전류 (A)',
        _ib,
        _checkMode
            ? '부하 전류를 넣으면 IB ≤ In ≤ IZ와 전압강하를 점검합니다. 비워 두면 허용전류만 보입니다.'
            : '이 회로에 실제로 흐르는 전류입니다. 명판 전류나 "부하 전류" 탭의 결과를 넣으십시오. '
                  '전동기 여유는 아래 스위치로 넣습니다.',
      ),
      calcSwitch(
        _motorSwitchLabel,
        _cableMotor,
        (v) => setState(() => _cableMotor = v),
        _motorSwitchGuide,
        key: 'ec_cable_motor',
      ),
      if (_checkMode)
        _field(
          'ec_chk_breaker',
          '차단기 정격 (A, 선택)',
          _chkBreaker,
          '설치된 차단기(MCCB)의 정격전류(In)입니다. 비워 두면 설계전류와 허용전류만 비교합니다.',
        ),
      calcDropdown<WireKind>(
        'ec_kind',
        '전선 종류',
        _kind,
        WireKind.values,
        (k) => k.label,
        (k) => setState(() {
          _kind = k;
          if (!k.methods.contains(_method)) _method = k.methods.first;
          if (!k.sizes.contains(_chkSize)) _chkSize = 2.5;
          _syncAmbient();
        }),
        'F-CV: 동력용 0.6/1kV 케이블(XLPE, 90°C).\n'
            'HFIX: 450/750V 저독성 난연 전선(KS C 3341). 도체 90°C(LS·대한전선 카탈로그). 전선관·덕트 속에 넣습니다.\n'
            'IV·PVC 전선: 도체 70°C. 전선 표시를 모르면 이것으로 계산하면 안전합니다.\n'
            '제어반 내부 배선: 반 내부 배선 덕트·배선에 IEC 60204-1 표 6(PVC, 반 내부 40°C)으로 계산합니다. 0.75sq부터.',
      ),
      calcDropdown<InstallMethod>(
        'ec_method',
        '공사 방법',
        _method,
        _kind.methods,
        methodLabel,
        (m) => setState(() {
          _method = m;
          _syncAmbient();
        }),
        '케이블 포설 방법입니다(KS C IEC 60364-5-52).\n'
            '· 펀칭형·사다리형 트레이(E): 케이블 트레이 위\n'
            '· 벽에 직접·바닥밀폐형 트레이(C): 새들로 벽·구조물에 고정하거나 바닥이 막힌 트레이\n'
            '· 전선관·덕트 속(B1·B2)\n· 지중 관로(D1)·지중 직매(D2)',
      ),
      if (isTray(_method) && _kind != WireKind.panel)
        _chipGroup(
          '트레이 포설 모양',
          '트레이 위 케이블을 한 줄로 나란히(서로 닿게) 포설하면 "한 줄 포설", 여러 겹으로 쌓거나 '
              '다발로 묶으면 "겹쳐 쌓음(묶음)"입니다.\n'
              '겹쳐 쌓음은 KS C IEC 60364-5-52 표 B.52.17 1행(다발·표면·밀폐), 한 줄은 2행(벽·바닥밀폐형 트레이)·'
              '4행(펀칭형 트레이) 값을 씁니다(Schneider EIG 그림 G16).\n'
              '현장 트레이는 겹쳐 쌓이는 경우가 많아 겹쳐 쌓음을 기본으로 둡니다(안전 쪽). 회로가 1개면 결과가 같습니다.',
          [
            calcChip('ec_lay_single', '한 줄 포설', !_stacked, () {
              setState(() => _stacked = false);
            }),
            calcChip('ec_lay_stacked', '겹쳐 쌓음(묶음)', _stacked, () {
              setState(() => _stacked = true);
            }),
          ],
        ),
      _field(
        'ec_ambient',
        '${_ambientLabel()} (°C)',
        _ambient,
        ground
            ? '매설 깊이의 지중 온도입니다. 모르면 20으로 두십시오(표 기준).'
            : _kind == WireKind.panel
            ? '반 내부 온도입니다. IEC 60204-1 표 6 기준은 40°C입니다. 40°C 미만은 현행 표 D.1에 없어 '
                  '1.0으로 계산합니다(안전 쪽).'
            : '케이블 주위 온도입니다. 표 기준은 30°C입니다. 보일러·터빈 건물처럼 더운 곳은 40~50을 넣으십시오.',
        onEdit: () => _ambientEdited = _ambient.text.trim().isNotEmpty,
      ),
      _field(
        'ec_circuits',
        ground ? '같은 관로·트렌치의 회로 수' : '같이 포설된 회로 수',
        _circuits,
        '같은 트레이·같은 관·같은 묶음에 나란히 있는 회로(케이블) 수입니다. 이 회로를 포함해 넣으십시오. '
            '많을수록 열이 빠지지 않아 허용전류가 줄어듭니다(다조 포설 보정). 20회로를 넘으면 표 끝 20회로 값을 씁니다.',
      ),
      _chipGroup(
        '병렬 가닥 수',
        '한 회로를 같은 굵기 케이블 여러 가닥으로 나눠 포설할 때 가닥 수입니다.\n'
            'KEC 123: 병렬 전선은 구리 50sq 이상, 같은 도체·재료·길이·굵기를 쓰고 가닥마다 퓨즈를 달지 않습니다.\n'
            '병렬 가닥도 서로 열을 주고받으므로 다조 포설 회로 수에 더해 계산합니다.\n'
            '4가닥 이상은 버스바 트렁킹 사용을 검토하십시오(KEC 232.3.2).',
        [
          for (final p in const [1, 2, 3, 4])
            calcChip('ec_par_$p', '$p가닥', _parallel == p, () {
              setState(() => _parallel = p);
            }),
        ],
      ),
      _field(
        'ec_length',
        '편도 길이 (m)',
        _length,
        '전원(분전반·MCC)에서 부하까지 케이블 한 가닥 길이입니다. 왕복이 아닙니다. 비워 두면 전압강하는 검토하지 않습니다.',
      ),
      if (!_dc)
        _field(
          'ec_pf2',
          '역률 (%)',
          _pf2,
          '전압강하 계산에 씁니다. 전동기 85, 히터·저항 부하 100을 넣으십시오. 비우면 85로 계산합니다.',
        ),
      _supplyDropdown('ec_supply'),
      const SizedBox(height: 12),
      result,
      if (basis.isNotEmpty) _basis('ec_cable_basis', basis),
    ]);
  }

  String _ambientLabel() => isGround(_method)
      ? '지중 온도'
      : _kind == WireKind.panel
      ? '반 내부 온도'
      : '주위 온도';

  Widget _supplyDropdown(String key) => calcDropdown<SupplyType>(
    key,
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
    'KEC 232.3.9 표 232.3-1 값은 수전점(수용가 설비의 인입구)부터 기기까지 전체 전압강하 한도입니다. '
        '여기서는 이 케이블 한 구간만 계산하므로, 간선 전압강하를 더해 한도 이내인지 확인하십시오.\n'
        '고압 수전(발전소·플랜트 자체 변압기)이라도 최종 회로는 저압 수전 값(동력 5%, 조명 3%)을 넘지 않는 것이 '
        '바람직합니다(표 232.3-1 주 a). 그래서 기본은 5%입니다.\n'
        '100m를 넘는 만큼 1m에 0.005%씩(최대 0.5%) 더 허용됩니다.',
  );

  String _peLine(double size) {
    final pe = peConductorSize(size);
    final sepP = peSeparateSize(size, mechProtected: true);
    final sepU = peSeparateSize(size, mechProtected: false);
    final sep = sepP == pe && sepU == pe
        ? '따로 포설할 때도 ${sqText(pe)} 이상'
        : '따로 포설할 때 최소 ${sqText(sepP)}(기계적 보호)·${sqText(sepU)}';
    return '보호도체(접지선): 케이블 안 ${sqText(pe)} / $sep (KEC 142.3.2)';
  }

  String _standardLine(double amb, int count) {
    final lay = isTray(_method) && _kind != WireKind.panel
        ? (_stacked ? ', 겹쳐 쌓음' : ', 한 줄 포설')
        : '';
    return _kind == WireKind.panel
        ? '기준: 부하 ≤ 차단기 ≤ 허용전류, IEC 60204-1 표 6 (PVC 70°C, 3상, ${methodLabel(_method)}, '
              '반 내부 ${fmt(amb)}°C: 표 D.1, $count회로: 표 D.2)'
        : '기준: KEC 212.4.1(부하 ≤ 차단기 ≤ 허용전류), KS C IEC 60364-5-52 부속서 B '
              '(${_kind.insulation == Insulation.xlpe90 ? 'XLPE 90°C' : 'PVC 70°C'}, ${methodLabel(_method)}, '
              '${_cph == Phase.three ? '3가닥 통전' : (_dc ? '2가닥 통전(직류)' : '2가닥 통전')}, '
              '${fmt(amb)}°C, $count회로$lay)';
  }

  /// 직류 차단기 안내(근거 보기). 특정 정격 값은 넣지 않는다.
  static const List<String> _dcBreakerBasis = [
    '직류 허용전류는 2가닥 통전 열(단상 교류와 같은 값)을 씁니다. IEC 60364-5-52 값을 옮긴 BS 7671 표 4D1A 등은 '
        '이 열을 "2 cables, single-phase AC or DC"로 적습니다(Eland Cables·Caledonian Cables 표).',
    '직류 차단 성능은 극 수에 따라 따로 정해집니다. LS ELECTRIC Metasol MCCB 카탈로그 차단용량 표는 '
        'DC 250V를 2극, DC 500V를 3극 기준으로 적습니다.',
    'Schneider Compact NSX DC 설명서: 높은 직류 전압에서는 극을 직렬로 연결하고, 필요한 극 수는 계통 전압과 '
        '극당 정격 전압으로 정합니다. 교류 값으로 표시된 순시 트립 설정은 직류에서 값이 달라집니다.',
    '전동기 회로 차단기 범위(NEC 430.52·LS 자료)는 교류 기준이라 직류에는 계산하지 않습니다.',
  ];

  static const String _dcBreakerLine =
      '직류 회로: 직류 정격 전압·차단용량이 표시된 차단기를 쓰십시오. 교류 전용 정격은 직류에 그대로 쓸 수 없습니다. '
      '극 수와 결선은 제조사 표로 확인하십시오.';

  List<String> _motorBasis(MotorBreakerRange r) => [
    '차단기 상한 ${fmt(r.highA, 1)}A: 정격전류의 250% ${fmt(r.necA, 1)}A(NEC 430.52), '
        '정격전류의 3배 ${fmt(r.ratedX3A, 1)}A'
        '${r.izX25A == null ? '' : '·허용전류의 2.5배 ${fmt(r.izX25A!, 1)}A'}'
        '(구 내선규정 방식, LS ELECTRIC MCCB 선정 자료 A1-124) 중 가장 작은 값',
    '전동기 여유 1.25배(50A 초과 1.1배): LS ELECTRIC MCCB 선정 자료 A1-124(구 내선규정 방식). NEC 430.22는 1.25배. KEC에는 없습니다.',
  ];

  String _vdFormula(Phase ph, Insulation ins) => ph == Phase.dc
      ? '식: ΔU = 2 × I × L × R (직류, 리액턴스 없음), R은 ${fmt(conductorTemp(ins))}°C 저항(IEC 60228)'
      : '식: ΔU = ${ph == Phase.three ? '√3' : '2'} × I × L × (R cosφ + X sinφ), '
            'R은 ${fmt(conductorTemp(ins))}°C 저항(IEC 60228), X = 0.096 Ω/km(60Hz, Schneider EIG)';

  static const String _peBasisLine =
      'KEC 142.3.2 1 다: 케이블 밖에 따로 포설하는 보호도체는 기계적 보호가 있으면 구리 2.5mm², 없으면 4mm² 이상. '
      '전선관·트렁킹 안은 기계적 보호가 있는 것으로 봅니다.';

  static const String _supplyTotalLine =
      '전압강하 한도는 수전점(인입구)부터 기기까지 합계입니다(KEC 232.3.9). 간선 전압강하를 더해 확인하십시오.';

  (Widget, String?, bool, List<String>) _cableResult(
    CableChoice c,
    List<String> inputNotes,
    double amb,
    int n,
  ) {
    final size = c.size;
    final top = _kind == WireKind.panel ? '120' : '300';
    final need = c.breaker ?? c.ib;
    final r = c.motorRange;
    String? breakerLine;
    String? breakerSum;
    if (r != null && r.low != null) {
      if (r.high != null && r.high! > r.low!) {
        breakerLine = '차단기 ${r.low}A ~ ${r.high}A (전동기 회로)';
        breakerSum = '차단기 ${r.low}~${r.high}A';
      } else {
        breakerLine = '차단기 ${r.low}A (전동기 회로)';
        breakerSum = '차단기 ${r.low}A';
      }
    } else if (c.breaker != null) {
      breakerLine = '차단기 ${c.breaker}A';
      breakerSum = breakerLine;
    }
    final dropOver = c.dropPct != null && c.dropPct! > c.dropLimitPct + 1e-9;
    final lines = <String>[
      ?breakerLine,
      if (size != null && c.iz != null)
        '허용전류 ${fmt(c.iz!, 1)}A (보정 후) ≥ ${c.breaker == null ? '설계전류' : '차단기'} ${fmt(need.toDouble())}A',
      if (_dc && size != null && c.iz != null)
        '직류 차단기 정격 In은 설계전류 ${fmt(c.ib, 1)}A 이상, 허용전류 ${fmt(c.iz!, 1)}A 이하로 선정하십시오'
            '(IB ≤ In ≤ IZ). 그 사이에 맞는 정격이 없으면 굵기를 한 단계 올리십시오.',
      if (_dc) _dcBreakerLine,
      if (c.dropChecked && c.dropV != null)
        '전압강하 ${fmt(c.dropV!, 2)}V (${fmt(c.dropPct!, 2)}%), '
            '${dropOver ? '한도 ${fmt(c.dropLimitPct, 2)}% 초과' : '한도 ${fmt(c.dropLimitPct, 2)}% 이내입니다.'}',
      if (!c.dropChecked) '길이를 넣으면 전압강하를 검토합니다.',
      if (size != null) _peLine(size),
      if (r != null)
        '과부하는 열동형 과부하 계전기(THR)로 보호합니다. 제조사 전동기 회로용 차단기 선정표로 확인하십시오.',
      if (c.parallel >= 4) '4가닥 이상 병렬은 버스바 트렁킹 사용을 검토하십시오(KEC 232.3.2).',
      ...inputNotes,
      ...c.notes,
    ];
    final basis = <String>[
      if (c.ib != c.load)
        '설계전류 ${fmt(c.ib, 1)}A = 부하 ${fmt(c.load, 1)}A × ${fmt(c.ib / c.load, 2)}',
      if (c.sizeByAmpacity != null)
        '허용전류 기준 ${sqText(c.sizeByAmpacity!)}${c.parallel > 1 ? ' × ${c.parallel}가닥' : ''} '
            '(보정 후 ≥ ${fmt(need.toDouble())}A)',
      if (c.sizeByDrop != null)
        '전압강하 기준 ${sqText(c.sizeByDrop!)} (한도 ${fmt(c.dropLimitPct, 2)}%)',
      if (size != null && c.iz != null && c.base != null)
        '${sqText(size)} 허용전류 ${fmt(c.iz!, 1)}A = 표 값 ${fmt(c.base!)} × 온도 보정 ${fmt(c.tempFactor, 2)} '
            '× 다조 포설 보정 ${fmt(c.groupFactor, 2)}${c.parallel > 1 ? ' × ${c.parallel}가닥' : ''}',
      if (c.parallel > 1)
        '병렬 ${c.parallel}가닥: 가닥마다 50sq 이상(KEC 123), 다조 포설은 병렬 가닥을 포함해 ${c.groupCount}가닥으로 계산',
      _standardLine(amb, c.groupCount),
      if (size != null) _peBasisLine,
      if (r != null) ..._motorBasis(r),
      if (_dc) ..._dcBreakerBasis,
      if (c.dropChecked) _vdFormula(_cph, _kind.insulation),
      if (c.dropChecked) _supplyTotalLine,
    ];
    final warn = size == null || dropOver;
    final result = calcResult(
      key: const Key('ec_cable_result'),
      big: size == null
          ? '검토 필요'
          : '${sqText(size)}${c.parallel > 1 ? ' × ${c.parallel}가닥' : ''}',
      caption: size == null
          ? (c.tempOutOfRange
                ? '온도 보정계수 표 범위를 넘습니다'
                : '표 범위(${top}sq ${c.parallel}가닥)를 넘습니다')
          : '${_kind == WireKind.fcv ? 'F-CV ' : ''}${_cph == Phase.three ? '3심' : '2심'} 기준 추천 굵기'
                '${_dc ? '(직류)' : ''}',
      warn: warn,
      lines: lines,
    );
    final summary = size == null
        ? '검토 필요'
        : [
            '${sqText(size)}${c.parallel > 1 ? '×${c.parallel}' : ''}',
            ?breakerSum,
            if (_dc) '직류',
            if (c.dropPct != null) '전압강하 ${fmt(c.dropPct!, 1)}%',
          ].join(' · ');
    return (result, summary, warn, basis);
  }

  (Widget, String?, bool, List<String>) _checkResult(
    CircuitCheck k,
    List<String> inputNotes,
    double amb,
    int n,
  ) {
    final iz = k.iz;
    final ib = k.ib;
    final br = k.breaker;
    final lines = <String>[];
    var fail = false;
    if (iz != null) {
      final izT = fmt(iz, 1);
      if (ib != null && br != null) {
        if (k.ibOk == true && k.inOk == true) {
          lines.add('IB ${fmt(ib, 1)}A ≤ In ${br}A ≤ IZ ${izT}A: 조건을 만족합니다.');
        } else {
          if (k.ibOk == false) {
            fail = true;
            lines.add('설계전류 ${fmt(ib, 1)}A가 차단기 ${br}A를 초과합니다. 차단기 정격이 부족합니다.');
          }
          if (k.inOk == false) {
            if (k.motorOverIzAllowed) {
              lines.add(
                '차단기 ${br}A가 허용전류 ${izT}A를 초과하지만 전동기 회로 상한 ${fmt(k.motorRange!.highA, 1)}A 이내입니다. '
                '과부하는 과부하 계전기(THR)로 보호해야 합니다.',
              );
            } else {
              fail = true;
              lines.add('차단기 ${br}A가 허용전류 ${izT}A를 초과합니다. 전선 굵기가 부족합니다.');
            }
          }
        }
      } else if (ib != null) {
        if (k.ibOk == true) {
          lines.add('설계전류 ${fmt(ib, 1)}A ≤ 허용전류 ${izT}A: 이내입니다.');
        } else {
          fail = true;
          lines.add('설계전류 ${fmt(ib, 1)}A가 허용전류 ${izT}A를 초과합니다.');
        }
        lines.add('차단기 정격을 넣으면 IB ≤ In ≤ IZ를 점검합니다.');
      } else if (br != null) {
        if (k.inOk == true) {
          lines.add('차단기 ${br}A ≤ 허용전류 ${izT}A: 이내입니다.');
        } else {
          fail = true;
          lines.add('차단기 ${br}A가 허용전류 ${izT}A를 초과합니다.');
        }
        lines.add('부하 전류를 넣으면 IB ≤ In ≤ IZ를 점검합니다.');
      } else {
        lines.add('부하 전류와 차단기 정격을 넣으면 IB ≤ In ≤ IZ를 점검합니다.');
      }
    }
    final dropOver = k.dropPct != null && k.dropPct! > k.dropLimitPct + 1e-9;
    if (k.dropV != null) {
      lines.add(
        '전압강하 ${fmt(k.dropV!, 2)}V (${fmt(k.dropPct!, 2)}%), '
        '${dropOver ? '한도 ${fmt(k.dropLimitPct, 2)}% 초과. 굵기를 올리거나 길이를 줄이십시오.' : '한도 ${fmt(k.dropLimitPct, 2)}% 이내입니다.'}',
      );
    } else if (_num(_length) == null || (_num(_length) ?? 0) <= 0) {
      lines.add('길이를 넣으면 전압강하를 검토합니다.');
    } else {
      lines.add('부하 전류를 넣으면 전압강하를 검토합니다.');
    }
    final r = k.motorRange;
    if (r != null && r.low != null) {
      lines.add(
        r.high != null && r.high! > r.low!
            ? '전동기 회로 차단기 범위 ${r.low}A ~ ${r.high}A'
            : '전동기 회로 차단기 ${r.low}A',
      );
    }
    lines.add(_peLine(k.size));
    if (_dc) lines.add(_dcBreakerLine);
    if (k.parallel >= 4) {
      lines.add('4가닥 이상 병렬은 버스바 트렁킹 사용을 검토하십시오(KEC 232.3.2).');
    }
    lines.addAll(inputNotes);
    lines.addAll(k.notes);
    final warn = fail || dropOver || iz == null;
    final sizeT =
        '${sqText(k.size)}${k.parallel > 1 ? ' × ${k.parallel}가닥' : ''}';
    final result = calcResult(
      key: const Key('ec_cable_result'),
      big: iz == null ? '검토 필요' : '${fmt(iz, 1)} A',
      caption: iz == null
          ? (k.tempOutOfRange
                ? '온도 보정계수 표 범위를 넘습니다'
                : '$sizeT 허용전류를 계산할 수 없습니다')
          : '$sizeT 보정 후 허용전류',
      warn: warn,
      lines: lines,
    );
    final checked = ib != null || br != null;
    final summary = iz == null
        ? '검토 필요'
        : [
            '$sizeT 허용전류 ${fmt(iz, 1)}A',
            if (checked) fail ? '점검 필요' : '조건 만족',
            if (k.dropPct != null) '전압강하 ${fmt(k.dropPct!, 1)}%',
          ].join(' · ');
    final basis = <String>[
      if (ib != null && k.load != null && ib != k.load)
        '설계전류 ${fmt(ib, 1)}A = 부하 ${fmt(k.load!, 1)}A × ${fmt(ib / k.load!, 2)}',
      if (iz != null && k.base != null)
        '${sqText(k.size)} 허용전류 ${fmt(iz, 1)}A = 표 값 ${fmt(k.base!)} × 온도 보정 ${fmt(k.tempFactor, 2)} '
            '× 다조 포설 보정 ${fmt(k.groupFactor, 2)}${k.parallel > 1 ? ' × ${k.parallel}가닥' : ''}',
      _standardLine(amb, k.groupCount),
      _peBasisLine,
      if (r != null) ..._motorBasis(r),
      if (_dc) ..._dcBreakerBasis,
      if (k.dropV != null) _vdFormula(_cph, _kind.insulation),
      if (k.dropV != null) _supplyTotalLine,
    ];
    return (result, summary, warn, basis);
  }

  // ③ 전압강하
  Widget _vdTab() {
    if (_awg) return _awgVdTab();
    final negative = _anyNegative([_vdI, _vdLen, _vdPf, _vdMult]);
    final ph = _dc ? Phase.dc : _phase;
    final volts = _dc ? _dcVolts : _volts;
    final i = _num(_vdI);
    final lenIn = _num(_vdLen);
    final len = lenIn == null || lenIn <= 0 ? null : lenIn;
    final ins = _vdKind.insulation;
    final notes = <String>[];
    final ok = !negative && i != null && i > 0;
    final pf = _dc ? 1.0 : _pctOf(_vdPf, 0.85, '역률', ok ? notes : []);
    final dv = !ok || len == null
        ? null
        : voltageDrop(
            current: i,
            lengthM: len,
            size: _vdSize,
            phase: ph,
            pf: pf,
            conductorTempC: conductorTemp(ins),
          );
    final simple = dv == null || _dc
        ? null
        : voltageDropSimple(
            current: i!,
            lengthM: len!,
            size: _vdSize,
            phase: _phase,
          );
    final limit = voltageDropLimit(_supply, len ?? 0);
    final pct = dv == null ? null : dv / volts * 100;
    final maxLen = !ok
        ? null
        : maxLengthForDrop(
            current: i,
            size: _vdSize,
            phase: ph,
            volts: volts,
            pf: pf,
            conductorTempC: conductorTemp(ins),
            supply: _supply,
          );
    final multIn = _num(_vdMult);
    final mult = multIn == null || multIn <= 0
        ? kMotorStartMultipleDefault
        : multIn;
    if (_vdStart && !_dc && ok && (multIn == null || multIn <= 0)) {
      notes.add('기동 전류 배수 값이 없어 ${fmt(kMotorStartMultipleDefault)}배로 계산했습니다.');
    }
    final startDv = !_vdStart || _dc || dv == null
        ? null
        : voltageDrop(
            current: i! * mult,
            lengthM: len!,
            size: _vdSize,
            phase: ph,
            pf: kMotorStartPf,
            conductorTempC: conductorTemp(ins),
          );
    final over = pct != null && pct > limit + 1e-9;
    String? summary;
    if (pct != null) {
      summary =
          '${fmt(pct, 2)}% · ${over ? '한도 ${fmt(limit, 2)}% 초과' : '한도 ${fmt(limit, 2)}% 이내'}';
    }
    return _page(sumKey: 'ec_sum_vd', summary: summary, warn: over, [
      _systemPicker('ec_vd'),
      _unitPicker('ec_vd'),
      calcDropdown<double>(
        'ec_vd_size',
        '전선 굵기',
        _vdSize,
        kVdSizes,
        sqText,
        (s) => setState(() => _vdSize = s),
        '포설되어 있거나 포설할 전선의 굵기(sq = mm²)입니다. 계장·제어용 0.75·1sq도 있습니다.',
      ),
      calcDropdown<WireKind>(
        'ec_vd_kind',
        '전선 종류',
        _vdKind,
        WireKind.values,
        (k) => k.label,
        (k) => setState(() => _vdKind = k),
        '도체 온도(70°C·90°C)에서의 저항으로 계산합니다. 운전 중 가장 불리한 값입니다.',
      ),
      _field('ec_vd_i', '전류 (A)', _vdI, '회로에 흐르는 전류입니다.'),
      _field('ec_vd_len', '편도 길이 (m)', _vdLen, '케이블 한 가닥 길이입니다(왕복 아님).'),
      if (!_dc)
        _field('ec_vd_pf', '역률 (%)', _vdPf, '전동기 85, 히터 100. 비우면 85로 계산합니다.'),
      if (!_dc)
        calcSwitch(
          '전동기 기동 시 전압강하',
          _vdStart,
          (v) => setState(() => _vdStart = v),
          '전동기 기동 중에는 정격전류의 5~7배가 역률 약 0.35로 흐릅니다(Schneider EIG). 이 기동 전류로 '
              '전압강하를 따로 계산합니다. 기동 중 전압강하에는 표 232.3-1 한도를 적용하지 않습니다(KEC 232.3.9 2).',
          key: 'ec_vd_start',
        ),
      if (!_dc && _vdStart)
        _field(
          'ec_vd_mult',
          '기동 전류 배수 (정격의 배)',
          _vdMult,
          '기동 전류가 정격전류의 몇 배인지 넣습니다. 모르면 6으로 두십시오(LS ELECTRIC 자료의 전부하전류 600% 조건). '
              '명판·시험 성적서에 기동 전류(IA/IN)가 있으면 그 값을 넣으십시오.',
        ),
      _supplyDropdown('ec_vd_supply'),
      const SizedBox(height: 12),
      if (negative)
        _negativeResult('ec_vd_result')
      else
        calcResult(
          key: const Key('ec_vd_result'),
          big: pct == null ? '— %' : '${fmt(pct, 2)} %',
          caption: dv == null
              ? (ok ? '길이를 넣으면 전압강하를 계산합니다' : '전류와 길이를 넣으십시오')
              : '전압강하 ${fmt(dv, 2)} V',
          warn: over,
          lines: [
            if (pct != null)
              over
                  ? '한도 ${fmt(limit, 2)}% 초과. 굵기를 올리거나 길이를 줄이십시오.'
                  : '한도 ${fmt(limit, 2)}% 이내입니다.',
            if (maxLen != null) '한도 이내 최대 편도 길이 약 ${fmt(maxLen, 0)} m',
            if (startDv != null)
              '기동 시(정격 ×${fmt(mult)}, 역률 0.35) ${fmt(startDv, 2)} V (${fmt(startDv / volts * 100, 1)}%)',
            if (startDv != null)
              '기동 중 전압강하는 표 232.3-1 한도 대상이 아닙니다. 전동기 단자 전압이 기동에 충분한지 확인하십시오.',
            if (_dc) '직류 제어·계장 회로는 기기 최소 동작 전압으로도 확인하십시오.',
            if (simple != null)
              '참고: 현장 간이식(${_phase == Phase.three ? '30.8' : '35.6'}·L·I/1000A, 역률 1·20°C) ${fmt(simple, 2)}V',
            ...notes,
          ],
        ),
      _basis('ec_vd_basis', [
        _vdFormula(ph, ins),
        if (_vdStart && !_dc)
          '기동: 정격전류 × ${fmt(mult)}배, 역률 0.35(Schneider EIG 2009 그림 G27·G28)',
        '최대 길이: 한도(100m를 넘으면 1m당 0.005%, 최대 0.5% 더함)와 전압강하가 같아지는 길이',
        _supplyTotalLine,
      ]),
    ]);
  }

  // ④ 역률
  Widget _pfTab() {
    final negative = _anyNegative([_pcKw, _pcNow, _pcTarget]);
    final p = _num(_pcKw);
    final ok = !negative && p != null && p > 0;
    final notes = <String>[];
    final now = _pctOf(_pcNow, 0.8, '개선 전 역률', ok ? notes : []);
    final target = _pctOf(_pcTarget, 0.95, '목표 역률', ok ? notes : []);
    final q = ok ? capacitorKvar(p, now, target) : null;
    final uf = q == null ? null : capacitorMicroFarad(q, _volts);
    final i1 = ok
        ? loadCurrent(kw: p, volts: _volts, phase: _phase, pf: now)
        : null;
    final i2 = ok
        ? loadCurrent(kw: p, volts: _volts, phase: _phase, pf: target)
        : null;
    final ic = q == null
        ? null
        : currentFromKva(kva: q, volts: _volts, phase: _phase);
    String? summary;
    if (q != null) {
      summary = '${fmt(q, 1)} kvar · ${fmt(uf!, 0)} μF';
    }
    return _page(sumKey: 'ec_sum_pf', summary: summary, [
      _voltsPhase(),
      _field(
        'ec_pc_kw',
        '유효 전력 (kW)',
        _pcKw,
        '역률을 올릴 부하의 전력(kW)입니다. 전력량계나 부하 목록에서 보십시오.',
      ),
      _field('ec_pc_now', '개선 전 역률 (%)', _pcNow, '현재 측정한 역률입니다.'),
      _field(
        'ec_pc_target',
        '목표 역률 (%)',
        _pcTarget,
        '보통 90~95%를 목표로 합니다. 100%에 가깝게 올리면 경부하 때 과보상이 됩니다.',
      ),
      const SizedBox(height: 12),
      if (negative)
        _negativeResult('ec_pf_result')
      else
        calcResult(
          key: const Key('ec_pf_result'),
          big: q == null ? '— kvar' : '${fmt(q, 1)} kvar',
          caption: '필요한 콘덴서 용량',
          lines: [
            if (uf != null && q! > 0)
              '정전용량 약 ${fmt(uf, 0)} μF (${_volts.toInt()}V, 60Hz)',
            if (ic != null && q! > 0) '콘덴서 전류 약 ${fmt(ic, 1)} A',
            if (i1 != null && i2 != null && q != null && q > 0)
              '부하 전류 개선 전 ${fmt(i1, 1)} A → 개선 후 ${fmt(i2, 1)} A',
            if (q != null && q == 0) '목표 역률이 개선 전 역률보다 높아야 합니다.',
            if (uf != null && q! > 0)
              'μF는 국내 저압 진상 콘덴서 표기(선간전압 기준)로 환산했습니다. 제조사 표로 확인하십시오.',
            ...notes,
          ],
        ),
      _basis('ec_pf_basis', [
        '식: Qc = P × (tanφ1 − tanφ2)',
        'C(μF) = Qc(kvar) × 10⁹ ÷ (2π × 60 × V²) (국내 저압 콘덴서 표기, 삼화엔지니어링 기술자료)',
        '전류: I = P ÷ (${_phase == Phase.three ? '√3 × ' : ''}V × 역률), 콘덴서 전류 = Qc ÷ (${_phase == Phase.three ? '√3 × ' : ''}V)',
      ]),
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
          calcHelp(
            '전압',
            '회로의 선간 전압입니다. 110·220V를 누르면 단상, 380·440·480V를 누르면 삼상으로 맞춰집니다. '
                '실제와 다르면 단상·삼상을 직접 누르십시오.',
          ),
        ],
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final v in kAcVolts)
            calcChip('ec_v_${v.toInt()}', '${v.toInt()}V', _volts == v, () {
              setState(() {
                _volts = v;
                _phase = v <= 220 ? Phase.single : Phase.three;
              });
            }),
          const SizedBox(width: 8),
          calcChip(
            'ec_ph_1',
            '단상',
            _phase == Phase.single,
            () => setState(() => _phase = Phase.single),
          ),
          calcChip(
            'ec_ph_3',
            '삼상',
            _phase == Phase.three,
            () => setState(() => _phase = Phase.three),
          ),
        ],
      ),
      const SizedBox(height: 12),
    ],
  );

  /// 교류/직류 선택과 전압. 부하 전류·전선 굵기·전압강하 탭이 같은 값(_dc·_dcVolts)을 쓴다.
  /// 키: '$prefix_ac'·'$prefix_dc'·'$prefix_dcv_125' 등.
  Widget _systemPicker(String prefix) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _chipGroup(
        '회로',
        '교류: 110·220V 단상, 380·440·480V 삼상.\n'
            '직류: 발전소 축전지·제어 전원은 125VDC를 많이 씁니다. 24VDC 계장 회로도 있습니다. '
            '직류는 역률이 없고 전압강하는 저항만으로 계산합니다(ΔU = 2 × I × L × R).\n'
            '부하 전류·전선 굵기·전압강하·부스바 탭이 같은 선택을 씁니다.',
        [
          calcChip('${prefix}_ac', '교류', !_dc, () {
            setState(() => _dc = false);
          }),
          calcChip('${prefix}_dc', '직류', _dc, () {
            setState(() => _dc = true);
          }),
        ],
      ),
      if (_dc)
        _chipGroup('직류 전압', '회로의 직류 전압입니다. 전압강하 %는 이 전압을 기준으로 계산합니다.', [
          for (final v in kDcVolts)
            calcChip(
              '${prefix}_dcv_${v.toInt()}',
              '${v.toInt()}V',
              _dcVolts == v,
              () => setState(() => _dcVolts = v),
            ),
        ])
      else
        _voltsPhase(),
    ],
  );
}
