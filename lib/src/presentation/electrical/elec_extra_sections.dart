// 역률 개선 탭의 "변압기 역률 개선"과 전선 굵기 탭의 "미네랄 절연 케이블·나도체 허용전류" 묶음.
// 계산은 ac_calc.dart, 표는 mi_tables.dart. 입력은 이 화면 안에서만 가지고 저장하지 않는다.
import 'package:flutter/material.dart';

import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import 'ac_calc.dart';
import 'elec_form_parts.dart' show fmt, readNum;
import 'mi_tables.dart';

String _sig(double v) => fmt(v, v.abs() >= 100 ? 1 : (v.abs() >= 1 ? 2 : 4));

/// 역률 개선 탭 아래: 변압기 자체가 쓰는 무효전력(무부하 + 누설)과 보상 용량.
class TransformerPfSection extends StatefulWidget {
  const TransformerPfSection({super.key});

  @override
  State<TransformerPfSection> createState() => _TransformerPfSectionState();
}

class _TransformerPfSectionState extends State<TransformerPfSection>
    with CalcFormParts<TransformerPfSection> {
  final _kva = TextEditingController();
  final _i0 = TextEditingController(text: '1.8');
  final _usc = TextEditingController(text: '4');
  final _load = TextEditingController(text: '100');

  @override
  void dispose() {
    for (final c in [_kva, _i0, _usc, _load]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = readNum(_kva),
        i0 = readNum(_i0),
        usc = readNum(_usc),
        lf = readNum(_load);
    final q = (s != null && i0 != null && usc != null && lf != null)
        ? transformerReactive(
            kva: s,
            i0Pct: i0,
            uscPct: usc,
            loadFactor: lf / 100,
          )
        : null;
    final lines = <String>[];
    if (q != null) {
      lines.addAll([
        '무부하(자화) 무효전력 = S × i0 = ${_sig(s!)} × ${fmt(i0!, 2)} % = ${_sig(q.noLoadKvar)} kvar. 무부하에서 전부하까지 거의 일정합니다.',
        '부하(누설) 무효전력 = S × usc × (부하율)² = ${_sig(s)} × ${fmt(usc!, 2)} % × ${fmt(lf! / 100, 2)}² = ${_sig(q.leakKvar)} kvar',
        '합계 = ${_sig(q.totalKvar)} kvar (변압기 용량의 ${fmt(q.totalKvar / s * 100, 1)} %)',
        '이만큼을 변압기 1차 또는 2차에서 콘덴서로 보상하면 변압기가 끌어가는 무효전력이 0에 가까워집니다.',
      ]);
      final t = kTransformerL22[s.round()];
      if (t != null && (s - s.round()).abs() < 1e-9) {
        lines.add(
          '참고 표(Schneider EIG 그림 L22, 20 kV 1차 유입식): 무부하 ${fmt(t[0], 1)} kvar, 전부하 ${fmt(t[1], 1)} kvar(무부하분 포함)',
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          '변압기 역률 개선 (MV/LV)',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: fc.text,
          ),
        ),
        const SizedBox(height: 8),
        calcField('ec_tp_kva', '변압기 용량 S (kVA)', _kva, '변압기 명판 정격 용량입니다.'),
        calcField(
          'ec_tp_i0',
          '무부하 전류 i0 (%)',
          _i0,
          '명판이나 시험성적서 값을 넣으십시오. 모르면 Schneider EIG 값인 약 1.8 %를 쓰고, 표 값은 용량에 따라 1.8~2.5 % 정도입니다.',
        ),
        calcField(
          'ec_tp_usc',
          '단락 전압 usc (%)',
          _usc,
          '명판의 %임피던스입니다. 모르면 Schneider EIG 전형값으로 유입식 750 kVA 이하 4 %, 800 kVA 이상 6 %, 건식 몰드 6 %를 쓰십시오.',
        ),
        calcField(
          'ec_tp_load',
          '부하율 (%)',
          _load,
          '변압기 정격 용량에 대한 현재 부하의 비율입니다. 전부하는 100입니다.',
        ),
        const SizedBox(height: 8),
        calcResult(
          key: const Key('ec_tp_result'),
          big: q == null ? '- kvar' : '${_sig(q.totalKvar)} kvar',
          caption: '변압기가 쓰는 무효전력',
          lines: lines.isEmpty ? const ['변압기 용량을 넣으십시오.'] : lines,
        ),
        const SizedBox(height: 6),
        Text(
          '근거: Schneider Electric Installation Guide 6장 6.2절(무부하 약 1.8 %, 누설 S·usc·부하율²). '
          '원문 한 곳 기준이며 한국 규정 원문과 대조 전입니다.',
          style: TextStyle(fontSize: 12, color: fc.textSub, height: 1.4),
        ),
      ],
    );
  }
}

/// 전선 굵기 탭 아래: 미네랄 절연(MI) 케이블·나도체 허용전류 표.
class MiCableSection extends StatefulWidget {
  const MiCableSection({super.key});

  @override
  State<MiCableSection> createState() => _MiCableSectionState();
}

