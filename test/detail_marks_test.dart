// 보관함 "도면 보기": 입력 값만 저장된 도면이어도 마킹이 0으로 나오지 않고
// 마킹 탭과 같은 값이 나오는지. 전선관 모양(총 절단 길이 카드·STEP 카드).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/common_widgets/smart_save_pad.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/data/tube_drawing_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/mobile_fabrication_detail_screen.dart';

void main() {
  final bends = [
    {'length': 150.0, 'angle': 0.0, 'rotation': 0.0},
    {'length': bendSetback(38.1, 90), 'angle': 90.0, 'rotation': 0.0},
    {'length': 300.0, 'angle': 90.0, 'rotation': 360.0},
    {'length': 200.0, 'angle': 0.0, 'rotation': 0.0},
  ];

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
      startFit: true,
      endFit: false,
    );
  });

  Map<String, dynamic> saved(
    List<Map<String, dynamic>> list, {
    Map<String, double>? specs,
  }) => {
    'id': 7,
    'date': '2026-09-21 10:00',
    'pipe_size': '1/2"',
    'total_length': 700.0,
    'p_to_p': jsonEncode({
      'project': 'TEST',
      'from': 'A',
      'to': 'B',
      'start_fit': true,
      'end_fit': false,
      'tail': 0.0,
      'start_dir': 'RIGHT',
      'specs': ?specs,
    }),
    'bend_data': jsonEncode(list),
  };

  testWidgets('입력 값만 있는 도면도 마킹 탭과 같은 마킹이 나온다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: MobileFabricationDetailScreen(itemData: saved(bends))),
    );
    await tester.pumpAndSettle();

    // 머리·총 절단 길이 카드(영어 이름 없이).
    expect(find.text('총 절단 길이'), findsOneWidget);
    expect(find.text('규격'), findsOneWidget);
    expect(find.text('시작'), findsOneWidget);
    expect(find.textContaining('Total Cut'), findsNothing);

    await tester.tap(find.text('마킹 가이드'));
    await tester.pumpAndSettle();

    // 같은 목록을 마킹 탭 셈으로.
    MobileBendDataManager().bendList
      ..clear()
      ..addAll([for (final b in bends) Map<String, dynamic>.from(b)]);
    final data = computeTubeFieldData(startDir: 'RIGHT');
    expect(data.bends.length, 2);
    for (final b in data.bends) {
      expect(find.text('${b.position.round()}'), findsWidgets);
    }
    expect(find.text('0'), findsNothing);
    expect(find.text('STEP'), findsNWidgets(2));
    expect(find.text('90° 벤딩 (실제 92.0°)'), findsNWidgets(2));
    expect(find.textContaining('지금 장비 설정(반경 38mm)'), findsOneWidget);
  });

  testWidgets('예전처럼 마킹 값이 저장된 도면은 저장된 값을 쓴다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final old = [
      {'length': 150.0, 'angle': 0.0, 'rotation': 0.0, 'marking_point': 150.0},
      {
        'length': 100.0,
        'angle': 90.0,
        'rotation': 0.0,
        'marking_point': 321.0,
        'mark_num': 1,
      },
      {'length': 200.0, 'angle': 0.0, 'rotation': 0.0, 'marking_point': 500.0},
    ];
    await tester.pumpWidget(
      MaterialApp(home: MobileFabricationDetailScreen(itemData: saved(old))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('마킹 가이드'));
    await tester.pumpAndSettle();
    expect(find.text('321'), findsOneWidget);
    expect(find.textContaining('지금 장비 설정'), findsNothing);
  });

  testWidgets('저장할 때 장비 값으로 셈하고, 지금 설정과 다르면 알린다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // 저장할 때(게인 12)의 마킹
    MobileBendDataManager().bendList
      ..clear()
      ..addAll([for (final b in bends) Map<String, dynamic>.from(b)]);
    final atSave = computeTubeFieldData(startDir: 'RIGHT');
    final specs = tubeSpecsSnapshot(MachineSpecs());

    // 그사이 설정을 바꿈(게인 20, 반경 50)
    MachineSpecs().update(gain90: 20.0, radius: 50.0);
    MobileBendDataManager().bendList
      ..clear()
      ..addAll([for (final b in bends) Map<String, dynamic>.from(b)]);
    final now = computeTubeFieldData(startDir: 'RIGHT');
    expect(
      now.bends.last.position.round(),
      isNot(atSave.bends.last.position.round()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MobileFabricationDetailScreen(
          itemData: saved(bends, specs: specs),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('마킹 가이드'));
    await tester.pumpAndSettle();
    for (final b in atSave.bends) {
      expect(find.text('${b.position.round()}'), findsWidgets);
    }
    expect(find.text('${now.bends.last.position.round()}'), findsNothing);
    expect(find.textContaining('저장할 때 장비 값(반경 38.1 · 게인 12'), findsOneWidget);
    expect(find.textContaining('다릅니다'), findsOneWidget);
  });

  testWidgets('저장할 때와 설정이 같으면 안내를 띄우지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MobileFabricationDetailScreen(
          itemData: saved(bends, specs: tubeSpecsSnapshot(MachineSpecs())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('마킹 가이드'));
    await tester.pumpAndSettle();
    expect(find.textContaining('장비 설정'), findsNothing);
    expect(find.textContaining('다릅니다'), findsNothing);
  });

  group('도면 저장 창', () {
    test('설정의 관 지름에 맞는 규격 칩을 고른다', () {
      const chips = ['1/4"', '3/8"', '1/2"', '8mm', '25mm'];
      expect(sizeChipForOd(12.7, chips), '1/2"');
      expect(sizeChipForOd(6.35, chips), '1/4"');
      expect(sizeChipForOd(25.0, chips), '25mm');
      expect(sizeChipForOd(6.0, chips), isNull);
      // 예전 도면(장비 값 없음)
      expect(savedTubeSpecs({'project': 'A'}), isNull);
    });

    testWidgets('설정이 3/8"이면 3/8"이 먼저 골라져 있다(예전엔 늘 1/2")', (tester) async {
      final c = AppSettingsController();
      final oldOd = c.tubeOD, oldInch = c.isInch;
      addTearDown(() {
        c.tubeOD = oldOd;
        c.isInch = oldInch;
      });
      c.isInch = false;
      c.tubeOD = 9.525;
      await tester.binding.setSurfaceSize(const Size(420, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SmartSavePad(
              totalCut: 700,
              bendList: [],
              includeStart: false,
              includeEnd: false,
              tailLength: 0,
              startDir: 'RIGHT',
            ),
          ),
        ),
      );
      bool sel(String label) => tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
          .selected;
      expect(sel('3/8"'), isTrue);
      expect(sel('1/2"'), isFalse);

      // 목록에 없는 6mm는 칩을 하나 더 만들어 고른다.
      c.tubeOD = 6.0;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SmartSavePad(
              totalCut: 700,
              bendList: [],
              includeStart: false,
              includeEnd: false,
              tailLength: 0,
              startDir: 'RIGHT',
            ),
          ),
        ),
      );
      expect(sel('6mm'), isTrue);
    });
  });
}
