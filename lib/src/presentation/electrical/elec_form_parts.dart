// 전기 설비 계산의 탭들이 같이 쓰는 화면 부품(탭 몸통·숫자 칸·이름표 칩·근거 보기)과 숫자 글꼴.
// 기존 탭은 electric_calculator_page.dart 안의 같은 모양 함수(_page·_field·_chipGroup·_basis)를 쓰고,
// 파일로 나눈 새 탭(부하 합산·단락 전류·축전지)은 이 mixin을 쓴다.
import 'package:flutter/material.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';

/// elecPage·_page의 sumKey → "최근 계산 기록"에 보일 한글 탭 이름(2026-09-29).
const Map<String, String> kElecTabLabels = {
  'els_sum': '부하 합산',
  'ec_sc_sum': '단락 전류',
  'eg_sum': '발전기 용량',
  'eb_sum': '축전지 용량',
  'ec_sum_load': '부하 전류',
  'ec_sum_cable': '전선 굵기',
  'ec_sum_vd': '전압강하',
  'ec_sum_pf': '역률 개선',
  'ec_sum_basic': '기초 계산',
  'ec_sum_cd': '전선관 규격 선정',
  'ec_sum_bus': '부스바 허용전류',
  'gr_sum': '접지',
  'emp_sum': '전동기 보호',
  'mc_sum': '전동기 점검',
  'mf_sum': '전동기 공식',
  'ms_sum': '전동기 선정',
  'mc2_sum': '콘덴서·단상',
  'mm_sum': '전동기 구동·효율',
  'pd_light_sum': '조명 광속법',
  'pd_bal_sum': '상 평형',
  'pd_feed_sum': '간선 전압강하',
  'ct_sum': '케이블 트레이',
  'tr_sum': '트레이 가공',
  'bb_sum': '부스바 절곡',
  'gb_sum': '접지바 가공',
};

/// 소수 [d]자리까지 쓰고 뒤의 0은 뗀다(12.50 → 12.5).
String fmt(double v, [int d = 1]) {
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// 부하 합산 탭이 단락 전류 탭으로 변압기 값(용량·2차 전압)을 넘길 때 쓰는 꾸러미.
/// 넘길 때마다 새로 만들어 같은 값도 다시 적용된다.
class ElecTransformerSeed {
  const ElecTransformerSeed(this.kva, this.volts);
  final double kva;
  final double volts;
}

/// 칸의 글을 숫자로 읽는다. 비었거나 숫자가 아니면 null.
double? readNum(TextEditingController c) =>
    double.tryParse(c.text.trim().replaceAll(',', ''));

mixin ElecTabParts<W extends StatefulWidget>
    on CalcFormParts<W>, RecentCalcHistoryMixin<W> {
  /// 탭 몸통: 위에 결과 요약 줄(고정), 아래 입력·결과 목록.
  /// 요약 줄이 있으면(=계산이 됨) "최근 계산 기록"에도 쌓는다.
  Widget elecPage(
    List<Widget> children, {
    required String sumKey,
    String? summary,
    bool warn = false,
  }) {
    if (summary != null) {
      logCalc(kElecTabLabels[sumKey] ?? sumKey, summary);
    }
    return GestureDetector(
    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
    behavior: HitTestBehavior.translucent,
    child: Column(
      children: [
        if (summary != null)
          Container(
            key: Key(sumKey),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: warn
                  ? fieldSoft(Colors.red.shade50, (p) => p.danger)
                  : fc.brandSoft,
              border: Border(bottom: BorderSide(color: fc.line)),
            ),
            child: Text(
              summary,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: warn ? fc.danger : fc.brand,
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: children,
          ),
        ),
      ],
    ),
  );
  }

  /// 숫자 칸(calcField와 같은 모양, 키보드 "다음"으로 다음 칸).
  Widget elecField(
    String key,
    String label,
    TextEditingController c,
    String guide, {
    VoidCallback? onEdit,
    bool signed = false,
  }) => calcBox(
    child: Row(
      children: [
        Expanded(flex: 5, child: calcLabel(label, guide)),
        Expanded(
          flex: 4,
          child: TextField(
            key: Key(key),
            controller: c,
            textAlign: TextAlign.right,
            keyboardType: TextInputType.numberWithOptions(
              decimal: true,
              signed: signed,
            ),
            textInputAction: TextInputAction.next,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: fc.text,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
            ),
            onChanged: (_) {
              onEdit?.call();
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
  );

  /// 이름표 + 칩 한 줄.
  Widget elecChipGroup(String label, String guide, List<Widget> chips) =>
      Padding(
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

  /// 접었다 펴는 "근거 보기".
  Widget elecBasis(String key, List<String> lines) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      key: Key(key),
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      iconColor: fc.brand,
      collapsedIconColor: fc.textSub,
      title: Text(
        '근거 보기',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: fc.text,
        ),
      ),
      children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '· $l',
              style: TextStyle(fontSize: 13, color: fc.text, height: 1.4),
            ),
          ),
      ],
    ),
  );

  Widget elecSectionTitle(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: fc.text,
      ),
    ),
  );
}

/// 풀이 한 단계. 식 → 숫자 대입 → 결과를 세 줄로 따로 보여 준다.
/// [formula]가 없으면 [text] 한 줄만 보인다(한도 판정처럼 식 모양이 아닌 설명).
class FormulaRow {
  const FormulaRow({
    this.label,
    this.formula,
    this.sub,
    this.result,
    this.text,
    this.note,
  });

  /// "정격전류"처럼 이 단계가 무엇인지.
  final String? label;

  /// "I = P ÷ (√3 × V × 역률 × 효율)".
  final String? formula;

  /// 식에 숫자를 넣은 모양("11 × 1000 ÷ (√3 × 380 × 0.85 × 0.9)").
  final String? sub;

  /// "21.8 A".
  final String? result;

  /// 식 모양이 아닌 한 줄 설명.
  final String? text;

  /// 결과 옆에 붙는 짧은 덧말("50A 이하라 1.25배").
  final String? note;
}

/// 결과 상자 안에 들어가는 "풀이" 카드: 식은 크게, 숫자 대입은 그 아래, 결과는 굵게.
/// [symbols]는 식에 나온 기호의 뜻("I 전류 (A)")이다.
class ElecFormulaCard extends StatelessWidget {
  const ElecFormulaCard({
    super.key,
    required this.rows,
    this.symbols = const [],
  });

  final List<FormulaRow> rows;
  final List<String> symbols;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '풀이',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: fc.textSub,
            ),
          ),
          for (final r in rows) _row(r),
          if (symbols.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: fc.line),
            const SizedBox(height: 8),
            for (final s in symbols)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  s,
                  style: TextStyle(fontSize: 12, color: fc.textSub, height: 1.4),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(FormulaRow r) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r.label != null)
            Text(
              r.label!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fc.textSub,
              ),
            ),
          if (r.text != null)
            Text(
              r.text!,
              style: TextStyle(fontSize: 13, color: fc.text, height: 1.45),
            ),
          if (r.formula != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              // 식은 중간에서 꺾이면 읽기 어려워, 폭이 모자라면 글자를 줄여 한 줄로 둔다.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  r.formula!,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: fc.text,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          if (r.sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                r.sub!,
                style: TextStyle(fontSize: 14, color: fc.text, height: 1.4),
              ),
            ),
          if (r.result != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                r.result!,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: fc.brand,
                ),
              ),
            ),
          if (r.note != null)
            Text(
              r.note!,
              style: TextStyle(fontSize: 12, color: fc.textSub, height: 1.4),
            ),
        ],
      ),
    );
  }
}
