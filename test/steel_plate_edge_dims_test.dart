// 도면 변 길이 치수(10-11, 사용자: "스케치 화면에서 넘긴 모양 도면 치수가 더 필요한데 치수가 빠진 게 보여"):
// 좌표로 넣은 판(좌표 입력·직접 절곡)은 꼭짓점~꼭짓점 변 길이를 판 바깥쪽에, 전체 치수는 그 바깥 줄로.
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_painter.dart';

const _t = [
  Offset(0, 0),
  Offset(65, 0),
  Offset(65, 40),
  Offset(145, 40),
  Offset(145, 0),
  Offset(210, 0),
  Offset(210, 75),
  Offset(142, 75),
  Offset(142, 145),
  Offset(68, 145),
  Offset(68, 75),
  Offset(0, 75),
];

void main() {
  cornerMarkTests();
  test('좌표 입력 판은 꼭짓점을 그림 자리로 들고 있다(돌리면 돌린 자리)', () {
    final p = platePlan(
      const PlateInput(shape: PlateShape.free, t: 3, points: _t),
    );
    expect(p.vertices, _t);
    final r = platePlan(
      const PlateInput(shape: PlateShape.free, t: 3, points: _t, rotQ: 1),
    );
    expect(r.vertices, [for (final v in _t) r.toDisplay(v)]);
    // 평판·절곡(ㄱ자)은 꼭짓점 치수를 안 단다
    expect(
      platePlan(
        const PlateInput(shape: PlateShape.flat, t: 3, length: 100, width: 50),
      ).vertices,
      isEmpty,
    );
  });

  test('직접 절곡은 전개도 자리(절곡부만큼 줄어든 x)', () {
    final p = platePlan(
      const PlateInput(
        shape: PlateShape.custom,
        t: 3,
        points: _t,
        bendLines: [PlateBendSpec(at: 30)],
      ),
    );
    expect(p.vertices.length, _t.length);
    // 오른쪽 끝 꼭짓점 x = 전개 길이(판 왼쪽 0에서)
    expect(p.vertices[5].dx, closeTo(p.maxX, 1e-9));
    expect(p.vertices[5].dx, lessThan(210));
  });

  test('변 치수를 켜면 전체 치수선이 한 줄 바깥으로', () {
    final p = platePlan(
      const PlateInput(shape: PlateShape.free, t: 3, points: _t),
    );
    const size = Size(800, 600);
    final a = PlatePainterLayout.of(p, size)!;
    final b = PlatePainterLayout.of(p, size, edgeDims: true)!;
    expect(b.edge, greaterThan(0));
    expect(b.topLeft.dy - b.widthDimY, greaterThan(a.topLeft.dy - a.widthDimY));
    expect(
      b.topLeft.dx - b.heightDimX,
      greaterThan(a.topLeft.dx - a.heightDimX),
    );
  });

  testWidgets('변 치수 그림(PDF 크기 글씨)도 그려진다', (tester) async {
    final p = platePlan(
      const PlateInput(
        shape: PlateShape.free,
        t: 3,
        points: _t,
        holes: [PlateHoleSpec(u: 105, v: 110, dia: 13.5)],
      ),
    );
    late ByteData? png;
    await tester.runAsync(() async {
      final rec = PictureRecorder();
      PlatePainter(
        plan: p,
        text: Colors.black,
        sub: Colors.grey,
        bg: Colors.white,
        fontScale: 2.2,
        holeDims: true,
        holeSizes: true,
        edgeDims: true,
      ).paint(Canvas(rec), const Size(1400, 1000));
      final img = await rec.endRecording().toImage(1400, 1000);
      png = await img.toByteData(format: ImageByteFormat.png);
    });
    expect(png!.lengthInBytes, greaterThan(1000));
  });

  testWidgets('스케치에서 넘긴 좌표 입력 판: 모양·결과 탭 그림에 변 치수', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PlatePage(
          bend: false,
          share: (_) async {},
          initial: {
            'sh': 'free',
            't': '3',
            'pts': [
              for (final v in _t) '${v.dx.round()},${v.dy.round()}',
            ].join('\n'),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    PlatePainter painter() =>
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
    expect(painter().edgeDims, isTrue);
    expect(painter().plan.vertices.length, 12);
    await tester.tap(find.byKey(const Key('pl_tab_result')));
    await tester.pumpAndSettle();
    expect(painter().edgeDims, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}

void cornerMarkTests() {
  test('코너 크기 글: 돌린 평판 따내기는 그림 가로 × 세로, 좌표 판은 앞 변 × 다음 변, 절곡 판 네 귀', () {
    final flat = platePlan(
      const PlateInput(
        shape: PlateShape.flat,
        t: 3,
        length: 200,
        width: 100,
        rotQ: 1,
        corners: [
          PlateCorner(PlateCornerKind.notch, 30, 10),
          PlateCorner.square,
          PlateCorner.square,
          PlateCorner.square,
        ],
      ),
    );
    final m = flat.cornerMarks.single;
    expect(m.label, '따냄 가로 10 × 세로 30');
    expect(m.at, Offset(flat.maxX, flat.minY)); // 돌린 판의 오른쪽 아래
    final free = platePlan(
      const PlateInput(
        shape: PlateShape.free,
        t: 3,
        points: [
          Offset(0, 0),
          Offset(200, 0),
          Offset(200, 100),
          Offset(0, 100),
        ],
        pointCorners: [
          PlateCorner.square,
          PlateCorner(PlateCornerKind.notch, 20, 15),
          PlateCorner.square,
          PlateCorner.square,
        ],
      ),
    );
    expect(free.cornerMarks.single.label, '따냄 앞 변 20 × 다음 변 15');
    final l = platePlan(
      const PlateInput(
        shape: PlateShape.l,
        t: 3,
        legs: [60, 85],
        width: 70,
        corners: [
          PlateCorner(PlateCornerKind.round, 10),
          PlateCorner(PlateCornerKind.round, 10),
          PlateCorner(PlateCornerKind.round, 10),
          PlateCorner(PlateCornerKind.round, 10),
        ],
      ),
    );
    expect(l.cornerMarks.length, 4);
    expect(l.cornerMarks.every((m) => m.label == 'R10'), isTrue);
    // 삼각 리브도 변 치수(따낸 모서리·빗변)
    final rib = platePlan(
      const PlateInput(
        shape: PlateShape.rib,
        t: 6,
        ribA: 150,
        ribB: 120,
        ribC: 20,
      ),
    );
    expect(rib.vertices.length, 4);
  });
}
