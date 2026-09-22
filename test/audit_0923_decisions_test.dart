// 2026-09-23 점검결과 "아침에 정할 것"에서 정한 대로 고친 것들의 확인.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/inventory_view_logic.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';

void main() {
  group('4번 컷팅 기록의 톱날 손실 몫', () {
    test('kerf가 저장·복원되고, 누적 합계 몫에 톱날 손실이 들어간다', () {
      final r = CutRecord(
        id: 'a',
        projectId: 'p',
        timestamp: DateTime(2026, 9, 23),
        tubeSize: '1/2"',
        originalLength: 1000,
        startFitting: '직관',
        endFitting: '직관',
        cutLength: 980,
        multiplier: 3,
        kerf: 2,
      );
      final back = CutRecord.fromMap('a', r.toMap());
      expect(back.kerf, 2);
      expect(back.usedWithKerf, (980 + 2) * 3);
    });

    test('예전 기록(kerf 없음)은 0으로 읽혀 예전처럼 절단 길이만 빠진다', () {
      final back = CutRecord.fromMap('b', {
        'projectId': 'p',
        'timestamp': '2026-09-23T00:00:00.000',
        'cutLength': 500.0,
        'multiplier': 2,
      });
      expect(back.kerf, 0);
      expect(back.usedWithKerf, 1000);
      expect(back.toMap().containsKey('kerf'), isFalse);
    });
  });

  group('3번 재고 칸 이름 두 가지', () {
    test('min_qty로 저장된 예전 자재도 부족으로 잡힌다', () {
      expect(isShortStock({'qty': 2, 'min_qty': 5}), isTrue);
      expect(isShortStock({'qty': 9, 'min_qty': 5}), isFalse);
      expect(isShortStock({'qty': 2, 'minQty': 5, 'min_qty': 1}), isTrue);
    });
  });

  group('2번 PC 일지 날짜', () {
    test('dateISO가 있으면 연도까지 읽고, 없으면 MM/DD로 추정한다', () {
      expect(
        reportDateOf({'date': '01/05', 'dateISO': '2025-01-05T09:00:00.000'}),
        DateTime(2025, 1, 5),
      );
      final guess = reportDateOf({'date': '01/05'});
      expect(guess.month, 1);
      expect(guess.day, 5);
    });
  });
}
