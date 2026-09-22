import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'package:flutter/services.dart';

// 새롭게 만든 전선관 전용 데이터 매니저 임포트 (경로를 맞게 수정해 주세요)
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';

// 특수 바텀시트 경로는 기존 공용 위젯 폴더를 그대로 씁니다.
import 'package:tubing_calculator/src/presentation/calculator/widgets/app_dialog.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_rolling_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_saddle_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_parallel_shrink_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/swipe_delete.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/undo_redo_buttons.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate800 = Color(0xFF1E293B);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

/// 전선관 "직관+각도"로 넣을 수 있는 가장 큰 각.
///
/// 🚀 [고침] 예전에는 180°까지 받아서 테이크업·게인 셈의 tan(θ/2)가 끝없이
/// 커졌다(180°에 1번 마킹 −1.9×10^18mm). 170°를 넘는 벤드는 전선관 현장에서
/// 쓰지 않으므로 여기서 막는다.
const double kConduitMaxAngle = 170.0;

class ConduitInputTab extends StatefulWidget {
  /// 목록 관리자. 없으면 계산기 목록(폰에 저장되는 것). 배치도 스키드 경로는 따로 준다.
  final ConduitDataManager? manager;

  const ConduitInputTab({super.key, this.manager});
  @override
  State<ConduitInputTab> createState() => _ConduitInputTabState();
}

