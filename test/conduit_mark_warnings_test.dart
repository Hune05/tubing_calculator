// 10-09: 전선관 입력 탭에서 넣은 첫 벤드 마킹이 관 끝보다 앞(음수)이어도 경고가 없었고,
// 90°를 넘는 옛 목록은 마킹 카드 메모에만 경고가 있었다(현장 탭·마킹지 띠에는 없음).
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';

void main() {
  final hand = {'benderType': 'hand', 'takeUp': 152.4, 'gain': 81.2, 'clr': 114.3};

  test('첫 90° 길이 120(테이크업 152.4보다 짧음)이면 "1번 마킹이 관 끝보다 32mm 앞" 경고', () {
    final w = conduitMarkWarnings([
      {'length': 120.0, 'angle': 90.0},
      {'length': 300.0, 'angle': 0.0},
    ], hand);
    expect(w, hasLength(1));
    expect(w.single, contains('1번 마킹이 관 끝보다 32mm 앞'));
    // 형상 점검 띠(conduitBendCheck)에도 같이 나온다.
    expect(
      conduitBendCheck([
        {'length': 120.0, 'angle': 90.0, 'rotation': 0.0},
        {'length': 300.0, 'angle': 0.0, 'rotation': 0.0},
      ], hand).warnings.first,
      contains('1번 마킹'),
    );
  });

  test('충분히 길면 경고 없음, 직관 뒤 벤드는 벤드 번호로 센다', () {
    expect(conduitMarkWarnings([
      {'length': 400.0, 'angle': 90.0},
      {'length': 300.0, 'angle': 0.0},
    ], hand), isEmpty);
    final w = conduitMarkWarnings([
      {'length': 50.0, 'angle': 0.0},
      {'length': 60.0, 'angle': 90.0},
    ], hand);
    expect(w.single, startsWith('1번 마킹'));
  });

  test('90°를 넘는 옛 목록은 띠 경고로 올린다', () {
    final w = conduitMarkWarnings([
      {'length': 400.0, 'angle': 135.0},
      {'length': 300.0, 'angle': 0.0},
    ], hand);
    expect(w.any((s) => s.contains('135°') && s.contains('90°를 넘는')), isTrue);
  });
}
