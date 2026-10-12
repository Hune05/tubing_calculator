// 칸 안 ▼ 목록(10-12, 사용자 "케이블 트레이 쪽이랑 접지바, 부스바 가공 쪽도 이렇게 변경하자"):
// 단추 줄 대신 큰 칸 + ▼. 목록 밖 값(부스바 각도 22.5°, 트레이 폭 250)도 칸에 바로 넣어 계산하고,
// 맞지 않는 값은 칸 아래에 알린다(트레이 가공).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/common/preset_menu.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_bend_page.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_ground_page.dart';
import 'package:tubing_calculator/src/presentation/electrical/cable_tray_page.dart';
import 'package:tubing_calculator/src/presentation/electrical/cable_tray_route_page.dart';

Future<void> _open(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

/// 목록 화면이 길어 아직 안 만들어진 칸이면 위·아래로 굴려 찾는다.
Future<void> _reveal(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  final sc = find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .first;
  for (final dy in [-400.0, 400.0]) {
    if (f.evaluate().isNotEmpty) break;
    for (var k = 0; k < 15 && f.evaluate().isEmpty; k++) {
      await tester.drag(sc, Offset(0, dy), warnIfMissed: false);
      await tester.pumpAndSettle();
    }
  }
  await tester.ensureVisible(f);
}

Future<void> _tap(WidgetTester tester, String key) async {
  if (find.byKey(Key(key)).evaluate().isEmpty) await _reveal(tester, key);
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await _reveal(tester, key);
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('목록 값 글: 끝 0을 지운다(칸 글과 맞춰 체크)', () {
    expect(presetKey(3), '3');
    expect(presetKey(13.5), '13.5');
    expect(presetKey(19.05), '19.05');
    expect(presetKey(0.333333), '0.333');
  });

  testWidgets('부스바 가공: 두께 ▼, 목록 밖 각도 22.5°도 칸에 바로', (tester) async {
    String? sent;
    await _open(tester, BusbarBendPage(share: (t) async => sent = t));
    // 10-12 철판 가공처럼 탭: 두께는 부스바 탭, 각도는 모양 탭, 카톡은 보내기 탭
    await _tap(tester, 'bb_tab_bar');
    await _tap(tester, 'bb_t_menu');
    await _tap(tester, 'bb_tv_10');
    expect(_text(tester, 'bb_t'), '10');
    await _tap(tester, 'bb_tab_shape');
    await _type(tester, 'bb_ang', '22.5');
    await _tap(tester, 'bb_tab_send');
    await _tap(tester, 'bb_share');
    expect(sent, contains('22.5°'));
    await _done(tester);
  });

  testWidgets('부스바 자유 꺾기: 꺾기마다 각도 칸(목록 밖 75°), 맞지 않으면 칸 아래 알림', (tester) async {
    String? sent;
    await _open(tester, BusbarBendPage(share: (t) async => sent = t));
    await _tap(tester, 'bb_k_free');
    await _type(tester, 'bb_fa_0', '75');
    expect(find.byKey(const Key('bb_fa_0_bad')), findsNothing);
    await _type(tester, 'bb_fa_1', '200');
    expect(find.byKey(const Key('bb_fa_1_bad')), findsOneWidget);
    await _type(tester, 'bb_fa_1', '30');
    await _tap(tester, 'bb_tab_send');
    await _tap(tester, 'bb_share');
    expect(sent, contains('UP 75°'));
    expect(sent, contains('DOWN 30°'));
    await _done(tester);
  });

  testWidgets('접지바 가공: 두께·폭 ▼', (tester) async {
    await _open(tester, const GroundBarPage());
    await _tap(tester, 'gb_tv_menu');
    await _tap(tester, 'gb_tv_800'); // 접지바 목록 키는 값 × 100(예전 단추와 같게)
    expect(_text(tester, 'gb_t'), '8');
    await _tap(tester, 'gb_wv_menu');
    await _tap(tester, 'gb_wv_10000');
    expect(_text(tester, 'gb_w'), '100');
    await _done(tester);
  });

  testWidgets('케이블 트레이 규격 선정: 표 밖 폭 250도 칸에 넣어 판정, ▼로 400', (tester) async {
    await _open(tester, const CableTrayPage());
    await _type(tester, 'ct_n_0', '10');
    await _type(tester, 'ct_w', '250');
    expect(find.textContaining('사다리형 250'), findsOneWidget);
    await _tap(tester, 'ct_w_menu');
    await _tap(tester, 'ct_w_400');
    expect(_text(tester, 'ct_w'), '400');
    expect(find.textContaining('사다리형 400 합격'), findsOneWidget);
    // 폭을 비우면 판정 대신 안내
    await _type(tester, 'ct_w', '');
    expect(find.text('트레이 폭과 내측 깊이를 넣으십시오'), findsOneWidget);
    await _done(tester);
  });

  testWidgets('케이블 트레이 가공: 각도 22.5° 바로, 맞지 않는 각도는 칸 아래 알림(마지막 맞는 값으로 계산)', (
    tester,
  ) async {
    String? sent;
    await _open(tester, CableTrayRoutePage(share: (t) async => sent = t));
    // 10-12 탭: 각도는 꺾기 탭, 카톡 글은 결과 탭
    await _tap(tester, 'tr_tab_bend');
    await _type(tester, 'tr_ang', '22.5');
    expect(find.byKey(const Key('tr_a_bad')), findsNothing);
    await _type(tester, 'tr_ang', '120');
    expect(find.byKey(const Key('tr_a_bad')), findsOneWidget);
    expect(find.textContaining('지금 계산은 22.5°'), findsOneWidget);
    await _type(tester, 'tr_ang', '22.5');
    await _tap(tester, 'tr_tab_result');
    await _tap(tester, 'tr_share');
    expect(sent, startsWith('[트레이 가공] 넘어가기 22.5°'));
    await _done(tester);
  });
}
