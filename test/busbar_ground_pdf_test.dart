import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_ground.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_ground_page.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_ground_pdf.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/steel_pdf_preview_page.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 9000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: GroundBarPage()));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('접지바 가공 지시서 PDF가 만들어진다(모자·두 줄·러그·취부)', () async {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      length: 500,
      rows: 2,
      rowGap: 20,
      hat: true,
      hatHeight: 40,
      hatFlange: 50,
      tabHoleCount: 1,
      tabHoleDia: 11.1,
      tabHolePitch: 25.4,
      lugHoles: 2,
      lugSpacing: 44.45,
      lugCount: 1,
      lugHoleDia: 13.5,
      packGround: true,
    );
    final bytes = await buildGroundBarPdf(
      GroundPdfInput(
        title: '시험',
        plan: p,
        thickness: 6,
        width: 50,
        rho: 8.4,
        summary: const [('재료', '구리 평강 6 × 50 mm')],
        bendRows: const [
          ['1', '왼쪽 챙 → 다리', '28', '41.2'],
        ],
        sections: const [
          GroundPdfSection('접지 구멍', ['첫 구멍 25']),
        ],
        notes: const ['시험 주의'],
      ),
    );
    expect(bytes.length, greaterThan(2000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('구멍 위치 표가 PDF에 들어간다(표가 있으면 더 커지고 여러 쪽이 된다)', () async {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 12,
      endDist: 25,
      count: 40,
      rows: 2,
      rowGap: 20,
    );
    GroundPdfInput make(List<GroundPdfSection> sec) => GroundPdfInput(
      title: '표 시험',
      plan: p,
      thickness: 6,
      width: 50,
      rho: 8.4,
      summary: const [('재료', '구리 평강')],
      bendRows: const [],
      sections: sec,
      notes: const [],
    );
    final none = await buildGroundBarPdf(
      make(const [
        GroundPdfSection('접지 구멍 위치', ['첫 구멍 25']),
      ]),
    );
    final table = await buildGroundBarPdf(
      make([
        GroundPdfSection(
          '접지 구멍 위치',
          const ['첫 구멍 25'],
          headers: const ['번호', '왼쪽 끝에서(mm)', '폭 방향(mm)', '지름(mm)'],
          rows: [
            for (final h in p.groundHoles)
              [h.label, '${h.x}', '${h.y}', '${h.dia}'],
          ],
        ),
      ]),
    );
    expect(p.groundHoles.length, 80);
    expect(table.length, greaterThan(none.length + 1500));
  });

  test('파일 이름', () {
    expect(
      groundBarFileName('1호기 접지바', DateTime(2026, 10, 3)),
      'ground_bar_1호기_접지바_20261003.pdf',
    );
    expect(
      groundBarFileName('', DateTime(2026, 10, 3)),
      'ground_bar_noname_20261003.pdf',
    );
  });

  testWidgets('PDF 단추는 미리보기를 연다(공유는 미리보기 단추)', (tester) async {
    final old = pdfPreviewBuilder;
    addTearDown(() => pdfPreviewBuilder = old);
    pdfPreviewBuilder = (Uint8List bytes, String name) =>
        Text('미리보기 $name ${bytes.length > 1000}');
    await _open(tester);
    await _type(tester, 'gb_job', '시험');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('gb_pdf')));
      for (
        var i = 0;
        i < 80 && find.textContaining('미리보기 ground_bar_').evaluate().isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('미리보기 ground_bar_시험_'), findsOneWidget);
    expect(find.text('접지바 가공 지시서 미리보기'), findsOneWidget);
    expect(find.byKey(const Key('pdf_preview_share')), findsOneWidget);
  });

  testWidgets('저장한 규격: 저장 → 값을 고침 → 불러오기 → 지우기', (tester) async {
    await _open(tester);
    await _type(tester, 'gb_t', '8');
    await _type(tester, 'gb_w', '60');
    await tester.tap(find.byKey(const Key('gb_saved')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ss_saved_empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ss_save_now')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ss_save_name')), '8×60 시험');
    await tester.tap(find.byKey(const Key('ss_save_ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ss_saved_8×60 시험')), findsOneWidget);
    expect(find.textContaining('8×60 · 곧은 막대'), findsOneWidget);
    // 바깥을 눌러 시트를 닫고 값을 바꾼 뒤 불러온다
    Navigator.of(
      tester.element(find.byKey(const Key('ss_saved_8×60 시험'))),
    ).pop();
    await tester.pumpAndSettle();
    await _type(tester, 'gb_t', '5');
    await _type(tester, 'gb_w', '40');
    await tester.tap(find.byKey(const Key('gb_saved')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ss_saved_8×60 시험')));
    await tester.pumpAndSettle();
    String text(String k) =>
        tester.widget<TextField>(find.byKey(Key(k))).controller!.text;
    expect(text('gb_t'), '8');
    expect(text('gb_w'), '60');
    expect(find.textContaining('불러왔습니다'), findsOneWidget);
    // 지우기(확인창)
    await tester.tap(find.byKey(const Key('gb_saved')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ss_saved_del_8×60 시험')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ss_confirm_ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ss_saved_empty')), findsOneWidget);
  });

  testWidgets('지시서 만들기가 실패하면 알리고, 다시 누를 수 있다(8차)', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }))));
    final p = groundBar(t: 6, w: 50, holeDia: 11.1, pitch: 25.4, endDist: 25, count: 3);
    final input = GroundPdfInput(
      title: '시험',
      plan: p,
      thickness: 6,
      width: 50,
      rho: 8.4,
      summary: const [],
      bendRows: const [],
      sections: const [],
      notes: const [],
    );
    var calls = 0;
    Future<Uint8List> fail(GroundPdfInput i, DateTime d) async {
      calls++;
      throw StateError('글꼴 없음');
    }

    await openGroundBarPdf(ctx, input, build: fail);
    await tester.pump();
    expect(find.text('지시서를 만들지 못했습니다. 다시 해 보십시오.'), findsOneWidget);
    await openGroundBarPdf(ctx, input, build: fail);
    expect(calls, 2);
  });
}
