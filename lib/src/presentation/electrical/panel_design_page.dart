// 분전반·조명 계산(10-03): 조명 광속법, 분전반 상 평형, 여러 부하가 붙은 간선의 전압강하.
// 식은 모두 정의식(panel_calc.dart)이라 표 값이 필요 없다. 조도·조명률·보수율은 설계 도서나 등기구 자료에서 읽어 넣는다.
// 어느 설비·공사에서든 쓴다(조명, 콘센트, 분전반, 간선).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import 'elec_calc.dart';
import 'elec_form_parts.dart';
import 'elec_tables.dart';
import 'panel_calc.dart';

/// 간선 전압강하에서 고를 수 있는 굵기(저항 표에 있는 굵기).
final List<double> _kSizes = kCuR20.keys.toList()..sort();

class PanelDesignPage extends StatelessWidget {
  const PanelDesignPage({super.key, this.initialTab = 0});

  /// 0 조명, 1 분전반 상 평형, 2 간선 전압강하, 3 분기회로 수.
  final int initialTab;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    initialIndex: initialTab.clamp(0, 3),
    child: Scaffold(
      backgroundColor: fc.background,
      appBar: AppBar(
        title: const Text('분전반·조명 계산'),
        bottom: const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(key: Key('pd_tab_light'), text: '조명'),
            Tab(key: Key('pd_tab_balance'), text: '상 평형'),
            Tab(key: Key('pd_tab_feeder'), text: '간선 전압강하'),
            Tab(key: Key('pd_tab_branch'), text: '분기회로 수'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [_LightingTab(), _BalanceTab(), _FeederTab(), _BranchTab()],
      ),
    ),
  );
}

// ─────────────────────────── 조명 ───────────────────────────

class _LightingTab extends StatefulWidget {
  const _LightingTab();
  @override
  State<_LightingTab> createState() => _LightingTabState();
}

