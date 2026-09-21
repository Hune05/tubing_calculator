/// 현장 탭(가로 줄자 화면)이 보여 줄 마킹 자료.
///
/// 튜브·전선관 계산기가 각자 이 모양으로 넘겨주고, 화면은 하나를 같이 쓴다.
/// 🚀 [바꿈] 예전에는 튜브용·전선관 탭용·전선관 "가로 도면 보기"용 현장 화면이
/// 세 벌 따로 있어서, 한쪽을 고치면 나머지는 그대로였다.
library;

/// 줄자 위의 마킹 하나.
class FieldMark {
  /// 벤드 번호(1부터). 직관 끝 표시는 0.
  final int number;

  /// 줄자 눈금(관 끝 0에서).
  final double position;

  /// 설계 각도. 0이면 직관 끝 표시(금 긋는 자리가 아니다).
  final double angle;

  /// 실제로 꺾을 각도(스프링백을 얹은 것).
  final double targetAngle;

  /// 방향값(0위·90우·180아래·270좌·360앞·450뒤).
  final double rotation;

  /// 앞 마킹에서 얼마나.
  final double gap;

  /// 꺾기 전에 관을 굴릴 각도(평면이 바뀔 때). 없으면 null.
  final double? roll;

  const FieldMark({
    required this.number,
    required this.position,
    required this.angle,
    required this.rotation,
    double? targetAngle,
    this.gap = 0.0,
    this.roll,
  }) : targetAngle = targetAngle ?? angle;

  bool get isBend => angle > 0;

  /// 스프링백 때문에 설계 각도보다 더 꺾어야 하는가.
  bool get hasOverBend => isBend && (targetAngle - angle).abs() >= 0.05;
}

/// 인치를 같이 보여 줄지(전선관 설정이 인치일 때). 셈은 늘 mm로 한다.
enum FieldInchMode { none, fraction, decimal }

/// mm를 인치 글로. 분수는 [denominator](16이면 1/16")에 맞춰 반올림하고 줄인다.
/// 예) 358mm → 14 1/8" (1/16), 14.09" (소수점)
String formatInch(double mm, FieldInchMode mode, {int denominator = 16}) {
  if (mode == FieldInchMode.none) return '';
  final inch = mm / 25.4;
  if (mode == FieldInchMode.decimal) return '${inch.toStringAsFixed(2)}"';
  final d = denominator <= 0 ? 16 : denominator;
  final negative = inch < 0;
  var n = (inch.abs() * d).round();
  final whole = n ~/ d;
  var num = n % d;
  var den = d;
  while (num > 0 && num % 2 == 0 && den % 2 == 0) {
    num ~/= 2;
    den ~/= 2;
  }
  final sign = negative ? '-' : '';
  if (num == 0) return '$sign$whole"';
  if (whole == 0) return '$sign$num/$den"';
  return '$sign$whole $num/$den"';
}

class FieldMarkingData {
  /// 자르는 길이(줄자 눈금). 0이면 없다.
  final double totalCut;
  final List<FieldMark> marks;

  /// "이대로는 만들 수 없습니다" 같은 경고.
  final List<String> warnings;

  /// 셈이 안 될 때의 까닭.
  final String? error;

  /// 인치를 같이 보여 줄지와 분수 눈금(16이면 1/16").
  final FieldInchMode inchMode;
  final int inchDenominator;

  const FieldMarkingData({
    required this.totalCut,
    required this.marks,
    this.warnings = const [],
    this.error,
    this.inchMode = FieldInchMode.none,
    this.inchDenominator = 16,
  });

  /// 인치 글(인치를 안 쓰면 빈 글).
  String inch(double mm) =>
      formatInch(mm, inchMode, denominator: inchDenominator);

  static const empty = FieldMarkingData(totalCut: 0, marks: []);

  bool get isEmpty => marks.isEmpty;

  List<FieldMark> get bends => [
    for (final m in marks)
      if (m.isBend) m,
  ];

  /// 자료가 바뀌었는지 가리는 글(한 단계씩 진행을 처음으로 되돌릴 때 쓴다).
  String get signature =>
      '${totalCut.toStringAsFixed(1)}|'
      '${marks.map((m) => '${m.position.toStringAsFixed(1)}/${m.angle}/${m.rotation}').join(',')}';
}

/// 한 단계씩 보기의 한 단계. 벤드 마킹을 입력 순서대로, 마지막에 자르기.
class FieldStep {
  final FieldMark? mark;
  final double position;
  const FieldStep.bend(FieldMark this.mark) : position = 0;
  const FieldStep.cut(this.position) : mark = null;

  bool get isCut => mark == null;
  double get at => mark?.position ?? position;
}

/// 앞 마킹에서 이 단계까지(자르기는 마지막 벤드 마킹에서).
double fieldStepGap(FieldMarkingData data, FieldStep step) {
  if (!step.isCut) return step.mark!.gap;
  final bends = data.bends;
  return step.at - (bends.isEmpty ? 0.0 : bends.last.position);
}

List<FieldStep> fieldSteps(FieldMarkingData data) => [
  for (final m in data.bends) FieldStep.bend(m),
  if (data.totalCut > 0) FieldStep.cut(data.totalCut),
];

/// 방향값을 현장 말로.
String fieldDirectionLabel(double rotation) {
  switch (rotation.round()) {
    case 0:
      return 'UP (위)';
    case 90:
      return 'RIGHT (오른쪽)';
    case 180:
      return 'DOWN (아래)';
    case 270:
      return 'LEFT (왼쪽)';
    case 360:
      return 'FRONT (앞)';
    case 450:
      return 'BACK (뒤)';
  }
  return '${rotation.round()}°';
}

/// 줄자 위 말풍선을 [lanes]줄에 나눠 겹치지 않게 한다.
///
/// [centers]는 말풍선 가운데 x(입력 순서), [width]는 말풍선 폭. 돌려주는 목록은
/// 같은 순서로 몇 번째 줄(0부터)에 놓을지. 모든 줄이 막히면 가장 먼저 비는 줄에
/// 놓는다(겹칠 수밖에 없을 때).
List<int> assignLabelLanes(
  List<double> centers, {
  required double width,
  int lanes = 2,
  double gap = 6,
}) {
  final order = List<int>.generate(centers.length, (i) => i)
    ..sort((a, b) => centers[a].compareTo(centers[b]));
  final laneRight = List<double>.filled(lanes, double.negativeInfinity);
  final result = List<int>.filled(centers.length, 0);
  for (final i in order) {
    final left = centers[i] - width / 2;
    var chosen = -1;
    for (var l = 0; l < lanes; l++) {
      if (left >= laneRight[l] + gap) {
        chosen = l;
        break;
      }
    }
    if (chosen < 0) {
      chosen = 0;
      for (var l = 1; l < lanes; l++) {
        if (laneRight[l] < laneRight[chosen]) chosen = l;
      }
    }
    result[i] = chosen;
    laneRight[chosen] = centers[i] + width / 2;
  }
  return result;
}
