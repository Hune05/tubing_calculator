// 압력 시험 계산기 공용: 압력 단위(kPa 환산)와 숫자 글. 화면·시험 기록·기록서 PDF가 같이 쓴다.
library;

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
String ptPressure(double kpa, PUnit u) => '${ptFmt(kpa / u.kpa)} ${u.label}';

/// 압력 변화: 내려가면 "X bar", 올라가면 "X bar 상승".
String ptDrop(double kpa, PUnit u) {
  final shown = ptFmt(kpa.abs() / u.kpa);
  return kpa < 0 && shown != '0' ? '$shown ${u.label} 상승' : '$shown ${u.label}';
}
