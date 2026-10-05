// 압력시험 위젯에 넘기는 값 시험.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_widget.dart';

Map<String, dynamic> _dec(String s) => jsonDecode(s) as Map<String, dynamic>;

void main() {
  final start = DateTime(2026, 10, 5, 10, 15);
  final due = DateTime(2026, 10, 5, 10, 45);
  final end = DateTime(2026, 10, 5, 10, 47);

  test('유지 중: 시작·완료 시각과 라인 번호·유지시간을 넘긴다', () {
    final j = _dec(
      encodePressureWidgetPayload(
        running: true,
        start: start,
        due: due,
        line: ' L-101 ',
        holdMin: 30,
      ),
    );
    expect(j['phase'], 'running');
    expect(j['line'], 'L-101');
    expect(j['holdMin'], 30.0);
    expect(j['startMs'], start.millisecondsSinceEpoch);
    expect(j['dueMs'], due.millisecondsSinceEpoch);
    expect(j.containsKey('endMs'), isFalse);
  });

  test('종료: 종료 시각을 넘기고 완료 시각은 뺀다', () {
    final j = _dec(
      encodePressureWidgetPayload(
        running: false,
        start: start,
        end: end,
        due: due,
        line: '',
        holdMin: 7.5,
      ),
    );
    expect(j['phase'], 'ended');
    expect(j['holdMin'], 7.5);
    expect(j['endMs'], end.millisecondsSinceEpoch);
    expect(j.containsKey('dueMs'), isFalse);
  });

  test('시작 전: 시각을 하나도 안 넘긴다', () {
    final j = _dec(
      encodePressureWidgetPayload(running: false, line: '', holdMin: 10),
    );
    expect(j['phase'], 'idle');
    expect(j.containsKey('startMs'), isFalse);
    expect(j.containsKey('dueMs'), isFalse);
  });
}
