import 'package:flutter/material.dart';

import 'package:tubing_calculator/src/presentation/calculator/screens/marking_page.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/calculator_page.dart';
import 'package:tubing_calculator/src/data/bend_data_manager.dart';

// 💡 일관된 테마 컬러
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MainCalculatorScreen extends StatefulWidget {
  const MainCalculatorScreen({super.key});

  @override
  State<MainCalculatorScreen> createState() => _MainCalculatorScreenState();
}

class _MainCalculatorScreenState extends State<MainCalculatorScreen> {
  final BendDataManager _dataManager = BendDataManager();
  late PageController _pageController;
  bool _isLoading = true;
  int _currentIndex = 0; // 🚀 현재 페이지 인덱스를 추적하는 변수 추가!

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // 🚀 스와이프할 때마다 현재 페이지 번호를 감지하여 앱바 타이틀을 바꾸기 위한 리스너
    _pageController.addListener(() {
      if (_pageController.hasClients) {
        int next = _pageController.page?.round() ?? 0;
        if (_currentIndex != next) {
          setState(() {
            _currentIndex = next;
          });
        }
      }
    });

    _initSettings();
  }

  Future<void> _initSettings() async {
    await _dataManager.loadSavedSettings();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: slate100,
        body: Center(child: CircularProgressIndicator(color: makitaTeal)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        // 🚀 현재 페이지가 0이면 계산기, 1이면 마킹 가이드로 타이틀 자동 변경!
        title: Text(
          _currentIndex == 0 ? "BENDING WORKSPACE" : "MARKING GUIDE",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.0,
          ),
        ),
        backgroundColor: makitaTeal,
        foregroundColor: pureWhite,
        elevation: 0,
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          children: [
            CalculatorPage(
              pageController: _pageController,
              bendList: _dataManager.bendList
                  .map((e) => e.cast<String, double>())
                  .toList(),
              onAddBend: (l, a, r) =>
                  setState(() => _dataManager.addBend(l, a, r)),
              onUpdateBend: (i, l, a, r) =>
                  setState(() => _dataManager.updateBend(i, l, a, r)),

              // 🚀 [추가된 부분] 라인 삭제 배관 연결!
              onDeleteBend: (index) => setState(() {
                _dataManager.bendList.removeAt(index);
              }),

              onClear: () => setState(() => _dataManager.clearBends()),
              onReorderBend: (oldIndex, newIndex) {
                setState(() {
                  final item = _dataManager.bendList.removeAt(oldIndex);
                  _dataManager.bendList.insert(newIndex, item);
                });
              },
            ),
            MarkingPage(pageController: _pageController),
          ],
        ),
      ),
    );
  }
}
