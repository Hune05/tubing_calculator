import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/painting.dart' show Color;

// 🚀 프로젝트마다 고정된 색(같은 프로젝트는 언제나 같은 색) - 프로젝트 목록,
// 내 일정 관리 달력/타임라인이 같은 색을 쓰도록 한 곳에 둔다.
const List<Color> kProjectPalette = [
  Color(0xFF2F80ED),
  Color(0xFFE0432B),
  Color(0xFF1D8A4E),
  Color(0xFF8E63CE),
  Color(0xFFC77700),
  Color(0xFF0E9AA7),
  Color(0xFFD6336C),
  Color(0xFF5C6BC0),
];

Color colorForProject(String projectId) {
  int h = 0;
  for (final c in projectId.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return kProjectPalette[h % kProjectPalette.length];
}

// 🚀 [프로젝트 단계 관리] 프로젝트(my_projects 문서)에 phases[] 를 추가하고,
// 각 일정(schedules[])이 phaseId로 어느 단계에 속하는지 가리킨다. 화면들은
// 프로젝트를 Map으로 주고받으므로 이 파일은 그 Map을 다루는 순수 함수만
// 모았다(저장은 기존 WorkProjectRepository.upsertProject 그대로).
//
// phase: { id, name, startDate, endDate, isCompleted }  (순서 = 리스트 순서)

// 공사 유형(프로젝트 태그): 회고/통계를 유형별로 묶어 보기 위한 분류.
// 목록에 없는 유형은 직접 입력할 수 있다.
const List<String> kProjectTypes = ['배관 신설', '튜빙 시공', '계장/결선', '보수·개조', '기타'];

const List<String> kStandardPhaseNames = [
  '설계',
  '자재 입고',
  '제작',
  '설치',
  '시운전·검사',
  '납품',
];

// 표준 단계에 기간을 자동으로 나눌 때 쓰는 상대 비중.
const List<double> kStandardPhaseWeights = [1, 1.5, 3, 3, 1, 0.5];

DateTime asDate(dynamic v) {
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

List<Map<String, dynamic>> phasesOf(Map<String, dynamic> log) {
  final raw = log['phases'];
  if (raw is! List) return [];
  return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

void setPhases(Map<String, dynamic> log, List<Map<String, dynamic>> phases) {
  log['phases'] = phases;
}

List<Map<String, dynamic>> schedulesOf(Map<String, dynamic> log) {
  final raw = log['schedules'];
  if (raw is! List) return [];
  return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

String newPhaseId() => 'ph_${DateTime.now().microsecondsSinceEpoch}';

Map<String, dynamic> makePhase(
  String name, {
  DateTime? start,
  DateTime? end,
  String? id,
}) => {
  'id': id ?? newPhaseId(),
  'name': name,
  'startDate': start,
  'endDate': end,
  'isCompleted': false,
};

DateTime? phaseStart(Map<String, dynamic> p) =>
    p['startDate'] == null ? null : dayOnly(asDate(p['startDate']));
DateTime? phaseEnd(Map<String, dynamic> p) =>
    p['endDate'] == null ? null : dayOnly(asDate(p['endDate']));

List<Map<String, dynamic>> schedulesInPhase(
  Map<String, dynamic> log,
  String? phaseId,
) {
  return schedulesOf(log).where((s) {
    final pid = s['phaseId']?.toString();
    if (phaseId == null) return pid == null || pid.isEmpty;
    return pid == phaseId;
  }).toList();
}

// 단계 진행률(0~1): 세부 일정이 있으면 완료 비율, 없으면 수동 완료 여부.
// 수동으로 "완료" 표시한 단계는 세부 일정이 남아 있어도 100%로 본다.
double phaseProgress(Map<String, dynamic> log, Map<String, dynamic> phase) {
  if (phase['isCompleted'] == true) return 1.0;
  final items = schedulesInPhase(log, phase['id']?.toString());
  if (items.isEmpty) return 0.0;
  final done = items.where((s) => s['isCompleted'] == true).length;
  return done / items.length;
}

bool phaseIsDone(Map<String, dynamic> log, Map<String, dynamic> phase) =>
    phaseProgress(log, phase) >= 1.0;

// 전체 진행률: 단계별 진행률의 평균. 단계가 없으면 일정 완료 비율.
double projectProgress(Map<String, dynamic> log) {
  final phases = phasesOf(log);
  if (phases.isEmpty) {
    final all = schedulesOf(log);
    if (all.isEmpty) return (log['progress'] ?? 0.0).toDouble();
    return all.where((s) => s['isCompleted'] == true).length / all.length;
  }
  final sum = phases.fold<double>(0, (a, p) => a + phaseProgress(log, p));
  return sum / phases.length;
}

// 지금 진행 중인 단계: 완료되지 않은 첫 단계(오늘이 속한 단계를 우선).
Map<String, dynamic>? currentPhase(Map<String, dynamic> log) {
  final phases = phasesOf(log);
  final today = dayOnly(DateTime.now());
  for (final p in phases) {
    final s = phaseStart(p), e = phaseEnd(p);
    if (!phaseIsDone(log, p) &&
        s != null &&
        e != null &&
        !today.isBefore(s) &&
        !today.isAfter(e)) {
      return p;
    }
  }
  for (final p in phases) {
    if (!phaseIsDone(log, p)) return p;
  }
  return null;
}

// 프로젝트 종료(납기) 예정일: 단계 종료일 중 가장 늦은 날, 없으면 납기일
// 일정 중 가장 늦은 날.
DateTime? projectDue(Map<String, dynamic> log) {
  DateTime? due;
  for (final p in phasesOf(log)) {
    final e = phaseEnd(p);
    if (e != null && (due == null || e.isAfter(due))) due = e;
  }
  if (due != null) return due;
  for (final s in schedulesOf(log)) {
    if (s['type'] == '납기일' && s['dateTime'] != null) {
      final d = dayOnly(asDate(s['dateTime']));
      if (due == null || d.isAfter(due)) due = d;
    }
  }
  return due;
}

DateTime? projectStart(Map<String, dynamic> log) {
  DateTime? st;
  for (final p in phasesOf(log)) {
    final s = phaseStart(p);
    if (s != null && (st == null || s.isBefore(st))) st = s;
  }
  return st;
}

int unresolvedIssueCount(Map<String, dynamic> log) =>
    (log['punch_lists'] as List? ?? [])
        .where((p) => p is Map && p['is_completed'] != true)
        .length;

// 시작~종료 기간을 표준 단계 비중대로 나눠 단계 리스트를 만든다.
List<Map<String, dynamic>> buildStandardPhases(DateTime start, DateTime end) =>
    buildPhasesFromWeights(
      kStandardPhaseNames,
      kStandardPhaseWeights,
      start,
      end,
    );

List<Map<String, dynamic>> buildPhasesFromWeights(
  List<String> names,
  List<double> weights,
  DateTime start,
  DateTime end,
) {
  final s = dayOnly(start);
  final e = dayOnly(end.isBefore(s) ? s : end);
  final int total = e.difference(s).inDays + 1;
  final double weightSum = weights.fold(0.0, (a, b) => a + b);
  final List<Map<String, dynamic>> result = [];
  double cursor = 0;
  for (int i = 0; i < names.length; i++) {
    final double span = total * weights[i] / weightSum;
    final int startOffset = cursor.round();
    cursor += span;
    int endOffset = cursor.round() - 1;
    if (endOffset < startOffset) endOffset = startOffset;
    if (endOffset > total - 1) endOffset = total - 1;
    result.add(
      makePhase(
        names[i],
        start: s.add(Duration(days: startOffset)),
        end: s.add(Duration(days: endOffset)),
      ),
    );
  }
  return result;
}

// 기존(단계 없는) 프로젝트를 새 구조로 옮긴다. 일정 종류를 표준 단계에
// 대응시켜, 실제로 일정이 있는 단계만 만들고 각 단계 기간은 소속 일정들의
// 최소~최대 날짜로 잡는다. 이미 옮겼거나 phases가 있으면 아무것도 안 한다.
// 바뀌었으면 true.
bool migrateProjectToPhases(Map<String, dynamic> log) {
  if (log['phasesMigrated'] == true ||
      (log['phases'] is List && (log['phases'] as List).isNotEmpty)) {
    if (log['phasesMigrated'] != true) log['phasesMigrated'] = true;
    return false;
  }
  const Map<String, String> typeToPhase = {
    '자재 요청': '자재 입고',
    '입고일': '자재 입고',
    '납기일': '납품',
    '검사일정': '시운전·검사',
    '기타': '제작',
  };
  final schedules = schedulesOf(log);
  final Map<String, String> phaseIdByName = {};
  final Map<String, List<DateTime>> datesByName = {};
  final List<String> order = [];
  for (final s in schedules) {
    final name = typeToPhase[s['type']] ?? '제작';
    if (!phaseIdByName.containsKey(name)) {
      phaseIdByName[name] = newPhaseId();
      datesByName[name] = [];
      order.add(name);
    }
    s['phaseId'] = phaseIdByName[name];
    if (s['dateTime'] != null) {
      datesByName[name]!.add(dayOnly(asDate(s['dateTime'])));
    }
  }
  order.sort(
    (a, b) => kStandardPhaseNames
        .indexOf(a)
        .compareTo(kStandardPhaseNames.indexOf(b)),
  );
  final phases = <Map<String, dynamic>>[];
  for (final name in order) {
    final dates = datesByName[name]!..sort();
    phases.add(
      makePhase(
        name,
        id: phaseIdByName[name],
        start: dates.isEmpty ? null : dates.first,
        end: dates.isEmpty ? null : dates.last,
      ),
    );
  }
  log['phases'] = phases;
  log['schedules'] = schedules;
  log['phasesMigrated'] = true;
  return true;
}

// ───────────────────── 작업일보 ↔ 단계/일정 연결 ─────────────────────

List<String> reportIds(Map report, String key) =>
    (report[key] as List? ?? []).map((e) => e.toString()).toList();

// 일보에서 "오늘 완료"로 체크한 세부 일정/단계를 프로젝트에 반영한다.
// 이미 완료된 것은 그대로 두고, 체크 해제해도 되돌리지 않는다(멱등).
// 바뀐 게 있으면 true.
bool applyReportEffects(Map<String, dynamic> log, Map report) {
  bool changed = false;
  final doneSchedules = reportIds(report, 'completedScheduleIds').toSet();
  final donePhases = reportIds(report, 'completedPhaseIds').toSet();
  if (doneSchedules.isNotEmpty && log['schedules'] is List) {
    for (final s in log['schedules'] as List) {
      if (s is Map &&
          doneSchedules.contains(s['id']?.toString()) &&
          s['isCompleted'] != true) {
        s['isCompleted'] = true;
        changed = true;
      }
    }
  }
  if (donePhases.isNotEmpty && log['phases'] is List) {
    for (final p in log['phases'] as List) {
      if (p is Map &&
          donePhases.contains(p['id']?.toString()) &&
          p['isCompleted'] != true) {
        p['isCompleted'] = true;
        changed = true;
      }
    }
  }
  return changed;
}

// 단계별 실제 투입: 일보 일수 / 투입 인원-일(명 x 일).
({int days, int manDays}) phaseWorkStats(
  Map<String, dynamic> log,
  String phaseId,
) {
  int days = 0, manDays = 0;
  for (final r in (log['daily_reports'] as List? ?? [])) {
    if (r is! Map) continue;
    if (reportIds(r, 'workedPhaseIds').contains(phaseId)) {
      days++;
      manDays += (r['worker_count'] as num?)?.toInt() ?? 1;
    }
  }
  return (days: days, manDays: manDays);
}

bool isMaterialSchedule(Map s) => s['type'] == '자재 요청' || s['type'] == '입고일';

// 자재 상태: pending(입고일 미정) / expected(입고 예정) / late(입고일 지남) / done(입고 완료)
String materialState(Map s) {
  if (s['isCompleted'] == true) return 'done';
  if (s['dateTime'] == null) return 'pending';
  final d = dayOnly(asDate(s['dateTime']));
  return d.isBefore(dayOnly(DateTime.now())) ? 'late' : 'expected';
}

// ───────────────────── 지연 감지 / 뒤 단계 밀기 ─────────────────────

// 진행중 프로젝트에서 종료일이 지났는데 아직 끝나지 않은 첫 단계와 지연 일수.
({Map<String, dynamic> phase, int index, int days})? delayedPhase(
  Map<String, dynamic> log,
) {
  if (log['status'] == 'DONE') return null;
  final today = dayOnly(DateTime.now());
  final phases = phasesOf(log);
  for (int i = 0; i < phases.length; i++) {
    final e = phaseEnd(phases[i]);
    if (e != null && e.isBefore(today) && !phaseIsDone(log, phases[i])) {
      return (phase: phases[i], index: i, days: today.difference(e).inDays);
    }
  }
  return null;
}

// 지연된 단계의 종료일을 오늘로 늘리고, 뒤 단계의 시작/종료일을 [days]만큼 민다.
dynamic _shiftDateValue(dynamic v, int days) {
  if (v == null) return null;
  final d = asDate(v).add(Duration(days: days));
  if (v is Timestamp) return Timestamp.fromDate(d);
  if (v is String) return d.toIso8601String();
  return d;
}

void shiftPhasesAfterDelay(
  Map<String, dynamic> log,
  int index,
  int days, {
  bool includeSchedules = false,
}) {
  if (includeSchedules && log['schedules'] is List) {
    final laterIds = <String>{
      for (final p in phasesOf(log).skip(index + 1)) p['id'].toString(),
    };
    for (final s in log['schedules'] as List) {
      if (s is! Map || s['isCompleted'] == true) continue;
      if (!laterIds.contains(s['phaseId']?.toString())) continue;
      s['dateTime'] = _shiftDateValue(s['dateTime'], days);
      if (s['endDate'] != null)
        s['endDate'] = _shiftDateValue(s['endDate'], days);
    }
  }
  final phases = phasesOf(log);
  final today = dayOnly(DateTime.now());
  phases[index]['endDate'] = today;
  for (int j = index + 1; j < phases.length; j++) {
    final s = phaseStart(phases[j]), e = phaseEnd(phases[j]);
    if (s != null) phases[j]['startDate'] = s.add(Duration(days: days));
    if (e != null) phases[j]['endDate'] = e.add(Duration(days: days));
  }
  setPhases(log, phases);
}

// 일보의 "사용한 자재"에서 이 자재 요청/입고 항목을 골라 둔 횟수.
int materialUsageCount(Map<String, dynamic> log, String scheduleId) {
  int n = 0;
  for (final r in (log['daily_reports'] as List? ?? [])) {
    if (r is Map && reportIds(r, 'usedMaterialIds').contains(scheduleId)) n++;
  }
  return n;
}

// 마지막으로 이 자재를 쓴 것으로 기록한 일보 날짜(없으면 null). 날짜 계산에는
// report_tools의 reportDateOf가 필요해 호출하는 쪽에서 일보 목록을 넘긴다.
List<Map> reportsUsingMaterial(Map<String, dynamic> log, String scheduleId) => [
  for (final r in (log['daily_reports'] as List? ?? []))
    if (r is Map && reportIds(r, 'usedMaterialIds').contains(scheduleId)) r,
];

// 입고(완료)됐는데 일보에 사용 기록이 한 번도 없는 자재 항목.
List<Map<String, dynamic>> unusedReceivedMaterials(Map<String, dynamic> log) =>
    [
      for (final s in schedulesOf(log))
        if (isMaterialSchedule(s) &&
            materialState(s) == 'done' &&
            materialUsageCount(log, s['id']?.toString() ?? '') == 0)
          s,
    ];
