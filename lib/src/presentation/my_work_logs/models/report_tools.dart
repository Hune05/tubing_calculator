import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

import 'package:tubing_calculator/main.dart'
    show flutterLocalNotificationsPlugin;
import 'project_phase.dart';

// 🚀 작업일보 부가 기능 모음: 기간 보고서(텍스트/PDF), 통합 검색, 일보 알림.

const List<String> kPhotoTags = ['작업 전', '작업 중', '작업 후', '자재', '이슈', '기타'];

// 일보 날짜는 "MM/dd" 문자열이라 연도가 없다. 올해로 보되, 오늘보다 한참 미래면
// 작년 것으로 본다(연말~연초 걸친 프로젝트 대비).
DateTime reportDate(String mmdd) {
  final parts = mmdd.split('/');
  final now = DateTime.now();
  final m = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 1;
  final d = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
  var dt = DateTime(now.year, m, d);
  if (dt.isAfter(now.add(const Duration(days: 30)))) {
    dt = DateTime(now.year - 1, m, d);
  }
  return dt;
}

// ───────────────────────── 기간 보고서 ─────────────────────────
class ReportSection {
  final String heading;
  final List<String> lines;
  ReportSection(this.heading, this.lines);
}

class ReportDoc {
  final String title;
  final String period;
  final List<ReportSection> sections;
  ReportDoc(this.title, this.period, this.sections);

  String toText() {
    final b = StringBuffer('[$title] 작업 보고\n$period\n');
    for (final s in sections) {
      b.writeln('\n■ ${s.heading}');
      for (final l in s.lines) {
        b.writeln(l);
      }
    }
    return b.toString().trimRight();
  }
}

String _md(DateTime d) => '${d.month}/${d.day}';

