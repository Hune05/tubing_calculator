// 전동기 정격 전류 표(2026-09-26 조사, 출처는 docs/전기계산기_근거.md).
//
// NEC Table 430.250(삼상 유도전동기): NECA·1999 NEC·NEC 2014 세 사본이 모든 칸 같음.
//   NEC 430.6(A)(1): 전선·차단기는 명판이 아니라 이 표 값으로 고른다(저속·다속 전동기 예외).
// IE3 4극 60Hz 380V: WEG W22 중남미 카탈로그(Cod 50024297 Rev14) 표 — 한 제조사 예시일 뿐,
//   실제 전동기는 명판 값을 쓴다.
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

typedef Ie3Row = ({double kw, double eff, double pf, double amps});

/// WEG W22 IE3 4극 60Hz 380V(효율·역률은 100% 부하).
const List<Ie3Row> kIe3At380V60Hz = [
  (kw: 0.75, eff: 85.5, pf: 0.79, amps: 1.69),
  (kw: 1.5, eff: 86.5, pf: 0.80, amps: 3.29),
  (kw: 2.2, eff: 89.5, pf: 0.79, amps: 4.72),
  (kw: 3.7, eff: 89.5, pf: 0.80, amps: 7.85),
  (kw: 5.5, eff: 91.7, pf: 0.82, amps: 11.1),
  (kw: 7.5, eff: 92.0, pf: 0.84, amps: 14.7),
  (kw: 11, eff: 92.7, pf: 0.81, amps: 22.2),
  (kw: 15, eff: 93.4, pf: 0.82, amps: 29.8),
  (kw: 18.5, eff: 93.8, pf: 0.81, amps: 36.9),
  (kw: 22, eff: 94.0, pf: 0.81, amps: 43.9),
  (kw: 30, eff: 94.4, pf: 0.84, amps: 57.4),
  (kw: 37, eff: 94.6, pf: 0.84, amps: 70.7),
  (kw: 45, eff: 95.1, pf: 0.85, amps: 84.5),
  (kw: 55, eff: 95.4, pf: 0.87, amps: 101),
  (kw: 75, eff: 95.5, pf: 0.85, amps: 140),
  (kw: 90, eff: 95.6, pf: 0.86, amps: 167),
  (kw: 110, eff: 95.8, pf: 0.86, amps: 203),
  (kw: 132, eff: 96.2, pf: 0.86, amps: 243),
  (kw: 150, eff: 96.2, pf: 0.86, amps: 276),
  (kw: 185, eff: 96.3, pf: 0.87, amps: 336),
  (kw: 200, eff: 96.3, pf: 0.86, amps: 367),
];

Ie3Row? ie3Row(double kw) {
  for (final r in kIe3At380V60Hz) {
    if ((r.kw - kw).abs() < 1e-6) return r;
  }
  return null;
}

/// NEC 430.52: 전동기 분기 단락·지락 보호 — 역한시 차단기는 정격 전류의 250%까지.
const double kNecInverseTimeBreakerMaxPct = 250;
