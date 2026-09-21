/// 오프셋·새들·롤링 오프셋 계산기가 쓰는 장비 값 한 벌.
///
/// 이 계산기들은 튜브 계산기와 전선관 계산기가 같이 쓴다. 🚀 [고침] 예전에는
/// 어디서 열든 튜브 벤더 제원(반경 38.1, 게인 12)을 읽어서, 전선관(CLR 114.3,
/// 테이크업 152.4)에서 오프셋을 넣으면 1번 마킹이 앞 직관 안쪽으로 들어갔다.
/// 어느 계산기에서 열었는지에 따라 한 벌을 골라 넘긴다.
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';

class BendSheetSpecs {
  /// 게인을 기하로 셈할 때 쓰는 반경(전선관은 CLR).
  final double radius;

  /// 실측 게인(90°). 0이면 반경으로 셈한다.
  final double gain90;

  /// 벤더에 물릴 수 있는 가장 짧은 곧은 구간. 0이면 경고하지 않는다.
  final double minStraight;
  final bool warnShoeInterference;

  /// 사용자가 설정에 넣은 여유(튜브 설정 "오프셋 축소 · 간섭 회피 여유").
  /// 1번 마킹을 그만큼 뒤로 민다.
  final double extraShrink;

  /// 기하 축소값(빗변 − 직진 거리)을 1번 마킹에 더할지.
  /// 전선관은 현장에서 "장애물까지 거리 + 축소값"에 1번 마킹을 찍으므로 설정
  /// 스위치("수축량 자동 공제")를 따른다. 튜브는 시작 거리 그대로 찍는다.
  final bool addGeometricShrink;

  /// 꺾이는 점에서 마킹까지의 거리. 마킹 화면이 빼는 값과 같아야
  /// "1번 마킹 = 시작 거리"가 된다.
  final double Function(double angle) markOffset;

  final bool isConduit;

  const BendSheetSpecs({
    required this.radius,
    required this.gain90,
    required this.markOffset,
    this.minStraight = 0.0,
    this.warnShoeInterference = true,
    this.extraShrink = 0.0,
    this.addGeometricShrink = false,
    this.isConduit = false,
  });

  /// 1번 마킹에 더할 축소값.
  double shrinkToAdd(double geometricShrink) =>
      (addGeometricShrink ? geometricShrink.clamp(0.0, double.infinity) : 0.0) +
      extraShrink;

  /// 1번 마킹이 찍힐 자리(앞 마킹이나 관 끝에서).
  double firstMark(double startDistance, double geometricShrink) =>
      startDistance + shrinkToAdd(geometricShrink);

  /// 첫 구간 길이(꺾이는 점까지). 마킹 화면이 [markOffset]을 도로 빼므로
  /// 마킹은 정확히 [firstMark] 자리에 찍힌다.
  double firstLength(double startDistance, double angle, double geometricShrink) =>
      firstMark(startDistance, geometricShrink) + markOffset(angle);

  /// 튜브 계산기용. 마킹 화면과 같은 제원 한 벌([MachineSpecs])을 본다.
  static Future<BendSheetSpecs> tube() async {
    final prefs = await SharedPreferences.getInstance();
    final m = MachineSpecs();
    // 제원이 아직 안 읽혔으면 폰에 적힌 값을 쓴다.
    final double radius = m.radius > 0
        ? m.radius
        : (prefs.getDouble('bendRadius') ?? 0.0);
    final double gain90 = m.gain90 > 0
        ? m.gain90
        : (prefs.getDouble('gain') ?? 0.0);
    return BendSheetSpecs(
      radius: radius,
      gain90: gain90,
      minStraight: prefs.getDouble('minStraight') ?? 0.0,
      warnShoeInterference: prefs.getBool('warnShoeInterference') ?? true,
      extraShrink: prefs.getDouble('offsetShrink') ?? 0.0,
      addGeometricShrink: false,
      markOffset: (angle) => bendSetback(radius, angle),
      isConduit: false,
    );
  }

  /// 전선관 계산기용. 전선관 설정(globalBenderSettings)에서 만든다.
  factory BendSheetSpecs.conduit(Map<String, dynamic> settings) {
    final Map<String, dynamic> s = Map<String, dynamic>.from(settings);
    return BendSheetSpecs(
      radius: (s['clr'] as num?)?.toDouble() ?? 0.0,
      gain90: (s['gain'] as num?)?.toDouble() ?? 0.0,
      minStraight: 0.0,
      warnShoeInterference: false,
      extraShrink: 0.0,
      addGeometricShrink: s['applyShrink'] ?? true,
      markOffset: (angle) => conduitMarkOffset(angle, s),
      isConduit: true,
    );
  }
}
