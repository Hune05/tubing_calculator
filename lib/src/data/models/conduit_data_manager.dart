import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConduitDataManager extends ChangeNotifier {
  // 1. 싱글톤 패턴: 전선관 탭 전역에서 단 하나의 인스턴스만 사용
  static final ConduitDataManager _instance = ConduitDataManager._internal();

  factory ConduitDataManager() {
    return _instance;
  }

  ConduitDataManager._internal() {
    // 최초 생성 시 로컬 스토리지에서 전선관 데이터를 불러옵니다.
    _loadData();
  }

  List<Map<String, dynamic>> bendList = [];

  // --- 상태 업데이트 및 로컬 저장 공통 메서드 ---
  void _updateAndSave() {
    notifyListeners(); // UI 갱신
    _saveData(); // 기기에 즉시 저장
  }

  // --- 기존 기능들 ---
  void addBend(Map<String, dynamic> bend) {
    bendList.add(bend);
    _updateAndSave();
  }

  void addMultipleBends(List<Map<String, dynamic>> bends) {
    bendList.addAll(bends);
    _updateAndSave();
  }

  void removeBend(int index) {
    bendList.removeAt(index);
    _updateAndSave();
  }

  void clearBends() {
    bendList.clear();
    _updateAndSave();
  }

  // 드래그 앤 드롭으로 순서를 변경할 때 저장하기 위한 로직
  void reorderBends(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = bendList.removeAt(oldIndex);
    bendList.insert(newIndex, item);
    _updateAndSave();
  }

  // --- 로컬 스토리지(SharedPreferences) 로직 ---
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    String jsonString = jsonEncode(bendList);
    // 다른 배관 데이터와 겹치지 않게 고유 키값 사용
    await prefs.setString('conduit_saved_bend_list', jsonString);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('conduit_saved_bend_list');

    if (jsonString != null) {
      List<dynamic> decodedList = jsonDecode(jsonString);
      bendList = decodedList.map((e) => Map<String, dynamic>.from(e)).toList();
      notifyListeners(); // 데이터를 다 불러오면 화면을 새로고침
    }
  }
}
