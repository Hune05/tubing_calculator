// 압력 시험 계산기 튜브 기준 화면: 시험 대상(튜브 기본·배관), 튜브 재질·치수 단위·규격·설계 온도,
// 허용 사용압력(계산값·제조사 값)과 설계압력·시험압력 확인, ST/S 넣기, 다른 탭으로 이어짐
// (공압 안전거리 구간 체적, 수압 온도 영향·매설, 시험 기록·기록 불러오기), 임시 저장, 좁은 폰·큰 글씨.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/hold_alarm.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_test_page.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_record.dart';

const _draftKey = 'pressure_test_draft_v1';

class FakeAlarm extends HoldAlarm {
  final scheduled = <(DateTime, String, String)>[];
  var cancels = 0;

  @override
  Future<void> schedule(
    DateTime at, {
    required String title,
    required String body,
  }) async => scheduled.add((at, title, body));

  @override
  Future<void> cancel() async => cancels++;
}

late FakeAlarm alarm;
late DateTime now;

Widget app({double textScale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: PressureTestPage(holdAlarm: alarm, now: () => now),
);

Future<void> pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app());
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

String textIn(WidgetTester tester, Key key) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)),
    )
    .map((t) => t.data ?? '')
    .join('\n');

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data ?? '';

String fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

bool chipOn(WidgetTester tester, String key) =>
    tester.widget<ChoiceChip>(find.byKey(Key(key))).selected;

Finder get listScroll => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

/// 긴 목록은 보이는 곳 근처만 만들므로, 없으면 맨 위로 올린 뒤 아래로 내려 찾는다.
Future<void> reveal(WidgetTester tester, String key) async {
  if (find.byKey(Key(key)).evaluate().isNotEmpty) return;
  tester.state<ScrollableState>(listScroll).position.jumpTo(0);
  await tester.pump();
  if (find.byKey(Key(key)).evaluate().isNotEmpty) return;
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    200,
    scrollable: listScroll,
  );
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await reveal(tester, key);
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String key, String v) async {
  await reveal(tester, key);
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), v);
  await tester.pump();
}

