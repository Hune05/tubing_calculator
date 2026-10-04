// 라인 컷팅 입력 화면 개편: 제조사 칩, 규격·톱날 알약, 첫 안내, 아래 요약 바, 짧아진 지점 카드.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart';

Finder lengthField(int i) => find
    .byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.labelText ?? '').startsWith('전체 길이'),
    )
    .at(i);

Future<void> open(WidgetTester tester, {Size size = const Size(1080, 2400), double dpr = 3, double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: CuttingMainScreen(
          project: CuttingProject(id: 'p1', name: 'TEST', createdAt: DateTime(2026, 9, 20)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('처음에는 짧은 순서 안내가 있고, 값을 넣으면 사라진다', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('cut_first_hint')), findsOneWidget);
    await tester.enterText(lengthField(0), '500');
    await tester.pump();
    expect(find.byKey(const Key('cut_first_hint')), findsNothing);
  });

  testWidgets('제조사는 칩 한 줄이고 누르면 바뀐다', (tester) async {
    await open(tester);
    for (final m in ['Swagelok', 'Parker', 'Hy-Lok', 'DK-Lok']) {
      expect(find.byKey(Key('maker_$m')), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('maker_Hy-Lok')));
    await tester.pump();
    final chip = tester.widget<Material>(
      find.ancestor(of: find.byKey(const Key('maker_Hy-Lok')), matching: find.byType(Material)).first,
    );
    expect(chip.color, isNot(const Color(0xFFF0F3F5)), reason: '선택한 칩은 배경색이 바뀐다');
  });

  testWidgets('톱날 알약: 처음에는 "톱날 없음", 누르면 설정 창이 열린다', (tester) async {
    await open(tester);
    expect(find.text('톱날 없음'), findsOneWidget);
    await tester.tap(find.byKey(const Key('input_kerf_picker')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsWidgets);
  });

  testWidgets('톱날이 저장돼 있으면 알약에 값이 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({'cutting_blade_kerf': 3.0});
    await open(tester);
    expect(find.text('톱날 3mm'), findsOneWidget);
  });

  testWidgets('아래 요약 바: 값이 없으면 "- mm", 넣으면 합계와 구간 수가 나온다', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('cut_summary_bar')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('cut_summary_total'))).data, '- mm');
    await tester.enterText(lengthField(0), '1200');
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('cut_summary_total'))).data, '1200 mm');
    expect(tester.widget<Text>(find.byKey(const Key('cut_summary_notes'))).data, contains('1구간'));
  });

  testWidgets('읽을 수 없는 값은 요약 바에 "확인 필요"로 나온다', (tester) async {
    await open(tester);
    await tester.enterText(lengthField(0), '12a0');
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('cut_summary_notes'))).data, contains('확인 필요 1'));
  });

  testWidgets('"결과 보기"를 누르면 결과 탭으로 가고, 결과 탭에서는 요약 바가 없다', (tester) async {
    await open(tester);
    await tester.enterText(lengthField(0), '1200');
    await tester.pump();
    await tester.tap(find.byKey(const Key('cut_summary_open_result')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cut_summary_bar')), findsNothing);
    await tester.tap(find.text('입력'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cut_summary_bar')), findsOneWidget);
  });

  testWidgets('지점 카드는 부속을 고른 뒤에만 "공제값 직접 입력" 단추가 보인다', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('pt_edit_0')), findsNothing);
    expect(find.text('탭해서 부속 고르기'), findsWidgets);
  });

  for (final w in [320.0, 360.0]) {
    testWidgets('폭 $w · 글자 1.3배에서 넘치지 않는다', (tester) async {
      await open(tester, size: Size(w * 3, 2000), scale: 1.3);
      await tester.enterText(lengthField(0), '1234.5');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
