// 벤딩 화면 작은 고침(점검 38번): 아이소 시작 방향 따라가기, 새들 한 번에 넣기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_pipe_visualizer.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_saddle_bottom_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    MachineSpecs().update(radius: 38.1);
  });

  testWidgets('아이소: 불러온 도면의 시작 방향이 바뀌면 따라간다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Widget view(String dir) => MaterialApp(
      home: Scaffold(
        body: MobilePipeVisualizer(
          bendList: const [],
          initialStartDir: dir,
          useSavedDirection: false,
        ),
      ),
    );
    String shown() => tester
        .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
        .value!;
    await tester.pumpWidget(view('RIGHT'));
    await tester.pump();
    expect(shown(), 'RIGHT');
    await tester.pumpWidget(view('UP')); // 보관함에서 다른 방향 도면을 불러옴
    await tester.pump();
    // 예전: 처음 방향(RIGHT)에 머물렀다.
    expect(shown(), 'UP');
  });

  testWidgets('새들 3점: 세 줄을 한 번에 넣는다(되돌리기 한 번)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final batches = <List<Map<String, double>>>[];
    var singles = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobileSaddleBottomSheet(
            currentRotation: 0,
            onAddBend: (_, _, _) => singles++,
            onAddBends: batches.add,
            specs: BendSheetSpecs(
              radius: 38.1,
              gain90: 0,
              markOffset: (a) => bendSetback(38.1, a),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 칸을 누르면 숫자판이 떠서 그 위를 덮으므로, 글만 바로 넣는다.
    tester.widget<TextField>(find.byType(TextField).first).controller!.text =
        '300';
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('RIGHT').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('RIGHT').first);
    await tester.pumpAndSettle();
    final apply = find.text('목록에 넣기').first;
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    // 짧아서 물림 경고가 뜨면 "그래도 넣기"
    if (find.text('슈 간섭 경고').evaluate().isNotEmpty) {
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();
    }
    expect(singles, 0);
    expect(batches.single.length, 3);
    expect(batches.single[1]['rotation'], 270.0); // 가운데는 반대 방향
  });

  testWidgets('F3 새들: 높이가 비면 말없이 넘어가지 않고 알린다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final batches = <List<Map<String, double>>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobileSaddleBottomSheet(
            currentRotation: 0,
            onAddBend: (_, _, _) {},
            onAddBends: batches.add,
            specs: BendSheetSpecs(
              radius: 38.1,
              gain90: 0,
              markOffset: (a) => bendSetback(38.1, a),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final f in tester.widgetList<TextField>(find.byType(TextField))) {
      f.controller!.text = '';
    }
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('RIGHT').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('RIGHT').first);
    await tester.pumpAndSettle();
    final apply = find.text('목록에 넣기').first;
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pump();
    expect(batches, isEmpty);
    expect(find.byKey(const Key('saddle_missing')), findsOneWidget);
  });
}
