// 공학용 계산기 화면: 누름판으로 계산, FT 단추, 분수 표시, 설정, 오류, 좁은 폰.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/field_tools/eng_calculator_page.dart';

Future<void> pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(const MaterialApp(home: EngCalculatorPage()));
  await tester.pump();
  await tester.pump();
}

Future<void> tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
}

String result(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('calc_display_result'))).data!;

String? fraction(WidgetTester tester) {
  final f = find.byKey(const Key('calc_display_fraction'));
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Text>(f).data;
}

void main() {
  moreTests();
  titleTests();
  modeStabilityTests();
  testWidgets('숫자·연산자를 누르면 바로 결과가 뜬다(=  없이도)', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_2');
    await tap(tester, 'calc_add');
    await tap(tester, 'calc_3');
    expect(result(tester), '5');
  });

  testWidgets('빼기 단추(calc_sub)로 뺄셈이 된다', (tester) async {
    // 실제 버그(2026-09-28): 빼기 단추는 화면용 유니코드 마이너스(−,
    // U+2212)를 식에 넣는데 계산기는 자판 하이픈(-)만 뺄셈으로 알아봐서,
    // 더하기는 되는데 빼기만 "식을 끝까지 읽지 못했습니다" 오류가 났다.
    await pump(tester);
    await tap(tester, 'calc_5');
    await tap(tester, 'calc_sub');
    await tap(tester, 'calc_3');
    expect(result(tester), '2');
  });

  testWidgets('곱셈·나눗셈이 먼저 계산된다', (tester) async {
    await pump(tester);
    for (final k in ['calc_2', 'calc_add', 'calc_3', 'calc_mul', 'calc_4']) {
      await tap(tester, k);
    }
    expect(result(tester), '14');
  });

  testWidgets('괄호', (tester) async {
    await pump(tester);
    for (final k in [
      'calc_lparen',
      'calc_2',
      'calc_add',
      'calc_3',
      'calc_rparen',
      'calc_mul',
      'calc_4',
    ]) {
      await tap(tester, k);
    }
    expect(result(tester), '20');
  });

  testWidgets('sin(30) = 0.5, 함수 단추는 괄호를 자동으로 연다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_sin');
    expect(find.text('sin('), findsOneWidget);
    await tap(tester, 'calc_3');
    await tap(tester, 'calc_0');
    await tap(tester, 'calc_rparen');
    expect(result(tester), '0.5');
  });

  testWidgets('거듭제곱', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_2');
    await tap(tester, 'calc_pow');
    await tap(tester, 'calc_3');
    expect(result(tester), '8');
  });

  testWidgets('AC로 지우고 ⌫로 한 글자 지운다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_1');
    await tap(tester, 'calc_2');
    expect(result(tester), '12');
    await tap(tester, 'calc_back');
    expect(result(tester), '1');
    await tap(tester, 'calc_ac');
    expect(result(tester), '0');
  });

  testWidgets('=를 누르면 결과가 식 자리로 오고, 이어서 계산할 수 있다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_5');
    await tap(tester, 'calc_add');
    await tap(tester, 'calc_3');
    await tap(tester, 'calc_eq');
    expect(result(tester), '8');
    await tap(tester, 'calc_mul');
    await tap(tester, 'calc_2');
    expect(result(tester), '16');
  });

  testWidgets('= 뒤에 숫자를 누르면 새로 시작한다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_5');
    await tap(tester, 'calc_eq');
    await tap(tester, 'calc_9');
    expect(result(tester), '9');
  });

  testWidgets('FT 단추: 3 FT 3 + 3 ÷ 8 = 3피트 3-3/8인치(39.375)', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_3');
    await tap(tester, 'calc_ft');
    expect(find.textContaining('12'), findsOneWidget);
    await tap(tester, 'calc_3');
    await tap(tester, 'calc_add');
    await tap(tester, 'calc_3');
    await tap(tester, 'calc_div');
    await tap(tester, 'calc_8');
    expect(result(tester), '39.375');
    expect(fraction(tester), "≈ 3' 3-3/8\"");
  });

  testWidgets('분수 표시는 기본으로 켜져 있고, 설정에서 끌 수 있다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_3');
    await tap(tester, 'calc_div');
    await tap(tester, 'calc_8');
    expect(fraction(tester), '≈ 3/8"');
    await tap(tester, 'calc_settings');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calc_show_fraction')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // 바깥을 눌러 시트를 닫는다.
    await tester.pumpAndSettle();
    expect(fraction(tester), isNull);
  });

  testWidgets('설정에서 라디안으로 바꾸면 sin(π/2)=1', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_settings');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calc_angle_rad')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tap(tester, 'calc_sin');
    await tap(tester, 'calc_pi');
    await tap(tester, 'calc_div');
    await tap(tester, 'calc_2');
    await tap(tester, 'calc_rparen');
    expect(result(tester), '1');
  });

  testWidgets('0으로 나누면 빨간 오류 글이 뜬다(분수 줄은 안 뜬다)', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_1');
    await tap(tester, 'calc_div');
    await tap(tester, 'calc_0');
    expect(result(tester), '0으로 나눌 수 없습니다');
    expect(fraction(tester), isNull);
  });

  testWidgets('식이 연산자로 끝나도(=  누르기 전) 오류로 막지 않고 그 앞까지 계산', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_5');
    await tap(tester, 'calc_add');
    expect(result(tester), '5');
  });

  testWidgets('AppBar "공식으로 계산" 단추로 공식 계산 화면을 연다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_formulas');
    await tester.pumpAndSettle();
    expect(find.text('공식 계산'), findsOneWidget);
    expect(find.text('전기'), findsOneWidget);
  });

  testWidgets('a/b로 분수를 만들면 분자·분모가 따로 보이고 바로 계산된다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_frac_key');
    await tap(tester, 'calc_3');
    expect(find.byKey(const Key('calc_frac_num')), findsOneWidget);
    await tap(tester, 'calc_frac_den');
    await tap(tester, 'calc_8');
    expect(result(tester), '0.375');
  });

  testWidgets('분자·분모 칸을 각각 눌러서 고칠 수 있다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_frac_key');
    await tap(tester, 'calc_3');
    await tap(tester, 'calc_frac_den');
    await tap(tester, 'calc_8');
    expect(result(tester), '0.375');
    // 분자 칸으로 돌아가 숫자를 더 친다(끝에 이어 붙는다: 3 → 31).
    await tap(tester, 'calc_frac_num');
    await tap(tester, 'calc_1');
    expect(result(tester), '3.875'); // "31/8" = 3.875
  });

  testWidgets('분수를 만들고 연산자를 누르면 식에 끼워 넣고 이어서 계산한다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_1');
    await tap(tester, 'calc_add');
    await tap(tester, 'calc_frac_key');
    await tap(tester, 'calc_1');
    await tap(tester, 'calc_frac_den');
    await tap(tester, 'calc_2');
    await tap(tester, 'calc_eq');
    expect(result(tester), '1.5');
    expect(find.byKey(const Key('calc_frac_num')), findsNothing);
  });

  testWidgets('자연수 부분: 3 다음 a/b를 누르면 3과 분수가 붙는다(대분수)', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_3');
    await tap(tester, 'calc_frac_key');
    expect(find.byKey(const Key('calc_frac_whole')), findsOneWidget);
    await tap(tester, 'calc_1');
    await tap(tester, 'calc_frac_den');
    await tap(tester, 'calc_2');
    expect(result(tester), '3.5'); // 3 + 1/2
  });

  testWidgets('S⇔D: 사칙연산 결과는 정확한 분수로 바꿔 볼 수 있다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_1');
    await tap(tester, 'calc_div');
    await tap(tester, 'calc_3');
    expect(find.byKey(const Key('calc_sd')), findsOneWidget);
    await tap(tester, 'calc_sd');
    expect(result(tester), '1/3');
    await tap(tester, 'calc_sd');
    expect(result(tester), '0.3333333'); // 다시 소수로.
  });

  testWidgets('S⇔D: 무리수(sin 등)를 거치면 분수 단추 자체가 없다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_sin');
    await tap(tester, 'calc_3');
    await tap(tester, 'calc_0');
    await tap(tester, 'calc_rparen');
    expect(result(tester), '0.5');
    expect(find.byKey(const Key('calc_sd')), findsNothing);
  });

  testWidgets('좁은 폰(320)·큰 글씨에서 누름판이 넘치지 않는다', (tester) async {
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) =>
        errors.add(d.exceptionAsString().split('\n').first);
    try {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const EngCalculatorPage(),
        ),
      );
      await tester.pump();
      for (final k in ['calc_1', 'calc_add', 'calc_2', 'calc_eq']) {
        await tap(tester, k);
      }
    } finally {
      FlutterError.onError = old;
    }
    expect(errors, isEmpty);
  });

  testWidgets('기본으로는 공학(고급) 모드라 삼각함수 줄이 보인다', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('calc_sin')), findsOneWidget);
    expect(find.byKey(const Key('calc_pow')), findsOneWidget);
  });

  testWidgets('갤럭시 계산기처럼: 단추를 누르면 기본 모드로 바뀌어 삼각함수 줄이 없어진다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_mode_toggle');
    await tester.pumpAndSettle(); // 전환 애니메이션이 끝나길 기다린다.
    expect(find.byKey(const Key('calc_sin')), findsNothing);
    expect(find.byKey(const Key('calc_pow')), findsNothing);
    // 기본 모드에서도 사칙연산·소수점·a/b·FT는 그대로 있다.
    expect(find.byKey(const Key('calc_7')), findsOneWidget);
    expect(find.byKey(const Key('calc_frac_key')), findsOneWidget);
    expect(find.byKey(const Key('calc_ft')), findsOneWidget);
    // 계산 자체는 기본 모드에서도 잘 된다.
    await tap(tester, 'calc_2');
    await tap(tester, 'calc_add');
    await tap(tester, 'calc_3');
    expect(result(tester), '5');
    // 다시 누르면 공학 모드로 돌아온다.
    await tap(tester, 'calc_mode_toggle');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calc_sin')), findsOneWidget);
  });

  testWidgets('기본 모드로 골라 두면 다음에 열 때도 기본 모드로 열린다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'field_eng_calc_advanced_v1': false,
    });
    await tester.pumpWidget(const MaterialApp(home: EngCalculatorPage()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calc_sin')), findsNothing);
  });

  testWidgets('기본↔공학 전환은 뚝 바뀌지 않고 중간 단계를 거친다(애니메이션)', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle(); // 설정을 읽은 뒤부터 애니메이션이 켜진다.
    final before = tester.getSize(find.byKey(const Key('calc_7'))).height;
    await tap(tester, 'calc_mode_toggle');
    await tester.pump(const Duration(milliseconds: 130)); // 절반쯤.
    // 중간에는 삼각함수 줄이 아직 남아 있고(반쯤 접힌 상태), 다른 단추 크기도 그새 변했다.
    expect(find.byKey(const Key('calc_sin')), findsOneWidget);
    final mid = tester.getSize(find.byKey(const Key('calc_7'))).height;
    await tester.pumpAndSettle();
    final after = tester.getSize(find.byKey(const Key('calc_7'))).height;
    expect(find.byKey(const Key('calc_sin')), findsNothing);
    expect(mid, greaterThan(before));
    expect(mid, lessThan(after));
  });

  testWidgets('=를 누르기 전에는 계산 기록 자리가 없다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_2');
    await tap(tester, 'calc_add');
    await tap(tester, 'calc_3');
    expect(find.byKey(const Key('calc_history')), findsNothing);
  });

  testWidgets('=를 누르면 그 식이 기록으로 쌓이고, 다음 계산이 이어서 쌓인다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_2');
    await tap(tester, 'calc_add');
    await tap(tester, 'calc_3');
    await tap(tester, 'calc_eq');
    expect(find.byKey(const Key('calc_history')), findsOneWidget);
    expect(find.text('2+3 = 5'), findsOneWidget);
    expect(result(tester), '5');
    // 이어서 계산해도(5×2) 기록에 새 줄이 늘어난다.
    await tap(tester, 'calc_mul');
    await tap(tester, 'calc_2');
    await tap(tester, 'calc_eq');
    expect(find.text('2+3 = 5'), findsOneWidget);
    expect(find.text('5×2 = 10'), findsOneWidget);
    expect(result(tester), '10');
  });

  testWidgets('결과가 그대로인데 =를 또 누르면 기록에 똑같은 줄이 더 안 생긴다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_5');
    await tap(tester, 'calc_eq');
    expect(find.text('5 = 5'), findsNothing); // 식과 결과가 같으면 안 쌓는다.
    await tap(tester, 'calc_eq');
    expect(find.byKey(const Key('calc_history')), findsNothing);
  });

  testWidgets('AppBar "단위 환산" 단추로 단위 변환 화면을 연다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_unit_convert');
    await tester.pumpAndSettle();
    expect(find.text('단위 환산'), findsOneWidget);
    // 길이 분류가 기본으로 골라져 있고, mm 1을 넣으면 cm 값이 바로 바뀐다.
    expect(find.text('길이'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('unit_from_value')), '1000');
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('unit_to_value'))).data,
      '100', // 기본 단위가 mm→cm이라 1000mm = 100cm.
    );
  });

  testWidgets('가로 화면(844×390)에서도 넘치지 않는다', (tester) async {
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) =>
        errors.add(d.exceptionAsString().split('\n').first);
    try {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester);
      for (final k in ['calc_1', 'calc_add', 'calc_2', 'calc_eq']) {
        await tap(tester, k);
      }
    } finally {
      FlutterError.onError = old;
    }
    expect(errors, isEmpty);
  });

  testWidgets('작은 폰(320×568)에서도 공학 모드·기본 모드 둘 다 넘치지 않는다', (tester) async {
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) =>
        errors.add(d.exceptionAsString().split('\n').first);
    try {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester); // 공학(고급) 모드로 시작.
      await tap(tester, 'calc_mode_toggle'); // 기본 모드도 확인.
      await tap(tester, 'calc_mode_toggle'); // 다시 공학 모드로.
    } finally {
      FlutterError.onError = old;
    }
    expect(errors, isEmpty);
  });

  testWidgets('계산 값 창이 커져서 결과 숫자가 크게 보인다(태블릿 화면 포함)', (tester) async {
    Future<double> resultHeight(Size size) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MaterialApp(home: EngCalculatorPage()));
      await tester.pump();
      await tap(tester, 'calc_1');
      await tap(tester, 'calc_2');
      return tester
          .getSize(find.byKey(const Key('calc_display_result')))
          .height;
    }

    // 예전(고정 40pt)에는 이 글자가 50px 안팎이었다. 지금은 남는 세로 자리만큼
    // 커지되 120을 넘지는 않는다 — 스마트폰도 태블릿도 자리가 넉넉해 그 한도에
    // 닿는다(태블릿에서만 특별히 더 커지는 건 아니다. 대신 키패드보다 계산 값 창
    // 몫을 키워서 태블릿에서 숫자가 작아 보이지 않게 했다).
    final phone = await resultHeight(const Size(390, 844));
    final tablet = await resultHeight(const Size(800, 1280));
    addTearDown(tester.view.reset);
    expect(phone, greaterThan(60));
    expect(tablet, greaterThan(60));
  });
}

