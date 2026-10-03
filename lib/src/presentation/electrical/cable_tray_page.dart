// 케이블 트레이 계산기(10-03): 트레이에 넣을 케이블 목록으로 점유율 판정과 권장 폭.
// 계산은 cable_tray.dart(KEC 232.41·판단기준 제213조의2 표와 규칙), 케이블 외경은 conduit_tables.dart.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/common_widgets/swipe_to_delete.dart';
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'cable_tray.dart';
import 'cable_tray_painter.dart';
import 'cable_weights.dart';
import 'elec_tables.dart' show GroupLayout;
import 'conduit_tables.dart';
import 'elec_calc.dart' show sqText;
import 'elec_form_parts.dart';

/// 케이블 한 줄 입력. [kind]가 null이면 직접 입력(외경·굵기·심 수).
class _TrayRow {
  CableKind? kind;
  AmsKind? ams; // AMS 계장 케이블이면(그때 kind는 안 씀)
  int amsN;
  double size;
  bool control;
  final TextEditingController count;
  final TextEditingController od;
  final TextEditingController sizeText;
  final TextEditingController cores;
  final TextEditingController weight; // 직접 입력 무게(kg/km)
  _TrayRow({this.kind = CableKind.fcv4, this.ams, this.amsN = 2, this.size = 35, this.control = false, String n = '1', String od = '', String sz = '', String cores = '1', String w = ''})
      : count = TextEditingController(text: n),
        od = TextEditingController(text: od),
        sizeText = TextEditingController(text: sz),
        cores = TextEditingController(text: cores),
        weight = TextEditingController(text: w);

  void dispose() {
    count.dispose();
    od.dispose();
    sizeText.dispose();
    cores.dispose();
    weight.dispose();
  }

  Map<String, Object?> toJson() => {
    'k': kind?.name,
    'a': ams?.name,
    'an': amsN,
    's': size,
    'c': control,
    'n': count.text,
    'od': od.text,
    'sz': sizeText.text,
    'co': cores.text,
    'w': weight.text,
  };

  static _TrayRow? fromJson(Object? m) {
    if (m is! Map) return null;
    final k = CableKind.values.where((c) => c.name == m['k']);
    final a = AmsKind.values.where((c) => c.name == m['a']);
    final s = m['s'];
    final row = _TrayRow(
      kind: k.isEmpty ? null : k.first,
      ams: a.isEmpty ? null : a.first,
      amsN: m['an'] is int ? m['an'] as int : 2,
      size: s is num ? s.toDouble() : 35,
      control: m['c'] == true,
      n: '${m['n'] ?? '1'}',
      od: '${m['od'] ?? ''}',
      sz: '${m['sz'] ?? ''}',
      cores: '${m['co'] ?? '1'}',
      w: '${m['w'] ?? ''}',
    );
    if (row.ams != null) {
      if (!amsCounts(row.ams!).contains(row.amsN)) row.amsN = amsCounts(row.ams!).first;
      final ss = amsSizes(row.ams!, row.amsN);
      if (!ss.contains(row.size)) row.size = ss.first;
    } else if (row.kind != null && !cableSizes(row.kind!).contains(row.size)) {
      row.size = cableSizes(row.kind!).first;
    }
    return row;
  }
}

/// 바닥에 직접 놓는 트레이 안내(덮개).
const List<String> kFloorTrayNotes = [
  '덮개: 사람이 다니거나 물건이 떨어지거나 밟힐 수 있는 곳은 덮개를 씌웁니다. KEC 232.41.2의 10 "별도로 방호를 필요로 하는 배선부분에는 필요한 방호력이 있는 불연성의 덮개 등"을 따릅니다.',
  '덮개 중량도 트레이 자중 칸에 더해 넣으십시오.',
  '바닥 트렌치(홈) 안이면 KEC 232.24: 받침대는 2m 이내마다, 뚜껑은 바닥 마감면과 평평하고 다니는 사람·장비 하중에 변형되지 않게, 바닥·옆면 방수와 물 고임 방지.',
  '참고: NEMA VE 2는 트레이를 바닥에 바로 놓지 말고 스트럿 위에 띄워 클램프로 고정하라고 합니다(해외 권고).',
];

/// 트레이에 넣는 케이블로 고를 수 있는 것: 케이블과 트레이용 접지선(F-GV).
/// HFIX·IV·HIV 같은 시스 없는 절연전선은 트레이에 그대로 깔지 않는다.
final List<CableKind> kTrayCableKinds = [
  for (final k in CableKind.values)
    if (!isInsulatedWire(k) || k == CableKind.fgv) k,
];

Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

class CableTrayPage extends StatefulWidget {
  const CableTrayPage({super.key, this.share = _defaultShare});

  /// 결과 글 보내기(시험에서 바꿔 끼운다).
  final Future<void> Function(String text) share;

  static const draftKey = 'cable_tray_draft_v1';

