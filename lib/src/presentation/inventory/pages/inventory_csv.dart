// 재고 엑셀(CSV) 내보내기·가져오기(10-09 자재 관리).
// 내보내기: 나에게 보이는 재고(내 것·공용)를 한 줄에 하나씩. 엑셀에서 한글이 깨지지 않게 맨 앞에 BOM.
// 가져오기: "아이디"가 있는 줄은 그 자재를 고치고, 비어 있으면 새로 넣는다.
//   수량은 덮어쓰지 않고 "고친 수량 − 내보낼 때 수량"만 더하고 뺀다(재고조사와 같은 셈, audit_delta.dart).
//   내보낸 뒤 컷팅 차감 등으로 움직인 것이 지워지지 않는다. 수량이 바뀐 줄은 재고조사 기록으로 남긴다.
// 이 파일은 글 만들기·읽기·계획만 한다(서버에 쓰는 것은 [applyInventoryImport]).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';

import '../../tube_cutting/cutting_stock_deduct.dart'
    show normalizeMaterialName;
import '../material_catalog.dart';
import 'audit_delta.dart';
import 'inventory_owner.dart';

/// 머리줄. "아이디"와 "내보낼 때 수량"은 가져올 때 쓰니 고치지 않는다.
const List<String> kInventoryCsvHeader = [
  '아이디',
  '이름',
  '분류',
  '규격',
  '제조사',
  '재질',
  '위치',
  '단위',
  '수량',
  '최소 수량',
  '히트 번호',
  '내보낼 때 수량',
];

/// 글 칸(머리줄 이름 → 재고 문서 칸).
const Map<String, String> _textFields = {
  '이름': 'name',
  '규격': 'spec',
  '제조사': 'maker',
  '재질': 'material',
  '위치': 'location',
  '단위': 'unit',
  '히트 번호': 'heatNo',
};

String _s(Object? v) => (v ?? '').toString().trim();

int _i(Object? v) => (v as num?)?.toInt() ?? 0;

/// 나에게 보이는 재고를 CSV 글로(분류 → 이름 차례). 엑셀에서 바로 열린다.
String buildInventoryCsv(
  Iterable<(String, Map<String, dynamic>)> docs,
  String? uid,
) {
  final rows =
      [
        for (final (id, d) in docs)
          if (canSeeStock(d, uid) && _s(d['name']).isNotEmpty) (id, d),
      ]..sort((a, b) {
        final c = materialCategoryLabel(
          _s(a.$2['category']),
        ).compareTo(materialCategoryLabel(_s(b.$2['category'])));
        return c != 0 ? c : _s(a.$2['name']).compareTo(_s(b.$2['name']));
      });
  final table = <List<dynamic>>[
    kInventoryCsvHeader,
    for (final (id, d) in rows)
      [
        id,
        _s(d['name']),
        materialCategoryLabel(_s(d['category'])),
        _s(d['spec']),
        _s(d['maker']),
        _s(d['material']),
        _s(d['location']),
        _s(d['unit']),
        _i(d['qty']),
        _i(d['minQty']),
        _s(d['heatNo']),
        _i(d['qty']),
      ],
  ];
  return '﻿${Csv(lineDelimiter: '\r\n').encode(table)}\r\n';
}

/// 파일 이름(날짜): 재고_20261009.csv
String inventoryCsvFileName(DateTime now) =>
    '재고_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';

/// CSV 한 줄.
class InventoryCsvRow {
  /// 파일에서 몇째 줄인지(머리줄이 1).
  final int line;
  final String id;

  /// 머리줄에 있는 글 칸만(문서 칸 이름 → 값). 없는 칸은 안 고친다.
  final Map<String, String> text;

  /// 분류 아이디(머리줄에 "분류"가 없거나 모르는 이름이면 null).
  final String? category;
  final int? qty;
  final int? minQty;
  final int? bookQty;

  const InventoryCsvRow({
    required this.line,
    this.id = '',
    this.text = const {},
    this.category,
    this.qty,
    this.minQty,
    this.bookQty,
  });

  String get name => text['name'] ?? '';
}

class InventoryCsvParse {
  final List<InventoryCsvRow> rows;

  /// 읽지 못한 줄과 까닭("5째 줄: 수량이 숫자가 아닙니다").
  final List<String> errors;
  const InventoryCsvParse(this.rows, this.errors);
}

