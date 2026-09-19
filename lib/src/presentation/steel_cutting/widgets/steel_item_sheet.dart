import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../data/models/steel_cutting_project_model.dart';
import '../../../data/models/steel_shape_db.dart';
import '../../tube_cutting/cutting_theme.dart';
import '../steel_cutting_favorites.dart';
import 'steel_shape_picker_sheet.dart';

/// 새 항목을 추가하거나([existing]이 null) 기존 항목을 수정한다([existing]이
/// 있으면). 추가 모드는 "추가하기"를 눌러도 시트가 닫히지 않고 규격은
/// 유지한 채 길이/수량만 비워서, 같은 규격을 여러 길이로 연달아 입력하는
/// 현장 작업(예: 40x40x3 앵글을 200mm x4, 350mm x2로 나눠 자르는 경우)을
/// 한 번에 끝낼 수 있게 했다.
Future<void> showSteelItemSheet(
  BuildContext context, {
  SteelCutItem? existing,
  required void Function(SteelCutItem item) onSave,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _SteelItemSheetBody(existing: existing, onSave: onSave),
    ),
  );
}

class _SteelItemSheetBody extends StatefulWidget {
  final SteelCutItem? existing;
  final void Function(SteelCutItem item) onSave;

  const _SteelItemSheetBody({required this.existing, required this.onSave});

  @override
  State<_SteelItemSheetBody> createState() => _SteelItemSheetBodyState();
}

