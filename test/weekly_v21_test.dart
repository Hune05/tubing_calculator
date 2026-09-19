import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/backup_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/notification_check_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/retro_overview_page.dart';

import 'helpers_text.dart';

Map<String, dynamic> proj(
  String name, {
  int? remind,
  String status = 'ACTIVE',
}) {
  return {
    'id': name,
    'name': name,
    'status': status,
    'phases': [],
    'schedules': [],
    'punch_lists': [],
    if (remind != null) 'reportReminderMinutes': remind,
    'daily_reports': [],
  };
}

Map<String, dynamic> doneWithCause(String name, String cause) => {
  ...proj(name, status: 'DONE'),
  'completedAt': DateTime.now(),
  'retro': {'cause': cause, 'lesson': ''},
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('오늘 알림 확인 여부', () {
    final logs = [proj('A'), proj('B', remind: 21 * 60)];
    List<ReminderSlot> slots(Set<int> pending) =>
        dailyReminderSlots(logs, 18 * 60, DateTime(2026, 9, 19, 10), pending);
    final both = slots({918300, 918301});

    test('예약 시간 + 30분이 지나기 전에는 아무것도 걸리지 않는다', () {
      expect(
        unconfirmedToday(both, [], DateTime(2026, 9, 19, 18, 20)),
        isEmpty,
      );
    });

    test('18:30이 지나도 기록이 없으면 18:00 알림만 걸린다', () {
      final m = unconfirmedToday(both, [], DateTime(2026, 9, 19, 18, 40));
      expect(m.map((s) => s.plan.minutes).toList(), [18 * 60]);
    });

    test('21:30이 지나면 둘 다 걸린다', () {
      final m = unconfirmedToday(both, [], DateTime(2026, 9, 19, 22));
      expect(m.length, 2);
    });

    test('오늘 그 시간 뒤에 확인된 기록이 있으면 빠진다', () {
      final seen = ['918300|${DateTime(2026, 9, 19, 18, 3).toIso8601String()}'];
      final m = unconfirmedToday(both, seen, DateTime(2026, 9, 19, 22));
      expect(m.map((s) => s.id).toList(), [918301]);
    });

    test('어제 기록은 오늘 확인으로 치지 않는다', () {
      final seen = ['918300|${DateTime(2026, 9, 18, 18, 3).toIso8601String()}'];
      final m = unconfirmedToday(both, seen, DateTime(2026, 9, 19, 19));
      expect(m.length, 1);
    });

    test('폰에 예약되지 않은 것은 여기서 다루지 않는다(예약 안 됨으로 따로 표시)', () {
      final m = unconfirmedToday(slots({}), [], DateTime(2026, 9, 19, 23));
      expect(m, isEmpty);
    });

    test('깨진 기록 줄은 무시한다', () {
      final m = unconfirmedToday(both, [
        '깨짐',
        'a|b|c',
      ], DateTime(2026, 9, 19, 19));
      expect(m.length, 1);
    });

    testWidgets('알림 점검 화면에 참고 문구가 뜬다', (tester) async {
      final n = DateTime.now();
      if (n.hour == 0 && n.minute < 35) return; // 자정 직후에는 30분 조건 때문에 검사할 수 없다
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationCheckPage(
            logs: [proj('자정', remind: 0)],
            pendingIdsLoader: () async => {918300},
            recordActive: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(findTextContaining('오늘 00:00 알림이 아직 확인되지 않았습니다'), findsOneWidget);
    });
  });

  group('원인별 건수', () {
    test('쉼표·줄바꿈·슬래시로 나누고 띄어쓰기·대소문자는 같게 센다', () {
      final r = retroCauseCounts([
        doneWithCause('a', '자재 지연, 인원 부족'),
        doneWithCause('b', '자재지연'),
        doneWithCause('c', '자재 지연/우천\n인원 부족'),
        doneWithCause('d', ''),
        doneWithCause('e', 'PLC 오류'),
        doneWithCause('f', 'plc 오류'),
      ]);
      expect(r, [('자재 지연', 3), ('PLC 오류', 2), ('인원 부족', 2), ('우천', 1)]);
    });

    test('한 프로젝트에 같은 원인이 두 번 적혀도 1건', () {
      expect(retroCauseCounts([doneWithCause('a', '우천, 우천')]), [('우천', 1)]);
    });

    test('원인이 없으면 빈 목록', () {
      expect(retroCauseCounts([doneWithCause('a', '')]), isEmpty);
    });

    testWidgets('원인 줄을 누르면 그 원인으로 검색된다', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: RetroOverviewPage(
            logs: [
              doneWithCause('가동', '자재 지연'),
              doneWithCause('나동', '자재 지연, 우천'),
              doneWithCause('다동', '인원 부족'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(findText('원인별 건수 (누르면 검색)'), findsOneWidget);
      expect(find.text('2건'), findsOneWidget);
      await tester.tap(findText('우천'));
      await tester.pumpAndSettle();
      // 검색창에 원인이 들어가고, 그 원인이 적힌 프로젝트만 남는다.
      expect(find.widgetWithText(TextField, '우천'), findsOneWidget);
      expect(findText('나동'), findsOneWidget);
      expect(findText('가동'), findsNothing);
      expect(findText('다동'), findsNothing);
    });
  });

  group('복원 미리 보기', () {
    BackupPreview backup(List<Map<String, dynamic>> ps) =>
        BackupPreview(ps.length, 0, null, {'projects': ps});

    test('새로 들어오는 것·덮어쓰는 것·그대로 두는 것을 나눈다', () {
      final plan = planRestore(
        backup([
          {'id': '1', 'name': '기존A'},
          {'id': '2', 'name': '새B'},
          {'id': '3', 'name': ''},
        ]),
        [
          {'id': '1', 'name': '기존A(현재)'},
          {'id': '9', 'name': '백업에 없음'},
          {'id': '8', 'name': '이것도 없음'},
        ],
      );
      expect(plan.overwritten, ['기존A']);
      expect(plan.added, ['새B', '이름 없음']);
      expect(plan.untouched, 2);
    });

    test('id가 없는 항목은 세지 않는다(복원에서도 건너뛴다)', () {
      final plan = planRestore(
        backup([
          {'name': 'id없음'},
        ]),
        [],
      );
      expect(plan.added, isEmpty);
      expect(plan.overwritten, isEmpty);
    });

    test('현재 프로젝트가 하나도 없으면 전부 새로 들어온다', () {
      final plan = planRestore(
        backup([
          {'id': '1', 'name': 'A'},
        ]),
        [],
      );
      expect(plan.added, ['A']);
      expect(plan.untouched, 0);
    });
  });

  group('안내 메시지가 화면을 계속 가리지 않게', () {
    test('되돌리기·작성 같은 버튼이 달린 안내는 모두 persist:false', () {
      final dir = Directory('lib/src/presentation/my_work_logs');
      final bad = <String>[];
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final isAction =
              lines[i].contains('SnackBarAction(') ||
              lines[i].contains('action: _retroFilled');
          if (!isAction) continue;
          final from = i < 6 ? 0 : i - 6;
          final near = lines.sublist(from, i + 1).join('\n');
          if (!near.contains('persist: false')) bad.add('${f.path}:${i + 1}');
        }
      }
      expect(bad, isEmpty, reason: 'persist: false가 없는 안내: $bad');
    });
  });
}
