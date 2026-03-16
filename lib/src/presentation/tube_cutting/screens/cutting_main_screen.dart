import 'package:flutter/material.dart';
import '../../../data/models/cutting_project_model.dart';
import '../../../data/models/fitting_item.dart';
import '../../../data/models/smart_fitting_db.dart';
import '../widgets/smart_fitting_selector_sheet.dart';

const Color lightBg = Color(0xFFF0F3F5);
const Color whiteCard = Colors.white;
const Color makitaTeal = Color(0xFF007580);
const Color makitaDark = Color(0xFF004D54);
const Color textPrimary = Color(0xFF1A1A1A);

class CutPoint {
  final String id = UniqueKey().toString();
  FittingItem fitting;
  TextEditingController c2cController;
  double calculatedCut;

  CutPoint({required this.fitting})
    : c2cController = TextEditingController(),
      calculatedCut = 0.0;
  void dispose() => c2cController.dispose();
}

class CuttingMainScreen extends StatefulWidget {
  final CuttingProject project;
  const CuttingMainScreen({super.key, required this.project});

  @override
  State<CuttingMainScreen> createState() => _CuttingMainScreenState();
}

class _CuttingMainScreenState extends State<CuttingMainScreen> {
  String _globalMaker = "Swagelok";
  List<CutPoint> _points = [];
  int _setMultiplier = 1;
  bool _groupSameLengths = false;

  @override
  void initState() {
    super.initState();
    _initializeSequence();
  }

  void _initializeSequence() {
    _points = [
      CutPoint(fitting: SmartFittingDB.getById("none")),
      CutPoint(fitting: SmartFittingDB.getById("none")),
    ];
  }

  @override
  void dispose() {
    for (var point in _points) {
      point.dispose();
    }
    super.dispose();
  }

  void _calculate() {
    setState(() {
      for (int i = 0; i < _points.length - 1; i++) {
        if (_points[i].c2cController.text.trim().isEmpty) {
          _points[i].calculatedCut = 0.0;
          continue;
        }

        double c2c = double.tryParse(_points[i].c2cController.text) ?? 0.0;
        double deduction1 = _points[i].fitting.deduction;
        double deduction2 = _points[i + 1].fitting.deduction;

        _points[i].calculatedCut = c2c - deduction1 - deduction2;
      }
    });
  }

  void _addPoint() {
    setState(() {
      _points.add(CutPoint(fitting: SmartFittingDB.getById("none")));
      _calculate();
    });
  }

  void _removePoint(int index) {
    if (_points.length <= 2) {
      return;
    }
    setState(() {
      _points[index].dispose();
      _points.removeAt(index);
      _calculate();
    });
  }

  Future<void> _openFittingSelector(int index) async {
    FittingItem? selectedItem = await SmartFittingSelectorSheet.show(
      context,
      _globalMaker,
    );
    if (selectedItem != null) {
      setState(() => _points[index].fitting = selectedItem);
      _calculate();
    }
  }

