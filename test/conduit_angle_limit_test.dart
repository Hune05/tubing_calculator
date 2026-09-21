// 전선관 "직관+각도" 각도 상한.
// 예전에는 180°가 들어가 1번 마킹이 −1.9×10^18mm로 나왔고, 200을 넣은 뒤
// 배관 형태를 바꿨다 돌아오면 묶음이 풀려 200° 벤드가 목록에 들어갔다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_input_tab.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ConduitDataManager().bendList.clear();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ConduitInputTab())),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  TextField angleField(WidgetTester tester) => tester.widget<TextField>(
    find.byWidgetPredicate(
      (w) =>
          w is TextField && (w.decoration?.hintText ?? '').contains('원하는 각도'),
    ),
  );

  Future<void> typeAngle(WidgetTester tester, String value) async {
    await tester.tap(find.text('직관+각도'));
    await tester.pump();
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is TextField && (w.decoration?.hintText ?? '').contains('원하는 각도'),
      ),
    );
    await tester.pumpAndSettle();
    angleField(tester).controller!.text = value;
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
  }

  testWidgets('200을 넣으면 칸도 170으로 바뀌고 알려 준다', (tester) async {
    await pump(tester);
    await typeAngle(tester, '200');
    expect(angleField(tester).controller!.text, '170');
    expect(find.textContaining('170°까지'), findsOneWidget);
  });

  testWidgets('형태를 바꿨다 돌아와도 170을 넘지 않고, 추가된 벤드도 170°', (tester) async {
    await pump(tester);
    await typeAngle(tester, '200');
    // 칸 글자를 몰래 200으로 되돌려 놓아도(예전 경로) 전환 때 다시 묶는다.
    angleField(tester).controller!.text = '200';
    await tester.tap(find.text('90° 벤딩'));
    await tester.pump();
    await tester.tap(find.text('직관+각도'));
    await tester.pump();
    expect(angleField(tester).controller!.text, '170');

    final len = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == '0',
    );
    tester.widget<TextField>(len.first).controller!.text = '1000';
    ScaffoldMessenger.of(
      tester.element(find.byType(ConduitInputTab)),
    ).removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('UP'));
    await tester.pump();
    await tester.ensureVisible(find.text('추가'));
    await tester.pump();
    await tester.tap(find.text('추가'));
    await tester.pump();
    final list = ConduitDataManager().bendList;
    expect(list, hasLength(1));
    expect(list.first['angle'], 170.0);
  });
}
