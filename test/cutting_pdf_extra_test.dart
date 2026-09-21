import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tubing_calculator/src/core/utils/pdf_fonts.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_diagram_pdf.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_diagram_view.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_plan_rows.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_result_logic.dart';

// 지시서 PDF: 필요한 부속 표, 세트 식, 테두리 없는 라인 요약, 글 복사의 세트 식.
DiagramPoint none() => const DiagramPoint(
  isNone: true,
  name: '직관',
  tubeOD: '',
  icon: AppGlyph.fitOther,
);

DiagramSegment ok(double c2c) =>
    DiagramSegment(state: SegmentState.ok, c2cMm: c2c, cutMm: c2c);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('필요한 부속 표', () {
    final orders = [
      const FittingOrder(
        maker: 'Swagelok',
        spec: '1/2"',
        name: 'Union Cross',
        qty: 4,
      ),
      const FittingOrder(maker: 'CUSTOM', spec: '미지정', name: '볼밸브', qty: 2),
    ];

    test('행: 부속·규격·제조사·수량, 직접 입력과 모르는 규격은 글자로', () {
      expect(fittingTableRows(orders), [
        ['Union Cross', '1/2"', 'Swagelok', '4'],
        ['볼밸브', '-', '직접 입력', '2'],
      ]);
      expect(kFittingHeaders, ['부속', '규격', '제조사', '수량']);
    });

    test('합계 줄은 종류 수와 전체 개수', () {
      expect(fittingTableTotal(orders), '총 2종 · 6개');
      expect(fittingTableTotal(const []), '총 0종 · 0개');
    });

    test('세트 수를 곱한 수량이 표에 그대로 나온다', () {
      final o = fittingOrderList(const [
        FittingUse(maker: 'S', spec: '1/2"', name: 'A'),
        FittingUse(maker: 'S', spec: '1/2"', name: 'A'),
        FittingUse(maker: 'S', spec: '1/2"', name: 'B'),
      ], 3);
      expect(fittingTableRows(o).map((r) => r.last), ['6', '3']);
      expect(fittingTableTotal(o), '총 2종 · 9개');
    });
  });

  group('지시서 글의 세트 식', () {
    test('세트가 여럿이면 합계가 1세트 × 세트 수 = 합계, 묶은 줄은 구성도', () {
      final lines = buildResultLines([600.0, 900.0, 600.0], 3, grouped: true);
      final t = buildInstructionText(
        projectName: 'A',
        date: DateTime(2026, 1, 2),
        maker: 'S',
        setMultiplier: 3,
        lines: lines,
        orders: const [],
      );
      expect(t.contains('1) 600.0mm × 6개 (구간 2개 × 3세트)'), true);
      expect(t.contains('2) 900.0mm × 3개 (구간 1개 × 3세트)'), true);
      expect(t.contains('합계 1세트 2100.0mm × 3세트 = 6300.0mm (총 9개)'), true);
    });

    test('세트가 하나면 예전 글 그대로', () {
      final t = buildInstructionText(
        projectName: 'A',
        date: DateTime(2026, 1, 2),
        maker: 'S',
        setMultiplier: 1,
        lines: buildResultLines([600.0, 600.0], 1, grouped: true),
        orders: const [],
      );
      expect(t.contains('1) 600.0mm × 2개\n'), true);
      expect(t.contains('합계 1200.0mm (총 2개)'), true);
    });
  });

  group('라인 요약 PDF', () {
    Future<List<int>> make(int sets) async {
      final fonts = await loadKoreanPdfFonts();
      final pdf = pw.Document(theme: fonts.theme);
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => buildDiagramPdfWidgets(
            points: [none(), none(), none()],
            segments: [ok(600), ok(900)],
            setMultiplier: sets,
          ),
        ),
      );
      return pdf.save();
    }

    test('요약이 테두리 없이(둥근 상자 없이) 그려진다', () async {
      // 요약 상자였던 마지막 위젯이 더는 테두리를 가진 Container가 아니다.
      final w = buildDiagramPdfWidgets(
        points: [none(), none()],
        segments: [ok(600)],
      );
      final last = w.last as pw.Container;
      expect(last.decoration, isNull);
      final bytes = await make(1);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('세트가 여럿이어도 만들어진다', () async {
      final bytes = await make(3);
      expect(bytes.length > 2000, true);
    });
  });
}
