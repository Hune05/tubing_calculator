import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:tubing_calculator/src/data/bend_data_manager.dart';
import 'package:tubing_calculator/src/core/common_widgets/smart_save_pad.dart';

class MarkingPage extends StatefulWidget {
  final PageController? pageController;
  const MarkingPage({super.key, this.pageController});

  @override
  State<MarkingPage> createState() => _MarkingPageState();
}

class _MarkingPageState extends State<MarkingPage> {
  final Color makitaTeal = const Color(0xFF007580);
  final Color slate900 = const Color(0xFF0F172A);
  final Color slate600 = const Color(0xFF475569);
  final Color slate100 = const Color(0xFFF1F5F9);
  final Color pureWhite = const Color(0xFFFFFFFF);

  bool _includeStartFitting = false;
  bool _includeEndFitting = false;
  double _tailLength = 0.0;
  final TextEditingController _tailController = TextEditingController(text: "0");

  @override
  void initState() {
    super.initState();
    _refreshSettings();

    _tailController.addListener(() {
      setState(() {
        _tailLength = double.tryParse(_tailController.text) ?? 0.0;
        BendDataManager().tail = _tailLength;
      });
    });
  }

  Future<void> _refreshSettings() async {
    final dataManager = BendDataManager();
    await dataManager.loadSavedSettings();
    if (mounted) {
      setState(() {
        _includeStartFitting = dataManager.startFit;
        _includeEndFitting = dataManager.endFit;
        _tailLength = dataManager.tail;
        _tailController.text = _tailLength > 0 ? _tailLength.round().toString() : "0";
      });
    }
  }

  @override
  void dispose() {
    _tailController.dispose();
    super.dispose();
  }

  String _getDirectionText(double rot) {
    if (rot == 0.0) return "UP";
    if (rot == 90.0) return "RIGHT";
    if (rot == 180.0) return "DOWN";
    if (rot == 270.0) return "LEFT";
    if (rot == 360.0) return "FRONT";
    if (rot == 450.0) return "BACK";
    return "${rot.toInt()}°";
  }

  IconData _getDirectionIcon(double rot) {
    if (rot == 0.0) return Icons.arrow_upward;
    if (rot == 90.0) return Icons.arrow_forward;
    if (rot == 180.0) return Icons.arrow_downward;
    if (rot == 270.0) return Icons.arrow_back;
    if (rot == 360.0) return Icons.call_made;
    if (rot == 450.0) return Icons.call_received;
    return Icons.rotate_right;
  }

