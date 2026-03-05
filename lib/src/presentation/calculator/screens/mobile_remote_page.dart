import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MobileRemotePage extends StatefulWidget {
  const MobileRemotePage({super.key});

  @override
  State<MobileRemotePage> createState() => _MobileRemotePageState();
}

class _MobileRemotePageState extends State<MobileRemotePage> {
  final PageController _pageController = PageController();

  int _currentMode = 0;
  int _innerTab = 0;
  bool _isInputFinished = false;
  String _selectedDir = "UP";

  // 고급스러운 다크/무광 톤 설정
  final Color darkBg = const Color(0xFF1E2124);
  final Color inputBg = const Color(0xFF2A2E33);
  final Color mutedWhite = const Color(0xFFD0D4D9);

  final List<Map<String, dynamic>> _modes = [
    {"name": "직관 (Straight)", "color": const Color(0xFF4A5D66)},
    {"name": "90° 벤딩", "color": const Color(0xFF00606B)},
    {"name": "오프셋", "color": const Color(0xFF8A6345)},
    {"name": "새들", "color": const Color(0xFF635666)},
    {"name": "롤링 오프셋", "color": const Color(0xFF3B5E52)},
  ];

  final TextEditingController _val1Ctrl = TextEditingController();
  final TextEditingController _val2Ctrl = TextEditingController();
  final TextEditingController _val3Ctrl = TextEditingController();
  final TextEditingController _angleCtrl = TextEditingController();

  void _resetState(int modeIndex) {
    setState(() {
      _currentMode = modeIndex;
      _innerTab = 0;
      _isInputFinished = false;
      _val1Ctrl.clear();
      _val2Ctrl.clear();
      _val3Ctrl.clear();
      _angleCtrl.clear();
    });
  }

