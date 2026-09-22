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
    expect(find.byKey(const ValueKey('duct_button')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('skid_conduit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('후강 전선관 28'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.text('후강 전선관 28'),
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
}
