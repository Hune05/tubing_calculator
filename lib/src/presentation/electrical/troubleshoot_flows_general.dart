// 고장 진단 흐름 중 설비 종류와 상관없이 쓰는 것(10-03): 전압 이상, 접속부 발열(열화상), 조명, 변압기, 역률 콘덴서.
// 판정에 쓰는 숫자는 근거 조사(2026-10-03)에서 두 곳 이상이 일치하거나 국제 규격·법령으로 확인한 것만 넣었다.
// 원문을 못 본 것은 화면 글에 "원문 못 봄"으로 적었다. 조명 불점등은 수치 기준이 없는 일반 점검 순서다.
// 엔진은 troubleshoot_page.dart, 단계 클래스는 troubleshoot_flows.dart.
library;

import 'troubleshoot_flows.dart';

/// 소수 [d]자리까지, 뒤의 0은 뗀다.
String _n(double v, [int d = 1]) {
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

const int _tabLoadSum = 2, _tabCable = 3, _tabVd = 4, _tabPf = 8;

// ── 전압이 이상하다 ───────────────────────────────────────────────────

/// 전기사업법 시행규칙 별표 3의 공급 전압 허용 범위: 공칭 → (아래, 위) V.
/// 별표 3 원문으로 확인했다. 220 V는 2025.6.13 개정(산업통상자원부령 제606호)에서 ±13 V가 ±22 V로 바뀌었다.
/// 별표 머리의 "개정 2025. 10. 1."은 부처 이름이 바뀐 것이고 값은 같다.
const Map<String, (double, double)> _kVoltRange = {
  '110': (104, 116),
  '220': (198, 242),
  '380': (342, 418),
};

WizFlow voltageFlow() => WizFlow(
  'voltage',
  '전압이 이상하다',
  '저전압·과전압: 허용 범위와 비교하고 선로·접속부·전원 쪽을 가려 갑니다',
  'v_meas',
  {
    'v_meas': WizMeasure(
      'v_meas',
      '사용하는 지점에서 전압을 잽니다',
      const [
        WizField(
          'nom',
          '공칭 전압',
          choices: [('110', '110 V'), ('220', '220 V'), ('380', '380 V')],
          initial: '220',
        ),
        WizField('v', '측정 전압', unit: 'V', hint: '부하가 걸린 상태에서 기기 단자(또는 가장 가까운 분전반)에서 잰 값. 삼상은 선간 전압'),
        WizField('vno', '무부하 전압', unit: 'V', optional: true, hint: '같은 지점에서 부하를 끈 상태의 전압. 넣으면 선로에서 얼마나 떨어지는지 보여 줍니다'),
      ],
      (v, sel) {
        final nom = sel['nom'] ?? '220';
        final r = _kVoltRange[nom]!;
        final x = v['v'];
        if (x == null) return const WizJudge(['측정 전압을 넣으십시오.']);
        final lines = <String>[
          '허용 범위 ${_n(r.$1, 0)}~${_n(r.$2, 0)} V (전기사업법 시행규칙 별표 3, 2025.6.13 개정 반영)',
        ];
        var warn = false;
        String next;
        if (x < r.$1) {
          lines.add('측정 ${_n(x)} V < ${_n(r.$1, 0)} V: 허용 범위보다 낮습니다.');
          warn = true;
          next = 'e_v_low';
        } else if (x > r.$2) {
          lines.add('측정 ${_n(x)} V > ${_n(r.$2, 0)} V: 허용 범위보다 높습니다.');
          warn = true;
          next = 'e_v_high';
        } else {
          lines.add('측정 ${_n(x)} V: 허용 범위 이내입니다.');
          next = 'e_v_ok';
        }
        final no = v['vno'];
        if (no != null && no > 0) {
          final drop = no - x;
          final pct = drop / no * 100;
          lines.add('무부하 ${_n(no)} V → 부하 중 ${_n(x)} V: 선로·접속부에서 ${_n(drop)} V(${_n(pct, 1)} %) 떨어집니다. 저압 수전 한도는 조명 3 %, 기타 5 %입니다(KEC 표 232.3-1).');
          if (pct > 5) warn = true;
        }
        return WizJudge(lines, warn: warn, next: next);
      },
      help: '전압은 부하를 걸었을 때와 껐을 때가 다르므로, 같은 지점에서 두 값을 재면 원인이 선로 쪽인지 전원 쪽인지 가려집니다.',
    ),
    'e_v_low': const WizEnd(
      'e_v_low',
      '전압이 낮습니다',
      causes: [
        '전선이 가늘거나 길어서 선로 전압강하가 큼(부하 전류가 클 때만 낮아짐)',
        '차단기·접촉기·단자 접속부 접촉 불량(부하가 걸릴 때만 낮아짐)',
        '전원 쪽 전압이 낮음(변압기 탭, 수전점 전압). 무부하에서도 낮으면 이쪽입니다',
        '큰 부하가 기동하는 순간의 일시적인 저하',
      ],
      actions: [
        '같은 지점에서 무부하 전압과 부하 중 전압을 비교합니다. 차이가 크면 선로·접속부, 무부하부터 낮으면 전원 쪽입니다.',
        '선로 쪽이면 분전반 → 차단기 → 기기 순으로 구간마다 전압을 재서 강하가 큰 구간을 찾고, 그 구간 접속부를 조입니다(열화상이 있으면 같이 봅니다).',
        '전선 굵기와 길이를 점검해 전압강하를 계산합니다.',
        '전원 쪽이면 변압기 탭 설정을 확인하고, 수전 전압이면 한전에 문의합니다.',
        '일시적인 저하(sag)는 순간 전압을 기록하는 계측기로 확인합니다. IEEE 1159는 0.1~0.9 pu를 저하로 구분합니다.',
      ],
      links: [('전압강하 탭', _tabVd)],
    ),
    'e_v_high': const WizEnd(
      'e_v_high',
      '전압이 높습니다',
      causes: [
        '전원 쪽 전압이 높음(경부하 시간대에 올라감)',
        '변압기 탭 설정이 높게 맞춰져 있음',
        '발전기를 쓰는 곳이면 AVR 설정이 높음',
        '삼상 4선·단상 3선에서 중성선 접속 불량(한쪽 전압은 높고 다른 쪽은 낮아짐)',
      ],
      actions: [
        '시간대를 바꿔 가며 전압을 기록해 경부하 때만 높은지 봅니다.',
        '상별 전압을 모두 재서 한 상만 높거나 상 사이 차이가 크면 중성선 접속을 점검합니다.',
        '변압기 탭을 확인하고, 수전 전압이면 한전에 문의합니다.',
      ],
    ),
    'e_v_ok': const WizEnd(
      'e_v_ok',
      '허용 범위 이내입니다',
      causes: [
        '평균 전압은 정상이지만 순간적으로 흔들릴 수 있음(큰 부하 기동, 계통 사고)',
        '기기 쪽 문제(전원부 불량)',
      ],
      actions: [
        '증상이 있을 때 전압을 기록합니다. IEEE 1159는 0.1~0.9 pu를 저하(sag), 1.1~1.8 pu를 상승(swell)으로 구분합니다.',
        '삼상이면 상별 전압 차이를 확인합니다.',
        '전압이 정상이면 기기 쪽 점검으로 넘어갑니다.',
      ],
    ),
  },
);

// ── 접속부·단자가 뜨겁다 (열화상) ──────────────────────────────────────

WizFlow heatFlow() => WizFlow(
  'heat',
  '접속부·단자가 뜨겁다 (열화상)',
  '열화상으로 잰 온도 차이를 기준표와 비교해 조치 시기를 정합니다',
  'h0',
  {
    'h0': const WizChoice(
      'h0',
      '무엇과 비교합니까?',
      [
        ('같은 부하의 비슷한 부품끼리(3상 R·S·T 같은 부위, 같은 크기의 단자)', 'h_sim'),
        ('주변 온도·주변 기기와', 'h_amb'),
      ],
      help: '비슷한 부품끼리 비교하는 쪽이 부하 영향이 같아 더 정확합니다. 정상 운전 부하에서 재고, 그때의 부하 전류를 함께 적어 두십시오. 부하가 낮으면 실제보다 낮게 나옵니다.',
    ),
    'h_sim': WizMeasure(
      'h_sim',
      '가장 뜨거운 곳과 정상 부위의 온도 차이',
      const [
        WizField('dt', '온도 차이 ΔT', unit: 'K', hint: '가장 뜨거운 곳 온도 − 같은 조건의 정상 부위 온도(℃ 차이와 같음)'),
        WizField(
          'std',
          '판정 기준',
          choices: [('neta', 'NETA 기준(FIST 4-13 표)'), ('gosi', '전기안전관리자 직무 고시 3상 비교 기준')],
          initial: 'neta',
        ),
      ],
      (v, sel) {
        final dt = v['dt'];
        if (dt == null) return const WizJudge(['온도 차이를 넣으십시오.']);
        final neta = (sel['std'] ?? 'neta') == 'neta';
        if (neta) {
          // 비슷한 부품 간 ΔT: 미국 개척국 FIST 4-13(2011) 39쪽에 옮겨 실린 NETA MTS 표.
          // FIST 표에는 우선순위 번호가 없고 3~4 K 사이가 비어 있다. 번호와 조치 글은 앱이 붙인 말이고,
          // 3 K를 넘으면 다음 구간(4~15 K)으로 본다(안전 쪽).
          final String pr;
          final String act;
          var ok = false;
          if (dt < 1) {
            pr = '1 K 미만';
            act = '정상 범위';
            ok = true;
          } else if (dt <= 3) {
            pr = '우선순위 4 (1~3 K)';
            act = '가능한 결함: 조사';
          } else if (dt <= 15) {
            pr = '우선순위 3 (4~15 K)';
            act = '개연성 있는 결함: 가능할 때 수리';
          } else {
            pr = '우선순위 1 (15 K 초과)';
            act = '중대한 결함: 즉시 수리';
          }
          return WizJudge(
            [
              '비슷한 부품 사이 ΔT ${_n(dt)} K → $pr',
              '조치: $act',
              '구간 값은 FIST 4-13(2011) 39쪽에 실린 NETA MTS 표입니다. 표에는 우선순위 번호가 없고 3~4 K 사이가 비어 있어, 3 K를 넘으면 4~15 K 구간으로 봅니다. 번호와 조치 글은 앱에서 붙인 말입니다.',
            ],
            warn: !ok,
            next: ok ? 'e_h_ok' : 'e_h_act',
          );
        }
        final String act;
        var ok = false;
        if (dt <= 5) {
          act = '정상(5 K 이하)';
          ok = true;
        } else if (dt < 10) {
          act = '요주의(5 K 초과 10 K 미만)';
        } else {
          act = '이상(10 K 이상)';
        }
        return WizJudge(
          [
            '3상 사이 ΔT ${_n(dt)} K → $act',
            '전기안전관리자의 직무에 관한 고시 별지 제7호서식(열화상 3상 비교)의 판정입니다. NETA(15 K 초과가 즉시 수리)보다 엄격합니다.',
          ],
          warn: !ok,
          next: ok ? 'e_h_ok' : 'e_h_act',
        );
      },
    ),
    'h_amb': WizMeasure(
      'h_amb',
      '가장 뜨거운 곳과 주위 온도의 차이',
      const [
        WizField('dt', '온도 차이 ΔT', unit: 'K', hint: '가장 뜨거운 곳 온도 − 주위(공기) 온도'),
      ],
      (v, sel) {
        final dt = v['dt'];
        if (dt == null) return const WizJudge(['온도 차이를 넣으십시오.']);
        // 주위 온도 대비 ΔT: FIST 4-13(2011) 39쪽에 옮겨 실린 NETA MTS 표. 우선순위 번호와 조치 글은 앱이 붙인 말이고,
        // 구간 사이(10~11 K 등)는 다음 구간으로 본다(안전 쪽).
        final String pr;
        final String act;
        var ok = false;
        if (dt < 1) {
          pr = '1 K 미만';
          act = '정상 범위';
          ok = true;
        } else if (dt <= 10) {
          pr = '우선순위 4 (1~10 K)';
          act = '가능한 결함: 조사';
        } else if (dt <= 20) {
          pr = '우선순위 3 (11~20 K)';
          act = '개연성 있는 결함: 가능할 때 수리';
        } else if (dt <= 40) {
          pr = '우선순위 2 (21~40 K)';
          act = '결함: 다음 기회에 수리';
        } else {
          pr = '우선순위 1 (40 K 초과)';
          act = '중대한 결함: 즉시 수리';
        }
        return WizJudge(
          [
            '주위 대비 ΔT ${_n(dt)} K → $pr',
            '조치: $act',
            '구간 값은 FIST 4-13(2011) 39쪽에 실린 NETA MTS 표입니다. 우선순위 번호와 조치 글은 앱에서 붙인 말입니다.',
            '부하 전류가 정격보다 낮을 때 잰 값이면 정격 부하에서는 더 높습니다.',
          ],
          warn: !ok,
          next: ok ? 'e_h_ok' : 'e_h_act',
        );
      },
    ),
    'e_h_ok': const WizEnd(
      'e_h_ok',
      '정상 범위입니다',
      causes: ['기준 이내입니다. 부하가 낮을 때 잰 값이면 실제보다 낮을 수 있습니다.'],
      actions: [
        '촬영 위치·부하 전류·주위 온도를 같이 기록해 다음 점검과 비교합니다.',
        '부하가 높은 시간대에 다시 재면 더 믿을 수 있습니다.',
      ],
    ),
    'e_h_act': const WizEnd(
      'e_h_act',
      '조치가 필요합니다',
      causes: [
        '접속부 조임 불량·산화·접촉 면적 부족(가장 흔한 원인)',
        '과부하: 전류가 전선·단자 정격을 넘음',
        '상 불평형: 한 상에 전류가 몰림',
        '접촉기·차단기 접점 열화',
      ],
      actions: [
        '상별 부하 전류를 재서 정격과 상 불평형을 확인합니다.',
        '정전 후 단자 조임 토크를 제조사 값으로 확인하고, 산화된 접촉면은 청소하거나 부품을 교환합니다.',
        '같은 위치를 같은 조건으로 다시 찍어 개선됐는지 확인하고 기록합니다.',
        '판정이 즉시 수리 단계면 부하를 줄이거나 정전 일정을 앞당깁니다.',
      ],
      links: [('전선 굵기 탭', _tabCable)],
    ),
  },
);

// ── 조명이 안 켜지거나 깜박인다 ────────────────────────────────────────

WizFlow lightingFlow() => WizFlow(
  'lighting',
  '조명이 안 켜지거나 깜박인다',
  '증상 범위로 램프·접속·전원 쪽을 가려 갑니다(일반 점검 순서)',
  'l0',
  {
    'l0': const WizChoice(
      'l0',
      '어떤 증상입니까?',
      [
        ('한 등만 안 켜지거나 깜박인다', 'e_l_single'),
        ('같은 회로의 여러 등이 같이 이상하다', 'e_l_multi'),
        ('깜박이거나 꺼졌다 켜졌다 한다(전체)', 'e_l_flicker'),
        ('회로 전체가 안 켜진다', 'e_l_none'),
      ],
      help: '이 흐름은 수치 판정 기준이 없는 일반 점검 순서입니다. 공식 가이드가 아니라 현장에서 쓰는 순서를 정리한 것입니다.',
    ),
    'e_l_single': const WizEnd(
      'e_l_single',
      '한 등만 이상합니다',
      causes: ['램프(광원) 수명', '안정기·드라이버 불량', '소켓·단자 접촉 불량', '그 등기구로 가는 배선 접속 불량'],
      actions: [
        '이웃한 정상 등과 램프를 맞바꿔 끼워 봅니다. 증상이 따라가면 램프, 그대로면 등기구 쪽입니다.',
        '램프가 정상이면 안정기·드라이버를 같은 종류로 맞바꿔 확인합니다.',
        '소켓 접점의 변색·눌림과 단자 조임을 점검합니다.',
      ],
    ),
    'e_l_multi': const WizEnd(
      'e_l_multi',
      '여러 등이 같이 이상합니다',
      causes: [
        '이상한 등들이 공유하는 구간의 접속 불량(분기 단자, 조인트박스)',
        '중성선 접속 불량',
        '해당 분기를 지나는 스위치·조광기 불량',
      ],
      actions: [
        '이상한 등과 정상 등이 갈라지는 지점을 찾습니다. 그 앞 구간이 공통 원인입니다.',
        '공통 구간의 접속부(분기 단자, 조인트박스)와 중성선 접속을 점검합니다.',
        '전원 쪽에서 등 쪽으로 순서대로 전압을 재서 전압이 사라지는 지점을 찾습니다.',
      ],
      links: [('전압강하 탭', _tabVd)],
    ),
    'e_l_flicker': const WizEnd(
      'e_l_flicker',
      '전체가 깜박입니다',
      causes: [
        '접속 불량(단자·조인트·차단기 접점)',
        '전압 변동: 큰 부하가 기동·정지할 때 같이 흔들림',
        '드라이버·안정기 수명',
      ],
      actions: [
        '깜박이는 시점이 다른 부하의 기동과 겹치는지 봅니다. 겹치면 전압 변동입니다.',
        '증상이 있을 때 전압을 재거나 기록합니다(\'전압이 이상하다\' 흐름).',
        '분전반 차단기 단자와 회로 접속부를 열화상으로 확인합니다(\'접속부·단자가 뜨겁다\' 흐름).',
      ],
    ),
    'e_l_none': const WizEnd(
      'e_l_none',
      '회로 전체가 안 켜집니다',
      causes: ['분전반 차단기 트립·꺼짐', '누전차단기 트립', '전원 쪽 정전·결상', '회로 스위치·타이머·센서 불량'],
      actions: [
        '분전반에서 해당 회로 차단기와 누전차단기 상태를 봅니다. 트립이면 \'차단기가 트립한다\' 흐름으로 원인을 가립니다.',
        '차단기 입력 쪽과 출력 쪽 전압을 재서 전압이 사라지는 지점을 찾습니다.',
        '스위치·타이머·센서를 바이패스해 봅니다(정전 후 배선을 임시로 이어 확인).',
      ],
    ),
  },
);

// ── 변압기 점검 결과를 판정한다 ────────────────────────────────────────

WizFlow transformerFlow() => WizFlow(
  'transformer',
  '변압기 점검 결과를 판정한다',
  '절연유 내압·산가와 온도 상승을 기준값과 비교합니다',
  'x_meas',
  {
    'x_meas': WizMeasure(
      'x_meas',
      '측정한 값을 넣습니다',
      const [
        WizField(
          'state',
          '절연유 상태',
          choices: [('new', '신유(새 기름)'), ('used', '사용 중')],
          initial: 'used',
        ),
        WizField('bd', '절연유 내압', unit: 'kV', optional: true, hint: '전극 간격 2.5 mm 시험'),
        WizField('acid', '산가', unit: 'mg KOH/g', optional: true),
        WizField('rise', '상부 유온 상승', unit: 'K', optional: true, hint: '상부 유온 − 주위 온도'),
      ],
      (v, sel) {
        final isNew = (sel['state'] ?? 'used') == 'new';
        final lines = <String>[];
        var bad = false;
        var any = false;
        final bd = v['bd'];
        if (bd != null) {
          any = true;
          if (isNew) {
            final ok = bd >= 30;
            lines.add('내압 ${_n(bd)} kV: 신유는 30 kV 이상 ${ok ? '적합' : '부적합'}');
            bad = bad || !ok;
          } else if (bd >= 20) {
            lines.add('내압 ${_n(bd)} kV: 사용 중 20 kV 이상 적합');
          } else if (bd >= 15) {
            lines.add('내압 ${_n(bd)} kV: 15~20 kV 요주의');
            bad = true;
          } else {
            lines.add('내압 ${_n(bd)} kV: 15 kV 미만 부적합');
            bad = true;
          }
        }
        final ac = v['acid'];
        if (ac != null) {
          any = true;
          if (isNew) {
            final ok = ac <= 0.02;
            lines.add('산가 ${_n(ac, 3)}: 신유는 0.02 이하 ${ok ? '적합' : '부적합'}');
            bad = bad || !ok;
          } else if (ac <= 0.2) {
            lines.add('산가 ${_n(ac, 3)}: 사용 중 0.2 이하 적합');
          } else if (ac < 0.4) {
            lines.add('산가 ${_n(ac, 3)}: 0.2~0.4 요주의');
            bad = true;
          } else {
            lines.add('산가 ${_n(ac, 3)}: 0.4 이상 부적합');
            bad = true;
          }
        }
        final rise = v['rise'];
        if (rise != null) {
          any = true;
          final ok = rise <= 60;
          lines.add('상부 유온 상승 ${_n(rise)} K: IEC 60076-2 한계 60 K(최고 주위 40 ℃ 기준) ${ok ? '이내' : '초과'}');
          bad = bad || !ok;
        }
        if (!any) return const WizJudge(['한 가지 이상 넣으십시오.']);
        lines.add('절연유 판정값(내압 30·20·15 kV, 산가 0.02·0.2·0.4)은 점검 자료 두 곳이 같은 2차 자료 값입니다. 법령·고시에는 시험 항목만 있고 판정값은 없습니다. 판정값의 원문은 못 봤습니다.');
        return WizJudge(lines, warn: bad, next: bad ? 'e_x_bad' : 'e_x_ok');
      },
    ),
    'e_x_ok': const WizEnd(
      'e_x_ok',
      '입력값은 기준 이내입니다',
      causes: ['측정한 항목은 정상입니다.'],
      actions: [
        '이상음·진동·누유·변색·냄새 같은 일상 점검 항목도 함께 확인합니다.',
        '측정값과 시험 날짜를 기록해 다음 점검과 비교합니다.',
      ],
    ),
    'e_x_bad': const WizEnd(
      'e_x_bad',
      '기준을 벗어난 항목이 있습니다',
      causes: ['절연유 열화·수분 혼입', '과부하나 냉각 불량으로 인한 온도 상승', '내부 방전·접속부 발열'],
      actions: [
        '절연유 내압·산가가 나쁘면 여과·교환을 검토하고 제조사와 상담합니다.',
        '온도 상승이 크면 부하 전류와 냉각(환기·팬·방열기)을 확인합니다.',
        '요주의 값은 시간을 두고 다시 측정해 추세를 봅니다.',
        '절연저항 시험은 1차 대지·1차-2차 DC 1,000 V, 2차 대지 DC 500 V로 합니다(점검 자료 기준).',
      ],
      links: [('부하 합산 탭', _tabLoadSum)],
    ),
  },
);

// ── 역률 콘덴서를 점검한다 ─────────────────────────────────────────────

WizFlow capacitorFlow() => WizFlow(
  'capacitor',
  '역률 콘덴서를 점검한다',
  '정전용량을 정격과 비교하고 세 상 사이 차이를 봅니다',
  'c_meas',
  {
    'c_meas': WizMeasure(
      'c_meas',
      '정전용량을 잽니다',
      const [
        WizField(
          'size',
          '콘덴서 용량',
          choices: [('le100', '100 kvar 이하'), ('gt100', '100 kvar 초과')],
          initial: 'le100',
        ),
        // 10-09 자료 점검: 정격(한 상)과 선간 측정값을 바로 비교해 정상 콘덴서도 Δ면 +50 %, Y면 −50 %로
        // 불합격이 났다. 결선을 골라 선간 값을 한 상 값으로 바꿔 비교한다(108 % 비교는 선간 값 그대로).
        WizField(
          'conn',
          '내부 결선',
          choices: [('delta', 'Δ 결선(저압 대부분)'), ('wye', 'Y 결선')],
          initial: 'delta',
        ),
        WizField('rated', '정격 정전용량', unit: 'μF', hint: '명판 값(상당 한 상의 값)'),
        WizField('cr', 'R상 측정값', unit: 'μF', hint: '삼상 콘덴서는 선간 단자 두 개씩 잰 값'),
        WizField('cs', 'S상 측정값', unit: 'μF'),
        WizField('ct', 'T상 측정값', unit: 'μF'),
      ],
      (v, sel) {
        final rated = v['rated'], a = v['cr'], b = v['cs'], c = v['ct'];
        if (rated == null || rated <= 0 || a == null || b == null || c == null) {
          return const WizJudge(['정격과 세 상의 측정값을 모두 넣으십시오.']);
        }
        // IEC 60831-1 7.2(같은 내용의 IS 13340-1:2012로 확인): 100 kvar 이하 −5~+10 %, 초과 −5~+5 %.
        final big = (sel['size'] ?? 'le100') == 'gt100';
        final hi = big ? 5.0 : 10.0;
        final lines = <String>['측정 전에 반드시 방전합니다. 전원을 끊고 5분 이상 지난 뒤 단자를 단락해 잔류전하가 없는지 확인하십시오.'];
        var bad = false;
        final wye = (sel['conn'] ?? 'delta') == 'wye';
        for (final (name, x) in [('R', a), ('S', b), ('T', c)]) {
          final ph = capacitorPhaseFromLineLine(x, wye: wye);
          final pct = ph / rated * 100 - 100;
          final ok = pct >= -5 && pct <= hi;
          lines.add('$name상(선간) ${_n(x)} μF → 한 상 ${_n(ph)} μF: 정격 대비 ${pct >= 0 ? '+' : ''}${_n(pct)} % (허용 −5~+${_n(hi, 0)} %) ${ok ? '정상' : '벗어남'}');
          bad = bad || !ok;
        }
        lines.add(wye
            ? 'Y 결선: 선간 두 단자 사이는 한 상 두 개가 직렬이라 한 상 = 선간 × 2'
            : 'Δ 결선: 선간 두 단자 사이는 한 상 + (나머지 두 상 직렬)이라 한 상 = 선간 ÷ 1.5');
        final mx = [a, b, c].reduce((p, q) => p > q ? p : q);
        final mn = [a, b, c].reduce((p, q) => p < q ? p : q);
        final ratio = mx / mn * 100;
        final rok = ratio <= 108;
        lines.add('세 값 최대 ÷ 최소 = ${_n(mx)} ÷ ${_n(mn)} = ${_n(ratio, 1)} % (108 % 이하) ${rok ? '정상' : '벗어남'}');
        bad = bad || !rok;
        lines.add('허용 범위는 IEC 60831-1 7.2의 제작 시험 한도입니다(100 kvar 이하 −5~+10 %, 100 kvar 초과 −5~+5 %). 공장 출하 때의 한도라 현장 점검에서는 참고로 쓰십시오.');
        lines.add('108 %는 삼상 콘덴서의 선간 단자 두 개씩 잰 정전용량의 최대 ÷ 최소 한도입니다(IEC 60831-1 7.2).');
        return WizJudge(lines, warn: bad, next: bad ? 'e_c_bad' : 'e_c_ok');
      },
    ),
    'e_c_ok': const WizEnd(
      'e_c_ok',
      '정전용량은 정상입니다',
      causes: ['측정 값은 허용 범위 이내입니다.'],
      actions: [
        '외관(팽창·누액)과 단자 온도(열화상)도 함께 확인합니다.',
        '값을 기록해 시간에 따른 감소를 봅니다.',
      ],
      links: [('역률 개선 탭', _tabPf)],
    ),
    'e_c_bad': const WizEnd(
      'e_c_bad',
      '정전용량이 허용 범위를 벗어났습니다',
      causes: [
        '소자 열화·단선으로 용량이 줄어듦',
        '한 상만 낮으면 그 상의 소자나 퓨즈 불량',
        '고조파가 많은 환경에서의 과열 열화',
      ],
      actions: [
        '외관을 확인합니다. 팽창·누액이 있으면 교체합니다.',
        '단자 온도가 75 ℃ 이상이면 접속부를 점검합니다(열화상). 75 ℃는 점검 자료의 참고 값이고 원문은 못 봤습니다.',
        '교체를 검토하고, 고조파가 많은 설비면 직렬 리액터 등 대책을 설계 단계에서 검토합니다.',
      ],
      links: [('역률 개선 탭', _tabPf)],
    ),
  },
);

/// 설비 종류와 상관없는 진단 흐름.
List<WizFlow> generalFlows() => [
  voltageFlow(),
  heatFlow(),
  lightingFlow(),
  transformerFlow(),
  capacitorFlow(),
];

/// 삼상 콘덴서를 선간 두 단자로 잰 값을 한 상 값으로 바꾼다(세 상이 비슷할 때).
/// Δ: 선간 = C + C/2 = 1.5C, Y: 선간 = C/2.
double capacitorPhaseFromLineLine(double lineLine, {required bool wye}) =>
    wye ? lineLine * 2 : lineLine / 1.5;
