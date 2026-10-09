// 자재 현황 "엑셀(CSV)로 내보내기 / 가져오기" 흐름(10-09): 파일 고르기·확인창·쓰기를 바꿔 넣고 본다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/inventory_csv.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/inventory_csv_actions.dart';

final _server = <String, Map<String, dynamic>>{
  'a': {'name': '유니온 3/8"', 'unit': 'EA', 'qty': 14, 'location': 'A창고'},
};

Future<InventorySnapshot> _read() async => (docs: _server, fromCache: false);

Future<void> _host(
  WidgetTester tester,
  Future<void> Function(BuildContext) run,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => run(context),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('가져오기: 바뀌는 내용을 보여 주고 "가져오기"를 누르면 그 계획으로 쓴다', (tester) async {
    InventoryImportPlan? applied;
    bool? wasOffline;
    const csv = '아이디,이름,위치,수량,내보낼 때 수량\na,"유니온 3/8""",B창고,20,14\n,새 자재,,5,\n';
    await _host(
      tester,
      (context) => importInventoryCsv(
        context,
        worker: '홍',
        uid: 'me',
        pick: () async => utf8.encode('﻿$csv'),
        read: _read,
        apply: (p, {required bool offline}) async {
          applied = p;
          wasOffline = offline;
          return p.updates.length + p.creates.length;
        },
      ),
    );
    expect(find.text('엑셀(CSV)에서 가져오시겠습니까?'), findsOneWidget);
    expect(find.textContaining('유니온 3/8": 14 → 20EA'), findsOneWidget);
    expect(find.textContaining('새로 넣을 자재 1건'), findsOneWidget);
    await tester.tap(find.byKey(const Key('inv_csv_import_ok')));
    await tester.pumpAndSettle();
    expect(applied!.updates.single.fields, {'location': 'B창고'});
    expect(applied!.creates.single.name, '새 자재');
    expect(wasOffline, isFalse);
    expect(find.text('2건을 가져왔습니다.'), findsOneWidget);
  });

  testWidgets('가져오기: 취소하면 쓰지 않는다', (tester) async {
    var called = false;
    await _host(
      tester,
      (context) => importInventoryCsv(
        context,
        worker: '홍',
        uid: 'me',
        pick: () async => utf8.encode('아이디,이름,수량\na,유니온,1\n'),
        read: _read,
        apply: (p, {required bool offline}) async {
          called = true;
          return 0;
        },
      ),
    );
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(called, isFalse);
  });

  testWidgets('가져오기: 바뀌는 것이 없으면 알리기만 한다', (tester) async {
    await _host(
      tester,
      (context) => importInventoryCsv(
        context,
        worker: '홍',
        uid: 'me',
        pick: () async =>
            utf8.encode(buildInventoryCsv([('a', _server['a']!)], 'me')),
        read: _read,
        apply: (p, {required bool offline}) async => fail('쓰면 안 된다'),
      ),
    );
    expect(find.byKey(const Key('inv_csv_nothing')), findsOneWidget);
    expect(find.textContaining('그대로 1건'), findsOneWidget);
  });

  testWidgets('가져오기: UTF-8이 아닌 파일(엑셀 기본 CSV)은 저장 방법을 알려 준다', (tester) async {
    await _host(
      tester,
      (context) => importInventoryCsv(
        context,
        worker: '홍',
        uid: 'me',
        pick: () async => [0xC0, 0xCC, 0xB8, 0xA7, 0x2C, 0x31], // CP949 "이름,1"
        read: _read,
      ),
    );
    expect(find.text('글자를 읽지 못했습니다'), findsOneWidget);
    expect(find.textContaining('CSV UTF-8'), findsOneWidget);
  });

  testWidgets('내보내기: 재고를 CSV 파일로 만들어 넘긴다', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('inv_csv');
    addTearDown(() => tmp.deleteSync(recursive: true));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      ),
    );
    String? content;
    List<int>? bytes;
    await tester.runAsync(() async {
      await _host(
        tester,
        (context) => exportInventoryCsv(
          context,
          uid: 'me',
          read: _read,
          share: (f) async {
            bytes = await f.readAsBytes();
            content = await f.readAsString();
          },
        ),
      );
      for (var i = 0; i < 50 && content == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    // 엑셀에서 한글이 안 깨지게 맨 앞에 BOM(EF BB BF)
    expect(bytes!.take(3).toList(), [0xEF, 0xBB, 0xBF]);
    expect(content, startsWith("아이디,이름"));
    expect(content, contains('a,"유니온 3/8""",기타,,,,A창고,EA,14,0,,14'));
  });
}
