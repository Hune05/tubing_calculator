// 현장 탭(가로 줄자 화면) 검사. 튜브·전선관이 같이 쓰는 화면.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_field_data.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking_screen.dart';

FieldMarkingData sample() => const FieldMarkingData(
  totalCut: 616,
  marks: [
    FieldMark(number: 0, position: 150, angle: 0, rotation: 0),
    FieldMark(
      number: 1,
      position: 163,
      angle: 21,
      targetAngle: 24,
      rotation: 0,
      gap: 163,
    ),
    FieldMark(
      number: 2,
      position: 357,
      angle: 21,
      targetAngle: 24,
      rotation: 180,
      gap: 194,
    ),
    FieldMark(number: 0, position: 616, angle: 0, rotation: 0),
  ],
);

Future<List<String>> pumpScreen(
  WidgetTester tester,
  FieldMarkingData data, {
  Size size = const Size(882, 344),
  bool isActive = false,
}) async {
  final errors = <String>[];
  final old = FlutterError.onError;
  FlutterError.onError = (d) => errors.add(d.exceptionAsString());
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      home: FieldMarkingScreen(
        listenable: ValueNotifier(0),
        compute: () => data,
        isActive: isActive,
      ),
    ),
  );
  await tester.pumpAndSettle();
  FlutterError.onError = old;
  return errors;
}