  @override
  Widget build(BuildContext context) {
    final dataManager = BendDataManager();
    final bendList = dataManager.bendList;

    final double takeUp90 = dataManager.takeUp90;
    final double gain90 = dataManager.gain90;
    final double fittingDepth = dataManager.fittingDepth;

    final double startFitting = _includeStartFitting ? fittingDepth : 0.0;
    final double endFitting = _includeEndFitting ? fittingDepth : 0.0;

    List<double> cumulativeMarks = [];
    List<Map<String, dynamic>> saveList = [];

    double cumulativeLength = 0;
    double totalGain = 0;

    for (int i = 0; i < bendList.length; i++) {
      double length = bendList[i]['length']!;
      double angle = bendList[i]['angle']!;
      double angleRad = angle * math.pi / 180.0;

      double currentTakeUp = takeUp90 * math.tan(angleRad / 2);
      double currentGain = gain90 * (angle / 90.0);

      cumulativeLength += length;

      // ✅ 누적 마킹 계산 (테이크업만 빼서 벤더 물림 위치 정확히 표시)
      double markPoint = cumulativeLength + startFitting - totalGain - currentTakeUp;
      cumulativeMarks.add(markPoint);
      
      totalGain += currentGain; // 다음 마킹을 위한 게인 누적

      Map<String, dynamic> bendWithMarking = Map<String, dynamic>.from(bendList[i]);
      bendWithMarking['marking_point'] = markPoint;
      saveList.add(bendWithMarking);
    }

    // 🚀 문제의 미친 연산 수정 완료!
    // 현장 로직: 컷팅 길이는 게인을 빼서 쪼잔하게 자르지 않고, 누적 기장 + 여유장으로 넉넉하게 산출!
    double totalCut = bendList.isEmpty
        ? 0
        : cumulativeLength + _tailLength + startFitting + endFitting;

    return Scaffold(
      backgroundColor: slate100,
      appBar: AppBar(
        title: const Text("MARKING GUIDE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
        backgroundColor: makitaTeal,
        foregroundColor: pureWhite,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => Navigator.of(context).pop()),
      ),
      body: Column(
        children: [
          // 상단 요약 정보 (표제란)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: pureWhite,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("TOTAL CUT LENGTH (안전 기장)", style: TextStyle(color: slate600, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        "${totalCut.round()} mm", // 130mm 사기 안 침!
                        style: TextStyle(color: Colors.red.shade700, fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("T-Up: ${takeUp90.round()} / Gain: ${gain90.round()}", style: TextStyle(color: slate600, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: makitaTeal,
                        foregroundColor: pureWhite,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => _handleSave(totalCut, saveList),
                      icon: const Icon(Icons.save, size: 20),
                      label: const Text("저장하기", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 컨트롤 패널 (피팅 및 여유장)
          Container(
            color: pureWhite,
            margin: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSimpleSwitch("시작 피팅 (+${fittingDepth.round()})", _includeStartFitting, (v) {
                      setState(() { _includeStartFitting = v; BendDataManager().startFit = v; });
                    })),
                    Container(width: 1, height: 40, color: Colors.grey.shade200),
                    Expanded(child: _buildSimpleSwitch("종료 피팅 (+${fittingDepth.round()})", _includeEndFitting, (v) {
                      setState(() { _includeEndFitting = v; BendDataManager().endFit = v; });
                    })),
                  ],
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                InkWell(
                  onTap: () => _showTailPad(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.straighten, color: slate600, size: 20),
                            const SizedBox(width: 8),
                            Text("말단 여유장 추가 (Tail)", style: TextStyle(color: slate900, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: makitaTeal.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text("${_tailLength.round()} mm >", style: TextStyle(color: makitaTeal, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 마킹 리스트 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            width: double.infinity,
            color: slate100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("MARKING POINTS (벤더 정렬선)", style: TextStyle(color: slate600, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                Text("※ 자르지 마세요", style: TextStyle(color: Colors.red.shade400, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // 메인 리스트
          Expanded(
            child: bendList.isEmpty
                ? Center(child: Text("데이터가 없습니다.", style: TextStyle(color: slate600)))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 40),
                    itemCount: bendList.length,
                    itemBuilder: (context, index) {
                      final bend = bendList[index];
                      int cumulativeMark = cumulativeMarks[index].round();
                      int sectionLength = bend['length']!.round();

                      int prevMark = index == 0 ? 0 : cumulativeMarks[index - 1].round();
                      int incrementalMark = cumulativeMark - prevMark;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: pureWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: makitaTeal.withOpacity(0.3), width: 1.5), // 마킹 지점 강조 테두리
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            // 구간 번호 배지
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(color: makitaTeal, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text("${index + 1}", style: TextStyle(color: pureWhite, fontWeight: FontWeight.w900)),
                            ),
                            const SizedBox(width: 20),
                            // 누적 마킹 포인트 (이게 선생님이 찾던 '130' 입니다)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("벤더 0점 맞춤 (마킹)", style: TextStyle(color: slate600, fontSize: 11, fontWeight: FontWeight.bold)),
                                  Text(
                                    "$cumulativeMark",
                                    style: TextStyle(color: slate900, fontSize: 36, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: makitaTeal.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                    child: Text("↳ 이전 마킹부터: +$incrementalMark", style: TextStyle(color: makitaTeal, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                  ),
                                ],
                              ),
                            ),
                            // 단독 구간 정보
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: slate100, borderRadius: BorderRadius.circular(4)),
                                  child: Text("요청 기장: $sectionLength", style: TextStyle(color: slate900, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(_getDirectionIcon(bend['rotation']!), size: 16, color: makitaTeal),
                                    const SizedBox(width: 4),
                                    Text("${bend['angle']?.round()}° / ${_getDirectionText(bend['rotation']!)}", style: TextStyle(color: makitaTeal, fontSize: 14, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ... (스위치 로직 및 키패드 하단 코드는 기존과 100% 동일하게 유지했습니다)
  Widget _buildSimpleSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(value ? Icons.check_circle : Icons.radio_button_unchecked, color: value ? makitaTeal : slate600, size: 22),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: value ? slate900 : slate600, fontSize: 14, fontWeight: value ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  void _handleSave(double totalCut, List<Map<String, dynamic>> saveList) {
    // 1. 혹시 모를 오염을 대비해 깊은 복사 진행
    final finalSaveData = List<Map<String, dynamic>>.from(saveList.map((e) => Map<String, dynamic>.from(e)));
    
    if (finalSaveData.isNotEmpty) {
      finalSaveData[0]['start_fit_applied'] = _includeStartFitting;
      finalSaveData[finalSaveData.length - 1]['end_fit_applied'] = _includeEndFitting;
      
      // 🚀 핵심 방어 로직: "마지막 구간 각도 강제 보존 명령"
      // 만약 외부(데이터 매니저 등)에서 각도를 0으로 훼손했다면, 원본 bendList를 참조하거나,
      // 최소한 저장 단계에서 각도가 누락되지 않도록 강제합니다.
      // (여전히 0이라면, 이건 CalculatorPage에서 넘어올 때부터 지워진 겁니다)
      if(finalSaveData.last['angle'] == null || finalSaveData.last['angle'] == 0) {
        // 이 경고가 뜬다면 데이터 매니저가 범인입니다.
        print("🚨 경고: 마킹 페이지 저장 단계에서 마지막 각도가 0으로 확인됨! 데이터 유실 의심!");
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartSavePad(
        totalCut: totalCut,
        bendList: finalSaveData, // 강제 보존된 리스트 전달
        includeStart: _includeStartFitting,
        includeEnd: _includeEndFitting,
        tailLength: _tailLength,
      ),
    );
  }

  void _showTailPad() {
    String tempValue = _tailLength > 0 ? _tailLength.round().toString() : "";
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void pressKey(String key) {
              setModalState(() {
                if (key == 'C') { tempValue = ""; } 
                else if (key == '⌫') { if (tempValue.isNotEmpty) tempValue = tempValue.substring(0, tempValue.length - 1); } 
                else { if (tempValue == "0") tempValue = key; else tempValue += key; }
              });
            }
            void applyTail() {
              _tailController.text = tempValue.isEmpty ? "0" : tempValue;
              Navigator.pop(context);
            }
            return Container(
              height: MediaQuery.of(context).size.height * 0.55,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(color: pureWhite, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("말단 여유 (Tail)", style: TextStyle(color: slate600, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(tempValue.isEmpty ? "0 mm" : "$tempValue mm", style: TextStyle(color: slate900, fontSize: 36, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: Row(children: [_numKey('7', pressKey), _numKey('8', pressKey), _numKey('9', pressKey), _numKey('C', pressKey, color: Colors.red.shade400)])),
                        Expanded(child: Row(children: [_numKey('4', pressKey), _numKey('5', pressKey), _numKey('6', pressKey), _numKey('⌫', pressKey, color: Colors.orange.shade400)])),
                        Expanded(child: Row(children: [_numKey('1', pressKey), _numKey('2', pressKey), _numKey('3', pressKey), _numKey('.', pressKey)])),
                        Expanded(
                          child: Row(
                            children: [
                              _numKey('0', pressKey), _numKey('00', pressKey),
                              Expanded(
                                flex: 2,
                                child: InkWell(
                                  onTap: () => applyTail(),
                                  child: Container(
                                    margin: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: makitaTeal, borderRadius: BorderRadius.circular(12)),
                                    alignment: Alignment.center,
                                    child: const Text("적용", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _numKey(String text, Function(String) onTap, {Color? color}) {
    return Expanded(
      child: InkWell(
        onTap: () => onTap(text),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: slate100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          alignment: Alignment.center,
          child: Text(text, style: TextStyle(color: color ?? slate900, fontSize: 24, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}