ReportDoc buildReportDoc(Map<String, dynamic> log, DateTime from, DateTime to) {
  final f = dayOnly(from), t = dayOnly(to);
  final progress = (projectProgress(log) * 100).round();
  final cur = currentPhase(log);
  final due = projectDue(log);
  final today = dayOnly(DateTime.now());

  final overview = <String>['진행률 $progress%'];
  if (cur != null) overview.add('현재 단계: ${cur['name']}');
  if (due != null) {
    final diff = due.difference(today).inDays;
    overview.add(
      '종료 예정 ${due.year}.${due.month}.${due.day} '
      '(${diff == 0
          ? 'D-Day'
          : diff > 0
          ? 'D-$diff'
          : 'D+${-diff}'})',
    );
  }
  final delay = delayedPhase(log);
  if (delay != null) {
    overview.add('⚠ ${delay.phase['name']} 단계 ${delay.days}일 지연');
  }

  final reports =
      (log['daily_reports'] as List? ?? []).whereType<Map>().where((r) {
        final d = reportDate(r['date']?.toString() ?? '');
        return !d.isBefore(f) && !d.isAfter(t);
      }).toList()..sort(
        (a, b) => reportDate(
          a['date'].toString(),
        ).compareTo(reportDate(b['date'].toString())),
      );

  final phaseNames = {
    for (final p in phasesOf(log)) p['id'].toString(): p['name'].toString(),
  };
  final dayLines = <String>[];
  final Map<String, int> phaseDays = {};
  int manDays = 0;
  final completedTitles = <String>[];
  final scheduleTitle = {
    for (final s in schedulesOf(log))
      s['id'].toString(): (s['title'] ?? s['type'] ?? '').toString(),
  };
  for (final r in reports) {
    final types = r['work_type'] is List
        ? (r['work_type'] as List).join('·')
        : (r['work_type']?.toString() ?? '');
    final workers = (r['worker_count'] as num?)?.toInt() ?? 1;
    manDays += workers;
    final pt = (r['points'] as num?)?.toInt() ?? 0;
    final wp = (r['wiring_points'] as num?)?.toInt() ?? 0;
    final extra = [
      if (pt > 0) '벤딩 ${pt}pt',
      if (wp > 0) '결선 $wp개소',
      if (r['is_overtime'] == true) '연장',
    ];
    dayLines.add(
      '· ${r['date']}  $types / $workers명${extra.isEmpty ? '' : ' / ${extra.join(' ')}'}',
    );
    final note = (r['note']?.toString() ?? '').trim();
    if (note.isNotEmpty && note != '특이사항 없음') {
      for (final l in note.split('\n')) {
        dayLines.add('   - $l');
      }
    }
    final mats = (r['materials_used']?.toString() ?? '').trim();
    if (mats.isNotEmpty) dayLines.add('   자재: $mats');
    for (final id in reportIds(r, 'workedPhaseIds')) {
      final n = phaseNames[id];
      if (n != null) phaseDays[n] = (phaseDays[n] ?? 0) + 1;
    }
    for (final id in reportIds(r, 'completedScheduleIds')) {
      final n = scheduleTitle[id];
      if (n != null && n.isNotEmpty) completedTitles.add('${r['date']} $n');
    }
  }

  final sections = <ReportSection>[
    ReportSection('진행 현황', overview),
    ReportSection(
      '작업 내역 (${reports.length}일, 투입 $manDays인·일)',
      dayLines.isEmpty ? ['이 기간에 작성된 일보가 없습니다.'] : dayLines,
    ),
  ];
  if (phaseDays.isNotEmpty) {
    sections.add(
      ReportSection(
        '단계별 작업일',
        phaseDays.entries.map((e) => '· ${e.key}: ${e.value}일').toList(),
      ),
    );
  }
  if (completedTitles.isNotEmpty) {
    sections.add(
      ReportSection('완료한 일정', completedTitles.map((e) => '· $e').toList()),
    );
  }

  final mats = schedulesOf(log).where(isMaterialSchedule).toList();
  if (mats.isNotEmpty) {
    final open = mats.where((m) => materialState(m) != 'done').toList();
    final lines = <String>[
      '입고 완료 ${mats.length - open.length} / 전체 ${mats.length}',
    ];
    for (final m in open) {
      final st = materialState(m);
      final label = switch (st) {
        'late' => '입고 지연',
        'pending' => '입고일 미정',
        _ => '입고 예정',
      };
      final dt = m['dateTime'] == null ? '' : ' ${_md(asDate(m['dateTime']))}';
      lines.add('· ${m['title'] ?? m['type']} ($label$dt)');
    }
    sections.add(ReportSection('자재 현황', lines));
  }

  final issues = (log['punch_lists'] as List? ?? [])
      .whereType<Map>()
      .where((p) => p['is_completed'] != true)
      .toList();
  if (issues.isNotEmpty) {
    sections.add(
      ReportSection(
        '미해결 이슈 (${issues.length})',
        issues
            .take(10)
            .map((p) => '· ${p['content'] ?? ''} (${p['location'] ?? ''})')
            .toList(),
      ),
    );
  }

  final lastPlan = reports.isNotEmpty
      ? (reports.last['next_day_plan']?.toString() ?? '').trim()
      : '';
  if (lastPlan.isNotEmpty) {
    sections.add(ReportSection('다음 계획', [lastPlan]));
  }

  return ReportDoc(
    log['name']?.toString() ?? '프로젝트',
    '기간 ${f.year}.${f.month}.${f.day} ~ ${t.year}.${t.month}.${t.day}',
    sections,
  );
}

Future<void> shareReportText(ReportDoc doc) async {
  // ignore: deprecated_member_use
  await Share.share(doc.toText());
}

