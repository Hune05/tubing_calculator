// 🚀 [5번 강화, 신규] 컷팅 계산기는 원래 "이 구간을 몇 mm로 잘라야 하나"만
// 계산했지, "6m짜리 원자재 한 본에서 몇 개가 나오고, 전체 작업에 원자재가
// 몇 본 필요한가"는 전혀 계산해주지 않았다. 이 파일은 필요한 절단 길이
// 목록과 원자재(스톡) 길이를 받아, 최대한 적은 본수로 배치하는 계산을 한다.
//
// 배치는 세 단계로 한다.
//  1) 잔재(이전에 자르고 남겨 둔 것)이 있으면 거기에 먼저 넣는다.
//  2) 나머지는 긴 것부터 넣는 방법(FFD)과 가장 꼭 맞는 곳에 넣는 방법(BFD) 중
//     본수가 적은 쪽을 고른다.
//  3) 그래도 이론상 최소 본수보다 많고 조각이 많지 않으면(_kMaxExactPieces개
//     이하) 더 촘촘한 배치를 직접 찾아본다(계산량 한도가 있어서 오래 걸리지 않는다).

class StockBarPlan {
  final List<double> pieces = [];
  final double stockLength;
  // 새 원자재가 아니라 잔재에서 나온 배치인지.
  final bool isLeftover;
  // 첫 절단 전에 끝을 다듬어 버리는 길이(새 원자재만). 로스로 센다.
  final double trim;

  StockBarPlan(this.stockLength, {this.isLeftover = false, this.trim = 0});

  double get usedLength => pieces.fold(0.0, (sum, p) => sum + p);
  double get wasteLength => (stockLength - usedLength).clamp(0.0, stockLength);

  // 톱날 손실까지 뺀, 실제로 남는 길이(보수적으로 조각마다 한 번씩 뺀다).
  double remainderWithKerf(double kerf) =>
      (stockLength - usedLength - trim - kerf * pieces.length).clamp(
        0.0,
        stockLength,
      );
}

class CuttingOptimizationResult {
  // 새 원자재에서 나온 배치. 본수·로스·사용률은 모두 이것만 센다.
  final List<StockBarPlan> bars;
  // 잔재에서 나온 배치(조각이 하나라도 들어간 것만).
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
  // 여러 길이를 섞어 쓰면 본마다 길이가 다르니 각 본의 길이를 더한다.
  double get totalStock => bars.fold(0.0, (sum, b) => sum + b.stockLength);

  // 이 계산대로 자르고 나면 [minLength] 이상 잔재들의 길이.
  List<double> keepableScraps({double minLength = kMinLeftoverMm}) {
    final out = <double>[];
    for (final b in [...bars, ...leftoverBars]) {
      final r = b.remainderWithKerf(kerf);
      if (r >= minLength) out.add(r.floorToDouble());
    }
    return out;
  }
}

// 이보다 짧은 잔재는 쓸 데가 없다고 보고 남겨 두지 않는다.
const double kMinLeftoverMm = 300;

/// 원자재 길이가 여러 가지([stockLengths])일 때: 가장 긴 원자재로 배치한 뒤 각 본을
/// 들어갈 수 있는 가장 짧은 길이로 바꾸는 방법과, 한 가지 길이만 쓰는 방법들을
/// 모두 계산해서 원자재를 가장 적게 쓰는(같으면 본수가 적은) 쪽을 고른다.
CuttingOptimizationResult optimizeCuttingMixed({
  required List<double> pieces,
  required List<double> stockLengths,
  double kerf = 0.0,
  List<double> leftovers = const [],
  double endTrim = 0.0,
}) {
  final lens = ({...stockLengths.where((l) => l > 0)}.toList())..sort();
  if (lens.isEmpty) {
    throw ArgumentError('원자재 길이가 하나도 없습니다.');
  }
  final longest = optimizeCutting(
    pieces: pieces,
    stockLength: lens.last,
    kerf: kerf,
    leftovers: leftovers,
    endTrim: endTrim,
  );
  if (lens.length == 1) return longest;

  // 가장 긴 원자재 배치에서 본마다 들어갈 수 있는 가장 짧은 길이로 줄인다.
  final shrunk = <StockBarPlan>[];
  for (final b in longest.bars) {
    // 조각 하나짜리 본은 조각이 들어가기만 하면 된다(톱날은 남는 끝에서 먹는다).
    final need =
        endTrim +
        (b.pieces.length == 1
            ? b.pieces.first
            : b.pieces.fold(0.0, (s, p) => s + p + kerf));
    final fit = lens.firstWhere(
      (l) => need <= l + 1e-6,
      orElse: () => lens.last,
    );
    shrunk.add(StockBarPlan(fit, trim: endTrim)..pieces.addAll(b.pieces));
  }
  var best = CuttingOptimizationResult(
    bars: shrunk,
    leftoverBars: longest.leftoverBars,
    stockLength: lens.last,
    kerf: kerf,
    oversizedPieces: longest.oversizedPieces,
    savedBars: longest.savedBars,
  );

  bool better(CuttingOptimizationResult a, CuttingOptimizationResult b) {
    if ((a.totalStock - b.totalStock).abs() > 1e-6) {
      return a.totalStock < b.totalStock;
    }
    return a.barCount < b.barCount;
  }

  for (final l in lens.take(lens.length - 1)) {
    final single = optimizeCutting(
      pieces: pieces,
      stockLength: l,
      kerf: kerf,
      leftovers: leftovers,
      endTrim: endTrim,
    );
    // 짧은 길이 하나로는 못 자르는 조각이 더 생기면 비교하지 않는다(빠진 조각으로 싸 보이면 안 된다).
    if (single.oversizedPieces.length != longest.oversizedPieces.length) {
      continue;
    }
    if (better(single, best)) best = single;
  }
  return best;
}

