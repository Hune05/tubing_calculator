import 'package:flutter/material.dart';

import '../models/skid_presets.dart' show kLayoutKindCabinet, kLayoutKindSkid;
import '../pages/layout_board_page.dart'
    show LayoutBoardPage, layoutBoardHasDraft;
import 'korean_text.dart';
import 'layout_board_ui.dart';

// 카톡 등에서 공유로 받은 도면을 어느 배치도에 깔지 묻고 그 배치도를 연다.
// 열리면 배경에 깔리고 바로 축척 맞추기가 뜬다.

/// 고른 곳: 'cabinet'·'skid'(새 배치도), 'draft'(이어서 하던 배치도).
Future<void> openSharedDrawing(BuildContext context, String imagePath) async {
  final bool hasDraft = await layoutBoardHasDraft();
  if (!context.mounted) return;
  final String? pick = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: pureWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    // 작은 폰(세로 568)에서는 창이 화면보다 길어 굴린다.
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "받은 도면을 어느 배치도에 깔겠습니까?",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tossText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              keepWords("배경에 깐 뒤 모서리 두 곳을 찍어 실제 크기에 맞춥니다."),
              style: const TextStyle(fontSize: 14, color: tossSubText),
            ),
            const SizedBox(height: 12),
            _row(
              ctx,
              key: 'shared_to_cabinet',
              icon: Icons.dashboard_outlined,
              label: "새 캐비닛 배치도",
              value: 'cabinet',
            ),
            _row(
              ctx,
              key: 'shared_to_skid',
              icon: Icons.grid_on_rounded,
              label: "새 스키드 배치도",
              value: 'skid',
            ),
            if (hasDraft) ...[
              _row(
                ctx,
                key: 'shared_to_draft',
                icon: Icons.history_rounded,
                label: "이어서 하던 배치도",
                value: 'draft',
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  keepWords("저장 안 하고 나간 배치도가 있습니다. 새 배치도를 고르면 그 내용은 지워집니다."),
                  style: const TextStyle(fontSize: 13, color: warningRed),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  if (pick == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => LayoutBoardPage(
        initialKind: pick == 'skid' ? kLayoutKindSkid : kLayoutKindCabinet,
        sharedDrawingPath: imagePath,
        resumeDraft: pick == 'draft',
      ),
    ),
  );
}

Widget _row(
  BuildContext ctx, {
  required String key,
  required IconData icon,
  required String label,
  required String value,
}) => ListTile(
  key: ValueKey(key),
  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
  leading: Icon(icon, color: tossBlue),
  title: Text(
    label,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: tossText,
    ),
  ),
  trailing: const Icon(Icons.chevron_right_rounded, color: tossSubText),
  onTap: () => Navigator.pop(ctx, value),
);
