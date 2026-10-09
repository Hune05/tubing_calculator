// 하루·한 주 정리(10-09 고도화 4번): 근태, 작업 일지, 안전 점검, 압력시험, 교정을 날짜별로 모아
// 보고서 한 장(ReportDoc)으로 만든다. 글로 보내기·PDF는 주간 보고와 같은 도구를 쓴다.
// 이 파일은 글 만들기만 한다(읽기는 화면 쪽, 시험은 따로).
import '../../instrument/cal_record.dart';
import '../../pressure_test/test_record.dart';
import '../../safety/safety_check_model.dart';
import 'attendance.dart';
import 'report_tools.dart';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

String _md(DateTime d) => '${d.month}/${d.day}';

/// "10/9 (목)"
String summaryDayLabel(DateTime d) => '${_md(d)} (${_weekdays[d.weekday - 1]})';

/// 정리할 기간(두 날 포함).
class SummaryRange {
  final DateTime from;
  final DateTime to;
  SummaryRange._(DateTime from, DateTime to) : from = _day(from), to = _day(to);

  /// 그날 하루.
  factory SummaryRange.day(DateTime d) => SummaryRange._(d, d);

  /// 그날이 든 주(월~일).
  factory SummaryRange.week(DateTime d) {
    final mon = _day(d).subtract(Duration(days: d.weekday - 1));
    return SummaryRange._(mon, mon.add(const Duration(days: 6)));
  }

  bool get isDay => from == to;

  bool contains(DateTime d) {
    final x = _day(d);
    return !x.isBefore(from) && !x.isAfter(to);
  }

  /// 앞뒤로 한 칸(하루면 하루, 한 주면 한 주).
  SummaryRange shift(int step) {
    final days = isDay ? step : step * 7;
    return SummaryRange._(
      from.add(Duration(days: days)),
      to.add(Duration(days: days)),
    );
  }

  /// "10/9 (목)" 또는 "10/6 (월) ~ 10/12 (일)"
  String get label => isDay
      ? summaryDayLabel(from)
      : '${summaryDayLabel(from)} ~ ${summaryDayLabel(to)}';

  /// 기간 안의 날짜들.
  List<DateTime> get days => [
    for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) d,
  ];
}

String _firstLine(String s) {
  final t = s.trim().split('\n').first.trim();
  return t.length > 60 ? '${t.substring(0, 60)}…' : t;
}

String _verdict(bool? pass) => pass == null ? '판정 없음' : (pass ? '합격' : '불합격');

const String _none = '  · 없음';

/// [attendance]가 null이면 근태를 읽지 못한 것(로그인 안 함·통신 없음)이다.
ReportDoc buildWorkSummaryDoc({
  required SummaryRange range,
  required Map<String, AttendanceRecord>? attendance,
  required List<Map<String, dynamic>> logs,
  required List<SafetyRecord> safety,
  required List<PtRecord> pts,
  required List<CalRecord> cals,
}) {
  // 근태
  final att = <String>[];
  var attDays = 0;
  if (attendance == null) {
    att.add('  · 근태를 읽지 못했습니다(로그인·통신 확인)');
  } else {
    for (final d in range.days) {
      final r = attendance[dateKey(d)];
      if (r == null) continue;
      attDays++;
      final time = (r.checkIn ?? '').isEmpty && (r.checkOut ?? '').isEmpty
          ? ''
          : ' ${r.checkIn ?? '?'}~${r.checkOut ?? '?'}';
      final memo = (r.memo ?? '').isEmpty ? '' : ' · ${r.memo}';
      att.add('  · ${summaryDayLabel(d)} ${r.type}$time$memo');
    }
    if (att.isEmpty) att.add(_none);
  }

  // 작업 일지(프로젝트마다 그 기간에 쓴 것)
  final work = <({DateTime date, String text})>[];
  for (final log in logs) {
    final name = (log['name'] ?? '').toString().trim();
    for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>()) {
      final d = reportDateOf(r);
      if (!range.contains(d)) continue;
      final types = workTypesOf(r['work_type']).join('·');
      final note = (r['note']?.toString() ?? '').trim();
      final body = (note.isEmpty || note == '특이사항 없음')
          ? types
          : [if (types.isNotEmpty) types, _firstLine(note)].join(' · ');
      final who = name.isEmpty ? '' : '$name: ';
      work.add((date: d, text: '  · ${_md(d)} $who$body'.trimRight()));
    }
  }
  work.sort((a, b) => a.date.compareTo(b.date));

  // 안전 점검
  final safe = [
    for (final r in safety)
      if (range.contains(r.at)) r,
  ]..sort((a, b) => a.at.compareTo(b.at));

  // 압력시험·교정
  final pt = [
    for (final r in pts)
      if (range.contains(r.date)) r,
  ]..sort((a, b) => a.date.compareTo(b.date));
  final cal = [
    for (final r in cals)
      if (range.contains(r.date)) r,
  ]..sort((a, b) => a.date.compareTo(b.date));
  final ptFail = pt.where((r) => r.verdict.pass == false).length;
  final calFail = cal.where((r) => r.finalPass == false).length;

  String place(String project, String site) {
    final p = project.trim().isNotEmpty ? project.trim() : site.trim();
    return p.isEmpty ? '' : ' · $p';
  }

  final summary = [
    if (attendance != null) '  · 근태 $attDays일',
    '  · 작업 일지 ${work.length}건',
    '  · 안전 점검 ${safe.length}회',
    '  · 압력시험 ${pt.length}건${ptFail > 0 ? ' (불합격 $ptFail)' : ''}',
    '  · 교정 ${cal.length}건${calFail > 0 ? ' (불합격 $calFail)' : ''}',
  ];

  final sections = [
    ReportSection('요약', summary),
    ReportSection('근태', att),
    ReportSection(
      '작업 일지',
      work.isEmpty ? [_none] : [for (final w in work) w.text],
    ),
    ReportSection(
      '안전 점검',
      safe.isEmpty
          ? [_none]
          : [
              for (final r in safe)
                '  · ${safetyTimeLabel(r.at)}'
                    '${r.site.isEmpty ? '' : ' ${r.site}'}'
                    '${r.work.isEmpty ? '' : ' · ${r.work}'}'
                    ' · ${r.unanswered == 0 ? '항목 모두 확인' : '미확인 ${r.unanswered}개'}',
            ],
    ),
    ReportSection(
      '압력시험',
      pt.isEmpty
          ? [_none]
          : [
              for (final r in pt)
                '  · ${_md(r.date)} ${r.line.isEmpty ? '(라인 번호 없음)' : r.line}'
                    ' ${_verdict(r.verdict.pass)}${place(r.projectName, r.site)}',
            ],
    ),
    ReportSection(
      '교정',
      cal.isEmpty
          ? [_none]
          : [
              for (final r in cal)
                '  · ${_md(r.date)} ${r.tag.isEmpty ? '(태그 없음)' : r.tag}'
                    '${r.instrument.isEmpty ? '' : ' ${r.instrument}'}'
                    ' ${_verdict(r.finalPass)}${place(r.projectName, '')}',
            ],
    ),
  ];
  final f = range.from;
  return ReportDoc(
    range.isDay ? '하루 정리' : '한 주 정리',
    range.label,
    sections,
    heading: '업무 보고',
    showAuthorLine: true,
    fileStamp:
        '${f.year}${f.month.toString().padLeft(2, '0')}${f.day.toString().padLeft(2, '0')}',
  );
}
