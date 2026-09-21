// 입력 목록 되돌리기 / 다시 하기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/bend_list_history.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_input_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_input_tab.dart';

Map<String, dynamic> b(double len, double angle, [double rot = 0]) => {
  'length': len,
  'angle': angle,
  'rotation': rot,
};

List<double> lens(List<Map<String, dynamic>> l) => [
  for (final x in l) (x['length'] as num).toDouble(),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 두 관리자가 같은 규칙을 따르는지 한 벌로 본다.
  // 관리자는 검사 안에서 만든다(만들 때 폰 저장값을 읽기 때문).
  final managers = <String, BendListHistory Function()>{
    '튜브': () => MobileBendDataManager(),
    '전선관': () => ConduitDataManager(),
  };

  for (final e in managers.entries) {
    final name = e.key;
    BendListHistory get() => e.value();
    List<Map<String, dynamic>> list() => (get() as dynamic).bendList;
    dynamic m() => get(); // 두 관리자의 같은 이름 함수를 부른다.

    group(name, () {
      setUp(() {
        SharedPreferences.setMockInitialValues({});
        list().clear();
        get().clearHistory();
      });

      test('넣기·고치기·지우기·순서 바꾸기·전체 삭제를 한 단계씩 되돌리고 다시 한다', () {
        m().addBend(b(100, 0));
        m().addBend(b(200, 90));
        m().addBend(b(300, 0));
        m().updateBend(1, b(250, 90));
        if (name == '튜브') {
          m().reorderBend(0, 2);
        } else {
          m().reorderBends(0, 3); // 끌어 놓기 규칙(뒤로 옮기면 한 칸 당긴다)
        }
        expect(lens(list()), [250, 300, 100]);
        m().removeBend(0);
        expect(lens(list()), [300, 100]);
        m().clearBends();
        expect(list(), isEmpty);

        expect(get().undo(), isTrue);
        expect(lens(list()), [300, 100]);
        get().undo();
        expect(lens(list()), [250, 300, 100]);
        get().undo();
        expect(lens(list()), [100, 250, 300]);
        get().undo();
        expect(lens(list()), [100, 200, 300]);

        expect(get().redo(), isTrue);
        expect(lens(list()), [100, 250, 300]);
        get().redo();
        get().redo();
        get().redo();
        expect(list(), isEmpty);
        expect(get().canRedo, isFalse);
      });

      test('되돌린 뒤 새로 넣으면 다시 하기는 사라진다', () {
        m().addBend(b(100, 0));
        m().addBend(b(200, 0));
        get().undo();
        expect(get().canRedo, isTrue);
        m().addBend(b(300, 0));
        expect(get().canRedo, isFalse);
        expect(lens(list()), [100, 300]);
      });

      test('되돌린 값은 따로 떨어져 있다(목록을 고쳐도 기록이 안 바뀐다)', () {
        m().addBend(b(100, 90));
        m().updateBend(0, b(150, 90));
        list()[0]['length'] = 999.0; // 바깥에서 목록 안을 건드려도
        get().undo();
        expect(lens(list()), [100]);
      });

      test('50단계까지만 기억한다', () {
        for (var i = 0; i < 60; i++) {
          m().addBend(b(i.toDouble(), 0));
        }
        var n = 0;
        while (get().undo()) {
          n++;
        }
        expect(n, BendListHistory.maxSteps);
        expect(list().length, 10);
      });

      test('빈 목록 전체 삭제·제자리 순서 바꾸기는 기록하지 않는다', () {
        m().clearBends();
        expect(get().canUndo, isFalse);
        m().addBend(b(100, 0));
        m().addBend(b(200, 0));
        final depth = get().undoDepth;
        if (name == '전선관') {
          m().reorderBends(1, 1);
          expect(get().undoDepth, depth);
        }
      });
    });
  }

  group('화면', () {
    Future<void> pump(WidgetTester tester, Widget tab) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: tab)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('전선관: 밀어서 지우고 ↶로 되돌리고 ↷로 다시 지운다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final m = ConduitDataManager();
      m.bendList
        ..clear()
        ..addAll([b(150, 0), b(72.3, 21), b(195.3, 21, 180)]);
      m.clearHistory();
      await pump(tester, const ConduitInputTab());

      final undo = find.byKey(const Key('list_undo'));
      expect(tester.widget<IconButton>(undo).onPressed, isNull);

      await tester.drag(find.text('길이: 72.3mm'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(m.bendList.length, 2);

      expect(find.text('2번 줄을 지웠습니다.'), findsOneWidget);
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect(lens(m.bendList), [150, 72.3, 195.3]);
      // ↶를 누르면 지운 줄 알림이 닫힌다(그 알림으로 한 번 더 넣지 않게).
      expect(find.text('2번 줄을 지웠습니다.'), findsNothing);

      await tester.tap(find.byKey(const Key('list_redo')));
      await tester.pumpAndSettle();
      expect(lens(m.bendList), [150, 195.3]);
    });

    testWidgets('튜브: 지운 줄 알림의 "되돌리기"도 같은 기록을 쓴다(다시 하기가 이어진다)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final m = MobileBendDataManager();
      m.bendList
        ..clear()
        ..addAll([b(150, 0), b(300, 90)]);
      m.clearHistory();
      await pump(tester, const MobileInputTab());

      await tester.drag(find.text('길이: 300.0 mm'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(lens(m.bendList), [150, 300]);
      expect(m.canRedo, isTrue);
      expect(m.canUndo, isFalse);
    });
  });
}
