import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:tubing_calculator/src/data/bend_data_manager.dart';
import 'package:tubing_calculator/src/core/common_widgets/smart_save_pad.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MarkingPage extends StatefulWidget {
  final PageController? pageController;
  const MarkingPage({super.key, this.pageController});

  @override
  State<MarkingPage> createState() => _MarkingPageState();
}

class _MarkingPageState extends State<MarkingPage> {
  bool _includeStartFitting = false;
  bool _includeEndFitting = false;
  double _tailLength = 0.0;
  final TextEditingController _tailController = TextEditingController(
    text: "0",
  );

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
        _tailController.text = _tailLength > 0
            ? _tailLength.round().toString()
            : "0";
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

    List<Map<String, dynamic>> displayMarks = [];
    double cumulativeLength = 0;
    int markNumber = 1;
    double prevMarkPoint = 0.0;

    for (int i = 0; i < bendList.length; i++) {
      double length = bendList[i]['length']!;
      double angle = bendList[i]['angle']!;

      cumulativeLength += length;

      if (angle == 0.0) {
        displayMarks.add({...bendList[i], 'is_straight': true});
        continue;
      }

      double angleRad = angle * math.pi / 180.0;
      double currentTakeUp = takeUp90 * math.tan(angleRad / 2);

      double markPoint = cumulativeLength + startFitting - currentTakeUp;
      double incrementalMark = markNumber == 1
          ? markPoint
          : (markPoint - prevMarkPoint);

      displayMarks.add({
        ...bendList[i],
        'is_straight': false,
        'mark_num': markNumber,
        'marking_point': markPoint,
        'incremental_mark': incrementalMark,
      });

      prevMarkPoint = markPoint;
      markNumber++;
    }

    double totalCut = bendList.isEmpty
        ? 0
        : cumulativeLength + _tailLength + startFitting + endFitting;

    // 🚀 핵심 로직: 단독으로 열렸는가? (pageController가 null이면 단독 실행)
    bool isStandalone = widget.pageController == null;

