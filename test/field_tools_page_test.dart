// 수평계·각도기 화면에 가짜 센서 값을 넣어 본다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/field_tools/level_page.dart';
import 'package:tubing_calculator/src/presentation/field_tools/protractor_page.dart';
import 'package:tubing_calculator/src/presentation/field_tools/tilt_sensor.dart';

const g = 9.81;
double sinD(double d) => math.sin(d * math.pi / 180);
double cosD(double d) => math.cos(d * math.pi / 180);

Future<StreamController<TiltSample>> pumpPage(
  WidgetTester tester,
  Widget Function(Stream<TiltSample> Function() src) build,
) async {
  final c = StreamController<TiltSample>.broadcast();
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: build(() => c.stream)));
  return c;
}

Future<void> send(
  WidgetTester tester,
  StreamController<TiltSample> c,
  double x,
  double y,
  double z,
) async {
  c.add((x: x, y: y, z: z));
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('수평계', () {
    testWidgets('눕혀서 평평하면 둥근 기포 + 수평입니다', (tester) async {
      final c = await pumpPage(tester, (s) => LevelPage(source: s));
      await send(tester, c, 0, 0, g);
      expect(find.byKey(const Key('level_bullseye')), findsOneWidget);
      expect(find.text("수평입니다"), findsOneWidget);
      expect(find.text("0.0°"), findsNWidgets(2)); // 좌우·앞뒤
      await c.close();
    });

    testWidgets('세워서 3° 기울면 기포관 + 3.0°, 수평 아님', (tester) async {
      final c = await pumpPage(tester, (s) => LevelPage(source: s));
      await send(tester, c, g * sinD(3), g * cosD(3), 0);
      expect(find.byKey(const Key('level_tube')), findsOneWidget);
      expect(find.byKey(const Key('level_value')), findsOneWidget);
      expect(find.text("3.0°"), findsOneWidget);
      expect(find.text("기포 쪽이 높습니다"), findsOneWidget);
      await c.close();
    });

    testWidgets('단위를 바꾸면 %로, 영점을 맞추면 0으로', (tester) async {
      final c = await pumpPage(tester, (s) => LevelPage(source: s));
      final deg = math.atan(0.02) * 180 / math.pi; // 2% 구배
      await send(tester, c, g * sinD(deg), g * cosD(deg), 0);
      await tester.tap(find.byKey(const Key('level_unit')));
      await tester.pump();
      expect(find.text("2.00%"), findsOneWidget);

      await tester.tap(find.byKey(const Key('level_calibrate')));
      await tester.pump();
      expect(find.text("0.00%"), findsOneWidget);
      expect(find.text("수평입니다"), findsOneWidget);
      // 영점은 폰에 남는다.
      final p = await SharedPreferences.getInstance();
      expect(p.getString(kLevelCalibKey), contains('upright_x'));
      await c.close();
    });

    testWidgets('값 고정이면 센서가 바뀌어도 숫자가 그대로', (tester) async {
      final c = await pumpPage(tester, (s) => LevelPage(source: s));
      await send(tester, c, g * sinD(3), g * cosD(3), 0);
      await tester.tap(find.byKey(const Key('level_hold')));
      await tester.pump();
      for (int i = 0; i < 20; i++) {
        await send(tester, c, g * sinD(10), g * cosD(10), 0);
      }
      expect(find.text("3.0°"), findsOneWidget);
      await c.close();
    });

    testWidgets('센서 값이 안 오면 "읽을 수 없습니다"', (tester) async {
      final c = await pumpPage(
        tester,
        (s) => LevelPage(source: s, noSensorAfter: const Duration(seconds: 1)),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('level_no_sensor')), findsOneWidget);
      await c.close();
    });
  });

  group('각도기', () {
    testWidgets('기준을 잡고 45° 돌리면 굽힌 각 45.0°, 사이각 135.0°', (tester) async {
      final c = await pumpPage(tester, (s) => ProtractorPage(source: s));
      await send(tester, c, 0, g, 0); // 세워서 첫 다리
      await tester.tap(find.byKey(const Key('bend_reference')));
      await tester.pump();
      for (int i = 0; i < 60; i++) {
        await send(tester, c, g * sinD(45), g * cosD(45), 0); // 둘째 다리
      }
      expect(find.text("45.0°"), findsOneWidget);
      expect(find.text("두 다리 사이 각 135.0°"), findsOneWidget);
      await c.close();
    });

    testWidgets('눕혀 두면 세우라고 알리고 기준을 못 잡는다', (tester) async {
      final c = await pumpPage(tester, (s) => ProtractorPage(source: s));
      await send(tester, c, 0, 0.5, g);
      expect(find.byKey(const Key('bend_too_flat')), findsOneWidget);
      final btn = tester.widget<ButtonStyleButton>(
        find.byKey(const Key('bend_reference')),
      );
      expect(btn.onPressed, isNull);
      await c.close();
    });

    testWidgets('화면 각도기: 처음 두 팔 사이 60.0°, 끌면 바뀐다', (tester) async {
      final c = await pumpPage(
        tester,
        (s) => ProtractorPage(source: s, initialTab: 1),
      );
      await tester.pump();
      expect(find.text("60.0°"), findsOneWidget);
      final box = tester.getRect(find.byKey(const Key('screen_protractor')));
      final center = Offset(box.center.dx, box.bottom - 24);
      // 위(90°) 쪽을 누르면 가까운 팔(60°)이 90°로 → 사이 90.0°
      await tester.tapAt(center + const Offset(0, -150));
      await tester.pump();
      expect(find.text("90.0°"), findsOneWidget);
      await c.close();
    });
  });

  group('작은 폰·큰 글씨에서도 넘치지 않는다', () {
    Future<StreamController<TiltSample>> small(
      WidgetTester tester,
      Widget page,
    ) async {
      final c = StreamController<TiltSample>.broadcast();
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: page,
        ),
      );
      return c;
    }

    testWidgets('수평계: 눕힘·세움·옆으로, mm/m', (tester) async {
      final c = StreamController<TiltSample>.broadcast();
      await small(tester, LevelPage(source: () => c.stream));
      for (final v in [
        (x: 1.0, y: -1.0, z: g),
        (x: g * sinD(20), y: g * cosD(20), z: 0.0),
        (x: -g, y: 2.0, z: 0.0),
      ]) {
        await send(tester, c, v.x, v.y, v.z);
        await tester.tap(find.byKey(const Key('level_unit')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('level_unit')));
        await tester.pump(); // mm/m(가장 긴 글자)
        expect(tester.takeException(), isNull);
      }
      await c.close();
    });

    testWidgets('각도기: 두 탭', (tester) async {
      final c = StreamController<TiltSample>.broadcast();
      await small(tester, ProtractorPage(source: () => c.stream));
      await send(tester, c, 0, g, 0);
      await tester.tap(find.byKey(const Key('bend_reference')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('tab_screen')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await c.close();
    });
  });
}
