// 프로젝트 이름에 '/' 등이 있어도 PDF 파일 이름이 경로를 깨지 않는다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_math.dart';

void main() {
  test('못 쓰는 글자는 _로', () {
    expect(safeFileName('A/B동'), 'A_B동');
    expect(safeFileName(r'a\b:c*d?e"f<g>h|i'), 'a_b_c_d_e_f_g_h_i');
    expect(safeFileName('루마 2공장'), '루마 2공장');
    expect(safeFileName('  '), '이름없음');
  });
}