// ── 2026-10-05: 퍼센트·mod·Ans·복사·기록 ──
void moreTests() {
  Future<void> seq(WidgetTester tester, List<String> keys) async {
    for (final k in keys) {
      await tap(tester, k);
    }
  }

  testWidgets('100−10%는 90(일반 계산기 방식)', (tester) async {
    await pump(tester);
    await seq(tester, [
      'calc_1', 'calc_0', 'calc_0', 'calc_sub', 'calc_1', 'calc_0', 'calc_pct',
    ]);
    expect(result(tester), '90');
  });

  testWidgets('cos(90)은 0으로 보인다', (tester) async {
    await pump(tester);
    await seq(tester, [
      'calc_cos', 'calc_9', 'calc_0', 'calc_rparen',
    ]);
    expect(result(tester), '0');
  });

  testWidgets('큰 정수는 자리를 다 보여 준다(123456789×987654321)', (tester) async {
    await pump(tester);
    await seq(tester, [
      'calc_1', 'calc_2', 'calc_3', 'calc_4', 'calc_5', 'calc_6', 'calc_7',
      'calc_8', 'calc_9', 'calc_mul', 'calc_9', 'calc_8', 'calc_7', 'calc_6',
      'calc_5', 'calc_4', 'calc_3', 'calc_2', 'calc_1',
    ]);
    expect(result(tester), '121932631112635269');
  });

  testWidgets('mod 단추: 7 mod 3 = 1, 뒤에 안 쳤을 때는 오류 없이 앞 값', (tester) async {
    await pump(tester);
    await seq(tester, ['calc_7', 'calc_mod']);
    expect(result(tester), '7');
    await seq(tester, ['calc_3']);
    expect(result(tester), '1');
  });

  testWidgets('Ans: = 뒤에 Ans×2', (tester) async {
    await pump(tester);
    await seq(tester, ['calc_2', 'calc_add', 'calc_3', 'calc_eq']);
    await seq(tester, ['calc_ans', 'calc_mul', 'calc_2']);
    expect(result(tester), '10');
  });

  testWidgets('Ans: 아직 =를 안 눌렀으면 안내 오류', (tester) async {
    await pump(tester);
    await seq(tester, ['calc_ans']);
    expect(find.textContaining('직전 결과가 없습니다'), findsWidgets);
  });

  testWidgets('! 단추: 5! = 120', (tester) async {
    await pump(tester);
    await seq(tester, ['calc_5', 'calc_fact']);
    expect(result(tester), '120');
  });

  testWidgets('기록은 앱을 다시 열어도 남고, 줄을 누르면 결과가 식에 들어가고, 지우기로 비운다', (tester) async {
    SharedPreferences.setMockInitialValues({
      kEngCalcHistoryKey: ['2+3 = 5'],
    });
    await tester.pumpWidget(const MaterialApp(home: EngCalculatorPage()));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('2+3 = 5'), findsOneWidget);
    await tap(tester, 'calc_history_item_0');
    await tap(tester, 'calc_mul');
    await tap(tester, 'calc_4');
    expect(result(tester), '20');
    await tap(tester, 'calc_history_clear');
    expect(find.text('2+3 = 5'), findsNothing);
  });

  testWidgets('= 를 누르면 기록이 폰에 저장된다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_2');
    await tap(tester, 'calc_add');
    await tap(tester, 'calc_3');
    await tap(tester, 'calc_eq');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    final p = await SharedPreferences.getInstance();
    expect(p.getStringList(kEngCalcHistoryKey), ['2+3 = 5']);
  });

  testWidgets('복사 단추: 결과를 클립보드에 넣고 알려 준다', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
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
    await pump(tester);
    await tap(tester, 'calc_2');
    await tap(tester, 'calc_add');
    await tap(tester, 'calc_3');
    await tap(tester, 'calc_copy');
    expect(copied, '5');
    expect(find.textContaining('복사했습니다'), findsOneWidget);
  });
}

