// 4-20mA 계산기(홈 "현장 작업" → 4-20mA 계산기). 탭: 환산(mA·%·측정값, NE43 신호 상태, 5점 표) →
// 교정 점검(넣은 값과 읽은 값의 스팬 % 오차, 허용 오차 판정) → 루프 전압(전원·저항·계기 최소 전압).
// 칸마다 "?" 안내. 계산은 signal_calc.dart, 근거는 docs/4-20mA계산기_근거.md.
import 'package:flutter/material.dart';

import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import '../electrical/elec_tables.dart' show cuResistance;
import 'signal_calc.dart';

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

const List<double> _points = [0, 25, 50, 75, 100];

/// 계장 전선 굵기(IEC 60228 2종) — 전기 계산기 저항 표에 있는 것.
const List<double> _wireSizes = [0.75, 1.0, 1.5, 2.5];

class SignalCalculatorPage extends StatefulWidget {
  const SignalCalculatorPage({super.key});

  @override
  State<SignalCalculatorPage> createState() => _SignalCalculatorPageState();
}

class _SignalCalculatorPageState extends State<SignalCalculatorPage>
    with SingleTickerProviderStateMixin, CalcFormParts {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  // 측정 범위(환산·교정 점검이 같이 씀)
  final _lrv = TextEditingController(text: '0');
  final _urv = TextEditingController(text: '10');
  final _unit = TextEditingController(text: 'bar');
  Transfer _transfer = Transfer.linear;

  // ① 환산
  _Input _input = _Input.ma;
  final _value = TextEditingController();

  // ② 교정 점검
  ReadKind _kind = ReadKind.ma;
  final _tol = TextEditingController();
  final _applied = [for (final _ in _points) TextEditingController()];
  final _reading = [for (final _ in _points) TextEditingController()];

  // ③ 루프 전압
  final _supply = TextEditingController(text: '24');
  final _minV = TextEditingController(text: '10.5');
  final _hartR = TextEditingController(text: '250');
  final _barrierR = TextEditingController(text: '0');
  final _wireLen = TextEditingController();
  double _wireSize = 1.5;
  final _wireR = TextEditingController();

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [
      _lrv,
      _urv,
      _unit,
      _value,
      _tol,
      ..._applied,
      ..._reading,
      _supply,
      _minV,
      _hartR,
      _barrierR,
      _wireLen,
      _wireR,
    ]) {
      c.dispose();
    }
    super.dispose();
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
            '4-20mA 계산기',
            style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
          ),
          bottom: TabBar(
            controller: _tabs,
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
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            controller: _tabs,
            children: [_convTab(), _calTab(), _loopTab()],
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

  /// 측정 범위 칸 — 두 탭에 같은 값.
  List<Widget> _rangeFields(String tab) => [
    calcField(
      '${tab}_lrv',
      '0% 값 (4mA)',
      _lrv,
      '계기가 4mA를 내는 측정값(LRV)입니다. 계기 명판·데이터시트·DCS 태그 설정에 적혀 있습니다. '
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
    calcBox(
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: calcLabel(
              '단위',
              '결과에 붙여 보일 단위입니다(bar, kPa, °C, m³/h 등). 계산에는 쓰지 않습니다.',
            ),
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
    ),
    calcSwitch(
      '제곱근 (차압 유량)',
      _transfer == Transfer.sqrt,
      (v) => setState(() => _transfer = v ? Transfer.sqrt : Transfer.linear),
      '차압 전송기로 유량을 잴 때 mA는 차압에 비례하고, 유량은 차압의 제곱근입니다. '
          '범위를 유량으로 넣고 켜십시오. 전송기 안에서 이미 제곱근을 풀어 내보내면(출력이 유량에 비례) 끄십시오.',
      key: '${tab}_sqrt',
    ),
    const SizedBox(height: 8),
  ];

  // ① 환산
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
        caption: _input == _Input.ma ? '측정값' : '출력 전류',
        warn: warn,
        lines: [
          if (_input != _Input.ma) '측정값 ${_pv(pv)}',
          if (_input != _Input.pct) '측정 범위의 ${_fmt(pct, 2)}%',
          if (_transfer == Transfer.sqrt)
            '차압 ${_fmt(pctFromMa(ma), 2)}% (mA는 차압에 비례)',
          '1-5V 입력이면 ${_fmt(ma * 0.25)} V (250Ω)',
          _stateText(st),
        ],
      );
    }
    return _page([
      ..._rangeFields('sg'),
      _chips('넣을 값', '아는 값을 고르고 아래 칸에 넣으십시오. 나머지를 셉니다.', [
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
      ]),
      calcField(
        'sg_value',
        switch (_input) {
          _Input.ma => '전류 (mA)',
          _Input.pct => '측정 범위 (%)',
          _Input.pv => '측정값${_u.isEmpty ? '' : ' ($_u)'}',
        },
        _value,
        switch (_input) {
          _Input.ma => '멀티미터·교정기로 잰 루프 전류입니다.',
          _Input.pct => '측정 범위의 몇 %인지입니다(0% = 4mA, 100% = 20mA).',
          _Input.pv => '압력·온도 등 측정값입니다. 이 값일 때 계기가 내야 할 전류를 셉니다.',
        },
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
    SignalState.failLow => '3.6mA 이하 — 고장 신호(낮음), 단선·계기 고장을 보십시오(NAMUR NE43).',
    SignalState.gapLow => '3.6~3.8mA — 고장 신호와 측정 사이, 정해지지 않은 구간입니다(NE43).',
    SignalState.underRange => '3.8~4mA — 0% 아래로 내려갔지만 측정은 맞는 구간입니다(NE43).',
    SignalState.normal => '4~20mA 정상 구간입니다.',
    SignalState.overRange => '20~20.5mA — 100% 위로 넘었지만 측정은 맞는 구간입니다(NE43).',
    SignalState.gapHigh => '20.5~21mA — 측정과 고장 신호 사이, 정해지지 않은 구간입니다(NE43).',
    SignalState.failHigh => '21mA 이상 — 고장 신호(높음)입니다(NAMUR NE43).',
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
          '5점 표',
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

  // ② 교정 점검
  Widget _calTab() {
    final range = _range;
    final tol = _num(_tol);
    final rows = <(int, CalPoint?)>[];
    if (range != null) {
      final (l, u) = range;
      for (var i = 0; i < _points.length; i++) {
        final applied = _num(_applied[i]) ?? pctToPv(_points[i], l, u);
        final reading = _num(_reading[i]);
        rows.add((
          i,
          reading == null
              ? null
              : checkPoint(
                  applied: applied,
                  reading: reading,
                  kind: _kind,
                  lrv: l,
                  urv: u,
                  transfer: _transfer,
                  tolPct: tol != null && tol > 0 ? tol : null,
                ),
        ));
      }
    }
    final done = [
      for (final r in rows)
        if (r.$2 != null) (r.$1, r.$2!),
    ];
    Widget summary;
    if (range == null) {
      summary = calcResult(
        big: '—',
        caption: '0% 값과 100% 값을 다르게 넣으십시오',
        lines: const [],
      );
    } else if (done.isEmpty) {
      summary = calcResult(
        big: '—',
        caption: '읽은 값을 한 점 이상 넣으십시오',
        lines: const [],
      );
    } else {
      final worst = done.reduce(
        (a, b) => b.$2.errPct.abs() > a.$2.errPct.abs() ? b : a,
      );
      final fails = [
        for (final d in done)
          if (d.$2.pass == false) d,
      ];
      final judged = done.first.$2.pass != null;
      summary = calcResult(
        key: const Key('sg_cal_result'),
        big: '${_signed(worst.$2.errPct, 2)}%',
        caption: !judged
            ? '가장 큰 오차(스팬 대비) — 허용 오차를 넣으면 판정합니다'
            : fails.isEmpty
            ? '정상 — ${done.length}점 모두 ±${_fmt(tol!)}% 안'
            : '허용 오차 넘음 — ${fails.length}점이 ±${_fmt(tol!)}% 밖',
        warn: fails.isNotEmpty,
        lines: [
          '가장 큰 오차: ${_fmt(_points[worst.$1])}% 점',
          if (fails.isNotEmpty)
            '넘은 점: ${fails.map((f) => '${_fmt(_points[f.$1])}%').join(', ')}',
          _kind == ReadKind.ma
              ? '오차 % = (읽은 mA − 이론 mA) ÷ 16mA × 100'
              : '오차 % = (지시값 − 넣은 값) ÷ 측정 범위 × 100',
        ],
      );
    }
    return _page([
      ..._rangeFields('sc'),
      _chips(
        '읽은 값',
        'mA: 계기 출력 전류를 교정기·멀티미터로 잽니다(전송기 점검). '
            '지시값: DCS·지시계·현장 게이지에 보이는 값입니다(루프 전체 점검).',
        [
          calcChip(
            'sc_kind_ma',
            'mA',
            _kind == ReadKind.ma,
            () => setState(() => _kind = ReadKind.ma),
          ),
          calcChip(
            'sc_kind_pv',
            '지시값',
            _kind == ReadKind.pv,
            () => setState(() => _kind = ReadKind.pv),
          ),
        ],
      ),
      calcField(
        'sc_tol',
        '허용 오차 (± 스팬 %)',
        _tol,
        '계기 정확도(데이터시트)나 발주처·교정 절차서가 정한 허용 오차입니다. '
            '예: ±0.5%면 0.5. 비우면 오차만 보이고 판정은 하지 않습니다.',
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
      if (range != null)
        for (var i = 0; i < _points.length; i++)
          _calRow(i, range.$1, range.$2, rows[i].$2),
      Align(
        alignment: Alignment.centerRight,
        child: calcToggle('sc_clear', '읽은 값 지우기', () {
          setState(() {
            for (final c in _reading) {
              c.clear();
            }
            for (final c in _applied) {
              c.clear();
            }
          });
        }),
      ),
      const SizedBox(height: 4),
      summary,
    ]);
  }

  Widget _calRow(int i, double l, double u, CalPoint? r) {
    final nominal = pctToPv(_points[i], l, u);
    final ideal = idealMa(_num(_applied[i]) ?? nominal, l, u, _transfer);
    final bad = r?.pass == false;
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
            children: [
              Text(
                '${_fmt(_points[i])}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: fc.text,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '이론 ${_fmt(ideal)} mA',
                  style: TextStyle(fontSize: 13, color: fc.textSub),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _smallField(
                  'sc_applied_$i',
                  '넣은 값${_u.isEmpty ? '' : ' ($_u)'}',
                  _applied[i],
                  _fmt(nominal),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _smallField(
                  'sc_read_$i',
                  _kind == ReadKind.ma
                      ? '읽은 mA'
                      : '읽은 지시값${_u.isEmpty ? '' : ' ($_u)'}',
                  _reading[i],
                  '',
                ),
              ),
            ],
          ),
          if (r != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '오차 ${_signed(r.errPct, 2)}%'
                '${r.errMa.isNaN ? '' : ' · ${_signed(r.errMa)} mA'}'
                ' · ${_signed(r.errPv)}${_u.isEmpty ? '' : ' $_u'}'
                '${r.pass == null ? '' : (r.pass! ? ' · 정상' : ' · 넘음')}',
                key: Key('sc_err_$i'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: bad ? fc.danger : fc.brand,
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
    String hint,
  ) => TextField(
    key: Key(key),
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fc.text),
    decoration: InputDecoration(
      isDense: true,
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    onChanged: (_) => setState(() {}),
  );

  // ③ 루프 전압
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
    final lc = vs == null || vmin == null
        ? null
        : loopCheck(supplyV: vs, minV: vmin, ohms: [hart, barrier, wire]);
    return _page([
      calcField(
        'sl_supply',
        '전원 전압 (V)',
        _supply,
        '루프 전원(DCS 카드·전원 장치) 전압입니다. 보통 24V DC.',
      ),
      calcField(
        'sl_minv',
        '계기 최소 전압 (V)',
        _minV,
        '전송기가 동작하는 데 필요한 단자 전압의 최솟값입니다. 계기 데이터시트 "Power supply"에 적혀 있습니다. '
            '예: Rosemount 3051(4-20mA HART) 10.5V. 계기마다 다르니 바꾸어 넣으십시오.',
      ),
      calcField(
        'sl_hart',
        'HART·입력 저항 (Ω)',
        _hartR,
        'DCS 입력 카드나 HART 통신용으로 루프에 든 저항입니다. HART 통신은 루프 저항 230Ω 이상이 필요해 보통 250Ω을 둡니다. '
            '카드 사양서의 입력 저항을 넣으십시오.',
      ),
      calcField(
        'sl_barrier',
        '배리어·절연기 (Ω)',
        _barrierR,
        '방폭 배리어·신호 절연기가 있으면 사양서의 직렬 저항(또는 전압 강하 ÷ 20mA)을 넣습니다. 없으면 0.',
      ),
      calcField(
        'sl_len',
        '전선 길이 (m, 편도)',
        _wireLen,
        '계기에서 판넬까지 한쪽 길이입니다. 왕복(두 가닥)으로 셉니다.',
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
        '또는 전선 저항 직접 (Ω, 왕복)',
        _wireR,
        '1.25sq처럼 위에 없는 굵기거나 재어 둔 값이 있으면 왕복 저항을 넣으십시오. 넣으면 길이·굵기보다 먼저 씁니다.',
      ),
      const SizedBox(height: 12),
      if (lc == null)
        calcResult(big: '—', caption: '전원 전압과 계기 최소 전압을 넣으십시오', lines: const [])
      else
        calcResult(
          key: const Key('sl_result'),
          big: '${_fmt(lc.volts21, 2)} V',
          caption: lc.okAt21(vmin!)
              ? '21mA일 때 계기 단자 전압 — 충분합니다'
              : lc.okAt20(vmin)
              ? '21mA일 때 계기 단자 전압 — 고장 신호를 끝까지 못 냅니다'
              : '20mA도 못 냅니다 — 전압이 모자랍니다',
          warn: !lc.okAt21(vmin),
          lines: [
            '루프 저항 합 ${_fmt(lc.totalOhm, 1)}Ω (전선 ${_fmt(wire, 1)}Ω)',
            '20mA일 때 ${_fmt(lc.volts20, 2)} V (최소 ${_fmt(vmin)} V)',
            '21mA까지 낼 수 있는 최대 루프 저항 ${_fmt(lc.maxOhm21, 0)}Ω',
            if (lc.totalOhm < 230)
              'HART 통신을 하려면 루프 저항이 230Ω 이상이어야 합니다(보통 250Ω).',
            '식: 단자 전압 = 전원 − 전류 × 루프 저항. 21mA는 NAMUR NE43 고장 신호(높음)의 시작.',
            '제조사 식은 여유를 더 둡니다 — 예: Rosemount 3051 최대 루프 저항 = 43.5 × (전원 − 10.5), 약 23mA 기준.',
          ],
        ),
    ]);
  }
}
