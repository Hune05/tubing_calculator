// 측면도 홀 표시(10-11, 사용자: "측면도에서 홀이 있으면 홀 표현도 해줘 캐드처럼"): 면을 뚫은 홀은 두께를 가로지르는
// 숨은선 두 줄과 중심선으로. 그릴 홀 고르기(자기 면 곧은 부분만)와 장공 길이 몫을 본다.
import 'dart:typed_data';

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_side_painter.dart';

void main() {
  PlatePlan z(List<PlateHoleSpec> holes) => platePlan(
    PlateInput(
      shape: PlateShape.z,
      t: 4,
      legs: const [60, 85, 50],
      width: 70,
      holes: holes,
    ),
  );

  test('면마다 홀 자리(면 시작에서 바깥 치수), 장공은 길이 방향 반 길이', () {
    final p = z(const [
      PlateHoleSpec(face: 0, u: 25, v: 35, dia: 11),
      PlateHoleSpec(face: 1, u: 45, v: 35, dia: 13.5, slot: 30),
      PlateHoleSpec(face: 2, u: 30, v: 20, dia: 9),
    ]);
    final hs = plateSideHoles(p);
    expect(hs.length, 3);
    expect(hs[0], (0, 25.0, 5.5));
    expect(hs[1].$1, 1);
    expect(hs[1].$2, 45.0);
    expect(hs[1].$3, closeTo(15, 1e-9)); // 장공 30 → 양 끝 ±15
    expect(hs[2], (2, 30.0, 4.5));
    expect(
      PlateSidePainter.of(
        p,
        t: 4,
        text: Colors.black,
        sub: Colors.grey,
        bg: Colors.white,
      ).holes,
      hs,
    );
  });

  test('절곡부에 걸린 홀·면을 벗어난 홀·판 밖 홀은 측면도에 그리지 않는다', () {
    final p = z(const [
      PlateHoleSpec(face: 0, u: 58, v: 35, dia: 9), // 1번 절곡부
      PlateHoleSpec(face: 2, u: 70, v: 35, dia: 9), // 3면(50)을 벗어남
      PlateHoleSpec(face: 1, u: 40, v: 90, dia: 9), // 폭(70) 밖
      PlateHoleSpec(face: 1, u: 40, v: 35, dia: 9),
    ]);
    expect(plateSideHoles(p), [(1, 40.0, 4.5)]);
  });

  testWidgets('홀이 있는 측면도도 그려진다(PNG)', (tester) async {
    final p = z(const [
      PlateHoleSpec(face: 0, u: 25, v: 35, dia: 11),
      PlateHoleSpec(face: 1, u: 45, v: 35, dia: 13.5, slot: 30),
    ]);
    final painter = PlateSidePainter.of(
      p,
      t: 4,
      text: Colors.black,
      sub: Colors.grey,
      bg: Colors.white,
    );
    late ByteData? png;
    await tester.runAsync(() async {
      final rec = PictureRecorder();
      painter.paint(Canvas(rec), const Size(600, 400));
      final img = await rec.endRecording().toImage(600, 400);
      png = await img.toByteData(format: ImageByteFormat.png);
    });
    expect(png!.lengthInBytes, greaterThan(1000));
  });
}