class _MiCableSectionState extends State<MiCableSection>
    with CalcFormParts<MiCableSection> {
  MiSheath _sheath = MiSheath.t70;
  MiMethod _method = MiMethod.c;
  bool _v750 = true;
  int _col = 1;
  final _amps = TextEditingController();

  @override
  void dispose() {
    _amps.dispose();
    super.dispose();
  }

  Widget _group(String label, String guide, List<Widget> chips) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        calcLabel(label, guide),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 6, children: chips),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cols = _method == MiMethod.c ? kMiColsC : kMiColsEfg;
    final col = _col.clamp(0, cols.length - 1);
    final rows = miRows(method: _method, sheath: _sheath, v750: _v750);
    final need = readNum(_amps);
    MiRow? pick;
    if (need != null && need > 0) {
      for (final r in rows) {
        if (r.amps[col] >= need) {
          pick = r;
          break;
        }
      }
    }
    final lines = <String>[
      if (need != null && need > 0)
        pick != null
            ? '필요 전류 ${_sig(need)} A 이상인 가장 작은 단면적: ${fmt(pick.mm2, 1)} mm² (허용 ${pick.amps[col]} A)'
            : '표의 가장 큰 단면적(${fmt(rows.last.mm2, 0)} mm², ${rows.last.amps[col]} A)으로도 모자랍니다. 병렬이나 다른 방식을 검토하십시오.',
      '${_v750 ? '750 V' : '500 V'} 케이블, ${_sheath == MiSheath.t70 ? '외피 70 ℃(PVC 피복 또는 접촉 가능한 나선)' : '외피 105 ℃(접촉하지 않는 나선)'}, ${_method == MiMethod.c ? '포설 방법 C' : '포설 방법 E·F·G'}, 열: ${cols[col]}',
      for (final r in rows) '${fmt(r.mm2, 1)} mm² : ${r.amps[col]} A',
      '주위 온도 30 ℃ 기준 표 값입니다. 온도·묶음 보정은 이 표에 반영하지 않았습니다.',
      '나도체(외피 없는 MI)는 접촉하지 않는 곳이면 105 ℃ 표를, 접촉할 수 있으면 70 ℃ 표를 쓰십시오.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          '미네랄 절연(MI) 케이블·나도체 허용전류',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: fc.text,
          ),
        ),
        const SizedBox(height: 8),
        _group(
          '외피',
          '손이 닿을 수 있는 곳이나 PVC 피복이면 70 ℃, 사람이 닿지 않고 가연물과도 떨어진 나선이면 105 ℃ 표를 씁니다.',
          [
            calcChip(
              'ec_mi_t70',
              '70 ℃ (PVC·접촉 가능)',
              _sheath == MiSheath.t70,
              () => setState(() => _sheath = MiSheath.t70),
            ),
            calcChip(
              'ec_mi_t105',
              '105 ℃ (접촉 불가 나선)',
              _sheath == MiSheath.t105,
              () => setState(() => _sheath = MiSheath.t105),
            ),
          ],
        ),
        _group('포설 방법', 'C는 벽·표면 위, E·F·G는 공기 중(트레이·사다리·이격)입니다.', [
          calcChip(
            'ec_mi_c',
            '벽·표면 (C)',
            _method == MiMethod.c,
            () => setState(() => _method = MiMethod.c),
          ),
          calcChip(
            'ec_mi_efg',
            '공기 중 (E·F·G)',
            _method == MiMethod.efg,
            () => setState(() => _method = MiMethod.efg),
          ),
        ]),
        _group('전압 등급', '500 V는 1.5·2.5·4 mm²뿐이고 750 V는 1.5~240 mm²입니다.', [
          calcChip('ec_mi_500', '500 V', !_v750, () => setState(() => _v750 = false)),
          calcChip('ec_mi_750', '750 V', _v750, () => setState(() => _v750 = true)),
        ]),
        _group('배치(열)', '도체 수와 놓는 모양에 맞는 열을 고르십시오.', [
          for (var i = 0; i < cols.length; i++)
            calcChip('ec_mi_col$i', cols[i], col == i, () => setState(() => _col = i)),
        ]),
        calcField(
          'ec_mi_amps',
          '필요 전류 (A, 선택)',
          _amps,
          '넣으면 이 전류를 견디는 가장 작은 단면적을 찾습니다. 설계전류를 넣으십시오.',
        ),
        const SizedBox(height: 8),
        calcResult(
          key: const Key('ec_mi_result'),
          big: pick == null ? '- mm²' : '${fmt(pick.mm2, 1)} mm²',
          caption: '미네랄 절연 케이블 허용전류',
          lines: lines,
        ),
        const SizedBox(height: 6),
        Text(
          '근거: IEC 60364-5-52 부속서 B 표 B.52.6~B.52.9(구리 도체·구리 외피). 원문 표는 확인하지 못했고 '
          '두 곳의 2차 자료(TiSoft, 승위·Wrexham 제조사 자료)가 일치하는 값입니다. 2차 자료·원문 대조 전입니다.',
          style: TextStyle(fontSize: 12, color: fc.textSub, height: 1.4),
        ),
      ],
    );
  }
}
