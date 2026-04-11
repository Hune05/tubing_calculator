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
  }

  bool _endFit = false;
  bool get endFit => _endFit;
  set endFit(bool value) {
    _endFit = value;
    _saveCurrentState();
  }

  double _tail = 0.0;
  double get tail => _tail;
  set tail(double value) {
    _tail = value;
    _saveCurrentState();
  }

  double _fittingDepth = 0.0;
  double get fittingDepth => _fittingDepth;

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

    notifyListeners(); // 🚀 데이터가 추가/수정/삭제되어 저장될 때마다 화면 갱신 방송!
  }

  void addBend(double length, double angle, double rotation) {
    bendList.add({'length': length, 'angle': angle, 'rotation': rotation});
    _saveCurrentState();
  }

  // 🚀 화면 튀는 현상을 막기 위해 한 번에 묶어서(Batch) 추가하는 함수!
  void addMultipleBends(List<Map<String, double>> newBends) {
    bendList.addAll(newBends);
    _saveCurrentState(); // 여기서 딱 한 번만 _saveCurrentState를 부르므로 렌더링 낭비 방지!
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

  void reorderBend(int oldIndex, int newIndex) {
    if (oldIndex >= 0 &&
        oldIndex < bendList.length &&
        newIndex >= 0 &&
        newIndex <= bendList.length) {
      final item = bendList.removeAt(oldIndex);
      bendList.insert(newIndex, item);
      _saveCurrentState();
    }
  }
}
