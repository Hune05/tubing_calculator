import 'cutting_math.dart';

// 튜브 컷팅 "결과" 탭의 계산(화면과 분리해서 테스트로 지킨다):
//  - 구간별/같은 길이끼리 묶은 "자를 길이" 목록과 총계,
//  - 잘랐음 표시(체크)의 진행 상황,
//  - 필요한 부속 목록,
//  - 카카오톡 등에 붙여넣을 지시서 글.

String _one(double v) => v.toStringAsFixed(1);

// ── 튜브 규격(제원) ──
// 자를 튜브가 어떤 규격인지는 양쪽 부속의 튜브 외경에서 알 수 있다. 시작 쪽 부속이 있으면 그
// 규격, 없으면(직관) 끝 쪽 부속의 규격을 따른다. 둘 다 모르면(부속을 안 골랐거나 규격이
// "ALL"/"미지정") [fallback](사용자가 직접 지정한 규격)을 쓴다. 그것도 없으면 빈 글자.
bool _validOd(String od) {
  final t = od.trim();
  return t.isNotEmpty && t != 'ALL' && t != '미지정';
}

String tubeSpecFor({
  required bool startIsFitting,
  required String startOD,
  required bool endIsFitting,
  required String endOD,
  String fallback = '',
}) {
  if (startIsFitting && _validOd(startOD)) return startOD.trim();
  if (endIsFitting && _validOd(endOD)) return endOD.trim();
  return fallback.trim();
}

class ResultLine {
  // 잘랐음 표시를 기억하는 열쇠. 길이·개수가 바뀌면 열쇠도 바뀌어서 이전 표시가 저절로 사라진다.
  final String key;
  final String title; // "PT1 → PT2" 또는 "2600.0 mm"
  final String detail; // 작은 글씨 설명
  final double cutMm; // 하나의 절단 길이
  final int count; // 세트 수를 곱한 개수
  final List<int> segments; // 이 줄에 들어간 구간 번호(0부터)
  final String spec; // 튜브 규격(모르면 빈 글자)
  // 세트 수를 곱하기 전의 개수(1세트에 들어 있는 개수)와 세트 수. count = baseCount × sets.
  // 1개 값(cutMm)은 세트 수와 상관없이 늘 같다.
  final int baseCount;
  final int sets;
  final bool grouped; // 같은 길이끼리 묶은 줄인지
  final String formulaPrefix; // 개수 식 앞에 붙는 말(튜브는 "구간", 형강은 없음)

  const ResultLine({
    required this.key,
    required this.title,
    required this.detail,
    required this.cutMm,
    required this.count,
    required this.segments,
    this.spec = '',
    this.baseCount = 1,
    this.sets = 1,
    this.grouped = false,
    this.formulaPrefix = '구간 ',
  });

  double get totalMm => cutMm * count;

  // "구간 2개 × 3세트 = 6개" 처럼 개수가 어디서 나왔는지. 세트가 1이면 빈 글자.
  String get countFormula => sets > 1
      ? '${grouped ? formulaPrefix : ''}$baseCount개 × $sets세트 = $count개'
      : '';
}

