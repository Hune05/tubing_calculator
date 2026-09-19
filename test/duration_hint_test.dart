import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/duration_hint.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_phase.dart'
    show kProjectTypes;
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/create_log_sheet.dart';

import 'helpers_text.dart';

String md(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

// 완료한 프로젝트: 작업 일지 [days]+1일치, 계획 [planned]일.
Map<String, dynamic> done(
  String type, {
  required int days,
  int? planned,
  String status = 'DONE',
}) {
  final end = DateTime(2026, 9, 1);
  final start = end.subtract(Duration(days: days));
  return {
    'id': '${type}_$days',
    'name': '$type $days',
    'status': status,
    'workType': type,
    'completedAt': end,
    'phases': planned == null
        ? []
        : [
            {
              'id': 'p',
              'name': '설치',
              'isCompleted': true,
              'startDate': start,
              'endDate': start.add(Duration(days: planned - 1)),
            },
          ],
    'schedules': [],
    'punch_lists': [],
    'daily_reports': [
      for (var i = 0; i <= days; i++)
        {
          'date': md(start.add(Duration(days: i))),
          'dateISO': start.add(Duration(days: i)).toIso8601String(),
          'worker_count': 1,
        },
    ],
  };
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final type = kProjectTypes.first;

  group('예상 기간 계산', () {
    test('같은 유형으로 완료한 프로젝트의 실제 평균과 계획 평균', () {
      final h = durationHintFor([
        done(type, days: 3, planned: 5), // 실제 4일, 계획 5일
        done(type, days: 5, planned: 7), // 실제 6일, 계획 7일
      ], type)!;
      expect(h.count, 2);
      expect(h.avgActual, 5);
      expect(h.avgPlanned, 6);
    });

    test('완료하지 않은 것·다른 유형은 세지 않는다', () {
      final h = durationHintFor([
        done(type, days: 3),
        done(type, days: 9, status: 'ACTIVE'),
        done('다른 유형', days: 20),
      ], type)!;
      expect(h.count, 1);
      expect(h.avgActual, 4);
    });

    test('계획이 없으면 계획 평균은 비운다', () {
      final h = durationHintFor([done(type, days: 3)], type)!;
      expect(h.avgPlanned, isNull);
      expect(durationHintText(h), '이 유형은 완료한 1건이 평균 4일 걸렸습니다.');
    });

    test('참고할 것이 없으면 null', () {
      expect(durationHintFor([], type), isNull);
      expect(durationHintFor([done('다른 유형', days: 3)], type), isNull);
      final noReports = done(type, days: 3)..['daily_reports'] = [];
      expect(durationHintFor([noReports], type), isNull);
    });

    test('문구', () {
      final h = durationHintFor([done(type, days: 11, planned: 10)], type)!;
      expect(durationHintText(h), '이 유형은 완료한 1건이 평균 12일 걸렸습니다(계획 평균 10일).');
    });

    test('계획·실제 일수 계산이 결과 정리 모아보기와 같다', () {
      final l = done(type, days: 7, planned: 9);
      expect(plannedDaysOf(l), 9);
      expect(actualDaysOf(l), 8);
    });
  });

  group('새 프로젝트 화면', () {
    Future<void> open(
      WidgetTester tester,
      List<Map<String, dynamic>> logs,
    ) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CreateLogSheet(existingLogs: logs)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('유형을 고르면 걸린 기간 참고가 나온다', (tester) async {
      await open(tester, [done(type, days: 11, planned: 10)]);
      expect(findTextContaining('평균'), findsNothing);
      await tester.tap(find.text(type));
      await tester.pumpAndSettle();
      expect(
        findText('이 유형은 완료한 1건이 평균 12일 걸렸습니다(계획 평균 10일).'),
        findsOneWidget,
      );
    });

    testWidgets('참고할 것이 없는 유형이면 아무것도 나오지 않는다', (tester) async {
      await open(tester, [done('다른 유형', days: 3)]);
      await tester.tap(find.text(type));
      await tester.pumpAndSettle();
      expect(findTextContaining('걸렸습니다'), findsNothing);
    });

    testWidgets('유형 선택을 풀면 참고도 사라진다', (tester) async {
      await open(tester, [done(type, days: 3)]);
      await tester.tap(find.text(type));
      await tester.pumpAndSettle();
      expect(findTextContaining('걸렸습니다'), findsOneWidget);
      await tester.tap(find.text(type));
      await tester.pumpAndSettle();
      expect(findTextContaining('걸렸습니다'), findsNothing);
    });

    testWidgets('예전처럼 목록 없이 열어도 동작한다', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CreateLogSheet())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(type));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
