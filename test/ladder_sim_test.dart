// 시퀀스 회로 동작: 자기유지, 정지, 과부하, 정역 인터록, Y-Δ 전환.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/ladder_sim.dart';

void main() {
  test('직입: 기동을 눌렀다 떼도 자기유지, 정지·과부하로 떨어진다', () {
    var s = solve(kDolCircuit, {});
    expect(s['MC'], false);
    expect(s['GL'], true);
    final (pressed, released) = pressButton(kDolCircuit, s, 'PB1');
    expect(pressed['MC'], true);
    expect(released['MC'], true, reason: '13-14 자기유지');
    expect(released['RL'], true);
    expect(released['GL'], false);
    expect(describeChanges(kDolCircuit, s, released), [
      'MC 코일 여자',
      '운전등 RL 켜짐',
      '정지등 GL 꺼짐',
    ]);
    s = released;
    s = pressButton(kDolCircuit, s, 'PB0').$2;
    expect(s['MC'], false);
    s = pressButton(kDolCircuit, s, 'PB1').$2;
    s = solve(kDolCircuit, {...s, 'OL': true});
    expect(s['MC'], false, reason: '과부하 95-96 열림');
    s = pressButton(kDolCircuit, s, 'PB1').$2;
    expect(s['MC'], false, reason: '과부하 복귀 전에는 기동 안 됨');
  });

  test('정역: 한쪽이 돌면 반대쪽은 눌러도 안 붙는다', () {
    var s = pressButton(kFwdRevCircuit, {}, 'PBF').$2;
    expect(s['MCF'], true);
    s = pressButton(kFwdRevCircuit, s, 'PBR').$2;
    expect(s['MCR'], false, reason: 'MCF 21-22 인터록');
    expect(s['MCF'], true);
    s = pressButton(kFwdRevCircuit, s, 'PB0').$2;
    s = pressButton(kFwdRevCircuit, s, 'PBR').$2;
    expect(s['MCR'], true);
    expect(s['MCF'], false);
  });

  test('Y-Δ: 기동하면 M·Y·타이머, 시간 다 되면 Y 떨어지고 Δ 자기유지', () {
    var s = pressButton(kStarDeltaCircuit, {}, 'PB1').$2;
    expect(s['MCM'], true);
    expect(s['MCY'], true);
    expect(s['T'], true);
    expect(s['MCD'], false);
    final before = s;
    s = solve(kStarDeltaCircuit, {...s, 'T.done': true});
    expect(s['MCY'], false);
    expect(s['MCD'], true);
    expect(s['T'], false, reason: 'MC-Δ 21-22로 타이머 복귀');
    expect(s['T.done'], false);
    expect(s['MCM'], true);
    final ch = describeChanges(kStarDeltaCircuit, before, s);
    expect(ch, contains('MC-Y 코일 소자'));
    expect(ch, contains('MC-Δ 코일 여자'));
    s = pressButton(kStarDeltaCircuit, s, 'PB0').$2;
    expect(s['MCM'], false);
    expect(s['MCD'], false);
    expect(s['MCY'], false);
  });
}
