// 벤딩 실측 기록: 차이·통계·참고 글, 저장소, 화면(참고가 바뀌고 계산 결과는 건드리지 않음).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/bend_check/bend_check_model.dart';
import 'package:tubing_calculator/src/presentation/bend_check/bend_check_page.dart';

final _t = DateTime(2026, 9, 30, 9);

BendCheck _c(String id, double calc, double actual, {String g = 'A', int day = 0}) =>
    BendCheck(
      id: id,
      at: _t.add(Duration(days: day)),
      group: g,
      calc: calc,
      actual: actual,
    );

void main() {
  group('통계', () {
    test('차이는 실측 − 계산', () {
      expect(_c('1', 100, 101.5).diff, closeTo(1.5, 1e-9));
      expect(_c('2', 100, 99).diff, -1);
    });

    test('묶음별 평균·범위·건수, 다른 묶음은 섞이지 않는다', () {
      final all = [
        _c('1', 100, 101),
        _c('2', 200, 203),
        _c('3', 50, 49),
        _c('4', 10, 20, g: 'B'),
      ];
      final s = statsFor(all, 'A')!;
      expect(s.n, 3);
      expect(s.mean, closeTo((1 + 3 - 1) / 3, 1e-9));
      expect(s.min, -1);
      expect(s.max, 3);
      expect(s.spread, greaterThan(0));
      expect(statsFor(all, 'B')!.mean, 10);
      expect(statsFor(all, '없음'), isNull);
    });

    test('하나뿐이면 흩어짐은 0', () {
      expect(statsFor([_c('1', 10, 11)], 'A')!.spread, 0);
    });

    test('참고 글', () {
      expect(
        referenceText(statsFor([_c('1', 100, 101), _c('2', 100, 103)], 'A')!),
        '지난 실측 2건: 평균 +2 mm (실측이 계산보다 길었습니다), 범위 +1 mm ~ +3 mm',
      );
      expect(
        referenceText(statsFor([_c('1', 100, 99.5)], 'A')!),
        '지난 실측 1건: 평균 -0.5 mm (실측이 계산보다 짧았습니다)',
      );
      expect(referenceText(statsFor([_c('1', 100, 100)], 'A')!), contains('거의 같았습니다'));
    });

    test('묶음 이름은 최근에 쓴 것이 앞이고 겹치지 않는다', () {
      final all = [
        _c('1', 1, 1, g: 'A', day: 0),
        _c('2', 1, 1, g: 'B', day: 2),
        _c('3', 1, 1, g: 'A', day: 1),
      ];
      expect(groupNames(all), ['B', 'A']);
    });

    test('공유 글', () {
      final t = buildBendCheckText([_c('1', 100, 101.5)]);
      expect(t, contains('[벤딩 실측 기록]'));
      expect(t, contains('■ A'));
      expect(t, contains('계산 100 → 실측 101.5 (+1.5 mm)'));
    });

    test('깨진 자료는 무시한다', () {
      expect(BendCheck.fromJson('x'), isNull);
      expect(BendCheck.fromJson({'at': '2026-01-01', 'calc': 'x', 'actual': 1}), isNull);
    });
  });

  group('저장소', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('추가·읽기·지우기, 최근 것이 앞, 같은 번호는 덮어씀', () async {
      await addBendCheck(_c('a', 1, 2, day: 0));
      await addBendCheck(_c('b', 1, 2, day: 1));
      await addBendCheck(_c('a', 1, 3, day: 0));
      var all = await loadBendChecks();
      expect(all.map((e) => e.id), ['b', 'a']);
      expect(all.last.actual, 3);
      await deleteBendCheck('b');
      all = await loadBendChecks();
      expect(all.map((e) => e.id), ['a']);
    });

    test('상한(300)까지만 남긴다', () async {
      for (var i = 0; i < 305; i++) {
        await addBendCheck(_c('$i', 1, 2, day: i));
      }
      expect((await loadBendChecks()).length, kBendCheckCap);
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
      var tick = 0; // 저장할 때마다 다른 시각(같은 시각이면 같은 번호가 된다)
      await tester.pumpWidget(
        MaterialApp(
          home: BendCheckPage(
            share: (t) async => sent = t,
            now: () => _t.add(Duration(seconds: tick++)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> record(WidgetTester tester, String calc, String actual) async {
      await tester.enterText(find.byKey(const Key('bendcheck_calc')), calc);
      await tester.enterText(find.byKey(const Key('bendcheck_actual')), actual);
      await tester.pump();
      await tester.tap(find.byKey(const Key('bendcheck_save')));
      await tester.pumpAndSettle();
    }

    testWidgets('입력하면 차이가 바로 보이고, 저장하면 기록과 참고가 생긴다', (tester) async {
      await open(tester);
      await tester.enterText(find.byKey(const Key('bendcheck_group')), 'A');
      await tester.enterText(find.byKey(const Key('bendcheck_calc')), '100');
      await tester.enterText(find.byKey(const Key('bendcheck_actual')), '101,5');
      await tester.pump();
      expect(find.text('차이 (실측 − 계산): +1.5 mm'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bendcheck_save')));
      await tester.pumpAndSettle();
      expect(find.text('저장했습니다'), findsOneWidget);
      expect((await loadBendChecks()).single.actual, 101.5);
      // 입력칸은 비워지고, 같은 묶음의 참고가 뜬다.
      expect(find.byKey(const Key('bendcheck_reference')), findsOneWidget);
      expect(find.textContaining('지난 실측 1건'), findsOneWidget);
      expect(find.text('기록이 적어 참고만 하십시오.'), findsOneWidget);
    });

    testWidgets('세 건이 쌓이면 "기록이 적다" 안내가 사라진다', (tester) async {
      await open(tester);
      await tester.enterText(find.byKey(const Key('bendcheck_group')), 'A');
      for (final v in ['101', '102', '103']) {
        await record(tester, '100', v);
      }
      expect(find.textContaining('지난 실측 3건'), findsOneWidget);
      expect(find.text('기록이 적어 참고만 하십시오.'), findsNothing);
    });

    testWidgets('규격·장비나 숫자가 비면 저장하지 않고 안내한다', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('bendcheck_save')));
      await tester.pump();
      expect(find.text('튜브 규격·장비를 적어 주십시오'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('bendcheck_group')), 'A');
      await tester.enterText(find.byKey(const Key('bendcheck_calc')), '100');
      await tester.enterText(find.byKey(const Key('bendcheck_actual')), 'abc');
      await tester.pump();
      await tester.tap(find.byKey(const Key('bendcheck_save')));
      await tester.pump();
      expect(find.text('계산값과 실측값을 숫자로 적어 주십시오'), findsOneWidget);
      expect(await loadBendChecks(), isEmpty);
    });

    testWidgets('묶음 이름을 눌러 채우고, 보내기와 밀어서 지우기', (tester) async {
      await addBendCheck(_c('1', 100, 102, g: '1/2" SUS'));
      await open(tester);
      // 처음에는 가장 최근 묶음이 채워져 있다.
      expect(find.widgetWithText(TextField, '1/2" SUS'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bendcheck_share')));
      await tester.pump();
      expect(sent, contains('■ 1/2" SUS'));

      await tester.drag(
        find.byKey(const Key('bendcheck_record_1')),
        const Offset(-800, 0),
      );
      await tester.pumpAndSettle();
      expect(await loadBendChecks(), isEmpty);
      expect(find.text('아직 기록이 없습니다'), findsOneWidget);
    });
  });
}
