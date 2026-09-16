// 🚀 [5번 강화, 신규] 컷팅 계산기는 원래 "이 구간을 몇 mm로 잘라야 하나"만
// 계산했지, "6m짜리 원자재 한 본에서 몇 개가 나오고, 전체 작업에 원자재가
// 몇 본 필요한가"는 전혀 계산해주지 않았다. 이 파일은 필요한 절단 길이
// 목록과 원자재(스톡) 길이를 받아, 최대한 적은 본수로 배치하는 간단한
// First-Fit-Decreasing(FFD) 빈 패킹을 계산한다.

class StockBarPlan {
  final List<double> pieces = [];
  final double stockLength;

  StockBarPlan(this.stockLength);

  double get usedLength => pieces.fold(0.0, (sum, p) => sum + p);
  double get wasteLength => (stockLength - usedLength).clamp(0.0, stockLength);
}

class CuttingOptimizationResult {
  final List<StockBarPlan> bars;
  final double stockLength;
  final double kerf;
  final List<double> oversizedPieces;

  const CuttingOptimizationResult({
    required this.bars,
    required this.stockLength,
    required this.kerf,
    required this.oversizedPieces,
  });

  int get barCount => bars.length;
  double get totalUsed => bars.fold(0.0, (sum, b) => sum + b.usedLength);
  double get totalWaste => bars.fold(0.0, (sum, b) => sum + b.wasteLength);
  double get totalStock => bars.length * stockLength;
}

/// [pieces]는 필요한 절단 길이 하나하나(수량만큼 이미 펼쳐진 리스트)이다.
/// [kerf]는 절단 1회당 톱날 손실 - 원자재 안에서 조각을 하나 잘라낼 때마다
/// 그만큼 더 소모되는 것으로 보수적으로 계산한다(실제로는 마지막 조각엔
/// 손실이 없을 수도 있지만, 부족한 것보다 여유 있게 잡는 게 현장에 안전하다).
CuttingOptimizationResult optimizeCutting({
  required List<double> pieces,
  required double stockLength,
  double kerf = 0.0,
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
  final List<StockBarPlan> bars = [];

  for (final length in sorted) {
    final double need = length + kerf;
    StockBarPlan? target;
    for (final bar in bars) {
      if (bar.usedLength + need <= stockLength + 1e-6) {
        target = bar;
        break;
      }
    }
    if (target == null) {
      target = StockBarPlan(stockLength);
      bars.add(target);
    }
    target.pieces.add(length);
  }

  return CuttingOptimizationResult(
    bars: bars,
    stockLength: stockLength,
    kerf: kerf,
    oversizedPieces: oversized,
  );
}
