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
import 'cable_tray.dart';
import 'conduit_tables.dart';
import 'elec_calc.dart' show sqText;
import 'elec_form_parts.dart';

/// 케이블 한 줄 입력. [kind]가 null이면 직접 입력(외경·굵기·심 수).
class _TrayRow {
  CableKind? kind;
  double size;
  bool control;
  final TextEditingController count;
  final TextEditingController od;
  final TextEditingController sizeText;
  final TextEditingController cores;
  _TrayRow({this.kind = CableKind.fcv4, this.size = 35, this.control = false, String n = '1', String od = '', String sz = '', String cores = '1'})
      : count = TextEditingController(text: n),
        od = TextEditingController(text: od),
        sizeText = TextEditingController(text: sz),
        cores = TextEditingController(text: cores);

  void dispose() {
    count.dispose();
    od.dispose();
    sizeText.dispose();
    cores.dispose();
  }

  Map<String, Object?> toJson() => {
    'k': kind?.name,
    's': size,
    'c': control,
    'n': count.text,
    'od': od.text,
    'sz': sizeText.text,
    'co': cores.text,
  };

  static _TrayRow? fromJson(Object? m) {
    if (m is! Map) return null;
    final k = CableKind.values.where((c) => c.name == m['k']);
    final s = m['s'];
    final row = _TrayRow(
      kind: k.isEmpty ? null : k.first,
      size: s is num ? s.toDouble() : 35,
      control: m['c'] == true,
      n: '${m['n'] ?? '1'}',
      od: '${m['od'] ?? ''}',
      sz: '${m['sz'] ?? ''}',
      cores: '${m['co'] ?? '1'}',
    );
    if (row.kind != null && !cableSizes(row.kind!).contains(row.size)) {
      row.size = cableSizes(row.kind!).first;
    }
    return row;
  }
}

/// 트레이에 넣는 케이블로 고를 수 있는 것: 케이블과 트레이용 접지선(F-GV).
/// HFIX·IV·HIV 같은 시스 없는 절연전선은 트레이에 그대로 깔지 않는다.
final List<CableKind> kTrayCableKinds = [
  for (final k in CableKind.values)
    if (!isInsulatedWire(k) || k == CableKind.fgv) k,
];

class CableTrayPage extends StatefulWidget {
  const CableTrayPage({super.key});

  static const draftKey = 'cable_tray_draft_v1';

  @override
  State<CableTrayPage> createState() => _CableTrayPageState();
}

