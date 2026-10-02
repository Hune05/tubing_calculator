// 케이블 트레이 엔진(10-03): 판단기준 제213조의2 해설 자료(jungi.net)의 계산 예 7개를 그대로 확인한다.
// 자료의 케이블은 옛 굵기(TFR-CV 22·38·60·100·150·200·250·500·600·800mm²)라 외경을 직접 넣는다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/cable_tray.dart';
import 'package:tubing_calculator/src/presentation/electrical/cable_tray_painter.dart';
import 'package:tubing_calculator/src/presentation/electrical/conduit_tables.dart';

TrayCable _c(double size, int cores, double od, int count, {bool control = false}) =>
    TrayCable(name: 'TFR-CV $size ${cores}C', od: od, size: size, cores: cores, count: count, control: control);

double? _min(TrayType t, List<TrayCable> cs, {double depth = 100, double margin = 0}) =>
    sizeTray(type: t, depth: depth, cables: cs, margin: margin, widths: kTrayTableWidths, standard: TrayStandard.old213)!.minWidth;

void main() {
  group('다심 (사다리형)', () {
    // 예 (1): 100mm² 이상만 → 외경 합 47×3 + 55×3 + 63×4 = 558 ≤ 600
    final big = [_c(100, 4, 47, 3), _c(150, 4, 55, 3), _c(200, 4, 63, 4)];
    // 예 (2): 100mm² 미만만 → 단면적 합 1,359 + 2,828 + 4,300 ≈ 8,487 ≤ 300폭 9,030
    final small = [_c(22, 4, 24, 3), _c(38, 4, 30, 4), _c(60, 4, 37, 4)];

    test('예 1: 100mm² 이상만 → 외경 합 558mm, 600폭', () {
      final c = checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 600, depth: 100, cables: big)!;
      expect(c.rule, TrayRule.multiBigDia);
      expect(c.used, closeTo(558, 1e-9));
      expect(c.ok, isTrue);
      expect(c.singleLayer, isTrue);
      expect(_min(TrayType.ladder, big), 600);
    });

    test('예 2: 100mm² 미만만 → 단면적 합 약 8,487mm², 300폭(9,030)', () {
      final c = checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 300, depth: 100, cables: small)!;
      expect(c.rule, TrayRule.multiSmallArea);
      expect(c.used, closeTo(8487, 3));
      expect(c.limit, 9030);
      expect(_min(TrayType.ladder, small), 300);
    });

    test('예 3: 섞임 → 30.5 × 558 + 8,487 = 25,506 ≤ 900폭 27,090 (750폭 22,580은 넘침)', () {
      final c = checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 900, depth: 100, cables: [...big, ...small])!;
      expect(c.rule, TrayRule.multiMixed);
      expect(c.used, closeTo(25506, 3));
      expect(c.limit, 27090);
      expect(c.ok, isTrue);
      expect(checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 750, depth: 100, cables: [...big, ...small])!.ok, isFalse);
      expect(_min(TrayType.ladder, [...big, ...small]), 900);
    });

    test('바닥밀폐형: 같은 섞임은 표 3(900폭 21,290) − 25.4 × 외경 합 → 900폭도 넘침', () {
      final c = checkTray(standard: TrayStandard.old213, type: TrayType.solid, width: 900, depth: 100, cables: [...big, ...small])!;
      expect(c.used, closeTo(8485.4 + 25.4 * 558, 3));
      expect(c.limit, 21290);
      expect(c.ok, isFalse);
      expect(_min(TrayType.solid, [...big, ...small]), isNull);
    });

    test('펀칭형·메시형은 사다리형 표와 같다', () {
      for (final t in [TrayType.punched, TrayType.mesh]) {
        expect(checkTray(standard: TrayStandard.old213, type: t, width: 300, depth: 100, cables: small)!.limit, 9030);
      }
      expect(checkTray(standard: TrayStandard.old213, type: TrayType.solid, width: 300, depth: 100, cables: small)!.limit, 7090);
    });
  });

  group('단심 (사다리형)', () {
    // 예 (1): 500mm² 이상만 → 40×3 + 43×6 + 49×3 = 525 ≤ 600
    final big = [_c(500, 1, 40, 3), _c(600, 1, 43, 6), _c(800, 1, 49, 3)];
    // 예 (2): 100~500mm²만 → 453×9 + 573×6 + 707×6 ≈ 11,757 ≤ 450폭 12,580
    final mid = [_c(150, 1, 24, 9), _c(200, 1, 27, 6), _c(250, 1, 30, 6)];

    test('예 1: 500mm² 이상만 → 외경 합 525mm, 600폭', () {
      final c = checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 600, depth: 100, cables: big)!;
      expect(c.rule, TrayRule.singleBigDia);
      expect(c.used, closeTo(525, 1e-9));
      expect(_min(TrayType.ladder, big), 600);
    });

    test('예 2: 100~500mm²만 → 단면적 합 약 11,757mm², 450폭(12,580)', () {
      final c = checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 450, depth: 100, cables: mid)!;
      expect(c.rule, TrayRule.singleMidArea);
      expect(c.used, closeTo(11757, 12)); // 자료는 한 가닥 면적을 453·573·707로 반올림한 뒤 곱했다
      expect(_min(TrayType.ladder, mid), 450);
    });

    test('예 3: 섞임 → 28 × 378 + 11,757 = 22,341 ≤ 900폭 25,160', () {
      final cs = [_c(500, 1, 40, 3), _c(600, 1, 43, 6), ...mid];
      final c = checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 900, depth: 100, cables: cs)!;
      expect(c.rule, TrayRule.singleMixed);
      expect(c.used, closeTo(22341, 12));
      expect(c.limit, 25160);
      expect(_min(TrayType.ladder, cs), 900);
    });

    test('예 4: 100mm² 미만이 있으면 모두 한 층 → 외경 합 840 ≤ 900', () {
      final cs = [_c(38, 1, 13.5, 12), _c(150, 1, 24, 9), _c(200, 1, 27, 6), _c(250, 1, 30, 6), _c(500, 1, 40, 3)];
      final c = checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 900, depth: 100, cables: cs)!;
      expect(c.rule, TrayRule.singleLayerDia);
      expect(c.used, closeTo(840, 1e-9));
      expect(_min(TrayType.ladder, cs), 900);
    });
  });

  test('다심·단심 함께 → 모두 한 층, 외경 합 828 ≤ 900 (자료 3번 예)', () {
    final cs = [
      _c(100, 4, 47, 3), _c(150, 4, 55, 3), _c(200, 4, 63, 2),
      _c(38, 1, 13.5, 6), _c(150, 1, 24, 6), _c(200, 1, 27, 3), _c(250, 1, 30, 3),
    ];
    final c = checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 900, depth: 100, cables: cs)!;
    expect(c.rule, TrayRule.singleLayerDia);
    expect(c.used, closeTo(828, 1e-9));
    expect(c.ok, isTrue);
  });

  group('제어·신호, 여유, 표 사이 폭', () {
    test('제어·신호 다심만, 깊이 150 이하 → 사다리 50%, 바닥밀폐 40%', () {
      final cs = [_c(2.5, 10, 20.5, 20, control: true)]; // 330mm² × 20 ≈ 6,601mm²
      final open = checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 150, depth: 100, cables: cs)!;
      expect(open.rule, TrayRule.controlPct);
      expect(open.limit, 150 * 100 * 0.5);
      final solid = checkTray(standard: TrayStandard.old213, type: TrayType.solid, width: 150, depth: 100, cables: cs)!;
      expect(solid.limit, 150 * 100 * 0.4);
      expect(open.ok, isTrue);
      expect(solid.ok, isFalse);
      // 깊이가 150을 넘으면 150으로 계산한다.
      final deep = checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 150, depth: 200, cables: cs)!;
      expect(deep.rule, TrayRule.controlPct);
      expect(deep.limit, 150 * 150 * 0.5);
    });

    test('예비 여유 20%는 쓴 양에 1.2를 곱한다', () {
      final cs = [_c(22, 4, 24, 3), _c(38, 4, 30, 4), _c(60, 4, 37, 4)];
      final c = checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 300, depth: 100, cables: cs, margin: 0.2)!;
      expect(c.used, closeTo(8485.4 * 1.2, 3));
      expect(c.ok, isFalse); // 10,182 > 9,030
      expect(_min(TrayType.ladder, cs, margin: 0.2), 450);
    });

    test('표에 없는 폭은 비례: 사다리 다심 200폭 = 27,090 ÷ 900 × 200', () {
      final cs = [_c(22, 4, 24, 1)];
      final c = checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 200, depth: 100, cables: cs)!;
      expect(c.limit, closeTo(27090 / 900 * 200, 1e-9));
      expect(c.notes.any((n) => n.contains('비례')), isTrue);
    });

    test('앱 외경 표에서 만든 케이블: F-CV 4심 95mm²는 100mm² 미만, 120mm²는 이상', () {
      final a = TrayCable.fromKind(CableKind.fcv4, 95, 2)!;
      final b = TrayCable.fromKind(CableKind.fcv4, 120, 2)!;
      expect(a.cores, 4);
      expect(a.od, 42.0);
      expect(checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 300, depth: 100, cables: [a])!.rule, TrayRule.multiSmallArea);
      expect(checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 300, depth: 100, cables: [b])!.rule, TrayRule.multiBigDia);
      final cvvs = TrayCable.fromKind(CableKind.cvvs10, 2.5, 1)!;
      expect(cvvs.control, isTrue);
      expect(cvvs.cores, 10);
    });

    test('케이블이 없으면 판정하지 않는다', () {
      expect(checkTray(type: TrayType.ladder, width: 300, depth: 100, cables: const []), isNull);
    });
  });

  group('단면 그림 놓기', () {
    test('굵은 것부터 바닥 왼쪽에, 폭을 넘으면 위 줄로', () {
      final lay = layoutTray([_c(10, 4, 20, 3), _c(100, 4, 50, 2)], 120, 100, singleLayer: false);
      expect(lay.dots.length, 5);
      expect(lay.dots.first.r, 25); // 50mm가 먼저
      expect(lay.dots[0].x, 25);
      expect(lay.dots[1].x, 75);
      expect(lay.dots[2].y, 10); // 50+50+20 = 120 → 셋째(20mm)는 바닥 줄 끝
      expect(lay.dots[3].y, 50 + 10); // 넷째부터 위 줄
      expect(lay.anyOver, isFalse);
    });

    test('한 층 규칙이면 위 줄로 안 올리고 폭을 넘친 것을 표시', () {
      final lay = layoutTray([_c(500, 1, 40, 4)], 150, 100, singleLayer: true);
      expect(lay.dots.every((d) => d.y == 20), isTrue);
      expect(lay.dots.where((d) => d.over).length, 1); // 40×4 = 160 > 150
    });

    test('깊이를 넘치면 표시하고, 너무 많으면 300가닥까지만 그린다', () {
      final deep = layoutTray([_c(10, 4, 60, 4)], 120, 100, singleLayer: false);
      expect(deep.anyOver, isTrue);
      final many = layoutTray([_c(2.5, 2, 12, 350)], 900, 150, singleLayer: false);
      expect(many.dots.length, kTrayDrawMax);
      expect(many.hidden, 50);
    });
  });

  test('숫자 글: 천 단위 쉼표', () {
    expect(trayNum(27090), '27,090');
    expect(trayNum(558), '558');
    expect(trayNum(13.5), '13.5');
    expect(trayNum(40), '40');
  });

  group('허용전류 보정', () {
    test('회로 수: 다심 전력은 가닥마다, 단심 전력은 3가닥에 하나, 제어는 빼고', () {
      expect(trayCircuits([_c(35, 4, 28, 4), _c(150, 1, 24, 9), _c(2.5, 10, 20, 5, control: true)]), 4 + 3);
      expect(trayCircuits([_c(150, 1, 24, 4)]), 2); // 4가닥 → 2회로(올림)
    });

    test('B.52.17: 한 줄 사다리형 4회로 0.80, 펀칭형 0.77, 바닥밀폐 0.75, 겹쳐 쌓음 0.65', () {
      final cs = [_c(35, 4, 28, 4)];
      expect(trayGroupFactor(TrayType.ladder, cs, oneRow: true), 0.80);
      expect(trayGroupFactor(TrayType.mesh, cs, oneRow: true), 0.80);
      expect(trayGroupFactor(TrayType.punched, cs, oneRow: true), 0.77);
      expect(trayGroupFactor(TrayType.solid, cs, oneRow: true), 0.75);
      expect(trayGroupFactor(TrayType.ladder, cs, oneRow: false), 0.65);
      expect(trayGroupFactor(TrayType.ladder, [_c(35, 4, 28, 1)], oneRow: true), 1);
    });
  });

  group('KEC 232.41 (기본)', () {
    test('종류·다심·단심 관계없이 외경 합 ≤ 내측 폭, 한 층', () {
      final cs = [_c(35, 4, 28, 5), _c(150, 1, 24, 3), _c(2.5, 10, 20.5, 2, control: true)]; // 140 + 72 + 41 = 253
      for (final t in TrayType.values) {
        final c = checkTray(type: t, width: 300, depth: 100, cables: cs)!;
        expect(c.rule, TrayRule.kecDia);
        expect(c.used, closeTo(253, 1e-9));
        expect(c.limit, 300);
        expect(c.singleLayer, isTrue);
        expect(c.ok, isTrue);
      }
      expect(checkTray(type: TrayType.ladder, width: 200, depth: 100, cables: cs)!.ok, isFalse);
      expect(sizeTray(type: TrayType.ladder, depth: 100, cables: cs)!.minWidth, 300);
    });

    test('여유 20%면 외경 합에 1.2: 253 × 1.2 = 303.6 → 400폭', () {
      final cs = [_c(35, 4, 28, 5), _c(150, 1, 24, 3), _c(2.5, 10, 20.5, 2, control: true)];
      expect(sizeTray(type: TrayType.ladder, depth: 100, cables: cs, margin: 0.2)!.minWidth, 400);
    });

    test('옛 기준보다 빡빡하다: 작은 다심 40가닥은 KEC 900폭도 넘는다', () {
      final cs = [_c(22, 4, 24, 40)]; // 외경 합 960 > 900, 옛 기준 단면적 18,096 ≤ 750폭 22,580
      expect(checkTray(type: TrayType.ladder, width: 900, depth: 100, cables: cs)!.ok, isFalse);
      expect(checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 750, depth: 100, cables: cs)!.ok, isTrue);
    });

    test('가장 굵은 케이블이 측판보다 높으면 알린다', () {
      final c = checkTray(type: TrayType.ladder, width: 300, depth: 60, cables: [_c(240, 4, 63, 1)])!;
      expect(c.notes.any((n) => n.contains('측판 높이')), isTrue);
    });
  });

  group('옛 기준 고친 곳', () {
    test('바닥밀폐형 다심 100mm² 이상만: 외경 합 ≤ 폭의 90%', () {
      final cs = [_c(100, 4, 47, 3), _c(150, 4, 55, 3), _c(200, 4, 63, 4)]; // 558
      final c = checkTray(standard: TrayStandard.old213, type: TrayType.solid, width: 600, depth: 100, cables: cs)!;
      expect(c.limit, 540);
      expect(c.ok, isFalse);
      expect(checkTray(standard: TrayStandard.old213, type: TrayType.solid, width: 750, depth: 100, cables: cs)!.ok, isTrue);
    });

    test('단심 50mm² 미만은 규정이 없다고 알린다', () {
      final c = checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 300, depth: 100, cables: [_c(35, 1, 13, 6)])!;
      expect(c.rule, TrayRule.singleLayerDia);
      expect(c.notes.any((n) => n.contains('50mm² 미만')), isTrue);
    });

    test('다심(면적 규칙)과 단심을 함께: 각각 만족, 빠듯한 쪽을 보인다', () {
      final cs = [_c(22, 4, 24, 3), _c(38, 4, 30, 4), _c(60, 4, 37, 4), _c(150, 1, 24, 9)];
      final c = checkTray(standard: TrayStandard.old213, type: TrayType.ladder, width: 300, depth: 100, cables: cs)!;
      // 다심 8,485 / 9,030 = 94% , 단심 4,071 / 8,380 = 49% → 다심 쪽
      expect(c.rule, TrayRule.multiSmallArea);
      expect(c.notes.any((n) => n.contains('각각 만족')), isTrue);
    });
  });
}
