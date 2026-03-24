// lib/src/presentation/remote/screens/mobile_remote_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// 💡 셋팅값을 불러오기 위해 SettingsManager 임포트
import 'package:tubing_calculator/src/core/utils/settings_manager.dart';
import '../widgets/remote_widgets.dart';

// 🎨 화이트 & 마키타 테마 컬러
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileRemotePage extends StatefulWidget {
  const MobileRemotePage({super.key});

  @override
  State<MobileRemotePage> createState() => _MobileRemotePageState();
}

class _MobileRemotePageState extends State<MobileRemotePage> {
  final PageController _pageController = PageController();

  int _currentMode = 0;
  bool _isTransmitting = false;

  // 💡 셋팅값을 동적으로 받을 변수
  String _serverRadius = "불러오는 중...";

  final List<Map<String, dynamic>> _modes = [
    {
      "key": "STRAIGHT",
      "name": "직관 (Straight)",
      "color": const Color(0xFF4A5D66),
    },
    {"key": "BEND_90", "name": "90° 벤딩", "color": const Color(0xFF00606B)},
    {"key": "OFFSET", "name": "오프셋", "color": const Color(0xFF8A6345)},
    {"key": "SADDLE", "name": "새들", "color": const Color(0xFF635666)},
    {"key": "ROLLING", "name": "롤링 오프셋", "color": const Color(0xFF3B5E52)},
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

    // 💡 초기화 시 셋팅값 불러오기
    _loadRadiusSetting();
  }

