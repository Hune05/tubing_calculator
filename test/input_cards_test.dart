// 입력 카드: 밀어서 지우기·되돌리기, 전선관 카드 눌러 고치기, 순서 바꾸기 번호 따라가기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_input_tab.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/swipe_delete.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_input_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('번호 따라가기', () {
    test('옮긴 줄은 새 자리로, 사이 줄은 한 칸씩', () {
      // 0번을 2번 자리로: [a b c] → [b c a]
      expect(movedIndex(0, 0, 2), 2);
      expect(movedIndex(1, 0, 2), 0);
      expect(movedIndex(2, 0, 2), 1);
      // 2번을 0번 자리로: [a b c] → [c a b]
      expect(movedIndex(2, 2, 0), 0);
      expect(movedIndex(0, 2, 0), 1);
      expect(movedIndex(3, 2, 0), 3);
    });

    test('지운 줄 뒤는 한 칸 당기고, 지운 줄을 고치던 중이면 그만둔다', () {
      expect(indexAfterRemove(3, 1), 2);
      expect(indexAfterRemove(1, 3), 1);
      expect(indexAfterRemove(2, 2), isNull);
      expect(indexAfterRemove(null, 0), isNull);
    });
  });

  Future<void> pump(WidgetTester tester, Widget tab) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: tab)));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('전선관 입력 카드', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      final m = ConduitDataManager();
      m.bendList
        ..clear()
        ..addAll([
          {'length': 150.0, 'angle': 0.0, 'rotation': 0.0},
          {'length': 72.3, 'angle': 21.0, 'rotation': 0.0},
          {'length': 195.3, 'angle': 21.0, 'rotation': 180.0},
        ]);
    });

    testWidgets('왼쪽으로 밀면 지워지고, 되돌리기로 제자리에 돌아온다', (tester) async {
      await pump(tester, const ConduitInputTab());
      expect(find.text('길이: 72.3mm'), findsOneWidget);
      // X 단추는 없다.
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.drag(find.text('길이: 72.3mm'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(ConduitDataManager().bendList.length, 2);
      expect(find.text('2번 줄을 지웠습니다.'), findsOneWidget);

      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      final list = ConduitDataManager().bendList;
      expect(list.length, 3);
      expect(list[1]['length'], 72.3);
      expect(list[1]['angle'], 21.0);
    });

    testWidgets('카드를 누르면 고치고, 21° 각도는 그대로 둔다', (tester) async {
      await pump(tester, const ConduitInputTab());
      await tester.tap(find.text('길이: 195.3mm'));
      await tester.pump();
      expect(find.text('수정'), findsOneWidget);
      // 21°는 튜브처럼 "직관+각도" 칸에 들어간다.
      final angleField = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '21',
      );
      expect(angleField, findsOneWidget);

      // 길이를 바꿔 넣고 수정.
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '195.3',
      );
      expect(field, findsOneWidget);
      tester.widget<TextField>(field).controller!.text = '200';
      await tester.pump();
      await tester.ensureVisible(find.text('수정'));
      await tester.pump();
      await tester.tap(find.text('수정'), warnIfMissed: true);
      await tester.pump();

      final list = ConduitDataManager().bendList;
      expect(list.length, 3);
      expect(list[2]['length'], 200.0);
      expect(list[2]['angle'], 21.0);
      expect(list[2]['rotation'], 180.0);
      expect(find.text('추가'), findsOneWidget);
    });

    testWidgets('고치다가 취소하면 목록은 그대로', (tester) async {
      await pump(tester, const ConduitInputTab());
      await tester.tap(find.text('길이: 150.0mm'));
      await tester.pump();
      await tester.ensureVisible(find.byIcon(Icons.close));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.text('추가'), findsOneWidget);
      expect(ConduitDataManager().bendList[0]['length'], 150.0);
    });
  });

  group('전선관 배관 형태', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ConduitDataManager().bendList.clear();
    });

    testWidgets('튜브처럼 세 칸(90° 벤딩·직관+각도·0° 직관)이다', (tester) async {
      await pump(tester, const ConduitInputTab());
      expect(find.text('90° 벤딩'), findsOneWidget);
      expect(find.text('직관+각도'), findsOneWidget);
      expect(find.text('0° 직관'), findsOneWidget);
      // 직관이 기본이라 방향 칸은 안 보인다.
      expect(find.text('진행 방향 (6축)'), findsNothing);
      await tester.tap(find.text('90° 벤딩'));
      await tester.pump();
      expect(find.text('진행 방향 (6축)'), findsOneWidget);
      expect(find.text('FRONT'), findsOneWidget);
    });
  });

  group('튜브 입력 카드', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      final m = MobileBendDataManager();
      m.bendList
        ..clear()
        ..addAll([
          {'length': 150.0, 'angle': 0.0, 'rotation': 0.0},
          {'length': 300.0, 'angle': 90.0, 'rotation': 0.0},
        ]);
    });

    testWidgets('왼쪽으로 밀면 지워지고 되돌릴 수 있다', (tester) async {
      await pump(tester, const MobileInputTab());
      expect(find.byIcon(Icons.close), findsNothing);
      await tester.drag(find.text('길이: 300.0 mm'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(MobileBendDataManager().bendList.length, 1);
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(MobileBendDataManager().bendList.length, 2);
      expect(MobileBendDataManager().bendList[1]['length'], 300.0);
    });

    testWidgets('꾹 눌러 끌 수 있는 목록이다', (tester) async {
      await pump(tester, const MobileInputTab());
      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNWidgets(2));
    });
  });
}
