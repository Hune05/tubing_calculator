import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

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

  // ★ 추가됨: 서버/태블릿에서 읽어온 설정값을 시뮬레이션하는 변수
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

  // 입력 컨트롤러
  final TextEditingController _val1Ctrl = TextEditingController();
  final TextEditingController _val2Ctrl = TextEditingController();
  final TextEditingController _angleCtrl = TextEditingController();

  // 포커스 노드 (자동 포커스 이동용)
  final FocusNode _val1Focus = FocusNode();
  final FocusNode _val2Focus = FocusNode();
  final FocusNode _angleFocus = FocusNode();

  final List<Map<String, dynamic>> _historyLogs = [];

  @override
  void dispose() {
    _val1Ctrl.dispose();
    _val2Ctrl.dispose();
    _angleCtrl.dispose();
    _val1Focus.dispose();
    _val2Focus.dispose();
    _angleFocus.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _resetState(int modeIndex) {
    setState(() {
      _currentMode = modeIndex;
      _innerTab = 0;
      _isInputFinished = false;
      _val1Ctrl.clear();
      _val2Ctrl.clear();
      _angleCtrl.clear();
    });
  }

  bool _validateInputs() {
    // 모든 모드에서 val1(기장, 단차, 높이 등)은 필수
    if (_val1Ctrl.text.isEmpty) return false;

    // ★ 수정됨: 90도 벤딩(mode == 1)일 때는 반경(val2) 검증을 생략함
    if (_currentMode == 2 && _angleCtrl.text.isEmpty) return false;
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
    HapticFeedback.heavyImpact();

    String finalAngle = (_currentMode == 1) ? "90" : _angleCtrl.text;
    // 90도 벤딩의 경우, 서버 연동 반경값을 기록에 남기도록 처리
    String finalVal2 = (_currentMode == 1) ? _serverRadius : _val2Ctrl.text;

    final newRecord = {
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "time":
          "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
      "mode": _modes[_currentMode]['name'],
      "color": _modes[_currentMode]['color'],
      "val1": _val1Ctrl.text,
      "val2": finalVal2,
      "angle": finalAngle,
      "dir": _selectedDir,
      "status": "pending",
    };

    setState(() {
      _historyLogs.insert(0, newRecord);
      _isInputFinished = false;
      _val1Ctrl.clear();
      _val2Ctrl.clear();
      _angleCtrl.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("데이터를 전송 큐에 담았습니다."),
        backgroundColor: Colors.grey.shade800,
        duration: const Duration(seconds: 1),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        var target = _historyLogs.firstWhere(
          (log) => log['id'] == newRecord['id'],
        );
        target['status'] = "completed";
      });
      HapticFeedback.mediumImpact();
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
                "전송 기록 (대조용)",
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
                              "수치1: ${log['val1']} / 수치2: ${log['val2']} / 각도: ${log['angle']}°  •  ${log['time']}",
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
                    ),
                  ),
                ],
              ),
            ),

            // [아이솔 형상 미리보기]
            AnimatedBuilder(
              animation: Listenable.merge([_val1Ctrl, _val2Ctrl, _angleCtrl]),
              builder: (context, child) => _buildIsoPreview(modeColor),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showHistorySheet,
        backgroundColor: inputBg,
        child: const Icon(Icons.history, color: Colors.white),
      ),
    );
  }

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
          if (index == 2) _buildInnerTabs(["일반 오프셋", "역산 (관 간격)"], modeColor),
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
      // ★ 수정됨: 90도 벤딩일 경우 L값만 필수 입력, R값은 연동된 데이터 표기
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
      inputs.add(
        _buildTextField(
          _innerTab == 0 ? "단차 높이 (H)" : "관 간격 (T)",
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
    }
    return inputs;
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
            children: [30, 45, 60, 90]
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

    final double startX = size.width * 0.1;
    final double midY = size.height * 0.5;
    double dynamicH = (val1 > 0 ? val1 : 50).clamp(20, 80).toDouble();
    double dynamicAngleX = (angle > 0 ? angle : 45).clamp(10, 80).toDouble();

    path.moveTo(startX, midY);

    if (mode == 0) {
      path.lineTo(size.width * 0.9, midY);
    } else if (mode == 1) {
      path.lineTo(size.width * 0.5, midY);
      path.arcToPoint(
        Offset(size.width * 0.5 + 40, midY - 40),
        radius: const Radius.circular(40),
        clockwise: false,
      );
      path.lineTo(size.width * 0.5 + 40, size.height * 0.1);
    } else if (mode == 2) {
      path.lineTo(size.width * 0.4, midY);
      path.lineTo(size.width * 0.4 + dynamicAngleX, midY - dynamicH);
      path.lineTo(size.width * 0.9, midY - dynamicH);
    } else if (mode == 3) {
      path.lineTo(size.width * 0.3, midY);
      if (innerTab == 0) {
        path.lineTo(size.width * 0.5, midY - dynamicH);
        path.lineTo(size.width * 0.7, midY);
      } else {
        double w = (val2 > 0 ? val2 : 30).clamp(10, 50).toDouble();
        path.lineTo(size.width * 0.4, midY - dynamicH);
        path.lineTo(size.width * 0.4 + w, midY - dynamicH);
        path.lineTo(size.width * 0.4 + w + (size.width * 0.1), midY);
      }
      path.lineTo(size.width * 0.9, midY);
    } else if (mode == 4) {
      path.lineTo(size.width * 0.3, midY);
      path.lineTo(size.width * 0.6, midY - dynamicH + 20);
      path.lineTo(size.width * 0.9, midY - dynamicH + 20);
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
