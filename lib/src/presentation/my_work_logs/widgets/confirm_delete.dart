import 'package:flutter/material.dart';

import 'korean_text.dart';

/// 사진처럼 되돌릴 수 없는 것을 지우기 전에 한 번 묻는다. 지우겠다고 하면 true.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = "지우기",
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(keepWords(title)),
      content: message == null ? null : Text(keepWords(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text("취소"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: const TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return ok == true;
}
