// 10-13 벤딩 실측 기록 고침: 견주는 값(다리 길이·자른 길이), 같은 각도끼리·장비 값이 같은 것끼리,
// 10-13 전 기록은 참고에서 뺌, 전선관 묶음 이름·장비 값.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/bend_check/bend_check_model.dart';
import 'package:tubing_calculator/src/presentation/bend_check/bend_check_page.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_field_data.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';

final _t = DateTime(2026, 10, 13, 9);

BendCheck _c(
  String id,
  double diff, {
  String g = 'A',
  String kind = kBendKindLeg,
  double? angle = 90,
  String setup = '',
  int version = kBendCheckVersion,
  int min = 0,
}) => BendCheck(
  id: id,
  at: _t.add(Duration(minutes: min)),
  group: g,
  calc: 500,
  actual: 500 + diff,
  kind: kind,
  angle: angle,
  setup: setup,
  version: version,
);

void main() {
  group('모델', () {
    test('판이 없는 옛 기록(10-13 전)은 참고에서 빠진다', () {
      final old = BendCheck.fromJson({
        'id': '1',
        'at': '2026-10-01T09:00:00',
        'group': 'A',
        'what': '90° 1번 마킹',
        'calc': 945,
        'actual': 966,
      })!;
      expect(old.version, 1);
      expect(old.counted, isFalse);
      expect(statsFor([old], 'A'), isNull);
      expect(statsFor([old, _c('2', 1)], 'A')!.n, 1);
    });

    test('새 칸(종류·각도·장비 값·판)이 저장했다 읽어도 남는다', () {
      final c = _c('1', 1.5, angle: 22.5, setup: '게인 40');
      final back = BendCheck.fromJson(c.toJson())!;
      expect(back.kind, kBendKindLeg);
      expect(back.angle, 22.5);
      expect(back.setup, '게인 40');
      expect(back.version, kBendCheckVersion);
      expect(back.kindKey, 'leg:22.5');
      expect(bendKindLabel(back.kindKey), '22.5° 다리');
      expect(
        bendKindLabel(_c('2', 0, kind: kBendKindCut, angle: null).kindKey),
        '자른 길이',
      );
    });

    test('같은 각도 다리끼리, 자른 길이는 따로 센다', () {
      final all = [
        _c('1', 2),
        _c('2', 4),
        _c('3', 30, angle: 45),
        _c('4', -1, kind: kBendKindCut, angle: null),
      ];
      expect(statsFor(all, 'A', kindKey: 'leg:90')!.mean, 3);
      expect(statsFor(all, 'A', kindKey: 'leg:45')!.n, 1);
      expect(statsFor(all, 'A', kindKey: 'cut')!.mean, -1);
    });

    test('장비 값을 주면 그 값으로 잰 기록만(장비 값이 안 적힌 손 기록은 센다)', () {
      final all = [
        _c('1', 10, setup: '게인 38', min: 0),
        _c('2', 1, setup: '게인 40', min: 1),
        _c('3', 3, setup: '게인 40', min: 2),
        _c('4', 2, min: 3), // 손으로 넣은 것
      ];
      final s = statsFor(all, 'A', kindKey: 'leg:90', setup: '게인 40')!;
      expect(s.n, 3);
      expect(s.mean, 2);
      expect(latestSetup(all, 'A', 'leg:90'), '게인 40');
      expect(latestSetup(all, 'A', 'cut'), isNull);
    });

    test('보내는 글: 종류마다 참고 한 줄, 옛 기록 표시', () {
      final t = buildBendCheckText([
        _c('1', 2, setup: '게인 40'),
        _c('2', 50, version: 1, kind: '', angle: null, min: -60),
      ]);
      expect(t, contains('90° 다리 (게인 40): 지난 실측 1건'));
      expect(t, contains('옛 기록(참고에서 뺌)'));
    });
  });

  group('다리 길이', () {
    late Map<String, dynamic> defaults;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      defaults = Map<String, dynamic>.from(globalBenderSettings.value);
    });
    tearDown(() => globalBenderSettings.value = defaults);

    test('전선관: 앞 꺾이는 점(처음은 관 끝)부터 입력 길이 합, 직관 줄도 더한다', () {
      ConduitDataManager().bendList
        ..clear()
        ..addAll([
          {'length': 965.0, 'angle': 90.0, 'rotation': 0.0},
          {'length': 568.0, 'angle': 0.0, 'rotation': 0.0},
          {'length': 79.9, 'angle': 45.0, 'rotation': 450.0},
          {'length': 141.4, 'angle': 45.0, 'rotation': 360.0},
          {'length': 356.0, 'angle': 0.0, 'rotation': 0.0},
        ]);
      final legs = [for (final m in computeConduitFieldData().bends) m.leg];
      expect(legs[0], 965.0);
      expect(legs[1], closeTo(568.0 + 79.9, 1e-9));
      expect(legs[2], closeTo(141.4, 1e-9));
    });

    test('전선관 장비 값: 유압은 게인만, 수동·시카고는 테이크업·게인·CLR', () {
      expect(
        conduitMeasureSetup({'benderType': 'ram', 'gain': 40.0, 'clr': 93.0}),
        '게인 40',
      );
      expect(
        conduitMeasureSetup({
          'benderType': 'hand',
          'takeUp': 152.4,
          'gain': 81.2,
          'clr': 114.3,
        }),
        '테이크업 152.4 · 게인 81.2 · CLR 114.3',
      );
    });

    test('튜브: 피팅 깊이를 더한 관 길이로, 장비 값은 반경·게인', () {
      MachineSpecs().resetForTest();
      MachineSpecs().update(
        radius: 38.1,
        gain90: 12.0,
        springback: 2.0,
        fittingDepth: 20.0,
        benderOffset: 0.0,
        cutMargin: 0.0,
        tail: 0.0,
        startFit: true,
        endFit: false,
      );
      MobileBendDataManager().bendList
        ..clear()
        ..addAll([
          {'length': 150.0, 'angle': 0.0, 'rotation': 0.0},
          {'length': bendSetback(38.1, 90), 'angle': 90.0, 'rotation': 0.0},
          {'length': 300.0, 'angle': 90.0, 'rotation': 90.0},
          {'length': 200.0, 'angle': 0.0, 'rotation': 0.0},
        ]);
      final legs = [for (final m in computeTubeFieldData().bends) m.leg];
      // 첫 줄(직관 150)에 시작 피팅 깊이 20이 붙는다.
      expect(legs[0], closeTo(150 + 20 + bendSetback(38.1, 90), 1e-9));
      expect(legs[1], 300.0);
      expect(tubeMeasureSetup(), '반경 38.1 · 게인 12');
    });
  });

  group('기록 화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var tick = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BendCheckPage(
            share: (t) async {},
            now: () => _t.add(Duration(seconds: tick++)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('자른 길이로 고르면 그 종류로 저장하고 참고도 그 종류만', (tester) async {
      await addBendCheck(_c('leg', 9, g: 'A'));
      await open(tester);
      await tester.tap(find.byKey(const Key('bendcheck_kind_cut')));
      await tester.pump();
      expect(find.byKey(const Key('bendcheck_angle')), findsNothing);
      // 다리 기록(+9)은 자른 길이 참고에 안 들어간다.
      expect(find.byKey(const Key('bendcheck_reference')), findsNothing);
      await tester.enterText(find.byKey(const Key('bendcheck_calc')), '1762');
      await tester.enterText(find.byKey(const Key('bendcheck_actual')), '1760');
      await tester.tap(find.byKey(const Key('bendcheck_save')));
      await tester.pumpAndSettle();
      final saved = (await loadBendChecks()).firstWhere((c) => c.id != 'leg');
      expect(saved.kind, kBendKindCut);
      expect(saved.angle, isNull);
      expect(find.textContaining('자른 길이 · 지난 실측 1건'), findsOneWidget);
    });

    testWidgets('옛 기록은 목록에 "옛 기록 · 참고에서 뺌"으로 남고 참고에는 안 든다', (tester) async {
      await addBendCheck(_c('old', 21, version: 1, kind: '', angle: null));
      await open(tester);
      expect(find.textContaining('옛 기록 · 참고에서 뺌'), findsOneWidget);
      expect(find.byKey(const Key('bendcheck_reference')), findsNothing);
    });
  });
}
