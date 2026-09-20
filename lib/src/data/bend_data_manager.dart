import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';

/// 태블릿·PC 화면이 쓰는 벤드 목록 보관함.
/// 제원(반경·게인·테이크업 등)은 [MachineSpecs] 한 벌을 같이 본다 —
/// 예전에는 폰 화면과 따로 들고 있어서, 폰에서 고친 제원이 여기 마킹에
/// 반영되지 않았다.
class BendDataManager extends ChangeNotifier {
  static final BendDataManager _instance = BendDataManager._internal();
  factory BendDataManager() => _instance;
  BendDataManager._internal() {
    _specs.addListener(notifyListeners);
  }

  final MachineSpecs _specs = MachineSpecs();

  List<Map<String, double>> bendList = [];

  String get pipeSize => _specs.pipeSize;

  bool get startFit => _specs.startFit;
  set startFit(bool value) => _specs.startFit = value;

  bool get endFit => _specs.endFit;
  set endFit(bool value) => _specs.endFit = value;

  double get tail => _specs.tail;
  set tail(double value) => _specs.tail = value;

  double get fittingDepth => _specs.fittingDepth;
  set fittingDepth(double value) => _specs.fittingDepth = value;

  double get takeUp90 => _specs.takeUp90;
  set takeUp90(double value) => _specs.takeUp90 = value;

  double get gain90 => _specs.gain90;
  set gain90(double value) => _specs.gain90 = value;

  double get radius => _specs.radius;
  set radius(double value) => _specs.radius = value;

  double get benderOffset => _specs.benderOffset;
  set benderOffset(double value) => _specs.benderOffset = value;

  double get springback => _specs.springback;
  set springback(double value) => _specs.springback = value;

  // 톱날 손실(커프). 자를 때 톱날이 먹는 두께.
  // 🚀 [고침] 폰 화면에는 있는데 태블릿·PC 쪽에는 칸이 없어서, 자를 길이에
  // 톱날 두께가 빠진 채로 나왔다.
  double get cutMargin => _specs.cutMargin;
  set cutMargin(double value) => _specs.cutMargin = value;

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
    _specs.update(
      pipeSize: pipeSize,
      startFit: startFit,
      endFit: endFit,
      tail: tail,
      fittingDepth: fittingDepth,
      takeUp90: takeUp90,
      gain90: gain90,
      radius: radius,
      benderOffset: benderOffset,
      springback: springback,
    );
  }

  Future<void> loadSavedSettings() async {
    await _specs.load();

    final prefs = await SharedPreferences.getInstance();
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

    notifyListeners();
  }

  Future<void> _saveCurrentState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_bend_list', jsonEncode(bendList));
    } catch (_) {}
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
