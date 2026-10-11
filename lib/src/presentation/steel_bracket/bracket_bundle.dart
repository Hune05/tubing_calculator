// 형강 브라켓 묶음(10-11, 상용 앱 비교 16번): 한 현장에서 만들 브라켓 여러 종류(ㄱ자 10개 + 문형 4개처럼)를 모아
// 규격별 자를 것·원자재 본수·무게를 합치고, 지시서 한 번·형강 컷팅 작업 하나로 보낸다. 저장은 이 기기만.
//  · 줄: 이름, 개수(세트), 입력 지도(bracket_form.dart). 줄을 누르면 그 브라켓을 화면으로 불러온다.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/app_components.dart'
    show AppSnackKind, showAppConfirm, showAppSnack;
import '../../core/common_widgets/swipe_to_delete.dart';
import '../../core/theme/field_view.dart';
import '../steel_cutting/screens/steel_cutting_detail_screen.dart';
import '../steel_plate/plate_ui.dart';
import '../tube_cutting/cutting_optimizer.dart';
import 'bracket_calc.dart';
import 'bracket_export.dart';
import 'bracket_form.dart';
import 'bracket_painter.dart';
import 'bracket_pdf.dart';
import 'bracket_settings.dart';

const String kBracketBundleKey = 'steel_bracket_bundle_v1';

class BracketBundleEntry {
  final String id;
  final String name;
  final int qty;
  final Map<String, dynamic> map;
  const BracketBundleEntry({
    required this.id,
    required this.name,
    required this.qty,
    required this.map,
  });

  BracketBundleEntry withQty(int q) =>
      BracketBundleEntry(id: id, name: name, qty: q, map: map);
  BracketBundleEntry withName(String n) =>
      BracketBundleEntry(id: id, name: n, qty: qty, map: map);

  /// 화면으로 불러올 지도: 묶음에서 바꾼 개수까지(점검 40).
  Map<String, dynamic> get loadMap => {...map, 'n': '$qty'};

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'qty': qty,
    'map': map,
  };

  static BracketBundleEntry? fromJson(Object? o) {
    if (o is! Map || o['map'] is! Map) return null;
    final q = o['qty'];
    return BracketBundleEntry(
      id: '${o['id'] ?? DateTime.now().microsecondsSinceEpoch}',
      name: '${o['name'] ?? ''}',
      qty: q is int && q > 0 ? q : 1,
      map: Map<String, dynamic>.from(o['map'] as Map),
    );
  }

  /// 이 줄 개수로 계산.
  BracketPlan plan(BracketSettings s) => bracketPlan(
    bracketInputFromMap(
      {...bracketUpgradeMap(map), 'n': '$qty'},
      stock: s.stock,
      kerf: s.kerf,
    ),
  );
}

Future<List<BracketBundleEntry>> readBracketBundle() async {
  try {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(kBracketBundleKey);
    if (raw == null) return [];
    final list = jsonDecode(raw);
    if (list is! List) return [];
    return [for (final o in list) ?BracketBundleEntry.fromJson(o)];
  } catch (_) {
    return [];
  }
}

Future<void> writeBracketBundle(List<BracketBundleEntry> list) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      kBracketBundleKey,
      jsonEncode([for (final e in list) e.toJson()]),
    );
  } catch (_) {}
}

/// 묶음 합: 규격 → (길이 → 개수), 규격별 원자재, 판 줄, 무게.
class BracketBundleTotal {
  final Map<String, Map<double, int>> cuts;
  final Map<String, CuttingOptimizationResult> stock;
  final List<String> plates;
  final double kg;
  final bool kgKnown;
  const BracketBundleTotal(
    this.cuts,
    this.stock,
    this.plates,
    this.kg,
    this.kgKnown,
  );
}

