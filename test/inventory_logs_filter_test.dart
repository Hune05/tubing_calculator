// 자재 기록을 작업별로 걸러 보는 화면.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_leftovers.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/widgets/cutting_optimization_sheet.dart';

void main() {
  // 잔재는 앱에서는 서버에 두지만, 검사에서는 폰 저장소로 바꿔 쓴다.
  leftoverStore = PrefsLeftoverStore();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // 재단 계획 창에 "이 작업 자재 기록" 단추가 붙는지 본다.
  // (자재 기록 화면 자체는 서버를 보므로 여기서는 단추만 확인한다.)
  Future<void> openSheet(
    WidgetTester tester, {
    required String jobLogName,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showCuttingOptimizationSheet(
                ctx,
                pieces: const [500, 700],
                initialStockLength: 6000,
                kerf: 2,
                jobLogName: jobLogName,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  testWidgets('작업 이름을 주면 "이 작업 자재 기록" 단추가 보인다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await openSheet(tester, jobLogName: '형강 컷팅 · 전선관');
    final btn = find.byKey(const Key('job_material_log'));
    expect(btn, findsOneWidget);
    await tester.ensureVisible(btn);
    expect(find.text('이 작업 자재 기록'), findsOneWidget);
  });

  testWidgets('작업 이름이 없으면 단추를 안 보인다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await openSheet(tester, jobLogName: '');
    expect(find.byKey(const Key('job_material_log')), findsNothing);
  });
}
