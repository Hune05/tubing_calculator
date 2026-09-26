// 수평계·각도기가 쓰는 셈. 화면·센서와 떼어 놓아서 폰 없이 검사할 수 있게 한다.
//
// 가속도 센서 값(x, y, z)은 폰이 가만히 있을 때 "위쪽"을 가리킨다(크기 약 9.8).
// 축: x = 화면 오른쪽, y = 화면 위쪽, z = 화면 밖(나를 향함). 화면은 세로로 고정해서 쓴다.
import 'dart:math' as math;

/// 폰이 놓인 모양.
enum TiltPose {
  /// 바닥에 눕힘(화면이 위) — 둥근 기포.
  flat,

  /// 아래 짧은 변으로 세움(세로) — 가로 기포관(x축).
  upright,

  /// 긴 변으로 세움(옆으로) — 세로 기포관(y축).
  sideways,
}

double _deg(double rad) => rad * 180 / math.pi;

/// 한 축이 수평면에서 얼마나 들렸는지(°). 위로 들리면 +.
/// [axis]는 그 축의 센서 값, [x]·[y]·[z]는 전체(크기를 셈).
double axisElevation(double axis, double x, double y, double z) {
  final g = math.sqrt(x * x + y * y + z * z);
  if (g == 0) return 0;
  return _deg(math.asin((axis / g).clamp(-1.0, 1.0)));
}

/// 폰이 놓인 모양을 고른다. 바뀌는 순간 왔다 갔다 하지 않게, 지금 모양이면
/// 조금 더 너그럽게 본다(가장 큰 축이 [hold] 배 이상 커야 바꾼다).
TiltPose poseFor(
  double x,
  double y,
  double z, {
  TiltPose? current,
  double hold = 1.15,
}) {
  final ax = x.abs(), ay = y.abs(), az = z.abs();
  TiltPose best;
  if (az >= ax && az >= ay) {
    best = TiltPose.flat;
  } else if (ay >= ax) {
    best = TiltPose.upright;
  } else {
    best = TiltPose.sideways;
  }
  if (current == null || current == best) return best;
  final cur = switch (current) {
    TiltPose.flat => az,
    TiltPose.upright => ay,
    TiltPose.sideways => ax,
  };
  final top = switch (best) {
    TiltPose.flat => az,
    TiltPose.upright => ay,
    TiltPose.sideways => ax,
  };
  return top > cur * hold ? best : current;
}

/// 화면 평면 안에서 폰이 돌아간 각(°, -180~180). 세로로 세우면 0,
/// 오른쪽으로 눕혀 세우면 -90, 왼쪽이면 +90 쪽. 각도기(벤딩 각도 재기)가 쓴다.
double screenRotation(double x, double y) => _deg(math.atan2(x, y));

/// 두 각의 차이를 -180~180으로.
double angleDiff(double a, double b) {
  var d = (a - b) % 360;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d;
}

/// 폰이 너무 눕혀져서 화면 평면 안의 돌림을 믿을 수 없는지(각도기용).
/// 화면이 수평에서 [maxLean]° 넘게 세워져 있어야 믿는다.
bool tooFlatForRotation(double x, double y, double z, {double maxLean = 35}) {
  final screenUp = axisElevation(z, x, y, z).abs(); // 화면이 하늘을 보는 정도
  return screenUp > 90 - maxLean;
}

/// 기울기 단위.
enum SlopeUnit { degree, percent, mmPerM }

String slopeUnitLabel(SlopeUnit u) => switch (u) {
  SlopeUnit.degree => '°',
  SlopeUnit.percent => '%',
  SlopeUnit.mmPerM => 'mm/m',
};

/// 각(°)을 단위로 바꾼 값. 퍼센트 = tan×100, mm/m = tan×1000(배관 구배).
double slopeIn(double deg, SlopeUnit u) {
  if (u == SlopeUnit.degree) return deg;
  final t = math.tan(deg * math.pi / 180);
  return u == SlopeUnit.percent ? t * 100 : t * 1000;
}

