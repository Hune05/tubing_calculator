import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BendDataManager {
  // 싱글톤 패턴 적용
  static final BendDataManager _instance = BendDataManager._internal();
  factory BendDataManager() => _instance;
  BendDataManager._internal();

  // 🔥 에러 해결 1: 타입을 CalculatorPage가 원하는 List<Map<String, double>>로 정확히 맞춤
  List<Map<String, double>> bendList = [];

  // ==========================================
  // 💡 메인 계산기 및 마킹 페이지에서 필요한 설정값
  // ==========================================

  String _pipeSize = '1/2"';
  String get pipeSize => _pipeSize;

  bool _startFit = false;
  bool get startFit => _startFit;
  // 🔥 에러 해결: setter 추가 및 값 변경 시 자동 저장
  set startFit(bool value) {
    _startFit = value;
    _saveCurrentState();
  }

  bool _endFit = false;
  bool get endFit => _endFit;
  // 🔥 에러 해결: setter 추가 및 값 변경 시 자동 저장
  set endFit(bool value) {
    _endFit = value;
    _saveCurrentState();
  }

  double _tail = 0.0;
  double get tail => _tail;
  // 🔥 에러 해결: setter 추가 및 값 변경 시 자동 저장
  set tail(double value) {
    _tail = value;
    _saveCurrentState();
  }

  double _fittingDepth = 0.0;
  double get fittingDepth => _fittingDepth;

  // 🔥 에러 해결 3: 마킹 계산에 필요한 Take-up과 Gain 추가!
  double _takeUp90 = 0.0;
  double get takeUp90 => _takeUp90;

  double _gain90 = 0.0;
  double get gain90 => _gain90;

  void updateSettings({
    String? pipeSize,
    bool? startFit,
    bool? endFit,
    double? tail,
    double? fittingDepth,
    double? takeUp90,
    double? gain90,
  }) {
    if (pipeSize != null) _pipeSize = pipeSize;
    if (startFit != null) _startFit = startFit;
    if (endFit != null) _endFit = endFit;
    if (tail != null) _tail = tail;
    if (fittingDepth != null) _fittingDepth = fittingDepth;
    if (takeUp90 != null) _takeUp90 = takeUp90;
    if (gain90 != null) _gain90 = gain90;
  }

  Future<void> loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 💡 1. 파이프 사이즈 동기화: SettingsManager가 저장한 OD와 단위(Inch/mm)를 조합해서 생성
    bool isInch = prefs.getBool('isInch') ?? false;
    double tubeOD = prefs.getDouble('tubeOD') ?? (isInch ? 0.5 : 12.7);
    _pipeSize = isInch ? '$tubeOD"' : '${tubeOD}mm';

    // 💡 2. 마킹 페이지 전용 변수 (단독 사용)
    _startFit = prefs.getBool('start_fit') ?? false;
    _endFit = prefs.getBool('end_fit') ?? false;
    _tail = prefs.getDouble('tail_length') ?? 0.0;

    // 🔥 3. 핵심 버그 해결: SettingsManager가 저장한 Key 이름과 완벽히 일치시킴!
    _fittingDepth = prefs.getDouble('fittingDepth') ?? 0.0;
    _takeUp90 = prefs.getDouble('takeUp') ?? 0.0;
    _gain90 = prefs.getDouble('gain') ?? 0.0;

    // 벤딩 리스트 복구
    final savedBends = prefs.getString('current_bend_list');
    if (savedBends != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(savedBends);
        bendList = decodedList.map((item) {
          final map = item as Map<String, dynamic>;
          return map.map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
          );
        }).toList();
      } catch (e) {
        bendList = [];
      }
    }
  }

  Future<void> _saveCurrentState() async {
    final prefs = await SharedPreferences.getInstance();

    // 벤딩 리스트 저장
    final jsonStr = jsonEncode(bendList);
    await prefs.setString('current_bend_list', jsonStr);

    // 마킹 페이지 상태 저장
    await prefs.setBool('start_fit', _startFit);
    await prefs.setBool('end_fit', _endFit);
    await prefs.setDouble('tail_length', _tail);

    // 🔥 SettingsManager 쪽 변수도 덮어쓸 경우를 대비해 Key 통일
    await prefs.setDouble('fittingDepth', _fittingDepth);
    await prefs.setDouble('takeUp', _takeUp90);
    await prefs.setDouble('gain', _gain90);
  }

  void addBend(double length, double angle, double rotation) {
    bendList.add({'length': length, 'angle': angle, 'rotation': rotation});
    _saveCurrentState();
  }

  void updateBend(int index, double length, double angle, double rotation) {
    if (index >= 0 && index < bendList.length) {
      bendList[index] = {
        'length': length,
        'angle': angle,
        'rotation': rotation,
      };
      _saveCurrentState();
    }
  }

  void clearBends() {
    bendList.clear();
    _saveCurrentState();
  }

  void removeBendAt(int index) {
    if (index >= 0 && index < bendList.length) {
      bendList.removeAt(index);
      _saveCurrentState();
    }
  }
}
