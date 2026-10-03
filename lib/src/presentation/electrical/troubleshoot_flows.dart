// 고장 진단 흐름(10-03): 증상 → 확인 질문 → 측정값 입력 → 판정 → 원인·조치로 이어지는 단계형 진단.
// 판정에 쓰는 기준은 앱 안에서 이미 근거를 확인한 것(저압 절연저항 기술기준 제52조, 전동기 보호 설정,
// 전동기 점검 불평형, TN 차단 조건)만 쓴다. 증상표를 새로 지어내지 않고, 근거 없는 숫자 판정은 넣지 않는다.
// 엔진은 troubleshoot_page.dart가 그린다.
library;

import 'elec_calc.dart';
import 'ground_calc.dart';
import 'motor_check.dart';
import 'motor_protect.dart';
import 'protection_calc.dart';
import 'troubleshoot_flows_general.dart';

/// 입력 칸 하나. [choices]가 있으면 고르는 칸이다.
class WizField {
  const WizField(
    this.key,
    this.label, {
    this.unit = '',
    this.hint = '',
    this.optional = false,
    this.choices,
    this.initial,
  });
  final String key;
  final String label;
  final String unit;
  final String hint;
  final bool optional;

  /// (값, 이름) 목록. 고른 값은 판정에서 sel[key]로 읽는다.
  final List<(String, String)>? choices;
  final String? initial;
}

/// 판정 결과: 과정을 보이는 줄들과 다음 단계.
class WizJudge {
  const WizJudge(this.lines, {this.warn = false, this.next});
  final List<String> lines;
  final bool warn;

  /// 다음 단계 id. null이면 이 단계에서 끝.
  final String? next;
}

sealed class WizStep {
  const WizStep(this.id, this.title);
  final String id;
  final String title;
}

/// 고르는 질문.
class WizChoice extends WizStep {
  const WizChoice(super.id, super.title, this.options, {this.help});
  final String? help;

  /// (이름, 다음 단계 id)
  final List<(String, String)> options;
}

/// 측정값을 넣어 판정하는 단계.
class WizMeasure extends WizStep {
  const WizMeasure(
    super.id,
    super.title,
    this.fields,
    this.judge, {
    this.help,
  });
  final String? help;
  final List<WizField> fields;
  final WizJudge Function(Map<String, double?> v, Map<String, String> sel)
  judge;
}

/// 결론: 원인 후보와 조치, 이어 볼 계산기.
class WizEnd extends WizStep {
  const WizEnd(
    super.id,
    super.title, {
    required this.causes,
    required this.actions,
    this.links = const [],
    this.note,
  });
  final List<String> causes;
  final List<String> actions;

  /// (이름, 전기 설비 계산 탭 번호)
  final List<(String, int)> links;
  final String? note;
}

/// 진단 흐름 하나.
class WizFlow {
  const WizFlow(this.id, this.title, this.subtitle, this.start, this.steps);
  final String id;
  final String title;
  final String subtitle;
  final String start;
  final Map<String, WizStep> steps;
}

