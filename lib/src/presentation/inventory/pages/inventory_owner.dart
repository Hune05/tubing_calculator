// 재고의 주인. 사람마다 자기 재고를 따로 두고, 같이 쓰는 공용 재고도 둔다.
//
// 재고 문서에 주인 칸(ownerUid)이 있으면 그 사람 것, 없으면 공용이다. 그래서 예전에
// 넣은 재고는 손대지 않아도 모두 공용으로 보인다(서버 자료를 옮기지 않는다).
// 남의 개인 재고는 목록·컷팅 차감에서 뺀다. 다만 이것은 앱이 가려 주는 것이고,
// 서버에서 막으려면 권한 규칙(firestore.rules)이 따로 필요하다.
import 'package:firebase_auth/firebase_auth.dart';

const String kStockOwnerUid = 'ownerUid';
const String kStockOwnerName = 'ownerName';

/// 목록에서 무엇을 볼지.
enum StockScope { all, mine, shared }

String stockScopeLabel(StockScope s) => switch (s) {
  StockScope.all => '전체',
  StockScope.mine => '내 것',
  StockScope.shared => '공용',
};

String _ownerOf(Map<String, dynamic> d) =>
    (d[kStockOwnerUid] ?? '').toString().trim();

/// 주인 칸이 없으면 공용.
bool isSharedStock(Map<String, dynamic> d) => _ownerOf(d).isEmpty;

/// 내 개인 재고인지. 로그인을 안 해 uid를 모르면 내 것은 없다.
bool isMyStock(Map<String, dynamic> d, String? uid) {
  final me = (uid ?? '').trim();
  return me.isNotEmpty && _ownerOf(d) == me;
}

/// 나에게 보이는 재고인지(공용이거나 내 것).
bool canSeeStock(Map<String, dynamic> d, String? uid) =>
    isSharedStock(d) || isMyStock(d, uid);

/// 목록 칩(전체·내 것·공용)에 맞는지. 남의 개인 재고는 어느 칩에서도 안 보인다.
bool matchesStockScope(
  Map<String, dynamic> d,
  String? uid,
  StockScope scope,
) {
  if (!canSeeStock(d, uid)) return false;
  return switch (scope) {
    StockScope.all => true,
    StockScope.mine => isMyStock(d, uid),
    StockScope.shared => isSharedStock(d),
  };
}

/// 이름이 같은 재고가 여럿일 때 어느 것을 먼저 쓸지. 작을수록 먼저.
/// 내 것 → 공용 차례. 남의 것은 쓰지 않는다(null).
int? stockPreference(Map<String, dynamic> d, String? uid) {
  if (isMyStock(d, uid)) return 0;
  if (isSharedStock(d)) return 1;
  return null;
}

/// 새 재고 문서에 붙일 주인 칸. 공용이거나 uid를 모르면 아무것도 안 붙인다(=공용).
Map<String, dynamic> stockOwnerFields({
  required bool shared,
  String? uid,
  String? name,
}) {
  final me = (uid ?? '').trim();
  if (shared || me.isEmpty) return const {};
  final who = (name ?? '').trim();
  return {kStockOwnerUid: me, if (who.isNotEmpty) kStockOwnerName: who};
}

/// 지금 앱을 쓰는 사람의 uid. 로그인을 안 했거나 읽지 못하면 null.
String? currentStockUid() {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return (uid == null || uid.isEmpty) ? null : uid;
  } catch (_) {
    return null;
  }
}
