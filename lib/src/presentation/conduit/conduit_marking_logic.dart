/// 전선관 마킹 셈. 화면과 떼어 놓아서 검사할 수 있게 한다.
///
/// 길이는 "꺾이는 점에서 꺾이는 점까지"로 본다(튜브 계산기와 같다).
/// 그래서 두 번째 벤드부터는 앞 벤드에서 줄어든 길이(게인)를 빼고 금을 긋는다.
/// 🚀 [고침] 예전에는 입력한 길이를 그대로 더해서, 총 자를 길이 셈은 게인을
/// 빼는데 마킹 자리는 빼지 않는 어긋남이 있었다(22mm EMT면 벤드마다 81mm).
library;

import 'dart:math' as math;

import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';

/// 각도별 게인. 표에는 90° 값 하나만 있으므로 기하 비율로 줄인다.
double conduitGainForAngle(double angle, double gain90) {
  if (angle <= 0 || gain90 <= 0) return 0.0;
  // 부동소수점 오차 방지: 90도 근처면 정확히 90도 게인 반환
  if ((angle - 90.0).abs() < 0.1) return gain90;

  // 기하학적 배관 절약분 이론 공식에 따른 각도별 비례 연산
  // Gain(θ) / Gain(90) = [2 * tan(θ/2) - (π * θ / 180)] / [2 - π/2]
  double radHalf = (angle / 2.0) * (math.pi / 180.0);
  double radFull = angle * (math.pi / 180.0);
  double numerator = 2.0 * math.tan(radHalf) - radFull;
  double denominator = 2.0 - (math.pi / 2.0); // 약 0.42920367

  if (denominator == 0) return 0.0;
  return gain90 * (numerator / denominator);
}

// ==========================================
// 🚀 [라우터] 설정값에 따라 계산기 분리
// ==========================================
List<Map<String, dynamic>> calculateConduitMarkings(
  List<Map<String, dynamic>> bendList,
  Map<String, dynamic> settings, {
  bool useCoupling = false,
}) {
  String benderType = settings['benderType'] ?? 'hand';

  if (benderType == 'ram') {
    return _ramMarkings(bendList, settings, useCoupling);
  } else if (benderType == 'chicago') {
    return _chicagoMarkings(bendList, settings, useCoupling);
  } else {
    return _handMarkings(bendList, settings, useCoupling);
  }
}

// ------------------------------------------
// 🧮 1. 수동 벤더(Hand) - TakeUp & Gain 보정
// ------------------------------------------
List<Map<String, dynamic>> _handMarkings(
  List<Map<String, dynamic>> bendList,
  Map<String, dynamic> settings,
  bool useCoupling,
) {
  List<Map<String, dynamic>> markings = [];
  double currentTapeMark = 0.0;

  double takeUp90 = settings['takeUp'] ?? 152.0;
  double clr = settings['clr'] ?? 0.0;
  double gain90 = settings['gain'] ?? 0.0;
  double couplingDepth = settings['couplingDepth'] ?? 20.0;
  bool applySpringback = settings['applySpringback'] ?? true;
  double springbackVal = settings['springback'] ?? 3.0;

  // 앞 벤드에서 줄어든 길이(게인). 다음 마킹 자리를 그만큼 당겨야 한다.
  double prevGain = 0.0;
  // 앞 벤드에 쓴 테이크업(각도가 다르면 값도 다르다).
  double prevTakeUp = 0.0;

  for (int i = 0; i < bendList.length; i++) {
    var bend = bendList[i];
    double len = (bend['length'] as num).toDouble();
    double angle = (bend['angle'] as num).toDouble();

    // 스프링백 보정
    double targetAngle = angle;
    if (applySpringback && angle > 0) {
      targetAngle += springbackVal;
    }

    // 🚀 [고침] 45°든 90°든 90° 테이크업을 그대로 빼고 있었다.
    // 각도에 맞게 줄여서 뺀다(90°면 예전과 같은 값).
    final double takeUp = scaleTakeUp(takeUp90, clr, angle);
    final double myGain = conduitGainForAngle(angle, gain90);

    bool isFirst = (i == 0);
    String note = '';
    double offset = len;

    // 줄자 마킹 위치 계산 (화살표를 맞출 자리)
    if (isFirst) {
      if (angle > 0) {
        offset -= takeUp;
        note += '테이크업(-${takeUp.round()}mm) ';
      }
      if (useCoupling) {
        offset -= couplingDepth;
        note += '커플링(-${couplingDepth.round()}mm) ';
      }
      if (note.isEmpty) {
        note = angle == 0.0 ? '직관 시작' : '첫 벤딩점';
      }
      currentTapeMark = offset;
    } else {
      // 🚀 [고침] 예전에는 입력한 길이를 그대로 더해서, 두 번째 벤드부터
      // 앞 벤드의 게인(22mm EMT면 81mm)만큼 뒤로 밀린 자리에 금을 그었다.
      // 길이는 꺾이는 점에서 꺾이는 점까지로 보므로, 앞 벤드에서 줄어든
      // 만큼 빼고 테이크업 차이를 더해 준다. 총 자를 길이 셈과도 맞는다.
      double gap = len - prevGain - takeUp + prevTakeUp;
      currentTapeMark += gap;
      offset = gap;
      note = angle == 0.0
          ? '직관 연장'
          : '간격 누적 (+${gap.round()}mm · 게인 -${prevGain.round()}mm)';
    }

    prevGain = myGain;
    prevTakeUp = takeUp;

    markings.add({
      ...bend,
      'mark': currentTapeMark,
      'gap': offset,
      'note': note.trim(),
      'benderType': 'hand',
      'targetAngle': targetAngle,
    });
  }
  return markings;
}

