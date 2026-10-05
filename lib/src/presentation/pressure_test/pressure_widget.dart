// 홈 화면 "압력시험" 위젯에 넘길 값. 앱의 시험 기록 탭이 진행 중인 유지시간 타이머를 그대로 보여 주려고
// 시작·완료 시각을 JSON으로 만든다(위젯은 통신 없이 이 값으로 남은 시간을 스스로 센다).
// phase: running(유지 중) / ended(시험 종료) / idle(시험 전). 완료 시각이 지난 running은 위젯이 "유지시간 완료"로 그린다.
library;

import 'dart:convert';

String encodePressureWidgetPayload({
  required bool running,
  DateTime? start,
  DateTime? end,
  DateTime? due,
  required String line,
  required double holdMin,
}) {
  final String phase = running
      ? 'running'
      : (start != null && end != null ? 'ended' : 'idle');
  return jsonEncode({
    'phase': phase,
    'line': line.trim(),
    'holdMin': (holdMin * 10).round() / 10,
    if (phase != 'idle' && start != null)
      'startMs': start.millisecondsSinceEpoch,
    if (phase == 'running' && due != null) 'dueMs': due.millisecondsSinceEpoch,
    if (phase == 'ended' && end != null) 'endMs': end.millisecondsSinceEpoch,
  });
}
