// 장비 사용법·앱 사용법 화면: "현장 자료" 화면에서 분리한 두 화면이 각자 뜨고
// 넘기다 멈춰도 예외가 없다(2026-09-28, 헤더 점 3개 구획 나누기의 일부).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/reference/page/app_usage_page.dart';
import 'package:tubing_calculator/src/presentation/reference/page/equipment_usage_page.dart';

Future<void> _scrollThrough(WidgetTester tester) async {
  final list = find.byType(ListView).last;
  for (var i = 0; i < 12; i++) {
    await tester.drag(list, const Offset(0, -1500));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: '스크롤 $i');
  }
}

void main() {
  testWidgets('장비 사용법 화면: 벤더 종류가 보이고 끝까지 넘겨도 예외가 없다', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: EquipmentUsagePage()));
    await tester.pumpAndSettle();
    expect(find.text('장비 사용법'), findsWidgets);
    expect(find.textContaining('튜브 수동 벤더'), findsOneWidget);
    await _scrollThrough(tester);
  });

  testWidgets('앱 사용법 화면: 계산기 사용 순서가 보이고 끝까지 넘겨도 예외가 없다', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AppUsagePage()));
    await tester.pumpAndSettle();
    expect(find.text('앱 사용법'), findsWidgets);
    expect(find.textContaining('벤딩 마킹 계산기 (튜브)'), findsOneWidget);
    await _scrollThrough(tester);
  });
}
