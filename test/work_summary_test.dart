// 하루·한 주 정리(10-09 고도화 4번): 기간 계산, 글 만들기, 화면.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_record.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/attendance.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/work_summary.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/work_summary_page.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_record.dart';
import 'package:tubing_calculator/src/presentation/safety/safety_check_model.dart';

final _thu = DateTime(2026, 10, 8, 14); // 목요일

final _logs = <Map<String, dynamic>>[
  {
    'id': 'p1',
    'name': '현장 A',
    'daily_reports': [
      {'dateISO': '2026-10-08', 'work_type': '배관', 'note': '1층 튜브 20m 포설'},
      {'dateISO': '2026-10-06', 'work_type': '결선', 'note': ''},
      {'dateISO': '2026-10-01', 'work_type': '배관', 'note': '지난주'},
    ],
  },
];

final _safety = [
  SafetyRecord(
    id: 's1',
    at: DateTime(2026, 10, 8, 7, 50),
    site: '현장 A',
    work: '계기 결선',
    lines: const [SafetyLine('작업허가서 확인', SafetyAnswer.yes)],
  ),
];

final _pts = [
  PtRecord(
    id: 'p',
    date: DateTime(2026, 10, 8),
    line: 'L-101',
    projectId: 'p1',
    projectName: '현장 A',
  ),
];

final _cals = [
  CalRecord(
    id: 'c',
    date: DateTime(2026, 10, 7),
    tag: 'PT-101',
    lrv: 0,
    urv: 10,
    found: const [],
  ),
];

final _att = {
  dateKey(DateTime(2026, 10, 8)): AttendanceRecord(
    date: DateTime(2026, 10, 8),
    checkIn: '07:30',
    checkOut: '17:20',
    memo: '태안 3호기',
  ),
};

String _text(ReportDoc d) => d.toText();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('기간: 하루·한 주(월~일), 앞뒤로 옮기기', () {
    final d = SummaryRange.day(_thu);
    expect(d.label, '10/8 (목)');
    expect(d.shift(1).label, '10/9 (금)');
    final w = SummaryRange.week(_thu);
    expect(w.label, '10/5 (월) ~ 10/11 (일)');
    expect(w.shift(-1).label, '9/28 (월) ~ 10/4 (일)');
    expect(w.days, hasLength(7));
    expect(w.contains(DateTime(2026, 10, 11, 23)), isTrue);
    expect(w.contains(DateTime(2026, 10, 12)), isFalse);
  });

  test('하루 정리: 그날 것만 모은다', () {
    final doc = buildWorkSummaryDoc(
      range: SummaryRange.day(_thu),
      attendance: _att,
      logs: _logs,
      safety: _safety,
      pts: _pts,
      cals: _cals,
    );
    final t = _text(doc);
    expect(t, startsWith('[하루 정리] 업무 보고\n10/8 (목)'));
    expect(t, contains('근태 1일'));
    expect(t, contains('10/8 (목) 정상근무 07:30~17:20 · 태안 3호기'));
    expect(t, contains('10/8 현장 A: 배관 · 1층 튜브 20m 포설'));
    expect(t, isNot(contains('현장 A: 결선'))); // 10/6 일지
    expect(t, contains('10/8 07:50 현장 A · 계기 결선 · 항목 모두 확인'));
    expect(t, contains('10/8 L-101 판정 없음 · 현장 A'));
    expect(t, contains('교정 0건'));
    expect(t, isNot(contains('PT-101'))); // 10/7 교정
  });

  test('한 주 정리: 그 주 월~일, 지난주 것은 빠진다', () {
    final doc = buildWorkSummaryDoc(
      range: SummaryRange.week(_thu),
      attendance: _att,
      logs: _logs,
      safety: _safety,
      pts: _pts,
      cals: _cals,
    );
    final t = _text(doc);
    expect(t, startsWith('[한 주 정리] 업무 보고'));
    expect(t, contains('작업 일지 2건'));
    expect(t, contains('10/6 현장 A: 결선'));
    expect(t, isNot(contains('지난주')));
    expect(t, contains('10/7 PT-101 판정 없음'));
    // 일지는 날짜 차례대로
    expect(t.indexOf('10/6 현장 A'), lessThan(t.indexOf('10/8 현장 A')));
  });

  test('근태를 못 읽으면 그렇다고 적고, 기록이 없으면 "없음"', () {
    final doc = buildWorkSummaryDoc(
      range: SummaryRange.day(DateTime(2026, 10, 10)),
      attendance: null,
      logs: _logs,
      safety: _safety,
      pts: _pts,
      cals: _cals,
    );
    final t = _text(doc);
    expect(t, contains('근태를 읽지 못했습니다'));
    expect(t, isNot(contains('근태 0일')));
    expect(t, contains('■ 안전 점검\n  · 없음'));
  });

  test('PDF가 만들어진다(파일 이름: 하루_정리_업무_보고_날짜)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final doc = buildWorkSummaryDoc(
      range: SummaryRange.week(_thu),
      attendance: _att,
      logs: _logs,
      safety: _safety,
      pts: _pts,
      cals: _cals,
    );
    final bytes = await buildReportPdfBytes(doc);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    expect(reportPdfFileName(doc), '한_주_정리_업무_보고_20261005.pdf');
  });

  testWidgets('화면: 하루로 열고, 한 주로 바꾸고, 앞으로 옮기고, 글로 보낸다', (tester) async {
    tester.view.physicalSize = const Size(412, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ReportDoc? sent;
    final asked = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: WorkSummaryPage(
          logs: _logs,
          now: () => _thu,
          load: (r) async {
            asked.add(r.label);
            return (attendance: _att, safety: _safety, pts: _pts, cals: _cals);
          },
          shareText: (d) async => sent = d,
          sharePdf: (d) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('10/8 (목)'), findsOneWidget);
    expect(find.byKey(const Key('ws_section_압력시험')), findsOneWidget);
    expect(find.text('· 10/8 L-101 판정 없음 · 현장 A'), findsOneWidget);
    expect(find.byKey(const Key('ws_today')), findsNothing);

    await tester.tap(find.byKey(const Key('ws_week')));
    await tester.pumpAndSettle();
    expect(find.text('10/5 (월) ~ 10/11 (일)'), findsOneWidget);
    expect(find.text('· 작업 일지 2건'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ws_next')));
    await tester.pumpAndSettle();
    expect(find.text('10/12 (월) ~ 10/18 (일)'), findsOneWidget);
    expect(find.byKey(const Key('ws_today')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ws_today')));
    await tester.pumpAndSettle();
    expect(find.text('10/5 (월) ~ 10/11 (일)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ws_share')));
    await tester.pumpAndSettle();
    expect(sent!.title, '한 주 정리');
    expect(asked.first, '10/8 (목)');
  });
}
