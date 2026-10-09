// 전기 설비 계산: 전동기 보호 탭. 계산은 motor_protect.dart, 근거는 docs/전기_접지_전동기보호_근거.md.
// Y-Δ 계전기 위치는 Siemens 용어 그대로 "주 접촉기(line contactor) = 0.58배"로 적는다. "라인 쪽"이라고만 쓰면 반대로 읽힐 수 있다.
// 국내 열동 계전기 120~125% 규칙과 "정격 125~150%" EOCR 설정은 출처 미확인으로 안내한다.
import 'package:flutter/material.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../common/calc_form_parts.dart';
import 'elec_form_parts.dart';
import 'motor_protect.dart';

class ElecMotorProtectTab extends StatefulWidget {
  const ElecMotorProtectTab({super.key, this.history});

  /// "최근 계산 기록"을 다른 탭과 함께 쓸 때 밖에서 만든 기록을 넣는다.
  final RecentCalcLog? history;

  @override
  State<ElecMotorProtectTab> createState() => _ElecMotorProtectTabState();
}

class _ElecMotorProtectTabState extends State<ElecMotorProtectTab>
    with
        CalcFormParts<ElecMotorProtectTab>,
        RecentCalcHistoryMixin<ElecMotorProtectTab>,
        ElecTabParts<ElecMotorProtectTab>,
        AutomaticKeepAliveClientMixin<ElecMotorProtectTab> {
  @override
  RecentCalcLog get calcLog => widget.history ?? super.calcLog;

  @override
  bool get wantKeepAlive => true;

  final _fla = TextEditingController(text: '40');
  final _run = TextEditingController();
  final _start = TextEditingController(text: '6');
  StartMethod _method = StartMethod.direct;
  RelayPlace _place = RelayPlace.insideDelta;
  bool _sf = true; // 서비스팩터 1.15 이상 또는 온도상승 40℃ 이하
  String _cls = '10';

  @override
  void dispose() {
    _fla.dispose();
    _run.dispose();
    _start.dispose();
    super.dispose();
  }

  /// "최근 계산 기록"으로 되돌릴 입력 묶음.
  // 화면을 나갔다 와도 입력이 남는다(8차).
  @override
  String? get elecDraftKey => 'elec_draft_motor_protect_v1';

  @override
  Map<String, Object?> historySnapshot() => {
    'fla': _fla.text,
    'run': _run.text,
    'start': _start.text,
    'method': _method.name,
    'place': _place.name,
    'sf': _sf,
    'cls': _cls,
  };

  /// 빠졌거나 모양이 다른 값은 지금 값을 그대로 둔다.
  @override
  void applyHistorySnapshot(Map<String, dynamic> m) {
    for (final (c, k) in [(_fla, 'fla'), (_run, 'run'), (_start, 'start')]) {
      if (m[k] is String) c.text = m[k] as String;
    }
    _method = StartMethod.values.asNameMap()[m['method']] ?? _method;
    _place = RelayPlace.values.asNameMap()[m['place']] ?? _place;
    if (m['sf'] is bool) _sf = m['sf'] as bool;
    if (kTripClass72.containsKey(m['cls'])) _cls = m['cls'] as String;
  }

  void _set(VoidCallback f) => setState(f);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final fla = readNum(_fla);
    final run = readNum(_run);
    final startS = readNum(_start);
    final children = <Widget>[
      elecField(
        'emp_fla',
        '전동기 정격전류 FLA (A)',
        _fla,
        '명판의 정격전류입니다. 계전기 설정과 NEC 상한의 기준입니다.',
      ),
      elecChipGroup(
        '기동 방식',
        '직입은 정격전류가 설정입니다. Y-Δ는 계전기가 어디에 붙었는지에 따라 설정이 달라집니다.',
        [
          calcChip(
            'emp_direct',
            '직입',
            _method == StartMethod.direct,
            () => _set(() => _method = StartMethod.direct),
          ),
          calcChip(
            'emp_yd',
            'Y-Δ',
            _method == StartMethod.starDelta,
            () => _set(() => _method = StartMethod.starDelta),
          ),
        ],
      ),
      if (_method == StartMethod.starDelta)
        elecChipGroup(
          '계전기 위치 (Y-Δ)',
          '주 접촉기(Siemens 원문의 \'line contactor\')에 붙은 계전기는 권선 전류를 보므로 정격의 0.58배로 맞춥니다. 모든 접촉기 앞 공통 전원 선로에 있으면 선전류를 보므로 정격 그대로입니다(이 경우는 원문 못 봄, 제조사 설명서 확인).',
          [
            calcChip(
              'emp_inside',
              '주 접촉기(권선 전류) → 0.58×FLA',
              _place == RelayPlace.insideDelta,
              () => _set(() => _place = RelayPlace.insideDelta),
            ),
            calcChip(
              'emp_line',
              '공통 전원 선로(선전류) → FLA',
              _place == RelayPlace.line,
              () => _set(() => _place = RelayPlace.line),
            ),
          ],
        ),
      elecChipGroup(
        '서비스팩터',
        'NEC 430.32 상한을 정합니다. 서비스팩터 1.15 이상이거나 온도상승 40℃ 이하 표시가 있으면 125%, 그 밖은 115%입니다.',
        [
          calcChip(
            'emp_sf_y',
            'SF 1.15 이상·온도상승 40℃ 이하',
            _sf,
            () => _set(() => _sf = true),
          ),
          calcChip('emp_sf_n', '그 밖', !_sf, () => _set(() => _sf = false)),
        ],
      ),
      elecField(
        'emp_run',
        '정상 운전전류 (A, 선택)',
        _run,
        '기동이 끝난 뒤 실측한 전류입니다. 넣으면 전자식(EOCR) 부하 설정 범위를 봅니다.',
      ),
      elecChipGroup(
        '트립 클래스',
        '과부하계전기의 동작 특성입니다. 일반 펌프·팬은 10A·10, 기동이 긴 부하는 20, 관성이 큰 부하는 30입니다.',
        [
          for (final c in kTripClass72.keys)
            calcChip(
              'emp_cls_$c',
              '클래스 $c',
              _cls == c,
              () => _set(() => _cls = c),
            ),
        ],
      ),
      elecField(
        'emp_start',
        '기동시간 (초, 선택)',
        _start,
        '기동에서 정격 속도까지 걸리는 시간입니다. 클래스 상한 이상이면 기동 중 트립될 수 있습니다.',
      ),
    ];
    String? summary;
    var warn = false;
    if (fla == null || fla <= 0) {
      children.add(
        calcResult(solve: true, 
          key: const Key('emp_result'),
          big: '— A',
          caption: '정격전류를 넣으면 계산합니다',
          lines: const [],
        ),
      );
    } else {
      final thr = thrSetting(fla, method: _method, place: _place);
      final necMax = necOverloadMax(fla, sf115OrTemp40: _sf);
      final may = startS == null ? null : startMayTrip(_cls, startS);
      final (cLo, cHi) = kTripClass72[_cls]!;
      warn = may == true;
      summary = '과부하계전기 설정 ${fmt(thr, 1)} A';
      children.add(
        calcResult(solve: true, 
          key: const Key('emp_result'),
          big: '${fmt(thr, 1)} A',
          warn: warn,
          caption:
              _method == StartMethod.starDelta &&
                  _place == RelayPlace.insideDelta
              ? '과부하계전기 설정 (Y-Δ, 주 접촉기: FLA ÷ √3)'
              : '과부하계전기 설정전류',
          lines: [
            if (_method == StartMethod.starDelta &&
                _place == RelayPlace.insideDelta)
              '① 설정 = FLA ÷ √3 = ${fmt(fla, 1)} ÷ 1.732 = ${fmt(thr, 2)} A. 주 접촉기에는 권선 전류(선전류의 0.58배)가 흐르므로 계전기를 전동기 정격전류의 0.58배로 맞춥니다(Siemens Industrial Controls Catalog 2019 3장).'
            else
              '① 설정 = 명판 정격전류 ${fmt(fla, 1)} A. 설정값은 트립 전류가 아니라 정격전류입니다.${_method == StartMethod.starDelta ? ' 공통 전원 선로에 둔 경우는 원문을 못 봤습니다.' : ''}',
            'IEC 60947-4-1 표 3: 주위 온도 보상형 열동 계전기는 설정전류의 1.05배에서 동작하지 않고 1.2배에서 동작합니다(+20 ℃ 기준). 비보상형 열동 계전기와 자기식(magnetic) 계전기는 1.0배 불동작, 1.2배 동작입니다(+40 ℃ 기준).',
            '② NEC 430.32 상한 = FLA × ${_sf ? "125" : "115"}% = ${fmt(fla, 1)} × ${_sf ? "1.25" : "1.15"} = ${fmt(necMax, 1)} A. 기동이 안 되어 설정을 올릴 때도 이 값을 초과하면 안 됩니다.',
            if (run != null && run > 0) ...[
              () {
                final (lo, hi) = eocrRange(run);
                return '③ 전자식(EOCR) 부하 설정 = 운전전류 × 110~125% = ${fmt(run, 1)} × 1.10 ~ ${fmt(run, 1)} × 1.25 = ${fmt(lo, 1)} ~ ${fmt(hi, 1)} A(삼화/Schneider EOCR-SS 카탈로그, 정밀하게 맞출 때는 103%). "정격 125~150%"라는 자료도 있으나 출처 미확인입니다. 쓰는 제품의 설명서를 따르십시오.';
              }(),
              'EOCR 기동지연(D-TIME)은 실측 기동시간 + 1초 정도, 과전류 지연(O-TIME)은 보통 4~6초입니다.',
            ],
            '${run != null && run > 0 ? "④" : "③"} 트립 클래스 $_cls: 설정전류 7.2배에서 ${fmt(cLo, 0)}~${fmt(cHi, 0)}초에 동작합니다(IEC 60947-4-1 표 2).',
            if (may == true)
              '기동시간 ${fmt(startS!, 1)}초가 클래스 $_cls 상한 ${fmt(cHi, 0)}초 이상이라 기동 중 트립될 수 있습니다. 더 큰 클래스를 쓰거나 기동 방식을 바꾸십시오.'
            else if (may == false)
              '기동시간 ${fmt(startS!, 1)}초는 클래스 $_cls 상한 ${fmt(cHi, 0)}초 이내입니다.',
          ],
        ),
      );
      final flc = fla;
      children.add(
        calcResult(solve: true, 
          key: const Key('emp_short'),
          big: '단락·전선',
          caption: 'FLC ${fmt(flc, 1)} A 기준(NEC 표 430.250 값을 쓰는 것이 원칙)',
          lines: [
            for (final e in kNecShortCircuitPct.entries)
              'NEC 430.52 ${e.key} 최대 = FLC × ${fmt(e.value, 0)}% = ${fmt(flc, 1)} × ${fmt(e.value / 100, 2)} = ${fmt(necShortCircuitMax(flc, e.key), 1)} A',
            '이 정격은 단락·지락 보호용이고 과부하 보호가 아닙니다. 규격 정격에 안 맞으면 다음 큰 규격을 쓸 수 있고, 기동이 안 되면 더 올릴 수 있습니다. 전동기 회로 차단기 범위는 "전선 굵기" 탭에서 계산합니다.',
            '전선 허용전류 하한 = FLC × 125% = ${fmt(flc, 1)} × 1.25 = ${fmt(motorConductorMin(flc), 1)} A (전동기 1대 연속운전).',
          ],
        ),
      );
    }
    children.addAll([
      calcResult(solve: true, 
        key: const Key('emp_notes'),
        big: '설정할 때 주의',
        caption: '확인된 항목만',
        lines: const [
          '진상 콘덴서를 전동기 단자에 병렬로 달 때는 과부하계전기 전원 쪽에서 분기하십시오. 계전기 부하 쪽(Y-Δ 델타 안 등)에 두면 계전기 전류가 줄어 오동작하거나 동작하지 않을 수 있습니다(내선규정 인용 두 곳과 실측 한 곳).',
          '과부하계전기(THR)는 과부하와 결상을 보호하고, EOCR은 과부하·단락·지락·결상·역상을 보호합니다(제품 구성에 따라 다름).',
          '기동 전류는 직입 정격의 약 5~8배, Y-Δ는 직입의 1/3입니다.',
          '소프트스타터·인버터로 구동하는 전동기의 과부하 설정은 확인하지 못했습니다. 제조사 설명서를 따르십시오.',
        ],
      ),
      const SizedBox(height: 12),
      elecBasis('emp_basis', const [
        'Y-Δ 주 접촉기 0.58배: Siemens Industrial Controls Catalog 2019 3장(과부하계전기) 원문에 "주 접촉기(line contactor)에 붙인 과부하계전기는 전동기 전류의 0.58배로 설정"이라고 되어 있습니다. 공통 전원 선로 위치(정격 그대로)는 원문을 못 봤습니다.',
        '1.05배 불동작·1.2배 동작은 IEC 60947-4-1 표 3의 주위 온도 보상형 열동 계전기 값(+20 ℃)입니다. 비보상형 열동 계전기와 자기식(magnetic) 계전기는 1.0배·1.2배(+40 ℃)입니다.',
        'NEC 430.32(125%·115%)와 NEC 430.52(175·250·300·800%)는 두 곳 이상이 같습니다. NEC는 미국 기준이라 국내 설계는 내선규정·KEC·제조사 선정표를 우선합니다.',
        '트립 클래스 시간(10A 2~10, 10 4~10, 20 6~20, 30 9~30초, 설정전류 7.2배)은 IEC 60947-4-1 표 2와 같습니다.',
        'EOCR 부하 설정 운전전류 110~125%는 삼화/Schneider EOCR-SS 카탈로그 원문입니다. "정격 125~150%"와 국내 과부하계전기 설정 "120~125%" 규칙은 출처 미확인입니다. 제조사 설명서가 우선입니다.',
        'LS ELECTRIC 전동기 회로 선정표(차단기·접촉기 짝)는 PDF 한글이 깨져 원본 대조 전이라 넣지 않았습니다.',
      ]),
    ]);
    return elecPage(children, sumKey: 'emp_sum', summary: summary, warn: warn);
  }
}
