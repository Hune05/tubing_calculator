// 케이블 트레이 계산기 화면(10-03): 가닥 수를 넣으면 판정·권장 폭, 폭 칩, 줄 더하기·밀어서 지우기, 직접 입력.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/cable_tray_page.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: CableTrayPage()));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('KEC(기본): 외경 합으로 판정과 권장 폭, 폭 칩을 누르면 그 폭으로', (tester) async {
    await _open(tester);
    expect(find.text('케이블 가닥 수를 넣으면 판정합니다'), findsNothing); // 기본 1가닥이 있어 바로 판정
    // F-CV 4심 35sq(외경 28) 10가닥 = 외경 합 280, 여유 20% → 336 → 300폭 불합격, 400폭
    await tester.enterText(find.byKey(const Key('ct_n_0')), '10');
    await tester.pumpAndSettle();
    expect(find.textContaining('사다리형 300 불합격'), findsOneWidget);
    expect(find.textContaining('권장 폭 400'), findsOneWidget);
    expect(find.textContaining('KEC 232.41: 케이블 외경 합'), findsWidgets);
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ct_wr_400')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ct_wr_400')));
    await tester.pumpAndSettle();
    expect(find.textContaining('사다리형 400 합격'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    // 여유 0%면 280 ≤ 300
    await tester.tap(find.byKey(const Key('ct_m_0')));
    await tester.pumpAndSettle();
    expect(find.textContaining('권장 폭 300'), findsOneWidget);
  });

  testWidgets('옛 판단기준(참고)으로 바꾸면 점유면적 표로 본다', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('ct_std_old213')));
    await tester.pumpAndSettle();
    // 32가닥 단면적 약 19,704mm² × 1.2 = 23,645 → 800폭(표에 없어 비례 24,080)
    await tester.enterText(find.byKey(const Key('ct_n_0')), '32');
    await tester.pumpAndSettle();
    expect(find.textContaining('권장 폭 800'), findsOneWidget);
    expect(find.textContaining('다심 100mm² 미만'), findsWidgets);
    // 바닥밀폐형, 여유 0%: 19,704 ≤ 900폭 21,290
    await tester.tap(find.byKey(const Key('ct_m_0')));
    await tester.tap(find.byKey(const Key('ct_type_solid')));
    await tester.pumpAndSettle();
    expect(find.textContaining('권장 폭 900'), findsOneWidget);
  });

  testWidgets('줄 더하기, 번호를 잡고 밀어서 지우기·되돌리기, 직접 입력', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('ct_add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ct_no_1')), findsOneWidget);
    // 2번 줄을 직접 입력으로: 외경 40, 500sq, 단심 3가닥
    await tester.tap(find.byKey(const Key('ct_kind_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('직접 입력 (외경)').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ct_od_1')), '40');
    await tester.enterText(find.byKey(const Key('ct_sz_1')), '500');
    await tester.enterText(find.byKey(const Key('ct_n_1')), '3');
    await tester.pumpAndSettle();
    // 외경 합 28 + 40×3 = 148 × 1.2 = 177.6 → 300폭 59%, 권장 200
    expect(find.textContaining('사다리형 300 합격 59% · 권장 폭 200'), findsOneWidget);
    // 밀어서 지우고 되돌리기
    await tester.drag(find.byKey(const Key('ct_no_1')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ct_no_1')), findsNothing);
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ct_no_1')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('ct_od_1'))).controller!.text, '40');
  });

  testWidgets('옛 기준: 제어·신호 케이블만이면 내 단면적 % 규칙', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('ct_std_old213')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ct_ctrl_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ct_ctrl_0')));
    await tester.pumpAndSettle();
    expect(find.textContaining('제어·신호 다심만'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('단면 그림이 나오고, 보내기 글에 판정·케이블이 들어간다', (tester) async {
    String? sent;
    tester.view.physicalSize = const Size(800, 4400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: CableTrayPage(share: (t) async => sent = t)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ct_n_0')), '6');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ct_section'), skipOffstage: false), findsOneWidget);
    await tester.tap(find.byKey(const Key('ct_share')));
    await tester.pumpAndSettle();
    expect(sent, contains('[케이블 트레이] 사다리형 폭 300'));
    expect(sent, contains('기준: KEC 232.41 (현행)'));
    expect(sent, contains('판정: 합격'));
    expect(sent, contains('1. F-CV 4심 35sq × 6가닥'));
    expect(sent, contains('KEC 232.41'));
  });

  testWidgets('AMS 쌍 케이블을 고르면 외경·무게 표로 계산한다', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('ct_kind_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('F-CVV-I/C-AMS 쌍').last);
    await tester.pumpAndSettle();
    // 기본 2P 1.5sq: 외경 18.5 → 10가닥 185mm × 1.2 = 222 ≤ 300
    await tester.enterText(find.byKey(const Key('ct_n_0')), '10');
    await tester.pumpAndSettle();
    expect(find.textContaining('사다리형 300 합격 74%'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('ct_ctrl_0'))).selected, isTrue); // 제어·신호로
  });
}
