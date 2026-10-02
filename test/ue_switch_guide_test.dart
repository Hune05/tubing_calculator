// UE J120 스위치 셋팅 가이드(10-02): 따라하기가 끝까지 넘어가고, 시험대에서 잠금을 풀어야 육각이 돌고,
// 압력을 올리면 동작·내리면 복귀(데드밴드)가 기록된다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/instrument/ue_switch_guide_page.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  testWidgets('따라하기 14단계, 끝까지 넘겨도 예외가 없다', (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: UeSwitchGuidePage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('J120 (안쪽 육각)'));
    await tester.pumpAndSettle();
    final next = find.byKey(const Key('ue_walk_next'), skipOffstage: false);
    await tester.dragUntilVisible(find.byKey(const Key('ue_walk_next')), find.byKey(const Key('ue_list')), const Offset(0, -300));
    for (var i = 0; i < 14; i++) {
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.text('1 / 14'), findsOneWidget);
    for (var k = 0; k < 20; k++) {
      await tester.drag(find.byKey(const Key('ue_list')), const Offset(0, -900));
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('시험대: 잠금 나사를 안 풀면 육각이 안 돌고, 올리면 동작·내리면 복귀', (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: UeSwitchGuidePage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('J120 (안쪽 육각)'));
    await tester.pumpAndSettle();
    final list = find.byKey(const Key('ue_list'));
    final slider = find.byKey(const Key('ue_bench_slider'));
    await tester.dragUntilVisible(slider, list, const Offset(0, -300));
    await tester.pumpAndSettle();
    // 끝까지 올림(10 bar) → 동작 (그림용 설정점 5.2)
    final r = tester.getRect(slider);
    await tester.tapAt(Offset(r.right - 4, r.center.dy));
    await tester.pumpAndSettle();
    expect(find.textContaining('동작 (COM–N.O. 도통)', skipOffstage: false), findsNothing); // 그림 글자는 캔버스라 위젯에 없음
    expect(find.textContaining('bar (목표와', skipOffstage: false), findsOneWidget);
    // 0으로 내림 → 복귀 기록
    await tester.tapAt(Offset(r.left + 4, r.center.dy));
    await tester.pumpAndSettle();
    expect(find.textContaining('동작 뒤 압력을 내려', skipOffstage: false), findsNothing);
    // 잠금 안 풀고 돌리기 → 안내
    final cw = find.byKey(const Key('ue_bench_cw'));
    await tester.ensureVisible(cw);
    await tester.pumpAndSettle();
    await tester.tap(cw);
    await tester.pump();
    expect(find.text('먼저 십자 잠금 나사를 푸십시오'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    // 풀고 돌리면 기록이 지워짐(다시 시험)
    await tester.ensureVisible(find.byKey(const Key('ue_bench_lock')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ue_bench_lock')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(cw);
    await tester.pumpAndSettle();
    await tester.tap(cw);
    await tester.pumpAndSettle();
    expect(find.text('압력을 올려 보십시오', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('H122: 처음 열면 H122, 따라하기 10단계, 시험대에서 HIGH 올림·LOW 내림 동작, LOW를 HIGH보다 못 올림', (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: UeSwitchGuidePage()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('h122_fig')), findsOneWidget);
    final list = find.byKey(const Key('ue_list'));
    final next = find.byKey(const Key('h122_walk_next'), skipOffstage: false);
    await tester.dragUntilVisible(find.byKey(const Key('h122_walk_next')), list, const Offset(0, -300));
    for (var i = 0; i < 10; i++) {
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.text('1 / 10'), findsOneWidget);
    final slider = find.byKey(const Key('h122_bench_slider'));
    await tester.dragUntilVisible(slider, list, const Offset(0, -300));
    await tester.pumpAndSettle();
    final r = tester.getRect(slider);
    await tester.tapAt(Offset(r.right - 4, r.center.dy)); // 10 bar: HIGH 동작
    await tester.pumpAndSettle();
    await tester.tapAt(Offset(r.left + 4, r.center.dy)); // 0 bar: LOW 동작
    await tester.pumpAndSettle();
    expect(find.textContaining('(목표보다', skipOffstage: false), findsNWidgets(2));
    final up = find.byKey(const Key('h122_low_up'));
    await tester.ensureVisible(up);
    await tester.pumpAndSettle();
    for (var i = 0; i < 20; i++) {
      await tester.tap(up);
      await tester.pump();
    }
    expect(find.text('LOW를 HIGH보다 높게 맞출 수 없습니다 (설명서)'), findsWidgets);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    for (var k = 0; k < 20; k++) {
      await tester.drag(list, const Offset(0, -900));
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('접점 알기: SPDT 동작 전 → DPDT 동작 → 2SPDT 1번만 동작, 닫힌 접점 글이 바뀐다', (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: UeSwitchGuidePage()));
    await tester.pumpAndSettle();
    final list = find.byKey(const Key('ue_list'));
    await tester.dragUntilVisible(find.byKey(const Key('ue_ct_fig')), list, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('COM–N.C. 붙음 (통전) · N.O. 떨어짐'), findsOneWidget);
    Future<void> tap(String t) async {
      final f = find.text(t);
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }
    await tap('DPDT');
    await tap('압력 높음 (동작)');
    expect(find.text('접점 1: COM1–N.O.1 붙음 (통전) · N.C.1 떨어짐'), findsOneWidget);
    expect(find.text('접점 2: COM2–N.O.2 붙음 (통전) · N.C.2 떨어짐'), findsOneWidget);
    await tap('2SPDT');
    await tap('1번만 동작');
    expect(find.text('스위치 1: COM–N.O. 붙음 (통전) · N.C. 떨어짐'), findsOneWidget);
    expect(find.text('스위치 2: COM–N.C. 붙음 (통전) · N.O. 떨어짐'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
