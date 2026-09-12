import 'dart:convert';
import 'package:flutter/foundation.dart'; // 🚀 ChangeNotifier를 위해 추가
import 'package:shared_preferences/shared_preferences.dart';

class BendDataManager extends ChangeNotifier {
  // 🚀 ChangeNotifier 상속
  // 싱글톤 패턴 적용
  static final BendDataManager _instance = BendDataManager._internal();
  factory BendDataManager() => _instance;
  BendDataManager._internal();

  List<Map<String, double>> bendList = [];

  String _pipeSize = '1/2"';
  String get pipeSize => _pipeSize;

  bool _startFit = false;
  bool get startFit => _startFit;
  set startFit(bool value) {
    _startFit = value;
    _saveCurrentState();
    notifyListeners();
  }

  bool _endFit = false;
  bool get endFit => _endFit;
  set endFit(bool value) {
    _endFit = value;
    _saveCurrentState();
    notifyListeners();
  }

  double _tail = 0.0;
  double get tail => _tail;
  set tail(double value) {
    _tail = value;
    _saveCurrentState();
    notifyListeners();
  }

  double _fittingDepth = 0.0;
  double get fittingDepth => _fittingDepth;
  set fittingDepth(double value) {
    _fittingDepth = value;
    _saveCurrentState();
    notifyListeners();
  }

  double _takeUp90 = 0.0;
  double get takeUp90 => _takeUp90;
  set takeUp90(double value) {
    _takeUp90 = value;
    _saveCurrentState();
    notifyListeners();
  }

  double _gain90 = 0.0;
  double get gain90 => _gain90;
  set gain90(double value) {
    _gain90 = value;
    _saveCurrentState();
    notifyListeners();
  }

  // 🚀 [추가] 실제 벤드 반경. 예전엔 이 필드가 아예 없어서
  // MarkingPage가 반경 대신 takeUp90 값을 잘못 가져다 쓰고 있었다.
  double _radius = 0.0;
  double get radius => _radius;
  set radius(double value) {
    _radius = value;
    _saveCurrentState();
    notifyListeners();
  }

  // 🚀 [추가] MobileBendDataManager에는 있지만 여기엔 없던 필드들.
  // 지금 당장 MarkingPage가 쓰진 않지만, 나중에 데스크톱 쪽 설정 화면이
  // 이 값들을 다루게 되면 저장/로드가 가능하도록 같이 채워둔다.
  double _benderOffset = 0.0;
  double get benderOffset => _benderOffset;
  set benderOffset(double value) {
    _benderOffset = value;
    _saveCurrentState();
    notifyListeners();
  }

  double _springback = 0.0;
  double get springback => _springback;
  set springback(double value) {
    _springback = value;
    _saveCurrentState();
    notifyListeners();
  }

  void updateSettings({
    String? pipeSize,
    bool? startFit,
    bool? endFit,
    double? tail,
    double? fittingDepth,
    double? takeUp90,
    double? gain90,
    double? radius,
    double? benderOffset,
    double? springback,
  }) {
    if (pipeSize != null) _pipeSize = pipeSize;
    if (startFit != null) _startFit = startFit;
    if (endFit != null) _endFit = endFit;
    if (tail != null) _tail = tail;
    if (fittingDepth != null) _fittingDepth = fittingDepth;
    if (takeUp90 != null) _takeUp90 = takeUp90;
    if (gain90 != null) _gain90 = gain90;
    if (radius != null) _radius = radius;
    if (benderOffset != null) _benderOffset = benderOffset;
    if (springback != null) _springback = springback;

    // 🚀 [수정] 예전엔 여기서 저장 호출이 빠져 있어서, 이 함수로 바뀐 값이
    // 화면엔 바로 보이지만 앱을 재시작하면 사라지는 버그가 있었다.
    _saveCurrentState();
    notifyListeners(); // 🚀 UI 즉각 반영 (방송)
  }

  Future<void> loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();

