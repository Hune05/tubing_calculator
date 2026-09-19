import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/reminder_problem_card.dart';

import 'helpers_text.dart';

Future<void> pump(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));
  await tester.pumpAndSettle();
}

void main() {
  _finalShareRecordTest();
  _finalReportNameTest();
  group('공유 결과 안내 문구', () {
    test(
      'each status has its own message and never claims what it cannot know',
      () {
        final ok = pdfShareNotice(ShareResultStatus.success, '마무리 보고서');
        final closed = pdfShareNotice(ShareResultStatus.dismissed, '마무리 보고서');
        final unknown = pdfShareNotice(
          ShareResultStatus.unavailable,
          '마무리 보고서',
        );
        expect(ok, '마무리 보고서를 공유했습니다.');
        expect(closed.contains('공유하지 않고 닫았습니다'), true);
        // 결과를 알 수 없을 때는 "보냈다/공유했다"고 단정하지 않는다.
        expect(unknown.contains('확인할 수 없습니다'), true);
        expect(unknown.contains('공유했습니다'), false);
        expect({ok, closed, unknown}.length, 3);
      },
    );

    test('messages end in the 습니다 style', () {
      for (final s in ShareResultStatus.values) {
        final m = pdfShareNotice(s, '마무리 보고서');
        expect(m.endsWith('.'), true);
        expect(m.contains('요.'), false, reason: m);
      }
    });
  });

  group('ReminderProblemCard', () {
    Widget card({
      required Future<String?> Function() onRetry,
      void Function(String?)? onRetried,
      VoidCallback? onOpenCheck,
      bool preview = false,
    }) => ReminderProblemCard(
      message: '일보 알림 2개가 필요한데 예약이 하나도 없습니다.',
      preview: preview,
      onOpenCheck: onOpenCheck ?? () {},
      onRetry: onRetry,
      onRetried: onRetried ?? (_) {},
    );

    testWidgets('shows both actions and the message', (tester) async {
      await pump(tester, card(onRetry: () async => null));
      expect(find.text('일보 알림 예약에 문제가 있습니다'), findsOneWidget);
      expect(find.text('다시 예약'), findsOneWidget);
      expect(find.text('알림 점검 열기'), findsOneWidget);
      expect(findTextContaining('예약이 하나도 없습니다'), findsOneWidget);
      expect(findTextContaining('다시 예약하거나 알림 점검에서 확인하십시오'), findsOneWidget);
    });

    testWidgets('retry that fixes it reports null and says so', (tester) async {
      final calls = <String?>[];
      var retried = 0;
      await pump(
        tester,
        card(
          onRetry: () async {
            retried++;
            return null;
          },
          onRetried: calls.add,
        ),
      );
      await tester.tap(find.text('다시 예약'));
      await tester.pumpAndSettle();
      expect(retried, 1);
      expect(calls, [null]);
      expect(find.text('알림을 다시 예약했습니다.'), findsOneWidget);
    });

    testWidgets(
      'retry that does not fix it keeps the problem and points to the check page',
      (tester) async {
        final calls = <String?>[];
        await pump(
          tester,
          card(onRetry: () async => '아직 문제', onRetried: calls.add),
        );
        await tester.tap(find.text('다시 예약'));
        await tester.pumpAndSettle();
        expect(calls, ['아직 문제']);
        expect(find.textContaining('아직 맞지 않습니다'), findsOneWidget);
      },
    );

    testWidgets('a throwing retry is treated as still-broken, not a crash', (
      tester,
    ) async {
      final calls = <String?>[];
      await pump(
        tester,
        card(
          onRetry: () async => throw StateError('boom'),
          onRetried: calls.add,
        ),
      );
      await tester.tap(find.text('다시 예약'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(calls.single, isNotNull);
    });

    testWidgets('the button is disabled while retrying (no double taps)', (
      tester,
    ) async {
      var retried = 0;
      final gate = Completer<void>();
      await pump(
        tester,
        card(
          onRetry: () async {
            retried++;
            await gate.future;
            return null;
          },
        ),
      );
      await tester.tap(find.text('다시 예약'));
      await tester.pump();
      // 진행 중에는 글자가 스피너로 바뀌어 다시 누를 수 없다.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('다시 예약'), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(retried, 1);
      expect(find.text('다시 예약'), findsOneWidget);
    });

    testWidgets('preview card says it is only a preview', (tester) async {
      await pump(tester, card(onRetry: () async => null, preview: true));
      expect(findTextContaining('미리 보기이며 실제 문제는 아닙니다'), findsOneWidget);
      expect(findTextContaining('다시 예약하거나'), findsNothing);
    });

    testWidgets('알림 점검 열기 calls its callback', (tester) async {
      var opened = 0;
      await pump(
        tester,
        card(onRetry: () async => null, onOpenCheck: () => opened++),
      );
      await tester.tap(find.text('알림 점검 열기'));
      expect(opened, 1);
    });
  });

  test(
    'resyncRemindersAndCheck never throws without the notification plugin',
    () async {
      // 테스트 환경에는 알림 플러그인이 없다 → 오류 없이 "문제 없음(null)"로 끝나야 한다.
      expect(await resyncRemindersAndCheck([]), isNull);
    },
  );
}

void _finalReportNameTest() {
  test('final report is labelled 마무리 보고서, not the generic 작업 보고', () {
    final t = DateTime.now();
    final log = <String, dynamic>{
      'id': 'a',
      'name': 'A현장',
      'status': 'DONE',
      'completedAt': t,
      'phases': [],
      'schedules': [],
      'punch_lists': [],
      'retro': {'cause': '원인', 'lesson': '교훈'},
      'daily_reports': [
        {
          'date':
              '${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')}',
          'dateISO': DateTime(t.year, t.month, t.day).toIso8601String(),
          'worker_count': 2,
        },
      ],
    };
    final doc = buildFinalReportDoc(log);
    expect(doc.heading, '마무리 보고서');
    expect(doc.toText().startsWith('[A현장] 마무리 보고서'), true);
    expect(
      reportPdfFileName(doc, DateTime(2026, 9, 19)),
      'A현장_마무리_보고서_20260919.pdf',
    );
    // 내용(총 통계, 결과 정리)은 그대로 들어 있다.
    expect(doc.sections.any((s) => s.heading == '총 통계'), true);
    expect(doc.sections.last.heading, '결과 정리');
    // 복사본만 바뀌고 원본 종류 표시는 그대로.
    expect(ReportDoc('t', 'p', []).withHeading('x').heading, 'x');
    expect(ReportDoc('t', 'p', []).heading, '작업 보고');
  });
}

