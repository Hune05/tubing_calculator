// 축 정렬 계산 검증: (1) 손으로 푼 예제, (2) 실제 기하로 만든 읽음값을 되돌려 풀기(계산 코드와 따로 세운 앞방향 모델),
// (3) 계산한 심·이동을 적용하면 어긋남이 0이 되는지, (4) 처짐·검산·오류·판정.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_math.dart';

// ── 계산 코드와 무관한 앞방향 모델 ──
// 이동 쪽 축: y(x) = y0 + sy·x, z(x) = z0 + sz·x (고정 쪽 축은 x축). 방향 u(φ): 12시(0°)=+y, 3시(90°)=+z.
({double y, double z}) _u(double deg) {
  final r = deg * math.pi / 180;
  return (y: math.cos(r), z: math.sin(r));
}

/// 곧은 원통(반지름 R, 중심 c)에 바깥에서 닿는 플런저가 [deg] 방향에서 읽는 값(누르면 +).
/// 원통 표면까지의 거리 t = c·u + √(R² − |c|² + (c·u)²) — 근사 없이 정확한 값.
double _rimReading(double cy, double cz, double deg, double R) {
  final u = _u(deg);
  final cu = cy * u.y + cz * u.z;
  final c2 = cy * cy + cz * cz;
  return cu + math.sqrt(R * R - c2 + cu * cu);
}

class _Truth {
  final double y0, sy, z0, sz; // 이동 쪽 축
  const _Truth(this.y0, this.sy, this.z0, this.sz);
  double y(double x) => y0 + sy * x;
  double z(double x) => z0 + sz * x;
}

/// 12시를 0으로 한 3·6·9시 읽음(+ 처짐 영향: 6시에 sag, 옆에 sag/2).
List<double> _rel(double Function(double deg) reading, double sag) {
  final r0 = reading(0);
  double at(double deg, double sagPart) => reading(deg) - r0 + sagPart;
  return [at(90, sag / 2), at(180, sag), at(270, sag / 2)];
}

