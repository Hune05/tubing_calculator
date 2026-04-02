// lib/src/data/models/order_model.dart

import 'cart_item_model.dart';

class OrderModel {
  final String id; // 발주 번호 (문서 ID)
  final String requester; // 요청자 (작업자)
  final String assignee; // 수신자 (담당자)
  final List<CartItemModel> items; // 발주 품목 리스트
  final String status; // 발주 대기, 발주 확인, 진행중, 처리 완료, 반려됨
  final DateTime requestDate; // 납기 희망일
  final DateTime? expectedDate; // 확정 입고 예정일
  final String? note; // 전체 요청사항
  final String? rejectReason; // 반려 사유

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

  // DB에서 가져올 때
  factory OrderModel.fromJson(Map<String, dynamic> json, String documentId) {
    return OrderModel(
      id: documentId,
      requester: json['requester'] ?? '알 수 없음',
      assignee: json['assignee'] ?? '미지정',
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (item) => CartItemModel.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      status: json['status'] ?? '발주 대기',
      // Firestore의 Timestamp를 DateTime으로 변환 (에러 방지 처리)
      requestDate: json['requestDate'] != null
          ? DateTime.parse(json['requestDate'].toDate().toString())
          : DateTime.now(),
      expectedDate: json['expectedDate'] != null
          ? DateTime.parse(json['expectedDate'].toDate().toString())
          : null,
      note: json['note'],
      rejectReason: json['rejectReason'],
    );
  }

  // DB로 보낼 때
  Map<String, dynamic> toJson() {
    return {
      'requester': requester,
      'assignee': assignee,
      'items': items.map((item) => item.toJson()).toList(),
      'status': status,
      'requestDate': requestDate, // Firestore 연동 시 Timestamp 래핑 필요
      if (expectedDate != null) 'expectedDate': expectedDate,
      if (note != null) 'note': note,
      if (rejectReason != null) 'rejectReason': rejectReason,
    };
  }

  // 데이터 상태 변경을 쉽게 해주는 헬퍼 (불변성 유지)
  OrderModel copyWith({
    String? status,
    DateTime? expectedDate,
    String? rejectReason,
  }) {
    return OrderModel(
      id: id,
      requester: requester,
      assignee: assignee,
      items: items,
      requestDate: requestDate,
      note: note,
      status: status ?? this.status,
      expectedDate: expectedDate ?? this.expectedDate,
      rejectReason: rejectReason ?? this.rejectReason,
    );
  }
}
