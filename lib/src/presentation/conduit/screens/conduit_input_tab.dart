import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 새롭게 만든 전선관 전용 데이터 매니저 임포트 (경로를 맞게 수정해 주세요)
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';

// 특수 바텀시트 경로는 기존 공용 위젯 폴더를 그대로 씁니다.
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_rolling_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_saddle_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_parallel_shrink_bottom_sheet.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate800 = Color(0xFF1E293B);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class ConduitInputTab extends StatefulWidget {
  const ConduitInputTab({super.key});
  @override
  State<ConduitInputTab> createState() => _ConduitInputTabState();
}

class _ConduitInputTabState extends State<ConduitInputTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  double _selectedType = 0.0; // 0.0: 직관, 90.0: 90도 벤딩
  double? _selectedRotation;
  final TextEditingController _lengthController = TextEditingController();

  final List<Map<String, dynamic>> _directions = [
    {"label": "UP", "val": 0.0, "icon": Icons.arrow_upward},
    {"label": "RIGHT", "val": 90.0, "icon": Icons.arrow_forward},
    {"label": "DOWN", "val": 180.0, "icon": Icons.arrow_downward},
    {"label": "LEFT", "val": 270.0, "icon": Icons.arrow_back},
    {"label": "FRONT", "val": 360.0, "icon": Icons.call_made},
    {"label": "BACK", "val": 450.0, "icon": Icons.call_received},
  ];

  bool get _canAdd {
    double val = double.tryParse(_lengthController.text) ?? 0.0;
    if (val <= 0) return false;
    if (_selectedType == 90.0 && _selectedRotation == null) return false;
    return true;
  }

  String _getDirectionText(double rot) {
    return _directions
        .firstWhere(
          (d) => d['val'] == rot,
          orElse: () => {"label": "${rot.toInt()}°"},
        )['label']
        .toString()
        .split(' ')
        .first;
  }

  IconData _getDirectionIcon(double rot) {
    return _directions.firstWhere(
      (d) => d['val'] == rot,
      orElse: () => {"icon": Icons.rotate_right},
    )['icon'];
  }

  @override
  void dispose() {
    _lengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListenableBuilder(
      listenable: ConduitDataManager(), // 변경: 전선관 매니저 감지
      builder: (context, child) {
        final manager = ConduitDataManager(); // 변경: 전선관 매니저 인스턴스
        final bendList = manager.bendList;

        // 🚀 [수정] 폴더블 대응으로 넓은 화면에서 마킹 탭과 나란히 붙여
        // 보여줄 수 있도록, 자체 Scaffold 대신 배경색만 칠하는 ColoredBox로
        // 바꿨다 (이 탭은 AppBar가 없으므로 내용 변화는 없다).
        return ColoredBox(
          color: slate100,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildHeader(bendList.length, manager),
                      Expanded(
                        child: bendList.isEmpty
                            ? _buildEmptyState()
                            : _buildReorderableList(manager),
                      ),
                    ],
                  ),
                ),
                _buildInputPanel(context, manager),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // 상단 영역 위젯 (헤더 및 리스트)
  // ==========================================

  Widget _buildHeader(int count, ConduitDataManager manager) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "전선관 배관 설계",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: slate900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "총 조립 구간",
                style: TextStyle(
                  color: slate600,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "$count",
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: makitaTeal,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                "개",
                style: TextStyle(color: slate600, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              if (count > 0)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      manager.clearBends();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Icon(
                        Icons.delete_sweep_rounded,
                        color: slate600.withValues(alpha: 0.8),
                        size: 24,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: slate600.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: slate900.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: slate100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_road_rounded,
                  size: 40,
                  color: slate600.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "설계된 배관이 없습니다",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: slate900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "하단 패널에서 배관 형태와 길이를\n입력하여 루트를 추가해보세요.",
                textAlign: TextAlign.center,
                style: TextStyle(color: slate600, height: 1.5, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReorderableList(ConduitDataManager manager) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: manager.bendList.length,
      onReorder: (oldIdx, newIdx) {
        manager.reorderBends(oldIdx, newIdx);
      },
      itemBuilder: (context, index) => _buildInputCard(
        index,
        manager.bendList[index],
        manager,
        Key('conduit_${manager.bendList[index].hashCode}_$index'),
      ),
    );
  }

  Widget _buildInputCard(
    int index,
    Map<String, dynamic> item,
    ConduitDataManager manager,
    Key key,
  ) {
    double angle = (item['angle'] as num).toDouble();
    double rotation = (item['rotation'] as num).toDouble();
    bool isStraight = angle == 0.0;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: slate900.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ReorderableDragStartListener(
          index: index,
          child: Icon(
            Icons.drag_indicator_rounded,
            color: slate600.withValues(alpha: 0.3),
          ),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: isStraight
                  ? slate100
                  : makitaTeal.withValues(alpha: 0.1),
              child: Icon(
                isStraight ? Icons.straighten : _getDirectionIcon(rotation),
                color: isStraight ? slate600 : makitaTeal,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isStraight
                        ? "직관 연장"
                        : "${angle.toStringAsFixed(1).replaceAll('.0', '')}° 벤딩",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: slate900,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        "길이: ${item['length']}mm",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: makitaTeal,
                        ),
                      ),
                      if (!isStraight) ...[
                        const SizedBox(width: 8),
                        Text(
                          "방향: ${_getDirectionText(rotation)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: slate600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.close_rounded,
            color: Colors.redAccent,
            size: 20,
          ),
          onPressed: () {
            HapticFeedback.mediumImpact();
            manager.removeBend(index);
          },
        ),
      ),
    );
  }

  // ==========================================
  // 하단 영역 위젯 (입력 폼)
  // ==========================================

  Widget _buildSectionLabel(
    String title, {
    String? subtitle,
    Color titleColor = slate600,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: slate600.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputPanel(BuildContext context, ConduitDataManager manager) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: slate900.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel("배관 형태"),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeSegment("직관 연장", 0.0, Icons.straighten),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTypeSegment(
                      "90° 벤딩",
                      90.0,
                      Icons.turn_right_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_selectedType == 90.0) ...[
                _buildSectionLabel(
                  "진행 방향 (필수)",
                  subtitle: "배관이 꺾여서 향할 방향을 선택해주세요",
                  titleColor: Colors.deepOrangeAccent,
                ),
                Column(
                  children: [
                    Row(
                      children: _directions
                          .take(3)
                          .map((d) => Expanded(child: _buildDirectionCell(d)))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: _directions
                          .skip(3)
                          .take(3)
                          .map((d) => Expanded(child: _buildDirectionCell(d)))
                          .toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              _buildSectionLabel("배관 길이 (mm)"),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _lengthController,
                      readOnly: true,
                      onTap: () async {
                        await MakitaNumpad.show(
                          context,
                          controller: _lengthController,
                          title: _selectedType == 0.0
                              ? "직관 길이 (mm)"
                              : "도달 거리 (mm)",
                        );
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: "길이 (mm) 입력",
                        filled: true,
                        fillColor: slate100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.edit,
                          color: slate600,
                          size: 20,
                        ),
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: slate900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  ElevatedButton.icon(
                    onPressed: _canAdd ? () => _addBend(manager) : null,
                    icon: const Icon(Icons.add_circle, size: 20),
                    label: const Text(
                      "추가",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: makitaTeal,
                      foregroundColor: pureWhite,
                      disabledBackgroundColor: slate600.withValues(alpha: 0.1),
                      disabledForegroundColor: slate600.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showSpecialToolsSheet(context, manager),
                  icon: const Icon(Icons.build_circle, color: slate800),
                  label: const Text(
                    "특수 벤딩 툴 (오프셋/새들 등)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: slate800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: slate600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSegment(String title, double typeValue, IconData icon) {
    bool isSelected = _selectedType == typeValue;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: isSelected ? makitaTeal : slate100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? makitaTeal : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _selectedType = typeValue;
              if (typeValue == 0.0) _selectedRotation = null;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: isSelected ? pureWhite : slate600, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? pureWhite : slate600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionCell(Map<String, dynamic> dir) {
    bool isSelected = _selectedRotation == dir['val'];
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: isSelected ? slate800 : slate100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedRotation = dir['val']);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(
                  dir['icon'],
                  color: isSelected ? pureWhite : slate600,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  dir['label'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? pureWhite : slate600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addBend(ConduitDataManager manager) {
    if (!_canAdd) return;

    double val = double.parse(_lengthController.text);
    HapticFeedback.mediumImpact();
    manager.addBend({
      'length': val,
      'angle': _selectedType,
      'rotation': _selectedType == 0.0 ? 0.0 : _selectedRotation!,
    });

    _lengthController.clear();
    setState(() {
      _selectedRotation = null;
    });
  }

  // ==========================================
  // 특수 벤딩 바텀 시트
  // ==========================================
  void _showSpecialToolsSheet(
    BuildContext context,
    ConduitDataManager manager,
  ) {
    double currentRot = manager.bendList.isNotEmpty
        ? (manager.bendList.last['rotation'] as num).toDouble()
        : 90.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: slate600.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "특수 벤딩 계산기",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: slate900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              _buildPopupToolBtn("오프셋 계산기", Icons.timeline, () {
                Navigator.pop(ctx);
                MobileOffsetBottomSheet.show(
                  context,
                  currentRotation: currentRot,
                  onAddMultipleBends: manager.addMultipleBends,
                );
              }),
              const SizedBox(height: 12),

              _buildPopupToolBtn("롤링 오프셋 계산기", Icons.sync, () {
                Navigator.pop(ctx);
                MobileRollingOffsetBottomSheet.show(
                  context,
                  currentRotation: currentRot,
                  onAddBend: (l, a, r) =>
                      manager.addBend({'length': l, 'angle': a, 'rotation': r}),
                );
              }),
              const SizedBox(height: 12),

              _buildPopupToolBtn("새들 벤딩 계산기", Icons.architecture, () {
                Navigator.pop(ctx);
                MobileSaddleBottomSheet.show(
                  context,
                  currentRotation: currentRot,
                  onAddBend: (l, a, r) =>
                      manager.addBend({'length': l, 'angle': a, 'rotation': r}),
                );
              }),
              const SizedBox(height: 12),

              _buildPopupToolBtn("평행/축소 벤딩 계산기", Icons.grid_view, () {
                Navigator.pop(ctx);
                MobileParallelShrinkBottomSheet.show(
                  context,
                  currentAngle: 30.0,
                );
              }),

              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPopupToolBtn(String label, IconData icon, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: slate100,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: makitaTeal, size: 26),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: slate900,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.chevron_right_rounded,
            color: slate600.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
