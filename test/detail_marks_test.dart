// 보관함 "도면 보기": 입력 값만 저장된 도면이어도 마킹이 0으로 나오지 않고
// 마킹 탭과 같은 값이 나오는지. 전선관 모양(총 절단 길이 카드·STEP 카드).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
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

  Map<String, dynamic> saved(List<Map<String, dynamic>> list) => {
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
}
