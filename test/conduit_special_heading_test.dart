// 전선관 특수 벤딩 시트가 "지금 진행 방향"을 실제 경로로 아는지.
// 예전에는 마지막 줄의 방향값(줄이 없으면 90=오른쪽)을 진행 방향으로 가정했다. 그런데 오프셋·새들·킥
// 뒤에는 관이 원래 방향으로 돌아와 있어 그 가정이 틀렸고, 3D에서 고른 시작 방향도 무시했다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/engine/bend_path.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_field_data.dart'
    show conduitStartDir;
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_input_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart'
    show globalBenderSettings;
import 'package:vector_math/vector_math_64.dart' as vm;

void phone(WidgetTester tester, {double height = 1800}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(420, height);
  addTearDown(tester.view.reset);
}

double sheetOpacity(WidgetTester tester, String rot) =>
    tester.widget<Opacity>(find.byKey(ValueKey('sheet_dir_$rot'))).opacity;

void main() {
  group('rotationForDirection', () {
    test('여섯 축은 방향값으로, 비스듬하면 null', () {
      for (final r in [0.0, 90.0, 180.0, 270.0, 360.0, 450.0]) {
        expect(rotationForDirection(directionForRotation(r)), r);
      }
      expect(rotationForDirection(vm.Vector3(1, 1, 0).normalized()), isNull);
      expect(rotationForDirection(vm.Vector3(2, 0, 0)), 90.0); // 길이는 상관없다
    });
  });

  group('전선관 입력 탭의 특수 도구', () {
    late ConduitDataManager manager;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      conduitStartDir.value = 'RIGHT';
      manager = ConduitDataManager.detached();
    });
    tearDown(() => conduitStartDir.value = 'RIGHT');

    Future<void> openTool(
      WidgetTester tester,
      String tool, {
      String dirKey = 'sheet_dir_0.0',
    }) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ConduitInputTab(manager: manager)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('특수 벤딩 툴 (오프셋/새들 등)'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(tool));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tool));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(ValueKey(dirKey)));
      await tester.pumpAndSettle();
    }

    testWidgets('오프셋 시트(규칙 전달): 줄이 없으면 3D 시작 방향(UP)을 따른다', (tester) async {
      conduitStartDir.value = 'UP';
      await openTool(tester, '오프셋');
      expect(sheetOpacity(tester, '0.0'), 0.38); // UP
      expect(sheetOpacity(tester, '180.0'), 0.38); // DOWN
      expect(sheetOpacity(tester, '90.0'), 1.0); // RIGHT
    });

    testWidgets('시작 방향 RIGHT에서 오프셋(위로 30°, 아래로 30°)을 넣은 뒤에도 진행 방향은 오른쪽', (
      tester,
    ) async {
      manager.addMultipleBends([
        {'length': 300.0, 'angle': 30.0, 'rotation': 0.0},
        {'length': 300.0, 'angle': 30.0, 'rotation': 180.0},
      ]);
      await openTool(tester, '오프셋');
      // 마지막 줄 방향값(아래)을 진행 방향으로 잘못 알면 위·아래가 흐리게 된다. 실제는 오른쪽 진행.
      expect(sheetOpacity(tester, '90.0'), 0.38); // RIGHT
      expect(sheetOpacity(tester, '270.0'), 0.38); // LEFT
      expect(sheetOpacity(tester, '0.0'), 1.0); // UP
      expect(sheetOpacity(tester, '180.0'), 1.0); // DOWN
    });

    testWidgets('킥 시트: 오프셋 뒤에 실제 진행 방향(오른쪽)에 수직인 위로 꺾는 입력이 거절되지 않는다', (
      tester,
    ) async {
      manager.addMultipleBends([
        {'length': 300.0, 'angle': 30.0, 'rotation': 0.0},
        {'length': 300.0, 'angle': 30.0, 'rotation': 180.0},
      ]);
      await openTool(tester, '킥', dirKey: 'cs_dir_0');
      // 방향 칸은 시트 자신의 칸(cs_dir_*)이다. 위(0)를 고르고 높이를 넣어 추가한다.
      await tester.tap(find.byKey(const Key('cs_dir_0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cs_height')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '1'));
      await tester.tap(find.widgetWithText(TextButton, '0'));
      await tester.tap(find.widgetWithText(TextButton, '0'));
      await tester.tap(find.text('적용'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cs_add')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cs_missing')), findsNothing); // 거절 알림 없음
      expect(manager.bendList.length, 3); // 오프셋 2줄 + 킥 1줄
      expect(manager.bendList.last['rotation'], 0.0);
    });

    testWidgets('백투백 시트: 후강(Rigid) 22mm이면 바깥지름 26.5를 미리 채운다', (tester) async {
      final saved = Map<String, dynamic>.from(globalBenderSettings.value);
      addTearDown(() => globalBenderSettings.value = saved);
      globalBenderSettings.value = {
        ...saved,
        'conduitType': 'Rigid',
        'conduitSize': '22mm',
      };
      await openTool(tester, '백투백 90°', dirKey: 'cs_dir_0');
      expect(
        tester.widget<TextField>(find.byKey(const Key('cs_od'))).controller!.text,
        '26.5',
      );
    });

    testWidgets('백투백 시트: 후강이 아닌 종류(EMT)이면 바깥지름을 비워 둔다', (tester) async {
      final saved = Map<String, dynamic>.from(globalBenderSettings.value);
      addTearDown(() => globalBenderSettings.value = saved);
      globalBenderSettings.value = {
        ...saved,
        'conduitType': 'EMT',
        'conduitSize': '22mm',
      };
      await openTool(tester, '백투백 90°', dirKey: 'cs_dir_0');
      expect(
        tester.widget<TextField>(find.byKey(const Key('cs_od'))).controller!.text,
        '',
      );
    });

    testWidgets('킥 시트: 진행 방향(오른쪽)과 나란한 칸은 흐리게, 누르면 안내 창만 뜨고 선택은 안 된다', (tester) async {
      await openTool(tester, '킥', dirKey: 'cs_dir_0');
      double op(String r) => tester.widget<Opacity>(find.byKey(Key('cs_dir_op_$r'))).opacity;
      expect(op('90'), 0.38);
      expect(op('270'), 0.38);
      expect(op('0'), 1.0);
      await tester.tap(find.byKey(const Key('cs_dir_90')));
      await tester.pumpAndSettle();
      expect(find.text('그 방향으로는 못 꺾습니다'), findsOneWidget);
    });

  });
}
