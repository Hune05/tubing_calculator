// 스위치 시험(압력·온도·레벨 스위치) 계산(화면 없음). 근거는 docs/4-20mA계산기_근거.md "스위치 시험".
//
// - 동작점: 스위치 접점이 바뀐 값. 상승 동작은 올라가며, 하강 동작은 내려가며 찾는다.
// - 복귀점: 되돌아가며 접점이 원래대로 돌아온 값.
// - 데드밴드 = |동작점 − 복귀점|.
// - 오차 = 측정한 동작점 − 동작점 설정값. 허용오차는 단위 값(± bar 등) 또는 범위 %(± % × |스팬|).
// - 복귀점 설정값을 넣으면 복귀점 − 복귀점 설정값, 데드밴드 설정값을 넣으면 데드밴드 − 데드밴드 설정값을
//   같은 허용오차로 판정한다. 데드밴드 허용 범위(최소·최대)를 넣으면 그 범위도 판정한다.
// - 반복(최대 3회)마다 판정하고, 모든 반복이 합격이어야 합격.
library;

import 'temp_sensor.dart';

/// 반복 횟수(칸 수). 한 번 이상 넣으면 판정한다.
const int kSwitchRepeats = 3;

/// 동작 방향: 상승 동작(값이 올라갈 때 동작, 고 경보), 하강 동작(값이 내려갈 때 동작, 저 경보).
enum SwitchDir { rising, falling }

String switchDirLabel(SwitchDir d) => d == SwitchDir.rising ? '상승 동작' : '하강 동작';

/// 허용오차 방식: 단위 값(± bar 등) 또는 범위 %(0%~100% 값의 스팬 기준).
enum SwitchTolMode { unit, pct }

/// 접점(기록만 한다).
enum SwitchContact { no, nc }

String switchContactLabel(SwitchContact c) =>
    c == SwitchContact.no ? 'NO (a접점)' : 'NC (b접점)';

/// 스위치 설정: 동작 방향·동작점 설정값·복귀점 또는 데드밴드 설정값·허용오차·데드밴드 허용 범위·접점.
class SwitchSpec {
  final SwitchDir dir;
  final double setpoint; // 동작점 설정값
  final double? resetSet; // 복귀점 설정값(선택)
  final double? dbSet; // 데드밴드 설정값(선택). 복귀점 설정값과 둘 중 하나만 쓴다
  final SwitchTolMode tolMode;
  final double? tol; // 허용오차(단위 값 또는 범위 %). 0 이하·없음은 판정하지 않음
  final double? dbMin; // 데드밴드 허용 최소(선택)
  final double? dbMax; // 데드밴드 허용 최대(선택)
  final SwitchContact? contact;

  const SwitchSpec({
    this.dir = SwitchDir.rising,
    required this.setpoint,
    this.resetSet,
    this.dbSet,
    this.tolMode = SwitchTolMode.unit,
    this.tol,
    this.dbMin,
    this.dbMax,
    this.contact,
  });

  /// 허용오차(단위 값). 범위 % 방식인데 측정 범위가 없으면 null(판정하지 않음).
  double? tolUnit((double, double)? range) {
    final t = tol;
    if (t == null || t <= 0) return null;
    if (tolMode == SwitchTolMode.unit) return t;
    if (range == null) return null;
    return t / 100 * (range.$2 - range.$1).abs();
  }

  /// 범위 % 허용오차를 넣었는데 측정 범위가 없어 판정할 수 없는지.
  bool tolNeedsRange((double, double)? range) =>
      tolMode == SwitchTolMode.pct && tol != null && tol! > 0 && range == null;

  /// 복귀점 목표: 복귀점 설정값, 없으면 데드밴드 설정값에서 계산(상승 동작은 아래, 하강 동작은 위).
  double? get resetTarget {
    if (resetSet != null) return resetSet;
    final d = dbSet;
    if (d == null) return null;
    return dir == SwitchDir.rising ? setpoint - d : setpoint + d;
  }

  /// 데드밴드 허용 범위를 넣었는지.
  bool get hasDbRange => dbMin != null || dbMax != null;

  Map<String, dynamic> toJson() => {
    'dir': dir.name,
    'sp': setpoint,
    if (resetSet != null) 'rs': resetSet,
    if (dbSet != null) 'db': dbSet,
    'tm': tolMode.name,
    if (tol != null) 'tol': tol,
    if (dbMin != null) 'dbMin': dbMin,
    if (dbMax != null) 'dbMax': dbMax,
    if (contact != null) 'ct': contact!.name,
  };

