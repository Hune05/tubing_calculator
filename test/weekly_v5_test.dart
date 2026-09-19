import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_style.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/weekly_plan.dart';

Map<String, dynamic> proj({
  String name = 'A현장',
  Map<String, dynamic>? extra,
  List<Map<String, dynamic>> reports = const [],
  List<Map<String, dynamic>> punches = const [],
}) => {
  'id': name,
  'name': name,
  'status': 'ACTIVE',
  'phases': [],
  'schedules': [],
  'daily_reports': reports,
  'punch_lists': punches,
  ...?extra,
};

void main() {
  _logoTest();
  TestWidgetsFlutterBinding.ensureInitialized();

  test('asOf shows a past week: reports land in 금주, note in period', () {
    final past = DateTime.now().subtract(const Duration(days: 21));
    final d0 = DateTime(past.year, past.month, past.day);
    final md =
        '${d0.month.toString().padLeft(2, '0')}/${d0.day.toString().padLeft(2, '0')}';
    final logs = [
      proj(
        reports: [
          {
            'date': md,
            'dateISO': d0.toIso8601String(),
            'note': '옛날작업',
            'worker_count': 3,
          },
        ],
      ),
    ];
    final cur = buildWeeklyPlanDoc(logs);
    final old = buildWeeklyPlanDoc(logs, asOf: d0);
    expect(cur.sections.expand((s) => s.lines).join().contains('옛날작업'), false);
    expect(old.sections.expand((s) => s.lines).join().contains('옛날작업'), true);
    expect(old.period.contains('지난 주 보기'), true);
    expect(cur.period.contains('지난 주 보기'), false);
    // 과거 기준일에서는 진행률 줄을 만들지 않는다(현재 값이라 오해를 부르므로).
    expect(old.sections.expand((s) => s.lines).join().contains('◐ 진행률'), false);
  });

  test('issue lines carry refs to the original punch maps', () {
    final p = <String, dynamic>{
      'content': '누수',
      'location': '2층',
      'is_completed': false,
    };
    final logs = [proj(punches: [p])];
    final d = buildWeeklyPlanDoc(logs);
    final s = d.sections.last;
    expect(s.heading, '미해결 이슈 현황');
    final refs = s.issueRefs!;
    expect(refs.length, 1);
    final i = refs.keys.first;
    expect(s.lines[i].contains('누수'), true);
    expect(identical(refs[i]!.punch, p), true);
  });

  test('single project uses its own header; hidden sections are removed', () {
    final logs = [
      proj(
        extra: {
          'reportHeader': {'company': '루마설비', 'manager': '홍길동'},
        },
        punches: [
          {'content': 'x', 'is_completed': false},
        ],
      ),
    ];
    ReportStyle.current = ReportStyle(hiddenSections: {'미해결 이슈'});
    final d = buildWeeklyPlanDoc(logs);
    expect(d.company, '루마설비');
    expect(d.manager, '홍길동');
    expect(d.sections.any((s) => s.heading.startsWith('미해결 이슈')), false);
    ReportStyle.current = ReportStyle();
    final two = buildWeeklyPlanDoc([proj(name: 'A'), proj(name: 'B')]);
    expect(two.company, isNull);
  });

  test('weekly PDF builds (header, signature) and can be written out', () async {
    ReportStyle.current = ReportStyle(
      company: '테스트설비',
      manager: '담당자',
      signature: true,
      sig1: '작성자',
      sig2: '확인자',
    );
    final logs = [
      proj(
        reports: [
          {
            'date': '09/19',
            'dateISO': DateTime.now().toIso8601String(),
            'note': '전선관 3개소 설치',
            'worker_count': 2,
          },
        ],
        punches: [
          {'content': '누수', 'location': '2층', 'is_completed': false},
        ],
      ),
    ];
    final doc = buildWeeklyPlanDoc(logs);
    final bytes = await buildReportPdfBytes(doc);
    expect(utf8.decode(bytes.sublist(0, 4)), '%PDF');
    expect(bytes.length > 2000, true);
    final out = File('build/weekly_test.pdf');
    await out.create(recursive: true);
    await out.writeAsBytes(bytes);
    ReportStyle.current = ReportStyle();
  });
}

void _logoTest() {
  test('weekly PDF with logo and signature images builds', () async {
    final b64 = File('build/logo_test.b64').existsSync()
        ? File('build/logo_test.b64').readAsStringSync()
        : null;
    if (b64 == null) return;
    ReportStyle.current = ReportStyle(
      company: '로고설비',
      manager: '홍길동',
      logoB64: b64,
      signature: true,
      sig1: '작성자',
      sig2: '확인자',
      sig1B64: b64,
    );
    final doc = buildWeeklyPlanDoc([proj()]);
    final bytes = await buildReportPdfBytes(doc);
    await File('build/weekly_logo_test.pdf').writeAsBytes(bytes);
    ReportStyle.current = ReportStyle();
  });
}
