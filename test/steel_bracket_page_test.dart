// 형강 브라켓 화면(10-11 개편): 위 그림 + 아래 탭(모양·부재·구멍·판·결과·보내기), 규격 고르는 창·방향,
// 부재도·입체 보기, 카톡 글·입력 남기기, 묶음·형강 컷팅·철판 가공으로 넘기기, 하중 칸, 10-10 저장 값 읽기, 묶음 화면.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/steel_cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_bundle.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_ui.dart';

String _text(WidgetTester t, Key k) {
  final w = t.widget(find.byKey(k));
  if (w is Text) return w.data ?? '';
  return t
      .widgetList<Text>(
        find.descendant(of: find.byKey(k), matching: find.byType(Text)),
      )
      .map((x) => x.data ?? '')
      .join(' ');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(
    WidgetTester tester, {
    Future<void> Function(String)? share,
    Map<String, Object>? draft,
    Future<SteelCuttingProject?> Function(String, List<SteelCutItem>, double)?
    create,
    void Function(BuildContext, Map<String, Object?>)? openPlate,
    bool keep = false,
  }) async {
    if (!keep) {
      SharedPreferences.setMockInitialValues({
        if (draft != null) BracketPage.draftKey: jsonEncode(draft),
      });
    }
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BracketPage(
          share: share ?? (_) async {},
          createProject: create,
          openPlate: openPlate ?? (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, String id) => tap(tester, 'br_tab_$id');

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('기본 ㄱ자 → 삼각 → 문형: 결과 탭 품번 카드', (tester) async {
    await open(tester);
    expect(_text(tester, const Key('br_sum')), startsWith('ㄱ자 · L-50×50×5'));
    expect(find.byKey(const Key('br_view')), findsOneWidget);
    await tab(tester, 'result');
    expect(_text(tester, const Key('br_piece_1')), contains('① 기둥  L-50×50×5'));
    expect(
      _text(tester, const Key('br_piece_1')),
      contains('300mm × 1개 · 양 끝 직각'),
    );
    expect(
      _text(tester, const Key('br_piece_1')),
      contains('구멍 2-φ13.5 · 벽 붙는 면 · 위 끝에서 80 · 260 · 게이지 27.5'),
    );
    expect(_text(tester, const Key('br_piece_2')), contains('250mm × 1개'));
    await tab(tester, 'shape');
    await tap(tester, 'br_shape_1');
    await tab(tester, 'result');
    expect(_text(tester, const Key('br_piece_3')), contains('③ 가새'));
    expect(
      _text(tester, const Key('br_piece_3')),
      contains('276.3mm(짧은 쪽 176.3)'),
    );
    await tab(tester, 'shape');
    await tap(tester, 'br_shape_2');
    await tab(tester, 'result');
    expect(_text(tester, const Key('br_piece_1')), contains('291mm × 2개'));
    expect(
      _text(tester, const Key('br_piece_3')),
      contains('③ 베이스 판  PL-9×150×150'),
    );
    expect(
      _text(tester, const Key('br_piece_3')),
      contains('150 × 150 × 9t × 2장'),
    );
    await done(tester);
  });

  testWidgets('규격 고르는 창·방향, 카톡 글, 입력 남기기', (tester) async {
    String? sent;
    await open(tester, share: (t) async => sent = t);
    await tab(tester, 'member');
    await tap(tester, 'br_spec');
    await tap(tester, 'br_spec_cat_1');
    await tap(tester, 'br_spec_item_찬넬 100x50x5');
    await tap(tester, 'br_spec_ok');
    expect(_text(tester, const Key('br_sum')), contains('ㄷ-100×50×5'));
    // 찬넬은 방향이 둘: 처음은 날개가 벽에(그림 폭 100)
    expect(
      tester.widget<PlateSegButton>(find.byKey(const Key('br_po_1'))).selected,
      isTrue,
    );
    await tap(tester, 'br_po_0'); // 등이 벽에 → 그림 폭 50
    await tab(tester, 'result');
    expect(_text(tester, const Key('br_piece_2')), contains('250mm'));
    await tab(tester, 'shape');
    await tester.enterText(find.byKey(const Key('br_a')), '400');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('br_sets')), '4');
    await tester.pumpAndSettle();
    await tab(tester, 'send');
    await tap(tester, 'br_share');
    expect(sent, startsWith('[형강 브라켓] ㄱ자 · ㄷ-100×50×5 · 4개'));
    expect(sent, contains('② 가로대 ㄷ-100×50×5 350mm × 4개'));
    expect(sent, contains('벽 고정 구멍 φ13.5 8개'));
    expect(sent, contains('재질 SS275 · 무도장'));
    await done(tester);
    await open(tester, keep: true);
    expect(
      tester.widget<TextField>(find.byKey(const Key('br_a'))).controller!.text,
      '400',
    );
    await done(tester);
  });

  testWidgets('부재도·입체 보기, 결과 카드를 누르면 그 부재도', (tester) async {
    await open(tester, draft: {'sh': 1});
    await tap(tester, 'br_vm_piece');
    expect(find.byKey(const Key('br_view_piece')), findsOneWidget);
    expect(find.byKey(const Key('br_pm_3')), findsOneWidget);
    await tap(tester, 'br_vm_3d');
    expect(find.byKey(const Key('br_3d')), findsOneWidget);
    await tab(tester, 'result');
    await tap(tester, 'br_piece_3');
    expect(find.byKey(const Key('br_view_piece')), findsOneWidget);
    expect(
      tester
          .widget<PlateCanvasButton>(find.byKey(const Key('br_pm_3')))
          .selected,
      isTrue,
    );
    await done(tester);
  });

  testWidgets('하중 확인 칸: 무게를 넣으면 휨·처짐 줄', (tester) async {
    await open(tester);
    await tab(tester, 'result');
    expect(find.byKey(const Key('br_load_가로대 휨')), findsNothing);
    await tester.enterText(find.byKey(const Key('br_lk')), '100');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('br_load_가로대 휨')), findsOneWidget);
    expect(find.byKey(const Key('br_load_가로대 끝 처짐')), findsOneWidget);
    await tap(tester, 'br_lm_0'); // 끝에 한 점
    expect(find.textContaining('59%'), findsWidgets);
    await done(tester);
  });

  testWidgets('보내기: 묶음에 넣기, 형강 컷팅 새 작업(확인 뒤), 베이스 판 → 철판 가공', (tester) async {
    String? made;
    List<SteelCutItem>? got;
    Map<String, Object?>? plate;
    await open(
      tester,
      draft: {'sh': 2},
      create: (name, items, stock) async {
        made = name;
        got = items;
        return SteelCuttingProject(
          id: 'x',
          name: name,
          createdAt: DateTime(2026),
          items: items,
        );
      },
      openPlate: (_, m) => plate = m,
    );
    await tab(tester, 'send');
    await tap(tester, 'br_bundle_add');
    final p = await SharedPreferences.getInstance();
    final bundle = jsonDecode(p.getString(kBracketBundleKey)!) as List;
    expect(bundle.length, 1);
    expect((bundle.first as Map)['qty'], 1);
    // 같은 것을 또 넣으면 막는다(앞 알림에 단추가 있어 그 알림이 지난 뒤에 뜬다)
    await tap(tester, 'br_bundle_add');
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('이미 묶음에 있습니다.'), findsOneWidget);
    await tap(tester, 'br_to_steel');
    expect(made, isNull); // 확인 전
    await tap(tester, 'br_steel_ok');
    expect(made, '브라켓 문형');
    expect(got!.map((x) => x.length).toSet(), {291, 200});
    expect(got!.firstWhere((x) => x.length == 291).qty, 2);
    await tap(tester, 'br_to_plate');
    expect(plate!['sh'], 'flat');
    expect(plate!['len'], '150');
    expect(plate!['n'], '2');
    await done(tester);
  });

  testWidgets('10-10 저장 값(직접 적은 규격·정사각 판 한 변)을 읽는다', (tester) async {
    await open(
      tester,
      draft: {
        'sh': 2,
        'ct': 1,
        'sp': '찬넬 100x50x5',
        'cs': '',
        'pl': true,
        'ps': '200',
        'pt': '12',
        'a': '800',
        'b': '900',
      },
    );
    await tab(tester, 'result');
    expect(_text(tester, const Key('br_piece_3')), contains('PL-12×200×200'));
    await done(tester);
  });

  testWidgets('묶음 화면: 개수 늘리기, 형강 컷팅 한 작업, 줄을 누르면 불러옴(되돌리기)', (tester) async {
    SharedPreferences.setMockInitialValues({
      kBracketBundleKey: jsonEncode([
        {'id': 'a', 'name': 'ㄱ자 A', 'qty': 2, 'map': <String, Object>{}},
        {
          'id': 'b',
          'name': '문형 B',
          'qty': 1,
          'map': {'sh': 2, 'pl': false},
        },
      ]),
    });
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    List<SteelCutItem>? got;
    Map<String, dynamic>? back;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('go'),
                onPressed: () async {
                  back = await Navigator.of(context).push<Map<String, dynamic>>(
                    MaterialPageRoute(
                      builder: (_) => BracketBundlePage(
                        createProject: (n, items, s) async {
                          got = items;
                          return SteelCuttingProject(
                            id: 'y',
                            name: n,
                            createdAt: DateTime(2026),
                            items: items,
                          );
                        },
                      ),
                    ),
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('go')));
    await tester.pumpAndSettle();
    expect(find.text('ㄱ자 A'), findsOneWidget);
    expect(find.byKey(const Key('bb_qty_a')), findsOneWidget);
    await tap(tester, 'bb_plus_a');
    expect(
      (tester.widget(find.byKey(const Key('bb_qty_a'))) as Text).data,
      '3개',
    );
    await tap(tester, 'bb_steel');
    await tap(tester, 'bb_steel_ok');
    // ㄱ자 기둥 300 × 3 + 문형 기둥 300 × 2
    expect(got!.firstWhere((x) => x.length == 300).qty, 5);
    await tap(tester, 'bb_row_b');
    expect(back?['sh'], 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
