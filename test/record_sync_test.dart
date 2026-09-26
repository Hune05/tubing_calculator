// 교정 기록·압력시험 기록의 서버 올리기·받기(record_sync.dart). 서버는 가짜(FakeRemote)만 쓴다.
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/record_sync.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_record.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_records_page.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_record.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_records_page.dart';

/// Firestore 대신 쓰는 가짜 서버: 모음 → 문서 이름 → 칸.
class FakeRemote implements RecordRemote {
  final Map<String, Map<String, Map<String, dynamic>>> colls = {};

  /// true면 읽기·쓰기가 바로 실패한다(통신 없음·권한 없음).
  bool fail = false;

  /// true면 읽기·쓰기가 끝나지 않는다(통신이 끊긴 채 기다리는 경우).
  bool hang = false;
  int writes = 0;
  int serverClock = 1000000;

  Map<String, dynamic>? doc(String c, String id) => colls[c]?[id];

  @override
  Future<void> write(String c, String id, Map<String, dynamic> fields) async {
    if (hang) return Completer<void>().future;
    if (fail) throw Exception('offline');
    writes++;
    colls.putIfAbsent(c, () => {})[id] = {
      ...fields,
      'updatedAt': Timestamp.fromMillisecondsSinceEpoch(serverClock++),
    };
  }

  @override
  Future<RemoteFetch> fetch(String c, String owner) async {
    if (hang) return Completer<RemoteFetch>().future;
    if (fail) throw Exception('offline');
    return RemoteFetch([
      for (final e in (colls[c] ?? const {}).entries)
        if (e.value['owner'] == owner) recordFromServerDoc(e.key, e.value),
    ]);
  }
}

CalRecord cal(String id, {String tag = 'PT-101'}) => CalRecord(
  id: id,
  date: DateTime(2026, 9, 26, 9),
  tag: tag,
  lrv: 0,
  urv: 10,
  unit: 'bar',
  found: const [CalEntry(reading: 4.0)],
);

PtRecord pt(String id, {String line = 'P-1001'}) =>
    PtRecord(id: id, date: DateTime(2026, 9, 26, 10), line: line);

/// 폰 하나의 저장 내용(바꿔 끼워 폰 두 대를 흉내 낸다).
Future<Map<String, Object>> phoneSnapshot() async {
  final p = await SharedPreferences.getInstance();
  return {for (final k in p.getKeys()) k: p.get(k)!};
}

void usePhone(Map<String, Object> values) =>
    SharedPreferences.setMockInitialValues(values);

