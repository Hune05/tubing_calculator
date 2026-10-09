// 10-09 남은 것 1묶음: 마킹 탭·현장 탭·마킹지가 같은 간격·번호를 보이게.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';
import 'package:tubing_calculator/src/presentation/field/marking_sheet_pdf.dart' show tapeNumberRows;

void main() {
  test('전선관: 번호는 벤드만 1번부터, 앞 마킹 간격은 앞 벤드에서 반올림한 마킹끼리', () {
    final m = calculateConduitMarkings([
      {'length': 200.0, 'angle': 0.0},
      {'length': 300.0, 'angle': 90.0},
      {'length': 400.0, 'angle': 90.0},
    ], {'benderType': 'hand', 'takeUp': 152.4, 'gain': 81.2, 'clr': 114.3});
    expect(m.map((x) => x['markNo']).toList(), [0, 1, 2]);
    final p1 = (m[1]['mark'] as num).toDouble();
    final p2 = (m[2]['mark'] as num).toDouble();
    expect(m[2]['note'], startsWith('앞 마킹 +${markGap(p2, p1).round()}mm'));
  });

  test('현장 탭 인치 간격은 누적 인치끼리 뺀 값(1/16"씩 밀리지 않는다)', () {
    const d = FieldMarkingData(
      totalCut: 400,
      marks: [
        FieldMark(number: 1, position: 100.4, angle: 90, rotation: 0, gap: 100),
        FieldMark(number: 2, position: 200.6, angle: 90, rotation: 90, gap: 101),
      ],
      inchMode: FieldInchMode.fraction,
    );
    expect(d.inch(100.4), '3 15/16"');
    expect(d.inch(200.6), '7 7/8"');
    // 누적 차 7 7/8 − 3 15/16 = 3 15/16
    expect(d.inchGap(200.6, d.previousOf(d.bends[1])), '3 15/16"');
    expect(d.inchGap(100.4, d.previousOf(d.bends[0])), '3 15/16"');
  });
  test('마킹지 번호 원: 가까우면 둘째 줄로, 멀면 첫째 줄', () {
    expect(tapeNumberRows([10, 40, 80]), [0, 0, 0]);
    expect(tapeNumberRows([10, 18, 26, 60]), [0, 1, 0, 0]);
    // 세 개가 붙으면 셋째는 첫째 줄과 15 이상 떨어졌을 때 첫째 줄
    expect(tapeNumberRows([10, 12, 14]), [0, 1, 0]);
  });
}
