import 'package:flutter/material.dart';
import 'dart:convert'; // 🚀 JSON 변환을 위해 추가
import 'package:shared_preferences/shared_preferences.dart'; // 🚀 로컬 저장을 위해 추가

import 'electric_calculator_page.dart';
import 'electric_marking_page.dart';

class ElectricBendingWorkspace extends StatefulWidget {
  final String startDir;
  final double clr;
  final double minClampLength;
  final Function(double, List<Map<String, dynamic>>)? onSaveCallback;

  const ElectricBendingWorkspace({
    super.key,
    required this.startDir,
    required this.clr,
    required this.minClampLength,
    this.onSaveCallback,
  });

  @override
  State<ElectricBendingWorkspace> createState() =>
      _ElectricBendingWorkspaceState();
}

class _ElectricBendingWorkspaceState extends State<ElectricBendingWorkspace> {
  final PageController _pageController = PageController();

  // 🚀 양쪽 페이지가 공유하는 데이터 창고
  List<Map<String, double>> _sharedBendList = [];

  @override
  void initState() {
    super.initState();
    _loadElectricBendList(); // 🚀 앱이 켜지거나 워크스페이스가 열릴 때 마지막 작업 내역 불러오기
  }

  // 📂 디스크에서 리스트 불러오기 (초기 1회)
  Future<void> _loadElectricBendList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonString = prefs.getString('saved_electric_bend_list');

      if (jsonString != null && jsonString.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(jsonString);

        // JSON 데이터를 다시 List<Map<String, double>> 형태로 안전하게 복구
        List<Map<String, double>> loadedList = decoded.map((item) {
          return Map<String, double>.from(
            item.map(
              (key, value) =>
                  MapEntry(key.toString(), double.parse(value.toString())),
            ),
          );
        }).toList();

        // 위젯이 아직 화면에 살아있는지(mounted) 확인 후 상태 업데이트
        if (mounted) {
          setState(() {
            _sharedBendList = loadedList;
          });
        }
      }
    } catch (e) {
      debugPrint("전동 계산기 데이터 불러오기 실패: $e");
    }
  }

  // 💾 디스크에 리스트 저장하기 (데이터가 바뀔 때마다 실행)
  Future<void> _saveElectricBendList(List<Map<String, double>> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 리스트를 글자(JSON 문자열)로 압축해서 저장
      String jsonString = jsonEncode(list);
      await prefs.setString('saved_electric_bend_list', jsonString);
    } catch (e) {
      debugPrint("전동 계산기 데이터 저장 실패: $e");
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // slate100
      // 💡 공통 AppBar와 하단 TabBar 완전히 삭제! (각 페이지가 스스로 그림)
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(), // 부드러운 스와이프 복구
        children: [
          ElectricCalculatorPage(
            startDir: widget.startDir,
            clr: widget.clr,
            minClampLength: widget.minClampLength,
            bendList: _sharedBendList,
            onListChanged: (newList) {
              setState(() {
                _sharedBendList = newList; // 1. 화면 업데이트
              });
              _saveElectricBendList(newList); // 🚀 2. 값이 바뀔 때마다 즉시 백그라운드 자동 저장!
            },
          ),
          ElectricMarkingPage(
            startDir: widget.startDir,
            bendList: _sharedBendList,
            onSaveCallback: widget.onSaveCallback, // 🚀 프로젝트로 쏠 콜백 전달
          ),
        ],
      ),
    );
  }
}
