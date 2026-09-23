import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../material_catalog.dart';
import 'inventory_owner.dart';

// 자재 목록(카탈로그)은 서버에 둔다. 폰을 바꿔도, 다른 화면에서도 같은 목록을 본다.
const String kMaterialCatalogCollection = 'material_catalog';
// 창고 재고
const String kInventoryCollection = 'inventory';
// 앱이 기억하는 제조사
const String kMaterialMakersPrefsKey = 'material_makers_v1';

CollectionReference<Map<String, dynamic>> get _catalog =>
    FirebaseFirestore.instance.collection(kMaterialCatalogCollection);

CollectionReference<Map<String, dynamic>> get _inventory =>
    FirebaseFirestore.instance.collection(kInventoryCollection);

/// 서버에 있는 자재 목록을 순서대로 읽는다.
Future<List<CatalogItem>> loadMaterialCatalog() async {
  final snap = await _catalog.get();
  final list = <CatalogItem>[
    for (final d in snap.docs) CatalogItem.fromMap(d.id, d.data()),
  ];
  list.sort((a, b) {
    final c = a.order.compareTo(b.order);
    return c != 0 ? c : a.name.compareTo(b.name);
  });
  return list;
}

/// 앱의 기본 목록 가운데 서버에 없는 것만 채운다. 이미 있는 것은 건드리지
/// 않으니(고쳐 놓은 이름이 되돌아가지 않는다) 여러 번 눌러도 안전하다.
/// 채운 개수를 돌려준다.
Future<int> seedMissingCatalog() async {
  final snap = await _catalog.get();
  // 통신이 없어 폰 캐시(비어 있을 수 있음)로 답하면 채우지 않는다. 예전엔 이때 천 건을
  // 쓰려다 서버 확인이 안 끝나 화면이 영영 돌았다.
  if (snap.metadata.isFromCache) return 0;
  final have = {for (final d in snap.docs) d.id};
  final missing = [
    for (final item in allMaterialCatalog())
      if (!have.contains(item.id)) item,
  ];
  if (missing.isEmpty) return 0;

  var batch = FirebaseFirestore.instance.batch();
  var n = 0;
  for (final item in missing) {
    batch.set(_catalog.doc(item.id), item.toMap());
    n++;
    if (n % 400 == 0) {
      await batch.commit();
      batch = FirebaseFirestore.instance.batch();
    }
  }
  await batch.commit();
  return missing.length;
}

Future<void> saveCatalogItem(CatalogItem item) async {
  await _catalog.doc(item.id).set(item.toMap(), SetOptions(merge: true));
}

Future<void> deleteCatalogItem(String id) async {
  await _catalog.doc(id).delete();
}

/// 카탈로그에서 고른 자재를 창고 재고에 넣는다. 수량은 0으로 시작한다
/// (재고조사나 반납으로 채운다). 같은 자재를 두 번 넣어도 늘어나지 않게
/// 문서 이름을 카탈로그 아이디로 정해 둔다.
/// 새로 들어간 개수를 돌려준다.
Future<int> addCatalogItemsToInventory(
  List<CatalogItem> items, {
  String maker = '',
  String location = '',
  String worker = '',
  // 공용으로 넣을지. 아니면 넣는 사람의 개인 재고가 된다(로그인 안 했으면 공용).
  bool shared = false,
}) async {
  final owner = stockOwnerFields(
    shared: shared,
    uid: currentStockUid(),
    name: worker,
  );
  // 개인 재고는 사람마다 문서가 따로라 문서 이름에 주인을 붙인다.
  final ownerTail = owner.isEmpty ? '' : '_u${owner[kStockOwnerUid]}';
  var added = 0;
  for (final item in items) {
    final docId =
        (maker.trim().isEmpty
            ? 'cat_${item.id}'
            : 'cat_${item.id}_${_slug(maker)}') +
        ownerTail;
    final ref = _inventory.doc(docId);
    final snap = await ref.get();
    if (snap.exists) continue;
    await ref.set({
      'name': item.name,
      'category': item.category,
      'spec': item.spec,
      'kind': item.kind,
      'unit': item.unit,
      'maker': maker.trim(),
      'location': location.trim(),
      'qty': 0,
      'minQty': 0,
      'status': '정상',
      'is_dead_stock': false,
      'is_reorder_needed': false,
      'catalogId': item.id,
      ...owner,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // 누가 언제 재고에 넣었는지 자재 기록에도 남긴다(수량은 0이라 재고는 안 움직인다).
    try {
      await FirebaseFirestore.instance.collection('inventory_logs').add({
        'material_name': item.name,
        'item_id': docId,
        'action': '자재 등록',
        'type': 'INIT',
        'qty': 0,
        'unit': item.unit,
        'worker_name': worker,
        'project_name': '자재 목록에서 넣음',
        'device': 'Mobile',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    added++;
  }
  return added;
}

String _slug(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'[^0-9a-z가-힣]+'), '_');

/// 제조사 목록(기본 + 앱이 기억한 것).
Future<List<String>> loadMakers() async {
  try {
    final p = await SharedPreferences.getInstance();
    return mergeMakers(p.getStringList(kMaterialMakersPrefsKey) ?? const []);
  } catch (_) {
    return mergeMakers(const []);
  }
}

/// 처음 보는 제조사를 적었으면 기억해 둔다.
Future<void> rememberMaker(String maker) async {
  final v = maker.trim();
  if (v.isEmpty) return;
  if (kCommonMaterialMakers.contains(v)) return;
  try {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(kMaterialMakersPrefsKey) ?? <String>[];
    if (list.contains(v)) return;
    list.add(v);
    await p.setStringList(kMaterialMakersPrefsKey, list);
  } catch (_) {}
}
