// 오프셋 시트가 목록에 넣는 두 구간: 1번 마킹이 시작 거리(기본 0) 자리에 오고,
// 앞(FRONT)을 골라도 끝 방향이 처음 방향으로 돌아온다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/core/engine/bend_path.dart';
import 'package:tubing_calculator/src/core/engine/tube_bending_engine.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_offset_bottom_sheet.dart';

void main() {
  for (final dir in ['UP', 'FRONT', 'BACK']) {
    testWidgets('$dir: 1번 마킹 0, 끝 방향은 처음과 같다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      MachineSpecs().resetForTest();
      MachineSpecs().update(radius: 100);
      final dm = MobileBendDataManager();
      dm.offsetHeight = 100;
      dm.offsetAngle = 45;
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      List<Map<String, double>> added = const [];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => MobileOffsetBottomSheet.show(
                  context,
                  currentRotation: 0,
                  specs: BendSheetSpecs(
                    radius: 100,
                    gain90: 0,
                    markOffset: (a) => bendSetback(100, a),
                  ),
                  onAddMultipleBends: (b) => added = b,
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(dir).first);
      await tester.tap(find.text(dir).first);
      await tester.pump();
      await tester.ensureVisible(find.text('적용').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('적용').first);
      await tester.pumpAndSettle();
      expect(added, hasLength(2));

      final res = TubeBendingEngine(radius: 100).calculate([
        for (final b in added)
          BendInstruction(
            length: b['length']!,
            angle: b['angle']!,
            rotation: b['rotation']!,
          ),
      ], 0);
      expect(
        (res['steps'] as List<StepResult>).first.markingPoint,
        closeTo(0, 0.1),
      );
      final path = buildBendPath(
        [
          for (final b in added)
            PathSegment(
              length: b['length']!,
              angle: b['angle']!,
              rotation: b['rotation']!,
            ),
        ],
        radius: 100,
        tail: 300,
      );
      expect(path.endDirection.x, closeTo(1, 0.001));
    });
  }

  testWidgets('F3 각도가 90° 이상이면 말없이 넘어가지 않고 알린다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    MachineSpecs().update(radius: 100);
    final dm = MobileBendDataManager();
    dm.offsetHeight = 100;
    dm.offsetAngle = 95;
    addTearDown(() => dm.offsetAngle = 45);
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    List<Map<String, double>> added = const [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => MobileOffsetBottomSheet.show(
                context,
                currentRotation: 0,
                specs: BendSheetSpecs(
                  radius: 100,
                  gain90: 0,
                  markOffset: (a) => bendSetback(100, a),
                ),
                onAddMultipleBends: (b) => added = b,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('UP').first);
    await tester.tap(find.text('UP').first);
    await tester.pump();
    await tester.ensureVisible(find.text('적용').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('적용').first);
    await tester.pump();
    expect(added, isEmpty);
    expect(find.textContaining('90°보다 작아야'), findsOneWidget);
  });
}
