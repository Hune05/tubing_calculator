// 전선관 입력 탭 '전체 지우기'는 먼저 묻고, 지우면 고치던 줄도 그만둔다.
// 예전에는 누르자마자 지웠고, 고치던 줄 번호가 남아 '수정'이 아무 일도 안 했다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_input_tab.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ConduitDataManager().bendList
      ..clear()
      ..addAll([
        {'length': 150.0, 'angle': 0.0, 'rotation': 0.0},
        {'length': 300.0, 'angle': 90.0, 'rotation': 0.0},
        {'length': 400.0, 'angle': 0.0, 'rotation': 0.0},
      ]);
  });

  testWidgets('묻고 지운다, 고치던 줄은 그만둔다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ConduitInputTab())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // 취소하면 그대로.
    await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('3줄을 모두 지우겠습니까'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(ConduitDataManager().bendList, hasLength(3));

    // 줄을 눌러 고치는 중에 지우면 고치기도 끝난다.
    await tester.tap(find.text('길이: 400.0mm'));
    await tester.pump();
    expect(find.text('수정'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();
    expect(ConduitDataManager().bendList, isEmpty);
    expect(find.text('수정'), findsNothing);
    expect(find.text('추가'), findsOneWidget);
  });
}
