// 고정 발 고르기(10-15): 모터만 움직이는 대신, 네 발(펌프 바깥·안쪽, 모터 앞·뒤) 가운데 움직이지 않을 두 발을 고른다.
// 모터 심을 더 뺄 수 없을 때(베이스 바운드)나 볼트 구멍이 걸려 옆으로 더 못 밀 때(볼트 바운드) 펌프 쪽도 같이 움직인다.
//
// 원리: 두 축이 맞으려면 (모터 보정 m(x)) − (펌프 보정 p(x)) = 목표 − 지금 모터 축 M(x) = D(x).
// 보정은 직선이라 p(x) = a + b·x, m(x) = p(x) + D(x). 고정한 발에서는 보정이 0이라는 조건 두 개로 a·b를 푼다.
//   펌프 발 x에서 고정: a + b·x = 0,   모터 발 x에서 고정: a + b·x = −D(x)
// 좌표는 alignment_math.dart와 같다(커플링 중심 0, 펌프 −, 모터 +).
library;

import 'alignment_math.dart';
import 'alignment_session.dart' show AlignFoot;

/// 발 자리 넷.
enum AlignFootPos {
  pumpOuter('펌프 바깥발'),
  pumpInner('펌프 안쪽발'),
  motorFront('모터 앞발'),
  motorRear('모터 뒷발');

  final String label;
  const AlignFootPos(this.label);

  bool get isPump => this == pumpOuter || this == pumpInner;
}

/// 처음(지금까지와 같음): 펌프 두 발 고정, 모터만 움직임.
const Set<AlignFootPos> kAlignFixedDefault = {AlignFootPos.pumpOuter, AlignFootPos.pumpInner};

/// 발마다 보정: 심(+ 넣기), 옆(+ 오른쪽).
typedef AlignFootMove = ({double shim, double move});

class AlignPlan {
  final Set<AlignFootPos> fixed;
  final Map<AlignFootPos, AlignFootMove> feet;
  const AlignPlan(this.fixed, this.feet);

  bool get pumpMoves => feet.entries.any((e) => e.key.isPump && (e.value.shim.abs() >= 0.005 || e.value.move.abs() >= 0.005));
}

/// 발 위치(x, mm). 펌프 거리는 커플링 중심에서 잰 양수.
Map<AlignFootPos, double> alignFootX({
  required double xFront,
  required double xRear,
  double? pumpInner,
  double? pumpOuter,
}) => {
  AlignFootPos.motorFront: xFront,
  AlignFootPos.motorRear: xRear,
  if (pumpInner != null) AlignFootPos.pumpInner: -pumpInner,
  if (pumpOuter != null) AlignFootPos.pumpOuter: -pumpOuter,
};

/// 고정 발 두 개로 네 발 보정을 구한다. 펌프 발 거리가 없으면 펌프 발은 결과에서 빠진다.
/// [fixed]가 두 개가 아니거나, 같은 자리이거나, 필요한 펌프 거리가 없으면 [AlignInputError].
AlignPlan alignPlan({
  required AlignResult r,
  required Set<AlignFootPos> fixed,
  required double xFront,
  required double xRear,
  double? pumpInner,
  double? pumpOuter,
  double targetY = 0,
  double targetZ = 0,
}) {
  if (fixed.length != 2) throw const AlignInputError('고정할 발을 두 개 고르십시오');
  final pos = alignFootX(xFront: xFront, xRear: xRear, pumpInner: pumpInner, pumpOuter: pumpOuter);
  // 펌프 두 발 고정이면 펌프 보정은 어디서나 0이라 펌프 거리 없이도 된다(처음 상태).
  final pumpBoth = fixed.every((f) => f.isPump);
  for (final f in pumpBoth ? const <AlignFootPos>[] : fixed) {
    if (!pos.containsKey(f)) throw const AlignInputError('펌프 발까지 거리를 넣어 주십시오');
  }
  if (pumpInner != null && pumpOuter != null && pumpOuter <= pumpInner) {
    throw const AlignInputError('펌프 바깥발이 안쪽발보다 더 멀어야 합니다');
  }
  final f1 = fixed.first, f2 = fixed.last;
  // 펌프 두 발 고정: 자리 값이 없어도 되게 아무 두 점(0, 1)으로 둔다(보정이 0이라 결과는 같다).
  final x1 = pumpBoth ? 0.0 : pos[f1]!, x2 = pumpBoth ? 1.0 : pos[f2]!;
  if ((x1 - x2).abs() < 1e-6) throw const AlignInputError('고정할 두 발이 같은 자리입니다');

  // 한 방향(위아래 또는 옆)의 펌프 보정 직선 (a, b).
  (double, double) solve(AxisLine m, double target) {
    double d(double x) => target - m.at(x);
    // 고정 조건: a + b·x = rhs
    double rhs(AlignFootPos f, double x) => f.isPump ? 0 : -d(x);
    final r1 = rhs(f1, x1), r2 = rhs(f2, x2);
    final b = (r1 - r2) / (x1 - x2);
    return (r1 - b * x1, b);
  }

  final (ay, by) = solve(r.vertical, targetY);
  final (az, bz) = solve(r.horizontal, targetZ);
  double corr(AlignFootPos f, double x, double a, double b, AxisLine m, double target) {
    final p = a + b * x;
    return f.isPump ? p : p + (target - m.at(x));
  }

  return AlignPlan(fixed, {
    for (final e in pos.entries)
      e.key: (
        shim: corr(e.key, e.value, ay, by, r.vertical, targetY),
        move: corr(e.key, e.value, az, bz, r.horizontal, targetZ),
      ),
  });
}

