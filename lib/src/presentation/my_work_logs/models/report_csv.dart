// 작업 일지를 엑셀에서 열 수 있는 CSV로 만든다. 투입 통계와 프로젝트 보고서 내보내기가 같이 쓴다.
import 'attendance.dart';
import 'project_phase.dart';
import 'report_tools.dart';

/// 머리줄(엑셀에서 한글이 깨지지 않게 맨 앞에 BOM을 둔다).
const String kReportCsvHeader =
    '﻿프로젝트,날짜,근태,작업유형,인원,연장시간,벤딩pt,결선개소,작업단계,특이사항';

String _q(String s) => '"${s.replaceAll('"', '""').replaceAll('\n', ' ')}"';

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// [reports]는 (프로젝트, 그 프로젝트의 작업 일지) 짝의 목록이다.
String buildReportsCsv(Iterable<(Map<String, dynamic>, Map)> reports) {
  final b = StringBuffer(kReportCsvHeader)..writeln();
  for (final (l, r) in reports) {
    final names = {
      for (final p in phasesOf(l)) p['id'].toString(): p['name'].toString(),
    };
    final types = workTypesOf(r['work_type']).join('/');
    b.writeln(
      [
        _q(l['name']?.toString() ?? ''),
        _date(reportDateOf(r)),
        _q(attendanceTypeOf(Map<String, dynamic>.from(r))),
        _q(types),
        r['worker_count'] ?? 1,
        r['overtime_hours'] ?? 0,
        r['points'] ?? 0,
        r['wiring_points'] ?? 0,
        _q(
          reportIds(
            r,
            'workedPhaseIds',
          ).map((id) => names[id] ?? '').where((e) => e.isNotEmpty).join('/'),
        ),
        _q(r['note']?.toString() ?? ''),
      ].join(','),
    );
  }
  return b.toString();
}

/// 한 프로젝트의 [from]~[to] 일지(날짜 오름차순)를 (프로젝트, 일지) 짝으로.
List<(Map<String, dynamic>, Map)> reportsInRange(
  Map<String, dynamic> log,
  DateTime from,
  DateTime to,
) {
  final out = <(Map<String, dynamic>, Map)>[];
  for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>()) {
    final d = reportDateOf(r);
    if (d.isBefore(from) || d.isAfter(to)) continue;
    out.add((log, r));
  }
  out.sort((a, b) => reportDateOf(a.$2).compareTo(reportDateOf(b.$2)));
  return out;
}