class _ConduitInputTabState extends State<ConduitInputTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // 🚀 [바꿈] 배관 형태를 튜브 계산기처럼 한 줄 세 칸(90° 벤딩 | 직관+각도 |
  // 0° 직관)으로 맞췄다. "직관+각도"로 21°처럼 원하는 각도도 넣는다.
  String _bendType = "0"; // "90", "custom", "0"
  double _selectedAngle = 0.0;
  double? _selectedRotation;
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _customAngleController = TextEditingController();

  // 🚀 [추가] 튜브처럼 카드를 눌러 고친다.
  int? _editingIndex;

  // 방향 칸 순서도 튜브 계산기와 같게 둔다(UP·FRONT·LEFT / RIGHT·DOWN·BACK).
  final List<Map<String, dynamic>> _directions = [
    {"label": "UP", "val": 0.0, "icon": Icons.arrow_upward},
    {"label": "FRONT", "val": 360.0, "icon": Icons.call_made},
    {"label": "LEFT", "val": 270.0, "icon": Icons.arrow_back},
    {"label": "RIGHT", "val": 90.0, "icon": Icons.arrow_forward},
    {"label": "DOWN", "val": 180.0, "icon": Icons.arrow_downward},
    {"label": "BACK", "val": 450.0, "icon": Icons.call_received},
  ];

  bool get _canAdd {
    double val = double.tryParse(_lengthController.text) ?? 0.0;
    if (val <= 0) return false;
    if (_bendType == "custom" && _selectedAngle <= 0) return false;
    if (_selectedAngle > kConduitMaxAngle) return false;
    if (_selectedAngle > 0 && _selectedRotation == null) return false;
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
    _customAngleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListenableBuilder(
      listenable: widget.manager ?? ConduitDataManager(),
      builder: (context, child) {
        final manager = widget.manager ?? ConduitDataManager();
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
          // 좁은 화면에서는 제목이 줄바꿈된다(오른쪽 단추 자리를 먼저 준다).
          Flexible(
            child: Column(
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
              const SizedBox(width: 4),
              UndoRedoButtons(
                history: manager,
                onChanged: () {
                  if (_editingIndex != null) _cancelEdit();
                },
              ),
              if (count > 0)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    // 🚀 [고침] 누르자마자 다 지웠고, 고치던 줄 번호도 남아서
                    // 아래 '수정'이 조용히 아무 일도 안 했다. 먼저 묻고,
                    // 지우면 고치기도 그만둔다(↶로 되돌릴 수 있다).
                    onTap: () => _confirmClear(manager),
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
                "아래에서 배관 형태와 길이를\n넣고 추가를 누르십시오.",
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
        final to = newIdx > oldIdx ? newIdx - 1 : newIdx;
        manager.reorderBends(oldIdx, newIdx);
        if (_editingIndex != null) {
          setState(
            () => _editingIndex = movedIndex(_editingIndex!, oldIdx, to),
          );
        }
      },
      itemBuilder: (context, index) => _buildInputCard(
        index,
        manager.bendList[index],
        manager,
        ObjectKey(manager.bendList[index]),
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
    final bool isEditingThis = _editingIndex == index;

    // 🚀 [바꿈] X 단추 대신 왼쪽으로 밀어서 지운다.
    return Dismissible(
      key: key,
      direction: DismissDirection.endToStart,
      background: swipeDeleteBackground(radius: 16, bottomMargin: 12),
      onDismissed: (_) => _removeBend(manager, index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isEditingThis ? Colors.orange.shade50 : pureWhite,
          borderRadius: BorderRadius.circular(16),
          border: isEditingThis
              ? Border.all(color: Colors.orange.shade400, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: slate900.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          onTap: () => _startEdit(index, item),
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
                child: isStraight
                    ? const AppIcon(
                        AppGlyph.straightPipe,
                        color: slate600,
                        size: 20,
                      )
                    : Icon(
                        _getDirectionIcon(rotation),
                        color: makitaTeal,
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
                    // 🚀 [고침] 길이와 방향을 한 줄에 붙여 놓아서, 방향 글이
                    // 길면 줄이 넘쳤다("RIGHT OVERFLOWED"). 자리가 모자라면
                    // 아랫줄로 내려가게 한다.
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          "길이: ${item['length']}mm",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: makitaTeal,
                          ),
                        ),
                        if (!isStraight)
                          Text(
                            "방향: ${_getDirectionText(rotation)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: slate600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtAngle(double a) =>
      a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toStringAsFixed(1);

  /// 각도 칸 값을 0~[kConduitMaxAngle]로 묶어 읽는다. 넘치면 칸 글자도
  /// 묶은 값으로 바꿔서, 보이는 값과 셈에 쓰는 값이 같게 한다.
  double _customAngle() {
    final double? typed = double.tryParse(_customAngleController.text);
    if (typed == null) return 0.0;
    final double a = typed.clamp(0.0, kConduitMaxAngle);
    if (a != typed) _customAngleController.text = _fmtAngle(a);
    return a;
  }

  /// 카드를 누르면 그 줄 값을 아래 입력칸에 넣고 "수정"으로 바꾼다.
  void _startEdit(int index, Map<String, dynamic> item) {
    HapticFeedback.lightImpact();
    final angle = (item['angle'] as num?)?.toDouble() ?? 0.0;
    final len = (item['length'] as num?)?.toDouble() ?? 0.0;
    setState(() {
      _editingIndex = index;
      _selectedAngle = angle;
      if (angle == 0.0) {
        _bendType = "0";
      } else if (angle == 90.0) {
        _bendType = "90";
      } else {
        _bendType = "custom";
        _customAngleController.text = _fmtAngle(angle);
      }
      _selectedRotation = angle == 0.0
          ? null
          : (item['rotation'] as num?)?.toDouble();
      _lengthController.text = len == len.roundToDouble()
          ? len.toStringAsFixed(0)
          : len.toString();
    });
  }

  Future<void> _confirmClear(ConduitDataManager manager) async {
    HapticFeedback.heavyImpact();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: "전체 지우기",
        okText: "지우기",
        onCancel: () => Navigator.pop(ctx, false),
        onOk: () => Navigator.pop(ctx, true),
        content: AppDialog.message(
          "배관 목록 ${manager.bendList.length}줄을 모두 지우겠습니까?\n(위의 ↶로 되돌릴 수 있습니다)",
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (_editingIndex != null) _cancelEdit();
    manager.clearBends();
  }

  void _cancelEdit() {
    HapticFeedback.lightImpact();
    setState(() {
      _editingIndex = null;
      _bendType = "0";
      _selectedAngle = 0.0;
      _selectedRotation = null;
      _lengthController.clear();
      _customAngleController.clear();
    });
  }

  void _removeBend(ConduitDataManager manager, int index) {
    if (index < 0 || index >= manager.bendList.length) return;
    HapticFeedback.mediumImpact();
    final removed = manager.bendList[index];
    manager.removeBend(index);
    final depthAfter = manager.undoDepth;
    if (_editingIndex == index) {
      _cancelEdit();
    } else {
      setState(() => _editingIndex = indexAfterRemove(_editingIndex, index));
    }
    showDeletedSnackBar(
      context,
      number: index + 1,
      onUndo: () {
        // 그새 다른 일이 없었으면 되돌리기 한 단계와 같게(다시 하기가 이어진다).
        if (manager.undoDepth == depthAfter) {
          manager.undo();
        } else {
          manager.insertBend(index, removed);
        }
        if (_editingIndex != null && _editingIndex! >= index && mounted) {
          setState(() => _editingIndex = _editingIndex! + 1);
        }
      },
    );
  }

  // ==========================================
  // 하단 영역 위젯 (입력 폼)
  // ==========================================

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
        constraints: BoxConstraints(maxHeight: inputPanelMaxHeight(context)),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        for (final seg in const [
                          ["90", "90° 벤딩"],
                          ["custom", "직관+각도"],
                          ["0", "0° 직관"],
                        ])
                          ButtonSegment(
                            value: seg[0],
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                seg[1],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                      selected: {_bendType},
                      onSelectionChanged: (Set<String> newSelection) {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _bendType = newSelection.first;
                          if (_bendType == "90") {
                            _selectedAngle = 90.0;
                          } else if (_bendType == "0") {
                            _selectedAngle = 0.0;
                            _selectedRotation = null;
                          } else {
                            _selectedAngle = _customAngle();
                          }
                        });
                      },
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>(
                          (states) => states.contains(WidgetState.selected)
                              ? makitaTeal
                              : Colors.grey.shade100,
                        ),
                        foregroundColor: WidgetStateProperty.resolveWith<Color>(
                          (states) => states.contains(WidgetState.selected)
                              ? pureWhite
                              : slate600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_bendType == "custom") ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    await MakitaNumpad.show(
                      context,
                      controller: _customAngleController,
                      title: "벤딩 각도 입력 (°)",
                    );
                    if (!context.mounted) return;
                    final double typed =
                        double.tryParse(_customAngleController.text) ?? 0.0;
                    setState(() {
                      _selectedAngle = _customAngle();
                      if (_selectedAngle == 0.0) _selectedRotation = null;
                    });
                    if (typed > kConduitMaxAngle) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "각도는 ${kConduitMaxAngle.toInt()}°까지 넣을 수 있습니다. "
                            "그보다 크면 마킹 값이 맞지 않습니다.",
                          ),
                        ),
                      );
                    }
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _customAngleController,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.deepOrange,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        hintText: "원하는 각도를 입력하십시오 (예: 45)",
                        filled: true,
                        fillColor: Colors.orange.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.orange.shade200),
                        ),
                        suffixIcon: const Icon(
                          Icons.edit,
                          color: Colors.deepOrange,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
                        " *방향을 선택하십시오",
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    // 칸 높이를 폭에 비례로 잡으면 가로 화면에서 칸이 커져 281px 넘쳤다.
                    mainAxisExtent: 40,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _directions.length,
                  itemBuilder: (context, index) {
                    final dir = _directions[index];
                    final bool isSelected = _selectedRotation == dir['val'];
                    return InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedRotation = dir['val']);
                      },
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
                              dir['label'],
                              style: TextStyle(
                                color: isSelected ? makitaTeal : slate900,
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
                              title: _selectedAngle == 0.0
                                  ? "직관 길이 (mm)"
                                  : "도달 거리 (mm)",
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
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
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
                          side: const BorderSide(color: slate600, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Icon(Icons.close, color: slate600),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _canAdd ? () => _addBend(manager) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _editingIndex != null
                            ? Colors.orange.shade600
                            : makitaTeal,
                        foregroundColor: pureWhite,
                        disabledBackgroundColor: slate600.withValues(
                          alpha: 0.1,
                        ),
                        disabledForegroundColor: slate600.withValues(
                          alpha: 0.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      icon: Icon(
                        _editingIndex != null ? Icons.check : Icons.add_circle,
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
            ],
          ),
        ),
      ),
    );
  }

  void _addBend(ConduitDataManager manager) {
    if (!_canAdd) return;

    double val = double.parse(_lengthController.text);
    HapticFeedback.mediumImpact();
    final angle = _selectedAngle;
    final bend = {
      'length': val,
      'angle': angle,
      'rotation': angle == 0.0 ? 0.0 : _selectedRotation!,
    };
    if (_editingIndex != null) {
      // 고칠 때 다른 칸은 그대로 둔다.
      final Map<String, dynamic> old = _editingIndex! < manager.bendList.length
          ? manager.bendList[_editingIndex!]
          : const {};
      manager.updateBend(_editingIndex!, {...old, ...bend});
    } else {
      manager.addBend(bend);
    }

    _lengthController.clear();
    setState(() {
      _selectedRotation = null;
      _editingIndex = null;
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
    // 🚀 [고침] 특수 벤딩 계산기들이 튜브 벤더 제원으로 셈하고 있었다.
    // 전선관 설정(CLR·테이크업·게인·수축량 스위치)을 넘긴다.
    final specs = BendSheetSpecs.conduit(globalBenderSettings.value);

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

              _buildPopupToolBtn("오프셋 계산기", AppGlyph.offset, () {
                Navigator.pop(ctx);
                MobileOffsetBottomSheet.show(
                  context,
                  currentRotation: currentRot,
                  onAddMultipleBends: manager.addMultipleBends,
                  specs: specs,
                );
              }),
              const SizedBox(height: 12),

              _buildPopupToolBtn("롤링 오프셋 계산기", AppGlyph.rollingOffset, () {
                Navigator.pop(ctx);
                MobileRollingOffsetBottomSheet.show(
                  context,
                  currentRotation: currentRot,
                  onAddBend: (l, a, r) =>
                      manager.addBend({'length': l, 'angle': a, 'rotation': r}),
                  specs: specs,
                );
              }),
              const SizedBox(height: 12),

              _buildPopupToolBtn("새들 벤딩 계산기", AppGlyph.saddle, () {
                Navigator.pop(ctx);
                MobileSaddleBottomSheet.show(
                  context,
                  currentRotation: currentRot,
                  onAddBend: (l, a, r) =>
                      manager.addBend({'length': l, 'angle': a, 'rotation': r}),
                  specs: specs,
                );
              }),
              const SizedBox(height: 12),

              _buildPopupToolBtn("평행/축소 벤딩 계산기", AppGlyph.parallel, () {
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

  Widget _buildPopupToolBtn(String label, AppGlyph icon, VoidCallback onTap) {
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
          AppIcon(icon, color: makitaTeal, size: 28),
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
