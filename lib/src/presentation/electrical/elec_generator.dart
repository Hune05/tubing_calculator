// 발전기 용량 산정(비상발전기)의 순수 계산. 화면 없음.
// 방식: PG 방식(PG1 정상 운전, PG2 가장 큰 전동기 기동 시 전압강하, PG3 마지막 전동기 기동, 고조파 가산).
// 식과 출처는 docs/전기_발전기_근거.md. 모두 원문 대조 전(2차 자료)이다.
// 2021년 국가건설기준 KDS 31 60 20의 GP 방식은 자료마다 식이 달라 넣지 않았다.
import 'dart:math' as math;

/// 시동방식 계수 C(PG2·PG3). 값은 KIEE 논문(2018) 표 1의 값이며 원문 대조 전이다.
enum GenStartKind {
  direct('직입', 1.0),
  starDelta('Y-Δ', 0.67),
  reactor65('리액터 65%', 0.65),
  custom('직접 입력', null);

  const GenStartKind(this.label, this.c);
  final String label;
  final double? c;
}

class GenInput {
  const GenInput({
    this.loadKw,
    this.demand,
    this.eff,
    this.pf,
    this.motorKw,
    this.beta,
    this.startC,
    this.xdPct,
    this.dvPct,
    this.startPf,
    this.genPf,
    this.harmonicKva,
    this.harmonicFactor,
    this.volts,
    this.chosenKva,
  });

  /// 정상 운전 부하 합계(전동기 포함, 출력 kW).
  final double? loadKw;

  /// 수용률 α. 1 이하.
  final double? demand;

  /// 부하 종합 효율 ηL (0 초과 1 이하).
  final double? eff;

  /// 부하 종합 역률 cosθL (0 초과 1 이하).
  final double? pf;

  /// 부하 중 기동 용량이 가장 큰 전동기 출력 Pm[kW]. 비우면 PG2·PG3는 계산하지 않는다.
  final double? motorKw;

  /// 전동기 출력 1kW당 기동 kVA β.
  final double? beta;

  /// 시동방식 계수 C.
  final double? startC;

  /// 발전기 과도 리액턴스 X″d[%].
  final double? xdPct;

  /// 전동기 기동 시 허용 순간 전압강하 ΔV[%].
  final double? dvPct;

  /// 기동 역률 cosθs. 비우면 PG3는 계산하지 않는다.
  final double? startPf;

  /// 발전기 역률 cosθG(PG3). 비우면 PG3는 계산하지 않는다.
  final double? genPf;

  /// 고조파 발생 부하(UPS·인버터 등) 입력 용량 Pc[kVA]. 비우면 가산하지 않는다.
  final double? harmonicKva;

  /// 고조파 가산 계수(2.0~2.5로 소개되나 원문 대조 전). Pc를 넣으면 필요하다.
  final double? harmonicFactor;

  /// 발전기 정격전압[V] (정격전류 계산용). 비우면 전류는 계산하지 않는다.
  final double? volts;

  /// 선정한 발전기 용량[kVA]. 넣으면 합격/불합격을 본다.
  final double? chosenKva;
}

class GenResult {
  const GenResult({
    required this.errors,
    this.pg1,
    this.pg2,
    this.pg3,
    this.pg4,
    this.required,
    this.governing,
    this.currentA,
    this.notes = const [],
    this.chosenPass,
    this.chosenMarginPct,
  });

  /// "입력 확인" 사유. 하나라도 있으면 값은 없다.
  final List<String> errors;
  final double? pg1;
  final double? pg2;
  final double? pg3;
  final double? pg4;

  /// 필요 발전기 용량[kVA]: 계산된 PG들의 최댓값.
  final double? required;

  /// 최댓값을 낸 방식 이름("PG1" 등).
  final String? governing;

  /// 필요 용량일 때 정격전류[A].
  final double? currentA;

  /// 계산에서 빠진 항목 안내.
  final List<String> notes;

  /// 선정 용량 합격 여부(선정 용량을 넣었을 때만).
  final bool? chosenPass;

  /// 선정 용량의 여유율[%] = 선정/필요 − 1.
  final double? chosenMarginPct;

  bool get ok => errors.isEmpty && required != null;
}

/// PG1 = 부하 kW × 수용률 ÷ (효율 × 역률) [kVA].
double genPg1(double loadKw, double demand, double eff, double pf) =>
    loadKw * demand / (eff * pf);

/// PG2 = Pm × β × C × X″d × (1 − ΔV) ÷ ΔV [kVA]. X″d·ΔV는 소수(0.25).
double genPg2(double pm, double beta, double c, double xd, double dv) =>
    pm * beta * c * xd * (1 - dv) / dv;

/// PG3 = [(부하 − Pm) ÷ η + Pm × β × C × cosθs] ÷ cosθG [kVA].
double genPg3(
  double loadKw,
  double pm,
  double eff,
  double beta,
  double c,
  double startPf,
  double genPf,
) => ((loadKw - pm) / eff + pm * beta * c * startPf) / genPf;