// [cuts]는 구간별 절단 길이이고, 계산할 수 없는 구간(비었음·못 읽음·간섭)은 null 또는 0 이하.
// [specs]는 구간별 튜브 규격(모르면 빈 글자, 목록이 없으면 모두 모르는 것으로). 규격이 다른 튜브는
// 길이가 같아도 하나로 묶지 않는다 — 서로 다른 튜브에서 잘라야 하기 때문이다.
List<ResultLine> buildResultLines(
  List<double?> cuts,
  int setMultiplier, {
  required bool grouped,
  List<String>? specs,
}) {
  final set = setMultiplier < 1 ? 1 : setMultiplier;
  String specOf(int i) => (specs != null && i < specs.length) ? specs[i] : '';
  final out = <ResultLine>[];
  if (!grouped) {
    for (var i = 0; i < cuts.length; i++) {
      final c = cuts[i];
      if (c == null || c <= 0) continue;
      final sp = specOf(i);
      out.add(
        ResultLine(
          key: sp.isEmpty
              ? 'seg:$i:${_one(c)}:$set'
              : 'seg:$i:$sp:${_one(c)}:$set',
          title: 'PT${i + 1} → PT${i + 2}',
          detail: '구간 길이 ${_one(c)} mm',
          cutMm: c,
          count: set,
          segments: [i],
          spec: sp,
          baseCount: 1,
          sets: set,
          grouped: false,
        ),
      );
    }
    return out;
  }
  // 같은 규격·같은 길이(소수 첫째 자리까지 같으면 같은 것으로)끼리 묶고, 처음 나온 순서를 지킨다.
  final order = <String>[];
  final members = <String, List<int>>{};
  final values = <String, double>{};
  final groupSpec = <String, String>{};
  for (var i = 0; i < cuts.length; i++) {
    final c = cuts[i];
    if (c == null || c <= 0) continue;
    final sp = specOf(i);
    final k = '$sp\u0001${_one(c)}';
    if (!members.containsKey(k)) {
      order.add(k);
      members[k] = [];
      values[k] = c;
      groupSpec[k] = sp;
    }
    members[k]!.add(i);
  }
  for (final k in order) {
    final segs = members[k]!;
    final count = segs.length * set;
    final sp = groupSpec[k]!;
    final len = _one(values[k]!);
    out.add(
      ResultLine(
        key: sp.isEmpty ? 'len:$len:$count' : 'len:$sp:$len:$count',
        title: '$len mm',
        detail: segs.map((i) => 'PT${i + 1}→${i + 2}').join(' · '),
        cutMm: values[k]!,
        count: count,
        segments: segs,
        spec: sp,
        baseCount: segs.length,
        sets: set,
        grouped: true,
      ),
    );
  }
  return out;
}

// 규격별 개수·길이 합계(처음 나온 순서). 규격을 모르는 줄은 빈 글자 규격으로 모인다.
class SpecTotal {
  final String spec;
  final int pieces;
  final double mm;
  const SpecTotal(this.spec, this.pieces, this.mm);
}

// 튜브 규격을 모르는 줄 수(규격을 지정하지 않은 채 저장하는 실수를 막는 데 쓴다).
int unknownSpecLineCount(List<ResultLine> lines) =>
    lines.where((l) => l.spec.isEmpty).length;

List<SpecTotal> specTotals(List<ResultLine> lines) {
  final order = <String>[];
  final pieces = <String, int>{};
  final mm = <String, double>{};
  for (final l in lines) {
    if (!pieces.containsKey(l.spec)) order.add(l.spec);
    pieces[l.spec] = (pieces[l.spec] ?? 0) + l.count;
    mm[l.spec] = (mm[l.spec] ?? 0) + l.totalMm;
  }
  return [for (final k in order) SpecTotal(k, pieces[k]!, mm[k]!)];
}

class ResultSummary {
  final int lineCount;
  final int totalPieces;
  final double totalMm;
  final int donePieces;
  final int doneLines;

  const ResultSummary({
    required this.lineCount,
    required this.totalPieces,
    required this.totalMm,
    required this.donePieces,
    required this.doneLines,
  });

  bool get anyDone => doneLines > 0;
  bool get allDone => lineCount > 0 && doneLines == lineCount;
  double get progress => totalPieces == 0 ? 0 : donePieces / totalPieces;
}

ResultSummary summarizeResult(List<ResultLine> lines, Set<String> done) {
  var pieces = 0, donePieces = 0, doneLines = 0;
  var mm = 0.0;
  for (final l in lines) {
    pieces += l.count;
    mm += l.totalMm;
    if (done.contains(l.key)) {
      donePieces += l.count;
      doneLines++;
    }
  }
  return ResultSummary(
    lineCount: lines.length,
    totalPieces: pieces,
    totalMm: mm,
    donePieces: donePieces,
    doneLines: doneLines,
  );
}