class _LightingTabState extends State<_LightingTab>
    with
        CalcFormParts<_LightingTab>,
        RecentCalcHistoryMixin<_LightingTab>,
        ElecTabParts<_LightingTab>,
        AutomaticKeepAliveClientMixin<_LightingTab> {
  @override
  bool get wantKeepAlive => true;

  final _lux = TextEditingController();
  final _x = TextEditingController();
  final _y = TextEditingController();
  final _h = TextEditingController();
  final _lm = TextEditingController();
  final _w = TextEditingController();
  final _u = TextEditingController();
  final _m = TextEditingController();

  @override
  void dispose() {
    for (final c in [_lux, _x, _y, _h, _lm, _w, _u, _m]) {
      c.dispose();
    }
    super.dispose();
  }

  /// 0~1 값. 1보다 크면 %로 보고 100으로 나눈다(조명률 60 → 0.6).
  double? _ratio(TextEditingController c) {
    final v = readNum(c);
    if (v == null) return null;
    return v > 1 ? v / 100 : v;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lux = readNum(_lux);
    final x = readNum(_x);
    final y = readNum(_y);
    final h = readNum(_h);
    final lm = readNum(_lm);
    final w = readNum(_w);
    final u = _ratio(_u);
    final m = _ratio(_m);
    final area = (x != null && y != null && x > 0 && y > 0) ? x * y : null;
    final k = (x != null && y != null && h != null)
        ? roomIndex(x: x, y: y, h: h)
        : null;
    final r = (lux != null && area != null && lm != null && u != null && m != null)
        ? lighting(
            lux: lux,
            areaM2: area,
            lumens: lm,
            u: u,
            m: m,
            x: x,
            y: y,
            wattsEach: w ?? 0,
          )
        : null;
    final missing = <String>[
      if (lux == null) '목표 조도',
      if (area == null) '방 가로·세로',
      if (lm == null) '등기구 광속',
      if (u == null) '조명률',
      if (m == null) '보수율',
    ];
    String? error;
    if (u != null && (u <= 0 || u > 1)) error = '조명률은 0보다 크고 1 이하(또는 %)로 넣으십시오.';
    if (m != null && (m <= 0 || m > 1)) error = '보수율은 0보다 크고 1 이하(또는 %)로 넣으십시오.';

    return elecPage(
      sumKey: 'pd_light_sum',
      summary: r == null
          ? null
          : '등기구 ${r.count}개 · ${r.cols}열 × ${r.rows}행 · 실제 ${fmt(r.actualLux, 0)} lx',
      [
        elecSectionTitle('방과 목표'),
        elecField('pd_lux', '목표 평균 조도 (lx)', _lux,
            '그 방에서 필요한 평균 조도입니다. 설계 도서나 KS 조도 기준에서 장소에 맞는 값을 넣으십시오.'),
        elecField('pd_x', '방 가로 (m)', _x, ''),
        elecField('pd_y', '방 세로 (m)', _y, ''),
        elecField('pd_h', '작업면~등기구 높이 (m, 선택)', _h,
            '작업면(책상 높이 등)에서 등기구까지의 높이입니다. 넣으면 실지수를 보여 줍니다. 조명률표를 읽을 때 씁니다.'),
        elecSectionTitle('등기구'),
        elecField('pd_lm', '등기구 1개 광속 (lm)', _lm,
            '등기구 1개가 내는 전광속입니다. 램프 광속이 아니라 등기구 제품 자료의 값을 쓰십시오.'),
        elecField('pd_w', '등기구 1개 소비전력 (W, 선택)', _w, '넣으면 전체 소비전력과 부하 전류를 보여 줍니다.'),
        elecField('pd_u', '조명률 U', _u,
            '방에서 작업면에 도달하는 광속 비율입니다. 등기구 제조사 조명률표에서 실지수와 천장·벽·바닥 반사율로 읽습니다. 0.6 또는 60처럼 넣으십시오.'),
        elecField('pd_m', '보수율 M', _m,
            '시간이 지나 조도가 떨어지는 것(먼지·광속 감소)을 미리 반영하는 계수입니다. 설계 기준이나 제조사 값을 넣으십시오. 0.8 또는 80처럼 넣으십시오.'),
        const SizedBox(height: 6),
        if (error != null)
          calcResult(
            key: const Key('pd_light_result'),
            big: '확인',
            caption: '입력 오류',
            lines: [error],
            warn: true,
          )
        else if (r == null)
          calcResult(
            key: const Key('pd_light_result'),
            big: '-',
            caption: '필요한 등기구 수',
            lines: [if (missing.isNotEmpty) '${missing.join('·')}을(를) 넣으십시오.'],
          )
        else
          calcResult(
            key: const Key('pd_light_result'),
            big: '${r.count}개',
            caption: '필요한 등기구 수',
            lines: [
              '① N = E × A ÷ (F × U × M) = ${fmt(lux!, 0)} × ${fmt(area!, 1)} ÷ (${fmt(lm!, 0)} × ${fmt(u!, 2)} × ${fmt(m!, 2)}) = ${fmt(r.exact, 2)}개',
              '② 올림해서 ${r.count}개. 배치 ${r.cols}열 × ${r.rows}행(칸 ${r.cols * r.rows}개 중 ${r.count}개 설치), 간격 가로 약 ${fmt(r.spacingX, 2)} m · 세로 약 ${fmt(r.spacingY, 2)} m',
              '③ 실제 평균 조도 = N × F × U × M ÷ A = ${r.count} × ${fmt(lm, 0)} × ${fmt(u, 2)} × ${fmt(m, 2)} ÷ ${fmt(area, 1)} = ${fmt(r.actualLux, 0)} lx',
              if (k != null) '실지수 K = X × Y ÷ (H × (X + Y)) = ${fmt(x!, 1)} × ${fmt(y!, 1)} ÷ (${fmt(h!, 1)} × ${fmt(x + y, 1)}) = ${fmt(k, 2)}',
              if (w != null && w > 0)
                '전체 소비전력 = ${r.count} × ${fmt(w, 0)} W = ${fmt(r.totalWatts / 1000, 2)} kW',
            ],
          ),
        elecBasis('pd_light_basis', const [
          '광속법: 등기구 수 N = E × A ÷ (F × U × M). E 평균 조도 lx, A 방 면적 m², F 등기구 광속 lm, U 조명률, M 보수율.',
          '실지수 K = (X × Y) ÷ (H × (X + Y)). 조명률표를 읽을 때 쓰는 값입니다.',
          '배치는 방의 가로세로비에 가깝게 열과 행으로 나눈 계산상 격자입니다. 실제 배치는 천장 구조·기둥·간섭을 보고 조정하십시오.',
          '조도 기준·조명률·보수율은 앱이 정하지 않습니다. 설계 도서나 등기구 제조사 자료의 값을 넣으십시오.',
          '참고 보수율: 청결한 LED 실내 0.8(CIBSE 기본값). 형광등기구 0.70, 매입 LED 평판 0.79는 한국도로공사 설계 자료가 인용한 값입니다(2차 자료).',
          '참고 최소 조도(산업안전보건기준에 관한 규칙 제8조): 초정밀 작업 750 lx, 정밀 작업 300 lx, 보통 작업 150 lx, 그 밖의 작업 75 lx 이상.',
          '장소별 권장 조도(KS A 3011)는 자료마다 값이 달라 넣지 않았습니다. 설계 도서나 원문으로 확인하십시오.',
          '한국식 표기 F × U × N = E × A × D의 D(감광보상률)는 1 ÷ M입니다. M과 D를 섞어 쓰지 마십시오.',
        ]),
      ],
    );
  }
}

