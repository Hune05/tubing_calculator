// 전동기·발전기 계산: 콘덴서·단상 탭. 전동기 단자 콘덴서 한도, 3상 모터 단상 운전(Steinmetz), 단상 모터 콘덴서.
// 계산은 motor_capacitor.dart, 근거와 확인 정도는 docs/전동기_콘덴서_토크_근거.md.
import 'package:flutter/material.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../common/calc_form_parts.dart';
import 'elec_form_parts.dart';
import 'motor_capacitor.dart';

enum _Sec { limit, steinmetz, single }

String _secName(_Sec s) => switch (s) {
  _Sec.limit => '콘덴서 한도',
  _Sec.steinmetz => '3상 모터 단상 운전',
  _Sec.single => '단상 모터 콘덴서',
};

class ElecMotorCapacitorTab extends StatefulWidget {
  const ElecMotorCapacitorTab({super.key, this.history});

  /// "최근 계산 기록"을 다른 탭과 함께 쓸 때 밖에서 만든 기록을 넣는다.
  final RecentCalcLog? history;

  @override
  State<ElecMotorCapacitorTab> createState() => _ElecMotorCapacitorTabState();
}

class _ElecMotorCapacitorTabState extends State<ElecMotorCapacitorTab>
    with
        CalcFormParts<ElecMotorCapacitorTab>,
        RecentCalcHistoryMixin<ElecMotorCapacitorTab>,
        ElecTabParts<ElecMotorCapacitorTab>,
        AutomaticKeepAliveClientMixin<ElecMotorCapacitorTab> {
  @override
  RecentCalcLog get calcLog => widget.history ?? super.calcLog;

  @override
  bool get wantKeepAlive => true;

  _Sec _sec = _Sec.limit;

  // 콘덴서 한도
  final _volts = TextEditingController(text: '380');
  final _i0 = TextEditingController();
  bool _estI0 = false;
  final _inA = TextEditingController();
  final _inPf = TextEditingController();
  final _setting = TextEditingController();
  final _pf1 = TextEditingController();
  final _pf2 = TextEditingController();
  int? _rpm; // 도표 L25 계수를 볼 동기 회전수
  final _tkw = TextEditingController();

  // 3상 모터 단상 운전
  final _skw = TextEditingController();
  final _svolts = TextEditingController(text: '220');
  final _shz = TextEditingController(text: '60');

  // 단상 모터 콘덴서
  final _pkw = TextEditingController();
  final _pvolts = TextEditingController(text: '220');
  final _phz = TextEditingController(text: '60');
  final _have = TextEditingController();

  /// 칸과 "최근 계산 기록" 입력 묶음의 키.
  List<(TextEditingController, String)> get _texts => [
    (_volts, 'volts'),
    (_i0, 'i0'),
    (_inA, 'inA'),
    (_inPf, 'inPf'),
    (_setting, 'set'),
    (_pf1, 'pf1'),
    (_pf2, 'pf2'),
    (_tkw, 'tkw'),
    (_skw, 'skw'),
    (_svolts, 'svolts'),
    (_shz, 'shz'),
    (_pkw, 'pkw'),
    (_pvolts, 'pvolts'),
    (_phz, 'phz'),
    (_have, 'have'),
  ];

  List<TextEditingController> get _all => [for (final (c, _) in _texts) c];

  // 화면을 나갔다 와도 입력이 남는다(8차).
  @override
  String? get elecDraftKey => 'elec_draft_motor_capacitor_v1';

  @override
  Map<String, Object?>? historySnapshot() => {
    'sec': _sec.name,
    for (final (c, k) in _texts) k: c.text,
    'estI0': _estI0,
    'rpm': _rpm,
  };

  @override
  void applyHistorySnapshot(Map<String, dynamic> m) {
    for (final (c, k) in _texts) {
      if (m[k] is String) c.text = m[k] as String;
    }
    _sec = _Sec.values.firstWhere((s) => s.name == m['sec'], orElse: () => _sec);
    if (m['estI0'] is bool) _estI0 = m['estI0'] as bool;
    // 회전수는 고르지 않은 상태(null)도 값이다. 키가 없거나 표에 없는 값이면 그대로 둔다.
    if (m.containsKey('rpm')) {
      final r = m['rpm'];
      if (r == null) {
        _rpm = null;
      } else if (r is num && const [3000, 1500, 1000, 750].contains(r.toInt())) {
        _rpm = r.toInt();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  double? _ratio(TextEditingController c) {
    final v = readNum(c);
    if (v == null) return null;
    return v > 1 ? v / 100 : v;
  }

  // ─────────────── 콘덴서 한도 ───────────────

  (List<Widget>, String?, List<String>, bool) _limit() {
    final v = readNum(_volts);
    final inA = readNum(_inA);
    final inPf = _ratio(_inPf);
    final i0 = _estI0
        ? (inA != null && inPf != null ? estimateNoLoadAmps(inA, inPf) : null)
        : readNum(_i0);
    final q = (i0 != null && v != null) ? capacitorLimitKvar(i0, v) : null;
    final lines = <String>[];
    String? summary;
    if (q != null) {
      lines.add('① 콘덴서 상한 Qc ≤ 0.9 × I0 × Un × √3 = 0.9 × ${fmt(i0!, 1)} × ${fmt(v! / 1000, 3)} × √3 = ${fmt(q, 2)} kvar');
      if (_estI0) {
        lines.add('무부하 전류 추정 I0 ≈ 2 × In × (1 − cosφn) = 2 × ${fmt(inA!, 1)} × (1 − ${fmt(inPf!, 3)}) = ${fmt(i0, 1)} A (원문 못 본 근사식입니다. 측정한 무부하 전류나 제조사 값이 있으면 그 값을 쓰십시오)');
      }
      lines.add('이 값을 넘으면 전동기를 끊은 뒤에도 콘덴서가 전동기를 발전기처럼 돌려 과전압(자기여자)이 생길 수 있습니다. 한도를 넘는 용량은 전동기와 따로 개폐하고 과전압 보호를 두십시오.');
      summary = '콘덴서 상한 ${fmt(q, 2)} kvar';
    }
    final tkw = readNum(_tkw);
    final tRow = (tkw != null && _rpm != null) ? schneiderL24Kvar(tkw, _rpm!) : null;
    if (tkw != null && _rpm != null) {
      lines.add(
        tRow == null
            ? '도표 L24에 ${fmt(tkw, 0)} kW 행이 없습니다(22~450 kW의 표 행만 있습니다).'
            : '도표 L24(3상 230/400 V): ${fmt(tkw, 0)} kW $_rpm rpm는 최대 ${fmt(tRow, 1)} kvar입니다. 이 값은 원하는 역률까지 보상하기에 작을 수 있다고 원문이 적고 있습니다.',
      );
    }
    final set = readNum(_setting);
    final p1 = _ratio(_pf1);
    final p2 = _ratio(_pf2);
    final ns = (set != null && p1 != null && p2 != null) ? relaySettingAfter(set, p1, p2) : null;
    if (ns != null) {
      lines.add('② 콘덴서를 달면 전원 쪽 전류가 줄어듭니다. 과부하계전기가 콘덴서보다 전원 쪽이면 설정 = ${fmt(set!, 1)} × ${fmt(p1!, 2)} ÷ ${fmt(p2!, 2)} = ${fmt(ns, 1)} A로 낮춥니다.');
      summary ??= '계전기 설정 ${fmt(ns, 1)} A';
    }
    if (_rpm != null && kRelayFactorByRpm[_rpm] != null) {
      final f = kRelayFactorByRpm[_rpm]!;
      lines.add('도표 L25 보정계수: $_rpm rpm ${fmt(f, 2)}${set == null ? '' : ' → 설정 ${fmt(set * f, 1)} A'}. 이 계수는 도표 L24의 kvar만큼 보상했을 때만 맞습니다. 그보다 크게 보상하면 실제 역률 비로 계산하십시오.');
    }
    return (
      [
        elecField('mc_volts', '전압 Un (V)', _volts, '전동기 정격(선간) 전압입니다. 380 또는 440처럼 넣으십시오.'),
        elecChipGroup('무부하 전류 I0', '한도 식에 쓰는 전동기 무부하 전류입니다. 측정했거나 제조사 자료가 있으면 직접 넣고, 모르면 정격전류와 정격 역률로 추정할 수 있습니다.', [
          calcChip('mc_i0_direct', '직접 입력', !_estI0, () => setState(() => _estI0 = false)),
          calcChip('mc_i0_est', '정격값으로 추정', _estI0, () => setState(() => _estI0 = true)),
        ]),
        if (!_estI0)
          elecField('mc_i0', '무부하 전류 I0 (A)', _i0, '전동기를 부하 없이 돌릴 때 전류입니다.')
        else ...[
          elecField('mc_in', '정격전류 In (A)', _inA, '명판의 정격전류입니다.'),
          elecField('mc_inpf', '정격 역률 cosφn', _inPf, '명판의 역률입니다. 85 또는 0.85처럼 넣으십시오.'),
        ],
        elecSectionTitle('과부하계전기 설정 보정 (선택)'),
        elecField('mc_set', '계전기 설정 (A)', _setting, '콘덴서를 달기 전 과부하계전기 설정입니다.'),
        elecField('mc_pf1', '보상 전 역률', _pf1, '콘덴서를 달기 전 운전 역률입니다.'),
        elecField('mc_pf2', '보상 후 역률', _pf2, '콘덴서를 단 뒤 운전 역률입니다.'),
        elecChipGroup('동기 회전수 (도표 L25)', '도표의 보정계수와 도표 L24 최대 kvar를 볼 동기 회전수(rpm)입니다.', [
          for (final r in const [3000, 1500, 1000, 750])
            calcChip('mc_rpm_$r', '$r', _rpm == r, () => setState(() => _rpm = _rpm == r ? null : r)),
        ]),
        elecField('mc_tkw', '전동기 출력 (kW, 도표 L24 조회)', _tkw, '22, 30, 37, 45, 55, 75, 90, 110, 132, 160, 200, 250, 280, 355, 400, 450 kW가 표에 있습니다. 위에서 동기 회전수를 고르면 최대 kvar를 보여 줍니다.'),
      ],
      summary,
      lines.isEmpty ? const ['전압과 무부하 전류(또는 정격전류·역률)를 넣으십시오.'] : lines,
      false,
    );
  }

  // ─────────────── 3상 모터 단상 운전 ───────────────

  (List<Widget>, String?, List<String>, bool) _steinmetz() {
    final kw = readNum(_skw);
    final v = readNum(_svolts);
    final hz = readNum(_shz);
    final c = (kw != null && v != null && hz != null) ? steinmetzRunMicroFarad(kw, v, hz) : null;
    final lines = <String>[];
    String? summary;
    if (c != null) {
      final perKw = c / kw!;
      lines.addAll([
        '① 운전 콘덴서 C = 2 × P ÷ (√3 × 2π × f × U²) = 2 × ${fmt(kw * 1000, 0)} ÷ (√3 × 2π × ${fmt(hz!, 0)} × ${fmt(v!, 0)}²) = ${fmt(c, 1)} μF (${fmt(perKw, 1)} μF/kW)',
        '② 기동 콘덴서(기동할 때만 병렬 추가) ≈ 운전용의 ${fmt(kStartCapLow, 0)}~${fmt(kStartCapHigh, 0)}배 = ${fmt(c * kStartCapLow, 0)}~${fmt(c * kStartCapHigh, 0)} μF(2~3배는 원문 못 봄). 기동 후에는 반드시 분리합니다.',
        '③ 이때 낼 수 있는 출력 ≈ 정격의 ${fmt(kSteinmetzOutputLow * 100, 0)}~${fmt(kSteinmetzOutputHigh * 100, 0)} % = ${fmt(kw * kSteinmetzOutputLow, 2)}~${fmt(kw * kSteinmetzOutputHigh, 2)} kW (자료마다 60~80 %로 갈립니다)',
        '④ 콘덴서 정격전압은 400 V 이상(400~450 V급)으로 고릅니다.',
        '결선: 220/380 V급 전동기를 Δ 결선으로 하고 단상 전원을 단자 두 개에 넣습니다. 콘덴서는 한쪽 전원 단자와 세 번째 빈 단자 사이(한 권선과 병렬)에 답니다. 콘덴서를 어느 전원 단자 쪽에 다느냐로 회전 방향이 정해집니다.',
        '소형 전동기용입니다(자료마다 0.75 kW 이하 또는 2.2 kW 미만). 기동 토크는 정격의 20~50 % 정도라 가벼운 부하 기동에만 맞습니다.',
        '식의 원문(규격·제조사 원본)은 못 봤습니다(de.wikipedia 한 곳, 직접 검산). 230 V 50 Hz에서 약 70 μF/kW로 일반 자료와 맞습니다. 60 Hz 값은 같은 식으로 환산한 것이라 출처에서 직접 확인한 값이 아닙니다.',
      ]);
      if (kw >= 2.2) {
        lines.add('${fmt(kw, 1)} kW는 자료가 말하는 소형 한도(2.2 kW 미만)를 넘습니다. 단상 운전이 적합한지 제조사에 확인하십시오.');
      }
      summary = '운전 콘덴서 ${fmt(c, 1)} μF · 출력 ${fmt(kw * kSteinmetzOutputLow, 2)}~${fmt(kw * kSteinmetzOutputHigh, 2)} kW';
    }
    return (
      [
        elecField('mc_skw', '전동기 정격 출력 (kW)', _skw, '3상 전동기 명판의 정격 출력입니다.'),
        elecField('mc_svolts', '단상 전원 전압 U (V)', _svolts, '단상 전원 전압이자 Δ 권선에 걸리는 전압입니다(220/380 V급 전동기를 220 V 단상에 쓰면 220).'),
        elecField('mc_shz', '주파수 (Hz)', _shz, '한국은 60 Hz입니다.'),
      ],
      summary,
      lines.isEmpty ? const ['출력·전압·주파수를 넣으십시오.'] : lines,
      false,
    );
  }

  // ─────────────── 단상 모터 콘덴서 ───────────────

  (List<Widget>, String?, List<String>, bool) _single() {
    final kw = readNum(_pkw);
    final v = readNum(_pvolts);
    final hz = readNum(_phz);
    final have = readNum(_have);
    final r = kw == null ? null : singlePhaseRunRangeUf(kw);
    final lines = <String>[];
    String? summary;
    if (r != null) {
      lines.addAll([
        '① 운전 콘덴서(영구 접속) 대략 범위 = ${fmt(kPscUfPerKwLow, 0)}~${fmt(kPscUfPerKwHigh, 0)} μF/kW × ${fmt(kw!, 2)} kW = ${fmt(r.$1, 0)}~${fmt(r.$2, 0)} μF',
        '② 기동 콘덴서 ≈ 운전용의 ${fmt(kStartCapLow, 0)}~${fmt(kStartCapHigh, 0)}배 = ${fmt(r.$1 * kStartCapLow, 0)}~${fmt(r.$2 * kStartCapHigh, 0)} μF (원심 스위치로 기동 후 분리하는 콘덴서 기동형, 2~3배는 원문 못 봄)',
        '③ 콘덴서 정격전압은 220~230 V 전원에서 400 V 이상, 또는 전원 전압의 1.5배 이상으로 고릅니다.',
        '원문을 못 본 폭 넓은 대략치입니다(2차 자료마다 20~25, 25~30, 30~50 μF/kW). 반드시 전동기 명판이나 제조사가 정한 용량을 우선하십시오. 정격 운전 중 콘덴서에는 전원 전압보다 높은 전압이 걸립니다.',
      ]);
      summary = '운전 콘덴서 ${fmt(r.$1, 0)}~${fmt(r.$2, 0)} μF';
    }
    if (have != null && v != null && hz != null && have > 0) {
      final ic = capacitorAmps(have, v, hz);
      final qc = capacitorKvarOf(have, v, hz);
      lines.add('④ 지금 콘덴서 ${fmt(have, 1)} μF를 ${fmt(v, 0)} V ${fmt(hz, 0)} Hz에 걸면 콘덴서 전류 Ic = 2π × f × C × V = ${fmt(ic, 2)} A, 무효전력 Qc = 2π × f × C × V² = ${fmt(qc, 3)} kvar');
      summary ??= '콘덴서 전류 ${fmt(ic, 2)} A';
    }
    return (
      [
        elecField('mc_pkw', '전동기 출력 (kW)', _pkw, '단상 전동기 명판의 정격 출력입니다.'),
        elecField('mc_pvolts', '전원 전압 (V)', _pvolts, '단상 전원 전압입니다.'),
        elecField('mc_phz', '주파수 (Hz)', _phz, '한국은 60 Hz입니다.'),
        elecField('mc_have', '달려 있는 콘덴서 (μF, 선택)', _have, '지금 달려 있는 콘덴서 용량입니다. 넣으면 콘덴서 전류와 무효전력을 보여 줍니다.'),
      ],
      summary,
      lines.isEmpty ? const ['전동기 출력을 넣으십시오.'] : lines,
      false,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final (fields, summary, lines, warn) = switch (_sec) {
      _Sec.limit => _limit(),
      _Sec.steinmetz => _steinmetz(),
      _Sec.single => _single(),
    };
    return elecPage(
      sumKey: 'mc2_sum',
      summary: summary,
      warn: warn,
      [
        elecChipGroup('계산 항목', '전동기에 콘덴서를 쓰는 세 가지 경우입니다.', [
          for (final s in _Sec.values)
            calcChip('mc2_sec_${s.name}', _secName(s), _sec == s, () => setState(() => _sec = s)),
        ]),
        ...fields,
        const SizedBox(height: 6),
        calcResult(solve: true, 
          key: const Key('mc2_result'),
          big: summary == null ? '-' : summary.split(' · ').first,
          caption: _secName(_sec),
          warn: warn,
          lines: lines,
        ),
        elecBasis('mc2_basis', const [
          '콘덴서 한도 Qc ≤ 0.9 × I0 × Un × √3와 도표 L24·L25: Schneider Electrical Installation Guide(2007) 장 L 원문으로 확인했습니다. 무부하 전류 추정식 I0 ≈ 2·In·(1 − cosφn)은 원문 못 봄(검색 요약뿐)입니다.',
          '3상 모터 단상 운전 C = 2P ÷ (√3·ω·U²): 원문 못 봄(de.wikipedia 한 곳), 직접 검산했습니다. 230 V 50 Hz 약 70 μF/kW와 맞습니다. 60 Hz 값은 식 환산입니다.',
          '단상 전동기 콘덴서 20~50 μF/kW와 기동 콘덴서 2~3배는 원문 못 봄, 2차 자료마다 폭이 넓은 대략치입니다. 명판 값을 우선합니다.',
          '출력 70~80 %, 기동 토크 20~50 %, 콘덴서 400~450 V급은 자료 여러 곳이 같은 범위입니다.',
          '한국 규정·교재의 μF/kW 표는 찾지 못했습니다. 전기안전·설계 기준이 따로 있으면 그 값을 따르십시오.',
        ]),
      ],
    );
  }
}
