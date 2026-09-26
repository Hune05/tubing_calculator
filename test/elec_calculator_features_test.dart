// 전기 계산기 2026-09-26 점검 반영 화면 시험: 전압 칩, 트레이 묶음, 입력 알림, 회로 점검,
// 직류·기동 전압강하, 전류↔전력, 부하 종류, 지중 온도, 병렬, 저장, 좁은 폰.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';

Future<void> pumpPage(
  WidgetTester tester, {
  Size size = const Size(390, 3200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage()));
  await tester.pumpAndSettle();
}

String textIn(WidgetTester tester, Key key) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: find.byKey(key), matching: find.byType(Text)),
  );
  return texts.map((t) => t.data ?? '').join('\n');
}

bool chipOn(WidgetTester tester, String key) =>
    tester.widget<ChoiceChip>(find.byKey(Key(key))).selected;

String fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

Future<void> openTab(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// 목록 밖(아직 안 그린) 칸도 찾아 보이게 한다. 아래로 찾고, 없으면 위로.
Future<void> reveal(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    final s = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    try {
      await tester.scrollUntilVisible(f, 200, scrollable: s, maxScrolls: 40);
    } catch (_) {
      await tester.scrollUntilVisible(f, -200, scrollable: s, maxScrolls: 40);
    }
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await reveal(tester, find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> openBasis(WidgetTester tester) async {
  await reveal(tester, find.text('근거 보기'));
  await tester.tap(find.text('근거 보기'));
  await tester.pumpAndSettle();
}

Future<void> pickDropdown(WidgetTester tester, String key, String item) async {
  await tapKey(tester, key);
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String key, String v) async {
  await reveal(tester, find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), v);
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('전압 칩: 220V는 단상, 380·440·480V는 삼상, 단상·삼상은 직접 바꿀 수 있다', (
    tester,
  ) async {
    await pumpPage(tester);
    await tapKey(tester, 'ec_v_220');
    expect(chipOn(tester, 'ec_ph_1'), isTrue);
    await tapKey(tester, 'ec_v_380');
    expect(chipOn(tester, 'ec_ph_3'), isTrue);
    expect(chipOn(tester, 'ec_ph_1'), isFalse);
    await tapKey(tester, 'ec_v_220');
    await tapKey(tester, 'ec_v_440');
    expect(chipOn(tester, 'ec_ph_3'), isTrue);
    await tapKey(tester, 'ec_v_220');
    await tapKey(tester, 'ec_v_480');
    expect(chipOn(tester, 'ec_ph_3'), isTrue);
    // 직접 바꾸기
    await tapKey(tester, 'ec_ph_1');
    expect(chipOn(tester, 'ec_ph_1'), isTrue);
    expect(chipOn(tester, 'ec_v_480'), isTrue);
  });

  testWidgets('트레이 6회로: 겹쳐 쌓음이 기본(0.57) → 6sq, 한 줄 포설(0.73) → 4sq', (
    tester,
  ) async {
    await pumpPage(tester);
    await openTab(tester, 'ec_tab_cable');
    expect(chipOn(tester, 'ec_lay_stacked'), isTrue);
    await type(tester, 'ec_ib', '21.85');
    await type(tester, 'ec_circuits', '6');
    expect(textIn(tester, const Key('ec_cable_result')), contains('6sq'));
    await tapKey(tester, 'ec_lay_single');
    expect(textIn(tester, const Key('ec_cable_result')), contains('4sq'));
    // 전선관(B2)이면 포설 모양 선택이 없다.
    await pickDropdown(tester, 'ec_method', '전선관·덕트 속 케이블 (B2)');
    expect(find.byKey(const Key('ec_lay_stacked')), findsNothing);
  });

  testWidgets('입력 알림: 길이 비움, 역률 비움, 회로 25, 음수, 온도 초과', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'ec_tab_cable');
    await type(tester, 'ec_ib', '20');
    await type(tester, 'ec_length', '');
    var r = textIn(tester, const Key('ec_cable_result'));
    expect(r, contains('길이를 넣으면 전압강하를 검토합니다.'));
    await type(tester, 'ec_length', '50');
    await type(tester, 'ec_pf2', '');
    r = textIn(tester, const Key('ec_cable_result'));
    expect(r, contains('역률 값이 없어 85%로 계산했습니다.'));
    await type(tester, 'ec_circuits', '25');
    r = textIn(tester, const Key('ec_cable_result'));
    expect(r, contains('다조 포설은 표 끝 20회로로 계산했습니다(입력 25).'));
    await type(tester, 'ec_circuits', '1');
    await type(tester, 'ec_ambient', '85');
    r = textIn(tester, const Key('ec_cable_result'));
    expect(r, contains('온도 보정계수 표 범위를 넘습니다'));
    expect(r, contains('주위 온도 85°C가'));
    expect(r, isNot(contains('허용전류가 부족합니다')));
    await type(tester, 'ec_ambient', '30');
    await type(tester, 'ec_length', '-5');
    r = textIn(tester, const Key('ec_cable_result'));
    expect(r, contains('음수는 넣을 수 없습니다'));
  });

  testWidgets('부하 탭: 효율·역률을 비우면 기본값을 알리고, 음수는 받지 않는다', (tester) async {
    await pumpPage(tester);
    await type(tester, 'ec_kw', '11');
    await type(tester, 'ec_eff', '');
    await type(tester, 'ec_pf', '0');
    final r = textIn(tester, const Key('ec_load_result'));
    expect(r, contains('역률 값이 없어 85%로 계산했습니다.'));
    expect(r, contains('효율 값이 없어 90%로 계산했습니다.'));
    await type(tester, 'ec_kw', '-11');
    expect(
      textIn(tester, const Key('ec_load_result')),
      contains('음수는 넣을 수 없습니다'),
    );
  });

  testWidgets('부하 종류 칩: 히터·저항은 효율·역률 100%, 전동기 여유 끔 → 11kW 16.7A', (
    tester,
  ) async {
    await pumpPage(tester);
    await tapKey(tester, 'ec_lt_heater');
    expect(fieldText(tester, 'ec_eff'), '100');
    expect(fieldText(tester, 'ec_pf'), '100');
    expect(
      tester.widget<Switch>(find.byKey(const Key('ec_motor'))).value,
      isFalse,
    );
    await type(tester, 'ec_kw', '11');
    final r = textIn(tester, const Key('ec_load_result'));
    expect(r, contains('16.7 A'));
    expect(r, isNot(contains('×1.25')));
    await tapKey(tester, 'ec_lt_motor');
    expect(fieldText(tester, 'ec_eff'), '90');
    expect(
      tester.widget<Switch>(find.byKey(const Key('ec_motor'))).value,
      isTrue,
    );
  });

  testWidgets('전동기 50A 초과는 1.1배: 380V 37kW 73.5A → 80.8A, 두 탭 스위치 이름이 같다', (
    tester,
  ) async {
    await pumpPage(tester);
    await type(tester, 'ec_kw', '37');
    expect(
      textIn(tester, const Key('ec_load_result')),
      contains('차단기·전선은 80.8 A (×1.1, 50A 초과) 기준'),
    );
    expect(find.text('전동기 부하 (×1.25, 50A 초과 ×1.1)'), findsOneWidget);
    await openTab(tester, 'ec_tab_cable');
    expect(find.text('전동기 부하 (×1.25, 50A 초과 ×1.1)'), findsOneWidget);
    // 전선 탭 전동기 여유는 기본으로 켜져 있다.
    expect(
      tester.widget<Switch>(find.byKey(const Key('ec_cable_motor'))).value,
      isTrue,
    );
  });

  testWidgets('기존 회로 점검: 2.5sq·30A 만족, 50A는 전동기 상한 이내, 전동기 끄면 부족', (
    tester,
  ) async {
    await pumpPage(tester);
    await openTab(tester, 'ec_tab_cable');
    await tapKey(tester, 'ec_mode_check');
    await type(tester, 'ec_ib', '21.85');
    await type(tester, 'ec_chk_breaker', '30');
    var r = textIn(tester, const Key('ec_cable_result'));
    expect(r, contains('32 A'));
    expect(r, contains('IB 27.3A ≤ In 30A ≤ IZ 32A: 조건을 만족합니다.'));
    expect(r, contains('전동기 회로 차단기 범위 30A ~ 50A'));
    expect(textIn(tester, const Key('ec_sum_cable')), contains('조건 만족'));
    await type(tester, 'ec_chk_breaker', '50');
    r = textIn(tester, const Key('ec_cable_result'));
    expect(r, contains('전동기 회로 상한 54.6A 이내입니다'));
    await tapKey(tester, 'ec_cable_motor');
    r = textIn(tester, const Key('ec_cable_result'));
    expect(r, contains('차단기 50A가 허용전류 32A를 초과합니다. 전선 굵기가 부족합니다.'));
    expect(textIn(tester, const Key('ec_sum_cable')), contains('점검 필요'));
    // 부하·차단기를 비우면 허용전류만.
    await type(tester, 'ec_ib', '');
    await type(tester, 'ec_chk_breaker', '');
    r = textIn(tester, const Key('ec_cable_result'));
    expect(r, contains('부하 전류와 차단기 정격을 넣으면 IB ≤ In ≤ IZ를 점검합니다.'));
  });

  testWidgets('병렬 2가닥: 500A → 120sq × 2가닥, 4가닥은 버스바 검토 알림', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'ec_tab_cable');
    await tapKey(tester, 'ec_cable_motor'); // 끔
    await type(tester, 'ec_ib', '500');
    await tapKey(tester, 'ec_par_2');
    var r = textIn(tester, const Key('ec_cable_result'));
    expect(r, contains('120sq × 2가닥'));
    await tapKey(tester, 'ec_par_4');
    r = textIn(tester, const Key('ec_cable_result'));
    expect(r, contains('버스바 트렁킹'));
  });

  testWidgets('지중(D1)을 고르면 온도 기본이 20°C, 직접 넣은 값은 그대로', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'ec_tab_cable');
    expect(fieldText(tester, 'ec_ambient'), '30');
    await pickDropdown(tester, 'ec_method', '지중 관로 (D1)');
    expect(fieldText(tester, 'ec_ambient'), '20');
    expect(find.text('지중 온도 (°C)'), findsOneWidget);
    await pickDropdown(tester, 'ec_method', '펀칭형·사다리형 트레이 (E)');
    expect(fieldText(tester, 'ec_ambient'), '30');
    await type(tester, 'ec_ambient', '45');
    await pickDropdown(tester, 'ec_method', '지중 직매 (D2)');
    expect(fieldText(tester, 'ec_ambient'), '45');
  });

  testWidgets('직류 24V 1sq 2A 50m → 4.62V 19.2%, 한도 초과, 역률 칸 없음', (
    tester,
  ) async {
    await pumpPage(tester);
    await openTab(tester, 'ec_tab_vd');
    await tapKey(tester, 'ec_vd_dc');
    // 직류 기본은 125V(발전소 축전지·제어 전원). 24V 계장은 한 번 더 누른다.
    expect(chipOn(tester, 'ec_vd_dcv_125'), isTrue);
    await tapKey(tester, 'ec_vd_dcv_24');
    expect(chipOn(tester, 'ec_vd_dcv_24'), isTrue);
    expect(find.byKey(const Key('ec_vd_pf')), findsNothing);
    await pickDropdown(tester, 'ec_vd_size', '1sq');
    await type(tester, 'ec_vd_i', '2');
    await type(tester, 'ec_vd_len', '50');
    final r = textIn(tester, const Key('ec_vd_result'));
    expect(r, contains('19.23 %'));
    expect(r, contains('전압강하 4.62 V'));
    expect(r, contains('한도 5% 초과. 굵기를 올리거나 길이를 줄이십시오.'));
    expect(r, contains('한도 이내 최대 편도 길이 약 13 m'));
    await tapKey(tester, 'ec_vd_dcv_125');
    expect(textIn(tester, const Key('ec_vd_result')), contains('3.69 %'));
  });

  testWidgets('전동기 기동 전압강하: 정격 20A ×6, 역률 0.35 → 44.63V 11.7%', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'ec_tab_vd');
    await type(tester, 'ec_vd_i', '20');
    await type(tester, 'ec_vd_len', '100');
    await tapKey(tester, 'ec_vd_start');
    var r = textIn(tester, const Key('ec_vd_result'));
    expect(r, contains('기동 시(정격 ×6, 역률 0.35) 44.63 V (11.7%)'));
    await type(tester, 'ec_vd_mult', '7');
    r = textIn(tester, const Key('ec_vd_result'));
    expect(r, contains('기동 시(정격 ×7'));
  });

  testWidgets('전류 ↔ 전력: 380V 삼상 100A → 65.8kVA·55.9kW, 50kVA → 76A', (
    tester,
  ) async {
    await pumpPage(tester);
    await type(tester, 'ec_conv_val', '100');
    var r = textIn(tester, const Key('ec_conv_result'));
    expect(r, contains('65.8 kVA'));
    expect(r, contains('유효전력 55.9 kW (역률 85%)'));
    await tapKey(tester, 'ec_conv_kva');
    await type(tester, 'ec_conv_val', '50');
    r = textIn(tester, const Key('ec_conv_result'));
    expect(r, contains('76 A'));
  });

  testWidgets('숫자 칸은 키보드 "다음"으로 다음 칸', (tester) async {
    await pumpPage(tester);
    for (final k in ['ec_kw', 'ec_eff', 'ec_pf', 'ec_conv_val']) {
      expect(
        tester.widget<TextField>(find.byKey(Key(k))).textInputAction,
        TextInputAction.next,
        reason: k,
      );
    }
  });

  testWidgets('넣은 값을 저장했다가 다시 열면 채운다', (tester) async {
    await pumpPage(tester);
    await type(tester, 'ec_kw', '11');
    await tapKey(tester, 'ec_v_440');
    await openTab(tester, 'ec_tab_cable');
    await tapKey(tester, 'ec_lay_single');
    await tester.pump(const Duration(seconds: 1));
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ElectricCalculatorPage.draftKey);
    expect(raw, isNotNull);
    final m = jsonDecode(raw!) as Map<String, dynamic>;
    expect(m['kw'], '11');
    expect(m['v'], 440);
    expect(m['stacked'], false);

    // 화면을 닫고 다시 연다.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage()));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'ec_kw'), '11');
    expect(chipOn(tester, 'ec_v_440'), isTrue);
    await openTab(tester, 'ec_tab_cable');
    expect(chipOn(tester, 'ec_lay_single'), isTrue);
  });

  testWidgets('저장 칸이 망가져 있어도 기본값으로 연다', (tester) async {
    SharedPreferences.setMockInitialValues({
      ElectricCalculatorPage.draftKey: '{망가진',
    });
    await pumpPage(tester);
    expect(fieldText(tester, 'ec_eff'), '90');
    expect(tester.takeException(), isNull);
  });

  testWidgets('좁은 폰(344)·큰 글씨: 새 화면(점검·병렬·직류·기동·근거 보기)도 넘치지 않는다', (
    tester,
  ) async {
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
        home: const ElectricCalculatorPage(),
      ),
    );
    await tester.pumpAndSettle();
    await type(tester, 'ec_kw', '37');
    await type(tester, 'ec_conv_val', '120');
    await openBasis(tester);
    expect(tester.takeException(), isNull, reason: '부하 탭');

    await tapKey(tester, 'ec_to_cable');
    expect(tester.takeException(), isNull, reason: '전선 탭');
    await tapKey(tester, 'ec_par_3');
    await openBasis(tester);
    expect(tester.takeException(), isNull, reason: '병렬·근거');
    await tapKey(tester, 'ec_mode_check');
    await type(tester, 'ec_chk_breaker', '100');
    expect(tester.takeException(), isNull, reason: '회로 점검');

    await openTab(tester, 'ec_tab_vd');
    await type(tester, 'ec_vd_i', '15');
    await tapKey(tester, 'ec_vd_start');
    expect(tester.takeException(), isNull, reason: '기동');
    await tapKey(tester, 'ec_vd_dc');
    expect(tester.takeException(), isNull, reason: '직류');

    await openTab(tester, 'ec_tab_pf');
    await type(tester, 'ec_pc_kw', '250');
    expect(tester.takeException(), isNull, reason: '역률');
  });
}
