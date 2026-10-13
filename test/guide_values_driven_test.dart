// 그림 설명(애니메이션)이 입력 값을 따라 모양이 바뀌는지: 같은 값이면 같은 그림, 각도나 비율이 다르면 다른 그림.
// (예전에는 오프셋·새들·킥·평행·축소 그림이 각도를 글자로만 바꾸고 모양은 고정이었다.)
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/offset_guide.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/parallel_shrink_guide.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/quick_kick_guide.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/quick_u_bend_guide.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/saddle_guide.dart';
import 'package:tubing_calculator/src/presentation/conduit/widgets/conduit_special_guides.dart';

class Shot {
  final List<int> bytes;
  final int w, h;
  Shot(this.bytes, this.w, this.h);

  /// [r,g,b] 색(±[tol])인 픽셀이 차지하는 가장 바깥 사각형. 없으면 null.
  Rect? box(int r, int g, int b, {int tol = 28}) {
    var minX = w, minY = h, maxX = -1, maxY = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (x > w - 44 && y < 34) continue; // 오른쪽 위 다시 보기 단추(청록)는 뺀다
        final i = (y * w + x) * 4;
        if ((bytes[i] - r).abs() <= tol && (bytes[i + 1] - g).abs() <= tol && (bytes[i + 2] - b).abs() <= tol) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    return maxX < 0 ? null : Rect.fromLTRB(minX.toDouble(), minY.toDouble(), maxX.toDouble(), maxY.toDouble());
  }
}

/// 그림을 끝까지 움직인 뒤 화면 그대로의 픽셀 값을 읽는다.
Future<Shot> pixels(WidgetTester tester, Widget guide) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: SizedBox(width: 340, child: guide),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 8));
  late Shot shot;
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1.0);
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List().toList();
    shot = Shot(bytes, img.width, img.height);
  });
  return shot;
}

