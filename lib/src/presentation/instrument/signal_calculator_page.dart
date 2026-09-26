// 4-20mA 계산기(홈 "현장 작업" → 4-20mA 계산기). 탭: 환산(mA·%·측정값, NE43 신호 상태, 5점 환산표) →
// 교정 점검(입력값 대비 측정값·지시값의 스팬 % 오차, 허용오차 판정, 시험점 3·5·11점과 상승·하강 히스테리시스,
// 온도 센서 값, 조정 전·후, 기록·성적서. "스위치"를 고르면 스위치 시험: 동작점·복귀점·데드밴드, 반복 3회) →
// 루프 전압(전원·저항·계기 최소 동작 전압, 확인 전류) →
// 온도 센서(Pt100·Pt1000·열전대 환산, 냉접점 보상, 5점 표). 칸마다 "?" 안내.
// 계산은 signal_calc.dart·temp_sensor.dart·switch_check.dart, 기록은 cal_record.dart, 근거는 docs/4-20mA계산기_근거.md.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import '../electrical/elec_tables.dart' show cuResistance;
import 'cal_record.dart';
import 'cal_record_pdf.dart';
import 'cal_records_page.dart';
import 'signal_calc.dart';
import 'switch_check.dart';
import 'temp_sensor.dart';

String _fmt(double v, [int d = 3]) {
  // 0.125가 0.12로 내려가지 않게(이진 소수 오차) 반올림 전에 아주 작게 밀어 준다.
  var s = (v + (v >= 0 ? 1e-9 : -1e-9)).toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  if (s == '-0') s = '0';
  return s;
}

/// 부호를 붙인 수(오차).
String _signed(double v, [int d = 3]) => '${v > 0 ? '+' : ''}${_fmt(v, d)}';

enum _Input { ma, pct, pv }

/// 스위치 복귀 설정: 없음·복귀점 설정값·데드밴드 설정값.
enum _ResetRef { none, reset, deadband }

const List<double> _points = kCalPoints;

/// 계장 전선 굵기(IEC 60228 2종): 전기 계산기 저항 표에 있는 것.
const List<double> _wireSizes = [0.75, 1.0, 1.5, 2.5];

/// 입력 중인 값 보관(화면을 나가거나 전화가 와도 남게).
const String kSignalDraftKey = 'signal_calc_draft_v1';

class SignalCalculatorPage extends StatefulWidget {
  const SignalCalculatorPage({super.key});

  @override
  State<SignalCalculatorPage> createState() => _SignalCalculatorPageState();
}

class _SignalCalculatorPageState extends State<SignalCalculatorPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, CalcFormParts {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  // 측정 범위(환산·교정 점검이 같이 씀)
  final _lrv = TextEditingController(text: '0');
  final _urv = TextEditingController(text: '10');
  final _unit = TextEditingController(text: 'bar');
  Transfer _transfer = Transfer.linear;

  // ① 환산
  _Input _input = _Input.ma;
  final _value = TextEditingController();

  // ② 교정 점검: 조정 전(found)·조정 후(left) 두 벌. 칸은 시험점이 가장 많을 때(21줄)만큼 만들어 앞에서부터 쓴다.
  ReadKind _kind = ReadKind.ma;
  final _tol = TextEditingController();
  bool _phaseLeft = false;
  bool _settingsOpen = true;
  CalPointSet _pointSet = CalPointSet.p5;
  bool _withDown = false;
  final _hystTol = TextEditingController();
  TempSensor? _calSensor; // 입력값이 °C일 때 교정기에 넣을 센서 값을 보인다
  final _calCj = TextEditingController(text: '20');
  final _foundApplied = [
    for (var i = 0; i < kMaxCalRows; i++) TextEditingController(),
  ];
  final _foundReading = [
    for (var i = 0; i < kMaxCalRows; i++) TextEditingController(),
  ];
  final _leftApplied = [
    for (var i = 0; i < kMaxCalRows; i++) TextEditingController(),
  ];
  final _leftReading = [
    for (var i = 0; i < kMaxCalRows; i++) TextEditingController(),
  ];
  final _readFocus = [for (var i = 0; i < kMaxCalRows; i++) FocusNode()];
  CalRecord? _editing; // 불러오거나 저장한 기록(고쳐 저장할 때 같은 id)

  // ② 교정 점검: 스위치 시험. 값은 전송기와 따로 보관한다(측정 범위·단위·센서는 같이 씀).
  bool _switchMode = false;
  SwitchDir _swDir = SwitchDir.rising;
  final _swSet = TextEditingController();
  _ResetRef _swRref = _ResetRef.none;
  final _swRval = TextEditingController();
  SwitchTolMode _swTolMode = SwitchTolMode.unit;
  final _swTol = TextEditingController();
  final _swDbMin = TextEditingController();
  final _swDbMax = TextEditingController();
  SwitchContact? _swContact;
  final _swFoundTrip = [
    for (var i = 0; i < kSwitchRepeats; i++) TextEditingController(),
  ];
  final _swFoundReset = [
    for (var i = 0; i < kSwitchRepeats; i++) TextEditingController(),
  ];
  final _swLeftTrip = [
    for (var i = 0; i < kSwitchRepeats; i++) TextEditingController(),
  ];
  final _swLeftReset = [
    for (var i = 0; i < kSwitchRepeats; i++) TextEditingController(),
  ];

  List<TextEditingController> get _swTrip =>
      _phaseLeft ? _swLeftTrip : _swFoundTrip;
  List<TextEditingController> get _swReset =>
      _phaseLeft ? _swLeftReset : _swFoundReset;

  /// 지금 시험점 목록.
  List<CalPointDef> get _defs => calPointList(_pointSet, withDown: _withDown);

  List<TextEditingController> get _applied =>
      _phaseLeft ? _leftApplied : _foundApplied;
  List<TextEditingController> get _reading =>
      _phaseLeft ? _leftReading : _foundReading;

  // ③ 루프 전압
  final _supply = TextEditingController(text: '24');
  final _minV = TextEditingController(text: '10.5');
  final _hartR = TextEditingController(text: '250');
  final _barrierR = TextEditingController(text: '0');
  final _extraV = TextEditingController(text: '0');
  final _wireLen = TextEditingController();
  double _wireSize = 1.5;
  final _wireR = TextEditingController();
  double _checkMa = 23;

