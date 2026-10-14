// 10-14 작업 일지 확인 서명: 서명하면 확정되고, 같은 사람은 바꿔 쓰고, 보고서 글·PDF에 들어가며,
// 보고서 양식의 켜고 끄기가 저장된다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_confirm.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_pdf.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_style.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> report() => {
    'id': 'r1',
    'date': '10/14',
    'dateISO': '2026-10-14',
    'work_type': ['신규 설치'],
    'worker_count': 3,
  };

  test('서명하면 확정되고, 같은 사람이 다시 하면 바꿔 쓴다', () {
    final r = report();
    addReportConfirmation(
      r,
      name: '홍길동',
      role: '감독원',
      sig: 'v1:0,0 100,40',
      at: DateTime(2026, 10, 14, 17, 5),
    );
    expect(r['locked'], isTrue);
    expect(isReportConfirmed(r), isTrue);
    expect(confirmLine(r), '홍길동(감독원) 10/14');
    addReportConfirmation(r, name: '김철수', at: DateTime(2026, 10, 15));
    addReportConfirmation(
      r,
      name: '홍길동',
      role: '감독원',
      at: DateTime(2026, 10, 16),
    );
    expect(confirmationsOf(r).map((c) => c.name), ['김철수', '홍길동']);
    expect(confirmLine(r), '김철수 10/15 · 홍길동(감독원) 10/16');
    expect(clearReportConfirmations(r), ['김철수', '홍길동(감독원)']);
    expect(isReportConfirmed(r), isFalse);
  });

  test('보고서 글에 "확인:" 줄, 문서에 서명 목록, PDF가 만들어진다', () async {
    final r = report();
    addReportConfirmation(
      r,
      name: '홍길동',
      role: '감독원',
      sig: 'v1:0,0 500,200 1000,400',
      at: DateTime(2026, 10, 14, 17, 5),
    );
    final log = <String, dynamic>{
      'name': '시험',
      'daily_reports': [r],
    };
    final doc = buildReportDoc(
      log,
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 31),
    );
    final text = doc.sections.expand((s) => s.lines).join('\n');
    expect(text, contains('확인: 홍길동(감독원) 10/14'));
    expect(doc.confirms.single.who, '홍길동(감독원)');
    expect(doc.withHeading('마무리 보고').confirms.length, 1);
    final bytes = await buildReportPdfBytes(doc);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    // 여러 프로젝트를 묶어도 어느 프로젝트 일지인지 붙는다.
    final merged = mergeReportDocs([doc, doc]);
    expect(merged.confirms.first.reportDate, '[시험] 10/14');
  });

  test('보고서 양식: 확인 서명은 기본 꺼짐, 켜면 그대로 읽힌다', () {
    expect(ReportStyle().reportConfirm, isFalse);
    final s = ReportStyle(reportConfirm: true);
    expect(ReportStyle.fromJson(s.toJson()).reportConfirm, isTrue);
    expect(ReportStyle.fromJson(const {}).reportConfirm, isFalse);
  });
}