const int _kMaxExactPieces = 24;
const int _kExactNodeLimit = 200000;

/// [pieces]는 필요한 절단 길이 하나하나(수량만큼 이미 펼쳐진 리스트)이다.
/// [kerf]는 절단 1회당 톱날 손실 - 원자재 안에서 조각을 하나 잘라낼 때마다
/// 그만큼 더 소모되는 것으로 보수적으로 계산한다(실제로는 마지막 조각엔
/// 손실이 없을 수도 있지만, 부족한 것보다 여유 있게 잡는 게 현장에 안전하다).
/// [leftovers]는 남아 있는 잔재 길이들(같은 규격만 넘긴다).
///
/// [endTrim]: 새 원자재마다 첫 절단 전에 끝을 다듬어 버리는 길이(찌그러진 끝·녹 등).
/// 잔재는 이미 톱으로 자른 끝이라 다듬지 않는다.
CuttingOptimizationResult optimizeCutting({
  required List<double> pieces,
  required double stockLength,
  double kerf = 0.0,
  List<double> leftovers = const [],
  double endTrim = 0.0,
}) {
  if (endTrim > 0 && endTrim < stockLength) {
    // 다듬은 만큼 짧은 원자재로 배치하고, 본은 원래 길이 + 다듬은 길이로 돌려놓는다.
    final r = optimizeCutting(
      pieces: pieces,
      stockLength: stockLength - endTrim,
      kerf: kerf,
      leftovers: leftovers,
    );
    return CuttingOptimizationResult(
      bars: [
        for (final b in r.bars)
          StockBarPlan(stockLength, trim: endTrim)..pieces.addAll(b.pieces),
      ],
      leftoverBars: r.leftoverBars,
      stockLength: stockLength,
      kerf: kerf,
      oversizedPieces: r.oversizedPieces,
      savedBars: r.savedBars,
    );
  }
  final List<double> oversized = [];
  final List<double> valid = [];
  // 원자재 한 본을 거의 통째로 쓰는 조각. 혼자 한 본에 들어가면 톱날 손실은
  // 남는 끝에서 먹으므로 받아 준다.
  // 🚀 [고침] 예전에는 6000 원자재에 6000 조각도 톱날 손실 때문에 '원자재보다
  // 길다'로 빠졌다.
  final List<double> wholeBar = [];
  for (final p in pieces) {
    if (p <= 0) continue;
    if (p > stockLength + 1e-6) {
      oversized.add(p);
    } else if (p + kerf > stockLength) {
      wholeBar.add(p);
    } else {
      valid.add(p);
    }
  }

  final sorted = [...valid]..sort((a, b) => b.compareTo(a));

  // 1) 잔재: 들어가는 곳 중 가장 꼭 맞는 곳에 넣는다.
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
  for (final p in wholeBar) {
    bars.add(StockBarPlan(stockLength)..pieces.add(p));
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

/// 본마다 조각 이름표(예: "PT1→PT2", 형강 항목 메모)를 붙인다. 같은 길이 조각은 서로
/// 바꿔도 되므로, 입력 순서대로 길이가 같은 이름표를 하나씩 가져간다.
/// [pieces]와 [labels]는 같은 순서·같은 개수(배치에 넘긴 조각 목록 그대로).
List<List<String>> labelsForBars(
  List<StockBarPlan> bars,
  List<double> pieces,
  List<String> labels,
) {
  final pool = <({double len, String label})>[
    for (var i = 0; i < pieces.length && i < labels.length; i++)
      (len: pieces[i], label: labels[i]),
  ];
  return [
    for (final b in bars)
      [
        for (final p in b.pieces)
          () {
            final i = pool.indexWhere((e) => (e.len - p).abs() < 1e-6);
            if (i < 0) return '';
            return pool.removeAt(i).label;
          }(),
      ],
  ];
}