void _finalShareRecordTest() {
  test('final report share result is recorded and labelled', () {
    final log = <String, dynamic>{};
    expect(finalReportShareLabel(log), isNull);
    final at = DateTime(2026, 9, 19, 15, 4);
    recordFinalReportShare(log, ShareResultStatus.success, at);
    expect(finalReportShareLabel(log), '9/19 15:04 공유함');
    recordFinalReportShare(log, ShareResultStatus.dismissed, at);
    expect(finalReportShareLabel(log), '9/19 15:04 만들었지만 공유하지 않음');
    recordFinalReportShare(log, ShareResultStatus.unavailable, at);
    expect(finalReportShareLabel(log)!.contains('공유 여부는 확인할 수 없음'), true);
    // 다시 만들면 마지막 결과로 덮어쓴다.
    recordFinalReportShare(
      log,
      ShareResultStatus.success,
      DateTime(2026, 9, 20, 9, 5),
    );
    expect(finalReportShareLabel(log), '9/20 09:05 공유함');
    // 알 수 없는 값·손상된 값은 표시하지 않는다.
    expect(
      finalReportShareLabel({
        'finalReportShare': {'status': 'weird'},
      }),
      isNull,
    );
    expect(finalReportShareLabel({'finalReportShare': 'x'}), isNull);
    // 저장 값이 Firestore를 거쳐 문자열/날짜로 돌아와도 읽힌다.
    expect(
      finalReportShareLabel({
        'finalReportShare': {'status': 'success', 'at': at.toIso8601String()},
      }),
      '9/19 15:04 공유함',
    );
  });
}
