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
library;

class SegmentLengthCheck {
  /// 앞에 이어진 직관까지 합친 곧은 길이.
  final double run;

  /// 벤더에 물릴 길이가 모자란가.
  final bool shoeInterference;

  /// 피팅 쪽 곧은 끝이 모자란가.
  final bool leakRisk;

  /// 누설을 따질 때 쓴 기준(mm).
  final double minFittingStraight;

  /// 앞 직관과 합쳐서 봤는가(창 문구에 쓴다).
  bool get merged => run > inputLength + 1e-9;

  final double inputLength;

  const SegmentLengthCheck({
    required this.run,
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
SegmentLengthCheck checkSegmentLength({
  required List<dynamic> existing,
  required double length,
  required double angle,
  required double tubeOdMm,
  required double minStraight,
  required bool warnShoeInterference,
}) {
  double val(dynamic m, String k) =>
      m is Map ? ((m[k] as num?)?.toDouble() ?? 0.0) : 0.0;

  // 바로 앞에 이어진 직관(0°)들의 길이.
  double trailingStraight = 0.0;
  for (int i = existing.length - 1; i >= 0; i--) {
    if (val(existing[i], 'angle') > 0) break;
    trailingStraight += val(existing[i], 'length');
  }
  final run = length + trailingStraight;

  final bool hasBendBefore = existing.any((b) => val(b, 'angle') > 0);
  // 관 끝에 닿는 구간: 앞에 벤드가 없으면 시작 끝, 벤드 뒤 직관이면 끝이 될 수 있다.
  final bool atPipeEnd = !hasBendBefore || angle <= 0;

  final minFitting = minFittingStraightMm(tubeOdMm);
  return SegmentLengthCheck(
    run: run,
    inputLength: length,
    shoeInterference: warnShoeInterference && run < minStraight,
    leakRisk: atPipeEnd && run < minFitting,
    minFittingStraight: minFitting,
  );
}
