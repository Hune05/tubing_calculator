// 한 단계씩은 세로 화면(숫자를 위아래로 길고 크게, 이전·다음은 아래), 줄자 보기는 가로.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking_screen.dart';

FieldMarkingData data() => const FieldMarkingData(
  totalCut: 1762,
  marks: [
    FieldMark(
      number: 1,
      position: 1007,
      angle: 90,
      targetAngle: 93,
      rotation: 0,
      gap: 1007,
    ),
    FieldMark(
      number: 2,
      position: 1301,
      angle: 45,
      targetAngle: 48,
      rotation: 450,
      gap: 294,
    ),
  ],
);

Future<List<String>> pump(
  WidgetTester tester,
  Size size, {
  bool isActive = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final errors = <String>[];
  final old = FlutterError.onError;
  FlutterError.onError = (d) => errors.add(d.exceptionAsString());
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox()); // 앞 화면의 상태를 버린다
  await tester.pumpWidget(
    MaterialApp(
      home: FieldMarkingScreen(
        listenable: ValueNotifier(0),
        compute: data,
        isActive: isActive,
        measureGroup: () => '묶음',
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('field_mode_toggle')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('field_mode_toggle')));
  await tester.pumpAndSettle();
  FlutterError.onError = old; // expect 전에 되돌린다
  return errors;
}

void main() {
  topBarTests();
  testWidgets('세로 화면: 이전·다음이 숫자 아래에 가로로 넓게 놓인다', (tester) async {
    final errors = await pump(tester, const Size(600, 1005));
    expect(errors, isEmpty);
    final number = tester.getRect(find.byKey(const Key('field_step_number')));
    final prev = tester.getRect(find.text('이전'));
    final next = tester.getRect(find.text('다음'));
    expect(prev.top, greaterThan(number.bottom)); // 숫자 아래
    expect(next.top, greaterThan(number.bottom));
    expect(prev.left, lessThan(next.left)); // 이전은 왼쪽, 다음은 오른쪽
    expect(next.center.dx, greaterThan(300)); // 오른쪽 절반
  });

  testWidgets('세로 화면: 각도가 숫자 아래로 쌓인다(옆이 아니라 아래)', (tester) async {
    await pump(tester, const Size(600, 1005));
    final number = tester.getRect(find.byKey(const Key('field_step_number')));
    final angle = tester.getRect(find.text('90°'));
    expect(angle.top, greaterThan(number.bottom - 4));
  });

  testWidgets('세로 화면에서도 숫자 크기는 가로 화면과 같다(영역을 채우게 키우지 않는다)', (tester) async {
    await pump(tester, const Size(600, 1005));
    final portraitW = tester
        .getRect(find.byKey(const Key('field_step_number')))
        .width;
    await pump(tester, const Size(1006, 600));
    final landscapeW = tester
        .getRect(find.byKey(const Key('field_step_number')))
        .width;
    expect(portraitW, closeTo(landscapeW, 1)); // 같은 크기
    expect(portraitW, lessThan(500)); // 화면 폭(600)을 가득 채우지 않는다
  });

  testWidgets('좁은 세로(344×700)에서도 넘치지 않는다', (tester) async {
    final errors = await pump(tester, const Size(344, 700));
    expect(errors, isEmpty);
    expect(find.byKey(const Key('field_next_gap')), findsOneWidget);
  });

  testWidgets('현장 탭은 줄자·한 단계씩 어느 쪽이든 화면 방향을 묶지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final calls = <List<dynamic>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          calls.add(List<dynamic>.from(call.arguments as List));
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1006, 600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: FieldMarkingScreen(
          listenable: ValueNotifier(0),
          compute: data,
          isActive: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('field_mode_toggle'))); // 한 단계씩
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('field_mode_toggle'))); // 줄자로
    await tester.pumpAndSettle();
    // 묶는 호출(가로·세로 목록)은 한 번도 없고, 푸는 호출(빈 목록)만 있다.
    expect(calls.where((l) => l.isNotEmpty), isEmpty);
  });
}

void topBarTests() {
  testWidgets('세로 800 안팎(A11)에서 위쪽 막대의 닫기가 화면 안에 들어온다', (tester) async {
    await pump(tester, const Size(600, 1005)); // A11 세로(dp)
    final close = tester.getRect(find.byKey(const Key('field_close')));
    expect(close.right, lessThanOrEqualTo(600));
  });
}
