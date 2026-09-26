// 단위 환산 화면(홈 "단위 환산") — 한 분류의 모든 단위, 인치 분수, 찾기, 맨 위 고정·숨기기,
// 전선 굵기·배관 호칭, 마지막 분류·값 기억. 2026-09-26 점검: 누르면 전체 선택, 길게 눌러
// 복사, 못 읽는 글·절대영도 알림, 쉼표 소수점, 게이지·절대압, 외경으로 호칭 찾기, 현장 자료
// 찾기에서 단위 분류로 바로 열기.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/reference/page/tube_reference_page.dart';
import 'package:tubing_calculator/src/presentation/unit_converter/unit_converter_page.dart';
import 'package:tubing_calculator/src/presentation/unit_converter/unit_defs.dart';

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
    expect(find.text('아무 칸에나 숫자를 입력하십시오'), findsOneWidget);
  });

  testWidgets('mm 35 → 인치 분수 1-3/8"과 오차, 인치 1.377953, 피트·인치', (tester) async {
    await pumpPage(tester);
    await type(tester, 'uc_field_mm', '35');
    expect(textOf(tester, 'uc_field_in_frac'), '1-3/8"');
    expect(textOf(tester, 'uc_field_in'), '1.377953');
    expect(textOf(tester, 'uc_field_cm'), '3.5');
    expect(textOf(tester, 'uc_field_ft_in'), '1-3/8"');
    expect(find.text('1-3/8"보다 0.08mm 깁니다'), findsOneWidget);
    expect(find.text('나머지 칸은 자동으로 바뀝니다'), findsOneWidget);

    await type(tester, 'uc_field_mm', '25.4');
    expect(find.text('오차 없음'), findsOneWidget);
  });

  testWidgets('분수 칸에 1-3/8을 넣으면 mm 34.925, 분수 눈금 1/32로 바꾸면 다시 계산', (
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
    expect(
      find.byKey(const Key("uc_insert_'")),
      findsNothing,
    ); // 피트 표시는 피트 칸에서만

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
    final f = tester.widget<TextField>(
      find.byKey(const Key('uc_field_in_frac')),
    );
    expect(f.focusNode!.hasFocus, isTrue);
    // 치는 중인 분수("1-", "1-3/")는 못 읽는다고 알리지 않는다.
    expect(find.byKey(const Key('uc_bad_input')), findsNothing);
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

  testWidgets(
    '압력: 게이지 0 bar → 1.01325 bar(a), 진공 -1.01325 bar → 0 bar(a), 안내 글',
    (tester) async {
      await pumpPage(tester, initialCategory: 'pressure');
      expect(find.textContaining('게이지압입니다'), findsOneWidget);
      await type(tester, 'uc_field_bar', '0');
      expect(textOf(tester, 'uc_field_bara'), '1.01325');
      expect(textOf(tester, 'uc_field_kpaa'), '101.325');
      expect(textOf(tester, 'uc_field_psia'), '14.69595');
      await type(tester, 'uc_field_bar', '-1.01325');
      expect(textOf(tester, 'uc_field_bara'), '0');
      await type(tester, 'uc_field_mh2o', '10');
      expect(textOf(tester, 'uc_field_kpa'), '98.0665');
      expect(textOf(tester, 'uc_field_inh2o68'), '394.4116');
    },
  );

  testWidgets('압력·온도 칸은 "-"가 있는 숫자판(삼성 자판 진공·영하)', (tester) async {
    await pumpPage(tester, initialCategory: 'pressure');
    TextInputType? kb(String id) =>
        tester.widget<TextField>(find.byKey(Key('uc_field_$id'))).keyboardType;
    const signed = TextInputType.numberWithOptions(decimal: true, signed: true);
    expect(kb('bar'), signed);
    expect(kb('psi'), signed);
    expect(kb('kgfcm2'), signed);
    expect(
      kb('bara'),
      const TextInputType.numberWithOptions(decimal: true),
    ); // 절대압은 음수가 없다
    await tester.tap(find.byKey(const Key('uc_cat_temp')));
    await tester.pumpAndSettle();
    expect(kb('c'), signed);
  });

  testWidgets('작은 수도 유효 7자리: 1 mmH₂O = 0.00000980665 MPa', (tester) async {
    await pumpPage(tester, initialCategory: 'pressure');
    await type(tester, 'uc_field_mmh2o', '1');
    expect(textOf(tester, 'uc_field_mpa'), '0.00000980665');
    expect(textOf(tester, 'uc_field_pa'), '9.80665');
  });

  testWidgets('쉼표 소수점: bar 1,5 → psi 21.75566 (15로 읽지 않는다)', (tester) async {
    await pumpPage(tester, initialCategory: 'pressure');
    await type(tester, 'uc_field_bar', '1,5');
    expect(textOf(tester, 'uc_field_psi'), '21.75566');
    await type(tester, 'uc_field_bar', '1,500');
    expect(textOf(tester, 'uc_field_kpa'), '150000');
  });

  testWidgets('못 읽는 글이면 "숫자를 읽을 수 없습니다", 치는 중인 "-"는 알리지 않는다', (tester) async {
    await pumpPage(tester, initialCategory: 'pressure');
    await type(tester, 'uc_field_bar', '-');
    expect(find.byKey(const Key('uc_bad_input')), findsNothing);
    await type(tester, 'uc_field_bar', '1.2.3');
    expect(find.text('숫자를 읽을 수 없습니다'), findsOneWidget);
    expect(textOf(tester, 'uc_field_psi'), '');
    await type(tester, 'uc_field_bar', '2');
    expect(find.text('숫자를 읽을 수 없습니다'), findsNothing);
  });

  testWidgets('온도: 절대영도 아래면 알리고 다른 칸은 비운다', (tester) async {
    await pumpPage(tester, initialCategory: 'temp');
    await type(tester, 'uc_field_c', '-300');
    expect(find.byKey(const Key('uc_warn')), findsOneWidget);
    expect(find.textContaining('절대영도'), findsOneWidget);
    expect(textOf(tester, 'uc_field_k'), '');
    await type(tester, 'uc_field_c', '-273.15');
    expect(find.byKey(const Key('uc_warn')), findsNothing);
    expect(textOf(tester, 'uc_field_k'), '0');
    await type(tester, 'uc_field_f', '32');
    expect(textOf(tester, 'uc_field_c'), '0'); // 지수 찌꺼기 없음
  });

  testWidgets('온도차: 10 °C 차 = 18 °F 차', (tester) async {
    await pumpPage(tester, initialCategory: 'tempdiff');
    await type(tester, 'uc_field_dc', '10');
    expect(textOf(tester, 'uc_field_df'), '18');
    expect(find.textContaining('1.8 °F 차'), findsOneWidget);
  });

  testWidgets('값이 있는 칸을 처음 누르면 글 전체가 골라진다(새로 치면 바뀐다)', (tester) async {
    await pumpPage(tester, initialCategory: 'pressure');
    await type(tester, 'uc_field_psi', '100');
    final bar = find.byKey(const Key('uc_field_bar'));
    await tester.tap(bar);
    await tester.pump();
    final ctrl = tester.widget<TextField>(bar).controller!;
    expect(ctrl.text, '6.894757');
    expect(ctrl.selection.start, 0);
    expect(ctrl.selection.end, ctrl.text.length);
    // 이미 커서가 있는 칸을 다시 누르면 커서만 옮긴다.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(bar);
    await tester.pump();
    expect(ctrl.selection.isCollapsed, isTrue);
  });

  testWidgets('줄을 길게 누르면 값과 단위를 복사하고 "복사했습니다"', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpPage(tester, initialCategory: 'pressure');
    await type(tester, 'uc_field_bar', '1');
    await tester.longPress(find.text('파운드/제곱인치'));
    await tester.pump();
    expect(copied, '14.50377 psi');
    expect(find.text('14.50377 psi 복사했습니다.'), findsOneWidget);
  });

  testWidgets('단위 이름 글씨는 13', (tester) async {
    await pumpPage(tester, initialCategory: 'pressure');
    final t = tester.widget<Text>(find.text('파운드/제곱인치'));
    expect(t.style!.fontSize, 13);
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

  testWidgets('찾기: mAq는 mH₂O가 맨 위, 20A는 배관 호칭 "표로 보기"', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('uc_search')), 'mAq');
    await tester.pumpAndSettle();
    final mh2o = tester.getTopLeft(
      find.byKey(const Key('uc_hit_pressure_mh2o')),
    );
    final mmh2o = tester.getTopLeft(
      find.byKey(const Key('uc_hit_pressure_mmh2o')),
    );
    expect(mh2o.dy, lessThan(mmh2o.dy));

    await tester.enterText(find.byKey(const Key('uc_search')), '20A');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('uc_hit_pipe_')), findsOneWidget);
    expect(find.text('표로 보기'), findsWidgets);
    expect(find.text('모든 단위 보기'), findsNothing);
    await tester.tap(find.byKey(const Key('uc_hit_pipe_')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('uc_od')), findsOneWidget);
  });

  testWidgets('⋮ 맨 위 고정 → 첫 줄로, 숨기기 → 사라지고 다시 보이기', (tester) async {
    await pumpPage(tester, initialCategory: 'pressure');
    double topOf(String id) =>
        tester.getTopLeft(find.byKey(Key('uc_field_$id'))).dy;
    expect(topOf('psi'), greaterThan(topOf('mpa')));

    await tester.tap(find.byKey(const Key('uc_menu_psi')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('맨 위 고정'));
    await tester.pumpAndSettle();
    expect(topOf('psi'), lessThan(topOf('mpa')));
    await tester.tap(find.byKey(const Key('uc_menu_psi')));
    await tester.pumpAndSettle();
    expect(find.text('고정 풀기'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5)); // 메뉴 닫기
    await tester.pumpAndSettle();

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

  testWidgets('전선 굵기: AWG 10 → 6sq, AWG 1/0 → 70sq(가장 가까운 50sq는 가늘다)', (
    tester,
  ) async {
    await pumpPage(tester, initialCategory: 'wire');
    expect(find.text('AWG나 SQ 중 하나를 입력하십시오'), findsOneWidget);
    expect(find.textContaining('1:1로 대응하지 않습니다'), findsOneWidget);
    await type(tester, 'uc_awg', '10');
    expect(textOf(tester, 'uc_sq'), '6');
    expect(find.textContaining('AWG 10 = 5.26mm²'), findsOneWidget);
    expect(find.textContaining('같거나 굵은 SQ: 6sq'), findsOneWidget);
    expect(find.textContaining('가장 가까운'), findsNothing); // 같은 규격이면 한 줄

    await type(tester, 'uc_awg', '1/0');
    expect(textOf(tester, 'uc_sq'), '70');
    expect(find.textContaining('같거나 굵은 SQ: 70sq'), findsOneWidget);
    expect(find.textContaining('가장 가까운 50sq는 더 가늡니다.'), findsOneWidget);
  });

  testWidgets('전선 굵기: 2.5sq → AWG 12(같거나 굵은 것), 14는 가늘다고 적는다', (tester) async {
    await pumpPage(tester, initialCategory: 'wire');
    await type(tester, 'uc_sq', '2.5');
    expect(textOf(tester, 'uc_awg'), '12');
    final result = tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const Key('uc_wire_result')),
            matching: find.byType(Text),
          ),
        )
        .data!;
    final lines = result.split('\n');
    expect(lines[1], '같거나 굵은 AWG 12 (3.31mm²)'); // 같거나 굵은 것이 먼저
    expect(lines[2], '가장 가까운 AWG 14 (2.08mm²)는 더 가늡니다.');

    await type(tester, 'uc_sq', '150');
    expect(textOf(tester, 'uc_awg'), '');
    expect(find.textContaining('4/0 (107.22mm²)보다 굵습니다'), findsOneWidget);

    await type(tester, 'uc_awg', 'x');
    expect(find.text('숫자를 읽을 수 없습니다'), findsOneWidget);
    await type(tester, 'uc_awg', '1/');
    expect(find.text('숫자를 읽을 수 없습니다'), findsNothing); // 1/0 치는 중
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
    // 많이 쓰는 분류가 앞: 길이·압력은 밀지 않아도 보인다.
    final chipBox = tester.getRect(find.byKey(const Key('uc_cats')));
    for (final id in ['length', 'pressure']) {
      final r = tester.getRect(find.byKey(Key('uc_cat_$id')));
      expect(r.right, lessThanOrEqualTo(chipBox.right), reason: id);
    }
    for (final c in kUnitCategories) {
      // 칩 줄은 옆으로 미는 목록이라 화면 밖 칩은 밀어서 찾는다(차례대로 오른쪽으로).
      await tester.scrollUntilVisible(
        find.byKey(Key('uc_cat_${c.id}')),
        120,
        scrollable: chips,
      );
      await tester.tap(find.byKey(Key('uc_cat_${c.id}')));
      await tester.pumpAndSettle();
      if (c.id == 'pressure') await type(tester, 'uc_field_bar', '-0.5');
      if (c.id == 'pipe') await type(tester, 'uc_od', '48.6');
      if (c.id == 'wire') await type(tester, 'uc_sq', '2.5');
      expect(tester.takeException(), isNull, reason: c.id);
    }
  });

  testWidgets('배관 호칭: 15A 줄에 1/2·15·21.7·21.3, 외경 표기', (tester) async {
    await pumpPage(tester, initialCategory: 'pipe');
    expect(find.text('15A'), findsOneWidget);
    expect(find.text('21.7'), findsOneWidget);
    expect(find.text('21.3'), findsOneWidget);
    expect(find.text('273.0'), findsOneWidget); // ASME NPS 10
    expect(find.text('323.8'), findsOneWidget); // ASME NPS 12
    expect(find.textContaining('KS D 3507'), findsOneWidget);
    expect(find.textContaining('KS C 8401'), findsOneWidget);
    expect(find.textContaining('KS C 8422'), findsNothing);
    expect(find.textContaining('바깥지름'), findsNothing);
    expect(find.text('계산값: 인치 × 25.4.'), findsOneWidget);
  });

  testWidgets('배관 호칭: 측정한 외경 48.6 → KS 40A (1-1/2B), 멀면 "가까운 호칭이 없습니다"', (
    tester,
  ) async {
    await pumpPage(tester, initialCategory: 'pipe');
    await type(tester, 'uc_od', '48.6');
    expect(find.byKey(const Key('uc_od_result')), findsOneWidget);
    expect(find.text('40A (1-1/2B)'), findsOneWidget);
    expect(find.text('NPS 1-1/2 (40A)'), findsOneWidget);
    expect(find.text('튜브'), findsNothing); // 1" 튜브(25.4)와는 멀다
    await type(tester, 'uc_od', '12.7');
    expect(find.text('1/2"'), findsWidgets); // 1/2" 튜브
    await type(tester, 'uc_od', '600');
    expect(find.text('가까운 호칭이 없습니다.'), findsOneWidget);
  });

  testWidgets('현장 자료에서 "psi"로 찾아 단위 환산을 누르면 압력 분류가 열린다', (tester) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: TubeReferencePage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'psi');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('단위 환산 — 압력'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('uc_field_psi')), findsOneWidget);
    final chip = tester.widget<ChoiceChip>(
      find.byKey(const Key('uc_cat_pressure')),
    );
    expect(chip.selected, isTrue);
  });
}
