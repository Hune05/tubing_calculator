// 튜브 벤딩 → 라인 컷팅 작업에 넣기(10-09 고도화 1번).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/bend_to_cutting.dart';

void main() {
  test('한 본에서 나오는 조각 수로 본수를 센다', () {
    expect(bentPieceBars(1762, 1, 6000), 1);
    expect(bentPieceBars(1762, 3, 6000), 1); // 한 본에서 3개
    expect(bentPieceBars(1762, 4, 6000), 2);
    expect(bentPieceBars(3500, 3, 6000), 3); // 한 본에 하나씩(길이 합으로 나누면 2본이 틀림)
    expect(bentPieceBars(6500, 1, 6000), 0); // 한 본보다 길다
  });

  test('컷팅 기록 한 줄: 자를 길이·개수·규격', () {
    final r = bendCutRecord(
      projectId: 'p',
      cut: 1762,
      count: 2,
      tubeSize: '1/2"',
    );
    expect(r.cutLength, 1762);
    expect(r.multiplier, 2);
    expect(r.tubeSize, '1/2"');
    expect(r.usedWithKerf, 3524);
    expect(r.startFitting, '벤딩 마킹');
  });

  testWidgets('창에서 개수를 정하고 작업을 고르면 그 작업에 넣는다', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    (CuttingJobChoice, int, bool)? sent;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSendToCuttingSheet(
                context,
                cut: 1762,
                tubeSize: '1/2"',
                loadJobs: () async => const [
                  CuttingJobChoice('j1', {
                    'name': '루마 2층',
                    'totalTubeUsed': 12000,
                  }),
                ],
                send: (j, c, k) async => sent = (j, c, k),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('튜브 1/2" · 자를 길이 1762mm'), findsOneWidget);
    await tester.tap(find.byKey(const Key('b2c_plus')));
    await tester.pump();
    expect(find.text('2개'), findsOneWidget);
    await tester.tap(find.byKey(const Key('b2c_job_j1')));
    await tester.pumpAndSettle();
    expect(sent!.$1.id, 'j1');
    expect(sent!.$2, 2);
    expect(sent!.$3, isTrue);
    expect(find.textContaining("'루마 2층' 작업에 1762mm × 2개"), findsOneWidget);
  });

  testWidgets('작업이 없으면 만들라고 알린다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSendToCuttingSheet(
                context,
                cut: 900,
                tubeSize: '',
                loadJobs: () async => const [],
                send: (j, c, k) async {},
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('b2c_empty')), findsOneWidget);
  });
}
