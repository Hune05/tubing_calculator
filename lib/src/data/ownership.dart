// 자료의 주인(내 것·공용). 재고(inventory_owner.dart)와 같은 규칙을 프로젝트·컷팅 작업·
// 잔재·설정에도 쓴다(점검 25·26번).
//
// 문서에 ownerUid가 있으면 그 사람 것, 없으면 공용이다. 그래서 예전 자료는 손대지 않아도
// 모두 공용으로 보인다. 남의 것은 목록에서 뺀다(앱이 가린다). 서버 규칙(firestore.rules)은
// 남의 것을 고치고 지우는 것을 막는다.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String kOwnerUid = 'ownerUid';
const String kOwnerName = 'ownerName';

String _ownerOf(Map d) => (d[kOwnerUid] ?? '').toString().trim();

/// 주인 칸이 없으면 공용.
bool isSharedDoc(Map d) => _ownerOf(d).isEmpty;

/// 내 것인지. uid를 모르면 내 것은 없다.
bool isMineDoc(Map d, String? uid) {
  final me = (uid ?? '').trim();
  return me.isNotEmpty && _ownerOf(d) == me;
}

/// 나에게 보이는지(공용이거나 내 것).
bool canSeeDoc(Map d, String? uid) => isSharedDoc(d) || isMineDoc(d, uid);

/// 고치고 지울 수 있는지(공용이거나 내 것). 서버 규칙과 같다.
bool canEditDoc(Map d, String? uid) => canSeeDoc(d, uid);

/// 새 문서에 붙일 주인 칸. 공용이거나 uid를 모르면 아무것도 안 붙인다(=공용).
Map<String, dynamic> ownerFieldsFor({
  required bool shared,
  String? uid,
  String? name,
}) {
  final me = (uid ?? '').trim();
  if (shared || me.isEmpty) return const {};
  final who = (name ?? '').trim();
  return {kOwnerUid: me, if (who.isNotEmpty) kOwnerName: who};
}

/// 지금 앱을 쓰는 사람의 uid. 로그인을 안 했거나 읽지 못하면 null.
String? currentUid() {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return (uid == null || uid.isEmpty) ? null : uid;
  } catch (_) {
    return null;
  }
}

/// 사람마다 따로 두는 설정 문서 이름. uid를 모르면 예전처럼 모두 같이 쓰는 문서.
String mySettingsDocId(String base, [String? uid]) {
  final me = (uid ?? currentUid() ?? '').trim();
  return me.isEmpty ? base : '${base}__$me';
}

/// 사람마다 따로 두는 설정 문서(my_project_settings 안).
/// 🚀 [고침] 보고서 양식·주소록·자재 즐겨찾기가 모두 문서 하나라, 남이 저장하면 내 PDF
/// 머리말·로고가 그 사람 것으로 바뀌었다.
DocumentReference<Map<String, dynamic>> mySettingsDoc(String base) =>
    FirebaseFirestore.instance
        .collection('my_project_settings')
        .doc(mySettingsDocId(base));

/// 내 설정 문서를 읽는다. 아직 없으면 예전에 같이 쓰던 문서를 읽어 이어받는다.
Future<Map<String, dynamic>?> readMySettings(
  String base, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  final col = FirebaseFirestore.instance.collection('my_project_settings');
  final mine = await col.doc(mySettingsDocId(base)).get().timeout(timeout);
  if (mine.exists) return mine.data();
  if (mySettingsDocId(base) == base) return null;
  final old = await col.doc(base).get().timeout(timeout);
  return old.data();
}

/// 공용 ↔ 내 것을 바꾼다. 공용으로 돌릴 때는 칸을 지우지 않고 비워 둔다
/// (옛 사본이 합칠 때 주인을 되살리지 않게). 바뀐 뒤 공용이면 true.
Future<bool> toggleSharedDoc(
  DocumentReference<Map<String, dynamic>> ref,
  Map data, {
  String? name,
}) async {
  final toShared = !isSharedDoc(data);
  await ref.update(
    toShared
        ? {kOwnerUid: '', kOwnerName: ''}
        : ownerFieldsFor(shared: false, uid: currentUid(), name: name),
  );
  return toShared;
}
