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

    // 모바일 전용 저장소 키 탐색
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
    await prefs.setDouble('fittingDepth', _fittingDepth);
    await prefs.setDouble('takeUp', _takeUp90);
    await prefs.setDouble('gain', _gain90);
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
