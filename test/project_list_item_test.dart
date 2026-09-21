import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/project/project_list_item.dart';

Map<String, dynamic> _project({
  Object? progress = 0.5,
  List<Map<String, dynamic>> materials = const [],
  String revision = 'Rev.0',
}) => {
  'id': '1',
  'name': 'TEST 프로젝트',
  'date': '2026.09.22',
  'revision': revision,
  'progress': progress,
  'isDeducted': false,
  'materials': materials,
  'daily_reports': [],
  'punch_lists': [],
};

Future<void> _pump(
  WidgetTester tester,
  Map<String, dynamic> project, {
  double width = 800,
  bool expanded = true,
}) async {
  tester.view.physicalSize = Size(width * 3, 2400 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ProjectListItem(
            project: project,
            isExpanded: expanded,
            onToggleExpand: () {},
            onUpdateRevision: () {},
            onDeleteProject: () {},
            onUpdateProgress: () {},
            onAddDailyReport: () {},
            onEditDailyReport: (_) {},
            onDeleteDailyReport: (_) {},
            onAddPunch: () {},
            onDeductInventory: () {},
            onStateUpdate: () {},
            onViewDailyReportDetail: (_) {},
            onViewPunchDetail: (_) {},
            onOpenCutting: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('진행률이 정수(1)로 저장돼 있어도 카드가 그려진다', (tester) async {
    await _pump(tester, _project(progress: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('100%'), findsWidgets);
  });

  testWidgets('튜브 자재에 길이(qty_mm)가 없어도 카드가 그려진다', (tester) async {
    await _pump(
      tester,
      _project(
        materials: [
          {'type': 'TUBE', 'name': '튜브 1/2'},
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('튜브 1/2'), findsOneWidget);
    expect(find.text('0 본'), findsOneWidget);
  });
}