/// 소수 [d]자리까지, 뒤의 0은 뗀다.
String _f(double v, [int d = 1]) {
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

const int _tabShort = 5, _tabGround = 11, _tabMotorProt = 12, _tabMotorCheck = 13;
const int _tabCable = 3, _tabVd = 4;

// ── 1. 차단기가 트립한다 ──────────────────────────────────────────────

WizFlow _tripFlow() => WizFlow(
  'trip',
  '차단기가 트립한다',
  '언제 트립하는지로 단락·과부하·누설·기동 중 어느 쪽인지 가려 갑니다',
  't0',
  {
    't0': const WizChoice('t0', '언제 트립합니까?', [
      ('투입하자마자, 또는 재투입해도 바로 트립', 't_short'),
      ('전동기를 기동하는 순간', 't_start'),
      ('운전하다가 수 분~수 시간 뒤', 't_over'),
      ('누전차단기(ELB)만 트립', 't_elb'),
    ], help: '차단기가 어느 보호 기능(순시·과부하·누전)으로 떨어졌는지 가리는 첫 질문입니다. 차단기 표시창·트립 표시가 있으면 함께 보십시오.'),
    't_short': WizMeasure(
      't_short',
      '절연저항을 측정합니다',
      const [
        WizField(
          'lv',
          '전로 구분',
          choices: [
            ('upTo500', '500 V 이하(380/220 V 회로)'),
            ('over500', '500 V 초과'),
            ('selv', 'SELV·PELV'),
          ],
          initial: 'upTo500',
        ),
        WizField('ir', '측정한 절연저항', unit: 'MΩ', hint: '차단기를 내리고 부하를 뗀 상태에서 전선 상호 간과 전로-대지 사이 중 작은 값'),
      ],
      (v, sel) {
        final c = switch (sel['lv']) {
          'over500' => LvCircuit.over500,
          'selv' => LvCircuit.selvPelv,
          _ => LvCircuit.upTo500,
        };
        final spec = lvInsulation(c);
        final ir = v['ir'];
        if (ir == null) return const WizJudge(['절연저항 값을 넣으십시오.']);
        final ok = ir >= spec.minMOhm;
        return WizJudge(
          [
            '시험전압 DC ${_f(spec.testV, 0)} V, 최소 ${_f(spec.minMOhm)} MΩ (기술기준 제52조)',
            '측정 ${_f(ir, 2)} MΩ ${ok ? "≥" : "<"} ${_f(spec.minMOhm)} MΩ: ${ok ? "합격" : "불합격"}',
          ],
          warn: !ok,
          next: ok ? 'e_short_other' : 'e_short_ins',
        );
      },
      help: '투입 즉시 떨어지면 단락이나 지락(절연 불량)이 대부분입니다. 먼저 절연저항으로 가립니다.',
    ),
    'e_short_ins': const WizEnd(
      'e_short_ins',
      '절연 불량 구간이 있습니다',
      causes: [
        '전선·케이블 절연 손상, 습기, 접속부 단락',
        '전동기·기기 내부 절연 불량(전동기면 권선 기준은 전동기 점검 탭)',
      ],
      actions: [
        '부하를 하나씩 분리해 가며 절연저항을 다시 측정해 불량 구간을 좁힙니다(이분 탐색).',
        '전동기가 의심되면 케이블을 떼고 전동기만 측정합니다. 저압 권선은 40 ℃ 환산 5 MΩ 이상이어야 합니다.',
        '원인을 제거하기 전에 재투입하지 않습니다.',
      ],
      links: [('전동기 점검 탭', _tabMotorCheck)],
    ),
    'e_short_other': const WizEnd(
      'e_short_other',
      '절연은 정상입니다. 그래도 즉시 트립한다면',
      causes: [
        '부하 쪽 단락이 아니라 큰 돌입전류(변압기·콘덴서·전동기 동시 기동)에 순시 설정이 낮은 경우',
        '차단기 자체 불량·접점 열화',
        '시험 조건 차이: 부하를 연결하고 투입하면 절연저항 측정 때 안 보이던 단락이 나타남',
      ],
      actions: [
        '부하를 연결한 상태에서 같은 절연저항을 다시 측정합니다.',
        '단락전류 계산으로 설치 지점의 예상 단락전류와 차단기 차단용량을 비교합니다.',
        '조정형 차단기는 순시 설정값이 설계와 같은지 확인합니다.',
      ],
      links: [('단락 전류 탭', _tabShort)],
    ),
    't_start': WizMeasure(
      't_start',
      '전동기 정격과 차단기를 비교합니다',
      const [
        WizField('fla', '전동기 정격전류', unit: 'A', hint: '명판 값'),
        WizField('in', '차단기 정격 In', unit: 'A'),
      ],
      (v, sel) {
        final fla = v['fla'], inn = v['in'];
        if (fla == null || fla <= 0 || inn == null || inn <= 0) {
          return const WizJudge(['정격전류와 차단기 정격을 넣으십시오.']);
        }
        final low = breakerFor(fla * 1.25);
        final r = motorBreakerRange(load: fla, low: low);
        final lines = <String>[
          '하한: 정격전류 × 1.25 = ${_f(fla * 1.25)} A 이상 표준 정격 → ${low ?? "없음"} A',
          '상한: min(정격 × 2.5 = ${_f(r.necA)}, 정격 × 3 = ${_f(r.ratedX3A)}) = ${_f(r.highA)} A 이하 표준 정격 → ${r.high ?? "없음"} A',
          '전동기 회로 차단기 범위: ${low ?? "-"} ~ ${r.high ?? "-"} A (현재 ${_f(inn)} A)',
        ];
        if (low != null && inn < low) {
          return WizJudge(lines, warn: true, next: 'e_start_small');
        }
        return WizJudge(lines, next: 'e_start_ok');
      },
      help: '기동 중 전류는 정격의 수 배까지 흐릅니다. 차단기가 범위 안에 있는지 먼저 봅니다.',
    ),
    'e_start_small': const WizEnd(
      'e_start_small',
      '차단기 정격이 정격전류에 비해 작습니다',
      causes: ['차단기 정격이 부하(정격 × 1.25)보다 작아 정상 운전·기동 전류에도 떨어짐'],
      actions: [
        '설계 도서의 차단기 정격과 현장 설치품이 같은지 확인합니다.',
        '범위 안의 표준 정격으로 교체하고, 전선 허용전류가 그 차단기를 받치는지 확인합니다(IB ≤ In ≤ IZ).',
      ],
      links: [('전선 굵기 탭', _tabCable)],
    ),
    'e_start_ok': const WizEnd(
      'e_start_ok',
      '차단기 정격은 범위 안입니다. 기동 때만 트립한다면',
      causes: [
        '직입 기동전류(정격의 수 배)에 비해 순시 설정이 낮음',
        '기동 중 전압강하가 커서 기동 시간이 길어짐(전선 굵기·길이)',
        '결상·한 상 접촉 불량으로 기동 전류가 한 상에 몰림',
        '모터 기계 부하가 무거워 기동이 늘어짐(펌프 밸브 개도, 커플링 걸림)',
      ],
      actions: [
        '기동 시간과 과부하계전기 트립 클래스를 비교합니다(전동기 보호 탭).',
        '기동 중 전압강하를 계산합니다(전압강하 탭, 전동기 기동 시 켜기).',
        '세 상 전류와 전압 불평형을 측정합니다(전동기 점검 탭).',
      ],
      links: [
        ('전동기 보호 탭', _tabMotorProt),
        ('전압강하 탭', _tabVd),
        ('전동기 점검 탭', _tabMotorCheck),
      ],
    ),
    't_over': WizMeasure(
      't_over',
      '실측 전류와 차단기 정격을 비교합니다',
      const [
        WizField('i', '실측 부하 전류', unit: 'A', hint: '운전 중 클램프 미터로 측정'),
        WizField('in', '차단기 정격 In', unit: 'A'),
        WizField('a', 'U상 전류', unit: 'A', optional: true),
        WizField('b', 'V상 전류', unit: 'A', optional: true),
        WizField('c', 'W상 전류', unit: 'A', optional: true),
      ],
      (v, sel) {
        final i = v['i'], inn = v['in'];
        if (i == null || inn == null || inn <= 0) {
          return const WizJudge(['실측 전류와 차단기 정격을 넣으십시오.']);
        }
        final lines = <String>[
          '실측 ${_f(i)} A, 차단기 ${_f(inn)} A: 부하율 ${_f(i / inn * 100, 0)} %',
        ];
        final u = (v['a'] != null && v['b'] != null && v['c'] != null)
            ? unbalancePct(v['a']!, v['b']!, v['c']!)
            : null;
        if (u != null) {
          lines.add('전류 불평형 ${_f(u, 1)} % (평균에서 가장 먼 값의 차 ÷ 평균).');
        }
        final over = i > inn;
        lines.add(over ? '실측 전류가 차단기 정격을 넘습니다: 과부하' : '실측 전류는 정격 이내입니다.');
        return WizJudge(lines, warn: over, next: over ? 'e_over' : 'e_over_ok');
      },
      help: '시간이 지나서 떨어지면 과부하나 접속부·주위 온도에 의한 열 트립이 흔합니다.',
    ),
    'e_over': const WizEnd(
      'e_over',
      '과부하입니다',
      causes: [
        '부하가 설계보다 커짐(부하 추가, 기계 부하 증가)',
        '한 상 전류만 큰 경우: 전압 불평형·결상·접속부 불량',
        '전동기 베어링·기계 마찰 증가로 전류 상승',
      ],
      actions: [
        '부하별 전류를 측정해 어느 부하가 커졌는지 찾습니다.',
        '부하가 정상이라면 차단기·전선 정격을 부하에 맞게 다시 선정합니다(IB ≤ In ≤ IZ).',
        '전동기라면 세 상 전류를 측정해 불평형을 확인합니다.',
      ],
      links: [('전선 굵기 탭', _tabCable), ('전동기 점검 탭', _tabMotorCheck)],
    ),
    'e_over_ok': const WizEnd(
      'e_over_ok',
      '전류는 정격 이내인데 트립합니다',
      causes: [
        '차단기 단자 접속 불량으로 단자가 과열되어 열동 소자가 일찍 동작',
        '주위 온도가 높거나 밀폐 분전반 내부 열 축적(차단기는 온도에 영향을 받음)',
        '다른 차단기와 나란히 설치되어 서로 열을 받음',
        '차단기 열화(반복 트립 이력)',
      ],
      actions: [
        '트립 직후 차단기 단자와 전선 접속부 온도를 열화상·접촉식으로 측정합니다.',
        '단자 조임 토크를 제조사 값으로 재확인합니다.',
        '분전반 내부 온도와 환기를 확인합니다.',
      ],
    ),
    't_elb': WizMeasure(
      't_elb',
      '누설전류와 절연저항을 측정합니다',
      const [
        WizField('leak', '누설전류', unit: 'mA', hint: '누설전류 클램프로 부하 쪽 선 전체를 함께 물려 측정'),
        WizField('idn', '누전차단기 감도전류 IΔn', unit: 'mA', initial: '30'),
        WizField('ir', '절연저항', unit: 'MΩ', optional: true, hint: '500 V 이하 회로 기준'),
      ],
      (v, sel) {
        final leak = v['leak'], idn = v['idn'];
        if (leak == null || idn == null || idn <= 0) {
          return const WizJudge(['누설전류와 감도전류를 넣으십시오.']);
        }
        final lines = <String>[
          '누설전류 ${_f(leak, 1)} mA ÷ 감도전류 ${_f(idn, 0)} mA = ${_f(leak / idn * 100, 0)} %',
        ];
        var warn = false;
        if (leak >= idn) {
          lines.add('누설전류가 감도전류 이상입니다: 이 회로의 누설이 트립 원인입니다.');
          warn = true;
        } else {
          lines.add('누설전류가 감도전류에 가까울수록 습기·온도 변화·기동 때 불필요하게 떨어질 가능성이 큽니다.');
        }
        final ir = v['ir'];
        if (ir != null) {
          final spec = lvInsulation(LvCircuit.upTo500);
          final ok = ir >= spec.minMOhm;
          lines.add('절연저항 ${_f(ir, 2)} MΩ ${ok ? "≥" : "<"} ${_f(spec.minMOhm)} MΩ(제52조): ${ok ? "합격" : "불합격"}');
          warn = warn || !ok;
        }
        return WizJudge(lines, warn: warn, next: 'e_elb');
      },
      help: '누전차단기는 선 전체의 합(왕복 전류 차)이 감도전류를 넘으면 떨어집니다.',
    ),
    'e_elb': const WizEnd(
      'e_elb',
      '누설 구간을 찾아 줄이는 순서',
      causes: [
        '케이블·기기의 절연 열화나 습기',
        '인버터·노이즈 필터·SMPS 등 기기 자체의 정상 누설이 합쳐짐',
        '중성선이 다른 회로와 공유되었거나 접지에 접촉(N-PE 단락)',
      ],
      actions: [
        '부하를 하나씩 분리하며 누설전류를 다시 측정해 큰 부하를 찾습니다.',
        '절연저항이 낮은 구간은 케이블·기기를 점검합니다.',
        '중성선이 접지·다른 회로와 만나지 않는지 확인합니다.',
        'TT 계통이면 접지극 저항이 50 V ÷ IΔn 이하인지 확인합니다(접지 탭).',
      ],
      links: [('접지 탭', _tabGround)],
    ),
  },
);

// ── 2. 전동기가 안 돌거나 계속 선다 ────────────────────────────────────

WizFlow _motorFlow() => WizFlow(
  'motor',
  '전동기가 안 돌거나 계속 선다',
  '전원 → 과부하계전기 설정 → 전동기 본체 순으로 가려 갑니다',
  'm0',
  {
    'm0': const WizChoice('m0', '증상이 어떻습니까?', [
      ('전혀 안 돈다(소리도 없다)', 'm_volt'),
      ('웅 소리만 나고 안 돈다 / 돌다가 선다', 'm_volt'),
      ('과부하계전기(THR·EOCR)가 반복해서 트립한다', 'm_thr'),
      ('과열·냄새·소손이 의심된다', 'e_m_burn'),
    ]),
    'm_volt': WizMeasure(
      'm_volt',
      '기동반 입력의 선간전압을 측정합니다',
      const [
        WizField('v1', 'L1-L2', unit: 'V'),
        WizField('v2', 'L2-L3', unit: 'V'),
        WizField('v3', 'L3-L1', unit: 'V'),
        WizField('rated', '전동기 정격전압', unit: 'V', initial: '380'),
      ],
      (v, sel) {
        final a = v['v1'], b = v['v2'], c = v['v3'], rated = v['rated'];
        if (a == null || b == null || c == null) {
          return const WizJudge(['세 선간전압을 모두 넣으십시오.']);
        }
        final low = [a, b, c].any((x) => x < 50);
        if (low) {
          return const WizJudge(
            ['한 선 이상의 전압이 거의 0입니다: 결상 또는 전원 없음'],
            warn: true,
            next: 'e_m_phase',
          );
        }
        final u = unbalancePct(a, b, c) ?? 0;
        final lines = <String>[
          '전압 불평형 = 평균에서 가장 먼 값의 차 ÷ 평균 = ${_f(u, 2)} %',
        ];
        var warn = false;
        if (u > 1) {
          warn = true;
          final der = nemaDerating(u);
          lines.add(
            der == null
                ? '5 %를 넘어 운전을 권장하지 않습니다(NEMA MG1).'
                : '1 %를 넘습니다. 출력 저감 계수 약 ${_f(der, 2)}(NEMA MG1, 4·5 %는 원문 미확인).',
          );
        } else {
          lines.add('1 % 이하: 전동기 단자 권장 범위입니다.');
        }
        if (rated != null && rated > 0) {
          final avg = (a + b + c) / 3;
          lines.add('평균 ${_f(avg, 0)} V, 정격 ${_f(rated, 0)} V 대비 ${_f((avg - rated) / rated * 100, 1)} %');
        }
        return WizJudge(lines, warn: warn, next: warn ? 'e_m_unb' : 'e_m_body');
      },
      help: '전원이 안 들어오거나 한 상이 빠지면 전동기가 아예 안 돌거나 웅 소리만 납니다. 전동기 단자가 아니라 기동반 입력에서 먼저 측정합니다.',
    ),
    'e_m_phase': const WizEnd(
      'e_m_phase',
      '결상 또는 전원 없음입니다',
      causes: [
        '한 상의 퓨즈 용단·차단기 한 극 개방',
        '접촉기 주접점 한 극 불량',
        '전원선 단선, 단자 접속 불량',
      ],
      actions: [
        '전원 쪽부터 차례로 올라가며 전압이 사라지는 지점을 찾습니다(차단기 → 퓨즈 → 접촉기 → 과부하계전기 → 전동기).',
        '원인 제거 전에 재기동하지 않습니다. 결상 상태에서 기동하면 전동기가 소손됩니다.',
        '결상 상태로 운전했다면 권선 상태를 점검합니다.',
      ],
      links: [('전동기 점검 탭', _tabMotorCheck)],
    ),
    'e_m_unb': const WizEnd(
      'e_m_unb',
      '전압 불평형이 큽니다',
      causes: [
        '단상 부하가 한 상에 몰림',
        '기동반·차단기·접촉기 접속부 고저항',
        '공급 측(변압기·간선) 불평형',
      ],
      actions: [
        '선간전압을 변압기 2차 → 분전반 → 기동반 → 전동기 단자까지 단계별로 측정해 불평형이 생기는 지점을 찾습니다.',
        '그 지점의 접속부 온도를 열화상으로 확인하고 조임을 점검합니다.',
        '해소 전에는 출력 저감 계수를 고려해 운전하거나 부하를 줄입니다.',
      ],
      links: [('전동기 점검 탭', _tabMotorCheck)],
    ),
    'e_m_body': const WizEnd(
      'e_m_body',
      '전원은 정상입니다. 전동기 본체를 점검합니다',
      causes: [
        '권선 단선·단락·지락(절연 불량)',
        '회전자 구속·베어링 고착·기계 부하 걸림',
        '기동반 제어 회로(접촉기 코일·인터록)',
      ],
      actions: [
        '케이블을 떼고 절연저항과 권선 저항을 측정합니다(전동기 점검 탭이 판정해 줍니다).',
        '커플링을 떼고 손으로 돌려 기계 고착을 확인합니다.',
        '접촉기 코일 전압과 제어 회로 접점을 확인합니다(결선도·기동 회로 화면).',
      ],
      links: [('전동기 점검 탭', _tabMotorCheck)],
    ),
    'm_thr': WizMeasure(
      'm_thr',
      '계전기 설정과 전류를 비교합니다',
      const [
        WizField('fla', '전동기 정격전류 FLA', unit: 'A'),
        WizField('set', '과부하계전기 설정값', unit: 'A'),
        WizField('run', '정상 운전 중 실측 전류', unit: 'A', optional: true),
        WizField(
          'method',
          '기동 방식',
          choices: [('direct', '직입'), ('yd_in', 'Y-Δ(계전기가 델타 안)'), ('yd_line', 'Y-Δ(라인 쪽)')],
          initial: 'direct',
        ),
      ],
      (v, sel) {
        final fla = v['fla'], set = v['set'];
        if (fla == null || fla <= 0 || set == null || set <= 0) {
          return const WizJudge(['정격전류와 설정값을 넣으십시오.']);
        }
        final m = sel['method'] ?? 'direct';
        final need = thrSetting(
          fla,
          method: m == 'direct' ? StartMethod.direct : StartMethod.starDelta,
          place: m == 'yd_line' ? RelayPlace.line : RelayPlace.insideDelta,
        );
        final max115 = necOverloadMax(fla, sf115OrTemp40: false);
        final max125 = necOverloadMax(fla, sf115OrTemp40: true);
        final lines = <String>[
          m == 'yd_in'
              ? '적정 설정 = FLA ÷ √3 = ${_f(fla)} ÷ 1.732 = ${_f(need, 2)} A'
              : '적정 설정 = 명판 정격전류 = ${_f(need, 1)} A',
          'NEC 430.32 상한: ${_f(max115, 1)} A (FLA × 115 %), 서비스팩터 1.15 이상·온도상승 40 ℃ 이하 표시면 ${_f(max125, 1)} A (× 125 %)',
          '현재 설정 ${_f(set, 1)} A',
        ];
        final run = v['run'];
        if (run != null) {
          lines.add('실측 ${_f(run, 1)} A ÷ 설정 ${_f(set, 1)} A = ${_f(run / set * 100, 0)} %');
        }
        if (set < need - 1e-9) {
          lines.add('설정이 적정값보다 낮습니다: 정상 운전 전류에도 트립합니다.');
          return WizJudge(lines, warn: true, next: 'e_thr_low');
        }
        if (run != null && run > need * 1.05) {
          lines.add('실측 전류가 정격보다 큽니다: 전동기에 실제 과부하가 걸려 있습니다.');
          return WizJudge(lines, warn: true, next: 'e_thr_real');
        }
        lines.add('설정은 적정 범위입니다.');
        return WizJudge(lines, next: 'e_thr_start');
      },
      help: '설정값이 낮게 맞춰졌거나 실제로 과부하이거나, 기동이 길어 트립하는 경우로 나뉩니다.',
    ),
    'e_thr_low': const WizEnd(
      'e_thr_low',
      '계전기 설정이 낮습니다',
      causes: ['설정 다이얼이 정격전류보다 낮게 맞춰짐', 'Y-Δ 계전기 위치에 맞지 않는 설정'],
      actions: [
        '설정을 적정값(직입은 명판 정격전류, Y-Δ 델타 안은 정격 ÷ √3)으로 맞춥니다.',
        '설정을 올려 트립을 피하지 마십시오. 상한은 NEC 430.32 기준 정격전류의 115~125 %입니다.',
      ],
      links: [('전동기 보호 탭', _tabMotorProt)],
    ),
    'e_thr_real': const WizEnd(
      'e_thr_real',
      '전동기에 실제 과부하가 걸립니다',
      causes: [
        '기계 부하 증가(펌프 밸브 과개도, 팬 댐퍼, 이물질)',
        '베어링 마모·정렬 불량으로 마찰 증가',
        '전압 저하·불평형으로 같은 부하에 전류 증가',
      ],
      actions: [
        '세 상 전류와 전압을 측정해 불평형·전압 저하를 확인합니다(전동기 점검 탭).',
        '기계 쪽(커플링·베어링·정렬)을 점검합니다. 정렬이 의심되면 축 정렬 계산을 이용합니다.',
        '설정을 올려 해결하지 않습니다. 상한(NEC 430.32 115~125 %)을 넘기면 소손 위험입니다.',
      ],
      links: [('전동기 점검 탭', _tabMotorCheck)],
    ),
    'e_thr_start': const WizEnd(
      'e_thr_start',
      '설정은 정상입니다. 기동할 때 트립한다면',
      causes: [
        '기동 시간이 트립 클래스 시간보다 길다(설정전류 7.2배에서 클래스 10A는 2~10초, 클래스 10은 4~10초, 클래스 20은 6~20초)',
        '기동 중 전압강하가 커서 기동이 늘어짐',
        '결상·한 상 접촉 불량',
      ],
      actions: [
        '기동 시간을 재서 트립 클래스와 비교합니다(전동기 보호 탭).',
        '기동 중 전압강하를 계산합니다(전압강하 탭).',
      ],
      links: [('전동기 보호 탭', _tabMotorProt), ('전압강하 탭', _tabVd)],
    ),
    'e_m_burn': const WizEnd(
      'e_m_burn',
      '전동기 본체 점검으로 이어 갑니다',
      causes: ['과부하·결상·전압 불평형·습기·서지 등 권선 열화'],
      actions: [
        '전원을 끊고 케이블을 떼어 절연저항과 권선 저항을 측정합니다.',
        '원인 파악 없이 재기동하지 않습니다.',
      ],
      links: [('전동기 점검 탭', _tabMotorCheck)],
      note: '전동기 점검 탭이 측정값을 넣으면 합격/불합격과 권선 모양으로 보는 원인까지 보여 줍니다.',
    ),
  },
);

// ── 3. 지락해도 차단되지 않는다 / 감전 보호 확인 ─────────────────────────

WizFlow _earthFlow() => WizFlow(
  'earth',
  '지락 보호가 안 되는 것 같다',
  '고장 루프 임피던스와 차단기로 자동 차단 조건을 확인합니다',
  'g0',
  {
    'g0': const WizChoice('g0', '접지 계통이 무엇입니까?', [
      ('TN (분전반 PE가 변압기 중성점 접지와 연결)', 'g_tn'),
      ('TT (설비 접지극이 따로 있음)', 'g_tt'),
    ]),
    'g_tn': WizMeasure(
      'g_tn',
      '고장 루프 임피던스를 측정해 비교합니다',
      const [
        WizField('u0', '대지전압 U₀', unit: 'V', initial: '220'),
        WizField(
          'dev',
          '보호장치',
          choices: [('b', 'B형'), ('c', 'C형'), ('d', 'D형'), ('setting', '순시 설정')],
          initial: 'c',
        ),
        WizField('in', '차단기 정격 In(순시 설정이면 설정 전류)', unit: 'A'),
        WizField('zs', '측정한 고장 루프 임피던스 Zs', unit: 'Ω'),
      ],
      (v, sel) {
        final u0 = v['u0'], inn = v['in'], zs = v['zs'];
        if (u0 == null || inn == null || zs == null) {
          return const WizJudge(['대지전압, 정격, 측정 Zs를 모두 넣으십시오.']);
        }
        final dev = switch (sel['dev']) {
          'b' => ProtDevice.b,
          'd' => ProtDevice.d,
          'setting' => ProtDevice.setting,
          _ => ProtDevice.c,
        };
        final ia = tripCurrentIa(dev, inn);
        final zmax = ia == null ? null : maxLoopImpedance(u0: u0, ia: ia);
        if (zmax == null) return const WizJudge(['값을 확인하십시오.']);
        final ok = zs <= zmax;
        return WizJudge(
          [
            'Ia = ${_f(ia!, 0)} A (순시 동작전류)',
            'Zs 최대 = U₀ ÷ Ia = ${_f(u0, 0)} ÷ ${_f(ia, 0)} = ${_f(zmax, 3)} Ω',
            '측정 ${_f(zs, 3)} Ω ${ok ? "≤" : ">"} ${_f(zmax, 3)} Ω: ${ok ? "합격" : "불합격"}',
            '규정 차단시간: ${maxDisconnectTime(sys: EarthSystem.tn, u0: u0)?.toString() ?? "-"} 초(KEC 표 211.2-1, 32 A 이하 분기회로). 측정값은 상온 값이라 운전 온도에서는 더 커집니다.',
          ],
          warn: !ok,
          next: ok ? 'e_g_ok' : 'e_g_fail',
        );
      },
      help: '지락전류가 차단기 순시 영역에 들어가야 규정 시간(분기 회로 0.4초) 안에 끊깁니다(KEC 211.2.5 조건 Zs × Ia ≤ U₀).',
    ),
    'e_g_ok': const WizEnd(
      'e_g_ok',
      '자동 차단 조건은 만족합니다',
      causes: ['측정값은 합격이지만 운전 온도·접속부 상태에 따라 여유가 줄 수 있습니다.'],
      actions: [
        '여유가 작으면(최대값의 80 % 안팎) 접속부 조임과 보호도체 연속성을 다시 확인합니다.',
        '보호도체(PE) 연속성은 저저항계로 확인합니다.',
      ],
      links: [('접지 탭', _tabGround)],
    ),
    'e_g_fail': const WizEnd(
      'e_g_fail',
      '자동 차단 조건을 만족하지 못합니다',
      causes: [
        '케이블이 길거나 가늘어 루프 저항이 큼',
        'PE 접속부 불량·보호도체 단선·부식',
        '전원 쪽 임피던스(변압기·간선)가 큼',
      ],
      actions: [
        '케이블을 굵게 하거나 짧게 합니다. 접지 탭의 TN 자동 차단에서 필요한 값을 계산합니다.',
        '차단기를 낮은 정격이나 B형으로 바꿔 순시 동작전류를 낮추는 방법을 검토합니다.',
        '누전차단기(RCD)를 추가해 보호합니다.',
        'PE 연속성과 접속부를 점검합니다.',
      ],
      links: [('접지 탭', _tabGround), ('전선 굵기 탭', _tabCable)],
    ),
    'g_tt': WizMeasure(
      'g_tt',
      '접지극 저항과 누전차단기를 비교합니다',
      const [
        WizField('ra', '측정한 접지 저항 R_A(접지극 + 보호도체)', unit: 'Ω'),
        WizField('idn', '누전차단기 감도전류 IΔn', unit: 'mA', initial: '30'),
      ],
      (v, sel) {
        final ra = v['ra'], idn = v['idn'];
        if (ra == null || idn == null || idn <= 0) {
          return const WizJudge(['접지 저항과 감도전류를 넣으십시오.']);
        }
        final max = ttMaxOhms(idn / 1000)!;
        final ok = ra <= max;
        final lines = <String>[
          'R_A 최대 = 50 V ÷ IΔn = 50 ÷ ${_f(idn / 1000, 3)} = ${_f(max, 0)} Ω',
          '측정 ${_f(ra, 1)} Ω ${ok ? "≤" : ">"} ${_f(max, 0)} Ω: ${ok ? "합격" : "불합격"}',
        ];
        if (ra > 100) {
          lines.add('노출도전부 접지극 저항은 100 Ω 이하여야 합니다(KEC 211.2.6).');
        }
        return WizJudge(lines, warn: !ok || ra > 100, next: ok && ra <= 100 ? 'e_tt_ok' : 'e_tt_fail');
      },
      help: 'TT 계통은 접지저항과 누전차단기 감도전류의 곱이 50 V 이하여야 합니다.',
    ),
    'e_tt_ok': const WizEnd(
      'e_tt_ok',
      'TT 조건은 만족합니다',
      causes: ['접지극 저항은 계절·습도로 변합니다. 한도에 바짝 붙었다면 여유를 확인하십시오.'],
      actions: ['누전차단기 시험 단추로 동작을 확인합니다.', '건기에 접지저항을 다시 측정합니다.'],
      links: [('접지 탭', _tabGround)],
    ),
    'e_tt_fail': const WizEnd(
      'e_tt_fail',
      'TT 조건을 만족하지 못합니다',
      causes: ['접지극 저항이 큼(토양 건조, 극 길이 부족)', '접지극·접지선 접속 부식'],
      actions: [
        '접지봉을 늘리거나 길게 박습니다(접지 탭 접지봉 병렬 계산).',
        '더 큰 감도전류 누전차단기를 쓰면 한도가 늘어납니다. 보호 목적과 맞는지 확인합니다.',
        '접속부를 점검하고 접지저항을 3점 전위강하법으로 다시 측정합니다.',
      ],
      links: [('접지 탭', _tabGround)],
    ),
  },
);

/// 진단 흐름 목록. 설비 종류와 상관없는 흐름을 앞에 두고 전동기 전용은 맨 뒤에 둔다.
List<WizFlow> troubleshootFlows() {
  final g = {for (final f in generalFlows()) f.id: f};
  return [
    _tripFlow(),
    g['voltage']!,
    g['heat']!,
    _earthFlow(),
    g['lighting']!,
    g['transformer']!,
    g['capacitor']!,
    _motorFlow(),
  ];
}
