// 단위 환산 화면(홈 "단위 환산") — 한 분류의 모든 단위, 인치 분수, 찾기, 맨 위에 두기·숨기기,
// 전선 굵기·배관 호칭, 마지막 분류·값 기억.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/unit_converter/unit_converter_page.dart';

Future<void> pumpPage(WidgetTester tester, {String? initialCategory}) async {
  tester.view.physicalSize = const Size(390, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: UnitConverterPage(initialCategory: initialCategory)),
  );
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

Future<void> type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('처음엔 칸이 비어 있다("1"을 미리 넣지 않는다)', (tester) async {
    await pumpPage(tester);
    expect(textOf(tester, 'uc_field_mm'), '');
    expect(textOf(tester, 'uc_field_in'), '');
    expect(find.text('아무 칸에나 숫자를 넣으십시오'), findsOneWidget);
  });

  testWidgets('mm 35 → 인치 분수 1-3/8"과 오차, 인치 1.377953, 피트·인치', (tester) async {
    await pumpPage(tester);
    await type(tester, 'uc_field_mm', '35');
    expect(textOf(tester, 'uc_field_in_frac'), '1-3/8"');
    expect(textOf(tester, 'uc_field_in'), '1.377953');
    expect(textOf(tester, 'uc_field_cm'), '3.5');
    expect(textOf(tester, 'uc_field_ft_in'), '1-3/8"');
    expect(find.text('실제가 분수보다 0.08mm 깁니다'), findsOneWidget);
  });

  testWidgets('분수 칸에 1-3/8을 넣으면 mm 34.925, 분수 눈금 1/32로 바꾸면 다시 셈', (
    tester,
  ) async {
    await pumpPage(tester);
    await type(tester, 'uc_field_in_frac', '1-3/8');
    expect(textOf(tester, 'uc_field_mm'), '34.925');

    await type(tester, 'uc_field_mm', '36');
    expect(textOf(tester, 'uc_field_in_frac'), '1-7/16"');
    await tester.tap(find.byKey(const Key('uc_den_32')));
    await tester.pump();
    expect(textOf(tester, 'uc_field_in_frac'), '1-13/32"');
  });

  testWidgets('분수 칸을 누르면 자판 위에 - / 줄이 붙고, 눌러서 1-3/8을 만든다', (tester) async {
    await pumpPage(tester);
    expect(find.byKey(const Key('uc_symbols')), findsNothing);
    await tester.tap(find.byKey(const Key('uc_field_in_frac')));
    await tester.pump();
    expect(find.byKey(const Key('uc_symbols')), findsOneWidget);
    expect(find.byKey(const Key("uc_insert_'")), findsNothing); // 피트 표시는 피트 칸에서만

    await tester.enterText(find.byKey(const Key('uc_field_in_frac')), '1');
    await tester.tap(find.byKey(const Key('uc_insert_-')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('uc_field_in_frac')),
      '${textOf(tester, 'uc_field_in_frac')}3',
    );
    await tester.tap(find.byKey(const Key('uc_insert_/')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('uc_field_in_frac')),
      '${textOf(tester, 'uc_field_in_frac')}8',
    );
    await tester.pump();
    expect(textOf(tester, 'uc_field_in_frac'), '1-3/8');
    expect(textOf(tester, 'uc_field_mm'), '34.925');
    // 단추를 눌러도 칸에서 커서가 빠지지 않는다.
    final f = tester.widget<TextField>(find.byKey(const Key('uc_field_in_frac')));
    expect(f.focusNode!.hasFocus, isTrue);
  });

  testWidgets("피트·인치 칸에는 ' \" 단추도 있다", (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('uc_field_ft_in')));
    await tester.pump();
    expect(find.byKey(const Key("uc_insert_'")), findsOneWidget);
    expect(find.byKey(const Key('uc_insert_"')), findsOneWidget);
  });

  testWidgets("피트·인치 칸: 4' 1-3/8 → mm 1254.125", (tester) async {
    await pumpPage(tester);
    await type(tester, 'uc_field_ft_in', "4' 1-3/8");
    expect(textOf(tester, 'uc_field_mm'), '1254.125');
  });

  testWidgets('압력: psi 100 → bar 6.894757, kgf/cm² 7.030696', (tester) async {
    await pumpPage(tester, initialCategory: 'pressure');
    await type(tester, 'uc_field_psi', '100');
    expect(textOf(tester, 'uc_field_bar'), '6.894757');
    expect(textOf(tester, 'uc_field_kgfcm2'), '7.030696');
    expect(textOf(tester, 'uc_field_mpa'), '0.6894757');
  });

  testWidgets('지우기를 누르면 이 분류의 칸이 모두 빈다', (tester) async {
    await pumpPage(tester, initialCategory: 'pressure');
    await type(tester, 'uc_field_bar', '10');
    await tester.tap(find.byKey(const Key('uc_clear')));
    await tester.pump();
    expect(textOf(tester, 'uc_field_bar'), '');
    expect(textOf(tester, 'uc_field_psi'), '');
  });

  testWidgets('분류를 바꿨다 돌아와도 값이 남고, 다시 열면 마지막 분류·값', (tester) async {
    await pumpPage(tester);
    await type(tester, 'uc_field_mm', '100');
    await tester.tap(find.byKey(const Key('uc_cat_torque')));
    await tester.pumpAndSettle();
    await type(tester, 'uc_field_nm', '10');
    expect(textOf(tester, 'uc_field_lbfft'), '7.375621');
    await tester.tap(find.byKey(const Key('uc_cat_length')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'uc_field_mm'), '100');
    expect(textOf(tester, 'uc_field_in'), '3.937008');

    // 닫고 다시 열기(폰에 남은 것).
    await tester.tap(find.byKey(const Key('uc_cat_torque')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await pumpPage(tester);
    expect(textOf(tester, 'uc_field_nm'), '10');
    expect(textOf(tester, 'uc_field_lbfft'), '7.375621');
  });

  testWidgets('찾기: psi를 누르면 압력 분류로, psi 칸에 커서', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('uc_search')), 'psi');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('uc_hit_pressure_psi')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('uc_field_bar')), findsOneWidget);
    final psi = tester.widget<TextField>(find.byKey(const Key('uc_field_psi')));
    expect(psi.focusNode!.hasFocus, isTrue);
  });

  testWidgets('⋮ 맨 위에 두기 → 첫 줄로, 숨기기 → 사라지고 다시 보이기', (tester) async {
    await pumpPage(tester, initialCategory: 'pressure');
    double topOf(String id) =>
        tester.getTopLeft(find.byKey(Key('uc_field_$id'))).dy;
    expect(topOf('psi'), greaterThan(topOf('mpa')));

    await tester.tap(find.byKey(const Key('uc_menu_psi')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('맨 위에 두기'));
    await tester.pumpAndSettle();
    expect(topOf('psi'), lessThan(topOf('mpa')));

    await tester.tap(find.byKey(const Key('uc_menu_inhg')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('숨기기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('uc_field_inhg')), findsNothing);
    await tester.tap(find.byKey(const Key('uc_unhide')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('uc_field_inhg')), findsOneWidget);

    final p = await SharedPreferences.getInstance();
    await tester.pump(const Duration(seconds: 1));
    expect(p.getStringList(kUnitConvFavKey), ['pressure/psi']);
  });

  testWidgets('전선 굵기: AWG 10 → 5.26mm², 가장 가까운 6sq; 2.5sq → AWG 14', (
    tester,
  ) async {
    await pumpPage(tester, initialCategory: 'wire');
    await type(tester, 'uc_awg', '10');
    expect(textOf(tester, 'uc_sq'), '5.26');
    expect(find.textContaining('가장 가까운 규격 6sq'), findsOneWidget);

    await type(tester, 'uc_sq', '2.5');
    expect(textOf(tester, 'uc_awg'), '14');
    expect(find.textContaining('같거나 굵은 AWG 12'), findsOneWidget);
  });

  testWidgets('좁은 폰(344)·큰 글씨(1.3배)에서 모든 분류가 넘치지 않는다', (tester) async {
    // 넘치면 테스트 틀이 그 오류로 실패시킨다.
    tester.view.physicalSize = const Size(344, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const UnitConverterPage(),
      ),
    );
    await tester.pumpAndSettle();
    await type(tester, 'uc_field_mm', '1234.5');
    final chips = find.descendant(
      of: find.byKey(const Key('uc_cats')),
      matching: find.byType(Scrollable),
    );
    for (final id in [
      'pressure',
      'torque',
      'mass',
      'force',
      'temp',
      'flow',
      'area',
      'volume',
      'angle',
      'power',
      'wire',
      'pipe',
      'length',
    ]) {
      // 칩 줄은 옆으로 미는 목록이라 화면 밖 칩은 밀어서 찾는다(길이는 맨 앞).
      await tester.scrollUntilVisible(
        find.byKey(Key('uc_cat_$id')),
        id == 'length' ? -120 : 120,
        scrollable: chips,
      );
      await tester.tap(find.byKey(Key('uc_cat_$id')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: id);
    }
  });

  testWidgets('배관 호칭: 15A 줄에 1/2·15·21.7·21.3', (tester) async {
    await pumpPage(tester, initialCategory: 'pipe');
    expect(find.text('15A'), findsOneWidget);
    expect(find.text('21.7'), findsOneWidget);
    expect(find.text('21.3'), findsOneWidget);
    expect(find.textContaining('KS D 3507'), findsOneWidget);
  });
}
