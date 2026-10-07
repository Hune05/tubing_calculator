// 앱 틀이 상태 표시줄을 비켜 가는지(점검 35번). PC 홈(옛 태블릿 격자 메뉴)은 10-08에 지움.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_frame.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
