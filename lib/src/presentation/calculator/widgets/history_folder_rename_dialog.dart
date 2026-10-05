/// 보관함 폴더(작업 이름) 이름 바꾸기 창. 이미 있는 이름을 고르면 그 작업과 합쳐진다.
library;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/common_widgets/save_name_chips.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/app_dialog.dart';

/// 새 작업 이름을 돌려준다(취소하면 null). [others]는 이미 있는 다른 작업 이름.
Future<String?> showFolderRenameDialog(
  BuildContext context, {
  required String current,
  required List<String> others,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(current: current, others: others),
  );
}

class _RenameDialog extends StatefulWidget {
  final String current;
  final List<String> others;
  const _RenameDialog({required this.current, required this.others});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.current,
  );
  bool _done = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '작업 이름 바꾸기',
      okText: '바꾸기',
      okKey: const Key('folder_rename_ok'),
      onCancel: () => Navigator.pop(context),
      onOk: () {
        if (_done) return;
        final v = _name.text.trim();
        if (v.isEmpty) return;
        _done = true;
        Navigator.pop(context, v);
      },
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('folder_rename_field'),
            controller: _name,
            autofocus: true,
            style: appFieldTextStyle,
            decoration: appFieldDecoration('작업 이름', hint: '예) A동 보일러실'),
          ),
          SaveNameChips(names: widget.others, controller: _name),
          const SizedBox(height: 12),
          const Text(
            '이미 있는 작업 이름으로 바꾸면 그 작업과 합쳐집니다.',
            style: TextStyle(color: AppColors.textSub, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