  factory SwitchSpec.fromJson(Map<String, dynamic> j) => SwitchSpec(
    dir: SwitchDir.values.firstWhere(
      (d) => d.name == j['dir'],
      orElse: () => SwitchDir.rising,
    ),
    setpoint: (j['sp'] as num).toDouble(),
    resetSet: (j['rs'] as num?)?.toDouble(),
    dbSet: (j['db'] as num?)?.toDouble(),
    tolMode: SwitchTolMode.values.firstWhere(
      (m) => m.name == j['tm'],
      orElse: () => SwitchTolMode.unit,
    ),
    tol: (j['tol'] as num?)?.toDouble(),
    dbMin: (j['dbMin'] as num?)?.toDouble(),
    dbMax: (j['dbMax'] as num?)?.toDouble(),
    contact: SwitchContact.values.where((c) => c.name == j['ct']).firstOrNull,
  );
}

/// 반복 한 번의 측정값: 동작점(비우면 이 반복은 측정하지 않음)과 복귀점(선택).
class SwitchRepeat {
  final double? trip;
  final double? reset;
  const SwitchRepeat({this.trip, this.reset});

  Map<String, dynamic> toJson() => {'t': trip, 'r': reset};
  factory SwitchRepeat.fromJson(Map<String, dynamic> j) => SwitchRepeat(
    trip: (j['t'] as num?)?.toDouble(),
    reset: (j['r'] as num?)?.toDouble(),
  );
}

/// 반복 한 번의 결과.
class SwitchRow {
  final double trip;
  final double? reset;
  final double err; // 동작점 오차(단위)
  final double? errPct; // 동작점 오차(범위 %). 측정 범위가 없으면 null
  final bool? tripPass; // 허용오차가 없으면 null
  final double? deadband; // 복귀점이 없으면 null
  // 복귀 오차: 복귀점 설정값이 있으면 복귀점 − 복귀점 설정값,
  // 데드밴드 설정값이 있으면 데드밴드 − 데드밴드 설정값. 둘 다 없거나 복귀점이 없으면 null.
  final double? resetErr;
  final bool? resetPass; // 복귀 오차가 허용오차 이내인지
  final bool? dbRangePass; // 데드밴드 허용 범위(넣었을 때)
  final bool wrongSide; // 복귀점이 동작 방향과 맞지 않는 쪽(상승 동작인데 복귀점이 동작점보다 높음 등)

  const SwitchRow({
    required this.trip,
    this.reset,
    required this.err,
    this.errPct,
    this.tripPass,
    this.deadband,
    this.resetErr,
    this.resetPass,
    this.dbRangePass,
    this.wrongSide = false,
  });

  /// 판정: 동작점·복귀점·데드밴드 가운데 판정한 것이 모두 합격이면 합격. 판정한 것이 없으면 null.
  bool? get pass {
    final v = [tripPass, resetPass, dbRangePass].whereType<bool>();
    if (v.isEmpty) return null;
    return v.every((e) => e);
  }
}

/// 한 벌(조정 전 또는 조정 후)의 결과.
class SwitchSummary {
  final SwitchSpec spec;
  final List<SwitchRow?> rows; // 반복마다(동작점이 없으면 null)
  final double? tolUnit; // 허용오차(단위). 없으면 null
  final bool tolNeedsRange; // 범위 % 허용오차인데 측정 범위가 없음

  const SwitchSummary({
    required this.spec,
    required this.rows,
    this.tolUnit,
    this.tolNeedsRange = false,
  });

  List<(int, SwitchRow)> get measured => [
    for (var i = 0; i < rows.length; i++)
      if (rows[i] != null) (i, rows[i]!),
  ];

  bool get isEmpty => measured.isEmpty;

  /// 동작점 오차가 가장 큰 반복.
  (int, SwitchRow)? get worst {
    final m = measured;
    if (m.isEmpty) return null;
    return m.reduce((a, b) => b.$2.err.abs() > a.$2.err.abs() ? b : a);
  }

  double? _avg(Iterable<double> v) =>
      v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;

  double? get avgTrip => _avg(measured.map((e) => e.$2.trip));
  double? get avgReset =>
      _avg(measured.map((e) => e.$2.reset).whereType<double>());
  double? get avgDeadband =>
      _avg(measured.map((e) => e.$2.deadband).whereType<double>());

  /// 반복성: 동작점의 최대 − 최소(반복 두 번 이상).
  double? get repeatability {
    final t = measured.map((e) => e.$2.trip).toList();
    if (t.length < 2) return null;
    t.sort();
    return t.last - t.first;
  }

  /// 불합격 반복.
  List<int> get failed => [
    for (final m in measured)
      if (m.$2.pass == false) m.$1,
  ];

