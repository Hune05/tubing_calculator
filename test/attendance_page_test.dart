// 근태 관리 화면(필드 헬퍼 4번, 작업 일지와 분리된 화면) 시험.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart'
    show setupFirebaseCoreMocks;
import 'package:firebase_core/firebase_core.dart';
import 'package:tubing_calculator/src/presentation/attendance/pages/attendance_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/attendance.dart';

import 'helpers_text.dart';

Future<void> _mount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // 오늘을 1일로 고정한다(오늘 줄로 옮겨도 1일이 화면에 남고, 날짜에 따라 결과가 바뀌지 않게).
  await tester.pumpWidget(
    MaterialApp(home: AttendancePage(today: DateTime(2026, 9, 1))),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  setUp(() => AttendanceCache.byDate = {});

  testWidgets('달 머리와 날짜 줄이 보인다', (tester) async {
    await _mount(tester);
    expect(findText("근태 관리"), findsOneWidget);
    expect(findTextContaining("2026년 9월"), findsOneWidget);
    expect(find.textContaining("일 ("), findsWidgets);
  });

  testWidgets('날짜를 누르면 근태 칩이 뜨고, 연차를 고르면 출퇴근 칸이 사라진다', (
    tester,
  ) async {
    await _mount(tester);
    await tester.tap(find.textContaining("1일 (").first);
    await tester.pumpAndSettle();

    for (final label in ['정상근무', '연차', '월차', '반차', '조퇴', '특근']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(findText("출근 시간"), findsOneWidget);
    expect(findText("퇴근 시간"), findsOneWidget);

    await tester.tap(find.text('연차'));
    await tester.pumpAndSettle();
    expect(findText("출근 시간"), findsNothing);
    expect(findText("퇴근 시간"), findsNothing);
  });

  testWidgets('저장을 누르면 오류 없이 시트가 닫힌다', (tester) async {
    await _mount(tester);
    await tester.tap(find.textContaining("1일 (").first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('연차'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    // 시트가 닫혀 근태 칩(6종)이 더는 안 보인다.
    expect(find.text('월차'), findsNothing);
  });

  testWidgets('이번 달을 열면 1일이 아니라 오늘 줄이 보인다', (tester) async {
    // 폰 크기(세로 800): 1일부터 그리면 26일은 화면 밖이다.
    tester.view.physicalSize = const Size(412, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: AttendancePage(today: DateTime(2026, 9, 26))),
    );
    await tester.pumpAndSettle();

    bool onScreen(String label) {
      final r = tester.getRect(find.text(label));
      return r.top >= 0 && r.bottom <= 800;
    }

    expect(onScreen('26일 (토)'), isTrue);
    expect(onScreen('1일 (화)'), isFalse);
  });
}
