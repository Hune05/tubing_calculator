// 부스바 가공 화면(10-03, 10-12 철판 가공처럼 위 그림 + 아래 탭): 기본값 ㄱ자, ㄷ자·Z자 바꾸기, 반경 경고,
// 카톡 글, 입력값 남기기, 연속 절곡. 칸은 모양·부스바 탭, 결과는 결과 탭, 카톡·PDF는 보내기 탭.
// 10-12 용어 정리(docs/가공_용어_정리_1012.md): 절곡·내R·K값·UP/DOWN·측면도·전개도·전개 길이.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_bend_page.dart';

Future<void> _open(
  WidgetTester tester, {
  Future<void> Function(String)? share,
  double height = 2400,
}) async {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
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

Future<void> _tab(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(Key('bb_tab_$id')));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    '기본값(5T×50, 내R 5, K값 0.4, 바깥 100×100, 90°): 전개 길이 191.0, 위 그림은 측면도·전개도',
    (tester) async {
      await _open(tester);
      // 위 그림: 처음은 측면도, "전개도"를 누르면 마킹
      expect(find.byKey(const Key('bb_shape_view')), findsOneWidget);
      await _tap(tester, 'bb_vm_mark');
      expect(find.byKey(const Key('bb_mark_view')), findsOneWidget);
      expect(find.textContaining('전개 길이 191mm'), findsOneWidget); // 제목 아래 요약
      await _tab(tester, 'result');
      // ρ = 7, 다리 97, 물림 7, 호 10.996 → 90 + 10.996 + 90
      expect(find.text('191 mm'), findsOneWidget);
      expect(find.text('90 mm · UP 90°'), findsOneWidget);
    },
  );

  testWidgets('ㄷ자는 마킹 2곳, Z자는 높이가 낮으면 알림', (tester) async {
    await _open(tester);
    await _tap(tester, 'bb_k_u');
    await _tab(tester, 'result');
    expect(find.textContaining('90°'), findsWidgets);
    expect(find.text('90 mm · UP 90°'), findsOneWidget);
    await _tab(tester, 'shape');
    await _tap(tester, 'bb_k_z');
    // 각도는 칸 + ▼ 목록(10-12)
    await _tap(tester, 'bb_a_menu');
    await _tap(tester, 'bb_a_45');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('bb_ang')))
          .controller!
          .text,
      '45',
    );
    await _type(tester, 'bb_ih', '3');
    expect(find.textContaining('절곡할 수 없습니다'), findsOneWidget);
    await _type(tester, 'bb_ih', '40');
    expect(find.textContaining('절곡할 수 없습니다'), findsNothing);
    await _tab(tester, 'result');
    expect(find.textContaining('경사부 길이'), findsOneWidget);
  });

  testWidgets('ㄱ자 다리가 반경보다 짧으면 절곡할 수 없다고 알린다(10-07)', (tester) async {
    await _open(tester);
    await _tab(tester, 'bar');
    await _type(tester, 'bb_t', '10');
    await _type(tester, 'bb_r', '10');
    await _tab(tester, 'shape');
    await _type(tester, 'bb_ia', '15');
    await _tab(tester, 'result');
    expect(find.textContaining('다리가 짧아'), findsOneWidget);
    await _tab(tester, 'shape');
    await _type(tester, 'bb_ia', '100');
    await _tab(tester, 'result');
    expect(find.textContaining('다리가 짧아'), findsNothing);
  });

  testWidgets('평절곡 내R이 두께보다 작으면 CDA 최소 내R 경고', (tester) async {
    await _open(tester);
    await _tab(tester, 'bar');
    await _type(tester, 'bb_r', '2');
    await _tab(tester, 'result');
    expect(find.textContaining('최소 내R 5mm(CDA'), findsOneWidget);
    await _tab(tester, 'bar');
    await _type(tester, 'bb_r', '8');
    await _tab(tester, 'result');
    expect(find.textContaining('최소 내R'), findsNothing);
  });

  testWidgets('카톡 글과 입력값 남기기', (tester) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t);
    await _tab(tester, 'bar');
    await _type(tester, 'bb_t', '10');
    await _tab(tester, 'send');
    await _tap(tester, 'bb_share');
    expect(sent, startsWith('[부스바 절곡] ㄱ자 10T×50mm 평절곡'));
    expect(sent, contains('전개 길이:'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await _open(tester);
    await _tab(tester, 'bar');
    expect(
      tester.widget<TextField>(find.byKey(const Key('bb_t'))).controller!.text,
      '10',
    );
  });

  testWidgets('연속 절곡: 기본 3곳(100씩·90°) → 마킹 3곳, 곳 수를 4·5로 늘리면 칸과 마킹이 따라 늘어난다', (
    tester,
  ) async {
    await _open(tester);
    await _tap(tester, 'bb_k_free');
    expect(find.byKey(const Key('bb_fs_3')), findsOneWidget);
    expect(find.byKey(const Key('bb_fs_4')), findsNothing);
    await _tab(tester, 'result');
    // 기본: 직선 4개 400 + 호 3개(ρ 7 → 10.996 × 3 = 33.0)
    expect(find.text('433 mm'), findsOneWidget);
    await _tab(tester, 'shape');
    await _tap(tester, 'bb_n_4');
    expect(find.byKey(const Key('bb_fs_4')), findsOneWidget);
    await _tab(tester, 'result');
    expect(
      find.text('544 mm'),
      findsOneWidget,
      reason: '직선 5개 500 + 호 4개 43.98',
    );
    await _tab(tester, 'shape');
    await _tap(tester, 'bb_n_5');
    expect(find.byKey(const Key('bb_fs_5')), findsOneWidget);
    await _tab(tester, 'result');
    expect(find.textContaining('절곡 5곳'), findsWidgets);
  });

  testWidgets('연속 절곡: 각도와 방향을 곳마다 바꾸면 마킹 줄에 UP·DOWN이 반영된다', (tester) async {
    await _open(tester);
    await _tap(tester, 'bb_k_free');
    // 절곡마다 각도는 칸 + ▼(10-12)
    await _tap(tester, 'bb_fa_0_menu');
    await _tap(tester, 'bb_fa_0_45');
    await _tap(tester, 'bb_fd_0_down');
    await _tab(tester, 'result');
    expect(find.textContaining('DOWN 45°'), findsWidgets);
    expect(
      find.textContaining('UP 90°'),
      findsWidgets,
      reason: '2번째·3번째 절곡은 그대로',
    );
  });

  testWidgets('연속 절곡: 입력값(곳 수·길이·각도)이 남았다가 다시 열면 이어진다', (tester) async {
    await _open(tester);
    await _tap(tester, 'bb_k_free');
    await _tap(tester, 'bb_n_5');
    await _type(tester, 'bb_fs_5', '123');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await _open(tester);
    expect(find.byKey(const Key('bb_fs_5')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('bb_fs_5')))
          .controller!
          .text,
      '123',
    );
  });

  testWidgets('연속 절곡: 칸이 비면 계산하지 않고, 카톡 글에 모든 절곡이 들어간다', (tester) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t);
    await _tap(tester, 'bb_k_free');
    await _tap(tester, 'bb_n_4');
    await _tab(tester, 'send');
    await _tap(tester, 'bb_share');
    expect(sent, contains('연속 절곡'));
    for (final n in ['1.', '2.', '3.', '4.']) {
      expect(sent, contains(n));
    }
    expect(sent, contains('직선부 100 · UP 90° · 직선부 100 · DOWN 90°'));
    await _tab(tester, 'shape');
    await _type(tester, 'bb_fs_2', '');
    await _tab(tester, 'result');
    expect(find.text('— mm'), findsOneWidget);
  });

  testWidgets('수직절곡은 평면도(넓은 면)라고 알린다(10-12)', (tester) async {
    await _open(tester);
    // 위 그림 단추 이름: 평절곡은 측면도, 수직절곡은 평면도
    expect(find.text('측면도'), findsOneWidget);
    await _tap(tester, 'bb_p_edge');
    expect(find.text('평면도'), findsOneWidget);
    expect(find.text('측면도'), findsNothing);
    expect(find.byKey(const Key('bb_shape_view')), findsOneWidget);
  });

  testWidgets('수직절곡 ㄷ자: 바닥이 반경보다 짧으면 그림 아래·제목 줄에도 알린다(10-12)', (tester) async {
    await _open(tester);
    await _tab(tester, 'bar');
    await _type(tester, 'bb_t', '6');
    await _type(tester, 'bb_w', '30');
    await _tab(tester, 'shape');
    await _tap(tester, 'bb_k_u');
    await _tap(tester, 'bb_p_edge');
    // 반경 30(폭 1배) + 폭 30 = 60씩: 바닥 바깥 100으로는 직선이 −20
    expect(find.textContaining('그림이 겹침'), findsOneWidget);
    Color? headColor() =>
        tester.widget<Text>(find.byKey(const Key('bb_head'))).style!.color;
    final bad = headColor(); // 제목 줄도 경고 색
    await _type(tester, 'bb_ib', '200');
    expect(find.textContaining('그림이 겹침'), findsNothing);
    expect(headColor(), isNot(bad));
  });
}
