// 튜브 보관함 탭: 카드 정보(굽힘 수·각도·저장 시각, 시작·도착 모르면 도면 요약),
// 폴더 이름 바꾸기·합치기와 되돌리기, 밀어서 지우기.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/history_card_info.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';

Map<String, dynamic> _row(
  int id, {
  String project = 'A동',
  String from = '모름',
  String to = '모름',
  String note = '',
  List<double> angles = const [90, 45],
  String date = '2026-10-05 15:14',
}) => {
  'id': id,
  'date': date,
  'p_to_p': jsonEncode({
    'project': project,
    'from': from,
    'to': to,
    'note': note,
    'tail': 25,
    'start_fit': true,
  }),
  'pipe_size': '1/2"',
  'total_length': 617.5,
  'bend_data': jsonEncode([
    {'length': 100.0, 'angle': 0.0},
    for (final a in angles) {'length': 50.0, 'angle': a},
  ]),
};

void main() {
  group('카드 정보', () {
    test('시작·도착을 둘 다 모르면 도면 요약을 제목으로 쓴다', () {
      final i = HistoryCardInfo.of(_row(1));
      expect(i.title, '굽힘 2개 도면');
      expect(i.shapeText, '굽힘 2개 (90°, 45°)');
      expect(i.dateText, '2026-10-05 15:14');
      expect(i.cut, 618);
      expect(i.bendCount, 2);
      expect(HistoryCardInfo.of(_row(2, angles: const [])).title, '직관 도면');
      expect(HistoryCardInfo.of(_row(2, angles: const [])).shapeText, '직관만');
    });

    test('하나라도 알면 그대로 보이고, 모르는 쪽만 모름', () {
      expect(HistoryCardInfo.of(_row(1, from: 'A', to: 'B')).title, 'A ➔ B');
      expect(HistoryCardInfo.of(_row(1, from: 'A')).title, 'A ➔ 모름');
    });

    test('각도가 많으면 6개까지만 보이고, 시각이 없던 옛 줄은 날짜만', () {
      final many = HistoryCardInfo.of(
        _row(1, angles: const [10, 20, 30, 40, 50, 60, 70], date: '2026-09-01'),
      );
      expect(many.shapeText, '굽힘 7개 (10°, 20°, 30°, 40°, 50°, 60° …)');
      expect(many.dateText, '2026-09-01');
      expect(
        HistoryCardInfo.of(_row(1, angles: const [22.5])).shapeText,
        '굽힘 1개 (22.5°)',
      );
    });

    test('깨진 줄도 터지지 않는다', () {
      final i = HistoryCardInfo.of({
        'id': 1,
        'p_to_p': '{깨짐',
        'bend_data': 'x',
        'date': null,
        'total_length': 'a',
      });
      expect(i.title, '직관 도면');
      expect(i.cut, 0);
      expect(i.dateText, '');
    });

    test('프로젝트 이름만 바꾸고 다른 값은 그대로 둔다', () {
      final out =
          jsonDecode(historyWithProject(_row(1)['p_to_p'] as String, ' B동 '))
              as Map;
      expect(out['project'], 'B동');
      expect(out['tail'], 25);
      expect(out['start_fit'], true);
      expect(
        (jsonDecode(historyWithProject('{깨짐', 'C')) as Map)['project'],
        'C',
      );
      expect(
        (jsonDecode(historyWithProject(null, 'C')) as Map)['project'],
        'C',
      );
    });
  });

  group('보관함 탭', () {
    late List<Map<String, dynamic>> rows;
    late List<Map<int, String>> updates;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      rows = [
        _row(5, project: 'B동', from: '1번', to: '2번', note: '시험 배관'),
        _row(4, project: 'A동'),
        _row(3, project: 'A동', angles: const [90]),
      ];
      updates = [];
      TubeHistoryDb.load = () async => [
        for (final r in rows) Map<String, dynamic>.from(r),
      ];
      TubeHistoryDb.delete = (id) async =>
          rows.removeWhere((r) => r['id'] == id);
      TubeHistoryDb.insert = (row) async {
        rows.insert(0, Map<String, dynamic>.from(row));
        return null;
      };
      TubeHistoryDb.updatePToP = (m) async {
        updates.add(Map.of(m));
        for (final r in rows) {
          final v = m[r['id']];
          if (v != null) r['p_to_p'] = v;
        }
      };
    });

    Future<void> open(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MobileHistoryTab())),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('카드에 저장 시각과 굽힘 요약이 보이고, 경로를 모르면 도면 요약이 제목', (tester) async {
      await open(tester);
      expect(find.text('보관된 도면 3개'), findsOneWidget);
      expect(find.text('1번 ➔ 2번'), findsOneWidget);
      // 맨 위 폴더(B동)만 열려 있으므로 A동도 펼친다.
      await tester.tap(find.text('A동'));
      await tester.pumpAndSettle();
      expect(find.text('굽힘 2개 도면'), findsOneWidget);
      expect(find.text('굽힘 1개 도면'), findsOneWidget);
      expect(find.text('굽힘 1개 (90°)'), findsOneWidget);
      expect(find.text('2026-10-05 15:14'), findsWidgets);
      expect(find.text('시험 배관'), findsOneWidget);
    });

    testWidgets('폴더 이름을 바꾸면 그 폴더의 모든 줄이 바뀌고, 되돌리기로 돌아온다', (tester) async {
      await open(tester);
      // A동 폴더 펼치기(처음엔 맨 위 폴더만 열려 있다)
      await tester.tap(find.byKey(const ValueKey('tube_folder_menu_A동')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('folder_rename_field')),
        '신규동',
      );
      await tester.tap(find.byKey(const Key('folder_rename_ok')));
      await tester.pumpAndSettle();

      expect(updates.single.keys.toSet(), {4, 3});
      expect(
        jsonDecode(
          rows.firstWhere((r) => r['id'] == 4)['p_to_p'] as String,
        )['project'],
        '신규동',
      );
      expect(
        jsonDecode(
          rows.firstWhere((r) => r['id'] == 4)['p_to_p'] as String,
        )['tail'],
        25,
      );
      expect(
        find.byKey(const ValueKey('tube_folder_menu_신규동')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('tube_folder_menu_A동')), findsNothing);
      expect(
        find.textContaining('작업 이름을 바꿨습니다: 신규동 (2개)'),
        findsOneWidget,
      );

      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(
        jsonDecode(
          rows.firstWhere((r) => r['id'] == 3)['p_to_p'] as String,
        )['project'],
        'A동',
      );
      expect(find.byKey(const ValueKey('tube_folder_menu_A동')), findsOneWidget);
    });

    testWidgets('이미 있는 이름으로 바꾸면 합쳐진다(칩으로 고른다)', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('tube_folder_menu_A동')));
      await tester.pumpAndSettle();
      // 다른 폴더 이름이 칩으로 나온다
      await tester.tap(find.widgetWithText(ChoiceChip, 'B동'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('folder_rename_ok')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('tube_folder_menu_A동')), findsNothing);
      expect(find.byKey(const ValueKey('tube_folder_menu_B동')), findsOneWidget);
      expect(find.textContaining('작업을 합쳤습니다: B동 (2개)'), findsOneWidget);
      expect(find.text('보관된 도면 3개'), findsOneWidget);
    });

    testWidgets('이름을 비우거나 그대로 두면 아무 일도 없다', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('tube_folder_menu_B동')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('folder_rename_ok'))); // 그대로 B동
      await tester.pumpAndSettle();
      expect(updates, isEmpty);

      await tester.tap(find.byKey(const ValueKey('tube_folder_menu_B동')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('folder_rename_field')),
        '   ',
      );
      await tester.tap(find.byKey(const Key('folder_rename_ok')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('folder_rename_field')),
        findsOneWidget,
      ); // 창이 그대로
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(updates, isEmpty);
    });

    testWidgets('바꾸기가 실패하면 알리고 목록은 그대로다', (tester) async {
      await open(tester);
      TubeHistoryDb.updatePToP = (m) async => throw Exception('디스크 가득');
      await tester.tap(find.byKey(const ValueKey('tube_folder_menu_B동')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('folder_rename_field')),
        'C동',
      );
      await tester.tap(find.byKey(const Key('folder_rename_ok')));
      await tester.pumpAndSettle();
      expect(find.text('이름을 바꾸지 못했습니다. 다시 시도하십시오.'), findsOneWidget);
      expect(find.byKey(const ValueKey('tube_folder_menu_B동')), findsOneWidget);
    });

    testWidgets('왼쪽으로 밀면 지워지고, 되돌리기로 다시 들어온다', (tester) async {
      await open(tester);
      await tester.drag(find.text('1번 ➔ 2번'), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(rows.any((r) => r['id'] == 5), isFalse);
      expect(find.textContaining('삭제했습니다'), findsOneWidget);
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(rows.any((r) => r['id'] == 5), isTrue);
    });
  });
}
