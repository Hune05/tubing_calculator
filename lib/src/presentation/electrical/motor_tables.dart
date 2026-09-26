// 전동기 정격 전류 표(2026-09-26 조사, 출처는 docs/전기계산기_근거.md).
//
// NEC Table 430.250(삼상 유도전동기): NECA·1999 NEC·NEC 2014 세 사본이 모든 칸 같음.
//   NEC 430.6(A)(1): 전선·차단기는 명판이 아니라 이 표 값으로 고른다(저속·다속 전동기 예외).
// IE3 4극 60Hz 380V·440V: HD현대일렉트릭 카탈로그(2022-03) — 제조사 예시일 뿐, 실제 전동기는 명판 값.
library;

typedef NecMotorRow = ({String hp, double hpValue, double a230, double a460});

/// NEC 430.250 — 230V·460V 열(표 머리의 계통 220~240V·440~480V에 쓴다).
const List<NecMotorRow> kNec430250 = [
  (hp: '1/2', hpValue: 0.5, a230: 2.2, a460: 1.1),
  (hp: '3/4', hpValue: 0.75, a230: 3.2, a460: 1.6),
  (hp: '1', hpValue: 1, a230: 4.2, a460: 2.1),
  (hp: '1-1/2', hpValue: 1.5, a230: 6.0, a460: 3.0),
  (hp: '2', hpValue: 2, a230: 6.8, a460: 3.4),
  (hp: '3', hpValue: 3, a230: 9.6, a460: 4.8),
  (hp: '5', hpValue: 5, a230: 15.2, a460: 7.6),
  (hp: '7-1/2', hpValue: 7.5, a230: 22, a460: 11),
  (hp: '10', hpValue: 10, a230: 28, a460: 14),
  (hp: '15', hpValue: 15, a230: 42, a460: 21),
  (hp: '20', hpValue: 20, a230: 54, a460: 27),
  (hp: '25', hpValue: 25, a230: 68, a460: 34),
  (hp: '30', hpValue: 30, a230: 80, a460: 40),
  (hp: '40', hpValue: 40, a230: 104, a460: 52),
  (hp: '50', hpValue: 50, a230: 130, a460: 65),
  (hp: '60', hpValue: 60, a230: 154, a460: 77),
  (hp: '75', hpValue: 75, a230: 192, a460: 96),
  (hp: '100', hpValue: 100, a230: 248, a460: 124),
  (hp: '125', hpValue: 125, a230: 312, a460: 156),
  (hp: '150', hpValue: 150, a230: 360, a460: 180),
  (hp: '200', hpValue: 200, a230: 480, a460: 240),
];

/// NEC 표에서 [hp]와 같은 줄. 없으면 null.
NecMotorRow? necRow(double hp) {
  for (final r in kNec430250) {
    if ((r.hpValue - hp).abs() < 1e-6) return r;
  }
  return null;
}

typedef Ie3Row = ({double kw, double eff, double pf, double a380, double a440});

