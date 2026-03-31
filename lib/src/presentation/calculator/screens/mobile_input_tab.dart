import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_rolling_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_saddle_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_parallel_shrink_bottom_sheet.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileInputTab extends StatefulWidget {
  const MobileInputTab({super.key});
  @override
  State<MobileInputTab> createState() => _MobileInputTabState();
}

class _MobileInputTabState extends State<MobileInputTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _lengthController = TextEditingController();
  double _selectedAngle = 90.0;
  double? _selectedRotation;
  int? _editingIndex;

  final List<Map<String, dynamic>> _directions = [
    {"label": "UP (위)", "val": 0.0, "icon": Icons.arrow_upward},
    {"label": "FRONT (앞)", "val": 360.0, "icon": Icons.call_made},
    {"label": "LEFT (좌)", "val": 270.0, "icon": Icons.arrow_back},
    {"label": "RIGHT (우)", "val": 90.0, "icon": Icons.arrow_forward},
    {"label": "DOWN (아래)", "val": 180.0, "icon": Icons.arrow_downward},
    {"label": "BACK (뒤)", "val": 450.0, "icon": Icons.call_received},
  ];

  @override
  void dispose() {
    _lengthController.dispose();
    super.dispose();
  }

  void _addSegment() {
    double length = double.tryParse(_lengthController.text) ?? 0.0;

    if (length <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("정확한 길이를 입력해주세요."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedAngle > 0 && _selectedRotation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("벤딩 진행 방향(6축)을 먼저 선택해주세요!"),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    final newBend = {
      'length': length,
      'angle': _selectedAngle,
      'rotation': _selectedAngle == 0.0 ? 0.0 : _selectedRotation!,
    };

    if (_editingIndex != null) {
      MobileBendDataManager().updateBend(_editingIndex!, newBend);
      setState(() => _editingIndex = null);
    } else {
      MobileBendDataManager().addBend(newBend);
    }

    setState(() {
      _lengthController.clear();
      _selectedRotation = null;
    });
  }

  void _cancelEdit() {
    HapticFeedback.lightImpact();
    setState(() {
      _editingIndex = null;
      _lengthController.clear();
      _selectedRotation = null;
    });
  }

  void _removeSegment(int index) {
    HapticFeedback.lightImpact();
    MobileBendDataManager().removeBend(index);
    setState(() {
      if (_editingIndex == index) {
        _cancelEdit();
      } else if (_editingIndex != null && _editingIndex! > index) {
        _editingIndex = _editingIndex! - 1;
      }
    });
  }

  void _clearAll() {
    HapticFeedback.heavyImpact();
    MobileBendDataManager().clearBends();
    setState(() => _cancelEdit());
  }

  void _addMultipleBends(List<Map<String, double>> bends) {
    MobileBendDataManager().addMultipleBends(bends);
  }

  void _addSingleBend(double length, double angle, double rotation) {
    MobileBendDataManager().addBend({
      'length': length,
      'angle': angle,
      'rotation': rotation,
    });
  }

  void _showSpecialBendingMenu() {
    double currentRot = _selectedRotation ?? 90.0;
    if (MobileBendDataManager().bendList.isNotEmpty) {
      final lastRot = MobileBendDataManager().bendList.last['rotation'];
      currentRot = (lastRot as num?)?.toDouble() ?? (_selectedRotation ?? 90.0);
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "특수 벤딩 계산 및 삽입",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: slate900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "현장 치수를 입력하면 벤딩 데이터가 자동으로 조립됩니다.",
                style: TextStyle(fontSize: 13, color: slate600),
              ),
              const SizedBox(height: 24),
              _buildSpecialMenuBtn("일반 오프셋 (Offset)", Icons.timeline, () {
                Navigator.pop(context);
                MobileOffsetBottomSheet.show(
                  context,
                  currentRotation: currentRot,
                  onAddMultipleBends: _addMultipleBends,
                );
              }),
              _buildSpecialMenuBtn("롤링 오프셋 (Rolling Offset)", Icons.sync, () {
                Navigator.pop(context);
                MobileRollingOffsetBottomSheet.show(
                  context,
                  currentRotation: currentRot,
                  onAddBend: _addSingleBend,
                );
              }),
              _buildSpecialMenuBtn("새들 벤딩 (Saddle)", Icons.architecture, () {
                Navigator.pop(context);
                MobileSaddleBottomSheet.show(
                  context,
                  currentRotation: currentRot,
                  onAddBend: _addSingleBend,
                );
              }),
              _buildSpecialMenuBtn(
                "평행 및 축소값 (Parallel & Shrink)",
                Icons.grid_view,
                () {
                  Navigator.pop(context);
                  MobileParallelShrinkBottomSheet.show(
                    context,
                    currentAngle: _selectedAngle,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialMenuBtn(String title, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: makitaTeal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: makitaTeal, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: slate900,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListenableBuilder(
      listenable: MobileBendDataManager(),
      builder: (context, child) {
        final bendList = MobileBendDataManager().bendList;

        return Column(
          children: [
            Expanded(
              flex: 4,
              child: Container(
                color: slate100,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      color: pureWhite,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "배관 라인 리스트",
                            style: TextStyle(
                              color: slate900,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (bendList.isNotEmpty)
                            InkWell(
                              onTap: _clearAll,
                              child: const Text(
                                "전체 삭제",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: bendList.isEmpty
                          ? const Center(
                              child: Text(
                                "아래에서 수치와 방향을 입력해\n배관을 조립해 주세요.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: slate600, height: 1.5),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: bendList.length,
                              itemBuilder: (context, index) {
                                final item = bendList[index];
                                bool isStraight =
                                    (item['angle'] as num?)?.toDouble() == 0.0;
                                double rotValue =
                                    (item['rotation'] as num?)?.toDouble() ??
                                    0.0;
                                String dirLabel = _directions.firstWhere(
                                  (d) => d['val'] == rotValue,
                                  orElse: () => {"label": "N/A"},
                                )['label'];
                                IconData dirIcon = _directions.firstWhere(
                                  (d) => d['val'] == rotValue,
                                  orElse: () => {"icon": Icons.help},
                                )['icon'];
                                bool isEditingThis = _editingIndex == index;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isEditingThis
                                        ? Colors.orange.shade50
                                        : pureWhite,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isEditingThis
                                          ? Colors.orange.shade400
                                          : Colors.grey.shade300,
                                      width: isEditingThis ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.02,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _editingIndex = index;
                                        _lengthController.text = item['length']
                                            .toString();
                                        _selectedAngle =
                                            (item['angle'] as num?)
                                                ?.toDouble() ??
                                            90.0;
                                        _selectedRotation =
                                            _selectedAngle == 0.0
                                            ? null
                                            : (item['rotation'] as num?)
                                                  ?.toDouble();
                                      });
                                    },
                                    leading: CircleAvatar(
                                      backgroundColor: isStraight
                                          ? Colors.grey.shade200
                                          : makitaTeal.withValues(alpha: 0.1),
                                      child: Icon(
                                        isStraight ? Icons.straighten : dirIcon,
                                        color: isStraight
                                            ? slate600
                                            : makitaTeal,
                                      ),
                                    ),
                                    title: Text(
                                      isStraight
                                          ? "직관 (Straight)"
                                          : "${(item['angle'] as num?)?.round()}° 벤딩 ($dirLabel)",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isStraight ? slate600 : slate900,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "길이: ${item['length']} mm",
                                      style: const TextStyle(
                                        color: makitaTeal,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      onPressed: () => _removeSegment(index),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: pureWhite,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "배관 형태",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: slate600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SegmentedButton<double>(
                              segments: const [
                                ButtonSegment(
                                  value: 90.0,
                                  label: Text(
                                    "90° 벤딩",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ButtonSegment(
                                  value: 0.0,
                                  label: Text(
                                    "0° 직관",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              selected: {_selectedAngle},
                              onSelectionChanged: (Set<double> newSelection) {
                                setState(() {
                                  _selectedAngle = newSelection.first;
                                  if (_selectedAngle == 0.0) {
                                    _selectedRotation = null;
                                  }
                                });
                              },
                              style: ButtonStyle(
                                backgroundColor:
                                    WidgetStateProperty.resolveWith<Color>(
                                      (states) =>
                                          states.contains(WidgetState.selected)
                                          ? makitaTeal
                                          : Colors.grey.shade100,
                                    ),
                                foregroundColor:
                                    WidgetStateProperty.resolveWith<Color>(
                                      (states) =>
                                          states.contains(WidgetState.selected)
                                          ? pureWhite
                                          : slate600,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_selectedAngle > 0) ...[
                        Row(
                          children: [
                            Text(
                              "진행 방향 (6축)",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedRotation == null
                                    ? Colors.redAccent
                                    : slate600,
                                fontSize: 13,
                              ),
                            ),
                            if (_selectedRotation == null)
                              const Text(
                                " *방향을 선택하세요",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 2.5,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: _directions.length,
                          itemBuilder: (context, index) {
                            final dir = _directions[index];
                            bool isSelected = _selectedRotation == dir['val'];
                            return InkWell(
                              onTap: () => setState(
                                () => _selectedRotation = dir['val'],
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? makitaTeal.withValues(alpha: 0.1)
                                      : Colors.grey.shade50,
                                  border: Border.all(
                                    color: isSelected
                                        ? makitaTeal
                                        : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      dir['icon'],
                                      size: 16,
                                      color: isSelected ? makitaTeal : slate600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      dir['label'].split(' ')[0],
                                      style: TextStyle(
                                        color: isSelected
                                            ? makitaTeal
                                            : slate900,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "길이 (mm)",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: slate600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    await MakitaNumpad.show(
                                      context,
                                      controller: _lengthController,
                                      title: "배관 길이 (mm)",
                                    );
                                    setState(() {});
                                  },
                                  child: AbsorbPointer(
                                    child: TextField(
                                      controller: _lengthController,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: makitaTeal,
                                        fontFamily: 'monospace',
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "0",
                                        filled: true,
                                        fillColor: Colors.grey.shade100,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        suffixIcon: const Icon(
                                          Icons.edit,
                                          color: slate600,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (_editingIndex != null) ...[
                            SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                onPressed: _cancelEdit,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: slate600,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                ),
                                child: const Icon(Icons.close, color: slate600),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _addSegment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _editingIndex != null
                                    ? Colors.orange.shade600
                                    : makitaTeal,
                                foregroundColor: pureWhite,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                              ),
                              icon: Icon(
                                _editingIndex != null
                                    ? Icons.check
                                    : Icons.add_circle,
                              ),
                              label: Text(
                                _editingIndex != null ? "수정" : "추가",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_editingIndex == null) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _showSpecialBendingMenu,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: makitaTeal,
                                width: 1.5,
                              ),
                              foregroundColor: makitaTeal,
                              backgroundColor: makitaTeal.withValues(
                                alpha: 0.05,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(
                              Icons.auto_awesome_mosaic,
                              size: 20,
                            ),
                            label: const Text(
                              "특수 벤딩 (오프셋 / 새들) 계산기",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