// ------------------------------------------
// 🧮 2. 유압식(Ram) - 3점 벤딩 비선형 공식 적용
// ------------------------------------------
List<Map<String, dynamic>> _ramMarkings(
  List<Map<String, dynamic>> bendList,
  Map<String, dynamic> settings,
  bool useCoupling,
) {
  List<Map<String, dynamic>> markings = [];
  double currentTapeMark = 0.0;

  double setback = settings['setback'] ?? 0.0;
  double baseRamTravel = settings['ramTravel'] ?? 0.0;
  double couplingDepth = settings['couplingDepth'] ?? 20.0;
  bool applySpringback = settings['applySpringback'] ?? true;
  double springbackVal = settings['springback'] ?? 3.0;

  for (int i = 0; i < bendList.length; i++) {
    var bend = bendList[i];
    double len = (bend['length'] as num).toDouble();
    double angle = (bend['angle'] as num).toDouble();

    double targetAngle = angle;
    if (applySpringback && angle > 0) {
      targetAngle += springbackVal;
    }

    bool isFirst = (i == 0);
    String note = '';
    double offset = len;

    // 🚀 [보정] 유압 실린더 비선형 삼각함수 이동 거리 연산: Stroke ∝ sin(θ / 2)
    double ramTravelForBend = 0.0;
    if (angle > 0 && baseRamTravel > 0) {
      double radTargetHalf = (targetAngle / 2.0) * (math.pi / 180.0);
      double rad45 = 45.0 * (math.pi / 180.0);
      ramTravelForBend =
          baseRamTravel * (math.sin(radTargetHalf) / math.sin(rad45));
    }

    if (isFirst) {
      if (angle > 0) {
        offset -= setback;
        note += '셋백(-${setback.round()}mm) ';
      }
      if (useCoupling) {
        offset -= couplingDepth;
        note += '커플링(-${couplingDepth.round()}mm) ';
      }
      if (note.isEmpty) {
        note = angle == 0.0 ? '직관 시작' : '첫 벤딩점';
      }
      currentTapeMark = offset;
    } else {
      double gap = len;
      currentTapeMark += gap;
      offset = gap;
      note = angle == 0.0 ? '직관 연장' : '간격 누적 (+${gap.round()}mm)';
    }

    markings.add({
      ...bend,
      'mark': currentTapeMark,
      'gap': offset,
      'note': note.trim(),
      'benderType': 'ram',
      'ramTravel': ramTravelForBend,
      'targetAngle': targetAngle,
    });
  }
  return markings;
}

// ------------------------------------------
// 🧮 3. 시카고식(Chicago) - 반올림 보정
// ------------------------------------------
List<Map<String, dynamic>> _chicagoMarkings(
  List<Map<String, dynamic>> bendList,
  Map<String, dynamic> settings,
  bool useCoupling,
) {
  List<Map<String, dynamic>> markings = [];
  double currentTapeMark = 0.0;

  double couplingDepth = settings['couplingDepth'] ?? 20.0;
  double degPerNotch = settings['degPerNotch'] ?? 2.5;
  double takeUp90 = settings['takeUp'] ?? 0.0;
  double clr = settings['clr'] ?? 0.0;
  double gain90 = settings['gain'] ?? 0.0;
  bool applySpringback = settings['applySpringback'] ?? true;
  double springbackVal = settings['springback'] ?? 3.0;

  double prevGain = 0.0;
  double prevTakeUp = 0.0;

  for (int i = 0; i < bendList.length; i++) {
    var bend = bendList[i];
    double len = (bend['length'] as num).toDouble();
    double angle = (bend['angle'] as num).toDouble();

    double targetAngle = angle;
    if (applySpringback && angle > 0) {
      targetAngle += springbackVal;
    }

    // 각도에 맞게 줄인 테이크업(90°면 예전과 같은 값).
    final double takeUp = scaleTakeUp(takeUp90, clr, angle);
    final double myGain = conduitGainForAngle(angle, gain90);

    bool isFirst = (i == 0);
    String note = '';
    double offset = len;

    // 🚀 [보정] 과도한 꺾임(Over-bending) 방지를 위해 ceil 대신 round 적용
    int notches = angle > 0 ? (targetAngle / degPerNotch).round() : 0;

    if (isFirst) {
      // 🚀 [버그 수정] 시카고식도 슈에 감아 구부리는 구조라 수동 벤더의
      // 테이크업과 동일한 여유 길이 차감이 필요함 (이전엔 누락되어 있었음).
      if (angle > 0) {
        offset -= takeUp;
        note += '테이크업(-${takeUp.round()}mm) ';
      }
      if (useCoupling) {
        offset -= couplingDepth;
        note += '커플링(-${couplingDepth.round()}mm) ';
      }
      if (note.isEmpty) {
        note = angle == 0.0 ? '직관 시작' : '첫 벤딩점';
      }
      currentTapeMark = offset;
    } else {
      // 수동 벤더와 같다 — 앞 벤드에서 줄어든 만큼 당겨 준다.
      double gap = len - prevGain - takeUp + prevTakeUp;
      currentTapeMark += gap;
      offset = gap;
      note = angle == 0.0
          ? '직관 연장'
          : '간격 누적 (+${gap.round()}mm · 게인 -${prevGain.round()}mm)';
    }

    prevGain = myGain;
    prevTakeUp = takeUp;

    markings.add({
      ...bend,
      'mark': currentTapeMark,
      'gap': offset,
      'note': note.trim(),
      'benderType': 'chicago',
      'notches': notches,
      'targetAngle': targetAngle,
    });
  }
  return markings;
}
