// 자재 요청 정리: 손으로 쓴 자재 요청 메모를 사진으로 찍으면 목록으로 정리해 주고,
// 확인·고친 뒤 카톡 등으로 글로 보낸다. 저장·발주는 하지 않는다(글을 만드는 도구).
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_icon_set.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/ai_material_note.dart';
import '../inventory/material_catalog.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'material_request_logic.dart';

const String kMaterialRequestSiteKey = 'material_request_site_v1';

/// 정리하던 목록(AI가 읽고 사람이 고친 것)을 폰에 남기는 칸. 10-07: 뒤로 가거나 앱을 닫으면
/// 목록이 사라져, 하루 횟수가 정해진 AI 읽기를 다시 해야 했다. 목록을 다 지우면 같이 지운다.
const String kMaterialRequestDraftKey = 'material_request_draft_v1';

Future<Uint8List?> _pickPhoto(ImageSource source) async {
  final x = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1800,
    maxHeight: 1800,
    imageQuality: 80,
  );
  return x?.readAsBytes();
}

// 카카오톡으로 바로 보내고, 카카오톡이 없으면 일반 공유창으로 대신 보낸다(튜브 컷팅 지시서와 같은 방식).
Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

class MaterialRequestPage extends StatefulWidget {
  final MaterialNoteCall parse;
  final Future<Uint8List?> Function(ImageSource source) pickPhoto;
  final Future<void> Function(String text) share;
  final List<CatalogItem>? catalog;
  final DateTime? today;

  const MaterialRequestPage({
    super.key,
    this.parse = callParseMaterialNote,
    this.pickPhoto = _pickPhoto,
    this.share = _defaultShare,
    this.catalog,
    this.today,
  });

  @override
  State<MaterialRequestPage> createState() => _MaterialRequestPageState();
}

class _MaterialRequestPageState extends State<MaterialRequestPage> {
  final _siteCtrl = TextEditingController();
  late final CatalogMatcher _matcher;
  List<MaterialNoteItem> _items = [];
  List<CatalogItem?> _suggest = [];
  bool _busy = false;
  bool _read = false; // 사진을 한 번이라도 읽었는지
  int? _remaining;

