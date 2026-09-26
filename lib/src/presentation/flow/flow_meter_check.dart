// 유량계 점검(화면 없음). 유량 전송기 명판·설정의 측정 범위와 출력 방식으로, 현장에서 잰 루프 전류(mA)와
// 표시창·DCS 지시값이 서로 맞는지 본다. mA ↔ % 식과 NE43 구간은 instrument/signal_calc.dart를 쓴다.
// 근거는 docs/유량계산_근거.md "유량계 점검".
library;

import 'dart:math' as math;

import '../instrument/signal_calc.dart';

/// 유량계 종류. 차압식만 출력이 차압(유량의 제곱)에 비례할 수 있고, 나머지는 mA가 유량에 비례한다.
enum MeterType { dp, mag, vortex, coriolis }

extension MeterTypeLabel on MeterType {
  String get label => switch (this) {
    MeterType.dp => '차압식',
    MeterType.mag => '전자식',
    MeterType.vortex => '와류식·터빈',
    MeterType.coriolis => '질량식',
  };
}

/// 차압식 전송기 출력 설정.
/// - [sqrtOut]: 전송기가 제곱근을 해서 내보냄(명판·설정 SQRT). mA가 유량에 비례, DCS는 선형.
/// - [linearDp]: 전송기는 차압 그대로(LINEAR). mA가 차압에 비례, DCS·지시계에서 제곱근.
enum DpOut { sqrtOut, linearDp }

/// mA가 유량에 비례하는지(차압식 차압 출력만 아님).
bool maFollowsFlow(MeterType t, DpOut o) =>
    t != MeterType.dp || o == DpOut.sqrtOut;

/// 측정 mA → 유량 %(0 아래 제곱근은 0).
double meterFlowPct(double ma, MeterType t, DpOut o) {
  final out = pctFromMa(ma);
  if (maFollowsFlow(t, o)) return out;
  return out <= 0 ? 0 : 10 * math.sqrt(out);
}

/// 유량 % → 나와야 할 mA.
double meterMa(double flowPct, MeterType t, DpOut o) {
  if (maFollowsFlow(t, o)) return maFromPct(flowPct);
  return maFromPct(flowPct <= 0 ? 0 : flowPct * flowPct / 100);
}

/// 유량 % → 차압 %(차압식). 유량 50%면 차압 25%.
double dpPctOfFlow(double flowPct) =>
    flowPct <= 0 ? 0 : flowPct * flowPct / 100;

/// 제곱근 설정이 틀렸을 때 흔한 경우.
enum SqrtMistake {
  /// 제곱근을 두 번(전송기 SQRT인데 DCS도 제곱근, 또는 선형 계기인데 DCS 제곱근이 켜짐).
  twice,

  /// 제곱근을 어디서도 안 함(전송기 LINEAR인데 DCS도 선형).
  none,
}

/// 점검 결과.
class MeterCheck {
  const MeterCheck({
    required this.flowPct,
    required this.expected,
    required this.cutOff,
    this.errSpanPct,
    this.errReadPct,
    this.pass,
    this.mistake,
  });

  /// mA로 본 유량 %.
  final double flowPct;

  /// mA로 보면 표시되어야 할 유량(소유량 차단 아래면 0).
  final double expected;

  /// 소유량 차단 아래라 0으로 본 것인지.
  final bool cutOff;

  /// 지시값 − 기대값의 스팬 %. 지시값이 없으면 null.
  final double? errSpanPct;

  /// 지시값 − 기대값의 지시 %(기대값이 0이면 null).
  final double? errReadPct;

  /// 허용 오차가 있을 때만 판정.
  final bool? pass;

  /// 지시값이 제곱근을 잘못 건 경우와 맞으면 그 경우.
  final SqrtMistake? mistake;
}

/// [ma] 측정 전류, [indicated] 표시창·DCS 지시값(없으면 null), [tolSpanPct] 허용 오차(스팬 %, 없으면 판정 안 함),
/// [cutPct] 소유량 차단(유량 %, 없으면 null). 측정 범위는 [lrv]~[urv](차압식은 0~최대 유량).
MeterCheck checkMeter({
  required double ma,
  required double lrv,
  required double urv,
  required MeterType type,
  DpOut dpOut = DpOut.sqrtOut,
  double? indicated,
  double? tolSpanPct,
  double? cutPct,
}) {
  final span = urv - lrv;
  final pct = meterFlowPct(ma, type, dpOut);
  final cut = cutPct != null && cutPct > 0 && pct < cutPct;
  final expected = cut ? lrv : pctToPv(pct, lrv, urv);
  if (indicated == null) {
    return MeterCheck(flowPct: pct, expected: expected, cutOff: cut);
  }
  final errSpan = (indicated - expected) / span * 100;
  final errRead = expected == 0
      ? null
      : (indicated - expected) / expected * 100;
  final pass = tolSpanPct == null ? null : errSpan.abs() <= tolSpanPct + 1e-9;

  // 기대값과 안 맞을 때만, 제곱근을 잘못 건 경우와 맞는지 본다.
  SqrtMistake? mistake;
  final band = tolSpanPct ?? 1.0;
  if (errSpan.abs() > band) {
    final out = pctFromMa(ma);
    double off(double p) => (indicated - pctToPv(p, lrv, urv)) / span * 100;
    if (maFollowsFlow(type, dpOut)) {
      // mA가 이미 유량인데 DCS가 한 번 더 제곱근.
      if (off(out <= 0 ? 0 : 10 * math.sqrt(out)).abs() <= band) {
        mistake = SqrtMistake.twice;
      }
    } else if (off(out).abs() <= band) {
      // mA가 차압인데 DCS가 선형으로 받음.
      mistake = SqrtMistake.none;
    }
  }
  return MeterCheck(
    flowPct: pct,
    expected: expected,
    cutOff: cut,
    errSpanPct: errSpan,
    errReadPct: errRead,
    pass: pass,
    mistake: mistake,
  );
}
