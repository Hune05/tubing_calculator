// 라벨 글 읽기: 재질 고르기(10-09).
// 예전에는 "316L"만 찾아 TP316·SS316이 빈칸이 됐고, 숫자 중간의 304(히트 번호·길이)를 SS304로 읽었다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_ocr.dart';

void main() {
  test('316L·316·304L·304를 가린다', () {
    expect(detectLabelMaterial('ASTM A269 TP316L 1/2" X 0.035'), 'SS316L');
    expect(detectLabelMaterial('SS 316 L SEAMLESS'), 'SS316L');
    expect(detectLabelMaterial('ASTM A269 TP316 SEAMLESS'), 'SS316');
    expect(detectLabelMaterial('SUS304L PIPE'), 'SS304L');
    expect(detectLabelMaterial('SS304 TUBE'), 'SS304');
  });

  test('히트 번호·길이 속의 304·316은 재질로 보지 않는다', () {
    expect(detectLabelMaterial('HEAT NO 23041 LENGTH 3048'), '');
    expect(detectLabelMaterial('HEAT 13160 TP316L'), 'SS316L');
    expect(detectLabelMaterial('LOT 30412 CARBON STEEL'), 'CARBON');
  });

  test('그 밖의 재질과 못 알아본 것', () {
    expect(detectLabelMaterial('monel 400'), 'MONEL');
    expect(detectLabelMaterial('PTFE TEFLON HOSE'), 'TEFLON');
    expect(detectLabelMaterial('NO GRADE'), '');
  });
}