// 지금 목록에 없는(길이가 바뀌어 쓸모없어진) 표시는 버린다.
Set<String> pruneDone(Set<String> done, List<ResultLine> lines) {
  final live = {for (final l in lines) l.key};
  return done.where(live.contains).toSet();
}

// ── 필요한 부속 ──
class FittingUse {
  final String maker;
  final String spec;
  final String name;
  const FittingUse({
    required this.maker,
    required this.spec,
    required this.name,
  });
}

class FittingOrder {
  final String maker;
  final String spec;
  final String name;
  final int qty;
  const FittingOrder({
    required this.maker,
    required this.spec,
    required this.name,
    required this.qty,
  });

  // "Union Cross 1/2\"" (규격을 모르면 이름만)
  String get label => spec.isEmpty || spec == '미지정' ? name : '$name $spec';
}

// 같은 제조사·규격·이름끼리 모아 세트 수를 곱한다. 많은 것부터, 같으면 이름순.
List<FittingOrder> fittingOrderList(List<FittingUse> uses, int setMultiplier) {
  final set = setMultiplier < 1 ? 1 : setMultiplier;
  final counts = <String, int>{};
  final first = <String, FittingUse>{};
  for (final u in uses) {
    final k = '${u.maker}|${u.spec}|${u.name}';
    counts[k] = (counts[k] ?? 0) + 1;
    first.putIfAbsent(k, () => u);
  }
  final out = [
    for (final e in counts.entries)
      FittingOrder(
        maker: first[e.key]!.maker,
        spec: first[e.key]!.spec,
        name: first[e.key]!.name,
        qty: e.value * set,
      ),
  ];
  out.sort((a, b) {
    final c = b.qty.compareTo(a.qty);
    return c != 0 ? c : a.label.compareTo(b.label);
  });
  return out;
}

// ── 지시서 글 ──
String buildInstructionText({
  required String projectName,
  required DateTime date,
  required String maker,
  required int setMultiplier,
  required List<ResultLine> lines,
  required List<FittingOrder> orders,
  double kerfMm = 0,
}) {
  final set = setMultiplier < 1 ? 1 : setMultiplier;
  final d =
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  final b = StringBuffer();
  b.writeln('[컷팅 지시서] $projectName');
  b.writeln(
    '$d · $maker · $set세트${kerfMm > 0 ? ' · 톱날 ${fmtMm(kerfMm)}mm' : ''}',
  );
  b.writeln();
  b.writeln('■ 자를 길이');
  var pieces = 0;
  var mm = 0.0;
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    final what = l.title.contains('→')
        ? l.title
        : '${l.title.replaceAll(' mm', '')}mm';
    final len = l.title.contains('→') ? ' ${_one(l.cutMm)}mm' : '';
    final sp = l.spec.isEmpty ? '' : '${l.spec} ';
    // 묶은 줄은 개수가 어디서 나왔는지도 덧붙인다("구간 2개 × 3세트").
    final how = (l.grouped && l.sets > 1)
        ? ' (구간 ${l.baseCount}개 × ${l.sets}세트)'
        : '';
    b.writeln('${i + 1}) $sp$what$len × ${l.count}개$how');
    pieces += l.count;
    mm += l.totalMm;
  }
  if (lines.isEmpty) {
    b.writeln('(계산된 구간이 없습니다)');
  } else {
    b.writeln(
      set > 1
          ? '합계 1세트 ${_one(mm / set)}mm × $set세트 = ${_one(mm)}mm (총 $pieces개)'
          : '합계 ${_one(mm)}mm (총 $pieces개)',
    );
  }
  if (orders.isNotEmpty) {
    b.writeln();
    b.writeln('■ 필요한 부속');
    for (final o in orders) {
      b.writeln('${o.label} × ${o.qty}');
    }
  }
  return b.toString().trimRight();
}

