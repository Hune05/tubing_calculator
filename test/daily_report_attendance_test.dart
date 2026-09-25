// 필드4: 근태(연차·월차·반차·조퇴·특근) 칩 선택 UI 시험.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart'
    show setupFirebaseCoreMocks;
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/daily_report_page.dart';

import 'helpers_text.dart';

Future<void> _mount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(home: DailyReportPage(projectName: '테스트 현장')),
  );
  await tester.pump();
  // readMySettings()의 6초 타임아웃이 끝나도록 시계를 미리 돌려 둔다
  // (안 그러면 시험이 끝난 뒤에도 타이머가 남아 있다고 실패한다).
  await tester.pump(const Duration(seconds: 7));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('근태 칩이 모두 보이고 기본값은 정상근무다', (tester) async {
    await _mount(tester);
    for (final label in ['정상근무', '연차', '월차', '반차', '조퇴', '특근']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(findText('출근 시간'), findsOneWidget);
    expect(findText('퇴근 시간'), findsOneWidget);
  });

  testWidgets('연차를 고르면 출퇴근 시간 칸이 사라진다', (tester) async {
    await _mount(tester);
    await tester.tap(find.text('연차'));
    await tester.pumpAndSettle();
    expect(findText('출근 시간'), findsNothing);
    expect(findText('퇴근 시간'), findsNothing);
  });

  testWidgets('반차를 고르면 출퇴근 시간 칸이 그대로 보인다', (tester) async {
    await _mount(tester);
    await tester.tap(find.text('반차'));
    await tester.pumpAndSettle();
    expect(findText('출근 시간'), findsOneWidget);
    expect(findText('퇴근 시간'), findsOneWidget);
  });

  testWidgets('연차를 골랐다가 정상근무로 되돌리면 시간 칸이 다시 보인다', (tester) async {
    await _mount(tester);
    await tester.tap(find.text('연차'));
    await tester.pumpAndSettle();
    expect(findText('출근 시간'), findsNothing);
    await tester.tap(find.text('정상근무'));
    await tester.pumpAndSettle();
    expect(findText('출근 시간'), findsOneWidget);
    expect(findText('퇴근 시간'), findsOneWidget);
  });
}
