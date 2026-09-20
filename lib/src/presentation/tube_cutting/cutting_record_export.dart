import '../../data/models/cutting_project_model.dart';

// 컷팅 기록을 표(PDF)로 내보낼 때 쓰는 글자와 합계를 만든다. 화면·파일과 따로 두어서
// 표의 합계가 기록과 어긋나지 않는지 테스트로 지킨다.

const List<String> kRecordHeaders = [
  '날짜',
  '규격',
  '구간(시작 → 끝 부속)',
  '절단(mm)',
  '수량',
  '합계(mm)',
];

class RecordExport {
  final List<List<String>> rows; // 날짜 오름차순
  final int totalCount; // 잘라 낸 전체 개수(수량 합)
  final double totalMm; // 전체 길이 합계
  final Map<String, ({int count, double mm})> byTubeSize;
  final DateTime? first;
  final DateTime? last;

  const RecordExport({
    required this.rows,
    required this.totalCount,
    required this.totalMm,
    required this.byTubeSize,
    required this.first,
    required this.last,
  });
}

String _one(double v) => v.toStringAsFixed(1);

// 규격을 모르는 기록의 표시 글자. 예전 기록은 규격이 "ALL"·"미지정"·빈 값으로 남아 있다.
const String kUnknownSpecLabel = '규격 미지정';

String normalizeSpec(String raw) {
  final t = raw.trim();
  return (t.isEmpty || t == 'ALL' || t == '미지정') ? kUnknownSpecLabel : t;
}

// 기록에 나오는 규격들(처음 나온 순서, 규격 미지정도 하나로).
List<String> recordSpecs(List<CutRecord> records) {
  final out = <String>[];
  for (final r in records) {
    final s = normalizeSpec(r.tubeSize);
    if (!out.contains(s)) out.add(s);
  }
  return out;
}

// 규격 하나만 남긴다([spec]이 null이면 전부).
List<CutRecord> filterBySpec(List<CutRecord> records, String? spec) =>
    spec == null
    ? records
    : records.where((r) => normalizeSpec(r.tubeSize) == spec).toList();

class RecordSpecTotal {
  final String spec;
  final int count;
  final double mm;
  const RecordSpecTotal(this.spec, this.count, this.mm);
}

// 규격별 개수·길이(수량을 곱한 값, 처음 나온 순서).
List<RecordSpecTotal> recordSpecTotals(List<CutRecord> records) {
  final order = <String>[];
  final count = <String, int>{};
  final mm = <String, double>{};
  for (final r in records) {
    final s = normalizeSpec(r.tubeSize);
    final m = r.multiplier < 1 ? 1 : r.multiplier;
    if (!count.containsKey(s)) order.add(s);
    count[s] = (count[s] ?? 0) + m;
    mm[s] = (mm[s] ?? 0) + r.cutLength * m;
  }
  return [for (final s in order) RecordSpecTotal(s, count[s]!, mm[s]!)];
}

String _md(DateTime d) => '${d.month}/${d.day}';

RecordExport buildRecordExport(List<CutRecord> records) {
  final sorted = [...records]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final rows = <List<String>>[];
  final bySize = <String, ({int count, double mm})>{};
  var count = 0;
  var mm = 0.0;
  for (final r in sorted) {
    final m = r.multiplier < 1 ? 1 : r.multiplier;
    final total = r.cutLength * m;
    final size = normalizeSpec(r.tubeSize);
    rows.add([
      _md(r.timestamp),
      size,
      '${r.startFitting.isEmpty ? '직관' : r.startFitting} → '
          '${r.endFitting.isEmpty ? '직관' : r.endFitting}',
      _one(r.cutLength),
      '$m',
      _one(total),
    ]);
    count += m;
    mm += total;
    final prev = bySize[size];
    bySize[size] = (count: (prev?.count ?? 0) + m, mm: (prev?.mm ?? 0) + total);
  }
  return RecordExport(
    rows: rows,
    totalCount: count,
    totalMm: mm,
    byTubeSize: bySize,
    first: sorted.isEmpty ? null : sorted.first.timestamp,
    last: sorted.isEmpty ? null : sorted.last.timestamp,
  );
}

// 기간 글자: 하루면 "9/13", 여러 날이면 "9/13 ~ 9/20".
String recordPeriodText(RecordExport e) {
  if (e.first == null || e.last == null) return '';
  final a = _md(e.first!);
  final b = _md(e.last!);
  return a == b ? a : '$a ~ $b';
}
