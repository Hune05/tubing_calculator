/// 보관함 전선관 도면의 작업 이름·도면 이름·메모 고치기 창.
library;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/common_widgets/save_name_chips.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/app_dialog.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';

class ConduitDrawingInfo {
  final String folderName;
  final String title;
  final String notes;
  const ConduitDrawingInfo(this.folderName, this.title, this.notes);
}

/// 고친 값을 돌려준다(취소하면 null). [otherFolders]는 이미 있는 작업 이름(칩으로 보여 준다).
Future<ConduitDrawingInfo?> showConduitDrawingEditDialog(
  BuildContext context, {
  required String folderName,
  required String title,
  required String notes,
  required List<String> otherFolders,
}) {
  return showDialog<ConduitDrawingInfo>(
    context: context,
    builder: (_) => _EditDialog(
      folderName: folderName,
      title: title,
      notes: notes,
      otherFolders: otherFolders,
    ),
  );
}

class _EditDialog extends StatefulWidget {
  final String folderName;
  final String title;
  final String notes;
  final List<String> otherFolders;
  const _EditDialog({
    required this.folderName,
    required this.title,
    required this.notes,
    required this.otherFolders,
  });

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _folder = TextEditingController(
    text: widget.folderName == '미분류 도면' ? '' : widget.folderName,
  );
  late final TextEditingController _title = TextEditingController(
    text: widget.title,
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.notes,
  );
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
      title: '도면 정보 고치기',
      okText: '저장',
      okKey: const Key('conduit_edit_ok'),
      onCancel: () => Navigator.pop(context),
      onOk: () {
        if (_done) return;
        if (_title.text.trim().isEmpty) return;
        _done = true;
        Navigator.pop(
          context,
          ConduitDrawingInfo(_folder.text, _title.text, _notes.text),
        );
      },
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('conduit_edit_folder'),
              controller: _folder,
              style: appFieldTextStyle,
              decoration: appFieldDecoration('작업 이름', hint: '예) A동 보일러실'),
            ),
            SaveNameChips(names: widget.otherFolders, controller: _folder),
            const SizedBox(height: 12),
            TextField(
              key: const Key('conduit_edit_title'),
              controller: _title,
              style: appFieldTextStyle,
              decoration: appFieldDecoration('도면 이름'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('conduit_edit_notes'),
              controller: _notes,
              maxLines: 3,
              minLines: 2,
              style: appFieldTextStyle,
              decoration: appFieldDecoration('메모', hint: '무엇을 했는지·특이사항'),
            ),
            const SizedBox(height: 8),
            const Text(
              '굽힘 값과 장비 설정은 바뀌지 않습니다.',
              style: TextStyle(color: AppColors.textSub, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
