/// 전선관 마킹 탭의 "보관함에 저장" 창.
library;

import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tubing_calculator/src/core/common_widgets/save_name_chips.dart';
import 'package:tubing_calculator/src/data/conduit_drawings.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/app_dialog.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_history_tab.dart';

const String _lastFolderKey = 'conduit_last_folder';

/// 저장 때 앱이 붙인 도면 이름("벤드 2개 · 617mm")인지. 사람이 지은 이름은 건드리지 않는다.
bool _isAutoTitle(String t) => RegExp(r'^벤드 \d+개 · \d+mm$').hasMatch(t.trim());

/// 창이 돌려주는 값. [overwrite]면 불러온 도면에 덮어쓴다.
class _SaveResult {
  final String folder;
  final String title;
  final String notes;
  final bool overwrite;
  const _SaveResult(this.folder, this.title, this.notes, this.overwrite);
}

/// 작업 이름(폴더)과 도면 이름을 받아 보관함에 넣는다. 넣었으면 true.
/// 보관함에서 불러와 고친 목록이면 "이 도면에 덮어쓰기"를 고를 수 있다.
/// [onOpenArchive]가 있으면 새로 저장한 알림에 "보관함 보기" 단추가 붙는다.
Future<bool> showConduitSaveDialog(
  BuildContext context, {
  required List<Map<String, dynamic>> bends,
  required double totalCut,
  required Map<String, dynamic> settings,
  VoidCallback? onOpenArchive,
}) async {
  String lastFolder = '';
  try {
    final prefs = await SharedPreferences.getInstance();
    lastFolder = prefs.getString(_lastFolderKey) ?? '';
  } catch (_) {}
  var drawings = <ConduitDrawing>[];
  try {
    drawings = await loadConduitDrawings();
  } catch (_) {}
  // 보관함에 이미 있는 작업 이름(새것 먼저)
  final recent = recentDistinctNames([for (final d in drawings) d.folderName]);

  // 불러온 도면이 아직 보관함에 있으면 덮어쓰기 대상, 지워졌으면 원본 기억을 버린다.
  final manager = ConduitDataManager();
  final sourceId = manager.sourceDrawingId;
  ConduitDrawing? target;
  if (sourceId != null) {
    for (final d in drawings) {
      if (d.id == sourceId) target = d;
    }
    if (target == null) manager.clearSource();
  }
  if (!context.mounted) return false;

  final bendCount = bends.where((b) => ((b['angle'] as num?) ?? 0) > 0).length;
  final messenger = ScaffoldMessenger.of(context);
  final result = await showDialog<_SaveResult>(
    context: context,
    builder: (_) => _SaveDialog(
      folder: lastFolder,
      title: '벤드 $bendCount개 · ${totalCut.round()}mm',
      summary: saveSummaryText(bends: bends, totalCut: totalCut),
      recentFolders: recent,
      target: target,
    ),
  );
  if (result == null) return false;

  ConduitDrawing? before;
  try {
    if (result.overwrite && target != null) {
      before = await overwriteConduitDrawing(
        id: target.id,
        folderName: result.folder,
        title: result.title,
        totalCut: totalCut,
        bends: bends,
        notes: result.notes,
        settings: settings,
      );
    }
    // 덮어쓸 도면이 그새 지워졌거나 새 도면으로 저장을 골랐으면 새 줄로 넣는다.
    if (before == null) {
      final saved = await saveConduitDrawing(
        folderName: result.folder,
        title: result.title,
        totalCut: totalCut,
        bends: bends,
        notes: result.notes,
        settings: settings,
      );
      // 다음 저장의 덮어쓰기 대상은 방금 새로 저장한 도면(처음 불러온 원본이 아니다).
      manager.moveSourceTo(saved.id);
    }
  } catch (e) {
    debugPrint('전선관 보관함 저장 실패: $e');
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent.shade400,
        behavior: SnackBarBehavior.floating,
        content: const Text(
          '저장하지 못했습니다. 다시 시도하십시오.',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
    return false;
  }
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastFolderKey, result.folder.trim());
  } catch (_) {}
  conduitDrawingsRevision.value++;

  final overwritten = before;
  if (overwritten != null) {
    // 덮어쓴 것은 바로 되돌릴 수 있게 이전 도면을 들고 있는다.
    final name = result.title.trim().isEmpty ? '이름 없는 도면' : result.title.trim();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.brand,
        behavior: SnackBarBehavior.floating,
        content: Text(
          '도면을 덮어썼습니다: $name',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        action: SnackBarAction(
          label: '되돌리기',
          textColor: Colors.white,
          onPressed: () async {
            await replaceConduitDrawing(overwritten);
            conduitDrawingsRevision.value++;
          },
        ),
      ),
    );
    return true;
  }
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: AppColors.brand,
      behavior: SnackBarBehavior.floating,
      content: const Text(
        '보관함에 저장했습니다.',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      action: onOpenArchive == null
          ? null
          : SnackBarAction(
              label: '보관함 보기',
              textColor: Colors.white,
              onPressed: onOpenArchive,
            ),
    ),
  );
  return true;
}

