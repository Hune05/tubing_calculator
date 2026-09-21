import 'package:tubing_calculator/src/presentation/common/app_icons.dart';

// 형강 종류(카테고리)마다 아이콘을 하나씩 정한다. 목록·선택창·항목 카드가 모두 이 함수를 쓴다.
// 🚀 [바꿈] 기본 아이콘을 빌려 쓰던 것(H빔 = 글자 H 등)을 단면 그림으로.
AppGlyph iconForSteel(String category) {
  switch (category) {
    case 'ANGLE':
      return AppGlyph.stAngle;
    case 'UNEQUAL':
      return AppGlyph.stUnequal;
    case 'CHANNEL':
      return AppGlyph.stChannel;
    case 'LIPC':
      return AppGlyph.stLipC;
    case 'STRUT':
      return AppGlyph.stStrut;
    case 'FLAT':
      return AppGlyph.stFlat;
    case 'SQUARE':
      return AppGlyph.stSquare;
    case 'ROUND':
      return AppGlyph.stRound;
    case 'BAR':
      return AppGlyph.stBar;
    case 'ROD':
      return AppGlyph.stRod;
    case 'BEAM':
      return AppGlyph.stBeam;
    default:
      return AppGlyph.stChannel;
  }
}
