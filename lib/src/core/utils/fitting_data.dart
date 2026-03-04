// 💡 신규 추가: 벤더 제원을 담을 데이터 클래스
class BenderSpec {
  final double bendRadius;
  final double takeUp;
  final double gain;
  final double minStraight;
  final double benderOffset;

  const BenderSpec({
    required this.bendRadius,
    required this.takeUp,
    required this.gain,
    required this.minStraight,
    required this.benderOffset,
  });
}

class FittingData {
  // ==========================================
  // 1. 피팅 삽입 깊이 (Insertion Depth) 데이터
  // ==========================================
  static final Map<String, Map<String, double>> _fittingData = {
    "Swagelok": _commonFittingData,
    "Hy-Lok": _commonFittingData, // 3사 호환 규격으로 데이터 동일 적용
    "Parker": _commonFittingData,
  };

  // 인치 및 미리 삽입 깊이 정밀 데이터 (mm)
  static final Map<String, double> _commonFittingData = {
    // Inch (분수 -> 소수점 변환값)
    "0.125": 12.7, // 1/8"
    "0.25": 15.2, // 1/4"
    "0.3125": 16.2, // 5/16"
    "0.375": 16.8, // 3/8"
    "0.5": 22.9, // 1/2"
    "0.625": 24.4, // 5/8"
    "0.75": 24.4, // 3/4"
    "0.875": 25.9, // 7/8"
    "1.0": 31.2, // 1"
    // Metric (mm)
    "3.0": 12.9,
    "4.0": 13.7,
    "6.0": 15.3,
    "8.0": 16.2,
    "10.0": 17.2,
    "12.0": 22.8,
    "14.0": 24.4,
    "15.0": 24.4,
    "16.0": 24.4,
    "18.0": 24.4,
    "20.0": 26.0,
    "22.0": 26.0,
    "25.0": 31.3,
  };

  static double getInsertionDepth(String brand, String od) {
    final brandData = _fittingData[brand] ?? _fittingData["Swagelok"]!;
    return brandData[od] ?? 0.0;
  }

  // ==========================================
  // 2. 벤더 장비 제원 (Bender Specs) 데이터
  // ==========================================
  static final Map<String, BenderSpec> _swagelokBenderData = {
    // [ Inch 규격 ]
    "0.125": const BenderSpec(
      bendRadius: 14.3,
      takeUp: 14.3,
      gain: 6.1,
      minStraight: 20.0,
      benderOffset: 0.0,
    ),
    "0.25": const BenderSpec(
      bendRadius: 14.3,
      takeUp: 14.3,
      gain: 6.1,
      minStraight: 20.0,
      benderOffset: 0.0,
    ),
    "0.3125": const BenderSpec(
      bendRadius: 23.8,
      takeUp: 23.8,
      gain: 10.2,
      minStraight: 25.0,
      benderOffset: 0.0,
    ),
    "0.375": const BenderSpec(
      bendRadius: 23.8,
      takeUp: 23.8,
      gain: 10.2,
      minStraight: 25.0,
      benderOffset: 0.0,
    ),
    "0.5": const BenderSpec(
      bendRadius: 38.1,
      takeUp: 38.1,
      gain: 20.0,
      minStraight: 30.0,
      benderOffset: 0.0,
    ),
    "0.625": const BenderSpec(
      bendRadius: 38.1,
      takeUp: 38.1,
      gain: 16.3,
      minStraight: 35.0,
      benderOffset: 0.0,
    ),
    "0.75": const BenderSpec(
      bendRadius: 57.2,
      takeUp: 57.2,
      gain: 24.5,
      minStraight: 45.0,
      benderOffset: 0.0,
    ),
    "0.875": const BenderSpec(
      bendRadius: 57.2,
      takeUp: 57.2,
      gain: 24.5,
      minStraight: 50.0,
      benderOffset: 0.0,
    ),
    "1.0": const BenderSpec(
      bendRadius: 76.2,
      takeUp: 76.2,
      gain: 32.6,
      minStraight: 60.0,
      benderOffset: 0.0,
    ),

    // [ Metric(mm) 규격 ]
    "3.0": const BenderSpec(
      bendRadius: 14.3,
      takeUp: 14.3,
      gain: 6.1,
      minStraight: 20.0,
      benderOffset: 0.0,
    ),
    "4.0": const BenderSpec(
      bendRadius: 14.3,
      takeUp: 14.3,
      gain: 6.1,
      minStraight: 20.0,
      benderOffset: 0.0,
    ),
    "6.0": const BenderSpec(
      bendRadius: 14.3,
      takeUp: 14.3,
      gain: 6.1,
      minStraight: 20.0,
      benderOffset: 0.0,
    ),
    "8.0": const BenderSpec(
      bendRadius: 23.8,
      takeUp: 23.8,
      gain: 10.2,
      minStraight: 25.0,
      benderOffset: 0.0,
    ),
    "10.0": const BenderSpec(
      bendRadius: 23.8,
      takeUp: 23.8,
      gain: 10.2,
      minStraight: 25.0,
      benderOffset: 0.0,
    ),
    "12.0": const BenderSpec(
      bendRadius: 38.1,
      takeUp: 38.1,
      gain: 20.0,
      minStraight: 30.0,
      benderOffset: 0.0,
    ),
    "14.0": const BenderSpec(
      bendRadius: 38.1,
      takeUp: 38.1,
      gain: 16.3,
      minStraight: 35.0,
      benderOffset: 0.0,
    ),
    "15.0": const BenderSpec(
      bendRadius: 38.1,
      takeUp: 38.1,
      gain: 16.3,
      minStraight: 35.0,
      benderOffset: 0.0,
    ),
    "16.0": const BenderSpec(
      bendRadius: 38.1,
      takeUp: 38.1,
      gain: 16.3,
      minStraight: 35.0,
      benderOffset: 0.0,
    ),
    "18.0": const BenderSpec(
      bendRadius: 57.2,
      takeUp: 57.2,
      gain: 24.5,
      minStraight: 45.0,
      benderOffset: 0.0,
    ),
    "20.0": const BenderSpec(
      bendRadius: 57.2,
      takeUp: 57.2,
      gain: 24.5,
      minStraight: 45.0,
      benderOffset: 0.0,
    ),
    "22.0": const BenderSpec(
      bendRadius: 57.2,
      takeUp: 57.2,
      gain: 24.5,
      minStraight: 50.0,
      benderOffset: 0.0,
    ),
    "25.0": const BenderSpec(
      bendRadius: 76.2,
      takeUp: 76.2,
      gain: 32.6,
      minStraight: 60.0,
      benderOffset: 0.0,
    ),
  };

  static BenderSpec? getBenderSpec(String brand, String od) {
    return _swagelokBenderData[od];
  }
}
