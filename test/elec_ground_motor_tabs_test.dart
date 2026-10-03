import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';

Future<void> _open(WidgetTester tester, String tabKey) async {
  tester.view.physicalSize = const Size(800, 9000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage()));
  await tester.pumpAndSettle();
  final tab = find.byKey(Key(tabKey));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('접지 탭: 보호도체 표 값과 단열 식, 규격으로 올림', (tester) async {
    await _open(tester, 'ec_tab_ground');
    // 기본 선도체 50 → 표 25 mm²
    expect(find.text('25 mm²'), findsOneWidget);
    expect(
      find.textContaining('표 142.3-1: 선도체 50 mm² → 보호도체 25 mm²'),
      findsOneWidget,
    );
    // 10 kA, 0.5초, 케이블 안 PVC 구리 k 115 → 61.5 → 70
    await _type(tester, 'gr_fault', '10000');
    expect(find.text('70 mm²'), findsOneWidget);
    expect(find.textContaining('= 61.5 mm² (규격 70 mm²)'), findsOneWidget);
    // 따로 포설로 바꾸면 k 143 → 49.5 → 표 25와 비교해 큰 값 50
    await _tap(tester, 'gr_sep_out');
    expect(find.text('50 mm²'), findsOneWidget);
    // 5초 초과 차단시간은 식을 쓰지 않는다
    await _type(tester, 'gr_sec', '6');
    expect(find.textContaining('단열 식은 고장전류와 차단시간(5초 이하)'), findsOneWidget);
  });

  testWidgets('접지 탭: 중성점·TT·본딩·접지도체', (tester) async {
    await _open(tester, 'ec_tab_ground');
    await _tap(tester, 'gr_mode_neutral');
    expect(find.text('15 Ω 이하'), findsOneWidget); // 150 ÷ 10
    await _tap(tester, 'gr_trip_1');
    expect(find.text('60 Ω 이하'), findsOneWidget);
    await _tap(tester, 'gr_mode_tt');
    expect(find.text('1667 Ω 이하'), findsOneWidget); // 50 ÷ 0.03
    await _tap(tester, 'gr_idn_1');
    expect(find.text('50 Ω 이하'), findsOneWidget);
    await _tap(tester, 'gr_mode_bonding');
    expect(find.textContaining('8 mm² 이상'), findsWidgets); // 16 ÷ 2
    await _tap(tester, 'gr_mode_grounding');
    expect(find.text('6 mm²'), findsOneWidget);
    await _tap(tester, 'gr_gmat_al');
    expect(find.text('쓸 수 없음'), findsOneWidget);
  });

  testWidgets('접지 탭: 접지봉 41.2 Ω, 병렬과 목표 판정', (tester) async {
    await _open(tester, 'ec_tab_ground');
    await _tap(tester, 'gr_mode_rod');
    expect(find.textContaining('1본: ρ/(2πl)'), findsOneWidget);
    expect(find.text('41.2 Ω'), findsOneWidget);
    await _type(tester, 'gr_n', '4');
    await _type(tester, 'gr_target', '10');
    // 1.2 × 41.2 ÷ 4 = 12.4 → 목표 10 초과
    expect(find.text('12.4 Ω'), findsOneWidget);
    expect(find.textContaining('목표 10 Ω를 초과합니다'), findsOneWidget);
    await _type(tester, 'gr_space', '0.5');
    expect(find.textContaining('1 m 미만이라 병렬 식을 쓸 수 없습니다'), findsOneWidget);
  });

  testWidgets('접지 탭: 풀이 줄(표 규칙·필요 단면적·접지봉 대입·본딩 단계)', (tester) async {
    await _open(tester, 'ec_tab_ground');
    expect(find.textContaining('S ÷ 2 = 50 ÷ 2 = 25 mm²'), findsOneWidget);
    await _type(tester, 'gr_fault', '10000');
    expect(find.textContaining('③ 필요 단면적'), findsOneWidget);
    expect(find.textContaining('중 61.5 mm² → 규격 70 mm²'), findsOneWidget);
    await _tap(tester, 'gr_mode_rod');
    expect(
      find.textContaining('= 100 ÷ (2π × 2.4) × (ln(4 × 2.4 ÷ 0.0071) − 1) = 41.2 Ω'),
      findsOneWidget,
    );
    await _type(tester, 'gr_n', '4');
    expect(find.textContaining('1.2 × 1본 ÷ 4 = 1.2 × 41.2 ÷ 4 = 12.4 Ω'), findsOneWidget);
    await _tap(tester, 'gr_mode_bonding');
    expect(find.textContaining('① 보호도체 ÷ 2 = 16 ÷ 2 = 8 mm²'), findsOneWidget);
    expect(find.textContaining('③ 25 mm² 상한: 작은 값 = min(25, 8) = 8 mm²'), findsOneWidget);
  });

  testWidgets('접지 탭: 고압 내력 계산식 대입', (tester) async {
    await _open(tester, 'ec_tab_ground');
    await _tap(tester, 'gr_mode_insulation');
    await _tap(tester, 'gr_ins_hv');
    expect(find.textContaining('= 6.9 × 1.5 = 10.35 kV'), findsOneWidget);
  });

  testWidgets('전동기 보호 탭: 직입 설정 = 정격, Y-Δ 델타 안 = 0.58배', (tester) async {
    await _open(tester, 'ec_tab_motor');
    expect(find.text('40 A'), findsOneWidget);
    expect(
      find.textContaining('NEC 430.32 상한 = FLA × 125% = 40 × 1.25 = 50 A'),
      findsOneWidget,
    );
    await _tap(tester, 'emp_yd');
    expect(find.text('23.1 A'), findsOneWidget); // 40 ÷ √3
    await _tap(tester, 'emp_line');
    expect(find.text('40 A'), findsOneWidget);
    await _tap(tester, 'emp_sf_n');
    expect(find.textContaining('FLA × 115% = 40 × 1.15 = 46 A'), findsOneWidget);
  });

  testWidgets('전동기 보호 탭: EOCR 범위, 트립 클래스, 단락 상한', (tester) async {
    await _open(tester, 'ec_tab_motor');
    await _type(tester, 'emp_run', '30');
    expect(find.textContaining('33 ~ 37.5 A'), findsOneWidget);
    expect(find.textContaining('= 30 × 1.10 ~ 30 × 1.25 = 33 ~ 37.5 A'), findsOneWidget);
    // 기동시간 6초: 클래스 10(상한 10초) 안
    expect(find.textContaining('기동시간 6초는 클래스 10 상한 10초 이내입니다'), findsOneWidget);
    await _type(tester, 'emp_start', '12');
    expect(find.textContaining('기동 중 트립될 수 있습니다'), findsOneWidget);
    await _tap(tester, 'emp_cls_20');
    expect(find.textContaining('기동시간 12초는 클래스 20 상한 20초 이내입니다'), findsOneWidget);
    // 단락 상한: 40 A × 250% = 100 A
    expect(find.textContaining('반한시 차단기 최대 = FLC × 250% = 40 × 2.5 = 100 A'), findsOneWidget);
    expect(find.textContaining('FLC × 125% = 40 × 1.25 = 50 A'), findsOneWidget);
  });
}
