// 전기 설비 계산: 전동기 점검 탭(10-03). 점검 순서 → 측정값 → 계산 과정 → 판정을 한 화면에 둔다.
// 계산은 motor_check.dart, 근거는 docs/전동기_점검_근거.md. 출처끼리 다른 값은 화면에 같이 적는다.
import 'package:flutter/material.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import 'circuit_reading_page.dart';
import 'elec_form_parts.dart';
import 'motor_check.dart';

class ElecMotorCheckTab extends StatefulWidget {
  const ElecMotorCheckTab({super.key, this.history});

  /// "최근 계산 기록"을 다른 탭과 함께 쓸 때 밖에서 만든 기록을 넣는다.
  final RecentCalcLog? history;

  @override
  State<ElecMotorCheckTab> createState() => _ElecMotorCheckTabState();
}

class _ElecMotorCheckTabState extends State<ElecMotorCheckTab>
    with
        CalcFormParts<ElecMotorCheckTab>,
        RecentCalcHistoryMixin<ElecMotorCheckTab>,
        ElecTabParts<ElecMotorCheckTab>,
        AutomaticKeepAliveClientMixin<ElecMotorCheckTab> {
  @override
  RecentCalcLog get calcLog => widget.history ?? super.calcLog;

  @override
  bool get wantKeepAlive => true;

  final _volt = TextEditingController(text: '380');
  final _ir1 = TextEditingController();
  final _ir10 = TextEditingController();
  final _irTemp = TextEditingController(text: '20');
  final _r1 = TextEditingController();
  final _r2 = TextEditingController();
  final _r3 = TextEditingController();
  final _rTemp = TextEditingController(text: '20');
  final _rRef = TextEditingController();
  final _rRefTemp = TextEditingController(text: '20');
  final _v1 = TextEditingController();
  final _v2 = TextEditingController();
  final _v3 = TextEditingController();
  final _a1 = TextEditingController();
  final _a2 = TextEditingController();
  final _a3 = TextEditingController();
  WindingKind _kind = WindingKind.random;
  IrCorrection _corr = IrCorrection.ieee43;
  bool _classA = false;

  @override
  void dispose() {
    for (final c in [
      _volt,
      _ir1,
      _ir10,
      _irTemp,
      _r1,
      _r2,
      _r3,
      _rTemp,
      _rRef,
      _rRefTemp,
      _v1,
      _v2,
      _v3,
      _a1,
      _a2,
      _a3,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// "최근 계산 기록"으로 되돌릴 글 칸과 그 이름.
  List<(TextEditingController, String)> get _texts => [
    (_volt, 'volt'),
    (_ir1, 'ir1'),
    (_ir10, 'ir10'),
    (_irTemp, 'irTemp'),
    (_r1, 'r1'),
    (_r2, 'r2'),
    (_r3, 'r3'),
    (_rTemp, 'rTemp'),
    (_rRef, 'rRef'),
    (_rRefTemp, 'rRefTemp'),
    (_v1, 'v1'),
    (_v2, 'v2'),
    (_v3, 'v3'),
    (_a1, 'a1'),
    (_a2, 'a2'),
    (_a3, 'a3'),
  ];

  // 화면을 나갔다 와도 입력이 남는다(8차).
  @override
  String? get elecDraftKey => 'elec_draft_motor_check_v1';

  @override
  Map<String, Object?> historySnapshot() => {
    for (final (c, k) in _texts) k: c.text,
    'kind': _kind.name,
    'corr': _corr.name,
    'classA': _classA,
  };

  /// 빠졌거나 모양이 다른 값은 지금 값을 그대로 둔다.
  @override
  void applyHistorySnapshot(Map<String, dynamic> m) {
    for (final (c, k) in _texts) {
      if (m[k] is String) c.text = m[k] as String;
    }
    _kind = WindingKind.values.asNameMap()[m['kind']] ?? _kind;
    _corr = IrCorrection.values.asNameMap()[m['corr']] ?? _corr;
    if (m['classA'] is bool) _classA = m['classA'] as bool;
  }

  void _set(VoidCallback f) => setState(f);

  /// 세 값의 불평형을 식 → 대입 → 결과로 적는다.
  String _unbText(List<double> v, String unit, int d) {
    final avg = (v[0] + v[1] + v[2]) / 3;
    final dev = v.map((x) => (x - avg).abs()).reduce((a, b) => a > b ? a : b);
    final pct = dev / avg * 100;
    return '불평형 = 평균에서 가장 먼 값의 차 ÷ 평균 × 100. 평균 = (${fmt(v[0], d)} + ${fmt(v[1], d)} + ${fmt(v[2], d)}) ÷ 3 = ${fmt(avg, d + 1)} $unit, 차 ${fmt(dev, d + 1)} ÷ ${fmt(avg, d + 1)} × 100 = ${fmt(pct, 2)} %';
  }

  String _kindLabel(WindingKind k) => switch (k) {
    WindingKind.random => '저압 랜덤권선',
    WindingKind.form => '고압 폼권선(1970년 이후)',
    WindingKind.old => '옛 권선(1970년 이전)',
  };

  Widget _three(String title, String guide, List<(String, String, TextEditingController)> f) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          elecSectionTitle(title),
          if (guide.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(guide, style: TextStyle(fontSize: 13, color: fc.textSub)),
            ),
          for (final (k, l, c) in f) elecField(k, l, c, ''),
        ],
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final children = <Widget>[
      calcResult(solve: true, 
        key: const Key('mc_steps'),
        big: '점검 순서',
        caption: '전동기가 탔는지 볼 때',
        lines: const [
          '① 전원 차단·검전·잠금. 기동반에서 전동기 케이블을 떼고, 케이블·스위치·콘덴서·CT를 분리해 전동기만 측정합니다.',
          '② 외관: 권선 절연이 부풀거나 갈라지거나 벗겨지거나 변색됐는지, 오염·쐐기·묶음 풀림을 봅니다(EASA AR100).',
          '③ 절연저항(메거): 세 상을 묶어 권선-접지 1분값을 측정합니다(최소값 판정용). 6단자면 한 상씩 측정하고 나머지 두 상을 접지하면 상간 절연까지 봅니다.',
          '④ 권선 저항: U-V, V-W, W-U 단자 사이를 측정합니다. 1 Ω 미만은 4선식 저항계를 씁니다.',
          '⑤ 아래 칸에 값을 넣고 판정합니다. 온도도 함께 적습니다.',
          '⑥ 다시 돌릴 때는 선간전압 불평형을 보고, 운전 중 세 상 전류를 측정합니다.',
        ],
      ),
      elecSectionTitle('전동기'),
      elecField(
        'mc_volt',
        '정격 전압 (V)',
        _volt,
        '명판의 선간전압입니다. 절연저항계 시험전압을 정합니다.',
      ),
      elecChipGroup(
        '권선 종류',
        '저압 전동기는 대부분 랜덤권선, 고압(3.3·6.6 kV)은 대부분 폼권선입니다.',
        [
          for (final k in WindingKind.values)
            calcChip(
              'mc_w_${k.name}',
              _kindLabel(k),
              _kind == k,
              () => _set(() => _kind = k),
            ),
        ],
      ),
      elecSectionTitle('절연저항'),
      elecField('mc_ir1', '1분값 (MΩ)', _ir1, '권선 전체-접지, 1분 측정값입니다.'),
      elecField(
        'mc_irtemp',
        '권선 온도 (℃)',
        _irTemp,
        '측정할 때 권선 온도입니다. 정지한 지 오래면 주위 온도에 가깝습니다.',
      ),
      elecField(
        'mc_ir10',
        '10분값 (MΩ, 선택)',
        _ir10,
        '넣으면 성극지수(PI)를 계산합니다.',
      ),
      elecChipGroup(
        '온도 보정',
        'IEEE 43은 40 ℃ 기준 10 ℃마다 절반, IEC 60034-27-4는 합성수지 절연을 40 ℃ 이하에서 보정하지 않습니다.',
        [
          calcChip(
            'mc_corr_ieee',
            'IEEE 43',
            _corr == IrCorrection.ieee43,
            () => _set(() => _corr = IrCorrection.ieee43),
          ),
          calcChip(
            'mc_corr_iec',
            'IEC 합성수지',
            _corr == IrCorrection.iecResin,
            () => _set(() => _corr = IrCorrection.iecResin),
          ),
        ],
      ),
      elecChipGroup('절연 등급', 'PI 최소값이 A종 1.5, B·F·H종 2.0입니다.', [
        calcChip('mc_cls_a', 'A종', _classA, () => _set(() => _classA = true)),
        calcChip('mc_cls_b', 'B·F·H종', !_classA, () => _set(() => _classA = false)),
      ]),
    ];

    final ratedV = readNum(_volt);
    final testV = ratedV == null ? null : megTestVoltage(ratedV);
    final ir1 = readNum(_ir1), ir10 = readNum(_ir10), irT = readNum(_irTemp);
    final minIr = minIrMOhm(_kind, ratedKv: (ratedV ?? 0) / 1000);
    final irSummary = <String>[];
    var bad = false;

    if (ir1 == null || ir1 <= 0 || irT == null) {
      children.add(
        calcResult(solve: true, 
          key: const Key('mc_ir_result'),
          big: '— MΩ',
          caption: '1분값과 권선 온도를 넣으면 판정합니다',
          lines: [
            if (testV != null)
              '시험전압: DC ${fmt(testV.$1, 0)}${testV.$2 == testV.$1 ? "" : "~${fmt(testV.$2, 0)}"} V (IEEE 43 표 1)',
          ],
        ),
      );
    } else {
      final r40 = irAt40(measuredMOhm: ir1, tempC: irT, method: _corr);
      final ok = r40 >= minIr;
      bad = bad || !ok;
      final pi = ir10 == null ? null : polarizationIndex(ir1, ir10);
      final piMin = minPi(classA: _classA);
      // 큰 글씨·요약·풀이가 같은 자릿수(소수 둘째)여야 1.3과 1.25처럼 달라 보이지 않는다.
      irSummary.add('IR ${fmt(r40, 2)} MΩ ${ok ? "합격" : "불합격"}');
      children.add(
        calcResult(solve: true, 
          key: const Key('mc_ir_result'),
          big: '${fmt(r40, 2)} MΩ (40 ℃)',
          warn: !ok,
          caption: '절연저항 40 ℃ 환산 1분값',
          lines: [
            if (testV != null)
              '시험전압: DC ${fmt(testV.$1, 0)}${testV.$2 == testV.$1 ? "" : "~${fmt(testV.$2, 0)}"} V (IEEE 43 표 1)',
            if (ir1 > 5000)
              '1분값이 5000 MΩ을 넘어 온도 보정을 하지 않습니다.'
            else if (_corr == IrCorrection.ieee43)
              '40 ℃ 환산: R40 = R × 0.5^((40 − T) ÷ 10) = ${fmt(ir1, 1)} × 0.5^((40 − ${fmt(irT)}) ÷ 10) = ${fmt(r40, 2)} MΩ'
            else if (irT <= 40)
              '합성수지 절연은 40 ℃ 이하에서 보정하지 않습니다: ${fmt(r40, 2)} MΩ'
            else
              '40 ℃ 환산: R40 = R × 2^((T − 40) ÷ 17) = ${fmt(ir1, 1)} × 2^((${fmt(irT)} − 40) ÷ 17) = ${fmt(r40, 2)} MΩ',
            _kind == WindingKind.old
                ? '최소 = 정격 kV + 1 = ${fmt((ratedV ?? 0) / 1000, 2)} + 1 = ${fmt(minIr, 1)} MΩ (IEEE 43 표 3, ${_kindLabel(_kind)})'
                : '최소 ${fmt(minIr, 1)} MΩ (IEEE 43 표 3, ${_kindLabel(_kind)})',
            ok
                ? '${fmt(r40, 2)} ≥ ${fmt(minIr, 1)} MΩ: 합격'
                : '${fmt(r40, 2)} < ${fmt(minIr, 1)} MΩ: 불합격. 습기·오염이면 청소·건조 후 다시 측정하고, 심한 열화면 운전과 내전압 시험을 하지 마십시오(IEEE 43 11.2).',
            if (ir10 != null && pi == null && ir1 > 5000)
              '1분값이 5000 MΩ을 넘으면 PI는 평가하지 않습니다.',
            if (pi != null)
              'PI = 10분값 ${fmt(ir10!, 1)} ÷ 1분값 ${fmt(ir1, 1)} = ${fmt(pi, 2)} (최소 ${fmt(piMin, 1)}): ${pi >= piMin ? "합격" : "불합격"}',
            if (pi != null && _kind == WindingKind.random)
              '랜덤권선은 PI가 맞지 않을 수 있어 60초/30초 비 1.5 이상을 쓰기도 합니다(EASA AR100).',
            'IEEE 43: 10 MVA 이하 기기는 PI나 절연저항 중 하나만 넘으면 됩니다.',
            '제조사 기준이 서로 다릅니다: 효성 5 미만 불합격·100 초과 양호(40 ℃), WEG 5 이하 위험(40 ℃), ABB 1 MΩ(25 ℃). 쓰는 전동기 설명서를 우선하십시오.',
            '흔히 쓰는 "1 MΩ 이상"은 전로 기준(전기설비기술기준 제52조)이고 권선 기준이 아닙니다.',
          ],
        ),
      );
    }

    children.addAll([
      _three('권선 저항', '단자 사이 저항(Ω)과 측정 온도를 넣습니다. 한 상이 측정 안 되면(OL) 그 상은 단선입니다.', [
        ('mc_r1', 'U-V (Ω)', _r1),
        ('mc_r2', 'V-W (Ω)', _r2),
        ('mc_r3', 'W-U (Ω)', _r3),
      ]),
      elecField('mc_rtemp', '측정 온도 (℃)', _rTemp, ''),
      elecField(
        'mc_rref',
        '기준값 (Ω, 선택)',
        _rRef,
        '시험성적서·이전 기록의 단자 간 저항입니다. 넣으면 같은 온도로 환산해 비교합니다.',
      ),
      elecField('mc_rreftemp', '기준값 온도 (℃)', _rRefTemp, ''),
    ]);
    final r1 = readNum(_r1), r2 = readNum(_r2), r3 = readNum(_r3);
    final rT = readNum(_rTemp), rRef = readNum(_rRef), rRefT = readNum(_rRefTemp);
    final unb = r1 == null || r2 == null || r3 == null
        ? null
        : unbalancePct(r1, r2, r3);
    if (unb == null) {
      children.add(
        calcResult(solve: true, 
          key: const Key('mc_r_result'),
          big: '— %',
          caption: '세 값을 넣으면 불평형을 계산합니다',
          lines: const [],
        ),
      );
    } else {
      final avg = (r1! + r2! + r3!) / 3;
      final limit = windingUnbalanceLimit(_kind);
      final ok = unb <= limit;
      bad = bad || !ok;
      irSummary.add('권선 불평형 ${fmt(unb, 2)} %');
      final atRef = rRef != null && rT != null && rRefT != null
          ? windingResistanceAt(ohms: avg, fromC: rT, toC: rRefT)
          : null;
      children.add(
        calcResult(solve: true, 
          key: const Key('mc_r_result'),
          big: '불평형 ${fmt(unb, 2)} %',
          warn: !ok,
          caption: '권선 저항 불평형 (허용 ${fmt(limit, 0)} %, EASA AR100)',
          lines: [
            '평균 = (${fmt(r1, 4)} + ${fmt(r2, 4)} + ${fmt(r3, 4)}) ÷ 3 = ${fmt(avg, 4)} Ω',
            '불평형 = 평균에서 가장 먼 값의 차 ${fmt(unb * avg / 100, 4)} ÷ 평균 × 100 = ${fmt(unb, 2)} %',
            ok
                ? '허용 ${fmt(limit, 0)} % 이내: 합격'
                : '허용 ${fmt(limit, 0)} %를 초과합니다: 단자·러그 조임(고저항 접속)을 먼저 확인하고, 그래도 크면 권선 이상을 의심합니다.',
            if (atRef != null)
              '측정 평균을 ${fmt(rRefT!)} ℃로 환산: ${fmt(avg, 4)} × (${fmt(rRefT)} + 234.5) ÷ (${fmt(rT!)} + 234.5) = ${fmt(atRef, 4)} Ω, 기준값과 차이 ${fmt((atRef - rRef!) / rRef * 100, 1)} % (기준 대비 허용치는 출처가 없어 참고만 합니다)',
            '불평형 허용치의 주목적은 고저항 접속 확인입니다. 층간 단락은 수리점의 서지 시험으로 확인합니다(EASA AR100).',
            'Y 결선이면 단자 간 저항 = 상 저항 × 2, Δ 결선이면 × 2/3입니다. 출력별 정상 저항값 표는 없어 기준값(시험성적서·이전 기록)과 비교합니다.',
          ],
        ),
      );
    }

    children.addAll([
      _three('선간전압 (선택)', '운전 전 단자에서 측정한 선간전압(V)입니다.', [
        ('mc_v1', 'U-V (V)', _v1),
        ('mc_v2', 'V-W (V)', _v2),
        ('mc_v3', 'W-U (V)', _v3),
      ]),
      _three('운전 전류 (선택)', '운전 중 세 상 전류(A)입니다.', [
        ('mc_a1', 'U상 (A)', _a1),
        ('mc_a2', 'V상 (A)', _a2),
        ('mc_a3', 'W상 (A)', _a3),
      ]),
    ]);
    final vu = [_v1, _v2, _v3].map(readNum).toList();
    final au = [_a1, _a2, _a3].map(readNum).toList();
    final vUnb = vu.contains(null) ? null : unbalancePct(vu[0]!, vu[1]!, vu[2]!);
    final aUnb = au.contains(null) ? null : unbalancePct(au[0]!, au[1]!, au[2]!);
    if (vUnb != null || aUnb != null) {
      final der = vUnb == null ? null : nemaDerating(vUnb);
      if (vUnb != null && vUnb > 1) bad = true;
      children.add(
        calcResult(solve: true, 
          key: const Key('mc_unb_result'),
          big: vUnb != null ? '전압 불평형 ${fmt(vUnb, 2)} %' : '전류 불평형 ${fmt(aUnb!, 1)} %',
          warn: vUnb != null && vUnb > 1,
          caption: '평균에서 가장 먼 값의 차 ÷ 평균 × 100 (NEMA MG1)',
          lines: [
            if (vUnb != null) ...[
              vUnb <= 1
                  ? '1 % 이하: 전동기 단자 권장 범위입니다.'
                  : (der == null
                        ? '5 %를 초과합니다: 운전을 권장하지 않습니다(NEMA MG1).'
                        : '1 %를 초과합니다: 출력 저감 계수 약 ${fmt(der, 2)}(NEMA 그림 기준, 4·5 % 값은 원문 미확인).'),
              _unbText([vu[0]!, vu[1]!, vu[2]!], 'V', 1),
              '온도상승 증가 = 2 × 불평형² = 2 × ${fmt(vUnb, 2)}² = ${fmt(unbalanceHeatingPct(vUnb), 1)} %입니다. 10 ℃ 오를 때마다 절연 수명이 절반입니다(DOE).',
            ],
            if (aUnb != null) ...[
              '전류 불평형 ${fmt(aUnb, 1)} %. 전류 불평형은 전압 불평형의 6~10배가 될 수 있습니다(DOE).',
              _unbText([au[0]!, au[1]!, au[2]!], 'A', 1),
              '원인 가리기: 세 상 리드를 한 칸씩 돌려 꽂아, 큰 전류가 전원선을 따라가면 전원 쪽, 전동기선을 따라가면 전동기 쪽 원인입니다(Franklin Electric 설명서).',
              '일반 전동기의 전류 불평형 판정값은 원문을 확인하지 못했습니다(수중 전동기 설명서는 만부하 5 % 이하).',
            ],
          ],
        ),
      );
    }

    children.addAll([
      calcResult(solve: true, 
        key: const Key('mc_causes'),
        big: '권선 모양으로 보는 원인',
        caption: 'EASA 고장 분류(수리점 자료)',
        lines: const [
          '한 상만 열화: 전압 불평형(불평형 부하, 단자 접속 불량, 접점 고저항)',
          '세 상 모두 고르게 열화: 과부하, 정격을 넘는 저전압·과전압',
          '세 상 모두 심한 열화: 회전자 구속, 너무 잦은 기동·역전',
          '단상 운전 소손: 퓨즈 용단, 접촉기 한 상 개방, 전원선 단선, 접속 불량',
          '상간·층간·코일 단락, 슬롯 지락: 오염, 마모, 진동, 서지',
          '서지 손상: 개폐 서지, 낙뢰, 콘덴서 방전, 인버터 등 반도체 전력장치',
          '습기: 절연저항·PI가 낮습니다. 오염·습기 때문이면 청소·건조로 회복되기도 합니다. 해수에 잠긴 권선은 보통 재권선합니다.',
        ],
      ),
      calcResult(solve: true, 
        key: const Key('mc_wiring'),
        big: '결선·회전 방향',
        caption: '단자 표기와 Y-Δ 결선',
        lines: const [
          '단자 표기: U1·V1·W1·U2·V2·W2 = (옛 표기) U·V·W·X·Y·Z = (NEMA) T1~T6. X = U2, Y = V2, Z = W2입니다.',
          'L1·L2·L3을 U·V·W에 물리면 축 쪽(부하 쪽)에서 볼 때 시계 방향으로 돕니다. 아무 두 상이나 바꾸면 반대로 돕니다. 명판 화살표가 우선입니다.',
          'Y-Δ 기동은 Δ 정격전압이 공급전압과 같아야 하고, 단자 연결편은 모두 뗍니다.',
          'Y-Δ 유리한 결선: L1 → U1·V2, L2 → V1·W2, L3 → W1·U2. 전환 순간 돌입전류가 작습니다(Siemens).',
          'Y-Δ 불리한 결선: L1 → U1·W2, L2 → V1·U2, L3 → W1·V2. 같은 방향으로 돌지만 전환 순간 돌입이 커 차단기 트립·접촉기 용착이 생길 수 있습니다.',
          'Y-Δ에서 Y 접촉기는 정격의 0.33배, 주·Δ 접촉기와 과부하계전기는 0.58배로 고릅니다.',
        ],
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: const Key('mc_open_circuit'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const CircuitReadingPage()),
          ),
          icon: const Icon(Icons.account_tree_outlined),
          label: const Text('결선도·기동 회로 그림으로 보기'),
        ),
      ),
      const SizedBox(height: 12),
      elecBasis('mc_basis', const [
        '절연저항 시험전압(IEEE 43 표 1), 최소값 5·100 MΩ·kV+1(표 3), PI 1.5·2.0(표 2), 40 ℃ 보정(6.3.3)은 IEEE 43-2000 원문입니다. 2013판은 EASA AR100-2025가 같은 값을 옮기고 있어 같다고 봅니다.',
        'IEC 60034-27-4:2018 표 1(합성수지 40 ℃ 이하 보정 없음, 17 K마다 절반)은 IEC 미리보기 원문입니다.',
        '권선 저항 불평형 2 %(랜덤권선)·1 %(폼권선)는 ANSI/EASA AR100-2025 4.3.1, 온도 환산 234.5는 IEEE 112 5.2.1입니다.',
        '전압 불평형 1 %와 온도상승 식은 미국 에너지부(DOE) 자료가 옮긴 NEMA MG1입니다. 저감계수 2 %·3 %는 EPRI 보고서, 4 %·5 %는 검색 요약입니다.',
        'KEC에는 전동기 절연저항 판정값이 없습니다(원문 확인). 회전기 절연내력은 접지 탭 "절연저항·내력"에 있습니다.',
        '탄 냄새 기준, 출력별 정상 권선 저항값, 일반 전동기 전류 불평형 판정값은 신뢰할 출처를 찾지 못해 넣지 않았습니다.',
      ]),
    ]);

    final summary = irSummary.isEmpty
        ? null
        : '${bad ? "소손·열화 의심" : "이상 없음"} · ${irSummary.join(" · ")}';
    return elecPage(children, sumKey: 'mc_sum', summary: summary, warn: bad);
  }
}
