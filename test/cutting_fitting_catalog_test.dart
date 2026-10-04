// 부속 공제값: 앱 안 부속표(통신 없이), 실측으로 덮기, 저장해 둔 라인에서 되살리기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/utils/db_seeder.dart';
import 'package:tubing_calculator/src/data/models/fitting_item.dart';
import 'package:tubing_calculator/src/data/models/smart_fitting_db.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_fitting_catalog.dart';

void main() {
  final all = SmartFittingDBSeeder.catalog();

  group('내장 부속표', () {
    test('제조사 4곳 × 규격마다 부속이 있다(통신이 없어도 고를 수 있다)', () {
      for (final maker in SmartFittingDBSeeder.makers) {
        for (final size in ['1/4', '3/8', '1/2', '3/4', '1', '8mm', '10mm', '12mm', '20mm', '25mm']) {
          expect(
            builtInFittingMaps(maker: maker, tubeOD: size),
            isNotEmpty,
            reason: '$maker $size',
          );
        }
      }
    });

    test('모든 부속의 공제값은 0보다 크고 id가 겹치지 않는다', () {
      final ids = <String>{};
      for (final m in all) {
        expect((m['deduction'] as num).toDouble(), greaterThan(0), reason: '${m['id']}');
        expect(ids.add(m['id'].toString()), true, reason: '겹치는 id ${m['id']}');
      }
    });

    test('id로 찾으면 같은 부속이 나온다', () {
      final m = all[10];
      final f = builtInFittingById(m['id'].toString())!;
      expect(f.maker, m['maker']);
      expect(f.tubeOD, m['tubeOD']);
      expect(f.deduction, (m['deduction'] as num).toDouble());
      expect(builtInFittingById('없는-id'), isNull);
    });
  });

  group('근사값 표시', () {
    test('내장 부속은 근사값, 직접 입력·직관·실측은 아니다', () {
      final f = builtInFittingById(all.first['id'].toString())!;
      expect(f.isApprox, true);
      expect(f.copyWith(measured: true).isApprox, false);
      expect(SmartFittingDB.getById('none').isApprox, false);
      expect(SmartFittingDB.getById('custom_input').isApprox, false);
      const custom = FittingItem(
        id: 'c', maker: 'CUSTOM', tubeOD: '1/2', category: 'CUSTOM',
        name: '니플', deduction: 10, icon: Icons.extension,
      );
      expect(custom.isApprox, false);
    });

    test('안내 글: 없으면 비고, 있으면 개수를 적는다', () {
      expect(approxFittingNote(0), '');
      expect(approxFittingNote(3), contains('3개'));
      final f = builtInFittingById(all.first['id'].toString())!;
      expect(approxFittingCount([f, f, SmartFittingDB.getById('none')]), 2);
    });
  });

  group('실측 공제값', () {
    test('실측값이 있으면 그 값으로 바꾸고 실측으로 표시한다', () {
      final f = builtInFittingById(all.first['id'].toString())!;
      final o = {fittingKeyOf(f): 13.5};
      final r = withOverride(f, o);
      expect(r.deduction, 13.5);
      expect(r.measured, true);
      expect(r.isApprox, false);
      expect(withOverride(f, const {}), same(f));
    });

    test('잰 값 글 읽기: 0~500mm 숫자만', () {
      expect(parseMeasuredDeduction('12.5'), 12.5);
      expect(parseMeasuredDeduction(' 12,5 '), 12.5);
      expect(parseMeasuredDeduction('0'), 0);
      expect(parseMeasuredDeduction(''), isNull);
      expect(parseMeasuredDeduction('abc'), isNull);
      expect(parseMeasuredDeduction('-1'), isNull);
      expect(parseMeasuredDeduction('501'), isNull);
    });
  });

  group('저장해 둔 라인에서 부속 되살리기', () {
    test('서버 목록의 id(내장 부속표 id)는 공제값을 잃지 않고 되살아난다 — 예전에는 직접 입력(0)으로 바뀌었다', () {
      final f = builtInFittingById(all[5]['id'].toString())!;
      final r = restoreFittingFromPoint({
        'fittingId': f.id,
        'isCustom': false,
        'customDed': f.deduction,
      });
      expect(r.id, f.id);
      expect(r.deduction, f.deduction);
      expect(r.deduction, greaterThan(0));
      expect(r.category, isNot('커스텀'));
    });

    test('실측값이 있으면 되살릴 때도 그 값을 쓴다', () {
      final f = builtInFittingById(all[5]['id'].toString())!;
      final r = restoreFittingFromPoint(
        {'fittingId': f.id},
        overrides: {fittingKeyOf(f): 20.0},
      );
      expect(r.deduction, 20.0);
      expect(r.measured, true);
    });

    test('아무 표에도 없는 id는 저장해 둔 이름·값으로 만든다(0으로 바꾸지 않는다)', () {
      final r = restoreFittingFromPoint({
        'fittingId': 'server-only-1',
        'isCustom': false,
        'customName': '특수 부속',
        'customDed': 17.3,
        'customOD': '3/4',
        'category': 'X',
        'maker': 'Swagelok',
      });
      expect(r.deduction, 17.3);
      expect(r.name, '특수 부속');
      expect(r.tubeOD, '3/4');
      expect(r.maker, 'Swagelok');
    });

    test('직접 입력·직관은 그대로', () {
      final c = restoreFittingFromPoint({
        'fittingId': 'x', 'isCustom': true,
        'customName': '니플', 'customDed': 9.0, 'customOD': '1/2',
      });
      expect(c.category, 'CUSTOM');
      expect(c.deduction, 9.0);
      expect(restoreFittingFromPoint({'fittingId': 'none'}).id, 'none');
      expect(restoreFittingFromPoint({}).id, 'none');
    });

    test('구간 저장 → 되살리기를 한 바퀴 돌려도 같다', () {
      final f = builtInFittingById(all[20]['id'].toString())!;
      final r = restoreFittingFromPoint(fittingPointJson(f));
      expect(r.id, f.id);
      expect(r.deduction, f.deduction);
      expect(r.maker, f.maker);
      expect(r.tubeOD, f.tubeOD);
    });
  });
}
