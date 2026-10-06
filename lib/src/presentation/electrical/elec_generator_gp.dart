// 발전기 용량 GP 방식(현행 국가건설기준 KDS 32 20 20:2024 예비전원설비 4.1(6)④, 식 4.1-1~4.1-5, 표 4.1-1).
// 원문: 국토교통부고시 제2026-93호 첨부 "KDS 32 20 20 예비전원설비"(2024-08-22 개정). 화면 없음.
//
//   GP ≥ [ΣP + (ΣPm − PL) × a + (PL × a × c)] × k
//
// ΣP  전동기 이외 부하의 입력용량 합계(VVVF(인버터) 제어 전동기 포함)(kVA)
//      일반 부하 P = kW ÷ (효율 × 역률)                         (4.1-2)
//      UPS     P = UPS 출력(kVA) ÷ UPS 효율 × λ + 축전지 충전용량 (4.1-3, 충전용량은 UPS 용량의 6~10 %)
//      VVVF    P = 인버터 용량(kW) ÷ (효율 × 역률) × λ             (4.1-4)
//      LED 등  P = 부하용량(kW) ÷ (효율 × 역률) × λ               (4.1-5)
// ΣPm 전동기 부하용량 합계(VVVF 제외)(kW), PL 기동용량이 가장 큰 전동기(동시 기동이면 합)(kW)
// a   kW당 입력용량 계수(추천 고효율 1.38, 표준형 1.45), c 기동계수, k 허용전압강하 계수(표 4.1-1, 불명확하면 1.07~1.13)
// λ   THD 가중값(KS C IEC 61000-3-6 표 6 참고, 특성을 모르면 2.5)

/// 전동기 기동계수 c(원문 추천값과 범위).
enum GpStart {
  direct('직입', 6, '5~7'),
  starDelta('Y-Δ', 2, '2~3'),
  vvvf('VVVF(인버터)', 1.5, '1~1.5'),
  reactor50('리액터 탭 50%', 3, null),
  reactor65('리액터 탭 65%', 3.9, null),
  reactor80('리액터 탭 80%', 4.8, null);

  const GpStart(this.label, this.c, this.range);
  final String label;
  final double c;
  final String? range;
}

/// 표 4.1-1 발전기 허용전압강하 계수 k. 행 = 허용 전압강하율 15~20 %, 열 = x″d 20~25 %.
/// 2024 개정에서 2021판의 오타(19 %행 0.95·0.09, 16 %행 23 % 1.20)를 바로잡은 값이다.
const List<List<double>> kGpKTable = [
  [1.13, 1.19, 1.25, 1.30, 1.36, 1.42], // 15 %
  [1.05, 1.10, 1.16, 1.21, 1.26, 1.31], // 16 %
  [0.98, 1.03, 1.07, 1.12, 1.17, 1.22], // 17 %
  [0.91, 0.96, 1.00, 1.05, 1.09, 1.14], // 18 %
  [0.85, 0.90, 0.94, 0.98, 1.02, 1.07], // 19 %
  [0.80, 0.84, 0.88, 0.92, 0.96, 1.00], // 20 %
];
const List<int> kGpDvPcts = [15, 16, 17, 18, 19, 20];
const List<int> kGpXdPcts = [20, 21, 22, 23, 24, 25];

/// 표 4.1-1에서 k를 찾는다. 표에 없는 조합이면 null(원문에 보간 규칙이 없다).
double? gpKFromTable(int dvPct, int xdPct) {
  final r = kGpDvPcts.indexOf(dvPct);
  final c = kGpXdPcts.indexOf(xdPct);
  if (r < 0 || c < 0) return null;
  return kGpKTable[r][c];
}

/// a 추천값.
const double kGpAHighEff = 1.38;
const double kGpAStandard = 1.45;

/// λ를 모를 때 원문이 쓰라는 값.
const double kGpLambdaUnknown = 2.5;

/// 전동기 줄 중 PL로 쓸 줄 번호. 원문 정의대로 기동용량(kW × c, a는 모든 줄에 같음)이 가장 큰 줄이다.
/// 같으면 앞 줄. 용량과 c가 0보다 큰 줄이 없으면 null.
int? gpLargestStartIndex(List<(double? kw, double? c)> motors) {
  int? best;
  var bestStart = 0.0;
  for (var n = 0; n < motors.length; n++) {
    final (kw, c) = motors[n];
    if (kw == null || c == null || kw <= 0 || c <= 0) continue;
    final s = kw * c;
    if (best == null || s > bestStart + 1e-9) {
      best = n;
      bestStart = s;
    }
  }
  return best;
}

/// 전동기 이외 부하 한 줄의 종류. 일반은 식 4.1-2, VVVF는 4.1-4, LED 등 고조파 부하는 4.1-5(λ를 곱함).
enum GpLoadKind {
  general('일반', false),
  vvvf('VVVF(인버터) 전동기', true),
  harmonic('LED 등 고조파 부하', true);

  const GpLoadKind(this.label, this.usesLambda);
  final String label;
  final bool usesLambda;
}

/// 전동기 이외 부하 한 줄(부하마다 효율·역률이 다를 수 있어 줄마다 넣는다).
class GpLoad {
  const GpLoad({required this.kind, this.kw, this.eff, this.pf});
  final GpLoadKind kind;
  final double? kw;

  /// 0~1.
  final double? eff;
  final double? pf;
}

class GpInput {
  const GpInput({
    this.loads = const [],
    this.upsKva,
    this.upsEff,
    this.upsChargePct,
    this.lambda,
    this.motorsKw,
    this.largestKw,
    required this.a,
    required this.c,
    this.k,
  });

