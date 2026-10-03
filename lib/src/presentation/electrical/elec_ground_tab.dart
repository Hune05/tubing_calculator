// 전기 설비 계산: 접지 탭. 계산은 ground_calc.dart, 근거는 docs/전기_접지_전동기보호_근거.md.
// KEC 조문은 사설 옮김 사이트로 확인했고 원문 대조 전이라 화면에도 "원문 확인 전"을 적는다.
import 'package:flutter/material.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../common/calc_form_parts.dart';
import 'elec_form_parts.dart';
import 'ac_calc.dart';
import 'ground_calc.dart';
import 'protection_calc.dart';

class ElecGroundTab extends StatefulWidget {
  const ElecGroundTab({super.key, this.history});

  /// "최근 계산 기록"을 다른 탭과 함께 쓸 때 밖에서 만든 기록을 넣는다.
  final RecentCalcLog? history;

  @override
  State<ElecGroundTab> createState() => _ElecGroundTabState();
}

enum _GMode { protective, grounding, neutral, tt, tn, insulation, rod, bonding }

String _modeLabel(_GMode m) => switch (m) {
  _GMode.protective => '보호도체 굵기',
  _GMode.grounding => '접지도체 최소',
  _GMode.neutral => '중성점 접지저항',
  _GMode.tt => 'TT 누전차단기',
  _GMode.tn => 'TN 자동 차단',
  _GMode.insulation => '절연저항·내력',
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

  // 접지봉
  final _rho = TextEditingController(text: '100');
  final _len = TextEditingController(text: '2.4');
  final _dia = TextEditingController(text: '14.2');
  final _n = TextEditingController(text: '1');
  final _space = TextEditingController(text: '3');
  final _target = TextEditingController();

  // 본딩
  final _pe = TextEditingController(text: '16');

  // TN 자동 차단
  final _u0 = TextEditingController(text: '220');
  final _inRating = TextEditingController(text: '16');
  final _zs = TextEditingController();
  final _ze = TextEditingController();
  final _cableLen = TextEditingController();
  final _sPh = TextEditingController(text: '2.5');
  final _sPe = TextEditingController(text: '2.5');
  ProtDevice _dev = ProtDevice.c;
  bool _branch = true; // 32 A 이하 분기회로

  // 절연저항·내력
  String _insKind = 'lv'; // lv | hv | machine
  LvCircuit _lv = LvCircuit.upTo500;
  final _megger = TextEditingController();
  HvCircuit _hvKind = HvCircuit.upTo7k;
  final _vmax = TextEditingController(text: '6.9');
  final _machineV = TextEditingController(text: '0.44');

  @override
  void dispose() {
    for (final c in [
      _u0,
      _inRating,
      _zs,
      _ze,
      _cableLen,
      _sPh,
      _sPe,
      _megger,
      _vmax,
      _machineV,
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
      elecChipGroup('계산 항목', '접지·절연 계산 여덟 가지입니다. 고르면 입력 칸이 바뀝니다.', [
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
      'TN·TT 자동 차단(211.2), 절연저항·절연내력(132·133·기술기준 제52조)은 현행 KEC 원문(2026.1.5 시행)으로 확인했습니다. 그 밖의 조문은 공식 원문이 아닌 사이트(cq4l 등)로 확인했습니다.',
      '접지도체 최소 굵기(142.3.1)와 TT·IT 계통 노출도전부 접지극 100 Ω 이하는 2025.12.30 개정(공고 제2025-198호)으로 바뀌었고, 현행 원문(2026.1.5 시행)으로 확인했습니다.',
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
                '① 표 142.3-1: 선도체 ${fmt(s!)} mm² → 보호도체 ${fmt(tableOnly, 1)} mm² (규격 ${fmt(tableStd)} mm²)',
                if (s <= 16)
                  '표 규칙: 선도체 16 mm² 이하는 같은 단면적입니다. S = ${fmt(s)} mm²',
                if (s > 16 && s <= 35)
                  '표 규칙: 선도체 16 mm² 초과 35 mm² 이하는 16 mm²입니다.',
                if (s > 35)
                  '표 규칙: 선도체 35 mm² 초과는 S ÷ 2 = ${fmt(s)} ÷ 2 = ${fmt(tableOnly, 1)} mm²입니다.',
                if (ad != null)
                  '② 단열 식: S = √(I² × t) ÷ k = √(${fmt(i!, 0)}² × ${fmt(t!, 2)}) ÷ ${fmt(k, 0)} = ${fmt(ad, 1)} mm² (규격 ${_std(ad)}), 차단시간 5초 이하에만 적용',
                if (ad != null)
                  '③ 필요 단면적 = 표 값과 단열 식 중 큰 값 = ${fmt(tableOnly, 1)}와 ${fmt(ad, 1)} 중 ${fmt(need, 1)} mm² → 규격 ${_std(need)}',
                if (ad == null && (i != null || t != null))
                  '단열 식은 고장전류와 차단시간(5초 이하)을 모두 넣어야 계산합니다.',
                '표 값은 선도체와 같은 재질일 때입니다. 재질이 다르면 (k₁/k₂)를 곱해 구합니다.',
                'TT 계통에서 전원과 설비의 접지극이 따로 떨어져 있으면 보호도체는 구리 25 mm²·알루미늄 35 mm²를 넘을 필요가 없습니다(142.3.2의 1 가).',
                '따로 포설하는 보호도체(케이블의 일부가 아님)는 기계적 보호가 있으면 구리 2.5 mm²·알루미늄 16 mm² 이상, 없으면 구리 4 mm²·알루미늄 16 mm² 이상이고 표 값이 더 크면 표 값입니다.',
                '보호도체 전류가 10 mA를 초과하면 구리 10 mm² 또는 알루미늄 16 mm² 이상으로 보강합니다. 금속 수도관, 인화성 물질(가스·액체·가루)을 담는 금속관, 상시 기계적 응력을 받는 지지 구조물, 가요성 금속배관(보호도체용 설계 제외), 가요성 금속전선관, 지지선·케이블 트레이는 보호도체·보호본딩도체로 쓰지 않습니다(142.3.2의 2 다).',
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
            caption: '접지도체 최소 단면적 (KEC 142.3.1의 1 가)',
            warn: warn,
            lines: [
              g.note,
              '접지도체 단면적은 보호도체 규정(142.3.2의 1, 표 또는 S = √(I²t)/k)도 만족해야 합니다. 중성점 접지용은 16 mm² 이상이고 7 kV 이하 전로는 6 mm²입니다.',
              '피뢰시스템이 접속되면 구리 16 mm² 또는 철 50 mm² 이상입니다(142.3.1의 1 나).',
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
                '고압·35 kV 이하 특고압 전로가 저압과 혼촉할 때의 규정입니다(142.5). 구 제2종 접지의 150/300/600 규칙과 같습니다.',
                '구 종별 참고: 제1종·특별 제3종 10 Ω, 제3종 100 Ω. KEC는 종별을 없앴고 이 숫자가 그대로 모든 접지공사에 적용되는 것은 아닙니다.',
              ],
            ),
          );
        }
      case _GMode.tt:
        final i = _v(_idn);
        final r = i == null ? null : ttMaxOhms(i);
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
              caption: 'TT 계통 누전차단기 보호: R_A × IΔn ≤ 50 V (KEC 211.2.6의 3)',
              lines: [
                'R_A = 노출도전부 PE 저항 + 접지극 저항의 합입니다.',
                '50 V ÷ ${fmt(_v(_idn)!, 3)} A = ${fmt(r, 0)} Ω',
                'KEC의 TT 조건은 50 V 하나입니다. 직류 120 V는 IT 계통(211.2.7)과 보조 보호등전위본딩(143.2.2)에만 있습니다.',
                '실제 설비는 이 값보다 훨씬 낮게(수십 Ω 이하) 시공하는 것이 안전합니다. 접지극 저항은 계절에 따라 변합니다.',
                '노출도전부 접지극 저항은 따로 100 Ω 이하여야 합니다(KEC 211.2.6의 3, 2025.12.30 추가). 계산값이 더 커도 접지극은 100 Ω 이하로 시공합니다.',
              ],
            ),
          );
        }
      case _GMode.tn:
        _buildTn(children, basis, (s, w) {
          summary = s;
          warn = w;
        });
      case _GMode.insulation:
        _buildInsulation(children, basis, (s, w) {
          summary = s;
          warn = w;
        });
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
                '① 1본: ρ/(2πl)·(ln(4l/r) − 1) = ${fmt(rho!, 0)} ÷ (2π × ${fmt(l!)}) × (ln(4 × ${fmt(l)} ÷ ${fmt(d! / 2000, 4)}) − 1) = ${fmt(one, 1)} Ω (r = 지름 ${fmt(d)} mm ÷ 2 = ${fmt(d / 2000, 4)} m)',
                if (n > 1)
                  '② $n본: ${sp > 10 ? "1.0" : "1.2"} × 1본 ÷ $n = ${sp > 10 ? "1.0" : "1.2"} × ${fmt(one, 1)} ÷ $n = ${fmt(many, 1)} Ω (집합계수 ${sp > 10 ? "1.0(간격 10 m 초과)" : "1.2(간격 1~10 m)"})',
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
                '① 보호도체 ÷ 2 = ${fmt(pe!)} ÷ 2 = ${fmt(pe / 2, 1)} mm²',
                '② 6 mm² 이상: 큰 값 = max(6, ${fmt(pe / 2, 1)}) = ${fmt(pe / 2 < 6 ? 6 : pe / 2, 1)} mm²',
                '③ 25 mm² 상한: 작은 값 = min(25, ${fmt(pe / 2 < 6 ? 6 : pe / 2, 1)}) = ${fmt(b, 1)} mm²',
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

  String _devLabel(ProtDevice d) => switch (d) {
    ProtDevice.b => 'B형',
    ProtDevice.c => 'C형',
    ProtDevice.d => 'D형',
    ProtDevice.setting => '순시 설정',
    ProtDevice.rcd => '누전차단기',
  };

  String _iaText(ProtDevice d, double x, double ia) => switch (d) {
    ProtDevice.b => 'B형 5 × In ${fmt(x)} A = ${fmt(ia, 0)} A',
    ProtDevice.c => 'C형 10 × In ${fmt(x)} A = ${fmt(ia, 0)} A',
    ProtDevice.d => 'D형 20 × In ${fmt(x)} A = ${fmt(ia, 0)} A',
    ProtDevice.setting => '순시 설정 ${fmt(x)} A × 1.2 = ${fmt(ia, 0)} A',
    ProtDevice.rcd => '누전차단기 5 × IΔn ${fmt(x, 3)} A = ${fmt(ia, 2)} A',
  };

  /// TN 계통 전원 자동 차단: Zs × Ia ≤ U₀와 최대 차단시간(KEC 211.2).
  void _buildTn(
    List<Widget> children,
    List<String> basis,
    void Function(String?, bool) out,
  ) {
    final u0 = _v(_u0), x = _v(_inRating);
    final ia = x == null ? null : tripCurrentIa(_dev, x);
    final zmax = u0 == null || ia == null
        ? null
        : maxLoopImpedance(u0: u0, ia: ia);
    final zsMeas = _v(_zs);
    final ze = _v(_ze), len = _v(_cableLen), sph = _v(_sPh), spe = _v(_sPe);
    final est = ze != null && len != null && sph != null && spe != null
        ? estimateLoopImpedance(
            ze: ze,
            lengthM: len,
            phaseMm2: sph,
            peMm2: spe,
          )
        : null;
    final zs = zsMeas ?? est;
    children.addAll([
      elecField(
        'gr_u0',
        '대지전압 U₀ (V)',
        _u0,
        '선과 대지 사이 전압입니다. 380/220 V 계통은 220 V입니다.',
      ),
      elecChipGroup(
        '보호장치',
        'B·C·D형은 순시 트립 범위 상한(5·10·20 In)을 Ia로 씁니다. 산업용 차단기는 순시 설정 전류를 넣으십시오.',
        [
          for (final d in ProtDevice.values)
            calcChip(
              'gr_dev_${d.name}',
              _devLabel(d),
              _dev == d,
              () => _set(() => _dev = d),
            ),
        ],
      ),
      elecField(
        'gr_in',
        switch (_dev) {
          ProtDevice.setting => '순시 트립 설정 전류 (A)',
          ProtDevice.rcd => '정격 감도전류 IΔn (A)',
          _ => '차단기 정격전류 In (A)',
        },
        _inRating,
        _dev == ProtDevice.rcd ? '30 mA는 0.03을 넣습니다.' : '차단기 명판의 값입니다.',
      ),
      elecChipGroup(
        '회로',
        '32 A 이하 분기회로는 표 211.2-1 시간, 배전회로(간선)와 32 A 초과 회로는 TN 5초입니다.',
        [
          calcChip(
            'gr_branch',
            '32 A 이하 분기회로',
            _branch,
            () => _set(() => _branch = true),
          ),
          calcChip(
            'gr_feeder',
            '배전회로·32 A 초과',
            !_branch,
            () => _set(() => _branch = false),
          ),
        ],
      ),
      elecField(
        'gr_zs',
        '측정한 고장 루프 임피던스 Zs (Ω, 선택)',
        _zs,
        '루프 임피던스 측정기로 측정한 값입니다. 넣으면 합격/불합격을 판정합니다.',
      ),
      elecSectionTitle('케이블로 대략 구하기 (선택)'),
      elecField(
        'gr_ze',
        '전원 쪽 임피던스 Ze (Ω)',
        _ze,
        '분전반 등 회로 시작점에서 측정한 값입니다.',
      ),
      elecField('gr_cablelen', '케이블 편도 길이 (m)', _cableLen, ''),
      elecField('gr_sph', '상도체 단면적 (mm²)', _sPh, ''),
      elecField('gr_spe', '보호도체 단면적 (mm²)', _sPe, ''),
    ]);
    if (zmax == null) {
      children.add(
        calcResult(
          key: const Key('gr_result'),
          big: '— Ω',
          caption: '대지전압과 보호장치 값을 넣으면 계산합니다',
          lines: const [],
        ),
      );
      out(null, false);
    } else {
      final t = _branch
          ? maxDisconnectTime(sys: EarthSystem.tn, u0: u0!)
          : distributionDisconnectTime(EarthSystem.tn);
      final tt = _branch
          ? maxDisconnectTime(sys: EarthSystem.tt, u0: u0!)
          : distributionDisconnectTime(EarthSystem.tt);
      final ok = zs == null ? null : zs <= zmax;
      // 단락(지락) 전류가 동작전류 이상이 되는 최대 케이블 길이: 상·보호도체 단면적을 넣었을 때.
      final maxLen = (sph != null && spe != null)
          ? maxLengthForTrip(u0: u0!, iaA: ia!, ze: ze ?? 0, phaseMm2: sph, peMm2: spe)
          : null;
      out('TN Zs ${fmt(zmax, 2)} Ω 이하', ok == false);
      children.add(
        calcResult(
          key: const Key('gr_result'),
          big: '${fmt(zmax, 2)} Ω 이하',
          warn: ok == false,
          caption: 'TN 계통 고장 루프 임피던스 최대 (Zs × Ia ≤ U₀)',
          lines: [
            'Ia = ${_iaText(_dev, x!, ia!)}',
            'Zs ≤ U₀ ÷ Ia = ${fmt(u0!)} ÷ ${fmt(ia, 2)} = ${fmt(zmax, 3)} Ω',
            if (t == null)
              'U₀ 50 V 이하는 차단시간 표 대상이 아닙니다.'
            else
              '최대 차단시간: ${fmt(t, 2)}초 (${_branch ? "표 211.2-1, 32 A 이하 분기회로" : "배전회로·32 A 초과, 211.2.3"}). 같은 전압 TT 계통은 ${tt == null ? "표 대상 아님" : "${fmt(tt, 2)}초"}.',
            if (est != null)
              '케이블 어림: Ze ${fmt(ze!, 3)} + 0.0225 × ${fmt(len!)} × (1/${fmt(sph!)} + 1/${fmt(spe!)}) = ${fmt(est, 3)} Ω (참고, 리액턴스 제외)',
            if (maxLen != null)
              '이 보호장치로 자동 차단되는 최대 케이블 길이 L = (U₀ ÷ Ia − Ze) ÷ (ρ × (1/S상 + 1/S보호)) = (${fmt(zmax, 3)} − ${fmt(ze ?? 0, 3)}) ÷ (0.0225 × (1/${fmt(sph!)} + 1/${fmt(spe!)})) = ${fmt(maxLen, 1)} m (참고, 리액턴스 제외라 큰 단면적에서는 실제보다 길게 나옵니다)',
            if (ok != null)
              ok
                  ? '${zsMeas != null ? "측정값" : "어림값"} Zs ${fmt(zs!, 3)} Ω ≤ ${fmt(zmax, 3)} Ω: 합격'
                  : '${zsMeas != null ? "측정값" : "어림값"} Zs ${fmt(zs!, 3)} Ω가 ${fmt(zmax, 3)} Ω를 초과합니다: 불합격. 케이블을 굵게 하거나 짧게 하거나, 누전차단기로 보호하십시오.',
            if (zsMeas != null)
              '측정값은 상온에서 측정한 것이라 운전 온도에서 커집니다. 영국 관행은 최대값의 0.8배(${fmt(zmax * 0.8, 3)} Ω) 이하로 봅니다(참고).',
            'TT 계통을 과전류차단기로 차단할 때도 Zs × Ia ≤ U₀이고, Zs에 접지극 저항까지 들어갑니다(211.2.6의 4).',
          ],
        ),
      );
    }
    basis.addAll([
      'Zs × Ia ≤ U₀(211.2.5의 6)와 표 211.2-1 차단시간은 현행 KEC 원문으로 확인했습니다. 표는 IEC 60364-4-41(2005)과 같고, IEC 2017 개정(직류 1초, 63 A 콘센트)은 KEC에 반영되지 않았습니다.',
      'B·C·D형 순시 범위(3~5·5~10·10~20 In)는 KEC 표 212.3-3(주택용 배선차단기)입니다. 산업용 차단기(표 212.3-2)에는 이 구분이 없어 순시 설정값을 씁니다.',
      '순시 설정 +20 %와 구리 ρ 0.0225 Ω·mm²/m는 Legrand 기술 자료(2차)입니다. 누전차단기 Ia = 5 × IΔn은 IEC 주석이고 KEC에는 없습니다. KEC에는 Zs 어림 계산식이 없습니다.',
    ]);
  }

  /// 저압 절연저항(기술기준 제52조), 고압·특고압 전로 절연내력(KEC 132), 회전기 절연내력(KEC 133).
  void _buildInsulation(
    List<Widget> children,
    List<String> basis,
    void Function(String?, bool) out,
  ) {
    children.add(
      elecChipGroup('시험 종류', '저압은 절연저항(메거), 고압 이상과 회전기는 절연내력(내전압)입니다.', [
        calcChip(
          'gr_ins_lv',
          '저압 절연저항',
          _insKind == 'lv',
          () => _set(() => _insKind = 'lv'),
        ),
        calcChip(
          'gr_ins_hv',
          '고압·특고압 전로 내력',
          _insKind == 'hv',
          () => _set(() => _insKind = 'hv'),
        ),
        calcChip(
          'gr_ins_mc',
          '회전기 내력',
          _insKind == 'machine',
          () => _set(() => _insKind = 'machine'),
        ),
      ]),
    );
    switch (_insKind) {
      case 'lv':
        final spec = lvInsulation(_lv);
        final m = _v(_megger);
        final ok = m == null ? null : m >= spec.minMOhm;
        out('절연저항 ${fmt(spec.minMOhm, 1)} MΩ 이상 (DC ${fmt(spec.testV, 0)} V)', ok == false);
        children.addAll([
          elecChipGroup('전로 구분', '사용전압으로 고릅니다. 일반 380/220 V 동력·전등 회로는 "500 V 이하"입니다.', [
            calcChip(
              'gr_lv_selv',
              'SELV·PELV',
              _lv == LvCircuit.selvPelv,
              () => _set(() => _lv = LvCircuit.selvPelv),
            ),
            calcChip(
              'gr_lv_500',
              'FELV 포함 500 V 이하',
              _lv == LvCircuit.upTo500,
              () => _set(() => _lv = LvCircuit.upTo500),
            ),
            calcChip(
              'gr_lv_over',
              '500 V 초과',
              _lv == LvCircuit.over500,
              () => _set(() => _lv = LvCircuit.over500),
            ),
          ]),
          elecField(
            'gr_megger',
            '측정한 절연저항 (MΩ, 선택)',
            _megger,
            '전선 상호 간과 전로-대지 사이 값 중 작은 것을 넣습니다.',
          ),
          calcResult(
            key: const Key('gr_result'),
            big: '${fmt(spec.minMOhm, 1)} MΩ 이상',
            warn: ok == false,
            caption: '시험전압 DC ${fmt(spec.testV, 0)} V (전기설비기술기준 제52조)',
            lines: [
              if (ok != null)
                ok
                    ? '측정값 ${fmt(m!, 2)} MΩ ≥ ${fmt(spec.minMOhm, 1)} MΩ: 합격'
                    : '측정값 ${fmt(m!, 2)} MΩ가 ${fmt(spec.minMOhm, 1)} MΩ 미만입니다: 불합격',
              '개폐기·과전류차단기로 나눌 수 있는 전로마다 전선 상호 간과 전로-대지 사이를 측정합니다.',
              'SPD 등 기기를 떼기 어려우면 DC 250 V로 측정하되 1 MΩ 이상이어야 합니다.',
              '정전이 어려워 측정이 곤란하면 저항성분 누설전류 1 mA 이하로 적합 판정합니다(KEC 132의 1).',
              '2021년 이전에 시설한 설비는 종전 기준(대지전압 150 V 이하 0.1, 300 V 이하 0.2, 400 V 미만 0.3, 400 V 이상 0.4 MΩ)을 따를 수 있습니다.',
            ],
          ),
        ]);
      case 'hv':
        final vm = _v(_vmax);
        final t = vm == null ? null : hvTestVoltageKv(_hvKind, vm);
        const labels = {
          HvCircuit.upTo7k: '7 kV 이하',
          HvCircuit.multiGround7to25: '7~25 kV 다중접지',
          HvCircuit.k7to60: '7~60 kV',
          HvCircuit.over60Ungrounded: '60 kV 초과 비접지',
          HvCircuit.over60Grounded: '60 kV 초과 접지',
          HvCircuit.over60Solid: '60 kV 초과 직접접지',
          HvCircuit.over170PlantSolid: '170 kV 초과 발전소·변전소',
        };
        const rules = {
          HvCircuit.upTo7k: '최대사용전압 × 1.5',
          HvCircuit.multiGround7to25: '최대사용전압 × 0.92',
          HvCircuit.k7to60: '최대사용전압 × 1.25 (10.5 kV 미만이면 10.5 kV)',
          HvCircuit.over60Ungrounded: '최대사용전압 × 1.25',
          HvCircuit.over60Grounded: '최대사용전압 × 1.1 (75 kV 미만이면 75 kV)',
          HvCircuit.over60Solid: '최대사용전압 × 0.72',
          HvCircuit.over170PlantSolid: '최대사용전압 × 0.64',
        };
        const factors = {
          HvCircuit.upTo7k: 1.5,
          HvCircuit.multiGround7to25: 0.92,
          HvCircuit.k7to60: 1.25,
          HvCircuit.over60Ungrounded: 1.25,
          HvCircuit.over60Grounded: 1.1,
          HvCircuit.over60Solid: 0.72,
          HvCircuit.over170PlantSolid: 0.64,
        };
        out(t == null ? null : '절연내력 ${fmt(t, 2)} kV 10분', t == null && vm != null);
        children.addAll([
          elecChipGroup('전로 종류', 'KEC 표 132-1의 전로 구분입니다. 중성점 접지 방식과 최대사용전압으로 고릅니다.', [
            for (final e in labels.entries)
              calcChip(
                'gr_hv_${e.key.name}',
                e.value,
                _hvKind == e.key,
                () => _set(() => _hvKind = e.key),
              ),
          ]),
          elecField(
            'gr_vmax',
            '최대사용전압 (kV)',
            _vmax,
            '설계 도서의 최대사용전압입니다. 공칭전압이 아닙니다.',
          ),
          calcResult(
            key: const Key('gr_result'),
            big: t == null ? '— kV' : '${fmt(t, 2)} kV',
            warn: t == null && vm != null,
            caption: t == null
                ? (vm == null ? '최대사용전압을 넣으면 계산합니다' : '이 전압은 고른 전로 종류의 범위를 벗어났습니다')
                : '전로와 대지 사이 10분 (KEC 표 132-1)',
            lines: [
              if (t != null)
                '${rules[_hvKind]} = ${fmt(vm!, 2)} × ${fmt(factors[_hvKind]!, 2)} = ${fmt(vm * factors[_hvKind]!, 2)} kV${(t - vm * factors[_hvKind]!).abs() > 1e-9 ? " → 최소값 적용 ${fmt(t, 2)} kV" : ""}',
              if (t != null)
                '교류 케이블 전로는 직류로 ${fmt(t, 2)} × 2 = ${fmt(t * 2, 2)} kV(2배)를 10분 가해 시험해도 됩니다.',
              '다심 케이블은 심선 상호 간과 심선-대지 사이에 가합니다.',
              'XLPE 등 고분자 케이블은 0.1 Hz 정현파로 상전압의 3배를 60분(정격 6~30 kV 케이블은 30분) 가해도 됩니다(132의 6).',
              '특고압 기기는 종류별 시험성적서 확인으로 대신할 수 있습니다(132의 5, 7 kV 이하 제외).',
            ],
          ),
        ]);
      default:
        final vm = _v(_machineV);
        final t = vm == null ? null : machineTestVoltageKv(vm);
        String volt(double kv) =>
            kv < 1 ? '${fmt(kv * 1000, 0)} V' : '${fmt(kv, 2)} kV';
        out(t == null ? null : '회전기 절연내력 ${volt(t)} 10분', false);
        children.addAll([
          elecField(
            'gr_mcv',
            '회전기 최대사용전압 (kV)',
            _machineV,
            '발전기·전동기 등입니다. 440 V 전동기는 0.44를 넣습니다.',
          ),
          calcResult(
            key: const Key('gr_result'),
            big: t == null ? '—' : volt(t),
            caption: '권선과 대지 사이 10분 (KEC 표 133-1)',
            lines: [
              if (t != null)
                vm! <= 7
                    ? '최대사용전압 × 1.5 (500 V 미만이면 500 V) = ${fmt(vm, 2)} × 1.5 = ${fmt(vm * 1.5, 3)} kV${vm * 1.5 < 0.5 ? " → 최소 500 V 적용" : ""} = ${volt(t)}'
                    : '최대사용전압 × 1.25 (10.5 kV 미만이면 10.5 kV) = ${fmt(vm, 2)} × 1.25 = ${fmt(vm * 1.25, 3)} kV${vm * 1.25 < 10.5 ? " → 최소 10.5 kV 적용" : ""} = ${volt(t)}',
              if (t != null)
                '회전변류기가 아닌 교류 회전기는 직류로 ${volt(t)} × 1.6 = ${volt(t * 1.6)}(1.6배)를 가해 시험해도 됩니다.',
              'KEC에는 전동기 절연저항(메거) 판정값이 없습니다. 메거 판정은 제조사 기준을 따르십시오.',
            ],
          ),
        ]);
    }
    basis.addAll([
      '저압 절연저항 표(SELV·PELV 250 V 0.5 MΩ, 500 V 이하 500 V 1.0 MΩ, 500 V 초과 1000 V 1.0 MΩ)는 전기설비기술기준 제52조 원문(2025.6.4 개정, 값은 2021년부터 같음)입니다. IEC 60364-6 표 6.1과 같습니다.',
      '고압·특고압 전로(표 132-1)와 회전기(표 133-1) 시험전압은 현행 KEC 원문입니다. 최대사용전압의 정의는 KEC 본문에 없어 설계 도서 값을 넣으십시오.',
    ]);
  }
}
