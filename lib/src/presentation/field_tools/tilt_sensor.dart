// 기울기 센서 읽기. 화면은 이 흐름만 받아서, 검사할 때는 가짜 값을 넣는다.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/utils/app_settings_controller.dart';

/// 가속도 한 번(x·y·z, m/s²).
typedef TiltSample = ({double x, double y, double z});

/// 폰 가속도 센서. 센서가 없는 기기(PC 등)면 오류로 끝난다.
Stream<TiltSample> deviceTiltStream() => accelerometerEventStream(
  samplingPeriod: SensorInterval.uiInterval,
).map((e) => (x: e.x, y: e.y, z: e.z));

/// 각도기용 빠른 센서(1초 약 50번, 10-15). 1초 15번이면 [기준 잡기] 직전 평균에 값이 7개뿐이라
/// 흔들림이 컸다. 대신 화면 쪽 누그러뜨리기를 그만큼 느리게 한다(protractor_page).
Stream<TiltSample> fastTiltStream() => accelerometerEventStream(
  samplingPeriod: SensorInterval.gameInterval,
).map((e) => (x: e.x, y: e.y, z: e.z));

/// 진동·소리 알림(10-15). HapticFeedback은 폰 "터치 진동"이 꺼져 있으면 아무것도 안 해서
/// 진동기를 직접 울린다(MainActivity "field/feedback"). 소리는 터치음 설정과 상관없다.
class FieldFeedback {
  static const _ch = MethodChannel('field/feedback');

  static void vibrate(int ms) {
    _ch.invokeMethod('vibrate', {'ms': ms}).catchError((_) {
      HapticFeedback.heavyImpact();
    });
  }

  static void beep(int ms) {
    _ch.invokeMethod('beep', {'ms': ms}).catchError((_) {});
  }
}

/// 수평계·각도기 화면을 여는 동안: 화면 꺼짐 막기 + 세로 고정.
/// 닫을 때는 설정의 "화면 꺼짐 방지" 값과 모든 방향으로 되돌린다.
class FieldToolSession {
  bool _on = false;

  void begin() {
    if (_on) return;
    _on = true;
    _safe(() => WakelockPlus.enable());
    _safe(
      () =>
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    );
  }

  void end() {
    if (!_on) return;
    _on = false;
    final keep = AppSettingsController().keepScreenOn;
    _safe(() => keep ? WakelockPlus.enable() : WakelockPlus.disable());
    _safe(() => SystemChrome.setPreferredOrientations(const []));
  }

  // 플러그인이 없는 곳(검사·일부 PC)에서도 죽지 않게.
  void _safe(Future<void> Function() f) {
    try {
      f().catchError((_) {});
    } catch (_) {}
  }
}
