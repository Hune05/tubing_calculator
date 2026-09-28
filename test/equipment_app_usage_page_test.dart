// 장비 사용법·앱 사용법 화면: "현장 자료" 화면에서 분리한 두 화면이 각자 뜨고
// 넘기다 멈춰도 예외가 없다(2026-09-28, 헤더 점 3개 구획 나누기의 일부).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/reference/page/app_usage_page.dart';
import 'package:tubing_calculator/src/presentation/reference/page/equipment_usage_page.dart';
import 'package:tubing_calculator/src/presentation/reference/page/gd402_manual_page.dart';

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

  testWidgets('장비 사용법: GD402 카드의 "전체 매뉴얼 보기"를 누르면 매뉴얼 화면이 열린다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: EquipmentUsagePage()));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byType(OutlinedButton),
      find.byType(ListView).last,
      const Offset(0, -400),
    );
    await tester.ensureVisible(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    expect(find.text('GD402 가스 밀도계 매뉴얼'), findsOneWidget);
    await tester.dragUntilVisible(
      find.textContaining('10. 수소순도계 보정 절차'),
      find.byType(ListView).last,
      const Offset(0, -400),
    );
    expect(find.textContaining('10. 수소순도계 보정 절차'), findsOneWidget);
  });

  testWidgets('GD402 매뉴얼 화면: 챕터가 다 보이고 끝까지 넘겨도 예외가 없다', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Gd402ManualPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('1. 사양'), findsOneWidget);
    final list = find.byType(ListView).last;
    // 10장(수소순도)은 처음부터 펼쳐져 있다 — 화면까지 내리면 탭 없이도 안 내용이 보인다.
    await tester.dragUntilVisible(
      find.textContaining('10. 수소순도계 보정 절차'),
      list,
      const Offset(0, -400),
    );
    expect(find.textContaining('제로가스'), findsWidgets);
    await tester.dragUntilVisible(
      find.textContaining('11. 점검·유지보수'),
      list,
      const Offset(0, -400),
    );
    expect(find.textContaining('11. 점검·유지보수'), findsOneWidget);
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
