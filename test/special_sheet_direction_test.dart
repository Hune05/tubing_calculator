// 특수 벤딩 시트(오프셋·굴림 오프셋·새들)의 방향 칸: 지금 진행 방향과 같거나 정반대인 축은 흐리게,
// 누르면 이유만 알리고 선택은 안 된다. 입력 탭이 시작 방향과 지금까지의 줄로 규칙을 넘겨 준다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_input_tab.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_rolling_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_saddle_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/sheet_direction_gate.dart';

/// 진행 방향이 오른쪽일 때의 규칙(우·좌는 못 꺾는다).
bool _rightTravel(double rot) => rot != 90.0 && rot != 270.0;

void phone(WidgetTester tester, {double height = 1400}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(420, height);
  addTearDown(tester.view.reset);
}

/// 방향을 아직 안 골랐다는 표시("*필수" 또는 "방향을 선택…") 개수.
int needMarks() =>
    find.textContaining('*필수').evaluate().length +
    find.textContaining('방향을 선택').evaluate().length;

double opacityOf(WidgetTester tester, String rot) =>
    tester.widget<Opacity>(find.byKey(ValueKey('sheet_dir_$rot'))).opacity;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    MobileBendDataManager().bendList.clear();
    MobileBendDataManager().clearHistory();
  });

  final sheets = <String, Widget Function(BendRule? rule)>{
    '오프셋': (rule) => MobileOffsetBottomSheet(
      currentRotation: 90,
      onAddMultipleBends: (_) {},
      canBendTo: rule,
    ),
    '굴림 오프셋': (rule) => MobileRollingOffsetBottomSheet(
      currentRotation: 90,
      onAddBend: (a, b, c) {},
      canBendTo: rule,
    ),
    '새들': (rule) => MobileSaddleBottomSheet(
      currentRotation: 90,
      onAddBend: (a, b, c) {},
      canBendTo: rule,
    ),
  };

  for (final e in sheets.entries) {
    group('${e.key} 시트', () {
      Future<void> open(WidgetTester tester, BendRule? rule) async {
        phone(tester, height: 2200);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: e.value(rule))),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('sheet_dir_0.0')));
        await tester.pumpAndSettle();
      }

      testWidgets('못 꺾는 방향은 흐리고, 누르면 이유 창만 뜨며 선택되지 않는다', (tester) async {
        await open(tester, _rightTravel);
        expect(opacityOf(tester, '90.0'), 0.38); // RIGHT
        expect(opacityOf(tester, '270.0'), 0.38); // LEFT
        expect(opacityOf(tester, '0.0'), 1.0); // UP
        expect(opacityOf(tester, '180.0'), 1.0); // DOWN
        expect(opacityOf(tester, '360.0'), 1.0); // FRONT

        final marksBefore = needMarks();
        expect(marksBefore, greaterThan(0));
        await tester.tap(find.byKey(const ValueKey('sheet_dir_90.0')));
        await tester.pumpAndSettle();
        expect(find.text('그 방향으로는 못 꺾습니다'), findsOneWidget);
        expect(find.textContaining("'RIGHT' 쪽이나 그 반대쪽으로"), findsOneWidget);
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();
        // 선택은 안 돼서 필수 표시가 그대로다.
        expect(needMarks(), marksBefore);
      });

      testWidgets('살아 있는 방향은 눌러서 고를 수 있다', (tester) async {
        await open(tester, _rightTravel);
        final before = needMarks();
        await tester.tap(find.byKey(const ValueKey('sheet_dir_0.0')));
        await tester.pumpAndSettle();
        expect(find.text('그 방향으로는 못 꺾습니다'), findsNothing);
        final after = needMarks();
        expect(after, lessThan(before)); // 필수 표시가 사라졌다
      });

      testWidgets('규칙을 안 주면(전선관 등) 예전처럼 모두 고를 수 있다', (tester) async {
        await open(tester, null);
        for (final r in ['0.0', '90.0', '180.0', '270.0', '360.0', '450.0']) {
          expect(opacityOf(tester, r), 1.0);
        }
      });
    });
  }

  group('입력 탭에서 열 때', () {
    Future<void> openSheet(
      WidgetTester tester,
      String menuText, {
      required String startDir,
    }) async {
      phone(tester, height: 1600);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MobileInputTab(startDir: startDir)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('특수 벤딩 툴 (오프셋/새들 등)'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(menuText));
      await tester.pumpAndSettle();
      await tester.tap(find.text(menuText));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('sheet_dir_0.0')));
      await tester.pumpAndSettle();
    }

    for (final menu in [
      '일반 오프셋 (Offset)',
      '롤링 오프셋 (Rolling Offset)',
      '새들 벤딩 (Saddle)',
    ]) {
      testWidgets('$menu: 시작 방향 UP이면 위·아래가 흐리다', (tester) async {
        await openSheet(tester, menu, startDir: 'UP');
        expect(opacityOf(tester, '0.0'), 0.38);
        expect(opacityOf(tester, '180.0'), 0.38);
        expect(opacityOf(tester, '90.0'), 1.0);
        expect(opacityOf(tester, '270.0'), 1.0);
      });
    }

    testWidgets('이미 위로 꺾은 줄이 있으면 시작 방향이 우여도 위·아래가 흐리다', (tester) async {
      MobileBendDataManager().addBend({
        'length': 200.0,
        'angle': 90.0,
        'rotation': 0.0,
      });
      await openSheet(tester, '일반 오프셋 (Offset)', startDir: 'RIGHT');
      expect(opacityOf(tester, '0.0'), 0.38);
      expect(opacityOf(tester, '180.0'), 0.38);
      expect(opacityOf(tester, '90.0'), 1.0);
    });
  });
}
