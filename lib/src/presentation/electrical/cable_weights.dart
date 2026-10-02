// 케이블 무게(kg/km, 개산) 표. 케이블 트레이 하중 계산에 쓴다(10-03).
// 값은 제조사 카탈로그 두 곳 이상에서 확인한 것만 넣는다. 다르면 큰 값(안전 쪽).
// 근거와 출처: docs/전기_케이블트레이_근거.md "케이블 무게".
library;

import 'conduit_tables.dart';

/// 한 가닥 무게(kg/km). 표에 없으면 null.
double? cableWeight(CableKind k, double size) => null;

const String cableWeightSource = '케이블 무게: 아직 표가 없습니다.';