  /// 전동기 이외 부하 줄(UPS 제외).
  final List<GpLoad> loads;

  /// UPS 출력 kVA, UPS 효율(0~1), 축전지 충전용량(UPS 용량의 %).
  final double? upsKva;
  final double? upsEff;
  final double? upsChargePct;

  /// THD 가중값 λ.
  final double? lambda;

  /// 전동기 부하 합계 ΣPm(VVVF 제외) kW, 기동용량이 가장 큰 전동기 PL kW.
  final double? motorsKw;
  final double? largestKw;

  final double a;
  final double c;

  /// 허용전압강하 계수 k.
  final double? k;
}

class GpResult {
  const GpResult({
    required this.errors,
    this.pGeneral = 0,
    this.pVvvf = 0,
    this.pLed = 0,
    this.pUps = 0,
    this.upsCharge = 0,
    this.sumP = 0,
    this.motorRest = 0,
    this.motorStart = 0,
    this.gp,
    this.loadP = const [],
  });

  /// 부하 줄마다의 입력용량 P(kVA). kW가 비었거나 0인 줄은 0.
  final List<double> loadP;

  final List<String> errors;
  final double pGeneral;
  final double pVvvf;
  final double pLed;

  /// UPS 입력용량(충전용량 포함)과 그중 충전용량.
  final double pUps;
  final double upsCharge;

  /// ΣP.
  final double sumP;

  /// (ΣPm − PL) × a, PL × a × c.
  final double motorRest;
  final double motorStart;

  final double? gp;

  bool get ok => errors.isEmpty && gp != null;
}

GpResult calcGp(GpInput i) {
  final errors = <String>[];
  bool frac(double? v) => v != null && v > 0 && v <= 1;
  double nz(double? v) => v ?? 0;

  for (final (name, v) in [
    ('UPS 출력', i.upsKva),
    ('전동기 합계', i.motorsKw),
    ('가장 큰 전동기', i.largestKw),
  ]) {
    if (v != null && v < 0) errors.add('$name은(는) 0 이상으로 넣으십시오.');
  }
  var anyLoad = false;
  var needLambdaLoad = false;
  for (var n = 0; n < i.loads.length; n++) {
    final l = i.loads[n];
    final kw = l.kw;
    if (kw == null || kw == 0) continue;
    final no = '부하 ${n + 1}';
    if (kw < 0) {
      errors.add('$no: 용량(kW)은 0 이상으로 넣으십시오.');
      continue;
    }
    anyLoad = true;
    if (l.kind.usesLambda) needLambdaLoad = true;
    if (!frac(l.eff)) errors.add('$no: 효율을 0 초과 100% 이하로 넣으십시오.');
    if (!frac(l.pf)) errors.add('$no: 역률을 0 초과 100% 이하로 넣으십시오.');
  }
  final hasUps = nz(i.upsKva) > 0;
  if (hasUps && !frac(i.upsEff)) {
    errors.add('UPS 효율을 0 초과 100% 이하로 넣으십시오.');
  }
  if (i.upsChargePct != null && i.upsChargePct! < 0) {
    errors.add('축전지 충전용량(%)은 0 이상으로 넣으십시오.');
  }
  final needLambda = hasUps || needLambdaLoad;
  if (needLambda && (i.lambda == null || i.lambda! <= 0)) {
    errors.add('고조파 발생 부하가 있으면 THD 가중값 λ를 넣으십시오(모르면 2.5).');
  }
  final pm = nz(i.motorsKw);
  final pl = nz(i.largestKw);
  if (pl > pm + 1e-9) {
    errors.add('가장 큰 전동기(PL)가 전동기 합계(ΣPm)보다 큽니다.');
  }
  if (i.k == null || i.k! <= 0) {
    errors.add('허용전압강하 계수 k를 정하십시오(표 4.1-1, 불명확하면 1.07~1.13).');
  }
  if (!anyLoad && !hasUps && pm <= 0) {
    errors.add('부하를 하나 이상 넣으십시오.');
  }
  if (errors.isNotEmpty) return GpResult(errors: errors);

  final lam = i.lambda ?? 1;
  final loadP = <double>[];
  var pGeneral = 0.0, pVvvf = 0.0, pLed = 0.0;
  for (final l in i.loads) {
    final kw = nz(l.kw);
    if (kw <= 0) {
      loadP.add(0);
      continue;
    }
    final p = kw / (l.eff! * l.pf!) * (l.kind.usesLambda ? lam : 1);
    loadP.add(p);
    switch (l.kind) {
      case GpLoadKind.general:
        pGeneral += p;
      case GpLoadKind.vvvf:
        pVvvf += p;
      case GpLoadKind.harmonic:
        pLed += p;
    }
  }
  final charge = hasUps ? i.upsKva! * nz(i.upsChargePct) / 100 : 0.0;
  final pUps = hasUps ? i.upsKva! / i.upsEff! * lam + charge : 0.0;
  final sumP = pGeneral + pVvvf + pLed + pUps;
  final rest = (pm - pl) * i.a;
  final start = pl * i.a * i.c;
  final gp = (sumP + rest + start) * i.k!;
  return GpResult(
    errors: const [],
    pGeneral: pGeneral,
    pVvvf: pVvvf,
    pLed: pLed,
    pUps: pUps,
    upsCharge: charge,
    sumP: sumP,
    motorRest: rest,
    motorStart: start,
    gp: gp,
    loadP: loadP,
  );
}
