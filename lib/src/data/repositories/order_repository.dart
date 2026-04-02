// lib/src/data/repositories/order_repository.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // 🚀 스토리지 임포트 추가
import '../models/order_model.dart';

class OrderRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; // 🚀 스토리지 인스턴스

  // 1. 신규 발주 DB에 쏘기
  Future<void> addOrder(OrderModel order) async {
    await _db.collection('material_orders').add(order.toJson());
  }

  // 2. 실시간 발주 현황 가져오기
  Stream<List<OrderModel>> streamOrders() {
    return _db
        .collection('material_orders')
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  // 3. 발주 상태 업데이트
  Future<void> updateOrder(OrderModel order) async {
    await _db
        .collection('material_orders')
        .doc(order.id)
        .update(order.toJson());
  }

  // 🚀 [신규] 사진을 Storage에 올리고 다운로드 URL 반환하는 함수
  Future<String> uploadImage(String filePath) async {
    File file = File(filePath);

    // 파일 이름이 겹치지 않게 현재 시간(밀리초)을 붙여서 고유한 이름 생성
    String fileName =
        'material_orders/${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';

    // 파이어베이스 스토리지에 파일 업로드
    TaskSnapshot snapshot = await _storage.ref(fileName).putFile(file);

    // 업로드 완료 후 어디서든 볼 수 있는 인터넷 URL 주소 받아오기
    String downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }
}
