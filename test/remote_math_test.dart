// 리모컨 한 건 → 계산기 한 줄. 폰 미리보기와 태블릿이 같은 셈을 쓰는지.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/remote_math.dart';

void main() {
  group('새들', () {
    test('3점은 각도의 절반으로 이동을 센다(폰 화면과 같게)', () {
      final l = remoteLineFor(
        mode: 'SADDLE',
        val1: 100,
        angle: 45,
        saddlePoints: 3,
      )!;
      expect(l.length, closeTo(261.3, 0.1));
      expect(l.angle, 45);
    });

    test('4점은 각도 그대로', () {
      final l = remoteLineFor(
        mode: 'SADDLE',
        val1: 100,
        angle: 45,
        saddlePoints: 4,
      )!;
      expect(l.length, closeTo(141.4, 0.1));
    });

    test('각도 범위 밖이면 못 보낸다', () {
      expect(
        remoteInputProblem(mode: 'SADDLE', val1: 100, angle: 0),
        isNotNull,
      );
      expect(
        remoteInputProblem(
          mode: 'SADDLE',
          val1: 100,
          angle: 90,
          saddlePoints: 4,
        ),
        isNotNull,
      );
      expect(
        remoteInputProblem(
          mode: 'SADDLE',
          val1: 100,
          angle: 90,
          saddlePoints: 3,
        ),
        isNull,
      );
    });
  });

  group('오프셋', () {
    test('각도로: 이동 = 높이 ÷ sin(각도)', () {
      final l = remoteLineFor(mode: 'OFFSET', val1: 100, angle: 30)!;
      expect(l.length, closeTo(200, 0.01));
      expect(l.angle, 30);
    });

    test('이동 길이로: 각도 = asin(높이 ÷ 이동)', () {
      final l = remoteLineFor(mode: 'OFFSET', val1: 100, val2: 200)!;
      expect(l.length, 200);
      expect(l.angle, closeTo(30, 0.01));
    });

    test('이동이 높이보다 짧으면 90°로 만들지 않고 막는다', () {
      expect(
        remoteInputProblem(mode: 'OFFSET', val1: 100, val2: 80),
        isNotNull,
      );
      expect(remoteLineFor(mode: 'OFFSET', val1: 100, val2: 80), isNull);
    });

    test('90° 이상 각도는 막는다', () {
      expect(remoteLineFor(mode: 'OFFSET', val1: 100, angle: 90), isNull);
    });
  });

  test('롤링: 참 높이 = √(높이² + 롤²), 이동 = 참 높이 ÷ sin(각도)', () {
    final l = remoteLineFor(mode: 'ROLLING', val1: 30, val2: 40, angle: 30)!;
    expect(l.length, closeTo(100, 0.01));
  });

  test('직관·90°', () {
    expect(remoteLineFor(mode: 'STRAIGHT', val1: 500)!.angle, 0);
    expect(remoteLineFor(mode: 'BEND_90', val1: 500)!.angle, 90);
    expect(remoteLineFor(mode: 'STRAIGHT', val1: 0), isNull);
  });

  test('옛 한국어 모드 이름도 받는다', () {
    expect(normalizeRemoteMode('새들'), 'SADDLE');
    expect(normalizeRemoteMode('OFFSET'), 'OFFSET');
  });
}
