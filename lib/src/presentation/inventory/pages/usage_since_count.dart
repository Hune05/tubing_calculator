/// 지난 재고조사 뒤로 자재가 얼마나 드나들었는지.
///
/// 🚀 [추가] 현장에서는 일단 가져다 쓰고, 정확한 수량은 재고조사 때 맞춘다.
/// 그래서 재고조사 화면에서 "지난번 센 뒤로 얼마나 나갔나"를 같이 보여 준다.
/// 옛 기록에 남아 있는 불출도 나간 것으로 함께 센다.
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
    final head = hasLastCount ? '지난 재고조사 뒤' : '지금까지 기록상';
    if (inQty == 0) return '$head $out 나감';
    if (out == 0) return '$head $inQty 들어옴';
    return '$head $out 나가고 $inQty 들어옴';
  }
}

/// 기록을 자재별로 훑어 드나듦을 센다.
///
/// [logsNewestFirst]는 최근 것부터 온 기록(화면이 받는 그대로).
/// 자재마다 최근 것부터 세다가 '실사'(재고조사) 기록을 만나면 거기서 멈춘다.
/// 기록에 자재 문서 아이디(item_id)가 있으면 'id:아이디'로, 없으면(09-23 전 옛 기록) 이름으로 묶는다
/// (10-09: 이름으로만 묶어 같은 이름·다른 제조사 자재의 드나듦이 서로 섞였다). 화면은 [usageForItem]으로 읽는다.
Map<String, UsageSinceCount> usageSinceLastCount(
  List<Map<String, dynamic>> logsNewestFirst,
) {
  final out = <String, int>{};
  final into = <String, int>{};
  final stopped = <String>{};
  final seen = <String>{};

  for (final log in logsNewestFirst) {
    final itemId = (log['item_id'] ?? '').toString().trim();
    final material = (log['material_name'] ?? log['itemName'] ?? '')
        .toString()
        .trim();
    final name = itemId.isNotEmpty ? 'id:$itemId' : material;
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
    } else if (type == 'IN' || type == 'RETURN') {
      // 태블릿(PC) 반납은 'RETURN'으로 남는다. 예전엔 여기서 빠져 반납이 안 세졌다.
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

/// 자재 하나(문서 [docId], 이름 [name])의 드나듦. 아이디로 남은 기록을 세고, 아이디 없는 옛 기록은
/// 이름이 겹치지 않을 때만([nameShared]가 false) 더한다(겹치면 어느 자재 것인지 모른다).
/// 아이디 기록에 재고조사가 있으면 그보다 오래된 옛 기록은 세지 않는다.
UsageSinceCount? usageForItem(
  Map<String, UsageSinceCount> all, {
  required String docId,
  required String name,
  bool nameShared = false,
}) {
  final byId = docId.isEmpty ? null : all['id:$docId'];
  final byName = nameShared || (byId?.hasLastCount ?? false)
      ? null
      : all[name.trim()];
  if (byId == null) return byName;
  if (byName == null) return byId;
  return UsageSinceCount(
    out: byId.out + byName.out,
    inQty: byId.inQty + byName.inQty,
    hasLastCount: byName.hasLastCount,
  );
}
