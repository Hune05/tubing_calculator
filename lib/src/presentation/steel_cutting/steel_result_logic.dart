import '../../data/models/steel_cutting_project_model.dart';
import '../tube_cutting/cutting_math.dart' show fmtKg, fmtMm;
import '../tube_cutting/cutting_result_logic.dart';
import 'steel_weight.dart';

// 형강 컷팅 "결과" 탭의 계산(화면과 분리해서 테스트로 지킨다). 튜브 컷팅의 결과 목록(ResultLine)을
// 그대로 쓰되, 줄은 "같은 규격·같은 길이"끼리 묶는다(항목이 여러 개여도 자르는 사람에게는 같은 일이다).

// 형강 재단 최적화의 "여러 길이 섞어 쓰기" 설정 저장 키(튜브 컷팅과 따로 둔다 — 쓰는 원자재 길이가 다르다).
const String kSteelMixPrefsKey = 'cutting_mix_lengths_steel_v1';

String _one(double v) => v.toStringAsFixed(1);

// 항목 → 결과 줄. 규격은 처음 나온 순서, 한 규격 안에서는 긴 것부터(긴 것을 먼저 자르면 남는 토막을 알기 쉽다).
List<ResultLine> buildSteelResultLines(List<SteelCutItem> items, int sets) {
  final set = sets < 1 ? 1 : sets;
  final shapeOrder = <String>[];
  final byShape = <String, Map<String, _Acc>>{};
  for (final it in items) {
    if (it.length <= 0 || it.qty <= 0) continue;
    if (!byShape.containsKey(it.shapeLabel)) {
      shapeOrder.add(it.shapeLabel);
      byShape[it.shapeLabel] = {};
    }
    final k = _one(it.length);
    final acc = byShape[it.shapeLabel]!.putIfAbsent(k, () => _Acc(it.length));
    acc.qty += it.qty;
    acc.items += 1;
    if (it.note.trim().isNotEmpty) acc.notes.add(it.note.trim());
  }
  final out = <ResultLine>[];
  for (final shape in shapeOrder) {
    final entries = byShape[shape]!.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    for (final e in entries) {
      final a = e.value;
      final count = a.qty * set;
      final noteText = a.notes.toSet().join(' · ');
      out.add(
        ResultLine(
          key: 'steel:$shape:${e.key}:$count',
          title: '${e.key} mm',
          detail: [
            if (a.items > 1) '${a.items}건 합침',
            if (noteText.isNotEmpty) noteText,
          ].join(' · '),
          cutMm: a.length,
          count: count,
          segments: const [],
          spec: shape,
          baseCount: a.qty,
          sets: set,
          grouped: true,
          formulaPrefix: '',
        ),
      );
    }
  }
  return out;
}

class _Acc {
  final double length;
  int qty = 0;
  int items = 0;
  final List<String> notes = [];
  _Acc(this.length);
}

// 규격 하나의 소계(결과 목록에서 규격 머리글에 쓴다).
class ShapeSubtotal {
  final String shape;
  final int kinds; // 길이 종류 수
  final int pieces; // 개수(세트 곱함)
  final double mm; // 길이 합계(세트 곱함)
  const ShapeSubtotal(this.shape, this.kinds, this.pieces, this.mm);

  // 이론 중량(kg, 세트 곱함). 규격 이름을 못 알아보면 null.
  double? get weightKg => steelWeightKg(shape, mm);
}

// 규격별 무게 합계와 전체(모르는 규격은 뺀다). 아무 규격도 모르면 total은 null.
class WeightTotals {
  final Map<String, double> bySpec;
  final double? total;
  final int unknownSpecs;
  const WeightTotals(this.bySpec, this.total, this.unknownSpecs);
}

WeightTotals weightTotals(List<ResultLine> lines) {
  final by = <String, double>{};
  var unknown = 0;
  for (final s in shapeSubtotals(lines)) {
    final w = s.weightKg;
    if (w == null) {
      unknown++;
    } else {
      by[s.shape] = w;
    }
  }
  final total = by.isEmpty ? null : by.values.fold<double>(0, (a, b) => a + b);
  return WeightTotals(by, total, unknown);
}

List<ShapeSubtotal> shapeSubtotals(List<ResultLine> lines) {
  final order = <String>[];
  final kinds = <String, int>{};
  final pieces = <String, int>{};
  final mm = <String, double>{};
  for (final l in lines) {
    if (!kinds.containsKey(l.spec)) order.add(l.spec);
    kinds[l.spec] = (kinds[l.spec] ?? 0) + 1;
    pieces[l.spec] = (pieces[l.spec] ?? 0) + l.count;
    mm[l.spec] = (mm[l.spec] ?? 0) + l.totalMm;
  }
  return [
    for (final s in order) ShapeSubtotal(s, kinds[s]!, pieces[s]!, mm[s]!),
  ];
}

// 카카오톡·메신저에 붙여넣는 형강 지시서 글.
String buildSteelInstructionText({
  required String projectName,
  required DateTime date,
  required int sets,
  required List<ResultLine> lines,
  double stockLength = 6000,
  double kerfMm = 0,
}) {
  final set = sets < 1 ? 1 : sets;
  final d =
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  final b = StringBuffer();
  b.writeln('[형강 컷팅 지시서] $projectName');
  b.writeln(
    '$d · $set세트 · 원자재 ${fmtMm(stockLength)}mm'
    '${kerfMm > 0 ? ' · 톱날 ${fmtMm(kerfMm)}mm' : ''}',
  );
  b.writeln();
  if (lines.isEmpty) {
    b.writeln('(절단 항목이 없습니다)');
    return b.toString().trimRight();
  }
  var pieces = 0;
  var mm = 0.0;
  final weights = weightTotals(lines);
  for (final sub in shapeSubtotals(lines)) {
    b.writeln('■ ${sub.shape}');
    for (final l in lines.where((x) => x.spec == sub.shape)) {
      final how = set > 1 ? ' (${l.baseCount}개 × $set세트)' : '';
      final note = l.detail.isEmpty ? '' : ' - ${l.detail}';
      b.writeln('${fmtMm(l.cutMm)}mm × ${l.count}개$how$note');
    }
    final w = sub.weightKg;
    b.writeln(
      '  소계 ${_one(sub.mm)}mm (${sub.pieces}개)'
      '${w == null ? '' : ' · 약 ${fmtKg(w)}kg'}',
    );
    pieces += sub.pieces;
    mm += sub.mm;
  }
  b.writeln();
  b.writeln(
    set > 1
        ? '합계 1세트 ${_one(mm / set)}mm × $set세트 = ${_one(mm)}mm (총 $pieces개)'
        : '합계 ${_one(mm)}mm (총 $pieces개)',
  );
  if (weights.total != null) {
    b.writeln(
      '총 중량 약 ${fmtKg(weights.total!)}kg (이론값'
      '${weights.unknownSpecs > 0 ? ', 중량을 모르는 규격 ${weights.unknownSpecs}종 제외' : ''})',
    );
  }
  return b.toString().trimRight();
}
