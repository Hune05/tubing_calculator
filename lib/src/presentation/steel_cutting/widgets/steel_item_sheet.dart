import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../data/models/steel_cutting_project_model.dart';
import '../../../data/models/steel_shape_db.dart';
import '../../tube_cutting/cutting_math.dart' show parseLengthInput, fmtMm;
import '../../tube_cutting/cutting_theme.dart';
import '../steel_custom_shapes.dart';
import '../steel_cutting_favorites.dart';
import '../steel_multi_input.dart';
import '../steel_shape_icons.dart';
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
  // 자주 쓰는 길이(많이 넣은 순서, 두 번 이상 쓴 것만).
  List<double> _topLengths = [];
  // 한 줄로 여러 길이 입력.
  late final TextEditingController _multiCtrl;
  bool _multiOpen = false;

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
    _lengthCtrl = TextEditingController(text: e != null ? fmtMm(e.length) : '');
    _qtyCtrl = TextEditingController(text: e != null ? '${e.qty}' : '1');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    // 즐겨찾기 별 아이콘이 길이 입력에 맞춰 즉시 켜지고/꺼지게.
    _lengthCtrl.addListener(() => setState(() {}));
    _qtyCtrl.addListener(() => setState(() {}));
    _multiCtrl = TextEditingController();
    _multiCtrl.addListener(() => setState(() {}));
    if (!_isEditing) {
      _loadQuickPicks();
      _loadTopLengths();
    }
  }

  // 칩을 길게 누르면 그 길이를 자주 쓰는 길이에서 뺀다(잘못 들어간 길이를 치운다).
  Future<void> _forgetLength(double v) async {
    HapticFeedback.selectionClick();
    final ok = await showCuttingConfirmDialog(
      context,
      title: "자주 쓰는 길이에서 빼기",
      message: "${fmtMm(v)}mm를 자주 쓰는 길이에서 뺍니다. 다시 여러 번 쓰면 또 나옵니다.",
      confirmLabel: "빼기",
      icon: Icons.straighten_rounded,
    );
    if (!ok || !mounted) return;
    await forgetSteelLength(v, shapeLabel: _shape?.label ?? '');
    if (!mounted) return;
    await _loadTopLengths();
    if (!mounted) return;
    showCuttingSnack(context, "${fmtMm(v)}mm를 자주 쓰는 길이에서 뺐습니다.");
  }

  Future<void> _loadTopLengths() async {
    final top = await loadTopSteelLengths(shapeLabel: _shape?.label ?? '');
    if (!mounted) return;
    setState(() => _topLengths = top);
  }

  // 여러 길이를 한 번에 추가한다(고른 규격·비고를 모두에게 적용).
  Future<void> _addMulti() async {
    final shape = _shape;
    if (shape == null) {
      showCuttingSnack(context, "규격을 선택해 주십시오.", isError: true);
      return;
    }
    final p = parseMultiLengths(_multiCtrl.text);
    if (p.bad.isNotEmpty) {
      showCuttingSnack(
        context,
        "읽을 수 없는 값이 있습니다: ${p.bad.join(', ')}",
        isError: true,
      );
      return;
    }
    if (p.entries.isEmpty) {
      showCuttingSnack(
        context,
        "길이를 적어 주십시오. 예: 500x3, 800x2, 1200",
        isError: true,
      );
      return;
    }
    final note = _noteCtrl.text.trim();
    for (final e in p.entries) {
      widget.onSave(
        SteelCutItem(
          id: '${DateTime.now().millisecondsSinceEpoch}_${_addedCount++}',
          category: shape.category,
          shapeLabel: shape.label,
          length: e.length,
          qty: e.qty,
          note: note,
        ),
      );
    }
    HapticFeedback.lightImpact();
    await bumpSteelLengthUse(
      p.entries.map((e) => e.length),
      shapeLabel: shape.label,
    );
    if (!mounted) return;
    setState(() => _multiCtrl.clear());
    showCuttingSnack(
      context,
      "'${shape.label}' ${p.entries.length}건(${p.pieces}개)을 추가했습니다.",
    );
    _loadTopLengths();
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
    _multiCtrl.dispose();
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
    // 규격이 바뀌면 그 규격에서 자주 쓰는 길이로 칩을 다시 읽는다.
    _loadTopLengths();
  }

  Future<String?> _promptCustomShapeLabel() =>
      promptCustomSteelShapeLabel(context);

  void _submit({required bool keepOpen}) {
    final shape = _shape;
    final parsed = parseLengthInput(_lengthCtrl.text);
    final length = parsed.value;
    final qty = int.tryParse(_qtyCtrl.text.trim());

    if (shape == null) {
      showCuttingSnack(context, "규격을 선택해 주십시오.", isError: true);
      return;
    }
    if (parsed.unreadable) {
      showCuttingSnack(
        context,
        "길이를 숫자로 읽을 수 없습니다. 예: 1200 또는 1200.5",
        isError: true,
      );
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
    // 여러 길이 입력·± 단추와 같은 한계. 너무 많으면 재단 계획·PDF 계산이 매우 느려진다.
    if (qty > 9999) {
      showCuttingSnack(context, "수량은 9999개까지 적을 수 있습니다.", isError: true);
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
    // 길이를 센 뒤에 칩을 다시 읽는다(방금 넣은 길이가 바로 반영된다).
    bumpSteelLengthUse([length], shapeLabel: shape.label).then((_) {
      if (mounted) _loadTopLengths();
    });
    // 직접 입력한 규격은 다음에 "내 규격"에서 고를 수 있게 적어 둔다.
    if (shape.category == 'CUSTOM') addCustomSteelShape(shape.label);
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
    showCuttingSnack(context, "'${shape.label}' ${fmtMm(length)}mm 추가했습니다.");
  }

  // 길이 칸의 값을 [delta]만큼 바꾼다(비어 있으면 0에서 시작, 0 아래로는 내려가지 않는다).
  void _bumpLength(double delta) {
    HapticFeedback.selectionClick();
    final cur = parseLengthInput(_lengthCtrl.text).value ?? 0;
    final next = (cur + delta).clamp(0, 1e9).toDouble();
    _lengthCtrl.text = next == 0 ? '' : fmtMm(next);
    _lengthCtrl.selection = TextSelection.collapsed(
      offset: _lengthCtrl.text.length,
    );
  }

  void _bumpQty(int delta) {
    HapticFeedback.selectionClick();
    final cur = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
    final next = (cur + delta).clamp(1, 9999);
    _qtyCtrl.text = '$next';
    _qtyCtrl.selection = TextSelection.collapsed(offset: _qtyCtrl.text.length);
  }

  Widget _stepChip({
    required Key key,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: CuttingColors.primarySoft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: CuttingColors.primaryDark,
            ),
          ),
        ),
      ),
    );
  }

  // "1250mm × 3개 = 3750mm" — 길이와 수량이 둘 다 유효할 때만.
  String? get _previewText {
    final len = parseLengthInput(_lengthCtrl.text).value;
    final qty = int.tryParse(_qtyCtrl.text.trim());
    if (len == null || len <= 0 || qty == null || qty <= 0) return null;
    return '${fmtMm(len)}mm × $qty개 = ${fmtMm(len * qty)}mm';
  }

  SteelQuickPick? get _currentQuickPick {
    final shape = _shape;
    final length = parseLengthInput(_lengthCtrl.text).value;
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
            _lengthCtrl.text = fmtMm(pick.length);
          });
          _loadTopLengths();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: CuttingColors.primaryDark),
              const SizedBox(width: 4),
              Text(
                "${pick.shapeLabel} ${fmtMm(pick.length)}mm",
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
                          anyIcon(
                            _shape == null
                                ? Icons.search
                                : iconForSteel(_shape!.category),
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
                          const Icon(AppIcons.forward, color: Colors.grey),
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
                        fieldKey: const Key('steel_length_field'),
                        errorText: parseLengthInput(_lengthCtrl.text).unreadable
                            ? "숫자로 읽을 수 없습니다"
                            : null,
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
                        fieldKey: const Key('steel_qty_field'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 길이와 수량을 손가락으로 바로 고치는 버튼(장갑 낀 손도 누를 수 있게 넉넉한 크기).
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          for (final d in const [-100, -10, 10, 100]) ...[
                            if (d != -100) const SizedBox(width: 4),
                            Expanded(
                              child: _stepChip(
                                key: Key('len_step_$d'),
                                label: d > 0 ? '+$d' : '$d',
                                onTap: () => _bumpLength(d.toDouble()),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Expanded(
                            child: _stepChip(
                              key: const Key('qty_minus'),
                              label: '−',
                              onTap: () => _bumpQty(-1),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _stepChip(
                              key: const Key('qty_plus'),
                              label: '+',
                              onTap: () => _bumpQty(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // 자주 넣은 길이: 누르면 길이 칸에 들어간다.
                if (_topLengths.isNotEmpty && !_isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "자주 쓰는 길이",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        for (final v in _topLengths)
                          InkWell(
                            key: Key('freq_len_${fmtMm(v)}'),
                            borderRadius: BorderRadius.circular(8),
                            onLongPress: () => _forgetLength(v),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _lengthCtrl.text = fmtMm(v);
                              _lengthCtrl.selection = TextSelection.collapsed(
                                offset: _lengthCtrl.text.length,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: CuttingColors.primary,
                                ),
                              ),
                              child: Text(
                                fmtMm(v),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: CuttingColors.primaryDark,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                // 입력한 값으로 나오는 합계를 미리 보여 준다(길이 × 수량 = 합계).
                if (_previewText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _previewText!,
                      key: const Key('steel_item_preview'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: CuttingColors.primary,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _buildField(
                  label: "비고 (선택)",
                  hint: "예: A구역 하단 프레임",
                  controller: _noteCtrl,
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('steel_multi_toggle'),
                      onPressed: () => setState(() => _multiOpen = !_multiOpen),
                      style: TextButton.styleFrom(
                        foregroundColor: CuttingColors.primaryDark,
                        padding: EdgeInsets.zero,
                      ),
                      icon: Icon(
                        _multiOpen
                            ? Icons.expand_less_rounded
                            : Icons.playlist_add_rounded,
                        size: 20,
                      ),
                      label: const Text(
                        "여러 길이 한 번에 입력",
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  if (_multiOpen) _buildMultiSection(),
                ],
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

  // 같은 규격에 "500x3, 800x2, 1200"처럼 적어 한 번에 넣는다. 읽은 결과를 바로 아래에 보여 준다.
  Widget _buildMultiSection() {
    final p = parseMultiLengths(_multiCtrl.text);
    final preview = multiPreviewText(p);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CuttingColors.primarySoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "위에서 고른 규격에 아래 길이를 모두 추가합니다. 쉼표나 줄바꿈으로 나누고, 길이x개수로 적습니다.",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: CuttingColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('steel_multi_field'),
            controller: _multiCtrl,
            minLines: 2,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: CuttingColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: "예: 500x3, 800x2, 1200",
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (p.bad.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                "읽을 수 없는 값: ${p.bad.join(', ')}",
                key: const Key('steel_multi_bad'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: CuttingColors.danger,
                ),
              ),
            )
          else if (preview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                preview,
                key: const Key('steel_multi_preview'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: CuttingColors.primary,
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const Key('steel_multi_add'),
              onPressed: p.entries.isNotEmpty && p.bad.isEmpty
                  ? _addMulti
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: CuttingColors.primaryDark,
                side: const BorderSide(
                  color: CuttingColors.primary,
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                p.entries.isEmpty ? "모두 추가" : "${p.entries.length}건 모두 추가",
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool isNumber = false,
    String? suffix,
    Key? fieldKey,
    String? errorText,
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
          key: fieldKey,
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
            errorText: errorText,
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

// 규격 선택창을 열고, "직접 입력"을 고르면 이름을 묻는다. 취소하면 null.
Future<SteelShapeItem?> pickSteelShape(BuildContext context) async {
  final picked = await SteelShapePickerSheet.show(context);
  if (picked == null) return null;
  if (picked.id != kCustomSteelShapeRequestId) return picked;
  if (!context.mounted) return null;
  final label = await promptCustomSteelShapeLabel(context);
  if (label == null || label.trim().isEmpty) return null;
  return SteelShapeItem(
    id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
    category: 'CUSTOM',
    label: label.trim(),
  );
}

Future<String?> promptCustomSteelShapeLabel(BuildContext context) {
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
          hintText: "예: 앵글 50x50x6 (이 형식이면 중량도 계산)",
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
