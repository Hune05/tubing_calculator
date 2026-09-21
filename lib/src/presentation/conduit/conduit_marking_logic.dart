/// 전선관 마킹 셈. 화면과 떼어 놓아서 검사할 수 있게 한다.
///
/// 길이는 "꺾이는 점에서 꺾이는 점까지"로 본다(튜브 계산기와 같다).
/// 그래서 두 번째 벤드부터는 앞 벤드에서 줄어든 길이(게인)를 빼고 금을 긋는다.
/// 🚀 [고침] 예전에는 입력한 길이를 그대로 더해서, 총 자를 길이 셈은 게인을
/// 빼는데 마킹 자리는 빼지 않는 어긋남이 있었다(22mm EMT면 벤드마다 81mm).
///
/// 마킹 자리 = 꺾이는 점의 줄자 눈금 − 그 벤더의 "꺾이는 점에서 마킹까지"
/// ([conduitMarkOffset]). 수동·시카고는 테이크업, 유압(램)은 셋백이다.
/// 🚀 [고침] 예전에는 벤더 종류마다 셈이 따로 있어서, 램은 두 번째 벤드부터
/// 게인도 셋백도 빼지 않아 총 자를 길이와 맞지 않았다. 한 셈으로 합쳤다.
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

double _num(Map<String, dynamic> s, String key, double fallback) =>
    (s[key] as num?)?.toDouble() ?? fallback;

/// 꺾이는 점에서 마킹(화살표를 맞출 자리)까지의 거리.
///
/// - 수동·시카고: 테이크업. 표에는 90° 값만 있으니 각도에 맞게 줄인다.
/// - 유압(램): 셋백 설정값. 90°가 기준이고 다른 각도는 tan(θ/2) 비율로 줄인다.
///
/// 오프셋·새들 계산기가 첫 구간 길이를 잡을 때도 이 값을 더해야
/// "1번 마킹 = 시작 거리"가 된다. 🚀 [고침] 예전에는 그 계산기들이 튜브
/// 벤더의 반경(38.1)으로 셋백을 셈해서, 전선관(CLR 114.3)에서는 1번 마킹이
/// 앞 직관 안쪽으로 50mm 넘게 들어갔다.
double conduitMarkOffset(double angle, Map<String, dynamic> settings) {
  if (angle <= 0) return 0.0;
  final String benderType = settings['benderType'] ?? 'hand';
  if (benderType == 'ram') {
    final double setback90 = _num(settings, 'setback', 0.0);
    if (setback90 <= 0) return 0.0;
    if ((angle - 90.0).abs() < 0.1) return setback90;
    return setback90 * math.tan(angle * math.pi / 360.0);
  }
  return scaleTakeUp(
    _num(settings, 'takeUp', 0.0),
    _num(settings, 'clr', 0.0),
    angle,
  );
}

