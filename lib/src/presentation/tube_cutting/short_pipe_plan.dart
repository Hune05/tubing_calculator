// 단관(짧은 직관) 컷팅: 같은 길이의 짧은 관을 여러 개 자를 때, 원자재 한 본에서 어떻게 자르고
// 몇 본이 드는지, 줄자의 어느 눈금에서 자르는지 알려 준다.
//
// 배치(원자재 본수 최소)는 cutting_optimizer.dart의 계산을 그대로 쓴다. 여기서는 입력을 절단 길이로
// 바꾸고(중심 간 거리 입력이면 양끝 부속 공제를 뺌), 본마다 "자르는 선" 위치를 셈하고, 카톡용 글을 만든다.
library;

import 'cutting_optimizer.dart';

/// 입력 한 줄: 길이(mm)와 개수.
class ShortPipeRow {
  final double length;
  final int qty;
  const ShortPipeRow(this.length, this.qty);
}

/// 줄 하나가 절단 길이로 바뀐 결과.
class ShortPipeCut {
  /// 입력 줄의 번호(0부터).
  final int row;

  /// 실제로 자를 길이(mm). 문제가 있으면 [problem]이 적힌다.
  final double cutLength;
  final int qty;

  /// 이 줄을 계산에서 뺀 까닭(없으면 null).
  final String? problem;

  const ShortPipeCut({
    required this.row,
    required this.cutLength,
    required this.qty,
    this.problem,
  });

  bool get ok => problem == null;
}

/// 원자재 한 본에서 한 조각을 자르는 자리.
class BarCutMark {
  /// 본 안에서 몇 번째 조각인지(0부터).
  final int index;

  /// 이 조각이 시작하는 자리(원자재 왼쪽 끝에서 mm. 끝 다듬기·앞 조각·톱날 손실을 더한 값).
  final double start;

  /// 자르는 선(줄자 눈금, mm). 이 눈금에서 톱을 댄다.
  final double cutAt;

  /// 이 조각의 길이.
  final double length;

  const BarCutMark({
    required this.index,
    required this.start,
    required this.cutAt,
    required this.length,
  });
}

class ShortPipePlan {
  final List<ShortPipeCut> cuts;
  final CuttingOptimizationResult result;

  /// 원자재보다 길어 자를 수 없는 조각들(mm).
  final List<double> oversized;
  final double stockLength;
  final double kerf;
  final double endTrim;

  const ShortPipePlan({
    required this.cuts,
    required this.result,
    required this.oversized,
    required this.stockLength,
    required this.kerf,
    required this.endTrim,
  });

  List<String> get problems => [
    for (final c in cuts)
      if (c.problem != null) '${c.row + 1}번 줄: ${c.problem}',
    for (final o in oversized)
      '${_fmt(o)}mm는 원자재(${_fmt(stockLength)}mm)보다 길어 자를 수 없습니다.',
  ];

  int get barCount => result.barCount;
  int get pieceCount => result.bars.fold(0, (a, b) => a + b.pieces.length);

  /// 쓴 원자재 길이 합에서 조각 길이 합을 뺀 것(끝 다듬기·톱날·남는 끝 포함, mm).
  double get lossLength => result.totalStock - result.totalUsed;

  /// 조각 길이 합 ÷ 쓴 원자재 길이 합(0~1). 원자재를 안 쓰면 0.
  double get usage =>
      result.totalStock <= 0 ? 0 : result.totalUsed / result.totalStock;
}

String _fmt(double v) => (v - v.roundToDouble()).abs() < 0.05
    ? '${v.round()}'
    : v.toStringAsFixed(1);

/// 입력 줄들을 절단 길이로 바꾼다.
/// [centerToCenter]가 참이면 입력은 중심 간 거리이고, 양쪽 끝에 같은 부속이 붙는다고 보고
/// 절단 길이 = 입력 − 2 × [endDeduction]. 거짓이면 입력이 곧 절단 길이다.
List<ShortPipeCut> shortPipeCuts(
  List<ShortPipeRow> rows, {
  bool centerToCenter = false,
  double endDeduction = 0,
}) {
  final out = <ShortPipeCut>[];
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    if (r.qty <= 0) continue;
    final cut = centerToCenter ? r.length - 2 * endDeduction : r.length;
    String? problem;
    if (!r.length.isFinite || r.length <= 0) {
      problem = '길이를 넣으십시오.';
    } else if (cut <= 0) {
      problem =
          '부속 공제값 ${_fmt(2 * endDeduction)}mm가 길이 ${_fmt(r.length)}mm 이상이라 자를 길이가 없습니다(간섭).';
    }
    out.add(
      ShortPipeCut(
        row: i,
        cutLength: problem == null ? cut : 0,
        qty: r.qty,
        problem: problem,
      ),
    );
  }
  return out;
}

