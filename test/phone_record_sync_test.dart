// 폰에만 있던 기록(안전 점검·벤딩 실측)을 서버에도 올리기(10-09 고도화 2번).
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/record_sync.dart';
import 'package:tubing_calculator/src/presentation/bend_check/bend_check_model.dart';
import 'package:tubing_calculator/src/presentation/bend_check/bend_check_page.dart';
import 'package:tubing_calculator/src/presentation/safety/safety_check_model.dart';
import 'package:tubing_calculator/src/presentation/safety/safety_check_page.dart';

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

final _at = DateTime(2026, 10, 9, 8, 5);

SafetyRecord _safety(String id, {int day = 0}) => SafetyRecord(
  id: id,
  at: _at.add(Duration(days: day)),
  site: '현장 A',
  work: '계기 결선',
  lines: const [SafetyLine('작업허가서 확인', SafetyAnswer.yes)],
);

BendCheck _bend(String id, {int day = 0}) => BendCheck(
  id: id,
  at: _at.add(Duration(days: day)),
  group: '1/2" SUS',
  calc: 100,
  actual: 101.5,
);

_FakeRemote _signIn() {
  final server = _FakeRemote();
  recordRemote = () => server;
  recordOwner = () async => const RecordOwner('작업자', 'uid-A');
  return server;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    recordRemote = () => null;
  });
  tearDown(() => recordRemote = () => null);

  test('안전 점검: 저장하면 서버에 올라가고 다른 폰에서 받으며, 지우면 다른 폰에서도 사라진다', () async {
    final server = _signIn();
    await addSafetyRecord(_safety('s1'));
    await RecordSync.idle();
    final doc = server.colls['safety_records']!['s1']!;
    expect(doc['owner'], '작업자');
    expect(doc['site'], '현장 A');

    // 다른 폰(빈 폰)
    SharedPreferences.setMockInitialValues({});
    await safetyRecordSync.syncNow();
    final got = await loadSafetyRecords();
    expect(got.single.work, '계기 결선');
    expect(got.single.lines.single.answer, SafetyAnswer.yes);

    await deleteSafetyRecord('s1');
    await RecordSync.idle();
    expect(server.colls['safety_records']!['s1']!['deleted'], true);
    SharedPreferences.setMockInitialValues({
      kSafetyRecordsKey: jsonEncode([_safety('s1').toJson()]),
    });
    await safetyRecordSync.syncNow();
    expect(await loadSafetyRecords(), isEmpty);
  });

  test('벤딩 실측: 저장·받기·지우기가 서버를 거친다', () async {
    final server = _signIn();
    await addBendCheck(_bend('b1'));
    await RecordSync.idle();
    expect(server.colls['bend_check_records']!['b1']!['actual'], 101.5);

    SharedPreferences.setMockInitialValues({});
    await bendCheckSync.syncNow();
    expect((await loadBendChecks()).single.diff, closeTo(1.5, 1e-9));

    await deleteBendCheck('b1');
    await RecordSync.idle();
    expect(server.colls['bend_check_records']!['b1']!['deleted'], true);
  });

  test('예전에 폰에만 저장한 기록은 목록을 처음 열 때 한꺼번에 올라간다', () async {
    // 이 기능 전에 저장한 기록(서버 표시 없음)
    SharedPreferences.setMockInitialValues({
      kSafetyRecordsKey: jsonEncode([_safety('old1').toJson()]),
      kBendChecksKey: jsonEncode([_bend('old2').toJson()]),
    });
    final server = _signIn();
    expect((await safetyRecordSync.status()).pending, 1);
    await safetyRecordSync.syncNow();
    await bendCheckSync.syncNow();
    expect(server.colls['safety_records']!.keys, ['old1']);
    expect(server.colls['bend_check_records']!.keys, ['old2']);
    expect((await safetyRecordSync.status()).pending, 0);
  });

  test('개수 상한으로 폰에서 밀려난 옛 기록은 서버에서 지우지 않는다', () async {
    final server = _signIn();
    for (var i = 0; i <= kSafetyRecordCap; i++) {
      await addSafetyRecord(_safety('r$i', day: i));
    }
    await RecordSync.idle();
    expect((await loadSafetyRecords()).length, kSafetyRecordCap);
    final docs = server.colls['safety_records']!;
    expect(docs.length, kSafetyRecordCap + 1);
    expect(docs.values.where((d) => d['deleted'] == true), isEmpty);
  });

  testWidgets('지난 점검 기록 화면: 서버에서 받아 보이고 위에 저장 상태 줄이 있다', (tester) async {
    final server = _signIn();
    await tester.runAsync(() async {
      await addSafetyRecord(_safety('s9'));
      await RecordSync.idle();
    });
    expect(server.colls['safety_records']!.containsKey('s9'), true);
    SharedPreferences.setMockInitialValues({}); // 새 폰
    await tester.pumpWidget(
      MaterialApp(home: SafetyHistoryPage(share: (_) async {})),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety_record_s9')), findsOneWidget);
    expect(find.textContaining('서버에 저장되어 있습니다'), findsOneWidget);
  });

  testWidgets('로그인 전이면 점검 기록 화면에 "폰에만 저장" 줄이 보인다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SafetyHistoryPage(share: (_) async {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('저장한 점검 기록이 없습니다'), findsOneWidget);
    expect(find.textContaining('폰에만 저장됩니다'), findsOneWidget);
  });

  testWidgets('벤딩 실측 화면: 다른 폰에서 올린 기록을 받아 보인다', (tester) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = _signIn();
    await tester.runAsync(() async {
      await addBendCheck(_bend('b7'));
      await RecordSync.idle();
    });
    expect(server.colls['bend_check_records']!.containsKey('b7'), true);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(home: BendCheckPage(share: (_) async {})),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bendcheck_record_b7')), findsOneWidget);
    expect(find.byKey(const Key('bendcheck_sync')), findsOneWidget);
    expect(find.textContaining('서버에 저장되어 있습니다'), findsOneWidget);
  });
}