  @override
  void initState() {
    super.initState();
    _matcher = CatalogMatcher(widget.catalog ?? allMaterialCatalog());
    _loadSite();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(kMaterialRequestDraftKey);
      if (raw == null || !mounted || _items.isNotEmpty) return;
      final items = [
        for (final m in jsonDecode(raw) as List)
          ?MaterialNoteItem.fromMap(m),
      ];
      if (items.isEmpty) return;
      setState(() {
        _setItems(items);
        _read = true;
      });
      _toast('정리하던 목록을 이어서 보입니다.');
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (_items.isEmpty) {
        await p.remove(kMaterialRequestDraftKey);
      } else {
        await p.setString(
          kMaterialRequestDraftKey,
          jsonEncode([for (final it in _items) it.toMap()]),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _siteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSite() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(kMaterialRequestSiteKey);
      if (v != null && mounted && _siteCtrl.text.isEmpty) {
        setState(() => _siteCtrl.text = v);
      }
    } catch (_) {}
  }

  Future<void> _saveSite() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(kMaterialRequestSiteKey, _siteCtrl.text.trim());
    } catch (_) {}
  }

  void _setItems(List<MaterialNoteItem> items) {
    _items = items;
    _suggest = [for (final it in items) _matcher.match(it)];
    _saveDraft();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _capture(ImageSource source) async {
    Uint8List? bytes;
    try {
      bytes = await widget.pickPhoto(source);
    } catch (_) {
      _toast('사진을 가져오지 못했습니다');
      return;
    }
    if (bytes == null || !mounted) return;
    setState(() => _busy = true);
    final res = await widget.parse(bytes);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.ok) {
      _toast(res.error ?? '읽지 못했습니다');
      return;
    }
    final items = res.items!;
    if (items.isEmpty) {
      setState(() => _read = true);
      _toast('목록을 찾지 못했습니다. 글씨가 잘 보이게 다시 찍어 주십시오');
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      // 이미 정리한 줄이 있으면 뒤에 이어 붙인다(메모가 여러 장일 때).
      _setItems([..._items, ...items]);
      _read = true;
      _remaining = res.remaining;
    });
  }

  Future<void> _edit(int index) async {
    final isNew = index >= _items.length;
    final result = await showModalBottomSheet<MaterialNoteItem?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditSheet(
        item: isNew ? const MaterialNoteItem(name: '') : _items[index],
        isNew: isNew,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final next = [..._items];
      if (isNew) {
        next.add(result);
      } else {
        next[index] = result;
      }
      _setItems(next);
    });
  }

  void _remove(int index) {
    final removed = _items[index];
    setState(() => _setItems([..._items]..removeAt(index)));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('“${removed.name}” 줄을 지웠습니다'),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () {
              if (!mounted) return;
              setState(() {
                final next = [..._items];
                next.insert(index.clamp(0, next.length), removed);
                _setItems(next);
              });
            },
          ),
        ),
      );
  }

  void _applySuggestion(int index) {
    final c = _suggest[index];
    if (c == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      final next = [..._items];
      next[index] = applyCatalog(next[index], c);
      _setItems(next);
    });
  }

  String get _text => buildMaterialRequestText(
    _items,
    date: widget.today ?? DateTime.now(),
    site: _siteCtrl.text,
  );

  Future<bool> _confirmUnsure() async {
    final n = _items.where((e) => e.unsure).length;
    if (n == 0) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('확인하지 않은 줄이 있습니다'),
        content: Text(
          '주황색 “확인” 표시가 남은 줄이 $n개 있습니다. 글씨를 잘못 읽었거나 수량이 없는 줄입니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('다시 확인'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('그대로 보내기'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _send() async {
    if (_items.isEmpty) return;
    if (!await _confirmUnsure() || !mounted) return;
    await _saveSite();
    await widget.share(_text);
  }

  Future<void> _copy() async {
    if (_items.isEmpty) return;
    if (!await _confirmUnsure() || !mounted) return;
    await Clipboard.setData(ClipboardData(text: _text));
    _toast('복사했습니다');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('자재 요청 정리')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  _photoButtons(),
                  if (_busy) ...[
                    const SizedBox(height: 20),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 8),
                    const Center(child: Text('메모를 읽는 중입니다…')),
                  ],
                  if (!_busy && _items.isEmpty && !_read) _intro(),
                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _siteField(),
                    const SizedBox(height: 12),
                    for (var i = 0; i < _items.length; i++) _row(i),
                    TextButton.icon(
                      onPressed: () => _edit(_items.length),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('줄 추가'),
                    ),
                    const SizedBox(height: 12),
                    _preview(),
                    if (_remaining != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '오늘 $_remaining번 더 읽을 수 있습니다.',
                          style: AppText.caption,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (_items.isNotEmpty) _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _photoButtons() => Row(
    children: [
      Expanded(
        child: FilledButton.icon(
          key: const Key('mr_camera'),
          onPressed: _busy ? null : () => _capture(ImageSource.camera),
          icon: const Icon(Icons.photo_camera_rounded),
          label: Text(_items.isEmpty ? '사진 찍기' : '한 장 더 찍기'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton.icon(
          key: const Key('mr_gallery'),
          onPressed: _busy ? null : () => _capture(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_rounded),
          label: const Text('사진 고르기'),
        ),
      ),
    ],
  );

  Widget _intro() => const Padding(
    padding: EdgeInsets.only(top: 24),
    child: Text(
      '종이에 손으로 쓴 자재 요청 목록을 찍으면 이름·규격·수량으로 정리해 줍니다. '
      '틀린 곳은 고친 뒤 카톡 등으로 글로 보내십시오.\n\n'
      '글씨가 잘 보이게 종이를 펴서 밝은 곳에서 찍으면 더 정확합니다.',
      style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.textSub),
    ),
  );

  Widget _siteField() => TextField(
    key: const Key('mr_site'),
    controller: _siteCtrl,
    onChanged: (_) => setState(() {}),
    decoration: const InputDecoration(
      labelText: '현장 이름 (선택)',
      hintText: '예: 루마',
      filled: true,
      fillColor: AppColors.surface,
    ),
  );

  Widget _row(int i) {
    final it = _items[i];
    final sug = _suggest[i];
    final sub = it.qty != null ? '${formatQty(it.qty!)}${it.unit}' : '수량 없음';
    return Dismissible(
      key: ObjectKey(it),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.danger,
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _remove(i),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: AppColors.surface,
        elevation: 0,
        child: InkWell(
          key: Key('mr_row_$i'),
          onTap: () => _edit(i),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text('${i + 1}', style: AppText.sub),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [it.name, if (it.spec.isNotEmpty) it.spec].join(' '),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            sub,
                            style: TextStyle(
                              fontSize: 14,
                              color: it.qty == null
                                  ? AppColors.caution
                                  : AppColors.textSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (it.unsure)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.caution.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '확인',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF9A5B00),
                          ),
                        ),
                      ),
                    const Icon(
                      AppIcons.forward,
                      color: AppColors.textFaint,
                    ),
                  ],
                ),
                if (sug != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 26, top: 6),
                    child: ActionChip(
                      key: Key('mr_suggest_$i'),
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '자재 목록의 “${sug.name}”(으)로 맞추기',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _applySuggestion(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _preview() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.brandSoft,
      borderRadius: BorderRadius.circular(AppRadius.medium),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('보낼 글', style: AppText.caption),
        const SizedBox(height: 6),
        SelectableText(
          _text,
          key: const Key('mr_preview'),
          style: const TextStyle(fontSize: 14, height: 1.55),
        ),
      ],
    ),
  );

  Widget _bottomBar() => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        OutlinedButton(
          key: const Key('mr_copy'),
          onPressed: _copy,
          child: const Text('복사'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            key: const Key('mr_send'),
            onPressed: _send,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('카톡으로 보내기'),
          ),
        ),
      ],
    ),
  );
}

