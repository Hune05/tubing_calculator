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

  testWidgets('전동기 결선: 9단자·12단자 접속표와 그림이 나온다', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: CircuitReadingPage()));
    await tester.pumpAndSettle();
    await _tap(tester, 'cr_n9');
    expect(find.byKey(const Key('cr_box9')), findsOneWidget);
    // 처음은 Y 9단자 저전압: L1 → T1·T7, 점퍼 T4·T5·T6
    expect(find.textContaining('L1 → T1·T7, L2 → T2·T8, L3 → T3·T9'), findsOneWidget);
    expect(find.textContaining('T4·T5·T6 끼리 각각 묶습니다'), findsOneWidget);
    await _tap(tester, 'cr_w_y9_high');
    expect(find.textContaining('L1 → T1, L2 → T2, L3 → T3'), findsOneWidget);
    expect(find.textContaining('T4·T7 / T5·T8 / T6·T9 끼리 각각 묶습니다'), findsOneWidget);
    await _tap(tester, 'cr_w_d9_low');
    expect(find.textContaining('L1 → T1·T6·T7, L2 → T2·T4·T8, L3 → T3·T5·T9'), findsOneWidget);
    expect(find.textContaining('점퍼(연결편): 없음'), findsOneWidget);
    expect(find.textContaining('IEC 표기는 확인하지 못했습니다'), findsOneWidget);
    await _tap(tester, 'cr_n12');
    expect(find.byKey(const Key('cr_box12')), findsOneWidget);
    expect(find.textContaining('L1 → T1, L2 → T2, L3 → T3'), findsOneWidget);
    expect(find.textContaining('T4·T7 / T5·T8 / T6·T9 / T10·T11·T12 끼리 각각 묶습니다'), findsOneWidget);
    await _tap(tester, 'cr_w_d12_low');
    expect(find.textContaining('L1 → T1·T6·T7·T12, L2 → T2·T4·T8·T10, L3 → T3·T5·T9·T11'), findsOneWidget);
    await _tap(tester, 'cr_w_d12_high');
    expect(find.textContaining('L1 → T1·T12, L2 → T2·T10, L3 → T3·T11'), findsOneWidget);
    // 6단자로 돌아오면 기존 그림
    await _tap(tester, 'cr_n6');
    expect(find.byKey(const Key('cr_box')), findsOneWidget);
    expect(find.textContaining('Y-Δ 기동 접촉기 셋'), findsOneWidget);
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