void main() {
  late FakeRemote server;
  var clock = 0;

  setUp(() {
    server = FakeRemote();
    clock = 1000;
    recordRemote = () => server;
    recordOwner = () async => const RecordOwner('차재훈', 'uid-a');
    recordSyncClock = () => clock += 10;
    recordSyncTimeout = const Duration(milliseconds: 200);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await RecordSync.idle();
  });

  group('교정 기록', () {
    test('저장하면 서버에 올라간다(주인·editedAt·지움 표시 칸)', () async {
      await CalRecordStore.put(cal('a'));
      await RecordSync.idle();
      final d = server.doc('calibration_records', 'a')!;
      expect(d['owner'], '차재훈');
      expect(d['ownerUid'], 'uid-a');
      expect(d['deleted'], false);
      expect(d['tag'], 'PT-101');
      expect(d['editedAt'], isA<int>());
      expect(d['updatedAt'], isA<Timestamp>());
      final s = await CalRecordStore.sync.status();
      expect(s.enabled, isTrue);
      expect(s.pending, 0);
      expect(recordSyncText(s), contains('서버에 저장되어 있습니다'));
    });

    test('지우기는 지움 표시로 올라가고 다른 폰에서도 지워진다', () async {
      await CalRecordStore.put(cal('a'));
      await CalRecordStore.put(cal('b', tag: 'FT-1'));
      await RecordSync.idle();
      final phoneA = await phoneSnapshot();

      // 폰 B: 처음 열면 서버 것을 받는다
      usePhone({});
      await CalRecordStore.sync.syncNow();
      expect((await CalRecordStore.load()).map((r) => r.id).toSet(), {
        'a',
        'b',
      });
      final phoneB = await phoneSnapshot();

      // 폰 A에서 지운다
      usePhone(phoneA);
      await CalRecordStore.delete('a');
      await RecordSync.idle();
      final d = server.doc('calibration_records', 'a')!;
      expect(d['deleted'], true);
      expect(d.containsKey('tag'), isFalse, reason: '지운 기록 내용은 서버에 남기지 않는다');
      expect((await CalRecordStore.sync.status()).pending, 0);

      // 폰 B를 다시 열면 지워져 있다
      usePhone(phoneB);
      await CalRecordStore.sync.syncNow();
      expect((await CalRecordStore.load()).map((r) => r.id), ['b']);
    });

    test('합치기: 나중에 고친 쪽이 이긴다(서버 것이 나중·폰 것이 나중)', () async {
      await CalRecordStore.put(cal('a', tag: 'PT-1'));
      await RecordSync.idle();
      final phoneA = await phoneSnapshot();

      // 폰 B가 받아서 고친다
      usePhone({});
      await CalRecordStore.sync.syncNow();
      await CalRecordStore.put(cal('a', tag: 'PT-2'));
      await RecordSync.idle();
      expect(server.doc('calibration_records', 'a')!['tag'], 'PT-2');

      // 폰 A를 열면 PT-2(서버 것이 나중)
      usePhone(phoneA);
      await CalRecordStore.sync.syncNow();
      expect((await CalRecordStore.load()).single.tag, 'PT-2');

      // 폰 A가 통신 없이 고친 뒤(PT-3) 통신되면 PT-3이 올라간다(폰 것이 나중)
      server.fail = true;
      await CalRecordStore.put(cal('a', tag: 'PT-3'));
      await RecordSync.idle();
      expect(server.doc('calibration_records', 'a')!['tag'], 'PT-2');
      server.fail = false;
      final s = await CalRecordStore.sync.syncNow();
      expect(s.pending, 0);
      expect(server.doc('calibration_records', 'a')!['tag'], 'PT-3');
      expect((await CalRecordStore.load()).single.tag, 'PT-3');
    });

    test('처음 한 번: 폰에만 있던 예전 기록을 모두 올리고 표시한다', () async {
      // 서버 올리기 전 앱에서 저장한 기록(표시 칸 없음)
      usePhone({
        CalRecordStore.key: jsonEncode([
          cal('old1').toJson(),
          cal('old2', tag: 'LT-9').toJson(),
        ]),
      });
      final before = await CalRecordStore.sync.status();
      expect(before.pending, 2);
      expect(recordSyncText(before), '폰에만 저장된 것 2건 · 통신되면 서버로 올라갑니다.');
      final s = await CalRecordStore.sync.syncNow();
      expect(s.pending, 0);
      expect(server.colls['calibration_records']!.keys.toSet(), {
        'old1',
        'old2',
      });
      final p = await SharedPreferences.getInstance();
      expect(p.getBool(CalRecordStore.sync.uploadedKey), isTrue);
      // 다시 열어도 또 올리지 않는다
      final n = server.writes;
      await CalRecordStore.sync.syncNow();
      expect(server.writes, n);
    });

    test('통신 없음: 폰 저장은 그대로, 올릴 것으로 남고 통신되면 올라간다', () async {
      server.fail = true;
      await CalRecordStore.put(cal('a'));
      await RecordSync.idle();
      expect((await CalRecordStore.load()).single.id, 'a');
      var s = await CalRecordStore.sync.syncNow();
      expect(s.enabled, isTrue);
      expect(s.pending, 1);
      expect((await CalRecordStore.load()).single.id, 'a');
      final p = await SharedPreferences.getInstance();
      expect(p.getBool(CalRecordStore.sync.uploadedKey), isNull);

      server.fail = false;
      s = await CalRecordStore.sync.syncNow();
      expect(s.pending, 0);
      expect(server.doc('calibration_records', 'a'), isNotNull);
    });

    test('통신이 끊긴 채 답이 없어도 저장은 기다리지 않는다', () async {
      server.hang = true;
      final sw = Stopwatch()..start();
      await CalRecordStore.put(cal('a'));
      expect(sw.elapsedMilliseconds, lessThan(150));
      expect((await CalRecordStore.load()).single.id, 'a');
      final s = await CalRecordStore.sync.syncNow(); // 읽기가 시간 초과
      expect(s.pending, 1);
      await RecordSync.idle(); // 올리기도 시간 초과로 끝난다
      expect((await CalRecordStore.sync.status()).pending, 1);
    });

    test('다른 사람 기록·읽을 수 없는 서버 기록은 받지 않는다', () async {
      server.colls['calibration_records'] = {
        'x': {...cal('x').toJson(), 'owner': '김철수', 'editedAt': 5},
        'bad': {'id': 'bad', 'owner': '차재훈', 'editedAt': 5}, // lrv·urv 없음
      };
      await CalRecordStore.sync.syncNow();
      expect(await CalRecordStore.load(), isEmpty);
    });

    test('Firebase가 없거나 로그인하지 않았으면 폰에만 저장한다', () async {
      recordRemote = () => null;
      await CalRecordStore.put(cal('a'));
      final s = await CalRecordStore.sync.syncNow();
      expect(s.enabled, isFalse);
      expect(recordSyncText(s), '폰에만 저장됩니다. 로그인하면 서버에도 저장됩니다.');
      expect((await CalRecordStore.load()).single.id, 'a');

      recordRemote = () => server;
      recordOwner = () async => null;
      expect((await CalRecordStore.sync.status()).enabled, isFalse);
    });
  });

  group('압력시험 기록', () {
    test('저장·지우기가 pressure_test_records에 올라간다', () async {
      await PtRecordStore.put(pt('a'));
      await RecordSync.idle();
      final d = server.doc('pressure_test_records', 'a')!;
      expect(d['line'], 'P-1001');
      expect(d['owner'], '차재훈');
      expect(server.doc('calibration_records', 'a'), isNull);

      await PtRecordStore.delete('a');
      await RecordSync.idle();
      expect(server.doc('pressure_test_records', 'a')!['deleted'], true);
      expect((await PtRecordStore.sync.status()).pending, 0);
    });

    test('다른 폰에서 올린 기록을 받고, 서버 것이 나중이면 서버 것으로 바꾼다', () async {
      server.colls['pressure_test_records'] = {
        'r1': {
          ...pt('r1', line: 'L-7').toJson(),
          'owner': '차재훈',
          'editedAt': 50,
        },
      };
      await PtRecordStore.sync.syncNow();
      expect((await PtRecordStore.load()).single.line, 'L-7');
      server.colls['pressure_test_records']!['r1'] = {
        ...pt('r1', line: 'L-8').toJson(),
        'owner': '차재훈',
        'editedAt': 999999,
      };
      await PtRecordStore.sync.syncNow();
      expect((await PtRecordStore.load()).single.line, 'L-8');
    });
  });

  group('목록 화면', () {
    Widget app(Widget page) => MaterialApp(home: page);

    testWidgets('교정 기록 목록: 서버 기록을 받아 보이고 "서버에 저장"을 알린다', (t) async {
      server.colls['calibration_records'] = {
        'r1': {
          ...cal('r1', tag: 'TT-5').toJson(),
          'owner': '차재훈',
          'editedAt': 50,
        },
      };
      await t.runAsync(() async {
        await t.pumpWidget(app(const CalRecordsPage()));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await t.pump();
      expect(find.text('TT-5'), findsOneWidget);
      expect(find.byKey(const Key('cr_sync')), findsOneWidget);
      expect(find.textContaining('서버에 저장되어 있습니다'), findsOneWidget);
    });

    testWidgets('압력시험 기록 목록: 통신 없으면 "폰에만 저장된 것 N건"', (t) async {
      server.fail = true;
      await t.runAsync(() async {
        await PtRecordStore.put(pt('a', line: 'P-9'));
        await RecordSync.idle();
        await t.pumpWidget(app(const PtRecordsPage()));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await t.pump();
      expect(find.text('P-9'), findsOneWidget);
      expect(find.text('폰에만 저장된 것 1건 · 통신되면 서버로 올라갑니다.'), findsOneWidget);
    });
  });
}
