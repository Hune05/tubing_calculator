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

  /// 사용자가 실제 부속을 재서 이 폰에 기억해 둔 공제값이면 true(카탈로그 값을 덮은 것).
  final bool measured;

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
    this.measured = false,
    required this.icon,
  });

  String get displayName {
    if (threadType != "없음" && threadSize != "없음") {
      return "$name ($threadType $threadSize)";
    }
    return name;
  }

  /// 공제값이 카탈로그 확정값이 아니라 크기별 기준값에 계수를 곱해 만든 **근사값**인지.
  /// 직접 입력한 부속·직관("없음")·사용자가 잰 값(실측)은 근사값이 아니다.
  bool get isApprox =>
      !measured &&
      !isCustom &&
      category != 'CUSTOM' &&
      maker != 'CUSTOM' &&
      maker != 'ALL' &&
      id != 'none' &&
      id != 'custom_input' &&
      id != kCustomFittingRequestId;

  FittingItem copyWith({double? deduction, bool? measured}) => FittingItem(
    id: id,
    maker: maker,
    tubeOD: tubeOD,
    category: category,
    name: name,
    threadType: threadType,
    threadSize: threadSize,
    deduction: deduction ?? this.deduction,
    insertionDepth: insertionDepth,
    isCustom: isCustom,
    measured: measured ?? this.measured,
    icon: icon,
  );
}
