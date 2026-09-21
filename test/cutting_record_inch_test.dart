// 인치로 넣고 저장한 기록의 '측정' 값은 mm여야 한다(기록 화면이 mm로 보인다).
// 예전에는 100in을 넣으면 '측정 100.0mm → 절단 2540.0mm'로 남았다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('인치 100 → 기록 측정 2540mm', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    List<CutRecord> saved = const [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CuttingMainScreen(
            project: CuttingProject(
              id: 'p1',
              name: 'TEST',
              createdAt: DateTime(2026, 9, 22),
            ),
            onSaveCallback: (total, fittings, [records = const []]) =>
                saved = records,
            onUndoCallback: (total, fittings, records) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('in'));
    await tester.pump();
    final field = find
        .byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.decoration?.labelText ?? '').startsWith('전체 길이'),
        )
        .first;
    await tester.enterText(field, '100');
    await tester.pump();
    await tester.tap(find.text('결과'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
    expect(saved.single.originalLength, closeTo(2540, 1e-9));
    expect(saved.single.cutLength, closeTo(2540, 1e-9));
  });
}
