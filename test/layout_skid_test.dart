// 스키드 평면도: 형강 폭 셈, 후강 바깥지름, 새 도면 종류, 바닥에서 높이 저장.
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

void main() {
  test('형강 위에서 본 폭: H형강·찬넬·앵글은 둘째 숫자, 각파이프·스트럿은 첫째', () {
    expect(steelPlanWidth('BEAM', 'H형강 200x100x5.5x8'), 100);
    expect(steelPlanWidth('CHANNEL', '찬넬 100x50x5x7.5'), 50);
    expect(steelPlanWidth('ANGLE', '앵글 50x50x6'), 50);
    expect(steelPlanWidth('SQUARE', '각파이프 50x30x2.3'), 50);
    expect(steelPlanWidth('STRUT', '스트럿 41x21x2.0'), 41);
  });

  test('후강 전선관은 KS 바깥지름, 형강·JB 목록이 비어 있지 않고 모두 그려진다', () {
    final conduits = kSkidConduitPresets.values.single;
    expect(conduits.map((p) => p.name), contains('후강 전선관 22'));
    expect(conduits.firstWhere((p) => p.name == '후강 전선관 22').height, 26.5);
    for (final list in [
      ...kSkidSteelPresets.values,
      ...kSkidConduitPresets.values,
      ...kSkidJbPresets.values,
    ]) {
      expect(list, isNotEmpty);
      for (final p in list) {
        for (final size in [Size(p.width, p.height), Size(p.height, p.width)]) {
          final rec = ui.PictureRecorder();
          InstrumentShapePainter(shape: p.shape!).paint(Canvas(rec), size);
          rec.endRecording();
        }
      }
    }
  });

  test('바닥에서 높이는 저장했다 읽어도 남는다', () {
    final a = PlacedItem(
      id: 'jb',
      name: '정션박스 300×300',
      position: Offset.zero,
      elevation: 1200,
    );
    expect(PlacedItem.fromJson(a.toJson()).elevation, 1200);
  });

  testWidgets('스키드로 새로 열면 스키드 크기·단추가 나오고 종류가 저장된다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
    });
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: LayoutBoardPage(initialKind: kLayoutKindSkid)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('skid_steel')), findsOneWidget);
    // 화면 맞춤 뒤 확대 기능이 읽는 배율이 실제(가로) 배율과 같아야 끝까지 확대된다.
    final ctrl = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    Matrix4 m = ctrl.value;
    expect(m.getMaxScaleOnAxis(), closeTo(m[0], 1e-9));
    expect(m[0], lessThan(0.5));

    // 두 손가락으로 여러 번 벌리면 1:1(1배)을 넘어 치수를 볼 만큼 커진다.
    // 예전에는 맞춘 크기의 4배(0.6배 안팎)에서 멈췄다.
    final Offset c = tester.getCenter(find.byType(InteractiveViewer));
    for (int n = 0; n < 6; n++) {
      final g1 = await tester.startGesture(c - const Offset(20, 0));
      final g2 = await tester.startGesture(c + const Offset(20, 0));
      for (int i = 0; i < 10; i++) {
        await g1.moveBy(const Offset(-8, 0));
        await g2.moveBy(const Offset(8, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g1.up();
      await g2.up();
      await tester.pumpAndSettle();
    }
    m = ctrl.value;
    expect(m[0], greaterThan(2));
    expect(find.byKey(const ValueKey('duct_button')), findsNothing);

    expect(find.byKey(const ValueKey('skid_conduit')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('skid_jb')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('정션박스 300×300'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.text('정션박스 300×300'),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('layout_board_draft_v1')!) as Map;
    expect(saved['kind'], kLayoutKindSkid);
    expect(saved['panelWidth'], kSkidDefaultLength);
    expect(saved['panelHeight'], kSkidDefaultWidth);
  });

  testWidgets('스키드는 평면·정면·좌측면·우측면 탭, 정면은 길이×1500으로 새로 생기고 저장된다', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
    });
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: LayoutBoardPage(initialKind: kLayoutKindSkid)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    for (final id in kSkidViewOrder) {
      expect(find.byKey(ValueKey('plate_tab_$id')), findsOneWidget);
    }
    expect(find.text('정면'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plate_tab_front')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('skid_jb')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('정션박스 300×300'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('layout_board_draft_v1')!) as Map;
    final front = (saved['sidePlates'] as Map)['front'] as Map;
    expect(front['panelWidth'], kSkidDefaultLength);
    expect(front['panelHeight'], kSkidDefaultHeight);
    expect((front['items'] as List).single['name'], '정션박스 300×300');
    expect(saved['items'], isEmpty); // 평면에는 안 들어갔다
  });
}