/// "1,234"·" 12 "·"12.0"도 읽는다. 빈 칸은 null, 숫자가 아니면 [bad].
int? _parseInt(String raw, void Function() bad) {
  final t = raw.replaceAll(',', '').trim();
  if (t.isEmpty) return null;
  final n = num.tryParse(t);
  if (n == null || n != n.roundToDouble()) {
    bad();
    return null;
  }
  return n.toInt();
}

/// 분류 칸: 한글 이름(전선관) 또는 아이디(CONDUIT). 모르면 null(안 고친다).
String? _categoryId(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  if (kMaterialCategoryLabels.containsKey(t)) return t;
  for (final e in kMaterialCategoryLabels.entries) {
    if (e.value == t) return e.key;
  }
  return null;
}

/// CSV 글을 읽는다. 머리줄 이름으로 칸을 찾으므로 칸 차례를 바꾸거나 칸을 빼도 된다.
InventoryCsvParse parseInventoryCsv(String text) {
  var t = text;
  if (t.startsWith('﻿')) t = t.substring(1);
  final List<List<dynamic>> table;
  try {
    table = Csv(autoDetect: true, skipEmptyLines: false).decode(t);
  } catch (_) {
    return const InventoryCsvParse([], ['CSV 파일을 읽지 못했습니다.']);
  }
  if (table.isEmpty) return const InventoryCsvParse([], ['빈 파일입니다.']);
  final head = [for (final h in table.first) _s(h)];
  final col = <String, int>{
    for (var i = 0; i < head.length; i++)
      if (head[i].isNotEmpty) head[i]: i,
  };
  if (!col.containsKey('이름')) {
    return const InventoryCsvParse([], [
      '머리줄에 "이름" 칸이 없습니다. 앱에서 내보낸 파일을 고쳐서 가져오십시오.',
    ]);
  }
  String cell(List<dynamic> r, String h) {
    final i = col[h];
    return i == null || i >= r.length ? '' : _s(r[i]);
  }

  final rows = <InventoryCsvRow>[];
  final errors = <String>[];
  for (var n = 1; n < table.length; n++) {
    final r = table[n];
    if (r.every((c) => _s(c).isEmpty)) continue; // 빈 줄
    final line = n + 1;
    var ok = true;
    void bad(String why) {
      if (ok) errors.add('$line째 줄: $why');
      ok = false;
    }

    final id = cell(r, '아이디');
    final text = <String, String>{
      for (final e in _textFields.entries)
        if (col.containsKey(e.key)) e.value: cell(r, e.key),
    };
    if ((text['name'] ?? '').isEmpty) bad('이름이 비어 있습니다');
    final qty = _parseInt(cell(r, '수량'), () => bad('수량이 숫자가 아닙니다'));
    final minQty = _parseInt(cell(r, '최소 수량'), () => bad('최소 수량이 숫자가 아닙니다'));
    final book = _parseInt(
      cell(r, '내보낼 때 수량'),
      () => bad('내보낼 때 수량이 숫자가 아닙니다'),
    );
    if (qty != null && qty < 0) bad('수량이 0보다 작습니다');
    if (!ok) continue;
    rows.add(
      InventoryCsvRow(
        line: line,
        id: id,
        text: text,
        category: col.containsKey('분류') ? _categoryId(cell(r, '분류')) : null,
        qty: qty,
        minQty: minQty,
        bookQty: book,
      ),
    );
  }
  return InventoryCsvParse(rows, errors);
}

/// 있는 자재 하나를 고치는 내용.
class InventoryImportUpdate {
  final String id;
  final String name;
  final Map<String, Object> fields; // 글 칸·분류·최소 수량
  final int qtyDelta; // 0이면 수량은 안 건드린다
  final int qtyBefore;
  final int qtyAfter;
  final String unit;

  /// 제조사(같은 이름 자재를 확인창에서 가려 보이려고).
  final String maker;
  const InventoryImportUpdate({
    required this.id,
    required this.name,
    this.maker = '',
    this.fields = const {},
    this.qtyDelta = 0,
    this.qtyBefore = 0,
    this.qtyAfter = 0,
    this.unit = '',
  });
}

class InventoryImportPlan {
  final List<InventoryImportUpdate> updates;
  final List<InventoryCsvRow> creates;
  final int unchanged;

  /// 넘긴 줄과 까닭(읽기 오류 포함).
  final List<String> problems;
  const InventoryImportPlan({
    this.updates = const [],
    this.creates = const [],
    this.unchanged = 0,
    this.problems = const [],
  });