// 좁은 폰(폴드 겉화면 약 347dp)에서 앱바 제목이 잘리지 않는다(아이콘 네 개 때문에 "공학…"으로 잘린 적 있다).
void titleTests() {
  testWidgets('좁은 폰(347dp)에서도 제목 "공학용 계산기"가 안 잘린다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(347, 770);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: EngCalculatorPage()));
    await tester.pump();
    await tester.pump();
    final p = tester.renderObject<RenderParagraph>(find.text('공학용 계산기'));
    expect(p.didExceedMaxLines, isFalse);
  });
}

// 폴드4에서 숫자를 누르던 중 키패드가 공학→기본 모드로 바뀐 일이 있었다(재현은 안 됨).
// 모드는 모드 단추와 저장값 읽기로만 바뀌고, 숫자·연산을 눌러서는 안 바뀐다는 것을 지킨다.
void modeStabilityTests() {
  testWidgets('공학 모드에서 숫자·연산을 많이 눌러도 모드가 안 바뀐다', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('calc_sin')), findsOneWidget);
    for (final k in [
      'calc_1', 'calc_2', 'calc_3', 'calc_4', 'calc_5', 'calc_6', 'calc_7',
      'calc_8', 'calc_9', 'calc_mul', 'calc_9', 'calc_8', 'calc_7', 'calc_6',
      'calc_5', 'calc_4', 'calc_3', 'calc_2', 'calc_1',
    ]) {
      await tap(tester, k);
    }
    expect(find.byKey(const Key('calc_sin')), findsOneWidget);
    expect(find.text('기본 계산기'), findsOneWidget); // 지금이 공학 모드라는 뜻(누르면 기본으로)
  });

  testWidgets('저장된 모드가 기본이면 기본으로 시작하고 눌러도 그대로다', (tester) async {
    SharedPreferences.setMockInitialValues({kEngCalcAdvancedKey: false});
    await tester.pumpWidget(const MaterialApp(home: EngCalculatorPage()));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('calc_sin')), findsNothing);
    await tap(tester, 'calc_7');
    await tap(tester, 'calc_add');
    await tap(tester, 'calc_3');
    expect(find.byKey(const Key('calc_sin')), findsNothing);
    expect(result(tester), '10');
  });

  testWidgets('모드 단추를 누르면 바뀌고 폰에 저장된다', (tester) async {
    await pump(tester);
    await tap(tester, 'calc_mode_toggle');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('calc_sin')), findsNothing);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    final p = await SharedPreferences.getInstance();
    expect(p.getBool(kEngCalcAdvancedKey), isFalse);
  });
}
