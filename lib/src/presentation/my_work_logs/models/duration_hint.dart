import 'project_phase.dart';
import 'report_tools.dart' show reportDateOf;

// 🚀 완료한 프로젝트의 기간으로, 새 프로젝트를 만들 때 "이 유형은 보통 며칠 걸렸는지" 참고를 보여 준다.
// 결과 정리 모아보기와 같은 계산을 쓴다(test/duration_hint_test.dart 가 지킨다).

/// 계획 기간(시작~납기, 일수). 시작이나 납기가 없으면 null.
int? plannedDaysOf(Map<String, dynamic> log) {
  final s = projectStart(log), e = projectDue(log);
  return (s != null && e != null) ? e.difference(s).inDays + 1 : null;
}

/// 실제 작업 기간(첫 작업 일지 ~ 완료일 또는 마지막 작업 일지, 일수). 작업 일지가 없으면 null.
int? actualDaysOf(Map<String, dynamic> log) {
  final dates = [
    for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>())
      reportDateOf(r),
  ]..sort();
  if (dates.isEmpty) return null;
  final end = log['completedAt'] != null
      ? dayOnly(asDate(log['completedAt']))
      : dates.last;
  return end.difference(dates.first).inDays + 1;
}

class DurationHint {
  final int count; // 참고한 완료 프로젝트 수
  final int avgActual; // 실제 평균 일수
  final int? avgPlanned; // 계획 평균 일수(계획이 있는 것만)
  const DurationHint(this.count, this.avgActual, this.avgPlanned);
}

/// [workType]으로 완료한 프로젝트들의 실제 평균 기간. 참고할 것이 없으면 null.
DurationHint? durationHintFor(
  List<Map<String, dynamic>> logs,
  String workType,
) {
  final done = logs.where(
    (l) =>
        l['status'] == 'DONE' && (l['workType']?.toString() ?? '') == workType,
  );
  final actuals = <int>[];
  final planned = <int>[];
  for (final l in done) {
    final a = actualDaysOf(l);
    if (a == null || a <= 0) continue;
    actuals.add(a);
    final p = plannedDaysOf(l);
    if (p != null && p > 0) planned.add(p);
  }
  if (actuals.isEmpty) return null;
  int avg(List<int> v) => (v.fold<int>(0, (a, b) => a + b) / v.length).round();
  return DurationHint(
    actuals.length,
    avg(actuals),
    planned.isEmpty ? null : avg(planned),
  );
}

/// 화면에 보여 줄 한 줄.
String durationHintText(DurationHint h) =>
    '이 유형은 완료한 ${h.count}건이 평균 ${h.avgActual}일 걸렸습니다'
    '${h.avgPlanned == null ? '' : '(계획 평균 ${h.avgPlanned}일)'}.';
