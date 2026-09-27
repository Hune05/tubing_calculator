// 축전지 용량 산정(발전소 직류 전원)의 순수 계산. 화면 없음.
// 구간 방식: 구간 s의 용량 = Σ (Ap − Ap-1) × K(단계 p 시작부터 구간 s 끝까지의 시간). 구간 용량의 최댓값이 기준이다.
// SBA S 0601 방식은 최댓값 ÷ 보수율 L, IEEE 485 방식은 최댓값 × 온도 보정계수 × (1 + 설계 여유) × 노화계수.
// K 값(용량환산시간)은 제조사 방전 특성표에서 읽어 사용자가 넣는다. 표는 앱에 없다. 근거는 docs/전기_축전지_근거.md.

enum BatteryMethod {
  sba('SBA S 0601'),
  ieee('IEEE 485');

  const BatteryMethod(this.label);
  final String label;
}

class BatteryStep {
  const BatteryStep(this.amps, this.minutes);

  /// 이 단계의 부하 전류[A].
  final double amps;

  /// 이 단계가 이어지는 시간[분].
  final double minutes;
}

/// K 값을 찾는 열쇠. 분 단위, 소수 둘째 자리까지, 뒤의 0은 뗀다(25.00 → 25).
String battTimeKey(double minutes) {
  var s = minutes.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// 단계 [from]부터 [to]까지(0부터, 양 끝 포함) 시간 합[분].
double battSpanMinutes(List<BatteryStep> steps, int from, int to) {
  var t = 0.0;
  for (var i = from; i <= to; i++) {
    t += steps[i].minutes;
  }
  return t;
}

/// 계산에 필요한 K의 시간 목록[분]. 중복 없이 작은 것부터.
List<double> battNeededTimes(List<BatteryStep> steps) {
  final byKey = <String, double>{};
  for (var s = 0; s < steps.length; s++) {
    for (var p = 0; p <= s; p++) {
      final t = battSpanMinutes(steps, p, s);
      byKey[battTimeKey(t)] = t;
    }
  }
  return byKey.values.toList()..sort();
}

class BatteryInput {
  const BatteryInput({
    required this.method,
    required this.steps,
    this.k = const {},
    this.maintenance,
    this.tempFactor,
    this.marginPct,
    this.agingFactor,
    this.chosenAh,
    this.busVolts,
    this.cellNominal,
    this.cellMin,
    this.cells,
    this.minBusVolts,
  });

  final BatteryMethod method;
  final List<BatteryStep> steps;

  /// 제조사 표에서 읽은 K[시간]. 열쇠는 [battTimeKey].
  final Map<String, double> k;

  /// SBA 방식의 보수율 L (0 초과 1 이하).
  final double? maintenance;

  /// IEEE 방식의 온도 보정계수.
  final double? tempFactor;

  /// IEEE 방식의 설계 여유[%].
  final double? marginPct;

  /// IEEE 방식의 노화계수(1.25는 용량이 80%로 줄었을 때를 뜻한다).
  final double? agingFactor;

  /// 선정한 축전지 용량[Ah].
  final double? chosenAh;

  /// 직류 모선 전압[V].
  final double? busVolts;

  /// 셀당 공칭 전압[V].
  final double? cellNominal;

  /// 셀당 최저 허용 전압(방전 종지)[V].
  final double? cellMin;

  /// 선정한 셀 수.
  final double? cells;

  /// 부하가 허용하는 최저 모선 전압[V].
  final double? minBusVolts;
}

class BatteryTerm {
  const BatteryTerm({
    required this.stepNo,
    required this.dAmps,
    required this.minutes,
    required this.k,
    required this.ah,
  });

  /// 단계 번호(1부터).
  final int stepNo;

  /// 전류 변화 Ap − Ap-1[A].
  final double dAmps;

  /// 단계 시작부터 구간 끝까지 시간[분].
  final double minutes;
  final double k;
  final double ah;
}

class BatterySection {
  const BatterySection({required this.endStep, required this.terms});

  /// 구간이 끝나는 단계 번호(1부터).
  final int endStep;
  final List<BatteryTerm> terms;

  double get total => terms.fold(0.0, (a, t) => a + t.ah);
}

class BatteryResult {
  const BatteryResult({
    required this.errors,
    this.sections = const [],
    this.maxSection,
    this.base,
    this.required,
    this.chosenPass,
    this.chosenMarginPct,
    this.cellRatio,
    this.endVolts,
    this.endVoltsPass,
  });

  /// "입력 확인" 사유. 하나라도 있으면 값은 없다.
  final List<String> errors;
  final List<BatterySection> sections;

  /// 구간 용량이 가장 큰 구간 번호(1부터).
  final int? maxSection;

  /// 구간 용량의 최댓값[Ah].
  final double? base;

  /// 필요 용량[Ah].
  final double? required;
  final bool? chosenPass;

  /// 선정 용량 여유율[%] = 선정/필요 − 1.
  final double? chosenMarginPct;

  /// 모선 전압 ÷ 셀당 공칭 전압.
  final double? cellRatio;

  /// 방전 종지 때 모선 전압 = 셀 수 × 셀당 최저 전압.
  final double? endVolts;
  final bool? endVoltsPass;

  bool get ok => errors.isEmpty && required != null;
}

BatteryResult calcBattery(BatteryInput i) {
  final errors = <String>[];

  if (i.steps.isEmpty) errors.add('방전 단계를 하나 이상 넣으십시오.');
  for (var n = 0; n < i.steps.length; n++) {
    final s = i.steps[n];
    if (!(s.amps > 0)) errors.add('${n + 1}단계 전류(A)를 0보다 크게 넣으십시오.');
    if (!(s.minutes > 0)) errors.add('${n + 1}단계 시간(분)을 0보다 크게 넣으십시오.');
  }

  if (i.method == BatteryMethod.sba) {
    if (i.maintenance == null || i.maintenance! <= 0 || i.maintenance! > 1) {
      errors.add('보수율 L은 0 초과 1 이하로 넣으십시오.');
    }
  } else {
    if (i.tempFactor == null || i.tempFactor! <= 0) {
      errors.add('온도 보정계수를 0보다 크게 넣으십시오.');
    }
    if (i.marginPct == null || i.marginPct! < 0) {
      errors.add('설계 여유(%)를 0 이상으로 넣으십시오. 없으면 0입니다.');
    }
    if (i.agingFactor == null || i.agingFactor! <= 0) {
      errors.add('노화계수를 0보다 크게 넣으십시오.');
    }
  }
  if (i.chosenAh != null && i.chosenAh! <= 0) {
    errors.add('선정 용량(Ah)은 0보다 크게 넣으십시오.');
  }

  // 셀 수 쪽 입력 확인.
  if (i.busVolts != null && i.busVolts! <= 0) {
    errors.add('직류 모선 전압(V)은 0보다 크게 넣으십시오.');
  }
  if (i.cellNominal != null && i.cellNominal! <= 0) {
    errors.add('셀당 공칭 전압(V)은 0보다 크게 넣으십시오.');
  }
  if (i.cellMin != null && i.cellMin! <= 0) {
    errors.add('셀당 최저 전압(V)은 0보다 크게 넣으십시오.');
  }
  if (i.cells != null &&
      (i.cells! < 1 || i.cells! != i.cells!.roundToDouble())) {
    errors.add('셀 수는 1 이상의 정수로 넣으십시오.');
  }
  if (i.minBusVolts != null && i.minBusVolts! <= 0) {
    errors.add('부하 최저 허용 전압(V)은 0보다 크게 넣으십시오.');
  }
  if (i.cells != null && i.minBusVolts != null && i.cellMin == null) {
    errors.add('최저 모선 전압을 보려면 셀당 최저 전압(V)도 넣으십시오.');
  }

  // K 값.
  final missing = <double>[];
  if (i.steps.isNotEmpty && errors.isEmpty) {
    for (final t in battNeededTimes(i.steps)) {
      final k = i.k[battTimeKey(t)];
      if (k == null) {
        missing.add(t);
      } else if (!(k > 0)) {
        errors.add('${battTimeKey(t)}분 K 값은 0보다 크게 넣으십시오.');
      }
    }
    if (missing.isNotEmpty) {
      errors.add(
        'K 값이 필요한 시간(분): ${missing.map(battTimeKey).join(', ')}. 제조사 방전 특성표에서 읽어 넣으십시오.',
      );
    }
  }
  if (errors.isNotEmpty) return BatteryResult(errors: errors);

  final sections = <BatterySection>[];
  for (var s = 0; s < i.steps.length; s++) {
    final terms = <BatteryTerm>[];
    for (var p = 0; p <= s; p++) {
      final prev = p == 0 ? 0.0 : i.steps[p - 1].amps;
      final d = i.steps[p].amps - prev;
      final t = battSpanMinutes(i.steps, p, s);
      final k = i.k[battTimeKey(t)]!;
      terms.add(
        BatteryTerm(stepNo: p + 1, dAmps: d, minutes: t, k: k, ah: d * k),
      );
    }
    sections.add(BatterySection(endStep: s + 1, terms: terms));
  }
  var maxIdx = 0;
  for (var s = 1; s < sections.length; s++) {
    if (sections[s].total > sections[maxIdx].total) maxIdx = s;
  }
  final base = sections[maxIdx].total;
  final required = i.method == BatteryMethod.sba
      ? base / i.maintenance!
      : base * i.tempFactor! * (1 + i.marginPct! / 100) * i.agingFactor!;

  bool? pass;
  double? margin;
  if (i.chosenAh != null) {
    pass = i.chosenAh! + 1e-9 >= required;
    margin = (i.chosenAh! / required - 1) * 100;
  }

  double? ratio;
  if (i.busVolts != null && i.cellNominal != null) {
    ratio = i.busVolts! / i.cellNominal!;
  }
  double? endV;
  bool? endPass;
  if (i.cells != null && i.cellMin != null) {
    endV = i.cells! * i.cellMin!;
    if (i.minBusVolts != null) endPass = endV + 1e-9 >= i.minBusVolts!;
  }

  return BatteryResult(
    errors: const [],
    sections: sections,
    maxSection: maxIdx + 1,
    base: base,
    required: required,
    chosenPass: pass,
    chosenMarginPct: margin,
    cellRatio: ratio,
    endVolts: endV,
    endVoltsPass: endPass,
  );
}
