// PC 홈에도 폰 홈의 전선관·현장 자료·프로필이 있고, 앱 틀이 상태 표시줄을 비켜 가는지(점검 35번).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_frame.dart';
import 'package:tubing_calculator/src/presentation/menu/page/menu_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in const [Size(1280, 800), Size(800, 1280)]) {
    testWidgets('PC 홈($size)에 전선관·현장 자료·프로필 칸이 있고 넘치지 않는다', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: MenuScreen()));
      await tester.pumpAndSettle();
      // 예전: PC 홈에 없어서 PC에서는 이름을 넣을 곳이 없었다.
      for (final t in ['전선관 벤딩', '현장 자료', '프로필']) {
        final f = find.text(t);
        await tester.scrollUntilVisible(
          f,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(f, findsOneWidget, reason: t);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('앱 틀: 상태 표시줄 자리만큼 화면을 내려 겹치지 않는다', (tester) async {
    tester.view.padding = const FakeViewPadding(top: 72, bottom: 48);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AppFrame(child: child!),
        home: const Scaffold(body: Text('맨 위', key: Key('top'))),
      ),
    );
    final dpr = tester.view.devicePixelRatio;
    expect(tester.getTopLeft(find.byKey(const Key('top'))).dy, 72 / dpr);
  });
}
