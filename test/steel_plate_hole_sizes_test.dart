// 도면 홀 크기 글(10-11, 사용자: "홀 크기 도면에 넣고 장공은 길이까지 넣는데 적용 미적용 버튼으로"):
// 같은 크기끼리 "4-φ13.5", 장공은 "장공 11×30"(폭 × 전체 길이), 그림 위 "홀 크기" 단추와 설정 "적용 | 미적용".
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_painter.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_settings.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_ui.dart';

const _holes = [
  PlateHoleSpec(u: 15, v: 15, dia: 13.5),
  PlateHoleSpec(u: 185, v: 15, dia: 13.5),
  PlateHoleSpec(u: 185, v: 85, dia: 13.5),
  PlateHoleSpec(u: 15, v: 85, dia: 13.5),
  PlateHoleSpec(u: 100, v: 50, dia: 11, slot: 30),
  PlateHoleSpec(u: 60, v: 50, dia: 9),
];

PlatePlan _flat([List<PlateHoleSpec> holes = _holes]) => platePlan(
  PlateInput(
    shape: PlateShape.flat,
    t: 3,
    length: 200,
    width: 100,
    holes: holes,
  ),
);

void main() {
  test('같은 크기끼리 묶어 "4-φ13.5", 장공은 폭 × 전체 길이', () {
    expect(
      [for (final (s, _) in plateHoleSizeGroups(_flat())) s],
      ['4-φ13.5', '장공 11×30', 'φ9'],
    );
    expect(plateHoleSizeGroups(_flat()).first.$2.length, 4);
  });

  testWidgets('홀 크기 글을 단 그림도 그려진다(PNG, 홀 많은 판)', (tester) async {
    final painter = PlatePainter(
      plan: _flat([
        for (var i = 0; i < 6; i++)
          for (var j = 0; j < 3; j++)
            PlateHoleSpec(
              u: 20.0 + 30 * i,
              v: 20.0 + 30 * j,
              dia: i.isEven ? 9 : 11,
            ),
      ]),
      text: Colors.black,
      sub: Colors.grey,
      bg: Colors.white,
      holeSizes: true,
      holeDims: true,
    );
    late ByteData? png;
    await tester.runAsync(() async {
      final rec = PictureRecorder();
      painter.paint(Canvas(rec), const Size(800, 500));
      final img = await rec.endRecording().toImage(800, 500);
      png = await img.toByteData(format: ImageByteFormat.png);
    });
    expect(png!.lengthInBytes, greaterThan(1000));
  });

  group('화면', () {
    Future<void> open(WidgetTester tester, Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PlatePage(
            bend: false,
            share: (_) async {},
            initial: {
              'sh': 'flat',
              't': '3',
              'len': '200',
              'wid': '100',
              'holes': [for (final h in _holes) h.toJson()],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }

    PlatePainter painter(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find
                      .descendant(
                        of: find.byKey(const Key('pl_view')),
                        matching: find.byType(CustomPaint),
                      )
                      .first,
                )
                .painter!
            as PlatePainter;

    testWidgets('그림 위 "홀 크기" 단추로 켜고 끄고, 다음에 열어도 그대로', (tester) async {
      await open(tester, {});
      expect(painter(tester).holeSizes, isTrue); // 처음은 적용
      await tester.tap(find.byKey(const Key('pl_hole_sizes')));
      await tester.pumpAndSettle();
      expect(painter(tester).holeSizes, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kPlateHoleSizeKey), isFalse);
    });

    testWidgets('설정에서 미적용으로 두면 그림에 글이 없다', (tester) async {
      await open(tester, {kPlateHoleSizeKey: false});
      expect(painter(tester).holeSizes, isFalse);
      expect(
        tester
            .widget<PlateCanvasButton>(find.byKey(const Key('pl_hole_sizes')))
            .selected,
        isFalse,
      );
    });

    testWidgets('설정 화면 "홀 크기 글" 적용 | 미적용', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: PlateSettingsPage()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('ps_hsize_off')));
      await tester.tap(find.byKey(const Key('ps_hsize_off')));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kPlateHoleSizeKey), isFalse);
    });
  });
}