// ─────────────────────────── 분전반 상 평형 ───────────────────────────

class _CircuitRow {
  _CircuitRow(this.id);
  final int id;
  final name = TextEditingController();
  final va = TextEditingController();
  PanelPhase phase = PanelPhase.r;
  bool three = false;

  void dispose() {
    name.dispose();
    va.dispose();
  }
}

class _BalanceTab extends StatefulWidget {
  const _BalanceTab();
  @override
  State<_BalanceTab> createState() => _BalanceTabState();
}

class _BalanceTabState extends State<_BalanceTab>
    with
        CalcFormParts<_BalanceTab>,
        RecentCalcHistoryMixin<_BalanceTab>,
        ElecTabParts<_BalanceTab>,
        AutomaticKeepAliveClientMixin<_BalanceTab> {
  @override
  bool get wantKeepAlive => true;

  static const _maxRows = 40;
  int _nextId = 0;
  late final List<_CircuitRow> _rows = [_CircuitRow(_nextId++)];
  final _volts = TextEditingController(text: '220');

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _volts.dispose();
    super.dispose();
  }

  void _add() {
    if (_rows.length >= _maxRows) return;
    setState(() => _rows.add(_CircuitRow(_nextId++)));
  }

  void _remove(_CircuitRow r) {
    if (_rows.length == 1) {
      setState(() {
        r.name.clear();
        r.va.clear();
      });
      return;
    }
    setState(() {
      _rows.remove(r);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => r.dispose());
  }

  /// 부하가 들어간 줄만.
  List<(_CircuitRow, PanelCircuit)> _circuits() => [
    for (final r in _rows)
      if ((readNum(r.va) ?? 0) > 0)
        (
          r,
          PanelCircuit(
            name: r.name.text.trim().isEmpty
                ? '${_rows.indexOf(r) + 1}번'
                : r.name.text.trim(),
            va: readNum(r.va)!,
            phase: r.phase,
            three: r.three,
          ),
        ),
  ];

  void _auto() {
    final cs = _circuits();
    if (cs.isEmpty) return;
    HapticFeedback.selectionClick();
    final out = autoBalance([for (final (_, c) in cs) c]);
    setState(() {
      for (var i = 0; i < cs.length; i++) {
        cs[i].$1.phase = out[i].phase;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = _circuits();
    final volts = readNum(_volts);
    final r = (volts != null && volts > 0)
        ? panelBalance([for (final (_, c) in cs) c], phaseVolts: volts)
        : null;
    return elecPage(
      sumKey: 'pd_bal_sum',
      summary: r == null
          ? null
          : '불평형률 ${fmt(r.unbalancePct, 1)} % (한도 ${fmt(kUnbalanceLimitPct, 0)} % ${r.unbalancePct <= kUnbalanceLimitPct + 1e-9 ? '이내' : '초과'}) · 중성선 약 ${fmt(r.neutralAmps, 1)} A',
      warn: r != null && r.unbalancePct > kUnbalanceLimitPct + 1e-9,
      [
        elecField('pd_bal_v', '상전압 (V)', _volts,
            '각 상과 중성선 사이 전압입니다. 380/220 V 계통이면 220, 208/120 V 계통이면 120입니다.'),
        elecSectionTitle('회로'),
        for (var i = 0; i < _rows.length; i++) _rowCard(i, _rows[i]),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('pd_bal_add'),
                onPressed: _rows.length >= _maxRows ? null : _add,
                icon: const Icon(Icons.add_rounded),
                label: Text('회로 추가 (${_rows.length}/$_maxRows)'),
              ),
              OutlinedButton(
                key: const Key('pd_bal_auto'),
                onPressed: cs.length < 2 ? null : _auto,
                child: const Text('상 자동 배정'),
              ),
            ],
          ),
        ),
        if (r == null)
          calcResult(
            key: const Key('pd_bal_result'),
            big: '-',
            caption: '설비 불평형률',
            lines: const ['회로의 부하(VA)를 넣으십시오.'],
          )
        else
          calcResult(
            key: const Key('pd_bal_result'),
            big: '${fmt(r.unbalancePct, 1)} %',
            caption: '설비 불평형률',
            warn: r.unbalancePct > kUnbalanceLimitPct + 1e-9,
            lines: [
              '한도 ${fmt(kUnbalanceLimitPct, 0)} %(3상 3선식·4선식, 전기공급약관·내선규정 해설 기준): ${r.unbalancePct <= kUnbalanceLimitPct + 1e-9 ? '합격' : '불합격'}',
              '상별 부하: R ${fmt(r.phaseVa[0], 0)} VA(${fmt(r.phaseAmps[0], 1)} A), S ${fmt(r.phaseVa[1], 0)} VA(${fmt(r.phaseAmps[1], 1)} A), T ${fmt(r.phaseVa[2], 0)} VA(${fmt(r.phaseAmps[2], 1)} A)',
              '① 불평형률 = (최대 상 − 최소 상) ÷ (총 부하 × 1/3) × 100 = (${fmt(r.phaseVa[r.maxPhase.index], 0)} − ${fmt(r.phaseVa[r.minPhase.index], 0)}) ÷ (${fmt(r.totalVa, 0)} × 1/3) × 100 = ${fmt(r.unbalancePct, 1)} %',
              '② 최대 상은 ${phaseName(r.maxPhase)}, 최소 상은 ${phaseName(r.minPhase)}입니다. 큰 상의 회로를 작은 상으로 옮기면 줄어듭니다.',
              '③ 중성선 전류 ≈ √(Ia² + Ib² + Ic² − Ia·Ib − Ib·Ic − Ic·Ia) = ${fmt(r.neutralAmps, 1)} A (세 상 역률이 같고 고조파가 없을 때)',
            ],
          ),
        elecBasis('pd_bal_basis', const [
          '설비 불평형률 = (각 상에 걸린 단상 부하 용량의 최대와 최소의 차) ÷ (총 부하 용량 × 1/3) × 100 %.',
          '삼상 부하는 세 상에 같은 크기로 나눠 넣습니다.',
          '중성선 전류는 세 상 부하의 역률이 같고 전류에 고조파가 없다고 본 값입니다. 조명·전산 부하처럼 3고조파가 큰 설비는 이보다 클 수 있습니다.',
          '한도 30 %는 3상 3선식·4선식 수전의 기준(한전 전기공급약관, 내선규정 해설서 인용)입니다. 전용 변압기로 수전하거나 단상 부하가 작은 경우 등 예외가 있고, 소규모 설비는 40 %까지 허용하는 설명도 있습니다. 규정 원문은 대조 전이니 설계 기준으로 확인하십시오.',
          '단상 3선식은 식이 다릅니다(분모가 총 부하의 1/2, 한도 40 %). 이 화면은 3상 4선식(상-중성선 부하)용입니다.',
          '자동 배정은 큰 회로부터 가장 가벼운 상에 차례로 넣는 방식입니다. 최적해는 아니지만 현장에서 손으로 맞추는 방식과 같습니다.',
        ]),
      ],
    );
  }

  Widget _rowCard(int i, _CircuitRow r) => Container(
    key: Key('pd_bal_row_$i'),
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    decoration: BoxDecoration(
      color: fc.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: fc.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w900, color: fc.brand)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: Key('pd_bal_name_$i'),
                controller: r.name,
                style: TextStyle(fontWeight: FontWeight.w700, color: fc.text),
                decoration: const InputDecoration(isDense: true, hintText: '회로 이름(선택)', border: InputBorder.none),
                onChanged: (_) => setState(() {}),
              ),
            ),
            IconButton(
              key: Key('pd_bal_del_$i'),
              tooltip: '지우기',
              icon: Icon(Icons.close_rounded, color: fc.textSub),
              onPressed: () => _remove(r),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: Key('pd_bal_va_$i'),
                controller: r.va,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: fc.text),
                decoration: const InputDecoration(isDense: true, suffixText: 'VA', border: InputBorder.none, hintText: '부하'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final p in PanelPhase.values)
              calcChip('pd_bal_ph_${i}_${phaseName(p)}', phaseName(p), !r.three && r.phase == p, () {
                setState(() {
                  r.phase = p;
                  r.three = false;
                });
              }),
            calcChip('pd_bal_3_$i', '삼상 부하', r.three, () => setState(() => r.three = !r.three)),
          ],
        ),
      ],
    ),
  );
}