// ── 저장 확인 ──
// "저장하기"를 누르면 보여 주는 확인 글. 무엇이 어디에 기록되는지, 입력이 비워지는지, 되돌릴 수
// 있는지를 저장하기 전에 알려 준다.
String buildSaveConfirmMessage({
  required double baseMm, // 톱날 손실을 뺀 1회 저장 길이(세트 수 곱한 값)
  required int cutCount, // 자를 구간 수(1세트 기준)
  required int setMultiplier,
  required double kerfLossMm,
  required List<FittingOrder> orders,
  required int notDoneLines, // 잘랐음 표시를 안 한 줄 수
  required bool anyDone, // 표시를 한 줄이 하나라도 있는지
  required bool recordsToProject, // 프로젝트 자재 사용량·기록에 올라가는지
  required bool canUndo,
  List<SpecTotal> specs = const [], // 규격별 합계(규격을 아는 것이 하나라도 있을 때 보여 준다)
  int unknownSpecLines = 0, // 튜브 규격을 모르는 줄 수
}) {
  final set = setMultiplier < 1 ? 1 : setMultiplier;
  final b = StringBuffer();
  // 1세트 길이 × 세트 수 = 합계 식으로 보여 준다(세트를 올려도 1세트 값은 그대로).
  if (set > 1) {
    b.writeln(
      '잘라 낸 길이는 1세트 ${_one(baseMm / set)}mm × $set세트 = ${_one(baseMm)}mm입니다 (구간 $cutCount개).',
    );
  } else {
    b.writeln('잘라 낸 길이는 총 ${_one(baseMm)}mm입니다 (구간 $cutCount개).');
  }
  if (kerfLossMm > 0) {
    b.writeln(
      '톱날 손실 ${_one(kerfLossMm)}mm가 더해져 누적 사용량에 ${_one(baseMm + kerfLossMm)}mm로 기록됩니다.',
    );
    // 🚀 [고침] 자재 사용량(재고 차감용)은 규격별 자른 길이만 쌓고 톱날 손실은
    // 넣지 않는다. 예전 글은 전부 더해진다고만 해서 실제와 달랐다.
    if (recordsToProject) {
      b.writeln('자재 사용량(빼기 대기)에는 톱날 손실을 넣지 않습니다.');
    }
  }
  if (specs.any((e) => e.spec.isNotEmpty)) {
    final t = specs
        .map((e) => '${e.spec.isEmpty ? '규격 미지정' : e.spec} ${_one(e.mm)}mm')
        .join(' · ');
    b.writeln('튜브 규격별: $t.');
  }
  if (unknownSpecLines > 0) {
    b.writeln('튜브 규격이 지정되지 않은 줄이 $unknownSpecLines개 있습니다.');
  }
  if (orders.isNotEmpty) {
    final shown = orders.take(3).map((o) => '${o.label} ×${o.qty}').join(' · ');
    final more = orders.length > 3 ? ' 외 ${orders.length - 3}종' : '';
    b.writeln('사용한 부속: $shown$more.');
  }
  if (anyDone && notDoneLines > 0) {
    b.writeln('아직 잘랐음 표시를 하지 않은 줄이 $notDoneLines개 있습니다.');
  }
  b.writeln();
  b.writeln(
    recordsToProject
        ? '저장하면 이 작업의 컷팅 기록과 자재 사용량(빼기 대기)에 올라가고, 입력이 비워집니다.'
        : '저장하면 누적 사용량에 더해지고, 입력이 비워집니다.',
  );
  if (canUndo) {
    b.write('저장한 뒤 10초 동안은 "실행 취소"로 되돌릴 수 있습니다.');
  }
  return b.toString().trimRight();
}