void main() {
  group('손으로 푼 예제(리버스 다이얼, 위아래만)', () {
    // A 6시 −0.20 → c_A = +0.10, B 6시 +0.10 → c_B(이동 쪽 기준) = +0.05
    // B면=−100, A면=+100, 기울기 = (0.10−0.05)/200 = 0.00025, 커플링 중심 값 0.075
    // 앞발(x=250) 0.1375 → 빼기 0.1375, 뒷발(x=550) 0.2125 → 빼기 0.2125
    final r = solveReverse(
      a90: -0.10, a180: -0.20, a270: -0.10, // 옆은 위아래만 어긋나므로 r90 = r270 = r180/2
      b90: 0.05, b180: 0.10, b270: 0.05,
      betweenPlanes: 200, couplingFromB: 100, frontFoot: 150, rearFoot: 450,
    );
    test('커플링 중심과 기울기', () {
      expect(r.vertical.v0, closeTo(0.075, 1e-9));
      expect(r.vertical.slope, closeTo(0.00025, 1e-12));
      expect(r.horizontal.v0, closeTo(0, 1e-9));
      expect(r.offset, closeTo(0.075, 1e-9));
      expect(r.angle100, closeTo(0.025, 1e-9)); // 0.00025 × 100
    });
    test('발 심 두께', () {
      expect(r.shimFront, closeTo(-0.1375, 1e-9));
      expect(r.shimRear, closeTo(-0.2125, 1e-9));
      expect(r.moveFront, closeTo(0, 1e-9));
    });
    test('검산은 0(옆 읽음 합 = 아래 읽음)', () {
      expect(r.closure, closeTo(0, 1e-9));
    });
    test('글', () {
      expect(shimText(r.shimFront), '빼기 0.14 mm');
      expect(shimText(0.0), '그대로');
      expect(shimText(0.35), '넣기 0.35 mm');
      expect(moveText(-0.1), '왼쪽 0.10 mm');
      expect(moveText(0.2), '오른쪽 0.20 mm');
      expect(moveText(0.001), '그대로');
    });
  });

  group('되돌려 풀기(실제 기하)', () {
    const R = 100.0; // 림 반지름 (오차 c²/2R를 작게)
    const D = 200.0, xc = 100.0, f1 = 150.0, f2 = 450.0;
    const xB = -xc, xA = D - xc;

    void reverseCase(_Truth t, {double sagA = 0, double sagB = 0}) {
      // 다이얼 A: 고정 쪽에 붙어 이동 쪽 림(중심 = 이동 쪽 축의 A면 위치)을 읽는다.
      final a = _rel((deg) => _rimReading(t.y(xA), t.z(xA), deg, R), sagA);
      // 다이얼 B: 이동 쪽에 붙어 고정 쪽 림(중심 = 고정 쪽 축 = 원점)을 읽는다. 이동 쪽 축을 기준으로 하면 고정 쪽 중심이 −c.
      final b = _rel((deg) => _rimReading(-t.y(xB), -t.z(xB), deg, R), sagB);
      final r = solveReverse(
        a90: a[0], a180: a[1], a270: a[2],
        b90: b[0], b180: b[1], b270: b[2],
        sagA: sagA, sagB: sagB,
        betweenPlanes: D, couplingFromB: xc, frontFoot: f1, rearFoot: f2,
      );
      const tol = 0.01; // 원통 정확식과 작은 각도 근사의 차이(수 마이크로~0.01mm)
      expect(r.vertical.v0, closeTo(t.y0, tol), reason: '위아래 커플링 중심 어긋남');
      expect(r.vertical.slope, closeTo(t.sy, 5e-5));
      expect(r.horizontal.v0, closeTo(t.z0, tol), reason: '옆 커플링 중심 어긋남');
      expect(r.horizontal.slope, closeTo(t.sz, 5e-5));
      // 발 값: 고치면 두 발에서 어긋남이 0
      expect(t.y(xA + f1) + r.shimFront, closeTo(0, tol));
      expect(t.y(xA + f2) + r.shimRear, closeTo(0, tol));
      expect(t.z(xA + f1) + r.moveFront, closeTo(0, tol));
      expect(t.z(xA + f2) + r.moveRear, closeTo(0, tol));
    }

    test('평행 어긋남만(위)', () => reverseCase(const _Truth(0.30, 0, 0, 0)));
    test('평행 어긋남만(아래, 오른쪽)', () => reverseCase(const _Truth(-0.25, 0, 0.40, 0)));
    test('각도 어긋남만', () => reverseCase(const _Truth(0, 0.0004, 0, -0.0003)));
    test('섞인 경우', () => reverseCase(const _Truth(0.12, -0.0006, -0.35, 0.0005)));
    test('큰 값(3mm·기울기 0.005)', () => reverseCase(const _Truth(2.0, 0.003, -3.0, -0.005)));
    test('처짐이 있는 브래킷(A −0.10, B −0.06)', () {
      reverseCase(const _Truth(0.12, -0.0006, -0.35, 0.0005), sagA: -0.10, sagB: -0.06);
    });
    test('처짐을 안 넣으면 위아래가 틀어진다(넣는 이유)', () {
      const t = _Truth(0.12, -0.0006, -0.35, 0.0005);
      const sag = -0.10;
      // 한쪽 다이얼만 처지면(둘이 같으면 서로 상쇄되어 커플링 중심 값은 우연히 맞는다) 위아래가 틀어진다.
      final a = _rel((deg) => _rimReading(t.y(xA), t.z(xA), deg, R), sag);
      final b = _rel((deg) => _rimReading(-t.y(xB), -t.z(xB), deg, R), 0);
      final wrong = solveReverse(
        a90: a[0], a180: a[1], a270: a[2], b90: b[0], b180: b[1], b270: b[2],
        betweenPlanes: D, couplingFromB: xc, frontFoot: f1, rearFoot: f2,
      );
      expect((wrong.vertical.v0 - t.y0).abs(), greaterThan(0.02));
    });
  });

  group('림·페이스', () {
    const R = 100.0, rho = 90.0, g = 40.0, f1 = 120.0, f2 = 420.0; // 림면이 커플링 중심에서 40mm
    void rfCase(_Truth t, {double sag = 0}) {
      final rim = _rel((deg) => _rimReading(t.y(g), t.z(g), deg, R), sag);
      // 페이스 읽음: 옆면이 다이얼 쪽으로 다가오면 +. 옆면 x = xf − θy(ρu_y − y_c) − θz(ρu_z − z_c), 읽음 = −x
      double face(double deg) {
        final u = _u(deg);
        final x = g - t.sy * (rho * u.y - t.y(g)) - t.sz * (rho * u.z - t.z(g));
        return -x;
      }
      final fc = _rel(face, 0);
      final r = solveRimFace(
        r90: rim[0], r180: rim[1], r270: rim[2],
        f90: fc[0], f180: fc[1], f270: fc[2],
        sagRim: sag,
        faceRadius: rho, couplingFromRim: g, frontFoot: f1, rearFoot: f2,
      );
      const tol = 0.01;
      expect(r.vertical.v0, closeTo(t.y0, tol));
      expect(r.vertical.slope, closeTo(t.sy, 5e-5));
      expect(r.horizontal.v0, closeTo(t.z0, tol));
      expect(r.horizontal.slope, closeTo(t.sz, 5e-5));
      expect(t.y(g + f1) + r.shimFront, closeTo(0, tol));
      expect(t.y(g + f2) + r.shimRear, closeTo(0, tol));
      expect(t.z(g + f1) + r.moveFront, closeTo(0, tol));
      expect(t.z(g + f2) + r.moveRear, closeTo(0, tol));
    }

    test('평행 어긋남만', () => rfCase(const _Truth(0.30, 0, -0.20, 0)));
    test('각도 어긋남만', () => rfCase(const _Truth(0, 0.0005, 0, -0.0004)));
    test('섞인 경우', () => rfCase(const _Truth(0.15, -0.0007, 0.25, 0.0006)));
    test('처짐이 있는 림 다이얼', () => rfCase(const _Truth(0.15, -0.0007, 0.25, 0.0006), sag: -0.08));
  });

  group('목표값(열팽창 미리 주기)', () {
    test('목표를 주면 그만큼 다른 자리로 가도록 심이 달라진다', () {
      final base = solveReverse(
        a90: 0, a180: 0, a270: 0, b90: 0, b180: 0, b270: 0,
        betweenPlanes: 200, couplingFromB: 100, frontFoot: 150, rearFoot: 450,
      );
      final hot = solveReverse(
        a90: 0, a180: 0, a270: 0, b90: 0, b180: 0, b270: 0,
        betweenPlanes: 200, couplingFromB: 100, frontFoot: 150, rearFoot: 450,
        targetY: -0.20, targetZ: 0.10,
      );
      expect(base.shimFront, closeTo(0, 1e-12));
      expect(hot.shimFront, closeTo(-0.20, 1e-12));
      expect(hot.shimRear, closeTo(-0.20, 1e-12));
      expect(hot.moveFront, closeTo(0.10, 1e-12));
    });
  });

  group('검산·입력 오류', () {
    test('옆 읽음 합이 아래와 안 맞으면 검산이 커진다', () {
      final r = solveReverse(
        a90: 0.10, a180: -0.20, a270: 0.30, // 합 0.40, 아래 −0.20 → 차 0.60
        b90: 0, b180: 0, b270: 0,
        betweenPlanes: 200, couplingFromB: 100, frontFoot: 150, rearFoot: 450,
      );
      expect(r.closure, closeTo(0.60, 1e-9));
    });

    test('거리 입력 오류는 던진다', () {
      AlignResult tryRev({double d = 200, double f1 = 150, double f2 = 450}) => solveReverse(
        a90: 0, a180: 0, a270: 0, b90: 0, b180: 0, b270: 0,
        betweenPlanes: d, couplingFromB: 100, frontFoot: f1, rearFoot: f2,
      );
      expect(() => tryRev(d: 0), throwsA(isA<AlignInputError>()));
      expect(() => tryRev(f1: 0), throwsA(isA<AlignInputError>()));
      expect(() => tryRev(f1: 500, f2: 450), throwsA(isA<AlignInputError>()));
      expect(
        () => solveRimFace(
          r90: 0, r180: 0, r270: 0, f90: 0, f180: 0, f270: 0,
          faceRadius: 0, couplingFromRim: 40, frontFoot: 120, rearFoot: 420,
        ),
        throwsA(isA<AlignInputError>()),
      );
    });
  });

  group('허용 오차 판정', () {
    AlignResult res(double vy, double sy) => AlignResult(
      vertical: AxisLine(vy, sy),
      horizontal: const AxisLine(0, 0),
      shimFront: 0, shimRear: 0, moveFront: 0, moveRear: 0,
      offset: vy.abs(), angle100: sy.abs() * 100, closure: 0,
    );

    test('회전수별 참고값', () {
      expect(defaultTolerance(3600).offset, 0.05);
      expect(defaultTolerance(1800).offset, 0.08);
      expect(defaultTolerance(1200).offset, 0.10);
      expect(defaultTolerance(900).offset, 0.15);
    });

    test('판정', () {
      const t = AlignTolerance(0.08, 0.08);
      expect(judge(res(0.05, 0.0005), t), AlignVerdict.ok);
      expect(judge(res(0.10, 0.0005), t), AlignVerdict.offsetOut);
      expect(judge(res(0.05, 0.0010), t), AlignVerdict.angleOut);
      expect(judge(res(0.10, 0.0010), t), AlignVerdict.bothOut);
    });
  });
}