  /// 복귀점을 넣지 않아 복귀점·데드밴드를 판정하지 못한 반복(복귀 설정·데드밴드 허용 범위가 있을 때).
  List<int> get resetMissing => [
    if (spec.resetSet != null || spec.dbSet != null || spec.hasDbRange)
      for (final m in measured)
        if (m.$2.reset == null) m.$1,
  ];

  /// 판정: 측정한 반복이 없거나 판정한 것이 없으면 null.
  bool? get pass {
    final m = measured;
    if (m.isEmpty || !m.any((e) => e.$2.pass != null)) return null;
    return failed.isEmpty;
  }
}

/// 반복마다 계산한다. [range]는 측정 범위(0%·100% 값). 없으면 범위 %를 계산하지 않는다.
SwitchSummary evaluateSwitch({
  required SwitchSpec spec,
  required List<SwitchRepeat> repeats,
  (double, double)? range,
}) {
  final tolU = spec.tolUnit(range);
  final span = range == null ? null : (range.$2 - range.$1).abs();
  const eps = 1e-9;
  SwitchRow? row(SwitchRepeat r) {
    final t = r.trip;
    if (t == null) return null;
    final err = t - spec.setpoint;
    final rs = r.reset;
    final db = rs == null ? null : (t - rs).abs();
    final double? rErr;
    if (rs == null) {
      rErr = null;
    } else if (spec.resetSet != null) {
      rErr = rs - spec.resetSet!;
    } else if (spec.dbSet != null) {
      rErr = db! - spec.dbSet!;
    } else {
      rErr = null;
    }
    bool? dbOk;
    if (db != null && spec.hasDbRange) {
      dbOk =
          (spec.dbMin == null || db >= spec.dbMin! - eps) &&
          (spec.dbMax == null || db <= spec.dbMax! + eps);
    }
    return SwitchRow(
      trip: t,
      reset: rs,
      err: err,
      errPct: span == null || span == 0 ? null : err / span * 100,
      tripPass: tolU == null ? null : err.abs() <= tolU + eps,
      deadband: db,
      resetErr: rErr,
      resetPass: rErr == null || tolU == null ? null : rErr.abs() <= tolU + eps,
      dbRangePass: dbOk,
      wrongSide:
          rs != null &&
          (spec.dir == SwitchDir.rising ? rs > t + eps : rs < t - eps),
    );
  }

  return SwitchSummary(
    spec: spec,
    rows: [for (final r in repeats) row(r)],
    tolUnit: tolU,
    tolNeedsRange: spec.tolNeedsRange(range),
  );
}

String _fmt(double v, [int d = 3]) {
  var s = (v + (v >= 0 ? 1e-9 : -1e-9)).toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s == '-0' ? '0' : s;
}

/// 데드밴드 허용 범위 글: "0.2 ~ 0.5", "0.2 이상", "0.5 이하". 없으면 ''.
String switchDbRangeText(SwitchSpec s, [String unit = '']) {
  final u = unit.trim().isEmpty ? '' : ' ${unit.trim()}';
  final lo = s.dbMin, hi = s.dbMax;
  if (lo != null && hi != null) return '${_fmt(lo)} ~ ${_fmt(hi)}$u';
  if (lo != null) return '${_fmt(lo)}$u 이상';
  if (hi != null) return '${_fmt(hi)}$u 이하';
  return '';
}

/// 허용오차 글: "±0.1 bar", "±0.5% 범위". 없으면 ''.
String switchTolText(SwitchSpec s, [String unit = '']) {
  final t = s.tol;
  if (t == null || t <= 0) return '';
  if (s.tolMode == SwitchTolMode.pct) return '±${_fmt(t)}% 범위';
  return '±${_fmt(t)}${unit.trim().isEmpty ? '' : ' ${unit.trim()}'}';
}

/// 교정기에 넣을 센서 값 글: "Pt100 138.506 Ω", "K형 4.096 mV, 냉접점 20 °C면 3.298 mV".
/// 적용 범위를 벗어나면 "K형 범위 초과".
String switchSensorText(TempSensor t, double tC, {double cjC = 0}) {
  String word((double, double) r, double v) => v > r.$2 ? '범위 초과' : '범위 미만';
  final v0 = sensorValue(t, tC);
  if (v0 == null) return '${t.label} ${word(t.tempRange, tC)}';
  final base = '${t.label} ${_fmt(v0)} ${t.unit}';
  if (t.isRtd || cjC == 0) return base;
  final v = calibratorValue(t, tC, cjC: cjC);
  return v == null
      ? '$base, 냉접점 ${_fmt(cjC)} °C는 ${word(t.tempRange, cjC)}'
      : '$base, 냉접점 ${_fmt(cjC)} °C면 ${_fmt(v)} mV';
}
