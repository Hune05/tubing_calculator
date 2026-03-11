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

// 🚀 드래그 앤 드롭을 위해 각 포인트에 고유 ID(Key) 부여
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
  bool _groupSameLengths = false; // 🚀 동일 치수 합산 스위치 상태

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
        double c2c = double.tryParse(_points[i].c2cController.text) ?? 0.0;
        double deduction1 = _points[i].fitting.deduction;
        double deduction2 = _points[i + 1].fitting.deduction;
        double cut = c2c - deduction1 - deduction2;
        _points[i].calculatedCut = cut > 0 ? cut : 0.0;
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

  void _saveRecord() {
    double totalOneSet = _points.fold(
      0,
      (sum, point) => sum + point.calculatedCut,
    );
    double finalTotal = totalOneSet * _setMultiplier;

    if (finalTotal <= 0) {
      return;
    }

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
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isNone
            ? Colors.grey.shade100
            : makitaTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isNone
              ? Colors.grey.shade300
              : makitaTeal.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        isNone ? "-" : item.category.replaceAll('_', '\n'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: item.category.length > 4 ? 9 : 12,
          fontWeight: FontWeight.w900,
          color: isNone ? Colors.grey : makitaTeal,
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
          "프로젝트: ${widget.project.name} | 누적 튜브: ${widget.project.estimatedMeters} m",
          style: const TextStyle(fontWeight: FontWeight.w900),
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
                                "추가",
                                style: TextStyle(color: whiteCard),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: makitaDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 🚀 ReorderableListView 로 변경 (드래그 앤 드롭 지원!)
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
                                _calculate(); // 위치가 바뀌었으니 재계산
                              });
                            },
                            itemBuilder: (context, index) {
                              return Container(
                                key: ValueKey(_points[index].id), // 고유 키 필수
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
                              // 🚀 명칭 변경: 배관 도식화 -> 배치도
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
                                      // 🚀 동일 치수 합산 스위치 추가
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
                                        activeColor: makitaTeal,
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
                                          onPressed: () {
                                            setState(() {
                                              if (_setMultiplier > 1) {
                                                _setMultiplier--;
                                              }
                                            });
                                          },
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
                                  child:
                                      _buildCuttingListRenderer(), // 🚀 합산 로직 분리
                                ),
                              ),
                              const SizedBox(height: 16),

                              ElevatedButton(
                                onPressed:
                                    _points.any((p) => p.calculatedCut > 0)
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
                                  "$_setMultiplier 세트 전량 저장 (합계: ${(_points.fold(0.0, (sum, p) => sum + p.calculatedCut) * _setMultiplier).toStringAsFixed(1)} mm)",
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

  // 🚀 컷팅 지시서 렌더링 (합산 vs 개별)
  Widget _buildCuttingListRenderer() {
    List<double> validCuts = _points
        .sublist(0, _points.length - 1)
        .map((p) => p.calculatedCut)
        .where((c) => c > 0)
        .toList();

    if (validCuts.isEmpty) {
      return const Center(
        child: Text("치수를 입력하세요.", style: TextStyle(color: Colors.grey)),
      );
    }

    if (_groupSameLengths) {
      // 그룹화 (예: 150mm가 2개면 150.0: 2)
      Map<double, int> grouped = {};
      for (var cut in validCuts) {
        grouped[cut] = (grouped[cut] ?? 0) + 1;
      }

      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: grouped.length,
        separatorBuilder: (_, __) => const Divider(),
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
                "기본 ${count}개 x $_setMultiplier SET",
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
      // 기존 개별 나열 모드
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _points.length - 1,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          double cutLen = _points[index].calculatedCut;
          if (cutLen <= 0) {
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

  Widget _buildFittingCard(int index) {
    FittingItem item = _points[index].fitting;
    bool isNone = item.id == "none";

    return Row(
      children: [
        // 🚀 드래그 핸들 아이콘 추가
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
          child: InkWell(
            onTap: () => _openFittingSelector(index),
            child: Container(
              padding: const EdgeInsets.only(
                left: 12,
                right: 12,
                top: 10,
                bottom: 10,
              ),
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
                          isNone ? "부속을 고르세요" : item.displayName,
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
        if (_points.length > 2)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () => _removePoint(index),
          ),
      ],
    );
  }

  Widget _buildLengthInputCard(int index) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 48,
        right: 0,
        top: 4,
        bottom: 4,
      ), // 드래그 핸들 공간 확보
      child: Row(
        children: [
          Container(width: 2, height: 50, color: Colors.grey.shade400),
          const SizedBox(width: 24),
          Expanded(
            child: TextField(
              controller: _points[index].c2cController,
              keyboardType: TextInputType.number,
              onChanged: (_) => _calculate(),
              // 🚀 텍스트필드 보라색 픽스: 커서 컬러 마키타 틸 지정
              cursorColor: makitaTeal,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: textPrimary,
              ),
              decoration: InputDecoration(
                labelText: "C to C 치수",
                labelStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: whiteCard,
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
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                // 🚀 포커스 테두리 확실하게 마키타 틸 적용
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: makitaTeal, width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
          item.name,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildVisualPipe(double cutLength) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          // 🚀 "대기" -> "치수"
          Text(
            cutLength > 0 ? "${cutLength.toStringAsFixed(1)} mm" : "치수",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: cutLength > 0 ? Colors.redAccent : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 6,
            color: cutLength > 0 ? textPrimary : Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
