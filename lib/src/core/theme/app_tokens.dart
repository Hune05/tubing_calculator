// 디자인 토큰 한 벌(UI 디자인 제안 D-A, docs/UI디자인_산업용비교_2026-09-25.md).
//
// 예전에는 화면마다 색·글자 크기를 직접 적어 색 선언이 490곳, 색값 112가지, 글자 크기
// 25가지였다. 이제 색·글자·모서리·간격은 여기 한 곳에서 정하고, 화면은 이름으로 가져다 쓴다.
// 색의 뜻(청록·초록·주황·빨강·회색)은 status_colors.dart와 같다.
library;

import 'package:flutter/material.dart';

import 'status_colors.dart';

/// 앱 글꼴(assets/fonts/NotoSansKR-VariableFont_wght.ttf, pubspec의 NotoSansKR).
/// 폰마다 기본 글꼴이 달라 줄바꿈 위치가 달랐던 것을 맞춘다.
const String kAppFontFamily = 'NotoSansKR';

/// 색 역할. 값은 이름으로 쓰고, 같은 역할에 다른 값을 새로 만들지 않는다.
abstract final class AppColors {
  // 주 색(누르는 것·골라짐)
  static const Color brand = kBrand; // #007580
  static const Color onBrand = Color(0xFFFFFFFF);
  static const Color brandSoft = Color(0xFFE6F2F3); // 옅은 청록 바탕(골라짐 배경 등)

  // 바탕·표면
  static const Color background = Color(0xFFF2F4F6); // 화면 바탕(옅은 회색)
  static const Color surface = Color(0xFFFFFFFF); // 카드·창·앱바
  static const Color fill = Color(0xFFF2F4F6); // 입력칸·칩 바탕
  static const Color line = Color(0xFFE5E8EB); // 나눔선·테두리

  // 글자
  static const Color text = Color(0xFF191F28); // 본문·제목(흰 바탕 약 16:1)
  static const Color textSub = Color(0xFF5F6B78); // 보조 글(약 5.4:1)
  static const Color textFaint = Color(0xFF8B95A1); // 힌트·꺼진 것(글 본문에는 쓰지 않는다)

  // 상태(색의 뜻)
  static const Color ok = kOk;
  static const Color caution = kCaution;
  static const Color danger = kDanger;
  static const Color idle = kIdle;
}

/// 글자 크기 7단 + 굵기 3단. 숫자 표시(계측값)는 자리 맞춤 숫자를 쓴다.
abstract final class AppText {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w600;
  static const FontWeight bold = FontWeight.w800;

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// 큰 계측값(총 절단 길이, 수평계 각도 등).
  static const TextStyle numberLarge = TextStyle(
    fontFamily: kAppFontFamily,
    fontSize: 40,
    fontWeight: bold,
    height: 1.1,
    color: AppColors.text,
    fontFeatures: _tabular,
  );

  /// 카드 안 계측값.
  static const TextStyle number = TextStyle(
    fontFamily: kAppFontFamily,
    fontSize: 28,
    fontWeight: bold,
    height: 1.15,
    color: AppColors.text,
    fontFeatures: _tabular,
  );

  /// 화면 제목.
  static const TextStyle title = TextStyle(
    fontFamily: kAppFontFamily,
    fontSize: 20,
    fontWeight: bold,
    height: 1.3,
    color: AppColors.text,
  );

  /// 카드·구역 제목.
  static const TextStyle subtitle = TextStyle(
    fontFamily: kAppFontFamily,
    fontSize: 17,
    fontWeight: medium,
    height: 1.35,
    color: AppColors.text,
  );

  /// 본문.
  static const TextStyle body = TextStyle(
    fontFamily: kAppFontFamily,
    fontSize: 15,
    fontWeight: regular,
    height: 1.45,
    color: AppColors.text,
  );

  /// 보조 글(설명·부가 정보).
  static const TextStyle sub = TextStyle(
    fontFamily: kAppFontFamily,
    fontSize: 13,
    fontWeight: regular,
    height: 1.4,
    color: AppColors.textSub,
  );

  /// 캡션·라벨(칸 이름, 단위, 배지).
  static const TextStyle caption = TextStyle(
    fontFamily: kAppFontFamily,
    fontSize: 12,
    fontWeight: medium,
    height: 1.3,
    color: AppColors.textSub,
  );
}

/// 모서리 3단.
abstract final class AppRadius {
  static const double small = 8; // 칩·입력칸·작은 단추
  static const double medium = 12; // 단추·카드 안 칸
  static const double large = 20; // 카드·창·아래 시트
}

/// 간격(4의 배수).
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}