  int get qtyChanged => updates.where((u) => u.qtyDelta != 0).length;
  bool get isEmpty => updates.isEmpty && creates.isEmpty;
}

/// 읽은 줄을 지금 재고([server]: 문서 id → 내용)와 맞춰 무엇을 고치고 넣을지 정한다.
InventoryImportPlan planInventoryImport(
  InventoryCsvParse parsed,
  Map<String, Map<String, dynamic>> server,
  String? uid,
) {
  final updates = <InventoryImportUpdate>[];
  final creates = <InventoryCsvRow>[];
  final problems = [...parsed.errors];
  var unchanged = 0;
  final seenIds = <String>{};
  // 새로 넣을 줄이 이미 있는 자재와 이름·제조사가 같으면 두 벌이 되므로 넘긴다.
  final existing = <String>{
    for (final d in server.values)
      if (canSeeStock(d, uid))
        '${normalizeMaterialName(_s(d['name']))}|${_s(d['maker'])}',
  };
  for (final r in parsed.rows) {
    if (r.id.isEmpty) {
      final key = '${normalizeMaterialName(r.name)}|${r.text['maker'] ?? ''}';
      if (existing.contains(key)) {
        problems.add(
          '${r.line}째 줄: "${r.name}"은 이미 재고에 있습니다(아이디 칸을 채우면 그 자재를 고칩니다)',
        );
        continue;
      }
      existing.add(key);
      creates.add(r);
      continue;
    }
    if (!seenIds.add(r.id)) {
      problems.add('${r.line}째 줄: 같은 아이디가 위에 또 있습니다');
      continue;
    }
    final d = server[r.id];
    if (d == null) {
      problems.add('${r.line}째 줄: 재고에 없는 아이디입니다(지워진 자재). 새로 넣으려면 아이디 칸을 비우십시오');
      continue;
    }
    if (!canSeeStock(d, uid)) {
      problems.add('${r.line}째 줄: 다른 사람의 개인 재고라 고치지 않습니다');
      continue;
    }
    final fields = <String, Object>{};
    r.text.forEach((k, v) {
      if (k == 'name' && v.isEmpty) return;
      if (v != _s(d[k])) fields[k] = v;
    });
    final cat = r.category;
    // 분류가 빈 자재는 '기타'로 내보낸다. 그대로 가져오면 바뀐 것으로 보지 않는다.
    final catNow = _s(d['category']).isEmpty ? '기타' : _s(d['category']);
    if (cat != null && cat != catNow) fields['category'] = cat;
    final minQty = r.minQty;
    if (minQty != null && minQty != _i(d['minQty'])) fields['minQty'] = minQty;
    final server0 = _i(d['qty']);
    var delta = 0;
    var after = server0;
    final qty = r.qty;
    if (qty != null) {
      final ad = auditDelta(counted: qty, book: r.bookQty, server: server0);
      delta = ad.delta;
      after = ad.after;
    }
    if (fields.isEmpty && delta == 0) {
      unchanged++;
      continue;
    }
    updates.add(
      InventoryImportUpdate(
        id: r.id,
        name: (fields['name'] as String?) ?? _s(d['name']),
        fields: fields,
        qtyDelta: delta,
        qtyBefore: server0,
        qtyAfter: after,
        unit: (fields['unit'] as String?) ?? _s(d['unit']),
        maker: (fields['maker'] as String?) ?? _s(d['maker']),
      ),
    );
  }
  return InventoryImportPlan(
    updates: updates,
    creates: creates,
    unchanged: unchanged,
    problems: problems,
  );
}

/// 확인창 줄의 자재 이름: 제조사가 있으면 "이름 (제조사)"(같은 이름 두 줄이 똑같아 보이지 않게, 10-09).
String _withMaker(String name, String maker) =>
    maker.trim().isEmpty ? name : '$name (${maker.trim()})';

