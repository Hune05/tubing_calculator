// 부스바 가공 화면(10-03): 기본값 L 꺾기, U·Z 바꾸기, 반경 경고, 카톡 글, 입력값 남기기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_bend_page.dart';

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

  testWidgets('자유 꺾기: 기본 3곳(100씩·90°) → 마킹 3곳, 곳 수를 4·5로 늘리면 칸과 마킹이 따라 늘어난다', (tester) async {
    await _open(tester, height: 16000);
    await tester.tap(find.byKey(const Key('bb_k_free')));
    await tester.pumpAndSettle();
    // 기본: 직선 4개 400 + 호 3개(ρ 7 → 10.996 × 3 = 33.0)
    expect(find.text('433 mm'), findsOneWidget);
    expect(find.byKey(const Key('bb_fs_3')), findsOneWidget);
    expect(find.byKey(const Key('bb_fs_4')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('bb_n_4')));
    await tester.tap(find.byKey(const Key('bb_n_4')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bb_fs_4')), findsOneWidget);
    expect(find.text('544 mm'), findsOneWidget, reason: '직선 5개 500 + 호 4개 43.98');

    await tester.ensureVisible(find.byKey(const Key('bb_n_5')));
    await tester.tap(find.byKey(const Key('bb_n_5')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bb_fs_5')), findsOneWidget);
    expect(find.textContaining('꺾는 곳 5곳'), findsOneWidget);
  });

  testWidgets('자유 꺾기: 각도와 방향을 곳마다 바꾸면 마킹 줄에 위로·아래로가 반영된다', (tester) async {
    await _open(tester, height: 16000);
    await tester.tap(find.byKey(const Key('bb_k_free')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('bb_fa_0_45')));
    await tester.tap(find.byKey(const Key('bb_fa_0_45')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('bb_fd_0_down')));
    await tester.tap(find.byKey(const Key('bb_fd_0_down')));
    await tester.pumpAndSettle();
    expect(find.textContaining('아래로 45°'), findsWidgets);
    expect(find.textContaining('위로 90°'), findsWidgets, reason: '2번째·3번째 꺾기는 그대로');
  });

  testWidgets('자유 꺾기: 입력값(곳 수·길이·각도)이 남았다가 다시 열면 이어진다', (tester) async {
    await _open(tester, height: 16000);
    await tester.tap(find.byKey(const Key('bb_k_free')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('bb_n_5')));
    await tester.tap(find.byKey(const Key('bb_n_5')));
    await tester.pumpAndSettle();
    await _type(tester, 'bb_fs_5', '123');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await _open(tester, height: 16000);
    expect(find.byKey(const Key('bb_fs_5')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('bb_fs_5'))).controller!.text, '123');
  });

  testWidgets('자유 꺾기: 칸이 비면 계산하지 않고, 카톡 글에 모든 꺾기가 들어간다', (tester) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t, height: 16000);
    await tester.tap(find.byKey(const Key('bb_k_free')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('bb_n_4')));
    await tester.tap(find.byKey(const Key('bb_n_4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bb_share')));
    await tester.pumpAndSettle();
    expect(sent, contains('자유 꺾기'));
    for (final n in ['1.', '2.', '3.', '4.']) {
      expect(sent, contains(n));
    }
    expect(sent, contains('직선 100 · 위 90° · 직선 100 · 아래 90°'));

    await _type(tester, 'bb_fs_2', '');
    expect(find.text('— mm'), findsOneWidget);
  });
}
