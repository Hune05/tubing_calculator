/// 입력 목록 머리의 되돌리기 / 다시 하기 단추(튜브·전선관 공용).
library;

import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tubing_calculator/src/data/models/bend_list_history.dart';

class UndoRedoButtons extends StatelessWidget {
  final BendListHistory history;

  /// 되돌리거나 다시 한 뒤(고치던 줄이 있으면 그만두게 한다).
  final VoidCallback? onChanged;

  /// 없으면 이 자리 보기의 보조 글 색.
  final Color? color;

  const UndoRedoButtons({
    super.key,
    required this.history,
    this.onChanged,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? FieldPalette.ofContext(context).textSub;
    return ListenableBuilder(
      listenable: history,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('list_undo'),
            tooltip: '되돌리기',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            icon: Icon(
              Icons.undo_rounded,
              color: history.canUndo ? color : color.withValues(alpha: 0.25),
            ),
            onPressed: history.canUndo
                ? () {
                    HapticFeedback.lightImpact();
                    // 지운 줄 알림이 남아 있으면 닫는다. 이미 되살린 줄을 그 알림으로
                    // 한 번 더 넣지 않게 한다.
                    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
                    if (history.undo()) onChanged?.call();
                  }
                : null,
          ),
          IconButton(
            key: const Key('list_redo'),
            tooltip: '다시 하기',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            icon: Icon(
              Icons.redo_rounded,
              color: history.canRedo ? color : color.withValues(alpha: 0.25),
            ),
            onPressed: history.canRedo
                ? () {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
                    if (history.redo()) onChanged?.call();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