  @override
  State<CableTrayPage> createState() => _CableTrayPageState();
}

class _CableTrayPageState extends State<CableTrayPage>
    with CalcFormParts<CableTrayPage>, RecentCalcHistoryMixin<CableTrayPage>, ElecTabParts<CableTrayPage> {
  static const int _maxRows = 12;

  TrayStandard _std = TrayStandard.kec;
  TrayType _type = TrayType.ladder;
  double _width = 300;
  double _depth = 100;
  int _marginPct = 20;
  final List<_TrayRow> _rows = [_TrayRow()];
  double _span = 2;
  TrayMount _mount = TrayMount.hanging;
  BendRule _bendRule = BendRule.domestic;
  double _elbow = 300;
  final _trayKg = TextEditingController();
  final _allow = TextEditingController();

  Timer? _saveTimer;
  bool _draftReady = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveNow();
    for (final r in _rows) {
      r.dispose();
    }
    _trayKg.dispose();
    _allow.dispose();
    super.dispose();
  }

  // ── 입력값 남기기 ──

  String _draft() => jsonEncode({
    'std': _std.name,
    't': _type.name,
    'w': _width,
    'd': _depth,
    'm': _marginPct,
    'sp': _span,
    'mt': _mount.name,
    'br': _bendRule.name,
    'el': _elbow,
    'tk': _trayKg.text,
    'al': _allow.text,
    'rows': [for (final r in _rows) r.toJson()],
  });

  Future<void> _loadDraft() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(CableTrayPage.draftKey);
      if (raw != null && mounted) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final t = TrayType.values.where((x) => x.name == m['t']);
        final st = TrayStandard.values.where((x) => x.name == m['std']);
        final rows = [for (final r in (m['rows'] as List? ?? const [])) ?_TrayRow.fromJson(r)];
        setState(() {
          if (t.isNotEmpty) _type = t.first;
          if (st.isNotEmpty) _std = st.first;
          if (m['w'] is num && kTrayWidths.contains((m['w'] as num).toDouble())) _width = (m['w'] as num).toDouble();
          if (m['d'] is num && kTrayDepths.contains((m['d'] as num).toDouble())) _depth = (m['d'] as num).toDouble();
          if (m['m'] is int) _marginPct = m['m'] as int;
          if (m['sp'] is num && kTraySpans.contains((m['sp'] as num).toDouble())) _span = (m['sp'] as num).toDouble();
          if (m['tk'] is String) _trayKg.text = m['tk'] as String;
          final mt = TrayMount.values.where((x) => x.name == m['mt']);
          if (mt.isNotEmpty) _mount = mt.first;
          final br = BendRule.values.where((x) => x.name == m['br']);
          if (br.isNotEmpty) _bendRule = br.first;
          if (m['el'] is num && kTrayElbowRadii.contains((m['el'] as num).toDouble())) _elbow = (m['el'] as num).toDouble();
          if (m['al'] is String) _allow.text = m['al'] as String;
          if (rows.isNotEmpty) {
            for (final r in _rows) {
              r.dispose();
            }
            _rows
              ..clear()
              ..addAll(rows.take(_maxRows));
          }
        });
      }
    } catch (_) {}
    _draftReady = true;
  }

  void _saveSoon() {
    if (!_draftReady) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _saveNow);
  }

  void _saveNow() {
    if (!_draftReady) return;
    final d = _draft();
    SharedPreferences.getInstance().then((p) => p.setString(CableTrayPage.draftKey, d)).catchError((_) => false);
  }

  void _set(VoidCallback f) {
    setState(f);
    _saveSoon();
  }

  // ── 케이블 목록 ──

  /// 입력한 줄을 계산용으로. 가닥 수가 비었거나 0인 줄은 뺀다. 숫자가 잘못된 줄이 있으면 [bad]에 번호.
  (List<TrayCable>, List<int> bad) _cables() {
    final out = <TrayCable>[];
    final bad = <int>[];
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final n = readNum(r.count);
      if (n == null || n == 0) continue;
      if (n < 0 || n != n.roundToDouble()) {
        bad.add(i + 1);
        continue;
      }
      if (r.ams != null) {
        final sp = amsSpec(r.ams!, r.amsN, r.size);
        if (sp == null) {
          bad.add(i + 1);
          continue;
        }
        out.add(TrayCable(
          name: '${amsKindLabel(r.ams!)} ${amsCountLabel(r.ams!, r.amsN)} ${sqText(r.size)}',
          od: sp.od,
          size: r.size,
          cores: amsCores(r.ams!, r.amsN),
          count: n.toInt(),
          control: r.control,
          weight: sp.kg,
          shielded: true,
        ));
      } else if (r.kind != null) {
        final c = TrayCable.fromKind(r.kind!, r.size, n.toInt());
        if (c == null) {
          bad.add(i + 1);
          continue;
        }
        out.add(TrayCable(name: c.name, od: c.od, size: c.size, cores: c.cores, count: c.count, control: r.control, weight: c.weight, shielded: c.shielded));
      } else {
        final od = readNum(r.od), sz = readNum(r.sizeText), co = readNum(r.cores);
        if (od == null || od <= 0 || sz == null || sz <= 0 || co == null || co < 1) {
          bad.add(i + 1);
          continue;
        }
        out.add(TrayCable(
          name: '직접 입력 ${fmt(sz)}sq ${co.round()}심 (외경 ${fmt(od)})',
          od: od,
          size: sz,
          cores: co.round(),
          count: n.toInt(),
          control: r.control,
          weight: readNum(r.weight) != null && readNum(r.weight)! > 0 ? readNum(r.weight) : null,
        ));
      }
    }
    return (out, bad);
  }

  void _addRow() {
    if (_rows.length >= _maxRows) return;
    final last = _rows.last;
    _set(() => _rows.add(_TrayRow(kind: last.kind, ams: last.ams, amsN: last.amsN, size: last.size, control: last.control, n: '1', od: last.od.text, sz: last.sizeText.text, cores: last.cores.text)));
  }

  void _deleteRow(_TrayRow r) {
    final i = _rows.indexOf(r);
    if (i < 0 || _rows.length <= 1) return;
    final copy = _TrayRow.fromJson(r.toJson())!;
    _set(() => _rows.removeAt(i).dispose());
    showDeleteUndo(
      context,
      '${i + 1}번 줄',
      onUndo: () {
        if (!mounted || _rows.length >= _maxRows) return;
        _set(() => _rows.insert(i.clamp(0, _rows.length), copy));
      },
    );
  }

  Widget _numBox(String key, TextEditingController c, String suffix, {double width = 92}) => SizedBox(
    width: width,
    child: TextField(
      key: Key(key),
      controller: c,
      textAlign: TextAlign.right,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: fc.text),
      decoration: InputDecoration(isDense: true, border: InputBorder.none, suffixText: suffix),
      onChanged: (_) => _set(() {}),
    ),
  );

  Widget _rowBox(int i) {
    final r = _rows[i];
    final dropdownStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fc.text);
    return SwipeToDelete(
      itemKey: ObjectKey(r),
      radius: 14,
      enabled: _rows.length > 1,
      onDelete: () => _deleteRow(r),
      child: calcBox(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 번호를 잡고 밀면 지운다(칸을 잡으면 글자 칸이 끌기를 가져간다).
                  SizedBox(
                    width: 26,
                    child: Text('${i + 1}', key: Key('ct_no_$i'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: trayRowColor(i))),
                  ),
                  Expanded(
                    child: DropdownButton<String>(
                      key: Key('ct_kind_$i'),
                      value: r.ams != null ? 'a:${r.ams!.name}' : (r.kind != null ? 'k:${r.kind!.name}' : 'direct'),
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      dropdownColor: fc.surface,
                      style: dropdownStyle,
                      items: [
                        for (final k in kTrayCableKinds) DropdownMenuItem(value: 'k:${k.name}', child: Text(cableKindLabel(k))),
                        for (final a in AmsKind.values) DropdownMenuItem(value: 'a:${a.name}', child: Text(amsKindLabel(a))),
                        const DropdownMenuItem(value: 'direct', child: Text('직접 입력 (외경)')),
                      ],
                      onChanged: (v) => _set(() {
                        if (v == null) return;
                        if (v.startsWith('a:')) {
                          final a = AmsKind.values.firstWhere((x) => 'a:${x.name}' == v);
                          r.ams = a;
                          r.kind = null;
                          if (!amsCounts(a).contains(r.amsN)) r.amsN = amsCounts(a).first;
                          final ss = amsSizes(a, r.amsN);
                          if (!ss.contains(r.size)) r.size = ss.first;
                          r.control = true;
                        } else if (v.startsWith('k:')) {
                          final k = CableKind.values.firstWhere((x) => 'k:${x.name}' == v);
                          r.ams = null;
                          r.kind = k;
                          final ss = cableSizes(k);
                          if (!ss.contains(r.size)) r.size = ss.firstWhere((s) => s >= r.size, orElse: () => ss.last);
                          r.control = cvvsCores(k) != null;
                        } else {
                          r.ams = null;
                          r.kind = null;
                        }
                      }),
                    ),
                  ),
                ],
              ),
              if (r.ams != null)
                Row(
                  children: [
                    const SizedBox(width: 26),
                    SizedBox(
                      width: 78,
                      child: DropdownButton<int>(
                        key: Key('ct_amsn_$i'),
                        value: r.amsN,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        dropdownColor: fc.surface,
                        style: dropdownStyle.copyWith(fontWeight: FontWeight.w600),
                        items: [for (final n in amsCounts(r.ams!)) DropdownMenuItem(value: n, child: Text(amsCountLabel(r.ams!, n)))],
                        onChanged: (n) => _set(() {
                          if (n == null) return;
                          r.amsN = n;
                          final ss = amsSizes(r.ams!, n);
                          if (!ss.contains(r.size)) r.size = ss.first;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<double>(
                        key: Key('ct_size_$i'),
                        value: r.size,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        dropdownColor: fc.surface,
                        style: dropdownStyle.copyWith(fontWeight: FontWeight.w600),
                        items: [
                          for (final s in amsSizes(r.ams!, r.amsN))
                            DropdownMenuItem(value: s, child: Text('${sqText(s)} (외경 ${fmt(amsSpec(r.ams!, r.amsN, s)!.od)})')),
                        ],
                        onChanged: (s) {
                          if (s != null) _set(() => r.size = s);
                        },
                      ),
                    ),
                    _numBox('ct_n_$i', r.count, '가닥', width: 86),
                  ],
                )
              else if (r.kind != null)
                Row(
                  children: [
                    const SizedBox(width: 26),
                    Expanded(
                      child: DropdownButton<double>(
                        key: Key('ct_size_$i'),
                        value: r.size,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        dropdownColor: fc.surface,
                        style: dropdownStyle.copyWith(fontWeight: FontWeight.w600),
                        items: [
                          for (final s in cableSizes(r.kind!))
                            DropdownMenuItem(value: s, child: Text('${sqText(s)} (외경 ${fmt(cableOd(r.kind!, s)!)})')),
                        ],
                        onChanged: (s) {
                          if (s != null) _set(() => r.size = s);
                        },
                      ),
                    ),
                    _numBox('ct_n_$i', r.count, '가닥', width: 86),
                  ],
                )
              else
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    const SizedBox(width: 22),
                    _numBox('ct_od_$i', r.od, 'mm', width: 80),
                    _numBox('ct_sz_$i', r.sizeText, 'sq', width: 76),
                    _numBox('ct_co_$i', r.cores, '심', width: 60),
                    _numBox('ct_n_$i', r.count, '가닥', width: 80),
                    _numBox('ct_wt_$i', r.weight, 'kg/km', width: 112),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.only(left: 26, top: 2),
                child: Wrap(
                  spacing: 6,
                  children: [
                    calcChip('ct_power_$i', '전력용', !r.control, () => _set(() => r.control = false)),
                    calcChip('ct_ctrl_$i', '제어·신호용', r.control, () => _set(() => r.control = true)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(List<TrayCable> cables, TrayCheck check) {
    final lay = layoutTray(cables, _width, _depth, singleLayer: check.singleLayer);
    return Container(
      key: const Key('ct_section'),
      height: 190,
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fc.line),
      ),
      child: CustomPaint(
        painter: TraySectionPainter(
          type: _type,
          width: _width,
          depth: _depth,
          layout: lay,
          text: fc.text,
          sub: fc.textSub,
          line: fc.line,
          bg: fc.background,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  /// 트레이에 모아 깔면 허용전류가 줄어드는 정도(회로 수 보정).
  List<Widget> _derating(List<TrayCable> cables, TrayCheck check) {
    final n = trayCircuits(cables);
    if (n <= 1) return const [];
    final lay = layoutTray(cables, _width, _depth, singleLayer: check.singleLayer);
    final oneRow = lay.dots.every((d) => (d.y - d.r).abs() < 1e-6);
    final layout = trayGroupLayout(_type, oneRow: oneRow);
    final f = trayGroupFactor(_type, cables, oneRow: oneRow);
    final how = oneRow ? '${trayTypeLabel(_type)}에 한 줄로 나란히' : '겹쳐 쌓음(묶음)';
    return [
      const SizedBox(height: 12),
      calcResult(
        key: const Key('ct_derate'),
        big: '× ${f.toStringAsFixed(2)}',
        caption: '허용전류 보정 · 전력 회로 $n개 · $how',
        warn: f < 0.8,
        lines: [
          '각 케이블의 허용전류에 ${f.toStringAsFixed(2)}를 곱해 굵기를 다시 확인하십시오.',
          '회로 수: 전력용 다심은 한 가닥이 한 회로, 전력용 단심은 3가닥이 한 회로로 셌습니다. 제어·신호는 뺐습니다.',
          'IEC 60364-5-52 표 B.52.17 ${layout == GroupLayout.bunched ? '1행(겹쳐 쌓음)' : '한 줄 행'}. 전기 설계 계산의 "전선 굵기" 탭에서 회로 수 $n개로 넣으면 같은 보정이 들어갑니다.',
          if (!oneRow) '한 줄로 펴서 포설하면 허용전류가 덜 줄어듭니다(넓은 트레이 필요).',
        ],
      ),
    ];
  }

  /// 곡률(굽힘) 반경: 가장 굵은(배수 큰) 케이블의 최소 굽힘 반경을 엘보 반경과 견준다.
  List<Widget> _bendSection(List<TrayCable> cables) {
    final mb = maxBend(cables, _bendRule);
    if (mb == null) return const [];
    final (need, worst) = mb;
    final ok = _elbow >= need - 1e-9;
    final fit = elbowFor(need);
    final f = bendFactor(worst, _bendRule);
    return [
      const SizedBox(height: 16),
      elecSectionTitle('최소 굽힘 반경'),
      elecChipGroup(
        '굽힘 반경 기준',
        '국내 시방서: 다심 외경의 6배, 단심 8배(서울시 SMCS·KRCCS·나라장터 시방서 등). 차폐 제어·AMS 케이블은 국내 규정이 없어 제조사 값 12배를 씁니다. '
            '제조사: 넥상스코리아 제품 자료의 12배(TFR-CV·TFR-CVV-S·TFR-CVV-AMS). KEC는 굽힘 반경 수치를 정하지 않고, 굽은 부분이 손상·응력을 받지 않는 반지름으로 하라고만 합니다(232.4.8의 4).',
        [for (final r in BendRule.values) calcChip('ct_br_${r.name}', bendRuleLabel(r), _bendRule == r, () => _set(() => _bendRule = r))],
      ),
      elecChipGroup(
        '엘보(곡관) 반경 (mm)',
        '트레이 수평·수직 엘보의 반경입니다. 흔히 300·600·900mm(LH 시방서 300 이상, 제조사 300·600·900).',
        [for (final e in kTrayElbowRadii) calcChip('ct_el_${e.toInt()}', fmt(e), _elbow == e, () => _set(() => _elbow = e))],
      ),
      calcResult(
        key: const Key('ct_bend'),
        big: 'R ${fmt(need, 0)} mm',
        caption: '최소 굽힘 반경 · 엘보 R${fmt(_elbow)} ${ok ? '합격' : '불합격'}',
        warn: !ok,
        lines: [
          '가장 큰 것: ${worst.name} 외경 ${fmt(worst.od)}mm × ${fmt(f.$1)} (${f.$2})',
          ok
              ? '엘보 R${fmt(_elbow)}로 굽힐 수 있습니다(최소 굽힘 반경 이상).'
              : fit == null
              ? 'R900 엘보로도 부족합니다. 더 큰 반경으로 돌리거나 굵은 케이블은 따로 돌리십시오.'
              : 'R${fmt(fit)} 이상 엘보를 쓰십시오.',
          for (final c in cables)
            if (c.count > 0) '${c.name}: R ${fmt(bendRadius(c, _bendRule), 0)}mm (${bendFactor(c, _bendRule).$2})',
          '반경은 케이블 안쪽 면 기준으로 보는 것이 보통입니다(ICEA). 국내 시방서는 기준점을 적지 않았습니다.',
        ],
      ),
    ];
  }

  /// 하중: 케이블 무게 + 트레이 자중을 지지 간격별 허용 하중과 견준다.
  List<Widget> _loadSection(List<TrayCable> cables) {
    final tray = readNum(_trayKg);
    final allow = readNum(_allow);
    final spans = trayMountSpans(_mount);
    final l = trayLoad(
      cables: cables,
      trayKgM: tray != null && tray > 0 ? tray : 0,
      span: _span,
      allowKgM: spans && allow != null && allow > 0 ? allow : null,
      margin: _marginPct / 100,
    );
    final ok = l.ok;
    return [
      const SizedBox(height: 16),
      elecSectionTitle('하중'),
      elecChipGroup(
        '설치 방법',
        '매달기·브래킷·받침대 위는 지지점 사이가 떠 있어 지지 간격과 허용 하중을 계산합니다. 바닥에 직접 설치하면 바닥이 받쳐 주므로 이 계산은 하지 않고 1m당 중량만 계산합니다.',
        [for (final mt in TrayMount.values) calcChip('ct_mt_${mt.name}', trayMountLabel(mt), _mount == mt, () => _set(() => _mount = mt))],
      ),
      if (trayMountSpans(_mount)) ...[
        elecChipGroup(
          _mount == TrayMount.stand ? '받침대 간격 (m)' : '지지 간격 (m)',
          '지지점 사이 거리입니다. 시방서마다 다릅니다(보통 2m 이하, 변전실 1.5m, 찬넬 3m).',
          [for (final sp in kTraySpans) calcChip('ct_sp_${sp.toString()}', '${fmt(sp)}m', _span == sp, () => _set(() => _span = sp))],
        ),
      ],
      elecField('ct_traykg', '트레이 자중 (kg/m)', _trayKg, '트레이 1m 중량입니다. 제조사 카탈로그 값을 넣습니다(예: 대양엔지니어링 사다리형 300폭 H100 가로대 300mm, 2.6t 7.0kg/m. 한 곳 자료). 지지점 하중에만 들어가고, 허용 하중 판정은 케이블 하중으로 합니다. 비우면 0으로 봅니다.', onEdit: _saveSoon),
      if (trayMountSpans(_mount))
        elecField('ct_allow', '허용 하중 (kg/m)', _allow, '제조사 카탈로그에서 이 지지 간격의 등분포 허용(사용) 하중입니다. 케이블만의 하중 기준(트레이 자중 제외)이라 케이블 하중과 비교합니다. NEMA VE-1·IEC 61537 기준 값은 안전율(1.5 이상)이 이미 들어 있어 그대로 넣고, KS 정하중이나 파괴 하중만 있으면 1.5로 나눠 넣으십시오(KEC 232.41.2 1호 안전율 1.5).', onEdit: _saveSoon),
      calcResult(
        key: const Key('ct_load'),
        big: '${fmt(l.totalKgM, 1)} kg/m',
        caption: !spans
            ? '트레이 1m당 중량 · 바닥에 직접 설치'
            : ok == null
            ? '트레이 1m당 하중 · 허용 하중을 넣으면 판정합니다'
            : '트레이 1m당 하중 · ${ok ? '합격' : '불합격'} ${fmt(l.pct!, 0)}%',
        warn: ok == false || l.missing.isNotEmpty,
        lines: [
          '케이블 ${fmt(l.cableKgM, 1)} kg/m${_marginPct > 0 ? ' (예비 여유 $_marginPct% 포함)' : ''} + 트레이 자중 ${fmt(l.trayKgM, 1)} kg/m',
          if (spans)
            '지지점 하나가 받는 하중 약 ${fmt(l.perSupportKg, 0)} kg (1m당 하중 × ${_mount == TrayMount.stand ? '받침대' : '지지'} 간격 ${fmt(_span)}m). ${_mount == TrayMount.stand ? '받침대' : '행거·앵커'} 선정에 씁니다.'
          else
            '바닥이 계속 받쳐 지지 간격·허용 하중 판정은 하지 않습니다. 바닥(슬래브·트렌치) 허용 하중 확인에 1m당 중량을 쓰십시오.',
          if (ok != null)
            ok
                ? '케이블 하중 ${fmt(l.cableKgM, 1)} kg/m가 허용 하중 ${fmt(l.allowKgM!, 1)} kg/m 이내입니다.'
                : '케이블 하중 ${fmt(l.cableKgM, 1)} kg/m가 허용 하중 ${fmt(l.allowKgM!, 1)} kg/m를 초과합니다. 지지 간격을 줄이거나 허용 하중이 큰 트레이로 선정하십시오.',
          if (spanWarning(_mount, _span) != null) spanWarning(_mount, _span)!,
          if (spans) '케이블 결속: 수평은 2m 이내마다 케이블타이(국내 시방서). 수평이 아닌 곳은 가로대에 단단히 고정(KEC 232.41.1 4호), 수직 간격은 국내 규정이 없습니다(NEMA VE 2는 약 450mm 권고).',
          if (!spans) ...kFloorTrayNotes,
          if (l.missing.isNotEmpty) '중량을 몰라 빠진 케이블: ${l.missing.join(', ')}. 직접 입력 줄에 kg/km를 넣으면 들어갑니다.',
          cableWeightSource,
        ],
      ),
    ];
  }

  /// 카톡으로 보내는 글.
  String _shareText(List<TrayCable> cables, TrayCheck check, TraySizing? sizing) {
    final b = StringBuffer('[케이블 트레이] ${trayTypeLabel(_type)} 폭 ${trayNum(_width)} × 깊이 ${trayNum(_depth)}mm');
    b.write('\n기준: ${trayStandardLabel(_std)}');
    b.write('\n판정: ${check.ok ? '합격' : '불합격'} (${fmt(check.pct, 0)}%)');
    final best = sizing?.minWidth;
    b.write(best == null ? '\n권장 폭: 표준 폭 안에 없음' : '\n권장 폭: ${trayNum(best)}mm');
    if (_marginPct > 0) b.write(' (예비 여유 $_marginPct%)');
    b.write('\n규칙: ${trayRuleLabel(check.rule)}');
    b.write('\n계산: ${check.formula}');
    b.write('\n케이블:');
    for (var i = 0; i < cables.length; i++) {
      final c = cables[i];
      b.write('\n ${i + 1}. ${c.name} × ${c.count}가닥${c.control ? ' (제어·신호)' : ''}');
    }
    b.write(_std == TrayStandard.kec ? '\n근거: KEC 232.41.1 6~9호' : '\n근거: 구 전기설비기술기준의 판단기준 제213조의2(참고)');
    return b.toString();
  }

  // ── 화면 ──

  @override
  Widget build(BuildContext context) {
    final (cables, bad) = _cables();
    final margin = _marginPct / 100;
    final check = cables.isEmpty
        ? null
        : checkTray(type: _type, width: _width, depth: _depth, cables: cables, margin: margin, standard: _std);
    final sizing = cables.isEmpty
        ? null
        : sizeTray(type: _type, depth: _depth, cables: cables, margin: margin, standard: _std);
    String? summary;
    Widget result;
    if (check == null) {
      result = calcResult(
        key: const Key('ct_result'),
        big: '— %',
        caption: '케이블 가닥 수를 넣으면 판정합니다',
        lines: [if (bad.isNotEmpty) '${bad.join(', ')}번 줄의 숫자를 확인하십시오.'],
      );
    } else {
      final best = sizing?.minWidth;
      final ok = check.ok;
      summary = [
        '${trayTypeLabel(_type)} ${fmt(_width)} ${ok ? '합격' : '불합격'} ${fmt(check.pct, 0)}%',
        best == null ? '맞는 폭 없음' : '권장 폭 ${fmt(best)}',
      ].join(' · ');
      final unit = check.byDia ? 'mm' : 'mm²';
      result = calcResult(
        key: const Key('ct_result'),
        big: '${fmt(check.pct, 0)} %',
        caption: '${trayTypeLabel(_type)} 폭 ${fmt(_width)} × 깊이 ${fmt(_depth)}mm · ${ok ? '합격' : '불합격'}',
        warn: !ok,
        lines: [
          ok
              ? '한도 이내입니다 (${trayNum(check.used)} / ${trayNum(check.limit)} $unit).'
              : '한도를 초과합니다 (${trayNum(check.used)} / ${trayNum(check.limit)} $unit). ${best == null ? '표준 폭 안에 맞는 폭이 없습니다. 트레이를 나누십시오.' : '폭 ${fmt(best)}mm 이상으로 선정하십시오.'}',
          if (ok && best != null && best < _width) '더 좁은 폭 ${fmt(best)}mm도 됩니다.',
          trayRuleLabel(check.rule),
          check.formula,
          ...check.notes,
          if (_std == TrayStandard.kec) '이격: 벽면 20mm·트레이 위아래 300mm 이상(좁으면 허용전류 저감). 자세한 것은 근거 보기.',
          if (bad.isNotEmpty) '${bad.join(', ')}번 줄은 숫자가 잘못되어 뺐습니다.',
        ],
      );
    }

    final children = <Widget>[
      elecChipGroup(
        '판정 기준',
        'KEC 232.41(현행): 트레이 종류·다심·단심을 가리지 않고 케이블 외경 합 ≤ 내측 폭, 한 층입니다. '
            '구 판단기준(제213조의2)은 2021년 KEC 전의 점유면적 표·비율 규정으로, 비교용 참고입니다.',
        [for (final t in TrayStandard.values) calcChip('ct_std_${t.name}', trayStandardLabel(t), _std == t, () => _set(() => _std = t))],
      ),
      elecChipGroup(
        '트레이 종류',
        _std == TrayStandard.kec
            ? 'KEC에서는 종류와 관계없이 같은 규칙입니다(허용전류 보정에만 영향).'
            : '구 기준: 사다리형·펀칭형·그물망형은 통풍이 되는 표(넓은 한도), 바닥밀폐형은 더 작은 표를 씁니다.',
        [for (final t in TrayType.values) calcChip('ct_type_${t.name}', trayTypeLabel(t), _type == t, () => _set(() => _type = t))],
      ),
      elecChipGroup(
        '트레이 폭 (mm)',
        '지금 트레이(또는 검토할 폭)의 내측 폭입니다. 표에 있는 폭은 150·300·450·600·750·900이고, 그 밖의 폭은 비례로 계산합니다.',
        [for (final w in kTrayWidths) calcChip('ct_w_${w.toInt()}', fmt(w), _width == w, () => _set(() => _width = w))],
      ),
      elecChipGroup(
        '내측 깊이 (mm)',
        '측판 높이(케이블이 들어가는 깊이)입니다. 제어·신호 케이블만 넣을 때 쓰입니다(150mm 이하).',
        [for (final d in kTrayDepths) calcChip('ct_d_${d.toInt()}', fmt(d), _depth == d, () => _set(() => _depth = d))],
      ),
      elecChipGroup(
        '예비 여유',
        '나중에 추가할 케이블을 위한 여유입니다. 사용량에 (1 + 여유)를 곱해 판정합니다. KEC에는 여유 기준이 없고 설계 관례입니다.',
        [for (final m in const [0, 10, 20, 30]) calcChip('ct_m_$m', '$m%', _marginPct == m, () => _set(() => _marginPct = m))],
      ),
      elecSectionTitle('케이블 목록'),
      for (var i = 0; i < _rows.length; i++) _rowBox(i),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('ct_add'),
          onPressed: _rows.length >= _maxRows ? null : _addRow,
          icon: const Icon(Icons.add_rounded),
          label: const Text('케이블 줄 추가', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
      if (_rows.length > 1)
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Text('지울 줄은 번호를 잡고 왼쪽으로 끝까지 미십시오.', style: TextStyle(fontSize: 12, color: fc.textSub)),
        ),
      const SizedBox(height: 8),
      result,
      if (check != null) ...[
        const SizedBox(height: 12),
        calcLabel('단면 그림', '케이블을 실제 외경 비율로 굵은 것부터 바닥에 포설한 모양으로 그린 그림입니다. 원 안 숫자는 목록의 줄 번호, 빨간 테두리는 폭이나 깊이를 벗어난 가닥입니다. 판정은 위 결과를 따릅니다.'),
        const SizedBox(height: 4),
        _section(cables, check),
      ],
      if (sizing != null) ...[
        const SizedBox(height: 12),
        calcLabel('폭별 판정', '같은 케이블을 표준 폭마다 계산한 사용률입니다. 누르면 그 폭으로 바꿉니다.'),
        const SizedBox(height: 4),
        Wrap(
          key: const Key('ct_widths'),
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (w, c) in sizing.rows)
              calcChip('ct_wr_${w.toInt()}', '${fmt(w)} · ${fmt(c.pct, 0)}%${c.ok ? '' : ' ✕'}', _width == w, () => _set(() => _width = w)),
          ],
        ),
      ],
      if (check != null) ..._derating(cables, check),
      if (check != null) ..._bendSection(cables),
      if (check != null) ..._loadSection(cables),
      const SizedBox(height: 12),
      elecBasis('ct_basis', [
        if (_std == TrayStandard.kec) ...[
          'KEC 232.41.1 6~9호(수평·수직, 다심·단심): 케이블 외경 합 ≤ 트레이 내측 폭, 한 층으로 시설. 점유면적 표·비율 규정은 없습니다.',
          ...kKecSpacingNotes,
          '허용전류 저감계수: KS C IEC 60364-5-52 표 B.52.17(여러 단이면 B.52.20·B.52.21).',
          '확인: 산업부 공고 2022-809·2023-563, 기후에너지환경부 공고 2025-198 신구조문, cq4l KEC 조문. 2026-01-05 시행본(2025-227)에서 트레이 조문은 바뀌지 않았습니다.',
        ] else ...[
          '구 판단기준 제213조의2(2021년 KEC 전, 참고용). 케이블 단면적은 완성품 외경으로 π/4 × 외경².',
          '다심 100mm² 이상만: 외경 합 ≤ 내측 폭(바닥밀폐형 90%), 한 층.',
          '다심 100mm² 미만만: 단면적 합 ≤ 표(사다리·통풍 150 4,510 / 300 9,030 / 450 13,540 / 600 18,060 / 750 22,580 / 900 27,090mm², 바닥밀폐 3,540 / 7,090 / 10,640 / 14,190 / 17,740 / 21,290mm²).',
          '다심 섞임: 작은 케이블 단면적 합 ≤ 표 − 30.5(바닥밀폐 25.4) × 100mm² 이상 외경 합. 굵은 케이블은 한 층, 위에 얹지 않음.',
          '제어·신호 다심만(깊이 150mm 이하, 초과하면 150으로): 단면적 합 ≤ 트레이 내 단면적의 50%(바닥밀폐 40%).',
          '단심 500mm² 이상만: 외경 합 ≤ 폭. 100~500mm²만: 단면적 합 ≤ 표(150 4,190 / 300 8,380 / 450 12,580 / 600 16,770 / 750 20,960 / 900 25,160mm²). 섞임: 표 − 28 × 500mm² 이상 외경 합. 50~100mm²가 있으면 외경 합 ≤ 폭, 한 층.',
          '다심·단심을 함께 넣으면 다심 규정과 단심 규정을 각각 만족(8호).',
          '표 값: 판단기준 해설 자료(jungi.net)·eom 조문·KRCCS 시방서가 같고, 미국 NEC 392.22를 mm로 바꾼 값과 같습니다. 해설 자료 계산 예 7개로 맞춰 봤습니다. 표에 없는 폭은 비례로 계산했습니다(규정 문구 아님).',
        ],
        cableOdSource,
      ]),
    ];

    return FieldViewTheme(
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: fc.background,
          appBar: AppBar(
            backgroundColor: fc.surface,
            foregroundColor: fc.text,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text('케이블 트레이 계산기', style: TextStyle(fontWeight: FontWeight.w800, color: fc.text)),
            actions: [
              if (check != null)
                IconButton(
                  key: const Key('ct_share'),
                  tooltip: '카톡으로 보내기',
                  icon: Icon(Icons.share_outlined, color: fc.text),
                  onPressed: () => widget.share(_shareText(cables, check, sizing)),
                ),
              calcHistoryButton(),
            ],
          ),
          body: elecPage(children, sumKey: 'ct_sum', summary: summary, warn: check != null && !check.ok),
        ),
      ),
    );
  }
}
