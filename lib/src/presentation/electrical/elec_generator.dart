// 발전기 용량 산정(비상발전기)의 순수 계산. 화면 없음.
// 방식: PG 방식(PG1 정상 운전, PG2 가장 큰 전동기 기동 시 전압강하, PG3 마지막 전동기 기동).
// 원문: 건축전기설비설계기준(국토교통부) 제5장 예비전원설비 3.1.1~3.1.2. 식과 출처는 docs/전기_발전기_근거.md.
// 원문은 사이리스터(고조파) 부하가 없을 때만 PG 방식을 쓴다(3.1.2(1)). 고조파 가산식(PG4)은 원문에 없어 넣지 않는다.
// 현행 GP 방식(KDS 32 20 20:2024)은 elec_generator_gp.dart.
import 'dart:math' as math;

/// 시동방식 계수 C(PG2·PG3). 원문 3.1.1(5) 표의 값.
/// 원문 표의 리액터 50%는 65%와 같은 0.65로 적혀 있어 오타로 보고 넣지 않았다.
enum GenStartKind {
  direct('직입', 1.0),
  starDelta('Y-Δ', 0.67),
  reactor65('리액터 65%', 0.65),
  reactor80('리액터 80%', 0.80),
  condorfer50('콘돌퍼 50%', 0.25),
  condorfer65('콘돌퍼 65%', 0.42),
  condorfer80('콘돌퍼 80%', 0.64),
  custom('직접 입력', null);

  const GenStartKind(this.label, this.c);
  final String label;
  final double? c;
}

/// 전동기 출력 1kW당 기동 입력 β[kVA/kW]. 원문 표의 기동 계급별 범위 가운데 값.
/// F 계급이 7.2다. 정리 글에 보이는 "0.72"는 원문 값이 아니다.
enum GenStartClass {
  e('E', 6.35),
  f('F', 7.2),
  g('G', 8.0),
  h('H', 9.0),
  j('J', 10.1),
  k('K', 11.4);

  const GenStartClass(this.label, this.beta);
  final String label;
  final double beta;
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
    this.volts,
    this.chosenKva,
  });

  /// 정상 운전 부하 합계(전동기 포함, 출력 kW).
  final double? loadKw;

  /// 수용률 α. 1 이하.
  final double? demand;

  /// 부하 종합 효율 ηL (0 초과 1 이하).
  final double? eff;

  /// 부하 종합 역률 cosθL (0 초과 1 이하). PG1과 PG3에 같이 쓴다.
  final double? pf;

  /// 부하 중 기동 용량이 가장 큰 전동기 출력 Pm[kW]. 비우면 PG2·PG3는 계산하지 않는다.
  final double? motorKw;

  /// 전동기 출력 1kW당 기동 입력 β[kVA/kW]. 기동 계급별 값(GenStartClass).
  final double? beta;

  /// 시동방식 계수 C.
  final double? startC;

  /// 발전기 과도 리액턴스 X″d[%]. 원문은 보통 20~25 %.
  final double? xdPct;

  /// 전동기 기동 시 허용 순간 전압강하 ΔV[%]. 원문은 승강기가 있으면 20, 그 밖에는 25.
  final double? dvPct;

  /// 기동 역률 Pfm. 원문은 불분명하면 0.4. 비우면 PG3는 계산하지 않는다.
  final double? startPf;

  /// 발전기 정격전압[V] (정격전류 계산용). 비우면 전류는 계산하지 않는다.
  final double? volts;

  /// 선정한 발전기 용량[kVA]. 넣으면 합격/불합격을 본다.
  final double? chosenKva;
}

/// 기동 역률을 모를 때 원문이 쓰라는 값(건축전기설비설계기준 제5장 3.1.2(5) "불분명시 0.4 적용").
const double kGenStartPfDefault = 0.4;

class GenResult {
  const GenResult({
    required this.errors,
    this.pg1,
    this.pg2,
    this.pg3,
    this.required,
    this.governing,
    this.currentA,
    this.notes = const [],
    this.chosenPass,
    this.chosenMarginPct,
    this.startPfUsed,
  });

  /// PG3에 실제로 쓴 기동 역률(비웠으면 원문 기본값 0.4).
  final double? startPfUsed;