Future<void> shareReportPdf(ReportDoc doc) async {
  final fontData = await rootBundle.load(
    'assets/fonts/NotoSansKR-VariableFont_wght.ttf',
  );
  final ttf = pw.Font.ttf(fontData);
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: ttf, bold: ttf),
  );
  pdf.addPage(
    pw.MultiPage(
      build: (ctx) => [
        pw.Text(
          '${doc.title} 작업 보고',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(doc.period, style: const pw.TextStyle(fontSize: 11)),
        for (final s in doc.sections) ...[
          pw.SizedBox(height: 14),
          pw.Text(
            s.heading,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(height: 6),
          for (final l in s.lines)
            pw.Text(l, style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
        ],
      ],
    ),
  );
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
  await file.writeAsBytes(await pdf.save());
  // ignore: deprecated_member_use
  await Share.shareXFiles([XFile(file.path)], text: '${doc.title} 작업 보고');
}

// ───────────────────────── 통합 검색 ─────────────────────────
class SearchHit {
  final Map<String, dynamic> log;
  final String kind; // 일보 | 이슈
  final String title;
  final String snippet;
  SearchHit(this.log, this.kind, this.title, this.snippet);
}

String _snippet(String text, String q) {
  final i = text.toLowerCase().indexOf(q.toLowerCase());
  if (i < 0) return text.length > 60 ? '${text.substring(0, 60)}…' : text;
  final s = (i - 20).clamp(0, text.length);
  final e = (i + q.length + 40).clamp(0, text.length);
  return '${s > 0 ? '…' : ''}${text.substring(s, e).replaceAll('\n', ' ')}${e < text.length ? '…' : ''}';
}

List<SearchHit> searchProjects(List<Map<String, dynamic>> logs, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];
  final hits = <SearchHit>[];
  for (final log in logs) {
    final name = log['name']?.toString() ?? '';
    for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>()) {
      final wt = r['work_type'] is List
          ? (r['work_type'] as List).join(' ')
          : (r['work_type']?.toString() ?? '');
      final fields = [
        r['note'],
        r['materials_used'],
        r['next_day_plan'],
        r['as_built_reason'],
        wt,
      ].map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty);
      for (final f in fields) {
        if (f.toLowerCase().contains(q)) {
          hits.add(
            SearchHit(log, '일보', '$name · ${r['date']}', _snippet(f, q)),
          );
          break;
        }
      }
    }
    for (final p in (log['punch_lists'] as List? ?? []).whereType<Map>()) {
      final f = [
        p['content'],
        p['location'],
      ].map((e) => e?.toString() ?? '').join(' ');
      if (f.toLowerCase().contains(q)) {
        hits.add(
          SearchHit(
            log,
            '이슈',
            '$name · ${p['location'] ?? ''}',
            _snippet(p['content']?.toString() ?? f, q),
          ),
        );
      }
    }
  }
  return hits;
}

// ───────────────────────── 일보 알림 ─────────────────────────
const int _kReminderId = 918273;
const String _kReminderChannel = 'daily_report_reminder';
const String _kPrefEnabled = 'report_reminder_enabled';
const String _kPrefMinutes = 'report_reminder_minutes';
bool _tzReady = false;

Future<({bool enabled, int minutes})> loadReportReminder() async {
  final p = await SharedPreferences.getInstance();
  return (
    enabled: p.getBool(_kPrefEnabled) ?? true,
    minutes: p.getInt(_kPrefMinutes) ?? 18 * 60,
  );
}

Future<void> saveReportReminder(bool enabled, int minutes) async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(_kPrefEnabled, enabled);
  await p.setInt(_kPrefMinutes, minutes);
}

// 진행중 프로젝트가 있는데 오늘 일보가 아직 없으면 오늘 정해진 시각에, 이미
// 썼으면 내일부터 매일 알린다. 앱을 열 때/일보 저장 후에 다시 맞춘다.
Future<void> syncReportReminder(List<Map<String, dynamic>> logs) async {
  try {
    final pref = await loadReportReminder();
    await flutterLocalNotificationsPlugin.cancel(id: _kReminderId);
    final active = logs.where((l) => l['status'] != 'DONE').toList();
    if (!pref.enabled || active.isEmpty) return;

    if (!_tzReady) {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      _tzReady = true;
    }
    final now = DateTime.now();
    final todayStr =
        '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    final wroteToday = active.any(
      (l) => (l['daily_reports'] as List? ?? []).whereType<Map>().any(
        (r) => r['date'] == todayStr,
      ),
    );
    var at = DateTime(
      now.year,
      now.month,
      now.day,
      pref.minutes ~/ 60,
      pref.minutes % 60,
    );
    if (wroteToday || !at.isAfter(now)) at = at.add(const Duration(days: 1));

    const channel = AndroidNotificationChannel(
      _kReminderChannel,
      '작업일보 알림',
      description: '작업일보 작성 리마인더',
      importance: Importance.high,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: _kReminderId,
      title: '작업일보',
      body: '오늘 작업 일보 아직 안 썼어요. 기억날 때 간단히 남겨두세요.',
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _kReminderChannel,
          '작업일보 알림',
          channelDescription: '작업일보 작성 리마인더',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  } catch (e) {
    debugPrint('일보 알림 설정 실패: $e');
  }
}
