// 결선도·기동 회로 화면: 버튼을 누르면 바뀐 코일이 순서대로 나오고, Y-Δ는 타이머로 전환된다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/circuit_reading_page.dart';

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pump();
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
}

void main() {
  testWidgets('전동기 결선: Y·Δ 설명이 바뀐다', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: CircuitReadingPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('아래 줄 W2·U2·V2를 한데 묶습니다'), findsOneWidget);
    await _tap(tester, 'cr_d');
    expect(find.textContaining('U1-W2, V1-U2, W1-V2'), findsOneWidget);
  });

  testWidgets('직입: 기동 누르면 자기유지, 정지로 멈춤', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: CircuitReadingPage(initialTab: 1)));
    await tester.pumpAndSettle();
    await _tap(tester, 'dol_btn_PB1');
    expect(find.textContaining('기동 PB1 누름 → MC 코일 여자'), findsOneWidget);
    expect(find.textContaining('그대로 유지(자기유지'), findsOneWidget);
    await _tap(tester, 'dol_btn_PB0');
    expect(find.textContaining('정지 PB0 누름 → MC 코일 소자'), findsOneWidget);
  });

  testWidgets('Y-Δ: 3초 뒤 MC-Y가 떨어지고 MC-Δ가 붙는다', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: CircuitReadingPage(initialTab: 3)));
    await tester.pumpAndSettle();
    await _tap(tester, 'yd_btn_PB1');
    expect(find.byKey(const Key('yd_timer')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('타이머 3초 경과'), findsOneWidget);
    expect(find.textContaining('MC-Δ 코일 여자'), findsOneWidget);
    expect(find.byKey(const Key('yd_timer')), findsNothing);
    await _tap(tester, 'yd_btn_PB0');
  });
}
