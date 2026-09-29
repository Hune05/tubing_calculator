// 튜브 아이소(3D 뷰어) 탭: 전선관 아이소 화면과 같은 모양(어두운 전체 화면,
// 흰 머리 없음)으로 맞췄다(2026-09-21 메모에 남아 있던 것 — 2026-09-29 처리).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';

const _kIsoDark = Color(0xFF151B22);

void main() {
  tearDown(() => MobileBendDataManager().bendList.clear());

  testWidgets('전선관 아이소와 같은 어두운 전체 화면이고, 옛 흰 머리 글은 없다', (tester) async {
    MobileBendDataManager().bendList
      ..clear()
      ..addAll([
        {'length': 150.0, 'angle': 90.0, 'rotation': 0.0},
      ]);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MobileViewerTab(startDir: 'RIGHT'))),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(MobileViewerTab),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.backgroundColor, _kIsoDark);
    expect(find.text('ISO 3D 도면 뷰어 (드래그하여 회전)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('치수가 없으면 어두운 배경에 안내 글이 뜬다', (tester) async {
    MobileBendDataManager().bendList.clear();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MobileViewerTab(startDir: 'RIGHT'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('입력된 치수가 없습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