    bool isInch = prefs.getBool('isInch') ?? false;
    double tubeOD = prefs.getDouble('tubeOD') ?? (isInch ? 0.5 : 12.7);
    _pipeSize = isInch ? '$tubeOD"' : '${tubeOD}mm';

    _startFit = prefs.getBool('start_fit') ?? false;
    _endFit = prefs.getBool('end_fit') ?? false;
    _tail = prefs.getDouble('tail_length') ?? 0.0;

    _fittingDepth = prefs.getDouble('fittingDepth') ?? 0.0;
    _takeUp90 = prefs.getDouble('takeUp') ?? 0.0;
    _gain90 = prefs.getDouble('gain') ?? 0.0;
    // 🚀 [추가] 예전엔 반경/오프셋/스프링백을 아예 불러오지 않았다.
    _radius = prefs.getDouble('bendRadius') ?? 0.0;
    _benderOffset = prefs.getDouble('benderOffset') ?? 0.0;
    _springback = prefs.getDouble('springback') ?? 0.0;

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

    notifyListeners(); // 🚀 로딩 끝난 후 화면 갱신 방송
  }

  // 🚀 [수정] notifyListeners()를 이 안에서 더 이상 부르지 않는다.
  // 예전엔 여기서만 불렀기 때문에, await 체인이 다 끝난 뒤에야(디스크 I/O
  // 완료 후) 알림이 갔다 - 세터를 호출한 시점과 리스너가 반응하는 시점 사이에
  // 지연이 생겼었다. 이제는 각 세터/메서드가 저장을 던져놓고 그 자리에서
  // 바로 notifyListeners()를 불러서 UI가 즉시 반응한다.
  Future<void> _saveCurrentState() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonStr = jsonEncode(bendList);
    await prefs.setString('current_bend_list', jsonStr);

    await prefs.setBool('start_fit', _startFit);
    await prefs.setBool('end_fit', _endFit);
    await prefs.setDouble('tail_length', _tail);

    await prefs.setDouble('fittingDepth', _fittingDepth);
    await prefs.setDouble('takeUp', _takeUp90);
    await prefs.setDouble('gain', _gain90);
    await prefs.setDouble('bendRadius', _radius);
    await prefs.setDouble('benderOffset', _benderOffset);
    await prefs.setDouble('springback', _springback);
  }

  void addBend(double length, double angle, double rotation) {
    bendList.add({'length': length, 'angle': angle, 'rotation': rotation});
    _saveCurrentState();
    notifyListeners();
  }

  // 🚀 화면 튀는 현상을 막기 위해 한 번에 묶어서(Batch) 추가하는 함수!
  void addMultipleBends(List<Map<String, double>> newBends) {
    bendList.addAll(newBends);
    _saveCurrentState();
    notifyListeners();
  }

  void updateBend(int index, double length, double angle, double rotation) {
    if (index >= 0 && index < bendList.length) {
      bendList[index] = {
        'length': length,
        'angle': angle,
        'rotation': rotation,
      };
      _saveCurrentState();
      notifyListeners();
    }
  }

  void clearBends() {
    bendList.clear();
    _saveCurrentState();
    notifyListeners();
  }

  void removeBendAt(int index) {
    if (index >= 0 && index < bendList.length) {
      bendList.removeAt(index);
      _saveCurrentState();
      notifyListeners();
    }
  }

  void reorderBend(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= bendList.length) return;

    final item = bendList.removeAt(oldIndex);
    // 🚀 [수정] 제거 후의 길이를 기준으로 clamp한다. 예전엔 제거 전 길이
    // 기준으로만 범위를 검사해서, 호출자가 Flutter ReorderableListView 특유의
    // "oldIndex<newIndex면 newIndex-1" 보정을 안 해주면 항목을 리스트 맨
    // 끝으로 옮길 때 RangeError가 났다.
    final clampedIndex = newIndex.clamp(0, bendList.length);
    bendList.insert(clampedIndex, item);
    _saveCurrentState();
    notifyListeners();
  }
}
