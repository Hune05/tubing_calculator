// 튜브 입력 탭의 "길이 넣고 추가" 흐름: 숫자판의 "추가" 단추, 지금 못 꺾는 방향 흐리게,
// 입력 오류 알림과 경고 창이 공용 모양인지.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_components.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_field_data.dart'
    show conduitStartDir;
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_input_tab.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_input_tab.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';

/// 폰 크기(배율 1)로 맞춘다. setSurfaceSize는 물리 픽셀이라 배율 3에서는 화면이 찌그러진다.
void phone(WidgetTester tester, {double height = 900}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(420, height);
  addTearDown(tester.view.reset);
}

/// 숫자판의 숫자 키(같은 글자가 입력 결과에도 나오므로 단추로 찾는다).
Finder numKey(String d) => find.widgetWithText(TextButton, d);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    MobileBendDataManager().bendList.clear();
    MobileBendDataManager().clearHistory();
  });

  group('숫자판', () {
    bool? result;
    late TextEditingController controller;

    Future<void> open(
      WidgetTester tester, {
      String? addLabel,
      String initial = '',
    }) async {
      result = null;
      controller = TextEditingController(text: initial);
      phone(tester, height: 1000);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await MakitaNumpad.show(
                    context,
                    controller: controller,
                    title: '길이',
                    addLabel: addLabel,
                  );
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
    }

    testWidgets('추가 이름이 없으면 예전처럼 적용 단추 하나뿐이고 false를 돌려준다', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('numpad_add')), findsNothing);
      await tester.tap(numKey('5'));
      await tester.tap(find.text('적용'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(controller.text, '5');
    });

    testWidgets('값이 0이면 추가를 못 누르고, 넣으면 눌러서 true와 값을 돌려준다', (tester) async {
      await open(tester, addLabel: '추가');
      ElevatedButton add() =>
          tester.widget<ElevatedButton>(find.byKey(const Key('numpad_add')));
      expect(add().onPressed, isNull);
      await tester.tap(numKey('5'));
      await tester.tap(numKey('0'));
      await tester.tap(numKey('0'));
      await tester.pump();
      expect(add().onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('numpad_add')));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(controller.text, '500');
    });

    testWidgets('같은 창의 적용은 값만 남기고 false, 닫기(X)는 값을 되돌린다', (tester) async {
      await open(tester, addLabel: '추가', initial: '120');
      await tester.tap(numKey('7')); // 첫 키는 원래 값을 지우고 시작
      await tester.tap(find.byKey(const Key('numpad_apply')));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(controller.text, '7');

      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(numKey('9'));
      await tester.tap(find.byKey(const Key('numpad_close')));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(controller.text, '7'); // 열 때 값으로
    });

    testWidgets('수정이라는 이름도 쓸 수 있다', (tester) async {
      await open(tester, addLabel: '수정');
      expect(find.text('수정'), findsOneWidget);
    });
  });

  group('입력 탭', () {
    Future<void> pump(WidgetTester tester, {String startDir = 'RIGHT'}) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MobileInputTab(startDir: startDir)),
        ),
      );
      await tester.pumpAndSettle();
    }

    double opacityOf(WidgetTester tester, String rot) =>
        tester.widget<Opacity>(find.byKey(ValueKey('dir_$rot'))).opacity;

    Future<void> typeLength(WidgetTester tester, String digits) async {
      await tester.tap(find.byIcon(AppIcons.edit), warnIfMissed: false);
      await tester.pumpAndSettle();
      for (final d in digits.split('')) {
        await tester.tap(numKey(d));
      }
      await tester.pump();
    }

    testWidgets('처음에는 진행 방향(우)과 그 반대(좌)가 흐리고, 흐린 칸을 누르면 이유를 알려 준다', (
      tester,
    ) async {
      await pump(tester);
      expect(opacityOf(tester, '90.0'), 0.38); // RIGHT
      expect(opacityOf(tester, '270.0'), 0.38); // LEFT
      expect(opacityOf(tester, '0.0'), 1.0); // UP
      expect(opacityOf(tester, '360.0'), 1.0); // FRONT

      await tester.tap(find.byKey(const ValueKey('dir_90.0')));
      await tester.pump();
      expect(find.textContaining('쪽으로는 지금 꺾을 수 없습니다'), findsOneWidget);
      expect(find.textContaining('방향을 선택하십시오'), findsOneWidget); // 선택은 안 됐다

      await tester.tap(find.byKey(const ValueKey('dir_0.0')));
      await tester.pump();
      expect(find.textContaining('방향을 선택하십시오'), findsNothing);
    });

    testWidgets('시작 방향이 UP이면 처음에는 위·아래가 흐리고 좌·우가 살아 있다', (tester) async {
      await pump(tester, startDir: 'UP');
      expect(opacityOf(tester, '0.0'), 0.38); // UP
      expect(opacityOf(tester, '180.0'), 0.38); // DOWN
      expect(opacityOf(tester, '90.0'), 1.0); // RIGHT
      expect(opacityOf(tester, '270.0'), 1.0); // LEFT
    });

    testWidgets('위로 꺾은 뒤에는 위·아래가 흐리고 우가 살아난다', (tester) async {
      MobileBendDataManager().addBend({
        'length': 200.0,
        'angle': 90.0,
        'rotation': 0.0,
      });
      await pump(tester);
      expect(opacityOf(tester, '0.0'), 0.38); // UP
      expect(opacityOf(tester, '180.0'), 0.38); // DOWN
      expect(opacityOf(tester, '90.0'), 1.0); // RIGHT
    });

    testWidgets('방향을 고른 뒤 숫자판의 추가를 누르면 바로 목록에 들어간다', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('dir_0.0')));
      await tester.pump();
      await typeLength(tester, '500');
      await tester.tap(find.byKey(const Key('numpad_add')));
      await tester.pumpAndSettle();

      final list = MobileBendDataManager().bendList;
      expect(list.length, 1);
      expect(list.single['length'], 500.0);
      expect(list.single['angle'], 90.0);
      expect(list.single['rotation'], 0.0);
      // 넣은 뒤 방향은 비워진다(다음 줄은 다시 고른다).
      expect(find.textContaining('방향을 선택하십시오'), findsOneWidget);
    });

    testWidgets('골라 둔 방향이 목록이 바뀌어 못 꺾는 방향이 되면 선택을 푼다', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('dir_0.0'))); // UP 고름
      await tester.pump();
      expect(find.textContaining('방향을 선택하십시오'), findsNothing);

      // 위로 꺾는 줄이 들어오면(예: 다른 곳에서 불러오기·↶) 관이 위로 가므로 UP은 못 꺾는다.
      MobileBendDataManager().addBend({
        'length': 200.0,
        'angle': 90.0,
        'rotation': 0.0,
      });
      await tester.pumpAndSettle();
      expect(opacityOf(tester, '0.0'), 0.38);
      expect(find.textContaining('방향을 선택하십시오'), findsOneWidget);
    });

    testWidgets('방향을 안 골랐으면 숫자판에 추가가 없고 적용만 있다', (tester) async {
      await pump(tester);
      await typeLength(tester, '500');
      expect(find.byKey(const Key('numpad_add')), findsNothing);
      expect(find.text('적용'), findsOneWidget);
    });

    testWidgets('0° 직관은 방향 없이도 숫자판에서 바로 추가된다', (tester) async {
      await pump(tester);
      await tester.tap(find.text('0° 직관'));
      await tester.pumpAndSettle();
      await typeLength(tester, '300');
      await tester.tap(find.byKey(const Key('numpad_add')));
      await tester.pumpAndSettle();
      final list = MobileBendDataManager().bendList;
      expect(list.single['length'], 300.0);
      expect(list.single['angle'], 0.0);
    });

    testWidgets('길이를 안 넣고 추가하면 공용 오류 알림이 뜬다', (tester) async {
      await pump(tester);
      await tester.tap(find.text('0° 직관'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('추가'));
      await tester.pump();
      expect(find.text('정확한 길이를 입력해 주십시오.'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(kAppSnackSuccess, isNotNull); // 공용 알림 부품을 쓰는 화면
    });

    testWidgets('짧은 길이 경고는 공용 확인 창이고, 무시하고 추가하면 들어간다', (tester) async {
      MobileBendDataManager().addBend({
        'length': 300.0,
        'angle': 90.0,
        'rotation': 0.0,
      });
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('dir_90.0')));
      await tester.pump();
      await typeLength(tester, '1');
      await tester.tap(find.byKey(const Key('numpad_add')));
      await tester.pumpAndSettle();

      expect(find.text('벤딩 및 누설 경고'), findsOneWidget);
      expect(find.byType(AppConfirmDialog), findsOneWidget);
      expect(find.text('취소 (다시 입력)'), findsOneWidget);
      expect(find.text('무시하고 추가'), findsOneWidget);
      expect(find.text('❌ 기계 간섭 위험'), findsNothing); // 이모지 대신 그림
      expect(MobileBendDataManager().bendList.length, 1);

      await tester.tap(find.text('취소 (다시 입력)'));
      await tester.pumpAndSettle();
      expect(MobileBendDataManager().bendList.length, 1);

      await tester.tap(find.text('추가'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('무시하고 추가'));
      await tester.pumpAndSettle();
      expect(MobileBendDataManager().bendList.length, 2);
    });
  });

  group('전선관 입력 탭', () {
    late ConduitDataManager manager;

    Future<void> pump(WidgetTester tester) async {
      phone(tester);
      manager = ConduitDataManager.detached();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ConduitInputTab(manager: manager)),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> typeLength(WidgetTester tester, String digits) async {
      await tester.tap(find.byIcon(AppIcons.edit), warnIfMissed: false);
      await tester.pumpAndSettle();
      for (final d in digits.split('')) {
        await tester.tap(numKey(d));
      }
      await tester.pump();
    }

    testWidgets('0° 직관은 숫자판의 추가로 바로 들어간다', (tester) async {
      await pump(tester);
      await typeLength(tester, '300');
      await tester.tap(find.byKey(const Key('numpad_add')));
      await tester.pumpAndSettle();
      expect(manager.bendList.length, 1);
      expect(manager.bendList.single['length'], 300.0);
      expect(manager.bendList.single['angle'], 0.0);
    });

    testWidgets('90° 벤딩은 방향을 고르기 전에는 숫자판에 추가가 없다', (tester) async {
      await pump(tester);
      await tester.tap(find.text('90° 벤딩'));
      await tester.pumpAndSettle();
      await typeLength(tester, '200');
      expect(find.byKey(const Key('numpad_add')), findsNothing);
      expect(find.text('적용'), findsOneWidget);
      await tester.tap(find.text('적용'));
      await tester.pumpAndSettle();

      // 방향을 고르고 다시 열면 추가가 있고, 누르면 목록에 들어간다.
      await tester.tap(find.text('UP'));
      await tester.pump();
      await tester.tap(find.byIcon(AppIcons.edit), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(numKey('5'));
      await tester.tap(find.byKey(const Key('numpad_add')));
      await tester.pumpAndSettle();
      expect(manager.bendList.length, 1);
      expect(manager.bendList.single['length'], 5.0);
      expect(manager.bendList.single['angle'], 90.0);
      expect(manager.bendList.single['rotation'], 0.0);
    });

    double conduitOpacity(WidgetTester tester, String rot) =>
        tester.widget<Opacity>(find.byKey(ValueKey('dir_$rot'))).opacity;

    testWidgets('처음에는 우·좌가 흐리고 흐린 칸을 누르면 이유만 알려 준다(선택은 안 된다)', (tester) async {
      await pump(tester);
      await tester.tap(find.text('90° 벤딩'));
      await tester.pumpAndSettle();
      expect(conduitOpacity(tester, '90.0'), 0.38); // RIGHT
      expect(conduitOpacity(tester, '270.0'), 0.38); // LEFT
      expect(conduitOpacity(tester, '0.0'), 1.0); // UP

      await tester.tap(find.byKey(const ValueKey('dir_90.0')));
      await tester.pump();
      expect(find.textContaining('쪽으로는 지금 꺾을 수 없습니다'), findsOneWidget);
      expect(find.textContaining('방향을 선택하십시오'), findsOneWidget);
    });

    testWidgets('위로 꺾은 뒤에는 위·아래가 흐리고, 골라 둔 방향이 못 꺾게 되면 선택이 풀린다', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('90° 벤딩'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dir_0.0'))); // UP 고름
      await tester.pump();
      expect(find.textContaining('방향을 선택하십시오'), findsNothing);

      manager.addBend({'length': 200.0, 'angle': 90.0, 'rotation': 0.0});
      await tester.pumpAndSettle();
      expect(conduitOpacity(tester, '0.0'), 0.38); // UP
      expect(conduitOpacity(tester, '180.0'), 0.38); // DOWN
      expect(conduitOpacity(tester, '90.0'), 1.0); // RIGHT
      expect(find.textContaining('방향을 선택하십시오'), findsOneWidget); // 선택이 풀렸다
    });

    testWidgets('3D에서 고른 시작 방향(UP)을 따르고, 바꾸면 바로 다시 따진다', (tester) async {
      addTearDown(() => conduitStartDir.value = 'RIGHT');
      conduitStartDir.value = 'UP';
      await pump(tester);
      await tester.tap(find.text('90° 벤딩'));
      await tester.pumpAndSettle();
      expect(conduitOpacity(tester, '0.0'), 0.38); // UP
      expect(conduitOpacity(tester, '180.0'), 0.38); // DOWN
      expect(conduitOpacity(tester, '90.0'), 1.0); // RIGHT
      expect(conduitOpacity(tester, '270.0'), 1.0); // LEFT

      conduitStartDir.value = 'RIGHT';
      await tester.pumpAndSettle();
      expect(conduitOpacity(tester, '0.0'), 1.0);
      expect(conduitOpacity(tester, '90.0'), 0.38);
    });

    testWidgets('살아 있는 방향으로는 그대로 추가된다', (tester) async {
      await pump(tester);
      await tester.tap(find.text('90° 벤딩'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dir_0.0')));
      await tester.pump();
      await typeLength(tester, '250');
      await tester.tap(find.byKey(const Key('numpad_add')));
      await tester.pumpAndSettle();
      expect(manager.bendList.single['rotation'], 0.0);
      expect(manager.bendList.single['length'], 250.0);
    });

    testWidgets('각도가 상한(90°)을 넘으면 공용 오류 알림이 뜬다', (tester) async {
      await pump(tester);
      await tester.tap(find.text('직관+각도'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(AppIcons.edit).first, warnIfMissed: false);
      await tester.pumpAndSettle();
      for (final d in '200'.split('')) {
        await tester.tap(numKey(d));
      }
      await tester.tap(find.text('적용'));
      await tester.pumpAndSettle();
      expect(find.textContaining('까지 넣을 수 있습니다'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
