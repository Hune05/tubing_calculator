import 'package:flutter/material.dart';
import '../../../data/models/cutting_project_model.dart';
import '../../../data/models/fitting_item.dart';
import '../../../data/models/smart_fitting_db.dart';
import '../widgets/smart_fitting_selector_sheet.dart';

// =========================================================
// 🎨 화이트 & 마키타 테마 팔레트 정의
// =========================================================
const Color lightBg = Color(0xFFF5F7FA); // 깨끗한 off-white 배경
const Color whiteCard = Colors.white; // 순백색 카드
const Color makitaTeal = Color(0xFF007580); // 마키타 틸 (메인 액센트)
const Color textPrimary = Colors.black87; // 진한 회색 텍스트
const Color textSecondary = Colors.black54; // 연한 회색 텍스트

// =========================================================
// 🧩 데이터 모델 리팩터링: 포인트를 하나의 객체로 통합
// =========================================================
class CutPoint {
  FittingItem fitting;
  TextEditingController c2cController;
  double calculatedCut;

  CutPoint({required this.fitting})
    : c2cController = TextEditingController(),
      calculatedCut = 0.0;

  void dispose() {
    c2cController.dispose();
  }
}

class CuttingMainScreen extends StatefulWidget {
  final CuttingProject project;

  const CuttingMainScreen({super.key, required this.project});

  @override
  State<CuttingMainScreen> createState() => _CuttingMainScreenState();
}

class _CuttingMainScreenState extends State<CuttingMainScreen> {
  String _selectedTubeSize = SmartFittingDB.tubeSizes[2]; // 기본 1/2"

  // 🌟 3개로 나뉘었던 리스트를 하나의 모델 리스트로 통합!
  List<CutPoint> _points = [];

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

  void _onTubeSizeChanged(String newSize) {
    setState(() {
      _selectedTubeSize = newSize;
      _points.clear();
      _initializeSequence();
    });
  }

  // 🚀 계산 로직
  void _calculate() {
    setState(() {
      // 마지막 포인트는 다음으로 가는 파이프가 없으므로 length - 1 까지만 반복
      for (int i = 0; i < _points.length - 1; i++) {
        double c2c = double.tryParse(_points[i].c2cController.text) ?? 0.0;
        double deduction1 = _points[i].fitting.deduction;
        double deduction2 = _points[i + 1].fitting.deduction;

        double cut = c2c - deduction1 - deduction2;
        _points[i].calculatedCut = cut > 0 ? cut : 0.0;
      }
    });
  }

  // 🚀 포인트 추가
  void _addPoint() {
    setState(() {
      _points.add(CutPoint(fitting: SmartFittingDB.getById("none")));
      _calculate();
    });
  }

  // 🚀 포인트 삭제
  void _removePoint(int index) {
    if (_points.length <= 2) return;
    setState(() {
      _points[index].dispose(); // 지우기 전에 컨트롤러 메모리 해제
      _points.removeAt(index);
      _calculate(); // 지운 후 재계산
    });
  }

  // 🌟 부속 선택 스마트 시트 호출 (파이어베이스 연동 버전으로 변경 완료!)
  Future<void> _openFittingSelector(int index) async {
    // 현재 선택된 규격(_selectedTubeSize)을 시트로 넘겨줍니다.
    FittingItem? selectedItem = await SmartFittingSelectorSheet.show(
      context,
      _selectedTubeSize,
    );

    if (selectedItem != null) {
      setState(() {
        _points[index].fitting = selectedItem;
      });
      _calculate();
    }
  }

