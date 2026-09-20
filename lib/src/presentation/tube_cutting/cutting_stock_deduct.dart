// 컷팅에서 쓴 자재를 창고 재고에서 뺄 때의 셈. 화면과 떼어 놓아서 검사할 수 있게 한다.

/// 뺄 자재 한 줄. 이름은 재고의 자재 이름과 같아야 찾을 수 있다.
class StockTake {
  final String name; // 재고에서 찾을 이름 (예: [HY-LOK] 3/8" Union)
  final int qty; // 뺄 개수(튜브는 본수)
  final String unit; // 본 / EA
  final String spec; // 규격 (재고에 없으면 알려 줄 때 쓴다)

  const StockTake({
    required this.name,
    required this.qty,
    required this.unit,
    this.spec = '',
  });
}

/// 튜브 한 본의 길이(mm). 이 길이로 올려 셈한다.
const int kTubeBarMm = 6000;

/// 컷팅 작업에 쌓인 사용량(materials)을 "뺄 자재 줄"로 바꾼다.
/// 튜브는 쓴 길이를 한 본 길이로 나눠 올림하고, 피팅은 개수를 그대로 쓴다.
List<StockTake> stockTakesFromMaterials(List<dynamic> materials) {
  final out = <StockTake>[];
  for (final raw in materials) {
    if (raw is! Map) continue;
    final m = raw;
    final isTube = m['type'] == 'TUBE';
    final name = (m['db_name'] ?? m['name'] ?? '').toString().trim();
    if (name.isEmpty) continue;

    final int qty = isTube
        ? _ceilDiv(((m['qty_mm'] as num?) ?? 0).round(), kTubeBarMm)
        : ((m['qty_ea'] as num?) ?? 0).round();
    if (qty <= 0) continue;

    out.add(
      StockTake(
        name: name,
        qty: qty,
        unit: isTube ? '본' : 'EA',
        spec: (m['spec'] ?? '').toString(),
      ),
    );
  }
  return out;
}

int _ceilDiv(int a, int b) {
  if (b <= 0 || a <= 0) return 0;
  return (a + b - 1) ~/ b;
}

/// 차감 결과. 뺀 것과, 재고에 없어서 못 뺀 것을 나눠 알려 준다.
class StockDeductResult {
  final List<StockTake> done; // 뺀 자재
  final List<StockTake> missing; // 재고에 그 이름이 없는 자재

  const StockDeductResult({required this.done, required this.missing});

  bool get allDone => missing.isEmpty;

  /// 다 끝난 뒤 화면에 보여 줄 글.
  String get message {
    if (done.isEmpty && missing.isEmpty) return "차감할 자재가 없습니다.";
    if (missing.isEmpty) return "자재 ${done.length}건을 재고에서 차감했습니다.";
    if (done.isEmpty) {
      return "재고에 없는 자재 ${missing.length}건입니다. 자재 목록에서 먼저 넣으십시오.";
    }
    return "자재 ${done.length}건을 차감했습니다."
        " ${missing.length}건은 재고에 없어 그대로 뒀습니다.";
  }
}