// ─────────────────────────── 간선 전압강하 ───────────────────────────

class _SegRow {
  _SegRow(this.id);
  final int id;
  final len = TextEditingController();
  final amps = TextEditingController();
  void dispose() {
    len.dispose();
    amps.dispose();
  }
}

class _FeederTab extends StatefulWidget {
  const _FeederTab();
  @override
  State<_FeederTab> createState() => _FeederTabState();
}

class _FeederTabState extends State<_FeederTab>
    with
        CalcFormParts<_FeederTab>,
        RecentCalcHistoryMixin<_FeederTab>,
        ElecTabParts<_FeederTab>,
        AutomaticKeepAliveClientMixin<_FeederTab> {
  @override
  bool get wantKeepAlive => true;

  static const _maxRows = 20;
  int _nextId = 0;
  late final List<_SegRow> _rows = [_SegRow(_nextId++), _SegRow(_nextId++)];
  Phase _phase = Phase.single;
  final _volts = TextEditingController(text: '220');
  final _pf = TextEditingController(text: '90');
  double _size = 4;
  bool _xlpe = false;
  bool _lighting = true;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _volts.dispose();
    _pf.dispose();
    super.dispose();
  }

  void _add() {
    if (_rows.length >= _maxRows) return;
    setState(() => _rows.add(_SegRow(_nextId++)));
  }

  void _remove(_SegRow r) {
    if (_rows.length == 1) return;
    setState(() => _rows.remove(r));
    WidgetsBinding.instance.addPostFrameCallback((_) => r.dispose());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final volts = readNum(_volts);
    final pfIn = readNum(_pf);
    final pf = _phase == Phase.dc ? 1.0 : (pfIn == null ? null : (pfIn > 1 ? pfIn / 100 : pfIn));
    final segs = <FeederSegment>[];
    var bad = false;
    for (final r in _rows) {
      final l = readNum(r.len);
      final a = readNum(r.amps);
      if (l == null && a == null) continue;
      if (l == null || a == null || l < 0 || a < 0) {
        bad = true;
        continue;
      }
      segs.add(FeederSegment(lengthM: l, loadAmps: a));
    }
    final res = (!bad && volts != null && pf != null && pf > 0 && pf <= 1 && segs.isNotEmpty)
        ? feederDrop(
            segments: segs,
            size: _size,
            phase: _phase,
            volts: volts,
            pf: pf,
            conductorTempC: _xlpe ? 90 : 70,
          )
        : null;
    final limit = res == null
        ? null
        : voltageDropLimit(_lighting ? SupplyType.lvLighting : SupplyType.lvOther, res.totalLengthM);
    final over = res != null && limit != null && res.totalDropPct > limit + 1e-9;
    return elecPage(
      sumKey: 'pd_feed_sum',
      warn: over,
      summary: res == null
          ? null
          : '전압강하 ${fmt(res.totalDropV, 1)} V · ${fmt(res.totalDropPct, 2)} %${limit == null ? '' : over ? ' (한도 ${fmt(limit, 1)} % 초과)' : ' (한도 ${fmt(limit, 1)} % 이내)'}',
      [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '간선(또는 분기 회로) 한 줄에 부하가 여러 군데 붙어 있을 때 씁니다. 구간마다 앞 지점에서 이 지점까지의 길이와, 이 지점에서 빠지는 부하 전류를 넣으십시오.',
            style: TextStyle(fontSize: 13, height: 1.45, color: fc.textSub),
          ),
        ),
        elecChipGroup('회로', '교류 단상, 교류 삼상, 직류 중 고릅니다.', [
          calcChip('pd_feed_single', '단상', _phase == Phase.single, () => setState(() => _phase = Phase.single)),
          calcChip('pd_feed_three', '삼상', _phase == Phase.three, () => setState(() => _phase = Phase.three)),
          calcChip('pd_feed_dc', '직류', _phase == Phase.dc, () => setState(() => _phase = Phase.dc)),
        ]),
        elecField('pd_feed_v', _phase == Phase.three ? '선간 전압 (V)' : '전압 (V)', _volts,
            '회로 전압입니다. 단상 220 V, 삼상 380 V처럼 넣으십시오. 전압강하 %는 이 전압을 기준으로 계산합니다.'),
        if (_phase != Phase.dc)
          elecField('pd_feed_pf', '역률 (%)', _pf, '부하 전체의 평균 역률입니다. 0.9 또는 90처럼 넣으십시오.'),
        calcDropdown<double>(
          'pd_feed_size',
          '전선 굵기 (mm²)',
          _size,
          _kSizes,
          (v) => '${fmt(v, 2)} mm²',
          (v) => setState(() => _size = v),
          '간선 전체가 같은 굵기라고 보고 계산합니다.',
        ),
        elecChipGroup('도체 최고 온도', '저항을 이 온도 값으로 계산합니다. PVC 절연은 70 ℃, XLPE 절연은 90 ℃입니다.', [
          calcChip('pd_feed_pvc', 'PVC 70 ℃', !_xlpe, () => setState(() => _xlpe = false)),
          calcChip('pd_feed_xlpe', 'XLPE 90 ℃', _xlpe, () => setState(() => _xlpe = true)),
        ]),
        elecChipGroup('판정 한도', '조명 회로는 3 %, 그 밖은 5 %입니다(KEC 232.3.9 저압 수전). 100 m를 넘으면 한도가 조금 늘어납니다.', [
          calcChip('pd_feed_lim_light', '조명 3 %', _lighting, () => setState(() => _lighting = true)),
          calcChip('pd_feed_lim_other', '동력 등 5 %', !_lighting, () => setState(() => _lighting = false)),
        ]),
        elecSectionTitle('구간'),
        for (var i = 0; i < _rows.length; i++) _segCard(i, _rows[i]),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton.icon(
            key: const Key('pd_feed_add'),
            onPressed: _rows.length >= _maxRows ? null : _add,
            icon: const Icon(Icons.add_rounded),
            label: Text('구간 추가 (${_rows.length}/$_maxRows)'),
          ),
        ),
        if (bad)
          calcResult(
            key: const Key('pd_feed_result'),
            big: '확인',
            caption: '입력 오류',
            lines: const ['구간의 길이와 부하 전류를 둘 다 넣으십시오(0 이상).'],
            warn: true,
          )
        else if (res == null)
          calcResult(
            key: const Key('pd_feed_result'),
            big: '-',
            caption: '총 전압강하',
            lines: const ['전압·역률과 구간의 길이·부하 전류를 넣으십시오.'],
          )
        else
          calcResult(
            key: const Key('pd_feed_result'),
            big: '${fmt(res.totalDropPct, 2)} %',
            caption: '총 전압강하 (${fmt(res.totalDropV, 1)} V)',
            warn: over,
            lines: [
              '전체 길이 ${fmt(res.totalLengthM, 0)} m, 전원 쪽 전류 ${fmt(res.totalAmps, 1)} A',
              if (limit != null)
                '한도 ${fmt(limit, 2)} %: ${over ? '불합격(초과)' : '합격'}',
              for (var i = 0; i < segs.length; i++)
                '${i + 1}구간: ${fmt(segs[i].lengthM, 0)} m, 전류 ${fmt(res.segCurrents[i], 1)} A → ${fmt(res.segDropV[i], 2)} V, 누적 ${fmt(res.cumDropV[i], 2)} V (${fmt(res.cumDropPct[i], 2)} %)',
            ],
          ),
        elecBasis('pd_feed_basis', const [
          '구간 전류 = 그 구간 끝과 그 뒤 모든 부하 전류의 합. 구간 전압강하 = 단상·직류 2 × I × L × (R·cosφ + X·sinφ), 삼상 √3 × I × L × (R·cosφ + X·sinφ).',
          '전선 저항은 20 ℃ 표 값에 도체 온도(PVC 70 ℃, XLPE 90 ℃)를 반영한 값, 리액턴스는 전압강하 탭과 같은 값을 씁니다.',
          '한도는 KEC 232.3.9 표의 저압 수전 값(조명 3 %, 동력 등 5 %)과 100 m 초과 가산입니다. 수전점부터 이 간선까지 이미 쓴 전압강하가 있으면 그만큼 뺀 값과 비교하십시오.',
        ]),
      ],
    );
  }

  Widget _segCard(int i, _SegRow r) => Container(
    key: Key('pd_feed_row_$i'),
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
    decoration: BoxDecoration(
      color: fc.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: fc.line),
    ),
    child: Row(
      children: [
        Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w900, color: fc.brand)),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            key: Key('pd_feed_len_$i'),
            controller: r.len,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fc.text),
            decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: '길이', suffixText: 'm'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            key: Key('pd_feed_amps_$i'),
            controller: r.amps,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fc.text),
            decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: '부하', suffixText: 'A'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        IconButton(
          key: Key('pd_feed_del_$i'),
          tooltip: '지우기',
          icon: Icon(Icons.close_rounded, color: fc.textSub),
          onPressed: _rows.length == 1 ? null : () => _remove(r),
        ),
      ],
    ),
  );
}

