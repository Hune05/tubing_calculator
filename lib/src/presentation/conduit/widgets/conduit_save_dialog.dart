/// 전선관 마킹 탭의 "보관함에 저장" 창.
library;

import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tubing_calculator/src/core/common_widgets/save_name_chips.dart';
import 'package:tubing_calculator/src/data/conduit_drawings.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/app_dialog.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_history_tab.dart';

const String _lastFolderKey = 'conduit_last_folder';

/// 작업 이름(폴더)과 도면 이름을 받아 보관함에 넣는다. 넣었으면 true.
/// [onOpenArchive]가 있으면 저장 알림에 "보관함 보기" 단추가 붙는다.
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
  // 보관함에 이미 있는 작업 이름(새것 먼저)
  var recent = <String>[];
  try {
    recent = recentDistinctNames([
      for (final d in await loadConduitDrawings()) d.folderName,
    ]);
  } catch (_) {}
  if (!context.mounted) return false;

  final bendCount = bends.where((b) => ((b['angle'] as num?) ?? 0) > 0).length;
  final messenger = ScaffoldMessenger.of(context);
  final result = await showDialog<(String, String, String)>(
    context: context,
    builder: (_) => _SaveDialog(
      folder: lastFolder,
      title: '벤드 $bendCount개 · ${totalCut.round()}mm',
      summary: saveSummaryText(bends: bends, totalCut: totalCut),
      recentFolders: recent,
    ),
  );
  if (result == null) return false;
  final (folder, title, notes) = result;

  try {
    await saveConduitDrawing(
      folderName: folder,
      title: title,
      totalCut: totalCut,
      bends: bends,
      notes: notes,
      settings: settings,
    );
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
    await prefs.setString(_lastFolderKey, folder.trim());
  } catch (_) {}
  conduitDrawingsRevision.value++;
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
  const _SaveDialog({
    required this.folder,
    required this.title,
    required this.summary,
    required this.recentFolders,
  });

  @override
  State<_SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<_SaveDialog> {
  late final TextEditingController _folder = TextEditingController(
    text: widget.folder,
  );
  late final TextEditingController _title = TextEditingController(
    text: widget.title,
  );
  final TextEditingController _notes = TextEditingController();

  // 저장을 두 번 눌러도 창은 한 번만 닫는다(두 번째 pop이 뒤 화면을 닫지 않게).
  bool _done = false;

  @override
  void dispose() {
    _folder.dispose();
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '보관함에 저장',
      okText: '저장',
      okKey: const Key('conduit_save_ok'),
      onCancel: () => Navigator.pop(context),
      onOk: () {
        if (_done) return;
        _done = true;
        Navigator.pop(context, (_folder.text, _title.text, _notes.text));
      },
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SaveSummaryBox(widget.summary),
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
