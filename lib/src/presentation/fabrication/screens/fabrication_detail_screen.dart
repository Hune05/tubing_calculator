import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:tubing_calculator/src/core/database/database_helper.dart';
import 'package:tubing_calculator/src/data/bend_data_manager.dart';

// 🚀 독립된 아이소 엔진 임포트
import 'package:tubing_calculator/src/presentation/calculator/widgets/pipe_visualizer.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class FabricationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> itemData;
  const FabricationDetailScreen({super.key, required this.itemData});

  @override
  State<FabricationDetailScreen> createState() =>
      _FabricationDetailScreenState();
}

class _FabricationDetailScreenState extends State<FabricationDetailScreen> {
  late Map<String, dynamic> currentData;
  late String project;
  late String from;
  late String to;

  bool startFit = false;
  bool endFit = false;
  double tail = 0.0;
  double fittingDepth = 0.0;

  String startDir = 'RIGHT';
  int? _selectedSegmentIndex;

  @override
  void initState() {
    super.initState();
    currentData = Map<String, dynamic>.from(widget.itemData);
    fittingDepth = BendDataManager().fittingDepth;
    _parsePtoP();
  }

  void _parsePtoP() {
    try {
      var pData = jsonDecode(currentData['p_to_p']);
      project = pData['project'] ?? "N/A";
      from = pData['from'] ?? "N/A";
      to = pData['to'] ?? "N/A";
      startFit = (pData['start_fit'] == true) || (pData['start_fit'] == 'true');
      endFit = (pData['end_fit'] == true) || (pData['end_fit'] == 'true');
      tail = double.tryParse(pData['tail']?.toString() ?? '0.0') ?? 0.0;
      startDir = pData['start_dir'] ?? 'RIGHT';
    } catch (e) {
      project = "N/A";
      from = currentData['p_to_p'] ?? "N/A";
      to = "";
      startDir = 'RIGHT';
    }
  }

  String _getDirectionTextShort(double rot) {
    if (rot == 0.0) return "UP";
    if (rot == 90.0) return "RIGHT";
    if (rot == 180.0) return "DOWN";
    if (rot == 270.0) return "LEFT";
    if (rot == 360.0) return "FRONT";
    if (rot == 450.0) return "BACK";
    return "${rot.toInt()}°";
  }

