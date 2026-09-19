import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/error_log.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/app_status_page.dart';

import 'helpers_text.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('오류 기록', () {
    final t = DateTime(2026, 9, 19, 21, 5);

    test('한 줄로 저장하고 다시 읽는다', () {
      final raw = addErrorLog([], t, '알림 예약', 'boom\n두 번째 줄   공백');
      final e = parseErrorLog(raw).single;
      expect(e.at, t);
      expect(e.where, '알림 예약');
      expect(e.message, 'boom 두 번째 줄 공백'); // 줄바꿈·연속 공백은 한 칸으로
    });

    test('아주 긴 내용은 잘린다', () {
      final raw = addErrorLog([], t, '위치', 'x' * 1000);
      final m = parseErrorLog(raw).single.message;
      expect(m.length, lessThanOrEqualTo(301));
      expect(m.endsWith('…'), true);
    });

    test('최근 20개만 남는다', () {
      var raw = <String>[];
      for (var i = 0; i < 25; i++) {
        raw = addErrorLog(raw, t.add(Duration(minutes: i)), '위치', '오류 $i');
      }
      final p = parseErrorLog(raw);
      expect(p.length, 20);
      expect(p.first.message, '오류 5');
      expect(p.last.message, '오류 24');
    });

    test('깨진 줄은 건너뛴다', () {
      final raw = ['깨짐', '날짜아님위치내용', ...addErrorLog([], t, '위치', '정상')];
      expect(parseErrorLog(raw).map((e) => e.message).toList(), ['정상']);
    });

    test('내용에 구분 문자가 있어도 잃지 않는다', () {
      final raw = addErrorLog([], t, '위치', 'ab');
      expect(parseErrorLog(raw).single.message, 'ab');
    });

    test('보내기 쉬운 글은 최근 것이 위', () {
      var raw = addErrorLog([], t, '가', '첫째');
      raw = addErrorLog(raw, t.add(const Duration(minutes: 3)), '나', '둘째');
      final text = errorsAsText(parseErrorLog(raw));
      expect(text.split('\n').first, '9/19 21:08 [나] 둘째');
      expect(text.split('\n').last, '9/19 21:05 [가] 첫째');
      expect(errorsAsText([]), '기록된 오류가 없습니다.');
    });

    test('기록·읽기·지우기가 실제로 저장소를 거친다', () async {
      await recordError('시험', StateError('boom'), at: t);
      final l = await loadErrors();
      expect(l.single.where, '시험');
      expect(l.single.message.contains('boom'), true);
      await clearErrors();
      expect(await loadErrors(), isEmpty);
    });
  });

  group('앱 상태 화면', () {
    Future<void> open(
      WidgetTester tester, {
      bool allowed = true,
      bool exact = true,
      Future<bool> Function()? server,
      DateTime? backup,
      int waiting = 0,
      List<ErrorEntry> errors = const [],
      Future<void> Function()? clearer,
    }) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: AppStatusPage(
            notificationsAllowed: () async => allowed,
            exactAllowed: () async => exact,
            pendingCount: () async => 3,
            serverReachable: server ?? () async => true,
            lastBackup: () async => backup,
            pendingWrites: () => waiting,
            errorsLoader: () async => errors,
            errorsClearer: clearer,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('모두 정상이면 정상 문구가 보인다', (tester) async {
      await open(
        tester,
        backup: DateTime.now().subtract(const Duration(hours: 3)),
      );
      expect(find.text('알림 권한'), findsOneWidget);
      expect(findText('허용됨'), findsNWidgets(2)); // 알림 권한, 정확한 시간 알림
      expect(findText('3개'), findsOneWidget);
      expect(findText('연결됨'), findsOneWidget);
      expect(findTextContaining('3시간 전'), findsOneWidget);
      expect(findText('없음'), findsOneWidget); // 서버에 올리는 중인 저장
      expect(find.text('기록된 오류가 없습니다.'), findsOneWidget);
    });

    testWidgets('문제가 있으면 무엇을 하면 되는지 함께 보인다', (tester) async {
      await open(
        tester,
        allowed: false,
        exact: false,
        server: () async => throw StateError('offline'),
        waiting: 2,
      );
      expect(findTextContaining('꺼져 있음'), findsOneWidget);
      expect(findTextContaining('최대 1시간 늦을 수 있습니다'), findsOneWidget);
      expect(findTextContaining('연결하지 못함'), findsOneWidget);
      expect(findTextContaining('2건'), findsOneWidget);
      expect(findText('아직 없음'), findsOneWidget); // 백업 기록 없음
    });

    testWidgets('오래된 백업은 주의로 보이되 날짜는 나온다', (tester) async {
      await open(
        tester,
        backup: DateTime.now().subtract(const Duration(days: 20)),
      );
      expect(findTextContaining('20일 전'), findsOneWidget);
    });

    testWidgets('오류 기록이 있으면 목록·복사·지우기가 나온다', (tester) async {
      var cleared = 0;
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await open(
        tester,
        errors: [ErrorEntry(DateTime(2026, 9, 19, 20, 0), '알림 예약', '실패했습니다')],
        clearer: () async => cleared++,
      );
      expect(find.text('1건'), findsOneWidget);
      expect(find.textContaining('[알림 예약]'), findsOneWidget);
      await tester.tap(find.text('오류 기록 복사'));
      await tester.pumpAndSettle();
      expect(copied, contains('[알림 예약] 실패했습니다'));
      await tester.tap(find.text('기록 지우기'));
      await tester.pumpAndSettle();
      expect(cleared, 1);
    });

    testWidgets('조회가 실패해도 화면이 죽지 않고 확인하지 못함으로 보인다', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: AppStatusPage(
            notificationsAllowed: () async => throw StateError('x'),
            exactAllowed: () async => throw StateError('x'),
            pendingCount: () async => throw StateError('x'),
            serverReachable: () async => true,
            lastBackup: () async => throw StateError('x'),
            pendingWrites: () => 0,
            errorsLoader: () async => throw StateError('x'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(findText('확인하지 못함'), findsNWidgets(3));
    });
  });
}