/// 화면에 보일 글. 도는 소수 한 자리, 퍼센트는 두 자리, mm/m는 한 자리.
/// [decimals]를 끄면 한 자리씩 줄인다(도·mm/m는 정수, 퍼센트는 한 자리).
String formatSlope(double deg, SlopeUnit u, {bool decimals = true}) {
  final v = slopeIn(deg, u);
  final digits = (u == SlopeUnit.percent ? 2 : 1) - (decimals ? 0 : 1);
  final s = v.abs().toStringAsFixed(digits);
  return '$s${slopeUnitLabel(u)}';
}

/// 수평으로 볼 수 있는지(°).
bool isLevel(double deg, {double within = 0.3}) => deg.abs() <= within;

/// 기포가 옮겨 갈 자리(-1~1). 기포는 높은 쪽으로 간다.
/// [deg]가 [fullScale]°일 때 끝에 닿는다.
double bubbleOffset(double deg, {double fullScale = 10}) =>
    (deg / fullScale).clamp(-1.0, 1.0);

/// 센서 값 흔들림을 누그러뜨린다(지수 평균). [alpha]가 작을수록 부드럽고 느리다.
class TiltSmoother {
  final double alpha;
  double? _x, _y, _z;
  TiltSmoother({this.alpha = 0.15});

  ({double x, double y, double z}) add(double x, double y, double z) {
    if (_x == null) {
      _x = x;
      _y = y;
      _z = z;
    } else {
      _x = _x! + alpha * (x - _x!);
      _y = _y! + alpha * (y - _y!);
      _z = _z! + alpha * (z - _z!);
    }
    return (x: _x!, y: _y!, z: _z!);
  }

  void reset() => _x = _y = _z = null;
}

/// 화면에 보이는 각을 덜 떨게 한다. 폰 센서는 가만히 둬도 0.1~0.3°씩 흔들려 숫자가
/// 계속 바뀌었다(2026-09-26 사용자: "감도가 너무 높다"). 새 값이 보이는 값에서 [band]°
/// 넘게 벗어날 때만 바꾸고, 그 안에서 [settle]번 머물면 실제 값으로 맞춘다 — 떨지 않고,
/// 멈추면 정확하다.
class AngleDeadband {
  final double band;
  final int settle;
  double? _shown;
  int _still = 0;
  AngleDeadband({this.band = 0.3, this.settle = 8});

  double apply(double v) {
    final s = _shown;
    if (s == null || (v - s).abs() > band) {
      _shown = v;
      _still = 0;
      return v;
    }
    if (++_still >= settle) {
      _shown = v;
      _still = 0;
    }
    return _shown!;
  }

  void reset() {
    _shown = null;
    _still = 0;
  }
}

/// 각도 글: [decimals]면 소수 한 자리, 아니면 정수(1°). 폰 센서로 잰 벤딩 각은
/// ±0.5~1°가 한계라 기본은 정수다.
String formatAngle(double deg, {bool decimals = false}) =>
    '${decimals ? deg.toStringAsFixed(1) : deg.round().toString()}°';

/// 화면 각도기: 가운데에서 [p] 쪽을 가리키는 각(°, 0 = 오른쪽, 위로 +, 0~180으로 자름).
/// 화면 y는 아래로 커지므로 뒤집어 센다.
double armAngle(double cx, double cy, double px, double py) {
  final a = _deg(math.atan2(cy - py, px - cx));
  // 가운데보다 아래를 누르면 가까운 끝(오른쪽 0°, 왼쪽 180°)으로 붙인다.
  if (a < 0) return a < -90 ? 180 : 0;
  return a;
}

/// 두 팔 사이 각(°, 0~180).
double armsBetween(double a, double b) => (a - b).abs().clamp(0.0, 180.0);
