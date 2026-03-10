import 'package:flutter/material.dart';

class FittingItem {
  final String id;
  final String maker; // 추가됨: 제조사 (Swagelok, Hy-Lok 등)
  final String tubeOD; // 추가됨: 튜브 외경 (1/4", 1/2" 등)
  final String category;
  final String name;
  final String threadType;
  final String threadSize;
  final double deduction;
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
    required this.icon,
  });

  String get displayName {
    if (threadType != "없음" && threadSize != "없음") {
      return "$name ($threadType $threadSize)";
    }
    return name;
  }
}
