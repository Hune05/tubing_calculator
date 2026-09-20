import 'cutting_optimizer.dart';
import 'cutting_result_logic.dart';

// 절단 지시서(PDF)에 넣는 "원자재 배치" 표의 글자를 만든다. 화면과 따로 두어서
// 표에 나오는 숫자가 계산 결과와 어긋나지 않는지 테스트로 지킨다.

String _mm(double v) => v.toStringAsFixed(0);

// 같은 길이는 묶어서 "2600×2 + 1400" 처럼 쓴다. 긴 것부터 나열한다.
String piecesText(List<double> pieces) {
  final sorted = [...pieces]..sort((a, b) => b.compareTo(a));
  final parts = <String>[];
  var i = 0;
  while (i < sorted.length) {
    var j = i;
    while (j < sorted.length && sorted[j] == sorted[i]) {
      j++;
    }
    final n = j - i;
    parts.add(n == 1 ? _mm(sorted[i]) : '${_mm(sorted[i])}×$n');
    i = j;
  }
  return parts.join(' + ');
}

const List<String> kPlanHeaders = ['원자재', '자를 길이(mm)', '사용(mm)', '남는 길이(mm)'];

// 남은 토막이 먼저, 새 원자재가 그다음. 남는 길이는 톱날 손실을 뺀 값이다.
List<List<String>> planRows(CuttingOptimizationResult r) {
  final rows = <List<String>>[];
  for (final b in r.leftoverBars) {
    rows.add([
      '남은 토막 ${_mm(b.stockLength)}',
      piecesText(b.pieces),
      _mm(b.usedLength),
      _mm(b.remainderWithKerf(r.kerf)),
    ]);
  }
  for (var i = 0; i < r.bars.length; i++) {
    final b = r.bars[i];
    rows.add([
      '${i + 1}번 (${_mm(b.stockLength)})',
      piecesText(b.pieces),
      _mm(b.usedLength),
      _mm(b.remainderWithKerf(r.kerf)),
    ]);
  }
  return rows;
}

// "3000mm 1본 + 6000mm 2본" 처럼 길이별 본수. 길이가 하나뿐이면 "6000mm 3본".
String barLengthsText(List<StockBarPlan> bars) {
  final counts = <double, int>{};
  for (final b in bars) {
    counts[b.stockLength] = (counts[b.stockLength] ?? 0) + 1;
  }
  final keys = counts.keys.toList()..sort();
  return keys.map((k) => '${_mm(k)}mm ${counts[k]}본').join(' + ');
}

// 표 위에 붙이는 한 줄 요약.
String planSummary(CuttingOptimizationResult r) {
  final lengths = r.bars.map((b) => b.stockLength).toSet();
  final head = r.bars.isEmpty
      ? '새 원자재 0본'
      : lengths.length == 1
      ? '새 원자재 ${r.barCount}본(${_mm(lengths.first)}mm)'
      : '새 원자재 ${r.barCount}본(${barLengthsText(r.bars)})';
  final left = r.leftoverBars.isEmpty
      ? ''
      : ', 남은 토막 ${r.leftoverBars.length}개 사용';
  return '$head$left';
}

// ── 필요한 부속 표(지시서 PDF) ──
const List<String> kFittingHeaders = ['부속', '규격', '제조사', '수량'];

// 제조사가 "CUSTOM"이면 직접 입력한 부속이라 "직접 입력"으로 쓴다. 규격을 모르면 "-".
List<List<String>> fittingTableRows(List<FittingOrder> orders) => [
  for (final o in orders)
    [
      o.name,
      (o.spec.isEmpty || o.spec == '미지정') ? '-' : o.spec,
      o.maker == 'CUSTOM' ? '직접 입력' : (o.maker.isEmpty ? '-' : o.maker),
      '${o.qty}',
    ],
];

// 표 아래 한 줄: "총 5종 · 12개".
String fittingTableTotal(List<FittingOrder> orders) =>
    '총 ${orders.length}종 · ${orders.fold<int>(0, (s, o) => s + o.qty)}개';
