class BenderSpecs {
  final double bendRadius;
  final double takeUp;
  final double gain;
  final double minStraight;
  final double benderOffset;
  final double fittingDepth;

  BenderSpecs({
    required this.bendRadius,
    required this.takeUp,
    required this.gain,
    required this.minStraight,
    required this.benderOffset,
    required this.fittingDepth,
  });
}

class BenderDatabase {
  static final Map<String, Map<String, BenderSpecs>> data = {
    "Swagelok": {
      "0.25": BenderSpecs(
        bendRadius: 14.2,
        takeUp: 12.7,
        gain: 1.5,
        minStraight: 20.0,
        benderOffset: 0.0,
        fittingDepth: 12.0,
      ),
      "0.375": BenderSpecs(
        bendRadius: 23.8,
        takeUp: 31.7,
        gain: 2.5,
        minStraight: 25.0,
        benderOffset: 0.0,
        fittingDepth: 15.0,
      ),
      "0.5": BenderSpecs(
        bendRadius: 38.1,
        takeUp: 38.1,
        gain: 4.0,
        minStraight: 30.0,
        benderOffset: 0.0,
        fittingDepth: 17.5,
      ),
      "6.0": BenderSpecs(
        bendRadius: 15.0,
        takeUp: 13.0,
        gain: 1.5,
        minStraight: 20.0,
        benderOffset: 0.0,
        fittingDepth: 12.0,
      ),
      "10.0": BenderSpecs(
        bendRadius: 24.0,
        takeUp: 26.0,
        gain: 2.5,
        minStraight: 25.0,
        benderOffset: 0.0,
        fittingDepth: 15.0,
      ),
      "12.0": BenderSpecs(
        bendRadius: 38.0,
        takeUp: 38.0,
        gain: 4.0,
        minStraight: 30.0,
        benderOffset: 0.0,
        fittingDepth: 17.5,
      ),
    },
    "Ridgid": {
      "0.5": BenderSpecs(
        bendRadius: 38.1,
        takeUp: 36.5,
        gain: 4.1,
        minStraight: 32.0,
        benderOffset: 1.5,
        fittingDepth: 17.5,
      ),
      "12.0": BenderSpecs(
        bendRadius: 38.0,
        takeUp: 36.5,
        gain: 4.1,
        minStraight: 32.0,
        benderOffset: 1.5,
        fittingDepth: 17.5,
      ),
    },
  };

  static BenderSpecs? getSpecs(String brand, String od) {
    return data[brand]?[od];
  }
}
