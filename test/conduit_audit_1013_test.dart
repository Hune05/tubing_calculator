// 10-13 전선관 점검 고침: 롤링 각도(마킹 카드·보관함·줄 고치기), 옛 도면 치수 기준 비교,
// 설정 "저장하지 않은 값"(노치당 각도·단위·줄자 정밀도)·뒤로 가기 묻기, 줄자 정밀도 칸(유압·시카고).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/conduit_drawings.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_field_data.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_result_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_diff.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';

void main() {
  late Map<String, dynamic> defaults;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    defaults = Map<String, dynamic>.from(globalBenderSettings.value);
  });
  tearDown(() {
    globalBenderSettings.value = defaults;
    ConduitDataManager().bendList.clear();
  });

  group('롤링 각도', () {
    test('보관함 줄은 굴림 각도(rollHint)를 남기고, 없으면 칸을 만들지 않는다', () {
      expect(
        conduitDrawingBendRow({
          'length': 300,
          'angle': 45,
          'rotation': 90,
          'rollHint': 53.1,
        }),
        {'length': 300.0, 'angle': 45.0, 'rotation': 90.0, 'rollHint': 53.1},
      );
      expect(
        conduitDrawingBendRow({
          'length': 300,
          'angle': 45,
          'rotation': 90,
        }).containsKey('rollHint'),
        isFalse,
      );
    });

    test('저장했다 읽어도 굴림 각도가 남는다', () async {
      final d = await saveConduitDrawing(
        folderName: '작업',
        title: '롤링',
        totalCut: 1000,
        bends: [
          {'length': 300.0, 'angle': 45.0, 'rotation': 90.0, 'rollHint': 53.1},
          {'length': 250.0, 'angle': 45.0, 'rotation': 90.0},
        ],
      );
      final back = (await loadConduitDrawings()).firstWhere(
        (e) => e.id == d.id,
      );
      expect(back.bends.first['rollHint'], 53.1);
      expect(back.bends.last.containsKey('rollHint'), isFalse);
      // JSON으로 한 번 더 오가도 그대로
      final again = ConduitDrawing.fromJson(
        jsonDecode(jsonEncode(back.toJson())),
      );
      expect(again!.bends.first['rollHint'], 53.1);
    });

    test('0.5° 이하 굴림은 안내하지 않는다', () {
      expect(conduitRollHint({'rollHint': 0.3}), isNull);
      expect(conduitRollHint({'rollHint': 53.1}), 53.1);
      expect(conduitRollHint({}), isNull);
    });

    testWidgets('마킹 탭 카드에 "N° 굴려 잡으십시오"가 보인다(튜브 카드와 같은 글)', (tester) async {
      ConduitDataManager().bendList
        ..clear()
        ..addAll([
          {'length': 300.0, 'angle': 45.0, 'rotation': 90.0, 'rollHint': 53.1},
          {'length': 250.0, 'angle': 45.0, 'rotation': 90.0},
        ]);
      await tester.binding.setSurfaceSize(const Size(420, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ConduitResultTab())),
      );
      await tester.pumpAndSettle();
      expect(find.text('꺾기 전에 관을 53° 굴려 잡으십시오'), findsOneWidget);
    });

    testWidgets('스프링백이 꺼져 각이 같으면 "(실제 N°)"를 붙이지 않는다', (tester) async {
      globalBenderSettings.value = {...defaults, 'applySpringback': false};
      ConduitDataManager().bendList
        ..clear()
        ..addAll([
          {'length': 300.0, 'angle': 90.0, 'rotation': 0.0},
        ]);
      await tester.binding.setSurfaceSize(const Size(420, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ConduitResultTab())),
      );
      await tester.pumpAndSettle();
      expect(find.text('90° 벤딩'), findsOneWidget);
      expect(find.textContaining('(실제'), findsNothing);
    });
  });

  group('옛 도면 치수 기준', () {
    test('치수 기준이 없고 테이크업·게인이 있는 옛 도면은 관 등으로 보고 비교한다', () {
      final saved = {'takeUp': 152.4, 'gain': 82.5, 'clr': 114.3};
      final now = {
        'takeUp': 152.4,
        'gain': 82.5,
        'clr': 114.3,
        'measureRef': 'center',
      };
      expect(
        conduitSettingDiffs(saved, now),
        contains('치수 기준: 저장 때 관 등 → 지금 관 중심'),
      );
      expect(conduitSettingChanges(saved, now), {'measureRef': 'back'});
    });

    test('테이크업·게인도 없는 도면은 기준만 바꾸면 값이 섞이므로 비교하지 않는다', () {
      expect(
        conduitSettingDiffs(
          {'benderType': 'hand'},
          {'benderType': 'hand', 'measureRef': 'center'},
        ),
        isEmpty,
      );
    });

    test('지금도 관 등이면 차이 없음', () {
      expect(
        conduitSettingDiffs(
          {'takeUp': 152.4},
          {'takeUp': 152.4, 'measureRef': 'back'},
        ),
        isEmpty,
      );
    });
  });

  group('설정', () {
    Future<void> pumpSettings(
      WidgetTester tester, {
      bool active = false,
    }) async {
      await tester.binding.setSurfaceSize(const Size(420, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open'),
                  onPressed: () => Navigator.push(
                    c,
                    MaterialPageRoute<void>(
                      builder: (_) => ConduitSettingsPage(isActive: active),
                    ),
                  ),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
    }

    testWidgets('시카고: 노치당 각도를 바꾸면 "저장하지 않은 값" 표시', (tester) async {
      globalBenderSettings.value = {
        ...defaults,
        'benderType': 'chicago',
        'degPerNotch': 2.5,
      };
      await pumpSettings(tester);
      expect(find.byKey(const Key('conduit_settings_unsaved')), findsNothing);
      final slider = find.byType(Slider);
      await tester.ensureVisible(slider.first);
      await tester.drag(slider.first, const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('conduit_settings_unsaved')), findsOneWidget);
    });

    testWidgets('유압·시카고도 인치(분수)면 줄자 정밀도 칸이 있다', (tester) async {
      for (final type in ['ram', 'chicago']) {
        globalBenderSettings.value = {
          ...defaults,
          'benderType': type,
          'unitSystem': '인치 (분수)',
          'fractionPrecision': '1/16"',
        };
        await pumpSettings(tester);
        expect(
          find.text('1/16"', skipOffstage: false),
          findsOneWidget,
          reason: type,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('설정 탭에서 저장하지 않고 뒤로 가면 묻고, "계속 고치기"면 남는다', (tester) async {
      globalBenderSettings.value = {
        ...defaults,
        'benderType': 'ram',
        'gain': 40.0,
      };
      await pumpSettings(tester, active: true);
      final gain = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '40.0',
      );
      tester.widget<TextField>(gain.first).controller!.text = '45';
      await tester.pump();
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      await nav.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('저장하지 않은 설정'), findsOneWidget);
      await tester.tap(find.text('계속 고치기'));
      await tester.pumpAndSettle();
      expect(find.byType(ConduitSettingsPage), findsOneWidget);
      // 저장하고 나가기
      await nav.maybePop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('conduit_settings_leave_save')));
      await tester.pumpAndSettle();
      expect(find.byType(ConduitSettingsPage), findsNothing);
      expect(globalBenderSettings.value['gain'], 45.0);
    });

    testWidgets('바꾼 것이 없으면 묻지 않고 나간다', (tester) async {
      await pumpSettings(tester, active: true);
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();
      expect(find.text('저장하지 않은 설정'), findsNothing);
      expect(find.byType(ConduitSettingsPage), findsNothing);
    });
  });
}
