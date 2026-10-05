// 안드로이드 홈 화면 위젯("빠른 실행", "오늘 요약")과 주고받는 곳.
// 위젯은 통신 없이 앱이 넘겨 둔 자료만 그린다(MainActivity의 FieldWidgetStore).
// - 앱 → 위젯: [push]로 빠른 실행 제목들, 오늘 요약 값, 출퇴근 상태를 넘긴다(같은 값이면 안 보낸다).
// - 위젯 → 앱: 위젯을 누르면 앱이 열리면서 동작("quick:제목" 등)이 넘어와 [pendingAction]에 놓인다.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 위젯을 눌러 들어온 동작. 같은 동작이 다시 와도 새 값으로 알려지도록 객체로 둔다.
class HomeWidgetAction {
  final String action;
  const HomeWidgetAction(this.action);

  /// 출퇴근 위젯 단추: "attendance:in"·"attendance:out"·"attendance:open" → in·out·open. 아니면 null.
  String? get attendanceAction =>
      action.startsWith('attendance:') && action.length > 11
      ? action.substring(11)
      : null;

  /// 압력시험 위젯을 눌러 들어왔나(시험 기록 탭을 연다).
  bool get isPressureOpen => action == 'pressure:open';

  /// "quick:내 프로젝트" → "내 프로젝트". 빠른 실행 동작이 아니면 null.
  String? get quickTitle => action.startsWith('quick:') && action.length > 6
      ? action.substring(6)
      : null;
}

/// 빠른 실행 위젯에 넘길 값: 제목 목록(JSON). 위젯은 네 개까지만 그린다.
String encodeQuickWidgetPayload(List<String> titles) =>
    jsonEncode(titles.where((t) => t.trim().isNotEmpty).take(4).toList());

/// 오늘 요약 위젯에 넘길 값(JSON). 모르는 값(아직 못 읽음)은 null로 두면 위젯에 "—"로 나온다.
String encodeSummaryWidgetPayload({
  required String date,
  int? schedule,
  int? reports,
  int? stock,
  String? attendance,
  required String updatedAt,
}) => jsonEncode({
  'date': date,
  'schedule': schedule,
  'reports': reports,
  'stock': stock,
  'attendance': attendance ?? '',
  'updatedAt': updatedAt,
});

class HomeWidgetSync {
  static const MethodChannel _ch = MethodChannel('field/widget');

  /// 위젯을 눌러 들어온 동작(아직 처리 안 한 것). 처리한 쪽이 null로 비운다.
  static final ValueNotifier<HomeWidgetAction?> pendingAction = ValueNotifier(
    null,
  );

  static String? _lastQuick;
  static String? _lastSummary;
  static String? _lastPt;

  /// 앱을 켤 때 한 번 부른다. 앱이 떠 있는 동안 위젯이 눌리면 [onReceived]를 먼저 부른다
  /// (예: 열려 있던 화면을 닫고 홈으로 돌아가기).
  static void init({VoidCallback? onReceived}) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'received') {
        onReceived?.call();
        await _take();
      }
    });
    _take(); // 앱이 꺼져 있을 때 위젯으로 열린 경우.
  }

  static Future<void> _take() async {
    try {
      final a = await _ch.invokeMethod<String>('takeAction');
      if (a == null || a.isEmpty) return;
      pendingAction.value = HomeWidgetAction(a);
    } on MissingPluginException {
      // 안드로이드가 아닌 곳(테스트·아이폰)
    } catch (e) {
      debugPrint('위젯 동작 가져오기 실패: $e');
    }
  }

  /// 위젯에 자료를 넘긴다. [quickJson]·[summaryJson] 중 바뀐 것만 보낸다.
  static Future<void> push({
    String? quickJson,
    String? summaryJson,
    String? clockJson,
    String? ptJson,
  }) async {
    final sendQuick = quickJson != null && quickJson != _lastQuick;
    final sendSummary = summaryJson != null && summaryJson != _lastSummary;
    // 출퇴근 값은 위젯 단추가 앱 밖에서 바꿀 수 있어(ClockPunch.kt) 같은 값이어도 늘 새로 보낸다.
    final sendClock = clockJson != null;
    final sendPt = ptJson != null && ptJson != _lastPt;
    if (!sendQuick && !sendSummary && !sendClock && !sendPt) return;
    try {
      await _ch.invokeMethod<void>('update', {
        if (sendQuick) 'quick': quickJson,
        if (sendSummary) 'summary': summaryJson,
        if (sendClock) 'clock': clockJson,
        if (sendPt) 'pt': ptJson,
      });
      if (sendQuick) _lastQuick = quickJson;
      if (sendSummary) _lastSummary = summaryJson;
      if (sendPt) _lastPt = ptJson;
    } on MissingPluginException {
      // 안드로이드가 아닌 곳
    } catch (e) {
      debugPrint('위젯 자료 보내기 실패: $e');
    }
  }

  /// 퇴근 깜빡 알림을 안드로이드(알람)에 예약한다. [at]이 없으면 예약을 취소한다.
  /// 위젯 단추로 출근했을 때는 안드로이드가 설정을 읽어 스스로 예약한다(ClockReminder.kt).
  static Future<void> setClockOutReminder(DateTime? at) async {
    try {
      await _ch.invokeMethod<void>('clockOutReminder', {
        'at': at?.millisecondsSinceEpoch,
      });
    } on MissingPluginException {
      // 안드로이드가 아닌 곳
    } catch (e) {
      debugPrint('퇴근 알림 예약 실패: $e');
    }
  }

  /// 시험용: 마지막으로 보낸 값을 잊는다.
  @visibleForTesting
  static void resetForTest() {
    _lastQuick = null;
    _lastSummary = null;
    _lastPt = null;
    pendingAction.value = null;
  }
}
