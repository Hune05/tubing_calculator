// 아이소 치수·실측·맞춤 경계값(10-17 밤샘 점검): 이상한 목록에서도 그리기·누르기·맞춤이 터지지 않는지.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_pipe_visualizer.dart';

Map<String, dynamic> b(double len, double ang, double rot) =>
    {'length': len, 'angle': ang, 'rotation': rot};

void main() {
  final cases = <String, List<Map<String, dynamic>>>{
    '직관 하나': [b(500, 0, 0)],
    '벤드 하나': [b(300, 90, 0)],
    '길이 0 벤드': [b(0, 90, 0), b(200, 90, 90)],
    '180° U': [b(300, 180, 0), b(300, 0, 0)],
    '45°·직관 섞임': [b(200, 45, 0), b(100, 0, 0), b(150, 45, 180), b(300, 0, 0)],
    '같은 방향 연속(못 만듦)': [b(50, 90, 0), b(50, 90, 0), b(50, 90, 0)],
    '아주 긴 것과 짧은 것': [b(6000, 90, 0), b(5, 90, 360), b(3000, 90, 180)],
  };
  for (final e in cases.entries) {
    for (final tail in [0.0, 150.0]) {
      testWidgets('${e.key} · 꼬리 $tail', (t) async {
        SharedPreferences.setMockInitialValues({'iso_dim_mode_v1': 2});
        t.view.physicalSize = const Size(360, 700);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(MaterialApp(
          home: Scaffold(
            body: MobilePipeVisualizer(
              bendList: e.value,
              tailLength: tail,
              useSavedDirection: false,
              showDimControl: true,
              startFit: true,
              endFit: true,
              fittingDepth: 23,
              bendRadius: 38.1,
              outerDiameter: 12.7,
              measuredDiff: const {0: 3, 1: -9, 99: 1},
              cutDiff: 2,
              measuredAngle: const {0: 92.0, 5: 80.0},
              onLegTap: (_) {},
              onBendTap: (_) {},
            ),
          ),
        ));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        // 여기저기 눌러 본다(치수·꺾이는 점·빈 곳).
        for (final p in const [Offset(180, 350), Offset(100, 300), Offset(250, 420), Offset(30, 650)]) {
          await t.tapAt(p);
          await t.pump();
          expect(t.takeException(), isNull);
        }
        await t.tap(find.byKey(const Key('iso_auto_fit')));
        await t.pump();
        expect(t.takeException(), isNull);
        await t.tap(find.byKey(const Key('iso_dim_1')));
        await t.pump();
        await t.tap(find.byKey(const Key('iso_dim_0')));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
      });
    }
  }
}