  // 🚀 커스텀 부속(삽입 깊이 직접 입력) 팝업
  void _showCustomFittingDialog(int index) {
    TextEditingController nameCtrl = TextEditingController(text: "커스텀 부속");
    TextEditingController dedCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: whiteCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          "부속 / 삽입 깊이 직접 입력",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: "부속 이름 (예: 밸브, 후렌지 등)",
                filled: true,
                fillColor: lightBg,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dedCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "공제값 (삽입 깊이) mm",
                filled: true,
                fillColor: lightBg,
                suffixText: "mm",
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "💡 팁: 전체 길이에서 튜브 삽입(물림) 깊이만 빼고 싶을 때 사용하세요.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: makitaTeal),
            onPressed: () {
              double customDed = double.tryParse(dedCtrl.text) ?? 0.0;
              setState(() {
                // 🚀 [에러 픽스] "" 대신 진짜 아이콘(Icons.extension)을 넣었습니다!
                _points[index].fitting = FittingItem(
                  id: "custom_${DateTime.now().millisecondsSinceEpoch}",
                  category: "CUSTOM",
                  name: nameCtrl.text.trim().isEmpty
                      ? "커스텀 부속"
                      : nameCtrl.text.trim(),
                  tubeOD: "직접입력",
                  maker: "CUSTOM",
                  deduction: customDed,
                  icon: Icons.extension, // 💡 이 부분이 수정되었습니다!
                );
                _calculate();
              });
              Navigator.pop(ctx);
            },
            child: const Text(
              "적용",
              style: TextStyle(color: whiteCard, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _saveRecord() {
    if (_points.any(
      (p) => p.c2cController.text.isNotEmpty && p.calculatedCut < 0,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("간섭이 발생한 구간이 있습니다. 치수를 확인해주세요!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    double totalOneSet = _points
        .sublist(0, _points.length - 1)
        .fold(
          0.0,
          (sum, point) =>
              sum + (point.calculatedCut > 0 ? point.calculatedCut : 0.0),
        );
    double finalTotal = totalOneSet * _setMultiplier;

    if (finalTotal <= 0) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      widget.project.addCutLength(finalTotal);
      for (var point in _points) {
        point.c2cController.clear();
        point.calculatedCut = 0.0;
      }
      _setMultiplier = 1;
      _calculate();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "$_setMultiplier세트 (총 ${finalTotal.toStringAsFixed(1)}mm) 기록 완료!",
        ),
        backgroundColor: makitaTeal,
      ),
    );
  }

  Widget _buildFittingBadge(FittingItem item, bool isNone) {
    bool isCustom = item.category == "CUSTOM";
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isNone
            ? Colors.grey.shade100
            : (isCustom
                  ? Colors.orange.shade50
                  : makitaTeal.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isNone
              ? Colors.grey.shade300
              : (isCustom ? Colors.orange : makitaTeal.withValues(alpha: 0.5)),
        ),
      ),
      child: Text(
        isNone ? "-" : item.category.replaceAll('_', '\n'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: item.category.length > 4 ? 9 : 12,
          fontWeight: FontWeight.w900,
          color: isNone
              ? Colors.grey
              : (isCustom ? Colors.orange.shade800 : makitaTeal),
          height: 1.1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: makitaTeal,
        foregroundColor: whiteCard,
        elevation: 0,
        title: Text(
          "프로젝트: ${widget.project.name} | 누적: ${widget.project.estimatedMeters} m",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            decoration: BoxDecoration(
              color: whiteCard,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.precision_manufacturing,
                  size: 28,
                  color: makitaTeal,
                ),
                const SizedBox(width: 12),
                const Text(
                  "메이커 고정",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Row(
                    children: ["Swagelok", "Parker", "Hy-Lok"].map((maker) {
                      bool isSelected = _globalMaker == maker;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _globalMaker = maker),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? makitaTeal : lightBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? makitaTeal
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              maker,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isSelected ? whiteCard : textPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "배관 라인 구축 (드래그로 순서 변경)",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _addPoint,
                              icon: const Icon(
                                Icons.add,
                                color: whiteCard,
                                size: 18,
                              ),
                              label: const Text(
                                "포인트 추가",
                                style: TextStyle(color: whiteCard),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: makitaDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ReorderableListView.builder(
                            itemCount: _points.length,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                final point = _points.removeAt(oldIndex);
                                _points.insert(newIndex, point);
                                _calculate();
                              });
                            },
                            itemBuilder: (context, index) {
                              return Container(
                                key: ValueKey(_points[index].id),
                                child: Column(
                                  children: [
                                    _buildFittingCard(index),
                                    if (index < _points.length - 1)
                                      _buildLengthInputCard(index),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, color: Colors.black12),

                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          color: whiteCard,
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "1. 배치도",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: textPrimary,
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: List.generate(_points.length, (
                                        index,
                                      ) {
                                        return Row(
                                          children: [
                                            _buildVisualFitting(
                                              _points[index].fitting,
                                              index,
                                            ),
                                            if (index < _points.length - 1)
                                              _buildVisualPipe(
                                                _points[index].calculatedCut,
                                                _points[index]
                                                    .c2cController
                                                    .text
                                                    .isNotEmpty,
                                              ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(
                        height: 1,
                        color: Colors.black12,
                        thickness: 2,
                      ),

                      Expanded(
                        flex: 1,
                        child: Container(
                          color: Colors.grey.shade50,
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        "2. 컷팅 지시서",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Text(
                                        "같은 길이 합산",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Switch(
                                        value: _groupSameLengths,
                                        activeThumbColor: makitaTeal,
                                        onChanged: (val) => setState(
                                          () => _groupSameLengths = val,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: whiteCard,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: makitaTeal),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove,
                                            color: makitaTeal,
                                          ),
                                          onPressed: () => setState(() {
                                            if (_setMultiplier > 1)
                                              _setMultiplier--;
                                          }),
                                        ),
                                        Text(
                                          "$_setMultiplier SET",
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: textPrimary,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add,
                                            color: makitaTeal,
                                          ),
                                          onPressed: () =>
                                              setState(() => _setMultiplier++),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: whiteCard,
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: _buildCuttingListRenderer(),
                                ),
                              ),
                              const SizedBox(height: 16),

                              ElevatedButton(
                                onPressed:
                                    _points.any(
                                      (p) => p.c2cController.text.isNotEmpty,
                                    )
                                    ? _saveRecord
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: makitaTeal,
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  "$_setMultiplier 세트 전량 저장 (합계: ${(_points.sublist(0, _points.length - 1).fold(0.0, (sum, p) => sum + (p.calculatedCut > 0 ? p.calculatedCut : 0)) * _setMultiplier).toStringAsFixed(1)} mm)",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: whiteCard,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFittingCard(int index) {
    FittingItem item = _points[index].fitting;
    bool isNone = item.id == "none";

    return Row(
      children: [
        const Icon(Icons.drag_handle, color: Colors.grey),
        const SizedBox(width: 8),
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isNone ? Colors.grey.shade300 : makitaDark,
            shape: BoxShape.circle,
          ),
          child: Text(
            "PT${index + 1}",
            style: TextStyle(
              color: isNone ? Colors.grey.shade600 : whiteCard,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: whiteCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isNone ? Colors.grey.shade300 : makitaTeal,
                width: isNone ? 1 : 2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _openFittingSelector(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          _buildFittingBadge(item, isNone),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isNone)
                                  Text(
                                    "${item.tubeOD} 규격",
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                Text(
                                  isNone ? "부속을 고르세요" : item.name,
                                  style: TextStyle(
                                    color: isNone ? Colors.grey : textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isNone)
                            Text(
                              "- ${item.deduction}mm",
                              style: const TextStyle(
                                color: makitaDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                IconButton(
                  tooltip: "공제값 직접 입력",
                  icon: const Icon(Icons.edit_square, color: Colors.grey),
                  onPressed: () => _showCustomFittingDialog(index),
                ),
              ],
            ),
          ),
        ),
        if (_points.length > 2)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () => _removePoint(index),
          ),
      ],
    );
  }

  Widget _buildLengthInputCard(int index) {
    bool hasInput = _points[index].c2cController.text.trim().isNotEmpty;
    bool isInterference = hasInput && _points[index].calculatedCut < 0;

    return Padding(
      padding: const EdgeInsets.only(left: 48, top: 4, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 2,
            height: isInterference ? 70 : 50,
            color: Colors.grey.shade400,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _points[index].c2cController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _calculate(),
                  cursorColor: makitaTeal,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: "전체 길이 (C to C / End to End)",
                    labelStyle: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: isInterference ? Colors.red.shade50 : whiteCard,
                    suffixText: "mm",
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isInterference
                            ? Colors.red
                            : Colors.grey.shade300,
                        width: isInterference ? 2 : 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isInterference ? Colors.red : makitaTeal,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                if (isInterference)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_rounded,
                          color: Colors.red,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "간섭 발생! 입력값이 양쪽 피팅 공제값의 합보다 작습니다.",
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
  }

  Widget _buildCuttingListRenderer() {
    List<double> validCuts = _points
        .sublist(0, _points.length - 1)
        .where((p) => p.c2cController.text.isNotEmpty && p.calculatedCut > 0)
        .map((p) => p.calculatedCut)
        .toList();

    if (validCuts.isEmpty) {
      bool hasError = _points.any(
        (p) => p.c2cController.text.isNotEmpty && p.calculatedCut < 0,
      );
      return Center(
        child: Text(
          hasError ? "간섭이 발생한 구간을 수정하세요." : "치수를 입력하세요.",
          style: TextStyle(
            color: hasError ? Colors.red : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (_groupSameLengths) {
      Map<double, int> grouped = {};
      for (var cut in validCuts) {
        grouped[cut] = (grouped[cut] ?? 0) + 1;
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: grouped.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          double length = grouped.keys.elementAt(index);
          int count = grouped[length]!;
          int totalCount = count * _setMultiplier;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "길이: ${length.toStringAsFixed(1)} mm",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
              Text(
                "기본 $count개 x $_setMultiplier SET",
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              Text(
                "총 $totalCount 개",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: makitaTeal,
                ),
              ),
              Text(
                "= ${(length * totalCount).toStringAsFixed(1)} mm",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.redAccent,
                ),
              ),
            ],
          );
        },
      );
    } else {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _points.length - 1,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          if (_points[index].c2cController.text.isEmpty) {
            return const SizedBox.shrink();
          }
          double cutLen = _points[index].calculatedCut;
          if (cutLen < 0) {
            return const SizedBox.shrink();
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "PT${index + 1} ➔ PT${index + 2} 구간",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Text(
                "${cutLen.toStringAsFixed(1)} mm",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
              Text(
                "x $_setMultiplier 개",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: makitaTeal,
                ),
              ),
              Text(
                "= ${(cutLen * _setMultiplier).toStringAsFixed(1)} mm",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.redAccent,
                ),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildVisualFitting(FittingItem item, int index) {
    bool isNone = item.id == "none";
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: whiteCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isNone ? Colors.grey.shade300 : makitaTeal,
              width: 3,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "PT${index + 1}",
                style: TextStyle(
                  color: isNone ? Colors.grey : makitaTeal,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              _buildFittingBadge(item, isNone),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.name.length > 8 ? "${item.name.substring(0, 8)}.." : item.name,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildVisualPipe(double cutLength, bool hasInput) {
    bool isInterference = hasInput && cutLength < 0;

    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          if (isInterference)
            const Text(
              "⚠️ 간섭",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.red,
              ),
            )
          else
            Text(
              hasInput ? "${cutLength.toStringAsFixed(1)} mm" : "치수",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: hasInput ? Colors.redAccent : Colors.grey,
              ),
            ),
          const SizedBox(height: 8),
          Container(
            height: 6,
            color: isInterference
                ? Colors.red
                : (hasInput ? textPrimary : Colors.grey.shade300),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
