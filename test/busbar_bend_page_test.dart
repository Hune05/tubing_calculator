// 부스바 절곡 계산기 화면(10-03): 기본값 L 꺾기, U·Z 바꾸기, 반경 경고, 카톡 글, 입력값 남기기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_bend_page.dart';

Future<void> _open(
  WidgetTester tester, {
  Future<void> Function(String)? share,
}) async {
  tester.view.physicalSize = const Size(800, 5200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: share == null
          ? const BusbarBendPage()
          : BusbarBendPage(share: share),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('기본값(5×50, r 5, k 0.4, 바깥 100×100, 90°): 절단 길이 191.0', (
    tester,
  ) async {
    await _open(tester);
    // ρ = 7, 다리 97, 물림 7, 호 10.996 → 90 + 10.996 + 90
    expect(find.text('191 mm'), findsOneWidget);
    expect(find.text('90 mm · 위로 90°'), findsOneWidget);
    expect(find.byKey(const Key('bb_shape_view')), findsOneWidget);
    expect(find.byKey(const Key('bb_mark_view')), findsOneWidget);
  });

  testWidgets('U 꺾기는 마킹 2곳, Z 꺾기는 높이가 낮으면 알림', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('bb_k_u')));
    await tester.pumpAndSettle();
    expect(find.textContaining('90°'), findsWidgets);
    expect(find.text('90 mm · 위로 90°'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bb_k_z')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bb_a_45')));
    await tester.pumpAndSettle();
    await _type(tester, 'bb_ih', '3');
    expect(find.textContaining('꺾을 수 없습니다'), findsOneWidget);
    await _type(tester, 'bb_ih', '40');
    expect(find.textContaining('꺾을 수 없습니다'), findsNothing);
    expect(find.textContaining('비스듬한 곧은 길이'), findsOneWidget);
  });

  testWidgets('눕혀 꺾기 안쪽 반경이 두께보다 작으면 CDA 최소 반경 경고', (tester) async {
    await _open(tester);
    await _type(tester, 'bb_r', '2');
    expect(find.textContaining('최소 반경 5mm(CDA'), findsOneWidget);
    await _type(tester, 'bb_r', '8');
    expect(find.textContaining('최소 반경'), findsNothing);
  });

  testWidgets('카톡 글과 입력값 남기기', (tester) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t);
    await _type(tester, 'bb_t', '10');
    await tester.tap(find.byKey(const Key('bb_share')));
    await tester.pumpAndSettle();
    expect(sent, startsWith('[부스바 절곡] L 꺾기 10×50mm 눕혀 꺾기'));
    expect(sent, contains('절단 길이:'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await _open(tester);
    expect(
      tester.widget<TextField>(find.byKey(const Key('bb_t'))).controller!.text,
      '10',
    );
  });
}
