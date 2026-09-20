/// 지난 재고조사 뒤로 자재가 얼마나 드나들었는지.
///
/// 🚀 [추가] 현장에서는 일단 가져다 쓰고, 정확한 수량은 재고조사 때 맞춘다.
/// 그래서 재고조사 화면에서 "지난번 센 뒤로 얼마나 나갔나"를 같이 보여 준다.
/// 불출과 컷팅 차감이 겹쳐 두 번 빠졌는지도 여기서 눈에 띈다.
library;

/// 자재 하나의 드나듦.
class UsageSinceCount {
  /// 나간 양(불출·컷팅 사용·형강 재단).
  final int out;

  /// 들어온 양(반납·차감 되돌림).
  final int inQty;

  /// 지난 재고조사 기록이 있었는지. 없으면 기록 전체를 센 것이다.
  final bool hasLastCount;

  const UsageSinceCount({
    required this.out,
    required this.inQty,
    required this.hasLastCount,
  });

  /// 순수하게 줄어든 양.
  int get net => out - inQty;

  bool get isEmpty => out == 0 && inQty == 0;

  /// 재고조사 화면에 붙일 한 줄.
  String get note {
    if (isEmpty) return '';
    final head = hasLastCount ? '지난 재고조사 뒤' : '기록에 남은 것만';
    if (inQty == 0) return '$head $out 나감';
    if (out == 0) return '$head $inQty 들어옴';
    return '$head $out 나가고 $inQty 들어옴';
  }
}

/// 기록을 자재별로 훑어 드나듦을 센다.
///
/// [logsNewestFirst]는 최근 것부터 온 기록(화면이 받는 그대로).
/// 자재마다 최근 것부터 세다가 '실사'(재고조사) 기록을 만나면 거기서 멈춘다.
Map<String, UsageSinceCount> usageSinceLastCount(
  List<Map<String, dynamic>> logsNewestFirst,
) {
  final out = <String, int>{};
  final into = <String, int>{};
  final stopped = <String>{};
  final seen = <String>{};

  for (final log in logsNewestFirst) {
    final name = (log['material_name'] ?? log['itemName'] ?? '')
        .toString()
        .trim();
    if (name.isEmpty) continue;
    seen.add(name);
    if (stopped.contains(name)) continue;

    final action = (log['action'] ?? '').toString();
    // 재고조사(실사)를 만나면 그 자재는 여기까지만 센다.
    if (action.contains('실사') || action.contains('재고조사')) {
      stopped.add(name);
      continue;
    }
    // 자재를 새로 넣기만 한 기록은 드나듦이 아니다.
    if (action.contains('등록') || action.contains('삭제')) continue;

    final qty = (log['qty'] as num?)?.toInt() ?? 0;
    if (qty <= 0) continue;

    final type = (log['type'] ?? '').toString();
    if (type == 'OUT') {
      out[name] = (out[name] ?? 0) + qty;
    } else if (type == 'IN') {
      into[name] = (into[name] ?? 0) + qty;
    }
  }

  return {
    for (final name in seen)
      if ((out[name] ?? 0) != 0 || (into[name] ?? 0) != 0)
        name: UsageSinceCount(
          out: out[name] ?? 0,
          inQty: into[name] ?? 0,
          hasLastCount: stopped.contains(name),
        ),
  };
}
