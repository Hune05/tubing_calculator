// 특수 벤딩 시트(퀵 킥·굴림 오프셋·새들·오프셋)가 폰 폭에서 넘치지 않는지.
// 예전에는 제목 줄·빠른 각도 줄·결과와 닫기 단추 줄이 320~390 폭에서 넘쳤다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_quick_kick_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_rolling_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_saddle_bottom_sheet.dart';

final specs = BendSheetSpecs(
  radius: 38.1,
  gain90: 0,
  markOffset: (a) => bendSetback(38.1, a),
);

final sheets = <String, Widget Function()>{
  '퀵 킥': () => const MobileQuickKickBottomSheet(),
  '굴림 오프셋': () => MobileRollingOffsetBottomSheet(
    currentRotation: 0,
    onAddBend: (_, _, _) {},
    specs: specs,
  ),
  '새들': () => MobileSaddleBottomSheet(
    currentRotation: 0,
    onAddBend: (_, _, _) {},
    specs: specs,
  ),
  '오프셋': () => MobileOffsetBottomSheet(
    currentRotation: 0,
    onAddMultipleBends: (_) {},
    specs: specs,
  ),
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    MachineSpecs().update(radius: 38.1);
  });

  for (final e in sheets.entries) {
    for (final w in [320.0, 360.0, 390.0]) {
      testWidgets('${e.key} 폭 ${w.toInt()}에서 넘치지 않는다', (tester) async {
        await tester.binding.setSurfaceSize(Size(w, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final errors = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) =>
            errors.add(d.exceptionAsString().split('\n').first);
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(body: SingleChildScrollView(child: e.value())),
            ),
          );
          await tester.pumpAndSettle();
        } finally {
          FlutterError.onError = old;
        }
        expect(errors, isEmpty);
      });
    }
  }
}
