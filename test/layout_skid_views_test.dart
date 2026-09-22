// 스키드: 전선관 부속(삼화기전 F-7 곤질레다·커플링·유니온), 면마다 그리기,
// 평면 부품 하나를 정면·측면에서도 보고 옮기기.
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

void main() {
  test('전선관 부속: 곤질레다 LB·LL·LR·LT·LC·LX와 커플링·유니온, 규격 16~54', () {
    expect(kSkidFittingPresets.keys, [
      '곤질레다 LB',
      '곤질레다 LL',
      '곤질레다 LR',
      '곤질레다 LT',
      '곤질레다 LC',
      '곤질레다 LX',
      '커플링',
      '유니온 커플링',
    ]);
    for (final list in kSkidFittingPresets.values) {
      expect(list.map((p) => p.name.split(' ').last), [
        '16',
        '22',
        '28',
        '36',
        '42',
        '54',
      ]);
      for (final p in list) {
        expect(SkidShape.isFitting(p.shape), isTrue);
        expect(p.depth, isNotNull);
        expect(p.width, greaterThan(p.height)); // 긴 쪽이 가로
      }
    }
    ModulePreset pick(String group, int size) => kSkidFittingPresets[group]!
        .firstWhere((p) => p.name.endsWith(' $size'));
    // 옆 허브가 있으면 위에서 본 폭이, 뒤 허브(LB)가 있으면 높이가 커진다.
    expect(pick('곤질레다 LL', 22).height, greaterThan(pick('곤질레다 LC', 22).height));
    expect(pick('곤질레다 LX', 22).height, greaterThan(pick('곤질레다 LL', 22).height));
    expect(pick('곤질레다 LB', 22).depth, greaterThan(pick('곤질레다 LC', 22).depth!));
    // 스키드 세로 크기는 깊이 칸(바닥에서 본 높이)을 쓴다.
    final lb = pick('곤질레다 LB', 28);
    expect(
      skidVerticalSize(
        PlacedItem(
          id: 'a',
          name: lb.name,
          position: Offset.zero,
          width: lb.width,
          height: lb.height,
          shape: lb.shape,
          depth: lb.depth,
        ),
      ),
      lb.depth,
    );
  });

  test('모든 스키드 부품을 위·옆·끝 모습으로 그린다(돌림·뒤집기 포함)', () {
    final shapes = {
      for (final g in [
        ...kSkidSteelPresets.values,
        ...kSkidJbPresets.values,
        ...kSkidConduitPresets.values,
        ...kSkidFittingPresets.values,
      ])
        for (final p in g) p.shape!,
    };
    for (final shape in shapes) {
      for (final face in SkidFace.values) {
        for (final size in const [Size(120, 40), Size(40, 120), Size(60, 60)]) {
          for (final mirror in [false, true]) {
            final rec = ui.PictureRecorder();
            SkidPartPainter(
              shape: shape,
              face: face,
              mirror: mirror,
            ).paint(Canvas(rec), size);
            rec.endRecording();
          }
        }
      }
      // 목록 칸 작은 그림(평면)도 그린다.
      final rec = ui.PictureRecorder();
      InstrumentShapePainter(
        shape: shape,
      ).paint(Canvas(rec), const Size(80, 30));
      rec.endRecording();
    }
  });

  test('면마다 자리·방향: 정면은 길이 방향 x, 측면은 y; 높이가 없으면 바닥에 놓인다', () {
    final beamX = PlacedItem(
      id: 'b',
      name: 'H형강 100x100x6x8',
      position: const Offset(200, 300),
      width: 1000,
      height: 100,
      shape: SkidShape.beam,
    );
    expect(skidViewFace(beamX, kSkidViewFront), SkidFace.side);
    expect(skidViewFace(beamX, 'left'), SkidFace.end);
    final r = skidViewRect(beamX, kSkidViewFront, planH: 1200, viewH: 1500);
    expect(r, const Rect.fromLTWH(200, 1400, 1000, 100)); // 바닥(1500)에 닿음
    final side = skidViewRect(beamX, 'left', planH: 1200, viewH: 1500);
    expect(side.left, 300);
    expect(side.width, 100);
    final right = skidViewRect(beamX, 'right', planH: 1200, viewH: 1500);
    expect(right.left, 1200 - 300 - 100);
    beamX.elevation = 800;
    expect(
      skidViewRect(beamX, kSkidViewFront, planH: 1200, viewH: 1500).center.dy,
      1500 - 800,
    );
    final jb = PlacedItem(
      id: 'j',
      name: '정션박스 300×300',
      position: Offset.zero,
      width: 300,
      height: 300,
      shape: SkidShape.jb,
    );
    expect(skidViewFace(jb, 'left'), SkidFace.side);
  });

  Future<void> openSkid(
    WidgetTester tester, {
    Map<String, Object>? prefs,
  }) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      ...?prefs,
    });
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: LayoutBoardPage(
          initialKind: kLayoutKindSkid,
          resumeDraft: prefs == null ? null : true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  testWidgets('스키드 단추: 형강·경로·JB·부속만, 계기·밸브·피팅은 없다', (tester) async {
    await openSkid(tester);
    for (final k in ['skid_steel', 'skid_route', 'skid_jb', 'skid_fitting']) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
    }
    for (final k in ['instrument_button', 'valve_button', 'fitting_button']) {
      expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
    }
    await tester.tap(find.byKey(const ValueKey('skid_fitting')));
    await tester.pumpAndSettle();
    expect(find.text('전선관 부속 놓기'), findsOneWidget);
    await tester.tap(find.text('곤질레다 LB 22'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.text('곤질레다 LB 22'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('평면 부품은 정면에도 보이고, 정면에서 끌면 평면 위치·높이가 바뀌고 되돌리기로 돌아온다', (
    tester,
  ) async {
    await openSkid(
      tester,
      prefs: {
        'layout_board_draft_v1': jsonEncode({
          'kind': kLayoutKindSkid,
          'panelWidth': 2400,
          'panelHeight': 1200,
          'items': [
            PlacedItem(
              id: 'jb1',
              name: '정션박스 400×300',
              position: const Offset(1000, 450),
              width: 400,
              height: 300,
              shape: SkidShape.jb,
              elevation: 600,
            ).toJson(),
          ],
        }),
      },
    );
    await tester.tap(find.byKey(const ValueKey('plate_tab_front')));
    await tester.pumpAndSettle();
    final proxy = find.byKey(const ValueKey('view_jb1'));
    expect(proxy, findsOneWidget);

    // 오른쪽·위로 끈다(판 1mm = 화면 k px).
    final Offset c = tester.getCenter(proxy);
    final g = await tester.startGesture(c);
    for (int i = 0; i < 10; i++) {
      await g.moveBy(const Offset(6, -4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();

    Map<String, dynamic> planItem() {
      final state = tester.state(find.byType(LayoutBoardPage)) as dynamic;
      final plates = state.debugPlates() as Map<String, Map<String, dynamic>>;
      return Map<String, dynamic>.from(
        (plates[kPlateMain]!['items'] as List).single as Map,
      );
    }

    final moved = planItem();
    expect((moved['x'] as num).toDouble(), greaterThan(1000));
    expect((moved['elev'] as num).toDouble(), greaterThan(600));
    expect((moved['y'] as num).toDouble(), 450); // 앞뒤 자리는 그대로

    // 되돌리기 단추
    await tester.tap(find.byIcon(Icons.undo_rounded).first);
    await tester.pumpAndSettle();
    final back = planItem();
    expect((back['x'] as num).toDouble(), 1000);
    expect((back['elev'] as num).toDouble(), 600);
  });
}
