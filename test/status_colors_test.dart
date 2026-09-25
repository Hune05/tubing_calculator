// 색의 뜻(UI 디자인 제안 D-B): 빨강은 경보·지우기에만, 평소 행동은 청록.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/theme/status_colors.dart';
import 'package:tubing_calculator/src/presentation/field_tools/level_painters.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/punch_list_page.dart';

Color? _bg(WidgetTester tester, Finder text) {
  final box = tester.widget<Container>(
    find.ancestor(of: text, matching: find.byType(Container)).first,
  );
  return (box.decoration as BoxDecoration?)?.color;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('수평계도 앱의 주 색(청록)', () {
    expect(kLevelBlue, kBrand);
  });

  testWidgets('이슈 등록: 등록 단추는 청록, 우선순위는 긴급만 빨강', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: PunchListPage()));
    await tester.pumpAndSettle();

    final submit = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('이슈 등록하기'),
        matching: find.byType(ElevatedButton),
      ),
    );
    // 예전: 빨강(새로 만드는 평소 행동인데 경보 색).
    expect(submit.style?.backgroundColor?.resolve({}), kBrand);

    // 기본 "보통"이 골라져 있다: 청록(예전: 주황).
    expect(_bg(tester, find.text('보통')), kBrand);
    await tester.tap(find.text('긴급'));
    await tester.pump();
    expect(_bg(tester, find.text('긴급')), kDanger);
    await tester.tap(find.text('여유'));
    await tester.pump();
    expect(_bg(tester, find.text('여유')), kIdle);
  });
}
