import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/bend_list_history.dart';

/// 폰 화면이 쓰는 벤드 목록 보관함.
/// 제원(반경·게인·테이크업 등)은 [MachineSpecs] 한 벌을 태블릿·PC 화면과
/// 같이 본다 — 예전에는 따로 들고 있어서 한쪽에서 고친 제원이 다른 쪽
/// 마킹에 반영되지 않았다.
class MobileBendDataManager extends ChangeNotifier with BendListHistory {
  static final MobileBendDataManager _instance =
      MobileBendDataManager._internal();
  factory MobileBendDataManager() => _instance;
  MobileBendDataManager._internal() {
    _specs.addListener(notifyListeners);
  }

  final MachineSpecs _specs = MachineSpecs();

  List<Map<String, dynamic>> bendList = [];

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
  double get cutMargin => _specs.cutMargin;
  set cutMargin(double value) => _specs.cutMargin = value;

  // ===============================================
  // 새들(Saddle) & 오프셋(Offset) 마지막 입력값 기억 변수
  // ===============================================
  // 🚀 [수정] 아래 7개 세터에 notifyListeners() 호출이 빠져 있었다.
  // 다른 세터들은 전부 _saveCurrentState()와 notifyListeners()를 같이
  // 부르는데, 이것들만 저장만 하고 구독자에게 알리지 않아서 이 값들을
  // 실시간으로 구독하는 화면이 있다면 갱신이 안 되는 비대칭이 있었다.
  double _saddleHeight = 100.0;
  double get saddleHeight => _saddleHeight;
  set saddleHeight(double value) {
    _saddleHeight = value;
    _saveCurrentState();
    notifyListeners();
  }

  double _saddleWidth = 200.0;
  double get saddleWidth => _saddleWidth;
  set saddleWidth(double value) {
    _saddleWidth = value;
    _saveCurrentState();
    notifyListeners();
  }

  double _saddleAngle3Pt = 45.0;
  double get saddleAngle3Pt => _saddleAngle3Pt;
  set saddleAngle3Pt(double value) {
    _saddleAngle3Pt = value;
    _saveCurrentState();
    notifyListeners();
  }

  double _saddleAngle4Pt = 30.0;
  double get saddleAngle4Pt => _saddleAngle4Pt;
  set saddleAngle4Pt(double value) {
    _saddleAngle4Pt = value;
    _saveCurrentState();
    notifyListeners();
  }

  double _offsetHeight = 100.0;
  double get offsetHeight => _offsetHeight;
  set offsetHeight(double value) {
    _offsetHeight = value;
    _saveCurrentState();
    notifyListeners();
  }

  double _offsetAngle = 45.0;
  double get offsetAngle => _offsetAngle;
  set offsetAngle(double value) {
    _offsetAngle = value;
    _saveCurrentState();
    notifyListeners();
  }

  double _offsetTravel = 150.0;
  double get offsetTravel => _offsetTravel;
  set offsetTravel(double value) {
    _offsetTravel = value;
    _saveCurrentState();
    notifyListeners();
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
    double? cutMargin,
  }) {
    _specs.update(
      takeUp90: takeUp90,
      fittingDepth: fittingDepth,
      gain90: gain90,
      radius: radius,
      benderOffset: benderOffset,
      springback: springback,
      cutMargin: cutMargin,
    );
  }

  Future<void> loadSavedSettings() async {
    await _specs.load();
    final prefs = await SharedPreferences.getInstance();

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

    await prefs.setDouble('saddleHeight', _saddleHeight);
    await prefs.setDouble('saddleWidth', _saddleWidth);
    await prefs.setDouble('saddleAngle3Pt', _saddleAngle3Pt);
    await prefs.setDouble('saddleAngle4Pt', _saddleAngle4Pt);
    await prefs.setDouble('offsetHeight', _offsetHeight);
    await prefs.setDouble('offsetAngle', _offsetAngle);
    await prefs.setDouble('offsetTravel', _offsetTravel);
  }

  @override
  List<Map<String, dynamic>> get historyTarget => bendList;
  @override
  set historyTarget(List<Map<String, dynamic>> v) => bendList = v;
  @override
  void persistHistoryTarget() => _saveCurrentState();

  void addBend(Map<String, dynamic> bend) {
    recordHistory();
    bendList.add(Map<String, dynamic>.from(bend));
    _saveCurrentState();
    notifyListeners();
  }

  void addMultipleBends(List<Map<String, dynamic>> newBends) {
    recordHistory();
    bendList.addAll(newBends.map((e) => Map<String, dynamic>.from(e)));
    _saveCurrentState();
    notifyListeners();
  }

  void updateBend(int index, Map<String, dynamic> bend) {
    if (index >= 0 && index < bendList.length) {
      recordHistory();
      bendList[index] = Map<String, dynamic>.from(bend);
      _saveCurrentState();
      notifyListeners();
    }
  }

  /// 지운 줄을 되돌릴 때 원래 자리에 다시 넣는다.
  void insertBend(int index, Map<String, dynamic> bend) {
    recordHistory();
    final at = index.clamp(0, bendList.length);
    bendList.insert(at, Map<String, dynamic>.from(bend));
    _saveCurrentState();
    notifyListeners();
  }

  /// 보관함에서 불러온 목록으로 통째로 바꾼다(↶로 되돌릴 수 있다).
  void replaceAll(List<Map<String, dynamic>> bends) {
    recordHistory();
    bendList = [for (final b in bends) Map<String, dynamic>.from(b)];
    _saveCurrentState();
    notifyListeners();
  }

  void clearBends() {
    if (bendList.isEmpty) return;
    recordHistory();
    bendList.clear();
    _saveCurrentState();
    notifyListeners();
  }

  void removeBend(int index) {
    if (index >= 0 && index < bendList.length) {
      recordHistory();
      bendList.removeAt(index);
      _saveCurrentState();
      notifyListeners();
    }
  }

  void reorderBend(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= bendList.length) return;

    recordHistory();
    final item = bendList.removeAt(oldIndex);
    // 🚀 [수정] 제거 후 길이를 기준으로 clamp - 호출자가 Flutter의
    // ReorderableListView 특유의 "oldIndex<newIndex면 newIndex-1" 보정을
    // 안 해줘도 마지막 위치로 옮길 때 RangeError가 나지 않는다.
    final clampedIndex = newIndex.clamp(0, bendList.length);
    bendList.insert(clampedIndex, item);
    _saveCurrentState();
    notifyListeners();
  }
}
