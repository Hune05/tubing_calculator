// 전선관 마킹 검사.
// 핵심: 마킹 자리와 "총 자를 길이"가 서로 맞아야 한다. 예전에는 총 길이는
// 게인을 빼는데 마킹 자리는 빼지 않아, 두 번째 벤드부터 게인만큼 밀렸다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';

// 22mm EMT 기본값.
const double kTakeUp90 = 152.4;
const double kGain90 = 81.2;
const double kClr = 114.3;

Map<String, dynamic> settings({
  String benderType = 'hand',
  double takeUp = kTakeUp90,
  double gain = kGain90,
  double clr = kClr,
  bool springback = false,
}) => {
  'benderType': benderType,
  'takeUp': takeUp,
  'gain': gain,
  'clr': clr,
  'couplingDepth': 20.0,
  'applySpringback': springback,
  'springback': 3.0,
  'degPerNotch': 2.5,
  'ramTravel': 0.0,
  'setback': 0.0,
};

List<Map<String, dynamic>> bends(List<List<double>> rows) => [
  for (final r in rows) {'length': r[0], 'angle': r[1], 'rotation': r[2]},
];

/// 화면이 쓰는 총 자를 길이 셈(구간 길이 합 − 각도별 게인 합).
double totalCut(List<Map<String, dynamic>> list, double gain90) {
  var sum = 0.0;
  var gains = 0.0;
  for (final b in list) {
    sum += b['length'] as double;
    final a = b['angle'] as double;
    if (a > 0) gains += conduitGainForAngle(a, gain90);
  }
  return sum - gains;
}

