/// 튜브 컷팅 기준 셈. 앱 코드를 보지 않고 다시 쓴 것.
///
/// 출처
/// - 배관 공통 관행: 절단 길이 = 중심 간 거리(center-to-center) − 양쪽 부속 공제
///   (부속 중심에서 관 끝이 닿는 자리까지). 인치 입력은 25.4를 곱한다.
/// - 톱날 손실(kerf): 자를 때마다 톱날 두께만큼 없어진다. 원자재 한 본에서 n개를
///   내면 자르는 횟수는 n번(끝을 버릴 때)이다. 마지막 조각이 원자재 끝에 딱 닿게
///   자르면 n−1번이지만, 원자재 끝은 보통 반듯하지 않아 n번으로 잡는다.
/// - 원자재 배치: 긴 것부터 넣기(First Fit Decreasing, FFD)와 이론상 최소
///   본수(총 길이 ÷ 원자재 길이 올림)를 같이 본다.
library;

const double refInchToMm = 25.4;

/// 절단 길이 = 중심 간 거리 − 시작 공제 − 끝 공제. 음수면 부속끼리 겹친다.
double refCutLength({
  required double c2c,
  required bool inch,
  required double startDeduction,
  required double endDeduction,
}) => (inch ? c2c * refInchToMm : c2c) - startDeduction - endDeduction;

/// 원자재 한 본에서 조각 [pieces]를 내는 데 드는 길이. 자르는 횟수는 조각 수와 같다.
double refBarNeed(List<double> pieces, double kerf) =>
    pieces.fold(0.0, (s, p) => s + p + kerf);

/// 긴 것부터 넣기(FFD). 각 본에 든 조각 목록을 돌려준다.
/// 원자재보다 긴 조각은 [oversized]에 따로 담는다.
({List<List<double>> bars, List<double> oversized}) refFirstFitDecreasing(
  List<double> pieces,
  double stock, {
  double kerf = 0.0,
}) {
  final oversized = <double>[];
  final valid = <double>[];
  for (final p in pieces) {
    if (p <= 0) continue;
    if (p > stock) {
      oversized.add(p);
    } else {
      valid.add(p);
    }
  }
  valid.sort((a, b) => b.compareTo(a));
  final bars = <List<double>>[];
  final used = <double>[];
  for (final p in valid) {
    final need = p + kerf;
    var placed = false;
    for (var i = 0; i < bars.length; i++) {
      // 조각 하나짜리 본은 조각만 들어가면 된다(톱날은 남는 끝에서 먹는다).
      if (used[i] + need <= stock + 1e-9) {
        bars[i].add(p);
        used[i] += need;
        placed = true;
        break;
      }
    }
    if (!placed) {
      bars.add([p]);
      used.add(need);
    }
  }
  return (bars: bars, oversized: oversized);
}

/// 이론상 최소 본수 = 총 길이 ÷ 원자재 길이 올림(톱날 손실은 빼고 본 하한).
int refLowerBoundBars(List<double> pieces, double stock) {
  final total = pieces.where((p) => p > 0 && p <= stock).fold(0.0, (s, p) => s + p);
  if (total <= 0) return 0;
  return (total / stock - 1e-9).ceil();
}

/// 한 본에서 남는 길이 = 원자재 − 조각 합 − 톱날 × 자른 횟수(조각 수).
double refBarRemainder(List<double> pieces, double stock, double kerf) =>
    stock - refBarNeed(pieces, kerf);
