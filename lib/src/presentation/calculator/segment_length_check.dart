/// 튜브 입력 탭에서 한 구간을 넣을 때 "너무 짧다"를 가리는 셈.
///
/// 🚀 [고침] 예전에는 넣는 구간 길이만 보고 판단했다.
/// - 직관 150 다음에 10mm 벤드 구간을 넣으면 한 줄로 이어진 160mm인데 10mm만 보고
///   "물림 거리 부족·누설 위험"을 띄웠다. 바로 앞에 이어진 직관은 합쳐서 본다.
/// - 누설 위험(피팅 너트가 물릴 곧은 끝)은 관 끝에서만 따질 일인데 중간 구간에도
///   띄웠다. 앞에 벤드가 없는 첫 구간(시작 끝)과 벤드 뒤에 붙이는 직관(끝이 될 수
///   있다)에서만 본다.
/// - 인치로 저장된 규격(0.5)을 mm 표에 그대로 대서 1/2" 튜브에 1/4" 기준(21mm)을
///   쓰고 있었다. mm로 바꿔서 댄다.
/// - 🚀 [고침 10-09] 꺾이는 점 사이 길이로 비교해서, 앞뒤 벤드의 셋백을 빼면 곧은 부분이
///   10mm뿐이어도 경고가 없었다(R38.1 90° 두 번 사이 80mm → 곧은 부분 3.8mm).
///   [radius]를 주면 앞 벤드·이 벤드의 셋백을 빼고 본다.
library;

import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';

class SegmentLengthCheck {
  /// 앞에 이어진 직관까지 합친 길이(꺾이는 점 기준).
  final double run;

  /// [run]에서 앞 벤드·이 벤드의 셋백을 뺀 곧은 부분(벤더·너트가 실제로 물리는 길이).
  final double straight;

  /// 벤더에 물릴 길이가 모자란가.
  final bool shoeInterference;

  /// 피팅 쪽 곧은 끝이 모자란가.
  final bool leakRisk;

  /// 누설을 따질 때 쓴 기준(mm).
  final double minFittingStraight;

  /// 앞 직관과 합쳐서 봤는가(창 문구에 쓴다).
  bool get merged => run > inputLength + 1e-9;

  /// 셋백을 빼고 봤는가(창 문구에 쓴다).
  bool get setbackRemoved => straight < run - 1e-9;

  final double inputLength;

  const SegmentLengthCheck({
    required this.run,
    required this.straight,
    required this.inputLength,
    required this.shoeInterference,
    required this.leakRisk,
    required this.minFittingStraight,
  });

  bool get hasWarning => shoeInterference || leakRisk;
}

/// 피팅 너트가 물리려면 끝에 이만큼 곧아야 한다(바깥지름 mm 기준).
double minFittingStraightMm(double odMm) {
  if (odMm <= 6.35) return 21.0; // 1/4"
  if (odMm <= 9.53) return 24.0; // 3/8"
  if (odMm <= 12.7) return 30.0; // 1/2"
  if (odMm <= 19.05) return 32.0; // 3/4"
  return 38.0; // 1" 이상
}

/// [existing]은 지금 목록('length'·'angle'), [length]·[angle]은 새로 넣을 구간.
/// [radius]가 0이면 셋백을 빼지 않는다(예전 셈).
SegmentLengthCheck checkSegmentLength({
  required List<dynamic> existing,
  required double length,
  required double angle,
  required double tubeOdMm,
  required double minStraight,
  required bool warnShoeInterference,
  double radius = 0.0,
}) {
  double val(dynamic m, String k) =>
      m is Map ? ((m[k] as num?)?.toDouble() ?? 0.0) : 0.0;

  // 바로 앞에 이어진 직관(0°)들의 길이와, 그 앞 마지막 벤드의 각.
  double trailingStraight = 0.0;
  double prevBendAngle = 0.0;
  for (int i = existing.length - 1; i >= 0; i--) {
    final a = val(existing[i], 'angle');
    if (a > 0) {
      prevBendAngle = a;
      break;
    }
    trailingStraight += val(existing[i], 'length');
  }
  final run = length + trailingStraight;
  final straight =
      run - bendSetback(radius, prevBendAngle) - bendSetback(radius, angle);

  final bool hasBendBefore = prevBendAngle > 0;
  // 관 끝에 닿는 구간: 앞에 벤드가 없으면 시작 끝, 벤드 뒤 직관이면 끝이 될 수 있다.
  final bool atPipeEnd = !hasBendBefore || angle <= 0;

  final minFitting = minFittingStraightMm(tubeOdMm);
  return SegmentLengthCheck(
    run: run,
    straight: straight,
    inputLength: length,
    shoeInterference: warnShoeInterference && straight < minStraight,
    leakRisk: atPipeEnd && straight < minFitting,
    minFittingStraight: minFitting,
  );
}

/// 목록 전체에서 벤드 앞 곧은 부분이 벤더 최소 물림보다 짧은 곳(10-09).
/// 예전에는 입력 탭에서 줄을 넣을 때만 봐서, 규격을 바꾸거나(3/8" → 1/2" 반경이 커짐)
/// 보관함에서 불러오거나 앞 줄 각도를 고친 뒤에는 마킹·현장 탭에 아무 경고가 없었다.
/// 마킹 값은 바꾸지 않고 알리기만 한다. [minStraight]가 0 이하면 보지 않는다.
List<String> minGripWarnings(
  List<Map<String, dynamic>> bendList, {
  required double radius,
  required double minStraight,
}) {
  if (minStraight <= 0) return const [];
  final out = <String>[];
  var bendNo = 0;
  for (var i = 0; i < bendList.length; i++) {
    final angle = (bendList[i]['angle'] as num?)?.toDouble() ?? 0.0;
    if (angle <= 0) continue;
    bendNo++;
    // 10-09 8차: 퀵 U벤드 두 번째 줄(길이 2R·곧은 부분 0)은 한 번에 180°로 꺾으면 물릴 필요가
    // 없다(예전에는 "곧은 부분 0.0mm가 최소 물림보다 짧다"가 떴다).
    final bool uSecond =
        (bendList[i]['uBend'] as num?)?.toInt() == 2 &&
        i > 0 &&
        (bendList[i - 1]['uBend'] as num?)?.toInt() == 1;
    if (uSecond) continue;
    final c = checkSegmentLength(
      existing: bendList.sublist(0, i),
      length: (bendList[i]['length'] as num?)?.toDouble() ?? 0.0,
      angle: angle,
      tubeOdMm: 0,
      minStraight: minStraight,
      warnShoeInterference: true,
      radius: radius,
    );
    // 곧은 부분이 0보다 작으면 형상 점검(짧은 구간)이 이미 알린다.
    if (c.straight >= 0 && c.straight < minStraight) {
      out.add(
        '$bendNo번 벤드 앞 곧은 부분 ${c.straight.toStringAsFixed(1)}mm가 최소 물림 '
        '${minStraight.toStringAsFixed(0)}mm보다 짧습니다. 벤더에 물리지 않을 수 있습니다.',
      );
    }
  }
  return out;
}
