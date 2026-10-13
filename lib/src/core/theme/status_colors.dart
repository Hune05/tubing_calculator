// 색의 뜻(UI 디자인 제안 D-B, docs/UI디자인_산업용비교_2026-09-25.md).
//
// 공장 제어 화면 표준(ISA-101)처럼 색이 상태를 말하게 한다. 같은 뜻에는 같은 색만 쓴다.
//   청록(kBrand)  = 누르는 것·골라짐(앱의 주 색)
//   초록(kOk)     = 완료·수평·정상
//   주황(kCaution) = 주의·기한 임박·경고를 알고도 진행
//   빨강(kDanger) = 지우기·기한 넘김·경보만(새로 만들기·등록 같은 평소 행동에는 쓰지 않는다)
//   회색(kIdle)   = 없음·꺼짐·낮은 우선순위
library;

import 'package:flutter/painting.dart';

const Color kBrand = Color(0xFF007580);
const Color kOk = Color(0xFF1B9E5A);
const Color kCaution = Color(0xFFC77700);
// 흰 바탕에서 글자로 써도 읽히게(약 4.9:1) 조금 진한 빨강.
const Color kDanger = Color(0xFFD92D20);
const Color kIdle = Color(0xFF5F6B78);
