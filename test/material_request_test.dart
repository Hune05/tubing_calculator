import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/ai_material_note.dart';
import 'package:tubing_calculator/src/presentation/inventory/material_catalog.dart';
import 'package:tubing_calculator/src/presentation/material_request/material_request_logic.dart';
import 'package:tubing_calculator/src/presentation/material_request/material_request_page.dart';

const _tube = MaterialNoteItem(name: '튜브', spec: '6mm SS316', qty: 50, unit: 'm');
const _elbow = MaterialNoteItem(name: '엘보', qty: 4, unit: '개');
const _noQty = MaterialNoteItem(name: '너트', spec: 'M8', unsure: true);

void main() {
  group('글 만들기', () {
    test('수량 꼴', () {
      expect(formatQty(50), '50');
      expect(formatQty(2.5), '2.5');
      expect(formatQty(2.456), '2.46');
    });

    test('카톡에 보낼 글', () {
      final t = buildMaterialRequestText(
        [_tube, _elbow],
        date: DateTime(2026, 9, 30),
        site: ' 루마 ',
      );
      expect(t, '[자재 요청] 9/30 (수) 루마\n1. 튜브 6mm SS316  50m\n2. 엘보  4개');
    });

    test('현장 이름이 없으면 머리에서 뺀다, 수량 없으면 이름만', () {
      final t = buildMaterialRequestText([_noQty], date: DateTime(2026, 10, 4));
      expect(t, '[자재 요청] 10/4 (일)\n1. 너트 M8');
    });
  });

  group('카탈로그 맞추기', () {
    const cat = [
      CatalogItem(id: 'a', name: '후강 전선관 22mm', category: 'CONDUIT', unit: '본', spec: '22mm'),
      CatalogItem(id: 'b', name: '후강 전선관 16mm', category: 'CONDUIT', unit: '본', spec: '16mm'),
      CatalogItem(id: 'c', name: '엘보 90도 16mm', category: 'ACC', unit: 'EA', spec: '16mm'),
      CatalogItem(id: 'd', name: '엘보 90도 22mm', category: 'ACC', unit: 'EA', spec: '22mm'),
    ];
    final m = CatalogMatcher(cat);

    test('이름과 규격이 분명히 하나에 맞으면 제안', () {
      final c = m.match(const MaterialNoteItem(name: '후강 전선관', spec: '22mm', qty: 3));
      expect(c?.id, 'a');
    });

    test('여러 개에 똑같이 맞으면(애매) 제안하지 않는다', () {
      expect(m.match(const MaterialNoteItem(name: '엘보', qty: 3)), isNull);
    });

    test('아무것에도 안 맞으면 null, 이미 같은 이름이면 null', () {
      expect(m.match(const MaterialNoteItem(name: '망치', qty: 1)), isNull);
      expect(m.match(const MaterialNoteItem(name: '후강 전선관 22mm', qty: 1)), isNull);
    });

    test('맞추면 이름이 바뀌고 수량은 그대로, 단위는 비었을 때만 채운다', () {
      final it = const MaterialNoteItem(name: '후강 전선관', spec: '22mm', qty: 3, unsure: true);
      final out = applyCatalog(it, cat[0]);
      expect(out.name, '후강 전선관 22mm');
      expect(out.spec, '');
      expect(out.qty, 3);
      expect(out.unit, '본');
      expect(out.unsure, true);
      expect(applyCatalog(it.copyWith(unit: '롤'), cat[0]).unit, '롤');
    });

    test('실제 자재 목록으로 돌려도 끝나고 예외가 없다', () {
      final real = CatalogMatcher(allMaterialCatalog());
      real.match(const MaterialNoteItem(name: '튜브', spec: '6mm', qty: 1));
    });
  });

  test('서버가 준 항목 읽기: 수량 없으면 확인 대상', () {
    final a = MaterialNoteItem.fromMap({'name': '튜브', 'qty': 3, 'unit': 'm', 'unsure': false});
    expect(a!.qty, 3);
    expect(a.unsure, false);
    expect(MaterialNoteItem.fromMap({'name': '엘보', 'qty': null})!.unsure, true);
    expect(MaterialNoteItem.fromMap({'name': ' '}), isNull);
    expect(MaterialNoteItem.fromMap('x'), isNull);
  });

  group('화면', () {
    late String? shared;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      shared = null;
    });

    Widget host({MaterialNoteCall? parse, List<CatalogItem> catalog = const []}) => MaterialApp(
      home: MaterialRequestPage(
        parse: parse ?? (b) async => const MaterialNoteResult.ok([_tube, _noQty], remaining: 19),
        pickPhoto: (s) async => Uint8List.fromList([1, 2, 3]),
        share: (t) async => shared = t,
        catalog: catalog,
        today: DateTime(2026, 9, 30),
      ),
    );

    testWidgets('찍으면 목록이 뜨고, 확인 줄이 있으면 물은 뒤 보낸다', (tester) async {
      await tester.pumpWidget(host());
      expect(find.byKey(const Key('mr_send')), findsNothing);
      await tester.tap(find.byKey(const Key('mr_camera')));
      await tester.pumpAndSettle();
      expect(find.text('튜브 6mm SS316'), findsOneWidget);
      expect(find.text('확인'), findsOneWidget); // 너트 줄 표시
      expect(find.textContaining('오늘 19번'), findsOneWidget);

      await tester.tap(find.byKey(const Key('mr_send')));
      await tester.pumpAndSettle();
      expect(find.text('확인하지 않은 줄이 있습니다'), findsOneWidget);
      await tester.tap(find.text('다시 확인'));
      await tester.pumpAndSettle();
      expect(shared, isNull);

      await tester.tap(find.byKey(const Key('mr_send')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('그대로 보내기'));
      await tester.pumpAndSettle();
      expect(shared, '[자재 요청] 9/30 (수)\n1. 튜브 6mm SS316  50m\n2. 너트 M8');
    });

    testWidgets('줄을 고치면 확인 표시가 사라지고 글에 반영된다', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('mr_gallery')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mr_row_1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('mr_edit_qty')), '8');
      await tester.enterText(find.byKey(const Key('mr_edit_unit')), '개');
      await tester.tap(find.byKey(const Key('mr_edit_save')));
      await tester.pumpAndSettle();
      expect(find.text('확인'), findsNothing);

      await tester.tap(find.byKey(const Key('mr_send')));
      await tester.pumpAndSettle();
      expect(shared, contains('2. 너트 M8  8개'));
    });

    testWidgets('수량에 글자를 넣으면 막는다', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('mr_camera')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mr_row_0')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('mr_edit_qty')), 'abc');
      await tester.tap(find.byKey(const Key('mr_edit_save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('0보다 큰 숫자'), findsOneWidget);
    });

    testWidgets('현장 이름이 글 머리에 붙고 기억된다', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('mr_camera')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('mr_site')), '루마');
      await tester.pump();
      expect(
        tester.widget<SelectableText>(find.byKey(const Key('mr_preview'))).data,
        startsWith('[자재 요청] 9/30 (수) 루마'),
      );
      await tester.tap(find.byKey(const Key('mr_send')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('그대로 보내기'));
      await tester.pumpAndSettle();
      final p = await SharedPreferences.getInstance();
      expect(p.getString(kMaterialRequestSiteKey), '루마');
    });

    testWidgets('실패하면 안내만 뜨고 목록은 비어 있다', (tester) async {
      await tester.pumpWidget(host(parse: (b) async => const MaterialNoteResult.fail('AI가 지금 응답하지 않습니다')));
      await tester.tap(find.byKey(const Key('mr_camera')));
      await tester.pumpAndSettle();
      expect(find.text('AI가 지금 응답하지 않습니다'), findsOneWidget);
      expect(find.byKey(const Key('mr_send')), findsNothing);
    });

    testWidgets('목록이 없다는 답이면 다시 찍으라고 안내', (tester) async {
      await tester.pumpWidget(host(parse: (b) async => const MaterialNoteResult.ok([])));
      await tester.tap(find.byKey(const Key('mr_camera')));
      await tester.pumpAndSettle();
      expect(find.textContaining('목록을 찾지 못했습니다'), findsOneWidget);
    });

    testWidgets('사진을 고르지 않으면 서버를 부르지 않는다', (tester) async {
      var called = false;
      await tester.pumpWidget(MaterialApp(
        home: MaterialRequestPage(
          parse: (b) async {
            called = true;
            return const MaterialNoteResult.ok([_tube]);
          },
          pickPhoto: (ImageSource s) async => null,
          catalog: const [],
        ),
      ));
      await tester.tap(find.byKey(const Key('mr_camera')));
      await tester.pumpAndSettle();
      expect(called, false);
    });

    testWidgets('줄을 밀어 지우면 되돌리기가 뜬다', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('mr_camera')));
      await tester.pumpAndSettle();
      await tester.drag(find.byKey(const Key('mr_row_0')), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('튜브 6mm SS316'), findsNothing);
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(find.text('튜브 6mm SS316'), findsOneWidget);
    });

    testWidgets('카탈로그 제안을 누르면 이름이 바뀐다', (tester) async {
      const cat = [
        CatalogItem(id: 'a', name: '후강 전선관 22mm', category: 'CONDUIT', unit: '본', spec: '22mm'),
      ];
      await tester.pumpWidget(host(
        parse: (b) async => const MaterialNoteResult.ok([
          MaterialNoteItem(name: '후강 전선관', spec: '22mm', qty: 3, unit: '본'),
        ]),
        catalog: cat,
      ));
      await tester.tap(find.byKey(const Key('mr_camera')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mr_suggest_0')));
      await tester.pumpAndSettle();
      expect(find.text('후강 전선관 22mm'), findsOneWidget);
      expect(find.byKey(const Key('mr_suggest_0')), findsNothing);
    });
  });
}
