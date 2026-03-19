import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

  // 🚀 [자재 관리 연동 핵심] 부모(ProjectManagementPage)로부터 받는 콜백
  final Function(
    double totalTubeLength,
    List<Map<String, dynamic>> fittingsList,
  )?
  onSaveCallback;

  const CuttingMainScreen({
    super.key,
    required this.project,
    this.onSaveCallback,
  });

  @override
  State<CuttingMainScreen> createState() => _CuttingMainScreenState();
}

class _CuttingMainScreenState extends State<CuttingMainScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  String _globalMaker = "Swagelok";
  List<CutPoint> _points = [];
  int _setMultiplier = 1;
  bool _groupSameLengths = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSequence();
    _loadDraftState();
  }

  void _initializeSequence() {
    _points = [
      CutPoint(fitting: SmartFittingDB.getById("none")),
      CutPoint(fitting: SmartFittingDB.getById("none")),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDraftState();
    for (var point in _points) {
      point.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveDraftState();
    }
  }

  String get _draftKey {
    if (widget.onSaveCallback == null) {
      return 'cutting_draft_standalone_absolute_fixed_key';
    }
    String idStr = widget.project.id.toString();
    if (idStr.isEmpty || idStr == 'null') {
      return 'cutting_draft_fallback_${widget.project.name}';
    }
    return 'cutting_draft_$idStr';
  }

  Future<void> _saveDraftState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateData = {
        'globalMaker': _globalMaker,
        'setMultiplier': _setMultiplier,
        'groupSameLengths': _groupSameLengths,
        'points': _points.map((p) {
          return {
            'fittingId': p.fitting.id,
            'c2c': p.c2cController.text,
            'isCustom': p.fitting.category == 'CUSTOM',
            'customName': p.fitting.name,
            'customDed': p.fitting.deduction,
            'customOD': p.fitting.tubeOD,
          };
        }).toList(),
      };
      await prefs.setString(_draftKey, jsonEncode(stateData));
    } catch (e) {
      debugPrint("임시 저장 실패: $e");
    }
  }

  Future<void> _loadDraftState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_draftKey);

      if (jsonStr != null) {
        final stateData = jsonDecode(jsonStr);
        setState(() {
          _globalMaker = stateData['globalMaker'] ?? "Swagelok";
          _setMultiplier = stateData['setMultiplier'] ?? 1;
          _groupSameLengths = stateData['groupSameLengths'] ?? false;

          if (stateData['points'] != null) {
            for (var p in _points) p.dispose();

            _points = (stateData['points'] as List).map((pData) {
              CutPoint p = CutPoint(fitting: SmartFittingDB.getById("none"));
              if (pData['isCustom'] == true) {
                p.fitting = FittingItem(
                  id: pData['fittingId'] ?? "custom",
                  category: "CUSTOM",
                  name: pData['customName'] ?? "커스텀 부속",
                  tubeOD: pData['customOD'] ?? "미지정",
                  maker: "CUSTOM",
                  deduction: (pData['customDed'] as num?)?.toDouble() ?? 0.0,
                  icon: Icons.extension,
                );
              } else {
                p.fitting = SmartFittingDB.getById(
                  pData['fittingId'] ?? "none",
                );
              }
              p.c2cController.text = pData['c2c'] ?? "";
              return p;
            }).toList();
          }
        });
        _calculate();
      }
    } catch (e) {
      debugPrint("불러오기 실패: $e");
    }
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
    _saveDraftState();
  }

  void _addPoint() {
    setState(() {
      _points.add(CutPoint(fitting: SmartFittingDB.getById("none")));
      _calculate();
    });
  }

  void _removePoint(int index) {
    if (_points.length <= 2) return;
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

  void _showCustomFittingDialog(int index) {
    TextEditingController nameCtrl = TextEditingController(text: "커스텀 부속");
    TextEditingController specCtrl = TextEditingController();
    TextEditingController deductionCtrl = TextEditingController();

    Widget buildInputField({
      required String label,
      required String hint,
      required TextEditingController controller,
      bool isNumber = false,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: makitaDark,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: isNumber
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
            cursorColor: makitaTeal,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
              suffixText: isNumber ? "mm" : null,
              suffixStyle: const TextStyle(
                color: makitaTeal,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: makitaTeal, width: 2.5),
              ),
            ),
          ),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: whiteCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: makitaTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.extension,
                        color: makitaTeal,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "커스텀 부속 설정",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                buildInputField(
                  label: "품명 (예: 볼 밸브, 체크 밸브)",
                  hint: "품명 입력",
                  controller: nameCtrl,
                ),
                const SizedBox(height: 16),
                buildInputField(
                  label: "규격 (예: 1/2, 3/8, 12mm)",
                  hint: "규격 입력",
                  controller: specCtrl,
                ),
                const SizedBox(height: 16),
                buildInputField(
                  label: "적용할 공제값 (Deduction)",
                  hint: "0.0",
                  controller: deductionCtrl,
                  isNumber: true,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: Colors.grey.shade300,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "취소",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: makitaTeal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          double customDed =
                              double.tryParse(deductionCtrl.text) ?? 0.0;
                          String specStr = specCtrl.text.trim().isEmpty
                              ? "미지정"
                              : specCtrl.text.trim();

                          setState(() {
                            _points[index].fitting = FittingItem(
                              id: "custom_${DateTime.now().millisecondsSinceEpoch}",
                              category: "CUSTOM",
                              name: nameCtrl.text.trim().isEmpty
                                  ? "커스텀 부속"
                                  : nameCtrl.text.trim(),
                              tubeOD: specStr, // 🚀 규격 정확히 저장
                              maker: "CUSTOM",
                              deduction: customDed,
                              icon: Icons.extension,
                            );
                            _calculate();
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          "적용하기",
                          style: TextStyle(
                            color: whiteCard,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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

    if (finalTotal <= 0) return;

    FocusScope.of(context).unfocus();

    // 🚀 [자재 관리용 완벽 분리] 제조사, 규격, 품명, 수량을 담을 객체 리스트
    Map<String, Map<String, dynamic>> groupedFittings = {};
    int totalFittingCount = 0;

    for (var point in _points) {
      if (point.fitting.id != "none") {
        String maker = point.fitting.category == "CUSTOM"
            ? "CUSTOM"
            : _globalMaker;
        String spec = point.fitting.tubeOD;
        String name = point.fitting.name;

        // 고유 식별 키 (제조사_규격_이름)
        String uniqueKey = "${maker}_${spec}_$name";

        if (groupedFittings.containsKey(uniqueKey)) {
          groupedFittings[uniqueKey]!['qty'] += 1;
        } else {
          groupedFittings[uniqueKey] = {
            'maker': maker,
            'spec': spec,
            'name': name,
            'qty': 1,
            'type': 'FITTING',
          };
        }
      }
    }

    List<Map<String, dynamic>> finalFittingsList = [];
    groupedFittings.forEach((key, data) {
      data['qty'] = (data['qty'] as int) * _setMultiplier;
      totalFittingCount += data['qty'] as int;
      // 🚀 [핵심] InventoryPage에서 필터링하는 방식과 100% 동일하게 db_name 생성!
      data['db_name'] = "[${data['maker']}] ${data['spec']} ${data['name']}";
      finalFittingsList.add(data);
    });

    setState(() {
      try {
        widget.project.recordUsage(
          tubeLengthMm: finalTotal,
          fittings: {},
          multiplier: _setMultiplier,
        );
      } catch (e) {
        debugPrint("단독 모드 에러 무시: $e");
      }

      // 🚀 부모(ProjectManagementPage)의 바구니로 완벽하게 규격화된 데이터를 쏩니다!
      if (widget.onSaveCallback != null) {
        widget.onSaveCallback!(finalTotal, finalFittingsList);
      }

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
          "튜브 총 ${finalTotal.toStringAsFixed(1)}mm 및 피팅 ${totalFittingCount}개 작업 완료!",
          style: const TextStyle(fontWeight: FontWeight.bold),
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
    super.build(context);

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: makitaTeal,
        foregroundColor: whiteCard,
        elevation: 0,
        title: Text(
          "프로젝트: ${widget.project.name}",
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
                          onTap: () {
                            setState(() => _globalMaker = maker);
                            _saveDraftState();
                          },
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
                            proxyDecorator:
                                (
                                  Widget child,
                                  int index,
                                  Animation<double> animation,
                                ) {
                                  return Material(
                                    color: Colors.transparent,
                                    elevation: 0,
                                    child: _buildFittingCard(index),
                                  );
                                },
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                List<FittingItem> currentFittings = _points
                                    .map((p) => p.fitting)
                                    .toList();
                                final movedFitting = currentFittings.removeAt(
                                  oldIndex,
                                );
                                currentFittings.insert(newIndex, movedFitting);

                                for (int i = 0; i < _points.length; i++) {
                                  _points[i].fitting = currentFittings[i];
                                }
                                _calculate();
                                _saveDraftState();
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
                                        onChanged: (val) {
                                          setState(
                                            () => _groupSameLengths = val,
                                          );
                                          _saveDraftState();
                                        },
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
                                                _saveDraftState();
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
                                          onPressed: () {
                                            setState(() {
                                              _setMultiplier++;
                                              _saveDraftState();
                                            });
                                          },
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
                                  "$_setMultiplier 세트 작업 완료 (저장 및 초기화)",
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
    bool isCustom = item.category == "CUSTOM";

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
                              isCustom ? "수동" : "- ${item.deduction}mm",
                              style: TextStyle(
                                color: isCustom
                                    ? Colors.orange.shade800
                                    : makitaDark,
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
          if (_points[index].c2cController.text.isEmpty)
            return const SizedBox.shrink();
          double cutLen = _points[index].calculatedCut;
          if (cutLen < 0) return const SizedBox.shrink();
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
