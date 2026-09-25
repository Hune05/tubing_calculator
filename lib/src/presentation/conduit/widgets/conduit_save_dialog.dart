/// 전선관 마킹 탭의 "보관함에 저장" 창.
library;

import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tubing_calculator/src/data/conduit_drawings.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/app_dialog.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_history_tab.dart';

const String _lastFolderKey = 'conduit_last_folder';

/// 작업 이름(폴더)과 도면 이름을 받아 보관함에 넣는다. 넣었으면 true.
Future<bool> showConduitSaveDialog(
  BuildContext context, {
  required List<Map<String, dynamic>> bends,
  required double totalCut,
  required Map<String, dynamic> settings,
}) async {
  String lastFolder = '';
  try {
    final prefs = await SharedPreferences.getInstance();
    lastFolder = prefs.getString(_lastFolderKey) ?? '';
  } catch (_) {}
  if (!context.mounted) return false;

  final bendCount = bends.where((b) => ((b['angle'] as num?) ?? 0) > 0).length;
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (_) => _SaveDialog(
      folder: lastFolder,
      title: '벤드 $bendCount개 · ${totalCut.round()}mm',
    ),
  );
  if (result == null) return false;
  final (folder, title) = result;

  await saveConduitDrawing(
    folderName: folder,
    title: title,
    totalCut: totalCut,
    bends: bends,
    settings: settings,
  );
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastFolderKey, folder.trim());
  } catch (_) {}
  conduitDrawingsRevision.value++;
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.brand,
        behavior: SnackBarBehavior.floating,
        content: Text(
          '보관함에 저장했습니다.',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
  return true;
}

/// 입력칸을 창이 스스로 들고 있다가 창이 사라질 때 치운다.
/// (창이 닫히는 동안 입력칸이 먼저 치워져 오류가 났다.)
class _SaveDialog extends StatefulWidget {
  final String folder;
  final String title;
  const _SaveDialog({required this.folder, required this.title});

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

  @override
  void dispose() {
    _folder.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '보관함에 저장',
      okText: '저장',
      okKey: const Key('conduit_save_ok'),
      onCancel: () => Navigator.pop(context),
      onOk: () => Navigator.pop(context, (_folder.text, _title.text)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('conduit_save_folder'),
            controller: _folder,
            style: appFieldTextStyle,
            decoration: appFieldDecoration('작업 이름(묶음)', hint: '예) A구역 메인라인'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('conduit_save_title'),
            controller: _title,
            style: appFieldTextStyle,
            decoration: appFieldDecoration('도면 이름'),
          ),
        ],
      ),
    );
  }
}
