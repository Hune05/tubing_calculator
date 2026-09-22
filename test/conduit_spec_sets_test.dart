// 전선관 설정: 손으로 고친 제원이 설정을 다시 열어도, 규격을 바꿨다 돌아와도 남는지.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/conduit_spec_sets.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';

Finder fieldWithText(String text) =>
    find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text);

Future<void> open(WidgetTester tester, Key key) async {
  await tester.binding.setSurfaceSize(const Size(500, 4000));
  await tester.pumpWidget(MaterialApp(home: ConduitSettingsPage(key: key)));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  final btn = find.text('현재 장비 설정 저장');
  await tester.ensureVisible(btn);
  await tester.pumpAndSettle();
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

Future<void> pickSize(WidgetTester tester, String from, String to) async {
  await tester.tap(find.text(from).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(to).last);
  await tester.pumpAndSettle();
}

void main() {
  late Map<String, dynamic> defaults;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    defaults = Map<String, dynamic>.from(globalBenderSettings.value);
  });
  tearDown(() => globalBenderSettings.value = defaults);

  test('조합 이름표는 대소문자·빈칸을 가리지 않는다', () {
    expect(
      conduitSpecKey(
        benderType: 'hand',
        manufacturer: 'Greenlee ',
        conduitType: 'EMT',
        conduitSize: '22mm',
      ),
      conduitSpecKey(
        benderType: 'HAND',
        manufacturer: 'greenlee',
        conduitType: 'emt',
        conduitSize: '22mm',
      ),
    );
  });

  test('적어 둔 조합별 제원을 다시 읽는다, 깨져 있어도 멈추지 않는다', () async {
    await saveConduitSpecSet('a', {'gain': 80.0, 'takeUp': 150.0});
    await saveConduitSpecSet('b', {'gain': 90.0});
    final sets = await loadConduitSpecSets();
    expect(sets['a']!['gain'], 80.0);
    expect(sets['a']!['takeUp'], 150.0);
    expect(sets['b']!['gain'], 90.0);

    SharedPreferences.setMockInitialValues({kConduitSpecSetsPrefsKey: '깨짐'});
    expect(await loadConduitSpecSets(), isEmpty);
  });

  testWidgets('고쳐 저장한 게인이 설정을 다시 열어도 그대로다(표 값으로 안 덮는다)', (tester) async {
    await open(tester, const Key('a'));
    final gain = fieldWithText(globalBenderSettings.value['gain'].toString());
    expect(gain, findsOneWidget);
    await tester.enterText(gain, '80.0');
    await save(tester);
    expect(globalBenderSettings.value['gain'], 80.0);

    await tester.pumpWidget(const SizedBox());
    await open(tester, const Key('b'));
    expect(fieldWithText('80.0'), findsOneWidget);
  });

  testWidgets('규격을 바꿨다 돌아오면 그 규격에 저장해 둔 값이 나온다', (tester) async {
    await open(tester, const Key('a'));
    final gain = fieldWithText(globalBenderSettings.value['gain'].toString());
    await tester.enterText(gain, '80.0');
    await save(tester);

    await pickSize(tester, '22mm', '28mm');
    // 28mm는 처음이라 표 값이 들어간다(80이 아니다).
    expect(fieldWithText('80.0'), findsNothing);

    await pickSize(tester, '28mm', '22mm');
    expect(fieldWithText('80.0'), findsOneWidget);
  });

  test('처음 고르는 규격의 스프링백·끝 여유 기본값', () {
    Map<String, double> d(String t, String z) =>
        conduitCorrectionDefaults(conduitType: t, conduitSize: z);
    expect(d('EMT', '22mm'), {'springback': 2.0, 'couplingAllowance': 50.0});
    expect(d('EMT', '16mm'), {'springback': 2.0, 'couplingAllowance': 40.0});
    expect(d('EMT', '36mm'), {'springback': 3.0, 'couplingAllowance': 60.0});
    expect(d('Rigid', '54mm'), {'springback': 5.0, 'couplingAllowance': 70.0});
    expect(d('PVC', '28mm')['springback'], 0.0);
  });

  testWidgets('스프링백·커플링 끝 여유도 규격마다 따로 기억한다', (tester) async {
    await open(tester, const Key('a'));
    await tester.enterText(fieldWithText('3.0'), '4.5');
    await tester.enterText(fieldWithText('50.0'), '55.0');
    await save(tester);

    await pickSize(tester, '22mm', '36mm');
    // 36mm는 처음이라 EMT 36mm 기본값(3°, 60)이 들어간다.
    expect(fieldWithText('4.5'), findsNothing);
    expect(fieldWithText('3.0'), findsOneWidget);
    expect(fieldWithText('60.0'), findsOneWidget);
    expect(find.textContaining('처음 고른 규격이라 기본값'), findsOneWidget);

    await pickSize(tester, '36mm', '22mm');
    expect(fieldWithText('4.5'), findsOneWidget);
    expect(fieldWithText('55.0'), findsOneWidget);
    expect(find.textContaining('저장해 둔 값입니다'), findsOneWidget);
  });

  testWidgets('저장 전에 규격을 바꿨다 돌아와도 고친 값이 남고, 저장하면 같이 저장된다', (tester) async {
    await open(tester, const Key('a'));
    await tester.enterText(
      fieldWithText(globalBenderSettings.value['gain'].toString()),
      '80.0',
    );
    await pickSize(tester, '22mm', '28mm');
    await tester.enterText(fieldWithText('3.0'), '3.5');
    await pickSize(tester, '28mm', '22mm');
    expect(fieldWithText('80.0'), findsOneWidget);

    await save(tester);
    expect(find.textContaining('다른 규격 1개도 같이 저장했습니다'), findsOneWidget);
    final sets = await loadConduitSpecSets();
    final k22 = conduitSpecKey(
      benderType: 'hand',
      manufacturer: 'Greenlee',
      conduitType: 'EMT',
      conduitSize: '22mm',
    );
    final k28 = conduitSpecKey(
      benderType: 'hand',
      manufacturer: 'Greenlee',
      conduitType: 'EMT',
      conduitSize: '28mm',
    );
    expect(sets[k22]!['gain'], 80.0);
    expect(sets[k28]!['springback'], 3.5);
  });

  testWidgets('스프링백이 없는 예전 기록도 지금 쓰던 스프링백을 잃지 않는다', (tester) async {
    final k22 = conduitSpecKey(
      benderType: 'hand',
      manufacturer: 'Greenlee',
      conduitType: 'EMT',
      conduitSize: '22mm',
    );
    SharedPreferences.setMockInitialValues({
      kConduitSpecSetsPrefsKey: '{"$k22":{"gain":81.2,"takeUp":152.4}}',
    });
    await open(tester, const Key('a'));
    await pickSize(tester, '22mm', '28mm');
    await pickSize(tester, '28mm', '22mm');
    // 표 기본값(EMT 22mm = 2°)이 아니라 쓰던 3°가 그대로다.
    expect(fieldWithText('3.0'), findsOneWidget);
    expect(fieldWithText('2.0'), findsNothing);
  });
}
