// 한 구간의 절단 길이 계산. 화면(_calculate)에서 옮겨 와 테스트로 지킨다.
// 절단 길이 = 중심 간 거리(c2c) - 양쪽 피팅 공제값. 공제값은 항상 mm 기준이라
// 입력이 인치면 먼저 mm로 바꾼다. 결과가 음수면 피팅끼리 간섭한다는 뜻이다.

const double kInchToMm = 25.4;

double cutLengthMm({
  required double c2cInput,
  required bool inputIsInch,
  required double startDeduction,
  required double endDeduction,
}) {
  final c2c = inputIsInch ? c2cInput * kInchToMm : c2cInput;
  return c2c - startDeduction - endDeduction;
}

// ── 길이 입력 해석 ──
// 길이 칸에 쓴 글자를 숫자로 읽는다. 폰 숫자 키패드에는 쉼표(,)가 있어서 "1200,5"처럼
// 쓰면 예전에는 읽지 못하고 조용히 0으로 계산했다. 이제는
//  - 공백은 무시하고,
//  - "1,200"처럼 세 자리씩 끊은 쉼표는 자릿수 구분으로 보고("1,500" = 1500),
//  - 그 밖의 쉼표 하나는 소수점으로 보고("1200,5" = 1200.5),
//  - 그래도 못 읽으면 못 읽었다고 알려 준다(음수·글자·점이 둘 이상인 값 등).
class LengthParse {
  final double? value; // 읽은 값. 비었거나 못 읽었으면 null
  final bool empty;
  bool get unreadable => !empty && value == null;

  const LengthParse.empty() : value = null, empty = true;
  const LengthParse.ok(double v) : value = v, empty = false;
  const LengthParse.bad() : value = null, empty = false;
}

LengthParse parseLengthInput(String raw) {
  var t = raw.replaceAll(RegExp(r'\s+'), '');
  if (t.isEmpty) return const LengthParse.empty();
  if (RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(t)) {
    t = t.replaceAll(',', '');
  } else if (RegExp(r'^\d*,\d+$').hasMatch(t)) {
    t = t.replaceFirst(',', '.');
  }
  if (!RegExp(r'^(\d+\.?\d*|\.\d+)$').hasMatch(t)) {
    return const LengthParse.bad();
  }
  final v = double.tryParse(t);
  if (v == null || !v.isFinite || v > 1e9) return const LengthParse.bad();
  return LengthParse.ok(v);
}

// ── 절단 길이 계산 과정 글자 ──
// "절단 2588.0mm = 2600 − 6 − 6" 처럼 어떻게 나온 값인지 보여 준다.
// 정수에 가까우면 소수점을 생략하고, 공제값이 음수면 더하기로 쓴다.
String fmtMm(double v) => (v - v.roundToDouble()).abs() < 0.05
    ? '${v.round()}'
    : v.toStringAsFixed(1);

// 화면·글에 쓰는 무게(kg) 표기. 100kg 미만은 소수 한 자리, 이상은 정수.
String fmtKg(double kg) =>
    kg >= 100 ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);

String cutBreakdownText({
  required double c2cMm,
  required double startDeduction,
  required double endDeduction,
}) {
  final cut = c2cMm - startDeduction - endDeduction;
  final head = '절단 ${cut.toStringAsFixed(1)}mm';
  final parts = <String>[fmtMm(c2cMm)];
  for (final d in [startDeduction, endDeduction]) {
    if (d == 0) continue;
    parts.add(d > 0 ? '− ${fmtMm(d)}' : '+ ${fmtMm(-d)}');
  }
  return parts.length == 1 ? head : '$head = ${parts.join(' ')}';
}

// ── 배치도 계산 ──

// 배치도에서 구간 선의 세로 길이. 가장 긴 구간이 [max], 짧을수록 [min]에 가깝게 그려서
// 길이 차이가 눈에 보이게 한다. 치수가 없거나 0 이하면 [min].
double segmentHeight(
  double? cutMm,
  double maxCutMm, {
  double min = 56,
  double max = 128,
}) {
  if (cutMm == null || cutMm <= 0 || maxCutMm <= 0) return min;
  final ratio = (cutMm / maxCutMm).clamp(0.0, 1.0);
  return min + (max - min) * ratio;
}

// 각 지점이 라인 시작에서 얼마나 떨어져 있는지(중심 간 거리를 이어 더한 값).
// [c2cMm]은 구간별 중심 간 거리이고, 없으면 null. 결과 길이는 구간 수 + 1이고
// 첫 지점은 0이다. 앞쪽 구간 하나라도 값이 없으면 그 뒤 지점은 알 수 없어 null.
List<double?> cumulativePositions(List<double?> c2cMm) {
  final out = <double?>[0.0];
  for (final v in c2cMm) {
    final prev = out.last;
    out.add(prev == null || v == null ? null : prev + v);
  }
  return out;
}

// "유니온 ×2 · 엘보 ×1" — 같은 이름을 세고 많은 것부터 나열한다(같으면 이름순).
String fittingCountsText(List<String> names) {
  final counts = <String, int>{};
  for (final n in names) {
    if (n.trim().isEmpty) continue;
    counts[n] = (counts[n] ?? 0) + 1;
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final c = counts[b]!.compareTo(counts[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  return keys.map((k) => '$k ×${counts[k]}').join(' · ');
}
