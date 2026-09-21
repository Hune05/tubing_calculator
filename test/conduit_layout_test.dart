// 전선관 화면이 폰 폭(344dp, 접은 화면)에서 넘치지 않는지 본다.
// 예전에는 설정 화면에서 칸 이름이 한 줄로 고정되어 최대 161px 넘쳤다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_input_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';

Future<List<String>> layoutErrors(
  WidgetTester tester,
  Widget page,
  double width, {
  Future<void> Function()? after,
}) async {
  final errors = <String>[];
  final old = FlutterError.onError;
  FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
  try {
    await tester.binding.setSurfaceSize(Size(width, 3000));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
    await tester.pumpAndSettle();
    if (after != null) await after();
  } finally {
    FlutterError.onError = old;
  }
  return errors;
}

void main() {
  late Map<String, dynamic> defaults;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    defaults = Map<String, dynamic>.from(globalBenderSettings.value);
  });
  tearDown(() => globalBenderSettings.value = defaults);

  for (final type in ['hand', 'ram', 'chicago']) {
    for (final w in [320.0, 344.0]) {
      testWidgets('설정 화면($type) 폭 ${w.toInt()}에서 넘치지 않는다', (tester) async {
        globalBenderSettings.value = {
          ...globalBenderSettings.value,
          'benderType': type,
        };
        final errors = await layoutErrors(
          tester,
          const ConduitSettingsPage(),
          w,
        );
        expect(errors, isEmpty);
      });
    }
  }

  testWidgets('입력 패널(90° 벤딩·직관+각도) 폭 344에서 넘치지 않는다', (tester) async {
    ConduitDataManager().bendList
      ..clear()
      ..addAll([
        {'length': 150.0, 'angle': 0.0, 'rotation': 0.0},
        {'length': 72.3, 'angle': 21.0, 'rotation': 0.0},
      ]);
    final errors = await layoutErrors(
      tester,
      const ConduitInputTab(),
      344,
      after: () async {
        await tester.tap(find.text('90° 벤딩'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('직관+각도'));
        await tester.pumpAndSettle();
        // 21° 줄을 눌러 고치기(✕·수정 단추가 같이 나온다).
        await tester.tap(find.text('길이: 72.3mm'));
        await tester.pumpAndSettle();
      },
    );
    expect(errors, isEmpty);
  });
  for (final type in ['hand', 'ram', 'chicago']) {
    testWidgets('설정 화면($type)에 공통 보정 칸이 다 있다', (tester) async {
      globalBenderSettings.value = {
        ...globalBenderSettings.value,
        'benderType': type,
        'applySpringback': true,
      };
      await layoutErrors(tester, const ConduitSettingsPage(), 344);
      for (final label in [
        '스프링백 보정',
        '스프링백 각도',
        '수축량(Shrink) 자동 공제',
        '커플링 끝 여유',
        '톱날 두께',
      ]) {
        expect(find.text(label), findsOneWidget, reason: '$type: $label');
      }
    });
  }
}