void main() {
  group('자료 셈', () {
    test('말풍선이 가까우면 두 줄로 나눈다', () {
      // 150과 163은 26px 떨어져 있어 한 줄에 못 놓는다(폭 108).
      final lanes = assignLabelLanes([300, 326, 714, 1232], width: 108);
      expect(lanes[0], isNot(lanes[1]));
      expect(lanes[2], 0);
      expect(lanes[3], 0);
    });

    test('입력 순서가 뒤섞여도 같은 줄의 말풍선은 겹치지 않는다', () {
      final xs = [500.0, 100.0, 180.0, 520.0, 260.0];
      final lanes = assignLabelLanes(xs, width: 100, lanes: 3);
      for (var i = 0; i < xs.length; i++) {
        for (var j = i + 1; j < xs.length; j++) {
          if (lanes[i] == lanes[j]) {
            expect((xs[i] - xs[j]).abs(), greaterThanOrEqualTo(100));
          }
        }
      }
    });

    test('한 단계씩: 벤드만 입력 순서대로, 마지막은 자르기', () {
      final steps = fieldSteps(sample());
      expect(steps.length, 3);
      expect(steps[0].mark!.number, 1);
      expect(steps[1].mark!.number, 2);
      expect(steps[2].isCut, isTrue);
      expect(steps[2].at, 616);
    });

    test('방향 이름', () {
      expect(fieldDirectionLabel(0), 'UP (위)');
      expect(fieldDirectionLabel(180), 'DOWN (아래)');
      expect(fieldDirectionLabel(360), 'FRONT (앞)');
      expect(fieldDirectionLabel(450), 'BACK (뒤)');
    });

    test('스프링백이 있으면 더 꺾을 각도를 알린다', () {
      final m = sample().bends.first;
      expect(m.hasOverBend, isTrue);
      expect(
        const FieldMark(
          number: 1,
          position: 0,
          angle: 90,
          rotation: 0,
        ).hasOverBend,
        isFalse,
      );
    });
  });

  group('전선관 자료', () {
    late Map<String, dynamic> defaults;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      defaults = Map<String, dynamic>.from(globalBenderSettings.value);
      conduitUseCoupling.value = false;
      ConduitDataManager().bendList
        ..clear()
        ..addAll([
          {'length': 150.0, 'angle': 0.0, 'rotation': 0.0},
          {'length': 72.3, 'angle': 21.0, 'rotation': 0.0},
          {'length': 195.3, 'angle': 21.0, 'rotation': 180.0},
          {'length': 200.0, 'angle': 0.0, 'rotation': 0.0},
        ]);
    });
    tearDown(() => globalBenderSettings.value = defaults);

    test('마킹 탭과 같은 자리·같은 절단 길이', () {
      final s = globalBenderSettings.value;
      final markings = calculateConduitMarkings(
        ConduitDataManager().bendList,
        s,
      );
      final data = computeConduitFieldData();
      expect(data.marks.length, 4);
      for (var i = 0; i < 4; i++) {
        expect(data.marks[i].position, closeTo(markings[i]['mark'], 1e-9));
      }
      expect(
        data.totalCut,
        closeTo(conduitTotalCut(ConduitDataManager().bendList, s), 1e-9),
      );
      // 벤드에만 번호, 직관 끝은 0.
      expect(data.marks.map((m) => m.number).toList(), [0, 1, 2, 0]);
      expect(
        data.bends[1].gap,
        closeTo(data.marks[2].position - data.marks[1].position, 1e-9),
      );
    });

    test('커플링 체결은 현장 탭에도 들어간다', () {
      final before = computeConduitFieldData().bends.first.position;
      conduitUseCoupling.value = true;
      final after = computeConduitFieldData().bends.first.position;
      final depth = (globalBenderSettings.value['couplingDepth'] as num)
          .toDouble();
      expect(before - after, closeTo(depth, 1e-9));
    });
  });

  group('화면', () {
    testWidgets('폰 가로(882×344)에서 넘치지 않고 자르기·직관 끝·꺾을 각도가 보인다', (tester) async {
      final errors = await pumpScreen(tester, sample());
      expect(errors, isEmpty);
      // 줄자 숫자는 그림으로 그려서 글자 위젯으로는 못 찾는다(폰 화면으로 확인).
      expect(find.text('✂ 자르기'), findsOneWidget);
      expect(find.text('직관 끝'), findsWidgets);
      expect(find.text('21°→24° · UP'), findsOneWidget);
    });

    testWidgets('한 단계씩: 누르기·볼륨 단추로 넘기고 끝낸 단계는 ✓', (tester) async {
      await pumpScreen(tester, sample());
      await tester.tap(find.byKey(const Key('field_mode_toggle')));
      await tester.pumpAndSettle();

      String number() =>
          tester.widget<Text>(find.byKey(const Key('field_step_number'))).data!;
      expect(number(), '163');
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('24°까지 꺾기(스프링백)'), findsOneWidget);

      // 화면 오른쪽을 누르면 다음.
      final area = find.byKey(const Key('field_step_area'));
      final box = tester.getRect(area);
      await tester.tapAt(Offset(box.right - 20, box.center.dy));
      await tester.pumpAndSettle();
      expect(number(), '357');
      expect(find.text('2 / 3'), findsOneWidget);

      // 볼륨 올림 = 다음(자르기).
      await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeUp);
      await tester.pumpAndSettle();
      expect(number(), '616');
      expect(find.text('여기서 자릅니다'), findsOneWidget);

      // 볼륨 내림 = 이전.
      await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeDown);
      await tester.pumpAndSettle();
      expect(number(), '357');

      // 왼쪽을 누르면 이전. 1번은 이미 끝낸 단계라 ✓.
      await tester.tapAt(Offset(box.left + 20, box.center.dy));
      await tester.pumpAndSettle();
      expect(number(), '163');
      expect(find.byIcon(Icons.check), findsWidgets);
    });

    testWidgets('경고가 있으면 위에 "확인"이 뜨고 누르면 내용이 나온다', (tester) async {
      final data = FieldMarkingData(
        totalCut: 616,
        marks: sample().marks,
        warnings: const ['3번 구간: 곧은 부분이 -10mm입니다. 이대로는 만들 수 없습니다.'],
      );
      await pumpScreen(tester, data);
      await tester.tap(find.byKey(const Key('field_warning_chip')));
      await tester.pumpAndSettle();
      expect(find.textContaining('3번 구간'), findsOneWidget);
    });

    testWidgets('긴 관(6m)·짧은 화면에서도 넘치지 않는다', (tester) async {
      final long = FieldMarkingData(
        totalCut: 6000,
        marks: [
          for (var i = 0; i < 12; i++)
            FieldMark(
              number: i + 1,
              position: 400.0 + i * 450,
              angle: 45,
              rotation: i.isEven ? 0 : 180,
            ),
        ],
      );
      final errors = await pumpScreen(tester, long, size: const Size(700, 300));
      expect(errors, isEmpty);
    });

    testWidgets('볼륨 단추: 한 단계씩 화면에서만 가로채고, 본체가 넘긴 올림에 다음으로', (tester) async {
      const channel = MethodChannel('field/volume_keys');
      final captures = <bool>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'setCapture') captures.add(call.arguments as bool);
        return null;
      });
      await pumpScreen(tester, sample(), isActive: true);
      expect(captures, isEmpty); // 전체 보기에서는 안 가로챈다.

      await tester.tap(find.byKey(const Key('field_mode_toggle')));
      await tester.pumpAndSettle();
      expect(captures.last, isTrue);

      // 본체가 "올림"을 넘겨준 것처럼.
      Future<void> press(String dir) async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'field/volume_keys',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('volume', dir),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();
      }

      await press('up');
      expect(
        tester.widget<Text>(find.byKey(const Key('field_step_number'))).data,
        '357',
      );
      await press('down');
      expect(
        tester.widget<Text>(find.byKey(const Key('field_step_number'))).data,
        '163',
      );

      await tester.tap(find.byKey(const Key('field_mode_toggle')));
      await tester.pumpAndSettle();
      expect(captures.last, isFalse); // 전체 보기로 돌아가면 음량 조절로.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });

    testWidgets('빈 목록이면 안내가 나온다', (tester) async {
      final errors = await pumpScreen(tester, FieldMarkingData.empty);
      expect(errors, isEmpty);
      expect(find.text('입력한 배관이 없습니다'), findsOneWidget);
    });
  });
}
