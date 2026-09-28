// 전기 설계 계산: 축전지 용량 탭(발전소 직류 전원). 계산은 elec_battery.dart, 근거는 docs/전기_축전지_근거.md.
// K 값(용량환산시간)은 제조사 방전 특성표에서 읽어 넣는다. 표는 앱에 없다.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import 'elec_battery.dart';
import 'elec_form_parts.dart';

class ElecBatteryTab extends StatefulWidget {
  const ElecBatteryTab({super.key, this.history});

  /// "최근 계산 기록"을 다른 탭과 함께 쓸 때 밖에서 만든 기록을 넣는다. 비우면 이 탭만의 기록을 쓴다.
  final RecentCalcLog? history;

  /// 입력값을 남기는 저장 칸.
  static const draftKey = 'elec_battery_draft_v1';

  @override
  State<ElecBatteryTab> createState() => _ElecBatteryTabState();
}

class _StepRow {
  final amps = TextEditingController();
  final minutes = TextEditingController();

  void dispose() {
    amps.dispose();
    minutes.dispose();
  }
}

class _ElecBatteryTabState extends State<ElecBatteryTab>
    with
        CalcFormParts<ElecBatteryTab>,
        RecentCalcHistoryMixin<ElecBatteryTab>,
        ElecTabParts<ElecBatteryTab>,
        AutomaticKeepAliveClientMixin<ElecBatteryTab> {
  @override
  RecentCalcLog get calcLog => widget.history ?? super.calcLog;

  // 탭을 옮겨도 입력이 사라지지 않게 살려 둔다.
  @override
  bool get wantKeepAlive => true;

  static const _maxSteps = 8;

  BatteryMethod _method = BatteryMethod.sba;
  final List<_StepRow> _steps = [_StepRow()];
  final Map<String, TextEditingController> _k = {};

  final _maint = TextEditingController(text: '0.8');
  final _temp = TextEditingController();
  final _margin = TextEditingController();
  final _aging = TextEditingController(text: '1.25');
  final _chosen = TextEditingController();
  final _bus = TextEditingController();
  final _cellNom = TextEditingController();
  final _cellMin = TextEditingController();
  final _cells = TextEditingController();
  final _minBus = TextEditingController();

  List<(TextEditingController, String)> get _texts => [
    (_maint, 'maint'),
    (_temp, 'temp'),
    (_margin, 'margin'),
    (_aging, 'aging'),
    (_chosen, 'chosen'),
    (_bus, 'bus'),
    (_cellNom, 'cellNom'),
    (_cellMin, 'cellMin'),
    (_cells, 'cells'),
    (_minBus, 'minBus'),
  ];

  Timer? _saveTimer;
  String? _lastDraft;
  String? _pendingDraft;
  bool _draftReady = false;

  TextEditingController _kc(String key) =>
      _k.putIfAbsent(key, () => TextEditingController());

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _flushDraft();
    for (final (c, _) in _texts) {
      c.dispose();
    }
    for (final s in _steps) {
      s.dispose();
    }
    for (final c in _k.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> _draft() => {
    'method': _method.name,
    'steps': [
      for (final s in _steps) [s.amps.text, s.minutes.text],
    ],
    'k': {for (final e in _k.entries) e.key: e.value.text},
    for (final (c, k) in _texts) k: c.text,
  };

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(ElecBatteryTab.draftKey);
      if (raw != null && mounted) {
        final m = jsonDecode(raw);
        if (m is Map<String, dynamic>) setState(() => _applyDraft(m));
      }
      _lastDraft = raw;
    } catch (_) {
      // 저장 칸을 못 읽어도 기본값으로 쓴다.
    }
    _draftReady = true;
  }

  void _applyDraft(Map<String, dynamic> m) {
    _method = BatteryMethod.values.firstWhere(
      (v) => v.name == m['method'],
      orElse: () => _method,
    );
    final st = m['steps'];
    if (st is List && st.isNotEmpty) {
      for (final s in _steps) {
        s.dispose();
      }
      _steps.clear();
      for (final e in st.take(_maxSteps)) {
        final row = _StepRow();
        if (e is List && e.length >= 2) {
          if (e[0] is String) row.amps.text = e[0] as String;
          if (e[1] is String) row.minutes.text = e[1] as String;
        }
        _steps.add(row);
      }
    }
    final k = m['k'];
    if (k is Map) {
      for (final e in k.entries) {
        if (e.key is String && e.value is String) {
          _kc(e.key as String).text = e.value as String;
        }
      }
    }
    for (final (c, key) in _texts) {
      if (m[key] is String) c.text = m[key] as String;
    }
  }

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
      await prefs.setString(ElecBatteryTab.draftKey, raw);
    } catch (_) {
      // 저장을 못 해도 계산에는 지장이 없다.
    }
  }

  /// 칸을 숫자로 읽는다. 비면 null, 숫자가 아니면 bad에 이름을 적는다.
  double? _read(TextEditingController c, String label, List<String> bad) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    final v = readNum(c);
    if (v == null) bad.add('$label: 숫자가 아닙니다.');
    return v;
  }

  Widget _stepRow(int n) {
    final s = _steps[n];
    Widget cell(String key, TextEditingController c, String hint) => Expanded(
      flex: 3,
      child: TextField(
        key: Key(key),
        controller: c,
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: fc.text,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: fc.textSub),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
    return calcBox(
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '${n + 1}단계',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: fc.text,
              ),
            ),
          ),
          cell('eb_a_$n', s.amps, '전류 A'),
          const SizedBox(width: 8),
          cell('eb_m_$n', s.minutes, '시간 분'),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _sectionTable(BatteryResult r) {
    TextStyle st({bool bold = false}) => TextStyle(
      fontSize: 13,
      color: fc.text,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
    Widget cell(String t, {bool bold = false, TextAlign a = TextAlign.right}) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Text(
            t,
            textAlign: a,
            style: st(bold: bold),
          ),
        );
    return Column(
      key: const Key('eb_sections'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in r.sections)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: fc.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: s.endStep == r.maxSection ? fc.brand : fc.line,
                width: s.endStep == r.maxSection ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.endStep == 1
                      ? '구간 1 (1단계까지)'
                      : '구간 ${s.endStep} (1~${s.endStep}단계)'
                            '${s.endStep == r.maxSection ? ', 최댓값' : ''}',
                  style: st(bold: true),
                ),
                const SizedBox(height: 4),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.2),
                    1: FlexColumnWidth(1.4),
                    2: FlexColumnWidth(1.4),
                    3: FlexColumnWidth(1.2),
                    4: FlexColumnWidth(1.6),
                  },
                  children: [
                    TableRow(
                      children: [
                        cell('단계', bold: true, a: TextAlign.left),
                        cell('전류 변화 A', bold: true),
                        cell('시간 분', bold: true),
                        cell('K 시간', bold: true),
                        cell('기여 Ah', bold: true),
                      ],
                    ),
                    for (final t in s.terms)
                      TableRow(
                        children: [
                          cell('${t.stepNo}', a: TextAlign.left),
                          cell(fmt(t.dAmps, 2)),
                          cell(fmt(t.minutes, 2)),
                          cell(fmt(t.k, 3)),
                          cell(fmt(t.ah, 2)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '구간 합계 ${fmt(s.total, 2)} Ah',
                    style: st(bold: true),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _scheduleSave();
    final bad = <String>[];

    // 단계.
    final steps = <BatteryStep>[];
    var anyStep = false;
    var stepsOk = true;
    for (var n = 0; n < _steps.length; n++) {
      final a = _read(_steps[n].amps, '${n + 1}단계 전류', bad);
      final m = _read(_steps[n].minutes, '${n + 1}단계 시간', bad);
      if (_steps[n].amps.text.trim().isNotEmpty ||
          _steps[n].minutes.text.trim().isNotEmpty) {
        anyStep = true;
      }
      if (a == null || m == null) {
        stepsOk = false;
        if (anyStep && bad.isEmpty) {
          bad.add('${n + 1}단계 전류(A)와 시간(분)을 모두 넣으십시오.');
        }
        steps.add(BatteryStep(a ?? 0, m ?? 0));
      } else {
        steps.add(BatteryStep(a, m));
      }
    }

    // K 칸: 단계가 모두 올바를 때만 필요한 시간 목록을 만든다.
    final needed = stepsOk && steps.every((s) => s.amps > 0 && s.minutes > 0)
        ? battNeededTimes(steps)
        : <double>[];
    final kMap = <String, double>{};
    for (final t in needed) {
      final key = battTimeKey(t);
      final c = _kc(key);
      final v = _read(c, 'K($key분)', bad);
      if (v != null) kMap[key] = v;
    }

    final input = BatteryInput(
      method: _method,
      steps: steps,
      k: kMap,
      maintenance: _read(_maint, '보수율 L', bad),
      tempFactor: _read(_temp, '온도 보정계수', bad),
      marginPct: _read(_margin, '설계 여유', bad),
      agingFactor: _read(_aging, '노화계수', bad),
      chosenAh: _read(_chosen, '선정 용량', bad),
      busVolts: _read(_bus, '직류 모선 전압', bad),
      cellNominal: _read(_cellNom, '셀당 공칭 전압', bad),
      cellMin: _read(_cellMin, '셀당 최저 전압', bad),
      cells: _read(_cells, '셀 수', bad),
      minBusVolts: _read(_minBus, '부하 최저 허용 전압', bad),
    );
    final empty = !anyStep && bad.isEmpty;
    final r = calcBattery(input);
    final errors = [...bad, if (bad.isEmpty) ...r.errors];
    final sba = _method == BatteryMethod.sba;

    Widget result;
    String? summary;
    var warn = false;
    if (empty) {
      result = calcResult(
        key: const Key('eb_result'),
        big: '—',
        caption: '방전 단계의 전류와 시간, K 값을 넣으면 필요 용량을 계산합니다',
        lines: const [],
      );
    } else if (errors.isNotEmpty) {
      warn = true;
      summary = '입력 확인';
      result = calcResult(
        key: const Key('eb_result'),
        big: '입력 확인',
        caption: '다음 입력값을 고치십시오',
        warn: true,
        lines: errors,
      );
    } else {
      final req = r.required!;
      final fail = r.chosenPass == false || r.endVoltsPass == false;
      warn = fail;
      summary = '필요 ${fmt(req, 1)} Ah (${_method.label})';
      result = calcResult(
        key: const Key('eb_result'),
        big: '${fmt(req, 1)} Ah',
        caption: '필요 축전지 용량 (${_method.label} 방식)',
        warn: fail,
        lines: [
          '구간 용량 최댓값: ${fmt(r.base!, 2)} Ah (구간 ${r.maxSection})',
          if (sba)
            '필요 용량 = 구간 최댓값 ÷ 보수율 = ${fmt(r.base!, 2)} ÷ ${fmt(input.maintenance!, 2)} = ${fmt(req, 1)} Ah'
          else
            '필요 용량 = 구간 최댓값 × 온도 보정계수 × (1 + 설계 여유) × 노화계수 = ${fmt(r.base!, 2)} × '
                '${fmt(input.tempFactor!, 2)} × ${fmt(1 + input.marginPct! / 100, 2)} × '
                '${fmt(input.agingFactor!, 2)} = ${fmt(req, 1)} Ah',
          sba
              ? 'K는 최저 온도와 셀당 최저 전압에 맞는 값이어야 합니다. 온도는 K에 들어 있어 따로 곱하지 않습니다.'
              : 'K는 25°C 기준 값이어야 합니다. 온도는 보정계수로 따로 곱합니다.',
          if (r.chosenPass != null)
            r.chosenPass!
                ? '선정 ${fmt(input.chosenAh!, 0)} Ah: 합격 (여유 ${fmt(r.chosenMarginPct!, 1)}%)'
                : '선정 ${fmt(input.chosenAh!, 0)} Ah: 불합격 (필요 ${fmt(req, 1)} Ah에 ${fmt(-r.chosenMarginPct!, 1)}% 부족)',
          if (r.cellRatio != null)
            '셀 수 계산값: ${fmt(input.busVolts!, 1)} V ÷ ${fmt(input.cellNominal!, 2)} V = ${fmt(r.cellRatio!, 2)}셀'
                '${r.cellRatio! == r.cellRatio!.roundToDouble() ? '' : ' (정수가 아니므로 제조사와 계통 기준으로 셀 수를 정하십시오)'}',
          if (r.endVolts != null)
            '방전 종지 모선 전압: ${fmt(input.cells!, 0)}셀 × ${fmt(input.cellMin!, 2)} V = ${fmt(r.endVolts!, 1)} V'
                '${r.endVoltsPass == null
                    ? ''
                    : r.endVoltsPass!
                    ? ', 부하 최저 허용 ${fmt(input.minBusVolts!, 1)} V 이상이라 합격'
                    : ', 부하 최저 허용 ${fmt(input.minBusVolts!, 1)} V 미만이라 불합격'}',
          '최종 선정은 제조사 방전 특성표와 설계 기준으로 확인하십시오.',
        ],
      );
    }

    return elecPage(sumKey: 'eb_sum', summary: summary, warn: warn, [
      elecChipGroup(
        '방식',
        'SBA S 0601: 최저 온도 기준 K를 쓰고 보수율 L로 나눕니다.\n'
            'IEEE 485: 25°C 기준 K를 쓰고 온도 보정계수, 설계 여유, 노화계수를 곱합니다.\n'
            '두 방식은 온도와 노화를 반영하는 순서가 다르며, 같은 조건이면 결과가 같다고 소개하는 논문이 있습니다(2차 자료).',
        [
          for (final m in BatteryMethod.values)
            calcChip('eb_method_${m.name}', m.label, _method == m, () {
              setState(() => _method = m);
            }),
        ],
      ),
      elecSectionTitle('방전 단계'),
      for (var n = 0; n < _steps.length; n++) _stepRow(n),
      Row(
        children: [
          if (_steps.length < _maxSteps)
            calcToggle('eb_add', '단계 추가', () {
              setState(() => _steps.add(_StepRow()));
            }),
          if (_steps.length > 1)
            calcToggle('eb_del', '마지막 단계 지우기', () {
              setState(() => _steps.removeLast().dispose());
            }),
        ],
      ),
      elecSectionTitle('K 값 (용량환산시간, 시간)'),
      if (needed.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: Text(
            '방전 단계의 전류와 시간을 넣으면 K 값이 필요한 시간별로 칸이 나옵니다.',
            style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.4),
          ),
        )
      else ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Text(
            '제조사 방전 특성표에서 이 방전 시간의 용량환산시간을 읽어 넣으십시오. '
            '${sba ? '최저 온도와 셀당 최저 전압에 맞는 표를 쓰십시오.' : '25°C 기준 표를 쓰십시오.'}',
            style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.4),
          ),
        ),
        for (final t in needed)
          elecField(
            'eb_k_${battTimeKey(t)}',
            'K (${battTimeKey(t)}분)',
            _kc(battTimeKey(t)),
            '용량환산시간 K[시간]입니다. 제조사 방전 특성표에서 방전 시간 ${battTimeKey(t)}분, 셀당 최저 전압에 맞는 값을 읽어 넣으십시오. 앱에는 표를 넣지 않았습니다.',
          ),
      ],
      elecSectionTitle('보정'),
      if (sba)
        elecField(
          'eb_maint',
          '보수율 (L)',
          _maint,
          '수명이 지나도 부하를 받치기 위한 비율입니다. 국내 자료에서 보통 0.8을 씁니다. 0 초과 1 이하로 넣으십시오.',
        )
      else ...[
        elecField(
          'eb_temp',
          '온도 보정계수',
          _temp,
          '최저 전해액 온도가 25°C보다 낮을 때 곱합니다. 강의 자료 한 곳이 IEEE 485 표 1 값으로 소개한 것은 4.4°C 1.30, 10°C 1.19, 15.6°C 1.11, 21.1°C 1.04, 25°C 1.00입니다(원문 대조 전). 제조사 표가 있으면 그 값을 넣으십시오.',
        ),
        elecField(
          'eb_margin',
          '설계 여유 (%)',
          _margin,
          '부하 증설 등에 두는 비율입니다. 자료마다 10~15%, 10~25%로 다르게 소개합니다. 설계 기준으로 정하고 없으면 0을 넣으십시오.',
        ),
        elecField(
          'eb_aging',
          '노화계수',
          _aging,
          '1.25는 수명 끝에 용량이 80%로 줄어도 부하를 받치기 위한 값입니다. IEEE 485를 소개한 자료 여러 곳이 같은 값을 적었습니다(2차 자료).',
        ),
      ],
      elecField(
        'eb_chosen',
        '선정 용량 (Ah, 선택)',
        _chosen,
        '제조사 표준 용량 중 고른 값을 넣으면 여유율과 합격/불합격을 봅니다.',
      ),
      elecSectionTitle('셀 수와 전압 (선택)'),
      elecField(
        'eb_bus',
        '직류 모선 전압 (V)',
        _bus,
        '발전소 제어 전원은 125V를 쓰는 곳이 많습니다. 설비 기준으로 넣으십시오.',
      ),
      elecChipGroup(
        '셀당 공칭 전압',
        '연축전지는 2.0V, 알칼리(니켈카드뮴)는 1.2V로 표기합니다. 만충전 때 연축전지의 셀 전압은 2.1V 안팎이라고 소개하는 자료도 있습니다.',
        [
          calcChip('eb_cell_lead', '연축전지 2.0 V', readNum(_cellNom) == 2.0, () {
            setState(() => _cellNom.text = '2');
          }),
          calcChip('eb_cell_alk', '알칼리 1.2 V', readNum(_cellNom) == 1.2, () {
            setState(() => _cellNom.text = '1.2');
          }),
        ],
      ),
      elecField(
        'eb_cellnom',
        '셀당 공칭 전압 (V)',
        _cellNom,
        '모선 전압 ÷ 셀당 공칭 전압으로 셀 수의 계산값을 봅니다. 정수가 아니면 제조사와 계통 기준으로 셀 수를 정합니다.',
      ),
      elecField(
        'eb_cellmin',
        '셀당 최저 전압 (V)',
        _cellMin,
        '방전을 끝내도 되는 셀당 최저 전압입니다. 전지 종류와 제조사 표로 정합니다. K 값을 읽은 표의 종지 전압과 같아야 합니다.',
      ),
      elecField(
        'eb_cells',
        '셀 수 (선택)',
        _cells,
        '선정한 셀 수입니다. 넣으면 방전 종지 때 모선 전압을 계산합니다.',
      ),
      elecField(
        'eb_minbus',
        '부하 최저 허용 전압 (V, 선택)',
        _minBus,
        '직류 부하가 견디는 최저 모선 전압입니다. 넣으면 방전 종지 전압과 견줘 합격/불합격을 봅니다.',
      ),
      const SizedBox(height: 12),
      result,
      if (r.ok && errors.isEmpty) _sectionTable(r),
      elecBasis('eb_basis', [
        '식: 구간 s의 용량 = Σ (Ap − Ap-1) × K(단계 p 시작부터 구간 s 끝까지의 시간). 구간 용량의 최댓값을 씁니다.',
        'SBA S 0601: C = (1 ÷ L) × [K1×I1 + K2×(I2 − I1) + K3×(I3 − I2) + …]. L은 보수율(보통 0.8), K는 방전 시간·최저 온도·최저 전압으로 정해집니다.',
        'IEEE 485(KEPIC EEG 1200): 구간 최댓값 × 온도 보정계수 × 설계 여유 ÷ 노화 비율(0.8, 곱으로는 1.25). K는 25°C 기준입니다.',
        '차이: K 구간의 잡는 방식과, 온도 보정과 노화를 넣는 시기가 다릅니다. 두 방식은 같은 조건이면 같은 용량이라는 국내 논문이 있습니다(2022, 초록만 확인).',
        '검증: 강의 자료(오리건 주립대 ESE 471)의 IEEE 485 예제 구간 3의 합 37.91 Ah와 이 앱의 계산이 같습니다.',
        '출처는 모두 원문 대조 전(2차 자료)입니다. 본문은 docs/전기_축전지_근거.md에 있습니다.',
        '서로 다른 값: 설계 여유는 자료마다 10~15%, 10~25%로 다릅니다. 셀당 공칭 전압은 2.0V로 부르는 자료와 2.1V로 적은 강의 자료가 있습니다.',
        '넣지 않은 것: K 표(제조사 자료), 리튬이온 축전지 식, 무작위 부하, SBA 증가형 식(K의 시간 기준을 확인하지 못함), 충전기 용량.',
      ]),
    ]);
  }
}
