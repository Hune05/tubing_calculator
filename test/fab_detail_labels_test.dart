// 도면 상세 화면·작업지시서 PDF의 방향·각도 글(10-08).
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/mobile_fabrication_detail_screen.dart';

void main() {
  test('방향 값은 화면 카드와 같은 말(FRONT·BACK이 UP·RIGHT로 섞이지 않는다)', () {
    expect(fabDirectionLabel(0), 'UP');
    expect(fabDirectionLabel(90), 'RIGHT');
    expect(fabDirectionLabel(180), 'DOWN');
    expect(fabDirectionLabel(270), 'LEFT');
    expect(fabDirectionLabel(360), 'FRONT');
    expect(fabDirectionLabel(450), 'BACK');
  });

  test('반 각도는 소수 한 자리로(22.5가 23으로 바뀌지 않는다)', () {
    expect(fabAngleText(22.5), '22.5');
    expect(fabAngleText(90), '90');
  });

  test("PDF 각도 칸에 스프링백을 얹은 꺾을 각도를 같이 적는다(10-09)", () {
    expect(fabAngleCell(90, 93), "90° (실제 93.0°)");
    expect(fabAngleCell(22.5, 24.5), "22.5° (실제 24.5°)");
    expect(fabAngleCell(45, 45), "45°");
    expect(fabAngleCell(45, null), "45°");
  });
}

