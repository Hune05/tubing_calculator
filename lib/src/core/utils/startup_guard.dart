// 앱을 켤 때 준비하는 일들이 앱 켜기를 막지 않게 한다.
//
// 🚀 [고침] 알림 준비에 윈도우용 설정이 없었다. flutter_local_notifications는 윈도우에서
// 그 설정이 없으면 오류를 던지고, main이 그것을 기다리므로 runApp까지 가지 못해 PC(윈도우)
// 앱이 아예 켜지지 않을 수 있었다. 서버 알림(FirebaseMessaging)도 윈도우를 지원하지 않는다.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'error_log.dart';

/// 서버 알림(FCM)을 쓸 수 있는 곳인지. 안드로이드·iOS·macOS만.
bool pushMessagingSupported({bool? isWeb, TargetPlatform? platform}) {
  if (isWeb ?? kIsWeb) return false;
  final p = platform ?? defaultTargetPlatform;
  return p == TargetPlatform.android ||
      p == TargetPlatform.iOS ||
      p == TargetPlatform.macOS;
}

/// 켤 때 하는 준비 하나. 실패하거나 [timeout]을 넘겨도 앱 켜기는 이어 가고 오류만 남긴다.
Future<void> startupStep(
  String what,
  Future<void> Function() step, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  try {
    await step().timeout(timeout);
  } catch (e) {
    debugPrint('시작 준비 실패($what): $e');
    unawaited(recordError('시작 준비: $what', e));
  }
}

/// 폰 알림 준비 설정. 윈도우·리눅스 설정도 넣는다(없으면 그 PC에서 오류).
InitializationSettings notificationInitSettings() =>
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      ),
      macOS: DarwinInitializationSettings(),
      windows: WindowsInitializationSettings(
        appName: '튜빙 계산기',
        appUserModelId: 'TubingCalculator.App',
        guid: '9cb65cfc-d23a-47c9-8876-5b1a127ba64b',
      ),
      linux: LinuxInitializationSettings(defaultActionName: '열기'),
    );
