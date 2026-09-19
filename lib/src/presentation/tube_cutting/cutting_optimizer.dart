// 🚀 [5번 강화, 신규] 컷팅 계산기는 원래 "이 구간을 몇 mm로 잘라야 하나"만
// 계산했지, "6m짜리 원자재 한 본에서 몇 개가 나오고, 전체 작업에 원자재가
// 몇 본 필요한가"는 전혀 계산해주지 않았다. 이 파일은 필요한 절단 길이
// 목록과 원자재(스톡) 길이를 받아, 최대한 적은 본수로 배치하는 계산을 한다.
//
// 배치는 세 단계로 한다.
//  1) 남은 토막(이전에 자르고 남겨 둔 것)이 있으면 거기에 먼저 넣는다.
//  2) 나머지는 긴 것부터 넣는 방법(FFD)과 가장 꼭 맞는 곳에 넣는 방법(BFD) 중
//     본수가 적은 쪽을 고른다.
//  3) 그래도 이론상 최소 본수보다 많고 조각이 많지 않으면(_kMaxExactPieces개
//     이하) 더 촘촘한 배치를 직접 찾아본다(계산량 한도가 있어서 오래 걸리지 않는다).

class StockBarPlan {
  final List<double> pieces = [];
  final double stockLength;
  // 새 원자재가 아니라 남은 토막에서 나온 배치인지.
  final bool isLeftover;

  StockBarPlan(this.stockLength, {this.isLeftover = false});

  double get usedLength => pieces.fold(0.0, (sum, p) => sum + p);
  double get wasteLength => (stockLength - usedLength).clamp(0.0, stockLength);

  // 톱날 손실까지 뺀, 실제로 남는 길이(보수적으로 조각마다 한 번씩 뺀다).
  double remainderWithKerf(double kerf) =>
      (stockLength - usedLength - kerf * pieces.length).clamp(0.0, stockLength);
}

class CuttingOptimizationResult {
  // 새 원자재에서 나온 배치. 본수·로스·사용률은 모두 이것만 센다.
  final List<StockBarPlan> bars;
  // 남은 토막에서 나온 배치(조각이 하나라도 들어간 것만).
  final List<StockBarPlan> leftoverBars;
  final double stockLength;
  final double kerf;
  final List<double> oversizedPieces;
  // 기본 방법(FFD)보다 몇 본을 줄였는지.
  final int savedBars;

  const CuttingOptimizationResult({
    required this.bars,
    required this.stockLength,
    required this.kerf,
    required this.oversizedPieces,
    this.leftoverBars = const [],
    this.savedBars = 0,
  });

  int get barCount => bars.length;
  double get totalUsed => bars.fold(0.0, (sum, b) => sum + b.usedLength);
  double get totalWaste => bars.fold(0.0, (sum, b) => sum + b.wasteLength);
  double get totalStock => bars.length * stockLength;

  // 이 계산대로 자르고 나면 [minLength] 이상 남는 토막들의 길이.
  List<double> keepableScraps({double minLength = kMinLeftoverMm}) {
    final out = <double>[];
    for (final b in [...bars, ...leftoverBars]) {
      final r = b.remainderWithKerf(kerf);
      if (r >= minLength) out.add(r.floorToDouble());
    }
    return out;
  }
}

// 이보다 짧은 토막은 쓸 데가 없다고 보고 남겨 두지 않는다.
const double kMinLeftoverMm = 300;

const int _kMaxExactPieces = 24;
const int _kExactNodeLimit = 200000;

