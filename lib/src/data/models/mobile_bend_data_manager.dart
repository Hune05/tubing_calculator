import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MobileBendDataManager extends ChangeNotifier {
  static final MobileBendDataManager _instance =
      MobileBendDataManager._internal();
  factory MobileBendDataManager() => _instance;
  MobileBendDataManager._internal();

  List<Map<String, dynamic>> bendList = [];

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

  // 🚀 핵심 제원들
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

  double _radius = 0.0;
  double get radius => _radius;
  set radius(double value) {
    _radius = value;
    _saveCurrentState();
    notifyListeners();
  }

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

  // ===============================================
  // 새들(Saddle) & 오프셋(Offset) 마지막 입력값 기억 변수
  // ===============================================
  double _saddleHeight = 100.0;
  double get saddleHeight => _saddleHeight;
  set saddleHeight(double value) {
    _saddleHeight = value;
    _saveCurrentState();
  }

  double _saddleWidth = 200.0;
  double get saddleWidth => _saddleWidth;
  set saddleWidth(double value) {
    _saddleWidth = value;
    _saveCurrentState();
  }

  double _saddleAngle3Pt = 45.0;
  double get saddleAngle3Pt => _saddleAngle3Pt;
  set saddleAngle3Pt(double value) {
    _saddleAngle3Pt = value;
    _saveCurrentState();
  }

  double _saddleAngle4Pt = 30.0;
  double get saddleAngle4Pt => _saddleAngle4Pt;
  set saddleAngle4Pt(double value) {
    _saddleAngle4Pt = value;
    _saveCurrentState();
  }

  double _offsetHeight = 100.0;
  double get offsetHeight => _offsetHeight;
  set offsetHeight(double value) {
    _offsetHeight = value;
    _saveCurrentState();
  }

  double _offsetAngle = 45.0;
  double get offsetAngle => _offsetAngle;
  set offsetAngle(double value) {
    _offsetAngle = value;
    _saveCurrentState();
  }

  double _offsetTravel = 150.0;
  double get offsetTravel => _offsetTravel;
  set offsetTravel(double value) {
    _offsetTravel = value;
    _saveCurrentState();
  }

  // ===============================================
  // 🚀 [추가됨] 설정 탭 진입 시 렉 걸림 방지용 일괄 업데이트 함수
  // ===============================================
  void updateMachineSpecs({
    double? takeUp90,
    double? fittingDepth,
    double? gain90,
    double? radius,
    double? benderOffset,
    double? springback,
  }) {
    if (takeUp90 != null) _takeUp90 = takeUp90;
    if (fittingDepth != null) _fittingDepth = fittingDepth;
    if (gain90 != null) _gain90 = gain90;
    if (radius != null) _radius = radius;
    if (benderOffset != null) _benderOffset = benderOffset;
    if (springback != null) _springback = springback;

    // 변수를 한 번에 다 바꾼 후, 마지막에 딱 1번만 저장 및 화면 갱신
    _saveCurrentState();
    notifyListeners();
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
    _radius = prefs.getDouble('bendRadius') ?? 0.0;
    _benderOffset = prefs.getDouble('benderOffset') ?? 0.0;
    _springback = prefs.getDouble('springback') ?? 0.0;

    _saddleHeight = prefs.getDouble('saddleHeight') ?? 100.0;
    _saddleWidth = prefs.getDouble('saddleWidth') ?? 200.0;
    _saddleAngle3Pt = prefs.getDouble('saddleAngle3Pt') ?? 45.0;
    _saddleAngle4Pt = prefs.getDouble('saddleAngle4Pt') ?? 30.0;
    _offsetHeight = prefs.getDouble('offsetHeight') ?? 100.0;
    _offsetAngle = prefs.getDouble('offsetAngle') ?? 45.0;
    _offsetTravel = prefs.getDouble('offsetTravel') ?? 150.0;

    final savedBends =
        prefs.getString('mobile_current_bend_list') ??
        prefs.getString('current_bend_list');
    if (savedBends != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(savedBends);
        bendList = decodedList.map((item) {
          final map = item as Map<String, dynamic>;
          return map.map(
            (key, value) =>
                MapEntry(key, value is num ? value.toDouble() : value),
          );
        }).toList();
      } catch (e) {
        bendList = [];
      }
    }
    notifyListeners();
  }

  Future<void> _saveCurrentState() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(bendList);

    await prefs.setString('mobile_current_bend_list', jsonStr);
    await prefs.setBool('start_fit', _startFit);
    await prefs.setBool('end_fit', _endFit);
    await prefs.setDouble('tail_length', _tail);

    // 이 값들은 SettingsManager를 통해 저장되지만, 즉각적인 캐싱을 위해 남겨둠
    await prefs.setDouble('fittingDepth', _fittingDepth);
    await prefs.setDouble('takeUp', _takeUp90);
    await prefs.setDouble('gain', _gain90);
    await prefs.setDouble('bendRadius', _radius);
    await prefs.setDouble('benderOffset', _benderOffset);
    await prefs.setDouble('springback', _springback);

    await prefs.setDouble('saddleHeight', _saddleHeight);
    await prefs.setDouble('saddleWidth', _saddleWidth);
    await prefs.setDouble('saddleAngle3Pt', _saddleAngle3Pt);
    await prefs.setDouble('saddleAngle4Pt', _saddleAngle4Pt);
    await prefs.setDouble('offsetHeight', _offsetHeight);
    await prefs.setDouble('offsetAngle', _offsetAngle);
    await prefs.setDouble('offsetTravel', _offsetTravel);
  }

  void addBend(Map<String, dynamic> bend) {
    bendList.add(Map<String, dynamic>.from(bend));
    _saveCurrentState();
    notifyListeners();
  }

  void addMultipleBends(List<Map<String, dynamic>> newBends) {
    bendList.addAll(newBends.map((e) => Map<String, dynamic>.from(e)));
    _saveCurrentState();
    notifyListeners();
  }

  void updateBend(int index, Map<String, dynamic> bend) {
    if (index >= 0 && index < bendList.length) {
      bendList[index] = Map<String, dynamic>.from(bend);
      _saveCurrentState();
      notifyListeners();
    }
  }

  void clearBends() {
    bendList.clear();
    _saveCurrentState();
    notifyListeners();
  }

  void removeBend(int index) {
    if (index >= 0 && index < bendList.length) {
      bendList.removeAt(index);
      _saveCurrentState();
      notifyListeners();
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
      notifyListeners();
    }
  }
}