/// HD현대일렉트릭 저압 유도전동기 카탈로그(2022-03, TEFC SSEN, KS C 4202 프리미엄·IE3) 4극 60Hz.
/// 효율은 100% 부하, 역률은 정격. 0.75~132kW는 WEG W22 60Hz와 1~4% 안에서 맞고, 160·200kW는 이 카탈로그뿐.
const List<Ie3Row> kIe3Hd60Hz = [
  (kw: 0.75, eff: 83.5, pf: 0.780, a380: 1.75, a440: 1.51),
  (kw: 1.5, eff: 86.5, pf: 0.810, a380: 3.25, a440: 2.81),
  (kw: 2.2, eff: 89.5, pf: 0.790, a380: 4.73, a440: 4.08),
  (kw: 3.7, eff: 89.5, pf: 0.800, a380: 7.85, a440: 6.78),
  (kw: 5.5, eff: 91.7, pf: 0.770, a380: 11.83, a440: 10.22),
  (kw: 7.5, eff: 91.7, pf: 0.790, a380: 15.73, a440: 13.58),
  (kw: 11, eff: 92.4, pf: 0.814, a380: 22.2, a440: 19.2),
  (kw: 15, eff: 93.0, pf: 0.815, a380: 30.1, a440: 26.0),
  (kw: 18.5, eff: 93.6, pf: 0.820, a380: 36.6, a440: 31.6),
  (kw: 22, eff: 93.6, pf: 0.820, a380: 43.6, a440: 37.6),
  (kw: 30, eff: 94.1, pf: 0.820, a380: 59.1, a440: 51.0),
  (kw: 37, eff: 94.5, pf: 0.850, a380: 70.0, a440: 60.4),
  (kw: 45, eff: 95.0, pf: 0.850, a380: 84.7, a440: 73.1),
  (kw: 55, eff: 95.4, pf: 0.850, a380: 103.1, a440: 89.0),
  (kw: 75, eff: 95.4, pf: 0.865, a380: 138.1, a440: 119.3),
  (kw: 90, eff: 95.4, pf: 0.865, a380: 165.7, a440: 143.1),
  (kw: 110, eff: 95.8, pf: 0.880, a380: 198.2, a440: 171.2),
  (kw: 132, eff: 95.8, pf: 0.880, a380: 237.9, a440: 205.5),
  (kw: 160, eff: 96.2, pf: 0.880, a380: 287.2, a440: 248.0),
  (kw: 200, eff: 96.2, pf: 0.885, a380: 356.9, a440: 308.2),
];

Ie3Row? ie3Row(double kw) {
  for (final r in kIe3Hd60Hz) {
    if ((r.kw - kw).abs() < 1e-6) return r;
  }
  return null;
}

/// NEC 430.52: 전동기 분기 단락·지락 보호 — 역한시 차단기는 정격 전류의 250%까지.
const double kNecInverseTimeBreakerMaxPct = 250;

// ─────────────── 구 내선규정(구 판단기준) 방식 — LS ELECTRIC MCCB 선정 자료 ───────────────
// LS ELECTRIC "배선용차단기/누전차단기 선정" A1-124 "전동기회로 간선용 차단기의 선정"
// (https://www.ls-electric.com/ko/cat/HPDT/MCCB_ELCB_K_%EC%84%A0%EC%A0%95_0902.pdf):
//  · 전선의 허용전류 IW: ΣIM ≤ ΣIL이면 IW ≥ ΣIM+ΣIL, ΣIM > ΣIL이고 ΣIM ≤ 50A면 IW ≥ 1.25ΣIM+ΣIL,
//    ΣIM > 50A면 IW ≥ 1.1ΣIM+ΣIL (IM 전동기 부하전류, IL 전동기 이외 부하전류).
//  · 차단기 정격전류 Ib: Ib ≤ 3ΣIM+ΣIL 또는 Ib ≤ 2.5IW, 두 식 중 작은 값.
//  · 비고: 기동전류는 전부하전류의 600%(10초 이내), 기동 돌입전류는 1700% 이내 조건.
// 전동기 하나만 있는 회로(IL = 0)에 그대로 쓴다. 미국 NEC 430.22는 늘 125%다.

/// 전동기 정격전류 합이 이 값(A)을 넘으면 1.1배, 이하이면 1.25배.
const double kMotorMarginSplitA = 50;

/// 전동기 회로 전선·차단기 여유 배수: 50A 이하 1.25, 50A 초과 1.1(구 내선규정 방식, LS 자료).
double motorMargin(double ratedA) => ratedA > kMotorMarginSplitA ? 1.1 : 1.25;

/// 차단기 상한: 전동기 정격전류의 3배(LS 자료 Ib ≤ 3ΣIM).
const double kMotorBreakerMaxRatedMult = 3;

/// 차단기 상한: 전선 허용전류의 2.5배(LS 자료 Ib ≤ 2.5IW).
const double kMotorBreakerMaxIzMult = 2.5;

/// 전동기 기동 전류 배수 기본값(정격의 6배). EIG 2009 G장: "5 to 7 times its full-load value",
/// LS 자료 비고: 전부하전류의 600%.
const double kMotorStartMultipleDefault = 6;

/// 기동 중 역률. EIG 2009 G장 그림 G27: "At start-up: cos φ = 0.35".
const double kMotorStartPf = 0.35;
