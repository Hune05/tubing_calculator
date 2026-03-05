import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MobileRemotePage extends StatefulWidget {
  const MobileRemotePage({super.key});

  @override
  State<MobileRemotePage> createState() => _MobileRemotePageState();
}

class _MobileRemotePageState extends State<MobileRemotePage> {
  // 스와이프를 위한 페이지 컨트롤러
  final PageController _pageController = PageController();
  int _currentMode = 0;
  bool _isInputFinished = false; // 수치 입력 ↔ 방향 설정 스위칭 용도
  String _selectedDir = "UP"; // 기본 방향

  // 모드별 정보 세팅 (색상으로 시인성 극대화)
  final List<Map<String, dynamic>> _modes = [
    {
      "name": "90° 벤딩",
      "color": const Color(0xFF0055BB),
      "l1": "L1 길이 (mm)",
      "l2": "반경 R (mm)",
    },
    {
      "name": "오프셋",
      "color": const Color(0xFFCC8800),
      "l1": "높이 H (mm)",
      "l2": "각도 θ (deg)",
    },
    {
      "name": "직관 (Straight)",
      "color": const Color(0xFF007744),
      "l1": "전체 길이 (mm)",
      "l2": "",
    },
  ];

  // 데이터 오염 방지: 모드별로 독립적인 입력창 할당
  final List<List<TextEditingController>> _ctrls = [
    [
      TextEditingController(),
      TextEditingController(text: "30"),
    ], // 90도 (기본 반경 30)
    [
      TextEditingController(),
      TextEditingController(text: "45"),
    ], // 오프셋 (기본 각도 45)
    [TextEditingController()], // 직관
  ];

  // 🔥 태블릿으로 최종 발사!
  Future<void> _sendToTablet() async {
    HapticFeedback.heavyImpact(); // 전송 시 묵직한 진동 (손맛)

    var currentInputs = _ctrls[_currentMode];
    String val1 = currentInputs[0].text;
    String val2 = currentInputs.length > 1 ? currentInputs[1].text : "0";

    try {
      await FirebaseFirestore.instance
          .collection('bending_results')
          .doc('current_work')
          .set({
            'command': 'SAVE_AND_DRAW',
            'mode': _modes[_currentMode]['name'],
            'val1': val1.isEmpty ? "0" : val1,
            'val2': val2.isEmpty ? "0" : val2,
            'direction': _selectedDir,
            'timestamp': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ ${_modes[_currentMode]['name']} 전송 완료!"),
            backgroundColor: _modes[_currentMode]['color'],
            duration: const Duration(seconds: 1),
          ),
        );
      }

      // 전송 후 다시 수치 입력 상태로 리셋
      setState(() => _isInputFinished = false);
    } catch (e) {
      debugPrint("전송 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    var mode = _modes[_currentMode];

    return Scaffold(
      // [키보드 올라올 때 레이아웃 찌그러짐 방지]
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // 🟥 [1단: 상단] 모드 인지 구역 (20%)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              height: 100,
              color: mode['color'],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "◀ 좌우로 밀어서 모드 변경 ▶",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    mode['name'],
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // 🟨 [2단: 중단] 입력 및 스위칭 구역 (스와이프 가능)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentMode = index;
                    _isInputFinished = false; // 모드 바뀌면 무조건 첫 단계로
                  });
                  HapticFeedback.lightImpact(); // 스와이프 시 가벼운 진동
                },
                itemCount: _modes.length,
                itemBuilder: (context, index) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isInputFinished
                        ? _buildDirectionStep() // 2단계: 방향 설정
                        : _buildInputStep(index), // 1단계: 수치 입력
                  );
                },
              ),
            ),

            // 🟦 [3단: 하단] 최종 할당 및 전송 구역 (20%) - 항상 고정됨
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              color: Colors.black87,
              child: ElevatedButton(
                onPressed: _isInputFinished
                    ? _sendToTablet
                    : null, // 입력 안 끝났으면 비활성화
                style: ElevatedButton.styleFrom(
                  backgroundColor: mode['color'],
                  disabledBackgroundColor: Colors.grey.shade800,
                  minimumSize: const Size.fromHeight(80),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.send,
                      color: _isInputFinished ? Colors.white : Colors.white30,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isInputFinished ? "전광판으로 쏘기" : "수치를 먼저 완료하세요",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _isInputFinished ? Colors.white : Colors.white30,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 👉 [중단 - 1단계] 수치 입력 화면
  Widget _buildInputStep(int index) {
    var inputs = _ctrls[index];
    var m = _modes[index];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTextField(m['l1'], inputs[0], m['color']),
          if (m['l2'] != "") ...[
            const SizedBox(height: 30),
            _buildTextField(m['l2'], inputs[1], m['color']),
          ],
          const SizedBox(height: 40),
          // 다음 단계(방향 설정)로 넘어가는 버튼
          ElevatedButton(
            onPressed: () {
              FocusScope.of(context).unfocus(); // 키보드 내리기
              setState(() => _isInputFinished = true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white12,
              minimumSize: const Size.fromHeight(60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              "방향 설정하기 ➡️",
              style: TextStyle(
                fontSize: 20,
                color: m['color'],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 👉 [중단 - 2단계] 방향 설정 화면
  Widget _buildDirectionStep() {
    var color = _modes[_currentMode]['color'];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "꺾을 방향을 선택하세요",
          style: TextStyle(
            fontSize: 22,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            childAspectRatio: 1.5,
            children: ["UP", "DOWN", "LEFT", "RIGHT"].map((dir) {
              bool isSelected = _selectedDir == dir;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDir = dir);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.white10,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    dir,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 30),
        TextButton.icon(
          onPressed: () => setState(() => _isInputFinished = false),
          icon: const Icon(Icons.refresh, color: Colors.white54),
          label: const Text(
            "수치 다시 수정하기",
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ),
      ],
    );
  }

  // 공통 텍스트 필드 위젯 (큼직하게!)
  Widget _buildTextField(
    String label,
    TextEditingController ctrl,
    Color focusColor,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 18, color: Colors.white54),
        floatingLabelAlignment: FloatingLabelAlignment.center,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: focusColor, width: 2),
        ),
      ),
    );
  }
}
