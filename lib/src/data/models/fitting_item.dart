import 'package:flutter/material.dart';

// 🚀 [부속 검색 팝업 고도화] SmartFittingSelectorSheet의 "커스텀으로
// 직접 입력" 버튼이 이 id를 가진 FittingItem을 결과로 돌려주면,
// 호출한 화면이 실제 부속 선택 대신 커스텀 입력 다이얼로그를 띄우라는
// 신호로 해석한다.
const String kCustomFittingRequestId = '__custom_fitting_request__';

class FittingItem {
  final String id;
  final String maker; // 제조사
  final String tubeOD; // 튜브 외경
  final String category; // 분류 (Valve, Union, Adapter 등)
  final String name; // 이름
  final String threadType; // 나사산 종류
  final String threadSize; // 나사산 크기
  final double deduction; // 공제값

  // 🚀 새로 추가된 치트키 항목들!
  final double insertionDepth; // 튜브 삽입 깊이 (Seat Depth)
  final bool isCustom; // 커스텀(직접 입력) 여부

  final IconData icon;

  const FittingItem({
    required this.id,
    required this.maker,
    required this.tubeOD,
    required this.category,
    required this.name,
    this.threadType = "없음",
    this.threadSize = "없음",
    required this.deduction,
    this.insertionDepth = 0.0, // 기본값 0
    this.isCustom = false, // 기본값 false (커스텀 아님)
    required this.icon,
  });

  String get displayName {
    if (threadType != "없음" && threadSize != "없음") {
      return "$name ($threadType $threadSize)";
    }
    return name;
  }
}
