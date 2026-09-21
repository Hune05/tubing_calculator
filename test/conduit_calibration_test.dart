// 전선관 "한 번 꺾어 보고 잡기" 검사.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';

void main() {
  group('셈', () {
    test('표 값으로 꺾은 토막을 재면 표 값이 그대로 나온다', () {
      // 22mm EMT: 테이크업 152.4, 게인 82.5. 1000mm 토막, 300에 마킹.
      const takeUp = 152.4, gain = 82.5, cut = 1000.0, mark = 300.0;
      const stub = mark + takeUp; // 452.4
      const other = cut + gain - stub; // 630.1
      final r = conduitCalibration(
        cut: cut,
        mark: mark,
        stub: stub,
        otherLeg: other,
      )!;
      expect(r.takeUp, closeTo(takeUp, 1e-9));
      expect(r.gain, closeTo(gain, 1e-9));
    });

    test('잡은 값으로 같은 토막을 다시 셈하면 마킹 자리·절단 길이가 맞다', () {
      final r = conduitCalibration(
        cut: 1200,
        mark: 350,
        stub: 498,
        otherLeg: 780,
      )!;
      final settings = {
        'benderType': 'hand',
        'takeUp': r.takeUp,
        'gain': r.gain,
        'clr': 114.3,
        'applySpringback': false,
        'bladeKerf': 0.0,
      };
      final list = [
        {'length': 498.0, 'angle': 90.0, 'rotation': 0.0},
        {'length': 780.0, 'angle': 0.0, 'rotation': 0.0},
      ];
      final m = calculateConduitMarkings(list, settings);
      expect(m.first['mark'] as double, closeTo(350, 1e-9));
      expect(conduitTotalCut(list, settings), closeTo(1200, 1e-9));
    });

    test('빈 칸·말이 안 되는 값이면 잡지 않는다', () {
      expect(
        conduitCalibration(cut: 0, mark: 300, stub: 450, otherLeg: 630),
        isNull,
      );
      // 스텁이 마킹 자리보다 짧다 → 테이크업 음수.
      expect(
        conduitCalibration(cut: 1000, mark: 500, stub: 450, otherLeg: 630),
        isNull,
      );
      // 다리 합이 자른 길이보다 짧다 → 게인 음수.
      expect(
        conduitCalibration(cut: 1200, mark: 300, stub: 450, otherLeg: 630),
        isNull,
      );
    });
  });

  group('설정 화면', () {
    late Map<String, dynamic> defaults;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      defaults = Map<String, dynamic>.from(globalBenderSettings.value);
    });
    tearDown(() => globalBenderSettings.value = defaults);

    testWidgets('재 본 값을 넣으면 테이크업·게인이 저장된다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 2600));
      await tester.pumpWidget(const MaterialApp(home: ConduitSettingsPage()));
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('conduit_calibrate'));
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      final fields = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '1000');
      await tester.enterText(fields.at(1), '300');
      await tester.enterText(fields.at(2), '448');
      await tester.enterText(fields.at(3), '630');
      await tester.pumpAndSettle();
      expect(find.text('148.0 mm'), findsOneWidget); // 448 − 300
      expect(find.text('78.0 mm'), findsOneWidget); // 448 + 630 − 1000

      await tester.tap(find.byKey(const Key('conduit_calib_apply')));
      await tester.pumpAndSettle();

      expect(globalBenderSettings.value['takeUp'], 148.0);
      expect(globalBenderSettings.value['gain'], 78.0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kConduitSettingsPrefsKey), contains('"gain":78.0'));
    });

    testWidgets('유압(램) 화면에는 단추가 없다(테이크업·게인을 안 쓴다)', (tester) async {
      globalBenderSettings.value = {
        ...globalBenderSettings.value,
        'benderType': 'ram',
      };
      await tester.binding.setSurfaceSize(const Size(420, 2600));
      await tester.pumpWidget(const MaterialApp(home: ConduitSettingsPage()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('conduit_calibrate')), findsNothing);
    });
  });
}
