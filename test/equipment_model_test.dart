// 장비 관리 대장의 계산: 점검 기한, 상태, 점검·반출 기록, 걸러 보기, 내보내기 글.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_model.dart';

final _now = DateTime(2026, 9, 30, 10);

Equipment _e({
  String id = 'e1',
  String name = '압력 게이지',
  String assetNo = '',
  int interval = 12,
  DateTime? last,
  DateTime? override,
  EquipStatus status = EquipStatus.ok,
  String holder = '',
  EquipCategory cat = EquipCategory.personal,
}) => Equipment(
  id: id,
  name: name,
  assetNo: assetNo,
  category: cat,
  intervalMonths: interval,
  lastDone: last,
  dueOverride: override,
  status: status,
  holder: holder,
  createdAt: _now,
);

void main() {
  group('개월 더하기', () {
    test('일반', () => expect(addMonths(DateTime(2026, 1, 15), 12), DateTime(2027, 1, 15)));
    test('말일 넘김: 1/31 + 1개월 = 2/28', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29)); // 윤년
    });
    test('해를 넘김', () => expect(addMonths(DateTime(2026, 11, 10), 3), DateTime(2027, 2, 10)));
  });

  group('기한과 상태', () {
    test('마지막일 + 주기가 다음 기한', () {
      final e = _e(last: DateTime(2026, 3, 31), interval: 6);
      expect(e.nextDue, DateTime(2026, 9, 30));
      expect(e.daysLeft(_now), 0);
      expect(dueLabel(e, _now), '오늘까지');
      expect(e.dueState(_now), DueState.soon);
    });

    test('지났으면 만료, 7일 밖이면 정상, 기한 없으면 none', () {
      expect(_e(last: DateTime(2025, 8, 1)).dueState(_now), DueState.overdue);
      expect(dueLabel(_e(last: DateTime(2025, 8, 1)), _now), '60일 지남');
      expect(_e(last: DateTime(2026, 9, 1)).dueState(_now), DueState.ok);
      expect(dueLabel(_e(last: DateTime(2026, 9, 1)), _now), startsWith('D-'));
      expect(_e(interval: 0, last: DateTime(2020, 1, 1)).dueState(_now), DueState.none);
      expect(_e().dueState(_now), DueState.none); // 마지막일 없음
    });

    test('7일째는 임박, 8일째는 정상', () {
      // 다음 기한 = 오늘 + 7일
      final soon = _e(override: DateTime(2026, 10, 7));
      final ok = _e(override: DateTime(2026, 10, 8));
      expect(soon.dueState(_now), DueState.soon);
      expect(ok.dueState(_now), DueState.ok);
    });

    test('직접 정한 기한이 주기 계산보다 먼저', () {
      final e = _e(last: DateTime(2026, 1, 1), override: DateTime(2026, 12, 25));
      expect(e.nextDue, DateTime(2026, 12, 25));
    });

    test('폐기한 장비는 기한을 따지지 않는다', () {
      final e = _e(last: DateTime(2020, 1, 1), status: EquipStatus.retired);
      expect(e.dueState(_now), DueState.none);
      expect(dueLabel(e, _now), '');
    });
  });

  group('교정·점검 기록', () {
    test('합격하면 마지막일이 바뀌고 직접 정한 기한이 지워진다', () {
      final e = _e(last: DateTime(2025, 1, 1), override: DateTime(2026, 1, 1));
      final r = recordInspection(
        e,
        at: DateTime(2026, 9, 30),
        type: EventType.cal,
        by: '한국교정',
        certNo: 'C-100',
      );
      expect(r.lastDone, DateTime(2026, 9, 30));
      expect(r.dueOverride, isNull);
      expect(r.nextDue, DateTime(2027, 9, 30));
      expect(r.events.first.type, EventType.cal);
      expect(r.events.first.certNo, 'C-100');
      expect(r.events.first.result, kResultPass);
    });

    test('다음 기한을 직접 주면 그 날짜', () {
      final r = recordInspection(
        _e(last: DateTime(2025, 1, 1)),
        at: DateTime(2026, 9, 30),
        type: EventType.check,
        nextDue: DateTime(2027, 3, 1),
      );
      expect(r.nextDue, DateTime(2027, 3, 1));
    });

    test('불합격이면 마지막일은 그대로이고 수리·점검 중이 된다', () {
      final e = _e(last: DateTime(2025, 10, 1));
      final r = recordInspection(
        e,
        at: DateTime(2026, 9, 30),
        type: EventType.cal,
        result: kResultFail,
      );
      expect(r.lastDone, DateTime(2025, 10, 1));
      expect(r.status, EquipStatus.repair);
      expect(r.events.length, 1);
    });

    test('수리 중이던 장비가 합격하면 다시 사용 가능', () {
      final r = recordInspection(
        _e(status: EquipStatus.repair),
        at: DateTime(2026, 9, 30),
        type: EventType.cal,
      );
      expect(r.status, EquipStatus.ok);
    });

    test('이력은 최신이 앞에 쌓인다', () {
      var e = _e();
      e = recordInspection(e, at: DateTime(2026, 1, 1), type: EventType.cal);
      e = recordInspection(e, at: DateTime(2026, 6, 1), type: EventType.check);
      expect(e.events.map((x) => x.type), [EventType.check, EventType.cal]);
    });
  });

  group('수리·폐기', () {
    test('폐기하면 폐기 상태가 되고 이력에 남는다', () {
      final r = retire(_e(), at: _now, note: '파손');
      expect(r.isRetired, true);
      expect(r.events.first.note, '폐기: 파손');
    });

    test('수리 기록과 다시 사용', () {
      var e = recordRepair(_e(), at: _now, by: '제조사');
      expect(e.status, EquipStatus.repair);
      e = markUsable(e, at: _now);
      expect(e.status, EquipStatus.ok);
    });
  });

  group('걸러 보기와 요약', () {
    final list = [
      _e(id: '1', name: '압력 게이지 A', assetNo: 'PG-001', last: DateTime(2025, 1, 1)), // 만료
      _e(id: '2', name: '멀티미터', last: DateTime(2025, 10, 5)), // 임박(5일 남음)
      _e(id: '3', name: '토크 렌치', cat: EquipCategory.work, last: DateTime(2026, 9, 1)), // 정상
      _e(id: '4', name: '튜브 벤더', cat: EquipCategory.work, interval: 0, holder: '홍길동'), // 기한 없음·반출
      _e(id: '5', name: '옛 게이지', last: DateTime(2020, 1, 1), status: EquipStatus.retired),
      _e(id: '6', name: '수리 중 계기', status: EquipStatus.repair, interval: 0),
    ];

    test('요약: 폐기는 뺀다', () {
      final s = summarize(list, _now);
      expect(s.total, 5);
      expect(s.overdue, 1);
      expect(s.soon, 1);
      expect(s.repair, 1);
    });

    test('정렬: 만료 → 임박 → 정상 → 기한 없음 → 폐기', () {
      final ids = sortLedger(list, _now).map((e) => e.id).toList();
      expect(ids.first, '1');
      expect(ids[1], '2');
      expect(ids[2], '3');
      expect(ids.last, '5');
    });

    test('기한 보기는 만료·임박만', () {
      expect(filterLedger(list, _now, view: LedgerView.due).map((e) => e.id), ['1', '2']);
    });

    test('분류·검색(관리번호·이름, 띄어쓰기 무시)', () {
      expect(filterLedger(list, _now, category: EquipCategory.work).map((e) => e.id).toSet(), {'3', '4'});
      expect(filterLedger(list, _now, query: 'pg001'), isEmpty); // 하이픈은 무시하지 않는다
      expect(filterLedger(list, _now, query: 'pg-001').single.id, '1');
      expect(filterLedger(list, _now, query: '압력게이지').single.id, '1');
    });
  });

  group('저장 모양과 글', () {
    test('JSON 왕복', () {
      var e = _e(assetNo: 'PG-001', last: DateTime(2026, 3, 1));
      e = recordInspection(e, at: DateTime(2026, 9, 1), type: EventType.cal, certNo: 'C1');
      e = e.copyWith(holder: '홍길동'); // 예전에 반출해 둔 자료도 그대로 읽고 쓴다
      final back = Equipment.fromJson(e.toJson());
      expect(back.assetNo, 'PG-001');
      expect(back.holder, '홍길동');
      expect(back.events.length, 1);
      expect(back.events.last.certNo, 'C1');
      expect(back.nextDue, e.nextDue);
    });

    test('망가진 자료는 던진다(동기화가 걸러낸다)', () {
      expect(() => Equipment.fromJson({'id': 'x'}), throwsFormatException);
      expect(() => Equipment.fromJson({'name': 'x'}), throwsFormatException);
    });

    test('QR 글은 관리번호가 있으면 그것', () {
      expect(_e(assetNo: 'PG-001').qrText, 'FH-EQ:PG-001');
      expect(_e(id: 'abc').qrText, 'FH-EQ:abc');
    });

    test('CSV: BOM, 따옴표, 기한 상태', () {
      final csv = buildLedgerCsv([_e(name: '게이지 "A"', last: DateTime(2025, 1, 1))], _now);
      expect(csv.startsWith('﻿관리번호,'), true);
      final lines = csv.trim().split('\n');
      expect(lines.length, 2);
      expect(lines[1], contains('"게이지 ""A"""'));
      expect(lines[1], contains('2026-01-01'));
      expect(lines[1], contains('만료'));
    });

    test('기한 글: 없으면 안내, 있으면 만료가 ⚠', () {
      expect(buildDueText([_e(last: DateTime(2026, 9, 1))], _now), contains('없습니다'));
      final t = buildDueText([_e(name: '게이지', assetNo: 'PG-1', last: DateTime(2025, 1, 1))], _now);
      expect(t, contains('⚠ PG-1 게이지'));
      expect(t, contains('지남'));
    });

    test('장비 한 대 글에 이력이 들어간다', () {
      final e = recordInspection(
        _e(name: '게이지', assetNo: 'PG-1'),
        at: DateTime(2026, 9, 1),
        by: '김반장',
      );
      final t = buildEquipmentText(e, _now);
      expect(t, contains('[장비] PG-1 게이지'));
      expect(t, contains('점검 양호 (김반장)'));
    });

    test('예시 목록은 이름이 겹치지 않는다', () {
      final names = kEquipPresets.map((p) => p.name).toList();
      expect(names.toSet().length, names.length);
    });
  });
}