    return Scaffold(
      backgroundColor: slate100,
      // 🚀 단독으로 열렸을 때만 '뒤로 가기'가 포함된 앱바를 띄웁니다!
      appBar: isStandalone
          ? AppBar(
              title: const Text(
                "MARKING GUIDE",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 1,
                ),
              ),
              backgroundColor: makitaTeal,
              foregroundColor: pureWhite,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null, // 스와이프 모드일 때는 겹치지 않게 숨김 (메인 화면이 대신 타이틀을 표시해줌)
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: pureWhite,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "TOTAL CUT LENGTH (안전 기장)",
                          style: TextStyle(
                            color: slate600,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${totalCut.round()} mm",
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "T-Up: ${takeUp90.round()} / Gain: ${gain90.round()}",
                        style: const TextStyle(
                          color: slate600,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: makitaTeal,
                          foregroundColor: pureWhite,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () => _handleSave(totalCut, displayMarks),
                        icon: const Icon(Icons.save, size: 20),
                        label: const Text(
                          "저장하기",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Container(
              color: pureWhite,
              margin: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  _buildOptionTile(
                    title: "시작 부속 포함 (삽입 깊이 +${fittingDepth.round()}mm)",
                    subtitle: "파이프 첫 시작점이 조인트(부속) 안으로 들어가는 깊이를 계산에 포함합니다.",
                    value: _includeStartFitting,
                    onChanged: (v) {
                      setState(() {
                        _includeStartFitting = v;
                        BendDataManager().startFit = v;
                      });
                    },
                  ),
                  Divider(
                    height: 1,
                    color: Colors.grey.shade200,
                    indent: 20,
                    endIndent: 20,
                  ),
                  _buildOptionTile(
                    title: "종료 부속 포함 (삽입 깊이 +${fittingDepth.round()}mm)",
                    subtitle: "파이프 끝부분이 조인트(부속) 안으로 들어가는 깊이를 계산에 포함합니다.",
                    value: _includeEndFitting,
                    onChanged: (v) {
                      setState(() {
                        _includeEndFitting = v;
                        BendDataManager().endFit = v;
                      });
                    },
                  ),
                  Divider(
                    height: 1,
                    color: Colors.grey.shade200,
                    indent: 20,
                    endIndent: 20,
                  ),

                  InkWell(
                    onTap: () => _showTailPad(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.straighten,
                                  color: slate600,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "최종 절단 여유 기장 (Tail)",
                                        style: TextStyle(
                                          color: slate900,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "마지막 벤딩 후, 현장 조인을 위해 끝에 넉넉하게 남겨둘 추가 길이를 설정합니다.",
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: makitaTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${_tailLength.round()} mm >",
                              style: const TextStyle(
                                color: makitaTeal,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              width: double.infinity,
              color: slate100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "MARKING POINTS (벤더 정렬선)",
                    style: TextStyle(
                      color: slate600,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    "※ 자르지 마세요",
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: displayMarks.isEmpty
                  ? const Center(
                      child: Text(
                        "데이터가 없습니다.",
                        style: TextStyle(color: slate600),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 40),
                      itemCount: displayMarks.length,
                      itemBuilder: (context, index) {
                        final item = displayMarks[index];

                        if (item['is_straight'] == true) {
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.arrow_downward,
                                  color: Colors.grey.shade500,
                                  size: 16,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "직관 연장: +${item['length']?.round()} mm",
                                  style: const TextStyle(
                                    color: slate600,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  "마킹 없음",
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        int cumulativeMark = item['marking_point'].round();
                        int incrementalMark = item['incremental_mark'].round();
                        int sectionLength = item['length']!.round();

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: pureWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: makitaTeal.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: makitaTeal,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "${item['mark_num']}",
                                  style: const TextStyle(
                                    color: pureWhite,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "누적 마킹 지점 (줄자 0점 고정)",
                                      style: TextStyle(
                                        color: slate600,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "$cumulativeMark",
                                      style: const TextStyle(
                                        color: slate900,
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    if (item['mark_num'] > 1)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: makitaTeal.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          "↳ 앞 벤딩과의 구간 거리: +$incrementalMark",
                                          style: const TextStyle(
                                            color: makitaTeal,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: slate100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "요청 기장: $sectionLength",
                                      style: const TextStyle(
                                        color: slate900,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        _getDirectionIcon(item['rotation']!),
                                        size: 16,
                                        color: makitaTeal,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${item['angle']?.round()}° / ${_getDirectionText(item['rotation']!)}",
                                        style: const TextStyle(
                                          color: makitaTeal,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
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
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                value ? Icons.check_circle : Icons.radio_button_unchecked,
                color: value ? makitaTeal : slate600,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: value ? slate900 : slate600,
                      fontSize: 14,
                      fontWeight: value ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSave(double totalCut, List<Map<String, dynamic>> saveList) {
    final finalSaveData = List<Map<String, dynamic>>.from(
      saveList.map((e) => Map<String, dynamic>.from(e)),
    );
    if (finalSaveData.isNotEmpty) {
      finalSaveData[0]['start_fit_applied'] = _includeStartFitting;
      finalSaveData[finalSaveData.length - 1]['end_fit_applied'] =
          _includeEndFitting;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartSavePad(
        totalCut: totalCut,
        bendList: finalSaveData,
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
                if (key == 'C') {
                  tempValue = "";
                } else if (key == '⌫') {
                  if (tempValue.isNotEmpty) {
                    tempValue = tempValue.substring(0, tempValue.length - 1);
                  }
                } else {
                  if (tempValue == "0") {
                    tempValue = key;
                  } else {
                    tempValue += key;
                  }
                }
              });
            }

            void applyTail() {
              _tailController.text = tempValue.isEmpty ? "0" : tempValue;
              Navigator.pop(context);
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.55,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: pureWhite,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "절단 여유 기장 (Tail)",
                        style: TextStyle(
                          color: slate600,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        tempValue.isEmpty ? "0 mm" : "$tempValue mm",
                        style: const TextStyle(
                          color: slate900,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _numKey('7', pressKey),
                              _numKey('8', pressKey),
                              _numKey('9', pressKey),
                              _numKey(
                                'C',
                                pressKey,
                                color: Colors.red.shade400,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              _numKey('4', pressKey),
                              _numKey('5', pressKey),
                              _numKey('6', pressKey),
                              _numKey(
                                '⌫',
                                pressKey,
                                color: Colors.orange.shade400,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              _numKey('1', pressKey),
                              _numKey('2', pressKey),
                              _numKey('3', pressKey),
                              _numKey('.', pressKey),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              _numKey('0', pressKey),
                              _numKey('00', pressKey),
                              Expanded(
                                flex: 2,
                                child: InkWell(
                                  onTap: () => applyTail(),
                                  child: Container(
                                    margin: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: makitaTeal,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      "적용",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
          decoration: BoxDecoration(
            color: slate100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: color ?? slate900,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
