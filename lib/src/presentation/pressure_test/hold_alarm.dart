// 압력 시험 유지시간 완료 알림(폰 예약 알림). 앱을 나가거나 화면을 꺼도 끝나는 시각에 울린다.
// 번호 918400 하나만 쓰므로 다시 예약하면 앞의 것을 바꾼다. 종료·새로 시작·불러오기 때 취소한다.
// 알림 플러그인이 준비되지 않았거나(위젯 시험·웹) 실패해도 화면은 그대로 동작한다.
//
// 플러그인은 앱이 main.dart에서 초기화한 것과 같은 하나(FlutterLocalNotificationsPlugin()은 싱글턴)를 쓴다.
// 권한 묻기·예약 방식은 my_work_logs/models/reminder_tools.dart의 ensureNotificationPermission·
// reminderScheduleMode와 같은 규칙이다. 그 파일은 main.dart를 가져와 계산기가 앱 전체에 묶이므로
// 가져오지 않고 같은 규칙을 여기 둔다(권한 물음 기록 키도 같은 'notif_permission_asked_v1').
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'pressure_units.dart';

const int kPtHoldNotifId = 918400;
const String kPtHoldChannelId = 'pressure_test_hold';
const String kPtHoldChannelName = '압력 시험 알림';
const String kPtHoldChannelDesc = '압력 시험 유지시간 완료 알림';
const String kPtHoldTitle = '압력 시험 유지시간 완료';

/// 알림 권한을 이미 물었는지(reminder_tools.dart와 같은 키: 앱 전체에서 한 번만 묻는다).
const String _kNotifPermAsked = 'notif_permission_asked_v1';

/// 알림 본문: 라인 번호(있으면)와 유지시간.
String ptHoldBody({required String line, required double holdMin}) {
  final who = line.trim().isEmpty ? '' : '${line.trim()} ';
  return '$who유지시간 ${ptFmt(holdMin, 1)}분이 지났습니다. 종료 압력을 기록하십시오.';
}

/// 유지시간 완료 알림. 시험에서는 가짜로 바꿔 넣는다.
abstract class HoldAlarm {
  const HoldAlarm();

  /// [at]에 울리게 예약한다(같은 번호의 앞 예약은 바뀐다).
  Future<void> schedule(
    DateTime at, {
    required String title,
    required String body,
  });

  /// 예약을 취소한다(이미 떠 있는 알림도 지운다).
  Future<void> cancel();

  /// 정확한 알람을 쓸 수 있는지. 안드로이드가 아니거나 알 수 없으면 true(안내 줄을 띄우지 않는다).
  Future<bool> canExact() async => true;

  /// 폰 설정의 "알람 및 리마인더" 허용 화면을 연다. 돌아와서 허용돼 있으면 true.
  Future<bool> requestExact() async => true;
}

/// 정확한 알람이 꺼져 있을 때 타이머 아래에 띄우는 글.
const String kPtExactOffText = '정확한 알람이 꺼져 있어 알림이 몇 분 늦을 수 있습니다.';

/// 앱의 알림 플러그인으로 예약한다. 모든 호출을 try/catch로 감싼다.
class PluginHoldAlarm extends HoldAlarm {
  const PluginHoldAlarm();

  static bool _tzReady = false;
  static bool _channelReady = false;

  static FlutterLocalNotificationsPlugin get _plugin =>
      FlutterLocalNotificationsPlugin();

  static AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  static void _ensureTz() {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    _tzReady = true;
  }

  static Future<void> _ensureChannel() async {
    if (_channelReady) return;
    const channel = AndroidNotificationChannel(
      kPtHoldChannelId,
      kPtHoldChannelName,
      description: kPtHoldChannelDesc,
      importance: Importance.high,
    );
    await _android?.createNotificationChannel(channel);
    _channelReady = true;
  }

  /// 알림 권한을 처음 한 번만 묻는다(이미 물었으면 그냥 돌아온다).
  static Future<void> _ensurePermission() async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_kNotifPermAsked) == true) return;
    await p.setBool(_kNotifPermAsked, true);
    await _android?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// 정확한 알람이 허용돼 있으면 정확한 시각, 아니면 폰이 묶어서 보내는 방식(늦을 수 있다).
  static Future<AndroidScheduleMode> _mode() async {
    try {
      return await _android?.canScheduleExactNotifications() == true
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  @override
  Future<void> schedule(
    DateTime at, {
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    try {
      await _ensurePermission();
      _ensureTz();
      await _ensureChannel();
      await _plugin.cancel(id: kPtHoldNotifId);
      await _plugin.zonedSchedule(
        id: kPtHoldNotifId,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            kPtHoldChannelId,
            kPtHoldChannelName,
            channelDescription: kPtHoldChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: await _mode(),
      );
    } catch (e) {
      debugPrint('압력 시험 알림 예약 실패: $e');
    }
  }

  @override
  Future<void> cancel() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(id: kPtHoldNotifId);
    } catch (e) {
      debugPrint('압력 시험 알림 취소 실패: $e');
    }
  }

  // 정확한 알람(SCHEDULE_EXACT_ALARM)이 없으면 안드로이드가 inexact로 묶어 보낸다.
  // 폰 시험(09-26): 14:50:42 예약이 14:56:11에 왔다(약 +7.5분 창). reminder_tools.dart의
  // canScheduleExactAlarms·requestExactAlarmPermission과 같은 호출(플러그인 21.x)을 여기 둔다.
  @override
  Future<bool> canExact() async {
    if (kIsWeb) return true;
    try {
      final a = _android;
      if (a == null) return true;
      return await a.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> requestExact() async {
    if (kIsWeb) return true;
    try {
      final a = _android;
      if (a == null) return true;
      await a.requestExactAlarmsPermission();
      return await a.canScheduleExactNotifications() ?? false;
    } catch (e) {
      debugPrint('정확한 알람 허용 화면 열기 실패: $e');
      return false;
    }
  }
}
