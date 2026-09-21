// 현장 탭: 인치 같이 보기, 누적/간격 전환, 햇빛 아래(흰 바탕) 검사.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_field_data.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking_screen.dart';

FieldMarkingData sample({FieldInchMode inch = FieldInchMode.none}) =>
    FieldMarkingData(
      totalCut: 616,
      inchMode: inch,
      marks: const [
        FieldMark(number: 0, position: 150, angle: 0, rotation: 0),
        FieldMark(number: 1, position: 163, angle: 21, rotation: 0, gap: 163),
        FieldMark(number: 2, position: 358, angle: 21, rotation: 180, gap: 195),
      ],
    );

Future<void> pump(WidgetTester tester, FieldMarkingData data) async {
  await tester.binding.setSurfaceSize(const Size(882, 344));
  await tester.pumpWidget(
    MaterialApp(
      home: FieldMarkingScreen(
        listenable: ValueNotifier(0),
        compute: () => data,
        isActive: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String bigNumber(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('field_step_number'))).data!;

void main() {
  group('인치 글', () {
    test('분수 눈금으로 반올림하고 줄인다', () {
      expect(formatInch(358, FieldInchMode.fraction), '14 1/8"'); // 14.094
      expect(formatInch(25.4, FieldInchMode.fraction), '1"');
      expect(formatInch(12.7, FieldInchMode.fraction), '1/2"');
      expect(formatInch(616, FieldInchMode.fraction), '24 1/4"'); // 24.252
      expect(
        formatInch(616, FieldInchMode.fraction, denominator: 8),
        '24 1/4"',
      );
      expect(
        formatInch(163, FieldInchMode.fraction, denominator: 32),
        '6 13/32"',
      );
    });
    test('소수점과 안 쓰기', () {
      expect(formatInch(358, FieldInchMode.decimal), '14.09"');
      expect(formatInch(358, FieldInchMode.none), '');
    });
  });

  test('자르기 단계의 간격은 마지막 벤드 마킹에서', () {
    final d = sample();
    final steps = fieldSteps(d);
    expect(fieldStepGap(d, steps[0]), 163);
    expect(fieldStepGap(d, steps[1]), 195);
    expect(fieldStepGap(d, steps[2]), 616 - 358);
  });

  group('전선관 설정의 단위', () {
    late Map<String, dynamic> defaults;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      defaults = Map<String, dynamic>.from(globalBenderSettings.value);
      ConduitDataManager().bendList
        ..clear()
        ..addAll([
          {'length': 300.0, 'angle': 90.0, 'rotation': 0.0},
          {'length': 400.0, 'angle': 0.0, 'rotation': 0.0},
        ]);
    });
    tearDown(() => globalBenderSettings.value = defaults);

    test('인치(분수) 설정이면 그 눈금으로, mm면 인치 안 씀', () {
      globalBenderSettings.value = {
        ...defaults,
        'unitSystem': '인치 (분수)',
        'fractionPrecision': '1/8"',
      };
      var d = computeConduitFieldData();
      expect(d.inchMode, FieldInchMode.fraction);
      expect(d.inchDenominator, 8);

      globalBenderSettings.value = {...defaults, 'unitSystem': '인치 (소수점)'};
      expect(computeConduitFieldData().inchMode, FieldInchMode.decimal);

      globalBenderSettings.value = {...defaults, 'unitSystem': '미터법 (mm)'};
      d = computeConduitFieldData();
      expect(d.inchMode, FieldInchMode.none);
      expect(d.inch(300), '');
    });
  });

  group('화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('간격으로 바꾸면 말풍선·단계 줄·큰 숫자가 앞 마킹에서 잰 값이 된다', (
      tester,
    ) async {
      await pump(tester, sample());
      expect(find.text('358'), findsOneWidget);

      await tester.tap(find.text('간격'));
      await tester.pumpAndSettle();
      expect(find.text('+195'), findsOneWidget); // 말풍선
      expect(find.text('+195 mm'), findsOneWidget); // 아래 단계 줄
      expect(find.text('+258'), findsOneWidget); // 자르기 말풍선(616 − 358)

      await tester.tap(find.byKey(const Key('field_mode_toggle')));
      await tester.pumpAndSettle();
      expect(bigNumber(tester), '+163');
      expect(find.textContaining('줄자 눈금 163 mm'), findsOneWidget);

      // 폰에 기억한다.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('field_show_gap'), isTrue);
    });

    testWidgets('인치 설정이면 한 단계씩 큰 숫자 아래에 인치를 같이', (tester) async {
      await pump(tester, sample(inch: FieldInchMode.fraction));
      await tester.tap(find.byKey(const Key('field_mode_toggle')));
      await tester.pumpAndSettle();
      expect(bigNumber(tester), '163');
      expect(
        tester.widget<Text>(find.byKey(const Key('field_step_inch'))).data,
        '6 7/16"',
      );
    });

    testWidgets('mm면 인치 줄이 없다', (tester) async {
      await pump(tester, sample());
      await tester.tap(find.byKey(const Key('field_mode_toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('field_step_inch')), findsNothing);
    });

    testWidgets('햇빛 아래: 흰 바탕, 더 큰 숫자, 넘치지 않음, 기억', (tester) async {
      final errors = <String>[];
      final old = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      await pump(tester, sample(inch: FieldInchMode.fraction));
      await tester.tap(find.byKey(const Key('field_contrast_toggle')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.white,
      );
      await tester.tap(find.byKey(const Key('field_mode_toggle')));
      await tester.pumpAndSettle();
      final t = tester.widget<Text>(find.byKey(const Key('field_step_number')));
      expect(t.style!.fontSize, 120);
      FlutterError.onError = old;
      expect(errors, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('field_high_contrast'), isTrue);
    });

    testWidgets('기억해 둔 보기로 다시 열린다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'field_show_gap': true,
        'field_high_contrast': true,
      });
      await pump(tester, sample());
      expect(find.text('+195'), findsOneWidget);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.white,
      );
    });
  });
}