class _SteelItemSheetBodyState extends State<_SteelItemSheetBody> {
  SteelShapeItem? _shape;
  late final TextEditingController _lengthCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _noteCtrl;
  int _addedCount = 0;
  List<SteelQuickPick> _favorites = [];
  List<SteelQuickPick> _recents = [];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _shape = SteelShapeItem(
        id: e.id,
        category: e.category,
        label: e.shapeLabel,
      );
    }
    _lengthCtrl = TextEditingController(
      text: e != null ? e.length.toStringAsFixed(0) : '',
    );
    _qtyCtrl = TextEditingController(text: e != null ? '${e.qty}' : '1');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    // 즐겨찾기 별 아이콘이 길이 입력에 맞춰 즉시 켜지고/꺼지게.
    _lengthCtrl.addListener(() => setState(() {}));
    if (!_isEditing) _loadQuickPicks();
  }

  Future<void> _loadQuickPicks() async {
    final favorites = await loadFavoriteSteelItems();
    final recents = await loadRecentSteelItems();
    if (!mounted) return;
    setState(() {
      _favorites = favorites;
      _recents = recents;
    });
  }

  @override
  void dispose() {
    _lengthCtrl.dispose();
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickShape() async {
    final picked = await SteelShapePickerSheet.show(context);
    if (picked == null) return;
    if (picked.id == kCustomSteelShapeRequestId) {
      if (!mounted) return;
      final label = await _promptCustomShapeLabel();
      if (label == null || label.trim().isEmpty) return;
      setState(
        () => _shape = SteelShapeItem(
          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          category: 'CUSTOM',
          label: label.trim(),
        ),
      );
    } else {
      setState(() => _shape = picked);
    }
  }

  Future<String?> _promptCustomShapeLabel() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CuttingColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            cuttingDialogIcon(Icons.edit_note_rounded),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                "규격 직접 입력",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: CuttingColors.textPrimary,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "예: 50x25x2 각파이프",
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CuttingColors.primary,
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text(
              "확인",
              style: TextStyle(color: CuttingColors.surface),
            ),
          ),
        ],
      ),
    );
  }

  void _submit({required bool keepOpen}) {
    final shape = _shape;
    final length = double.tryParse(_lengthCtrl.text.trim());
    final qty = int.tryParse(_qtyCtrl.text.trim());

    if (shape == null) {
      showCuttingSnack(context, "규격을 선택해 주십시오.", isError: true);
      return;
    }
    if (length == null || length <= 0) {
      showCuttingSnack(context, "길이를 정확히 입력해 주십시오.", isError: true);
      return;
    }
    if (qty == null || qty <= 0) {
      showCuttingSnack(context, "수량을 정확히 입력해 주십시오.", isError: true);
      return;
    }

    final item = SteelCutItem(
      id:
          widget.existing?.id ??
          '${DateTime.now().millisecondsSinceEpoch}_$_addedCount',
      category: shape.category,
      shapeLabel: shape.label,
      length: length,
      qty: qty,
      note: _noteCtrl.text.trim(),
    );
    widget.onSave(item);
    HapticFeedback.lightImpact();
    saveRecentSteelItem(
      SteelQuickPick(
        category: shape.category,
        shapeLabel: shape.label,
        length: length,
      ),
    );

    if (!keepOpen) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _addedCount++;
      _lengthCtrl.clear();
      _qtyCtrl.text = '1';
      _noteCtrl.clear();
    });
    showCuttingSnack(
      context,
      "'${shape.label}' ${length.toStringAsFixed(0)}mm 추가했습니다.",
    );
  }

  SteelQuickPick? get _currentQuickPick {
    final shape = _shape;
    final length = double.tryParse(_lengthCtrl.text.trim());
    if (shape == null || length == null || length <= 0) return null;
    return SteelQuickPick(
      category: shape.category,
      shapeLabel: shape.label,
      length: length,
    );
  }

  Future<void> _toggleFavorite() async {
    final current = _currentQuickPick;
    if (current == null) return;
    final wasFav = _favorites.any((f) => f.key == current.key);
    final updated = await toggleFavoriteSteelItem(current);
    if (!mounted) return;
    setState(() => _favorites = updated);
    showCuttingSnack(context, wasFav ? "즐겨찾기에서 제거했습니다." : "즐겨찾기에 추가했습니다.");
  }

  Widget _buildQuickPickChip(SteelQuickPick pick, IconData icon) {
    return Material(
      color: CuttingColors.primarySoft,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() {
            _shape = SteelShapeItem(
              id: pick.category == 'CUSTOM'
                  ? 'custom_${DateTime.now().millisecondsSinceEpoch}'
                  : pick.shapeLabel,
              category: pick.category,
              label: pick.shapeLabel,
            );
            _lengthCtrl.text = pick.length.toStringAsFixed(0);
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: CuttingColors.primaryDark),
              const SizedBox(width: 4),
              Text(
                "${pick.shapeLabel} ${pick.length.toStringAsFixed(0)}mm",
                style: const TextStyle(
                  color: CuttingColors.primaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickPickSection() {
    final picks = <MapEntry<SteelQuickPick, IconData>>[
      ..._favorites.map((f) => MapEntry(f, Icons.star_rounded)),
      ..._recents
          .where((r) => !_favorites.any((f) => f.key == r.key))
          .map((r) => MapEntry(r, Icons.history_rounded)),
    ];
    if (picks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "즐겨찾기 / 최근 사용",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: picks.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) =>
                _buildQuickPickChip(picks[i].key, picks[i].value),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isFav =
        _currentQuickPick != null &&
        _favorites.any((f) => f.key == _currentQuickPick!.key);

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: CuttingColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    cuttingDialogIcon(Icons.add_box_outlined),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _isEditing ? "항목 수정" : "절단 항목 추가",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: CuttingColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 4),
                  _buildQuickPickSection(),
                ],
                Row(
                  children: [
                    Text(
                      "규격",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: isFav ? "즐겨찾기 해제" : "이 규격+길이 즐겨찾기",
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        isFav ? Icons.star_rounded : Icons.star_border_rounded,
                        color: isFav ? Colors.amber.shade700 : Colors.grey,
                        size: 20,
                      ),
                      onPressed: _currentQuickPick == null
                          ? null
                          : _toggleFavorite,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Material(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _pickShape,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _shape == null
                                ? Icons.search
                                : (_shape!.category == 'ANGLE'
                                      ? Icons.change_history_rounded
                                      : Icons.view_week_rounded),
                            color: CuttingColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _shape?.label ?? "탭해서 규격 선택",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _shape == null
                                    ? Colors.grey.shade500
                                    : CuttingColors.textPrimary,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildField(
                        label: "길이",
                        hint: "0",
                        controller: _lengthCtrl,
                        isNumber: true,
                        suffix: "mm",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildField(
                        label: "수량",
                        hint: "1",
                        controller: _qtyCtrl,
                        isNumber: true,
                        suffix: "개",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildField(
                  label: "비고 (선택)",
                  hint: "예: A구역 하단 프레임",
                  controller: _noteCtrl,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (!_isEditing)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _submit(keepOpen: true),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(
                              color: CuttingColors.primary,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "추가하고 계속",
                            style: TextStyle(
                              color: CuttingColors.primary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    if (!_isEditing) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _submit(keepOpen: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CuttingColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          _isEditing ? "저장" : "추가하고 닫기",
                          style: const TextStyle(
                            color: CuttingColors.surface,
                            fontSize: 15,
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

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool isNumber = false,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: CuttingColors.textPrimary,
          ),
          cursorColor: CuttingColors.primary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            suffixText: suffix,
            suffixStyle: const TextStyle(
              color: CuttingColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
