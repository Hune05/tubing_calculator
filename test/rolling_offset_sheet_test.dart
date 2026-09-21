// 굴림 오프셋 시트가 목록에 넣는 첫 구간.
// 예전에는 축소값만 넣어 R150·높이 100·45°에서 1번 마킹이 −20.7mm였다.
// 반경이 달라도 1번 마킹이 시작 거리 자리에 와야 한다.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/core/engine/tube_bending_engine.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_rolling_offset_bottom_sheet.dart';

BendSheetSpecs tubeSpecs(double r) =>
    BendSheetSpecs(radius: r, gain90: 0, markOffset: (a) => bendSetback(r, a));

double firstMark(List<(double, double, double)> bends, double r) {
  final res = TubeBendingEngine(radius: r).calculate([
    for (final (l, a, rot) in bends)
      BendInstruction(length: l, angle: a, rotation: rot),
  ], 0);
  return (res['steps'] as List<StepResult>).first.markingPoint;
}

void main() {
  // 높이 100, 굴림 0, 45°: 빗변 141.42, 전진 100.
  final travel = 100 / math.sin(math.pi / 4);
  const advance = 100.0;

  for (final r in [38.1, 100.0, 150.0]) {
    for (final start in [0.0, 250.0]) {
      test('R$r 시작 거리 $start: 1번 마킹 = 시작 거리', () {
        final bends = rollingOffsetBends(
          specs: tubeSpecs(r),
          startDistance: start,
          travel: travel,
          angle: 45,
          advance: advance,
          rotation: 0,
        );
        expect(firstMark(bends, r), closeTo(start, 0.1));
        expect(bends[1].$1, closeTo(141.4, 0.05));
      });
    }
  }

  test('두 번째 방향은 반대(앞↔뒤 포함)', () {
    for (final (sel, opp) in [(0.0, 180.0), (360.0, 450.0), (450.0, 360.0)]) {
      final bends = rollingOffsetBends(
        specs: tubeSpecs(100),
        startDistance: 0,
        travel: travel,
        angle: 45,
        advance: advance,
        rotation: sel,
      );
      expect(bends[0].$3, sel);
      expect(bends[1].$3, opp);
    }
  });

  testWidgets('시트에서 넣으면 1번 마킹이 시작 거리(기본 0) 자리', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final added = <(double, double, double)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => MobileRollingOffsetBottomSheet.show(
                context,
                currentRotation: 0,
                specs: tubeSpecs(150),
                onAddBend: (l, a, r) => added.add((l, a, r)),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('UP'));
    await tester.tap(find.text('UP'));
    await tester.pump();
    await tester.ensureVisible(find.text('도면 적용'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('도면 적용'));
    await tester.pump();
    expect(added, hasLength(2));
    expect(firstMark(added, 150), closeTo(0, 0.1));
  });
}
