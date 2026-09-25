// 튜브 마킹 탭: 전선관 모양(총 절단 길이 카드 + STEP 카드)으로 바꾼 뒤에도
// 값·피팅 단추·스프링백·굴림이 그대로 나오고, 좁은 화면·가로에서 넘치지 않는지.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    MachineSpecs().update(
      radius: 38.1,
      gain90: 12.0,
      springback: 2.0,
      fittingDepth: 23.0,
      benderOffset: 0.0,
      cutMargin: 0.0,
      tail: 0.0,
      startFit: false,
      endFit: false,
    );
    MobileBendDataManager().bendList
      ..clear()
      ..addAll([
        {'length': 150.0, 'angle': 0.0, 'rotation': 0.0},
        {'length': bendSetback(38.1, 90), 'angle': 90.0, 'rotation': 0.0},
        {'length': 300.0, 'angle': 90.0, 'rotation': 360.0}, // 앞: 평면이 바뀜
        {'length': 200.0, 'angle': 0.0, 'rotation': 0.0},
      ]);
  });

  // 그리는 동안 난 오류(넘침 등)를 모은다. expect 전에 원래대로 돌려놓는다.
  Future<List<String>> collect(Future<void> Function() body) async {
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    try {
      await body();
    } finally {
      FlutterError.onError = old;
    }
    return errors;
  }

  Future<List<String>> pumpTab(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    return collect(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MobileResultTab(startDir: 'RIGHT')),
        ),
      );
      await tester.pumpAndSettle();
    });
  }

  testWidgets('총 절단 길이 카드와 STEP 카드, 마킹 값은 현장 탭과 같다', (tester) async {
    final errors = await pumpTab(tester, const Size(400, 2000));
    expect(errors, isEmpty);

    final data = computeTubeFieldData(startDir: 'RIGHT');
    expect(find.text('마킹 가이드'), findsOneWidget);
    expect(find.text('총 절단 길이'), findsOneWidget);
    expect(find.text('${data.totalCut.round()}'), findsWidgets);
    // 벤딩에만 STEP 번호(1, 2), 직관은 번호 없이.
    expect(find.text('STEP'), findsNWidgets(2));
    expect(find.text('직관 연장 마킹'), findsNWidgets(2));
    for (final b in data.bends) {
      expect(find.text('${b.position.round()}'), findsWidgets);
    }
    // 스프링백은 "실제" 각도로, 두 번째 벤드는 굴림 안내.
    expect(find.text('90° 벤딩 (실제 92.0°)'), findsNWidgets(2));
    expect(find.textContaining('굴려 물리십시오'), findsOneWidget);
    expect(find.textContaining('앞 마킹과의 거리'), findsOneWidget);
    // 저장·마킹지는 오른쪽 위 아이콘.
    expect(find.byKey(const Key('tube_save_drawing')), findsOneWidget);
    expect(find.byKey(const Key('tube_marking_sheet')), findsOneWidget);
  });

  testWidgets('피팅 시작·종료 단추를 누르면 켜지고 총 길이가 늘어난다', (tester) async {
    await pumpTab(tester, const Size(400, 2000));
    final before = computeTubeFieldData(startDir: 'RIGHT').totalCut;

    Finder check(String key) => find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byIcon(Icons.check_rounded),
    );
    expect(check('tube_start_fit'), findsNothing);
    await tester.tap(find.byKey(const Key('tube_start_fit')));
    await tester.pumpAndSettle();
    expect(MobileBendDataManager().startFit, isTrue);
    // 켜진 것을 색만이 아니라 ✓로도 보인다(햇빛 아래).
    expect(check('tube_start_fit'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tube_end_fit')));
    await tester.pumpAndSettle();
    expect(MobileBendDataManager().endFit, isTrue);

    final after = computeTubeFieldData(startDir: 'RIGHT').totalCut;
    expect(after, closeTo(before + 46, 1e-6));
    expect(find.text('${after.round()}'), findsWidgets);
    expect(find.text('직관 +150 (+피팅 23) mm'), findsOneWidget);
  });

  for (final size in const [Size(320, 640), Size(800, 360)]) {
    testWidgets('넘치지 않는다 ${size.width.toInt()}×${size.height.toInt()}', (
      tester,
    ) async {
      expect(await pumpTab(tester, size), isEmpty);
      final errors = await collect(() async {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pumpAndSettle();
      });
      expect(errors, isEmpty);
    });
  }

  testWidgets('목록이 비면 안내 글', (tester) async {
    MobileBendDataManager().bendList.clear();
    final errors = await pumpTab(tester, const Size(400, 800));
    expect(errors, isEmpty);
    expect(find.text('입력 탭에서 치수를 넣어 주십시오.'), findsOneWidget);
    expect(find.byKey(const Key('tube_marking_sheet')), findsNothing);
  });
}
