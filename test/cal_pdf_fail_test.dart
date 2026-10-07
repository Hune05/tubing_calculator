// 교정 성적서 만들기가 실패하면 알리고 다시 누를 수 있다(10-08).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_record.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_record_pdf.dart';

void main() {
  testWidgets('실패하면 안내가 뜨고, 다시 부르면 또 만든다', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }))));
    final r = CalRecord(id: 'x', date: DateTime(2026, 10, 8), tag: 'PT-1', lrv: 0, urv: 10, found: const [CalEntry(reading: 4)]);
    var calls = 0;
    Future<Uint8List> fail(CalRecord _) async {
      calls++;
      throw StateError('글꼴 없음');
    }

    await openCalRecordPdf(ctx, r, build: fail);
    await tester.pump();
    expect(find.text('성적서를 만들지 못했습니다. 다시 해 보십시오.'), findsOneWidget);
    await openCalRecordPdf(ctx, r, build: fail);
    expect(calls, 2);
  });
}
