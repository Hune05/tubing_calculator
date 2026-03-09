import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;

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

  // ★ 가장 중요한 핵심 룰: 통신 중 다른 조작을 막는 락(Lock) 변수
  bool _isTransmitting = false;

  final String _serverRadius = "45.0";

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
  final TextEditingController _angleCtrl = TextEditingController();
  final TextEditingController _result1Ctrl = TextEditingController();
  final TextEditingController _result2Ctrl = TextEditingController();

  final FocusNode _val1Focus = FocusNode();
  final FocusNode _val2Focus = FocusNode();
  final FocusNode _angleFocus = FocusNode();

  final List<Map<String, dynamic>> _historyLogs = [];

  @override
  void initState() {
    super.initState();
    _val1Ctrl.addListener(_calculateDynamicValues);
    _val2Ctrl.addListener(_calculateDynamicValues);
    _angleCtrl.addListener(_calculateDynamicValues);
  }

  @override
  void dispose() {
    _val1Ctrl.removeListener(_calculateDynamicValues);
    _val2Ctrl.removeListener(_calculateDynamicValues);
    _angleCtrl.removeListener(_calculateDynamicValues);

    _val1Ctrl.dispose();
    _val2Ctrl.dispose();
    _angleCtrl.dispose();
    _result1Ctrl.dispose();
    _result2Ctrl.dispose();
    _val1Focus.dispose();
    _val2Focus.dispose();
    _angleFocus.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _calculateDynamicValues() {
    double h = double.tryParse(_val1Ctrl.text) ?? 0;
    double val2 = double.tryParse(_val2Ctrl.text) ?? 0;
    double angle = double.tryParse(_angleCtrl.text) ?? 0;

    if (_currentMode == 2) {
      if (_innerTab == 0) {
        if (h > 0 && angle > 0 && angle < 90) {
          double d = h / math.sin(angle * (math.pi / 180));
          _val2Ctrl.text = d.toStringAsFixed(1);
        } else if (angle == 0) {
          _val2Ctrl.text = "";
        }
      } else if (_innerTab == 1) {
        if (h > 0 && val2 > 0 && val2 >= h) {
          double deg = math.asin(h / val2) * (180 / math.pi);
          _angleCtrl.text = deg.toStringAsFixed(1);
        } else {
          _angleCtrl.text = "";
        }
      }
    } else if (_currentMode == 3) {
      if (h > 0 && angle > 0 && angle < 90) {
        double d = h / math.sin(angle * (math.pi / 180));
        _result1Ctrl.text = d.toStringAsFixed(1);
      } else {
        _result1Ctrl.text = "";
      }
    } else if (_currentMode == 4) {
      if (h > 0 && val2 > 0) {
        double trueH = math.sqrt((h * h) + (val2 * val2));
        _result1Ctrl.text = trueH.toStringAsFixed(1);

        if (angle > 0 && angle < 90) {
          double d = trueH / math.sin(angle * (math.pi / 180));
          _result2Ctrl.text = d.toStringAsFixed(1);
        } else {
          _result2Ctrl.text = "";
        }
      } else {
        _result1Ctrl.text = "";
        _result2Ctrl.text = "";
      }
    }
  }

  void _resetState(int modeIndex) {
    if (_isTransmitting) return; // 전송 중일 때는 모드 변경도 막음
    setState(() {
      _currentMode = modeIndex;
      _innerTab = 0;
      _isInputFinished = false;
      _val1Ctrl.clear();
      _val2Ctrl.clear();
      _angleCtrl.clear();
      _result1Ctrl.clear();
      _result2Ctrl.clear();
    });
  }

  bool _validateInputs() {
    if (_val1Ctrl.text.isEmpty) return false;

    if (_currentMode == 2) {
      if (_innerTab == 0 && _angleCtrl.text.isEmpty) return false;
      if (_innerTab == 1 && _val2Ctrl.text.isEmpty) return false;
    }
    if (_currentMode == 3) {
      if (_innerTab == 1 && _val2Ctrl.text.isEmpty) return false;
      if (_angleCtrl.text.isEmpty) return false;
    }
    if (_currentMode == 4 &&
        (_val2Ctrl.text.isEmpty || _angleCtrl.text.isEmpty)) {
      return false;
    }
    return true;
  }

  void _sendData() {
    if (_isTransmitting) return; // 중복 터치 방지 (Lock)

    HapticFeedback.heavyImpact();

    // 1. 화면 전체를 잠금 상태로 변경
    setState(() {
      _isTransmitting = true;
    });

    String sendVal1 = "";
    String sendVal2 = "";
    String sendAngle = "";

    if (_currentMode == 0) {
      sendVal1 = _val1Ctrl.text;
    } else if (_currentMode == 1) {
      sendVal1 = _val1Ctrl.text;
      sendAngle = "90";
    } else if (_currentMode == 2) {
      if (_innerTab == 0) {
        sendVal1 = _val1Ctrl.text;
        sendAngle = _angleCtrl.text;
        sendVal2 = "";
      } else {
        sendVal1 = _val1Ctrl.text;
        sendVal2 = _val2Ctrl.text;
        sendAngle = "";
      }
    } else if (_currentMode == 3) {
      sendVal1 = _val1Ctrl.text;
      if (_innerTab == 1) {
        sendVal2 = _val2Ctrl.text;
      }
      sendAngle = _angleCtrl.text;
    } else if (_currentMode == 4) {
      sendVal1 = _val1Ctrl.text;
      sendVal2 = _val2Ctrl.text;
      sendAngle = _angleCtrl.text;
    }

    final newRecord = {
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "time":
          "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
      "mode": _modes[_currentMode]['name'],
      "color": _modes[_currentMode]['color'],
      "val1": sendVal1,
      "val2": sendVal2,
      "angle": sendAngle,
      "dir": _selectedDir,
      "status": "pending",
    };

    setState(() {
      _historyLogs.insert(0, newRecord);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("데이터 전송 중... 태블릿 처리 대기중입니다."),
        backgroundColor: Colors.blueAccent.shade700,
        duration: const Duration(seconds: 2),
      ),
    );

    // 2. 태블릿에서 "팝업 처리 완료!" 신호가 올 때까지 대기 시뮬레이션 (2초)
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      HapticFeedback.mediumImpact();

      setState(() {
        // 기록을 완료 상태로 변경
        var target = _historyLogs.firstWhere(
          (log) => log['id'] == newRecord['id'],
        );
        target['status'] = "completed";

        // 3. 락 해제 및 다음 입력을 위한 초기화
        _isTransmitting = false;
        _isInputFinished = false;
        _val1Ctrl.clear();
        _val2Ctrl.clear();
        _angleCtrl.clear();
        _result1Ctrl.clear();
        _result2Ctrl.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("태블릿 입력 완료! 다음 작업을 진행하세요."),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 1),
        ),
      );
    });
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
                          if (log['val2'] != "")
                            subtitleText += " / W/D/Roll: ${log['val2']}";
                          if (log['angle'] != "")
                            subtitleText += " / 각도: ${log['angle']}°";
                          subtitleText += "  •  ${log['time']}";

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: log['color'],
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

  @override
  Widget build(BuildContext context) {
    var modeColor = _modes[_currentMode]['color'];

    return Scaffold(
      backgroundColor: darkBg,
      resizeToAvoidBottomInset: true,
      // ★ 화면 전체를 감싸서 전송 중(_isTransmitting)일 때 모든 터치를 무시(AbsorbPointer)함
      body: AbsorbPointer(
        absorbing: _isTransmitting,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
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
                          ),
                        ),
                      ],
                    ),
                  ),

                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _val1Ctrl,
                      _val2Ctrl,
                      _angleCtrl,
                    ]),
                    builder: (context, child) => _buildIsoPreview(modeColor),
                  ),

                  Expanded(
                    child: PageView.builder(
                      // 전송 중일 때는 페이지 스와이프도 안 먹히게 막음 (단일 기능으로 강제)
                      physics: _isTransmitting
                          ? const NeverScrollableScrollPhysics()
                          : const BouncingScrollPhysics(),
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

                  Container(
                    padding: const EdgeInsets.all(20),
                    color: darkBg,
                    child: ElevatedButton(
                      // ★ 버튼 잠금 로직 적용
                      onPressed: (_isInputFinished && !_isTransmitting)
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
                      // ★ 전송 중일 때 텍스트 대신 로딩 스피너 표시
                      child: _isTransmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _isInputFinished ? "태블릿으로 데이터 전송" : "수치를 입력하세요",
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
              // ★ 전송 중일 때 화면 전체를 살짝 어둡게 처리하여 시각적으로 잠김을 알림
              if (_isTransmitting)
                Container(
                  color: Colors.black.withValues(alpha: 0.4),
                  width: double.infinity,
                  height: double.infinity,
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        // 전송 중에는 기록장도 열지 못하게 블락
        onPressed: _isTransmitting ? null : _showHistorySheet,
        backgroundColor: _isTransmitting ? Colors.grey.shade800 : inputBg,
        child: Icon(
          Icons.history,
          color: _isTransmitting ? Colors.grey.shade500 : Colors.white,
        ),
      ),
    );
  }

  // === 아래 UI 빌드 함수들은 기존과 완전히 동일합니다 ===
  Widget _buildIsoPreview(Color modeColor) {
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
            painter: GridPainter(),
          ),
          CustomPaint(
            size: const Size(double.infinity, 140),
            painter: PipeIsoPainter(
              mode: _currentMode,
              innerTab: _innerTab,
              val1: double.tryParse(_val1Ctrl.text) ?? 0,
              val2:
                  double.tryParse(_val2Ctrl.text) ??
                  double.tryParse(_serverRadius) ??
                  0,
              angle: double.tryParse(_angleCtrl.text) ?? 0,
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
                "아이솔 형상 미리보기",
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputStep(int index) {
    var modeColor = _modes[_currentMode]['color'];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          if (index == 2) _buildInnerTabs(["일반 오프셋", "오프셋 역산"], modeColor),
          if (index == 3) _buildInnerTabs(["3 포인트 새들", "4 포인트 새들"], modeColor),
          const SizedBox(height: 16),
          ..._buildDynamicInputs(index, modeColor),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              if (!_validateInputs()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("필수 수치를 모두 입력해주세요!"),
                    backgroundColor: Colors.redAccent.shade700,
                  ),
                );
                HapticFeedback.lightImpact();
                return;
              }
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
                  "방향 설정으로 이동",
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
                _angleCtrl.clear();
                _result1Ctrl.clear();
                _result2Ctrl.clear();
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
      inputs.add(
        _buildTextField(
          "직관 기장 (L)",
          _val1Ctrl,
          _val1Focus,
          focusColor,
          nextFocus: null,
        ),
      );
    } else if (mode == 1) {
      inputs.add(
        _buildTextField(
          "기장 (L)",
          _val1Ctrl,
          _val1Focus,
          focusColor,
          nextFocus: null,
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
    } else if (mode == 2) {
      if (_innerTab == 0) {
        inputs.add(
          _buildTextField(
            "단차 높이 (H)",
            _val1Ctrl,
            _val1Focus,
            focusColor,
            nextFocus: _angleFocus,
          ),
        );
        inputs.add(const SizedBox(height: 20));
        inputs.add(
          _buildTextField(
            "벤딩 각도 (θ)",
            _angleCtrl,
            _angleFocus,
            focusColor,
            showQuickAngles: true,
            nextFocus: null,
          ),
        );
        inputs.add(const SizedBox(height: 20));
        inputs.add(
          _buildReadOnlyField("자동 계산된 대각 길이 (D)", _val2Ctrl, Colors.blueAccent),
        );
      } else {
        inputs.add(
          _buildTextField(
            "단차 높이 (H)",
            _val1Ctrl,
            _val1Focus,
            focusColor,
            nextFocus: _val2Focus,
          ),
        );
        inputs.add(const SizedBox(height: 20));
        inputs.add(
          _buildTextField(
            "대각 길이 (D)",
            _val2Ctrl,
            _val2Focus,
            focusColor,
            nextFocus: null,
          ),
        );
        inputs.add(const SizedBox(height: 20));
        inputs.add(
          _buildReadOnlyField("자동 계산된 각도 (θ)", _angleCtrl, Colors.greenAccent),
        );
      }
    } else if (mode == 3) {
      inputs.add(
        _buildTextField(
          "장애물 높이 (H)",
          _val1Ctrl,
          _val1Focus,
          focusColor,
          nextFocus: _innerTab == 1 ? _val2Focus : _angleFocus,
        ),
      );
      inputs.add(const SizedBox(height: 20));
      if (_innerTab == 1) {
        inputs.add(
          _buildTextField(
            "장애물 폭 (W)",
            _val2Ctrl,
            _val2Focus,
            focusColor,
            nextFocus: _angleFocus,
          ),
        );
        inputs.add(const SizedBox(height: 20));
      }
      inputs.add(
        _buildTextField(
          "벤딩 각도 (θ)",
          _angleCtrl,
          _angleFocus,
          focusColor,
          showQuickAngles: true,
          nextFocus: null,
        ),
      );
      inputs.add(const SizedBox(height: 20));
      inputs.add(
        _buildReadOnlyField(
          "자동 계산된 마킹 간격 (D)",
          _result1Ctrl,
          Colors.orangeAccent,
        ),
      );
    } else if (mode == 4) {
      inputs.add(
        _buildTextField(
          "수직 단차 (H)",
          _val1Ctrl,
          _val1Focus,
          focusColor,
          nextFocus: _val2Focus,
        ),
      );
      inputs.add(const SizedBox(height: 20));
      inputs.add(
        _buildTextField(
          "수평 롤 (Roll)",
          _val2Ctrl,
          _val2Focus,
          focusColor,
          nextFocus: _angleFocus,
        ),
      );
      inputs.add(const SizedBox(height: 20));
      inputs.add(
        _buildTextField(
          "벤딩 각도 (θ)",
          _angleCtrl,
          _angleFocus,
          focusColor,
          showQuickAngles: true,
          nextFocus: null,
        ),
      );
      inputs.add(const SizedBox(height: 20));
      inputs.add(
        _buildReadOnlyField(
          "자동 계산된 진단차 (True H)",
          _result1Ctrl,
          Colors.purpleAccent,
        ),
      );
      inputs.add(const SizedBox(height: 10));
      inputs.add(
        _buildReadOnlyField(
          "자동 계산된 대각 길이 (D)",
          _result2Ctrl,
          Colors.blueAccent,
        ),
      );
    }
    return inputs;
  }

  Widget _buildReadOnlyField(
    String label,
    TextEditingController ctrl,
    Color textColor,
  ) {
    return TextField(
      controller: ctrl,
      enabled: false,
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14, color: Colors.grey),
        filled: true,
        fillColor: inputBg,
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl,
    FocusNode currentFocus,
    Color focusColor, {
    bool showQuickAngles = false,
    bool isOptional = false,
    FocusNode? nextFocus,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          focusNode: currentFocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          textInputAction: nextFocus != null
              ? TextInputAction.next
              : TextInputAction.done,
          onSubmitted: (_) {
            if (nextFocus != null) {
              FocusScope.of(context).requestFocus(nextFocus);
            } else {
              FocusScope.of(context).unfocus();
            }
          },
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: mutedWhite,
          ),
          decoration: InputDecoration(
            labelText: isOptional ? label : "$label *",
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
            children: [22.5, 30, 45, 60]
                .map(
                  (angle) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          ctrl.text = angle.toString();
                          if (nextFocus == null)
                            FocusScope.of(context).unfocus();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: mutedWhite,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          backgroundColor: inputBg,
                        ),
                        child: Text(
                          "$angle°",
                          style: const TextStyle(fontSize: 14),
                        ),
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
          icon: const Icon(Icons.edit, color: Colors.grey),
          label: const Text(
            "수치 입력으로 돌아가기",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PipeIsoPainter extends CustomPainter {
  final int mode;
  final int innerTab;
  final double val1;
  final double val2;
  final double angle;
  final Color themeColor;

  PipeIsoPainter({
    required this.mode,
    required this.innerTab,
    required this.val1,
    required this.val2,
    required this.angle,
    required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final paint = Paint()
      ..color = themeColor
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double startX = size.width * 0.15;
    final double midY = size.height * 0.55;

    double dynamicH = (val1 > 0 ? val1 : 50).clamp(20, 70).toDouble();
    double safeAngle = (angle > 0 ? angle : 45).clamp(10, 80).toDouble();
    double rad = safeAngle * (math.pi / 180);
    double runX = dynamicH / math.tan(rad);
    runX = runX.clamp(10, size.width * 0.5).toDouble();

    path.moveTo(startX, midY);

    if (mode == 0) {
      path.lineTo(size.width * 0.85, midY);
    } else if (mode == 1) {
      path.lineTo(size.width * 0.5, midY);
      path.arcToPoint(
        Offset(size.width * 0.5 + 40, midY - 40),
        radius: const Radius.circular(40),
        clockwise: false,
      );
      path.lineTo(size.width * 0.5 + 40, size.height * 0.1);
    } else if (mode == 2) {
      path.lineTo(size.width * 0.35, midY);
      path.lineTo(size.width * 0.35 + runX, midY - dynamicH);
      path.lineTo(size.width * 0.85, midY - dynamicH);
    } else if (mode == 3) {
      path.lineTo(size.width * 0.25, midY);
      if (innerTab == 0) {
        path.lineTo(size.width * 0.25 + runX, midY - dynamicH);
        path.lineTo(size.width * 0.25 + (runX * 2), midY);
      } else {
        double w = (val2 > 0 ? val2 : 30).clamp(10, 60).toDouble();
        path.lineTo(size.width * 0.25 + runX, midY - dynamicH);
        path.lineTo(size.width * 0.25 + runX + w, midY - dynamicH);
        path.lineTo(size.width * 0.25 + (runX * 2) + w, midY);
      }
      path.lineTo(size.width * 0.85, midY);
    } else if (mode == 4) {
      path.lineTo(size.width * 0.3, midY);
      path.lineTo(size.width * 0.3 + runX, midY - dynamicH + 15);
      path.lineTo(size.width * 0.85, midY - dynamicH + 15);
    }

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
  bool shouldRepaint(covariant PipeIsoPainter oldDelegate) {
    return oldDelegate.val1 != val1 ||
        oldDelegate.val2 != val2 ||
        oldDelegate.angle != angle ||
        oldDelegate.mode != mode ||
        oldDelegate.innerTab != innerTab;
  }
}
