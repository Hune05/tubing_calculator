import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/pdf_fonts.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_diagram_pdf.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_diagram_view.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart';

// 배치도 PDF: 여러 상태의 지점·구간을 그려도 문서가 만들어지는지, 화면의 공유 버튼.
DiagramPoint none() => const DiagramPoint(
  isNone: true,
  name: '직관',
  tubeOD: '',
  icon: AppGlyph.fitOther,
);

DiagramPoint fit(String name) =>
    DiagramPoint(isNone: false, name: name, tubeOD: '1/2"', icon: AppGlyph.fitUnion);

DiagramSegment ok(double c2c, {double sd = 0, double ed = 0}) => DiagramSegment(
  state: SegmentState.ok,
  c2cMm: c2c,
  cutMm: c2c - sd - ed,
  startDeduction: sd,
  endDeduction: ed,
);

Future<Uint8List> makePdf(
  List<DiagramPoint> pts,
  List<DiagramSegment> segs, {
  int sets = 1,
}) async {
  final fonts = await loadKoreanPdfFonts();
  final pdf = pw.Document(theme: fonts.theme);
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => buildDiagramPdfWidgets(
        points: pts,
        segments: segs,
        setMultiplier: sets,
      ),
    ),
  );
  return pdf.save();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('여러 상태가 섞인 라인도 PDF로 만들어진다', () async {
    final bytes = await makePdf(
      [none(), fit('유니온'), none(), fit('엘보'), none()],
      [
        ok(2600, ed: 6),
        const DiagramSegment(
          state: SegmentState.interference,
          c2cMm: 10,
          cutMm: -5,
          startDeduction: 8,
          endDeduction: 7,
        ),
        const DiagramSegment(state: SegmentState.empty),
        const DiagramSegment(state: SegmentState.unreadable),
      ],
      sets: 3,
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length > 2000, true);
  });

  test('지점이 아주 많아도(여러 쪽) 만들어진다', () async {
    final n = 40;
    final bytes = await makePdf(
      [for (var i = 0; i < n; i++) i.isEven ? none() : fit('유니온')],
      [for (var i = 0; i < n - 1; i++) ok(300.0 + i * 50, sd: 6, ed: 6)],
    );
    final text = String.fromCharCodes(bytes);
    final pages = RegExp(r'/Type/Page\b').allMatches(text).length;
    expect(pages > 1, true);
  });

  test('PDF 글꼴은 보통·굵게가 따로 들어가고 가장 얇은 글꼴은 쓰지 않는다', () async {
    final bytes = await makePdf([none(), fit('유니온')], [ok(500)]);
    final text = String.fromCharCodes(bytes);
    expect(text.contains('NotoSansKR-Regular'), true);
    expect(text.contains('NotoSansKR-Bold'), true);
    expect(text.contains('NotoSansKR-Thin'), false);
  });

  test('구간이 하나뿐인 가장 작은 라인', () async {
    final bytes = await makePdf([none(), none()], [ok(500)]);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('위젯 수는 지점 수 + 간격 + 요약', () {
    final w = buildDiagramPdfWidgets(
      points: [none(), none(), none()],
      segments: [ok(100), ok(200)],
    );
    expect(w.length, 3 + 2);
  });

  group('배치도 탭 공유 버튼', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('치수가 없으면 내보낼 것이 없다고 알려 준다', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuttingMainScreen(
              project: CuttingProject(
                id: 'p1',
                name: 'TEST',
                createdAt: DateTime(2026, 9, 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('배치도'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('diagram_share')), findsOneWidget);
      await tester.tap(find.byKey(const Key('diagram_share')));
      await tester.pump();
      expect(find.textContaining('내보낼 치수가 없습니다'), findsOneWidget);
    });
  });
}