  // ④ 온도 센서
  TempSensor _tSensor = TempSensor.pt100;
  bool _tFromTemp = true; // °C → Ω·mV(아니면 Ω·mV → °C)
  final _tValue = TextEditingController();
  final _tCj = TextEditingController(text: '20');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreDraft();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _writeDraft(_draftJson());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _writeDraft(_draftJson());
    _tabs.dispose();
    for (final c in [
      _lrv,
      _urv,
      _unit,
      _value,
      _tol,
      ..._foundApplied,
      ..._foundReading,
      ..._leftApplied,
      ..._leftReading,
      _supply,
      _minV,
      _hartR,
      _barrierR,
      _extraV,
      _wireLen,
      _wireR,
      _hystTol,
      _calCj,
      _tValue,
      _tCj,
      _swSet,
      _swRval,
      _swTol,
      _swDbMin,
      _swDbMax,
      ..._swFoundTrip,
      ..._swFoundReset,
      ..._swLeftTrip,
      ..._swLeftReset,
    ]) {
      c.dispose();
    }
    for (final f in _readFocus) {
      f.dispose();
    }
    super.dispose();
  }

  // ─────────────── 입력 보관 ───────────────

  Map<String, dynamic> _draftJson() => {
    'lrv': _lrv.text,
    'urv': _urv.text,
    'unit': _unit.text,
    'transfer': _transfer.name,
    'kind': _kind.name,
    'tol': _tol.text,
    'phaseLeft': _phaseLeft,
    'fa': [for (final c in _foundApplied) c.text],
    'fr': [for (final c in _foundReading) c.text],
    'la': [for (final c in _leftApplied) c.text],
    'lr': [for (final c in _leftReading) c.text],
    'editing': _editing?.id,
    'supply': _supply.text,
    'minV': _minV.text,
    'hart': _hartR.text,
    'barrier': _barrierR.text,
    'extraV': _extraV.text,
    'wireLen': _wireLen.text,
    'wireSize': _wireSize,
    'wireR': _wireR.text,
    'checkMa': _checkMa,
    'pset': _pointSet.name,
    'down': _withDown,
    'hystTol': _hystTol.text,
    'calSensor': _calSensor?.name,
    'calCj': _calCj.text,
    'tSensor': _tSensor.name,
    'tFromTemp': _tFromTemp,
    'tValue': _tValue.text,
    'tCj': _tCj.text,
    'swMode': _switchMode,
    'swDir': _swDir.name,
    'swSet': _swSet.text,
    'swRref': _swRref.name,
    'swRval': _swRval.text,
    'swTolMode': _swTolMode.name,
    'swTol': _swTol.text,
    'swDbMin': _swDbMin.text,
    'swDbMax': _swDbMax.text,
    'swContact': _swContact?.name,
    'swFt': [for (final c in _swFoundTrip) c.text],
    'swFr': [for (final c in _swFoundReset) c.text],
    'swLt': [for (final c in _swLeftTrip) c.text],
    'swLr': [for (final c in _swLeftReset) c.text],
  };

  static Future<void> _writeDraft(Map<String, dynamic> j) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(kSignalDraftKey, jsonEncode(j));
    } catch (_) {
      // 보관 못 하면 그냥 넘어간다(계산에는 영향 없음)
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(kSignalDraftKey);
      if (raw == null || raw.isEmpty) return;
      final j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      CalRecord? ed;
      final edId = j['editing'] as String?;
      if (edId != null) {
        final list = await CalRecordStore.load();
        for (final r in list) {
          if (r.id == edId) ed = r;
        }
      }
      if (!mounted) return;
      void set(TextEditingController c, Object? v) {
        if (v is String) c.text = v;
      }

      void setList(List<TextEditingController> cs, Object? v) {
        if (v is! List) return;
        for (var i = 0; i < cs.length && i < v.length; i++) {
          set(cs[i], v[i]);
        }
      }

      setState(() {
        set(_lrv, j['lrv']);
        set(_urv, j['urv']);
        set(_unit, j['unit']);
        _transfer = Transfer.values.firstWhere(
          (t) => t.name == j['transfer'],
          orElse: () => _transfer,
        );
        _kind = ReadKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => _kind,
        );
        set(_tol, j['tol']);
        _phaseLeft = j['phaseLeft'] == true;
        setList(_foundApplied, j['fa']);
        setList(_foundReading, j['fr']);
        setList(_leftApplied, j['la']);
        setList(_leftReading, j['lr']);
        _editing = ed;
        set(_supply, j['supply']);
        set(_minV, j['minV']);
        set(_hartR, j['hart']);
        set(_barrierR, j['barrier']);
        set(_extraV, j['extraV']);
        set(_wireLen, j['wireLen']);
        final ws = (j['wireSize'] as num?)?.toDouble();
        if (ws != null && _wireSizes.contains(ws)) _wireSize = ws;
        set(_wireR, j['wireR']);
        final cm = (j['checkMa'] as num?)?.toDouble();
        if (cm != null && kLoopCheckMa.contains(cm)) _checkMa = cm;
        _pointSet = CalPointSet.values.firstWhere(
          (s) => s.name == j['pset'],
          orElse: () => _pointSet,
        );
        _withDown = j['down'] == true;
        set(_hystTol, j['hystTol']);
        _calSensor = TempSensor.values
            .where((s) => s.name == j['calSensor'])
            .firstOrNull;
        set(_calCj, j['calCj']);
        _tSensor = TempSensor.values.firstWhere(
          (s) => s.name == j['tSensor'],
          orElse: () => _tSensor,
        );
        _tFromTemp = j['tFromTemp'] != false;
        set(_tValue, j['tValue']);
        set(_tCj, j['tCj']);
        _switchMode = j['swMode'] == true;
        _swDir = SwitchDir.values.firstWhere(
          (d) => d.name == j['swDir'],
          orElse: () => _swDir,
        );
        set(_swSet, j['swSet']);
        _swRref = _ResetRef.values.firstWhere(
          (r) => r.name == j['swRref'],
          orElse: () => _swRref,
        );
        set(_swRval, j['swRval']);
        _swTolMode = SwitchTolMode.values.firstWhere(
          (m) => m.name == j['swTolMode'],
          orElse: () => _swTolMode,
        );
        set(_swTol, j['swTol']);
        set(_swDbMin, j['swDbMin']);
        set(_swDbMax, j['swDbMax']);
        _swContact = SwitchContact.values
            .where((c) => c.name == j['swContact'])
            .firstOrNull;
        setList(_swFoundTrip, j['swFt']);
        setList(_swFoundReset, j['swFr']);
        setList(_swLeftTrip, j['swLt']);
        setList(_swLeftReset, j['swLr']);
      });
    } catch (_) {
      // 보관한 값이 망가졌으면 처음 상태로
    }
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', ''));

  String get _u => _unit.text.trim();
  String _pv(double v) => _u.isEmpty ? _fmt(v) : '${_fmt(v)} $_u';

  /// 측정 범위가 맞으면 (lrv, urv).
  (double, double)? get _range {
    final l = _num(_lrv), u = _num(_urv);
    if (l == null || u == null || l == u) return null;
    return (l, u);
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
            '계기 교정',
            style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
          ),
          bottom: TabBar(
            controller: _tabs,
            // 탭 넷이 좁은 폰·큰 글씨에서도 잘리지 않게 옆으로 밀린다.
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
              Tab(key: Key('sg_tab_conv'), text: '환산'),
              Tab(key: Key('sg_tab_cal'), text: '교정 점검'),
              Tab(key: Key('sg_tab_loop'), text: '루프 전압'),
              Tab(key: Key('sg_tab_temp'), text: '온도 센서'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            controller: _tabs,
            children: [_convTab(), _calTab(), _loopTab(), _tempTab()],
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

  /// 측정 범위 칸: 두 탭에 같은 값.
  List<Widget> _rangeFields(String tab) => [
    calcField(
      '${tab}_lrv',
      '0% 값 (4mA)',
      _lrv,
      '계기가 4mA를 내는 측정값(LRV)입니다. 계기 명판·데이터시트·DCS 태그 설정에 있습니다. '
          '영하 온도처럼 음수도 넣을 수 있습니다.',
      signed: true,
    ),
    calcField(
      '${tab}_urv',
      '100% 값 (20mA)',
      _urv,
      '계기가 20mA를 내는 측정값(URV)입니다.',
      signed: true,
    ),
    _unitField(tab),
    _chips(
      '출력 특성',
      '선형: mA가 측정값에 비례합니다.\n'
          '제곱근(DCS 연산): 차압 전송기 출력은 차압에 비례하고 DCS가 유량으로 바꿉니다. 측정 범위를 유량으로 넣으십시오.\n'
          '제곱근(전송기 출력): 전송기가 제곱근 출력으로 설정되어 mA가 유량에 비례합니다. 측정 범위를 차압으로 넣으십시오. '
          '차압 약 1% 아래 저유량 구간은 제조사 설정(선형·차단)에 따라 다릅니다.',
      [
        for (final t in Transfer.values)
          calcChip(
            '${tab}_tf_${t.name}',
            transferLabel(t),
            _transfer == t,
            () => setState(() => _transfer = t),
          ),
      ],
    ),
  ];

  /// 단위 칸(환산·교정 점검·스위치가 같은 값).
  Widget _unitField(String tab) => calcBox(
    child: Row(
      children: [
        Expanded(
          flex: 5,
          child: calcLabel('단위', '결과에 표시할 단위입니다. 계산에는 영향이 없습니다.'),
        ),
        Expanded(
          flex: 4,
          child: TextField(
            key: Key('${tab}_unit'),
            controller: _unit,
            textAlign: TextAlign.right,
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
        const SizedBox(width: 8),
      ],
    ),
  );

  // ─────────────── ① 환산 ───────────────

  Widget _convTab() {
    final range = _range;
    final v = _num(_value);
    Widget result;
    if (range == null) {
      result = calcResult(
        big: '—',
        caption: '0% 값과 100% 값을 다르게 넣으십시오',
        lines: const [],
      );
    } else if (v == null) {
      result = calcResult(big: '—', caption: '값을 넣으십시오', lines: const []);
    } else {
      final (l, u) = range;
      final double ma, pct, pv;
      switch (_input) {
        case _Input.ma:
          ma = v;
          pct = pvPctFromOutPct(pctFromMa(ma), _transfer);
          pv = pctToPv(pct, l, u);
        case _Input.pct:
          pct = v;
          pv = pctToPv(pct, l, u);
          ma = maFromPct(outPctFromPvPct(pct, _transfer));
        case _Input.pv:
          pv = v;
          pct = pvToPct(pv, l, u);
          ma = idealMa(pv, l, u, _transfer);
      }
      final st = signalState(ma);
      final warn =
          st == SignalState.failLow ||
          st == SignalState.failHigh ||
          st == SignalState.gapLow ||
          st == SignalState.gapHigh;
      result = calcResult(
        key: const Key('sg_conv_result'),
        big: _input == _Input.ma ? _pv(pv) : '${_fmt(ma)} mA',
        caption: switch (_input) {
          _Input.ma => '측정값',
          _Input.pct => '출력 전류',
          _Input.pv => '출력 전류(역산)',
        },
        warn: warn,
        lines: [
          if (_input != _Input.ma) '측정값 ${_pv(pv)}',
          if (_input != _Input.pct) '측정 범위의 ${_fmt(pct, 2)}%',
          if (_transfer == Transfer.sqrt)
            '차압 ${_fmt(pctFromMa(ma), 2)}% (mA는 차압에 비례)',
          if (_transfer == Transfer.sqrtOut)
            '유량 ${_fmt(pctFromMa(ma), 2)}% (mA는 유량에 비례)',
          '1-5V 입력이면 ${_fmt(ma * 0.25)} V (250Ω)',
          _stateText(st),
        ],
      );
    }
    return _page([
      ..._rangeFields('sg'),
      _chips(
        '입력 항목',
        '아는 값을 골라 넣으면 나머지를 계산합니다. '
            'DCS·지시계 값을 "측정값"으로 넣으면 mA를 역산합니다.',
        [
          calcChip(
            'sg_in_ma',
            'mA',
            _input == _Input.ma,
            () => setState(() => _input = _Input.ma),
          ),
          calcChip(
            'sg_in_pct',
            '%',
            _input == _Input.pct,
            () => setState(() => _input = _Input.pct),
          ),
          calcChip(
            'sg_in_pv',
            '측정값',
            _input == _Input.pv,
            () => setState(() => _input = _Input.pv),
          ),
        ],
      ),
      calcField(
        'sg_value',
        switch (_input) {
          _Input.ma => '전류 (mA)',
          _Input.pct => '백분율 (%)',
          _Input.pv => '측정값${_u.isEmpty ? '' : ' ($_u)'}',
        },
        _value,
        switch (_input) {
          _Input.ma => '멀티미터·교정기로 측정한 루프 전류입니다.',
          _Input.pct => '측정 범위의 백분율입니다(0% = 4mA, 100% = 20mA).',
          _Input.pv => '압력·온도 등 측정값(DCS·지시계 값)입니다. 이 값에 해당하는 mA를 역산합니다.',
        },
        signed: true,
      ),
      const SizedBox(height: 12),
      result,
      if (range != null) ...[
        const SizedBox(height: 12),
        _tableCard(range.$1, range.$2),
      ],
    ]);
  }

  String _stateText(SignalState s) => switch (s) {
    SignalState.failLow => '3.6mA 이하: 고장 신호(하한). 단선·계기 고장을 점검하십시오(NAMUR NE43).',
    SignalState.gapLow =>
      '3.6~3.8mA: NE43에서 정하지 않은 구간입니다. 계기의 고장 신호 설정값(예: 3.75mA)일 수 있습니다.',
    SignalState.underRange => '3.8~4mA: 0% 미만이지만 유효한 측정 구간입니다(NE43).',
    SignalState.normal => '4~20mA 정상 구간입니다.',
    SignalState.overRange => '20~20.5mA: 100% 초과이지만 유효한 측정 구간입니다(NE43).',
    SignalState.gapHigh =>
      '20.5~21mA: NE43에서 정하지 않은 구간입니다. 계기의 포화값(예: 20.8mA)일 수 있습니다.',
    SignalState.failHigh => '21mA 이상: 고장 신호(상한)입니다(NAMUR NE43).',
  };

  Widget _tableCard(double l, double u) => Container(
    key: const Key('sg_table'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: fc.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '5점 환산표',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: fc.text,
          ),
        ),
        const SizedBox(height: 8),
        _tableRow('%', 'mA', '측정값', head: true),
        for (final p in _points)
          _tableRow(
            _fmt(p),
            _fmt(maFromPct(outPctFromPvPct(p, _transfer))),
            _pv(pctToPv(p, l, u)),
          ),
      ],
    ),
  );

  Widget _tableRow(String a, String b, String c, {bool head = false}) {
    final st = TextStyle(
      fontSize: 15,
      fontWeight: head ? FontWeight.w800 : FontWeight.w600,
      color: head ? fc.textSub : fc.text,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(a, style: st)),
          Expanded(flex: 3, child: Text(b, style: st)),
          Expanded(
            flex: 4,
            child: Text(c, style: st, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  // ─────────────── ② 교정 점검 ───────────────

  String get _phase => _phaseLeft ? '조정 후' : '조정 전';

  bool get _anyInput => [
    ..._foundApplied,
    ..._foundReading,
    ..._leftApplied,
    ..._leftReading,
  ].any((c) => c.text.trim().isNotEmpty);

  String _settingsLine() {
    if (_switchMode) return _swSettingsLine();
    final r = _range;
    final tol = _num(_tol);
    return [
      r == null ? '범위 없음' : '${_pv(r.$1)} ~ ${_pv(r.$2)}',
      transferLabel(_transfer),
      kindLabel(_kind),
      tol == null || tol <= 0 ? '허용오차 없음' : '±${_fmt(tol)}%',
      // 기본(5점 상승)이 아니면 시험점, 넣었으면 히스테리시스 허용값과 센서.
      if (_pointSet != CalPointSet.p5 || _withDown) calPointsText(_defs),
      if (_hystTolActive != null) '히스테리시스 ${_fmt(_hystTolActive!)}%',
      if (_sensorActive != null) _sensorActive!.label,
    ].join(' · ');
  }

  /// 히스테리시스 허용값(하강 포함이고 0보다 클 때만).
  double? get _hystTolActive {
    final h = _num(_hystTol);
    return _withDown && h != null && h > 0 ? h : null;
  }

  /// 교정 점검에 쓰는 센서: 범위 단위가 °C이고 입력값이 공정값(mA 입력이 아님)일 때만.
  TempSensor? get _sensorActive =>
      _kind != ReadKind.maIn && isCelsiusUnit(_u) ? _calSensor : null;

  /// 냉접점 온도: 비우면 0 °C.
  double get _calCjC => _num(_calCj) ?? 0;

  Widget _calTab() {
    if (_switchMode) return _switchTab();
    final range = _range;
    final tol = _num(_tol);
    final s = range == null ? null : _summary(_phaseLeft, range);
    final other = range == null ? null : _summary(!_phaseLeft, range);
    Widget summary;
    if (s == null) {
      summary = calcResult(
        big: '—',
        caption: '0% 값과 100% 값을 다르게 넣으십시오',
        lines: const [],
      );
    } else if (s.isEmpty) {
      summary = calcResult(
        big: '—',
        caption: '$_phase: 측정값을 한 점 이상 넣으십시오',
        lines: [if (other != null && !other.isEmpty) _otherLine(other)],
      );
    } else {
      final defs = _defs;
      String label(int i) => calPointLabel(defs, i);
      String labels(List<int> l) => l.map(label).join(', ');
      final worst = s.worst!;
      final fails = s.failed;
      final hystFails = s.hystFailed;
      final advise = s.adjustAdvised;
      final mh = s.maxHyst;
      final tolOk = tol != null && tol > 0;
      summary = calcResult(
        key: const Key('sg_cal_result'),
        big: '${_signed(worst.$2.errPct, 2)}%',
        caption: s.pass == null
            ? '$_phase 최대 오차 (스팬 %)'
            : fails.isEmpty
            ? (tolOk
                  ? '$_phase 합격: ${s.measured.length}점 모두 ±${_fmt(tol)}% 이내'
                  : '$_phase 합격: 히스테리시스 허용값 이내')
            : hystFails.isEmpty
            ? '$_phase 불합격: ${fails.length}점 허용오차 초과'
            : s.errFailed.isEmpty
            ? '$_phase 불합격: ${fails.length}점 히스테리시스 허용값 초과'
            : '$_phase 불합격: ${fails.length}점 허용오차·히스테리시스 허용값 초과',
        warn: fails.isNotEmpty,
        lines: [
          if (s.pass == null) '허용오차를 넣으면 합격·불합격을 판정합니다.',
          '최대 오차: ${label(worst.$1)} 점',
          if (mh != null) '최대 히스테리시스: ${_fmt(mh.$2, 2)}% (${label(mh.$1)} 점)',
          if (fails.isNotEmpty) '불합격 점: ${labels(fails)}',
          if (hystFails.isNotEmpty) '히스테리시스 초과: ${labels(hystFails)}',
          if (advise.isNotEmpty)
            '조정 권장: ${labels(advise)} 점이 허용오차의 50%(조정 한계)를 넘습니다.',
          if (other != null && !other.isEmpty) _otherLine(other),
          _kind == ReadKind.ma
              ? '오차 % = (측정값 − 이론값) ÷ 16mA × 100'
              : '오차 % = (지시값 − 이론값) ÷ 스팬 × 100',
          if (_withDown) '히스테리시스 = |상승 오차 % − 하강 오차 %| (같은 측정점)',
        ],
      );
    }
    return _page([
      ..._editingBanner(),
      _modeChips(),
      _settingsHeader(),
      if (_settingsOpen) ..._calSettings(),
      _phaseChips('영점·스팬을 조정한 뒤'),
      if (s != null && !s.isEmpty) _miniSummary(s),
      if (range != null && s != null)
        for (var i = 0; i < s.defs.length; i++)
          _calRow(i, range.$1, range.$2, s),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          calcToggle('sc_new', '새로 시작', _confirmNewCheck),
          calcToggle('sc_clear', '이 표 지우기', _confirmClearPhase),
        ],
      ),
      const SizedBox(height: 4),
      summary,
      const SizedBox(height: 12),
      _saveButtons(),
    ]);
  }

  /// 불러온 기록 표시(지금 고른 교정 대상과 같은 종류일 때만).
  List<Widget> _editingBanner() {
    final ed = _editingForMode;
    if (ed == null) return const [];
    return [
      Container(
        key: const Key('sc_editing'),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: fc.brandSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '불러온 기록: ${ed.tag.isEmpty ? '(태그 없음)' : ed.tag} · ${calDay(ed.date)}',
          style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
        ),
      ),
    ];
  }

  /// 불러온 기록이 지금 교정 대상(전송기·스위치)과 같은 종류면 그 기록.
  CalRecord? get _editingForMode {
    final ed = _editing;
    return ed != null && ed.isSwitch == _switchMode ? ed : null;
  }

  /// 교정 대상: 전송기(기본)·스위치.
  Widget _modeChips() => _chips(
    '교정 대상',
    '전송기: 4-20mA 전송기·루프를 시험점마다 점검합니다.\n'
        '스위치: 압력·온도·레벨 스위치의 동작점·복귀점·데드밴드를 시험합니다.\n'
        '입력한 값은 따로 보관되어 바꿔도 지워지지 않습니다.',
    [
      calcChip(
        'sc_mode_tx',
        '전송기',
        !_switchMode,
        () => setState(() => _switchMode = false),
      ),
      calcChip(
        'sc_mode_sw',
        '스위치',
        _switchMode,
        () => setState(() => _switchMode = true),
      ),
    ],
  );

  /// 조정 전·조정 후 고르기. [adjust]: 조정 후 설명의 조정 내용.
  Widget _phaseChips(String adjust) => _chips(
    '구분',
    '조정 전(As Found): 조정하기 전 측정값입니다.\n'
        '조정 후(As Left): $adjust 다시 측정한 값입니다.\n'
        '조정하지 않았으면 조정 전만 넣으십시오. 성적서에 둘 다 적힙니다.',
    [
      calcChip(
        'sc_phase_found',
        '조정 전',
        !_phaseLeft,
        () => setState(() => _phaseLeft = false),
      ),
      calcChip(
        'sc_phase_left',
        '조정 후',
        _phaseLeft,
        () => setState(() => _phaseLeft = true),
      ),
    ],
  );

  /// 기록 저장·저장한 기록 단추.
  Widget _saveButtons() => Row(
    children: [
      Expanded(
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            key: const Key('sc_save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: fc.brand,
              foregroundColor: fc.onBrand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _saveSheet,
            child: const Text(
              '기록 저장',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: SizedBox(
          height: 48,
          child: OutlinedButton(
            key: const Key('sc_records'),
            style: OutlinedButton.styleFrom(
              foregroundColor: fc.brand,
              side: BorderSide(color: fc.brand),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _openRecords,
            child: const Text(
              '저장한 기록',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
      ),
    ],
  );

  /// 설정(범위·출력 특성·측정 방법·허용오차)을 한 줄로 보이고 접고 펴기.
  Widget _settingsHeader() => Container(
    key: const Key('sc_settings'),
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
    decoration: BoxDecoration(
      color: fc.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: fc.line),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _settingsLine(),
            key: const Key('sc_settings_line'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: fc.text,
            ),
          ),
        ),
        calcToggle(
          'sc_settings_toggle',
          _settingsOpen ? '접기' : '설정 바꾸기',
          () => setState(() => _settingsOpen = !_settingsOpen),
        ),
      ],
    ),
  );

  List<Widget> _calSettings() => [
    ..._rangeFields('sc'),
    _chips(
      '측정 방법',
      '전송기 출력(mA): 표준기로 공정값을 넣고 출력 mA를 측정합니다(전송기 교정).\n'
          '루프 지시값: 표준기로 공정값을 넣고 DCS·지시계 값을 읽습니다(루프 점검). 지시값은 mA로 역산해 보여 줍니다.\n'
          'mA 입력 → 지시값: 루프 교정기로 mA를 넣고 DCS 입력 카드·지시계·밸브 행정을 읽습니다.',
      [
        for (final k in ReadKind.values)
          calcChip(
            'sc_kind_${k.name}',
            kindLabel(k),
            _kind == k,
            () => _changeKind(k),
          ),
      ],
    ),
    calcField(
      'sc_tol',
      '허용오차 (±%, 스팬)',
      _tol,
      '계기 정확도(데이터시트)나 교정 절차서의 허용오차입니다. 예: ±0.5%면 0.5. '
          '비우면 판정하지 않습니다. 출력 mA로 측정하면 16mA 스팬, 지시값이면 측정 범위 스팬 기준입니다. '
          '허용오차의 50%를 넘는 점은 조정을 권합니다(조정 한계).',
    ),
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final t in const ['0.1', '0.25', '0.5', '1'])
            calcChip('sc_tol_$t', '±$t%', _tol.text.trim() == t, () {
              setState(() => _tol.text = t);
            }),
        ],
      ),
    ),
    _chips(
      '시험점',
      '교정 절차서에 정한 시험점을 고르십시오.\n'
          '3점: 0·50·100%.\n5점: 0·25·50·75·100%(기본).\n11점: 0%부터 100%까지 10%씩.\n'
          '값을 넣은 뒤 바꾸면 새 시험점에도 있는 점의 값은 그대로 둡니다.',
      [
        for (final p in CalPointSet.values)
          calcChip(
            'sc_pts_${p.name}',
            calSetLabel(p),
            _pointSet == p,
            () => _changePoints(p, _withDown),
          ),
      ],
    ),
    calcSwitch(
      '하강 포함',
      _withDown,
      (v) => _changePoints(_pointSet, v),
      '상승(0% → 100%)으로 측정한 뒤 같은 점을 하강(100% → 0%)으로 다시 측정합니다. '
          '하강할 때는 목표점을 넘지 않게 위에서 맞추십시오.\n'
          '같은 점의 상승·하강 오차 차이가 히스테리시스입니다.',
      key: 'sc_down',
    ),
    if (_withDown)
      calcField(
        'sc_hyst_tol',
        '히스테리시스 허용값 (%, 선택)',
        _hystTol,
        '계기 데이터시트나 교정 절차서의 히스테리시스 허용값입니다(스팬 %). '
            '비우면 히스테리시스는 판정하지 않고 값만 보입니다. '
            '넣으면 하강 점의 히스테리시스가 이 값을 넘을 때 그 점을 불합격으로 판정합니다.',
      ),
    if (_kind != ReadKind.maIn && isCelsiusUnit(_u)) ..._sensorSettings(),
  ];

  /// 교정 점검의 센서 고르기(범위 단위가 °C일 때만 보인다).
  List<Widget> _sensorSettings() => [
    _chips(
      '센서',
      '온도 전송기를 교정할 때 교정기로 넣을 센서 값(저항 Ω, 열기전력 mV)을 점마다 보입니다. '
          '입력값은 그대로 °C로 넣습니다.\n'
          'Pt100·Pt1000: IEC 60751(α 0.00385).\n'
          '열전대: IEC 60584-1(NIST ITS-90 식).',
      [
        calcChip(
          'sc_sensor_none',
          '없음',
          _calSensor == null,
          () => setState(() => _calSensor = null),
        ),
        for (final t in TempSensor.values)
          calcChip(
            'sc_sensor_${t.name}',
            t.label,
            _calSensor == t,
            () => setState(() => _calSensor = t),
          ),
      ],
    ),
    if (_calSensor != null && !_calSensor!.isRtd)
      calcField('sc_cj', '냉접점 온도 (°C)', _calCj, _cjGuide, signed: true),
  ];

  static const String _cjGuide =
      '열전대 선이 전송기 단자에 물리는 곳의 온도입니다. '
      '교정기의 냉접점 보상을 끄고 mV로 넣을 때는 E(온도) − E(냉접점)을 넣어야 합니다. '
      '비우면 0 °C(기준접점 0 °C 표 값)로 계산합니다.';

  /// 시험점 바꾸기. 새 시험점에도 있는 점(같은 %·방향)의 값은 옮기고,
  /// 없어지는 점에 값이 있으면 먼저 묻는다.
  Future<void> _changePoints(CalPointSet set, bool withDown) async {
    if (set == _pointSet && withDown == _withDown) return;
    final oldDefs = _defs;
    final newDefs = calPointList(set, withDown: withDown);
    final lists = [_foundApplied, _foundReading, _leftApplied, _leftReading];
    final lost = [
      for (var i = 0; i < oldDefs.length; i++)
        if (!newDefs.contains(oldDefs[i]) &&
            lists.any((l) => l[i].text.trim().isNotEmpty))
          i,
    ];
    if (lost.isNotEmpty &&
        !await _confirm(
          '시험점 바꾸기',
          '새 시험점에 없는 점(${lost.map((i) => calPointLabel(oldDefs, i)).join(', ')})에 입력한 값은 지워집니다. 바꾸겠습니까?',
          '바꾸기',
        )) {
      return;
    }
    setState(() {
      for (final l in lists) {
        final old = [for (final c in l) c.text];
        for (final c in l) {
          c.clear();
        }
        for (var j = 0; j < newDefs.length; j++) {
          final i = oldDefs.indexOf(newDefs[j]);
          if (i >= 0) l[j].text = old[i];
        }
      }
      _pointSet = set;
      _withDown = withDown;
    });
  }

  /// 측정 방법을 바꾸면 입력한 값의 뜻이 달라지므로 먼저 묻는다.
  Future<void> _changeKind(ReadKind k) async {
    if (k == _kind) return;
    if (!_anyInput) {
      setState(() => _kind = k);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('측정 방법 바꾸기'),
        content: const Text('측정 방법을 바꾸면 입력한 값의 뜻이 달라집니다. 입력한 값을 지우고 바꾸겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            key: const Key('sc_kind_ok'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('지우고 바꾸기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _clearAllInputs();
      _kind = k;
    });
  }

  Widget _miniSummary(CalSummary s) {
    final w = s.worst!;
    final bad = s.pass == false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$_phase · 최대 오차 ${_signed(w.$2.errPct, 2)}%'
        '${s.pass == null ? '' : ' · ${calVerdictText(s.pass)}'}',
        key: const Key('sc_mini'),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: bad ? fc.danger : fc.brand,
        ),
      ),
    );
  }

  String _otherLine(CalSummary o) {
    final w = o.worst!;
    return '${_phaseLeft ? '조정 전' : '조정 후'}: 최대 오차 ${_signed(w.$2.errPct, 2)}%'
        '${o.pass == null ? '' : ' · ${calVerdictText(o.pass)}'}';
  }

  List<CalEntry> _entries(bool left) {
    final a = left ? _leftApplied : _foundApplied;
    final r = left ? _leftReading : _foundReading;
    return [
      for (var i = 0; i < _defs.length; i++)
        CalEntry(applied: _num(a[i]), reading: _num(r[i])),
    ];
  }

  CalSummary _summary(bool left, (double, double) range) => evaluateCal(
    entries: _entries(left),
    lrv: range.$1,
    urv: range.$2,
    transfer: _transfer,
    kind: _kind,
    tolPct: _num(_tol),
    points: _defs,
    hystTolPct: _hystTolActive,
  );

  void _clearAllInputs() {
    for (final c in [
      ..._foundApplied,
      ..._foundReading,
      ..._leftApplied,
      ..._leftReading,
    ]) {
      c.clear();
    }
  }

  Future<bool> _confirm(String title, String body, String okLabel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            key: const Key('sc_confirm_ok'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(okLabel, style: TextStyle(color: fc.danger)),
          ),
        ],
      ),
    );
    return ok == true && mounted;
  }

  Future<void> _confirmNewCheck() async {
    if (_switchMode) return _confirmNewSwitch();
    if (!_anyInput && _editing == null) return;
    if (!await _confirm(
      '새로 시작',
      '조정 전·후에 입력한 값을 모두 지우고 새로 시작하겠습니까? 저장한 기록은 지워지지 않습니다.',
      '새로 시작',
    )) {
      return;
    }
    setState(() {
      _clearAllInputs();
      _phaseLeft = false;
      _editing = null;
    });
  }

  Future<void> _confirmClearPhase() async {
    if (_switchMode) return _confirmClearSwitchPhase();
    if (![..._applied, ..._reading].any((c) => c.text.trim().isNotEmpty)) {
      return;
    }
    if (!await _confirm('이 표 지우기', '$_phase 표에 입력한 값을 지우겠습니까?', '지우기')) {
      return;
    }
    setState(() {
      for (final c in [..._applied, ..._reading]) {
        c.clear();
      }
    });
  }

  void _snack(String t, {SnackBarAction? action}) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t), action: action));

  Future<void> _saveSheet() async {
    final range = _range;
    if (_switchMode) {
      final a = _swSummary(false), b = _swSummary(true);
      if (a == null || b == null) {
        _snack('동작점 설정값을 넣으십시오.');
        return;
      }
      if (a.isEmpty && b.isEmpty) {
        _snack('동작점을 한 번 이상 넣으십시오.');
        return;
      }
    } else {
      if (range == null) {
        _snack('0% 값과 100% 값을 다르게 넣으십시오.');
        return;
      }
      if (_summary(false, range).isEmpty && _summary(true, range).isEmpty) {
        _snack('측정값을 한 점 이상 넣으십시오.');
        return;
      }
    }
    final ed = _editingForMode;
    final (lastWorker, lastRef) = await CalRecordStore.lastWorkerAndRef();
    if (!mounted) return;
    final res = await showModalBottomSheet<_SaveResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: fc.surface,
      builder: (_) => _CalSaveSheet(
        editing: ed,
        worker: ed?.worker ?? lastWorker,
        refStd: ed?.refStd ?? lastRef,
      ),
    );
    if (res == null || !mounted) return;
    final now = DateTime.now();
    final keep = !res.asNew && ed != null;
    final id = keep ? ed.id : now.microsecondsSinceEpoch.toString();
    final date = DateTime(
      res.calDate.year,
      res.calDate.month,
      res.calDate.day,
      now.hour,
      now.minute,
    );
    final rec = _switchMode
        ? _switchRecord(id, date, res)
        : _transmitterRecord(id, date, res, range!);
    await CalRecordStore.put(rec);
    if (!mounted) return;
    setState(() => _editing = rec);
    _snack(
      '${rec.tag} 기록을 저장했습니다.',
      action: SnackBarAction(
        label: '성적서 보기',
        onPressed: () => openCalRecordPdf(context, rec),
      ),
    );
  }

  /// 스위치 시험 기록. 측정 범위가 없으면 0% 값 = 100% 값으로 적는다(범위 없음).
  CalRecord _switchRecord(String id, DateTime date, _SaveResult res) {
    final range = _range;
    final l0 = _num(_lrv) ?? 0;
    final sensor = _swSensor;
    return CalRecord(
      id: id,
      date: date,
      nextDue: res.nextDue,
      tag: res.tag,
      instrument: res.instrument,
      model: res.model,
      refStd: res.refStd,
      worker: res.worker,
      ambient: res.ambient,
      memo: res.memo,
      lrv: range?.$1 ?? l0,
      urv: range?.$2 ?? l0,
      unit: _u,
      found: const [],
      sensor: sensor,
      cjC: sensor == null || sensor.isRtd ? null : _calCjC,
      sw: _swSpec,
      swFound: _swRepeats(false),
      swLeft: _swSummary(true)!.isEmpty ? const [] : _swRepeats(true),
    );
  }

  CalRecord _transmitterRecord(
    String id,
    DateTime date,
    _SaveResult res,
    (double, double) range,
  ) {
    final (l, u) = range;
    final tol = _num(_tol);
    return CalRecord(
      id: id,
      date: date,
      nextDue: res.nextDue,
      tag: res.tag,
      instrument: res.instrument,
      model: res.model,
      refStd: res.refStd,
      worker: res.worker,
      ambient: res.ambient,
      memo: res.memo,
      lrv: l,
      urv: u,
      unit: _u,
      transfer: _transfer,
      kind: _kind,
      tolPct: tol != null && tol > 0 ? tol : null,
      found: _entries(false),
      left: _summary(true, range).isEmpty ? const [] : _entries(true),
      points: _defs,
      hystTolPct: _hystTolActive,
      sensor: _sensorActive,
      cjC: _sensorActive == null || _sensorActive!.isRtd ? null : _calCjC,
    );
  }

  Future<void> _openRecords() async {
    final r = await Navigator.of(context).push<CalRecord>(
      MaterialPageRoute(builder: (_) => const CalRecordsPage()),
    );
    if (r == null || !mounted) return;
    String t(double? v) => v == null ? '' : _fmt(v, 6);
    if (r.isSwitch) {
      _loadSwitch(r);
      _snack('${r.tag} 기록을 불러왔습니다.');
      return;
    }
    setState(() {
      _switchMode = false;
      _lrv.text = _fmt(r.lrv, 6);
      _urv.text = _fmt(r.urv, 6);
      _unit.text = r.unit;
      _transfer = r.transfer;
      _kind = r.kind;
      _tol.text = r.tolPct == null ? '' : _fmt(r.tolPct!, 6);
      // 기록의 시험점을 그대로 쓴다(묶음과 다르면 5점, 같은 점의 값만 옮긴다).
      final (ps, dn) = calSetOf(r.points) ?? (CalPointSet.p5, false);
      _pointSet = ps;
      _withDown = dn;
      final defs = _defs;
      _clearAllInputs();
      for (var k = 0; k < r.points.length; k++) {
        final i = defs.indexOf(r.points[k]);
        if (i < 0) continue;
        final f = k < r.found.length ? r.found[k] : const CalEntry();
        final g = k < r.left.length ? r.left[k] : const CalEntry();
        _foundApplied[i].text = t(f.applied);
        _foundReading[i].text = t(f.reading);
        _leftApplied[i].text = t(g.applied);
        _leftReading[i].text = t(g.reading);
      }
      _hystTol.text = r.hystTolPct == null ? '' : _fmt(r.hystTolPct!, 6);
      _calSensor = r.sensor;
      if (r.cjC != null) _calCj.text = _fmt(r.cjC!, 6);
      _phaseLeft = false;
      _settingsOpen = false;
      _editing = r;
    });
    _snack('${r.tag} 기록을 불러왔습니다.');
  }

  /// 교정기에 넣을 센서 값 글: "Pt100 138.506 Ω", "K형 4.096 mV, 냉접점 20 °C면 3.298 mV".
  String _sensorText(TempSensor t, double tC) {
    final v0 = sensorValue(t, tC);
    if (v0 == null) return '${t.label} ${_rangeWord(t.tempRange, tC)}';
    final base = '${t.label} ${_fmt(v0)} ${t.unit}';
    final cj = _calCjC;
    if (t.isRtd || cj == 0) return base;
    final v = calibratorValue(t, tC, cjC: cj);
    return v == null
        ? '$base, 냉접점 ${_fmt(cj)} °C는 ${_rangeWord(t.tempRange, cj)}'
        : '$base, 냉접점 ${_fmt(cj)} °C면 ${_fmt(v)} mV';
  }

  /// 적용 범위를 벗어난 쪽: 범위 초과·범위 미만.
  String _rangeWord((double, double) r, double v) =>
      v > r.$2 ? '범위 초과' : '범위 미만';

  Widget _calRow(int i, double l, double u, CalSummary s) {
    final defs = s.defs;
    final r = s.points[i];
    final nominal = nominalInput(defs[i].pct, _kind, l, u);
    final applied = _num(_applied[i]) ?? nominal;
    final maIn = _kind == ReadKind.maIn;
    final expectedText = switch (_kind) {
      ReadKind.ma => '이론값 ${_fmt(idealMa(applied, l, u, _transfer))} mA',
      ReadKind.pv =>
        '이론값 ${_pv(applied)} · ${_fmt(idealMa(applied, l, u, _transfer))} mA',
      ReadKind.maIn => '이론값 ${_pv(pvFromMa(applied, l, u, _transfer))}',
    };
    final verdict = s.rowPass(i);
    final bad = verdict == false;
    final h = s.hystAt(i);
    final sensor = _sensorActive;
    return Container(
      key: Key('sc_row_$i'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 10),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bad ? fc.danger : fc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                calPointLabel(defs, i),
                key: Key('sc_label_$i'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: defs[i].down ? fc.textSub : fc.text,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  expectedText,
                  key: Key('sc_expected_$i'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: fc.brand,
                  ),
                ),
              ),
            ],
          ),
          if (sensor != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _sensorText(sensor, applied),
                key: Key('sc_sensor_val_$i'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: fc.text,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _smallField(
                  'sc_applied_$i',
                  maIn ? '입력 (mA)' : '입력값${_u.isEmpty ? '' : ' ($_u)'}',
                  _applied[i],
                  _fmt(nominal),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _smallField(
                  'sc_read_$i',
                  _kind == ReadKind.ma
                      ? '측정값 (mA)'
                      : '지시값${_u.isEmpty ? '' : ' ($_u)'}',
                  _reading[i],
                  '',
                  focus: _readFocus[i],
                  last: i == defs.length - 1,
                  onNext: i < defs.length - 1
                      ? () => _readFocus[i + 1].requestFocus()
                      : null,
                ),
              ),
            ],
          ),
          if (r != null && _kind != ReadKind.ma)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '환산 mA ${_fmt(idealMa(r.reading, l, u, _transfer))} (지시값 역산)',
                key: Key('sc_flow_$i'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: fc.text,
                ),
              ),
            ),
          if (r != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                // 판정을 앞에: 줄 끝에서 판정 글자가 두 줄로 끊기지 않게.
                '${verdict == null ? '' : '${calVerdictText(verdict)} · '}'
                '오차 ${_signed(r.errPct, 2)}%'
                '${r.errMa.isNaN ? '' : ' · ${_signed(r.errMa)} mA'}'
                '${r.errPv.isNaN ? '' : ' · ${_signed(r.errPv)}${_u.isEmpty ? '' : ' $_u'}'}',
                key: Key('sc_err_$i'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: bad ? fc.danger : fc.brand,
                ),
              ),
            ),
          if (h != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '히스테리시스 ${_fmt(h, 2)}%'
                '${s.hystPass(i) == null ? '' : (s.hystPass(i)! ? ' · 허용값 이내' : ' · 허용값 초과')}',
                key: Key('sc_hyst_$i'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: s.hystPass(i) == false ? fc.danger : fc.text,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _smallField(
    String key,
    String label,
    TextEditingController c,
    String hint, {
    FocusNode? focus,
    bool last = false,
    VoidCallback? onNext,
  }) => TextField(
    key: Key(key),
    controller: c,
    focusNode: focus,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    textInputAction: onNext != null
        ? TextInputAction.next
        : (last ? TextInputAction.done : null),
    onSubmitted: onNext == null ? null : (_) => onNext(),
    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fc.text),
    decoration: InputDecoration(
      isDense: true,
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    onChanged: (_) => setState(() {}),
  );

  // ─────────────── ② 교정 점검: 스위치 시험 ───────────────

  /// 스위치 설정. 동작점 설정값이 없으면 null.
  SwitchSpec? get _swSpec {
    final sp = _num(_swSet);
    return sp == null ? null : _swSpecAt(sp);
  }

  SwitchSpec _swSpecAt(double setpoint) {
    final rv = _num(_swRval);
    final tol = _num(_swTol);
    return SwitchSpec(
      dir: _swDir,
      setpoint: setpoint,
      resetSet: _swRref == _ResetRef.reset ? rv : null,
      dbSet: _swRref == _ResetRef.deadband && rv != null ? rv.abs() : null,
      tolMode: _swTolMode,
      tol: tol != null && tol > 0 ? tol : null,
      dbMin: _num(_swDbMin),
      dbMax: _num(_swDbMax),
      contact: _swContact,
    );
  }

  List<SwitchRepeat> _swRepeats(bool left) {
    final t = left ? _swLeftTrip : _swFoundTrip;
    final r = left ? _swLeftReset : _swFoundReset;
    return [
      for (var i = 0; i < kSwitchRepeats; i++)
        SwitchRepeat(trip: _num(t[i]), reset: _num(r[i])),
    ];
  }

  /// 한 벌의 결과. 동작점 설정값이 없으면 null.
  SwitchSummary? _swSummary(bool left) {
    final sp = _swSpec;
    if (sp == null) return null;
    return evaluateSwitch(spec: sp, repeats: _swRepeats(left), range: _range);
  }

  /// 스위치 시험에 쓰는 센서: 단위가 °C일 때만.
  TempSensor? get _swSensor => isCelsiusUnit(_u) ? _calSensor : null;

  bool get _swAnyInput => [
    ..._swFoundTrip,
    ..._swFoundReset,
    ..._swLeftTrip,
    ..._swLeftReset,
  ].any((c) => c.text.trim().isNotEmpty);

  /// 부호를 붙인 값과 단위: "+0.05 bar".
  String _spv(double v) => _u.isEmpty ? _signed(v) : '${_signed(v)} $_u';

  String get _uu => _u.isEmpty ? '' : ' ($_u)';

  String _swSettingsLine() {
    final sp = _swSpecAt(_num(_swSet) ?? 0);
    final hasSet = _num(_swSet) != null;
    final tol = switchTolText(sp, _u);
    final db = switchDbRangeText(sp, _u);
    return [
      '스위치',
      switchDirLabel(_swDir),
      hasSet ? '동작점 ${_pv(sp.setpoint)}' : '동작점 없음',
      if (sp.resetSet != null) '복귀점 ${_pv(sp.resetSet!)}',
      if (sp.dbSet != null) '데드밴드 ${_pv(sp.dbSet!)}',
      tol.isEmpty ? '허용오차 없음' : tol,
      if (db.isNotEmpty) '데드밴드 $db',
      if (_swContact != null) switchContactLabel(_swContact!),
      if (_swSensor != null) _swSensor!.label,
    ].join(' · ');
  }

  Widget _switchTab() {
    final sp = _swSpec;
    final s = _swSummary(_phaseLeft);
    final other = _swSummary(!_phaseLeft);
    return _page([
      ..._editingBanner(),
      _modeChips(),
      _settingsHeader(),
      if (_settingsOpen) ..._swSettings(),
      _phaseChips('동작점·데드밴드를 조정한 뒤'),
      if (sp != null && _swSensor != null) _swSensorCard(sp, _swSensor!),
      if (s != null && !s.isEmpty) _swMini(s),
      for (var i = 0; i < kSwitchRepeats; i++) _swRow(i, s),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          calcToggle('sc_new', '새로 시작', _confirmNewCheck),
          calcToggle('sc_clear', '이 표 지우기', _confirmClearPhase),
        ],
      ),
      const SizedBox(height: 4),
      _swResult(sp, s, other),
      const SizedBox(height: 12),
      _saveButtons(),
    ]);
  }

  List<Widget> _swSettings() {
    final pct = _swTolMode == SwitchTolMode.pct;
    return [
      _chips(
        '동작 방향',
        '상승 동작: 값이 올라갈 때 동작하는 스위치입니다(고압·고온·고레벨 경보, H·HH). '
            '동작점 아래에서 천천히 올려 동작점을 찾고, 다시 천천히 내려 복귀점을 찾습니다.\n'
            '하강 동작: 값이 내려갈 때 동작하는 스위치입니다(저압·저유량·저레벨 경보, L·LL). '
            '동작점 위에서 천천히 내려 동작점을 찾고, 다시 천천히 올려 복귀점을 찾습니다.\n'
            '동작점 가까이에서는 아주 천천히 바꾸십시오. 빨리 바꾸면 동작점이 늦게 측정됩니다.',
        [
          for (final d in SwitchDir.values)
            calcChip(
              'sw_dir_${d.name}',
              switchDirLabel(d),
              _swDir == d,
              () => setState(() => _swDir = d),
            ),
        ],
      ),
      _unitField('sw'),
      calcField(
        'sw_set',
        '동작점 설정값$_uu',
        _swSet,
        '스위치가 동작해야 하는 값입니다. 계기 명판·설정표·인터록 목록에 있습니다.',
        signed: true,
      ),
      _chips(
        '복귀 설정',
        '복귀점: 스위치가 원래 상태로 돌아와야 하는 값을 알면 고르십시오.\n'
            '데드밴드: 동작점과 복귀점의 차이(차압) 설정값을 알면 고르십시오.\n'
            '고르면 복귀점 또는 데드밴드도 같은 허용오차로 판정합니다. 모르면 없음.',
        [
          for (final (r, label) in const [
            (_ResetRef.none, '없음'),
            (_ResetRef.reset, '복귀점'),
            (_ResetRef.deadband, '데드밴드'),
          ])
            calcChip(
              'sw_rref_${r.name}',
              label,
              _swRref == r,
              () => setState(() => _swRref = r),
            ),
        ],
      ),
      if (_swRref != _ResetRef.none)
        calcField(
          'sw_rval',
          _swRref == _ResetRef.reset ? '복귀점 설정값$_uu' : '데드밴드 설정값$_uu',
          _swRval,
          _swRref == _ResetRef.reset
              ? '스위치가 원래 상태로 돌아와야 하는 값입니다.'
              : '동작점과 복귀점의 차이 설정값입니다. 상승 동작이면 복귀점 = 동작점 − 데드밴드, '
                    '하강 동작이면 복귀점 = 동작점 + 데드밴드입니다.',
          signed: _swRref == _ResetRef.reset,
        ),
      _chips(
        '허용오차 방식',
        '단위: 허용오차를 단위 값으로 넣습니다(예: ±0.1 bar).\n'
            '% 범위: 측정 범위 스팬의 %로 넣습니다(예: 0~10 bar의 ±1% = ±0.1 bar). '
            '0% 값과 100% 값이 필요합니다.',
        [
          calcChip(
            'sw_tolm_unit',
            '단위',
            !pct,
            () => setState(() => _swTolMode = SwitchTolMode.unit),
          ),
          calcChip(
            'sw_tolm_pct',
            '% 범위',
            pct,
            () => setState(() => _swTolMode = SwitchTolMode.pct),
          ),
        ],
      ),
      calcField(
        'sw_tol',
        pct ? '허용오차 (±%, 범위)' : '허용오차 (±$_u)',
        _swTol,
        '계기 데이터시트나 교정 절차서의 동작점 허용오차입니다. '
            '비우면 판정하지 않습니다. 반복마다 |동작점 − 동작점 설정값| ≤ 허용오차면 합격입니다.',
      ),
      calcField(
        'sw_lrv',
        pct ? '범위 0% 값' : '범위 0% 값 (선택)',
        _lrv,
        '계기 측정 범위의 아래 값입니다. % 범위 허용오차와 오차 %에만 씁니다. '
            '전송기 교정 점검과 같은 칸입니다.',
        signed: true,
      ),
      calcField(
        'sw_urv',
        pct ? '범위 100% 값' : '범위 100% 값 (선택)',
        _urv,
        '계기 측정 범위의 위 값입니다. % 범위 허용오차와 오차 %에만 씁니다.',
        signed: true,
      ),
      calcField(
        'sw_dbmin',
        '데드밴드 최소 (선택)$_uu',
        _swDbMin,
        '데드밴드(|동작점 − 복귀점|)가 이 값 미만이면 불합격입니다. 명판·데이터시트의 데드밴드 범위를 넣으십시오.',
      ),
      calcField(
        'sw_dbmax',
        '데드밴드 최대 (선택)$_uu',
        _swDbMax,
        '데드밴드가 이 값을 초과하면 불합격입니다.',
      ),
      _chips(
        '접점',
        '시험한 접점을 기록합니다. 판정에는 쓰지 않습니다.\n'
            'NO (a접점): 평소 열려 있다가 동작하면 닫힙니다.\n'
            'NC (b접점): 평소 닫혀 있다가 동작하면 열립니다.',
        [
          calcChip(
            'sw_ct_none',
            '기록 안 함',
            _swContact == null,
            () => setState(() => _swContact = null),
          ),
          for (final c in SwitchContact.values)
            calcChip(
              'sw_ct_${c.name}',
              switchContactLabel(c),
              _swContact == c,
              () => setState(() => _swContact = c),
            ),
        ],
      ),
      if (isCelsiusUnit(_u)) ..._sensorSettings(),
    ];
  }

  /// 온도 스위치: 동작점·복귀점 설정값에 해당하는 센서 값.
  Widget _swSensorCard(SwitchSpec sp, TempSensor t) {
    final target = sp.resetTarget;
    return Container(
      key: const Key('sw_sensor'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '동작점 ${_pv(sp.setpoint)}: ${_sensorText(t, sp.setpoint)}',
            key: const Key('sw_sensor_set'),
            style: TextStyle(fontWeight: FontWeight.w700, color: fc.text),
          ),
          if (target != null)
            Text(
              '복귀점 ${_pv(target)}: ${_sensorText(t, target)}',
              key: const Key('sw_sensor_reset'),
              style: TextStyle(fontWeight: FontWeight.w700, color: fc.text),
            ),
        ],
      ),
    );
  }

  Widget _swMini(SwitchSummary s) {
    final w = s.worst!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$_phase · 최대 오차 ${_spv(w.$2.err)}'
        '${s.pass == null ? '' : ' · ${calVerdictText(s.pass)}'}',
        key: const Key('sw_mini'),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: s.pass == false ? fc.danger : fc.brand,
        ),
      ),
    );
  }

  /// 데드밴드 허용 범위를 벗어난 쪽.
  String _dbSide(SwitchSpec sp, double db) =>
      sp.dbMax != null && db > sp.dbMax! ? '초과' : '미만';

  Widget _swRow(int i, SwitchSummary? s) {
    final row = s?.rows[i];
    final sp = s?.spec;
    final v = row?.pass;
    final bad = v == false;
    TextStyle st(bool red) => TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: red ? fc.danger : fc.brand,
    );
    final target = sp?.resetTarget;
    return Container(
      key: Key('sw_row_$i'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 10),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bad ? fc.danger : fc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '반복 ${i + 1}',
            key: Key('sw_label_$i'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: fc.text,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _smallField(
                  'sw_trip_$i',
                  '동작점$_uu',
                  _swTrip[i],
                  sp == null ? '' : _fmt(sp.setpoint),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _smallField(
                  'sw_reset_$i',
                  '복귀점$_uu',
                  _swReset[i],
                  target == null ? '' : _fmt(target),
                ),
              ),
            ],
          ),
          if (row != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                // 판정을 앞에: 줄 끝에서 판정 글자가 두 줄로 끊기지 않게.
                '${v == null ? '' : '${calVerdictText(v)} · '}'
                '오차 ${_spv(row.err)}'
                '${row.errPct == null ? '' : ' (${_signed(row.errPct!, 2)}%)'}',
                key: Key('sw_err_$i'),
                style: st(row.tripPass == false || bad),
              ),
            ),
          if (row?.deadband != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '데드밴드 ${_pv(row!.deadband!)}'
                '${row.dbRangePass == null ? '' : (row.dbRangePass! ? ' · 허용 범위 이내' : ' · 허용 범위 ${_dbSide(sp!, row.deadband!)}')}',
                key: Key('sw_db_$i'),
                style: st(row.dbRangePass == false),
              ),
            ),
          if (row?.resetErr != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${sp!.resetSet != null ? '복귀점 오차' : '데드밴드 오차'} ${_spv(row!.resetErr!)}'
                '${row.resetPass == null ? '' : (row.resetPass! ? ' · 허용오차 이내' : ' · 허용오차 초과')}',
                key: Key('sw_rerr_$i'),
                style: st(row.resetPass == false),
              ),
            ),
          if (row != null && row.wrongSide)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _swDir == SwitchDir.rising
                    ? '복귀점이 동작점보다 높습니다. 동작 방향을 확인하십시오.'
                    : '복귀점이 동작점보다 낮습니다. 동작 방향을 확인하십시오.',
                key: Key('sw_side_$i'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fc.danger,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 불합격 사유(반복마다).
  List<String> _swFailReasons(SwitchSummary s) {
    final tolU = s.tolUnit;
    final sp = s.spec;
    final out = <String>[];
    for (final (i, r) in s.measured) {
      final n = '반복 ${i + 1}';
      if (r.tripPass == false && tolU != null) {
        out.add('$n: 동작점 오차 ${_spv(r.err)}, 허용오차 ±${_pv(tolU)} 초과.');
      }
      if (r.resetPass == false && tolU != null) {
        out.add(
          '$n: ${sp.resetSet != null ? '복귀점 오차' : '데드밴드 오차'} '
          '${_spv(r.resetErr!)}, 허용오차 ±${_pv(tolU)} 초과.',
        );
      }
      if (r.dbRangePass == false) {
        out.add(
          '$n: 데드밴드 ${_pv(r.deadband!)}, '
          '허용 범위(${switchDbRangeText(sp, _u)}) ${_dbSide(sp, r.deadband!)}.',
        );
      }
    }
    return out;
  }

  String _swOtherLine(SwitchSummary o) {
    final w = o.worst!;
    return '${_phaseLeft ? '조정 전' : '조정 후'}: 최대 오차 ${_spv(w.$2.err)}'
        '${o.pass == null ? '' : ' · ${calVerdictText(o.pass)}'}';
  }

  Widget _swResult(SwitchSpec? sp, SwitchSummary? s, SwitchSummary? other) {
    if (sp == null || s == null) {
      return calcResult(
        key: const Key('sw_result'),
        big: '—',
        caption: '동작점 설정값을 넣으십시오',
        lines: const [],
      );
    }
    if (s.isEmpty) {
      return calcResult(
        key: const Key('sw_result'),
        big: '—',
        caption: '$_phase: 동작점을 한 번 이상 넣으십시오',
        lines: [
          if (other != null && !other.isEmpty) _swOtherLine(other),
          '보통 3회 반복합니다. 반복마다 동작점과 복귀점을 넣으십시오.',
        ],
      );
    }
    final w = s.worst!;
    final n = s.measured.length;
    final fails = s.failed;
    final missing = s.resetMissing;
    final rp = s.repeatability;
    final avgR = s.avgReset, avgDb = s.avgDeadband;
    final tolU = s.tolUnit;
    return calcResult(
      key: const Key('sw_result'),
      big: _spv(w.$2.err),
      caption: s.pass == null
          ? '$_phase 동작점 최대 오차'
          : fails.isEmpty
          ? '$_phase 합격: $n회 모두 합격'
          : '$_phase 불합격: $n회 중 ${fails.length}회 불합격',
      warn: fails.isNotEmpty,
      lines: [
        if (s.pass == null)
          s.tolNeedsRange
              ? '% 범위 허용오차는 0% 값과 100% 값을 다르게 넣어야 판정합니다.'
              : '허용오차나 데드밴드 허용 범위를 넣으면 합격·불합격을 판정합니다.',
        ..._swFailReasons(s),
        '최대 오차: 반복 ${w.$1 + 1}'
            '${w.$2.errPct == null ? '' : ' (범위의 ${_signed(w.$2.errPct!, 2)}%)'}'
            '${tolU == null ? '' : ', 허용오차 ±${_pv(tolU)}'}',
        '평균 동작점 ${_pv(s.avgTrip!)}'
            '${avgR == null ? '' : ' · 평균 복귀점 ${_pv(avgR)}'}',
        if (avgDb != null) '평균 데드밴드 ${_pv(avgDb)}',
        if (rp != null) '반복성(동작점 최대 − 최소): ${_pv(rp)}',
        if (missing.isNotEmpty)
          '복귀점을 넣지 않은 반복(${missing.map((i) => '반복 ${i + 1}').join(', ')})은 '
              '복귀점·데드밴드를 판정하지 않았습니다.',
        if (s.measured.any((e) => e.$2.wrongSide))
          '동작 방향과 반대쪽에 복귀점이 있는 반복이 있습니다. 동작 방향(${switchDirLabel(_swDir)})을 확인하십시오.',
        if (other != null && !other.isEmpty) _swOtherLine(other),
        '오차 = 측정한 동작점 − 동작점 설정값',
        '데드밴드 = |동작점 − 복귀점|',
      ],
    );
  }

  Future<void> _confirmNewSwitch() async {
    if (!_swAnyInput && _editingForMode == null) return;
    if (!await _confirm(
      '새로 시작',
      '스위치 시험의 조정 전·후에 입력한 값을 모두 지우고 새로 시작하겠습니까? 저장한 기록은 지워지지 않습니다.',
      '새로 시작',
    )) {
      return;
    }
    setState(() {
      _clearSwitchInputs();
      _phaseLeft = false;
      _editing = null;
    });
  }

  Future<void> _confirmClearSwitchPhase() async {
    if (![..._swTrip, ..._swReset].any((c) => c.text.trim().isNotEmpty)) {
      return;
    }
    if (!await _confirm('이 표 지우기', '$_phase 표에 입력한 값을 지우겠습니까?', '지우기')) {
      return;
    }
    setState(() {
      for (final c in [..._swTrip, ..._swReset]) {
        c.clear();
      }
    });
  }

  void _clearSwitchInputs() {
    for (final c in [
      ..._swFoundTrip,
      ..._swFoundReset,
      ..._swLeftTrip,
      ..._swLeftReset,
    ]) {
      c.clear();
    }
  }

  /// 스위치 기록 불러오기: 설정·반복 값·센서를 되살린다.
  void _loadSwitch(CalRecord r) {
    final sp = r.sw!;
    String t(double? v) => v == null ? '' : _fmt(v, 6);
    setState(() {
      _switchMode = true;
      final range = r.switchRange;
      if (range != null) {
        _lrv.text = t(range.$1);
        _urv.text = t(range.$2);
      }
      _unit.text = r.unit;
      _swDir = sp.dir;
      _swSet.text = t(sp.setpoint);
      _swRref = sp.resetSet != null
          ? _ResetRef.reset
          : (sp.dbSet != null ? _ResetRef.deadband : _ResetRef.none);
      _swRval.text = t(sp.resetSet ?? sp.dbSet);
      _swTolMode = sp.tolMode;
      _swTol.text = t(sp.tol);
      _swDbMin.text = t(sp.dbMin);
      _swDbMax.text = t(sp.dbMax);
      _swContact = sp.contact;
      _clearSwitchInputs();
      for (var i = 0; i < kSwitchRepeats; i++) {
        final f = i < r.swFound.length ? r.swFound[i] : const SwitchRepeat();
        final g = i < r.swLeft.length ? r.swLeft[i] : const SwitchRepeat();
        _swFoundTrip[i].text = t(f.trip);
        _swFoundReset[i].text = t(f.reset);
        _swLeftTrip[i].text = t(g.trip);
        _swLeftReset[i].text = t(g.reset);
      }
      _calSensor = r.sensor;
      if (r.cjC != null) _calCj.text = _fmt(r.cjC!, 6);
      _phaseLeft = false;
      _settingsOpen = false;
      _editing = r;
    });
  }

  // ─────────────── ③ 루프 전압 ───────────────

  Widget _loopTab() {
    final vs = _num(_supply);
    final vmin = _num(_minV);
    final len = _num(_wireLen);
    final wireDirect = _num(_wireR);
    final wire =
        wireDirect ??
        (len == null || len <= 0
            ? 0.0
            : wireLoopOhm(ohmPerKm: cuResistance(_wireSize, 20), lengthM: len));
    final hart = _num(_hartR) ?? 0;
    final barrier = _num(_barrierR) ?? 0;
    final extra = _num(_extraV) ?? 0;
    final lc = vs == null || vmin == null
        ? null
        : loopCheck(
            supplyV: vs,
            minV: vmin,
            ohms: [hart, barrier, wire],
            checkMa: _checkMa,
            extraV: extra,
          );
    final cm = _fmt(_checkMa, 2);
    return _page([
      calcField(
        'sl_supply',
        '전원 전압 (V)',
        _supply,
        '루프 전원(DCS 카드·전원 장치) 전압입니다. 보통 24V DC입니다.',
      ),
      calcField(
        'sl_minv',
        '계기 최소 동작 전압 (V)',
        _minV,
        '전송기가 동작하는 최소 단자 전압입니다. 데이터시트 "Power supply" 항목에 있습니다. '
            '예: Rosemount 3051(4-20mA HART) 10.5V. 계기마다 다르니 확인해 넣으십시오.',
      ),
      calcField(
        'sl_hart',
        'HART·입력 저항 (Ω)',
        _hartR,
        'DCS 입력 카드나 HART 통신용 저항입니다. HART 통신에는 루프 저항 230Ω 이상이 필요해 보통 250Ω을 씁니다. '
            '카드 사양서의 입력 저항을 넣으십시오.',
      ),
      calcField(
        'sl_barrier',
        '배리어·절연기 (Ω)',
        _barrierR,
        '방폭 배리어·신호 절연기의 직렬 저항입니다(사양서). 없으면 0.',
      ),
      calcField(
        'sl_extra',
        '지시계·기타 전압 강하 (V)',
        _extraV,
        '루프 지시계처럼 전류와 상관없이 전압을 먹는 기기의 전압 강하입니다(사양서). 없으면 0.',
      ),
      calcField(
        'sl_len',
        '편도 길이 (m)',
        _wireLen,
        '계기에서 판넬까지 편도 길이입니다. 왕복(두 가닥)으로 계산합니다.',
      ),
      _chips('전선 굵기', '계장 케이블 굵기입니다(IEC 60228 2종 구리, 20°C 저항).', [
        for (final s in _wireSizes)
          calcChip(
            'sl_sq_${_fmt(s)}',
            '${_fmt(s)}sq',
            _wireSize == s,
            () => setState(() => _wireSize = s),
          ),
      ]),
      calcField(
        'sl_wire_r',
        '전선 저항 직접 입력 (Ω, 왕복)',
        _wireR,
        '1.25sq처럼 목록에 없는 굵기이거나 실측값이 있으면 넣으십시오. 입력하면 길이·굵기 대신 이 값으로 계산합니다.',
      ),
      _chips(
        '확인 전류',
        '고장 신호(상한)까지 낼 수 있는지 확인할 전류입니다.\n'
            '21mA: NAMUR NE43 고장 신호 하한.\n'
            '21.75mA: Rosemount 3051 기본 고장 신호.\n'
            '22.5mA: Rosemount NAMUR 설정.\n'
            '23mA: Rosemount 3051 최대 루프 저항 식(43.5 × (전원 − 10.5)) 기준.\n'
            '계기의 고장 신호 설정값을 고르십시오. 모르면 23mA가 안전합니다.',
        [
          for (final m in kLoopCheckMa)
            calcChip(
              'sl_cm_${_fmt(m, 2)}',
              '${_fmt(m, 2)}mA',
              _checkMa == m,
              () => setState(() => _checkMa = m),
            ),
        ],
      ),
      const SizedBox(height: 4),
      if (lc == null)
        calcResult(
          big: '—',
          caption: '전원 전압과 계기 최소 동작 전압을 넣으십시오',
          lines: const [],
        )
      else
        calcResult(
          key: const Key('sl_result'),
          big: '${_fmt(lc.voltsCheck, 2)} V',
          caption: lc.okAtCheck(vmin!)
              ? '${cm}mA 때 계기 단자 전압: 충분'
              : lc.okAt20(vmin)
              ? '전압 부족: ${cm}mA 고장 신호를 낼 수 없습니다'
              : '전압 부족: 20mA도 낼 수 없습니다',
          warn: !lc.okAtCheck(vmin),
          lines: [
            '루프 총저항 ${_fmt(lc.totalOhm, 1)}Ω (전선 ${_fmt(wire, 1)}Ω)',
            '20mA 때 단자 전압 ${_fmt(lc.volts20, 2)} V (최소 동작 전압 ${_fmt(vmin)} V)',
            '최대 루프 저항 ${_fmt(lc.maxOhm, 0)}Ω (${cm}mA 기준)',
            if (lc.totalOhm < 230)
              'HART 통신을 하려면 루프 저항이 230Ω 이상이어야 합니다(보통 250Ω).',
            '식: 단자 전압 = 전원 − 전류 × 루프 저항 − 기타 전압 강하.',
          ],
        ),
    ]);
  }

  // ─────────────── ④ 온도 센서 ───────────────

  String _tRange((double, double) r, String unit) =>
      '${_fmt(r.$1)} ~ ${_fmt(r.$2)} $unit';

  Widget _tempTab() {
    final s = _tSensor;
    final v = _num(_tValue);
    final cjText = _tCj.text.trim();
    final cj = _num(_tCj) ?? 0;
    final cjE = s.isRtd ? 0.0 : tcEmf(s, cj);
    final std = s.isRtd
        ? '기준: IEC 60751 (α 0.00385, Callendar–Van Dusen 식)'
        : '기준: IEC 60584-1 (NIST ITS-90 기준 함수)';
    Widget result;
    if (v == null) {
      result = calcResult(big: '—', caption: '값을 넣으십시오', lines: const []);
    } else if (cjE == null) {
      result = calcResult(
        key: const Key('st_result'),
        big: '—',
        caption: '냉접점 온도를 ${_tRange(s.tempRange, '°C')} 이내로 넣으십시오',
        warn: true,
        lines: const [],
      );
    } else if (_tFromTemp) {
      final e0 = sensorValue(s, v);
      if (e0 == null) {
        result = calcResult(
          key: const Key('st_result'),
          big: _rangeWord(s.tempRange, v),
          caption: '${s.label} 적용 범위: ${_tRange(s.tempRange, '°C')}',
          warn: true,
          lines: [std],
        );
      } else if (s.isRtd) {
        result = calcResult(
          key: const Key('st_result'),
          big: '${_fmt(e0)} Ω',
          caption: '${s.label} 저항',
          lines: [
            std,
            'R0 = ${_fmt(s.r0)} Ω, 적용 범위 ${_tRange(s.tempRange, '°C')}',
          ],
        );
      } else {
        final withCj = cj != 0;
        result = calcResult(
          key: const Key('st_result'),
          big: '${_fmt(e0 - cjE)} mV',
          caption: withCj
              ? '교정기에 넣을 mV (냉접점 ${_fmt(cj)} °C)'
              : '${s.label} 열기전력 (기준접점 0 °C)',
          lines: [
            '기준접점 0 °C mV: ${_fmt(e0)} mV',
            if (withCj)
              '교정기에 넣을 mV = E(온도) − E(냉접점) = ${_fmt(e0)} − ${_fmt(cjE)} = ${_fmt(e0 - cjE)} mV',
            std,
            '적용 범위: ${_tRange(s.tempRange, '°C')}',
          ],
        );
      }
    } else {
      final total = v + cjE;
      final t = sensorTemp(s, total);
      final vr = s.valueRange;
      if (t == null) {
        result = calcResult(
          key: const Key('st_result'),
          big: _rangeWord(vr, total),
          caption:
              '${s.label} 적용 범위: ${_tRange(vr, s.unit)} (${_tRange(s.inverseTempRange, '°C')})',
          warn: true,
          lines: [std],
        );
      } else {
        result = calcResult(
          key: const Key('st_result'),
          big: '${_fmt(t, 2)} °C',
          caption: s.isRtd
              ? '${s.label} 온도'
              : (cj != 0
                    ? '${s.label} 온도 (냉접점 ${_fmt(cj)} °C 보상)'
                    : '${s.label} 온도 (기준접점 0 °C)'),
          lines: [
            if (!s.isRtd && cj != 0)
              '측정 mV + E(냉접점) = ${_fmt(v)} + ${_fmt(cjE)} = ${_fmt(total)} mV',
            std,
            '적용 범위: ${_tRange(vr, s.unit)} (${_tRange(s.inverseTempRange, '°C')})',
          ],
        );
      }
    }
    return _page([
      _chips(
        '센서',
        'Pt100·Pt1000: 백금 측온저항체, IEC 60751(α 0.00385). 0 °C에서 100 Ω·1000 Ω입니다.\n'
            'K·J·T·E·N·R·S·B형: 열전대, IEC 60584-1. NIST ITS-90 기준 함수로 계산합니다.\n'
            '센서 명판이나 전송기 설정(센서 종류)을 보고 고르십시오.',
        [
          for (final t in TempSensor.values)
            calcChip(
              'st_s_${t.name}',
              t.label,
              _tSensor == t,
              () => setState(() => _tSensor = t),
            ),
        ],
      ),
      _chips(
        '계산 방향',
        '°C → ${s.unit}: 온도에 해당하는 센서 값을 계산합니다(교정기로 넣을 값).\n'
            '${s.unit} → °C: 단자에서 측정한 센서 값을 온도로 역산합니다.',
        [
          calcChip(
            'st_dir_t',
            '°C → ${s.unit}',
            _tFromTemp,
            () => setState(() => _tFromTemp = true),
          ),
          calcChip(
            'st_dir_v',
            '${s.unit} → °C',
            !_tFromTemp,
            () => setState(() => _tFromTemp = false),
          ),
        ],
      ),
      calcField(
        'st_value',
        _tFromTemp ? '온도 (°C)' : (s.isRtd ? '저항 (Ω)' : '열기전력 (mV)'),
        _tValue,
        _tFromTemp
            ? '센서 값을 알고 싶은 온도입니다.'
            : (s.isRtd
                  ? '측온저항체 단자에서 측정한 저항입니다. 2선식이면 도선 저항이 더해져 있으니 빼고 넣으십시오.'
                  : '열전대 단자(냉접점)에서 측정한 mV입니다.'),
        signed: true,
      ),
      if (!s.isRtd)
        calcField('st_cj', '냉접점 온도 (°C)', _tCj, _cjGuide, signed: true),
      if (!s.isRtd && cjText.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '냉접점 온도가 비어 있어 0 °C로 계산합니다.',
            style: TextStyle(fontSize: 13, color: fc.textSub),
          ),
        ),
      const SizedBox(height: 4),
      result,
      const SizedBox(height: 12),
      _tempTable(cjE),
    ]);
  }

  /// 측정 범위(환산 탭)가 °C이면 그 범위의 5점 표: % · °C · Ω/mV · mA.
  Widget _tempTable(double? cjE) {
    final s = _tSensor;
    final range = _range;
    if (range == null || !isCelsiusUnit(_u)) {
      return Text(
        '환산 탭의 측정 범위 단위를 °C로 넣으면 그 범위의 5점 표가 여기에 나옵니다.',
        key: const Key('st_table_hint'),
        style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.4),
      );
    }
    final (l, u) = range;
    final cj = _num(_tCj) ?? 0;
    String val(double t) {
      final v0 = sensorValue(s, t);
      if (v0 == null) return _rangeWord(s.tempRange, t);
      if (s.isRtd) return _fmt(v0);
      return cjE == null ? '—' : _fmt(v0 - cjE);
    }

    return Container(
      key: const Key('st_table'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '5점 표 (${s.label}, ${_fmt(l)} ~ ${_fmt(u)} °C)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: fc.text,
            ),
          ),
          const SizedBox(height: 8),
          _tempRow('%', '°C', s.unit, 'mA', head: true),
          for (final p in _points)
            _tempRow(
              _fmt(p),
              _fmt(pctToPv(p, l, u), 2),
              val(pctToPv(p, l, u)),
              _fmt(maFromPct(outPctFromPvPct(p, _transfer))),
            ),
          if (!s.isRtd)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                cj == 0
                    ? 'mV는 기준접점 0 °C 값입니다.'
                    : 'mV는 냉접점 ${_fmt(cj)} °C를 뺀 값(교정기에 넣을 값)입니다.',
                style: TextStyle(fontSize: 13, color: fc.textSub),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tempRow(String a, String b, String c, String d, {bool head = false}) {
    final st = TextStyle(
      fontSize: 15,
      fontWeight: head ? FontWeight.w800 : FontWeight.w600,
      color: head ? fc.textSub : fc.text,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(a, style: st)),
          Expanded(flex: 3, child: Text(b, style: st)),
          Expanded(
            flex: 4,
            child: Text(c, style: st, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 3,
            child: Text(d, style: st, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

/// 저장 창에서 돌려주는 값. [asNew]: 새 기록으로(아니면 불러온 기록을 고침).
class _SaveResult {
  final bool asNew;
  final DateTime calDate;
  final DateTime? nextDue;
  final String tag, instrument, model, refStd, worker, ambient, memo;
  const _SaveResult({
    required this.asNew,
    required this.calDate,
    required this.nextDue,
    required this.tag,
    required this.instrument,
    required this.model,
    required this.refStd,
    required this.worker,
    required this.ambient,
    required this.memo,
  });
}

/// 차기 교정일 고르기: 없음·6개월·1년·2년.
const List<(String, int)> _dueChoices = [
  ('없음', 0),
  ('6개월', 6),
  ('1년', 12),
  ('2년', 24),
];

/// 교정 기록 저장 창. 입력 칸은 이 창이 만들고 치운다.
class _CalSaveSheet extends StatefulWidget {
  final CalRecord? editing;
  final String worker;
  final String refStd;
  const _CalSaveSheet({
    required this.editing,
    required this.worker,
    required this.refStd,
  });

  @override
  State<_CalSaveSheet> createState() => _CalSaveSheetState();
}

class _CalSaveSheetState extends State<_CalSaveSheet> {
  late final _tag = TextEditingController(text: widget.editing?.tag ?? '');
  late final _inst = TextEditingController(
    text: widget.editing?.instrument ?? '',
  );
  late final _model = TextEditingController(text: widget.editing?.model ?? '');
  late final _ref = TextEditingController(text: widget.refStd);
  late final _worker = TextEditingController(text: widget.worker);
  late final _ambient = TextEditingController(
    text: widget.editing?.ambient ?? '',
  );
  late final _memo = TextEditingController(text: widget.editing?.memo ?? '');
  late DateTime _calDate = widget.editing?.date ?? DateTime.now();
  late int _dueMonths = _initialDue();
  bool _tagError = false;

  int _initialDue() {
    final e = widget.editing;
    if (e?.nextDue == null) return 0;
    final m =
        (e!.nextDue!.year - e.date.year) * 12 +
        (e.nextDue!.month - e.date.month);
    return _dueChoices.any((c) => c.$2 == m) ? m : 0;
  }

  DateTime? get _nextDue => _dueMonths == 0
      ? null
      : DateTime(_calDate.year, _calDate.month + _dueMonths, _calDate.day);

  /// 불러온 기록의 태그를 바꾸면 다른 계기로 보고 "새로 저장"을 기본으로.
  bool get _tagChanged =>
      widget.editing != null && _tag.text.trim() != widget.editing!.tag;

  @override
  void dispose() {
    for (final c in [_tag, _inst, _model, _ref, _worker, _ambient, _memo]) {
      c.dispose();
    }
    super.dispose();
  }

  void _done(bool asNew) {
    if (_tag.text.trim().isEmpty) {
      setState(() => _tagError = true);
      return;
    }
    Navigator.pop(
      context,
      _SaveResult(
        asNew: asNew,
        calDate: _calDate,
        nextDue: _nextDue,
        tag: _tag.text.trim(),
        instrument: _inst.text.trim(),
        model: _model.text.trim(),
        refStd: _ref.text.trim(),
        worker: _worker.text.trim(),
        ambient: _ambient.text.trim(),
        memo: _memo.text.trim(),
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _calDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null && mounted) setState(() => _calDate = d);
  }

  Widget _field(
    String key,
    String label,
    TextEditingController c, {
    String? hint,
    bool error = false,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      key: Key(key),
      controller: c,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(fontSize: 16, color: fc.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error ? '태그 번호를 넣으십시오' : null,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ed = widget.editing;
    // 새 기록이거나 태그를 바꿨으면 "새로 저장"이 기본 단추.
    final primaryNew = ed == null || _tagChanged;
    final due = _nextDue;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ed == null ? '교정 기록 저장' : '교정 기록 고치기',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: fc.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '폰에만 저장됩니다. 성적서(PDF)는 "저장한 기록"에서 봅니다.',
              style: TextStyle(fontSize: 13, color: fc.textSub),
            ),
            const SizedBox(height: 12),
            _field(
              'cs_tag',
              '태그 번호',
              _tag,
              hint: '예: PT-101',
              error: _tagError,
              onChanged: (_) => setState(() {}),
            ),
            _field('cs_inst', '계기', _inst, hint: '예: 급수 펌프 토출 압력 전송기'),
            _field('cs_model', '제조사·모델', _model, hint: '예: Rosemount 3051'),
            _field('cs_ref', '표준기', _ref, hint: '모델·일련번호·교정 유효일'),
            _field('cs_worker', '작업자', _worker),
            _field('cs_ambient', '주위 조건', _ambient, hint: '예: 23°C, 45%RH'),
            Row(
              children: [
                Text(
                  '교정일',
                  style: TextStyle(fontWeight: FontWeight.w700, color: fc.text),
                ),
                const SizedBox(width: 8),
                TextButton(
                  key: const Key('cs_date'),
                  onPressed: _pickDate,
                  child: Text(
                    calDay(_calDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  '차기 교정일',
                  style: TextStyle(fontWeight: FontWeight.w700, color: fc.text),
                ),
                const SizedBox(width: 8),
                Text(
                  due == null ? '없음' : calDay(due),
                  key: const Key('cs_due_text'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: fc.brand,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (label, m) in _dueChoices)
                  ChoiceChip(
                    key: Key('cs_due_$m'),
                    label: Text(label),
                    selected: _dueMonths == m,
                    onSelected: (_) => setState(() => _dueMonths = m),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _field('cs_memo', '메모', _memo, maxLines: 2),
            const SizedBox(height: 4),
            Row(
              children: [
                if (ed != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      key: Key(
                        primaryNew ? 'cs_save_overwrite' : 'cs_save_new',
                      ),
                      onPressed: () => _done(!primaryNew),
                      child: Text(primaryNew ? '고쳐 저장' : '새로 저장'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton(
                    key: const Key('cs_save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: fc.brand,
                      foregroundColor: fc.onBrand,
                    ),
                    onPressed: () => _done(primaryNew),
                    child: Text(
                      ed == null ? '저장' : (primaryNew ? '새로 저장' : '고쳐 저장'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
