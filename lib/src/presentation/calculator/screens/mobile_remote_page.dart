import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vector_math/vector_math_64.dart' as vmath; // 🚀 3D 엔진 필수 패키지

import '../widgets/remote_widgets.dart';

// 💡 리모컨 UI용 색상 정의
const Color makitaTeal = Color(0xFF007580);
const Color inputBg = Color(0xFF1E1E1E);
const Color darkBg = Color(0xFF121212);
const Color mutedWhite = Color(0xFFE0E0E0);

class MobileRemotePage extends StatefulWidget {
  const MobileRemotePage({super.key});

  @override
  State<MobileRemotePage> createState() => _MobileRemotePageState();
}

class _MobileRemotePageState extends State<MobileRemotePage> {
  final PageController _pageController = PageController();

  int _currentMode = 0;
  bool _isTransmitting = false;

  final String _serverRadius = "45.0";

  final List<Map<String, dynamic>> _modes = [
    {"name": "직관 (Straight)", "color": const Color(0xFF4A5D66)},
    {"name": "90° 벤딩", "color": const Color(0xFF00606B)},
    {"name": "오프셋", "color": const Color(0xFF8A6345)},
    {"name": "새들", "color": const Color(0xFF635666)},
    {"name": "롤링 오프셋", "color": const Color(0xFF3B5E52)},
  ];

  final int _modeCount = 5;
  late List<int> _innerTabs;
  late List<bool> _isInputFinishedList;
  late List<String> _selectedDirs;

  late List<TextEditingController> _val1Ctrls;
  late List<TextEditingController> _val2Ctrls;
  late List<TextEditingController> _angleCtrls;
  late List<TextEditingController> _result1Ctrls;
  late List<TextEditingController> _result2Ctrls;

  late List<FocusNode> _val1FocusNodes;
  late List<FocusNode> _val2FocusNodes;
  late List<FocusNode> _angleFocusNodes;

  final List<Map<String, dynamic>> _historyLogs = [];

