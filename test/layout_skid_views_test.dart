// 스키드: 전선관 부속(삼화기전 F-7 곤질레다·커플링·유니온), 면마다 그리기,
// 평면 부품 하나를 정면·측면에서도 보고 옮기기.
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/skid_route_editor_page.dart';

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
        // 곤질레다는 긴 쪽이 가로. 커플링·유니온은 지름이 더 클 수 있어 돌린 횟수로 본다.
        if (SkidShape.isCondulet(p.shape)) {
          expect(p.width, greaterThan(p.height));
        } else {
          expect(skidTurnsOnly(p.shape), isTrue);
        }
      }
    }
    ModulePreset pick(String group, int size) => kSkidFittingPresets[group]!
        .firstWhere((p) => p.name.endsWith(' $size'));
    // 표 값(JK 곤질레다·KS 커플링·대승 DA-UF 유니온): ㄱ자형과 곧은형은 길이가 다르다.
    expect([pick('곤질레다 LB', 16).width, pick('곤질레다 LB', 16).depth], [125, 66]);
    expect(pick('곤질레다 LL', 16).height, 60);
    expect(pick('곤질레다 LC', 36).width, 197);
    expect(pick('곤질레다 LT', 36).width, 197);
    expect([pick('커플링', 54).width, pick('커플링', 54).height], [64, 68]);
    expect([pick('유니온 커플링', 28).width, pick('유니온 커플링', 28).height], [47, 53]);
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
    await tester.tap(find.byIcon(AppIcons.undo).first);
    await tester.pumpAndSettle();
    final back = planItem();
    expect((back['x'] as num).toDouble(), 1000);
    expect((back['elev'] as num).toDouble(), 600);
  });
  test('면별 차례·가려짐: 가까운 것이 나중(위), 뒤에 가려진 것은 가려진 정도가 크다, 좌·우측면은 앞뒤가 반대', () {
    PlacedItem jb(String id, double x, double y) => PlacedItem(
      id: id,
      name: '정션박스 300×300',
      position: Offset(x, y),
      width: 300,
      height: 300,
      shape: SkidShape.jb,
      elevation: 800,
    );
    // 같은 x·높이, y만 다름: 정면(y 큰 쪽에서 봄)에서 back은 front 뒤에 완전히 가린다.
    final back = jb('back', 1000, 100);
    final front = jb('front', 1000, 800);
    final f = skidViewLayout(
      [front, back],
      kSkidViewFront,
      planH: 1200,
      viewH: 1500,
    );
    expect(f.map((p) => p.it.id), ['back', 'front']);
    expect(f.first.covered, closeTo(1, 1e-9));
    expect(f.last.covered, 0);
    // 좌측면(x=0 쪽)·우측면: x만 다른 둘
    final near = jb('x0', 100, 450);
    final far = jb('x1', 1500, 450);
    final l = skidViewLayout([near, far], 'left', planH: 1200, viewH: 1500);
    expect(l.map((p) => p.it.id), ['x1', 'x0']);
    expect(l.first.covered, closeTo(1, 1e-9));
    final r = skidViewLayout([near, far], 'right', planH: 1200, viewH: 1500);
    expect(r.map((p) => p.it.id), ['x0', 'x1']);
    // 나란히(겹치지 않게) 놓이면 안 가린다.
    final side = jb('side', 1400, 800);
    expect(
      skidViewLayout(
        [side, back],
        kSkidViewFront,
        planH: 1200,
        viewH: 1500,
      ).firstWhere((p) => p.it.id == 'back').covered,
      0,
    );
  });

  testWidgets('정면: 뒤에 가려진 부품은 점선 테두리, 관리에서 끄면 안 그린다(임시 저장에 남음)', (
    tester,
  ) async {
    Map<String, dynamic> jb(String id, double y) => PlacedItem(
      id: id,
      name: '정션박스 300×300',
      position: Offset(1000, y),
      width: 300,
      height: 300,
      shape: SkidShape.jb,
      elevation: 800,
    ).toJson();
    await openSkid(
      tester,
      prefs: {
        'layout_board_draft_v1': jsonEncode({
          'kind': kLayoutKindSkid,
          'panelWidth': 2400,
          'panelHeight': 1200,
          'items': [jb('front', 800), jb('back', 100)],
        }),
      },
    );
    await tester.tap(find.byKey(const ValueKey('plate_tab_front')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hidden_back')), findsOneWidget);
    expect(find.byKey(const ValueKey('hidden_front')), findsNothing);
    // 가까운 부품이 Stack에서 나중(위)이다.
    final order = tester
        .widgetList<Positioned>(find.byType(Positioned))
        .map((p) => p.key)
        .whereType<ValueKey<String>>()
        .map((k) => k.value)
        .where((v) => v == 'view_front' || v == 'view_back')
        .toList();
    expect(order, ['view_back', 'view_front']);

    // 관리 → 가려진 부품 보이기 끄기
    await tester.tap(find.byIcon(AppIcons.more).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle_hidden_parts')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hidden_back')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('layout_board_draft_v1')!) as Map;
    expect(saved['showHiddenParts'], false);
  });
  test('좌우 뒤집기: 저장했다 읽어도 남고(예전 도면은 false), 그림이 실제로 좌우 대칭으로 바뀐다', () async {
    final lb = PlacedItem(
      id: 'lb',
      name: '곤질레다 LB 22',
      position: Offset.zero,
      width: 125,
      height: 48,
      shape: SkidShape.cdLB,
      flipped: true,
    );
    expect(lb.toJson()['flip'], true);
    expect(PlacedItem.fromJson(lb.toJson()).flipped, isTrue);
    final old = Map<String, dynamic>.from(lb.toJson())..remove('flip');
    expect(PlacedItem.fromJson(old).flipped, isFalse);

    Future<List<int>> px(bool mirror, Size size) async {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));
      SkidPartPainter(shape: SkidShape.cdLB, mirror: mirror).paint(c, size);
      final img = await rec.endRecording().toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      return (await img.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
    }

    // 가로로 놓인 LB: 뒤집은 그림의 (x)는 원래 그림의 (w-1-x)와 같다.
    const size = Size(120, 48);
    final a = await px(false, size), b = await px(true, size);
    int diff = 0;
    for (int y = 0; y < 48; y++) {
      for (int x = 0; x < 120; x++) {
        final i = (y * 120 + x) * 4, j = (y * 120 + (119 - x)) * 4;
        if ((a[i] - b[j]).abs() > 40) diff++;
      }
    }
    expect(diff, lessThan(120 * 48 * 0.02)); // 테두리 반 픽셀 차이만
    // 뒤집기 전후가 같은 그림이면 안 된다(허브가 한쪽에만 있으니).
    int same = 0;
    for (int k = 0; k < a.length; k += 4) {
      if ((a[k] - b[k]).abs() > 40) same++;
    }
    expect(same, greaterThan(50));
    // 세로로 돌려 놓아도(칸이 세로로 김) 길이 방향으로 뒤집힌다: 위아래가 바뀐다.
    const tall = Size(48, 120);
    final c = await px(false, tall), d = await px(true, tall);
    int diffV = 0;
    for (int y = 0; y < 120; y++) {
      for (int x = 0; x < 48; x++) {
        final i = (y * 48 + x) * 4, j = ((119 - y) * 48 + x) * 4;
        if ((c[i] - d[j]).abs() > 40) diffV++;
      }
    }
    expect(diffV, lessThan(120 * 48 * 0.02));
  });

  testWidgets('편집 창의 좌우 뒤집기 단추는 전선관 부속에만 있고, 누르면 뒤집히고 되돌리기로 돌아온다', (
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
              id: 'lb',
              name: '곤질레다 LB 22',
              position: const Offset(1000, 500),
              width: 125,
              height: 48,
              shape: SkidShape.cdLB,
              depth: 72,
            ).toJson(),
            PlacedItem(
              id: 'jb',
              name: '정션박스 300×300',
              position: const Offset(200, 200),
              width: 300,
              height: 300,
              shape: SkidShape.jb,
            ).toJson(),
          ],
        }),
      },
    );
    await tester.tap(find.byKey(const ValueKey('jb')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('flip_button')), findsNothing);
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('lb')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('flip_button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('flip_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(LayoutBoardPage)) as dynamic;
    Map<String, dynamic> lb() {
      final plates = state.debugPlates() as Map<String, Map<String, dynamic>>;
      return Map<String, dynamic>.from(
        (plates[kPlateMain]!['items'] as List).firstWhere(
              (e) => e['id'] == 'lb',
            )
            as Map,
      );
    }

    expect(lb()['flip'], true);
    expect(lb()['w'], 125); // 크기는 그대로
    await tester.tap(find.byIcon(AppIcons.undo).first);
    await tester.pumpAndSettle();
    expect(lb()['flip'], isNull);
  });
  testWidgets('정면에서 고정 치수 측정: 평면 부품 둘을 누르면 치수가 생기고, 부품이 옮겨지면 치수가 따라온다', (
    tester,
  ) async {
    Map<String, dynamic> jb(String id, double x, double elev) => PlacedItem(
      id: id,
      name: '정션박스 300×300',
      position: Offset(x, 450),
      width: 300,
      height: 300,
      shape: SkidShape.jb,
      elevation: elev,
    ).toJson();
    await openSkid(
      tester,
      prefs: {
        'layout_board_draft_v1': jsonEncode({
          'kind': kLayoutKindSkid,
          'panelWidth': 2400,
          'panelHeight': 1200,
          'items': [jb('a', 200, 800), jb('b', 1500, 800)],
        }),
      },
    );
    await tester.tap(find.byKey(const ValueKey('plate_tab_front')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('고정 치수 측정'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('view_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('view_b')));
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(LayoutBoardPage)) as dynamic;
    Map<String, dynamic> front() {
      final plates = state.debugPlates() as Map<String, Map<String, dynamic>>;
      return plates['front']!;
    }

    final dims = front()['dimensions'] as List;
    expect(dims, hasLength(1));
    final d = Map<String, dynamic>.from(dims.single as Map);
    expect(d['p1']['id'], 'view_a');
    expect(d['p2']['id'], 'view_b');
    // 정면에서 본 자리: a는 x 200, 높이 800 → 위 = 1500-800-150 = 550
    expect(d['p1']['x'], 200);
    expect(d['p1']['y'], 550);
    // 센터 거리 = 1650 - 350 = 1300
    final dim = PlacedDimension.fromJson(d);
    expect(computeDimensionEndpoints(dim).distance, 1300);

    // 평면에서 b를 오른쪽으로 옮기면(저장 칸을 직접 고침) 정면 치수가 따라온다.
    await tester.tap(find.byKey(const ValueKey('plate_tab_main')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('모듈 배치/이동'));
    await tester.pumpAndSettle();
    final Offset c = tester.getCenter(find.byKey(const ValueKey('b')));
    final g = await tester.startGesture(c);
    for (int i = 0; i < 10; i++) {
      await g.moveBy(const Offset(8, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plate_tab_front')));
    await tester.pumpAndSettle();
    final moved = PlacedDimension.fromJson(
      Map<String, dynamic>.from((front()['dimensions'] as List).single as Map),
    );
    expect(computeDimensionEndpoints(moved).distance, greaterThan(1300));
  });
  test('경로 입력 작은 도면: 정면·측면에 평면 부품을 점선 네모 대신 그 면에서 본 모양으로 그린다', () async {
    final jb = PlacedItem(
      id: 'j',
      name: '정션박스 300×300',
      position: const Offset(1000, 450),
      width: 300,
      height: 300,
      shape: SkidShape.jb,
      elevation: 800,
    );
    Future<List<int>> px(List<PlacedItem> plan) async {
      const size = Size(300, 200);
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      SkidMiniViewPainter(
        board: const Size(2400, 1500),
        items: const [],
        view: kSkidViewFront,
        planViews: skidViewLayout(
          plan,
          kSkidViewFront,
          planH: 1200,
          viewH: 1500,
        ),
        others: const [],
        route: const [],
        routeOd: 26.5,
        version: 'v',
      ).paint(c, size);
      final img = await rec.endRecording().toImage(300, 200);
      return (await img.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
    }

    final empty = await px([]);
    final withJb = await px([jb]);
    int diff = 0;
    for (int k = 0; k < empty.length; k += 4) {
      if ((empty[k] - withJb[k]).abs() > 40) diff++;
    }
    expect(diff, greaterThan(100)); // JB가 그려졌다
    // 뒤에 가려진 부품이 있어도 그려진다(점선 테두리 포함).
    final back = PlacedItem(
      id: 'b',
      name: '정션박스 300×300',
      position: const Offset(1100, 100), // 2/3 가려짐
      width: 300,
      height: 300,
      shape: SkidShape.jb,
      elevation: 800,
    );
    final two = await px([jb, back]);
    int diff2 = 0;
    for (int k = 0; k < two.length; k += 4) {
      if ((two[k] - withJb[k]).abs() > 40) diff2++;
    }
    expect(diff2, greaterThan(20)); // 안 가려진 1/3과 점선이 그려졌다
  });

  test('커플링·유니온은 칸 비율이 아니라 돌린 횟수로 방향을 본다(지름이 길이보다 크다)', () {
    final u = kSkidFittingPresets['유니온 커플링']!.firstWhere(
      (p) => p.name.endsWith(' 54'),
    );
    expect(u.height, greaterThan(u.width)); // 63 × 82
    PlacedItem item({int? rotation}) => PlacedItem(
      id: 'u',
      name: u.name,
      position: Offset.zero,
      width: rotation == 90 ? u.height : u.width,
      height: rotation == 90 ? u.width : u.height,
      shape: u.shape,
      depth: u.depth,
      rotation: rotation,
    );
    // 놓은 그대로면 길이가 x 방향: 정면에서는 옆모습, 좌측면에서는 끝모습.
    expect(skidViewFace(item(), kSkidViewFront), SkidFace.side);
    expect(skidViewFace(item(), 'left'), SkidFace.end);
    expect(skidViewFace(item(rotation: 90), kSkidViewFront), SkidFace.end);
    expect(
      InstrumentShape.inferredQuarterTurns(u.shape!, Size(u.width, u.height)),
      0,
    );
    // 곤질레다는 예전처럼 칸 비율로 가린다(세로로 길면 y 방향).
    final lb = kSkidFittingPresets['곤질레다 LB']!.first;
    expect(
      skidViewFace(
        PlacedItem(
          id: 'b',
          name: lb.name,
          position: Offset.zero,
          width: lb.height,
          height: lb.width,
          shape: lb.shape,
          depth: lb.depth,
        ),
        kSkidViewFront,
      ),
      SkidFace.end,
    );
  });
}
