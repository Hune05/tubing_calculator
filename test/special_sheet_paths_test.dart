// 특수 벤딩 시트가 한 번에 넣는 줄들의 방향이 모두 유효한지(경로 계산이 "나란해서 꺾을 수 없습니다"를
// 내지 않는지)를, 진행 방향 6개 × 고른 방향 6개 × 대표 각도로 따진다.
// 첫 줄만 규칙에 맞으면 뒤 줄도 맞는다는 전제(시트가 첫 방향만 거르는 이유)를 확인한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/engine/bend_path.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_rolling_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/opposite_rotation.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_special_calc.dart';

const _axes = [0.0, 90.0, 180.0, 270.0, 360.0, 450.0];

List<PathSegment> _segs(List<(double, double, double)> bends) => [
  const PathSegment(length: 500, angle: 0, rotation: 0), // 앞 직관
  for (final (l, a, r) in bends) PathSegment(length: l, angle: a, rotation: r),
];

bool _parallelWarning(double heading, List<(double, double, double)> bends) {
  final path = buildBendPath(
    _segs(bends),
    radius: 30,
    startDirection: directionForRotation(heading),
  );
  return path.warnings.any((w) => w.contains('나란해서'));
}

/// 진행 방향 [heading]에서 꺾을 수 있는 모든 [sel]에 대해 [make]가 만든 줄이 유효한지 모아서 돌려준다.
List<String> _bad(
  String name,
  List<(double, double, double)> Function(double sel, double heading) make,
) {
  final out = <String>[];
  for (final h in _axes) {
    for (final sel in _axes) {
      final allowed = canBendToward(
        directionForRotation(h),
        directionForRotation(sel),
      );
      if (!allowed) continue;
      if (_parallelWarning(h, make(sel, h))) out.add('$name 진행=$h 고른=$sel');
    }
  }
  return out;
}

void main() {
  test('규칙이 맞는 짝(진행·고른 방향)이 어떤 것인지: 같은 축·반대 축만 거절', () {
    for (final h in _axes) {
      for (final sel in _axes) {
        final same = h == sel || oppositeRotation(h) == sel;
        expect(
          canBendToward(directionForRotation(h), directionForRotation(sel)),
          !same,
          reason: '진행=$h 고른=$sel',
        );
      }
    }
  });

  test('시험이 민감한지: 못 꺾는 방향으로 첫 줄을 넣으면 경고가 난다', () {
    expect(_parallelWarning(90, [(300, 45, 90)]), isTrue);
    expect(_parallelWarning(90, [(300, 45, 270)]), isTrue);
    expect(_parallelWarning(90, [(300, 45, 0)]), isFalse);
  });

  test('오프셋: 첫 줄은 고른 방향, 둘째 줄은 그 반대 (각도 90° 미만)', () {
    for (final a in [10.0, 22.5, 30.0, 45.0, 60.0, 89.0]) {
      expect(
        _bad('오프셋 $a', (sel, h) {
          final (r1, r2) = offsetRotations(sel);
          return [(300, a, r1), (400, a, r2)];
        }),
        isEmpty,
      );
      expect(
        _bad('오프셋(뒤집기) $a', (sel, h) {
          final (r1, r2) = offsetRotations(sel, inverted: true);
          return [(300, a, r1), (400, a, r2)];
        }),
        isEmpty,
      );
    }
  });

  test('새들 3점·4점', () {
    for (final a in [20.0, 30.0, 45.0, 60.0, 80.0]) {
      expect(
        _bad('새들3 $a', (sel, h) {
          final opp = oppositeRotation(sel);
          return [(300, a / 2, sel), (400, a, opp), (400, a / 2, sel)];
        }),
        isEmpty,
      );
      expect(
        _bad('새들4 $a', (sel, h) {
          final opp = oppositeRotation(sel);
          return [(300, a, sel), (400, a, opp), (200, a, opp), (400, a, sel)];
        }),
        isEmpty,
      );
    }
  });

  test('롤링 오프셋(rollingOffsetBends)', () {
    final specs = BendSheetSpecs(radius: 40, gain90: 0, markOffset: (a) => 10);
    for (final a in [22.5, 30.0, 45.0, 60.0]) {
      expect(
        _bad('롤링 $a', (sel, h) {
          return rollingOffsetBends(
            specs: specs,
            startDistance: 0,
            travel: 400,
            angle: a,
            advance: 200,
            rotation: sel,
          );
        }),
        isEmpty,
      );
    }
  });

  test('전선관 분할 90°(같은 방향으로 작은 각을 이어 꺾음)', () {
    for (final n in [2, 3, 4, 5, 6]) {
      expect(
        _bad('분할 $n', (sel, h) {
          final list = conduitSegmentedBends(
            cornerDistance: 600,
            radius: 300,
            bends: n,
            rotation: sel,
          )!;
          return [
            for (final b in list)
              (
                (b['length'] as num).toDouble(),
                (b['angle'] as num).toDouble(),
                (b['rotation'] as num).toDouble(),
              ),
          ];
        }),
        isEmpty,
      );
    }
  });

  test('전선관 스터브업(90° 한 번)', () {
    expect(
      _bad('스터브업', (sel, h) {
        final list = conduitStubBends(stub: 300, rotation: sel)!;
        return [(300, 90, (list.single['rotation'] as num).toDouble())];
      }),
      isEmpty,
    );
  });

  test('전선관 백투백 90°: 진행 방향에 수직으로 첫 90°, 둘째는 처음 진행 방향의 반대', () {
    for (final h in _axes) {
      for (final sel in _axes) {
        final canFirst = canBendToward(
          directionForRotation(h),
          directionForRotation(sel),
        );
        // 시트의 수직 점검(내적 0)까지 통과하는 짝만 본다.
        final perpendicular =
            directionForRotation(h).dot(directionForRotation(sel)).abs() < 1e-6;
        if (!canFirst || !perpendicular) continue;
        final list = conduitBackToBackBends(
          firstLength: 400,
          spacing: 200,
          firstRotation: sel,
          secondRotation: oppositeRotation(h),
        )!;
        final bends = [
          for (final b in list)
            (
              (b['length'] as num).toDouble(),
              (b['angle'] as num).toDouble(),
              (b['rotation'] as num).toDouble(),
            ),
        ];
        expect(_parallelWarning(h, bends), isFalse, reason: '진행=$h 고른=$sel');
      }
    }
  });

  test('백투백은 진행 방향을 잘못 알면 둘째 줄이 못 꺾는 방향이 된다(그래서 진짜 진행 방향이 필요하다)', () {
    // 실제 진행은 오른쪽(90)인데 시트가 위(0)로 알고 있으면: 첫 90°=오른쪽에 수직인 위(0)... 이 아니라
    // 시트는 "진행=위"라 보고 옆(90)으로 꺾게 한다 → 실제로는 오른쪽 진행에 오른쪽으로 꺾는 꼴.
    final list = conduitBackToBackBends(
      firstLength: 400,
      spacing: 200,
      firstRotation: 90, // 시트가 고르게 한 방향(진행=위로 착각했을 때 수직인 것)
      secondRotation: oppositeRotation(0), // 시트가 안다고 믿은 진행(위)의 반대
    )!;
    final bends = [
      for (final b in list)
        (
          (b['length'] as num).toDouble(),
          (b['angle'] as num).toDouble(),
          (b['rotation'] as num).toDouble(),
        ),
    ];
    expect(_parallelWarning(90, bends), isTrue); // 실제 진행(우)과 나란한 첫 줄
  });
}
