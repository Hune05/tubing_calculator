// 계기 교정 "교정 가스" 탭: 수소 순도계(요꼬가와 GD402 가스 밀도계) 교정 가스 용기가 얼마나 남았고
// 몇 번 더 교정할 수 있는지. 계산은 cal_gas.dart, 근거는 docs/교정가스_근거.md.
// 넣은 값은 'cal_gas_draft_v1'에 저장해 다음에 열 때 되살린다.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import '../pressure_test/pressure_units.dart';
import 'cal_gas.dart';

const String kCalGasDraftKey = 'cal_gas_draft_v1';

String _f(double v, [int d = 2]) {
  var s = (v + (v >= 0 ? 1e-9 : -1e-9)).toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  if (s == '-0') s = '0';
  return s;
}

/// 큰 수는 천 단위 쉼표.
String _int(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String _time(double minutes) {
  if (minutes < 60) return '${_f(minutes, 0)}분';
  final h = minutes / 60;
  if (h < 48) return '${_f(h, 1)}시간';
  return '${_f(h / 24, 1)}일';
}

class CalGasTab extends StatefulWidget {
  const CalGasTab({super.key});

  @override
  State<CalGasTab> createState() => _CalGasTabState();
}

class _CalGasTabState extends State<CalGasTab>
    with
        AutomaticKeepAliveClientMixin,
        WidgetsBindingObserver,
        CalcFormParts<CalGasTab> {
  CalGas _gas = CalGas.h2;
  PUnit _pUnit = PUnit.mpa;
  bool _airScale = false;
  final _water = TextEditingController(text: '47');
  final _p = TextEditingController();
  final _rest = TextEditingController();
  final _kg = TextEditingController();
  final _t = TextEditingController(text: '20');
  final _lpm = TextEditingController(text: '0.6');
  final _min = TextEditingController();

  Map<String, TextEditingController> get _fields => {
    'water': _water,
    'p': _p,
    'rest': _rest,
    'kg': _kg,
    't': _t,
    'lpm': _lpm,
    'min': _min,
  };

  bool _loaded = false;
  bool _touched = false;
  Timer? _saveTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kCalGasDraftKey);
      if (raw != null && mounted && !_touched) {
        final m = jsonDecode(raw);
        if (m is Map) {
          super.setState(() {
            _gas = CalGas.values.firstWhere(
              (g) => g.name == m['gas'],
              orElse: () => _gas,
            );
            _pUnit = punitByName(m['pUnit'], _pUnit);
            if (m['airScale'] is bool) _airScale = m['airScale'] as bool;
            final f = m['fields'];
            if (f is Map) {
              for (final e in _fields.entries) {
                final v = f[e.key];
                if (v is String) e.value.text = v;
              }
            }
          });
        }
      }
    } catch (_) {
      // 읽지 못하면 기본값으로 시작한다.
    } finally {
      _loaded = true;
    }
  }

  void _saveNow() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_loaded) return;
    final json = jsonEncode({
      'gas': _gas.name,
      'pUnit': _pUnit.name,
      'airScale': _airScale,
      'fields': {for (final e in _fields.entries) e.key: e.value.text},
    });
    SharedPreferences.getInstance()
        .then((p) => p.setString(kCalGasDraftKey, json))
        .catchError((_) => false);
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
    if (state != AppLifecycleState.resumed) _saveNow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveNow();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? _n(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', ''));

  double? _bar(TextEditingController c) {
    final v = _n(c);
    return v == null ? null : v * _pUnit.kpa / 100;
  }

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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final byWeight = _gas.byWeight;
    final water = _n(_water) ?? 0;
    final pu = _pUnit.label;
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          _chips(
            '가스',
            '요꼬가와 GD402 수소 순도 교정: 제로는 수소 100%, 스팬은 이산화탄소 100%입니다(설명서 IM 11T03E01-01E 10장). '
                '질소는 치환·퍼지용입니다.',
            [
              for (final g in CalGas.values)
                calcChip('cg_gas_${g.name}', g.label, _gas == g, () {
                  setState(() => _gas = g);
                }),
            ],
          ),
          calcField(
            'cg_water',
            '용기 내용적 (L)',
            _water,
            '용기 어깨에 각인된 내용적(V)입니다. 국내 고압가스 용기는 47L가 흔합니다.',
          ),
          if (!byWeight) ...[
            _chips('압력 단위', '용기 조정기 1차 압력계의 단위를 고르십시오. 국내 용기 각인(FP)은 MPa입니다.', [
              for (final u in [PUnit.mpa, PUnit.bar, PUnit.kgfcm2])
                calcChip('cg_pu_${u.name}', u.label, _pUnit == u, () {
                  setState(() => _pUnit = u);
                }),
            ]),
            calcField(
              'cg_p',
              '지금 용기 압력 ($pu)',
              _p,
              '조정기 1차(용기 쪽) 압력계 값입니다. 게이지 압력으로 넣습니다. 새 수소·질소 용기는 보통 14.7MPa로 충전됩니다.',
            ),
            calcField(
              'cg_rest',
              '남길 압력 ($pu)',
              _rest,
              '이 압력이 되면 용기를 바꿉니다. 조정기가 제대로 일하는 압력보다 높게, 공기가 거꾸로 들어가지 않게 조금 남깁니다. '
                  '회사·공급사 기준을 넣으십시오.',
            ),
          ] else
            calcField(
              'cg_kg',
              '남은 가스 무게 (kg)',
              _kg,
              '저울에 단 무게에서 용기 무게(각인 TW)를 뺀 값입니다. 이산화탄소는 용기 안에서 액체로 있어 20°C에서 압력이 '
                  '57.3bar에 머뭅니다. 그래서 압력계로는 남은 양을 알 수 없습니다.\n'
                  '가득 찬 용기는 내용적 ÷ 1.47(충전상수)kg입니다'
                  '${water > 0 ? ': ${_f(water, 0)}L면 ${_f(water / kCo2FillConstant, 1)}kg' : ''}.',
            ),
          calcField(
            'cg_t',
            '용기 온도 (°C)',
            _t,
            '용기가 놓인 곳의 온도입니다. 압축 계수 표는 0~40°C까지입니다.',
          ),
          calcField(
            'cg_lpm',
            '유량 (L/min)',
            _lpm,
            'GD402 교정 가스 유량은 0.1~1L/min, 정격 0.6L/min(±10%)입니다(사양서 GS 11T3E1-01E). 유량계 눈금을 넣습니다.',
          ),
          _chips(
            '유량계 눈금',
            '면적식 유량계(로터미터)는 눈금을 맞춘 가스가 따로 있습니다. 유량계 명판을 보십시오. '
                '공기 눈금으로 수소를 흘리면 실제 유량은 눈금의 약 3.8배입니다(√(공기 밀도 ÷ 가스 밀도)).',
            [
              calcChip('cg_scale_gas', '이 가스 눈금', !_airScale, () {
                setState(() => _airScale = false);
              }),
              calcChip('cg_scale_air', '공기 눈금', _airScale, () {
                setState(() => _airScale = true);
              }),
            ],
          ),
          calcField(
            'cg_min',
            '교정 1회에 흘리는 시간 (분)',
            _min,
            '이 가스를 흘려 지시가 안정되고 확정(ENT)할 때까지의 시간입니다. 배관을 퍼지하는 시간도 넣으십시오. '
                '제조사가 정한 값이 없어 비워 두었습니다.',
          ),
          const SizedBox(height: 4),
          _result(),
          _note(
            '가스량은 0°C, 101.325kPa 기준(Nm³, NL)입니다. 수소·질소는 압축 계수(NIST)를 넣어 계산합니다. '
            '150bar 수소를 이상기체로 계산하면 약 9% 많게 나옵니다.',
          ),
          _note(
            '수소는 공기 중 4~75%에서 탑니다. 교정 가스는 벤트 라인으로 밖에 내보내십시오. '
            '요꼬가와는 표준 가스로 2~3개월마다 확인하고, 틀어졌으면 교정하라고 합니다(IM 11T03E01-01E 11장).',
            key: const Key('cg_note'),
          ),
        ],
      ),
    );
  }

  Widget _result() {
    final t = _n(_t);
    final water = _n(_water);
    if (t == null || water == null || water <= 0) {
      return calcResult(
        big: '—',
        caption: '용기 내용적과 온도를 넣으십시오',
        lines: const [],
      );
    }
    if (t < kZMinC || t > kZMaxC) {
      return calcResult(
        big: '—',
        caption: '온도는 0~40°C로 넣으십시오',
        lines: const [],
        warn: true,
      );
    }
    final r = calGasUse(
      gas: _gas,
      tC: t,
      waterL: water,
      pGaugeBar: _bar(_p),
      residualGaugeBar: _bar(_rest),
      netKg: _n(_kg),
      lpm: _n(_lpm),
      airScale: _airScale,
      minutes: _n(_min),
    );
    if (r == null) {
      final p = _bar(_p), rest = _bar(_rest);
      return calcResult(
        big: '—',
        caption: _gas.byWeight
            ? '남은 가스 무게를 넣으십시오'
            : p == null || rest == null
            ? '지금 용기 압력과 남길 압력을 넣으십시오'
            : p < rest
            ? '남길 압력이 지금 압력보다 높습니다'
            : '압력은 ${_f(kZMaxBar - kAtmBar, 0)}bar(게이지)까지 계산합니다',
        lines: const [],
      );
    }
    final lines = <String>[
      if (r.totalNm3 != null) '지금 용기 안: ${_f(r.totalNm3!, 2)} Nm³',
      if (r.actualLpm != null && _airScale)
        '실제 유량: ${_f(r.actualLpm!, 2)} L/min (공기 눈금 × ${_f(airScaleFactor(_gas), 2)})',
      if (r.perCalNL != null) '교정 1회 사용량: ${_f(r.perCalNL!, 1)} NL',
      if (r.dropPerCalBar != null)
        '교정 1회에 용기 압력이 ${_f(r.dropPerCalBar! * 100 / _pUnit.kpa, _pUnit == PUnit.mpa ? 4 : 2)} ${_pUnit.label}쯤 내려갑니다',
      if (r.flowMinutes != null)
        '계속 흘리면 ${_gas.byWeight ? '다 쓸 때' : '남길 압력'}까지 ${_time(r.flowMinutes!)}',
      if (r.perCalNL == null) '교정 1회에 흘리는 시간을 넣으면 남은 교정 횟수가 나옵니다.',
    ];
    if (r.calsLeft != null) {
      return calcResult(
        key: const Key('cg_result'),
        big: '${_int(r.calsLeft!)}회',
        caption: '남은 교정 횟수 (쓸 수 있는 양 ${_f(r.availableNm3, 2)} Nm³)',
        lines: lines,
      );
    }
    return calcResult(
      key: const Key('cg_result'),
      big: '${_f(r.availableNm3, 2)} Nm³',
      caption: _gas.byWeight ? '쓸 수 있는 양' : '남길 압력까지 쓸 수 있는 양',
      lines: lines,
    );
  }
}
