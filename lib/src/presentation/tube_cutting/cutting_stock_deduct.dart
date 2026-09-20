import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// 튜브 한 본의 기본 길이(mm).
/// 자재마다 길이가 다르면 [barLengthByName]으로 따로 넘긴다.
const int kTubeBarMm = 6000;

/// 자재 문서에 적힌 한 본 길이(mm)를 읽는다. 없으면 기본값 6000.
int barLengthOf(Map<String, dynamic>? data) {
  final v = (data?['barLengthMm'] as num?)?.toInt() ?? 0;
  return v > 0 ? v : kTubeBarMm;
}

/// 컷팅 작업에 쌓인 사용량(materials)을 "뺄 자재 줄"로 바꾼다.
/// 튜브는 쓴 길이를 한 본 길이로 나눠 올림하고, 피팅은 개수를 그대로 쓴다.
/// [barLengthByName]에 자재 이름별 한 본 길이가 있으면 그 길이로 나눈다
/// (3m·8m짜리 원자재를 6m로 나누던 것을 막는다).
/// [unitByName]에 자재를 세는 단위가 있으면 그 단위로 뺀다.
/// 🚀 [고침] 창고에서 미터로 세는 자재도 무조건 본으로 뺐다. 6m 한 본을
/// 쓰면 "2m"짜리 재고에서 2가 아니라 1이 빠져 재고가 안 맞았다.
List<StockTake> stockTakesFromMaterials(
  List<dynamic> materials, {
  Map<String, int>? barLengthByName,
  Map<String, String>? unitByName,
}) {
  final out = <StockTake>[];
  for (final raw in materials) {
    if (raw is! Map) continue;
    final m = raw;
    final isTube = m['type'] == 'TUBE';
    final name = (m['db_name'] ?? m['name'] ?? '').toString().trim();
    if (name.isEmpty) continue;

    final stockUnit = (unitByName?[name] ?? '').trim();
    final mm = ((m['qty_mm'] as num?) ?? 0).round();

    int qty;
    String unit;
    if (!isTube) {
      qty = ((m['qty_ea'] as num?) ?? 0).round();
      unit = stockUnit.isEmpty ? 'EA' : stockUnit;
    } else if (stockUnit == 'm') {
      qty = _ceilDiv(mm, 1000);
      unit = 'm';
    } else {
      qty = _ceilDiv(mm, barLengthByName?[name] ?? kTubeBarMm);
      unit = stockUnit.isEmpty ? '본' : stockUnit;
    }
    if (qty <= 0) continue;

    out.add(
      StockTake(
        name: name,
        qty: qty,
        unit: unit,
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

/// 창고 재고에 적힌 자재별 한 본 길이(mm)와 세는 단위.
class StockInfo {
  /// 자재 이름 → 한 본 길이(mm). 적혀 있지 않은 자재는 빠진다(기본 6000).
  final Map<String, int> barLengthByName;

  /// 자재 이름 → 세는 단위(본·m·EA 등).
  final Map<String, String> unitByName;

  /// 자재 이름 → 지금 창고에 있는 수량.
  final Map<String, int> qtyByName;

  const StockInfo({
    this.barLengthByName = const {},
    this.unitByName = const {},
    this.qtyByName = const {},
  });
}

/// 뺄 자재 가운데 창고에 모자란 것을 알려 준다.
/// 🚀 [고침] 예전에는 빼고 나서야 재고가 마이너스가 된 것을 알았다.
/// 재단 계획을 짤 때 미리 보고 자재를 챙길 수 있게 한다.
String shortStockWarning(List<StockTake> takes, Map<String, int> stockQty) {
  final lines = <String>[];
  for (final t in takes) {
    final name = t.name.trim();
    if (!stockQty.containsKey(name)) continue;
    final have = stockQty[name] ?? 0;
    if (have >= t.qty) continue;
    lines.add("${t.name}: ${t.qty}${t.unit} 필요 · 창고에 $have${t.unit}");
  }
  if (lines.isEmpty) return '';
  return "창고에 모자란 자재가 있습니다.\n"
      "${lines.join('\n')}\n"
      "먼저 챙겨 두십시오.";
}

/// 창고 재고에서 한 본 길이와 세는 단위를 한 번에 읽어 온다.
Future<StockInfo> loadStockInfo() async {
  try {
    final snap = await FirebaseFirestore.instance.collection('inventory').get();
    final bars = <String, int>{};
    final units = <String, String>{};
    final qty = <String, int>{};
    for (final d in snap.docs) {
      final name = (d.data()['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      final len = (d.data()['barLengthMm'] as num?)?.toInt() ?? 0;
      if (len > 0) bars[name] = len;
      final unit = (d.data()['unit'] as String?)?.trim() ?? '';
      if (unit.isNotEmpty) units[name] = unit;
      qty[name] = (d.data()['qty'] as num?)?.toInt() ?? 0;
    }
    return StockInfo(
      barLengthByName: bars,
      unitByName: units,
      qtyByName: qty,
    );
  } catch (_) {
    return const StockInfo();
  }
}

/// 아직 반납하지 않은 불출 수량을 자재 이름별로 읽어 온다.
/// 🚀 [고침] 창고에서 불출로 이미 빼 간 자재를 컷팅에서 또 빼면 재고가
/// 두 번 줄어든다. 빼기 전에 이 목록을 보여 주고 사람이 판단하게 한다.
Future<Map<String, int>> loadOpenCheckouts() async {
  try {
    final snap = await FirebaseFirestore.instance.collection('checkouts').get();
    final out = <String, int>{};
    for (final d in snap.docs) {
      final name = (d.data()['itemName'] as String?)?.trim() ?? '';
      final qty = (d.data()['checkoutQty'] as num?)?.toInt() ?? 0;
      if (name.isEmpty || qty <= 0) continue;
      out[name] = (out[name] ?? 0) + qty;
    }
    return out;
  } catch (_) {
    return const {};
  }
}

/// 뺄 자재 가운데 아직 불출 중인 것만 골라 알림 글을 만든다.
/// 불출 중인 것이 없으면 빈 글을 돌려준다.
String doubleDeductWarning(
  List<StockTake> takes,
  Map<String, int> openCheckouts,
) {
  final lines = <String>[];
  for (final t in takes) {
    final held = openCheckouts[t.name.trim()] ?? 0;
    if (held > 0) lines.add("${t.name} $held${t.unit}");
  }
  if (lines.isEmpty) return '';
  return "아래 자재는 불출로 이미 나가 있습니다.\n"
      "${lines.join('\n')}\n"
      "그 자재로 자른 것이면 여기서 또 빼면 재고가 두 번 줍니다.";
}

/// 차감 결과. 뺀 것과, 재고에 없어서 못 뺀 것을 나눠 알려 준다.
class StockDeductResult {
  final List<StockTake> done; // 뺀 자재
  final List<StockTake> missing; // 재고에 그 이름이 없는 자재
  /// 빼고 나면 재고가 음수가 되는 자재. 이름 → 뺀 뒤 남는 수량(음수).
  final Map<String, int> negative;

  /// 통신이 안 돼 재고 목록을 서버에서 받지 못했다(폰에 있던 것으로 맞춰 봤다).
  final bool offline;

  const StockDeductResult({
    required this.done,
    required this.missing,
    this.negative = const {},
    this.offline = false,
  });

  bool get allDone => missing.isEmpty;

  /// 다 끝난 뒤 화면에 보여 줄 글.
  String get message {
    if (done.isEmpty && missing.isEmpty) return "차감할 자재가 없습니다.";

    final tail = StringBuffer();
    if (negative.isNotEmpty) {
      tail.write(" ${negative.length}건은 재고보다 많이 빼서 마이너스가 됐습니다.");
    }

    // 통신이 안 될 때는 "재고에 없다"고 잘라 말하면 안 된다. 폰에 안 받아진
    // 자재일 수 있으므로 그대로 두고 통신되면 다시 하라고 알려 준다.
    if (missing.isNotEmpty && offline) {
      if (done.isEmpty) {
        return "통신이 안 돼 재고를 확인하지 못했습니다."
            " ${missing.length}건은 그대로 뒀으니 통신될 때 다시 차감하십시오.";
      }
      return "자재 ${done.length}건을 차감했습니다."
          " ${missing.length}건은 통신이 안 돼 확인하지 못했습니다.${tail.toString()}";
    }

    if (missing.isEmpty) {
      return "자재 ${done.length}건을 재고에서 차감했습니다.${tail.toString()}";
    }
    if (done.isEmpty) {
      return "재고에 없는 자재 ${missing.length}건입니다. 자재 목록에서 먼저 넣으십시오.";
    }
    return "자재 ${done.length}건을 차감했습니다."
        " ${missing.length}건은 재고에 없어 그대로 뒀습니다.${tail.toString()}";
  }
}

/// 방금 뺀 것을 도로 넣는다(잘못 눌렀을 때).
/// 기록에는 반납으로 남겨서, 무엇이 왜 돌아왔는지 자재 기록에 보인다.
Future<void> undoStockTakes(
  List<StockTake> takes, {
  required String projectName,
  String worker = '',
  String device = 'Mobile',
  String action = '차감 되돌림',
  String projectId = '',
}) async {
  final db = FirebaseFirestore.instance;

  var who = worker.trim();
  if (who.isEmpty) {
    try {
      final p = await SharedPreferences.getInstance();
      who = p.getString('user_real_name') ?? '';
    } catch (_) {}
  }

  final all = await db.collection('inventory').get();
  final byName = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
  for (final d in all.docs) {
    final n = (d.data()['name'] as String?)?.trim() ?? '';
    if (n.isEmpty || byName.containsKey(n)) continue;
    byName[n] = d;
  }

  final batch = db.batch();
  var any = false;
  for (final take in takes) {
    if (take.qty <= 0) continue;
    final doc = byName[take.name.trim()];
    if (doc == null) continue;
    batch.update(db.collection('inventory').doc(doc.id), {
      'qty': FieldValue.increment(take.qty),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    batch.set(db.collection('inventory_logs').doc(), {
      'material_name': take.name,
      'type': 'IN',
      'action': action,
      'qty': take.qty,
      'unit': (doc.data()['unit'] as String?) ?? take.unit,
      'worker_name': who,
      'project_name': projectName,
      'project_id': projectId,
      'device': device,
      'timestamp': FieldValue.serverTimestamp(),
    });
    any = true;
  }
  if (!any) return;

  if (all.metadata.isFromCache) {
    unawaited(batch.commit().catchError((_) {}));
  } else {
    await batch.commit().timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
  }
}

// ── 재고에서 실제로 빼는 부분 (형강·튜브가 같이 쓴다) ──

/// 자재 이름으로 창고 재고를 찾아 수량을 뺀다. 이름이 맞는 자재가 없으면
/// 그대로 두고 [StockDeductResult.missing]에 담아 돌려준다(예전에는 수량이
/// 음수인 자재를 새로 만들어 버려서 재고가 엉켰다).
/// 뺄 때마다 자재 기록에 불출로 남긴다.
Future<StockDeductResult> deductStockTakes(
  List<StockTake> takes, {
  required String projectName,
  String worker = '',
  String device = 'Mobile',
  String action = '컷팅 사용',
  String projectId = '',
}) async {
  final db = FirebaseFirestore.instance;

  var who = worker.trim();
  if (who.isEmpty) {
    try {
      final p = await SharedPreferences.getInstance();
      who = p.getString('user_real_name') ?? '';
    } catch (_) {}
  }

  final done = <StockTake>[];
  final missing = <StockTake>[];
  final negative = <String, int>{};

  // 이름마다 따로 물어보면 통신이 없을 때 폰에 안 받아진 자재를 "재고에 없다"고
  // 잘못 알려 준다. 재고 목록을 한 번에 받아서 맞춰 보고, 폰에 있던 것으로
  // 맞춘 것인지(offline) 같이 돌려준다.
  final all = await db.collection('inventory').get();
  final offline = all.metadata.isFromCache;

  final byName = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
  for (final d in all.docs) {
    final n = (d.data()['name'] as String?)?.trim() ?? '';
    if (n.isEmpty || byName.containsKey(n)) continue;
    byName[n] = d;
  }

  final batch = db.batch();
  for (final take in takes) {
    if (take.qty <= 0 || take.name.trim().isEmpty) continue;
    final doc = byName[take.name.trim()];
    if (doc == null) {
      missing.add(take);
      continue;
    }
    final data = doc.data();
    final unit = (data['unit'] as String?) ?? take.unit;
    final left = ((data['qty'] as num?)?.toInt() ?? 0) - take.qty;
    if (left < 0) negative[take.name] = left;

    batch.update(db.collection('inventory').doc(doc.id), {
      'qty': FieldValue.increment(-take.qty),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    batch.set(db.collection('inventory_logs').doc(), {
      'material_name': take.name,
      'type': 'OUT',
      'action': action,
      'qty': take.qty,
      'unit': unit,
      'worker_name': who,
      'project_name': projectName,
      'project_id': projectId,
      'device': device,
      'timestamp': FieldValue.serverTimestamp(),
    });
    done.add(take);
  }

  if (done.isEmpty) {
    return StockDeductResult(
      done: done,
      missing: missing,
      negative: negative,
      offline: offline,
    );
  }

  // 통신이 없으면 commit이 끝나지 않는다. 폰에 적어 두면 통신될 때 올라가므로
  // 기다리지 않고 넘어간다(예전에는 여기서 화면이 멈췄다).
  if (offline) {
    unawaited(batch.commit().catchError((_) {}));
  } else {
    await batch.commit().timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
  }
  return StockDeductResult(
    done: done,
    missing: missing,
    negative: negative,
    offline: offline,
  );
}
