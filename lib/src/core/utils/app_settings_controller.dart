import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'settings_manager.dart';

/// 🚀 [신규] 앱 전역에서 공유하는 단일 설정 저장소.
///
/// 예전에는 MobileInputTab / MobileSettingsTab / CalculatorPage(데스크톱)가
/// 각자 SettingsManager.loadSettings()와 SharedPreferences를 독립적으로 불러서
/// 로컬 캐시로 들고 있었다. 그래서:
///  - 입력 탭이 build()마다 설정을 재로딩하며 무한 리빌드에 빠지는 버그
///  - 설정 탭에서 값을 바꿔도 이미 열려 있는 다른 탭(입력 탭, 결과 탭)이
///    그 변경을 반영하지 못하는 동기화 버그
///  - 데스크톱 계산기 화면이 "화면 꺼짐 방지" 사용자 설정을 무시하고
///    항상 wakelock을 켜버리는 불일치
/// 가 반복적으로 발생했다.
///
/// 이 컨트롤러 하나로 로드/저장을 통합하고 ChangeNotifier로 만들어서,
/// 값이 바뀌면 구독 중인 모든 화면이 자동으로 최신 상태를 반영하게 한다.
/// (MobileBendDataManager가 벤드 리스트에 대해 하는 역할을, 설정값에 대해
///  똑같이 해주는 클래스라고 보면 된다.)
class AppSettingsController extends ChangeNotifier {
  AppSettingsController._internal();
  static final AppSettingsController _instance =
      AppSettingsController._internal();
  factory AppSettingsController() => _instance;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;
  Future<void>? _loadingFuture;

  // ------------------------------
  // 기본 설정
  // ------------------------------
  bool isInch = false;
  bool useHaptic = true;
  bool saveHistory = true;
  String tubeMaterial = "SUS";
  String benderBrand = "Swagelok";
  String measurementMode = "C-to-C";
  String defaultRotation = "CW (시계방향)";
  String fittingType = "Twin Ferrule";
  String benderMark = "0 (기본/다양한 각도)";
  String benderType = "수동 (Hand)";

  // ------------------------------
  // 치수/제원
  // ------------------------------
  double tubeOD = 12.7;
  double tubeWT = 0.0;
  double bendRadius = 0.0;
  double takeUp = 0.0;
  double springback = 0.0;
  double gain = 0.0;
  // 🚀 예전엔 CalculatorPage는 기본값 50.0, MobileInputTab은 기본값 0.0으로
  // 서로 달랐다(0.0이면 간섭 경고 자체가 사실상 무력화됨). 더 안전한 쪽인
  // 50.0을 공통 기본값으로 통일한다.
  double minStraight = 50.0;
  double benderOffset = 0.0;
  double fittingDepth = 0.0;
  double markThickness = 0.0;
  double offsetShrink = 0.0;
  double cutMargin = 0.0;

  // ------------------------------
  // AUTO/MAN 상태
  // ------------------------------
  bool autoRadius = true;
  bool autoTakeUp = true;
  bool autoGain = true;
  bool autoMinStraight = true;
  bool autoOffset = true;
  bool autoFittingDepth = true;

  // ------------------------------
  // 앱 동작 관련
  // ------------------------------
  bool keepScreenOn = false;
  bool warnShoeInterference = true;

  bool get isElectric => benderType == "전동 (Electric)";

  /// 이미 로드되어 있으면 아무 것도 하지 않고, 아니면 한 번만 로드한다.
  /// 여러 화면이 동시에 initState에서 호출해도 실제 로딩은 한 번만 일어난다.
  Future<void> ensureLoaded() {
    if (_isLoaded) return Future.value();
    return _loadingFuture ??= load();
  }

