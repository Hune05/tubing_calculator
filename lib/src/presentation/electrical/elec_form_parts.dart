// 전기 설비 계산의 탭들이 같이 쓰는 화면 부품(탭 몸통·숫자 칸·이름표 칩·근거 보기)과 숫자 글꼴.
// 기존 탭은 electric_calculator_page.dart 안의 같은 모양 함수(_page·_field·_chipGroup·_basis)를 쓰고,
// 파일로 나눈 새 탭(부하 합산·단락 전류·축전지)은 이 mixin을 쓴다.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/common_widgets/text_fields_traversal.dart';
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import '../common/number_text.dart';
export '../common/formula_card.dart';
export '../common/number_text.dart';
export '../../core/common_widgets/text_fields_traversal.dart';

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

/// true면 [ElecTabParts.elecFold]의 모든 구역을 처음부터 펼친다(위젯 테스트 전용: 접힌 칸은 화면에 안 그려져 찾을 수 없다).
bool kElecFoldOpenAll = false;

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
    parseNumberText(c.text);

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
          ElecSummaryBar(sumKey: sumKey, summary: summary, warn: warn),
          Expanded(
            child: FocusTraversalGroup(
              policy: TextFieldsOnlyTraversalPolicy(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                children: children,
              ),
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
    bool ratioHint = true,
  }) => ratioHinted(
    label,
    c,
    calcBox(
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
            // 칸이 0.9를 90%로 읽지 않는 탭(부하 합산)은 "= 90%"를 붙이지 않는다.
            decoration: ratioDecoration(ratioHint ? label : '', c),
            onChanged: (_) {
              onEdit?.call();
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
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

  /// 접었다 펴는 구역. 길어진 화면에서 덜 쓰는 구역을 접어 둔다.
  /// [children]이 비면 아무것도 그리지 않는다. [subtitle]은 접힌 채로도 보이는 요약(예: "3곳", "필요 120 · 적합").
  /// 사용자가 펴거나 접은 상태는 구역 이름([key])별로 폰에 적어 다음에도 그대로 둔다. 적은 게 없으면 [open]이 처음 상태다.
  List<Widget> elecFold(
    String key,
    String title,
    List<Widget> children, {
    bool open = false,
    String? subtitle,
  }) {
    if (children.isEmpty) return const [];
    return [
      ElecFold(
        key: ValueKey('fold#$key'),
        foldKey: key,
        title: title,
        open: open,
        subtitle: subtitle,
        children: children,
      ),
    ];
  }

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


/// [ElecTabParts.elecFold]가 그리는 접었다 펴는 구역. 펴고 접은 상태를 폰에 기억한다.
class ElecFold extends StatefulWidget {
  const ElecFold({
    super.key,
    required this.foldKey,
    required this.title,
    required this.children,
    this.open = false,
    this.subtitle,
  });

  final String foldKey;
  final String title;
  final List<Widget> children;
  final bool open;
  final String? subtitle;

  static String prefKey(String k) => 'fold_v1_$k';

  @override
  State<ElecFold> createState() => _ElecFoldState();
}

class _ElecFoldState extends State<ElecFold>
    with AutomaticKeepAliveClientMixin {
  /// 목록 밖으로 스크롤해도, 접어 둬도 안의 칩·입력 상태를 지우지 않는다.
  @override
  bool get wantKeepAlive => true;

  final ExpansibleController _ctl = ExpansibleController();

  /// 지금 펼쳐져 있는지. 접힌 구역 안 칸은 화면에 안 보이므로 키보드 "다음"이 들어가지 않게 막는다.
  late bool _isOpen = widget.open || kElecFoldOpenAll;

  @override
  void initState() {
    super.initState();
    if (!kElecFoldOpenAll) _restore();
  }

  /// 저장된 상태가 처음 상태와 다르면 맞춘다(저장이 없으면 그대로).
  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getBool(ElecFold.prefKey(widget.foldKey));
      if (!mounted) return;
      if (saved == null || saved == widget.open) return;
      setState(() => _isOpen = saved);
      if (saved) {
        _ctl.expand();
      } else {
        _ctl.collapse();
      }
    } catch (_) {}
  }

  Future<void> _save(bool v) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(ElecFold.prefKey(widget.foldKey), v);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: Key(widget.foldKey),
        maintainState: true,
        controller: _ctl,
        initiallyExpanded: widget.open || kElecFoldOpenAll,
        onExpansionChanged: (v) {
          setState(() => _isOpen = v);
          _save(v);
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 2),
        childrenPadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        iconColor: fc.brand,
        collapsedIconColor: fc.textSub,
        title: Text(
          widget.title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: fc.text,
          ),
        ),
        subtitle: widget.subtitle == null
            ? null
            : Text(
                widget.subtitle!,
                style: TextStyle(fontSize: 13, color: fc.textSub),
              ),
        children: [
          ExcludeFocus(
            excluding: !_isOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          ),
        ],
      ),
    );
  }
}

/// 탭 맨 위 결과 요약 줄. 높이를 늘 같게 둬서, 값을 넣다가 결과가 생기거나 "입력 확인"으로 바뀌어도
/// 아래 칸이 밀리지 않는다(입력 중 칸이 움직이면 엉뚱한 칸을 누르게 된다).
/// 요약이 없을 때는 빈 줄(옅은 안내)만 두고 [sumKey] 키를 붙이지 않는다.
class ElecSummaryBar extends StatelessWidget {
  const ElecSummaryBar({
    super.key,
    required this.sumKey,
    this.summary,
    this.warn = false,
    this.action,
  });

  final String sumKey;
  final String? summary;
  final bool warn;

  /// 오른쪽 끝 단추(예: "원인 확인"). 목록 맨 위에 넣으면 칸이 밀리므로 여기에 둔다.
  final Widget? action;

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Container(
      key: s == null ? null : Key(sumKey),
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: s == null
            ? fc.surface
            : (warn ? fieldSoft(Colors.red.shade50, (p) => p.danger) : fc.brandSoft),
        border: Border(bottom: BorderSide(color: fc.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: s == null
                ? Text(
                    '값을 넣으면 결과가 여기에 나옵니다',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: fc.textSub),
                  )
                : Text(
                    s,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: s.length > 26 ? 14 : 16,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                      color: warn ? fc.danger : fc.brand,
                    ),
                  ),
          ),
          ?action,
        ],
      ),
    );
  }
}