class _EditSheet extends StatefulWidget {
  final MaterialNoteItem item;
  final bool isNew;
  const _EditSheet({required this.item, required this.isNew});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _spec = TextEditingController(text: widget.item.spec);
  late final _qty = TextEditingController(
    text: widget.item.qty == null ? '' : formatQty(widget.item.qty!),
  );
  late final _unit = TextEditingController(text: widget.item.unit);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _spec.dispose();
    _qty.dispose();
    _unit.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '이름을 적어 주십시오');
      return;
    }
    final qtyText = _qty.text.trim();
    double? qty;
    if (qtyText.isNotEmpty) {
      qty = double.tryParse(qtyText);
      if (qty == null || qty <= 0) {
        setState(() => _error = '수량은 0보다 큰 숫자로 적어 주십시오');
        return;
      }
    }
    // 사용자가 직접 본 줄이므로 확인 표시를 뗀다. 수량이 비면 여전히 확인 대상.
    Navigator.pop(
      context,
      MaterialNoteItem(
        name: name,
        spec: _spec.text.trim(),
        qty: qty,
        unit: _unit.text.trim(),
        unsure: qty == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isNew ? '줄 추가' : '줄 고치기', style: AppText.title),
            const SizedBox(height: 12),
            TextField(
              key: const Key('mr_edit_name'),
              controller: _name,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('mr_edit_spec'),
              controller: _spec,
              decoration: const InputDecoration(labelText: '규격 (선택)'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('mr_edit_qty'),
                    controller: _qty,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: '수량'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('mr_edit_unit'),
                    controller: _unit,
                    decoration: const InputDecoration(
                      labelText: '단위',
                      hintText: 'm, 개, 본',
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('mr_edit_save'),
                onPressed: _save,
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
