// 자재 입고·검수(10-15). 자재 일정을 입고 완료로 바꿀 때 들어온 수량·검수 메모·검수 사진을 적는다.
// 이미 입고 완료면 같은 화면에서 고친다. 돌려주는 값: {'receivedQty','note','photos'} (닫으면 null).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tubing_calculator/src/core/utils/background_photos.dart';

import '../../../core/theme/app_icon_set.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/image_picker_helper.dart' show ImagePickerHelper;
import '../models/material_receipt.dart';
import '../models/photo_store.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/photo_detail_modal.dart';

class MaterialReceivePage extends StatefulWidget {
  final Map<String, dynamic> item;
  final String? projectName;
  const MaterialReceivePage({super.key, required this.item, this.projectName});

  @override
  State<MaterialReceivePage> createState() => _MaterialReceivePageState();
}

class _MaterialReceivePageState extends State<MaterialReceivePage> {
  late final TextEditingController _qty;
  late final TextEditingController _note;
  late final List<String> _photos;
  final BackgroundPhotos _jobs = BackgroundPhotos();
  late final String _snap;

  bool get _done => widget.item['isCompleted'] == true;

  String get _unit => materialUnit(widget.item);

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    // 입고 수량은 들어온 값, 없으면 주문 수량을 미리 채운다(대개 다 들어온다).
    final r = materialReceivedQty(it) ?? materialQty(it);
    _qty = TextEditingController(text: r == null ? '' : fmtQty(r));
    _note = TextEditingController(text: (it['receiveNote'] ?? '').toString());
    _photos = materialReceivePhotos(it);
    _snap = _snapshot();
  }

  String _snapshot() => '${_qty.text}|${_note.text}|${_photos.join(',')}';

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    if (_photos.length >= 6) return;
    FocusScope.of(context).unfocus();
    final picked = await ImagePickerHelper.pickRawImages(
      context,
      maxCount: 6 - _photos.length,
      stampSite: true,
    );
    if (picked.isEmpty || !mounted) return;
    _jobs.addAll(
      _photos,
      picked,
      update: (fn) => mounted ? setState(fn) : fn(),
      siteLabel: widget.projectName,
    );
  }

  Future<void> _save() async {
    await _jobs.waitAll();
    if (!mounted) return;
    final t = _qty.text.replaceAll(',', '').trim();
    Navigator.pop(context, <String, dynamic>{
      'receivedQty': t.isEmpty ? null : num.tryParse(t),
      'note': _note.text.trim(),
      'photos': List<String>.from(_photos),
    });
  }

  Future<void> _leave() async {
    if (_snapshot() != _snap &&
        !await confirmDelete(
          context,
          title: "적은 검수 내용을 버리시겠습니까?",
          message: "저장하지 않고 나가면 입고 수량·메모·사진이 사라집니다.",
          confirmLabel: "버리기",
        )) {
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  InputDecoration _deco(String label, {String? hint, String? suffix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final q = materialQty(it);
    final t = _qty.text.replaceAll(',', '').trim();
    final r = num.tryParse(t);
    final short = (q != null && r != null && r < q) ? q - r : null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(AppIcons.back, size: 20),
            onPressed: _leave,
          ),
          title: const Text("입고·검수"),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    (it['title'] ?? it['type'] ?? '자재').toString(),
                    style: AppText.title,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    q == null
                        ? "주문 수량이 없습니다(일정 고치기에서 넣을 수 있습니다)."
                        : "주문 ${fmtQty(q)}$_unit",
                    style: AppText.sub,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('receive_qty'),
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: _deco(
                      "들어온 수량",
                      suffix: _unit.isEmpty ? null : _unit,
                    ),
                  ),
                  if (short != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      "${fmtQty(short)}$_unit 덜 들어왔습니다. 저장하면 개요에 부족으로 남습니다.",
                      key: const Key('receive_short'),
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('receive_note'),
                    controller: _note,
                    maxLines: 3,
                    decoration: _deco(
                      "검수 메모 (선택)",
                      hint: "예: 외관 이상 없음, 성적서 확인, 1EA 찍힘",
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "검수 사진 ${_photos.length}/6",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSub,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 84,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        InkWell(
                          key: const Key('receive_photo_add'),
                          onTap: _addPhotos,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 84,
                            height: 84,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.add_a_photo_rounded,
                              color: AppColors.textSub,
                            ),
                          ),
                        ),
                        for (int i = 0; i < _photos.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Stack(
                              children: [
                                GestureDetector(
                                  onTap: () => PhotoDetailModal.show(
                                    context: context,
                                    title: "검수 사진",
                                    content: _note.text,
                                    imagePaths: _photos,
                                    initialIndex: i,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: PhotoImage(
                                      _photos[i],
                                      width: 84,
                                      height: 84,
                                    ),
                                  ),
                                ),
                                if (_jobs.busy(_photos[i]))
                                  PhotoBusyOverlay(
                                    key: Key('receive_photo_busy_$i'),
                                  ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () async {
                                      if (!await confirmDelete(
                                        context,
                                        title: "이 사진을 지우시겠습니까?",
                                      )) {
                                        return;
                                      }
                                      if (mounted) {
                                        setState(() => _photos.removeAt(i));
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black87,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 12,
                                      ),
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
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                key: const Key('receive_save'),
                onPressed: _save,
                child: Text(_done ? "검수 내용 저장" : "입고 완료로 저장"),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
