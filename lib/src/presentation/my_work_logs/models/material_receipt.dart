// 자재 수량·입고 검수(10-15). 자재 일정(자재 요청·입고일)에 주문 수량·단위를 적고, 입고 완료로 바꿀 때
// 들어온 수량·검수 메모·검수 사진을 남긴다. 덜 들어온 것은 개요·일정 목록·보고서에 "N 부족"으로 보인다.
//
// 저장 칸(일정 Map): 'qty'(주문 수량) 'unit'(단위) 'receivedQty'(입고 수량) 'receiveNote'(검수 메모)
// 'receivePhotos'(검수 사진 경로·주소) 'receivedAt'(ISO) 'receivedBy'(받은 사람).
library;

import 'project_phase.dart' show isMaterialSchedule, touchItem;

/// 단위 고르기 칩(현장에서 많이 쓰는 것).
const List<String> kMaterialUnits = ['EA', 'm', '본', '롤', '세트', 'kg', 'BOX'];

/// 이 칸들은 일정 편집 창이 새 Map을 만들 때 그대로 옮겨야 한다.
const List<String> kMaterialReceiptKeys = [
  'qty',
  'unit',
  'receivedQty',
  'receiveNote',
  'receivePhotos',
  'receivedAt',
  'receivedBy',
];

num? _num(Object? v) => v is num ? v : num.tryParse('${v ?? ''}'.trim());

String fmtQty(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

num? materialQty(Map s) {
  final n = _num(s['qty']);
  return n == null || n <= 0 ? null : n;
}

num? materialReceivedQty(Map s) {
  final n = _num(s['receivedQty']);
  return n == null || n < 0 ? null : n;
}

String materialUnit(Map s) => (s['unit'] ?? '').toString().trim();

List<String> materialReceivePhotos(Map s) => [
  for (final e in (s['receivePhotos'] as List?) ?? const []) e.toString(),
];

/// 입고 완료인데 주문보다 덜 들어온 양(없으면 null).
num? materialShortage(Map s) {
  if (s['isCompleted'] != true) return null;
  final q = materialQty(s), r = materialReceivedQty(s);
  if (q == null || r == null || r >= q) return null;
  return q - r;
}

/// 한 줄: "주문 20EA" / "주문 20EA · 입고 18EA · 2EA 부족" / "입고 18EA". 수량이 없으면 ''.
String materialQtyLabel(Map s) {
  final u = materialUnit(s);
  final q = materialQty(s), r = materialReceivedQty(s);
  final parts = <String>[
    if (q != null) '주문 ${fmtQty(q)}$u',
    if (s['isCompleted'] == true && r != null) '입고 ${fmtQty(r)}$u',
  ];
  final short = materialShortage(s);
  if (short != null) parts.add('${fmtQty(short)}$u 부족');
  return parts.join(' · ');
}

/// 덜 들어온 자재(개요 경고·보고서용).
List<Map<String, dynamic>> shortMaterials(Map<String, dynamic> log) => [
  for (final s in (log['schedules'] as List? ?? const []))
    if (s is Map<String, dynamic> &&
        isMaterialSchedule(s) &&
        materialShortage(s) != null)
      s,
];

/// 입고 검수 결과를 적고 입고 완료로 바꾼다.
void applyMaterialReceipt(
  Map s, {
  num? receivedQty,
  String note = '',
  List<String> photos = const [],
  String who = '',
  DateTime? at,
}) {
  s['isCompleted'] = true;
  if (receivedQty == null) {
    s.remove('receivedQty');
  } else {
    s['receivedQty'] = receivedQty;
  }
  if (note.trim().isEmpty) {
    s.remove('receiveNote');
  } else {
    s['receiveNote'] = note.trim();
  }
  if (photos.isEmpty) {
    s.remove('receivePhotos');
  } else {
    s['receivePhotos'] = List<String>.from(photos);
  }
  s['receivedAt'] = (at ?? DateTime.now()).toIso8601String();
  if (who.trim().isNotEmpty) s['receivedBy'] = who.trim();
  touchItem(s);
}

/// 입고 완료를 되돌릴 때: 들어온 수량·받은 시각만 지운다(메모·사진은 다시 받을 때 그대로 보이게 남긴다).
void undoMaterialReceipt(Map s) {
  s['isCompleted'] = false;
  s.remove('receivedQty');
  s.remove('receivedAt');
  s.remove('receivedBy');
  touchItem(s);
}