BracketBundleTotal bracketBundleTotal(
  List<BracketBundleEntry> list,
  BracketSettings s,
) {
  final cuts = <String, Map<double, int>>{};
  final plates = <String, int>{};
  var kg = 0.0;
  var known = true;
  for (final e in list) {
    final p = e.plan(s);
    kg += p.kgTotal;
    known &= p.weightKnown;
    for (final pc in p.pieces) {
      if (pc.kind == BracketPieceKind.member ||
          pc.kind == BracketPieceKind.rod) {
        final m = cuts.putIfAbsent(pc.spec, () => {});
        final l = double.parse(pc.length.toStringAsFixed(1));
        m[l] = (m[l] ?? 0) + pc.qty * e.qty;
      } else {
        plates[pc.ks] = (plates[pc.ks] ?? 0) + pc.qty * e.qty;
      }
    }
  }
  final stock = <String, CuttingOptimizationResult>{};
  if (s.stock > 0) {
    for (final e in cuts.entries) {
      if (e.key.startsWith('전산볼트')) continue;
      stock[e.key] = optimizeCutting(
        pieces: [
          for (final l in e.value.entries)
            for (var k = 0; k < l.value; k++) l.key,
        ],
        stockLength: s.stock,
        kerf: s.kerf,
      );
    }
  }
  return BracketBundleTotal(
    cuts,
    stock,
    [for (final e in plates.entries) '${e.key} × ${e.value}장'],
    kg,
    known,
  );
}

String _f(double v, [int d = 1]) {
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  return s;
}

/// 묶음 화면. 줄을 누르면 그 입력 지도를 돌려준다(편집 화면이 불러옴).
class BracketBundlePage extends StatefulWidget {
  const BracketBundlePage({super.key, this.createProject});

  /// 형강 컷팅 작업 만들기(시험에서 바꿔 끼운다).
  final BracketProjectCreator? createProject;

  @override
  State<BracketBundlePage> createState() => _BracketBundlePageState();
}

