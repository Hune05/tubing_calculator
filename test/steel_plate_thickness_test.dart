// 철판 가공 두께 칸(10-12, 사용자 "두께 입력 창이 메인, 퀵 버튼은 드롭다운" → "확인하고 개선할 거 찾아봐" → "전부 진행 해"):
// 큰 두께 칸 + 칸 안 ▼ 목록, 옆 칸 수량, 목록에 없는 두께는 ▼에서 "목록에 넣기", 절곡이면 공제값 기준 한 줄,
// 두께가 비면 안내·칸 테두리, ▼ 목록은 칸 아래에 펼쳐짐(폰 폭).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_calc.dart'
    show PlateMaterial;
import 'package:tubing_calculator/src/presentation/steel_plate/plate_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_settings.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_ui.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    bool bend = false,
    Map<String, Object> prefs = const {},
    Size size = const Size(800, 2400),
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PlatePage(bend: bend, share: (_) async {}),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String k) =>
      tester.widget<TextField>(find.byKey(Key(k))).controller!.text;

  testWidgets('두께 옆 칸은 수량(빈 반쪽을 씀), 품명은 아래 한 줄', (tester) async {
    await open(tester);
    final t = tester.getTopLeft(find.byKey(const Key('pl_t')));
    final q = tester.getTopLeft(find.byKey(const Key('pl_qty')));
    expect(q.dy, closeTo(t.dy, 0.5));
    expect(q.dx, greaterThan(t.dx));
    expect(
      tester.getTopLeft(find.byKey(const Key('pl_job'))).dy,
      greaterThan(t.dy + 20),
    );
  });

  testWidgets('목록에 없는 3T는 ▼ 맨 위 "목록에 넣기" → 설정 목록에 들어가고 체크', (tester) async {
    await open(tester);
    expect(text(tester, 'pl_t'), '3');
    await tap(tester, 'pl_t_menu');
    expect(find.text('3T 목록에 넣기'), findsOneWidget);
    await tap(tester, 'pl_t_add');
    expect(find.textContaining('3T를 철판 두께 목록에 넣었습니다'), findsOneWidget);
    final s = await PlateSettings.load();
    expect(s.thick[PlateMaterial.steel], contains('3'));
    await tap(tester, 'pl_t_menu');
    expect(find.byKey(const Key('pl_t_add')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('pl_t_3')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    await tap(tester, 'pl_t_3');
  });

  testWidgets('절단 + 절곡: 두께 칸 아래 공제값 기준(업체 값 있음·없음)', (tester) async {
    await open(
      tester,
      bend: true,
      prefs: {
        PlatePage.bendTableKey: jsonEncode({
          '4.5': {'r': 4.5, 'bd': 7},
        }),
      },
    );
    String line() =>
        tester.widget<Text>(find.byKey(const Key('pl_t_bend'))).data ?? '';
    expect(line(), contains('3T 업체 값 없음, 일반값'));
    await tap(tester, 'pl_t_menu');
    // 업체 값을 저장해 둔 두께에 "업체 값"
    expect(
      find.descendant(
        of: find.byKey(const Key('pl_t_4.5')),
        matching: find.text('업체 값'),
      ),
      findsOneWidget,
    );
    await tap(tester, 'pl_t_4.5');
    expect(line(), contains('4.5T 업체 값(내R 4.5 · 90° 공제 7)'));
  });

  testWidgets('두께가 비면 "두께를 넣으십시오", 칸 테두리 진하게, 그림 칸도 두께를 짚음', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('pl_t')), '');
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('pl_shape_status'))).data,
      '두께를 넣으십시오.',
    );
    expect(
      tester
          .widget<PlateNumField>(
            find.ancestor(
              of: find.byKey(const Key('pl_t')),
              matching: find.byType(PlateNumField),
            ),
          )
          .highlight,
      isTrue,
    );
    expect(find.textContaining('두께를 넣으면 그림이 나옵니다'), findsOneWidget);
  });

  testWidgets('폰 폭: ▼ 목록은 두께 칸 아래에 펼쳐진다(칸을 덮지 않음)', (tester) async {
    await open(tester, bend: true, size: const Size(360, 780));
    await tester.tap(find.byKey(const Key('pl_tab_shape')));
    await tester.pumpAndSettle();
    final sc = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .last;
    await tester.scrollUntilVisible(
      find.byKey(const Key('pl_t_menu')),
      100,
      scrollable: sc,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pl_t_menu')));
    await tester.pumpAndSettle();
    final fieldBottom = tester.getBottomLeft(find.byKey(const Key('pl_t'))).dy;
    final firstItem = tester.getTopLeft(find.byKey(const Key('pl_t_1.6'))).dy;
    expect(firstItem, greaterThanOrEqualTo(fieldBottom));
    await tester.tap(find.byKey(const Key('pl_t_1.6')));
    await tester.pumpAndSettle();
    expect(text(tester, 'pl_t'), '1.6');
  });
}
