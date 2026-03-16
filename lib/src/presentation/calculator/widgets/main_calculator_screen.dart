// lib/src/presentation/calculator/widgets/main_calculator_screen.dart
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
  int _currentIndex = 0;

  // 🚀 [추가] 메인 화면에서 시작 방향 상태를 총괄 관리합니다!
  String _currentStartDir = 'RIGHT';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // 스와이프할 때마다 현재 페이지 번호를 감지하여 앱바 타이틀을 바꾸기 위한 리스너
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

              // 🚀 [해결] 여기서 계산기 쪽에 현재 방향과 변경 콜백을 넘겨줍니다!
              startDir: _currentStartDir,
              onStartDirChanged: (newDir) {
                setState(() {
                  _currentStartDir = newDir;
                });
              },

              onAddBend: (l, a, r) =>
                  setState(() => _dataManager.addBend(l, a, r)),
              onUpdateBend: (i, l, a, r) =>
                  setState(() => _dataManager.updateBend(i, l, a, r)),
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

            // 🚀 [중요] 마킹 페이지로 넘어갈 때(저장 화면) 최종 시작 방향을 함께 넘겨줍니다!
            MarkingPage(
              pageController: _pageController,
              startDir: _currentStartDir, // <-- 마킹 페이지가 이걸 받아서 DB에 저장하게 됨
            ),
          ],
        ),
      ),
    );
  }
}
