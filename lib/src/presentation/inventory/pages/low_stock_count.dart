// 홈 화면 "재고 부족" 배지(필드 헬퍼 2번). 최소 수량 아래로 내려간 자재 수를 센다.
//
// 재고 부족 판정(isShortStock)은 이미 자재 현황 화면 안에 있었지만, 그 화면에 들어가야만
// 보였다. 오늘 일지 미작성 배지(fetchMissingReportCount)와 같은 자리에 두어, 현장 나가기
// 전에 홈만 보고 무엇을 챙겨야 하는지 알 수 있게 한다.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'inventory_owner.dart';
import 'inventory_view_logic.dart';

/// 자재 문서 목록에서 부족한 것 수를 센다(화면과 떼어 놓아서 검사할 수 있게).
/// 남의 개인 재고는 세지 않는다(자재 현황 화면과 같은 기준, canSeeStock).
int countLowStock(Iterable<Map<String, dynamic>> docs, String? uid) =>
    docs.where((d) => canSeeStock(d, uid) && isShortStock(d)).length;

/// 최소 수량 아래로 내려간 자재 수(홈 배지). 읽지 못하면 null.
Future<int?> fetchLowStockCount() async {
  try {
    final uid = currentStockUid();
    final col = FirebaseFirestore.instance.collection('inventory');
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await col.get().timeout(const Duration(seconds: 6));
    } on TimeoutException {
      // 통신이 없으면 폰에 남은 것으로(다른 목록 화면과 같은 방식).
      snapshot = await col.get(const GetOptions(source: Source.cache));
    }
    return countLowStock(snapshot.docs.map((d) => d.data()), uid);
  } catch (e) {
    debugPrint('재고 부족 수 읽기 실패: $e');
    return null;
  }
}