/// 입력칸을 창이 스스로 들고 있다가 창이 사라질 때 치운다.
/// (창이 닫히는 동안 입력칸이 먼저 치워져 오류가 났다.)
class _SaveDialog extends StatefulWidget {
  final String folder;
  final String title;
  final String summary;
  final List<String> recentFolders;

  /// 불러와 고친 도면(덮어쓰기 대상). 없으면 늘 새 도면으로 저장한다.
  final ConduitDrawing? target;
  const _SaveDialog({
    required this.folder,
    required this.title,
    required this.summary,
    required this.recentFolders,
    this.target,
  });

  @override
  State<_SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<_SaveDialog> {
  // 불러온 도면이 있으면 덮어쓰기를 먼저 고른다("새 도면으로 저장"으로 바꿀 수 있다).
  late bool _overwrite = widget.target != null;

  late final TextEditingController _folder = TextEditingController(
    text: widget.target != null
        ? (widget.target!.folderName == '미분류 도면'
              ? ''
              : widget.target!.folderName)
        : widget.folder,
  );
  // 덮어쓸 때 도면 이름: 사람이 지은 이름은 그대로, 앱이 붙인 이름이면 새 값(길이·굽힘 수)으로 갱신.
  late final String _overwriteTitle =
      widget.target != null && !_isAutoTitle(widget.target!.title)
      ? widget.target!.title
      : widget.title;

  late final TextEditingController _title = TextEditingController(
    text: widget.target != null ? _overwriteTitle : widget.title,
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.target?.notes ?? '',
  );

  // 저장을 두 번 눌러도 창은 한 번만 닫는다(두 번째 pop이 뒤 화면을 닫지 않게).
  bool _done = false;

  @override
  void dispose() {
    _folder.dispose();
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// 덮어쓰기와 새 도면을 바꿀 때 도면 이름이 손대지 않은 값이면 그에 맞는 이름으로 바꿔 준다
  /// (새 도면인데 옛 도면과 같은 이름이 되지 않게).
  void _setMode(bool overwrite) {
    final t = widget.target;
    if (t == null || overwrite == _overwrite) return;
    setState(() {
      if (overwrite && _title.text == widget.title) {
        _title.text = _overwriteTitle;
      }
      if (!overwrite && _title.text == _overwriteTitle) {
        _title.text = widget.title;
      }
      _overwrite = overwrite;
    });
  }

  Widget _modeChip(Key key, String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      key: key,
      label: SizedBox(
        width: double.infinity,
        child: Text(label, textAlign: TextAlign.center),
      ),
      selected: selected,
      selectedColor: AppColors.brand,
      backgroundColor: AppColors.background,
      showCheckmark: false,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textSub,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
      onSelected: (_) => onTap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    return AppDialog(
      title: '보관함에 저장',
      okText: _overwrite && target != null ? '덮어쓰기' : '저장',
      okKey: const Key('conduit_save_ok'),
      onCancel: () => Navigator.pop(context),
      onOk: () {
        if (_done) return;
        _done = true;
        Navigator.pop(
          context,
          _SaveResult(
            _folder.text,
            _title.text,
            _notes.text,
            _overwrite && target != null,
          ),
        );
      },
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SaveSummaryBox(widget.summary),
          if (target != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _modeChip(
                    const Key('save_mode_overwrite'),
                    '이 도면에 덮어쓰기',
                    _overwrite,
                    () => _setMode(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _modeChip(
                    const Key('save_mode_new'),
                    '새 도면으로 저장',
                    !_overwrite,
                    () => _setMode(false),
                  ),
                ),
              ],
            ),
            if (_overwrite)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '덮어쓸 도면: ${target.title} · ${target.date}',
                    key: const Key('save_overwrite_target'),
                    style: const TextStyle(
                      color: AppColors.textSub,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const Key('conduit_save_folder'),
            controller: _folder,
            style: appFieldTextStyle,
            decoration: appFieldDecoration('작업 이름(묶음)', hint: '예) A구역 메인라인'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: SaveNameChips(
              names: widget.recentFolders,
              controller: _folder,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('conduit_save_title'),
            controller: _title,
            style: appFieldTextStyle,
            decoration: appFieldDecoration('도면 이름'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('conduit_save_notes'),
            controller: _notes,
            style: appFieldTextStyle,
            maxLines: 2,
            decoration: appFieldDecoration('메모 (선택)'),
          ),
        ],
      ),
    );
  }
}
