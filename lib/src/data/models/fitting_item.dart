import 'package:flutter/material.dart';

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
