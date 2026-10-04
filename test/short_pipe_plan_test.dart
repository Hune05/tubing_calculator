// 단관(짧은 직관) 컷팅: 절단 길이, 원자재 본수, 자르는 선 눈금, 카톡 글.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_optimizer.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/short_pipe_plan.dart';

void main() {
  group('절단 길이', () {
    test('입력이 곧 절단 길이', () {
      final c = shortPipeCuts([const ShortPipeRow(250, 4)]);
      expect(c.single.cutLength, 250);
      expect(c.single.qty, 4);
      expect(c.single.ok, true);
    });

    test('중심 간 거리 입력이면 양쪽 부속 공제를 뺀다', () {
      final c = shortPipeCuts(
        [const ShortPipeRow(300, 2)],
        centerToCenter: true,
        endDeduction: 12.7,
      );
      expect(c.single.cutLength, closeTo(274.6, 1e-9));
    });

    test('공제값 합이 길이 이상이면 간섭으로 빼고 이유를 적는다', () {
      final c = shortPipeCuts(
        [const ShortPipeRow(20, 1)],
        centerToCenter: true,
        endDeduction: 12,
      );
      expect(c.single.ok, false);
      expect(c.single.problem, contains('간섭'));
      expect(c.single.cutLength, 0);
    });

    test('개수가 0인 줄은 건너뛰고 길이가 0이면 길이를 넣으라고 한다', () {
      final c = shortPipeCuts([const ShortPipeRow(100, 0), const ShortPipeRow(0, 2)]);
      expect(c.length, 1);
      expect(c.single.problem, contains('길이를 넣으십시오'));
    });
  });

  group('계획', () {
    test('6000mm 한 본에 250mm 24개(톱날 0) — 딱 한 본', () {
      final p = planShortPipes([const ShortPipeRow(250, 24)], stockLength: 6000);
      expect(p.barCount, 1);
      expect(p.pieceCount, 24);
      expect(p.problems, isEmpty);
    });

    test('톱날 3mm이면 253mm씩 먹어 한 본에 23개 — 24개는 두 본', () {
      final p = planShortPipes(
        [const ShortPipeRow(250, 24)],
        stockLength: 6000,
        kerf: 3,
      );
      expect(p.barCount, 2);
      expect(p.pieceCount, 24);
    });

    test('원자재보다 긴 조각은 자를 수 없다고 알린다', () {
      final p = planShortPipes([const ShortPipeRow(7000, 1)], stockLength: 6000);
      expect(p.barCount, 0);
      expect(p.problems.single, contains('자를 수 없습니다'));
    });

    test('이용률·로스', () {
      final p = planShortPipes([const ShortPipeRow(1000, 3)], stockLength: 6000);
      expect(p.barCount, 1);
      expect(p.usage, closeTo(0.5, 1e-9));
      expect(p.lossLength, closeTo(3000, 1e-9));
    });
  });

  group('자르는 선 눈금', () {
    test('끝 다듬기·톱날을 더해 줄자 눈금을 셈한다', () {
      final bar = StockBarPlan(6000, trim: 10)..pieces.addAll([500, 300, 200]);
      final m = barCutMarks(bar, 3);
      expect(m.map((e) => e.cutAt).toList(), [510, 813, 1016]);
      expect(m.map((e) => e.start).toList(), [10, 513, 816]);
    });

    test('끝 다듬기·톱날이 없으면 조각 길이를 이어 더한 값', () {
      final bar = StockBarPlan(6000)..pieces.addAll([100, 100, 100]);
      expect(barCutMarks(bar, 0).map((e) => e.cutAt).toList(), [100, 200, 300]);
    });

    test('마지막 눈금 뒤 남는 길이가 잔재와 같다', () {
      final bar = StockBarPlan(6000, trim: 10)..pieces.addAll([500, 300, 200]);
      final last = barCutMarks(bar, 3).last.cutAt;
      expect(6000 - last - 3, closeTo(bar.remainderWithKerf(3), 1e-9));
    });
  });

  test('카톡 글: 길이별 개수, 본별 눈금, 문제 줄', () {
    final p = planShortPipes(
      [const ShortPipeRow(1000, 2), const ShortPipeRow(500, 1), const ShortPipeRow(9000, 1)],
      stockLength: 6000,
      kerf: 3,
    );
    final t = shortPipePlanText(p);
    expect(t, contains('[단관 컷팅] 원자재 6000mm · 톱날 3mm'));
    expect(t, contains('자를 길이: 1000×2, 500×1'));
    expect(t, contains('원자재 1본 · 조각 3개'));
    expect(t, contains('1번: 1000 + 1000 + 500 → 자르는 선 1000 / 2003 / 2506'));
    expect(t, contains('(잔재 3491)'));
    expect(t, contains('※ 9000mm는 원자재'));
  });
}
