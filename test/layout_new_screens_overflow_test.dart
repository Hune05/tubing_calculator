// 이번 주에 새로 만든 배치도 화면이 좁은 폰(320·344)·보통 폰·글자 크게(1.3배)에서 넘치지 않는지 본다.
// 축척 맞추기, 카톡으로 받은 도면 창, 스키드 전선관 부속 창, 스키드 정면(부품·가려진 부품 점선).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/drawing_scale_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/shared_drawing_sheet.dart';

const List<(Size, double)> kCases = [
  (Size(320, 568), 1.0),
  (Size(344, 760), 1.3),
  (Size(390, 844), 1.0),
];

Widget app(Widget home, double scale, {GlobalKey<NavigatorState>? nav}) =>
    MaterialApp(
      navigatorKey: nav,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    );

void main() {
  for (final (size, scale) in kCases) {
    final String tag = '${size.width.toInt()}x${size.height.toInt()} ×$scale';

    testWidgets('$tag: 축척 맞추기 화면이 넘치지 않는다', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          const DrawingScalePage(
            imagePath: 'no_such.png',
            initialWidthMm: 2400,
            initialHeightMm: 1200,
            targetName: '스키드',
            imageSize: Size(1600, 1000),
          ),
          scale,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final Rect box = tester.getRect(
        find.byKey(const ValueKey('scale_image')),
      );
      await tester.tapAt(box.topLeft + const Offset(5, 5));
      await tester.tapAt(box.bottomRight - const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('scale_apply')), findsOneWidget);
    });

    testWidgets('$tag: 받은 도면 창이 넘치지 않는다(이어서 하던 배치도 줄 포함)', (tester) async {
      SharedPreferences.setMockInitialValues({
        'layout_board_onboarding_shown_v1': true,
        'layout_board_draft_v1': jsonEncode({'panelWidth': 600, 'items': []}),
      });
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openSharedDrawing(context, 'no_such.png'),
                child: const Text('받기'),
              ),
            ),
          ),
          scale,
        ),
      );
      await tester.tap(find.text('받기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('shared_to_draft')), findsOneWidget);
    });

    testWidgets('$tag: 스키드 부속 창·정면(가려진 부품 점선)이 넘치지 않는다', (tester) async {
      Map<String, dynamic> jb(String id, double y) => PlacedItem(
        id: id,
        name: '정션박스 300×300',
        position: Offset(1000, y),
        width: 300,
        height: 300,
        shape: SkidShape.jb,
        elevation: 800,
      ).toJson();
      SharedPreferences.setMockInitialValues({
        'layout_board_onboarding_shown_v1': true,
        'layout_board_draft_v1': jsonEncode({
          'kind': kLayoutKindSkid,
          'panelWidth': 2400,
          'panelHeight': 1200,
          'items': [jb('front', 800), jb('back', 100)],
        }),
      });
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        app(
          const LayoutBoardPage(
            initialKind: kLayoutKindSkid,
            resumeDraft: true,
          ),
          scale,
          nav: nav,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byKey(const ValueKey('skid_fitting')));
      await tester.tap(find.byKey(const ValueKey('skid_fitting')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('전선관 부속 놓기'), findsOneWidget);
      nav.currentState!.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('plate_tab_front')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('hidden_back')), findsOneWidget);

      // 관리 창(가려진 부품 보이기 줄이 있는 곳)
      await tester.tap(find.byTooltip('더보기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('toggle_hidden_parts')), findsOneWidget);
      nav.currentState!.pop();
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
