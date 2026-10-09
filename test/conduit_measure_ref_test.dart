// 10-09 사용자: 전선관 길이를 늘 관 중심(가상 중심선)으로 재는데 앱 칸이 "관 등까지"라
// 매번 바깥지름 절반(22mm 후강 13)을 빼거나 더해야 했다 → 치수 기준을 고르게 함.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_field_data.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_diff.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';
import 'package:tubing_calculator/src/presentation/conduit/widgets/conduit_calibration_sheet.dart';

void main() {
  test('바깥지름: 후강은 KS 표, EMT는 C80.3, 모르면 null', () {
    expect(conduitOuterDiameter('Rigid', '22mm'), 26.5);
    expect(conduitOuterDiameter('EMT', '22mm'), 23.4);
    expect(conduitOuterDiameter('Rigid', '99mm'), isNull);
    expect(conduitOuterDiameter('Rigid', ''), isNull);
  });

  test('관 등 기준 표 값을 관 중심으로: 테이크업 − D/2, 게인 − D (관 등이면 그대로)', () {
    final c = conduitTableValuesForRef(takeUp: 152.4, gain: 82.5, od: 23.4, center: true);
    expect(c.takeUp, closeTo(140.7, 1e-9));
    expect(c.gain, closeTo(59.1, 1e-9));
    final b = conduitTableValuesForRef(takeUp: 152.4, gain: 82.5, od: 23.4, center: false);
    expect(b.takeUp, 152.4);
    expect(b.gain, 82.5);
  });

  test('관 중심으로 재고 표 값을 바꿔 쓰면 90° 마킹이 관 등 기준과 같은 자리(관 위의 같은 점)', () {
    // 관 끝에서 꺾인 다리까지: 관 등 500 = 관 중심 500 − 23.4/2.
    const od = 23.4;
    final back = {'benderType': 'hand', 'takeUp': 152.4, 'gain': 82.5, 'clr': 114.3};
    final cv = conduitTableValuesForRef(takeUp: 152.4, gain: 82.5, od: od, center: true);
    final center = {...back, 'takeUp': cv.takeUp, 'gain': cv.gain, kConduitMeasureRefKey: kConduitRefCenter};
    final mBack = calculateConduitMarkings([
      {'length': 500.0, 'angle': 90.0},
      {'length': 300.0, 'angle': 0.0},
    ], back);
    final mCenter = calculateConduitMarkings([
      {'length': 500.0 - od / 2, 'angle': 90.0},
      {'length': 300.0 - od / 2, 'angle': 0.0},
    ], center);
    expect(mCenter.first['mark'] as double, closeTo(mBack.first['mark'] as double, 1e-9));
    // 자를 길이도 같다(관은 같은 관이다).
    expect(
      conduitTotalCut([
        {'length': 500.0 - od / 2, 'angle': 90.0},
        {'length': 300.0 - od / 2, 'angle': 0.0},
      ], center),
      closeTo(conduitTotalCut([
        {'length': 500.0, 'angle': 90.0},
        {'length': 300.0, 'angle': 0.0},
      ], back), 1e-9),
    );
  });

  test('마킹지 제원·보관함 비교에 치수 기준이 나온다', () {
    final specs = {for (final (k, v) in conduitMarkingSheetSpecs({'benderType': 'ram', kConduitMeasureRefKey: 'center'})) k: v};
    expect(specs['치수 기준'], '관 중심');
    expect(
      conduitSettingDiffs({'measureRef': 'back'}, {'measureRef': 'center'}),
      ['치수 기준: 저장 때 관 등 → 지금 관 중심'],
    );
  });

  testWidgets('설정에 "치수 기준"이 있고, 관 중심이면 시험 벤딩 안내도 관 중심까지', (tester) async {
    SharedPreferences.setMockInitialValues({});
    globalBenderSettings.value = {
      ...globalBenderSettings.value,
      'benderType': 'ram',
      kConduitMeasureRefKey: kConduitRefCenter,
    };
    await tester.binding.setSurfaceSize(const Size(420, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: ConduitSettingsPage()));
    await tester.pumpAndSettle();
    // 칸 이름은 줄바꿈 자리 표시(U+2060)가 끼어 있어 그것을 빼고 찾는다.
    final label = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? w.textSpan?.toPlainText() ?? '').replaceAll('⁠', '') == '치수 기준',
    );
    expect(label, findsOneWidget);
    expect(find.text('관 중심 (가상 중심선)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('conduit_calibrate')));
    await tester.pumpAndSettle();
    expect(find.byType(ConduitCalibrationSheet), findsOneWidget);
    expect(find.textContaining('관 중심(가상 중심선)까지'), findsWidgets);
    expect(find.textContaining('관 바깥면(등)까지'), findsNothing);
  });
}
