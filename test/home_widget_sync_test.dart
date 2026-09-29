// 홈 화면 위젯 자료 넘기기: 값 만들기, 같은 값은 다시 안 보내기, 위젯 눌림 동작 받기.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/utils/home_widget_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('field/widget');
  final calls = <MethodCall>[];
  String? nextAction;

  setUp(() {
    calls.clear();
    nextAction = null;
    HomeWidgetSync.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (call) async {
          calls.add(call);
          if (call.method == 'takeAction') {
            final a = nextAction;
            nextAction = null;
            return a;
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, null);
  });

  group('값 만들기', () {
    test('빠른 실행은 빈 제목을 빼고 네 개까지만', () {
      final j = encodeQuickWidgetPayload(['가', ' ', '나', '다', '라', '마']);
      expect(jsonDecode(j), ['가', '나', '다', '라']);
    });

    test('오늘 요약: 못 읽은 값은 null로, 근태는 빈 글로', () {
      final j = jsonDecode(
        encodeSummaryWidgetPayload(
          date: '9월 29일 (화)',
          schedule: 2,
          updatedAt: '11:30',
        ),
      );
      expect(j['date'], '9월 29일 (화)');
      expect(j['schedule'], 2);
      expect(j['reports'], isNull);
      expect(j['stock'], isNull);
      expect(j['attendance'], '');
      expect(j['updatedAt'], '11:30');
    });

    test('위젯 동작에서 빠른 실행 제목을 꺼낸다', () {
      expect(const HomeWidgetAction('quick:내 프로젝트').quickTitle, '내 프로젝트');
      expect(const HomeWidgetAction('open').quickTitle, isNull);
      expect(const HomeWidgetAction('quick:').quickTitle, isNull);
    });
  });

  group('앱 → 위젯', () {
    test('바뀐 값만 보내고 같은 값은 다시 안 보낸다', () async {
      await HomeWidgetSync.push(quickJson: '["가"]');
      await HomeWidgetSync.push(quickJson: '["가"]');
      await HomeWidgetSync.push(quickJson: '["가","나"]', summaryJson: '{}');
      final updates = calls.where((c) => c.method == 'update').toList();
      expect(updates.length, 2);
      expect((updates[0].arguments as Map)['quick'], '["가"]');
      expect((updates[0].arguments as Map).containsKey('summary'), isFalse);
      expect((updates[1].arguments as Map)['summary'], '{}');
    });

    test('안드로이드 쪽이 없어도(시험·아이폰) 오류 없이 넘어간다', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, null);
      await HomeWidgetSync.push(quickJson: '["가"]');
    });
  });

  group('위젯 → 앱', () {
    test('앱이 꺼져 있을 때 위젯으로 열린 동작을 시작할 때 받는다', () async {
      nextAction = 'quick:공학용 계산기';
      HomeWidgetSync.init();
      await Future<void>.delayed(Duration.zero);
      expect(HomeWidgetSync.pendingAction.value?.quickTitle, '공학용 계산기');
    });

    test('앱이 떠 있을 때 받으면 onReceived를 먼저 부른다', () async {
      var called = 0;
      HomeWidgetSync.init(onReceived: () => called++);
      await Future<void>.delayed(Duration.zero);
      nextAction = 'quick:내 프로젝트';
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'field/widget',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('received'),
            ),
            (_) {},
          );
      await Future<void>.delayed(Duration.zero);
      expect(called, 1);
      expect(HomeWidgetSync.pendingAction.value?.quickTitle, '내 프로젝트');
    });
  });
}
