// 재고에서 빼기 전에, 이름이 같은 재고(제조사만 다른 것)가 여럿이면 어느 것에서 뺄지 묻는 창(10-09).
// 고른 것은 작업마다 폰에 기억해서 다음에 물을 때 미리 골라 두고, 되돌리기도 같은 재고로 넣는다.
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'cutting_stock_deduct.dart';

/// 고른 결과.
class StockPicks {
  /// 다듬은 자재 이름 → 고른 재고 문서 id(빼기·되돌리기에 넘긴다).
  final Map<String, String> ids;

  /// 뺄 자재 이름 → 고른 재고(확인창에 보인다).
  final Map<String, StockChoice> chosen;
  const StockPicks({this.ids = const {}, this.chosen = const {}});

  static const StockPicks none = StockPicks();

  /// 확인창 줄에 붙일 글(뺄 자재 이름 → "삼화 · A창고").
  Map<String, String> get labels => {
    for (final e in chosen.entries) e.key: e.value.short,
  };

  /// 창고 수량 표(자재 이름 → 수량)를 고른 재고의 수량으로 바꾼 것(모자람 알림이 맞게).
  Map<String, int> applyQty(Map<String, int> qtyByName) {
    if (chosen.isEmpty) return qtyByName;
    final out = Map<String, int>.of(qtyByName);
    final lookup = materialLookup(out.keys.toList(), (k) => k);
    for (final e in chosen.entries) {
      final key = findMaterial(lookup, e.key) ?? e.key;
      out[key] = e.value.qty;
    }
    return out;
  }
}

/// 이름이 같은 재고가 여럿인 자재가 있으면 고르게 한다. 없으면 묻지 않고 [StockPicks.none].
/// 취소하면 null(빼지 않는다). [load]는 시험에서 재고 읽기를 바꿔 넣는다.
Future<StockPicks?> askSameNameStock(
  BuildContext context,
  List<StockTake> takes, {
  required String jobKey,
  Future<Map<String, List<StockChoice>>> Function(List<StockTake>)? load,
}) async {
  final choices = await (load ?? loadSameNameChoices)(takes);
  if (choices.isEmpty) return StockPicks.none;
  final remembered = await loadStockPicks(jobKey);
  if (!context.mounted) return null;

  // 기억한 것이 아직 있으면 그것, 없으면 수량 많은 것을 미리 골라 둔다.
  final sel = <String, String>{
    for (final e in choices.entries)
      e.key:
          e.value.any((c) => c.id == remembered[normalizeMaterialName(e.key)])
          ? remembered[normalizeMaterialName(e.key)]!
          : e.value.first.id,
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        key: const Key('stock_pick_dialog'),
        title: const Text('뺄 재고 고르기'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이름이 같은 재고가 여럿입니다. 뺄 것을 고르십시오. 고른 것은 이 작업에 기억합니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSub,
                    height: 1.4,
                  ),
                ),
                for (final e in choices.entries) ...[
                  const SizedBox(height: 14),
                  Text(
                    e.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final c in e.value)
                    ListTile(
                      key: Key('stock_pick_${c.id}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        sel[e.key] == c.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: sel[e.key] == c.id
                            ? AppColors.brand
                            : AppColors.textSub,
                      ),
                      title: Text(
                        c.maker.isEmpty ? '제조사 없음' : c.maker,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          if (c.location.isNotEmpty) '위치 ${c.location}',
                          '수량 ${c.qty}${c.unit}',
                        ].join(' · '),
                      ),
                      onTap: () => setLocal(() => sel[e.key] = c.id),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('stock_pick_ok'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('다음'),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return null;
  final ids = <String, String>{};
  final chosen = <String, StockChoice>{};
  for (final e in choices.entries) {
    final c = e.value.firstWhere((c) => c.id == sel[e.key]);
    ids[normalizeMaterialName(e.key)] = c.id;
    chosen[e.key] = c;
  }
  await saveStockPicks(jobKey, ids);
  return StockPicks(ids: ids, chosen: chosen);
}
