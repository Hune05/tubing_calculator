// 접지바 구멍 계산기 화면(10-03): 기본값, 막대 길이로 바꾸기, 겹침 알림, 카톡 글, 입력값 남기기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_ground_page.dart';

Future<void> _open(
  WidgetTester tester, {
  Future<void> Function(String)? share,
}) async {
  tester.view.physicalSize = const Size(800, 5200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: share == null ? const GroundBarPage() : GroundBarPage(share: share),
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

  testWidgets('기본값(구멍 10개, 피치 25.4, 끝 25): 길이 278.6', (tester) async {
    await _open(tester);
    // 50 + 9 × 25.4 = 278.6
    expect(find.text('278.6 mm'), findsOneWidget);
    expect(find.text('1번 25'), findsOneWidget);
    expect(find.text('10번 253.6'), findsOneWidget);
    expect(find.byKey(const Key('gb_view')), findsOneWidget);
  });

  testWidgets('막대 길이로: 500mm에는 구멍 18개', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('gb_by_len')));
    await tester.pumpAndSettle();
    // (500 − 50) ÷ 25.4 = 17.7 → 17칸 → 18개
    expect(find.textContaining('구멍 18개'), findsWidgets);
  });

  testWidgets('피치가 구멍 지름 이하이면 겹침 알림, 피치 칩은 칸을 채운다', (tester) async {
    await _open(tester);
    await _type(tester, 'gb_pitch', '8');
    expect(find.textContaining('서로 겹칩니다'), findsOneWidget);
    await tester.tap(find.byKey(const Key('gb_pp_4445')));
    await tester.pumpAndSettle();
    expect(find.textContaining('서로 겹칩니다'), findsNothing);
  });

  testWidgets('카톡 글과 입력값 남기기', (tester) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t);
    await _type(tester, 'gb_n', '4');
    await tester.tap(find.byKey(const Key('gb_share')));
    await tester.pumpAndSettle();
    expect(sent, startsWith('[접지바] 구리 6×50mm · 구멍 φ11.1 4개 피치 25.4'));
    expect(sent, contains('자르는 길이: 126.2mm'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await _open(tester);
    expect(
      tester.widget<TextField>(find.byKey(const Key('gb_n'))).controller!.text,
      '4',
    );
  });
}
