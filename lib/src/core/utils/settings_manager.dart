import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager {
  static Future<void> saveSettings({
    // 기본 설정
    required bool isInch,
    required bool useHaptic,
    required bool saveHistory,
    required String tubeMaterial,
    required String benderBrand,
    required String measurementMode,
    required String defaultRotation,
    required String fittingType,
    required String benderMark,
    required double tubeOD,
    required double tubeWT,

    // 상세 제원
    required double bendRadius,
    required double takeUp,
    required double springback,
    required double gain,
    required double minStraight,
    required double benderOffset,
    required double fittingDepth,
    required double markThickness,
    required double offsetShrink,
    required double cutMargin,

    // 💡 핵심: AUTO / MAN 상태 저장
    required bool autoRadius,
    required bool autoTakeUp,
    required bool autoGain,
    required bool autoMinStraight,
    required bool autoOffset,
    required bool autoFittingDepth,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 기본 설정 저장
    await prefs.setBool('isInch', isInch);
    await prefs.setBool('useHaptic', useHaptic);
    await prefs.setBool('saveHistory', saveHistory);
    await prefs.setString('tubeMaterial', tubeMaterial);
    await prefs.setString('benderBrand', benderBrand);
    await prefs.setString('measurementMode', measurementMode);
    await prefs.setString('defaultRotation', defaultRotation);
    await prefs.setString('fittingType', fittingType);
    await prefs.setString('benderMark', benderMark);

    // 수치 저장
    await prefs.setDouble('tubeOD', tubeOD);
    await prefs.setDouble('tubeWT', tubeWT);
    await prefs.setDouble('bendRadius', bendRadius);
    await prefs.setDouble('takeUp', takeUp);
    await prefs.setDouble('springback', springback);
    await prefs.setDouble('gain', gain);
    await prefs.setDouble('minStraight', minStraight);
    await prefs.setDouble('benderOffset', benderOffset);
    await prefs.setDouble('fittingDepth', fittingDepth);
    await prefs.setDouble('markThickness', markThickness);
    await prefs.setDouble('offsetShrink', offsetShrink);
    await prefs.setDouble('cutMargin', cutMargin);

    // AUTO 상태 저장
    await prefs.setBool('auto_radius', autoRadius);
    await prefs.setBool('auto_takeUp', autoTakeUp);
    await prefs.setBool('auto_gain', autoGain);
    await prefs.setBool('auto_minStraight', autoMinStraight);
    await prefs.setBool('auto_offset', autoOffset);
    await prefs.setBool('auto_fittingDepth', autoFittingDepth);
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'isInch': prefs.getBool('isInch'),
      'useHaptic': prefs.getBool('useHaptic'),
      'saveHistory': prefs.getBool('saveHistory'),
      'tubeMaterial': prefs.getString('tubeMaterial'),
      'benderBrand': prefs.getString('benderBrand'),
      'measurementMode': prefs.getString('measurementMode'),
      'defaultRotation': prefs.getString('defaultRotation'),
      'fittingType': prefs.getString('fittingType'),
      'benderMark': prefs.getString('benderMark'),

      'tubeOD': prefs.getDouble('tubeOD'),
      'tubeWT': prefs.getDouble('tubeWT'),
      'bendRadius': prefs.getDouble('bendRadius'),
      'takeUp': prefs.getDouble('takeUp'),
      'springback': prefs.getDouble('springback'),
      'gain': prefs.getDouble('gain'),
      'minStraight': prefs.getDouble('minStraight'),
      'benderOffset': prefs.getDouble('benderOffset'),
      'fittingDepth': prefs.getDouble('fittingDepth'),
      'markThickness': prefs.getDouble('markThickness'),
      'offsetShrink': prefs.getDouble('offsetShrink'),
      'cutMargin': prefs.getDouble('cutMargin'),

      'auto_radius': prefs.getBool('auto_radius'),
      'auto_takeUp': prefs.getBool('auto_takeUp'),
      'auto_gain': prefs.getBool('auto_gain'),
      'auto_minStraight': prefs.getBool('auto_minStraight'),
      'auto_offset': prefs.getBool('auto_offset'),
      'auto_fittingDepth': prefs.getBool('auto_fittingDepth'),
    };
  }
}
