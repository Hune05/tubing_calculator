// 전기 설비 계산: 발전기 용량 탭(비상발전기 PG 방식). 계산은 elec_generator.dart, 근거는 docs/전기_발전기_근거.md.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../common/calc_form_parts.dart';
import 'elec_form_parts.dart';
import 'elec_generator.dart';

class ElecGeneratorTab extends StatefulWidget {
  const ElecGeneratorTab({super.key, this.history});

  /// "최근 계산 기록"을 다른 탭과 함께 쓸 때 밖에서 만든 기록을 넣는다. 비우면 이 탭만의 기록을 쓴다.
  final RecentCalcLog? history;

  /// 입력값을 남기는 저장 칸.
  static const draftKey = 'elec_generator_draft_v1';

  @override
  State<ElecGeneratorTab> createState() => _ElecGeneratorTabState();
}

class _ElecGeneratorTabState extends State<ElecGeneratorTab>
    with
        CalcFormParts<ElecGeneratorTab>,
        RecentCalcHistoryMixin<ElecGeneratorTab>,
        ElecTabParts<ElecGeneratorTab>,
        AutomaticKeepAliveClientMixin<ElecGeneratorTab> {
  // 탭을 옮겨도 입력이 사라지지 않게 살려 둔다.
  @override
  bool get wantKeepAlive => true;

  @override
  RecentCalcLog get calcLog => widget.history ?? super.calcLog;

  final _load = TextEditingController();
  final _demand = TextEditingController(text: '100');
  final _eff = TextEditingController(text: '85');
  final _pf = TextEditingController(text: '80');
  final _motor = TextEditingController();
  final _beta = TextEditingController();
  final _c = TextEditingController();
  final _xd = TextEditingController();
  final _dv = TextEditingController();
  final _startPf = TextEditingController();
  final _genPf = TextEditingController();
  final _harm = TextEditingController();
  final _harmF = TextEditingController();
  final _volts = TextEditingController(text: '380');
  final _chosen = TextEditingController();

  List<(TextEditingController, String)> get _texts => [
    (_load, 'load'),
    (_demand, 'demand'),
    (_eff, 'eff'),
    (_pf, 'pf'),
    (_motor, 'motor'),
    (_beta, 'beta'),
    (_c, 'c'),
    (_xd, 'xd'),
    (_dv, 'dv'),
    (_startPf, 'startPf'),
    (_genPf, 'genPf'),
    (_harm, 'harm'),
    (_harmF, 'harmF'),
    (_volts, 'volts'),
    (_chosen, 'chosen'),
  ];

  Timer? _saveTimer;
  String? _lastDraft;
  String? _pendingDraft;
  bool _draftReady = false;

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
    super.dispose();
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(ElecGeneratorTab.draftKey);
      if (raw != null && mounted) {
        final m = jsonDecode(raw);
        if (m is Map<String, dynamic>) {
          setState(() {
            for (final (c, k) in _texts) {
              if (m[k] is String) c.text = m[k] as String;
            }
          });
        }
      }
      _lastDraft = raw;
    } catch (_) {
      // 저장 칸을 못 읽어도 기본값으로 쓴다.
    }
    _draftReady = true;
  }

  void _scheduleSave() {
    if (!_draftReady) return;
    final raw = jsonEncode({for (final (c, k) in _texts) k: c.text});
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
      await prefs.setString(ElecGeneratorTab.draftKey, raw);
    } catch (_) {
      // 저장을 못 해도 계산에는 지장이 없다.
    }
  }

  /// 칸을 숫자로 읽는다. 비면 null, 숫자가 아니면 bad에 이름을 적는다.
  /// [pct]인 칸(수용률·효율·역률)은 %로 넣는다: 1을 넘으면 100으로 나눠 비율로 바꾼다(0.85도 그대로 받는다).
  double? _read(
    TextEditingController c,
    String label,
    List<String> bad, {
    bool pct = false,
  }) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    var v = readNum(c);
    if (v == null) {
      bad.add('$label: 숫자가 아닙니다.');
    } else if (pct && v > 1) {
      v = v / 100;
    }
    return v;
  }

  GenStartKind get _kind {
    final v = readNum(_c);
    for (final k in GenStartKind.values) {
      if (k.c != null && v != null && (v - k.c!).abs() < 1e-9) return k;
    }
    return GenStartKind.custom;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _scheduleSave();
    final bad = <String>[];
    final input = GenInput(
      loadKw: _read(_load, '부하 합계', bad),
      demand: _read(_demand, '수용률', bad, pct: true),
      eff: _read(_eff, '효율', bad, pct: true),
      pf: _read(_pf, '역률', bad, pct: true),
      motorKw: _read(_motor, '가장 큰 전동기', bad),
      beta: _read(_beta, 'β', bad),
      startC: _read(_c, '기동 방식 계수', bad),
      xdPct: _read(_xd, 'X″d', bad),
      dvPct: _read(_dv, '허용 전압강하', bad),
      startPf: _read(_startPf, '기동 역률', bad, pct: true),
      genPf: _read(_genPf, '발전기 역률', bad, pct: true),
      harmonicKva: _read(_harm, '고조파 부하', bad),
      harmonicFactor: _read(_harmF, '고조파 가산 계수', bad),
      volts: _read(_volts, '발전기 전압', bad),
      chosenKva: _read(_chosen, '선정 용량', bad),
    );
    final empty = _load.text.trim().isEmpty && bad.isEmpty;
    final r = calcGenerator(input);
    final errors = [...bad, if (bad.isEmpty) ...r.errors];

    Widget result;
    String? summary;
    var warn = false;
    if (empty) {
      result = calcResult(solve: true, 
        key: const Key('eg_result'),
        big: '—',
        caption: '부하 합계를 넣으면 필요 발전기 용량을 계산합니다',
        lines: const [],
      );
    } else if (errors.isNotEmpty) {
      warn = true;
      summary = '입력 확인';
      result = calcResult(solve: true, 
        key: const Key('eg_result'),
        big: '입력 확인',
        caption: '다음 입력값을 고치십시오',
        warn: true,
        lines: errors,
      );
    } else {
      final req = r.required!;
      final fail = r.chosenPass == false;
      warn = fail;
      summary = '필요 ${fmt(req, 0)} kVA (${r.governing})';
      result = calcResult(solve: true, 
        key: const Key('eg_result'),
        big: '${fmt(req, 1)} kVA',
        caption: '필요 발전기 용량 (${r.governing} 기준)',
        warn: fail,
        lines: [
          '① PG1 정상 운전: ${fmt(r.pg1!, 1)} kVA = ${fmt(input.loadKw!, 1)} × '
              '${fmt(input.demand!, 2)} ÷ (${fmt(input.eff!, 2)} × ${fmt(input.pf!, 2)})',
          if (r.pg2 != null)
            '② PG2 전동기 기동 전압강하: ${fmt(r.pg2!, 1)} kVA = ${fmt(input.motorKw!, 1)} × '
                '${fmt(input.beta!, 2)} × ${fmt(input.startC!, 2)} × ${fmt(input.xdPct! / 100, 3)} '
                '× (1 − ${fmt(input.dvPct! / 100, 3)}) ÷ ${fmt(input.dvPct! / 100, 3)}',
          if (r.pg3 != null)
            '③ PG3 마지막 전동기 기동: ${fmt(r.pg3!, 1)} kVA = [(${fmt(input.loadKw!, 1)} − '
                '${fmt(input.motorKw!, 1)}) ÷ ${fmt(input.eff!, 2)} + ${fmt(input.motorKw!, 1)} × '
                '${fmt(input.beta!, 2)} × ${fmt(input.startC!, 2)} × ${fmt(input.startPf!, 2)}] '
                '÷ ${fmt(input.genPf!, 2)}',
          if (r.pg4 != null)
            '④ PG4 고조파 가산: ${fmt(r.pg4!, 1)} kVA = PG1 + ${fmt(input.harmonicKva!, 1)} × '
                '${fmt(input.harmonicFactor!, 2)} = ${fmt(r.pg1!, 1)} + ${fmt(input.harmonicKva!, 1)} × '
                '${fmt(input.harmonicFactor!, 2)}',
          '⑤ 가장 큰 값을 필요 용량으로 합니다: max(${[
            'PG1 ${fmt(r.pg1!, 1)}',
            if (r.pg2 != null) 'PG2 ${fmt(r.pg2!, 1)}',
            if (r.pg3 != null) 'PG3 ${fmt(r.pg3!, 1)}',
            if (r.pg4 != null) 'PG4 ${fmt(r.pg4!, 1)}',
          ].join(', ')}) = ${fmt(req, 1)} kVA (${r.governing})',
          if (r.currentA != null)
            '정격전류: ${fmt(r.currentA!, 0)} A = ${fmt(req, 1)} kVA × 1000 ÷ (√3 × ${fmt(input.volts!, 0)} V)',
          if (r.chosenPass != null)
            r.chosenPass!
                ? '선정 ${fmt(input.chosenKva!, 0)} kVA: 합격 (여유 ${fmt(r.chosenMarginPct!, 1)}%)'
                : '선정 ${fmt(input.chosenKva!, 0)} kVA: 불합격 (필요 ${fmt(req, 1)} kVA에 ${fmt(-r.chosenMarginPct!, 1)}% 부족)',
          ...r.notes,
          '최종 용량은 제조사 검토로 확정합니다.',
          '2021년 개정 KDS 31 60 20의 GP 방식은 자료마다 식이 달라 넣지 않았습니다. 새 설계는 기준 원문으로 확인하십시오.',
        ],
      );
    }

    return elecPage(sumKey: 'eg_sum', summary: summary, warn: warn, [
      elecSectionTitle('부하'),
      elecField(
        'eg_load',
        '부하 합계 (kW)',
        _load,
        '정상 운전 때 발전기에 걸리는 부하의 출력 합계입니다. 전동기 부하도 포함합니다. 부하 일람표의 kW를 더해 넣으십시오.',
      ),
      elecField(
        'eg_demand',
        '수용률 (α, %)',
        _demand,
        '부하가 한꺼번에 다 걸리지 않을 때 줄이는 비율입니다. 근거가 없으면 100으로 두십시오. 100을 초과해 넣을 수 없습니다.',
      ),
      elecField(
        'eg_eff',
        '부하 종합 효율 (%)',
        _eff,
        '85%로 쓰는 자료가 있습니다(2차 자료). 부하 자료가 있으면 그 값을 넣으십시오.',
      ),
      elecField(
        'eg_pf',
        '부하 종합 역률 (%)',
        _pf,
        '80%로 쓰는 자료가 있습니다(2차 자료). 부하 자료가 있으면 그 값을 넣으십시오.',
      ),
      elecSectionTitle('가장 큰 전동기'),
      elecField(
        'eg_motor',
        '전동기 출력 (kW)',
        _motor,
        '기동 용량이 가장 큰 전동기의 출력입니다. 없으면 비워 두십시오. 그러면 PG2와 PG3는 계산하지 않습니다.',
      ),
      elecChipGroup(
        '기동 방식',
        '기동 방식 계수 C: 직입 1.0, Y-Δ 0.67, 리액터 65% 0.65. 논문 표 한 곳에서 확인한 값이며 원문 대조 전(2차 자료)입니다.\n'
            '소프트스타터·인버터는 제조사 자료로 계수를 직접 넣으십시오.',
        [
          for (final k in GenStartKind.values)
            calcChip('eg_start_${k.name}', k.label, _kind == k, () {
              setState(() {
                if (k.c != null) {
                  _c.text = fmt(k.c!, 2);
                } else {
                  _c.clear();
                }
              });
            }),
        ],
      ),
      elecField(
        'eg_c',
        '기동 방식 계수 (C)',
        _c,
        '위 기동 방식을 고르면 값이 채워집니다. 다른 방식은 제조사 자료 값을 직접 넣으십시오.',
      ),
      elecField(
        'eg_beta',
        '기동 kVA/kW (β)',
        _beta,
        '전동기 출력 1kW당 기동 kVA입니다. KIEE 논문(2018) 예제는 7.2를 썼고 다른 정리 글에는 0.72로 적혀 서로 다릅니다. 제조사 자료로 확인하십시오.',
      ),
      elecField(
        'eg_xd',
        '발전기 X″d (%)',
        _xd,
        '발전기 명판이나 제조사 자료의 과도 리액턴스입니다. 20~25%로 소개하는 자료가 있으나 발전기마다 다릅니다.',
      ),
      elecField(
        'eg_dv',
        '허용 전압강하 ΔV (%)',
        _dv,
        '전동기 기동 순간에 발전기 전압이 떨어져도 되는 비율입니다. 일반 25% 이하, 비상용 승강기가 있으면 20% 이하로 소개하는 자료가 있습니다(2차 자료). 설계 기준으로 확인하십시오.',
      ),
      elecField(
        'eg_startpf',
        '기동 역률 (%, PG3, 선택)',
        _startPf,
        '전동기 기동 때의 역률입니다. 제조사 자료 값을 넣으십시오. 논문 표에는 전동기 용량별로 15~62%가 있습니다. 비우면 PG3를 계산하지 않습니다.',
      ),
      elecField(
        'eg_genpf',
        '발전기 역률 (%, PG3, 선택)',
        _genPf,
        '발전기 명판 역률입니다. 보통 80%입니다. 비우면 PG3를 계산하지 않습니다.',
      ),
      elecSectionTitle('고조파 부하와 결과'),
      elecField(
        'eg_harm',
        '고조파 부하 (kVA, 선택)',
        _harm,
        'UPS·인버터·LED 등 정류기 부하의 입력 용량입니다. 없으면 비워 두십시오.',
      ),
      elecField(
        'eg_harmf',
        '고조파 가산 계수',
        _harmF,
        'PG1에 고조파 부하 × 계수를 더합니다. 2.0~2.5로 소개하는 정리 글이 한 곳 있으나 원문 대조 전입니다. 고조파 부하를 넣었으면 계수도 넣으십시오.',
      ),
      elecField('eg_volts', '발전기 전압 (V)', _volts, '3상 선간전압입니다. 정격전류 계산에 씁니다.'),
      elecField(
        'eg_chosen',
        '선정 용량 (kVA, 선택)',
        _chosen,
        '제조사 표준 용량 중 고른 값을 넣으면 합격/불합격을 판정합니다.',
      ),
      const SizedBox(height: 12),
      result,
      elecBasis('eg_basis', [
        '방식: PG 방식. 필요 용량은 PG1, PG2, PG3, PG4 중 큰 값입니다.',
        'PG1 = 부하 kW × 수용률 ÷ (효율 × 역률).',
        'PG2 = 전동기 kW × β × C × X″d × (1 − ΔV) ÷ ΔV. 가장 큰 전동기를 기동할 때 허용 전압강하 조건입니다.',
        'PG3 = [(부하 − 전동기) ÷ 효율 + 전동기 × β × C × 기동 역률] ÷ 발전기 역률. 마지막 전동기를 기동할 때 조건입니다.',
        'PG4 = PG1 + 고조파 부하 × 가산 계수.',
        '출처: KIEE 논문 2018(이종혁·김진오), 한양대 논문 2021, 발전기 용량 산정 정리 글(cq4l.com). 모두 원문 대조 전(2차 자료)입니다. 논문의 PG2 예제 351 kVA와 이 식의 결과가 같습니다.',
        '서로 다른 값: β를 논문은 7.2, 정리 글은 0.72로 적었습니다. PG3의 역률 기호도 자료마다 다르게 적혀 있어 기동 역률 칸을 따로 두었습니다.',
        '2021년 6월 개정 KDS 31 60 20은 GP 방식을 씁니다. 자료마다 식이 셋으로 갈려 원문 대조 전이라 넣지 않았습니다.',
        '넣지 않은 것: GP 방식, 단상 부하 불평형 보정, 고도·온도 출력 감소, 연료·환기 조건.',
      ]),
    ]);
  }
}
