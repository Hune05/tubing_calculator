// 전기 설비 계산의 접었다 펴는 구역: 덜 쓰는 구역은 처음에 접혀 있고, 누르면 펴지며 폰에 기억된다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';

Future<void> _open(WidgetTester tester, int tab) async {
  tester.view.physicalSize = const Size(390, 12000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: ElectricCalculatorPage(initialTab: tab)),
  );
  await tester.pumpAndSettle();
}

bool _expanded(WidgetTester tester, String key) =>
    tester.widget<ExpansionTile>(find.byKey(Key(key))).initiallyExpanded;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const folds = {
    5: ['ec_sc_fold_motor', 'ec_sc_fold_breaker', 'ec_sc_fold_cable'],
    2: ['els_fold_sheet', 'els_fold_saved'],
    3: ['ec_fold_mi'],
    8: ['ec_fold_tp'],
  };

  for (final e in folds.entries) {
    testWidgets('탭 ${e.key}: 덜 쓰는 구역(${e.value.join(', ')})은 처음에 접혀 있다', (
      tester,
    ) async {
      await _open(tester, e.key);
      for (final k in e.value) {
        await tester.scrollUntilVisible(
          find.byKey(Key(k)),
          400,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .first,
        );
        expect(_expanded(tester, k), isFalse, reason: k);
      }
    });
  }

  testWidgets('단락 전류의 "저압 전동기 기여"를 펴면 입력 칸이 나오고 폰에 적힌다', (tester) async {
    await _open(tester, 5);
    expect(find.byKey(const Key('ec_sc_mkw')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('ec_sc_fold_motor')));
    await tester.tap(find.text('저압 전동기 기여 (선택)'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ec_sc_mkw')), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('fold_v1_ec_sc_fold_motor'), isTrue);
  });

  testWidgets('MI 구역의 칩 선택은 접었다 펴도, 목록 밖으로 스크롤했다 와도 남는다', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: ElectricCalculatorPage(initialTab: 3)),
    );
    await tester.pumpAndSettle();
    final list = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('ec_fold_mi')),
      400,
      scrollable: list,
    );
    await tester.tap(find.text('미네랄 절연(MI) 케이블·나도체 허용전류'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('ec_mi_t105')),
      300,
      scrollable: list,
    );
    await tester.ensureVisible(find.byKey(const Key('ec_mi_t105')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ec_mi_t105')));
    await tester.pumpAndSettle();
    bool on() => tester
        .widget<ChoiceChip>(find.byKey(const Key('ec_mi_t105')))
        .selected;
    expect(on(), isTrue);
    // 목록 맨 위까지 올렸다가 다시 내려온다.
    await tester.drag(list, const Offset(0, 6000));
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, -6000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('ec_mi_t105')),
      300,
      scrollable: list,
    );
    expect(on(), isTrue, reason: '스크롤 뒤');
  });
  testWidgets('편 구역은 목록 밖으로 스크롤했다 돌아와도 펼쳐진 채다', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: ElectricCalculatorPage(initialTab: 5)),
    );
    await tester.pumpAndSettle();
    final list = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('ec_sc_fold_cable')),
      300,
      scrollable: list,
    );
    await tester.tap(find.text('케이블 단락 열적 강도 (I²t)'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ec_sc_t')), findsOneWidget);
    await tester.drag(list, const Offset(0, 8000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('ec_sc_t')),
      300,
      scrollable: list,
    );
    expect(find.byKey(const Key('ec_sc_t')), findsOneWidget);
  });
}
