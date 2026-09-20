// 자재 화면이 쓰는 잔글씨 계산. 화면과 떼어 놓아서 검사(test)로 확인할 수 있게 한다.

/// 자재 규격. 등록·실사 화면은 'spec'으로 저장하는데 현황 화면만 'size'를
/// 읽고 있어서 규격이 늘 빈칸으로 보였다. 둘 다 본다.
String inventorySpecOf(Map<String, dynamic> data) {
  final spec = (data['spec'] ?? data['size'] ?? '').toString().trim();
  return spec;
}

/// 목록 한 줄에 붙는 "규격  |  보관 위치". 빈 칸은 아예 빼서
/// "-  |  H-2 자재렉"처럼 허전하게 보이지 않게 한다.
String inventorySpecAndPlace(Map<String, dynamic> data) {
  final parts = <String>[];
  final spec = inventorySpecOf(data);
  if (spec.isNotEmpty) parts.add(spec);
  final place = (data['location'] ?? '').toString().trim();
  if (place.isNotEmpty) parts.add(place);
  if (parts.isEmpty) return '규격·위치 미기재';
  return parts.join('  |  ');
}

/// 재고가 최소 수량 아래로 내려갔는지. 최소 수량을 안 적어 둔 자재는 따지지 않는다.
/// (최소 수량은 "이만큼은 늘 있어야 한다"는 뜻이라, 그 수량까지 내려오면 모자란 것으로 본다.)
bool isShortStock(Map<String, dynamic> data) {
  final min = (data['minQty'] as num?)?.toInt() ?? 0;
  if (min <= 0) return false;
  final qty = (data['qty'] as num?)?.toInt() ?? 0;
  return qty <= min;
}

/// 잔재를 규격별로 묶어 보여 줄 때 쓰는 정렬 순서.
/// 규격 이름순, 같은 규격 안에서는 긴 것부터(긴 잔재를 먼저 쓰게 된다).
int compareLeftoverRow(
  String labelA,
  double lengthA,
  String labelB,
  double lengthB,
) {
  final c = labelA.compareTo(labelB);
  if (c != 0) return c;
  return lengthB.compareTo(lengthA);
}