/// [pieces]는 필요한 절단 길이 하나하나(수량만큼 이미 펼쳐진 리스트)이다.
/// [kerf]는 절단 1회당 톱날 손실 - 원자재 안에서 조각을 하나 잘라낼 때마다
/// 그만큼 더 소모되는 것으로 보수적으로 계산한다(실제로는 마지막 조각엔
/// 손실이 없을 수도 있지만, 부족한 것보다 여유 있게 잡는 게 현장에 안전하다).
/// [leftovers]는 남아 있는 토막 길이들(같은 규격만 넘긴다).
CuttingOptimizationResult optimizeCutting({
  required List<double> pieces,
  required double stockLength,
  double kerf = 0.0,
  List<double> leftovers = const [],
}) {
  final List<double> oversized = [];
  final List<double> valid = [];
  for (final p in pieces) {
    if (p <= 0) continue;
    if (p + kerf > stockLength) {
      oversized.add(p);
    } else {
      valid.add(p);
    }
  }

  final sorted = [...valid]..sort((a, b) => b.compareTo(a));

  // 1) 남은 토막: 들어가는 곳 중 가장 꼭 맞는 곳에 넣는다.
  final leftoverPlans = ([
    ...leftovers.where((l) => l > 0),
  ]..sort()).map((l) => StockBarPlan(l, isLeftover: true)).toList();
  final rest = <double>[];
  for (final length in sorted) {
    final need = length + kerf;
    StockBarPlan? best;
    double bestRoom = double.infinity;
    for (final bar in leftoverPlans) {
      final room = bar.stockLength - bar.usedLength - kerf * bar.pieces.length;
      if (need <= room + 1e-6 && room - need < bestRoom) {
        best = bar;
        bestRoom = room - need;
      }
    }
    if (best == null) {
      rest.add(length);
    } else {
      best.pieces.add(length);
    }
  }

  // 2)·3) 나머지는 새 원자재에 배치한다.
  final ffd = _pack(rest, stockLength, kerf, bestFit: false);
  var bestBins = ffd;
  final bfd = _pack(rest, stockLength, kerf, bestFit: true);
  if (bfd.length < bestBins.length) bestBins = bfd;

  final needTotal = rest.fold(0.0, (s, p) => s + p + kerf);
  final lowerBound = (needTotal / stockLength - 1e-9).ceil();
  if (bestBins.length > lowerBound && rest.length <= _kMaxExactPieces) {
    final budget = _Budget(_kExactNodeLimit);
    while (bestBins.length > lowerBound && !budget.exhausted) {
      final found = _search(
        rest,
        stockLength,
        kerf,
        bestBins.length - 1,
        budget,
      );
      if (found == null) break;
      bestBins = found;
    }
  }

  final bars = <StockBarPlan>[];
  for (final b in bestBins) {
    bars.add(StockBarPlan(stockLength)..pieces.addAll(b));
  }

  return CuttingOptimizationResult(
    bars: bars,
    leftoverBars: leftoverPlans.where((b) => b.pieces.isNotEmpty).toList(),
    stockLength: stockLength,
    kerf: kerf,
    oversizedPieces: oversized,
    savedBars: ffd.length - bars.length,
  );
}

List<List<double>> _pack(
  List<double> sorted,
  double cap,
  double kerf, {
  required bool bestFit,
}) {
  final bins = <List<double>>[];
  final used = <double>[];
  for (final length in sorted) {
    final need = length + kerf;
    int target = -1;
    double bestRoom = double.infinity;
    for (int i = 0; i < bins.length; i++) {
      final room = cap - used[i];
      if (need <= room + 1e-6) {
        if (!bestFit) {
          target = i;
          break;
        }
        if (room - need < bestRoom) {
          bestRoom = room - need;
          target = i;
        }
      }
    }
    if (target == -1) {
      bins.add([]);
      used.add(0.0);
      target = bins.length - 1;
    }
    bins[target].add(length);
    used[target] += need;
  }
  return bins;
}

class _Budget {
  int left;
  bool exhausted = false;
  _Budget(this.left);
}

// [maxBins]본 이하로 모두 들어가는 배치를 찾는다(없거나 한도를 넘으면 null).
List<List<double>>? _search(
  List<double> sorted,
  double cap,
  double kerf,
  int maxBins,
  _Budget budget,
) {
  final n = sorted.length;
  final need = [for (final p in sorted) p + kerf];
  final room = <double>[];
  final bins = <List<double>>[];
  final placedIn = List<int>.filled(n, -1);

  bool dfs(int i) {
    if (i == n) return true;
    if (--budget.left < 0) {
      budget.exhausted = true;
      return false;
    }
    // 같은 길이 조각은 앞의 조각보다 앞쪽 원자재에 넣지 않는다(같은 배치를 또 보지 않게).
    final int from = (i > 0 && need[i] == need[i - 1]) ? placedIn[i - 1] : 0;
    final seen = <int>{};
    for (int j = from; j < bins.length; j++) {
      if (need[i] > room[j] + 1e-6) continue;
      if (!seen.add((room[j] * 1000).round())) continue;
      room[j] -= need[i];
      bins[j].add(sorted[i]);
      placedIn[i] = j;
      if (dfs(i + 1)) return true;
      bins[j].removeLast();
      room[j] += need[i];
      if (budget.exhausted) return false;
    }
    if (bins.length < maxBins) {
      room.add(cap - need[i]);
      bins.add([sorted[i]]);
      placedIn[i] = bins.length - 1;
      if (dfs(i + 1)) return true;
      bins.removeLast();
      room.removeLast();
    }
    return false;
  }

  return dfs(0) ? bins : null;
}