class _CableTrayPageState extends State<CableTrayPage>
    with CalcFormParts<CableTrayPage>, RecentCalcHistoryMixin<CableTrayPage>, ElecTabParts<CableTrayPage> {
  static const int _maxRows = 12;

  TrayType _type = TrayType.ladder;
  double _width = 300;
  double _depth = 100;
  int _marginPct = 20;
  final List<_TrayRow> _rows = [_TrayRow()];

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
    super.dispose();
  }

  // ── 입력값 남기기 ──

  String _draft() => jsonEncode({
    't': _type.name,
    'w': _width,
    'd': _depth,
    'm': _marginPct,
    'rows': [for (final r in _rows) r.toJson()],
  });

  Future<void> _loadDraft() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(CableTrayPage.draftKey);
      if (raw != null && mounted) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final t = TrayType.values.where((x) => x.name == m['t']);
        final rows = [for (final r in (m['rows'] as List? ?? const [])) ?_TrayRow.fromJson(r)];
        setState(() {
          if (t.isNotEmpty) _type = t.first;
          if (m['w'] is num && kTrayWidths.contains((m['w'] as num).toDouble())) _width = (m['w'] as num).toDouble();
          if (m['d'] is num && kTrayDepths.contains((m['d'] as num).toDouble())) _depth = (m['d'] as num).toDouble();
          if (m['m'] is int) _marginPct = m['m'] as int;
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
      if (r.kind != null) {
        final c = TrayCable.fromKind(r.kind!, r.size, n.toInt());
        if (c == null) {
          bad.add(i + 1);
          continue;
        }
        out.add(TrayCable(name: c.name, od: c.od, size: c.size, cores: c.cores, count: c.count, control: r.control));
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
        ));
      }
    }
    return (out, bad);
  }

  void _addRow() {
    if (_rows.length >= _maxRows) return;
    final last = _rows.last;
    _set(() => _rows.add(_TrayRow(kind: last.kind, size: last.size, control: last.control, n: '1', od: last.od.text, sz: last.sizeText.text, cores: last.cores.text)));
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
                    child: Text('${i + 1}', key: Key('ct_no_$i'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: fc.textSub)),
                  ),
                  Expanded(
                    child: DropdownButton<CableKind?>(
                      key: Key('ct_kind_$i'),
                      value: r.kind,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      dropdownColor: fc.surface,
                      style: dropdownStyle,
                      items: [
                        for (final k in kTrayCableKinds) DropdownMenuItem(value: k, child: Text(cableKindLabel(k))),
                        const DropdownMenuItem(value: null, child: Text('직접 입력 (외경)')),
                      ],
                      onChanged: (k) => _set(() {
                        r.kind = k;
                        if (k != null) {
                          final ss = cableSizes(k);
                          if (!ss.contains(r.size)) r.size = ss.firstWhere((s) => s >= r.size, orElse: () => ss.last);
                          r.control = cvvsCores(k) != null;
                        }
                      }),
                    ),
                  ),
                ],
              ),
              if (r.kind != null)
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

  // ── 화면 ──

  @override
  Widget build(BuildContext context) {
    final (cables, bad) = _cables();
    final margin = _marginPct / 100;
    final check = cables.isEmpty
        ? null
        : checkTray(type: _type, width: _width, depth: _depth, cables: cables, margin: margin);
    final sizing = cables.isEmpty
        ? null
        : sizeTray(type: _type, depth: _depth, cables: cables, margin: margin);
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
              ? '한도 안입니다 (${fmt(check.used, 0)} / ${fmt(check.limit, 0)} $unit).'
              : '한도를 넘습니다 (${fmt(check.used, 0)} / ${fmt(check.limit, 0)} $unit). ${best == null ? '표준 폭 안에 맞는 폭이 없습니다. 트레이를 나누십시오.' : '폭 ${fmt(best)}mm 이상으로 선정하십시오.'}',
          if (ok && best != null && best < _width) '더 좁은 폭 ${fmt(best)}mm도 됩니다.',
          trayRuleLabel(check.rule),
          check.formula,
          ...check.notes,
          if (bad.isNotEmpty) '${bad.join(', ')}번 줄은 숫자가 잘못되어 뺐습니다.',
        ],
      );
    }

    final children = <Widget>[
      elecChipGroup(
        '트레이 종류',
        '사다리형·펀칭형·메시형은 통풍이 되는 표(넓은 한도), 바닥밀폐형은 더 작은 표를 씁니다.',
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
        '나중에 더 넣을 케이블 몫입니다. 쓴 양에 (1 + 여유)를 곱해 판정합니다. KEC에는 여유 기준이 없고 설계 관례입니다.',
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
          label: const Text('케이블 줄 더하기', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
      if (_rows.length > 1)
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Text('줄 번호를 잡고 왼쪽으로 밀면 지웁니다', style: TextStyle(fontSize: 12, color: fc.textSub)),
        ),
      const SizedBox(height: 8),
      result,
      if (sizing != null) ...[
        const SizedBox(height: 12),
        calcLabel('폭별 판정', '같은 케이블로 표준 폭마다 본 사용률입니다. 누르면 그 폭으로 바꿉니다.'),
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
      const SizedBox(height: 12),
      elecBasis('ct_basis', [
        'KEC 232.41 케이블트레이공사(옛 판단기준 제213조의2). 케이블 단면적은 완성품 외경으로 π/4 × 외경².',
        '다심 100mm² 이상만: 외경 합 ≤ 트레이 내측 폭, 한 층으로.',
        '다심 100mm² 미만만: 단면적 합 ≤ 표(사다리·통풍 150 4,510 / 300 9,030 / 450 13,540 / 600 18,060 / 750 22,580 / 900 27,090mm², 바닥밀폐 3,540 / 7,090 / 10,640 / 14,190 / 17,740 / 21,290mm²).',
        '다심 섞임: 작은 케이블 단면적 합 ≤ 표 − 30.5(바닥밀폐 25.4) × 100mm² 이상 외경 합.',
        '제어·신호 다심만(깊이 150mm 이하): 단면적 합 ≤ 트레이 내 단면적의 50%(바닥밀폐 40%).',
        '단심 500mm² 이상만: 외경 합 ≤ 폭. 100~500mm²만: 단면적 합 ≤ 표(150 4,190 / 300 8,380 / 450 12,580 / 600 16,770 / 750 20,960 / 900 25,160mm²). 섞임: 표 − 28 × 500mm² 이상 외경 합.',
        '단심 100mm² 미만이 있거나 다심·단심을 함께 넣으면: 모두 한 층, 외경 합 ≤ 폭.',
        '표 값은 판단기준 해설 자료(jungi.net)에서 옮겼고, 미국 NEC 392.22를 mm로 바꾼 값과 같습니다. 같은 자료의 계산 예 7개로 맞춰 봤습니다.',
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
            actions: [calcHistoryButton()],
          ),
          body: elecPage(children, sumKey: 'ct_sum', summary: summary, warn: check != null && !check.ok),
        ),
      ),
    );
  }
}
