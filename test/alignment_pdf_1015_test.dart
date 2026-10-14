// 10-15 축 정렬 기록 PDF: 만들어지고(빈 기록·다 찬 기록), 파일 이름, 지난 기록 창에 PDF 단추.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/record_sync.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_math.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_page.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_pdf.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_record.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_session.dart';

final _at = DateTime(2026, 10, 15, 1, 40);

AlignRecord _rec({bool full = true}) => AlignRecord(
  id: '1',
  at: _at,
  machine: full ? '1호기 급수펌프' : '',
  method: AlignMethod.reverse,
  stage: AlignStage.after,
  rpm: 1800,
  note: full ? '배관 풀고 측정' : '',
  inputs: full
      ? {
          'between': '200', 'coupB': '100', 'front': '150', 'rear': '450',
          'a90': '-0.10', 'a180': '-0.20', 'a270': '-0.10',
          'b90': '0.05', 'b180': '0.10', 'b270': '0.05',
          'sagA': '-0.02', 'targetY': '0.1',
          'sf_frontLeft': '0.08', 'sf_rearRight': '0.02',
          'tolO': '0.05', 'tolA': '0.05',
        }
      : const {},
  offset: 0.075,
  angle100: 0.025,
  shimFront: -0.14,
  shimRear: -0.21,
  moveFront: 0,
  moveRear: 0.1,
  verdict: AlignVerdict.offsetOut,
  rounds: full
      ? [
          AlignRound(
            at: _at,
            offset: 0.3,
            angle100: 0.1,
            verdict: AlignVerdict.bothOut,
            shimFront: -0.14,
            shimRear: -0.21,
            moveFront: 0,
            moveRear: 0,
            done: {for (final f in AlignFoot.values) f: -0.1},
          ),
        ]
      : const [],
  footStart: full ? {for (final f in AlignFoot.values) f: 1.0} : const {},
  footEnd: full ? {for (final f in AlignFoot.values) f: 0.9} : const {},
);

void main() {
  test('기록 PDF가 만들어진다(빈 기록도), 파일 이름', () async {
    for (final r in [_rec(), _rec(full: false)]) {
      final bytes = await buildAlignPdf(r);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    }
    expect(alignPdfFileName(_rec()), 'align_1호기_급수펌프_20261015_0140.pdf');
    expect(alignPdfFileName(_rec(full: false)), 'align_machine_20261015_0140.pdf');
  });

  testWidgets('지난 기록 창에 PDF 단추', (tester) async {
    SharedPreferences.setMockInitialValues({});
    recordRemote = () => null;
    await AlignStore.put(_rec());
    await tester.pumpWidget(MaterialApp(home: AlignmentHistoryPage(share: (_) async {})));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('align_record_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('align_history_pdf')), findsOneWidget);
    expect(find.textContaining('소프트 풋(mm): 앞발 왼쪽 0.08'), findsOneWidget);
  });
}
