// 현장 자료 화면: 전선관 탭에 추가한 홀쏘 최소 지름·유볼트 고르는 법·탭 드릴·
// 볼트 렌치 사이즈·부속 이름 정리(사용자 요청 2026-09-25 — 전선관·후렉시블 작업 참고용).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/reference/page/tube_reference_page.dart';

Widget app(Widget home) => MaterialApp(home: home);

Future<void> _openConduitTab(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app(const TubeReferencePage()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('전선관'));
  await tester.pumpAndSettle();
}

// 카드가 많아 뷰포트를 늘려도 다 안 보인다 - 목표 글자가 보일 때까지 내려서 찾는다.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.dragUntilVisible(
    target,
    find.byType(ListView).first,
    const Offset(0, -300),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('전선관 탭에 홀쏘 최소 지름 표가 있고, 규격별 값이 바깥지름+3mm다', (
    tester,
  ) async {
    await _openConduitTab(tester);
    final title = find.textContaining('관통 구멍(홀쏘) 최소 지름');
    await _scrollTo(tester, title);
    expect(title, findsOneWidget);
    // 16C 바깥지름 21.0mm → 최소 홀쏘 24mm.
    expect(find.text('24'), findsWidgets);
    // 54C 바깥지름 59.6mm → 최소 홀쏘 62.6mm.
    expect(find.text('62.6'), findsWidgets);
  });

  testWidgets('유볼트 카드는 정확한 로드 규격 없이 고르는 법만 안내한다', (tester) async {
    await _openConduitTab(tester);
    final title = find.textContaining('유볼트(U밴드) 고르는 법');
    await _scrollTo(tester, title);
    expect(title, findsOneWidget);
    expect(find.textContaining('카탈로그마다 달라'), findsOneWidget);
  });

  testWidgets('탭 드릴 표에 M8·M10 지름이 있다', (tester) async {
    await _openConduitTab(tester);
    final title = find.textContaining('탭 사이즈별 홀가공 지름');
    await _scrollTo(tester, title);
    expect(title, findsOneWidget);
    expect(find.text('M8'), findsWidgets);
    expect(find.text('6.8'), findsOneWidget);
    expect(find.text('M10'), findsWidgets);
    expect(find.text('8.5'), findsOneWidget);
  });

  testWidgets('볼트 렌치 사이즈 표에 M8·M12 값이 있다', (tester) async {
    await _openConduitTab(tester);
    final title = find.textContaining('볼트 머리·렌치(스패너) 사이즈');
    await _scrollTo(tester, title);
    expect(title, findsOneWidget);
    expect(find.text('M8'), findsWidgets);
    expect(find.text('13'), findsOneWidget);
    expect(find.text('M12'), findsWidgets);
    expect(find.text('19'), findsOneWidget);
  });

  testWidgets('부속 이름 정리 카드에 로크너트·부싱·니플이 있다', (tester) async {
    await _openConduitTab(tester);
    final title = find.textContaining('전선관·후렉시블 부속 이름 정리');
    await _scrollTo(tester, title);
    expect(title, findsOneWidget);
    expect(find.text('로크너트(Lock Nut)'), findsOneWidget);
    expect(find.textContaining('부싱'), findsWidgets);
    expect(find.textContaining('니플'), findsWidgets);
  });

  testWidgets('검색으로 "홀커터"를 찾으면 전선관 탭으로 간다', (tester) async {
    tester.view.physicalSize = const Size(390, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const TubeReferencePage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '홀커터');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('관통 구멍(홀쏘) 최소 지름'));
    await tester.pumpAndSettle();

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 1);
  });
}