  @override
  void initState() {
    super.initState();
    _innerTabs = List.filled(_modeCount, 0);
    _isInputFinishedList = List.filled(_modeCount, false);
    _selectedDirs = List.filled(_modeCount, "UP");

    _val1Ctrls = List.generate(
      _modeCount,
      (_) => TextEditingController()..addListener(_calculateDynamicValues),
    );
    _val2Ctrls = List.generate(
      _modeCount,
      (_) => TextEditingController()..addListener(_calculateDynamicValues),
    );
    _angleCtrls = List.generate(
      _modeCount,
      (_) => TextEditingController()..addListener(_calculateDynamicValues),
    );
    _result1Ctrls = List.generate(_modeCount, (_) => TextEditingController());
    _result2Ctrls = List.generate(_modeCount, (_) => TextEditingController());

    _val1FocusNodes = List.generate(_modeCount, (_) => FocusNode());
    _val2FocusNodes = List.generate(_modeCount, (_) => FocusNode());
    _angleFocusNodes = List.generate(_modeCount, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (int i = 0; i < _modeCount; i++) {
      _val1Ctrls[i].dispose();
      _val2Ctrls[i].dispose();
      _angleCtrls[i].dispose();
      _result1Ctrls[i].dispose();
      _result2Ctrls[i].dispose();
      _val1FocusNodes[i].dispose();
      _val2FocusNodes[i].dispose();
      _angleFocusNodes[i].dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _calculateDynamicValues() {
    int m = _currentMode;
    double h = double.tryParse(_val1Ctrls[m].text) ?? 0;
    double val2 = double.tryParse(_val2Ctrls[m].text) ?? 0;
    double angle = double.tryParse(_angleCtrls[m].text) ?? 0;

    if (m == 2) {
      if (_innerTabs[m] == 0) {
        if (h > 0 && angle > 0 && angle < 90) {
          _val2Ctrls[m].text = (h / math.sin(angle * (math.pi / 180)))
              .toStringAsFixed(1);
        } else if (angle == 0) {
          _val2Ctrls[m].text = "";
        }
      } else {
        if (h > 0 && val2 > 0 && val2 >= h) {
          _angleCtrls[m].text = (math.asin(h / val2) * (180 / math.pi))
              .toStringAsFixed(1);
        } else {
          _angleCtrls[m].text = "";
        }
      }
    } else if (m == 3) {
      if (h > 0 && angle > 0 && angle < 90) {
        _result1Ctrls[m].text = (h / math.sin(angle * (math.pi / 180)))
            .toStringAsFixed(1);
      } else {
        _result1Ctrls[m].text = "";
      }
    } else if (m == 4) {
      if (h > 0 && val2 > 0) {
        double trueH = math.sqrt((h * h) + (val2 * val2));
        _result1Ctrls[m].text = trueH.toStringAsFixed(1);
        if (angle > 0 && angle < 90) {
          _result2Ctrls[m].text = (trueH / math.sin(angle * (math.pi / 180)))
              .toStringAsFixed(1);
        } else {
          _result2Ctrls[m].text = "";
        }
      } else {
        _result1Ctrls[m].text = "";
        _result2Ctrls[m].text = "";
      }
    }
  }

  void _onPageChanged(int modeIndex) {
    if (_isTransmitting) return;
    setState(() => _currentMode = modeIndex);
  }

  bool _validateInputs() {
    int m = _currentMode;
    if (_val1Ctrls[m].text.isEmpty) return false;
    if (m == 2) {
      if (_innerTabs[m] == 0 && _angleCtrls[m].text.isEmpty) return false;
      if (_innerTabs[m] == 1 && _val2Ctrls[m].text.isEmpty) return false;
    }
    if (m == 3) {
      if (_innerTabs[m] == 1 && _val2Ctrls[m].text.isEmpty) return false;
      if (_angleCtrls[m].text.isEmpty) return false;
    }
    if (m == 4 && (_val2Ctrls[m].text.isEmpty || _angleCtrls[m].text.isEmpty)) {
      return false;
    }
    return true;
  }

  Future<void> _sendData() async {
    if (_isTransmitting) return;
    HapticFeedback.heavyImpact();
    setState(() => _isTransmitting = true);

    int m = _currentMode;
    String sendVal1 = _val1Ctrls[m].text;
    String sendVal2 =
        (m == 2 && _innerTabs[m] == 1) ||
            (m == 3 && _innerTabs[m] == 1) ||
            m == 4
        ? _val2Ctrls[m].text
        : "";
    String sendAngle = m == 1
        ? "90"
        : ((m == 2 && _innerTabs[m] == 0) || m == 3 || m == 4
              ? _angleCtrls[m].text
              : "");

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final newRecord = {
      "id": timestamp.toString(),
      "time":
          "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
      "mode": _modes[m]['name'],
      "color": _modes[m]['color'].value,
      "val1": sendVal1,
      "val2": sendVal2,
      "angle": sendAngle,
      "dir": _selectedDirs[m],
      "status": "pending",
      "timestamp": timestamp,
    };

    setState(() => _historyLogs.insert(0, newRecord));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("서버로 데이터 전송 중..."),
        backgroundColor: Colors.blueAccent.shade700,
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      await FirebaseFirestore.instance
          .collection('remote_commands')
          .doc(timestamp.toString())
          .set(newRecord);

      if (!mounted) return;
      HapticFeedback.mediumImpact();

      setState(() {
        _historyLogs.firstWhere(
          (log) => log['id'] == newRecord['id'],
        )['status'] = "completed";
        _isTransmitting = false;
        _isInputFinishedList[m] = false;
        _selectedDirs[m] = "UP";
        _innerTabs[m] = 0;
        _val1Ctrls[m].clear();
        _val2Ctrls[m].clear();
        _angleCtrls[m].clear();
        _result1Ctrls[m].clear();
        _result2Ctrls[m].clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("태블릿 전송 완료!"),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      setState(() {
        _isTransmitting = false;
        _historyLogs.firstWhere(
          (log) => log['id'] == newRecord['id'],
        )['status'] = "failed";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("전송 실패: $e"),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var modeColor = _modes[_currentMode]['color'];

    return Scaffold(
      backgroundColor: darkBg,
      resizeToAvoidBottomInset: true,
      body: AbsorbPointer(
        absorbing: _isTransmitting,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(modeColor),
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _val1Ctrls[_currentMode],
                      _val2Ctrls[_currentMode],
                      _angleCtrls[_currentMode],
                    ]),
                    builder: (context, child) => _buildIsoPreview(modeColor),
                  ),
                  Expanded(
                    child: PageView.builder(
                      physics: _isTransmitting
                          ? const NeverScrollableScrollPhysics()
                          : const BouncingScrollPhysics(),
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemCount: _modes.length,
                      itemBuilder: (context, index) {
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _isInputFinishedList[index]
                              ? _buildDirectionStep(index)
                              : _buildInputStep(index),
                        );
                      },
                    ),
                  ),
                  _buildBottomButton(modeColor),
                ],
              ),
              if (_isTransmitting)
                Container(
                  color: Colors.black.withValues(alpha: 0.4),
                  width: double.infinity,
                  height: double.infinity,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isTransmitting ? null : _showHistorySheet,
        backgroundColor: _isTransmitting ? Colors.grey.shade800 : inputBg,
        child: Icon(
          Icons.history,
          color: _isTransmitting ? Colors.grey.shade500 : Colors.white,
        ),
      ),
    );
  }

  Widget _buildHeader(Color modeColor) {
    return Container(
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
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [핵심 수정] 가짜 2D 그림을 버리고 진짜 3D 벡터 엔진(Preview3DPainter)으로 연동
  Widget _buildIsoPreview(Color modeColor) {
    int m = _currentMode;

    // 현재 입력창의 값들 파싱
    double val1 = double.tryParse(_val1Ctrls[m].text) ?? 50.0;
    double val2 = double.tryParse(_val2Ctrls[m].text) ?? 50.0;
    double angle = double.tryParse(_angleCtrls[m].text) ?? 45.0;

    // 아무것도 입력 안 했을 때 기본 표시값
    if (val1 == 0) val1 = 50.0;
    if (val2 == 0) val2 = 50.0;

    // 모드(m)에 따라 3D 뷰어에 던져줄 가상의 벤딩 리스트 생성
    List<Map<String, dynamic>> previewBends = [];

    if (m == 0) {
      // 직관
      previewBends.add({'length': val1, 'angle': 0.0, 'rotation': 0.0});
    } else if (m == 1) {
      // 90도
      previewBends.add({'length': val1, 'angle': 90.0, 'rotation': 90.0});
      previewBends.add({'length': 50.0, 'angle': 0.0, 'rotation': 0.0});
    } else if (m == 2) {
      // 오프셋
      double a = angle == 0 ? 45.0 : angle;
      double travel = val1 / math.sin(a * math.pi / 180.0);
      previewBends.add({'length': 40.0, 'angle': a, 'rotation': 90.0});
      previewBends.add({'length': travel, 'angle': a, 'rotation': 270.0});
      previewBends.add({'length': 40.0, 'angle': 0.0, 'rotation': 0.0});
    } else if (m == 3) {
      // 새들 (3 Point)
      double a = angle == 0 ? 45.0 : angle;
      double travel = val1 / math.sin((a / 2) * math.pi / 180.0);
      previewBends.add({'length': 30.0, 'angle': a / 2, 'rotation': 0.0});
      previewBends.add({'length': travel, 'angle': a, 'rotation': 180.0});
      previewBends.add({'length': travel, 'angle': a / 2, 'rotation': 0.0});
    } else if (m == 4) {
      // 롤링
      double a = angle == 0 ? 45.0 : angle;
      double t = math.sqrt(val1 * val1 + val2 * val2);
      previewBends.add({'length': 40.0, 'angle': a, 'rotation': 45.0});
      previewBends.add({'length': t, 'angle': a, 'rotation': 225.0});
      previewBends.add({'length': 40.0, 'angle': 0.0, 'rotation': 0.0});
    }

    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: inputBg,
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(double.infinity, 140),
            painter: Preview3DPainter(
              bendList: previewBends,
              themeColor: modeColor,
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                "3D 자동 변환 미리보기",
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputStep(int index) {
    var modeColor = _modes[index]['color'];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          if (index == 2)
            InnerTabSelector(
              tabs: const ["일반 오프셋", "오프셋 역산"],
              selectedIndex: _innerTabs[index],
              activeColor: modeColor,
              onTabSelected: (i) => setState(() {
                _innerTabs[index] = i;
                _val1Ctrls[index].clear();
                _val2Ctrls[index].clear();
                _angleCtrls[index].clear();
                _result1Ctrls[index].clear();
                _result2Ctrls[index].clear();
              }),
            ),
          if (index == 3)
            InnerTabSelector(
              tabs: const ["3 포인트 새들", "4 포인트 새들"],
              selectedIndex: _innerTabs[index],
              activeColor: modeColor,
              onTabSelected: (i) => setState(() {
                _innerTabs[index] = i;
                _val1Ctrls[index].clear();
                _val2Ctrls[index].clear();
                _angleCtrls[index].clear();
                _result1Ctrls[index].clear();
              }),
            ),
          const SizedBox(height: 16),
          ..._buildDynamicInputs(index, modeColor),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              if (!_validateInputs()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("필수 수치를 입력해주세요!"),
                    backgroundColor: Colors.redAccent.shade700,
                  ),
                );
                HapticFeedback.lightImpact();
                return;
              }
              setState(() => _isInputFinishedList[index] = true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: inputBg,
              side: BorderSide(color: modeColor, width: 1.5),
              minimumSize: const Size.fromHeight(60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "방향 설정으로 이동",
                  style: TextStyle(
                    fontSize: 18,
                    color: mutedWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, color: mutedWhite, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDynamicInputs(int m, Color focusColor) {
    List<Widget> inputs = [];
    if (m == 0) {
      inputs.add(
        RemoteTextField(
          label: "직관 기장 (L)",
          ctrl: _val1Ctrls[m],
          currentFocus: _val1FocusNodes[m],
          focusColor: focusColor,
        ),
      );
    } else if (m == 1) {
      inputs.add(
        RemoteTextField(
          label: "기장 (L)",
          ctrl: _val1Ctrls[m],
          currentFocus: _val1FocusNodes[m],
          focusColor: focusColor,
        ),
      );
      inputs.add(const SizedBox(height: 20));
      inputs.add(
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.link, color: focusColor, size: 20),
              const SizedBox(width: 10),
              Text(
                "태블릿 연동 반경(R): $_serverRadius mm",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    } else if (m == 2) {
      if (_innerTabs[m] == 0) {
        inputs.add(
          RemoteTextField(
            label: "단차 높이 (H)",
            ctrl: _val1Ctrls[m],
            currentFocus: _val1FocusNodes[m],
            focusColor: focusColor,
            nextFocus: _angleFocusNodes[m],
          ),
        );
        inputs.add(const SizedBox(height: 20));
        inputs.add(
          RemoteTextField(
            label: "벤딩 각도 (θ)",
            ctrl: _angleCtrls[m],
            currentFocus: _angleFocusNodes[m],
            focusColor: focusColor,
            showQuickAngles: true,
          ),
        );
        inputs.add(const SizedBox(height: 20));
        inputs.add(
          RemoteReadOnlyField(
            label: "자동 계산된 대각 길이 (D)",
            ctrl: _val2Ctrls[m],
            textColor: Colors.blueAccent,
          ),
        );
      } else {
        inputs.add(
          RemoteTextField(
            label: "단차 높이 (H)",
            ctrl: _val1Ctrls[m],
            currentFocus: _val1FocusNodes[m],
            focusColor: focusColor,
            nextFocus: _val2FocusNodes[m],
          ),
        );
        inputs.add(const SizedBox(height: 20));
        inputs.add(
          RemoteTextField(
            label: "대각 길이 (D)",
            ctrl: _val2Ctrls[m],
            currentFocus: _val2FocusNodes[m],
            focusColor: focusColor,
          ),
        );
        inputs.add(const SizedBox(height: 20));
        inputs.add(
          RemoteReadOnlyField(
            label: "자동 계산된 각도 (θ)",
            ctrl: _angleCtrls[m],
            textColor: Colors.greenAccent,
          ),
        );
      }
    } else if (m == 3) {
      inputs.add(
        RemoteTextField(
          label: "장애물 높이 (H)",
          ctrl: _val1Ctrls[m],
          currentFocus: _val1FocusNodes[m],
          focusColor: focusColor,
          nextFocus: _innerTabs[m] == 1
              ? _val2FocusNodes[m]
              : _angleFocusNodes[m],
        ),
      );
      inputs.add(const SizedBox(height: 20));
      if (_innerTabs[m] == 1) {
        inputs.add(
          RemoteTextField(
            label: "장애물 폭 (W)",
            ctrl: _val2Ctrls[m],
            currentFocus: _val2FocusNodes[m],
            focusColor: focusColor,
            nextFocus: _angleFocusNodes[m],
          ),
        );
        inputs.add(const SizedBox(height: 20));
      }
      inputs.add(
        RemoteTextField(
          label: "벤딩 각도 (θ)",
          ctrl: _angleCtrls[m],
          currentFocus: _angleFocusNodes[m],
          focusColor: focusColor,
          showQuickAngles: true,
        ),
      );
      inputs.add(const SizedBox(height: 20));
      inputs.add(
        RemoteReadOnlyField(
          label: "자동 계산된 마킹 간격 (D)",
          ctrl: _result1Ctrls[m],
          textColor: Colors.orangeAccent,
        ),
      );
    } else if (m == 4) {
      inputs.add(
        RemoteTextField(
          label: "수직 단차 (H)",
          ctrl: _val1Ctrls[m],
          currentFocus: _val1FocusNodes[m],
          focusColor: focusColor,
          nextFocus: _val2FocusNodes[m],
        ),
      );
      inputs.add(const SizedBox(height: 20));
      inputs.add(
        RemoteTextField(
          label: "수평 롤 (Roll)",
          ctrl: _val2Ctrls[m],
          currentFocus: _val2FocusNodes[m],
          focusColor: focusColor,
          nextFocus: _angleFocusNodes[m],
        ),
      );
      inputs.add(const SizedBox(height: 20));
      inputs.add(
        RemoteTextField(
          label: "벤딩 각도 (θ)",
          ctrl: _angleCtrls[m],
          currentFocus: _angleFocusNodes[m],
          focusColor: focusColor,
          showQuickAngles: true,
        ),
      );
      inputs.add(const SizedBox(height: 20));
      inputs.add(
        RemoteReadOnlyField(
          label: "자동 계산된 진단차 (True H)",
          ctrl: _result1Ctrls[m],
          textColor: Colors.purpleAccent,
        ),
      );
      inputs.add(const SizedBox(height: 10));
      inputs.add(
        RemoteReadOnlyField(
          label: "자동 계산된 대각 길이 (D)",
          ctrl: _result2Ctrls[m],
          textColor: Colors.blueAccent,
        ),
      );
    }
    return inputs;
  }

  Widget _buildDirectionStep(int index) {
    var modeColor = _modes[index]['color'];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
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
          child: DirectionSelector(
            selectedDir: _selectedDirs[index],
            modeColor: modeColor,
            onDirSelected: (dir) => setState(() => _selectedDirs[index] = dir),
          ),
        ),
        const SizedBox(height: 40),
        TextButton.icon(
          onPressed: () => setState(() => _isInputFinishedList[index] = false),
          icon: const Icon(Icons.edit, color: Colors.grey),
          label: const Text(
            "수치 입력으로 돌아가기",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton(Color modeColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: darkBg,
      child: ElevatedButton(
        onPressed: (_isInputFinishedList[_currentMode] && !_isTransmitting)
            ? _sendData
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: modeColor,
          disabledBackgroundColor: inputBg,
          minimumSize: const Size.fromHeight(70),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isTransmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                _isInputFinishedList[_currentMode]
                    ? "태블릿으로 데이터 전송"
                    : "수치를 입력하세요",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _isInputFinishedList[_currentMode]
                      ? Colors.white
                      : Colors.grey.shade600,
                ),
              ),
      ),
    );
  }

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: inputBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                "전송 기록 (태블릿 전송 데이터)",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _historyLogs.isEmpty
                    ? Center(
                        child: Text(
                          "기록이 없습니다.",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _historyLogs.length,
                        itemBuilder: (context, index) {
                          var log = _historyLogs[index];
                          bool isCompleted = log['status'] == 'completed';
                          String subtitleText = "H/L: ${log['val1']}";
                          if (log['val2'] != "") {
                            subtitleText += " / W/D/Roll: ${log['val2']}";
                          }
                          if (log['angle'] != "") {
                            subtitleText += " / 각도: ${log['angle']}°";
                          }
                          subtitleText += "  •  ${log['time']}";
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Color(log['color']),
                              radius: 12,
                            ),
                            title: Text(
                              "${log['mode']} (${log['dir']})",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              subtitleText,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                              ),
                            ),
                            trailing: Icon(
                              isCompleted ? Icons.check_circle : Icons.schedule,
                              color: isCompleted
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ============================================================================
/// 🚀 [완벽 교체] 리모컨용 3D 벡터 미리보기 엔진 (Quaternion 적용)
/// ============================================================================
class Preview3DPainter extends CustomPainter {
  final List<Map<String, dynamic>> bendList;
  final Color themeColor;

  Preview3DPainter({required this.bendList, required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (bendList.isEmpty || size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = themeColor
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. 3D 공간 벡터 추적 (Quaternion 적용)
    List<vmath.Vector3> pts3D = [];
    vmath.Vector3 currentPos = vmath.Vector3.zero();
    // 리모컨에서는 사용자가 보기 편하도록 X축(가로)을 진행 방향으로 고정
    vmath.Vector3 currentDir = vmath.Vector3(1, 0, 0);
    vmath.Vector3 currentNormal = vmath.Vector3(0, 1, 0);

    pts3D.add(currentPos.clone());

    for (var bend in bendList) {
      double l = (bend['length'] ?? 0).toDouble();
      double a = (bend['angle'] ?? 0).toDouble();
      double rot = (bend['rotation'] ?? 0).toDouble();

      currentPos += (currentDir * l);
      pts3D.add(currentPos.clone());

      if (a > 0) {
        double thetaRad = a * (math.pi / 180.0);
        double rollRad = rot * (math.pi / 180.0);

        vmath.Quaternion rollQuat = vmath.Quaternion.axisAngle(
          currentDir,
          rollRad,
        );
        rollQuat.rotate(currentNormal);
        currentNormal.normalize();

        vmath.Quaternion bendQuat = vmath.Quaternion.axisAngle(
          currentNormal,
          thetaRad,
        );
        bendQuat.rotate(currentDir);
        currentDir.normalize();
      }
    }

    // 2. 리모컨 화면을 위한 약간의 고정된 회전 (아이소메트릭 뷰)
    vmath.Matrix4 cameraMatrix = vmath.Matrix4.identity()
      ..rotateX(math.pi / 8)
      ..rotateY(-math.pi / 6);

    List<vmath.Vector3> rotatedPts = pts3D
        .map((p) => cameraMatrix.transformed3(p))
        .toList();

    // 3. 2D 투영 및 자동 스케일 맞춤
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;

    for (var p in rotatedPts) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    double drawWidth = maxX - minX == 0 ? 100 : maxX - minX;
    double drawHeight = maxY - minY == 0 ? 100 : maxY - minY;
    // 리모컨 화면(140px)에 꽉 차게 보이기 위해 여백 조절 (0.8)
    double scale = math
        .min((size.width * 0.8) / drawWidth, (size.height * 0.8) / drawHeight)
        .clamp(0.1, 5.0);

    Offset tr(vmath.Vector3 p) {
      return Offset(
        (p.x - (minX + maxX) / 2) * scale + size.width / 2,
        (p.y - (minY + maxY) / 2) * scale + size.height / 2,
      );
    }

    List<Offset> finalPoints = rotatedPts.map((p) => tr(p)).toList();

    // 4. 선 그리기
    final path = Path();
    for (int i = 0; i < finalPoints.length; i++) {
      if (i == 0)
        path.moveTo(finalPoints[i].dx, finalPoints[i].dy);
      else
        path.lineTo(finalPoints[i].dx, finalPoints[i].dy);
    }

    // 그림자 효과
    canvas.drawPath(
      path,
      Paint()
        ..color = themeColor.withValues(alpha: 0.3)
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant Preview3DPainter oldDelegate) => true;
}
