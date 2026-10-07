// 공식 계산: 목록에서 고르면 칸마다 이름·단위·도움말이 있고, 다 넣으면 바로 결과가 뜬다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    // 속도수두: hv=V²/2g=10²/19.6133≈5.099m.
    expect(v('flow_velocity_head', {'vel': 10}), closeTo(5.099, 0.001));
    // 마찰손실(달시-바이스바흐): f=0.02,L/D=100/0.1=1000,V=2 →
    // 0.02×1000×4/19.6133≈4.079m.
    expect(
      v('flow_friction_loss', {'f': 0.02, 'l': 100, 'd': 0.1, 'vel': 2}),
      closeTo(4.079, 0.001),
    );
    // 오리피스: Q=Cd×A×√(2gh)=0.6×0.01×√(2×9.80665×2)≈0.03758㎥/s.
    expect(
      v('flow_orifice', {'cd': 0.6, 'a': 0.01, 'h': 2}),
      closeTo(0.03758, 0.0001),
    );
    // 펌프 축동력: P=ρgQH/η=1000×9.80665×0.05×20/0.7=14009.5W.
    expect(
      v('pump_shaft_power', {'rho': 1000, 'q': 0.05, 'h': 20, 'eta': 0.7}),
      closeTo(14009.5, 0.1),
    );
    // 피상전력(3-4-5 직각삼각형 ×1000): S=√(3000²+4000²)=5000VA.
    expect(v('apparent_power', {'p': 3000, 'q': 4000}), 5000);
    // 유효전력: P=S×cosθ=1000×0.8=800W.
    expect(v('real_power_from_s', {'s': 1000, 'pf': 0.8}), 800);
    // 역률: cosθ=P/S=800/1000=0.8.
    expect(v('power_factor', {'p': 800, 's': 1000}), 0.8);
    // 역률개선 콘덴서: tan(cos⁻¹0.8)=0.75, tan(cos⁻¹0.95)≈0.32868,
    // Qc=100×(0.75-0.32868)≈42.13var.
    expect(
      v('pf_correction_capacitor', {'p': 100, 'pf1': 0.8, 'pf2': 0.95}),
      closeTo(42.13, 0.01),
    );
    // 임피던스(3-4-5): Z=√(3²+4²)=5Ω.
    expect(v('impedance_z', {'r': 3, 'x': 4}), 5);
    // 전선 저항: R=ρL/A=0.0172×100/2.5=0.688Ω.
    expect(
      v('conductor_resistance', {'rho': 0.0172, 'l': 100, 'a': 2.5}),
      0.688,
    );
    // 변압기 2차 전압: V2=220×(10/100)=22V.
    expect(v('transformer_v2', {'v1': 220, 'n1': 100, 'n2': 10}), 22);
    // 변압기 단락전류: Isc=100×100/5=2000A.
    expect(v('transformer_short_circuit', {'in_': 100, 'z': 5}), 2000);
    // 동기속도: Ns=120×60/4=1800rpm.
    expect(v('motor_sync_speed', {'f': 60, 'p': 4}), 1800);
    // 슬립: s=(1800-1750)/1800≈0.02778.
    expect(v('motor_slip', {'ns': 1800, 'n': 1750}), closeTo(0.02778, 0.0001));
    // 토크: T=9549×10/1750≈54.566N·m.
    expect(v('motor_torque', {'p': 10, 'n': 1750}), closeTo(54.566, 0.001));
    // 줄열: H=I²Rt=10²×2×5=1000J.
    expect(v('joule_heat', {'i': 10, 'r': 2, 't': 5}), 1000);
    // 파스칼: P=F/A=1000/0.01=100000Pa.
    expect(v('pascal_pressure', {'f': 1000, 'a': 0.01}), 100000);
    // 실린더 힘: F=P×A=1000000×0.005=5000N.
    expect(v('cylinder_force', {'p': 1000000, 'a': 0.005}), 5000);
    // 실린더 속도: v=Q/A=0.001/0.005=0.2m/s.
    expect(v('cylinder_speed', {'q': 0.001, 'a': 0.005}), 0.2);
    // 유압 동력: Power=P×Q=1000000×0.001=1000W.
    expect(v('hydraulic_power', {'p': 1000000, 'q': 0.001}), 1000);
    // 보일의 법칙(압력): P2=100000×0.02/0.01=200000Pa.
    expect(v('boyle_pressure', {'p1': 100000, 'v1': 0.02, 'v2': 0.01}), 200000);
    // 보일의 법칙(부피): V2=100000×0.02/200000=0.01㎥.
    expect(v('boyle_volume', {'p1': 100000, 'v1': 0.02, 'p2': 200000}), 0.01);
    // 게이지압→절대압: 500000+101325=601325Pa.
    expect(v('gauge_to_absolute', {'pg': 500000, 'patm': 101325}), 601325);
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
    expect(find.text('위 칸에 값을 모두 넣으십시오'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('formula_in_i')), '10');
    await tester.pump();
    expect(find.text('위 칸에 값을 모두 넣으십시오'), findsOneWidget); // 아직 저항이 비었다.
    await tester.enterText(find.byKey(const Key('formula_in_r')), '5');
    await tester.pump();
    expect(find.text('50 V'), findsOneWidget);
    expect(find.text('전압'), findsOneWidget);
  });

  testWidgets('치자마자 뒤로 가도 마지막 입력이 남는다(10-07)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);
    await tester.tap(find.byKey(const Key('formula_ohm_v')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('formula_in_i')), '12');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pageBack();
    await tester.pumpAndSettle();
    final p = await SharedPreferences.getInstance();
    expect(p.getString('formula_draft_ohm_v'), contains('"i":"12"'));
  });

  testWidgets('"?" 도움말을 누르면 이 칸에 뭘 넣는지 알려준다', (tester) async {
    await pump(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('formula_power_3ph')),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('formula_power_3ph')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.help_outline_rounded).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('선과 선 사이 전압'), findsOneWidget);
  });

  testWidgets('칸 이름으로 충분한 칸(도움말이 빈 칸)에는 "?"가 없다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('formula_ohm_v')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.help_outline_rounded), findsNothing);
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

  testWidgets('계산이 끝나면 "최근 계산 기록"에 쌓인다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('formula_ohm_v')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('formula_in_i')), '10');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('formula_in_r')), '5');
    await tester.pump(const Duration(milliseconds: 800)); // 디바운스 지나가기
    await tester.tap(find.byKey(const Key('calc_history_button')));
    await tester.pumpAndSettle();
    expect(find.text('최근 계산 기록'), findsOneWidget);
    expect(find.textContaining('50 V'), findsWidgets);
  });

  testWidgets('좁은 폰(320)·큰 글씨에서 넘치지 않는다', (tester) async {
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) =>
        errors.add(d.exceptionAsString().split('\n').first);
    try {
      // 너비만 좁히고 높이는 넉넉히 둬(스크롤 없이) 너비 넘침만 본다.
      tester.view.physicalSize = const Size(320, 8000);
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