  String _extractValue(Map<String, dynamic> map, List<String> keys) {
    for (String key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        var val = map[key];
        if (val is num) {
          return val.toStringAsFixed(1);
        } else if (val is String && val.isNotEmpty) {
          double? parsed = double.tryParse(val);
          return parsed != null ? parsed.toStringAsFixed(1) : val;
        }
      }
    }
    return "";
  }

  Future<void> _editInfo() async {
    TextEditingController projCtrl = TextEditingController(text: project);
    TextEditingController fromCtrl = TextEditingController(text: from);
    TextEditingController toCtrl = TextEditingController(text: to);
    String selectedSize = currentData['pipe_size'] ?? '1/2"';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 24,
          ),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: makitaTeal, width: 2),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "도면 정보 수정",
                  style: TextStyle(
                    color: slate900,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: projCtrl,
                  decoration: const InputDecoration(
                    labelText: "PROJECT",
                    filled: true,
                    fillColor: slate100,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fromCtrl,
                        decoration: const InputDecoration(
                          labelText: "FROM",
                          filled: true,
                          fillColor: slate100,
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: toCtrl,
                        decoration: const InputDecoration(
                          labelText: "TO",
                          filled: true,
                          fillColor: slate100,
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: makitaTeal,
                    ),
                    onPressed: () async {
                      Map<String, dynamic> newPtoP = {
                        "project": projCtrl.text,
                        "from": fromCtrl.text,
                        "to": toCtrl.text,
                        "start_fit": startFit,
                        "end_fit": endFit,
                        "tail": tail,
                        "start_dir": startDir,
                      };
                      await DatabaseHelper.instance.updateHistory(
                        currentData['id'],
                        {
                          'p_to_p': jsonEncode(newPtoP),
                          'pipe_size': selectedSize,
                        },
                      );
                      setState(() {
                        currentData['p_to_p'] = jsonEncode(newPtoP);
                        currentData['pipe_size'] = selectedSize;
                        _parsePtoP();
                      });
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "수정 완료",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> bendList = [];
    try {
      List<dynamic> rawList = jsonDecode(currentData['bend_data']);
      bendList = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      bendList = [];
    }

    // 🚀 [문제 해결의 핵심!] 건너뛰는 버그 수정
    // 3D 뷰어와 리스트가 '진짜 번호'를 공유할 수 있도록 정확히 계산합니다.
    int markNumber = 1;
    for (int i = 0; i < bendList.length; i++) {
      bool isStraight = (bendList[i]['angle']?.toDouble() ?? 0.0) == 0.0;
      bendList[i]['is_straight'] = isStraight;
      bendList[i]['display_mark_num'] = isStraight ? 0 : markNumber;
      if (!isStraight) markNumber++; // 직관이 아닐 때만 번호를 하나씩 올립니다.
    }

    final double absoluteTotalCut =
        double.tryParse(currentData['total_length']?.toString() ?? '0') ?? 0.0;
    final int displayTotalCut = absoluteTotalCut.round();

    String fittingStr = "";
    if (startFit) fittingStr += "S ";
    if (endFit) fittingStr += (fittingStr.isNotEmpty ? "& E" : "E");
    if (fittingStr.isEmpty) fittingStr = "None";

    return Scaffold(
      backgroundColor: slate100,
      appBar: AppBar(
        title: Text(
          'ISO DWG: $project',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: makitaTeal,
        foregroundColor: pureWhite,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, size: 28),
            onPressed: _editInfo,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: pureWhite,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "LINE",
                          style: TextStyle(
                            color: slate600,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$from ➔ $to",
                          style: const TextStyle(
                            color: slate900,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "SIZE / FIT",
                            style: TextStyle(
                              color: slate600,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${currentData['pipe_size']} / $fittingStr",
                            style: const TextStyle(
                              color: makitaTeal,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "TOTAL CUT",
                            style: TextStyle(
                              color: slate600,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$displayTotalCut mm",
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 7,
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: pureWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: PipeVisualizer(
                          bendList: bendList, // 🚀 완벽하게 번호 매겨진 데이터 전달
                          tailLength: tail,
                          selectedSegmentIndex: _selectedSegmentIndex,
                          initialStartDir: startDir,
                          onStartDirChanged: (newDir) async {
                            setState(() {
                              startDir = newDir;
                            });
                            try {
                              Map<String, dynamic> newPtoP = {
                                "project": project,
                                "from": from,
                                "to": to,
                                "start_fit": startFit,
                                "end_fit": endFit,
                                "tail": tail,
                                "start_dir": newDir,
                              };
                              String newPtoPJson = jsonEncode(newPtoP);
                              await DatabaseHelper.instance.updateHistory(
                                currentData['id'],
                                {'p_to_p': newPtoPJson},
                              );
                              currentData['p_to_p'] = newPtoPJson;
                            } catch (e) {
                              debugPrint("방향 저장 실패: $e");
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.only(
                        top: 12,
                        bottom: 12,
                        right: 12,
                      ),
                      decoration: BoxDecoration(
                        color: pureWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: bendList.isEmpty
                          ? const Center(
                              child: Text(
                                "NO DATA",
                                style: TextStyle(color: slate600),
                              ),
                            )
                          : Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: slate100,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "상세 작업 구간",
                                        style: TextStyle(
                                          color: slate600,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount:
                                        bendList.length + (tail > 0 ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      bool isSelected =
                                          _selectedSegmentIndex == index;
                                      if (index < bendList.length) {
                                        return _buildSegmentListItem(
                                          index: index,
                                          isSelected: isSelected,
                                          bendData: bendList[index],
                                          onTap: () => setState(
                                            () => _selectedSegmentIndex =
                                                isSelected ? null : index,
                                          ),
                                        );
                                      } else {
                                        return _buildSegmentListItem(
                                          index: index,
                                          isSelected: isSelected,
                                          isTail: true,
                                          tailLength: tail,
                                          onTap: () => setState(
                                            () => _selectedSegmentIndex =
                                                isSelected ? null : index,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 직관/벤딩을 완벽하게 분리한 UI (직관은 마킹값 스킵)
  Widget _buildSegmentListItem({
    required int index,
    required bool isSelected,
    Map<String, dynamic>? bendData,
    required VoidCallback onTap,
    bool isTail = false,
    double? tailLength,
  }) {
    String lengthText = "";
    String directionText = "";
    String markText = "";
    String baText = "";
    String sbText = "";

    bool isStraight = false;
    int displayMarkNum = 0;

    if (isTail) {
      lengthText = tailLength?.round().toString() ?? "0";
      directionText = "TAIL";
    } else if (bendData != null) {
      double rawLength = (bendData['length'] ?? 0).toDouble();
      double rotation = (bendData['rotation'] ?? 0.0).toDouble();
      String angle = bendData['angle']?.toString() ?? '0';

      isStraight = bendData['is_straight'] ?? false;
      displayMarkNum = bendData['display_mark_num'] ?? 0;

      lengthText = rawLength.round().toString();
      directionText = "${_getDirectionTextShort(rotation)} $angle°";

      // 🚀 핵심 로직: 직관(Straight)이면 아예 마킹값을 무시해버림!
      if (!isStraight) {
        markText = _extractValue(bendData, [
          'mark',
          'marking',
          'marking_point',
        ]);
        baText = _extractValue(bendData, ['bend_allowance', 'ba']);
        sbText = _extractValue(bendData, ['springback', 'sb']);
      }
    }

    // 🚀 [1] 직관(Straight) 및 꼬리(Tail) 구간 렌더링 (마킹 UI 완전 제거)
    if (isTail || isStraight) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.orange.withValues(alpha: 0.15)
                : slate100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(
                isTail ? Icons.straighten : Icons.arrow_downward,
                color: Colors.grey.shade500,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isTail ? "여유 기장 (TAIL)" : "직관 연장 (L: $lengthText mm)",
                  style: const TextStyle(
                    color: slate600,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (isTail)
                Text(
                  "+$lengthText mm",
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // 🚀 [2] 실제 벤딩 구간: 번호표 큼직하게 + 마킹값 거대하게!
    bool hasExtraInfo = baText.isNotEmpty || sbText.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.orange.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 진짜 벤딩 마킹 번호표
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.orange.shade700 : makitaTeal,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "$displayMarkNum",
                    style: const TextStyle(
                      color: pureWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // 거대한 마킹 값
                if (markText.isNotEmpty)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "MARKING (마킹 지점)",
                          style: TextStyle(
                            color: slate600,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "$markText mm",
                          style: TextStyle(
                            color: isSelected
                                ? Colors.orange.shade800
                                : slate900,
                            fontSize: 32, // 🔥 사이즈 폭발
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // 길이와 벤딩 각도 등 부차적 정보
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.orange.withOpacity(0.05) : slate100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Colors.orange.shade200
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "입력 기장(L)",
                        style: TextStyle(
                          color: slate600,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "$lengthText mm",
                        style: const TextStyle(
                          color: slate900,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 24, color: Colors.grey.shade300),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "벤딩 각도/방향",
                        style: TextStyle(
                          color: slate600,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        directionText,
                        style: const TextStyle(
                          color: makitaTeal,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (hasExtraInfo) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (baText.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(
                        "BA: $baText",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (sbText.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.purple.shade100),
                      ),
                      child: Text(
                        "SB: $sbText°",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
