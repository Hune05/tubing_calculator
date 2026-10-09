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
import 'package:tubing_calculator/src/presentation/calculator/bend_check.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/skid_presets.dart'
    show kThickConduitOd;

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

/// 유압(가운데 미는 방식): 꺾이는 점에서 슈 가운데 마킹까지 = 그 각도 게인 ÷ 2.
double ramShoeCenterOffset(double angle, double gain90) =>
    conduitGainForAngle(angle, gain90) / 2.0;

// ───────── 치수 기준(관 중심 / 관 등) ─────────
// 10-09 사용자: 길이를 늘 가상의 중심선(관 중심)으로 재는데 앱 칸은 "관 등까지"라 매번 바깥지름
// 절반(22mm 후강 13)을 빼거나 더해야 했다. 셈 식은 기준과 상관없이 같고, 길이·게인·테이크업이
// 같은 기준이면 된다. 그래서 기준을 고르게 하고, 입력 칸·시험 벤딩 안내를 그 기준으로 말한다.
// 제조사 표 값(관 등 기준)은 표에서 채울 때만 바깥지름만큼 바꿔 넣는다(이미 넣은 값은 그대로).

const String kConduitMeasureRefKey = 'measureRef';
const String kConduitRefCenter = 'center';
const String kConduitRefBack = 'back';

/// 길이를 관 중심(가상의 중심선)으로 재는지. 없으면 예전처럼 관 등.
bool conduitCenterRef(Map<String, dynamic> s) =>
    s[kConduitMeasureRefKey] == kConduitRefCenter;

/// 입력 칸·안내에 쓰는 말.
String conduitRefPhrase(Map<String, dynamic> s) =>
    conduitCenterRef(s) ? '관 중심(가상 중심선)' : '관 등(바깥면)';

/// EMT 바깥지름(mm). ANSI C80.3 — 앱의 EMT 규격 이름(16~54)은 제조사 표처럼 1/2"~2"에 맞춘다.
const Map<int, double> kEmtOd = {
  16: 17.9,
  22: 23.4,
  28: 29.5,
  36: 38.4,
  42: 44.2,
  54: 55.8,
};

/// 고른 전선관의 바깥지름. 모르면 null.
double? conduitOuterDiameter(String? conduitType, String? conduitSize) {
  final m = RegExp(r'(\d+)').firstMatch(conduitSize ?? '');
  if (m == null) return null;
  final n = int.parse(m.group(1)!);
  return (conduitType ?? '').toUpperCase().contains('EMT')
      ? kEmtOd[n]
      : kThickConduitOd[n];
}

/// 관 등 기준 제조사 표 값(90° 테이크업·게인)을 고른 기준으로. 관 중심이면 90°에서
/// 꺾이는 점이 다리마다 바깥지름 절반 안쪽으로 오므로 테이크업 − D/2, 게인 − D.
({double takeUp, double gain}) conduitTableValuesForRef({
  required double takeUp,
  required double gain,
  required double? od,
  required bool center,
}) {
  if (!center || od == null || od <= 0) return (takeUp: takeUp, gain: gain);
  return (takeUp: takeUp - od / 2, gain: gain - od);
}

