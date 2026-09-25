// 튜브 도면(보관함)에 같이 남기는 장비 값.
//
// 🚀 [고침] 예전에는 도면에 크기(늘 1/2")만 남고 반경·게인·스프링백이 없어서,
// 다시 열면 지금 설정으로 마킹을 셈했다. 그사이 설정을 바꿨으면 마킹은 새 값,
// 자를 길이는 옛 값이라 서로 맞지 않았다. 저장할 때 값을 같이 남기고, 열 때는
// 그 값으로 셈하며 지금 설정과 다르면 알린다(전선관 보관함과 같은 방식).
library;

import 'package:tubing_calculator/src/core/utils/pipe_size.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';

/// p_to_p 안에 넣는 칸 이름.
const String kTubeDrawingSpecsKey = 'specs';

/// 마킹 셈에 쓰는 장비 값만 모은다.
Map<String, double> tubeSpecsSnapshot(MachineSpecs s) => {
  'radius': s.radius,
  'gain90': s.gain90,
  'springback': s.springback,
  'benderOffset': s.benderOffset,
  'fittingDepth': s.fittingDepth,
};

/// 저장된 도면의 장비 값. 없거나(예전 도면) 모양이 다르면 null.
Map<String, double>? savedTubeSpecs(Map<String, dynamic> pToP) {
  final raw = pToP[kTubeDrawingSpecsKey];
  if (raw is! Map) return null;
  final out = <String, double>{};
  for (final k in const [
    'radius',
    'gain90',
    'springback',
    'benderOffset',
    'fittingDepth',
  ]) {
    final v = raw[k];
    out[k] = v is num ? v.toDouble() : 0.0;
  }
  return out;
}

/// 두 장비 값이 마킹이 달라질 만큼 다른지(0.05 넘게).
bool tubeSpecsDiffer(Map<String, double> a, Map<String, double> b) =>
    a.keys.any((k) => ((a[k] ?? 0) - (b[k] ?? 0)).abs() > 0.05);

/// 알림 글에 쓰는 짧은 요약("반경 38.1 · 게인 12 · 스프링백 2°").
String describeTubeSpecs(Map<String, double> s) {
  String n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return "반경 ${n(s['radius'] ?? 0)} · 게인 ${n(s['gain90'] ?? 0)} · "
      "스프링백 ${n(s['springback'] ?? 0)}°";
}

/// 설정의 관 지름(mm)에 맞는 규격 칩. 맞는 것이 없으면 null.
String? sizeChipForOd(double odMm, Iterable<String> chips) {
  if (odMm <= 0) return null;
  for (final c in chips) {
    if ((pipeSizeToMm(c) - odMm).abs() < 0.05) return c;
  }
  return null;
}
