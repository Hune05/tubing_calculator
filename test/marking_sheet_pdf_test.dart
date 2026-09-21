// 벤딩 마킹지(PDF) 검사.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_field_data.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';
import 'package:tubing_calculator/src/presentation/field/marking_sheet_pdf.dart';

const data = FieldMarkingData(
  totalCut: 616,
  marks: [
    FieldMark(number: 0, position: 150, angle: 0, rotation: 0),
    FieldMark(
      number: 1,
      position: 163,
      angle: 21,
      targetAngle: 24,
      rotation: 0,
      gap: 163,
    ),
    FieldMark(
      number: 2,
      position: 358,
      angle: 21,
      targetAngle: 24,
      rotation: 180,
      gap: 195,
      roll: 30,
    ),
  ],
  warnings: ['3번 구간: 곧은 부분이 -10mm입니다. 이대로는 만들 수 없습니다.'],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('줄자 숫자 간격은 12개 안쪽', () {
    expect(tapeLabelStep(616), 100);
    expect(tapeLabelStep(2400), 200);
    expect(tapeLabelStep(6000), 500);
    expect(tapeLabelStep(12000), 1000);
  });

  test('PDF가 만들어진다(한글 글꼴·표·줄자·경고)', () async {
    final bytes = await buildMarkingSheetPdf(
      title: '전선관 벤딩 마킹지',
      data: data,
      specs: const [('테이크업(90°)', '152.4 mm'), ('게인(90°)', '82.5 mm')],
      inputs: const [
        {'length': 150.0, 'angle': 0.0, 'rotation': 0.0},
        {'length': 72.3, 'angle': 21.0, 'rotation': 0.0},
        {'length': 195.3, 'angle': 21.0, 'rotation': 180.0},
      ],
      date: DateTime(2026, 9, 21),
    );
    expect(bytes.length, greaterThan(10000));
    expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
  });

  test('관이 6m여도 한 장에 만들어진다', () async {
    final long = FieldMarkingData(
      totalCut: 6000,
      marks: [
        for (var i = 0; i < 20; i++)
          FieldMark(
            number: i + 1,
            position: 200.0 + i * 280,
            angle: 45,
            rotation: 0,
          ),
      ],
    );
    final bytes = await buildMarkingSheetPdf(
      title: '튜브 벤딩 마킹지',
      data: long,
      specs: const [],
      inputs: const [],
    );
    expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
  });

  test('전선관 제원 글', () {
    final defaults = Map<String, dynamic>.from(globalBenderSettings.value);
    conduitUseCoupling.value = true;
    final specs = conduitMarkingSheetSpecs({
      ...defaults,
      'benderType': 'hand',
      'takeUp': 152.4,
      'gain': 82.5,
    });
    conduitUseCoupling.value = false;
    final map = {for (final (k, v) in specs) k: v};
    expect(map['테이크업(90°)'], '152.4 mm');
    expect(map['게인(90°)'], '82.5 mm');
    expect(map['커플링'], '체결 · 끝 여유 50 mm');
    expect(map['벤더'], contains('수동'));

    final ram = conduitMarkingSheetSpecs({
      ...defaults,
      'benderType': 'ram',
      'setback': 40.0,
    });
    final ramMap = {for (final (k, v) in ram) k: v};
    expect(ramMap.containsKey('셋백(90°)'), isTrue);
    expect(ramMap.containsKey('테이크업(90°)'), isFalse);
  });
}