void main() {
  // 관 색(브랜드 청록 #007580)이 차지하는 범위가 모양을 따라 바뀌는지 본다. 글자·값표만 바뀌면 범위는 그대로다.
  const teal = (0, 117, 128);
  const orange = (234, 88, 12);

  Future<void> expectDiffers(
    WidgetTester tester,
    Widget a,
    Widget b,
    String why, {
    (int, int, int) color = teal,
    double minMove = 10,
  }) async {
    final ra = (await pixels(tester, a)).box(color.$1, color.$2, color.$3);
    final rb = (await pixels(tester, b)).box(color.$1, color.$2, color.$3);
    expect(ra, isNotNull, reason: '$why: 첫 그림에 관 색이 없다');
    expect(rb, isNotNull, reason: '$why: 둘째 그림에 관 색이 없다');
    final move = (ra!.left - rb!.left).abs() + (ra.top - rb.top).abs() + (ra.right - rb.right).abs() + (ra.bottom - rb.bottom).abs();
    expect(move, greaterThanOrEqualTo(minMove), reason: '$why: 관이 차지하는 범위가 거의 같다($ra / $rb)');
  }

  testWidgets('같은 값이면 같은 그림이다(그림이 매번 달라지지 않는다)', (tester) async {
    const g = OffsetGuide(heightMm: 100, runMm: 173, travelMm: 200, shrinkMm: 27, angleDeg: 30);
    final a = await pixels(tester, g);
    final b = await pixels(tester, g);
    expect(a.bytes, b.bytes);
  });

  testWidgets('일반 오프셋: 각도 15° → 60°에서 모양이 바뀐다', (tester) async {
    await expectDiffers(
      tester,
      const OffsetGuide(heightMm: 100, runMm: 373, travelMm: 386, shrinkMm: 13, angleDeg: 15),
      const OffsetGuide(heightMm: 100, runMm: 58, travelMm: 115, shrinkMm: 58, angleDeg: 60),
      '오프셋 각도',
    );
  });

  testWidgets('킥: 각도 15° → 60°에서 모양이 바뀐다', (tester) async {
    await expectDiffers(
      tester,
      const QuickKickGuide(heightMm: 100, runMm: 373, travelMm: 386, angleDeg: 15),
      const QuickKickGuide(heightMm: 100, runMm: 58, travelMm: 115, angleDeg: 60),
      '킥 각도',
    );
  });

  testWidgets('새들: 다리 각도 22.5° → 45°, 마루 폭이 달라도 모양이 바뀐다', (tester) async {
    await expectDiffers(
      tester,
      const SaddleGuide(heightMm: 100, travelMm: 261, shrinkMm: 20, cornerAngleDeg: 22.5, peakAngleDeg: 45),
      const SaddleGuide(heightMm: 100, travelMm: 141, shrinkMm: 40, cornerAngleDeg: 45, peakAngleDeg: 90),
      '새들 각도',
    );
    await expectDiffers(
      tester,
      const SaddleGuide(heightMm: 100, travelMm: 200, shrinkMm: 30, cornerAngleDeg: 30, flatWidthMm: 40),
      const SaddleGuide(heightMm: 100, travelMm: 200, shrinkMm: 30, cornerAngleDeg: 30, flatWidthMm: 250),
      '새들 마루 폭',
    );
  });

  testWidgets('평행: 각도에 따라 꺾임 기울기와 스태거 폭이 바뀐다', (tester) async {
    await expectDiffers(
      tester,
      ParallelShrinkGuide.parallel(angleDeg: 15, spacingMm: 100, staggerMm: 13),
      ParallelShrinkGuide.parallel(angleDeg: 60, spacingMm: 100, staggerMm: 58),
      '평행 각도',
    );
  });

  testWidgets('축소값: 각도에 따라 삼각형 모양이 바뀐다', (tester) async {
    await expectDiffers(
      tester,
      ParallelShrinkGuide.shrink(angleDeg: 15, riseMm: 100, shrinkMm: 13),
      ParallelShrinkGuide.shrink(angleDeg: 70, riseMm: 100, shrinkMm: 70),
      '축소값 각도',
    );
  });

  testWidgets('퀵 U벤드: C-C 폭과 리턴 길이 비율에 따라 모양이 바뀐다', (tester) async {
    await expectDiffers(
      tester,
      const QuickUBendGuide(startMm: 300, returnMm: 300, cToCWidthMm: 60, apexMm: 330),
      const QuickUBendGuide(startMm: 300, returnMm: 120, cToCWidthMm: 130, apexMm: 365),
      'U벤드 비율',
    );
  });

  testWidgets('분할 90°: 나누는 횟수에 따라 모양이 바뀐다', (tester) async {
    await expectDiffers(
      tester,
      const SegmentedGuide(radiusMm: 300, bends: 3, spacingMm: 160, angleDeg: 30),
      const SegmentedGuide(radiusMm: 300, bends: 8, spacingMm: 50, angleDeg: 11.25),
      '분할 횟수',
    );
  });

  testWidgets('백투백 90°: 간격 ÷ 첫 다리 비율에 따라 폭이 바뀐다', (tester) async {
    await expectDiffers(
      tester,
      const BackToBackGuide(spacingMm: 150, distanceMm: 176, firstMm: 400, outside: true),
      const BackToBackGuide(spacingMm: 600, distanceMm: 626, firstMm: 400, outside: true),
      '백투백 비율',
    );
  });

  testWidgets('스터브업: 마킹 ÷ 스터브 비율에 따라 마킹 자리가 바뀐다', (tester) async {
    await expectDiffers(
      tester,
      const StubUpGuide(stubMm: 300, markMm: 100),
      const StubUpGuide(stubMm: 300, markMm: 250),
      '스터브업 마킹 자리',
      color: orange,
      minMove: 6,
    );
  });

  testWidgets('값이 0이어도 모든 그림이 오류 없이 그려진다', (tester) async {
    for (final g in <Widget>[
      const OffsetGuide(heightMm: 0, runMm: 0, travelMm: 0, shrinkMm: 0, angleDeg: 0),
      const QuickKickGuide(heightMm: 0, runMm: 0, travelMm: 0, angleDeg: 0),
      const SaddleGuide(heightMm: 0, travelMm: 0, shrinkMm: 0, cornerAngleDeg: 0),
      ParallelShrinkGuide.parallel(angleDeg: 0, spacingMm: 0, staggerMm: 0),
      ParallelShrinkGuide.shrink(angleDeg: 0, riseMm: 0, shrinkMm: 0),
      const QuickUBendGuide(startMm: 0, returnMm: 0, cToCWidthMm: 0, apexMm: 0),
      const SegmentedGuide(radiusMm: 0, bends: 5, spacingMm: 0, angleDeg: 0),
      const BackToBackGuide(spacingMm: 0, distanceMm: 0, firstMm: 0, outside: true),
      const StubUpGuide(stubMm: 0, markMm: 0),
    ]) {
      await pixels(tester, g);
      expect(tester.takeException(), isNull, reason: g.runtimeType.toString());
    }
  });

  testWidgets('극단 각도(5°·85°)에서도 오류 없이 그려진다', (tester) async {
    for (final a in [3.0, 5.0, 85.0, 89.0]) {
      for (final g in <Widget>[
        OffsetGuide(heightMm: 100, runMm: 50, travelMm: 120, shrinkMm: 10, angleDeg: a),
        QuickKickGuide(heightMm: 100, runMm: 50, travelMm: 120, angleDeg: a),
        SaddleGuide(heightMm: 100, travelMm: 120, shrinkMm: 10, cornerAngleDeg: a, peakAngleDeg: a * 2, flatWidthMm: 50),
        ParallelShrinkGuide.parallel(angleDeg: a, spacingMm: 100, staggerMm: 10),
        ParallelShrinkGuide.shrink(angleDeg: a, riseMm: 100, shrinkMm: 10),
      ]) {
        await pixels(tester, g);
        expect(tester.takeException(), isNull, reason: '${g.runtimeType} $a');
      }
    }
  });
}