void main() {
  group('각도별 게인', () {
    test('90°는 표에 적힌 값 그대로', () {
      expect(conduitGainForAngle(90, kGain90), closeTo(kGain90, 0.001));
    });

    test('45°는 비례가 아니라 기하 비율로 줄어든다', () {
      // 비례로 치면 40.6이 나오지만 실제로는 8.1 남짓이다.
      final g = conduitGainForAngle(45, kGain90);
      expect(g, closeTo(scaleMeasuredGain(kGain90, 45), 0.001));
      expect(g, lessThan(15));
    });

    test('0°나 게인이 없으면 0', () {
      expect(conduitGainForAngle(0, kGain90), 0.0);
      expect(conduitGainForAngle(90, 0), 0.0);
    });
  });

  group('각도별 테이크업', () {
    test('90°는 표에 적힌 값 그대로', () {
      expect(scaleTakeUp(kTakeUp90, kClr, 90), closeTo(kTakeUp90, 0.001));
    });

    test('45°는 90°보다 작다(예전에는 같은 값을 뺐다)', () {
      final t45 = scaleTakeUp(kTakeUp90, kClr, 45);
      expect(t45, lessThan(kTakeUp90));
      // 반경 쪽만 tan(22.5)로 줄고, 신발이 먹는 고정분(152.4−114.3)은 그대로.
      expect(t45, closeTo(114.3 * 0.41421 + 38.1, 0.05));
    });

    test('0°면 뺄 것이 없다', () {
      expect(scaleTakeUp(kTakeUp90, kClr, 0), 0.0);
    });

    test('반경을 모르면 tan 비율로만 줄인다', () {
      expect(scaleTakeUp(kTakeUp90, 0, 90), closeTo(kTakeUp90, 0.001));
      expect(scaleTakeUp(kTakeUp90, 0, 45), lessThan(kTakeUp90));
    });
  });

  group('수동 벤더 마킹', () {
    test('첫 마킹은 길이에서 테이크업을 뺀 자리', () {
      final m = calculateConduitMarkings(
        bends([
          [1000, 90, 0],
        ]),
        settings(),
      );
      expect(m.first['mark'] as double, closeTo(1000 - kTakeUp90, 0.001));
    });

    test('두 번째 마킹에서 앞 벤드 게인을 뺀다', () {
      final list = bends([
        [1000, 90, 0],
        [800, 90, 90],
      ]);
      final m = calculateConduitMarkings(list, settings());
      // 예전에는 그냥 +800이었다. 지금은 +800 − 81.2.
      expect(
        (m[1]['mark'] as double) - (m[0]['mark'] as double),
        closeTo(800 - kGain90, 0.001),
      );
    });

    test('마지막 마킹이 총 자를 길이를 넘지 않는다', () {
      final list = bends([
        [1000, 90, 0],
        [800, 90, 90],
        [600, 90, 180],
      ]);
      final m = calculateConduitMarkings(list, settings());
      final cut = totalCut(list, kGain90);
      expect(m.last['mark'] as double, lessThan(cut));
    });

    test('마킹 간격을 다 더하면 총 길이 셈과 맞는다', () {
      final list = bends([
        [1000, 90, 0],
        [800, 90, 90],
        [600, 90, 180],
      ]);
      final m = calculateConduitMarkings(list, settings());
      final cut = totalCut(list, kGain90);
      // 마지막 마킹 뒤에 남는 길이 = 테이크업 − 게인 (90°가 이어질 때).
      expect(cut - (m.last['mark'] as double), closeTo(kTakeUp90 - kGain90, 0.01));
    });

    test('45°가 섞이면 그 각의 테이크업·게인을 쓴다', () {
      final list = bends([
        [1000, 45, 0],
        [800, 90, 90],
      ]);
      final m = calculateConduitMarkings(list, settings());
      expect(
        m[0]['mark'] as double,
        closeTo(1000 - scaleTakeUp(kTakeUp90, kClr, 45), 0.01),
      );
      final gap = (m[1]['mark'] as double) - (m[0]['mark'] as double);
      expect(
        gap,
        closeTo(
          800 -
              conduitGainForAngle(45, kGain90) -
              scaleTakeUp(kTakeUp90, kClr, 90) +
              scaleTakeUp(kTakeUp90, kClr, 45),
          0.01,
        ),
      );
    });

    test('직관(0°)은 테이크업을 빼지 않는다', () {
      final m = calculateConduitMarkings(
        bends([
          [1000, 0, 0],
        ]),
        settings(),
      );
      expect(m.first['mark'] as double, closeTo(1000, 0.001));
      expect(m.first['note'], '직관 시작');
    });

    test('커플링을 쓰면 그만큼 더 뺀다', () {
      final m = calculateConduitMarkings(
        bends([
          [1000, 90, 0],
        ]),
        settings(),
        useCoupling: true,
      );
      expect(m.first['mark'] as double, closeTo(1000 - kTakeUp90 - 20, 0.001));
    });

    test('스프링백은 꺾을 각도에만 붙는다', () {
      final m = calculateConduitMarkings(
        bends([
          [1000, 90, 0],
        ]),
        settings(springback: true),
      );
      expect(m.first['targetAngle'] as double, closeTo(93.0, 0.001));
      // 마킹 자리는 설계 각도로 잡는다(스프링백 때문에 자리가 밀리면 안 된다).
      expect(m.first['mark'] as double, closeTo(1000 - kTakeUp90, 0.001));
    });
  });

  group('시카고 벤더 마킹', () {
    test('수동 벤더와 같은 자리에 금을 긋는다', () {
      final list = bends([
        [1000, 90, 0],
        [800, 90, 90],
      ]);
      final hand = calculateConduitMarkings(list, settings());
      final chi = calculateConduitMarkings(
        list,
        settings(benderType: 'chicago'),
      );
      for (var i = 0; i < hand.length; i++) {
        expect(chi[i]['mark'] as double, closeTo(hand[i]['mark'] as double, 0.001));
      }
    });

    test('노치 수를 알려 준다', () {
      final m = calculateConduitMarkings(
        bends([
          [1000, 90, 0],
        ]),
        settings(benderType: 'chicago'),
      );
      expect(m.first['notches'], 36); // 90 / 2.5
    });
  });

  group('유압(램) 벤더', () {
    test('램 이동 거리는 각도에 따라 sin(각/2)로 준다', () {
      final s = settings(benderType: 'ram');
      s['ramTravel'] = 100.0;
      final m = calculateConduitMarkings(
        bends([
          [1000, 90, 0],
          [800, 45, 90],
        ]),
        s,
      );
      final t90 = m[0]['ramTravel'] as double;
      final t45 = m[1]['ramTravel'] as double;
      expect(t90, closeTo(100.0, 0.001)); // sin45/sin45 = 1
      expect(t45, lessThan(t90));
    });
  });
  group('벤더 종류에 관계없이', () {
    test('마킹 자리 = 꺾이는 점 − 그 벤더의 마킹 거리', () {
      final list = bends([
        [150, 0, 0],
        [80, 21, 0],
        [195.3, 21, 180],
        [200, 0, 0],
      ]);
      for (final type in ['hand', 'chicago', 'ram']) {
        final s = settings(benderType: type);
        s['setback'] = 40.0;
        final m = calculateConduitMarkings(list, s);
        var developed = 0.0;
        var prevGain = 0.0;
        for (var i = 0; i < list.length; i++) {
          final len = list[i]['length'] as double;
          final a = list[i]['angle'] as double;
          developed += len - prevGain;
          expect(
            m[i]['mark'] as double,
            closeTo(developed - conduitMarkOffset(a, s), 0.001),
            reason: '$type ${i + 1}번',
          );
          prevGain = conduitGainForAngle(a, kGain90);
        }
      }
    });

    test('램도 두 번째 벤드부터 앞 벤드 게인을 뺀다(예전에는 안 뺐다)', () {
      final list = bends([
        [1000, 90, 0],
        [800, 90, 90],
      ]);
      final m = calculateConduitMarkings(list, settings(benderType: 'ram'));
      expect(
        (m[1]['mark'] as double) - (m[0]['mark'] as double),
        closeTo(800 - kGain90, 0.001),
      );
      expect(m[1]['note'], contains('게인'));
    });

    test('직관 뒤에 오는 벤드는 직관 자리에서 테이크업만큼 앞에 찍힌다', () {
      // 직관 150 다음 21° 벤드(꺾이는 점까지 59.3 = 21° 테이크업)면 딱 150.
      final off = conduitMarkOffset(21, settings());
      final m = calculateConduitMarkings(
        bends([
          [150, 0, 0],
          [off, 21, 0],
        ]),
        settings(),
      );
      expect(m[1]['mark'] as double, closeTo(150, 0.001));
      expect(m[1]['gap'] as double, closeTo(0, 0.001));
      expect(m[1]['short'], isFalse);
    });

    test('앞 마킹보다 앞에 찍히면 순서가 거꾸로라고 알려 준다', () {
      final m = calculateConduitMarkings(
        bends([
          [150, 0, 0],
          [10, 21, 0],
        ]),
        settings(),
      );
      expect(m[1]['short'], isTrue);
      // 앞이 직관이면 꺾을 수는 있으므로 "만들 수 없다"고 하지 않는다.
      expect(m[1]['note'], contains('순서가 거꾸로'));
      expect(m[1]['note'], isNot(contains('만들 수 없습니다')));
    });

    test('설정값이 정수로 들어와도 셈한다', () {
      final s = settings();
      s['takeUp'] = 152;
      s['gain'] = 81;
      final m = calculateConduitMarkings(
        bends([
          [1000, 90, 0],
        ]),
        s,
      );
      expect(m.first['mark'] as double, closeTo(1000 - 152, 0.001));
    });
  });
}
