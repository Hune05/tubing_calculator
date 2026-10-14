// 10-15 자재 수량·입고 검수: 주문 수량과 들어온 수량을 견줘 부족을 알리고, 일정 화면에서 입고 완료를
// 누르면 검수 화면이 열려 수량·메모를 적는다. 일정을 고쳐도 검수 기록은 남는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/material_receipt.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/project_schedule_page.dart';

Map<String, dynamic> _mat({num? qty, String unit = 'm', bool done = false}) => {
  'id': 'm1',
  'type': '자재 요청',
  'title': '케이블 F-CV 2.5sq',
  'dateTime': null,
  'isCompleted': done,
  'qty': ?qty,
  'unit': unit,
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('수량 글과 부족 셈', () {
    final m = _mat(qty: 20);
    expect(materialQtyLabel(m), '주문 20m');
    applyMaterialReceipt(
      m,
      receivedQty: 18,
      note: '1롤 찍힘',
      at: DateTime(2026, 10, 15),
    );
    expect(m['isCompleted'], isTrue);
    expect(materialShortage(m), 2);
    expect(materialQtyLabel(m), '주문 20m · 입고 18m · 2m 부족');
    final log = <String, dynamic>{
      'name': '시험',
      'schedules': [m],
    };
    expect(shortMaterials(log).single['id'], 'm1');
    final doc = buildReportDoc(
      log,
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 31),
    );
    final text = doc.sections.expand((s) => s.lines).join('\n');
    expect(text, contains('입고 18m · 2m 부족'));
    undoMaterialReceipt(m);
    expect(m['isCompleted'], isFalse);
    expect(materialShortage(m), isNull);
    expect(m['receiveNote'], '1롤 찍힘', reason: '되돌려도 메모는 남는다');
    // 다 들어오면 부족이 아니다.
    applyMaterialReceipt(m, receivedQty: 20);
    expect(materialShortage(m), isNull);
  });

  testWidgets('일정 화면: 자재 완료를 누르면 검수 화면, 덜 들어오면 부족 표시', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    List<Map<String, dynamic>>? out;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () async {
                out = await Navigator.push<List<Map<String, dynamic>>>(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => ProjectSchedulePage(
                      projectName: '시험',
                      initialSchedules: [_mat(qty: 20)],
                    ),
                  ),
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
    expect(find.textContaining('주문 20m'), findsOneWidget);

    // 완료(왼쪽 동그라미)를 누르면 검수 화면.
    await tester.tap(find.byIcon(Icons.local_shipping_outlined));
    await tester.pumpAndSettle();
    expect(find.text('입고·검수'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('receive_qty')))
          .controller!
          .text,
      '20',
    );
    await tester.enterText(find.byKey(const Key('receive_qty')), '17');
    await tester.pump();
    expect(find.byKey(const Key('receive_short')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('receive_note')), '3m 모자람');
    await tester.tap(find.byKey(const Key('receive_save')));
    await tester.pumpAndSettle();
    // 완료한 일정은 기본으로 숨겨 둔다 → 보이게.
    await tester.tap(find.text('완료 숨김'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3m 부족'), findsOneWidget);

    // 일정을 고쳐도 검수 기록은 남는다.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('schedule_qty')))
          .controller!
          .text,
      '20',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3m 부족'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    final m = out!.single;
    expect(m['receivedQty'], 17);
    expect(m['receiveNote'], '3m 모자람');
    expect(m['isCompleted'], isTrue);
  });
}
