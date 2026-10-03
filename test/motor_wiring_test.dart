// 3상 모터 결선 접속표: 조사한 표와 같고, 모든 단자가 정확히 한 번씩 쓰이는지로 스스로 점검한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/motor_wiring.dart';

void main() {
  final all = [...kWiring6, ...kWiring9, ...kWiring12];

  test('모든 결선: 단자 1..N이 전원 또는 점퍼에 정확히 한 번씩만 쓰인다', () {
    for (final w in all) {
      final used = [...w.usedTerminals]..sort();
      expect(used, [for (var i = 1; i <= w.terminals; i++) i], reason: w.id);
    }
  });

  test('전원선 L1·L2·L3에 물리는 단자 수가 같다', () {
    for (final w in all) {
      expect(w.l1.length, w.l2.length, reason: w.id);
      expect(w.l2.length, w.l3.length, reason: w.id);
    }
  });

  test('결선 수: 6단자 2, 9단자 4, 12단자 4', () {
    expect(kWiring6.length, 2);
    expect(kWiring9.length, 4);
    expect(kWiring12.length, 4);
    expect(wiringsFor(9), same(kWiring9));
    expect(wiringsFor(7), isEmpty);
  });

  MotorWiring byId(String id) => all.firstWhere((w) => w.id == id);

  test('6단자: Y는 4·5·6 묶음, Δ는 U-Z·V-X·W-Y(1+6, 2+4, 3+5)', () {
    final y = byId('y6');
    expect([y.l1, y.l2, y.l3], [[1], [2], [3]]);
    expect(y.joins, [[4, 5, 6]]);
    final d = byId('d6');
    expect([d.l1, d.l2, d.l3], [[1, 6], [2, 4], [3, 5]]);
    expect(d.joins, isEmpty);
    expect(kLabels6[4], ('X', 'U2'));
    expect(kLabels6[6], ('Z', 'W2'));
  });

  test('9단자 표(EASA·Electric Motor Warehouse·AEMC·BCcampus 일치)', () {
    final yl = byId('y9_low');
    expect([yl.l1, yl.l2, yl.l3], [[1, 7], [2, 8], [3, 9]]);
    expect(yl.joins, [[4, 5, 6]]);
    final yh = byId('y9_high');
    expect([yh.l1, yh.l2, yh.l3], [[1], [2], [3]]);
    expect(yh.joins, [[4, 7], [5, 8], [6, 9]]);
    final dl = byId('d9_low');
    expect([dl.l1, dl.l2, dl.l3], [[1, 6, 7], [2, 4, 8], [3, 5, 9]]);
    expect(dl.joins, isEmpty);
    final dh = byId('d9_high');
    expect(dh.joins, [[4, 7], [5, 8], [6, 9]]);
  });

  test('12단자 표', () {
    final yh = byId('y12_high');
    expect([yh.l1, yh.l2, yh.l3], [[1], [2], [3]]);
    expect(yh.joins, [[4, 7], [5, 8], [6, 9], [10, 11, 12]]);
    final yl = byId('y12_low');
    expect([yl.l1, yl.l2, yl.l3], [[1, 7], [2, 8], [3, 9]]);
    expect(yl.joins, [[4, 5, 6], [10, 11, 12]]);
    final dh = byId('d12_high');
    expect([dh.l1, dh.l2, dh.l3], [[1, 12], [2, 10], [3, 11]]);
    expect(dh.joins, [[4, 7], [5, 8], [6, 9]]);
    final dl = byId('d12_low');
    expect([dl.l1, dl.l2, dl.l3], [[1, 6, 7, 12], [2, 4, 8, 10], [3, 5, 9, 11]]);
    expect(dl.joins, isEmpty);
  });

  test('저전압(병렬)은 전원 단자가 고전압(직렬)의 두 배다', () {
    expect(byId('y9_low').l1.length, 2 * byId('y9_high').l1.length);
    expect(byId('y12_low').l1.length, 2 * byId('y12_high').l1.length);
    expect(byId('d12_low').l1.length, 2 * byId('d12_high').l1.length);
  });
}