  /// "입력 확인" 사유. 하나라도 있으면 값은 없다.
  final List<String> errors;
  final double? pg1;
  final double? pg2;
  final double? pg3;

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

/// PG3 = [(부하 − Pm) ÷ η + Pm × β × C × Pfm] × 1 ÷ cosθL [kVA].
/// 원문 식대로 PG1과 같은 부하 종합 역률 cosθL로 나눈다(발전기 역률이 아니다).
double genPg3(
  double loadKw,
  double pm,
  double eff,
  double beta,
  double c,
  double startPf,
  double pf,
) => ((loadKw - pm) / eff + pm * beta * c * startPf) / pf;

/// 발전기 정격전류[A] = kVA × 1000 ÷ (√3 × V). 3상.
double genRatedCurrent(double kva, double volts) =>
    kva * 1000 / (math.sqrt(3) * volts);

GenResult calcGenerator(GenInput i) {
  final errors = <String>[];
  final notes = <String>[];

  bool pos(double? v) => v != null && v > 0;
  bool frac(double? v) => v != null && v > 0 && v <= 1;

  if (!pos(i.loadKw)) errors.add('부하 합계(kW)를 0보다 크게 넣으십시오.');
  if (!frac(i.demand)) errors.add('수용률은 0 초과 100% 이하로 넣으십시오.');
  if (!frac(i.eff)) errors.add('효율은 0 초과 100% 이하로 넣으십시오.');
  if (!frac(i.pf)) errors.add('역률은 0 초과 100% 이하로 넣으십시오.');

  final hasMotor = i.motorKw != null && i.motorKw! != 0;
  if (i.motorKw != null && i.motorKw! < 0) {
    errors.add('전동기 출력(kW)은 0 이상으로 넣으십시오.');
  }
  if (hasMotor && i.motorKw! > 0) {
    if (!pos(i.beta)) errors.add('전동기 1kW당 기동 kVA(β)를 0보다 크게 넣으십시오.');
    if (!pos(i.startC)) errors.add('기동 방식 계수(C)를 0보다 크게 넣으십시오.');
    if (i.xdPct == null || i.xdPct! <= 0 || i.xdPct! >= 100) {
      errors.add('발전기 X″d(%)를 0 초과 100 미만으로 넣으십시오.');
    }
    if (i.dvPct == null || i.dvPct! <= 0 || i.dvPct! >= 100) {
      errors.add('허용 전압강하 ΔV(%)를 0 초과 100 미만으로 넣으십시오.');
    }
    // %로 읽는 칸에 0.25처럼 비율을 넣으면 0.25%로 계산돼 PG2가 크게 틀어진다. 고쳐 읽지 않고 알린다.
    for (final (name, v) in [('발전기 X″d', i.xdPct), ('허용 전압강하 ΔV', i.dvPct)]) {
      if (v != null && v > 0 && v < 1) {
        errors.add('$name(%) 입력값이 $v입니다. 이 칸은 %라서 $v%로 계산됩니다. 비율이면 ${(v * 100).round()}처럼 넣으십시오.');
      }
    }
    if (pos(i.loadKw) && i.motorKw! > i.loadKw!) {
      errors.add('가장 큰 전동기(kW)가 부하 합계보다 큽니다.');
    }
  }
  if (i.startPf != null && !frac(i.startPf)) {
    errors.add('기동 역률은 0 초과 100% 이하로 넣으십시오.');
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
  double? startPf;
  if (hasMotor) {
    pg2 = genPg2(
      i.motorKw!,
      i.beta!,
      i.startC!,
      i.xdPct! / 100,
      i.dvPct! / 100,
    );
    // 기동 역률을 비우면(예전 저장값 등) PG3를 빼지 않고 원문 기본값 0.4로 계산하고 알린다.
    startPf = i.startPf ?? kGenStartPfDefault;
    if (i.startPf == null) {
      notes.add('기동 역률을 비워 원문 기본값 40 %(불분명시 0.4)로 PG3를 계산했습니다. 제조사 값이 있으면 넣으십시오.');
    }
    pg3 = genPg3(
      i.loadKw!,
      i.motorKw!,
      i.eff!,
      i.beta!,
      i.startC!,
      startPf,
      i.pf!,
    );
  } else {
    notes.add('가장 큰 전동기를 넣지 않아 PG2와 PG3는 계산하지 않았습니다.');
  }

  final cands = <String, double>{
    'PG1': pg1,
    'PG2': ?pg2,
    'PG3': ?pg3,
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
    required: gVal,
    governing: gName,
    currentA: i.volts == null ? null : genRatedCurrent(gVal, i.volts!),
    notes: notes,
    chosenPass: pass,
    chosenMarginPct: margin,
    startPfUsed: startPf,
  );
}
