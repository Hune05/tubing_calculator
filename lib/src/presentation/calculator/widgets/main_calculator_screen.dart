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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
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
        title: const Text(
          "BENDING WORKSPACE",
          style: TextStyle(
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
              onClear: () => setState(() => _dataManager.clearBends()),
              // 🔥 에러 해결: 부모 위젯에서 순서 변경 로직 주입!
              onReorderBend: (oldIndex, newIndex) {
                setState(() {
                  // 기존 항목을 빼서 새 위치에 끼워 넣음
                  final item = _dataManager.bendList.removeAt(oldIndex);
                  _dataManager.bendList.insert(newIndex, item);
                });
                // (선택) 만약 BendDataManager에 저장 기능이 있다면 여기서 호출해서 바뀐 순서를 저장해 주세요.
                // _dataManager.saveSettings();
              },
            ),
            MarkingPage(pageController: _pageController),
          ],
        ),
      ),
    );
  }
}
