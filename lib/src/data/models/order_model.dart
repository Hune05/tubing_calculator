import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_item_model.dart';

class OrderModel {
  final String id;
  final String requester;
  final String assignee;
  final List<CartItemModel> items;
  final String status;
  final DateTime requestDate;
  final DateTime? expectedDate;
  final String? note;
  final String? rejectReason;

  OrderModel({
    required this.id,
    required this.requester,
    required this.assignee,
    required this.items,
    required this.status,
    required this.requestDate,
    this.expectedDate,
    this.note,
    this.rejectReason,
  });

  // 🔥 상태 업데이트를 위한 copyWith 메서드
  OrderModel copyWith({
    String? id,
    String? requester,
    String? assignee,
    List<CartItemModel>? items,
    String? status,
    DateTime? requestDate,
    DateTime? expectedDate,
    String? note,
    String? rejectReason,
  }) {
    return OrderModel(
      id: id ?? this.id,
      requester: requester ?? this.requester,
      assignee: assignee ?? this.assignee,
      items: items ?? this.items,
      status: status ?? this.status,
      requestDate: requestDate ?? this.requestDate,
      expectedDate: expectedDate ?? this.expectedDate,
      note: note ?? this.note,
      rejectReason: rejectReason ?? this.rejectReason,
    );
  }

  // 🔥 파이어베이스에 올리기 위한 Map 변환 (Timestamp 변환 포함)
  Map<String, dynamic> toMap() {
    return {
      'requester': requester,
      'assignee': assignee,
      'items': items.map((x) => x.toMap()).toList(),
      'status': status,
      'requestDate': Timestamp.fromDate(requestDate),
      'expectedDate': expectedDate != null
          ? Timestamp.fromDate(expectedDate!)
          : null,
      'note': note,
      'rejectReason': rejectReason,
    };
  }

  // 🔥 파이어베이스에서 내려받은 Map을 Dart 객체로 변환
  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id, // 파이어베이스의 문서 ID를 삽입
      requester: map['requester'] ?? '',
      assignee: map['assignee'] ?? '',
      items: map['items'] != null
          ? List<CartItemModel>.from(
              map['items'].map((x) => CartItemModel.fromMap(x)),
            )
          : [],
      status: map['status'] ?? '발주 대기',
      // Firestore의 Timestamp를 Dart의 DateTime으로 변환
      requestDate: map['requestDate'] != null
          ? (map['requestDate'] as Timestamp).toDate()
          : DateTime.now(),
      expectedDate: map['expectedDate'] != null
          ? (map['expectedDate'] as Timestamp).toDate()
          : null,
      note: map['note'],
      rejectReason: map['rejectReason'],
    );
  }
}