  // 💡 SettingsManager에서 금형 반경(CLR) 값을 불러오는 함수
  Future<void> _loadRadiusSetting() async {
    try {
      final data = await SettingsManager.loadSettings();
      if (mounted) {
        setState(() {
          double rValue = data['bendRadius'] ?? 45.0; // 값이 없으면 기본 45.0
          _serverRadius = rValue.toStringAsFixed(1);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _serverRadius = "N/A");
      }
    }
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

  void _safeUpdate(TextEditingController ctrl, String newVal) {
    if (ctrl.text != newVal) ctrl.text = newVal;
  }

  void _calculateDynamicValues() {
    int m = _currentMode;
    double val1 = double.tryParse(_val1Ctrls[m].text) ?? 0;
    double val2 = double.tryParse(_val2Ctrls[m].text) ?? 0;
    double angleInput = double.tryParse(_angleCtrls[m].text) ?? 0;

    if (m == 2) {
      double h = val1;
      if (_innerTabs[m] == 0) {
        double angle = angleInput;
        if (h > 0 && angle > 0 && angle < 90) {
          double sinVal = math.sin(angle * (math.pi / 180));
          if (sinVal != 0)
            _safeUpdate(_val2Ctrls[m], (h / sinVal).toStringAsFixed(1));
        } else if (angle == 0) {
          _safeUpdate(_val2Ctrls[m], "");
        }
      } else {
        double d = val2;
        if (h > 0 && d > 0 && d >= h) {
          _safeUpdate(
            _angleCtrls[m],
            (math.asin(h / d) * (180 / math.pi)).toStringAsFixed(1),
          );
        } else {
          _safeUpdate(_angleCtrls[m], "");
        }
      }
    } else if (m == 3) {
      double h = val1;
      double angle = angleInput;
      if (h > 0 && angle > 0 && angle < 90) {
        double sinVal = math.sin(angle * (math.pi / 180));
        if (sinVal != 0)
          _safeUpdate(_result1Ctrls[m], (h / sinVal).toStringAsFixed(1));
      } else {
        _safeUpdate(_result1Ctrls[m], "");
      }
    } else if (m == 4) {
      double h = val1;
      double roll = val2;
      double trueH = math.sqrt((h * h) + (roll * roll));

      if (h > 0 && roll > 0) {
        _safeUpdate(_result1Ctrls[m], trueH.toStringAsFixed(1));
      } else {
        _safeUpdate(_result1Ctrls[m], "");
      }

      if (_innerTabs[m] == 0) {
        double angle = angleInput;
        if (trueH > 0 && angle > 0 && angle < 90) {
          double sinVal = math.sin(angle * (math.pi / 180));
          if (sinVal != 0)
            _safeUpdate(_result2Ctrls[m], (trueH / sinVal).toStringAsFixed(1));
        } else {
          _safeUpdate(_result2Ctrls[m], "");
        }
      } else {
        double d = angleInput;
        if (trueH > 0 && d > 0 && d >= trueH) {
          double calcAngle = math.asin(trueH / d) * (180 / math.pi);
          _safeUpdate(_result2Ctrls[m], calcAngle.toStringAsFixed(1));
        } else {
          _safeUpdate(_result2Ctrls[m], "");
        }
      }
    }
  }

  void _onPageChanged(int modeIndex) {
    if (_isTransmitting) return;
    setState(() => _currentMode = modeIndex);
    _loadRadiusSetting(); // 💡 스와이프 할 때마다 최신 설정값 갱신
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
    if (m == 4) {
      if (_val2Ctrls[m].text.isEmpty) return false;
      if (_angleCtrls[m].text.isEmpty) return false;
    }
    return true;
  }

  Future<void> _sendData() async {
    if (_isTransmitting) return;
    HapticFeedback.heavyImpact();
    setState(() => _isTransmitting = true);

    int m = _currentMode;
    String sendVal1 = _val1Ctrls[m].text;
    String sendVal2 = "";
    String sendAngle = "";

    if (m == 0) {
      // STRAIGHT
    } else if (m == 1) {
      sendAngle = "90";
    } else if (m == 2) {
      if (_innerTabs[m] == 0) {
        sendAngle = _angleCtrls[m].text;
      } else {
        sendVal2 = _val2Ctrls[m].text;
        sendAngle = _angleCtrls[m].text;
      }
    } else if (m == 3) {
      if (_innerTabs[m] == 1) sendVal2 = _val2Ctrls[m].text;
      sendAngle = _angleCtrls[m].text;
    } else if (m == 4) {
      sendVal2 = _val2Ctrls[m].text;
      if (_innerTabs[m] == 0) {
        sendAngle = _angleCtrls[m].text;
      } else {
        sendVal1 = "${_val1Ctrls[m].text}|${_angleCtrls[m].text}";
        sendAngle = _result2Ctrls[m].text;
      }
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final newRecord = {
      "id": timestamp.toString(),
      "time":
          "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
      "mode": _modes[m]['key'],
      "modeName": _modes[m]['name'],
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
      const SnackBar(
        content: Text("서버로 데이터 전송 중..."),
        backgroundColor: makitaTeal,
        duration: Duration(seconds: 1),
      ),
    );

    try {
      await FirebaseFirestore.instance
          .collection('remote_commands')
          .doc(timestamp.toString())
          .set(newRecord);

      FirebaseFirestore.instance
          .collection('remote_commands')
          .doc(timestamp.toString())
          .snapshots()
          .listen((docSnapshot) {
            if (docSnapshot.exists &&
                docSnapshot.data()!['status'] == 'completed') {
              if (mounted) {
                setState(() {
                  var targetLog = _historyLogs.firstWhere(
                    (log) => log['id'] == timestamp.toString(),
                    orElse: () => <String, dynamic>{},
                  );
                  if (targetLog.isNotEmpty) targetLog['status'] = "completed";
                });
              }
            }
          });

      if (!mounted) return;
      HapticFeedback.mediumImpact();

      setState(() {
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
      backgroundColor: slate100,
      resizeToAvoidBottomInset: true,
      body: AbsorbPointer(
        absorbing: _isTransmitting,
        child: SafeArea(
          bottom: false,
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
                    builder: (context, child) => _build2DPreview(modeColor),
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
                  color: Colors.white.withValues(alpha: 0.6),
                  width: double.infinity,
                  height: double.infinity,
                  child: const Center(
                    child: CircularProgressIndicator(color: makitaTeal),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isTransmitting ? null : _showHistorySheet,
        backgroundColor: _isTransmitting ? Colors.grey.shade300 : pureWhite,
        elevation: 4,
        child: Icon(
          Icons.history,
          color: _isTransmitting ? Colors.grey.shade400 : slate900,
        ),
      ),
    );
  }

  Widget _buildHeader(Color modeColor) {
    return Container(
      height: 80,
      width: double.infinity,
      color: modeColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "좌우로 스와이프하여 모드 변경",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _modes[_currentMode]['name'],
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: pureWhite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _build2DPreview(Color modeColor) {
    int m = _currentMode;
    double val1 = double.tryParse(_val1Ctrls[m].text) ?? 50.0;
    double val2 = double.tryParse(_val2Ctrls[m].text) ?? 50.0;
    double angleInput = double.tryParse(_angleCtrls[m].text) ?? 45.0;
    double angle = (m == 4 && _innerTabs[m] == 1) ? 45.0 : angleInput;

    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: pureWhite,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: CustomPaint(
        painter: Preview2DPainter(
          mode: m,
          val1: val1 <= 0 ? 50 : val1,
          val2: val2 <= 0 ? 50 : val2,
          angle: angle,
          innerTab: _innerTabs[m],
          themeColor: modeColor,
          selectedDir: _selectedDirs[m],
        ),
      ),
    );
  }

  Widget _buildInputStep(int index) {
    var modeColor = _modes[index]['color'];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          if (index == 2)
            InnerTabSelector(
              tabs: const ["일반 오프셋", "오프셋 역산"],
              selectedIndex: _innerTabs[index],
              activeColor: modeColor,
              onTabSelected: (i) => setState(() {
                _innerTabs[index] = i;
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
                _val2Ctrls[index].clear();
                _angleCtrls[index].clear();
                _result1Ctrls[index].clear();
              }),
            ),
          if (index == 4)
            InnerTabSelector(
              tabs: const ["일반 롤링", "롤링 역산"],
              selectedIndex: _innerTabs[index],
              activeColor: modeColor,
              onTabSelected: (i) => setState(() {
                _innerTabs[index] = i;
                _angleCtrls[index].clear();
                _result2Ctrls[index].clear();
              }),
            ),
          const SizedBox(height: 24),
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
              backgroundColor: pureWhite,
              foregroundColor: modeColor,
              elevation: 0,
              side: BorderSide(color: modeColor, width: 2),
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "방향 설정으로 이동",
                  style: TextStyle(
                    fontSize: 18,
                    color: modeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward, color: modeColor, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  List<Widget> _buildDynamicInputs(int m, Color focusColor) {
    if (m == 0) return _buildStraightInputs(m, focusColor);
    if (m == 1) return _buildBend90Inputs(m, focusColor);
    if (m == 2) return _buildOffsetInputs(m, focusColor);
    if (m == 3) return _buildSaddleInputs(m, focusColor);
    if (m == 4) return _buildRollingInputs(m, focusColor);
    return [];
  }

  List<Widget> _buildStraightInputs(int m, Color color) {
    return [
      RemoteTextField(
        label: "직관 기장 (L)",
        ctrl: _val1Ctrls[m],
        currentFocus: _val1FocusNodes[m],
        focusColor: color,
      ),
    ];
  }

  List<Widget> _buildBend90Inputs(int m, Color color) {
    return [
      RemoteTextField(
        label: "기장 (L)",
        ctrl: _val1Ctrls[m],
        currentFocus: _val1FocusNodes[m],
        focusColor: color,
      ),
      const SizedBox(height: 20),
      _buildRadiusInfo(color),
    ];
  }

  List<Widget> _buildOffsetInputs(int m, Color color) {
    if (_innerTabs[m] == 0) {
      return [
        RemoteTextField(
          label: "단차 높이 (H)",
          ctrl: _val1Ctrls[m],
          currentFocus: _val1FocusNodes[m],
          focusColor: color,
          nextFocus: _angleFocusNodes[m],
        ),
        const SizedBox(height: 20),
        RemoteTextField(
          label: "벤딩 각도 (θ)",
          ctrl: _angleCtrls[m],
          currentFocus: _angleFocusNodes[m],
          focusColor: color,
          showQuickAngles: true,
        ),
        const SizedBox(height: 20),
        RemoteReadOnlyField(
          label: "자동 계산된 대각 길이 (D)",
          ctrl: _val2Ctrls[m],
          textColor: Colors.blue.shade700,
        ),
      ];
    } else {
      return [
        RemoteTextField(
          label: "단차 높이 (H)",
          ctrl: _val1Ctrls[m],
          currentFocus: _val1FocusNodes[m],
          focusColor: color,
          nextFocus: _val2FocusNodes[m],
        ),
        const SizedBox(height: 20),
        RemoteTextField(
          label: "대각 길이 (D)",
          ctrl: _val2Ctrls[m],
          currentFocus: _val2FocusNodes[m],
          focusColor: color,
        ),
        const SizedBox(height: 20),
        RemoteReadOnlyField(
          label: "자동 계산된 각도 (θ)",
          ctrl: _angleCtrls[m],
          textColor: Colors.green.shade700,
        ),
      ];
    }
  }

  List<Widget> _buildSaddleInputs(int m, Color color) {
    List<Widget> inputs = [
      RemoteTextField(
        label: "장애물 높이 (H)",
        ctrl: _val1Ctrls[m],
        currentFocus: _val1FocusNodes[m],
        focusColor: color,
        nextFocus: _innerTabs[m] == 1
            ? _val2FocusNodes[m]
            : _angleFocusNodes[m],
      ),
      const SizedBox(height: 20),
    ];
    if (_innerTabs[m] == 1) {
      inputs.add(
        RemoteTextField(
          label: "장애물 폭 (W)",
          ctrl: _val2Ctrls[m],
          currentFocus: _val2FocusNodes[m],
          focusColor: color,
          nextFocus: _angleFocusNodes[m],
        ),
      );
      inputs.add(const SizedBox(height: 20));
    }
    inputs.addAll([
      RemoteTextField(
        label: "벤딩 각도 (θ)",
        ctrl: _angleCtrls[m],
        currentFocus: _angleFocusNodes[m],
        focusColor: color,
        showQuickAngles: true,
      ),
      const SizedBox(height: 20),
      RemoteReadOnlyField(
        label: "자동 계산된 마킹 간격 (D)",
        ctrl: _result1Ctrls[m],
        textColor: Colors.orange.shade700,
      ),
    ]);
    return inputs;
  }

  List<Widget> _buildRollingInputs(int m, Color color) {
    bool isReverse = _innerTabs[m] == 1;
    return [
      RemoteTextField(
        label: "수직 단차 (H)",
        ctrl: _val1Ctrls[m],
        currentFocus: _val1FocusNodes[m],
        focusColor: color,
        nextFocus: _val2FocusNodes[m],
      ),
      const SizedBox(height: 20),
      RemoteTextField(
        label: "수평 롤 (Roll)",
        ctrl: _val2Ctrls[m],
        currentFocus: _val2FocusNodes[m],
        focusColor: color,
        nextFocus: _angleFocusNodes[m],
      ),
      const SizedBox(height: 20),
      RemoteReadOnlyField(
        label: "자동 계산된 진단차 (True H)",
        ctrl: _result1Ctrls[m],
        textColor: Colors.purple.shade700,
      ),
      const SizedBox(height: 20),
      RemoteTextField(
        label: isReverse ? "대각 길이 (D) 입력" : "벤딩 각도 (θ) 입력",
        ctrl: _angleCtrls[m],
        currentFocus: _angleFocusNodes[m],
        focusColor: color,
        showQuickAngles: !isReverse,
      ),
      const SizedBox(height: 20),
      RemoteReadOnlyField(
        label: isReverse ? "자동 계산된 각도 (θ)" : "자동 계산된 대각 길이 (D)",
        ctrl: _result2Ctrls[m],
        textColor: isReverse ? Colors.green.shade700 : Colors.blue.shade700,
      ),
    ];
  }

  // 💡 [수정] 수동/자동 갱신이 가능한 연동 반경 정보 위젯
  Widget _buildRadiusInfo(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: slate100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.link, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "태블릿 연동 반경(R): $_serverRadius mm",
              style: const TextStyle(
                color: slate600,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 22, color: slate600),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadRadiusSetting();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("연동 반경 값을 최신화했습니다."),
                  backgroundColor: makitaTeal,
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
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
            color: slate900,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: DirectionSelector(
            selectedDir: _selectedDirs[index],
            modeColor: modeColor,
            onDirSelected: (dir) => setState(() {
              _selectedDirs[index] = dir;
            }),
          ),
        ),
        const SizedBox(height: 40),
        TextButton.icon(
          onPressed: () => setState(() => _isInputFinishedList[index] = false),
          icon: const Icon(Icons.edit, color: slate600),
          label: const Text(
            "수치 입력으로 돌아가기",
            style: TextStyle(color: slate600, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton(Color modeColor) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: pureWhite,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: ElevatedButton(
          onPressed: (_isInputFinishedList[_currentMode] && !_isTransmitting)
              ? _sendData
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: modeColor,
            disabledBackgroundColor: Colors.grey.shade300,
            minimumSize: const Size.fromHeight(60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isTransmitting
              ? const CircularProgressIndicator(color: pureWhite)
              : Text(
                  _isInputFinishedList[_currentMode]
                      ? "태블릿으로 데이터 전송"
                      : "수치를 입력하세요",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _isInputFinishedList[_currentMode]
                        ? pureWhite
                        : Colors.grey.shade600,
                  ),
                ),
        ),
      ),
    );
  }

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                "전송 기록 (태블릿 전송 데이터)",
                style: TextStyle(
                  color: slate900,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _historyLogs.isEmpty
                    ? const Center(
                        child: Text(
                          "기록이 없습니다.",
                          style: TextStyle(color: slate600),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _historyLogs.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
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
                              backgroundColor: Color(log['color']),
                              radius: 16,
                              child: const Icon(
                                Icons.check,
                                color: pureWhite,
                                size: 16,
                              ),
                            ),
                            title: Text(
                              "${log['modeName']} (${log['dir']})",
                              style: const TextStyle(
                                color: slate900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              subtitleText,
                              style: const TextStyle(
                                color: slate600,
                                fontSize: 13,
                              ),
                            ),
                            trailing: Icon(
                              isCompleted ? Icons.check_circle : Icons.schedule,
                              color: isCompleted
                                  ? Colors.green.shade600
                                  : Colors.orange.shade600,
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

class Preview2DPainter extends CustomPainter {
  final int mode;
  final double val1;
  final double val2;
  final double angle;
  final int innerTab;
  final Color themeColor;
  final String selectedDir;

  Preview2DPainter({
    required this.mode,
    required this.val1,
    required this.val2,
    required this.angle,
    required this.innerTab,
    required this.themeColor,
    required this.selectedDir,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = themeColor
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shadowPaint = Paint()
      ..color = themeColor.withValues(alpha: 0.2)
      ..strokeWidth = 14.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    List<Offset> pts = [];
    double h = val1;
    double w = val2;
    double safeAngle = (angle <= 0 || angle >= 90) ? 45.0 : angle;
    double rad = safeAngle * math.pi / 180.0;

    if (mode == 0) {
      pts = [const Offset(0, 0), Offset(h, 0)];
    } else if (mode == 1) {
      pts = [Offset(0, h), const Offset(0, 0), Offset(h, 0)];
    } else if (mode == 2) {
      double travelX = h / math.tan(rad);
      double straightBase = math.max(20.0, travelX * 0.3);
      pts = [
        Offset(0, h),
        Offset(straightBase, h),
        Offset(straightBase + travelX, 0),
        Offset(straightBase * 2 + travelX, 0),
      ];
    } else if (mode == 3) {
      double travelX = h / math.tan(rad);
      double straightBase = math.max(20.0, travelX * 0.3);
      if (innerTab == 0) {
        pts = [
          Offset(0, h),
          Offset(straightBase, h),
          Offset(straightBase + travelX, 0),
          Offset(straightBase + travelX * 2, h),
          Offset(straightBase * 2 + travelX * 2, h),
        ];
      } else {
        pts = [
          Offset(0, h),
          Offset(straightBase, h),
          Offset(straightBase + travelX, 0),
          Offset(straightBase + travelX + w, 0),
          Offset(straightBase + travelX * 2 + w, h),
          Offset(straightBase * 2 + travelX * 2 + w, h),
        ];
      }
    } else if (mode == 4) {
      double trueH = math.sqrt((h * h) + (w * w));
      double travelX = trueH / math.tan(rad);
      double straightBase = math.max(20.0, travelX * 0.3);
      pts = [
        Offset(0, trueH),
        Offset(straightBase, trueH),
        Offset(straightBase + travelX, 0),
        Offset(straightBase * 2 + travelX, 0),
      ];
    }

    if (pts.isEmpty) return;

    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (var p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    double drawW = maxX - minX == 0 ? 100 : maxX - minX;
    double drawH = maxY - minY == 0 ? 100 : maxY - minY;

    double scale = math.min(
      (size.width * 0.8) / drawW,
      (size.height * 0.6) / drawH,
    );
    scale = scale.clamp(0.1, 10.0);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);

    if (selectedDir == "DOWN") canvas.scale(1, -1);
    if (selectedDir == "LEFT") canvas.scale(-1, 1);

    List<Offset> finalPoints = pts.map((p) {
      return Offset(
        (p.dx - (minX + maxX) / 2) * scale,
        (p.dy - (minY + maxY) / 2) * scale,
      );
    }).toList();

    final path = Path();
    for (int i = 0; i < finalPoints.length; i++) {
      if (i == 0)
        path.moveTo(finalPoints[i].dx, finalPoints[i].dy);
      else
        path.lineTo(finalPoints[i].dx, finalPoints[i].dy);
    }

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant Preview2DPainter oldDelegate) {
    return oldDelegate.mode != mode ||
        oldDelegate.val1 != val1 ||
        oldDelegate.val2 != val2 ||
        oldDelegate.angle != angle ||
        oldDelegate.innerTab != innerTab ||
        oldDelegate.selectedDir != selectedDir;
  }
}
