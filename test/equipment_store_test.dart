// 장비 관리 대장의 저장(폰 안 + 서버 맞추기)과 기한 알림 계획.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/record_sync.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_model.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_reminders.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_store.dart';

class _FakeRemote implements RecordRemote {
  final Map<String, Map<String, Map<String, dynamic>>> colls = {};
  int clock = 1000000;

  @override
  Future<void> write(String c, String id, Map<String, dynamic> fields) async {
    colls.putIfAbsent(c, () => {})[id] = {
      ...fields,
      'updatedAt': Timestamp.fromMillisecondsSinceEpoch(clock++),
    };
  }

  @override
  Future<RemoteFetch> fetch(String c, String owner) async => RemoteFetch([
    for (final e in (colls[c] ?? const {}).entries)
      if (e.value['owner'] == owner) recordFromServerDoc(e.key, e.value),
  ]);
}

final _now = DateTime(2026, 9, 30, 10);

Equipment _e(String id, {String name = '게이지', String assetNo = '', DateTime? last, int interval = 12}) =>
    Equipment(
      id: id,
      name: name,
      assetNo: assetNo,
      intervalMonths: interval,
      lastDone: last,
      createdAt: _now,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('저장소', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('추가·바꾸기·지우기', () async {
      await EquipmentStore.put(_e('a', name: '하나'));
      await EquipmentStore.put(_e('b', name: '둘'));
      await EquipmentStore.put(_e('a', name: '하나(고침)'));
      var all = await EquipmentStore.load();
      expect(all.map((e) => e.name).toSet(), {'하나(고침)', '둘'});
      await EquipmentStore.delete('a');
      all = await EquipmentStore.load();
      expect(all.map((e) => e.id), ['b']);
    });

    test('망가진 자료 한 건은 건너뛰고 나머지는 읽는다', () async {
      SharedPreferences.setMockInitialValues({
        EquipmentStore.key:
            '[{"id":"x"},{"id":"ok","name":"정상","createdAt":"2026-09-30T00:00:00.000"}]',
      });
      final all = await EquipmentStore.load();
      expect(all.single.name, '정상');
    });

    test('관리번호·QR 글·앱 번호·시리얼로 찾는다', () {
      final all = [
        _e('id1', assetNo: 'PG-001'),
        Equipment(id: 'id2', name: '시리얼 장비', serial: 'SN-77', createdAt: _now),
      ];
      expect(EquipmentStore.findByCode(all, 'pg-001')!.id, 'id1');
      expect(EquipmentStore.findByCode(all, 'FH-EQ:PG-001')!.id, 'id1');
      expect(EquipmentStore.findByCode(all, 'FH-EQ:id2')!.id, 'id2');
      expect(EquipmentStore.findByCode(all, 'sn-77')!.id, 'id2');
      expect(EquipmentStore.findByCode(all, '없음'), isNull);
      expect(EquipmentStore.findByCode(all, '  '), isNull);
    });
  });

  group('서버와 맞추기', () {
    test('폰에서 저장한 장비가 서버를 거쳐 다른 폰에 보이고, 지우면 사라진다', () async {
      final server = _FakeRemote();
      recordRemote = () => server;
      recordOwner = () async => const RecordOwner('작업자', 'uid-A');
      addTearDown(() => recordRemote = () => null);

      SharedPreferences.setMockInitialValues({});
      await EquipmentStore.put(_e('a', name: '압력 게이지', assetNo: 'PG-001'));
      await RecordSync.idle();
      expect(server.colls['equipment_ledger']!.containsKey('a'), true);

      // 다른 폰: 폰 저장은 비어 있다.
      SharedPreferences.setMockInitialValues({});
      expect(await EquipmentStore.load(), isEmpty);
      await EquipmentStore.sync.syncNow();
      final got = await EquipmentStore.load();
      expect(got.single.name, '압력 게이지');
      expect(got.single.assetNo, 'PG-001');

      // 그 폰에서 지우면 서버에서도 지움 표시가 되어 처음 폰에서도 사라진다.
      await EquipmentStore.delete('a');
      await RecordSync.idle();
      SharedPreferences.setMockInitialValues({
        EquipmentStore.key: '[{"id":"a","name":"압력 게이지","createdAt":"2026-09-30T00:00:00.000"}]',
      });
      await EquipmentStore.sync.syncNow();
      expect(await EquipmentStore.load(), isEmpty);
    });
  });

  group('기한 알림 계획', () {
    test('30일 전·7일 전·당일 오전 9시, 지난 시각은 뺀다', () {
      final e = _e('a', name: '게이지', assetNo: 'PG-1', last: DateTime(2025, 10, 31)); // 기한 2026-10-31
      final plan = planEquipmentReminders([e], _now);
      expect(plan.map((r) => r.when), [
        DateTime(2026, 10, 1, 9),
        DateTime(2026, 10, 24, 9),
        DateTime(2026, 10, 31, 9),
      ]);
      expect(plan.first.body, contains('PG-1 게이지'));
      expect(plan.first.body, contains('30일 남았습니다'));
      expect(plan.last.body, contains('오늘입니다'));
    });

    test('이미 지난 알림은 잡지 않는다', () {
      // 기한 10/5: 30일 전(9/5)·… 7일 전(9/28)은 지났고 당일(10/5)만 남는다.
      final e = _e('a', last: DateTime(2025, 10, 5));
      final plan = planEquipmentReminders([e], _now);
      expect(plan.length, 1);
      expect(plan.single.when, DateTime(2026, 10, 5, 9));
    });

    test('기한이 없거나 폐기한 장비는 잡지 않는다', () {
      final none = _e('a', interval: 0, last: DateTime(2025, 1, 1));
      final retired = _e('b', last: DateTime(2026, 9, 25)).copyWith(status: EquipStatus.retired);
      expect(planEquipmentReminders([none, retired], _now), isEmpty);
    });

    test('같은 장비·시점은 늘 같은 아이디, 다르면 다른 아이디', () {
      expect(equipNotifId('a', 30), equipNotifId('a', 30));
      expect(equipNotifId('a', 30), isNot(equipNotifId('a', 7)));
      expect(equipNotifId('a', 30), isNot(equipNotifId('b', 30)));
      expect(equipNotifId('a', 0), greaterThanOrEqualTo(0));
    });
  });
}
