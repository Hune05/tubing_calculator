// 장비 사용법·앱 사용법 화면: "현장 자료" 화면에서 분리한 두 화면이 각자 뜨고
// 넘기다 멈춰도 예외가 없다(2026-09-28, 헤더 점 3개 구획 나누기의 일부).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_manual.dart';
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
      find.widgetWithText(OutlinedButton, '전체 매뉴얼 보기(설치·배선·보정 세 가지·경보표 전부)'),
      find.byType(ListView).last,
      const Offset(0, -400), maxIteration: 200,
    );
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '전체 매뉴얼 보기(설치·배선·보정 세 가지·경보표 전부)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '전체 매뉴얼 보기(설치·배선·보정 세 가지·경보표 전부)'));
    await tester.pumpAndSettle();
    expect(find.text('GD402 가스 밀도계 매뉴얼'), findsOneWidget);
    await tester.dragUntilVisible(
      find.textContaining('10. 수소순도계 보정 절차'),
      find.byType(ListView).last,
      const Offset(0, -400), maxIteration: 200,
    );
    expect(find.textContaining('10. 수소순도계 보정 절차'), findsOneWidget);
  });

  testWidgets('장비 사용법: REMS 아미고 2·타이거 SR 카드에 제원이 있고, 설명서 단추가 받는 곳을 알려 준다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: EquipmentUsagePage()));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.byKey(const Key('vendor_manual_REMS|Amigo 2')), find.byType(ListView).last, const Offset(0, -400), maxIteration: 200);
    expect(find.textContaining('REMS 아미고 2'), findsWidgets);
    expect(find.text('1700 W'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('vendor_manual_REMS|Amigo 2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vendor_manual_REMS|Amigo 2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manual_pick')), findsOneWidget);
    expect(find.text(kOfficialManualUrls['REMS|Amigo 2']!), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.byKey(const Key('vendor_manual_REMS|Tiger SR')), find.byType(ListView).last, const Offset(0, -400), maxIteration: 200);
    expect(find.text('1400 W (230 V 6.4 A / 110 V 12.8 A)'), findsOneWidget);
    // 두 카드 모두 주의 사항·정비·고장 대처·정리가 기본으로 들어 있다
    for (final t in ['주의 사항', '정비 (점검)', '고장 났을 때', '쓴 뒤 정리']) {
      expect(find.text(t, skipOffstage: false), findsNWidgets(2), reason: t);
    }
  });

  test('설명서 열쇠: 같은 제조사·모델이면 같은 설명서', () {
    expect(manualKeyFor(maker: 'rems', model: 'Amigo 2', id: 'x'), 'REMS|Amigo 2');
    expect(manualKeyFor(maker: 'REMS', model: 'Tiger SR'), 'REMS|Tiger SR');
    expect(manualKeyFor(id: 'abc'), 'id:abc');
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
      const Offset(0, -400), maxIteration: 200,
    );
    expect(find.textContaining('제로가스'), findsWidgets);
    await tester.dragUntilVisible(
      find.textContaining('11. 점검·유지보수'),
      list,
      const Offset(0, -400), maxIteration: 200,
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
