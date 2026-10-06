// 감전 보호 자동 차단(TN·TT)과 절연저항·절연내력 판정(10-03). 화면 없이 계산만 한다.
// 근거: 현행 KEC 원문(기후에너지환경부공고 제2025-227호, 시행 2026.1.5) 211.2·132·133,
// 전기설비기술기준 제52조(고시 제2025-18호). 원문은 국가법령정보센터에서 직접 받아 확인했다.
// B·C·D형 순시 범위는 KEC 표 212.3-3, 차단시간은 표 211.2-1과 211.2.3의 3(TN 5초·TT 1초)으로 확인했다.
// 원문 확인을 못 한 값(차단기 순시 설정 +20 %, 구리 ρ 0.0225, 누전차단기 Ia = 5 × IΔn)은 화면에 "참고"로 표시한다.
// 정리: docs/전기_접지_전동기보호_근거.md
library;

enum EarthSystem { tn, tt }

/// KEC 표 211.2-1: 32 A 이하 분기회로 최대 차단시간(초). [u0] 대지전압(교류) 또는 직류 선간전압(V).
/// 50 V 이하는 표 대상이 아니라 null. 직류 50~120 V는 [비고1](감전보호 외 다른 이유로 차단 필요할 수 있음)이라 null.
double? maxDisconnectTime({
  required EarthSystem sys,
  required double u0,
  bool dc = false,
}) {
  if (u0 <= 50) return null;
  final tn = sys == EarthSystem.tn;
  if (u0 <= 120) return dc ? null : (tn ? 0.8 : 0.3);
  if (u0 <= 230) return dc ? (tn ? 5 : 0.4) : (tn ? 0.4 : 0.2);
  if (u0 <= 400) return dc ? (tn ? 0.4 : 0.2) : (tn ? 0.2 : 0.07);
  return dc ? 0.1 : (tn ? 0.1 : 0.04);
}

/// 배전회로(간선)와 32 A 초과 회로의 최대 차단시간(초): TN 5초, TT 1초(KEC 211.2.3의 3 다·라).
double distributionDisconnectTime(EarthSystem sys) =>
    sys == EarthSystem.tn ? 5 : 1;

/// 보호장치 종류. B·C·D는 순시 트립 범위 상한(5·10·20 In)을 Ia로 쓴다(KEC 표 212.3-3, 주택용 배선차단기).
/// [setting]은 순시 설정 전류에 허용오차 20 %를 더한다(Legrand, 2차 자료).
/// [rcd]는 누전차단기: Ia = 5 × IΔn(IEC 60364-4-41 주석, KEC에는 주석 없음).
enum ProtDevice { b, c, d, setting, rcd }

/// 차단시간 안에 보호장치를 동작시키는 전류 Ia(A). [rating] B·C·D는 정격전류 In, setting은 순시 설정 전류, rcd는 IΔn.
double? tripCurrentIa(ProtDevice dev, double rating) {
  if (rating <= 0) return null;
  return switch (dev) {
    ProtDevice.b => 5 * rating,
    ProtDevice.c => 10 * rating,
    ProtDevice.d => 20 * rating,
    ProtDevice.setting => 1.2 * rating,
    ProtDevice.rcd => 5 * rating,
  };
}

/// TN 계통 조건 Zs × Ia ≤ U0에서 고장 루프 임피던스 최댓값(Ω).
double? maxLoopImpedance({required double u0, required double ia}) {
  if (u0 <= 0 || ia <= 0) return null;
  return u0 / ia;
}

/// 케이블로 Zs를 대략 구한다: Zs ≈ Ze + ρ·L·(1/S상 + 1/S보호). ρ 기본 0.0225 Ω·mm²/m(구리, 운전 온도 반영
/// 관례값, Legrand 2차 자료). 리액턴스는 뺀다(굵은 케이블은 과소평가).
double? estimateLoopImpedance({
  required double ze,
  required double lengthM,
  required double phaseMm2,
  required double peMm2,
  double rho = 0.0225,
}) {
  if (ze < 0 || lengthM <= 0 || phaseMm2 <= 0 || peMm2 <= 0) return null;
  return ze + rho * lengthM * (1 / phaseMm2 + 1 / peMm2);
}

/// 저압 전로 구분(전기설비기술기준 제52조 표).
enum LvCircuit { selvPelv, upTo500, over500 }

/// 저압 전로 절연저항: (시험전압 V DC, 최소 MΩ).
({double testV, double minMOhm}) lvInsulation(LvCircuit c) => switch (c) {
  LvCircuit.selvPelv => (testV: 250, minMOhm: 0.5),
  LvCircuit.upTo500 => (testV: 500, minMOhm: 1.0),
  LvCircuit.over500 => (testV: 1000, minMOhm: 1.0),
};

/// 고압·특고압 전로 종류(KEC 표 132-1의 1~7).
enum HvCircuit {
  upTo7k,
  multiGround7to25,
  k7to60,
  over60Ungrounded,
  over60Grounded,
  over60Solid,
  over170PlantSolid,
}

/// 전로 절연내력 시험전압(kV). [vmaxKv] 최대사용전압(kV). 종류의 전압 범위를 벗어나면 null.
double? hvTestVoltageKv(HvCircuit kind, double vmaxKv) {
  if (vmaxKv <= 0) return null;
  switch (kind) {
    case HvCircuit.upTo7k:
      return vmaxKv <= 7 ? 1.5 * vmaxKv : null;
    case HvCircuit.multiGround7to25:
      return vmaxKv > 7 && vmaxKv <= 25 ? 0.92 * vmaxKv : null;
    case HvCircuit.k7to60:
      if (vmaxKv <= 7 || vmaxKv > 60) return null;
      final v = 1.25 * vmaxKv;
      return v < 10.5 ? 10.5 : v;
    case HvCircuit.over60Ungrounded:
      return vmaxKv > 60 ? 1.25 * vmaxKv : null;
    case HvCircuit.over60Grounded:
      if (vmaxKv <= 60) return null;
      final v = 1.1 * vmaxKv;
      return v < 75 ? 75 : v;
    case HvCircuit.over60Solid:
      return vmaxKv > 60 ? 0.72 * vmaxKv : null;
    case HvCircuit.over170PlantSolid:
      return vmaxKv > 170 ? 0.64 * vmaxKv : null;
  }
}

/// 회전기(발전기·전동기 등, 회전변류기 제외) 절연내력 시험전압(kV), KEC 표 133-1. 권선과 대지 사이 10분.
/// 7 kV 이하 1.5배(500 V 미만이면 500 V), 7 kV 초과 1.25배(10.5 kV 미만이면 10.5 kV).
double? machineTestVoltageKv(double vmaxKv) {
  if (vmaxKv <= 0) return null;
  if (vmaxKv <= 7) {
    final v = 1.5 * vmaxKv;
    return v < 0.5 ? 0.5 : v;
  }
  final v = 1.25 * vmaxKv;
  return v < 10.5 ? 10.5 : v;
}
