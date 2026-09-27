// 공식 계산: 목록에서 고르면 칸마다 이름·단위·도움말이 있고, 다 넣으면 바로 결과가 뜬다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/field_tools/formula_calc_page.dart';
import 'package:tubing_calculator/src/presentation/field_tools/formula_defs.dart';

void main() {
  test('공식마다 이름·식·입력 칸이 있다(빈 목록 없음)', () {
    expect(kFormulas, isNotEmpty);
    for (final f in kFormulas) {
      expect(f.inputs, isNotEmpty, reason: f.id);
      expect(f.name, isNotEmpty, reason: f.id);
      expect(f.formulaText, isNotEmpty, reason: f.id);
    }
  });

  test('공식 id가 서로 겹치지 않는다', () {
    final ids = kFormulas.map((f) => f.id).toSet();
    expect(ids.length, kFormulas.length);
  });

  test('전기·유량 공식이 맞게 계산된다(손계산 대조)', () {
    double v(String id, Map<String, double> vals) =>
        kFormulas.firstWhere((f) => f.id == id).compute(vals);

    // 옴의 법칙: V=IR, 10A×5Ω=50V. I=V/R=50/5=10A. R=V/I=50/10=5Ω.
    expect(v('ohm_v', {'i': 10, 'r': 5}), 50);
    expect(v('ohm_i', {'v': 50, 'r': 5}), 10);
    expect(v('ohm_r', {'v': 50, 'i': 10}), 5);
    // 전력: P=VI=100W, P=I²R=10²×1=100W, P=V²/R=100²/100=100W.
    expect(v('power_vi', {'v': 10, 'i': 10}), 100);
    expect(v('power_ir', {'i': 10, 'r': 1}), 100);
    expect(v('power_vr', {'v': 100, 'r': 100}), 100);
    // 3상: P=√3×380×10×1 ≈ 6581.79W.
    expect(v('power_3ph', {'v': 380, 'i': 10, 'pf': 1}), closeTo(6581.79, 0.1));
    // 유도 리액턴스 60Hz 0.1H: 2π×60×0.1≈37.7Ω.
    expect(v('reactance_l', {'f': 60, 'l': 0.1}), closeTo(37.7, 0.1));
    // 용량 리액턴스 60Hz 100μF: 1/(2π×60×0.0001)≈26.5Ω.
    expect(v('reactance_c', {'f': 60, 'c': 0.0001}), closeTo(26.5, 0.1));
    // 공진주파수 L=1H,C=1F: f=1/(2π)≈0.159Hz.
    expect(v('resonant_freq', {'l': 1, 'c': 1}), closeTo(0.159, 0.01));
    // 연속방정식: Q=A×V=0.01×2=0.02m³/s.
    expect(v('flow_q', {'a': 0.01, 'vel': 2}), closeTo(0.02, 1e-9));
    // 관 유속: D=0.1m→A=π×0.01/4≈0.007854, V=Q/A=0.01/0.007854≈1.273m/s.
    expect(v('flow_v_from_d', {'q': 0.01, 'd': 0.1}), closeTo(1.273, 0.01));
    // 레이놀즈수: 1000×2×0.05/0.001=100000.
    expect(
      v('reynolds', {'rho': 1000, 'vel': 2, 'd': 0.05, 'mu': 0.001}),
      100000,
    );
    // 수두압: P=ρgh=1000×9.80665×10≈98066.5Pa.
    expect(v('head_pressure', {'rho': 1000, 'h': 10}), closeTo(98066.5, 1));
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: FormulaCalcPage()));
    await tester.pump();
  }

  testWidgets('목록에서 공식을 고르면 상세 화면이 열린다', (tester) async {
    await pump(tester);
    expect(find.text('전기'), findsOneWidget);
    await tester.tap(find.byKey(const Key('formula_ohm_v')));
    await tester.pumpAndSettle();
    expect(find.text('V = I × R'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    // "유량"은 목록 아래쪽에 있어 스크롤해야 화면(지연 생성)에 나온다.
    await tester.scrollUntilVisible(
      find.text('유량'),
      400,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('유량'), findsOneWidget);
  });

  testWidgets('칸을 다 넣으면 바로 결과가 뜬다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('formula_ohm_v')));
    await tester.pumpAndSettle();
    expect(find.text('위 칸을 모두 넣으십시오'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('formula_in_i')), '10');
    await tester.pump();
    expect(find.text('위 칸을 모두 넣으십시오'), findsOneWidget); // 아직 저항이 비었다.
    await tester.enterText(find.byKey(const Key('formula_in_r')), '5');
    await tester.pump();
    expect(find.text('50 V'), findsOneWidget);
    expect(find.text('전압'), findsOneWidget);
  });

  testWidgets('"?" 도움말을 누르면 이 칸에 뭘 넣는지 알려준다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('formula_ohm_v')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.help_outline_rounded).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('전류입니다'), findsOneWidget);
  });

  testWidgets('0으로 나누면 오류로 알린다(예: 저항 0)', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('formula_ohm_i')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('formula_in_v')), '10');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('formula_in_r')), '0');
    await tester.pump();
    expect(find.text('오류'), findsOneWidget);
  });

  testWidgets('좁은 폰(320)·큰 글씨에서 넘치지 않는다', (tester) async {
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) =>
        errors.add(d.exceptionAsString().split('\n').first);
    try {
      // 너비만 좁히고 높이는 넉넉히 둬(스크롤 없이) 너비 넘침만 본다.
      tester.view.physicalSize = const Size(320, 2600);
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
          home: const FormulaCalcPage(),
        ),
      );
      await tester.pump();
      // 대표로 몇 개만(입력 칸이 가장 많은 레이놀즈수 포함) 열어 본다.
      for (final id in ['ohm_v', 'power_3ph', 'reynolds']) {
        final f = kFormulas.firstWhere((e) => e.id == id);
        await tester.tap(find.byKey(Key('formula_${f.id}')));
        await tester.pumpAndSettle();
        for (final v in f.inputs) {
          await tester.enterText(find.byKey(Key('formula_in_${v.key}')), '1.5');
          await tester.pump();
        }
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    } finally {
      FlutterError.onError = old;
    }
    expect(errors, isEmpty);
  });
}
