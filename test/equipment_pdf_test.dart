// 장비 관리 대장 PDF와 QR 라벨 PDF가 만들어지는지(PDF 머리 글자, 페이지 수, QR 그리기).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_model.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_pdf.dart';

final _now = DateTime(2026, 9, 30, 10);

Equipment _e(int i) => Equipment(
  id: 'id$i',
  name: '압력 게이지 $i',
  assetNo: 'PG-${i.toString().padLeft(3, '0')}',
  maker: '와이카',
  model: 'A-$i',
  intervalMonths: 12,
  lastDone: DateTime(2025, 10, 15),
  createdAt: _now,
);

int _pageCount(List<int> pdf) => RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(pdf)).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('관리 대장 PDF가 만들어진다(장비가 없어도)', () async {
    final some = await buildLedgerPdf([for (var i = 1; i <= 5; i++) _e(i)], _now);
    expect(String.fromCharCodes(some.take(4)), '%PDF');
    final none = await buildLedgerPdf(const [], _now);
    expect(String.fromCharCodes(none.take(4)), '%PDF');
  });

  test('관리 대장은 장비가 많으면 여러 쪽이 된다', () async {
    final few = await buildLedgerPdf([for (var i = 1; i <= 3; i++) _e(i)], _now);
    final many = await buildLedgerPdf([for (var i = 1; i <= 120; i++) _e(i)], _now);
    expect(_pageCount(many), greaterThan(_pageCount(few)));
  });

  test('QR 라벨 PDF: 한 쪽에 24장, 25장이면 두 쪽', () async {
    final one = await buildLabelsPdf([for (var i = 1; i <= 24; i++) _e(i)]);
    final two = await buildLabelsPdf([for (var i = 1; i <= 25; i++) _e(i)]);
    expect(String.fromCharCodes(one.take(4)), '%PDF');
    expect(_pageCount(one), 1);
    expect(_pageCount(two), 2);
    // 한글이 기본 글꼴(Courier, 한글 못 그림)로 나오면 안 된다(QR 아래 글자 그리기를 꺼 둔다).
    expect(latin1.decode(one).contains('Courier'), false);
  });

  test('라벨이 없어도 안내 한 쪽이 나온다', () async {
    final empty = await buildLabelsPdf(const []);
    expect(_pageCount(empty), 1);
  });

  testWidgets('화면 QR이 그려진다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: QrCodeView(data: 'FH-EQ:PG-001', size: 180))),
    );
    expect(find.byType(QrCodeView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
