// 저장 → 되돌리기 왕복: 자재 사용량(재고 차감용)이 제자리로 돌아와야 한다.
// 예전에는 되돌리기가 규격 없이 전체 길이(톱날 손실 포함)를 첫 튜브 줄에서만
// 빼서 다른 규격 줄이 남고, 톱날 손실만큼 더 빠졌다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_firestore_helper.dart';

CutRecord rec(String size, double cut, {int sets = 1}) => CutRecord(
  id: '',
  projectId: 'p',
  timestamp: DateTime(2026, 9, 22),
  tubeSize: size,
  originalLength: cut,
  startFitting: '',
  endFitting: '',
  cutLength: cut,
  multiplier: sets,
);

List<Map<String, dynamic>> roundTrip(
  List<dynamic> before,
  List<CutRecord> records,
  double totalWithKerf,
) {
  final by = tubeUsageBySize(records);
  final saved = mergeMaterialsUsage(
    before,
    totalWithKerf,
    const [],
    tubeLengthBySize: by,
  );
  return subtractMaterialsUsage(
    saved,
    totalWithKerf,
    const [],
    tubeLengthBySize: by,
  );
}

void main() {
  test('규격별로 모은다(세트 수 곱함)', () {
    expect(
      tubeUsageBySize([
        rec('1/2"', 1000),
        rec('3/8"', 2000, sets: 2),
        rec('1/2"', 500),
      ]),
      {'1/2"': 1500.0, '3/8"': 4000.0},
    );
  });

  test('규격 두 개 + 톱날 손실: 되돌리면 빈 목록', () {
    final after = roundTrip(const [], [
      rec('1/2"', 1000),
      rec('3/8"', 2000),
    ], 3006);
    expect(after, isEmpty);
  });

  test('앞서 쌓인 5000이 있으면 되돌린 뒤 5000 그대로', () {
    final before = [
      {'db_name': tubeMaterialName('1/2"'), 'type': 'TUBE', 'qty_mm': 5000.0},
    ];
    final after = roundTrip(before, [rec('1/2"', 1000)], 1003);
    expect(after, hasLength(1));
    expect(after.first['qty_mm'], closeTo(5000, 1e-9));
  });
}
