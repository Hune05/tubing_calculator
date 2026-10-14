// 10-14 킥 역산: 각도 대신 높이+수평 거리(atan) 또는 높이+빗변(asin)으로 각도를 거꾸로 셈한다.
// 전선관 킥 시트와 튜브 퀵 킥 시트 둘 다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_quick_kick_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/conduit/widgets/conduit_special_sheets.dart';

final specs = BendSheetSpecs.conduit({
  'benderType': 'hand',
  'clr': 114.3,
  'takeUp': 152.4,
  'gain': 20.0,
  'applyShrink': true,
});

Future<List<List<Map<String, dynamic>>>> openKick(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(400, 900) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final added = <List<Map<String, dynamic>>>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open'),
              onPressed: () => ConduitSpecialSheets.showKick(
                context,
                currentRotation: 90,
                onAddBends: added.add,
                specs: specs,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return added;
}

/// 숫자 칸은 숫자판으로 넣는 칸(읽기 전용)이라 시험에서는 칸의 값을 바로 바꾼다.
Future<void> type(WidgetTester tester, String key, String text) async {
  tester.widget<TextField>(find.byKey(Key(key))).controller!.text = text;
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

String allText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text, skipOffstage: false))
    .map((t) => t.data ?? '')
    .join('\n');

void main() {
  group('전선관 킥', () {
    testWidgets('각도 넣기가 기본이고, 역산을 고르면 각도 칸 대신 거리 칸이 나온다', (tester) async {
      await openKick(tester);
      expect(find.byKey(const Key('cs_angle')), findsOneWidget);
      expect(find.byKey(const Key('cs_run')), findsNothing);
      await tapKey(tester, 'cs_kick_in_run');
      expect(find.byKey(const Key('cs_angle')), findsNothing);
      expect(find.byKey(const Key('cs_run')), findsOneWidget);
      await tapKey(tester, 'cs_kick_in_travel');
      expect(find.byKey(const Key('cs_run')), findsNothing);
      expect(find.byKey(const Key('cs_travel')), findsOneWidget);
    });

    testWidgets('높이 100 + 수평 거리 173.2 → 30.0°, 넣으면 30° 한 줄', (tester) async {
      final added = await openKick(tester);
      await tapKey(tester, 'cs_kick_in_run');
      await type(tester, 'cs_height', '100');
      await type(tester, 'cs_run', '173.2');
      await type(tester, 'cs_start', '500');
      final t = allText(tester);
      expect(t, contains('계산된 각도 (∠)'));
      expect(t, contains('30°'));
      expect(t, contains('200 mm')); // 빗변
      await tapKey(tester, 'cs_dir_0');
      await tapKey(tester, 'cs_add');
      expect(added.length, 1);
      final b = added.single.single;
      expect(b['angle'], closeTo(30.0, 0.05));
      expect(b['length'], closeTo(500 + specs.markOffset(30), 0.1));
    });

    testWidgets('높이 100 + 빗변 200 → 30.0°; 빗변이 높이보다 짧으면 못 넣고 알림', (
      tester,
    ) async {
      final added = await openKick(tester);
      await tapKey(tester, 'cs_kick_in_travel');
      await type(tester, 'cs_height', '100');
      await type(tester, 'cs_travel', '200');
      await type(tester, 'cs_start', '500');
      expect(allText(tester), contains('30°'));
      expect(allText(tester), contains('173.2 mm')); // 수평 거리
      await type(tester, 'cs_travel', '100');
      await tapKey(tester, 'cs_dir_0');
      await tapKey(tester, 'cs_add');
      expect(find.textContaining('빗변은 높이보다 길어야 합니다'), findsOneWidget);
      expect(added, isEmpty);
    });
  });

  group('튜브 퀵 킥', () {
    Future<void> openTube(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(400, 900) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open'),
                  onPressed: () => MobileQuickKickBottomSheet.show(context),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
    }

    testWidgets('높이 + 수평 거리 / 높이 + 빗변으로 각도가 거꾸로 나온다', (tester) async {
      await openTube(tester);
      // 높이 칸은 첫 TextField.
      final height = tester
          .widgetList<TextField>(find.byType(TextField))
          .first
          .controller!;
      height.text = '100';
      await tester.pumpAndSettle();
      await tapKey(tester, 'qk_in_run');
      await type(tester, 'qk_run', '173.2');
      expect(allText(tester), contains('계산된 각도 (∠)'));
      expect(allText(tester), contains('30.0°'));
      expect(allText(tester), contains('빗변 (Travel): 200.0 mm'));
      await tapKey(tester, 'qk_in_travel');
      await type(tester, 'qk_travel', '200');
      expect(allText(tester), contains('30.0°'));
      await type(tester, 'qk_travel', '80');
      expect(allText(tester), contains('빗변은 높이보다 길어야 합니다'));
      await tapKey(tester, 'qk_in_angle');
      expect(allText(tester), contains('도달 빗변 (C-C Travel)'));
    });
  });
}