/// 발전기 정격전류[A] = kVA × 1000 ÷ (√3 × V). 3상.
double genRatedCurrent(double kva, double volts) =>
    kva * 1000 / (math.sqrt(3) * volts);

GenResult calcGenerator(GenInput i) {
  final errors = <String>[];
  final notes = <String>[];

  bool pos(double? v) => v != null && v > 0;
  bool frac(double? v) => v != null && v > 0 && v <= 1;

  if (!pos(i.loadKw)) errors.add('부하 합계(kW)를 0보다 크게 넣으십시오.');
  if (!frac(i.demand)) errors.add('수용률은 0 초과 1 이하로 넣으십시오.');
  if (!frac(i.eff)) errors.add('효율은 0 초과 1 이하로 넣으십시오.');
  if (!frac(i.pf)) errors.add('역률은 0 초과 1 이하로 넣으십시오.');

  final hasMotor = i.motorKw != null && i.motorKw! != 0;
  if (i.motorKw != null && i.motorKw! < 0) {
    errors.add('전동기 출력(kW)은 0 이상으로 넣으십시오.');
  }
  if (hasMotor && i.motorKw! > 0) {
    if (!pos(i.beta)) errors.add('전동기 1kW당 기동 kVA(β)를 0보다 크게 넣으십시오.');
    if (!pos(i.startC)) errors.add('시동방식 계수(C)를 0보다 크게 넣으십시오.');
    if (i.xdPct == null || i.xdPct! <= 0 || i.xdPct! >= 100) {
      errors.add('발전기 X″d(%)를 0 초과 100 미만으로 넣으십시오.');
    }
    if (i.dvPct == null || i.dvPct! <= 0 || i.dvPct! >= 100) {
      errors.add('허용 전압강하 ΔV(%)를 0 초과 100 미만으로 넣으십시오.');
    }
    if (pos(i.loadKw) && i.motorKw! > i.loadKw!) {
      errors.add('가장 큰 전동기(kW)가 부하 합계보다 큽니다.');
    }
  }
  if (i.startPf != null && !frac(i.startPf)) {
    errors.add('기동 역률은 0 초과 1 이하로 넣으십시오.');
  }
  if (i.genPf != null && !frac(i.genPf)) {
    errors.add('발전기 역률은 0 초과 1 이하로 넣으십시오.');
  }
  if (i.harmonicKva != null && i.harmonicKva! < 0) {
    errors.add('고조파 부하(kVA)는 0 이상으로 넣으십시오.');
  }
  final hasHarm = i.harmonicKva != null && i.harmonicKva! > 0;
  if (hasHarm && !pos(i.harmonicFactor)) {
    errors.add('고조파 부하를 넣었으면 가산 계수도 넣으십시오.');
  }
  if (i.volts != null && i.volts! <= 0) {
    errors.add('발전기 전압(V)은 0보다 크게 넣으십시오.');
  }
  if (i.chosenKva != null && i.chosenKva! <= 0) {
    errors.add('선정 용량(kVA)은 0보다 크게 넣으십시오.');
  }
  if (errors.isNotEmpty) return GenResult(errors: errors);

  final pg1 = genPg1(i.loadKw!, i.demand!, i.eff!, i.pf!);
  double? pg2;
  double? pg3;
  double? pg4;
  if (hasMotor) {
    pg2 = genPg2(
      i.motorKw!,
      i.beta!,
      i.startC!,
      i.xdPct! / 100,
      i.dvPct! / 100,
    );
    if (i.startPf != null && i.genPf != null) {
      pg3 = genPg3(
        i.loadKw!,
        i.motorKw!,
        i.eff!,
        i.beta!,
        i.startC!,
        i.startPf!,
        i.genPf!,
      );
    } else {
      notes.add('PG3는 기동 역률과 발전기 역률을 넣어야 계산합니다. 지금은 뺐습니다.');
    }
  } else {
    notes.add('가장 큰 전동기를 넣지 않아 PG2와 PG3는 계산하지 않았습니다.');
  }
  if (hasHarm) pg4 = pg1 + i.harmonicKva! * i.harmonicFactor!;

  final cands = <String, double>{
    'PG1': pg1,
    'PG2': ?pg2,
    'PG3': ?pg3,
    'PG4': ?pg4,
  };
  var gName = 'PG1';
  var gVal = pg1;
  cands.forEach((k, v) {
    if (v > gVal) {
      gName = k;
      gVal = v;
    }
  });

  bool? pass;
  double? margin;
  if (i.chosenKva != null) {
    pass = i.chosenKva! + 1e-9 >= gVal;
    margin = (i.chosenKva! / gVal - 1) * 100;
  }
  return GenResult(
    errors: const [],
    pg1: pg1,
    pg2: pg2,
    pg3: pg3,
    pg4: pg4,
    required: gVal,
    governing: gName,
    currentA: i.volts == null ? null : genRatedCurrent(gVal, i.volts!),
    notes: notes,
    chosenPass: pass,
    chosenMarginPct: margin,
  );
}