// ─────────────────────────── 분기회로 수 ───────────────────────────

class _BranchTab extends StatefulWidget {
  const _BranchTab();
  @override
  State<_BranchTab> createState() => _BranchTabState();
}

class _BranchTabState extends State<_BranchTab>
    with
        CalcFormParts<_BranchTab>,
        RecentCalcHistoryMixin<_BranchTab>,
        ElecTabParts<_BranchTab>,
        AutomaticKeepAliveClientMixin<_BranchTab> {
  @override
  bool get wantKeepAlive => true;

  final _area = TextEditingController();
  final _density = TextEditingController();
  final _extra = TextEditingController();
  final _volts = TextEditingController(text: '220');
  final _amps = TextEditingController(text: '20');
  final _util = TextEditingController(text: '100');

  @override
  void dispose() {
    for (final c in [_area, _density, _extra, _volts, _amps, _util]) {
      c.dispose();
    }
    super.dispose();
  }

  /// 건축물 용도별 표준부하(VA/m²): 내선규정 해설 자료. 주택·아파트는 자료마다 40·30으로 갈린다.
  static const _uses = <(String, String, double)>[
    ('pd_use_10', '공장·극장·교회 등 10', 10),
    ('pd_use_20', '병원·호텔·학교·음식점 등 20', 20),
    ('pd_use_30', '사무실·은행·상점 등 30', 30),
    ('pd_use_house', '주택·아파트 40', 40),
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final area = readNum(_area);
    final dens = readNum(_density);
    final extra = readNum(_extra) ?? 0;
    final volts = readNum(_volts);
    final amps = readNum(_amps);
    final utilIn = readNum(_util);
    final util = utilIn == null ? null : (utilIn > 1 ? utilIn / 100 : utilIn);
    final r = (area != null && dens != null && volts != null && amps != null && util != null)
        ? branchCircuits(
            areaM2: area,
            densityVaPerM2: dens,
            extraVa: extra,
            volts: volts,
            branchAmps: amps,
            utilization: util,
          )
        : null;
    return elecPage(
      sumKey: 'pd_branch_sum',
      summary: r == null ? null : '분기회로 ${r.count}개 · 부하 ${fmt(r.totalVa, 0)} VA',
      [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '바닥면적에 표준부하를 곱한 부하설비용량을 분기회로 하나가 맡는 용량으로 나눠 회로 수를 구합니다.',
            style: TextStyle(fontSize: 13, height: 1.45, color: fc.textSub),
          ),
        ),
        elecChipGroup(
          '건축물 용도 (표준부하, VA/m²)',
          '내선규정 해설 자료의 표준부하입니다. 눌러서 값을 넣고, 설계 기준이 다르면 아래 칸에서 고치십시오.\n'
              '주택·아파트는 자료에 따라 40으로도 30으로도 적혀 있어 어느 쪽이 현행인지 확인하지 못했습니다. 설계 기준으로 확인하십시오.',
          [
            for (final (k, label, v) in _uses)
              calcChip(k, label, readNum(_density) == v, () => setState(() => _density.text = fmt(v, 0))),
          ],
        ),
        elecField('pd_branch_density', '표준부하 (VA/m²)', _density, '용도에 맞는 값을 위에서 누르거나 직접 넣으십시오.'),
        elecField('pd_branch_area', '바닥면적 (m²)', _area, '그 부하를 쓰는 건축물 바닥면적입니다.'),
        elecField('pd_branch_extra', '가산부하 (VA, 선택)', _extra,
            '표준부하에 더하는 부하입니다. 주택·아파트의 세대당 가산, 상점 진열장(폭 1 m당 500 VA) 등입니다. 설계 기준의 값을 넣으십시오.'),
        elecField('pd_branch_v', '전압 (V)', _volts, '110 또는 220처럼 넣으십시오.'),
        elecField('pd_branch_amps', '분기회로 정격 (A)', _amps, '15, 20처럼 분기회로 과전류차단기 정격입니다.'),
        elecField('pd_branch_util', '이용률 (%)', _util,
            '분기회로 정격 중 쓸 비율입니다. 정격 전부를 쓰면 100, 정격의 80% 이내로 쓰려면 80을 넣으십시오.'),
        const SizedBox(height: 6),
        if (r == null)
          calcResult(
            key: const Key('pd_branch_result'),
            big: '-',
            caption: '분기회로 수',
            lines: const ['표준부하, 바닥면적, 전압, 분기회로 정격, 이용률을 넣으십시오.'],
          )
        else
          calcResult(
            key: const Key('pd_branch_result'),
            big: '${r.count}개',
            caption: '분기회로 수',
            lines: [
              '① 부하설비용량 = 바닥면적 × 표준부하 + 가산부하 = ${fmt(area!, 1)} × ${fmt(dens!, 1)} + ${fmt(extra, 0)} = ${fmt(r.totalVa, 0)} VA',
              '② 분기회로 하나의 용량 = 전압 × 분기 전류 × 이용률 = ${fmt(volts!, 0)} × ${fmt(amps!, 0)} × ${fmt(util!, 2)} = ${fmt(r.perCircuitVa, 0)} VA',
              '③ 회로 수 = ${fmt(r.totalVa, 0)} ÷ ${fmt(r.perCircuitVa, 0)} = ${fmt(r.exact, 2)} → 올림 ${r.count}개',
              '3 kW(110 V는 1.5 kW) 이상 냉난방·취사 기기는 별도 전용 분기회로로 하는 것이 일반적입니다(내선규정 해설). 이 계산에는 따로 넣지 않았으니 전용 회로는 더해 주십시오.',
            ],
          ),
        elecBasis('pd_branch_basis', const [
          '분기회로 수 = 부하설비용량 ÷ (전압 × 분기 전류 × 이용률), 소수는 올림.',
          '부하설비용량 = P × A + Q × B + C (P 바닥면적, A 표준부하, Q 별도 계산 부분의 면적, B 그 표준부하, C 가산부하)를 한 용도 기준으로 줄인 식입니다.',
          '표준부하 10·20·30 VA/m²(공장·극장 / 병원·호텔·학교 / 사무실·상점)는 내선규정 해설 자료 여러 곳에서 같습니다. 주택·아파트는 40과 30으로 갈립니다.',
          '내선규정·KEC 원문은 대조 전입니다. 분기회로 정격별 최대 부하, 콘센트 수, 전선 최소 굵기는 자료마다 달라 이 화면에 넣지 않았습니다. 전선 굵기는 전선 굵기 탭으로 확인하십시오.',
        ]),
      ],
    );
  }
}