  // 데이터 전송 (이모티콘 제거)
  void _sendData() {
    HapticFeedback.heavyImpact();

    String finalAngle = (_currentMode == 1) ? "90" : _angleCtrl.text;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "전송 완료: ${_modes[_currentMode]['name']} (각도: $finalAngle°)",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _modes[_currentMode]['color'],
        duration: const Duration(seconds: 1),
      ),
    );
    setState(() => _isInputFinished = false);
  }

  @override
  Widget build(BuildContext context) {
    var modeColor = _modes[_currentMode]['color'];

    return Scaffold(
      backgroundColor: darkBg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // [1단: 상단 모드 표시 바]
            Container(
              height: 90,
              width: double.infinity,
              color: modeColor,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "좌우로 스와이프하여 모드 변경",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _modes[_currentMode]['name'],
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // [2단: 메인 입력 구역]
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _resetState,
                itemCount: _modes.length,
                itemBuilder: (context, index) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isInputFinished
                        ? _buildDirectionStep()
                        : _buildInputStep(index),
                  );
                },
              ),
            ),

            // [3단: 하단 고정 액션 버튼]
            Container(
              padding: const EdgeInsets.all(20),
              color: darkBg,
              child: ElevatedButton(
                onPressed: _isInputFinished ? _sendData : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: modeColor,
                  disabledBackgroundColor: inputBg,
                  minimumSize: const Size.fromHeight(70),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isInputFinished ? "데이터 전송" : "수치를 입력하세요",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _isInputFinished
                        ? Colors.white
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1단계: 수치 및 탭 입력 (가이드 포함)
  // ==========================================
  Widget _buildInputStep(int index) {
    var modeColor = _modes[_currentMode]['color'];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          if (index == 2) _buildInnerTabs(["일반 오프셋", "역산 (관 간격)"], modeColor),
          if (index == 3) _buildInnerTabs(["3 포인트 새들", "4 포인트 새들"], modeColor),

          if (index == 2 || index == 3 || index == 4) ...[
            const SizedBox(height: 16),
            _buildMiniGuide(index, modeColor),
          ],

          const SizedBox(height: 16),
          ..._buildDynamicInputs(index, modeColor),

          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              setState(() => _isInputFinished = true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: inputBg,
              side: BorderSide(color: modeColor, width: 1.5),
              minimumSize: const Size.fromHeight(60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "방향 설정",
                  style: TextStyle(
                    fontSize: 18,
                    color: mutedWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward, color: mutedWhite, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 미니 가이드 박스 생성 위젯
  Widget _buildMiniGuide(int mode, Color themeColor) {
    String guideText = "";
    if (mode == 2) {
      guideText = _innerTab == 0
          ? "배관이 이동할 수직 단차(H)와 꺾일 각도(θ)를 입력하세요."
          : "두 배관 사이의 평행 간격(T)과 벤딩 각도(θ)를 입력하세요.";
    } else if (mode == 3) {
      guideText = _innerTab == 0
          ? "장애물의 최고 높이(H)와 꺾일 각도(θ)를 입력하세요."
          : "장애물의 높이(H) 및 전체 폭(W), 꺾일 각도(θ)를 모두 입력하세요.";
    } else if (mode == 4) {
      guideText = "수직 단차(H)와 수평으로 틀어지는 롤(Roll) 값을 측정하여 입력하세요.";
    }

    if (guideText.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: themeColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              guideText,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInnerTabs(List<String> tabs, Color activeColor) {
    return Row(
      children: List.generate(tabs.length, (i) {
        bool isSelected = _innerTab == i;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _innerTab = i;
                _val1Ctrl.clear();
                _val2Ctrl.clear();
                _val3Ctrl.clear();
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? inputBg : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? activeColor : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                tabs[i],
                style: TextStyle(
                  color: isSelected ? activeColor : Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  List<Widget> _buildDynamicInputs(int mode, Color focusColor) {
    List<Widget> inputs = [];

    if (mode == 0) {
      inputs.add(_buildTextField("직관 기장 (L)", _val1Ctrl, focusColor));
    } else if (mode == 1) {
      inputs.add(_buildTextField("첫단 기장 (L1) - 생략가능", _val1Ctrl, focusColor));
      inputs.add(const SizedBox(height: 20));
      inputs.add(_buildTextField("벤딩 반경 (R)", _val2Ctrl, focusColor));
    } else if (mode == 2) {
      inputs.add(
        _buildTextField(
          _innerTab == 0 ? "단차 높이 (H)" : "관 간격 (T)",
          _val1Ctrl,
          focusColor,
        ),
      );
      inputs.add(const SizedBox(height: 20));
      inputs.add(
        _buildTextField(
          "벤딩 각도 (θ)",
          _angleCtrl,
          focusColor,
          showQuickAngles: true,
        ),
      );
    } else if (mode == 3) {
      inputs.add(_buildTextField("장애물 높이 (H)", _val1Ctrl, focusColor));
      inputs.add(const SizedBox(height: 20));
      if (_innerTab == 1) {
        inputs.add(_buildTextField("장애물 폭 (W)", _val2Ctrl, focusColor));
        inputs.add(const SizedBox(height: 20));
      }
      inputs.add(
        _buildTextField(
          "벤딩 각도 (θ)",
          _angleCtrl,
          focusColor,
          showQuickAngles: true,
        ),
      );
    } else if (mode == 4) {
      inputs.add(_buildTextField("수직 단차 (H)", _val1Ctrl, focusColor));
      inputs.add(const SizedBox(height: 20));
      inputs.add(_buildTextField("수평 롤 (Roll)", _val2Ctrl, focusColor));
      inputs.add(const SizedBox(height: 20));
      inputs.add(
        _buildTextField(
          "벤딩 각도 (θ)",
          _angleCtrl,
          focusColor,
          showQuickAngles: true,
        ),
      );
    }
    return inputs;
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl,
    Color focusColor, {
    bool showQuickAngles = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: mutedWhite,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 14, color: Colors.grey),
            filled: true,
            fillColor: inputBg,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: focusColor, width: 2),
            ),
          ),
        ),
        if (showQuickAngles) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [30, 45, 60, 90]
                .map(
                  (angle) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          ctrl.text = angle.toString();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: mutedWhite,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          backgroundColor: inputBg,
                        ),
                        child: Text("$angle°"),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  // ==========================================
  // 2단계: 6축 방향 설정 화면
  // ==========================================
  Widget _buildDirectionStep() {
    var modeColor = _modes[_currentMode]['color'];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "벤딩 방향축 (6-Axis)",
          style: TextStyle(
            fontSize: 20,
            color: mutedWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: ["UP", "DOWN", "LEFT", "RIGHT", "FRONT", "BACK"].map((
              dir,
            ) {
              bool isSelected = _selectedDir == dir;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDir = dir);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected ? modeColor : inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? modeColor : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: modeColor.withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ]
                        : [],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    dir,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 40),
        TextButton.icon(
          onPressed: () => setState(() => _isInputFinished = false),
          icon: const Icon(
            Icons.edit,
            color: Colors.grey,
          ), // 복구 아이콘도 정갈한 edit으로 변경
          label: const Text(
            "수치 입력으로 돌아가기",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
