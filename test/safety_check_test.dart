// 작업 전 안전 점검: 글 만들기·저장 구조, 화면에서 체크→저장→기록→다시 보내기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/safety/safety_check_model.dart';
import 'package:tubing_calculator/src/presentation/safety/safety_check_page.dart';

final _at = DateTime(2026, 9, 30, 8, 5);

SafetyRecord _rec({List<SafetyLine>? lines, String id = '1'}) => SafetyRecord(
  id: id,
  at: _at,
  site: '루마',
  work: '센서 3개소 결선',
  people: '홍길동, 김철수',
  risks: '바닥 미끄러움',
  lines:
      lines ??
      const [
        SafetyLine('작업허가서 확인', SafetyAnswer.yes),
        SafetyLine('밀폐 공간 확인', SafetyAnswer.na),
        SafetyLine('보호구 착용', SafetyAnswer.none),
      ],
);

void main() {
  group('글과 자료', () {
    test('카톡 글: 확인은 ✔, 해당 없음은 -, 미확인은 □', () {
      expect(
        buildSafetyCheckText(_rec()),
        '[작업 전 안전 점검] 9/30 (수) 08:05\n'
        '현장: 루마\n'
        '작업: 센서 3개소 결선\n'
        '✔ 작업허가서 확인\n'
        '- 밀폐 공간 확인 (해당 없음)\n'
        '□ 보호구 착용 (미확인)\n'
        '위험 요인·메모: 바닥 미끄러움\n'
        '참석: 홍길동, 김철수',
      );
    });

    test('비어 있는 칸은 글에서 뺀다', () {
      final t = buildSafetyCheckText(
        SafetyRecord(id: 'x', at: _at, lines: const []),
      );
      expect(t, '[작업 전 안전 점검] 9/30 (수) 08:05');
    });

    test('저장했다 읽으면 그대로고, 미확인 수를 센다', () {
      final r = SafetyRecord.fromJson(_rec().toJson())!;
      expect(r.site, '루마');
      expect(r.lines.length, 3);
      expect(r.lines[1].answer, SafetyAnswer.na);
      expect(r.unanswered, 1);
    });

    test('깨진 자료는 무시한다', () {
      expect(SafetyRecord.fromJson('x'), isNull);
      expect(SafetyRecord.fromJson({'at': 'x'}), isNull);
    });

    test('기본 항목이 있고 겹치지 않는다', () {
      expect(kDefaultSafetyItems.toSet().length, kDefaultSafetyItems.length);
      expect(kDefaultSafetyItems.length, greaterThanOrEqualTo(8));
    });
  });

  group('저장소', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('추가·읽기·지우기, 최근 것이 앞', () async {
      await addSafetyRecord(_rec(id: 'a'));
      await addSafetyRecord(
        SafetyRecord(
          id: 'b',
          at: _at.add(const Duration(hours: 1)),
          lines: const [],
        ),
      );
      var all = await loadSafetyRecords();
      expect(all.map((e) => e.id), ['b', 'a']);
      await deleteSafetyRecord('b');
      all = await loadSafetyRecords();
      expect(all.map((e) => e.id), ['a']);
    });

    test('같은 번호를 다시 저장하면 덮어쓴다', () async {
      await addSafetyRecord(_rec(id: 'a'));
      await addSafetyRecord(_rec(id: 'a'));
      expect((await loadSafetyRecords()).length, 1);
    });

    test('기록은 상한(100)까지만 남긴다', () async {
      for (var i = 0; i < 105; i++) {
        await addSafetyRecord(
          SafetyRecord(
            id: '$i',
            at: _at.add(Duration(minutes: i)),
            lines: const [],
          ),
        );
      }
      expect((await loadSafetyRecords()).length, kSafetyRecordCap);
    });

    test('항목을 고쳐 저장하면 다음에 그대로 읽는다', () async {
      expect(await loadSafetyItems(), kDefaultSafetyItems);
      await saveSafetyItems(['하나', '둘']);
      expect(await loadSafetyItems(), ['하나', '둘']);
    });
  });

  group('화면', () {
    String? sent;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      sent = null;
    });

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: SafetyCheckPage(share: (t) async => sent = t, now: () => _at),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('항목이 뜨고, 확인을 누르면 체크되고 다시 누르면 풀린다', (tester) async {
      await open(tester);
      expect(find.text('작업허가서 확인'), findsOneWidget);
      final yes = find.byKey(const Key('safety_yes_작업허가서 확인'));
      await tester.tap(yes);
      await tester.pump();
      expect(tester.widget<ChoiceChip>(yes).selected, true);
      await tester.tap(yes);
      await tester.pump();
      expect(tester.widget<ChoiceChip>(yes).selected, false);
    });

    testWidgets('적던 체크·작업 내용은 화면을 나갔다 와도 남는다(10-08)', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('safety_yes_작업허가서 확인')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('safety_work')), '배관 용접');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      await open(tester);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('safety_yes_작업허가서 확인'))).selected, true);
      expect(find.text('배관 용접'), findsOneWidget);
    });

    testWidgets('미확인이 있으면 물어보고, 그대로 하면 저장·전송된다', (tester) async {
      await open(tester);
      await tester.enterText(find.byKey(const Key('safety_work')), '결선');
      await tester.tap(find.byKey(const Key('safety_yes_작업허가서 확인')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('safety_send')));
      await tester.pumpAndSettle();
      expect(find.text('확인하지 않은 항목이 있습니다'), findsOneWidget);
      await tester.tap(find.text('다시 확인'));
      await tester.pumpAndSettle();
      expect(sent, isNull);
      expect(await loadSafetyRecords(), isEmpty);

      await tester.tap(find.byKey(const Key('safety_send')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety_confirm_go')));
      await tester.pumpAndSettle();
      expect(sent, contains('작업: 결선'));
      expect(sent, contains('✔ 작업허가서 확인'));
      final saved = await loadSafetyRecords();
      expect(saved.length, 1);
      expect(saved.single.work, '결선');
      // 저장한 뒤 화면은 새 점검으로 비워진다.
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('safety_yes_작업허가서 확인')))
            .selected,
        false,
      );
    });

    testWidgets('모두 확인하면 묻지 않고 저장, 현장 이름은 기억한다', (tester) async {
      SharedPreferences.setMockInitialValues({
        kSafetyItemsKey: ['가', '나'],
      });
      await open(tester);
      await tester.enterText(find.byKey(const Key('safety_site')), '루마');
      await tester.tap(find.byKey(const Key('safety_yes_가')));
      await tester.tap(find.byKey(const Key('safety_na_나')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('safety_save')));
      await tester.pumpAndSettle();
      expect(find.text('확인하지 않은 항목이 있습니다'), findsNothing);
      expect(find.text('저장했습니다'), findsOneWidget);
      final p = await SharedPreferences.getInstance();
      expect(p.getString(kSafetySiteKey), '루마');
      expect((await loadSafetyRecords()).single.lines.map((l) => l.answer), [
        SafetyAnswer.yes,
        SafetyAnswer.na,
      ]);
    });

    testWidgets('항목 고치기: 더하고 지운다', (tester) async {
      SharedPreferences.setMockInitialValues({
        kSafetyItemsKey: ['가', '나'],
      });
      await open(tester);
      await tester.tap(find.byKey(const Key('safety_edit_items')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('safety_add_field')), '다');
      await tester.tap(find.byKey(const Key('safety_add_button')));
      await tester.pump();
      // 휴지통 단추는 없고, 왼쪽으로 밀어서 지운다.
      expect(find.byKey(const Key('safety_remove_가')), findsNothing);
      await tester.drag(find.byKey(const Key('safety_item_나')), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safety_item_나')), findsNothing);
      expect(find.text('삭제했습니다: 나'), findsOneWidget);
      // 되돌리기로 같은 자리에 다시 들어온다.
      await tester.tap(find.byKey(const Key('safety_item_undo')));
      await tester.pump();
      expect(find.byKey(const Key('safety_item_나')), findsOneWidget);
      await tester.drag(find.byKey(const Key('safety_item_가')), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety_items_done')));
      await tester.pumpAndSettle();
      expect(find.text('가'), findsNothing);
      expect(find.text('나'), findsOneWidget);
      expect(find.text('다'), findsOneWidget);
      expect(await loadSafetyItems(), ['나', '다']);
    });

    testWidgets('지난 기록에서 보고 다시 보내고 지운다', (tester) async {
      await addSafetyRecord(_rec(id: '7'));
      await open(tester);
      await tester.tap(find.byKey(const Key('safety_history')));
      await tester.pumpAndSettle();
      expect(find.textContaining('루마'), findsWidgets);
      await tester.tap(find.byKey(const Key('safety_record_7')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety_history_send')));
      await tester.pumpAndSettle();
      expect(sent, contains('[작업 전 안전 점검]'));

      await tester.tap(find.byKey(const Key('safety_record_7')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety_history_delete')));
      await tester.pumpAndSettle();
      expect(find.text('저장한 점검 기록이 없습니다'), findsOneWidget);
      // 지운 뒤 되돌리기로 다시 들어온다.
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safety_record_7')), findsOneWidget);
      expect((await loadSafetyRecords()).single.id, '7');
      // 줄을 왼쪽으로 밀어도 지운다.
      await tester.drag(find.byKey(const Key('safety_record_7')), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('저장한 점검 기록이 없습니다'), findsOneWidget);
      expect(await loadSafetyRecords(), isEmpty);
      expect(find.text('되돌리기'), findsOneWidget);
    });
  });
}
