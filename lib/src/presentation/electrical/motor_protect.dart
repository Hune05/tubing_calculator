// 전동기 보호 계산(10-03): 열동·전자식 과부하계전기 설정, 트립 클래스, 단락보호 차단기 상한, 전선 허용전류 여유.
// 화면 없이 계산만 한다. 근거와 확인 정도는 docs/전기_접지_전동기보호_근거.md.
//
// 확인 정도(2026-10-03 조사): Y-Δ 델타 내부 설정 0.58배·NEC 430.32 125/115%·NEC 430.52 비율·트립 클래스 시간은
// 두 곳 이상이 같다. 국내 열동 계전기 120~125% 규칙과 EOCR 설정 배수는 출처마다 달라 범위로만 보인다.
library;

import 'dart:math' as math;

enum StartMethod { direct, starDelta }

/// 계전기 위치(Y-Δ 기동일 때): 델타 권선 안(상전류를 봄) / 접촉기 라인 쪽(선전류를 봄).
enum RelayPlace { insideDelta, line }

/// 열동 과부하계전기 설정 전류(A). 직입은 명판 정격전류 그대로.
/// Y-Δ에서 계전기가 델타 권선 안에 있으면 상전류 = 선전류/√3이라 FLA/√3(0.58배)로 맞춘다
/// (Siemens 설명서: "정격전류의 0.58배보다 높게 설정하지 말 것").
/// 라인 쪽에 있으면 선전류를 보므로 FLA 그대로(검색 요약 한 곳, 확인 필요).
double thrSetting(
  double fla, {
  StartMethod method = StartMethod.direct,
  RelayPlace place = RelayPlace.insideDelta,
}) {
  if (method == StartMethod.starDelta && place == RelayPlace.insideDelta) {
    return fla / math.sqrt(3);
  }
  return fla;
}

/// NEC 430.32 과부하 보호 최대 설정(A): 서비스팩터 1.15 이상 또는 온도상승 40℃ 이하 표시면 FLA × 125%, 그 밖은 115%.
double necOverloadMax(double fla, {required bool sf115OrTemp40}) =>
    fla * (sf115OrTemp40 ? 1.25 : 1.15);

/// 전자식(EOCR) 부하 설정 범위(A): 기동이 끝난 정상 운전전류의 110~125%(삼화 매뉴얼 설명 두 곳).
/// 다른 자료는 정격전류의 125~150%라고 해서 기준이 다르다(출처 상이).
(double, double) eocrRange(double runningAmps) =>
    (runningAmps * 1.10, runningAmps * 1.25);

/// 트립 클래스(IEC 60947-4-1): 설정전류 7.2배에서 냉상태 동작시간 범위(초).
const Map<String, (double, double)> kTripClass72 = {
  '10A': (2, 10),
  '10': (4, 10),
  '20': (6, 20),
  '30': (9, 30),
};

/// 기동시간이 클래스 상한 이상이면 기동 중에 트립될 수 있다(기동전류 6배 근처 가정, 7.2배 기준 근사).
/// 반환: null이면 판단 못 함, true면 주의(클래스 상한 이상).
bool? startMayTrip(String cls, double startSeconds) {
  final r = kTripClass72[cls];
  if (r == null || startSeconds <= 0) return null;
  return startSeconds >= r.$2;
}

/// NEC 430.52 단락·지락 보호 장치 최대 정격(FLC 대비 %). FLC는 명판이 아니라 NEC 표 430.250 값.
const Map<String, double> kNecShortCircuitPct = {
  '이중소자(지연) 퓨즈': 175,
  '역시간 차단기': 250,
  '비지연 퓨즈': 300,
  '순시트립 차단기': 800,
};

/// FLC(A)에 대한 최대 정격(A). 규격 정격에 안 맞으면 다음 큰 규격을 쓸 수 있고, 기동이 안 되면 올릴 수 있다.
double necShortCircuitMax(double flc, String type) =>
    flc * (kNecShortCircuitPct[type] ?? 250) / 100;

/// 전동기 1대 연속운전 전선 허용전류 하한: FLC × 125%.
double motorConductorMin(double flc) => flc * 1.25;