/// 모터 발에서 뺄 수 있는 심(지금 심의 왼쪽·오른쪽 중 작은 쪽)보다 더 빼야 하는 발(베이스 바운드).
/// [now]는 심 기록의 지금 심. 넣지 않은 발(0)은 뺄 수 없는 것으로 본다.
Map<AlignFootPos, double> alignShortShim(AlignPlan p, Map<AlignFoot, double> now) {
  double avail(AlignFoot a, AlignFoot b) {
    final x = now[a] ?? 0, y = now[b] ?? 0;
    return x < y ? x : y;
  }

  final out = <AlignFootPos, double>{};
  for (final (pos, a, b) in [
    (AlignFootPos.motorFront, AlignFoot.frontLeft, AlignFoot.frontRight),
    (AlignFootPos.motorRear, AlignFoot.rearLeft, AlignFoot.rearRight),
  ]) {
    final s = p.feet[pos]?.shim;
    if (s == null || s >= -0.005) continue;
    final short = -s - avail(a, b);
    if (short > 0.005) out[pos] = short;
  }
  return out;
}

/// 모든 고정 발 쌍 가운데, 모터에서 뺄 심이 모자라지 않고 펌프는 올리기만(심 넣기만) 하는 쌍을 고른다.
/// 그런 쌍이 여럿이면 네 발 심을 움직이는 양의 합이 가장 작은 것. 없으면 null.
Set<AlignFootPos>? alignAutoFixed({
  required AlignResult r,
  required Map<AlignFoot, double> now,
  required double xFront,
  required double xRear,
  required double pumpInner,
  required double pumpOuter,
  double targetY = 0,
  double targetZ = 0,
}) {
  const all = AlignFootPos.values;
  Set<AlignFootPos>? best;
  double bestCost = double.infinity;
  for (var i = 0; i < all.length; i++) {
    for (var j = i + 1; j < all.length; j++) {
      final fixed = {all[i], all[j]};
      final AlignPlan p;
      try {
        p = alignPlan(r: r, fixed: fixed, xFront: xFront, xRear: xRear, pumpInner: pumpInner, pumpOuter: pumpOuter, targetY: targetY, targetZ: targetZ);
      } on AlignInputError {
        continue;
      }
      if (alignShortShim(p, now).isNotEmpty) continue;
      final pumpDown = p.feet.entries.any((e) => e.key.isPump && e.value.shim < -0.005);
      if (pumpDown) continue;
      final cost = p.feet.values.fold<double>(0, (s, v) => s + v.shim.abs());
      if (cost < bestCost - 1e-9) {
        bestCost = cost;
        best = fixed;
      }
    }
  }
  return best;
}

/// 저장한 고정 발 글("motorRear,pumpOuter")을 이름으로: "모터 뒷발·펌프 바깥발".
String alignFixedLabel(String saved) => [
  for (final n in saved.split(','))
    for (final f in AlignFootPos.values)
      if (f.name == n) f.label,
].join('·');
