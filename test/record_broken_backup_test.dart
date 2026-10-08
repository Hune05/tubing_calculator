// 압력시험·교정 기록 저장 칸이 깨져도 원문을 따로 남긴다(10-08).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_record.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_record.dart';

void main() {
  test('압력시험 기록 칸 전체가 깨지면 원문을 _broken 칸에 남긴다', () async {
    SharedPreferences.setMockInitialValues({PtRecordStore.key: '[{깨진'});
    expect(await PtRecordStore.load(), isEmpty);
    final p = await SharedPreferences.getInstance();
    expect(p.getString('${PtRecordStore.key}_broken'), '[{깨진');
  });

  test('교정 기록 한 건이 깨지면 원문을 남기고 나머지는 읽는다', () async {
    SharedPreferences.setMockInitialValues({CalRecordStore.key: '[{"id": 5, "date": "x"}]'});
    expect(await CalRecordStore.load(), isEmpty);
    final p = await SharedPreferences.getInstance();
    expect(p.getString('${CalRecordStore.key}_broken'), isNotNull);
  });
}
