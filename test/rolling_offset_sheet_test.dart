// 굴림 오프셋 시트가 목록에 넣는 첫 구간.
// 예전에는 축소값만 넣어 R150·높이 100·45°에서 1번 마킹이 −20.7mm였다.
// 반경이 달라도 1번 마킹이 시작 거리 자리에 와야 한다.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/core/engine/tube_bending_engine.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_rolling_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/rolling_offset_guide.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';

BendSheetSpecs tubeSpecs(double r) =>
    BendSheetSpecs(radius: r, gain90: 0, markOffset: (a) => bendSetback(r, a));

double firstMark(List<(double, double, double)> bends, double r) {
  final res = TubeBendingEngine(radius: r).calculate([
    for (final (l, a, rot) in bends)
      BendInstruction(length: l, angle: a, rotation: rot),
  ], 0);
  return (res['steps'] as List<StepResult>).first.markingPoint;
}

void main() {
  // 높이 100, 굴림 0, 45°: 빗변 141.42, 전진 100.
  final travel = 100 / math.sin(math.pi / 4);
  const advance = 100.0;

  for (final r in [38.1, 100.0, 150.0]) {
    for (final start in [0.0, 250.0]) {
      test('R$r 시작 거리 $start: 1번 마킹 = 시작 거리', () {
        final bends = rollingOffsetBends(
          specs: tubeSpecs(r),
          startDistance: start,
          travel: travel,
          angle: 45,
          advance: advance,
          rotation: 0,
        );
        expect(firstMark(bends, r), closeTo(start, 0.1));
        expect(bends[1].$1, closeTo(141.4, 0.05));
      });
    }
  }

  test('두 번째 방향은 반대(앞↔뒤 포함)', () {
    for (final (sel, opp) in [(0.0, 180.0), (360.0, 450.0), (450.0, 360.0)]) {
      final bends = rollingOffsetBends(
        specs: tubeSpecs(100),
        startDistance: 0,
        travel: travel,
        angle: 45,
        advance: advance,
        rotation: sel,
      );
      expect(bends[0].$3, sel);
      expect(bends[1].$3, opp);
    }
  });

  testWidgets('시트에서 넣으면 1번 마킹이 시작 거리(기본 0) 자리', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final added = <(double, double, double)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => MobileRollingOffsetBottomSheet.show(
                context,
                currentRotation: 0,
                specs: tubeSpecs(150),
                onAddBend: (l, a, r) => added.add((l, a, r)),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('UP'));
    await tester.tap(find.text('UP'));
    await tester.pump();
    await tester.ensureVisible(find.text('목록에 넣기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('목록에 넣기'));
    await tester.pump();
    expect(added, hasLength(2));
    expect(firstMark(added, 150), closeTo(0, 0.1));
  });

  Future<void> openSheet(
    WidgetTester tester, {
    required void Function(double, double, double) one,
    void Function(List<Map<String, double>>)? many,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => MobileRollingOffsetBottomSheet.show(
                context,
                currentRotation: 0,
                specs: tubeSpecs(150),
                onAddBend: one,
                onAddBends: many,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('UP'));
    await tester.tap(find.text('UP'));
    await tester.pump();
  }

  testWidgets('X12 한 벌을 한 번에 넣는다(↶ 한 번에 빠지게)', (tester) async {
    final one = <(double, double, double)>[];
    final many = <List<Map<String, double>>>[];
    await openSheet(
      tester,
      one: (l, a, r) => one.add((l, a, r)),
      many: many.add,
    );
    await tester.ensureVisible(find.text('목록에 넣기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('목록에 넣기'));
    await tester.pump();
    expect(one, isEmpty);
    expect(many, hasLength(1));
    expect(many.single, hasLength(2));
  });

  testWidgets('F3 각도가 비면 말없이 넘어가지 않고 알린다', (tester) async {
    final one = <(double, double, double)>[];
    await openSheet(tester, one: (l, a, r) => one.add((l, a, r)));
    final angle = find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == '45',
    );
    // 숫자판으로 넣는 칸이라 글을 바로 비운다.
    tester.widget<TextField>(angle.first).controller!.text = '';
    await tester.pump();
    await tester.ensureVisible(find.text('목록에 넣기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('목록에 넣기'));
    await tester.pump();
    expect(one, isEmpty);
    expect(find.byKey(const Key('rolling_missing')), findsOneWidget);
  });

  testWidgets('각도를 90° 이상(120°)으로 넣으면 목록에 넣지 않고 알린다(10-08)', (tester) async {
    final one = <(double, double, double)>[];
    final many = <List<Map<String, double>>>[];
    await openSheet(tester, one: (l, a, r) => one.add((l, a, r)), many: many.add);
    final angle = find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == '45',
    );
    tester.widget<TextField>(angle.first).controller!.text = '120';
    await tester.pump();
    await tester.ensureVisible(find.text('목록에 넣기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('목록에 넣기'));
    await tester.pump();
    expect(one, isEmpty);
    expect(many, isEmpty);
    expect(find.text('넣을 수 없습니다. 각도는 90°보다 작아야 합니다.'), findsOneWidget);
  });

  testWidgets('입력 칸을 누르면 그림이 그 값을 강조한다(칸 ↔ 그림 연동)', (tester) async {
    await openSheet(tester, one: (l, a, r) {});
    RollingFocus? focus() =>
        tester
            .widget<RollingOffsetGuide>(
              find.byType(RollingOffsetGuide, skipOffstage: false),
            )
            .focus;
    expect(focus(), isNull);

    await tester.ensureVisible(find.byType(TextField).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).at(0)); // Rise 칸
    await tester.pumpAndSettle();
    expect(focus(), RollingFocus.rise);
    // 숫자판 오른쪽 위 닫기 단추.
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    // 빠른 각도 단추는 벤딩 각도 칸과 같은 값이다.
    await tester.ensureVisible(find.text('30°'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30°'));
    await tester.pumpAndSettle();
    expect(focus(), RollingFocus.bend);
    expect(tester.takeException(), isNull);
  });

  // 10-09: 시트에 보이는 "1번 → 2번 마킹 간격"이 마킹 탭(엔진·전선관 마킹)과 같아야 한다.
  // 예전 시트는 빗변 − R·tan(θ/2)로 R38.1·45°에서 125.6을 보였다(마킹 탭 139.8).
  test("시트 마킹 간격 = 튜브 마킹 탭의 1번→2번 간격(반경·실측 게인)", () {
    for (final (r, g90) in [(38.1, 0.0), (38.1, 12.0), (100.0, 0.0), (57.2, 24.5)]) {
      for (final ang in [22.5, 30.0, 45.0, 60.0]) {
        final specs = BendSheetSpecs(
          radius: r,
          gain90: g90,
          markOffset: (a) => bendSetback(r, a),
        );
        final tr = 100 / math.sin(ang * math.pi / 180);
        final bends = rollingOffsetBends(
          specs: specs,
          startDistance: 200,
          travel: tr,
          angle: ang,
          advance: 100 / math.tan(ang * math.pi / 180),
          rotation: 0,
        );
        final res = TubeBendingEngine(radius: r, userGain90: g90).calculate([
          for (final (l, a, rot) in bends)
            BendInstruction(length: l, angle: a, rotation: rot),
        ], 0);
        final steps = res["steps"] as List<StepResult>;
        final gap = steps[1].markingPoint - steps[0].markingPoint;
        // 목록 줄은 0.1로 반올림해 넣으므로 그만큼만 허용.
        expect(specs.markGap(tr, ang), closeTo(gap, 0.1), reason: "R$r g$g90 $ang°");
      }
    }
    // 보고된 예: R38.1, 진짜 오프셋 100, 45° → 139.8.
    final s = BendSheetSpecs(radius: 38.1, gain90: 0, markOffset: (a) => bendSetback(38.1, a));
    expect(s.markGap(100 / math.sin(math.pi / 4), 45), closeTo(139.8, 0.05));
  });

  test("시트 마킹 간격 = 전선관 마킹의 1번→2번 간격(표 게인 비율)", () {
    final settings = <String, dynamic>{
      "benderType": "hand",
      "takeUp": 152.4,
      "gain": 82.5,
      "clr": 114.3,
      "applySpringback": false,
    };
    final specs = BendSheetSpecs.conduit(settings);
    for (final ang in [10.0, 22.5, 30.0, 45.0, 60.0]) {
      final tr = 100 / math.sin(ang * math.pi / 180);
      final marks = calculateConduitMarkings([
        {"length": 300.0, "angle": ang},
        {"length": tr, "angle": ang},
      ], settings);
      final gap = (marks[1]["mark"] as num) - (marks[0]["mark"] as num);
      expect(specs.markGap(tr, ang), closeTo(gap, 0.01), reason: "$ang°");
    }
  });

  testWidgets('전선관(축소값 더하기 켬)이면 시작 거리 칸이 "1번 마킹 = 이 값 + 축소값"이라고 말한다(10-09)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Future<void> openWith(BendSheetSpecs specs) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => MobileRollingOffsetBottomSheet.show(
                  context,
                  currentRotation: 0,
                  specs: specs,
                  onAddBend: (l, a, r) {},
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
    }

    await openWith(BendSheetSpecs.conduit({
      'benderType': 'hand',
      'takeUp': 152.4,
      'gain': 82.5,
      'clr': 114.3,
      'applyShrink': true,
    }));
    expect(find.textContaining('1번 마킹 = 이 값 + 축소값'), findsOneWidget);
  });

  testWidgets('튜브(축소값을 따로 더하지 않음)는 예전처럼 "1번 마킹 자리"', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => MobileRollingOffsetBottomSheet.show(
                context,
                currentRotation: 0,
                specs: tubeSpecs(38.1),
                onAddBend: (l, a, r) {},
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1번 마킹 자리'), findsOneWidget);
    expect(find.textContaining('이 값 + 축소값'), findsNothing);
  });
}
