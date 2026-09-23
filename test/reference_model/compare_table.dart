/// 앱 값과 기준 값을 모아 표로 찍는 도구. 검사를 실패시키지 않는다.
library;

/// 판정 세 가지.
enum Verdict {
  appWrong('앱이 틀림'),
  convention('기준이 관행값이라 다름'),
  definition('정의가 달라 비교 불가'),
  same('일치');

  final String label;
  const Verdict(this.label);
}

class DiffRow {
  final String calc; // 계산기 이름
  final String input; // 입력
  final double app;
  final double ref;
  final String unit;
  final Verdict verdict;
  final String why; // 판정 근거(숫자로)

  const DiffRow({
    required this.calc,
    required this.input,
    required this.app,
    required this.ref,
    required this.unit,
    required this.verdict,
    this.why = '',
  });

  double get diff => app - ref;
}

class CompareTable {
  final double threshold;
  final List<DiffRow> rows = [];
  final List<String> notes = [];

  CompareTable({this.threshold = 0.5});

  /// 값을 하나 넣는다. 차이가 [threshold] 미만이면 판정을 '일치'로 바꾼다.
  void add({
    required String calc,
    required String input,
    required double app,
    required double ref,
    String unit = 'mm',
    Verdict verdict = Verdict.appWrong,
    String why = '',
  }) {
    final same = (app - ref).abs() < threshold || (app.isNaN && ref.isNaN);
    rows.add(
      DiffRow(
        calc: calc,
        input: input,
        app: app,
        ref: ref,
        unit: unit,
        verdict: same ? Verdict.same : verdict,
        why: why,
      ),
    );
  }

  /// 값 비교가 아닌 관찰(직접 비교 못 함·경고 빠짐 등)을 적어 둔다.
  void note(String s) => notes.add(s);

  String _n(double v) => v.isFinite ? v.toStringAsFixed(2) : v.toString();

  /// 차이 난 줄만 표로 찍고 요약 줄을 찍는다.
  void printReport() {
    final diffs = rows.where((r) => r.verdict != Verdict.same).toList();
    final buf = StringBuffer();
    buf.writeln('');
    buf.writeln('=== 기준 모델과 차이 난 것 (${threshold}mm/° 이상) ===');
    buf.writeln('| 계산기 | 입력 | 앱 값 | 기준 값 | 차이 | 판정 | 근거 |');
    buf.writeln('|---|---|---|---|---|---|---|');
    for (final r in diffs) {
      buf.writeln(
        '| ${r.calc} | ${r.input} | ${_n(r.app)}${r.unit} | ${_n(r.ref)}${r.unit} '
        '| ${_n(r.diff)} | ${r.verdict.label} | ${r.why} |',
      );
    }
    if (notes.isNotEmpty) {
      buf.writeln('');
      buf.writeln('=== 값으로 비교 못 한 것 · 관찰 ===');
      for (final n in notes) {
        buf.writeln('- $n');
      }
    }
    final byVerdict = <Verdict, int>{};
    for (final r in diffs) {
      byVerdict[r.verdict] = (byVerdict[r.verdict] ?? 0) + 1;
    }
    buf.writeln('');
    buf.writeln(
      '요약: 비교 ${rows.length}건, 일치 ${rows.length - diffs.length}건, '
      '차이 ${diffs.length}건'
      '(앱이 틀림 ${byVerdict[Verdict.appWrong] ?? 0} / '
      '관행값 ${byVerdict[Verdict.convention] ?? 0} / '
      '정의 다름 ${byVerdict[Verdict.definition] ?? 0}), '
      '관찰 ${notes.length}건',
    );
    // ignore: avoid_print
    print(buf.toString());
  }
}