/// 확인창 글: 몇 건을 고치고 넣는지, 수량이 바뀌는 자재, 넘긴 줄.
String inventoryImportSummary(InventoryImportPlan p, {int max = 8}) {
  final b = StringBuffer()
    ..writeln('고칠 자재 ${p.updates.length}건(수량 바뀜 ${p.qtyChanged}건)')
    ..writeln('새로 넣을 자재 ${p.creates.length}건')
    ..write('그대로 ${p.unchanged}건');
  if (p.problems.isNotEmpty) b.write(' · 넘긴 줄 ${p.problems.length}건');
  final moved = [
    for (final u in p.updates)
      if (u.qtyDelta != 0) u,
  ];
  if (moved.isNotEmpty) {
    b.write('\n\n수량이 바뀌는 자재');
    for (final u in moved.take(max)) {
      b.write(
        '\n• ${_withMaker(u.name, u.maker)}: ${u.qtyBefore} → ${u.qtyAfter}${u.unit}',
      );
    }
    if (moved.length > max) b.write('\n… 외 ${moved.length - max}건');
  }
  if (p.creates.isNotEmpty) {
    b.write('\n\n새로 넣을 자재');
    for (final r in p.creates.take(max)) {
      b.write(
        '\n• ${_withMaker(r.name, r.text['maker'] ?? '')} ${r.qty ?? 0}${r.text['unit']?.isNotEmpty == true ? r.text['unit'] : 'EA'}',
      );
    }
    if (p.creates.length > max) b.write('\n… 외 ${p.creates.length - max}건');
  }
  if (p.problems.isNotEmpty) {
    b.write('\n\n넘긴 줄');
    for (final m in p.problems.take(max)) {
      b.write('\n• $m');
    }
    if (p.problems.length > max) b.write('\n… 외 ${p.problems.length - max}건');
  }
  return b.toString();
}

/// 계획대로 서버에 쓴다(재고와 기록을 같이). 통신이 없으면([offline]) 폰에 적어 두고 기다리지 않는다.
/// 쓴 건수(고침 + 새로)를 돌려준다.
Future<int> applyInventoryImport(
  InventoryImportPlan plan, {
  required String worker,
  String? uid,
  bool offline = false,
}) async {
  final db = FirebaseFirestore.instance;
  final inv = db.collection('inventory');
  final logs = db.collection('inventory_logs');
  final batches = <WriteBatch>[db.batch()];
  var ops = 0;
  WriteBatch next(int need) {
    // 한 번에 500건까지라 넉넉히 나눈다.
    if (ops + need > 400) {
      batches.add(db.batch());
      ops = 0;
    }
    ops += need;
    return batches.last;
  }

  for (final u in plan.updates) {
    final b = next(u.qtyDelta != 0 ? 2 : 1);
    b.update(inv.doc(u.id), {
      ...u.fields,
      if (u.qtyDelta != 0) 'qty': FieldValue.increment(u.qtyDelta),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    if (u.qtyDelta != 0) {
      b.set(logs.doc(), {
        'type': 'AUDIT',
        'action': '재고 실사',
        'project_name': '엑셀(CSV) 가져오기',
        'material_name': u.name,
        'item_id': u.id,
        'qty': u.qtyDelta.abs(),
        'sign': u.qtyDelta > 0 ? '+' : '-',
        'unit': u.unit.isEmpty ? 'EA' : u.unit,
        'worker_name': worker,
        'device': 'Mobile',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }
  for (final r in plan.creates) {
    final b = next(2);
    final ref = inv.doc();
    final unit = (r.text['unit'] ?? '').isEmpty ? 'EA' : r.text['unit']!;
    b.set(ref, {
      for (final e in r.text.entries)
        if (e.value.isNotEmpty) e.key: e.value,
      'unit': unit,
      'category': r.category ?? '기타',
      'qty': r.qty ?? 0,
      'minQty': r.minQty ?? 0,
      'status': '정상',
      'is_dead_stock': false,
      'is_reorder_needed': false,
      // 새로 넣는 자재는 내 개인 재고(로그인 안 했으면 공용), 다른 화면과 같다.
      ...stockOwnerFields(shared: false, uid: uid, name: worker),
      'createdAt': FieldValue.serverTimestamp(),
    });
    b.set(logs.doc(), {
      'type': 'INIT',
      'action': '자재 등록',
      'project_name': '엑셀(CSV) 가져오기',
      'material_name': r.name,
      'item_id': ref.id,
      'qty': r.qty ?? 0,
      'unit': unit,
      'worker_name': worker,
      'device': 'Mobile',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
  for (final b in batches) {
    if (offline) {
      unawaited(b.commit().catchError((_) {}));
    } else {
      await b.commit().timeout(const Duration(seconds: 8), onTimeout: () {});
    }
  }
  return plan.updates.length + plan.creates.length;
}
