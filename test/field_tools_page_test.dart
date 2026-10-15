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

/// 설정(오른쪽 아래 톱니) → 단위 고르기 → 닫기.
Future<void> pickUnit(WidgetTester tester, String unitName) async {
  await tester.tap(find.byKey(const Key('level_settings')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('unit_$unitName')));
  await tester.pumpAndSettle();
  await tester.tapAt(const Offset(10, 10)); // 시트 밖을 눌러 닫기
  await tester.pumpAndSettle();
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
      expect(find.text("수평입니다"), findsNothing);
      await c.close();
    });

    testWidgets('단위를 바꾸면 %로, 영점을 맞추면 0으로', (tester) async {
      final c = await pumpPage(tester, (s) => LevelPage(source: s));
      final deg = math.atan(0.02) * 180 / math.pi; // 2% 구배
      await send(tester, c, g * sinD(deg), g * cosD(deg), 0);
      await pickUnit(tester, 'percent');
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

    testWidgets('길게 누르면 지금 자세 영점만 지우고 되돌릴 수 있다', (tester) async {
      SharedPreferences.setMockInitialValues({
        kLevelCalibKey: '{"flat_x":0.5,"flat_y":0.5,"upright_x":0.3}',
      });
      final c = await pumpPage(tester, (s) => LevelPage(source: s));
      await send(tester, c, g * sinD(3), g * cosD(3), 0); // 세움
      await tester.longPress(find.byKey(const Key('level_calibrate')));
      await tester.pump();
      final p = await SharedPreferences.getInstance();
      final saved = p.getString(kLevelCalibKey)!;
      expect(saved, isNot(contains('upright_x')));
      expect(saved, contains('flat_x')); // 눕힘 영점은 그대로
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const Key('level_calib_undo')));
      await tester.pump();
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

    testWidgets('모양 고정이면 폰을 눕혀도 기포관 그대로', (tester) async {
      final c = await pumpPage(tester, (s) => LevelPage(source: s));
      await send(tester, c, g * sinD(3), g * cosD(3), 0); // 세움
      await tester.tap(find.byKey(const Key('level_pose_lock')));
      await tester.pump();
      for (int i = 0; i < 40; i++) {
        await send(tester, c, 0, 0, g); // 눕힘
      }
      expect(find.byKey(const Key('level_tube')), findsOneWidget);
      expect(find.byKey(const Key('level_bullseye')), findsNothing);
      await c.close();
    });

    testWidgets('설정: 소수점 끄기·소리 끄기가 폰에 남는다', (tester) async {
      final c = await pumpPage(tester, (s) => LevelPage(source: s));
      await send(tester, c, g * sinD(3), g * cosD(3), 0);
      await tester.tap(find.byKey(const Key('level_settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('set_decimals')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('set_sound')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text("3°"), findsOneWidget);
      final p = await SharedPreferences.getInstance();
      expect(p.getBool(kLevelDecimalsKey), isFalse);
      expect(p.getBool(kLevelSoundKey), isFalse);
      await c.close();
    });

    testWidgets('자 길이 맞추기: 밀어서 맞추면 폰에 남는다', (tester) async {
      final c = await pumpPage(tester, (s) => LevelPage(source: s));
      await send(tester, c, 0, g, 0);
      expect(find.byKey(const Key('level_ruler')), findsOneWidget);
      await tester.tap(find.byKey(const Key('level_settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('set_ruler')));
      await tester.pumpAndSettle();
      final before = tester.getSize(find.byKey(const Key('ruler_card'))).width;
      await tester.drag(
        find.byKey(const Key('ruler_slider')),
        const Offset(60, 0),
      );
      await tester.pumpAndSettle();
      final after = tester.getSize(find.byKey(const Key('ruler_card'))).width;
      expect(after, greaterThan(before));
      await tester.tap(find.byKey(const Key('ruler_ok')));
      await tester.pumpAndSettle();
      final p = await SharedPreferences.getInstance();
      expect(p.getDouble(kRulerDpPerMmKey), closeTo(after / 54, 0.01));
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
    // 말풍선(_pill)은 열쇠가 바깥 상자에 붙어 있어 안의 글을 찾는다.
    String textOf(WidgetTester tester, String key) {
      final f = find.byKey(Key(key));
      final w = tester.widget(f);
      if (w is Text) return w.data!;
      return tester.widget<Text>(find.descendant(of: f, matching: find.byType(Text))).data!;
    }

    /// 설정 시트를 열어 [key] 스위치·칩을 누르고 닫는다.
    Future<void> setting(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(const Key('protractor_settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }

    testWidgets('기준을 잡고 45° 돌리면 굽힌 각 45°, 사이각 135°(기본은 정수)', (tester) async {
      final c = await pumpPage(tester, (s) => ProtractorPage(source: s));
      await send(tester, c, 0, g, 0); // 세워서 첫 다리
      await tester.tap(find.byKey(const Key('bend_reference')));
      await tester.pump();
      for (int i = 0; i < 60; i++) {
        await send(tester, c, g * sinD(45), g * cosD(45), 0); // 둘째 다리
      }
      expect(textOf(tester, 'bend_value'), "45°");
      expect(find.text("두 다리 사이 각 135°"), findsOneWidget);

      // 30° 더 돌리면 굽힌 각 75°, 폰 옆면 기울기는 15°(값이 따로 논다).
      for (int i = 0; i < 60; i++) {
        await send(tester, c, g * sinD(75), g * cosD(75), 0);
      }
      expect(textOf(tester, 'bend_value'), "75°");
      expect(textOf(tester, 'bend_tilt'), "15°");

      // 설정에서 "소수점 보기"를 켜면 소수 한 자리, 폰에 남는다.
      await setting(tester, 'protractor_decimals');
      expect(textOf(tester, 'bend_value'), "75.0°");
      final p = await SharedPreferences.getInstance();
      expect(p.getBool(kProtractorDecimalsKey), isTrue);
      await c.close();
    });

    testWidgets('소수점을 켜 둔 적이 있으면 소수 한 자리로 연다', (tester) async {
      SharedPreferences.setMockInitialValues({kProtractorDecimalsKey: true});
      final c = await pumpPage(tester, (s) => ProtractorPage(source: s));
      await tester.pump();
      for (int i = 0; i < 30; i++) {
        await send(tester, c, g * sinD(10), g * cosD(10), 0);
      }
      expect(textOf(tester, 'bend_tilt'), "10.0°");
      await c.close();
    });

    testWidgets('첫 안내: 관을 세워 굽힌 면이 위아래가 되게', (tester) async {
      final c = await pumpPage(tester, (s) => ProtractorPage(source: s));
      await send(tester, c, 0, g, 0);
      expect(textOf(tester, 'bend_guide'), contains("관을 세워"));
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

    testWidgets('앞뒤로 15° 기울면 주의, 25° 기울면 기준을 못 잡는다(10-15)', (tester) async {
      final c = await pumpPage(tester, (s) => ProtractorPage(source: s));
      ButtonStyleButton btn() => tester.widget<ButtonStyleButton>(
        find.byKey(const Key('bend_reference')),
      );
      for (int i = 0; i < 40; i++) {
        await send(tester, c, 0, g * cosD(15), g * sinD(15));
      }
      expect(find.byKey(const Key('bend_lean_warn')), findsOneWidget);
      expect(find.text("폰 기울기 15° · 똑바로 세우면 더 정확합니다"), findsOneWidget);
      expect(btn().onPressed, isNotNull);
      for (int i = 0; i < 40; i++) {
        await send(tester, c, 0, g * cosD(25), g * sinD(25));
      }
      expect(find.byKey(const Key('bend_too_flat')), findsOneWidget);
      expect(find.byKey(const Key('bend_lean_warn')), findsNothing);
      expect(btn().onPressed, isNull);
      await c.close();
    });

    testWidgets('기준은 누르는 순간 흔들림이 아니라 누르기 직전 가만히 있던 값(10-15)', (tester) async {
      int t = 0;
      final c = await pumpPage(
        tester,
        (s) => ProtractorPage(source: s, clockMs: () => t),
      );
      for (; t <= 1000; t += 50) {
        await send(tester, c, 0, g, 0); // 곧은 다리에 대고 가만히(돌림 0°)
      }
      for (int i = 0; i < 3; i++) {
        t += 50;
        await send(tester, c, g * sinD(12), g * cosD(12), 0); // 누르며 흔들림
      }
      await tester.tap(find.byKey(const Key('bend_reference')));
      await tester.pump();
      for (int i = 0; i < 60; i++) {
        t += 50;
        await send(tester, c, g * sinD(45), g * cosD(45), 0);
      }
      expect(textOf(tester, 'bend_value'), "45°");
      await c.close();
    });

    testWidgets('자동 고정: 굽힌 다리에서 1초 가만히 있으면 고정, 움직여도 값 그대로', (tester) async {
      SharedPreferences.setMockInitialValues({kProtractorAutoHoldKey: true});
      int t = 0;
      final c = await pumpPage(
        tester,
        (s) => ProtractorPage(source: s, clockMs: () => t),
      );
      await tester.pump();
      await send(tester, c, 0, g, 0);
      await tester.tap(find.byKey(const Key('bend_reference')));
      await tester.pump();
      for (int i = 0; i < 50; i++) {
        t += 50;
        await send(tester, c, g * sinD(45), g * cosD(45), 0);
      }
      expect(find.text("자동 고정됨"), findsOneWidget);
      expect(textOf(tester, 'bend_value'), "45°");
      for (int i = 0; i < 30; i++) {
        t += 50;
        await send(tester, c, g * sinD(80), g * cosD(80), 0);
      }
      expect(textOf(tester, 'bend_value'), "45°");
      // 풀면 다시 잰다
      await tester.tap(find.byKey(const Key('bend_hold')));
      await tester.pump();
      for (int i = 0; i < 5; i++) {
        t += 50;
        await send(tester, c, g * sinD(80), g * cosD(80), 0);
      }
      expect(find.text("자동 고정됨"), findsNothing);
      expect(textOf(tester, 'bend_value'), "80°");
      await c.close();
    });

    testWidgets('목표 각도: 남은 각을 보이고 맞으면 "맞음"', (tester) async {
      final c = await pumpPage(tester, (s) => ProtractorPage(source: s));
      await setting(tester, 'target_45');
      final p = await SharedPreferences.getInstance();
      expect(p.getDouble(kProtractorTargetKey), 45);
      for (int i = 0; i < 3; i++) {
        await send(tester, c, 0, g, 0);
      }
      await tester.tap(find.byKey(const Key('bend_reference')));
      await tester.pump();
      for (int i = 0; i < 60; i++) {
        await send(tester, c, g * sinD(40), g * cosD(40), 0);
      }
      expect(textOf(tester, 'bend_target'), "목표 45° · 5° 더");
      for (int i = 0; i < 60; i++) {
        await send(tester, c, g * sinD(45.2), g * cosD(45.2), 0);
      }
      expect(textOf(tester, 'bend_target'), "목표 45° 맞음");
      for (int i = 0; i < 60; i++) {
        await send(tester, c, g * sinD(48), g * cosD(48), 0);
      }
      expect(textOf(tester, 'bend_target'), "목표 45° · 3° 넘음");
      await c.close();
    });

    group('화면 각도기', () {
      Future<({StreamController<TiltSample> c, Offset center})> open(
        WidgetTester tester,
      ) async {
        final c = await pumpPage(
          tester,
          (s) => ProtractorPage(source: s, initialTab: 1),
        );
        await tester.pump();
        final box = tester.getRect(find.byKey(const Key('screen_protractor')));
        return (c: c, center: Offset(box.center.dx, box.bottom - 24));
      }

      Offset polar(Offset center, double deg, double r) => center +
          Offset(math.cos(deg * math.pi / 180) * r, -math.sin(deg * math.pi / 180) * r);

      Future<void> drag(WidgetTester tester, Offset from, List<Offset> path) async {
        final gst = await tester.startGesture(from);
        for (final p in path) {
          await gst.moveTo(p);
          await tester.pump();
        }
        await gst.up();
        await tester.pump();
      }

      testWidgets('처음 두 팔 사이 60°, 팔을 끌면 바뀐다', (tester) async {
        final o = await open(tester);
        expect(textOf(tester, 'screen_value'), "60°");
        await drag(tester, polar(o.center, 60, 140), [
          polar(o.center, 70, 140),
          polar(o.center, 90, 140),
        ]);
        expect(textOf(tester, 'screen_value'), "90°");
        await o.c.close();
      });

      testWidgets('팔이 아닌 곳을 누르거나 끌면 팔이 움직이지 않는다', (tester) async {
        final o = await open(tester);
        await tester.tapAt(polar(o.center, 120, 140));
        await tester.pump();
        await drag(tester, polar(o.center, 150, 140), [
          polar(o.center, 140, 140),
          polar(o.center, 120, 140),
        ]);
        expect(textOf(tester, 'screen_value'), "60°");
        await o.c.close();
      });

      testWidgets('끄는 팔이 다른 팔을 넘어가도 잡은 팔만 움직인다', (tester) async {
        final o = await open(tester);
        // 0° 팔을 잡아 60° 팔을 넘어 100°까지
        await drag(tester, polar(o.center, 2, 140), [
          for (double a = 10; a <= 100; a += 10) polar(o.center, a, 140),
        ]);
        expect(textOf(tester, 'screen_value'), "40°"); // 100 - 60
        expect(textOf(tester, 'arm_chip_0'), "100°");
        expect(textOf(tester, 'arm_chip_1'), "60°");
        await o.c.close();
      });

      testWidgets('미세 조정: 고른 팔을 1°씩, 소수점을 켜면 0.1°씩', (tester) async {
        final o = await open(tester);
        await tester.tap(find.byKey(const Key('arm_plus')));
        await tester.pump();
        expect(textOf(tester, 'screen_value'), "61°");
        await tester.tap(find.byKey(const Key('arm_chip_0'))); // 0° 팔로
        await tester.pump();
        await tester.tap(find.byKey(const Key('arm_minus'))); // 0°에서는 더 못 줄인다
        await tester.pump();
        expect(textOf(tester, 'screen_value'), "61°");
        await setting(tester, 'protractor_decimals');
        await tester.tap(find.byKey(const Key('arm_plus')));
        await tester.pump();
        expect(textOf(tester, 'screen_value'), "60.9°");
        await o.c.close();
      });
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
        await pickUnit(tester, 'mmPerM'); // 가장 긴 글자
        expect(tester.takeException(), isNull);
      }
      await c.close();
    });

    testWidgets('U2 수평계: 큰 숫자가 왼쪽 자 밑에 깔리지 않는다', (tester) async {
      for (final w in [320.0, 360.0]) {
        final c = StreamController<TiltSample>.broadcast();
        await tester.binding.setSurfaceSize(Size(w, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(home: LevelPage(source: () => c.stream)),
        );
        await send(tester, c, g * sinD(-12.3), g * cosD(12.3), 0); // 세움
        final ruler = tester.getRect(find.byKey(const Key('level_ruler')));
        final value = tester.getRect(find.byKey(const Key('level_value')));
        expect(value.left, greaterThanOrEqualTo(ruler.right), reason: '$w');
        expect(value.right, lessThanOrEqualTo(w), reason: '$w');
        await c.close();
      }
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
