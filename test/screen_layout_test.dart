// 화면 구성(2026-09-27): 자동·폰 화면·태블릿 화면, 큰 화면에서 폰 화면 폭 제한, 고르기 단추가 폰에 기억되는지.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/common_widgets/screen_layout_picker.dart';
import 'package:tubing_calculator/src/core/utils/screen_layout.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ScreenLayout.mode.value = ScreenLayoutMode.auto;
  });
  tearDown(() => ScreenLayout.mode.value = ScreenLayoutMode.auto);

  test('자동: 짧은 변 600dp 이상이면 태블릿(폴더블 안쪽 화면이 쓰던 기준 그대로)', () {
    expect(ScreenLayout.isTabletSize(const Size(599, 1200)), isFalse);
    expect(ScreenLayout.isTabletSize(const Size(600, 960)), isTrue);
    expect(ScreenLayout.isTabletSize(const Size(360, 800)), isFalse);
    // 가로로 든 폰(짧은 변 360)은 태블릿이 아니다.
    expect(ScreenLayout.isTabletSize(const Size(800, 360)), isFalse);
  });

  test('폰 화면은 어느 크기든 태블릿이 아니고, 태블릿 화면은 폰 크기도 태블릿', () {
    ScreenLayout.mode.value = ScreenLayoutMode.phone;
    expect(ScreenLayout.isTabletSize(const Size(900, 1400)), isFalse);
    ScreenLayout.mode.value = ScreenLayoutMode.tablet;
    expect(ScreenLayout.isTabletSize(const Size(360, 800)), isTrue);
  });

  Future<void> pumpHost(WidgetTester tester, Size size, {Key? probeKey}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ScreenLayoutHost(
          child: LayoutBuilder(
            builder: (context, c) => Text(
              'w=${c.maxWidth.toInt()} mq=${MediaQuery.of(context).size.width.toInt()} '
              'tablet=${ScreenLayout.isTablet(context)}',
              key: const Key('probe'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String probe(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('probe'))).data!;

  testWidgets('폰 화면 + 큰 화면(800×1280): 내용 폭 600으로 좁히고 화면 폭도 600으로 알려 준다', (
    tester,
  ) async {
    ScreenLayout.mode.value = ScreenLayoutMode.phone;
    await pumpHost(tester, const Size(800, 1280));
    expect(probe(tester), 'w=600 mq=600 tablet=false');
    final r = tester.getRect(find.byKey(const Key('probe')));
    expect(r.left, greaterThanOrEqualTo(100)); // 가운데에 모임
  });

  testWidgets('폰 화면이어도 진짜 폰(390 폭)과 가로로 든 폰(800×360)은 좁히지 않는다', (tester) async {
    ScreenLayout.mode.value = ScreenLayoutMode.phone;
    await pumpHost(tester, const Size(390, 844));
    expect(probe(tester), 'w=390 mq=390 tablet=false');
    await pumpHost(tester, const Size(800, 360));
    expect(probe(tester), 'w=800 mq=800 tablet=false');
  });

  testWidgets('자동·태블릿 화면은 좁히지 않는다', (tester) async {
    await pumpHost(tester, const Size(800, 1280));
    expect(probe(tester), 'w=800 mq=800 tablet=true');
    ScreenLayout.mode.value = ScreenLayoutMode.tablet;
    await pumpHost(tester, const Size(800, 1280));
    expect(probe(tester), 'w=800 mq=800 tablet=true');
  });

  testWidgets('화면 구성을 바꾸면 화면이 바로 다시 그려진다', (tester) async {
    await pumpHost(tester, const Size(800, 1280));
    expect(probe(tester), contains('tablet=true'));
    ScreenLayout.mode.value = ScreenLayoutMode.phone;
    await tester.pumpAndSettle();
    expect(probe(tester), 'w=600 mq=600 tablet=false');
  });

  testWidgets('고르기: 폰 화면을 누르면 바뀌고 폰에 기억되고, 다시 읽으면 그대로', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ScreenLayoutPicker())),
    );
    expect(find.text('자동'), findsOneWidget);
    expect(find.text('폰 화면'), findsOneWidget);
    expect(find.text('태블릿 화면'), findsOneWidget);
    await tester.tap(find.byKey(const Key('screen_layout_phone')));
    await tester.pumpAndSettle();
    expect(ScreenLayout.mode.value, ScreenLayoutMode.phone);
    expect(find.text(ScreenLayoutMode.phone.description), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ScreenLayout.prefKey), 'phone');
    ScreenLayout.mode.value = ScreenLayoutMode.auto;
    await ScreenLayout.load();
    expect(ScreenLayout.mode.value, ScreenLayoutMode.phone);
  });
}