/// 마킹 목록. 항목마다 'mark'(줄자 눈금), 'gap'(앞 마킹에서 얼마나), 'note',
/// 'targetAngle'(스프링백을 얹은 꺾을 각도)에 벤더별 값(ramTravel·notches)이 붙는다.
List<Map<String, dynamic>> calculateConduitMarkings(
  List<Map<String, dynamic>> bendList,
  Map<String, dynamic> settings, {
  bool useCoupling = false,
}) {
  final String benderType = settings['benderType'] ?? 'hand';
  final double gain90 = _num(settings, 'gain', 0.0);
  final double couplingDepth = _num(settings, 'couplingDepth', 20.0);
  final bool applySpringback = settings['applySpringback'] ?? true;
  final double springbackVal = _num(settings, 'springback', 3.0);
  final double baseRamTravel = _num(settings, 'ramTravel', 0.0);
  final double degPerNotch = _num(settings, 'degPerNotch', 2.5);
  final String offsetName = benderType == 'ram' ? '셋백' : '테이크업';

  final markings = <Map<String, dynamic>>[];

  // 꺾이는 점의 줄자 눈금. 구간 길이를 더하고 앞 벤드의 게인을 뺀 것.
  // 커플링을 꽂으면 관 끝이 그만큼 안으로 들어가므로 줄자 0이 뒤로 간다.
  double developed = useCoupling ? -couplingDepth : 0.0;
  double prevMark = 0.0;
  double prevGain = 0.0;

  for (int i = 0; i < bendList.length; i++) {
    final bend = bendList[i];
    final double len = (bend['length'] as num).toDouble();
    final double angle = (bend['angle'] as num).toDouble();

    // 스프링백은 꺾을 각도에만 얹는다. 마킹 자리는 설계 각도로 잡는다.
    double targetAngle = angle;
    if (applySpringback && angle > 0) {
      targetAngle += springbackVal;
    }

    developed += len - prevGain;
    final double markOffset = conduitMarkOffset(angle, settings);
    final double mark = developed - markOffset;
    final bool isFirst = i == 0;
    final double gap = isFirst ? mark : mark - prevMark;

    String note;
    if (isFirst) {
      note = '';
      if (angle > 0) note += '$offsetName(-${markOffset.round()}mm) ';
      if (useCoupling) note += '커플링(-${couplingDepth.round()}mm) ';
      if (note.isEmpty) note = angle == 0.0 ? '직관 시작' : '첫 벤딩점';
    } else if (gap < 0) {
      // 앞 마킹보다 뒤로 가면 그 사이 곧은 부분이 벤더에 물릴 만큼 없다.
      note =
          '앞 마킹보다 ${(-gap).round()}mm 앞입니다. '
          '구간이 짧아 이대로는 만들 수 없습니다.';
    } else if (angle == 0.0) {
      note = '직관 연장 (앞 마킹 +${gap.round()}mm)';
    } else {
      note = '앞 마킹 +${gap.round()}mm';
      if (prevGain > 0) note += ' (앞 벤드 게인 -${prevGain.round()}mm)';
    }

    final item = <String, dynamic>{
      ...bend,
      'mark': mark,
      'gap': gap,
      'note': note.trim(),
      'benderType': benderType,
      'targetAngle': targetAngle,
      'short': !isFirst && gap < 0,
    };

    if (benderType == 'ram') {
      // 🚀 [보정] 유압 실린더 비선형 삼각함수 이동 거리 연산: Stroke ∝ sin(θ / 2)
      double ramTravelForBend = 0.0;
      if (angle > 0 && baseRamTravel > 0) {
        final double radTargetHalf = (targetAngle / 2.0) * (math.pi / 180.0);
        final double rad45 = 45.0 * (math.pi / 180.0);
        ramTravelForBend =
            baseRamTravel * (math.sin(radTargetHalf) / math.sin(rad45));
      }
      item['ramTravel'] = ramTravelForBend;
    } else if (benderType == 'chicago') {
      // 🚀 [보정] 과도한 꺾임(Over-bending) 방지를 위해 ceil 대신 round 적용
      item['notches'] = angle > 0 ? (targetAngle / degPerNotch).round() : 0;
    }

    markings.add(item);
    prevMark = mark;
    prevGain = conduitGainForAngle(angle, gain90);
  }
  return markings;
}

/// 전선관 규격 이름(22mm, G22, E25, 1/2" …)에서 바깥지름(mm)을 뽑는다.
/// 3D 그림에서 관 굵기를 실제대로 그릴 때 쓴다. 못 읽으면 0.
double conduitOuterDiameterMm(String size) {
  final s = size.trim();
  if (s.isEmpty) return 0.0;

  // "22mm", "G22", "E25", "22" 처럼 숫자가 곧 지름인 경우.
  final mm = RegExp(r'(\d+(?:\.\d+)?)\s*mm').firstMatch(s);
  if (mm != null) return double.tryParse(mm.group(1)!) ?? 0.0;

  final letter = RegExp(r'^[A-Za-z]+\s*(\d+(?:\.\d+)?)$').firstMatch(s);
  if (letter != null) return double.tryParse(letter.group(1)!) ?? 0.0;

  // 인치 표기("1/2\"", "3/4\"")는 인치를 mm로 바꾼다.
  final frac = RegExp(r'^(\d+)\s*/\s*(\d+)').firstMatch(s);
  if (frac != null) {
    final a = double.tryParse(frac.group(1)!) ?? 0;
    final b = double.tryParse(frac.group(2)!) ?? 0;
    if (b > 0) return a / b * 25.4;
  }

  final plain = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(s);
  if (plain != null) return double.tryParse(plain.group(1)!) ?? 0.0;
  return 0.0;
}
