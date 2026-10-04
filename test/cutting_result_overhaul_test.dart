// 라인 컷팅 결과 탭 개편: 자른 줄 감추기, 잘랐음 지우기(되돌리기), 경고를 눌러 입력 탭으로.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_leftovers.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart';

Finder lengthField(int i) => find
    .byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.labelText ?? '').startsWith('전체 길이'),
    )
    .at(i);

// 지점이 여럿이어도 목록 아래 칸이 만들어지도록 화면을 길게 쓴다.
Future<void> open(WidgetTester tester, {Size size = const Size(1080, 4200), double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: CuttingMainScreen(
          project: CuttingProject(id: 'p1', name: '루마', createdAt: DateTime(2026, 9, 20)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, List<String> values) async {
  for (var i = 0; i < values.length - 1; i++) {
    await tester.tap(find.text('포인트 추가'));
    await tester.pump();
  }
  for (var i = 0; i < values.length; i++) {
    await tester.enterText(lengthField(i), values[i]);
  }
  await tester.pump();
}

Finder checks() => find.byWidgetPredicate(
  (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('result_check_'),
);

void main() {
  leftoverStore = PrefsLeftoverStore();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('줄이 없으면 감추기·지우기 칩이 없다', (tester) async {
    await open(tester);
    await tester.tap(find.text('결과'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('result_hide_done')), findsNothing);
    expect(find.byKey(const Key('result_clear_done')), findsNothing);
  });

  testWidgets('목록이 비었으면 "입력 탭으로 가기" 단추가 있고 누르면 입력 탭으로 간다', (tester) async {
    await open(tester);
    await tester.tap(find.text('결과'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('result_empty_action')), findsOneWidget);
    await tester.tap(find.byKey(const Key('result_empty_action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cut_summary_bar')), findsOneWidget);
  });

  testWidgets('줄이 있으면 "자른 줄 감추기"가 있고, 잘랐음 표시가 있을 때만 "잘랐음 지우기"가 나온다', (tester) async {
    await open(tester);
    await fill(tester, ['600', '900']);
    await tester.tap(find.text('결과'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('result_hide_done')), findsOneWidget);
    expect(find.byKey(const Key('result_clear_done')), findsNothing);
    await tester.tap(checks().first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('result_clear_done')), findsOneWidget);
  });

  testWidgets('자른 줄 감추기를 켜면 잘랐음으로 표시한 줄이 목록에서 빠지고, 끄면 돌아온다', (tester) async {
    await open(tester);
    await fill(tester, ['600', '900']);
    await tester.tap(find.text('결과'));
    await tester.pumpAndSettle();
    final rowFinder = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('result_row_'),
    );
    expect(rowFinder, findsNWidgets(2));
    await tester.tap(rowFinder.first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('result_hide_done')));
    await tester.pumpAndSettle();
    expect(rowFinder, findsNWidgets(1));
    await tester.tap(find.byKey(const Key('result_hide_done')));
    await tester.pumpAndSettle();
    expect(rowFinder, findsNWidgets(2));
  });

  testWidgets('감추기를 켜 두면 다시 열어도 기억한다', (tester) async {
    SharedPreferences.setMockInitialValues({'cutting_result_hide_done': true});
    await open(tester);
    await fill(tester, ['600', '900']);
    await tester.tap(find.text('결과'));
    await tester.pumpAndSettle();
    final chip = tester.widget<InkWell>(find.byKey(const Key('result_hide_done')));
    expect(chip.onTap, isNotNull);
    final deco = tester.widget<Container>(
      find.descendant(of: find.byKey(const Key('result_hide_done')), matching: find.byType(Container)).first,
    );
    expect((deco.decoration as BoxDecoration).color, isNot(Colors.grey.shade100), reason: '켜진 칩은 틸 바탕');
  });

  testWidgets('잘랐음 지우기: 표시를 모두 지우고, 되돌리기로 되살린다', (tester) async {
    await open(tester);
    await fill(tester, ['600', '900']);
    await tester.tap(find.text('결과'));
    await tester.pumpAndSettle();
    await tester.tap(checks().at(0));
    await tester.tap(checks().at(1));
    await tester.pumpAndSettle();
    expect(find.text('잘랐음 2/2개'), findsNothing); // 모두 잘랐으면 다른 글
    await tester.tap(find.byKey(const Key('result_clear_done')));
    await tester.pumpAndSettle();
    expect(find.text('잘랐음 0/2개'), findsOneWidget);
    expect(find.text('2줄의 잘랐음 표시를 지웠습니다.'), findsOneWidget);
    await tester.tap(find.text('실행 취소'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('result_clear_done')), findsOneWidget);
    expect(find.text('잘랐음 0/2개'), findsNothing);
  });

  testWidgets('목록에서 뺀 구간 경고를 누르면 입력 탭으로 간다', (tester) async {
    await open(tester);
    await fill(tester, ['600', '12a0', '900']);
    await tester.tap(find.text('결과'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('result_warning')), findsOneWidget);
    await tester.tap(find.byKey(const Key('result_warning_tap')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cut_summary_bar')), findsOneWidget, reason: '입력 탭에는 아래 요약 바가 있다');
  });

  for (final w in [320.0, 360.0]) {
    testWidgets('결과 탭: 폭 $w · 글자 1.3배에서 넘치지 않는다', (tester) async {
      await open(tester, size: Size(w * 3, 4200), scale: 1.3);
      await fill(tester, ['600', '900']);
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      await tester.tap(checks().first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
