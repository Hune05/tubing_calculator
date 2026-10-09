// 압력 시험 계산기 공용: 압력 단위(kPa 환산)와 숫자 글. 화면·시험 기록·기록서 PDF가 같이 쓴다.
library;

import 'dart:math' as math;

/// 압력 단위와 kPa 환산.
enum PUnit { bar, mpa, kgfcm2, psi, kpa }

extension PUnitInfo on PUnit {
  String get label => switch (this) {
    PUnit.bar => 'bar',
    PUnit.mpa => 'MPa',
    PUnit.kgfcm2 => 'kgf/cm²',
    PUnit.psi => 'psi',
    PUnit.kpa => 'kPa',
  };
  double get kpa => switch (this) {
    PUnit.bar => 100,
    PUnit.mpa => 1000,
    PUnit.kgfcm2 => 98.0665,
    PUnit.psi => 6.894757293168361,
    PUnit.kpa => 1,
  };
}

/// 이름으로 단위 찾기(모르는 이름이면 [fallback]).
PUnit punitByName(Object? name, [PUnit fallback = PUnit.bar]) =>
    PUnit.values.firstWhere((u) => u.name == name, orElse: () => fallback);

/// 단위마다 보일 소수 자리. MPa는 셋째 자리까지(8차, 10-09: 1.035 MPa가 1.03으로 보였다).
int ptDecimals(PUnit u) => u == PUnit.mpa ? 3 : 2;

/// 기준값(최소·최대·허용치)을 보일 소수 자리: 단위 기본 자리와, 작은 값도 유효 숫자 두 자리는 보이게 한
/// 자리 중 큰 것(최대 6). 허용 압력강하 0.0035 MPa가 0.003으로 뭉개지지 않게.
int ptDecimalsFor(double v, PUnit u) {
  final base = ptDecimals(u);
  if (v == 0 || !v.isFinite) return base;
  final mag = (math.log(v.abs()) / math.ln10).floor();
  final need = (1 - mag).clamp(0, 6);
  return need > base ? need : base;
}

/// 최소값(이 값 "이상")을 [d]자리에서 올려 글로. 보인 값대로 맞춰도 최소를 넘는다(8차: 내림으로 보여
/// 1.035 → "1.03 이상"이라 그대로 하면 불합격이었다).
String ptFmtUp(double v, [int d = 2]) {
  final f = math.pow(10, d).toDouble();
  return ptFmt(((v * f) - 1e-6).ceilToDouble() / f, d);
}

/// 최대값·허용치(이 값 "이하"·"이내")를 [d]자리에서 내려 글로.
String ptFmtDown(double v, [int d = 2]) {
  final f = math.pow(10, d).toDouble();
  return ptFmt(((v * f) + 1e-6).floorToDouble() / f, d);
}

/// 최소 압력 글("1.035 MPa"), 올림.
String ptPressureUp(double kpa, PUnit u) {
  final v = kpa / u.kpa;
  return '${ptFmtUp(v, ptDecimalsFor(v, u))} ${u.label}';
}

/// 최대·허용 압력 글, 내림.
String ptPressureDown(double kpa, PUnit u) {
  final v = kpa / u.kpa;
  return '${ptFmtDown(v, ptDecimalsFor(v, u))} ${u.label}';
}

/// 소수 [d]자리까지, 끝의 0은 뗀다(0.125가 0.12로 내려가지 않게 아주 작게 밀어 준다).
String ptFmt(double v, [int d = 2]) {
  var s = (v + (v >= 0 ? 1e-9 : -1e-9)).toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  if (s == '-0') s = '0';
  return s;
}

/// kPa 값을 [u] 단위 글로("7 bar").
String ptPressure(double kpa, PUnit u) =>
    '${ptFmt(kpa / u.kpa, ptDecimals(u))} ${u.label}';

/// 압력 변화: 내려가면 "X bar", 올라가면 "X bar 상승".
String ptDrop(double kpa, PUnit u) {
  final shown = ptFmt(kpa.abs() / u.kpa, ptDecimals(u));
  return kpa < 0 && shown != '0' ? '$shown ${u.label} 상승' : '$shown ${u.label}';
}
