// 전기 설계 계산: 접지 탭. 계산은 ground_calc.dart, 근거는 docs/전기_접지_전동기보호_근거.md.
// KEC 조문은 사설 옮김 사이트로 확인했고 원문 대조 전이라 화면에도 "원문 확인 전"을 적는다.
import 'package:flutter/material.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../common/calc_form_parts.dart';
import 'elec_form_parts.dart';
import 'ground_calc.dart';

class ElecGroundTab extends StatefulWidget {
  const ElecGroundTab({super.key, this.history});

  /// "최근 계산 기록"을 다른 탭과 함께 쓸 때 밖에서 만든 기록을 넣는다.
  final RecentCalcLog? history;

  @override
  State<ElecGroundTab> createState() => _ElecGroundTabState();
}

enum _GMode { protective, grounding, neutral, tt, rod, bonding }

String _modeLabel(_GMode m) => switch (m) {
  _GMode.protective => '보호도체 굵기',
  _GMode.grounding => '접지도체 최소',
  _GMode.neutral => '중성점 접지저항',
  _GMode.tt => 'TT 누전차단기',
  _GMode.rod => '접지봉 저항',
  _GMode.bonding => '본딩 도체',
};

class _ElecGroundTabState extends State<ElecGroundTab>
    with
        CalcFormParts<ElecGroundTab>,
        RecentCalcHistoryMixin<ElecGroundTab>,
        ElecTabParts<ElecGroundTab>,
        AutomaticKeepAliveClientMixin<ElecGroundTab> {
  @override
  RecentCalcLog get calcLog => widget.history ?? super.calcLog;

  @override
  bool get wantKeepAlive => true;

  _GMode _mode = _GMode.protective;

  // 보호도체
  final _phase = TextEditingController(text: '50');
  final _fault = TextEditingController();
  final _sec = TextEditingController(text: '0.5');
  GroundMaterial _mat = GroundMaterial.copper;
  GroundInsulation _ins = GroundInsulation.pvc;
  bool _separate = false; // 케이블에 병합되지 않고 따로 포설

  // 접지도체
  String _gMat = 'cu';
  bool _hv = false;

  // 중성점
  final _i1 = TextEditingController(text: '10');
  String _trip = 'normal';

  // TT
  final _idn = TextEditingController(text: '0.03');
  bool _dc = false;

  // 접지봉
  final _rho = TextEditingController(text: '100');
  final _len = TextEditingController(text: '2.4');
  final _dia = TextEditingController(text: '14.2');
  final _n = TextEditingController(text: '1');
  final _space = TextEditingController(text: '3');
  final _target = TextEditingController();

  // 본딩
  final _pe = TextEditingController(text: '16');

  @override
  void dispose() {
    for (final c in [
      _phase,
      _fault,
      _sec,
      _i1,
      _idn,
      _rho,
      _len,
      _dia,
      _n,
      _space,
      _target,
      _pe,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(VoidCallback f) => setState(f);

  double? _v(TextEditingController c) => readNum(c);

  String _std(double? s) {
    final r = s == null ? null : roundUpToStd(s);
    return r == null ? '표 범위 밖' : '${fmt(r)} mm²';
  }

  Widget _modeChips() =>
      elecChipGroup('계산 항목', '접지 계산 여섯 가지입니다. 고르면 입력 칸이 바뀝니다.', [
        for (final m in _GMode.values)
          calcChip('gr_mode_${m.name}', _modeLabel(m), _mode == m, () {
            _set(() => _mode = m);
          }),
      ]);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final children = <Widget>[_modeChips()];
    String? summary;
    var warn = false;
    final basis = <String>[
      'KEC 조문은 공식 원문이 아닌 사이트(cq4l 등)로 확인했고 원문(법제처·협회) 대조 전입니다. 설계 도서와 현행 KEC 원문으로 확인하십시오.',
      '2026-01-06 개정 KEC 142.3.1(접지도체)은 일렉킴 인용으로 확인했습니다. TT 100 Ω 상한과 고압·특고압 접지저항 제한은 개정안 단계 보도만 확인해 넣지 않았습니다.',
    ];

    switch (_mode) {
      case _GMode.protective:
        final s = _v(_phase);
        final tableOnly = s != null && s > 0
            ? protectiveConductorFromTable(s)
            : null;
        final i = _v(_fault), t = _v(_sec);
        final k = groundK(_mat, _ins, separate: _separate)!;
        final ad = i != null && t != null
            ? adiabaticMinArea(fault: i, seconds: t, k: k)
            : null;
        children.addAll([
          elecField(
            'gr_phase',
            '선도체 단면적 (mm²)',
            _phase,
            '보호도체와 같은 재질의 선도체 단면적입니다. 표 142.3-1로 보호도체 최소를 구합니다.',
          ),
          elecSectionTitle('고장전류로 구하기 (선택)'),
          elecField(
            'gr_fault',
            '예상 고장전류 (A, 실효값)',
            _fault,
            '비우면 표 값만 봅니다. 단열 식 S = √(I²t) / k.',
          ),
          elecField(
            'gr_sec',
            '차단시간 (초, 5초 이하)',
            _sec,
            '보호장치가 고장전류를 끊는 시간입니다. 5초를 초과하면 이 식을 쓰지 않습니다.',
          ),
          elecChipGroup('재질', '보호도체 재질입니다.', [
            calcChip(
              'gr_mat_cu',
              '구리',
              _mat == GroundMaterial.copper,
              () => _set(() => _mat = GroundMaterial.copper),
            ),
            calcChip(
              'gr_mat_al',
              '알루미늄',
              _mat == GroundMaterial.aluminum,
              () => _set(() => _mat = GroundMaterial.aluminum),
            ),
          ]),
          elecChipGroup('절연', '보호도체 절연체 종류입니다.', [
            calcChip(
              'gr_ins_pvc',
              'PVC',
              _ins == GroundInsulation.pvc,
              () => _set(() => _ins = GroundInsulation.pvc),
            ),
            calcChip(
              'gr_ins_xlpe',
              'XLPE·EPR',
              _ins == GroundInsulation.xlpe,
              () => _set(() => _ins = GroundInsulation.xlpe),
            ),
          ]),
          elecChipGroup(
            '포설',
            '케이블에 병합되지 않고 묶이지도 않은 보호도체면 "따로", 다심 케이블의 한 심이거나 묶인 도체면 "케이블 안·묶음"입니다.',
            [
              calcChip(
                'gr_sep_in',
                '케이블 안·묶음',
                !_separate,
                () => _set(() => _separate = false),
              ),
              calcChip(
                'gr_sep_out',
                '따로 포설',
                _separate,
                () => _set(() => _separate = true),
              ),
            ],
          ),
        ]);
        if (tableOnly == null) {
          children.add(
            calcResult(
              key: const Key('gr_result'),
              big: '—',
              caption: '선도체 단면적을 넣으면 계산합니다',
              lines: const [],
            ),
          );
        } else {
          final tableStd = roundUpToStd(tableOnly) ?? tableOnly;
          final need = ad == null
              ? tableOnly
              : (ad > tableOnly ? ad : tableOnly);
          final needStd = roundUpToStd(need);
          summary =
              '보호도체 ${needStd == null ? "표 범위 밖" : "${fmt(needStd)} mm²"}';
          warn = needStd == null;
          children.add(
            calcResult(
              key: const Key('gr_result'),
              big: needStd == null ? '표 범위 밖' : '${fmt(needStd)} mm²',
              caption: ad == null
                  ? '표 142.3-1 기준 보호도체 최소'
                  : '표와 단열 식 중 큰 값 (표준 규격)',
              warn: warn,
              lines: [
                '표 142.3-1: 선도체 ${fmt(s!)} mm² → 보호도체 ${fmt(tableOnly, 1)} mm² (규격 ${fmt(tableStd)} mm²)',
                if (ad != null)
                  '단열 식: √(${fmt(i!, 0)}² × ${fmt(t!, 2)}) ÷ k ${fmt(k, 0)} = ${fmt(ad, 1)} mm² (규격 ${_std(ad)}), 차단시간 5초 이하에만 적용',
                if (ad == null && (i != null || t != null))
                  '단열 식은 고장전류와 차단시간(5초 이하)을 모두 넣어야 계산합니다.',
                '표 값은 선도체와 같은 재질일 때입니다. 재질이 다르면 (k₁/k₂)를 곱해 구합니다.',
                '따로 포설하는 보호도체(케이블의 일부가 아님)는 기계적 보호가 있으면 구리 2.5 mm²·알루미늄 16 mm² 이상, 없으면 구리 4 mm²·알루미늄 16 mm² 이상이고 표 값이 더 크면 표 값입니다.',
                '보호도체 전류가 10 mA를 초과하면 구리 10 mm² 또는 알루미늄 16 mm² 이상으로 보강합니다. 금속 수도관·가스관·가요 전선관·케이블 트레이는 보호도체로 쓰지 않습니다.',
              ],
            ),
          );
        }
        basis.addAll([
          'k 값(IEC 60364-5-54 부속서 A): 따로 포설 구리 PVC 143·XLPE 176, 알루미늄 PVC 95·XLPE 116. 케이블 안·묶음 구리 PVC 115·XLPE 143, 알루미늄 PVC 76·XLPE 94. 세 곳이 같습니다. 나도체 k는 넣지 않았습니다.',
        ]);
      case _GMode.grounding:
        final g = groundingConductorMin(material: _gMat, highVoltage: _hv);
        summary = g.mm2 == null ? '알루미늄 접지도체 불가' : '접지도체 ${fmt(g.mm2!)} mm² 이상';
        warn = g.mm2 == null;
        children.addAll([
          elecChipGroup('재질', '접지도체 재질입니다.', [
            calcChip(
              'gr_gmat_cu',
              '구리',
              _gMat == 'cu',
              () => _set(() => _gMat = 'cu'),
            ),
            calcChip(
              'gr_gmat_fe',
              '철',
              _gMat == 'fe',
              () => _set(() => _gMat = 'fe'),
            ),
            calcChip(
              'gr_gmat_al',
              '알루미늄',
              _gMat == 'al',
              () => _set(() => _gMat = 'al'),
            ),
          ]),
          elecChipGroup('설비 전압', '고압 이상 설비의 접지도체는 구리 16 mm² 이상입니다.', [
            calcChip('gr_lv', '저압', !_hv, () => _set(() => _hv = false)),
            calcChip('gr_hv', '고압 이상', _hv, () => _set(() => _hv = true)),
          ]),
          calcResult(
            key: const Key('gr_result'),
            big: g.mm2 == null ? '쓸 수 없음' : '${fmt(g.mm2!)} mm²',
            caption: '접지도체 최소 단면적 (고정설비, 큰 고장전류가 없을 때)',
            warn: warn,
            lines: [
              g.note,
              '큰 고장전류가 흐르는 접지도체는 보호도체와 같은 식(S = √(I²t)/k)으로 구합니다. 중성점 접지용은 16 mm² 이상이고 7 kV 이하 전로는 6 mm²입니다.',
              '피뢰시스템이 접속되면 구리 16 mm² 이상입니다(2024년 판).',
              '이동용 기계 외함 접지는 별도 규정이 있습니다(캡타이어 등). 이 화면은 고정설비만 다룹니다.',
            ],
          ),
        ]);
      case _GMode.neutral:
        final i = _v(_i1);
        final r = i == null ? null : neutralGroundMaxOhms(i, trip: _trip);
        children.addAll([
          elecField(
            'gr_i1',
            '고압·특고압측 1선 지락전류 (A)',
            _i1,
            '실측값을 쓰고, 어려우면 선로정수로 계산한 값을 씁니다.',
          ),
          elecChipGroup(
            '저압 혼촉 시 자동 차단',
            '고압·특고압 전로가 저압과 혼촉해 저압 대지전압이 150 V를 초과할 때의 차단 시간입니다. 일반은 150, 1~2초 이내는 300, 1초 이내는 600을 씁니다.',
            [
              calcChip(
                'gr_trip_n',
                '일반 (150)',
                _trip == 'normal',
                () => _set(() => _trip = 'normal'),
              ),
              calcChip(
                'gr_trip_2',
                '2초 이내 (300)',
                _trip == 'within2s',
                () => _set(() => _trip = 'within2s'),
              ),
              calcChip(
                'gr_trip_1',
                '1초 이내 (600)',
                _trip == 'within1s',
                () => _set(() => _trip = 'within1s'),
              ),
            ],
          ),
        ]);
        if (r == null) {
          children.add(
            calcResult(
              key: const Key('gr_result'),
              big: '— Ω',
              caption: '지락전류를 넣으면 계산합니다',
              lines: const [],
            ),
          );
        } else {
          summary = '중성점 접지저항 ${fmt(r, 2)} Ω 이하';
          children.add(
            calcResult(
              key: const Key('gr_result'),
              big: '${fmt(r, 2)} Ω 이하',
              caption: 'KEC 142.5 변압기 중성점 접지저항',
              lines: [
                'R ≤ ${fmt(_trip == 'within1s' ? 600 : (_trip == 'within2s' ? 300 : 150), 0)} ÷ 1선 지락전류 ${fmt(_v(_i1)!, 1)} A = ${fmt(r, 2)} Ω',
                '구 제2종(B종) 접지의 150/300/600 규칙과 같습니다.',
                '구 종별 참고: 제1종·특별 제3종 10 Ω, 제3종 100 Ω. KEC는 종별을 없앴고 이 숫자가 그대로 모든 접지공사에 적용되는 것은 아닙니다.',
              ],
            ),
          );
        }
      case _GMode.tt:
        final i = _v(_idn);
        final r = i == null ? null : ttMaxOhms(i, dc: _dc);
        children.addAll([
          elecField(
            'gr_idn',
            '누전차단기 정격 감도전류 IΔn (A)',
            _idn,
            '30 mA는 0.03, 100 mA는 0.1을 넣습니다.',
          ),
          elecChipGroup('감도전류 예', '자주 쓰는 값입니다.', [
            for (final (label, v) in const [
              ('30 mA', '0.03'),
              ('100 mA', '0.1'),
              ('300 mA', '0.3'),
              ('500 mA', '0.5'),
              ('1 A', '1'),
            ])
              calcChip(
                'gr_idn_$v',
                label,
                _idn.text.trim() == v,
                () => _set(() => _idn.text = v),
              ),
          ]),
          elecChipGroup('전류 종류', '교류는 50 V, 직류는 120 V를 씁니다.', [
            calcChip('gr_ac', '교류 50 V', !_dc, () => _set(() => _dc = false)),
            calcChip('gr_dc', '직류 120 V', _dc, () => _set(() => _dc = true)),
          ]),
        ]);
        if (r == null) {
          children.add(
            calcResult(
              key: const Key('gr_result'),
              big: '— Ω',
              caption: '감도전류를 넣으면 계산합니다',
              lines: const [],
            ),
          );
        } else {
          summary = 'TT 접지저항 ${fmt(r, 0)} Ω 이하';
          children.add(
            calcResult(
              key: const Key('gr_result'),
              big: '${fmt(r, 0)} Ω 이하',
              caption: 'TT 계통 누전차단기 보호: R_A × IΔn ≤ ${_dc ? 120 : 50} V',
              lines: [
                'R_A = 노출도전부 PE 저항 + 접지극 저항의 합입니다.',
                '${_dc ? 120 : 50} V ÷ ${fmt(_v(_idn)!, 3)} A = ${fmt(r, 0)} Ω',
                '실제 설비는 이 값보다 훨씬 낮게(수십 Ω 이하) 시공하는 것이 안전합니다. 접지극 저항은 계절에 따라 변합니다.',
                'TT에서 100 Ω 이하로 두는 개정안은 시행 여부를 확인하지 못해 넣지 않았습니다.',
              ],
            ),
          );
        }
      case _GMode.rod:
        final rho = _v(_rho), l = _v(_len), d = _v(_dia);
        final n = int.tryParse(_n.text.trim()) ?? 1;
        final sp = _v(_space) ?? 0;
        final one = rho != null && l != null && d != null
            ? rodResistance(rho: rho, lengthM: l, diaMm: d)
            : null;
        final many = one == null ? null : rodsParallel(one, n, spacingM: sp);
        final target = _v(_target);
        children.addAll([
          elecField(
            'gr_rho',
            '대지저항률 ρ (Ω·m)',
            _rho,
            '측정한 값이 가장 좋습니다. 아래 토양별 값은 참고값입니다.',
          ),
          elecChipGroup('토양 참고값', '습도·계절·층 구조에 따라 크게 다릅니다. 확인용입니다.', [
            for (final (name, v) in kSoilResistivity)
              calcChip(
                'gr_soil_${v.toInt()}',
                '$name ${fmt(v, 0)}',
                _v(_rho) == v,
                () => _set(() => _rho.text = fmt(v, 0)),
              ),
          ]),
          elecField('gr_len', '봉 길이 (m)', _len, '매설 길이입니다.'),
          elecField('gr_dia', '봉 지름 (mm)', _dia, '예: 14.2(직경 14.2mm 접지봉).'),
          elecField('gr_n', '봉 개수', _n, '병렬로 박는 봉 수입니다.'),
          if (n > 1)
            elecField(
              'gr_space',
              '봉 사이 간격 (m)',
              _space,
              '1 m 이상이어야 이 식을 씁니다. 10 m를 초과하면 서로 영향이 없다고 봅니다.',
            ),
          elecField(
            'gr_target',
            '목표 접지저항 (Ω, 선택)',
            _target,
            '넣으면 목표를 만족하는지 봅니다.',
          ),
        ]);
        if (one == null) {
          children.add(
            calcResult(
              key: const Key('gr_result'),
              big: '— Ω',
              caption: '값을 넣으면 계산합니다',
              lines: const [],
            ),
          );
        } else if (many == null) {
          warn = true;
          children.add(
            calcResult(
              key: const Key('gr_result'),
              big: '${fmt(one, 1)} Ω (1본)',
              warn: true,
              caption: '봉 사이 간격이 1 m 미만이라 병렬 식을 쓸 수 없습니다',
              lines: const ['봉 간격을 1 m 이상으로 하십시오.'],
            ),
          );
        } else {
          final ok = target == null ? null : many <= target;
          warn = ok == false;
          summary = '접지봉 $n본 ${fmt(many, 1)} Ω';
          children.add(
            calcResult(
              key: const Key('gr_result'),
              big: '${fmt(many, 1)} Ω',
              warn: warn,
              caption: n == 1 ? '접지봉 1본 접지저항 (근사)' : '접지봉 $n본 병렬 (근사)',
              lines: [
                '1본: ρ/(2πl)·(ln(4l/r) − 1) = ${fmt(one, 1)} Ω',
                if (n > 1)
                  '$n본: ${sp > 10 ? "1.0" : "1.2"} × 1본 ÷ $n = ${fmt(many, 1)} Ω (집합계수 ${sp > 10 ? "1.0(간격 10 m 초과)" : "1.2(간격 1~10 m)"})',
                if (ok != null)
                  ok
                      ? '목표 ${fmt(target!, 1)} Ω 이내입니다.'
                      : '목표 ${fmt(target!, 1)} Ω를 초과합니다. 봉을 늘리거나 길게 박거나 접지저항 저감 방법을 검토하십시오.',
                '이 식은 근사식이고 한 곳 자료입니다. 실제 접지저항은 시공 후 측정(3점 전위강하법)으로 확인하십시오.',
                '측정 요령: 전류 보조극을 접지극에서 접지극 규모의 6.5배 이상(또는 80 m 이상) 띄우고, 전위 보조극은 그 61.8 % 지점에 박습니다. 51.8 %·71.8 % 지점도 측정해 평균과 비교합니다.',
              ],
            ),
          );
        }
        basis.add(
          '접지봉 식과 병렬 집합계수(K 1.2, 간격 10 m 초과 1.0)는 한 곳(eom) 자료입니다. 대지저항률 참고값은 두 곳이 비슷하지만 출처마다 폭이 큽니다.',
        );
      case _GMode.bonding:
        final pe = _v(_pe);
        final b = pe == null || pe <= 0 ? null : bondingConductorMinCopper(pe);
        children.add(
          elecField(
            'gr_pe',
            '설비 안 가장 큰 보호도체 단면적 (mm²)',
            _pe,
            '주접지단자에 연결된 보호도체 중 가장 큰 것입니다.',
          ),
        );
        if (b == null) {
          children.add(
            calcResult(
              key: const Key('gr_result'),
              big: '—',
              caption: '단면적을 넣으면 계산합니다',
              lines: const [],
            ),
          );
        } else {
          summary = '보호등전위본딩 ${fmt(b, 1)} mm² 이상';
          children.add(
            calcResult(
              key: const Key('gr_result'),
              big: '${fmt(b, 1)} mm² 이상 (규격 ${_std(b)})',
              caption: '보호등전위본딩 도체 최소 단면적 (구리)',
              lines: [
                '가장 큰 보호도체의 1/2 이상, 구리 6 mm² 이상. 구리 25 mm²를 넘길 필요는 없습니다.',
                '${fmt(pe!)} ÷ 2 = ${fmt(pe / 2, 1)} → 6 mm² 이상, 25 mm² 상한 적용 = ${fmt(b, 1)} mm²',
                '알루미늄은 16 mm², 강은 50 mm² 이상입니다.',
                '수도관·가스관은 건물 인입 최초 밸브 뒤에서 본딩합니다.',
              ],
            ),
          );
        }
    }

    children.addAll([const SizedBox(height: 12), elecBasis('gr_basis', basis)]);
    return elecPage(children, sumKey: 'gr_sum', summary: summary, warn: warn);
  }
}
