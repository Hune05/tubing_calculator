// 라인 컷팅 "구간 추가"(10-09 사용자 지적): 예전에는 지금 구간의 끝 부속 앞에 끼워 넣어 지금 구간을
// 밀어내고 새 구간이 2번 자리에 들어갔다. 이제 그 부속 뒤에 붙어, 앞 구간과 뒤 구간 길이가 그대로 남는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart';

Finder _len(int i) => find
    .byWidgetPredicate(
      (w) =>
          w is TextField && (w.decoration?.labelText ?? '').startsWith('전체 길이'),
    )
    .at(i);

String _lenText(WidgetTester tester, int i) =>
    tester.widget<TextField>(_len(i)).controller!.text;

int _lenCount() => find
    .byWidgetPredicate(
      (w) =>
          w is TextField && (w.decoration?.labelText ?? '').startsWith('전체 길이'),
    )
    .evaluate()
    .length;

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 4800);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CuttingMainScreen(
          project: CuttingProject(
            id: 'p1',
            name: 'TEST',
            createdAt: DateTime(2026, 10, 10),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('구간 하나일 때 "구간 추가"는 끝 부속 뒤(다음 줄)에 붙고, 첫 구간 길이는 그대로', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(_len(0), '1200');
    await tester.pump();
    // 첫 부속 뒤에는 단추가 없고(첫 구간이 이미 있다), 끝 부속(2번) 뒤에 있다.
    expect(find.byKey(const Key('cut_add_after_0')), findsNothing);
    await tester.tap(find.byKey(const Key('cut_add_after_1')));
    await tester.pump();
    expect(_lenCount(), 2);
    expect(_lenText(tester, 0), '1200'); // 지금 구간은 밀리지 않는다
    expect(_lenText(tester, 1), ''); // 새 구간은 그 다음 줄
    expect(
      tester.widget<Text>(find.byKey(const Key('segment_title_1'))).data,
      'PT2 → PT3',
    );
  });

  testWidgets('가운데 부속 뒤에 붙이면 앞·뒤 구간 길이가 그대로 남고 그 사이에 빈 구간이 생긴다', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('포인트 추가'));
    await tester.pump();
    await tester.enterText(_len(0), '1000');
    await tester.enterText(_len(1), '2000');
    await tester.pump();
    await tester.tap(find.byKey(const Key('cut_add_after_1')));
    await tester.pump();
    expect(_lenCount(), 3);
    expect(_lenText(tester, 0), '1000');
    expect(_lenText(tester, 1), '');
    expect(_lenText(tester, 2), '2000');
  });
}