  // 기록 저장
  void _saveRecord() {
    double totalCutSum = _points.fold(
      0,
      (sum, point) => sum + point.calculatedCut,
    );
    if (totalCutSum <= 0) return;

    setState(() {
      widget.project.addCutLength(totalCutSum);
      for (var point in _points) {
        point.c2cController.clear();
        point.calculatedCut = 0.0;
      }
      _calculate();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "멀티 컷팅 기록 완료! (총 ${totalCutSum.toStringAsFixed(1)}mm / 누적 ${widget.project.estimatedMeters}m)",
        ),
        backgroundColor: makitaTeal,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: whiteCard,
        elevation: 0,
        foregroundColor: textPrimary,
        title: Text(
          "[ ${widget.project.name} ] 멀티 포인트 컷팅",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: textPrimary,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text(
                "누적 튜브: ${widget.project.estimatedMeters} m",
                style: const TextStyle(
                  color: makitaTeal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // =========================================================
          // [좌측 패널]: 시퀀스 입력 영역 (세로 스크롤)
          // =========================================================
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 규격 선택
                  const Text(
                    "1. 튜브 규격 (Size)",
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: SmartFittingDB.tubeSizes.map((size) {
                      bool isSelected = _selectedTubeSize == size;
                      return ChoiceChip(
                        label: Text(
                          size,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: makitaTeal,
                        backgroundColor: whiteCard,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : textPrimary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(
                          color: isSelected ? makitaTeal : Colors.grey.shade300,
                        ),
                        onSelected: (bool selected) {
                          if (selected) _onTubeSizeChanged(size);
                        },
                      );
                    }).toList(),
                  ),
                  const Divider(height: 40, color: Colors.black12),

                  // 2. 멀티 포인트 리스트 입력
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "2. 배관 라인 설정",
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addPoint,
                        icon: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: const Text(
                          "부속 추가",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: makitaTeal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: ListView.builder(
                      itemCount: _points.length,
                      itemBuilder: (context, index) {
                        return Column(
                          children: [
                            _buildFittingCard(index),
                            // 마지막 요소가 아닐 때만 길이 입력창 렌더링
                            if (index < _points.length - 1)
                              _buildLengthInputCard(index),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 세로 구분선
          Container(width: 1, color: Colors.black12),

          // =========================================================
          // [우측 패널]: 도식화 뷰어 (가로 스크롤 배관도)
          // =========================================================
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const Text(
                    "배관 라인 도식화",
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "센터-투-센터(C2C) 치수 입력 시 실제 절단장(mm)이 자동 계산됩니다.",
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 50),

                  // 🌟 멀티 포인트 기차칸 UI (가로 스크롤)
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(_points.length, (index) {
                            return Row(
                              children: [
                                _buildVisualFitting(
                                  _points[index].fitting,
                                  index,
                                ),
                                // 마지막 요소가 아닐 때만 파이프 렌더링
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

                  const SizedBox(height: 40),

                  // 전체 저장 버튼
                  ElevatedButton.icon(
                    onPressed: _points.any((p) => p.calculatedCut > 0)
                        ? _saveRecord
                        : null,
                    icon: const Icon(Icons.save_outlined, size: 28),
                    label: Text(
                      "현재 시퀀스 전체 저장 (총 ${_points.length}포인트)",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: makitaTeal,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      minimumSize: const Size(double.infinity, 64),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // 위젯 빌더 헬퍼 함수들
  // =========================================================

  // 좌측: 부속 선택 카드
  Widget _buildFittingCard(int index) {
    FittingItem item = _points[index].fitting;
    bool isNone = item.id == "none";

    return Row(
      children: [
        // 포인트 번호 (PT1, PT2...)
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isNone
                ? Colors.grey.shade200
                : makitaTeal.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            "PT${index + 1}",
            style: TextStyle(
              color: isNone ? textSecondary : makitaTeal,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // 부속 카드
        Expanded(
          child: InkWell(
            onTap: () => _openFittingSelector(index),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: whiteCard,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    color: isNone ? Colors.grey : makitaTeal,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isNone)
                          Text(
                            item.maker,
                            style: const TextStyle(
                              color: makitaTeal,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Text(
                          item.displayName,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: isNone
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isNone)
                    Text(
                      "- ${item.deduction}mm",
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_drop_down_circle_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        // 삭제 버튼
        if (_points.length > 2)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: IconButton(
              icon: const Icon(
                Icons.remove_circle_outline,
                color: Colors.redAccent,
                size: 24,
              ),
              onPressed: () => _removePoint(index),
            ),
          ),
      ],
    );
  }

  // 좌측: 기장(C2C) 입력 카드
  Widget _buildLengthInputCard(int index) {
    return Padding(
      padding: const EdgeInsets.only(left: 21, top: 4, bottom: 4),
      child: Row(
        children: [
          // 연결 실선 도식
          Container(width: 2, height: 60, color: Colors.grey.shade300),
          const SizedBox(width: 32),
          // 입력창
          Expanded(
            child: TextField(
              controller: _points[index].c2cController,
              keyboardType: TextInputType.number,
              onChanged: (_) => _calculate(),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
              decoration: InputDecoration(
                labelText: "C to C (PT${index + 1} ➔ PT${index + 2}) 치수 입력",
                labelStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: whiteCard,
                suffixText: "mm",
                suffixStyle: const TextStyle(color: Colors.grey, fontSize: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: makitaTeal, width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 우측: 도식화 뷰어 내의 부속(밝은 박스)
  Widget _buildVisualFitting(FittingItem item, int index) {
    bool isNone = item.id == "none";
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: whiteCard,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: isNone
                  ? Colors.grey.shade200
                  : makitaTeal.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "PT${index + 1}",
                style: TextStyle(
                  color: isNone ? Colors.grey : makitaTeal,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                item.icon,
                size: 36,
                color: isNone ? Colors.grey.shade400 : textPrimary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 90,
          child: Text(
            item.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textPrimary,
              fontSize: 11,
              fontWeight: isNone ? FontWeight.normal : FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // 우측: 도식화 뷰어 내의 파이프(깔끔한 직선 라인)
  Widget _buildVisualPipe(double cutLength) {
    bool hasLength = cutLength > 0;
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hasLength ? "${cutLength.toStringAsFixed(1)} mm" : "C2C 대기",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: hasLength ? makitaTeal : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 8,
                color: hasLength ? Colors.grey.shade300 : Colors.grey.shade200,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 3, height: 24, color: textPrimary),
                  Container(width: 3, height: 24, color: textPrimary),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
