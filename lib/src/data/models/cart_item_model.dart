// lib/src/data/models/cart_item_model.dart

class CartItemModel {
  final String title;
  final String qty;
  final String type; // 일반 자재, 브라켓 제작, 레이저 가공
  final String? fabSpec;
  final List<String>? photos; // 임시로 파일 경로(String) 저장, 나중엔 URL

  CartItemModel({
    required this.title,
    required this.qty,
    required this.type,
    this.fabSpec,
    this.photos,
  });

  // DB(Firestore)에서 데이터를 가져올 때 쓰는 공장
  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      title: json['title'] ?? '',
      qty: json['qty'] ?? '',
      type: json['type'] ?? '일반 자재',
      fabSpec: json['fabSpec'],
      photos: json['photos'] != null ? List<String>.from(json['photos']) : null,
    );
  }

  // DB(Firestore)로 데이터를 보낼 때 쓰는 포장기
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'qty': qty,
      'type': type,
      if (fabSpec != null) 'fabSpec': fabSpec,
      if (photos != null && photos!.isNotEmpty) 'photos': photos,
    };
  }
}
