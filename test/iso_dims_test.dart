// 아이소 캐드식 치수(10-17): 계획·실측 보기로 복잡한 배관을 여러 방향에서 그려도 오류가 없는지.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_pipe_visualizer.dart';

void main() {
  final bends = <Map<String, dynamic>>[
    {'length': 500.0, 'angle': 90.0, 'rotation': 0.0},
    {'length': 300.0, 'angle': 90.0, 'rotation': 360.0},
    {'length': 400.0, 'angle': 90.0, 'rotation': 180.0},
    {'length': 250.0, 'angle': 90.0, 'rotation': 270.0},
    {'length': 80.0, 'angle': 90.0, 'rotation': 0.0},
    {'length': 150.0, 'angle': 0.0, 'rotation': 0.0},
    {'length': 350.0, 'angle': 90.0, 'rotation': 450.0},
    {'length': 200.0, 'angle': 45.0, 'rotation': 90.0},
  ];
  for (final mode in [1, 2]) {
    for (final size in const [Size(360, 640), Size(800, 1200)]) {
      testWidgets('치수 $mode · ${size.width.toInt()}', (t) async {
        SharedPreferences.setMockInitialValues({'iso_dim_mode_v1': mode});
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(MaterialApp(
          home: Scaffold(
            body: MobilePipeVisualizer(
              bendList: bends,
              useSavedDirection: false,
              showDimControl: true,
              bendRadius: 38.1,
              outerDiameter: 12.7,
              measuredDiff: const {0: 3, 3: -1, 4: 6},
              cutDiff: 1,
              measuredAngle: const {0: 91.0, 3: 92.5},
            ),
          ),
        ));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.byKey(const Key('iso_dim_2')), findsOneWidget);
        if (mode == 2) {
          expect(find.byKey(const Key('iso_measure_summary')), findsOneWidget);
          expect(find.textContaining('불합격 2'), findsOneWidget);
          // 각도: 91(+1 합격)·92.5(+2.5 불합격).
          expect(find.textContaining('각도 2 불합격 1'), findsOneWidget);
        }
        // 잘 보이게 맞춤.
        await t.tap(find.byKey(const Key('iso_auto_fit')));
        await t.pump();
        expect(t.takeException(), isNull);
        // 돌리기 단추로 네 방향 다 그려 본다.
        for (var i = 0; i < 4; i++) {
          await t.tap(find.byIcon(Icons.rotate_90_degrees_cw));
          await t.pump();
          expect(t.takeException(), isNull);
        }
      });
    }
  }
}
