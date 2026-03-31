import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/core/common_widgets/smart_save_pad.dart';
import 'package:tubing_calculator/src/core/engine/tube_bending_engine.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_pipe_visualizer.dart';
import 'package:tubing_calculator/src/core/database/database_helper.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/mobile_fabrication_detail_screen.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

// ==========================================
// 🚀 2탭: 모바일 결과 (Marking) 화면
// ==========================================
class MobileResultTab extends StatefulWidget {
  final String startDir;
  const MobileResultTab({super.key, required this.startDir});
  @override
  State<MobileResultTab> createState() => _MobileResultTabState();
}

class _MobileResultTabState extends State<MobileResultTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
  }

  Future<void> _refreshSettings() async {
    final dataManager = MobileBendDataManager();
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
    super.build(context);

    return ListenableBuilder(
      listenable: MobileBendDataManager(),
      builder: (context, child) {
        final dataManager = MobileBendDataManager();
        final bendList = dataManager.bendList;
        final double radius = dataManager.takeUp90;
        final double fittingDepth = dataManager.fittingDepth;
        final engine = TubeBendingEngine(radius: radius);

        List<BendInstruction> instructions = [];
        for (int i = 0; i < bendList.length; i++) {
          double l = (bendList[i]['length'] as num?)?.toDouble() ?? 0.0;
          if (i == 0 && _includeStartFitting) {
            l += fittingDepth;
          }
          if (i == bendList.length - 1 && _includeEndFitting) {
            l += fittingDepth;
          }
          instructions.add(
            BendInstruction(
              length: l,
              angle: (bendList[i]['angle'] as num?)?.toDouble() ?? 0.0,
              rotation: (bendList[i]['rotation'] as num?)?.toDouble() ?? 0.0,
            ),
          );
        }

        final result = engine.calculate(instructions, 0.0);
        final double pureCutLength = result['totalCutLength'];
        final List<StepResult> steps = result['steps'];

        List<Map<String, dynamic>> displayMarks = [];
        int markNumber = 1;
        double lastMarkingPoint = 0.0;
        double accumulatedIncremental = 0.0;

        for (int i = 0; i < bendList.length; i++) {
          double angleValue = (bendList[i]['angle'] as num?)?.toDouble() ?? 0.0;
          bool isStraight = angleValue == 0.0;
          double currentMark = steps[i].markingPoint;
          double currentLength =
              (bendList[i]['length'] as num?)?.toDouble() ?? 0.0;

          if (currentMark > lastMarkingPoint) {
            lastMarkingPoint = currentMark;
          }

          if (currentLength <= 0.01 && isStraight) {
            accumulatedIncremental += steps[i].incrementalMark;
            displayMarks.add({
              ...bendList[i],
              'is_straight': true,
              'is_hidden': true,
              'mark_num': 0,
              'marking_point': currentMark,
              'incremental_mark': 0.0,
            });
            continue;
          }

          if (isStraight) {
            accumulatedIncremental += steps[i].incrementalMark;
            displayMarks.add({
              ...bendList[i],
              'is_straight': true,
              'is_hidden': false,
              'mark_num': 0,
              'marking_point': currentMark,
              'incremental_mark': 0.0,
            });
          } else {
            displayMarks.add({
              ...bendList[i],
              'is_straight': false,
              'is_hidden': false,
              'mark_num': markNumber,
              'marking_point': currentMark,
              'incremental_mark':
                  steps[i].incrementalMark + accumulatedIncremental,
            });
            markNumber++;
            accumulatedIncremental = 0.0;
          }
        }

        double totalCut = bendList.isEmpty ? 0.0 : pureCutLength + _tailLength;
        double diffAfterLastMark = (totalCut - lastMarkingPoint) - radius;
        if (diffAfterLastMark < 0) {
          diffAfterLastMark = 0;
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: pureWhite,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "TOTAL CUT LENGTH",
                          style: TextStyle(
                            color: slate600,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${totalCut.round()} mm",
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (bendList.isNotEmpty && diffAfterLastMark > 0)
                          Text(
                            "※ 마지막 벤딩 후 잔여: +${diffAfterLastMark.round()}mm",
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "반경(R): ${radius.round()}mm",
                        style: const TextStyle(
                          color: slate600,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text(
                          "저장",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
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
                    title: "시작 피팅 (+${fittingDepth.round()}mm)",
                    value: _includeStartFitting,
                    onChanged: (v) => setState(() {
                      _includeStartFitting = v;
                      MobileBendDataManager().startFit = v;
                    }),
                  ),
                  Divider(
                    height: 1,
                    color: Colors.grey.shade200,
                    indent: 20,
                    endIndent: 20,
                  ),
                  _buildOptionTile(
                    title: "종료 피팅 (+${fittingDepth.round()}mm)",
                    value: _includeEndFitting,
                    onChanged: (v) => setState(() {
                      _includeEndFitting = v;
                      MobileBendDataManager().endFit = v;
                    }),
                  ),
                  Divider(
                    height: 1,
                    color: Colors.grey.shade200,
                    indent: 20,
                    endIndent: 20,
                  ),
                  InkWell(
                    onTap: _showTailPad,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.straighten, color: slate600, size: 20),
                              SizedBox(width: 12),
                              Text(
                                "절단 여유 기장 (Tail)",
                                style: TextStyle(
                                  color: slate900,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "${_tailLength.round()} mm >",
                            style: const TextStyle(
                              color: makitaTeal,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              width: double.infinity,
              color: slate100,
              child: const Text(
                "MARKING POINTS (줄자 0점 고정)",
                style: TextStyle(
                  color: slate600,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: displayMarks.isEmpty
                  ? const Center(
                      child: Text(
                        "1번 탭에서 치수를 입력해주세요.",
                        style: TextStyle(color: slate600, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 40),
                      itemCount: displayMarks.length,
                      itemBuilder: (context, index) {
                        final item = displayMarks[index];
                        if (item['is_hidden'] == true) {
                          return const SizedBox.shrink();
                        }

                        int cumulativeMark =
                            (item['marking_point'] as num?)?.round() ?? 0;
                        int incrementalMark =
                            (item['incremental_mark'] as num?)?.round() ?? 0;
                        int originalLength =
                            (item['length'] as num?)?.round() ?? 0;

                        if (item['is_straight'] == true) {
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.arrow_downward,
                                  color: Colors.grey,
                                  size: 16,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "직관 연장: +$originalLength mm",
                                    style: const TextStyle(
                                      color: slate600,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  "마킹: $cumulativeMark",
                                  style: const TextStyle(
                                    color: makitaTeal,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        double rotationVal =
                            (item['rotation'] as num?)?.toDouble() ?? 0.0;
                        double angleVal =
                            (item['angle'] as num?)?.toDouble() ?? 0.0;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: pureWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: makitaTeal.withValues(alpha: 0.3),
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
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: makitaTeal,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "${item['mark_num']}",
                                  style: const TextStyle(
                                    color: pureWhite,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "누적 마킹 지점",
                                      style: TextStyle(
                                        color: slate600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      "$cumulativeMark",
                                      style: const TextStyle(
                                        color: slate900,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    if ((item['mark_num'] as num?) != null &&
                                        (item['mark_num'] as num) > 1)
                                      Text(
                                        "↳ 앞 마킹과의 거리: +$incrementalMark",
                                        style: const TextStyle(
                                          color: makitaTeal,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "길이: $originalLength",
                                    style: const TextStyle(
                                      color: slate900,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        _getDirectionIcon(rotationVal),
                                        size: 16,
                                        color: makitaTeal,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${angleVal.round()}° / ${_getDirectionText(rotationVal)}",
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
        );
      },
    );
  }

  Widget _buildOptionTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_circle : Icons.radio_button_unchecked,
              color: value ? makitaTeal : slate600,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: value ? slate900 : slate600,
                fontSize: 15,
                fontWeight: value ? FontWeight.bold : FontWeight.normal,
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
        startDir: widget.startDir,
        onSaveCallback: null,
      ),
    );
  }

  void _showTailPad() async {
    _tailController.text = _tailLength > 0
        ? _tailLength.round().toString()
        : "";
    await MakitaNumpad.show(
      context,
      controller: _tailController,
      title: "절단 여유 기장 (mm)",
    );
    if (!mounted) {
      return;
    }
    double val = double.tryParse(_tailController.text) ?? 0.0;
    setState(() {
      _tailLength = val;
      MobileBendDataManager().tail = _tailLength;
    });
  }
}

// ==========================================
// 🚀 3탭: 모바일 도면 (3D Viewer) 화면
// ==========================================
class MobileViewerTab extends StatefulWidget {
  final String startDir;
  final ValueChanged<String>? onStartDirChanged;

  const MobileViewerTab({
    super.key,
    required this.startDir,
    this.onStartDirChanged,
  });

  @override
  State<MobileViewerTab> createState() => _MobileViewerTabState();
}

class _MobileViewerTabState extends State<MobileViewerTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListenableBuilder(
      listenable: MobileBendDataManager(),
      builder: (context, child) {
        final dataManager = MobileBendDataManager();
        final bendList = dataManager.bendList;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: pureWhite,
              child: const Row(
                children: [
                  Icon(Icons.threed_rotation, color: makitaTeal, size: 20),
                  SizedBox(width: 10),
                  Text(
                    "ISO 3D 도면 뷰어 (드래그하여 회전)",
                    style: TextStyle(
                      color: slate900,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: bendList.isEmpty
                  ? const Center(
                      child: Text(
                        "입력된 치수가 없습니다.",
                        style: TextStyle(color: slate600, fontSize: 14),
                      ),
                    )
                  : MobilePipeVisualizer(
                      bendList: bendList,
                      tailLength: dataManager.tail,
                      initialStartDir: widget.startDir,
                      onStartDirChanged: widget.onStartDirChanged,
                      startFit: dataManager.startFit,
                      endFit: dataManager.endFit,
                      isLightMode: false,
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ==========================================
// 🚀 4탭: 모바일 보관함 (History) 화면
// ==========================================
class MobileHistoryTab extends StatefulWidget {
  const MobileHistoryTab({super.key});
  @override
  State<MobileHistoryTab> createState() => _MobileHistoryTabState();
}

class _MobileHistoryTabState extends State<MobileHistoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, List<Map<String, dynamic>>> _groupedHistory = {};
  bool _isLoading = true;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshHistory() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getHistory();
    if (!mounted) {
      return;
    }

    Map<String, List<Map<String, dynamic>>> tempGrouped = {};
    for (var item in data) {
      String rawPtoP = item['p_to_p'] ?? '{}';
      String project = "미지정 프로젝트";
      try {
        var pData = jsonDecode(rawPtoP);
        if (pData['project'] != null &&
            pData['project'].toString().trim().isNotEmpty) {
          project = pData['project'];
        }
      } catch (_) {}

      if (!tempGrouped.containsKey(project)) {
        tempGrouped[project] = [];
      }
      tempGrouped[project]!.add(item);
    }

    tempGrouped.forEach((key, list) {
      list.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    });

    setState(() {
      _groupedHistory = tempGrouped;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    Map<String, List<Map<String, dynamic>>> filteredGroupedHistory = {};
    if (_searchQuery.isEmpty) {
      filteredGroupedHistory = _groupedHistory;
    } else {
      _groupedHistory.forEach((folderName, items) {
        bool folderMatches = folderName.toLowerCase().contains(_searchQuery);
        List<Map<String, dynamic>> matchingItems = items.where((item) {
          String rawPtoP = item['p_to_p'] ?? '{}';
          String fromTo = "";
          try {
            var pData = jsonDecode(rawPtoP);
            fromTo = "${pData['from']} ➔ ${pData['to']}".toLowerCase();
          } catch (_) {}
          return fromTo.contains(_searchQuery);
        }).toList();
        if (folderMatches) {
          filteredGroupedHistory[folderName] = items;
        } else if (matchingItems.isNotEmpty) {
          filteredGroupedHistory[folderName] = matchingItems;
        }
      });
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: pureWhite,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '프로젝트명 또는 경로 검색...',
              hintStyle: const TextStyle(color: slate600),
              prefixIcon: const Icon(Icons.search, color: makitaTeal),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.cancel, color: slate600),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    )
                  : null,
              filled: true,
              fillColor: slate100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) =>
                setState(() => _searchQuery = val.toLowerCase()),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: makitaTeal),
                )
              : filteredGroupedHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_off,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? '검색 결과가 없습니다.'
                            : '저장된 도면이 없습니다.',
                        style: const TextStyle(
                          color: slate600,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredGroupedHistory.keys.length,
                  itemBuilder: (context, index) {
                    String folderName = filteredGroupedHistory.keys.elementAt(
                      index,
                    );
                    List<Map<String, dynamic>> folderItems =
                        filteredGroupedHistory[folderName]!;
                    return Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: pureWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ExpansionTile(
                          initiallyExpanded:
                              index == 0 || _searchQuery.isNotEmpty,
                          iconColor: makitaTeal,
                          collapsedIconColor: slate600,
                          leading: const Icon(
                            Icons.folder,
                            color: makitaTeal,
                            size: 28,
                          ),
                          title: Text(
                            "$folderName (${folderItems.length})",
                            style: const TextStyle(
                              color: slate900,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          children: folderItems.map((item) {
                            String rawPtoP = item['p_to_p'] ?? '{}';
                            String fromTo = "경로 미상";
                            try {
                              var pData = jsonDecode(rawPtoP);
                              fromTo = "${pData['from']} ➔ ${pData['to']}";
                            } catch (_) {}
                            double cutRaw =
                                double.tryParse(
                                  item['total_length'].toString(),
                                ) ??
                                0.0;
                            int cutDisplay = cutRaw.round();

                            return Container(
                              margin: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: 12,
                              ),
                              decoration: BoxDecoration(
                                color: slate100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          MobileFabricationDetailScreen(
                                            itemData: item,
                                          ),
                                    ),
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  _refreshHistory();
                                },
                                title: Text(
                                  fromTo,
                                  style: const TextStyle(
                                    color: makitaTeal,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.straighten,
                                            size: 14,
                                            color: slate600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Total Cut: $cutDisplay mm",
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            "Size: ${item['pipe_size']}",
                                            style: const TextStyle(
                                              color: slate600,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "날짜: ${item['date']?.toString().substring(0, 10) ?? ''}",
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red.shade400,
                                  ),
                                  onPressed: () async {
                                    bool? confirm = await showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: pureWhite,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        title: const Text(
                                          "삭제 확인",
                                          style: TextStyle(
                                            color: slate900,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        content: const Text(
                                          "이 도면을 보관함에서 영구 삭제하시겠습니까?",
                                          style: TextStyle(color: slate600),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text(
                                              "취소",
                                              style: TextStyle(
                                                color: slate600,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: Text(
                                              "삭제",
                                              style: TextStyle(
                                                color: Colors.red.shade600,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await DatabaseHelper.instance
                                          .deleteHistory(item['id']);
                                      if (!context.mounted) {
                                        return;
                                      }
                                      _refreshHistory();
                                    }
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