class _BracketBundlePageState extends State<BracketBundlePage> {
  List<BracketBundleEntry> _list = [];
  BracketSettings _s = BracketSettings.defaults;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await readBracketBundle();
    final s = await BracketSettings.load();
    if (!mounted) return;
    setState(() {
      _list = l;
      _s = s;
      _ready = true;
    });
  }

  void _save(List<BracketBundleEntry> l) {
    setState(() => _list = l);
    writeBracketBundle(l);
  }

  void _remove(BracketBundleEntry e) {
    final before = List.of(_list);
    final at = before.indexOf(e);
    _save([..._list]..remove(e));
    showAppSnack(
      context,
      '"${e.name}"을 묶음에서 뺐습니다.',
      kind: AppSnackKind.undo,
      onUndo: () {
        if (!mounted) return;
        final l = List.of(_list)..insert(at.clamp(0, _list.length), e);
        _save(l);
      },
    );
  }

  // 줄 이름 바꾸기(점검 46: 넣을 때 작업 이름 그대로라 같은 이름이 여럿 생겼다)
  Future<void> _rename(BracketBundleEntry e) async {
    final r = await showPlateSheet<String>(
      context,
      (_) => _RenameSheet(name: e.name),
    );
    if (r == null || r.isEmpty || r == e.name || !mounted) return;
    _save([for (final x in _list) x.id == e.id ? x.withName(r) : x]);
  }

  Future<void> _pdf() async {
    if (_list.isEmpty) return;
    final t = bracketBundleTotal(_list, _s);
    final plans = [for (final e in _list) (e, e.plan(_s))];
    await openBracketPdf(context, () async {
      final pngs = <(String, dynamic)>[];
      for (final (e, p) in plans) {
        pngs.add((
          '${e.name} × ${e.qty}개 (${bracketSummaryOf(bracketUpgradeMap(e.map))})',
          await renderBracketPng(p.drawing),
        ));
      }
      return BracketPdfInput(
        title: '브라켓 ${_list.length}종',
        docTitle: '형강 브라켓 묶음 지시서',
        summary: [
          ('브라켓', '${_list.length}종 · ${_list.fold(0, (s, e) => s + e.qty)}개'),
          ('무게', '약 ${_f(t.kg)}kg${t.kgKnown ? '' : ' 이상'}'),
          ('공차', _s.tolerance),
        ],
        drawingCaption: pngs.first.$1,
        drawingPng: pngs.first.$2,
        moreDrawings: [for (final x in pngs.skip(1)) (x.$1, x.$2)],
        moreHeight: 240,
        drawingHeight: 240,
        author: _s.author,
        sections: [
          BracketPdfSection(
            '자를 것 합계 (규격별)',
            const [],
            headers: const ['규격', '길이(mm)', '개수'],
            rows: [
              for (final c in t.cuts.entries)
                for (final l
                    in (c.value.entries.toList()
                      ..sort((a, b) => b.key.compareTo(a.key))))
                  [c.key, _f(l.key), '${l.value}'],
            ],
          ),
          for (final (e, p) in plans)
            BracketPdfSection(
              '${e.name} × ${e.qty}개',
              const [],
              headers: const ['품번', '토막', '규격', '길이(mm)', '끝 모양', '개수'],
              rows: [
                for (final pc in p.pieces)
                  [
                    pc.markText,
                    pc.name,
                    pc.ks,
                    pc.kind == BracketPieceKind.plate
                        ? '${_f(pc.length)} × ${_f(pc.width)}'
                        : _f(pc.length),
                    pc.ends,
                    '${pc.qty * e.qty}',
                  ],
              ],
            ),
          if (t.plates.isNotEmpty) BracketPdfSection('판', t.plates),
          if (t.stock.isNotEmpty)
            BracketPdfSection('원자재', [
              for (final e in t.stock.entries)
                if (e.value.barCount > 0)
                  '${e.key}: ${_f(e.value.stockLength)}mm ${e.value.barCount}본',
            ]),
        ],
        notes: [
          for (final (e, p) in plans)
            for (final s in p.problems) '${e.name}: $s',
        ],
      );
    }, previewTitle: '묶음 지시서 미리보기');
  }

  Future<void> _toSteel() async {
    if (_list.isEmpty) return;
    final items = bracketCutItems([
      for (final e in _list) (e.name, e.plan(_s), e.qty),
    ]);
    final name = '브라켓 묶음 ${_list.length}종';
    final go = await showAppConfirm(
      context,
      title: '형강 컷팅에 새 작업 만들기',
      message:
          '"$name" 작업을 새로 만들고 자를 것 ${items.length}줄을 넣습니다. 있던 작업은 건드리지 않습니다.',
      okText: '만들기',
      okKey: const Key('bb_steel_ok'),
    );
    if (!go || !mounted) return;
    final make = widget.createProject ?? createBracketSteelProject;
    final pr = await make(name, items, _s.stock);
    if (!mounted) return;
    if (pr == null) {
      showAppSnack(
        context,
        '작업을 만들지 못했습니다. 다시 해 보십시오.',
        kind: AppSnackKind.error,
      );
      return;
    }
    showAppSnack(
      context,
      '형강 컷팅에 "$name" 작업을 만들었습니다.',
      undoLabel: '열기',
      onUndo: () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SteelCuttingDetailScreen(project: pr),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => FieldViewTheme(
    child: Builder(
      builder: (context) {
        final t = _ready ? bracketBundleTotal(_list, _s) : null;
        return Scaffold(
          backgroundColor: fc.surface,
          appBar: AppBar(
            backgroundColor: fc.surface,
            foregroundColor: fc.text,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              '브라켓 묶음',
              style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
            ),
          ),
          body: !_ready
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: [
                    if (_list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          '묶음이 비었습니다. 브라켓 화면 보내기 탭에서 "묶음에 넣기"를 누르십시오.',
                          key: const Key('bb_empty'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: fc.textSub, height: 1.4),
                        ),
                      ),
                    if (_list.isNotEmpty) ...[
                      PlateSection('브라켓 (누르면 불러옴, 밀면 뺌)', [
                        for (final e in _list)
                          SwipeToDelete(
                            itemKey: ValueKey('bb_${e.id}'),
                            onDelete: () => _remove(e),
                            child: _row(e),
                          ),
                      ], first: true),
                      PlateSection('합계', [
                        PlateBigValue(
                          value: '약 ${_f(t!.kg)}kg${t.kgKnown ? '' : ' 이상'}',
                          caption:
                              '${_list.fold(0, (s, e) => s + e.qty)}개 · ${_list.length}종',
                        ),
                        // 규격 이름이 길어 이름|값 줄에서 접혔다(10-11 실기기) → 규격 한 줄, 길이 × 개수 한 줄
                        for (final c in t.cuts.entries)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.key,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: fc.text,
                                ),
                              ),
                              Text(
                                [
                                      for (final l
                                          in (c.value.entries.toList()..sort(
                                            (a, b) => b.key.compareTo(a.key),
                                          )))
                                        '${_f(l.key)} × ${l.value}',
                                    ].join(' · ') +
                                    (t.stock[c.key] != null &&
                                            t.stock[c.key]!.barCount > 0
                                        ? ' → ${_f(_s.stock)} 원자재 ${t.stock[c.key]!.barCount}본'
                                        : ''),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: fc.textSub,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        if (t.plates.isNotEmpty) PlateLines(t.plates),
                      ]),
                      PlateSection('보내기', [
                        plateActions([
                          PlateActionButton(
                            key: const Key('bb_pdf'),
                            icon: Icons.picture_as_pdf_outlined,
                            label: '묶음 지시서 PDF',
                            primary: true,
                            onTap: _pdf,
                          ),
                          PlateActionButton(
                            key: const Key('bb_steel'),
                            icon: Icons.content_cut_rounded,
                            label: '형강 컷팅에 새 작업으로',
                            onTap: _toSteel,
                          ),
                          PlateActionButton(
                            key: const Key('bb_clear'),
                            icon: Icons.delete_outline_rounded,
                            label: '묶음 비우기',
                            danger: true,
                            onTap: () async {
                              final ok = await showAppConfirm(
                                context,
                                title: '묶음 비우기',
                                message: '브라켓 ${_list.length}종을 묶음에서 모두 뺍니다.',
                                okText: '비우기',
                                destructive: true,
                              );
                              if (!ok || !mounted) return;
                              final before = List.of(_list);
                              _save([]);
                              if (!context.mounted) return;
                              showAppSnack(
                                context,
                                '묶음을 비웠습니다.',
                                kind: AppSnackKind.undo,
                                onUndo: () {
                                  if (mounted) _save(before);
                                },
                              );
                            },
                          ),
                        ]),
                      ]),
                    ],
                  ],
                ),
        );
      },
    ),
  );

  Widget _row(BracketBundleEntry e) {
    final p = e.plan(_s);
    Widget step(IconData icon, String key, VoidCallback? on) => IconButton(
      key: Key(key),
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: on == null ? fc.textFaint : fc.text),
      onPressed: on,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: fc.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fc.line),
      ),
      child: InkWell(
        key: Key('bb_row_${e.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pop(context, e.loadMap),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: fc.text,
                      ),
                    ),
                    Text(
                      '${bracketSummaryOf(bracketUpgradeMap(e.map))} · 약 ${_f(p.kgTotal)}kg${p.ok ? '' : ' · 고칠 곳 ${p.problems.length}'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: p.ok ? fc.textSub : fc.danger,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              step(Icons.edit_outlined, 'bb_rename_${e.id}', () => _rename(e)),
              step(
                Icons.remove_rounded,
                'bb_minus_${e.id}',
                e.qty > 1
                    ? () => _save([
                        for (final x in _list)
                          x == e ? x.withQty(x.qty - 1) : x,
                      ])
                    : null,
              ),
              Text(
                '${e.qty}개',
                key: Key('bb_qty_${e.id}'),
                style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
              ),
              step(
                Icons.add_rounded,
                'bb_plus_${e.id}',
                () => _save([
                  for (final x in _list) x == e ? x.withQty(x.qty + 1) : x,
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 이름 바꾸기 창: 글 칸 조절기는 창이 닫히는 그림이 끝난 뒤(창이 사라질 때) 버린다.
class _RenameSheet extends StatefulWidget {
  const _RenameSheet({required this.name});
  final String name;

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final TextEditingController _c = TextEditingController(
    text: widget.name,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlateSheetFrame(
    title: '이름 바꾸기',
    okText: '바꾸기',
    okKey: const Key('bb_rename_ok'),
    onOk: () => Navigator.pop(context, _c.text.trim()),
    children: [
      PlateNumField(
        fieldKey: 'bb_rename_field',
        label: '이름',
        controller: _c,
        unit: null,
        text: true,
        autofocus: true,
      ),
    ],
  );
}
