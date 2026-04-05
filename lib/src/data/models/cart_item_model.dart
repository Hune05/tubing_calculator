class CartItemModel {
  final String title;
  final String qty;
  final String type;
  final String? fabSpec;
  final List<String>? photos;

  CartItemModel({
    required this.title,
    required this.qty,
    required this.type,
    this.fabSpec,
    this.photos,
  });

  // 🔥 Dart 객체를 파이어베이스용 Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'qty': qty,
      'type': type,
      'fabSpec': fabSpec,
      'photos': photos,
    };
  }

  // 🔥 파이어베이스 Map을 Dart 객체로 변환
  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      title: map['title'] ?? '',
      qty: map['qty'] ?? '',
      type: map['type'] ?? '일반 자재',
      fabSpec: map['fabSpec'],
      photos: map['photos'] != null ? List<String>.from(map['photos']) : null,
    );
  }
}
