import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_bend.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_bend_page.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_bend_pdf.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/steel_pdf_preview_page.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 9000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: BusbarBendPage()));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('부스바 절곡 지시서 PDF가 만들어진다(Z 옵셋)', () async {
    final z = busbarZ(d: 5, r: 5, k: 0.4, a: 50, c: 50, h: 40, deg: 45);
    final bytes = await buildBendPdf(
      BendPdfInput(
        title: '시험',
        plan: z.plan,
        thickness: 5,
        rho: 7,
        summary: const [('재료', '구리 평강 5 × 50 mm')],
        notes: const ['시험 주의'],
      ),
    );
    expect(bytes.length, greaterThan(2000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('파일 이름', () {
    expect(
      bendFileName('1호기 모선', DateTime(2026, 10, 3)),
      'busbar_bend_1호기_모선_20261003.pdf',
    );
    expect(
      bendFileName('', DateTime(2026, 10, 3)),
      'busbar_bend_noname_20261003.pdf',
    );
  });

  testWidgets('PDF 단추는 미리보기를 연다', (tester) async {
    final old = pdfPreviewBuilder;
    addTearDown(() => pdfPreviewBuilder = old);
    pdfPreviewBuilder = (Uint8List bytes, String name) =>
        Text('미리보기 $name ${bytes.length > 1000}');
    await _open(tester);
    await _type(tester, 'bb_job', '시험');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('bb_pdf')));
      for (
        var i = 0;
        i < 80 && find.textContaining('미리보기 busbar_bend_').evaluate().isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('미리보기 busbar_bend_시험_'), findsOneWidget);
    expect(find.text('부스바 절곡 지시서 미리보기'), findsOneWidget);
    expect(find.byKey(const Key('pdf_preview_share')), findsOneWidget);
  });

  testWidgets('저장한 규격: 저장 → 값을 고침 → 불러오기 → 지우기', (tester) async {
    await _open(tester);
    await _type(tester, 'bb_t', '8');
    await _type(tester, 'bb_w', '60');
    await tester.tap(find.byKey(const Key('bb_k_z')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bb_saved')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ss_saved_empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ss_save_now')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ss_save_name')), '8×60 시험');
    await tester.tap(find.byKey(const Key('ss_save_ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ss_saved_8×60 시험')), findsOneWidget);
    expect(find.textContaining('8×60 · Z 꺾기 · 눕혀'), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(const Key('ss_saved_8×60 시험'))),
    ).pop();
    await tester.pumpAndSettle();
    await _type(tester, 'bb_t', '5');
    await _type(tester, 'bb_w', '40');
    await tester.tap(find.byKey(const Key('bb_k_l')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bb_saved')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ss_saved_8×60 시험')));
    await tester.pumpAndSettle();
    String text(String k) =>
        tester.widget<TextField>(find.byKey(Key(k))).controller!.text;
    expect(text('bb_t'), '8');
    expect(text('bb_w'), '60');
    expect(find.byKey(const Key('bb_ih')), findsOneWidget); // Z 칸이 다시 나타남
    expect(find.textContaining('불러왔습니다'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bb_saved')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ss_saved_del_8×60 시험')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ss_confirm_ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ss_saved_empty')), findsOneWidget);
  });
}