  Future<void> load() async {
    final data = await SettingsManager.loadSettings();

    isInch = data['isInch'] ?? false;
    useHaptic = data['useHaptic'] ?? true;
    saveHistory = data['saveHistory'] ?? true;
    tubeMaterial = data['tubeMaterial'] ?? "SUS";
    benderBrand = data['benderBrand'] ?? "Swagelok";
    measurementMode = data['measurementMode'] ?? "C-to-C";
    defaultRotation = data['defaultRotation'] ?? "CW (시계방향)";
    fittingType = data['fittingType'] ?? "Twin Ferrule";
    benderMark = data['benderMark'] ?? "0 (기본/다양한 각도)";
    benderType = data['benderType'] ?? "수동 (Hand)";

    tubeOD = data['tubeOD'] ?? (isInch ? 0.5 : 12.7);
    tubeWT = data['tubeWT'] ?? 0.0;
    bendRadius = data['bendRadius'] ?? 0.0;
    takeUp = data['takeUp'] ?? 0.0;
    springback = data['springback'] ?? 0.0;
    gain = data['gain'] ?? 0.0;
    minStraight = data['minStraight'] ?? 50.0;
    benderOffset = data['benderOffset'] ?? 0.0;
    fittingDepth = data['fittingDepth'] ?? 0.0;
    markThickness = data['markThickness'] ?? 0.0;
    offsetShrink = data['offsetShrink'] ?? 0.0;
    cutMargin = data['cutMargin'] ?? 0.0;

    autoRadius = data['auto_radius'] ?? true;
    autoTakeUp = data['auto_takeUp'] ?? true;
    autoGain = data['auto_gain'] ?? true;
    autoMinStraight = data['auto_minStraight'] ?? true;
    autoOffset = data['auto_offset'] ?? true;
    autoFittingDepth = data['auto_fittingDepth'] ?? true;

    keepScreenOn = data['keepScreenOn'] ?? false;
    warnShoeInterference = data['warnShoeInterference'] ?? true;

    _isLoaded = true;
    _loadingFuture = null;
    _applyWakelock();
    notifyListeners();
  }

  /// 설정 탭에서 "저장" 버튼을 눌렀을 때 호출. 컨트롤러의 현재 필드값들을
  /// 그대로 영속 저장소(SettingsManager)에 기록하고, 구독자들에게 알린다.
  Future<void> save() async {
    await SettingsManager.saveSettings(
      isInch: isInch,
      useHaptic: useHaptic,
      saveHistory: saveHistory,
      tubeMaterial: tubeMaterial,
      benderBrand: benderBrand,
      measurementMode: measurementMode,
      defaultRotation: defaultRotation,
      fittingType: fittingType,
      benderMark: benderMark,
      benderType: benderType,
      tubeOD: tubeOD,
      tubeWT: tubeWT,
      bendRadius: bendRadius,
      takeUp: takeUp,
      springback: springback,
      gain: gain,
      minStraight: minStraight,
      benderOffset: benderOffset,
      fittingDepth: fittingDepth,
      markThickness: markThickness,
      offsetShrink: offsetShrink,
      cutMargin: cutMargin,
      autoRadius: autoRadius,
      autoTakeUp: autoTakeUp,
      autoGain: autoGain,
      autoMinStraight: autoMinStraight,
      autoOffset: autoOffset,
      autoFittingDepth: autoFittingDepth,
      keepScreenOn: keepScreenOn,
      warnShoeInterference: warnShoeInterference,
    );
    _applyWakelock();
    notifyListeners();
  }

  /// 🚀 [수정] "화면 꺼짐 방지" 스위치는 예전처럼 토글 즉시 적용되지만,
  /// 이제 이 한 곳에서만 wakelock을 건드린다. CalculatorPage 등 다른 화면은
  /// 더 이상 자기 마음대로 WakelockPlus.enable()을 부르지 않는다 - 그래서
  /// "설정에서 껐는데 계산기 화면 들어가면 다시 켜지는" 불일치가 사라진다.
  Future<void> setKeepScreenOn(bool value) async {
    keepScreenOn = value;
    _applyWakelock();
    await SettingsManager.saveSettings(
      isInch: isInch,
      useHaptic: useHaptic,
      saveHistory: saveHistory,
      tubeMaterial: tubeMaterial,
      benderBrand: benderBrand,
      measurementMode: measurementMode,
      defaultRotation: defaultRotation,
      fittingType: fittingType,
      benderMark: benderMark,
      benderType: benderType,
      tubeOD: tubeOD,
      tubeWT: tubeWT,
      bendRadius: bendRadius,
      takeUp: takeUp,
      springback: springback,
      gain: gain,
      minStraight: minStraight,
      benderOffset: benderOffset,
      fittingDepth: fittingDepth,
      markThickness: markThickness,
      offsetShrink: offsetShrink,
      cutMargin: cutMargin,
      autoRadius: autoRadius,
      autoTakeUp: autoTakeUp,
      autoGain: autoGain,
      autoMinStraight: autoMinStraight,
      autoOffset: autoOffset,
      autoFittingDepth: autoFittingDepth,
      keepScreenOn: keepScreenOn,
      warnShoeInterference: warnShoeInterference,
    );
    notifyListeners();
  }

  void _applyWakelock() {
    if (keepScreenOn) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }
}
