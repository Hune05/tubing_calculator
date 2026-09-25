// 앱을 켤 때 준비가 앱 켜기를 막지 않는지(점검 24번: 윈도우 PC).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/startup_guard.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('알림 준비 설정에 윈도우·리눅스 설정이 들어 있다', () {
    final s = notificationInitSettings();
    // 예전: android·iOS만 있어 윈도우에서 오류를 던졌다.
    expect(s.windows, isNotNull);
    expect(s.windows!.guid, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(s.linux, isNotNull);
    expect(s.android, isNotNull);
  });

  test('서버 알림은 안드로이드·iOS·macOS에서만', () {
    expect(
      pushMessagingSupported(isWeb: false, platform: TargetPlatform.android),
      isTrue,
    );
    expect(
      pushMessagingSupported(isWeb: false, platform: TargetPlatform.iOS),
      isTrue,
    );
    expect(
      pushMessagingSupported(isWeb: false, platform: TargetPlatform.windows),
      isFalse,
    );
    expect(
      pushMessagingSupported(isWeb: false, platform: TargetPlatform.linux),
      isFalse,
    );
    expect(
      pushMessagingSupported(isWeb: true, platform: TargetPlatform.android),
      isFalse,
    );
  });

  test('준비 하나가 오류를 던져도 다음으로 넘어간다', () async {
    var next = false;
    await startupStep('알림 준비', () async => throw ArgumentError('windows'));
    next = true;
    expect(next, isTrue);
  });

  testWidgets('준비 하나가 끝나지 않아도 제한 시간 뒤 넘어간다', (tester) async {
    var done = false;
    unawaited(
      startupStep(
        '멈춘 준비',
        () => Completer<void>().future,
        timeout: const Duration(seconds: 3),
      ).then((_) => done = true),
    );
    await tester.pump(const Duration(seconds: 4));
    expect(done, isTrue);
  });
}