/// 목록 칸([key])을 열고 [label]을 고른다.
Future<void> choose(WidgetTester tester, String key, String label) async {
  await tapKey(tester, key);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

String dropValue(WidgetTester tester, String key) =>
    tester.widget<DropdownButton<String>>(find.byKey(Key(key))).value!;

Future<void> reading(WidgetTester tester, String p, [String? t]) async {
  await tester.enterText(find.byKey(const Key('pt_rd_p')), p);
  if (t != null) await tester.enterText(find.byKey(const Key('pt_rd_t')), t);
  await tester.tap(find.byKey(const Key('pt_rd_ok')));
  await tester.pumpAndSettle();
}

/// 화면을 닫아 임시 저장 쓰기를 이 시험 안에서 끝낸다(다음 시험으로 새지 않게).
Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<String> tubeText(WidgetTester tester) async {
  await reveal(tester, 'pt_tube_result');
  return textIn(tester, const Key('pt_tube_result'));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    alarm = FakeAlarm();
    now = DateTime(2026, 9, 26, 9, 0, 0);
  });

  testWidgets('처음 열면 튜브(SS316·인치·1/4" × 0.035"): 허용 사용압력 351.63bar(제조사 값)', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(chipOn(tester, 'pt_kind_tube'), isTrue);
    expect(chipOn(tester, 'pt_kind_pipe'), isFalse);
    expect(chipOn(tester, 'pt_tm_ss316'), isTrue);
    expect(chipOn(tester, 'pt_ts_inch'), isTrue);
    expect(dropValue(tester, 'pt_tube_size'), 'i1/4x035');
    // 설계압력이 없어도 튜브 허용 사용압력은 보인다
    var r = await tubeText(tester);
    expect(r, startsWith('튜브 허용 사용압력 (설계 온도 38°C 이하)\n351.63 bar'));
    expect(
      r,
      contains(
        'SS316 1/4" × 0.035": 외경 1/4" (6.35 mm) · 두께 0.035" (0.89 mm) · 내경 0.180" (4.57 mm)',
      ),
    );
    expect(
      r,
      contains('B31.3 304.1.2, S 20 ksi, 최대 외경 6.48 mm, 최소 두께 0.756 mm'),
    );
    expect(r, contains('최소 두께: A269 표 4: 외경 12.7mm 미만 −15%'));
    expect(r, contains('공칭 두께로 계산하면'));
    expect(
      r,
      contains(
        '제조사 값 351.63 bar: 5100 psig, Swagelok MS-01-107 표 3, 5쪽, −28~37°C',
      ),
    );
    expect(r, contains('허용 사용압력은 계산값과 제조사 값 중 작은 것입니다(제조사 값).'));
    final notes = textIn(tester, const Key('pt_tube_notes'));
    expect(notes, contains('튜브·피팅·밸브 중 가장 낮은 것'));
    expect(notes, contains('345.2.3(d)'));
    expect(notes, contains('1.35배'));

    // 설계압력 100bar: 이내, 수압 PT 150bar는 튜브 항복 압력 이내
    await type(tester, 'pt_design', '100');
    r = await tubeText(tester);
    expect(r, contains('설계압력 100 bar: 허용 사용압력 이내'));
    expect(r, contains('시험압력 150 bar: 튜브 항복 압력'));
    expect(r, contains('이내 (345.2.1(a), 최소 항복강도 30 ksi)'));
    // 시험압력 계산은 배관과 같다
    expect(textIn(tester, const Key('pt_plan_result')), contains('150 bar 이상'));

    // 설계압력 400bar: 초과, PT 600bar는 항복 초과
    await type(tester, 'pt_design', '400');
    r = await tubeText(tester);
    expect(r, contains('설계압력 400 bar: 허용 사용압력 초과'));
    expect(r, contains('시험압력 600 bar: 튜브 항복 압력'));
    expect(r, contains('초과. 항복 압력 이하로 낮출 수 있습니다(345.2.1(a)).'));
    await finish(tester);
  });

  testWidgets('공압 B31.3: 최대 시험압력 = 1.33P와 항복의 90% 중 작은 것, B31.1: 항복의 90%', (
    tester,
  ) async {
    await pumpPage(tester);
    await tapKey(tester, 'pt_pneu');
    await type(tester, 'pt_design', '100');
    var r = await tubeText(tester);
    expect(r, contains('공압 최대 시험압력: 133 bar (1.33P와 튜브 항복 압력의 90%'));
    expect(r, contains('시험압력 110 bar: 튜브 항복 압력의 90% 이내'));
    // 1/8" × 0.028" 탄소강, 설계 400bar → 1.1P = 440bar, 90% 항복(약 824bar) 이내
    await choose(tester, 'pt_tube_size', '1/8" × 0.028"');
    await tapKey(tester, 'pt_tm_cs');
    await type(tester, 'pt_design', '400');
    r = await tubeText(tester);
    expect(r, contains('탄소강 1/8" × 0.028"'));
    expect(r, contains('Y = d/(D + d)'));
    expect(r, contains('Swagelok MS-01-107 표 1, 3쪽'));
    // 실제 시험압력 900bar → 90% 초과
    await type(tester, 'pt_actual', '900');
    r = await tubeText(tester);
    expect(r, contains('시험압력 900 bar: 튜브 항복 압력의 90% 초과'));
    // B31.1
    await tapKey(tester, 'pt_b311');
    r = await tubeText(tester);
    expect(r, contains('튜브 응력 한도(항복강도의 90%)'));
    expect(r, contains('(137.1.4·102.3.3(b))'));
    // B31.1이면 104.1.2 식과 표 A-1 A179 S(13.4ksi), 두꺼운 벽은 y = d/(d + Do)
    expect(r, contains('B31.1 104.1.2, S 13.4 ksi'));
    expect(r, contains('허용 응력 S: B31.1 표 A-1, A179, 설계 온도로 보간'));
    expect(r, contains('y = d/(d + Do)로 계산했습니다(표 104.1.2-1 일반 주 (b)).'));
    expect(r, isNot(contains('Y = d/(D + d)')));
    expect(r, contains('A179는 보일러 외부 배관(BEP)의 압력 부분에 쓸 수 없습니다(표 A-1 주 (1)).'));
    expect(r, isNot(contains('다시 확인하십시오')));
    // B31.1 공압 안전밸브 줄(1.5P 이하)
    expect(
      textIn(tester, const Key('pt_plan_result')),
      contains(
        '안전밸브 설정압력: 600 bar(최대 시험압력 1.5P) 이하, 격리하지 않은 기기 한도 이내 (137.2.6)',
      ),
    );
    await finish(tester);
  });

  testWidgets('설계 온도: 300°C면 S 보간·제조사 값 제외·ST/S 넣기, 범위 밖이면 계산하지 않음', (
    tester,
  ) async {
    await pumpPage(tester);
    await type(tester, 'pt_design', '100');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('pt_tube_temp')))
          .keyboardType,
      const TextInputType.numberWithOptions(decimal: true, signed: true),
    );
    await type(tester, 'pt_tube_temp', '300');
    var r = await tubeText(tester);
    expect(r, startsWith('튜브 허용 사용압력 (설계 온도 300°C)'));
    expect(r, contains('S 17.28 ksi'));
    expect(r, contains('제조사 값 5100 psig은 −28~37°C 값이라 이 설계 온도에서는 계산값만 씁니다.'));
    expect(r, contains('(계산값)'));
    expect(r, contains('ST/S = 20 ÷ 17.28 = 1.157'));
    await tapKey(tester, 'pt_tube_ratio');
    expect(find.byKey(const Key('pt_tube_ratio')), findsNothing);
    await reveal(tester, 'pt_ratio');
    expect(fieldText(tester, 'pt_ratio'), '1.157');
    // 1.5 × 100 × 1.157 = 173.55bar
    await reveal(tester, 'pt_plan_result');
    expect(
      textIn(tester, const Key('pt_plan_result')),
      contains('173.55 bar 이상'),
    );
    await type(tester, 'pt_tube_temp', '500');
    r = await tubeText(tester);
    expect(r, startsWith('튜브 허용 사용압력 (설계 온도 500°C)\n—'));
    expect(r, contains('표 A-1에 넣은 범위(-254~427°C) 밖이라 계산하지 않습니다.'));
    await tapKey(tester, 'pt_tm_cs');
    await type(tester, 'pt_tube_temp', '-40');
    expect(await tubeText(tester), contains('(-29~427°C) 밖이라'));
    await finish(tester);
  });

  testWidgets('B31.1 튜브: 표 A-3 A213 TP316 S로 계산, 제조사 값 비교는 B31.3과 같다', (
    tester,
  ) async {
    await pumpPage(tester);
    var r = await tubeText(tester);
    expect(r, contains('허용 응력 S: B31.3 표 A-1, A269·A213 TP316, 설계 온도로 보간'));
    await tapKey(tester, 'pt_b311');
    r = await tubeText(tester);
    // 38°C 이하: S 20ksi, 계산 5147psi > 제조사 5100psig → 351.63bar(제조사 값)
    expect(r, startsWith('튜브 허용 사용압력 (설계 온도 38°C 이하)\n351.63 bar'));
    expect(
      r,
      contains('B31.1 104.1.2, S 20 ksi, 최대 외경 6.48 mm, 최소 두께 0.756 mm'),
    );
    expect(r, contains('허용 응력 S: B31.1 표 A-3, A213 TP316, 설계 온도로 보간'));
    expect(r, contains('B31.1 표 A-3에는 A269가 없어 같은 TP316인 A213 값을 씁니다.'));
    expect(r, contains('(제조사 값)'));
    // 100°C(212°F): S = 17.3 − 1.7 × 0.12 = 17.096ksi
    // P = 2 × 17096 × 0.02975 / (0.255 − 0.8 × 0.02975) = 4399.70psi = 303.35bar
    await type(tester, 'pt_tube_temp', '100');
    r = await tubeText(tester);
    expect(r, startsWith('튜브 허용 사용압력 (설계 온도 100°C)\n303.35 bar'));
    expect(r, contains('S 17.1 ksi'));
    expect(r, contains('(계산값)'));
    // ST/S는 B31.3 수압에만
    expect(r, isNot(contains('ST/S')));
    // 탄소강 38°C 이하: S 13.4ksi, 938 / 0.227 = 4132.16psi = 284.9bar < 제조사 4800psig
    await type(tester, 'pt_tube_temp', '');
    await tapKey(tester, 'pt_tm_cs');
    r = await tubeText(tester);
    expect(r, startsWith('튜브 허용 사용압력 (설계 온도 38°C 이하)\n284.9 bar'));
    expect(r, contains('B31.1 104.1.2, S 13.4 ksi'));
    expect(r, contains('(계산값)'));
    // 범위: B31.1은 −29°C 아래를 계산하지 않는다(B31.3 SS316은 −254°C까지)
    await tapKey(tester, 'pt_tm_ss316');
    await type(tester, 'pt_tube_temp', '-40');
    r = await tubeText(tester);
    expect(
      r,
      contains('B31.1 표 A-3, A213 TP316에 넣은 범위(-29~427°C) 밖이라 계산하지 않습니다.'),
    );
    expect(r, contains('B31.1은 −29°C 아래 저온을 124.1.2(B31T 요건)로 따로 확인합니다.'));
    await tapKey(tester, 'pt_b313');
    r = await tubeText(tester);
    expect(r, isNot(contains('밖이라')));
    await finish(tester);
  });

  testWidgets(
    'mm 튜브: 12 × 1.5mm SS316은 계산값(316.5bar), 탄소강은 제조사 값 없음, 배관이면 튜브 칸 없음',
    (tester) async {
      await pumpPage(tester);
      await tapKey(tester, 'pt_ts_mm');
      expect(dropValue(tester, 'pt_tube_size'), 'm12x1.5');
      var r = await tubeText(tester);
      expect(r, contains('\n316.5 bar'));
      expect(r, contains('외경 12 mm · 두께 1.5 mm · 내경 9 mm'));
      expect(r, contains('제조사 값 330 bar: 330 bar, Swagelok MS-01-107 표 4, 6쪽'));
      expect(r, contains('(계산값)'));
      await choose(tester, 'pt_tube_size', '6 × 1 mm');
      expect(dropValue(tester, 'pt_tube_size'), 'm6x1');
      await tapKey(tester, 'pt_tm_cs');
      r = await tubeText(tester);
      expect(r, contains('최소 두께: A179는 최소 두께로 주문하는 관이라 적힌 두께 그대로'));
      expect(
        r,
        contains('제조사 값 없음: Swagelok mm 탄소강 표는 EN 10305-1 관 기준이라 넣지 않았습니다.'),
      );
      // 인치로 돌아가면 인치 기본 규격
      await tapKey(tester, 'pt_ts_inch');
      expect(dropValue(tester, 'pt_tube_size'), 'i1/4x035');
      // 배관
      await tapKey(tester, 'pt_kind_pipe');
      expect(find.byKey(const Key('pt_tube_size')), findsNothing);
      expect(find.byKey(const Key('pt_tube_result')), findsNothing);
      expect(find.byKey(const Key('pt_tube_notes')), findsNothing);
      await type(tester, 'pt_design', '10');
      expect(
        textIn(tester, const Key('pt_plan_result')),
        contains('15 bar 이상'),
      );
      await finish(tester);
    },
  );

  testWidgets('공압 안전거리: 구간 1은 시험 압력 탭 튜브, 구간을 더하고 지운다', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'pt_tab_energy');
    expect(
      textOf(tester, 'pt_se_tube'),
      '구간 1: SS316 1/4" × 0.035", 내경 4.57 mm (시험 압력 탭 규격)',
    );
    expect(find.byKey(const Key('pt_se_id')), findsNothing);
    await type(tester, 'pt_se_tlen', '100');
    expect(
      textIn(tester, const Key('pt_se_volume')),
      contains('시험 구간 체적 1.64 L'),
    );
    await tapKey(tester, 'pt_seg_add');
    expect(dropValue(tester, 'pt_seg_size_0'), 'i1/4x035');
    await type(tester, 'pt_seg_len_0', '100');
    expect(
      textIn(tester, const Key('pt_se_volume')),
      contains('시험 구간 체적 3.28 L'),
    );
    await choose(tester, 'pt_seg_size_0', '1/2" × 0.049"');
    // 1/2" × 0.049" 내경 10.21mm, 100m → 8.19L + 1.64L
    expect(
      textIn(tester, const Key('pt_se_volume')),
      contains('시험 구간 체적 9.83 L'),
    );
    await type(tester, 'pt_se_pt', '10');
    expect(
      textIn(tester, const Key('pt_energy_result')),
      contains('(체적 9.83 L, k = 1.4)'),
    );
    await tapKey(tester, 'pt_seg_del_0');
    expect(find.byKey(const Key('pt_seg_size_0')), findsNothing);
    expect(
      textIn(tester, const Key('pt_se_volume')),
      contains('시험 구간 체적 1.64 L'),
    );
    // "시험 압력 탭에서 바꾸기"
    await tapKey(tester, 'pt_se_tube_goto');
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
    await choose(tester, 'pt_tube_size', '3/8" × 0.035"');
    await openTab(tester, 'pt_tab_energy');
    expect(textOf(tester, 'pt_se_tube'), contains('3/8" × 0.035", 내경 7.75 mm'));
    // 배관이면 관 내경·길이 칸
    await openTab(tester, 'pt_tab_plan');
    await tapKey(tester, 'pt_kind_pipe');
    await openTab(tester, 'pt_tab_energy');
    expect(find.byKey(const Key('pt_se_id')), findsOneWidget);
    expect(find.byKey(const Key('pt_se_tube')), findsNothing);
    await finish(tester);
  });

  testWidgets('압력 강하(수압): 튜브 치수·재질을 쓰고, 매설(축 구속)을 켜면 커진다(튜브 약 10%)', (
    tester,
  ) async {
    await pumpPage(tester);
    await openTab(tester, 'pt_tab_decay');
    await tapKey(tester, 'pt_d_hydro');
    expect(
      textOf(tester, 'pt_d_tube'),
      startsWith('튜브: SS316 1/4" × 0.035" (외경 1/4"'),
    );
    expect(find.byKey(const Key('pt_od')), findsNothing);
    var r = textIn(tester, const Key('pt_hydro_result'));
    // SS316 1/4" × 0.035", 20°C → 약 3.22 bar/°C
    expect(r, contains('1°C당 3.22 bar'));
    expect(r, contains('D = 평균 지름'));
    await tapKey(tester, 'pt_restrained');
    r = textIn(tester, const Key('pt_hydro_result'));
    expect(r, contains('(β − 2α)'));
    expect(r, contains('매설되거나 축 방향으로 구속된 관'));
    final v = double.parse(
      RegExp(r'1°C당 ([\d.]+) bar').firstMatch(r)!.group(1)!,
    );
    // 두꺼운 튜브는 관이 거의 늘지 않아 (β − 2α)/(β − 3α) ≈ 1.1에 가깝다
    expect(v / 3.2154, inInclusiveRange(1.05, 1.11));
    // 배관이면 외경·두께 칸
    await openTab(tester, 'pt_tab_plan');
    await tapKey(tester, 'pt_kind_pipe');
    await openTab(tester, 'pt_tab_decay');
    expect(find.byKey(const Key('pt_od')), findsOneWidget);
    expect(find.byKey(const Key('pt_d_tube')), findsNothing);
    await finish(tester);
  });

  testWidgets('시험 기록: 튜브 규격을 시험 정보·기록에 넣고, 불러오면 튜브로 되살린다', (tester) async {
    await pumpPage(tester);
    await choose(tester, 'pt_tube_size', '1/2" × 0.049"');
    await type(tester, 'pt_design', '10');
    await openTab(tester, 'pt_tab_record');
    expect(
      textOf(tester, 'pt_r_info_tube'),
      '튜브: SS316 (ASTM A269/A213) 1/2" × 0.049" (12.7 × 1.24 mm)',
    );
    expect(find.byKey(const Key('pt_r_od')), findsNothing);
    expect(textOf(tester, 'pt_r_tube'), contains('물 온도 영향 계산에 씁니다.'));
    await type(tester, 'pt_r_line', 'IT-101');
    await tapKey(tester, 'pt_r_start');
    await reading(tester, '15', '20');
    now = DateTime(2026, 9, 26, 9, 11, 0);
    await tapKey(tester, 'pt_r_end');
    await reading(tester, '14', '19');
    await tapKey(tester, 'pt_r_leak');
    expect(
      textIn(tester, const Key('pt_r_result')),
      contains('물 온도 변화 -1°C: 온도만으로 압력이 약'),
    );
    await tapKey(tester, 'pt_r_save');
    await tapKey(tester, 'ps_save');
    final saved = (await PtRecordStore.load()).single;
    expect(saved.tubeId, 'i1/2x049');
    expect(saved.tubeMat, 'ss316');
    expect(
      saved.tubeSpec,
      'SS316 (ASTM A269/A213) 1/2" × 0.049" (12.7 × 1.24 mm)',
    );
    expect(saved.odMm, closeTo(12.7, 1e-9));
    expect(saved.wallMm, closeTo(1.2446, 1e-9));
    expect(
      ptRecordsCsv([saved]),
      contains('"SS316 (ASTM A269/A213) 1/2"" × 0.049"" (12.7 × 1.24 mm)"'),
    );
    // 배관·다른 규격으로 바꾼 뒤 불러오면 튜브·규격이 돌아온다
    await openTab(tester, 'pt_tab_plan');
    await choose(tester, 'pt_tube_size', '1/4" × 0.035"');
    await tapKey(tester, 'pt_kind_pipe');
    await openTab(tester, 'pt_tab_record');
    ScaffoldMessenger.of(
      tester.element(find.byKey(const Key('pt_r_result'))),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tapKey(tester, 'pt_r_records');
    await tester.tap(find.byKey(Key('pr_item_${saved.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pr_act_load')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'pt_r_info_tube'), contains('1/2" × 0.049"'));
    await openTab(tester, 'pt_tab_plan');
    expect(chipOn(tester, 'pt_kind_tube'), isTrue);
    expect(dropValue(tester, 'pt_tube_size'), 'i1/2x049');
    await finish(tester);
  });

  testWidgets('배관 기록(튜브 규격 없음)을 불러오면 배관으로', (tester) async {
    await PtRecordStore.put(
      PtRecord(
        id: 'p',
        date: DateTime(2026, 9, 25),
        line: 'P-9',
        odMm: 60.5,
        wallMm: 3.9,
      ),
    );
    await pumpPage(tester);
    await openTab(tester, 'pt_tab_record');
    await tapKey(tester, 'pt_r_records');
    await tester.tap(find.byKey(const Key('pr_item_p')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pr_act_load')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pt_r_info_tube')), findsNothing);
    expect(fieldText(tester, 'pt_r_od'), '60.5');
    await openTab(tester, 'pt_tab_plan');
    expect(chipOn(tester, 'pt_kind_pipe'), isTrue);
    await finish(tester);
  });

  testWidgets('검증 반영 글: B31.1 수압 안전밸브 한도 조건, 압력계 다이얼·디지털, 공압 강하의 137.4.6(d) 참고', (
    tester,
  ) async {
    await pumpPage(tester);
    await tapKey(tester, 'pt_b311');
    await type(tester, 'pt_design', '10');
    await reveal(tester, 'pt_plan_result');
    expect(
      textIn(tester, const Key('pt_plan_result')),
      contains(
        '안전밸브 권장 설정압력: 20 bar (시험압력 15 bar의 1⅓배, 137.1.4·137.4.5 한도를 넘지 않는 범위에서)',
      ),
    );
    await reveal(tester, 'pt_gauge');
    final g = textIn(tester, const Key('pt_gauge'));
    expect(g, contains('다이얼 압력계 기준입니다. 디지털 압력계는'));
    expect(g, contains('발주처가 승인하면 더 길게 둘 수 있습니다'));
    await reveal(tester, 'pt_notes');
    expect(
      textIn(tester, const Key('pt_notes')),
      contains('발주처 승인, 용접부 100% 체적 검사(RT·UT)'),
    );
    await openTab(tester, 'pt_tab_decay');
    await type(tester, 'pt_p1', '7');
    await type(tester, 'pt_p2', '6.9');
    await reveal(tester, 'pt_decay_result');
    final d = textIn(tester, const Key('pt_decay_result'));
    expect(d, contains('판정 기준은 절차서가 정합니다.'));
    expect(
      d,
      contains('137.4.6(d)의 "대기 변화로 설명되지 않는 강하는 찾아 고친다"는 수압 시험 조항입니다.'),
    );
    await finish(tester);
  });

  group('임시 저장', () {
    testWidgets('튜브 선택·설계 온도·구간·매설을 저장한다', (tester) async {
      await pumpPage(tester);
      await tapKey(tester, 'pt_tm_cs');
      await tapKey(tester, 'pt_ts_mm');
      await choose(tester, 'pt_tube_size', '16 × 2 mm');
      await type(tester, 'pt_tube_temp', '120');
      await openTab(tester, 'pt_tab_energy');
      await type(tester, 'pt_se_tlen', '30');
      await tapKey(tester, 'pt_seg_add');
      await type(tester, 'pt_seg_len_0', '12');
      await openTab(tester, 'pt_tab_decay');
      await tapKey(tester, 'pt_d_hydro');
      await tapKey(tester, 'pt_restrained');
      await tester.pump(const Duration(seconds: 1));
      final prefs = await SharedPreferences.getInstance();
      final m = jsonDecode(prefs.getString(_draftKey)!) as Map;
      expect(m['tube'], isTrue);
      expect(m['tubeMat'], 'cs');
      expect(m['tubeSys'], 'metric');
      expect(m['tubeId'], 'm16x2');
      expect(m['restrained'], isTrue);
      expect(m['segs'], [
        {'id': 'm16x2', 'len': '12'},
      ]);
      expect(m['fields']['tubeTemp'], '120');
      expect(m['fields']['tubeLen'], '30');
      await finish(tester);
    });

    testWidgets('다시 열면 튜브 선택·구간을 되살린다', (tester) async {
      SharedPreferences.setMockInitialValues({
        _draftKey: jsonEncode({
          'tube': true,
          'tubeMat': 'cs',
          'tubeSys': 'metric',
          'tubeId': 'm16x2',
          'restrained': true,
          'segs': [
            {'id': 'm10x1', 'len': '5'},
            {'id': 'i1/4x035', 'len': '7'}, // 다른 단위 규격은 기본 규격으로
          ],
          'fields': {'tubeTemp': '120', 'tubeLen': '30'},
        }),
      });
      await pumpPage(tester);
      expect(chipOn(tester, 'pt_tm_cs'), isTrue);
      expect(chipOn(tester, 'pt_ts_mm'), isTrue);
      expect(dropValue(tester, 'pt_tube_size'), 'm16x2');
      expect(fieldText(tester, 'pt_tube_temp'), '120');
      await openTab(tester, 'pt_tab_energy');
      expect(fieldText(tester, 'pt_se_tlen'), '30');
      expect(dropValue(tester, 'pt_seg_size_0'), 'm10x1');
      expect(dropValue(tester, 'pt_seg_size_1'), 'm12x1.5');
      expect(fieldText(tester, 'pt_seg_len_1'), '7');
      await openTab(tester, 'pt_tab_decay');
      await tapKey(tester, 'pt_d_hydro');
      expect(
        tester.widget<Switch>(find.byKey(const Key('pt_restrained'))).value,
        isTrue,
      );
      await finish(tester);
    });

    testWidgets('튜브·배관을 적지 않은 이전 임시 저장은 배관으로 되살린다', (tester) async {
      SharedPreferences.setMockInitialValues({
        _draftKey: jsonEncode({
          'fields': {'design': '10', 'od': '60.5'},
        }),
      });
      await pumpPage(tester);
      expect(chipOn(tester, 'pt_kind_pipe'), isTrue);
      expect(find.byKey(const Key('pt_tube_result')), findsNothing);
      await finish(tester);
    });
  });

  testWidgets('좁은 폰(344)·큰 글씨: 튜브 칸·결과·확인 사항, 구간, 수압 튜브 줄, 기록 탭이 넘치지 않는다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(344, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(textScale: 1.3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await type(tester, 'pt_design', '100');
    await type(tester, 'pt_actual', '900');
    await type(tester, 'pt_tube_temp', '300');
    await tapKey(tester, 'pt_b311');
    await tapKey(tester, 'pt_b313');
    await reveal(tester, 'pt_tube_result');
    await tester.scrollUntilVisible(
      find.byKey(const Key('pt_tube_notes')),
      300,
      scrollable: listScroll,
    );
    expect(tester.takeException(), isNull);
    // 목록 열기(인치 이름은 모두 같은 길이)
    await choose(tester, 'pt_tube_size', '1/2" × 0.049"');
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'pt_tm_cs');
    await tapKey(tester, 'pt_ts_mm');
    await choose(tester, 'pt_tube_size', '16 × 1.5 mm');
    await type(tester, 'pt_tube_temp', '500');
    await reveal(tester, 'pt_tube_result');
    expect(tester.takeException(), isNull);
    await openTab(tester, 'pt_tab_energy');
    await type(tester, 'pt_se_tlen', '120');
    await tapKey(tester, 'pt_seg_add');
    await tapKey(tester, 'pt_seg_add');
    await type(tester, 'pt_seg_len_1', '8');
    await type(tester, 'pt_se_pt', '10');
    await tester.scrollUntilVisible(
      find.byKey(const Key('pt_energy_fragment')),
      300,
      scrollable: listScroll,
    );
    expect(tester.takeException(), isNull);
    await openTab(tester, 'pt_tab_decay');
    await tapKey(tester, 'pt_d_hydro');
    await tapKey(tester, 'pt_restrained');
    await reveal(tester, 'pt_hydro_result');
    expect(tester.takeException(), isNull);
    await openTab(tester, 'pt_tab_record');
    await reveal(tester, 'pt_r_tube');
    expect(tester.takeException(), isNull);
    await finish(tester);
  });
}
