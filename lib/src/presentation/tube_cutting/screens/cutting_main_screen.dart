import 'package:flutter/material.dart';
import '../../../data/models/cutting_project_model.dart';
import '../../../data/models/fitting_item.dart';
import '../../../data/models/smart_fitting_db.dart';
import '../widgets/smart_fitting_selector_sheet.dart';
import '../widgets/visual_result_panel.dart';

const Color darkBg = Color(0xFF1E2124);
const Color cardBg = Color(0xFF2A2E33);
const Color makitaTeal = Color(0xFF007580);
const Color mutedWhite = Color(0xFFD0D4D9);

class CuttingMainScreen extends StatefulWidget {
  final CuttingProject project;

  const CuttingMainScreen({super.key, required this.project});

  @override
  State<CuttingMainScreen> createState() => _CuttingMainScreenState();
}

class _CuttingMainScreenState extends State<CuttingMainScreen> {
  final TextEditingController _totalLenCtrl = TextEditingController();

  String _selectedTubeSize = SmartFittingDB.tubeSizes[2]; // 기본 1/2" 셋팅

  // 텍스트(String) 대신 부속의 상세 정보(아이콘, 공제값 등)를 담은 객체 사용
  late FittingItem _startFitting;
  late FittingItem _endFitting;

  double _cutLength = 0.0;

  @override
  void initState() {
    super.initState();
    // 초기 부속 설정: "없음 (직관)"
    _startFitting = SmartFittingDB.getById("none");
    _endFitting = SmartFittingDB.getById("none");
  }

  @override
  void dispose() {
    _totalLenCtrl.dispose();
    super.dispose();
  }

  // 계산 로직 (객체의 deduction 값을 직접 가져와서 계산)
  void _calculate() {
    double total = double.tryParse(_totalLenCtrl.text) ?? 0.0;

    setState(() {
      _cutLength = total - _startFitting.deduction - _endFitting.deduction;
      if (_cutLength < 0) _cutLength = 0; // 마이너스 방지
    });
  }

  // 튜브 규격 변경 (터치형 칩 적용)
  void _onTubeSizeChanged(String newSize) {
    setState(() {
      _selectedTubeSize = newSize;
      _startFitting = SmartFittingDB.getById("none");
      _endFitting = SmartFittingDB.getById("none");
    });
    _calculate();
  }

  // ★ 핵심: 하단 스마트 시트 호출 및 결과 반영
  Future<void> _openFittingSelector(bool isStart) async {
    // 팝업을 띄우고 유저가 부속을 고를 때까지 기다림
    FittingItem? selectedItem = await SmartFittingSelectorSheet.show(context);

    // 유저가 부속을 정상적으로 골랐다면
    if (selectedItem != null) {
      setState(() {
        if (isStart) {
          _startFitting = selectedItem;
        } else {
          _endFitting = selectedItem;
        }
      });
      _calculate(); // 즉시 재계산
    }
  }

  // 작업 기록 누적 저장
  void _saveRecord() {
    if (_cutLength <= 0) return;

    setState(() {
      widget.project.addCutLength(_cutLength);
      _totalLenCtrl.clear();
      _cutLength = 0.0;
      // 다음 컷팅을 위해 양단 부속 초기화 (선택 사항)
      // _startFitting = SmartFittingDB.getById("none");
      // _endFitting = SmartFittingDB.getById("none");
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "기록 완료! (현재까지 누적 ${widget.project.estimatedMeters} m 소요)",
        ),
        backgroundColor: makitaTeal,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        title: Text(
          "[ ${widget.project.name} ] 스마트 컷팅 작업",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text(
                "총 누적 튜브: ${widget.project.estimatedMeters} m",
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      // 태블릿을 위한 좌우 분할
      body: Row(
        children: [
          // [좌측 패널]: 치수 및 피팅 설정 영역 (드롭다운 제거, 터치 UI 적용)
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "1. 튜브 규격 (Size)",
                      style: TextStyle(color: mutedWhite, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    // 드롭다운 대신 직관적인 버튼(ChoiceChip) 묶음 사용
                    Wrap(
                      spacing: 12,
                      children: SmartFittingDB.tubeSizes.map((size) {
                        return ChoiceChip(
                          label: Text(
                            size,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: _selectedTubeSize == size,
                          selectedColor: makitaTeal,
                          backgroundColor: cardBg,
                          labelStyle: TextStyle(
                            color: _selectedTubeSize == size
                                ? Colors.white
                                : Colors.grey,
                          ),
                          onSelected: (bool selected) {
                            if (selected) _onTubeSizeChanged(size);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 40),

                    const Text(
                      "2. 도면상 전체 치수 (Center to Center)",
                      style: TextStyle(color: mutedWhite, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _totalLenCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculate(),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: cardBg,
                        suffixText: "mm",
                        suffixStyle: const TextStyle(
                          color: Colors.grey,
                          fontSize: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    const Text(
                      "3. 양단 피팅(조인트) 선택 (터치하여 변경)",
                      style: TextStyle(color: mutedWhite, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // 시작점 부속 터치 영역
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "시작점 (Start)",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildTouchableFittingCard(
                                _startFitting,
                                () => _openFittingSelector(true),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // 끝점 부속 터치 영역
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "끝점 (End)",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildTouchableFittingCard(
                                _endFitting,
                                () => _openFittingSelector(false),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          Container(width: 1, color: Colors.white.withOpacity(0.05)), // 세로 구분선
          // [우측 패널]: 시각적 컷팅 확정(Visual Result) 화면
          Expanded(
            flex: 3,
            child: VisualResultPanel(
              startFitting: _startFitting,
              endFitting: _endFitting,
              cutLength: _cutLength,
              onSave: _cutLength > 0 ? _saveRecord : null,
            ),
          ),
        ],
      ),
    );
  }

  // 부속을 선택하기 위한 커다란 터치 카드 위젯 (드롭다운 대체)
  Widget _buildTouchableFittingCard(FittingItem item, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 80, // 카드 높이를 키워서 누르기 편하게
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            // 부속 아이콘
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, color: Colors.white70, size: 28),
            ),
            const SizedBox(width: 16),
            // 부속 이름
            Expanded(
              child: Text(
                item.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 변경할 수 있다는 화살표 아이콘
            const Icon(Icons.arrow_drop_down_circle, color: makitaTeal),
          ],
        ),
      ),
    );
  }
}
