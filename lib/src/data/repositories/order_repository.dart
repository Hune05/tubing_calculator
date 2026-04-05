import 'dart:io'; // 🔥 File 객체를 사용하기 위해 필수
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // 🔥 파이어베이스 스토리지 필수!
import '../models/order_model.dart';
import '../models/cart_item_model.dart';

class OrderRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; // 스토리지 인스턴스 추가
  final String collectionPath = 'orders';

  // 🚀 실시간 스트림 (현황 탭 및 로그 화면 자동 업데이트)
  Stream<List<OrderModel>> streamOrders() {
    return _db
        .collection(collectionPath)
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // 🚀 새로운 발주 등록
  Future<void> addOrder(OrderModel order) async {
    await _db.collection(collectionPath).add(order.toMap());
  }

  // 🚀 기존 발주 상태 업데이트 (반려, 완료, 날짜 변경 등)
  Future<void> updateOrder(OrderModel order) async {
    if (order.id.isNotEmpty) {
      await _db.collection(collectionPath).doc(order.id).update(order.toMap());
    }
  }

  // 🚀 사진 업로드 (Firebase Storage 완벽 연동)
  Future<String> uploadImage(String localPath) async {
    try {
      File file = File(localPath);

      // 파일이 실제로 존재하는지 안전 확인
      if (!await file.exists()) {
        throw Exception("파일을 찾을 수 없습니다.");
      }

      // 고유한 파일명 생성 (타임스탬프 활용하여 중복 방지)
      String fileName =
          'order_img_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Firebase Storage의 'orders' 폴더 안에 저장하도록 경로 설정
      Reference ref = _storage.ref().child('orders/$fileName');

      // 파일 업로드 실행
      UploadTask uploadTask = ref.putFile(file);

      // 업로드가 완료될 때까지 대기
      TaskSnapshot snapshot = await uploadTask;

      // 업로드된 파일의 웹 접속(다운로드) URL 가져오기
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl; // 성공 시 진짜 파이어베이스 URL 반환!
    } catch (e) {
      print("🚨 이미지 업로드 실패: $e");
      // 업로드 실패 시 에러를 던져서 프론트(UI)쪽에서 스낵바로 알려주게 함
      throw Exception("이미지 업로드 중 오류가 발생했습니다.");
    }
  }
}
