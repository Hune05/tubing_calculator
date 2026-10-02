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

  testWidgets('가닥 수를 넣으면 판정과 권장 폭이 나오고, 폭 칩을 누르면 그 폭으로 판정한다', (tester) async {
    await _open(tester);
    expect(find.text('케이블 가닥 수를 넣으면 판정합니다'), findsNothing); // 기본 1가닥이 있어 바로 판정
    // F-CV 4심 35sq(외경 28) 32가닥 = 단면적 약 19,704mm², 여유 20% → 23,645 → 사다리형 900폭(27,090)
    await tester.enterText(find.byKey(const Key('ct_n_0')), '32');
    await tester.pumpAndSettle();
    expect(find.textContaining('사다리형 300 불합격'), findsOneWidget);
    expect(find.textContaining('권장 폭 900'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ct_wr_900')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ct_wr_900')));
    await tester.pumpAndSettle();
    expect(find.textContaining('사다리형 900 합격'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    // 여유 0%면 750폭(22,580)도 된다.
    await tester.tap(find.byKey(const Key('ct_m_0')));
    await tester.pumpAndSettle();
    expect(find.textContaining('권장 폭 750'), findsOneWidget);
    // 바닥밀폐형은 표가 작다: 19,704 ≤ 900폭 21,290.
    await tester.tap(find.byKey(const Key('ct_type_solid')));
    await tester.pumpAndSettle();
    expect(find.textContaining('권장 폭 900'), findsOneWidget);
  });

  testWidgets('줄 더하기, 번호를 잡고 밀어서 지우기·되돌리기, 직접 입력', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('ct_add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ct_no_1')), findsOneWidget);
    // 2번 줄을 직접 입력으로: 외경 40, 500sq, 단심 → 다심·단심 함께 → 모두 한 층
    await tester.tap(find.byKey(const Key('ct_kind_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('직접 입력 (외경)').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ct_od_1')), '40');
    await tester.enterText(find.byKey(const Key('ct_sz_1')), '500');
    await tester.enterText(find.byKey(const Key('ct_n_1')), '3');
    await tester.pumpAndSettle();
    expect(find.textContaining('모두 한 층'), findsWidgets);
    // 밀어서 지우고 되돌리기
    await tester.drag(find.byKey(const Key('ct_no_1')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ct_no_1')), findsNothing);
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ct_no_1')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('ct_od_1'))).controller!.text, '40');
  });

  testWidgets('제어·신호 케이블만이면 내 단면적 % 규칙', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('ct_ctrl_0')));
    await tester.pumpAndSettle();
    expect(find.textContaining('제어·신호 다심만'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('단면 그림이 나오고, 보내기 글에 판정·케이블이 들어간다', (tester) async {
    String? sent;
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: CableTrayPage(share: (t) async => sent = t)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ct_n_0')), '6');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ct_section'), skipOffstage: false), findsOneWidget);
    await tester.tap(find.byKey(const Key('ct_share')));
    await tester.pumpAndSettle();
    expect(sent, contains('[케이블 트레이 점유율] 사다리형 폭 300'));
    expect(sent, contains('판정: 합격'));
    expect(sent, contains('1. F-CV 4심 35sq × 6가닥'));
    expect(sent, contains('KEC 232.41'));
  });
}
