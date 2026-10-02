// 도면 보관함: 가져온 도면·사진 목록(최근에 연 것부터). 파일·사진·카톡 공유로 가져온다. 통신 없이 폰에 보관.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/common_widgets/swipe_to_delete.dart';
import '../../core/theme/app_icon_set.dart';
import '../../core/theme/app_tokens.dart';
import 'drawing_models.dart';
import 'drawing_store.dart';
import 'drawing_viewer_page.dart';
import 'dxf_reader.dart';

/// 파일을 보관함에 넣고 바로 연다(카톡 공유·파일 고르기 공용). DWG·모르는 형식은 안내만 한다.
Future<void> importAndOpenDrawing(BuildContext context, String path, {String? name}) async {
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final pathName = path.split(RegExp(r'[\\/]')).last;
  var fileName = (name == null || name.trim().isEmpty) ? pathName : name.trim();
  // 보낸 쪽 이름에 확장자가 없으면 받은 파일의 확장자를 붙인다.
  if (kindForName(fileName) == null && !isDwgName(fileName) && (kindForName(pathName) != null || isDwgName(pathName))) {
    fileName = '$fileName.${pathName.split('.').last}';
  }
  if (isDwgName(fileName)) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('DWG 파일'),
        content: const Text(kDwgHelp),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠습니다'))],
      ),
    );
    return;
  }
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: Card(child: Padding(padding: EdgeInsets.all(20), child: Row(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(width: 16), Text('도면을 여는 중입니다')])))),
    ),
  );
  try {
    final doc = await DrawingStore.importFile(path, name: fileName);
    nav.pop();
    await nav.push(MaterialPageRoute<void>(builder: (_) => DrawingViewerPage(doc: doc)));
  } on DxfError catch (e) {
    nav.pop();
    messenger?.showSnackBar(SnackBar(content: Text(e.message), duration: const Duration(seconds: 6)));
  } catch (e) {
    nav.pop();
    messenger?.showSnackBar(SnackBar(content: Text('도면을 열지 못했습니다: $e')));
  }
}

class DrawingLibraryPage extends StatefulWidget {
  const DrawingLibraryPage({super.key});

  @override
  State<DrawingLibraryPage> createState() => _DrawingLibraryPageState();
}

class _DrawingLibraryPageState extends State<DrawingLibraryPage> {
  List<DrawingDoc>? _docs;
  final Map<String, String> _thumbs = {};
  String _q = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await DrawingStore.load();
    for (final d in list) {
      try {
        final t = await DrawingStore.thumbPath(d.id);
        if (await File(t).exists()) _thumbs[d.id] = t;
      } catch (_) {}
    }
    if (mounted) setState(() => _docs = list);
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.pickFiles(type: FileType.any);
    if (res == null || res.files.isEmpty || !mounted) return;
    final f = res.files.first;
    if (f.path == null) return;
    await importAndOpenDrawing(context, f.path!, name: f.name);
    await _reload();
  }

  Future<void> _pickPhoto(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src);
    if (x == null || !mounted) return;
    await importAndOpenDrawing(context, x.path, name: x.name);
    await _reload();
  }

  Future<void> _open(DrawingDoc d) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DrawingViewerPage(doc: d)));
    await _reload();
  }

  /// 끝까지 밀었을 때 묻는다. 폰에 둔 도면 파일과 표시가 같이 지워져 되돌릴 수 없으므로
  /// 되돌리기 대신 도면 이름을 적어 한 번 더 묻는다(10-02).
  Future<bool> _confirmDelete(DrawingDoc d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('도면을 삭제하겠습니까?'),
        content: Text('"${d.displayName}"와 그 위에 한 표시를 이 폰에서 지웁니다. 되돌릴 수 없습니다. 받은 원래 파일(카톡 등)은 그대로 있습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(key: const Key('dl_delete_ok'), onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    return ok == true;
  }

  /// 확인을 받은 뒤: 목록에서 곧바로 빼고(밀린 줄이 남지 않게) 폰에서 지운다.
  Future<void> _delete(DrawingDoc d) async {
    setState(() {
      _docs = [for (final x in _docs ?? const <DrawingDoc>[]) if (x.id != d.id) x];
      _thumbs.remove(d.id);
    });
    try {
      await DrawingStore.delete(d.id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('도면을 지우지 못했습니다.')));
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final docs = _docs;
    final q = _q.trim().toLowerCase();
    final list = docs == null
        ? null
        : [
            for (final d in docs)
              if (q.isEmpty || '${d.displayName} ${d.name} ${d.drawingNo}'.toLowerCase().contains(q)) d,
          ];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('도면 보기')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('dl_add'),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  key: const Key('dl_add_file'),
                  leading: const Icon(LucideIcons.folderOpen),
                  title: const Text('파일에서 (PDF·DXF·사진)'),
                  subtitle: const Text('카톡으로 받은 파일은 카톡에서 "공유 → 필드 헬퍼"로도 엽니다'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFile();
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.image),
                  title: const Text('앨범 사진'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(AppIcons.camera),
                  title: const Text('사진 찍기 (현장·도면)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        ),
        icon: const Icon(AppIcons.add),
        label: const Text('가져오기'),
      ),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                TextField(
                  key: const Key('dl_search'),
                  onChanged: (v) => setState(() => _q = v),
                  decoration: const InputDecoration(prefixIcon: Icon(AppIcons.search, size: 18), hintText: '도면명·도번으로 찾기', isDense: true),
                ),
                const SizedBox(height: 8),
                if (docs!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      '아직 가져온 도면이 없습니다.\n아래 "가져오기"로 PDF·DXF·사진을 넣거나,\n카톡에서 도면을 "공유 → 필드 헬퍼"로 보내십시오.\n\n통신 없이 폰에 보관되고, 원본은 바꾸지 않습니다.',
                      key: Key('dl_empty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.textSub),
                    ),
                  ),
                for (final d in list) _tile(d),
              ],
            ),
    );
  }

  Widget _tile(DrawingDoc d) {
    final thumb = _thumbs[d.id];
    final kind = switch (d.kind) {
      DrawingKind.pdf => 'PDF',
      DrawingKind.image => '사진',
      DrawingKind.dxf => 'DXF',
    };
    // 왼쪽으로 끝까지 밀면 도면 이름을 적은 확인창이 뜬다(휴지통 단추는 뺐다).
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SwipeToDelete(
        itemKey: ValueKey('dl_swipe_${d.id}'),
        bottomMargin: 0,
        confirm: () => _confirmDelete(d),
        onDelete: () => _delete(d),
        child: _card(d, thumb, kind),
      ),
    );
  }

  Widget _card(DrawingDoc d, String? thumb, String kind) {
    return Card(
      key: Key('dl_doc_${d.id}'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(d),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 76,
                  height: 56,
                  color: const Color(0xFFEFF1F3),
                  child: thumb == null ? const Icon(LucideIcons.fileText, color: AppColors.textFaint) : Image.file(File(thumb), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
                    const SizedBox(height: 2),
                    Text(
                      [kind, if (d.pages > 1) '${d.pages}쪽', if (d.drawingNo.isNotEmpty) d.drawingNo, if (d.rev.isNotEmpty) 'REV ${d.rev}'].join(' · '),
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSub),
                    ),
                    Text('연 때 ${markDate(d.openedAt)}', style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                  ],
                ),
              ),
              if (d.openIssues > 0)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Text('문제 ${d.openIssues}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.danger)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
