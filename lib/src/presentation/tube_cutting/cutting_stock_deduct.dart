import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../inventory/pages/inventory_owner.dart';

// 컷팅에서 쓴 자재를 창고 재고에서 뺄 때의 셈. 화면과 떼어 놓아서 검사할 수 있게 한다.

/// 자재 이름을 견주기 좋게 다듬는다.
///
/// 🚀 [고침] 컷팅 쪽 자재 이름은 "[제조사] 규격 이름"으로 붙여 만들고,
/// 재고 쪽 이름은 자재 목록에서 들어온다. 빈칸이 하나 더 들어갔거나
/// 따옴표 모양(" ” ″)만 달라도 "재고에 없는 자재"로 빠져 버렸다.
/// 빈칸을 하나로 줄이고, 따옴표를 한 가지로 맞추고, 대소문자를 무시한다.
String normalizeMaterialName(String name) {
  return name
      .replaceAll('\u201C', '"')
      .replaceAll('\u201D', '"')
      .replaceAll('\u2033', '"')
      .replaceAll('\u2018', "'")
      .replaceAll('\u2019', "'")
      .replaceAll('\u2032', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
}

/// 이름으로 재고 문서를 찾는 표를 만든다.
/// 똑같은 이름을 먼저 보고, 없으면 다듬은 이름으로 한 번 더 본다.
///
/// [rank]를 주면 이름이 같은 문서 가운데 값이 작은 것을 쓰고, null인 문서는
/// 아예 뺀다(내 재고 → 공용 차례, 남의 개인 재고는 안 씀). 값이 같으면 먼저 온 것.
Map<String, T> materialLookup<T>(
  Iterable<T> docs,
  String Function(T) nameOf, {
  int? Function(T)? rank,
}) {
  final out = <String, T>{};
  final best = <String, int>{};
  void put(String key, T d, int r) {
    final have = best[key];
    if (have != null && have <= r) return;
    out[key] = d;
    best[key] = r;
  }

  for (final d in docs) {
    final raw = nameOf(d).trim();
    if (raw.isEmpty) continue;
    final r = rank == null ? 0 : rank(d);
    if (r == null) continue;
    put(raw, d, r);
    put(normalizeMaterialName(raw), d, r);
  }
  return out;
}

/// 표에서 자재를 찾는다(똑같은 이름 → 다듬은 이름 차례로).
T? findMaterial<T>(Map<String, T> lookup, String name) {
  final raw = name.trim();
  return lookup[raw] ?? lookup[normalizeMaterialName(raw)];
}

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

/// 미터로 세는 단위인지("m", "M", "미터"). 🚀 [고침] PC 자재 등록은 "M"(대문자)으로
/// 저장해서, 소문자만 보던 차감이 6m 한 본을 써도 1만 뺐다.
bool isMeterUnit(String unit) {
  final u = unit.trim().toLowerCase();
  return u == 'm' || u == '미터' || u == 'meter';
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

    final stockUnit = (_pick(unitByName, name) ?? '').trim();
    final mm = ((m['qty_mm'] as num?) ?? 0).round();

    int qty;
    String unit;
    if (!isTube) {
      qty = ((m['qty_ea'] as num?) ?? 0).round();
      unit = stockUnit.isEmpty ? 'EA' : stockUnit;
    } else if (isMeterUnit(stockUnit)) {
      qty = _ceilDiv(mm, 1000);
      unit = 'm';
    } else {
      qty = _ceilDiv(mm, _pick(barLengthByName, name) ?? kTubeBarMm);
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

/// 이름이 조금 달라도 찾아 준다(빈칸·따옴표·대소문자).
V? _pick<V>(Map<String, V>? map, String name) {
  if (map == null || map.isEmpty) return null;
  final direct = map[name.trim()];
  if (direct != null) return direct;
  final want = normalizeMaterialName(name);
  for (final e in map.entries) {
    if (normalizeMaterialName(e.key) == want) return e.value;
  }
  return null;
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
  final lookup = materialLookup(stockQty.keys, (k) => k);
  final lines = <String>[];
  for (final t in takes) {
    final key = findMaterial(lookup, t.name);
    if (key == null) continue;
    final have = stockQty[key] ?? 0;
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
    // 이름이 같으면 차감과 같은 문서(내 것 → 공용)를 읽는다. 남의 개인 재고는 뺀다.
    final uid = currentStockUid();
    final best = <String, int>{};
    for (final d in snap.docs) {
      final name = (d.data()['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      final pref = stockPreference(d.data(), uid);
      if (pref == null) continue;
      final have = best[name];
      if (have != null && have <= pref) continue;
      best[name] = pref;
      final len = (d.data()['barLengthMm'] as num?)?.toInt() ?? 0;
      if (len > 0) bars[name] = len;
      final unit = (d.data()['unit'] as String?)?.trim() ?? '';
      if (unit.isNotEmpty) units[name] = unit;
      qty[name] = (d.data()['qty'] as num?)?.toInt() ?? 0;
    }
    return StockInfo(barLengthByName: bars, unitByName: units, qtyByName: qty);
  } catch (_) {
    return const StockInfo();
  }
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
  // 내 재고 → 공용 차례로 쓰고, 남의 개인 재고는 건드리지 않는다.
  final uid = currentStockUid();
  final byName = materialLookup(
    all.docs,
    (d) => (d.data()['name'] as String?) ?? '',
    rank: (d) => stockPreference(d.data(), uid),
  );

  final batch = db.batch();
  var any = false;
  for (final take in takes) {
    if (take.qty <= 0) continue;
    final doc = findMaterial(byName, take.name);
    if (doc == null) continue;
    batch.update(db.collection('inventory').doc(doc.id), {
      'qty': FieldValue.increment(take.qty),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    batch.set(db.collection('inventory_logs').doc(), {
      'material_name': take.name,
      'item_id': doc.id,
      'type': 'IN',
      'action': action,
      'qty': take.qty,
      'unit': (doc.data()['unit'] as String?) ?? take.unit,
      'worker_name': who,
      'project_name': projectName,
      'job_name': projectName,
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
    await batch.commit().timeout(const Duration(seconds: 8), onTimeout: () {});
  }
}

// ── 재고에서 실제로 빼는 부분 (형강·튜브가 같이 쓴다) ──

/// 자재 이름으로 창고 재고를 찾아 수량을 뺀다. 이름이 맞는 자재가 없으면
/// 그대로 두고 [StockDeductResult.missing]에 담아 돌려준다(예전에는 수량이
/// 음수인 자재를 새로 만들어 버려서 재고가 엉켰다).
/// 뺄 때마다 자재 기록에 나간 것으로 남긴다.
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

  // 내 재고 → 공용 차례로 쓰고, 남의 개인 재고는 건드리지 않는다.
  final uid = currentStockUid();
  final byName = materialLookup(
    all.docs,
    (d) => (d.data()['name'] as String?) ?? '',
    rank: (d) => stockPreference(d.data(), uid),
  );

  final batch = db.batch();
  for (final take in takes) {
    if (take.qty <= 0 || take.name.trim().isEmpty) continue;
    final doc = findMaterial(byName, take.name);
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
      'item_id': doc.id,
      'type': 'OUT',
      'action': action,
      'qty': take.qty,
      'unit': unit,
      'worker_name': who,
      'project_name': projectName,
      // 작업 이름을 따로 남긴다. 'project_name'은 예전 기록에서 "왜 썼는지"를
      // 적는 데도 쓰여서, 작업별로 걸러 보려면 칸이 따로 있어야 한다.
      'job_name': projectName,
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
    await batch.commit().timeout(const Duration(seconds: 8), onTimeout: () {});
  }
  return StockDeductResult(
    done: done,
    missing: missing,
    negative: negative,
    offline: offline,
  );
}

// ── 재단 계획의 새 원자재를 재고에서 뺄 때 (튜브·형강 같이) ──

/// 규격별 새 원자재 한 본 한 본의 길이(mm). 재단 계획 창이 만들고,
/// 이미 뺀 것도 같은 모양으로 적어 둔다. 길이가 -1이면 예전 기록이라
/// 길이를 모르는 본이다(어떤 길이와도 맞춘다).
typedef BarsBySpec = Map<String, List<double>>;

/// 필요한 본([need]) 가운데 아직 안 뺀 것. 같은 규격·같은 길이끼리 지운다.
/// 🚀 [고침] 예전에는 한 규격이라도 빠지면 전부 "뺐음"이 되어, 이름이 안 맞아
/// 못 뺀 규격을 다시 뺄 단추가 없었다. 남은 것만 다시 뺄 수 있게 한다.
BarsBySpec barsStillToDeduct(BarsBySpec need, BarsBySpec done) {
  final out = <String, List<double>>{};
  for (final e in need.entries) {
    final pool = [...(done[e.key] ?? const <double>[])];
    final left = <double>[];
    final sorted = [...e.value]..sort();
    for (final len in sorted) {
      var i = pool.indexWhere((d) => (d - len).abs() < 0.5);
      if (i < 0) i = pool.indexWhere((d) => d < 0);
      if (i >= 0) {
        pool.removeAt(i);
      } else {
        left.add(len);
      }
    }
    if (left.isNotEmpty) out[e.key] = left;
  }
  return out;
}

/// 두 본 목록을 합친다.
BarsBySpec addBars(BarsBySpec a, BarsBySpec b) {
  final out = <String, List<double>>{
    for (final e in a.entries) e.key: [...e.value],
  };
  for (final e in b.entries) {
    (out[e.key] ??= <double>[]).addAll(e.value);
  }
  out.removeWhere((_, v) => v.isEmpty);
  return out;
}

int barCountOf(BarsBySpec m) => m.values.fold(0, (s, l) => s + l.length);

/// 뺀 본을 적어 둘 글. 서버 문서에 그대로 넣는다.
String encodeDeductedBars(BarsBySpec m) {
  final keys = m.keys.toList()..sort();
  return jsonEncode({
    for (final k in keys)
      if (m[k]!.isNotEmpty) k: [for (final v in m[k]!) v.round()],
  });
}

/// [encodeDeductedBars]로 적은 글을 읽는다. 예전 모양("규격=본수;...")이면
/// 길이를 모르는 본(-1)으로 읽는다. 못 읽으면 빈 것.
BarsBySpec decodeDeductedBars(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return {};
  if (s.startsWith('{')) {
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return {
        for (final e in m.entries)
          if (e.value is List)
            e.key: [
              for (final v in e.value as List)
                if (v is num) v.toDouble(),
            ],
      }..removeWhere((_, v) => v.isEmpty);
    } catch (_) {
      return {};
    }
  }
  final out = <String, List<double>>{};
  for (final part in s.split(';')) {
    final i = part.lastIndexOf('=');
    if (i <= 0) continue;
    final n = int.tryParse(part.substring(i + 1)) ?? 0;
    if (n > 0) out[part.substring(0, i)] = List.filled(n, -1.0);
  }
  return out;
}

/// 뺄 본을 "뺄 자재 줄"로 바꾼다. [nameOf]는 규격을 재고 이름으로 바꾼다.
/// 🚀 [고침] 예전에는 규격 이름 + 본수 + '본'으로만 만들어서, 창고가 m로 세는
/// 자재면 6m 두 본을 빼도 2m가 빠졌다. m로 세면 길이를 더해 m로 뺀다.
List<StockTake> stockTakesForBars(
  BarsBySpec bars, {
  String Function(String spec)? nameOf,
  Map<String, String>? unitByName,
}) {
  final out = <StockTake>[];
  for (final e in bars.entries) {
    if (e.value.isEmpty) continue;
    final name = (nameOf?.call(e.key) ?? e.key).trim();
    if (name.isEmpty) continue;
    final stockUnit = (_pick(unitByName, name) ?? '').trim();
    final known = e.value.every((l) => l > 0);
    if (isMeterUnit(stockUnit) && known) {
      final mm = e.value.fold(0.0, (s, l) => s + l).round();
      out.add(
        StockTake(name: name, qty: _ceilDiv(mm, 1000), unit: 'm', spec: e.key),
      );
    } else {
      out.add(
        StockTake(
          name: name,
          qty: e.value.length,
          unit: stockUnit.isEmpty || isMeterUnit(stockUnit) ? '본' : stockUnit,
          spec: e.key,
        ),
      );
    }
  }
  return out;
}

/// 차감 결과에서 실제로 뺀 규격의 본만 고른다(못 찾은 이름은 남긴다).
BarsBySpec deductedPart(BarsBySpec asked, List<StockTake> done) {
  final specs = {for (final t in done) t.spec};
  return {
    for (final e in asked.entries)
      if (specs.contains(e.key)) e.key: [...e.value],
  };
}
