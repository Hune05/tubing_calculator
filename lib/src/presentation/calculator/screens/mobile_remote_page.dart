// lib/src/presentation/remote/screens/mobile_remote_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

// 💡 셋팅값을 불러오기 위해 SettingsManager 임포트
import 'package:tubing_calculator/src/core/utils/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/profile/profile_tools.dart'
    show currentUid;
import '../remote_math.dart';
import '../widgets/remote_widgets.dart';

// 🎨 화이트 & 마키타 테마 컬러
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF191F28); // 토스 스타일의 부드러운 검정
const Color slate600 = Color(0xFF5F6B78); // 토스 스타일의 세련된 회색
const Color slate100 = Color(0xFFF2F4F6); // 토스 스타일의 배경 회색
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

  // 보낸 사람 이름. 태블릿·PC는 같은 이름이 보낸 명령만 받는다.
  String _senderName = '';
  // 보낸 명령의 결과(태블릿 반영)를 기다리는 듣기. 화면을 나가면 닫는다.
  final List<StreamSubscription> _resultSubs = [];

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

    _loadRadiusSetting();
    _loadSenderName();
  }

  Future<void> _loadSenderName() async {
    try {
      final p = await SharedPreferences.getInstance();
      final n = (p.getString('user_real_name') ?? '').trim();
      if (mounted) setState(() => _senderName = n == '로그인 필요' ? '' : n);
    } catch (_) {}
  }

  Future<void> _loadRadiusSetting() async {
    try {
      final data = await SettingsManager.loadSettings();
      if (mounted) {
        setState(() {
          double rValue = data['bendRadius'] ?? 45.0;
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
    for (final sub in _resultSubs) {
      sub.cancel();
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
          if (sinVal != 0) {
            _safeUpdate(_val2Ctrls[m], (h / sinVal).toStringAsFixed(1));
          }
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
        // 🚀 3-Point 새들(원형 배관)은 중심각의 절반(사이드 각)을 기준으로 계산해야 함.
        // 4-Point는 각도를 그대로 사용. (mobile_saddle_bottom_sheet.dart의 공식과 일치시킴)
        double effectiveAngle = _innerTabs[m] == 0 ? angle / 2 : angle;
        double sinVal = math.sin(effectiveAngle * (math.pi / 180));
        if (sinVal != 0) {
          _safeUpdate(_result1Ctrls[m], (h / sinVal).toStringAsFixed(1));
        }
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
          if (sinVal != 0) {
            _safeUpdate(_result2Ctrls[m], (trueH / sinVal).toStringAsFixed(1));
          }
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
    _loadRadiusSetting();
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

  /// 지금 모드에서 보낼 값(높이·폭/이동/롤·각도). 확인과 보내기가 같이 쓴다.
  ({String val1, String val2, String angle}) _sendValues(int m) {
    String v1 = _val1Ctrls[m].text;
    String v2 = "";
    String a = "";
    if (m == 1) {
      a = "90";
    } else if (m == 2) {
      // 오프셋은 높이와 각도만 보낸다. 이동 길이로 넣었으면(역산) 폰이 셈한 각도를
      // 보낸다 — 화면 글(소수 한 자리)이 아니라 셈 값 그대로 보내 이동 길이가 어긋나지 않게.
      if (_innerTabs[m] == 1) {
        final h = double.tryParse(v1) ?? 0;
        final d = double.tryParse(_val2Ctrls[m].text) ?? 0;
        a = (h > 0 && d >= h)
            ? (math.asin(h / d) * 180 / math.pi).toStringAsFixed(4)
            : "";
      } else {
        a = _angleCtrls[m].text;
      }
    } else if (m == 3) {
      if (_innerTabs[m] == 1) v2 = _val2Ctrls[m].text;
      a = _angleCtrls[m].text;
    } else if (m == 4) {
      v2 = _val2Ctrls[m].text;
      a = _innerTabs[m] == 0 ? _angleCtrls[m].text : _result2Ctrls[m].text;
    }
    return (val1: v1, val2: v2, angle: a);
  }

  /// 새들 3점(원형)=안쪽 탭 0, 4점=탭 1.
  int _saddlePoints(int m) => _innerTabs[m] == 0 ? 3 : 4;

  /// 보낼 수 없는 값이면 까닭(태블릿과 같은 셈으로 본다).
  String? _sendProblem(int m) {
    final v = _sendValues(m);
    // 오프셋 역산은 이동 길이를 보내지 않지만, "이동이 높이보다 짧다"를 알려 주려고
    // 확인할 때는 넣은 이동 길이도 같이 본다.
    final checkVal2 = (m == 2 && _innerTabs[m] == 1)
        ? _val2Ctrls[m].text
        : v.val2;
    return remoteInputProblem(
      mode: _modes[m]['key'] as String,
      val1: double.tryParse(v.val1) ?? 0,
      val2: double.tryParse(checkVal2) ?? 0,
      angle: double.tryParse(v.angle) ?? 0,
      saddlePoints: _saddlePoints(m),
    );
  }

  void _setLogStatus(String id, String status, [String? why]) {
    if (!mounted) return;
    setState(() {
      final log = _historyLogs.firstWhere(
        (l) => l['id'] == id,
        orElse: () => <String, dynamic>{},
      );
      if (log.isNotEmpty) {
        log['status'] = status;
        if (why != null) log['reason'] = why;
      }
    });
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendData() async {
    if (_isTransmitting) return;
    int m = _currentMode;

    final problem = _sendProblem(m);
    if (problem != null) {
      _snack(problem, Colors.red.shade700);
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() => _isTransmitting = true);

    final v = _sendValues(m);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = timestamp.toString();

    final newRecord = <String, dynamic>{
      "id": id,
      "time":
          "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
      "mode": _modes[m]['key'],
      "modeName": _modes[m]['name'],
      "color": _modes[m]['color'].value,
      "val1": v.val1,
      "val2": v.val2,
      "angle": v.angle,
      "dir": _selectedDirs[m],
      if (m == 3) "saddlePoints": _saddlePoints(m),
      "status": "pending",
      "timestamp": timestamp,
    };

    final db = FirebaseFirestore.instance;
    final ref = db.collection('remote_commands').doc(id);

    // 1) 통신 확인. 통신이 없는데 쓰면 폰에 쌓였다가 나중에(엉뚱한 때) 태블릿에서
    //    실행될 수 있고, 예전엔 "전송 중" 장막이 영영 안 걷혔다.
    try {
      await db
          .collection('remote_commands')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isTransmitting = false);
      _snack("통신이 없어 보내지 않았습니다. 폰과 태블릿 모두 통신이 있어야 합니다.", Colors.red.shade700);
      return;
    }

    if (!mounted) return;
    setState(() => _historyLogs.insert(0, newRecord));

    // 2) 보내기
    try {
      await ref
          .set({
            ...newRecord,
            // 태블릿·PC는 같은 이름이 보낸 것만 받는다.
            if (_senderName.isNotEmpty) "sender": _senderName,
            if (currentUid() != null) "uid": currentUid(),
            "sentAt": FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTransmitting = false);
      _setLogStatus(id, "failed", "보내지 못함");
      _snack("보내지 못했습니다. 통신을 확인하십시오.", Colors.red.shade700);
      return;
    }

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
    _snack("보냈습니다. 태블릿 반영을 기다립니다.", makitaTeal);

    // 3) 태블릿이 넣었는지 기다린다(완료·실패·응답 없음).
    StreamSubscription? sub;
    Timer? timer;
    void finish() {
      timer?.cancel();
      sub?.cancel();
      _resultSubs.remove(sub);
    }

    final listening = ref.snapshots().listen((snap) {
      final data = snap.data();
      final status = data?['status'];
      if (status == 'completed') {
        finish();
        _setLogStatus(id, "completed");
        _snack("태블릿에 들어갔습니다.", Colors.green.shade700);
      } else if (status == 'failed') {
        finish();
        final why = (data?['reason'] ?? '').toString();
        _setLogStatus(id, "failed", why.isEmpty ? null : why);
        _snack(
          why.isEmpty ? "태블릿이 넣지 못했습니다." : "태블릿이 넣지 못했습니다: $why",
          Colors.red.shade700,
        );
      }
    }, onError: (_) {});
    sub = listening;
    _resultSubs.add(listening);
    timer = Timer(const Duration(seconds: 12), () {
      finish();
      _setLogStatus(id, "no_response", "태블릿 응답 없음");
      // 나중에 태블릿이 열려도 실행되지 않게 표시해 둔다.
      ref.update({'status': 'expired'}).catchError((_) {});
      _snack(
        "태블릿이 받지 않았습니다. 계산기 화면이 열려 있는지, 같은 이름으로 쓰는지 확인하십시오.",
        Colors.orange.shade800,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    var modeColor = _modes[_currentMode]['color'];

    return Scaffold(
      backgroundColor: pureWhite, // 전체 배경 흰색 통일
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
                  color: pureWhite.withValues(alpha: 0.8), // 투명도 있는 하얀 장막
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
    );
  }

  // 🌟 토스 감성: 크고 시원한 헤더
  Widget _buildHeader(Color modeColor) {
    // 높이를 110으로 묶어 두면 글씨를 크게 한 폰에서 아래가 넘쳤다. 최소 높이만 둔다.
    return Container(
      constraints: const BoxConstraints(minHeight: 110),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      width: double.infinity,
      color: modeColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "좌우로 스와이프하여 모드 변경",
            style: TextStyle(
              color: pureWhite.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _modes[_currentMode]['name'],
              style: const TextStyle(
                fontSize: 30, // 폰트 크기 확대
                fontWeight: FontWeight.w900, // 폰트 굵기 극대화
                letterSpacing: -0.5, // 세련된 자간
                color: pureWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 프리뷰: 밑줄 제거, 깨끗한 여백
  Widget _build2DPreview(Color modeColor) {
    int m = _currentMode;
    double val1 = double.tryParse(_val1Ctrls[m].text) ?? 50.0;
    double val2 = double.tryParse(_val2Ctrls[m].text) ?? 50.0;
    double angleInput = double.tryParse(_angleCtrls[m].text) ?? 45.0;
    double angle = (m == 4 && _innerTabs[m] == 1) ? 45.0 : angleInput;

    return Container(
      height: 160,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: pureWhite,
        // 거슬리던 Border 제거
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

  // 🌟 입력 영역: 입력창 사이의 광활한 여백 (SizedBox 32 적용)
  Widget _buildInputStep(int index) {
    var modeColor = _modes[index]['color'];
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 32,
      ), // 패딩 빵빵하게
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
          const SizedBox(height: 32), // 여백 확장
          ..._buildDynamicInputs(index, modeColor),
          const SizedBox(height: 48), // 여백 확장
          ElevatedButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              if (!_validateInputs()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      "필수 수치를 입력해 주십시오!",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.redAccent.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                HapticFeedback.lightImpact();
                return;
              }
              // 태블릿과 같은 셈으로 미리 본다(예: 이동이 높이보다 짧은 오프셋).
              final problem = _sendProblem(index);
              if (problem != null) {
                _snack(problem, Colors.redAccent.shade700);
                HapticFeedback.lightImpact();
                return;
              }
              setState(() => _isInputFinishedList[index] = true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: pureWhite,
              foregroundColor: modeColor,
              elevation: 0,
              side: BorderSide(color: modeColor, width: 2), // 얇은 선보다 확실한 굵기
              minimumSize: const Size.fromHeight(60), // 버튼 키우기
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16), // 완전 둥글게
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: modeColor, size: 24),
              ],
            ),
          ),
          const SizedBox(height: 24),
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

  // 🌟 입력 필드 간 간격을 32로 통일
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
      const SizedBox(height: 32),
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
        const SizedBox(height: 32),
        RemoteTextField(
          label: "벤딩 각도 (θ)",
          ctrl: _angleCtrls[m],
          currentFocus: _angleFocusNodes[m],
          focusColor: color,
          showQuickAngles: true,
        ),
        const SizedBox(height: 32),
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
        const SizedBox(height: 32),
        RemoteTextField(
          label: "대각 길이 (D)",
          ctrl: _val2Ctrls[m],
          currentFocus: _val2FocusNodes[m],
          focusColor: color,
        ),
        const SizedBox(height: 32),
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
      const SizedBox(height: 32),
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
      inputs.add(const SizedBox(height: 32));
    }
    inputs.addAll([
      RemoteTextField(
        label: "벤딩 각도 (θ)",
        ctrl: _angleCtrls[m],
        currentFocus: _angleFocusNodes[m],
        focusColor: color,
        showQuickAngles: true,
      ),
      const SizedBox(height: 32),
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
        label: "수직 높이 (H)",
        ctrl: _val1Ctrls[m],
        currentFocus: _val1FocusNodes[m],
        focusColor: color,
        nextFocus: _val2FocusNodes[m],
      ),
      const SizedBox(height: 32),
      RemoteTextField(
        label: "수평 롤 (Roll)",
        ctrl: _val2Ctrls[m],
        currentFocus: _val2FocusNodes[m],
        focusColor: color,
        nextFocus: _angleFocusNodes[m],
      ),
      const SizedBox(height: 32),
      RemoteReadOnlyField(
        label: "진단차 (True H) - 자동 계산",
        ctrl: _result1Ctrls[m],
        textColor: Colors.purple.shade700,
      ),
      const SizedBox(height: 32),
      if (!isReverse) ...[
        RemoteTextField(
          label: "벤딩 각도 (θ) 입력",
          ctrl: _angleCtrls[m],
          currentFocus: _angleFocusNodes[m],
          focusColor: color,
          showQuickAngles: true,
        ),
        const SizedBox(height: 32),
        RemoteReadOnlyField(
          label: "마킹 간격 (D) - 자동 계산",
          ctrl: _result2Ctrls[m],
          textColor: Colors.blue.shade700,
        ),
      ] else ...[
        RemoteTextField(
          label: "마킹 간격 (D) 입력",
          ctrl: _angleCtrls[m],
          currentFocus: _angleFocusNodes[m],
          focusColor: color,
          showQuickAngles: false,
        ),
        const SizedBox(height: 32),
        RemoteReadOnlyField(
          label: "벤딩 각도 (θ) - 자동 계산",
          ctrl: _result2Ctrls[m],
          textColor: Colors.green.shade700,
        ),
      ],
    ];
  }

  // 🌟 토스 감성: 둥글고 선 없는 박스
  Widget _buildRadiusInfo(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: slate100, // 배경으로만 구분
        borderRadius: BorderRadius.circular(16), // 완전 둥글게
        // 거슬리는 border 제거
      ),
      child: Row(
        children: [
          Icon(Icons.link_rounded, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "태블릿 연동 금형 반경(R): $_serverRadius mm",
              style: const TextStyle(
                color: slate900,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 24, color: slate600),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadRadiusSetting();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "연동 반경 값을 최신화했습니다.",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: makitaTeal,
                  behavior: SnackBarBehavior.floating,
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
          "어느 방향으로 꺾으시겠습니까?", // 문구 부드럽게
          style: TextStyle(
            fontSize: 22,
            color: slate900,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 48), // 여백 빵빵하게
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
        const SizedBox(height: 56), // 여백 빵빵하게
        TextButton.icon(
          onPressed: () => setState(() => _isInputFinishedList[index] = false),
          icon: const Icon(Icons.edit_rounded, color: slate600),
          label: const Text(
            "수치 다시 입력하기",
            style: TextStyle(
              color: slate600,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // 🌟 하단 고정 버튼: 둥글고 거대한 버튼 (그림자로 살짝 띄우기)
  Widget _buildBottomButton(Color modeColor) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: pureWhite,
          // 상단 선 대신 은은한 그림자
          boxShadow: [
            BoxShadow(
              color: slate900.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        // 🚀 [고침] 기록 단추가 떠 있는 단추(FAB)라 작은 폰에서 이 단추 위에
        // 겹쳤다. 같은 줄 왼쪽에 둔다.
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: OutlinedButton(
                key: const Key('remote_history'),
                onPressed: _isTransmitting ? null : _showHistorySheet,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: const BorderSide(color: slate100, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Icon(
                  Icons.history,
                  color: _isTransmitting ? slate600 : slate900,
                  size: 28,
                  semanticLabel: "전송 기록",
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                key: const Key('remote_send'),
                onPressed:
                    (_isInputFinishedList[_currentMode] && !_isTransmitting)
                    ? _sendData
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: modeColor,
                  disabledBackgroundColor: slate100, // 토스식 비활성 색상
                  disabledForegroundColor: slate600,
                  minimumSize: const Size.fromHeight(64), // 버튼 더 크게
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16), // 완전 둥글게
                  ),
                ),
                child: _isTransmitting
                    ? const CircularProgressIndicator(color: pureWhite)
                    // 좁은 폰에서 "주십시/오"처럼 끊기지 않게 한 줄로 줄여 넣는다.
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isInputFinishedList[_currentMode]
                              ? "태블릿으로 전송하기"
                              : "수치를 먼저 넣으십시오",
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _isInputFinishedList[_currentMode]
                                ? pureWhite
                                : slate600,
                          ),
                        ),
                      ),
              ),
            ),
          ],
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
                  color: slate100, // 연하게
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                "최근 전송 기록",
                style: TextStyle(
                  color: slate900,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _historyLogs.isEmpty
                    ? const Center(
                        child: Text(
                          "아직 전송한 기록이 없습니다.",
                          style: TextStyle(
                            color: slate600,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _historyLogs.length,
                        // 🌟 Divider를 아주 연하게
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: slate100,
                          indent: 24,
                          endIndent: 24,
                        ),
                        itemBuilder: (context, index) {
                          var log = _historyLogs[index];
                          bool isCompleted = log['status'] == 'completed';
                          bool isFailed =
                              log['status'] == 'failed' ||
                              log['status'] == 'no_response';
                          final Color leadColor = isCompleted
                              ? Color(log['color'])
                              : isFailed
                              ? Colors.red.shade600
                              : Colors.orange.shade600;

                          String subtitleText = "H/L: ${log['val1']}";
                          if (log['val2'] != "") {
                            subtitleText += " / W/D/Roll: ${log['val2']}";
                          }
                          if (log['angle'] != "") {
                            subtitleText += " / 각도: ${log['angle']}°";
                          }
                          if ((log['reason'] ?? '').toString().isNotEmpty) {
                            subtitleText += "\n${log['reason']}";
                          }

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ), // 패딩 넉넉하게
                            // 🚀 [고침] 앞 아이콘이 늘 ✓라 실패한 전송도 된 것처럼
                            // 보였다. 뒤 아이콘과 같이 상태를 따른다.
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: leadColor.withValues(
                                  alpha: 0.1,
                                ), // 배경을 투명하게
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCompleted
                                    ? Icons.check_rounded
                                    : isFailed
                                    ? Icons.error_outline_rounded
                                    : Icons.schedule_rounded,
                                key: const Key('remote_log_lead'),
                                color: leadColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              "${log['modeName']} (${log['dir']})",
                              style: const TextStyle(
                                color: slate900,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                "$subtitleText\n${log['time']}",
                                style: const TextStyle(
                                  color: slate600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            trailing: Icon(
                              isCompleted
                                  ? Icons.check_circle_rounded
                                  : isFailed
                                  ? Icons.error_outline_rounded
                                  : Icons.schedule_rounded,
                              color: isCompleted
                                  ? Colors.green.shade600
                                  : isFailed
                                  ? Colors.red.shade600
                                  : Colors.orange.shade600,
                              size: 28,
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
      ..color = themeColor
          .withValues(alpha: 0.15) // 그림자도 더 부드럽게
      ..strokeWidth =
          16.0 // 살짝 더 두껍게 해서 네온사인처럼
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
      if (i == 0) {
        path.moveTo(finalPoints[i].dx, finalPoints[i].dy);
      } else {
        path.lineTo(finalPoints[i].dx, finalPoints[i].dy);
      }
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
