import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_header.dart';

import 'package:tubing_calculator/src/presentation/calculator/screens/marking_page.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/calculator_page.dart';
import 'package:tubing_calculator/src/data/bend_data_manager.dart';

const Color makitaTeal = AppColors.brand;
const Color slate900 = AppColors.text;
const Color slate100 = AppColors.background;
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

  String _currentStartDir = 'RIGHT';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

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
        title: AppHeaderTitle(_currentIndex == 0 ? "벤딩 작업" : "마킹 가이드"),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: AppColors.line)),
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

              startDir: _currentStartDir,
              onStartDirChanged: (newDir) {
                setState(() {
                  _currentStartDir = newDir;
                });
              },

              onAddBend: (l, a, r) =>
                  setState(() => _dataManager.addBend(l, a, r)),

              // 🚀 [핵심 연결] 아이소 튀는 걸 막기 위한 다중 삽입 콜백!
              onAddMultipleBends: (bends) =>
                  setState(() => _dataManager.addMultipleBends(bends)),

              onUpdateBend: (i, l, a, r) =>
                  setState(() => _dataManager.updateBend(i, l, a, r)),

              onDeleteBend: (index) => setState(() {
                _dataManager.removeBendAt(index);
              }),
              onClear: () => setState(() => _dataManager.clearBends()),

              onReorderBend: (oldIndex, newIndex) {
                setState(() {
                  _dataManager.reorderBend(oldIndex, newIndex);
                });
              },
            ),

            MarkingPage(
              pageController: _pageController,
              startDir: _currentStartDir,
            ),
          ],
        ),
      ),
    );
  }
}
