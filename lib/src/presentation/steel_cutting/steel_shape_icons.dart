import 'package:flutter/material.dart';

// 형강 종류(카테고리)마다 아이콘을 하나씩 정한다. 목록·선택창·항목 카드가 모두 이 함수를 쓴다.
IconData iconForSteel(String category) {
  switch (category) {
    case 'ANGLE':
      return Icons.square_foot_rounded;
    case 'UNEQUAL':
      return Icons.square_foot_outlined;
    case 'CHANNEL':
      return Icons.view_week_rounded;
    case 'LIPC':
      return Icons.view_week_outlined;
    case 'STRUT':
      return Icons.horizontal_split_rounded;
    case 'FLAT':
      return Icons.horizontal_rule_rounded;
    case 'SQUARE':
      return Icons.crop_square_rounded;
    case 'ROUND':
      return Icons.circle_outlined;
    case 'BAR':
      return Icons.circle;
    case 'ROD':
      return Icons.linear_scale_rounded;
    case 'BEAM':
      return Icons.h_mobiledata_rounded;
    default:
      return Icons.edit_note_rounded;
  }
}
