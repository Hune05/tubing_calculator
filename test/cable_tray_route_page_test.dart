// 케이블 트레이 형상 계산기 화면(10-03): 기본값으로 바로 마킹, 각도·나눠 꺾기·종류 바꾸기, 카톡 글, 입력값 남기기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/cable_tray_route_page.dart';

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
          ? const CableTrayRoutePage()
          : CableTrayRoutePage(share: share),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('기본값(높이 300 + 여유 50, 90°, 측판 100): 마킹 4곳과 길이', (tester) async {
    await _open(tester);
    // 경사 350, 첫 꺾는 곳 1000 − 50 = 950, 윗면 500, 아랫변 V컷 200 × 2
    // 950 + 350 + 500 + 350 + 500 + 400 = 3,050
    expect(find.textContaining('넘어가기 90° · 마킹 4곳 · 3,050mm'), findsOneWidget);
    expect(find.text('950 mm · 위로 90° (IN)'), findsOneWidget);
    expect(find.text('1,400 mm · 아래로 90° (OUT)'), findsOneWidget);
    expect(find.textContaining('3m 트레이 2개'), findsOneWidget);
    expect(find.byKey(const Key('tr_side_view')), findsOneWidget);
    expect(find.byKey(const Key('tr_mark_view')), findsOneWidget);
  });

  testWidgets('카톡 글과 입력값 남기기', (tester) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t);
    await tester.tap(find.byKey(const Key('tr_rail_150')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tr_share')));
    await tester.pumpAndSettle();
    expect(sent, startsWith('[트레이 형상] 넘어가기 90° · 측판 높이 150mm'));
    expect(sent, contains('윗변 V컷 폭 300'));
    // 다시 열면 측판 150 그대로
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await _open(tester);
    expect(find.textContaining('3,250mm'), findsOneWidget);
  });

  testWidgets('45° 나눠 꺾기·올라가기, 너무 가까우면 알림', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('tr_a_45')));
    await tester.pumpAndSettle();
    expect(find.textContaining('한쪽 수평 길이 350mm'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tr_k_up')));
    await tester.pumpAndSettle();
    expect(find.textContaining('올라가기 45° · 마킹 2곳'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tr_n_3')));
    await tester.pumpAndSettle();
    expect(find.textContaining('올라가기 45° · 마킹 6곳'), findsOneWidget);
    expect(find.textContaining('나눠 꺾은 반경 약 R'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('tr_face')), '100');
    await tester.pumpAndSettle();
    expect(find.textContaining('너무 가깝습니다'), findsOneWidget);
  });
}