/// 단관 컷팅 계획. 문제 있는 줄은 계산에서 빼고 [ShortPipePlan.problems]에 적는다.
ShortPipePlan planShortPipes(
  List<ShortPipeRow> rows, {
  required double stockLength,
  double kerf = 0,
  double endTrim = 0,
  bool centerToCenter = false,
  double endDeduction = 0,
}) {
  final cuts = shortPipeCuts(
    rows,
    centerToCenter: centerToCenter,
    endDeduction: endDeduction,
  );
  final pieces = <double>[
    for (final c in cuts)
      if (c.ok)
        for (var k = 0; k < c.qty; k++) c.cutLength,
  ];
  final result = optimizeCutting(
    pieces: pieces,
    stockLength: stockLength,
    kerf: kerf,
    endTrim: endTrim,
  );
  return ShortPipePlan(
    cuts: cuts,
    result: result,
    oversized: result.oversizedPieces,
    stockLength: stockLength,
    kerf: kerf,
    endTrim: endTrim,
  );
}

/// 본 하나에서 조각마다 자르는 선(줄자 눈금)을 셈한다.
/// 줄자의 0은 원자재 끝이다. 새 원자재는 [StockBarPlan.trim]만큼 끝을 다듬은 자리부터 쓴다.
/// 조각 길이만큼 가서 자르고, 다음 조각은 톱날 손실만큼 더 간 자리에서 시작한다.
List<BarCutMark> barCutMarks(StockBarPlan bar, double kerf) {
  final out = <BarCutMark>[];
  var pos = bar.trim;
  for (var i = 0; i < bar.pieces.length; i++) {
    final len = bar.pieces[i];
    final cutAt = pos + len;
    out.add(BarCutMark(index: i, start: pos, cutAt: cutAt, length: len));
    pos = cutAt + kerf;
  }
  return out;
}

/// 카톡·메모에 붙이는 글.
String shortPipePlanText(ShortPipePlan p, {String title = '단관 컷팅'}) {
  final b = StringBuffer(
    '[$title] 원자재 ${_fmt(p.stockLength)}mm'
    '${p.kerf > 0 ? ' · 톱날 ${_fmt(p.kerf)}mm' : ''}'
    '${p.endTrim > 0 ? ' · 끝 다듬기 ${_fmt(p.endTrim)}mm' : ''}',
  );
  final counts = <double, int>{};
  for (final bar in p.result.bars) {
    for (final len in bar.pieces) {
      counts[len] = (counts[len] ?? 0) + 1;
    }
  }
  final keys = counts.keys.toList()..sort((a, b) => b.compareTo(a));
  if (keys.isNotEmpty) {
    b.writeln();
    b.write('자를 길이: ${keys.map((k) => '${_fmt(k)}×${counts[k]}').join(', ')}');
  }
  b.writeln();
  b.write(
    '원자재 ${p.barCount}본 · 조각 ${p.pieceCount}개 · 이용률 ${(p.usage * 100).toStringAsFixed(0)}%',
  );
  for (var i = 0; i < p.result.bars.length; i++) {
    final bar = p.result.bars[i];
    final marks = barCutMarks(bar, p.kerf);
    b.writeln();
    b.write(
      '${i + 1}번: ${bar.pieces.map(_fmt).join(' + ')}'
      ' → 자르는 선 ${marks.map((m) => _fmt(m.cutAt)).join(' / ')}',
    );
    final rest = bar.remainderWithKerf(p.kerf);
    if (rest >= 1) b.write(' (잔재 ${_fmt(rest.floorToDouble())})');
  }
  for (final prob in p.problems) {
    b.writeln();
    b.write('※ $prob');
  }
  return b.toString();
}