/// 꺾이는 점에서 마킹(화살표를 맞출 자리)까지의 거리.
///
/// - 수동·시카고: 테이크업. 표에는 90° 값만 있으니 각도에 맞게 줄인다.
/// - 유압(램): 가운데서 미는 방식이라 마킹을 슈 가운데에 맞춘다. 슈 가운데가 닿는 자리는
///   굽은 부분(호)의 한가운데라, 꺾이는 점에서 그 각도 게인의 절반만큼 앞이다
///   (셋백 R·tan(θ/2) − 호의 절반 R·θ/2 = 게인/2, 관 등 기준으로 재도 같다).
///   10-09 사용자: "슈의 가운데에 맞추고", 실측 게인 40·슈 반경 93(93×0.4292 = 39.9).
///   예전에는 '셋백' 칸(표 22mm 175, 사용자는 반경 93을 넣음)만큼 앞에 찍어 90°에서
///   73mm 앞에 마킹했다. 셋백 칸은 이제 셈에 쓰지 않는다.
///
/// 오프셋·새들 계산기가 첫 구간 길이를 잡을 때도 이 값을 더해야
/// "1번 마킹 = 시작 거리"가 된다. 🚀 [고침] 예전에는 그 계산기들이 튜브
/// 벤더의 반경(38.1)으로 셋백을 셈해서, 전선관(CLR 114.3)에서는 1번 마킹이
/// 앞 직관 안쪽으로 50mm 넘게 들어갔다.
double conduitMarkOffset(double angle, Map<String, dynamic> settings) {
  if (angle <= 0) return 0.0;
  final String benderType = settings['benderType'] ?? 'hand';
  if (benderType == 'ram') {
    return ramShoeCenterOffset(angle, _num(settings, 'gain', 0.0));
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
  final bool applySpringback = settings['applySpringback'] ?? true;
  final double springbackVal = _num(settings, 'springback', 3.0);
  final double baseRamTravel = _num(settings, 'ramTravel', 0.0);
  final double degPerNotch = _num(settings, 'degPerNotch', 2.5);
  final String offsetName = benderType == 'ram' ? '슈 가운데' : '테이크업';

  final markings = <Map<String, dynamic>>[];

  // 꺾이는 점의 줄자 눈금. 구간 길이를 더하고 앞 벤드의 게인을 뺀 것.
  // 커플링을 체결하면 줄자 0점을 커플링 끝에 댄다. 나사 물림(탭 깊이)에 따라
  // 관이 들어가는 깊이가 매번 달라서, 깊이를 빼서 셈하면 마킹이 같이 흔들린다.
  // 그래서 마킹은 옮기지 않고, 자를 길이에만 끝 여유를 더한다(conduitTotalCut).
  double developed = 0.0;
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
      if (useCoupling) note += '줄자 0점: 커플링 끝 ';
      if (note.isEmpty) note = angle == 0.0 ? '직관 시작' : '첫 벤딩점';
    } else if (gap < 0) {
      // 앞 마킹보다 앞에 찍힌다. 앞이 직관이면 한 줄로 이어진 관이라 꺾을 수는
      // 있다(금 긋는 순서만 거꾸로). 만들 수 있는지는 위 띠(conduitBendCheck)가 본다.
      note = '앞 마킹보다 ${(-gap).round()}mm 앞에 찍힙니다(순서가 거꾸로).';
    } else if (angle == 0.0) {
      note = '직관 연장 (앞 마킹 +${gap.round()}mm)';
    } else {
      note = '앞 마킹 +${gap.round()}mm';
      if (prevGain > 0) note += ' (앞 벤드 게인 -${prevGain.round()}mm)';
    }

    // 90°를 넘는 벤드(예전 판에서 저장한 목록)는 게인 셈이 맞지 않는다.
    if (angle > 90.0 + 1e-9) {
      note = '$note 90°를 넘는 벤드는 게인·마킹 값이 맞지 않습니다. 90° 이하로 나누십시오.'.trim();
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

/// 마킹 탭 위에 띄울 형상 점검(짧은 구간·못 꺾는 방향·관끼리 닿음).
///
/// 튜브 마킹 화면과 같은 점검([checkBends])을 CLR로 돌린다. 직관은 다음
/// 구간에 합쳐서 보므로, 직관 뒤의 짧은 구간을 "만들 수 없다"고 하지 않는다.
BendCheck conduitBendCheck(
  List<Map<String, dynamic>> bendList,
  Map<String, dynamic> settings, {
  String startDir = 'RIGHT',
}) {
  final base = checkBends(
    bendList,
    radius: _num(settings, 'clr', 0.0),
    startDir: startDir,
    outerDiameter: conduitDrawOuterDiameterMm(settings),
    warnZeroRadius: false,
  );
  final extra = conduitMarkWarnings(bendList, settings);
  if (extra.isEmpty) return base;
  return BendCheck(
    warnings: [...extra, ...base.warnings],
    rollByIndex: base.rollByIndex,
  );
}

/// 마킹 자리로 보는 경고(10-09). 형상 점검(checkBends)은 CLR로만 봐서 못 잡던 것:
/// - 벤드 마킹이 관 끝(0)이나 그보다 앞에 찍힘(22mm 수동 90°에 길이 120이면 −32mm) — 꺾을 수 없다.
/// - 90°를 넘는 벤드(예전 판에서 저장한 목록) — 게인 셈이 맞지 않는다(예전에는 마킹 카드 메모에만 있었다).
List<String> conduitMarkWarnings(
  List<Map<String, dynamic>> bendList,
  Map<String, dynamic> settings,
) {
  if (bendList.isEmpty) return const [];
  final marks = calculateConduitMarkings(bendList, settings);
  final out = <String>[];
  var bendNo = 0;
  for (var i = 0; i < marks.length; i++) {
    final angle = (marks[i]['angle'] as num?)?.toDouble() ?? 0.0;
    if (angle <= 0) continue;
    bendNo++;
    final mark = (marks[i]['mark'] as num).toDouble();
    if (mark <= 0.05) {
      out.add(
        '$bendNo번 마킹이 관 끝${mark.abs() < 0.5 ? '' : '보다 ${mark.abs().round()}mm 앞'}에 찍힙니다. '
        '이대로는 꺾을 수 없습니다. 앞 길이를 늘리십시오.',
      );
    }
    if (angle > 90.0 + 1e-9) {
      out.add('$bendNo번 벤드가 ${angle.round()}°입니다. 90°를 넘는 벤드는 게인·마킹 값이 맞지 않습니다. 90° 이하로 나누십시오.');
    }
  }
  return out;
}

/// 3D 그림·관끼리 닿음 점검에 쓸 관 바깥지름(mm).
/// 후강(Rigid)의 "22mm"는 지름이 아니라 호칭이라, 호칭 숫자를 그대로 지름으로 그리면 관이
/// 가늘게 그려진다(22 대신 실제 26.5). 후강일 때는 KS C 8401 표([kThickConduitOd])로 실제
/// 바깥지름을 쓰고, 그 밖의 종류·표기는 예전처럼 규격 글에서 읽는다.
double conduitDrawOuterDiameterMm(Map<String, dynamic> settings) {
  final size = (settings['conduitSize'] ?? '').toString().trim();
  if (settings['conduitType'] == 'Rigid') {
    final m = RegExp(r'^(\d+)\s*mm$').firstMatch(size);
    final od = m == null ? null : kThickConduitOd[int.parse(m.group(1)!)];
    if (od != null) return od;
  }
  return conduitOuterDiameterMm(size);
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

/// 총 절단 길이 = 구간 길이 합 − 각도별 게인 합 + 톱날 두께.
/// 마킹 탭과 현장 탭이 같은 값을 쓰도록 한 곳에 둔다.
double conduitTotalCut(
  List<Map<String, dynamic>> bendList,
  Map<String, dynamic> settings, {
  bool useCoupling = false,
}) {
  if (bendList.isEmpty) return 0.0;
  final double gain90 = _num(settings, 'gain', 0.0);
  double sum = 0.0;
  double gains = 0.0;
  for (final bend in bendList) {
    final double len = (bend['length'] as num).toDouble();
    final double angle = (bend['angle'] as num).toDouble();
    sum += len;
    if (angle > 0) gains += conduitGainForAngle(angle, gain90);
  }
  // 10-09 사용자 결정: 톱날 두께(bladeKerf)는 더하지 않는다(자르는 자리는 순수 길이).
  return sum - gains + (useCoupling ? conduitCouplingAllowance(settings) : 0.0);
}

/// 커플링 체결 때 자를 길이에 더하는 끝 여유(기본 50mm).
/// 커플링에 관이 들어가는 깊이는 나사 물림에 따라 달라서, 넉넉히 잘라
/// 벤딩한 뒤 반대쪽 끝을 맞춰 자른다.
double conduitCouplingAllowance(Map<String, dynamic> settings) =>
    _num(settings, 'couplingAllowance', 50.0);

/// 90°로 한 번 꺾어 잰 값으로 이 벤더의 테이크업·게인(90°)을 잡는다.
///
/// - [cut] 자른 길이
/// - [mark] 관 끝에서 화살표를 맞춘 마킹 자리
/// - [stub] 꺾은 뒤 그 관 끝에서 꺾인 관 바깥면(등)까지(스텁 높이)
/// - [otherLeg] 반대쪽 끝에서 꺾인 관 바깥면(등)까지
///
/// 테이크업 = 스텁 − 마킹 자리, 게인 = 두 다리 합 − 자른 길이.
/// 제조사 표 값도 바깥면 기준으로 잰 값이라 같은 셈이다. 못 잡으면 null.
({double takeUp, double gain})? conduitCalibration({
  required double cut,
  required double mark,
  required double stub,
  required double otherLeg,
}) {
  if (cut <= 0 || mark <= 0 || stub <= 0 || otherLeg <= 0) return null;
  final takeUp = stub - mark;
  final gain = stub + otherLeg - cut;
  if (takeUp <= 0 || gain < 0) return null;
  return (takeUp: takeUp, gain: gain);
}

/// 유압(슈 가운데 맞춤) 시험 벤딩: 게인 = 두 다리 합 − 자른 길이,
/// 꺾이는 점 → 슈 가운데 = 스텁 − 마킹 자리. 슈 가운데 셈([ramShoeCenterOffset])이
/// 맞으면 두 번째 값이 게인의 절반과 같다([diff] = 잰 값 − 게인/2). 못 잡으면 null.
({double gain, double centerOffset, double diff})? ramCalibration({
  required double cut,
  required double mark,
  required double stub,
  required double otherLeg,
}) {
  if (cut <= 0 || mark <= 0 || stub <= 0 || otherLeg <= 0) return null;
  final gain = stub + otherLeg - cut;
  final centerOffset = stub - mark;
  if (gain < 0 || centerOffset < 0) return null;
  return (gain: gain, centerOffset: centerOffset, diff: centerOffset - gain / 2);
}
