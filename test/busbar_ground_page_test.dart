// 접지바 구멍 계산기 화면(10-03): 기본값, 막대 길이로 바꾸기, 겹침 알림, 카톡 글, 입력값 남기기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_ground_page.dart';

Future<void> _open(
  WidgetTester tester, {
  Future<void> Function(String)? share,
  double height = 5200,
}) async {
  tester.view.physicalSize = Size(800, height);
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
    expect(find.text('첫 구멍 25 → 피치 25.4 × 9칸 → 마지막 구멍 253.6'), findsOneWidget);
    expect(find.text('1~5번'), findsOneWidget);
    expect(find.text('6~10번'), findsOneWidget);
    expect(find.text('25   50.4   75.8   101.2   126.6'), findsOneWidget);
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

  testWidgets('끝 L 꺾기: 왼쪽 탭을 켜면 꺾기 선과 옆모습, 카톡 글에 포함', (tester) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t);
    await tester.tap(find.byKey(const Key('gb_tab_1')));
    await tester.pumpAndSettle();
    await _type(tester, 'gb_n', '4');
    await _type(tester, 'gb_tabl', '40');
    await _type(tester, 'gb_t', '6');
    // 곧은 28 + 호 13.2 + 구멍 줄 126.2
    expect(find.text('167.4 mm'), findsOneWidget);
    expect(find.byKey(const Key('gb_shape_view')), findsOneWidget);
    expect(find.textContaining('왼쪽 탭 · 시작선 28 mm'), findsOneWidget);
    expect(find.textContaining('첫 구멍 66.2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('gb_share')));
    await tester.pumpAndSettle();
    expect(sent, contains('왼쪽 탭 꺾기 시작선 28 · 끝선 41.2mm'));
    expect(sent, contains('1~4번 66.2 · 91.6 · 117 · 142.4'));
  });

  testWidgets('탭이 너무 짧으면 알림', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('gb_tab_2')));
    await tester.pumpAndSettle();
    await _type(tester, 'gb_tabr', '5');
    expect(find.textContaining('꺾기에 너무 짧습니다'), findsOneWidget);
  });

  testWidgets('모자: 챙·높이 입력, 꺾기 4곳, 챙 구멍 위치, 옆모습', (tester) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t, height: 12000);
    await _type(tester, 'gb_n', '4');
    await tester.tap(find.byKey(const Key('gb_tab_4')));
    await tester.pumpAndSettle();
    await _type(tester, 'gb_t', '6');
    await _type(tester, 'gb_hatf', '50');
    await tester.tap(find.byKey(const Key('gb_mc_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gb_shape_view')), findsOneWidget);
    expect(find.textContaining('왼쪽 챙 → 다리'), findsWidgets);
    expect(find.textContaining('오른쪽 다리 → 챙'), findsWidgets);
    expect(find.byKey(const Key('gb_tab_holes')), findsOneWidget);
    expect(find.text('19'), findsOneWidget); // 왼쪽 챙 구멍: 평평한 38 가운데
    await tester.tap(find.byKey(const Key('gb_share')));
    await tester.pumpAndSettle();
    expect(sent, contains('모자 높이 40 · 챙 50'));
    expect(sent, contains('챙 구멍 φ11.1 (왼쪽 끝에서 중심): 왼쪽 1 19 · 오른쪽 1'));
  });

  testWidgets('두 줄 대칭·비대칭 바꾸기: 줄 간격, A·B줄 위치, 엇갈림 칸', (tester) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t, height: 9000);
    await tester.tap(find.byKey(const Key('gb_rm_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gb_gap')), findsOneWidget);
    expect(find.byKey(const Key('gb_shift')), findsNothing);
    // 폭 50, 간격 20 → A줄 15 · B줄 35, 길이 변화 없음 278.6
    expect(find.text('278.6 mm'), findsOneWidget);
    expect(find.textContaining('두 줄 대칭'), findsWidgets);
    expect(find.text('A1~5'), findsOneWidget);
    expect(find.text('B1~5'), findsOneWidget);
    await tester.tap(find.byKey(const Key('gb_rm_2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gb_shift')), findsOneWidget);
    expect(find.text('291.3 mm'), findsOneWidget); // 278.6 + 12.7
    await tester.tap(find.byKey(const Key('gb_share')));
    await tester.pumpAndSettle();
    expect(sent, contains('구멍 φ11.1 10개 × 2줄'));
    expect(sent, contains('B줄은 길이 방향으로 12.7mm 옮김'));
  });

  testWidgets('구멍 하나만 크기 바꾸기: 적용·기본으로·전부 기본으로', (tester) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t, height: 9000);
    expect(find.byKey(const Key('gb_ov_list')), findsNothing);
    await _type(tester, 'gb_ovdia', '18');
    await tester.tap(find.byKey(const Key('gb_ov_apply'))); // 처음 구멍(1번)이 선택돼 있다
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gb_ov_list')), findsOneWidget);
    expect(find.textContaining('바꾼 구멍 1개: 1번 φ18'), findsOneWidget);
    await tester.tap(find.byKey(const Key('gb_share')));
    await tester.pumpAndSettle();
    expect(sent, contains('크기 바꾼 구멍: 1번 φ18'));
    await tester.tap(find.byKey(const Key('gb_ov_reset')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gb_ov_list')), findsNothing);
    // 너무 큰 지름은 겹침 알림
    await _type(tester, 'gb_ovdia', '45');
    await tester.tap(find.byKey(const Key('gb_ov_apply')));
    await tester.pumpAndSettle();
    expect(find.textContaining('서로 겹칩니다'), findsWidgets);
    await tester.tap(find.byKey(const Key('gb_ov_clear')));
    await tester.pumpAndSettle();
    expect(find.textContaining('서로 겹칩니다'), findsNothing);
  });

  testWidgets('모자 오른쪽 챙을 따로: 비우면 같고 넣으면 길이가 늘어난다', (tester) async {
    await _open(tester, height: 9000);
    await tester.tap(find.byKey(const Key('gb_tab_4')));
    await tester.pumpAndSettle();
    final before = find.textContaining('mm · 구멍');
    expect(before, findsWidgets);
    expect(find.byKey(const Key('gb_hatfr')), findsOneWidget);
    await _type(tester, 'gb_hatfr', '60');
    expect(find.textContaining('챙 40 / 60'), findsWidgets);
  });
}
