// 마킹지 PDF 실측 표(10-18): 실측이 있을 때·없을 때 모두 만들어지는지.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';
import 'package:tubing_calculator/src/presentation/field/marking_sheet_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const data = FieldMarkingData(
    totalCut: 1000,
    marks: [
      FieldMark(number: 1, position: 462, angle: 90, rotation: 0, leg: 500),
      FieldMark(number: 2, position: 746, angle: 90, rotation: 360, gap: 284, leg: 300),
    ],
  );
  for (final withMeasure in [false, true]) {
    test('실측 ${withMeasure ? '있음' : '없음'}', () async {
      final bytes = await buildMarkingSheetPdf(
        title: '튜브 벤딩 마킹지',
        data: data,
        specs: const [('반경', '38.1')],
        inputs: const [],
        measured: withMeasure ? const {0: 3, 2: -1} : const {},
        angles: withMeasure ? const {1: 92.5} : const {},
      );
      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(1000));
    });
  }
}
