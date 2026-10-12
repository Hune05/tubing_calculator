// 숫자 칸 안 ▼ 목록(10-12): 사용자 "두께 입력 창이 메인이 되고 퀵 버튼을 드롭다운으로" → 철판 두께에서 시작해
// 부스바·접지바·케이블 트레이·형강 브라켓 금형·철판 홀 지름까지 같은 모양으로("바꿀 만한 곳만" — 고를 것이 2~4개뿐인
// 선택은 단추 그대로).
//  · 칸이 주인공(바로 숫자를 친다), 칸 안 오른쪽 ▼(칸 높이 색 단추, 맨손으로 누르기 좋게)에 자주 쓰는 값.
//  · 목록은 칸 아래 남은 높이에 맞춰 펼친다(넘치면 목록 안에서 스크롤 — 위로 밀려 칸을 덮지 않게).
//  · 지금 값에 체크, 항목 옆 작은 표시(업체 값 등), 맨 위·맨 아래 덧붙임 줄(목록에 넣기·목록 고치기).
library;

import 'package:flutter/material.dart';

import '../../core/theme/field_view.dart';

/// 목록 한 줄: 고르면 돌려줄 값, 보이는 글, (선택) 옆 작은 표시, 키.
class PresetItem {
  final String value;
  final String label;
  final String? badge;
  final Key? key;
  const PresetItem(this.value, this.label, {this.badge, this.key});
}

/// 칸 안 ▼ 단추. [onOpen]에 단추 자리(context)를 넘긴다.
class PresetMenuButton extends StatelessWidget {
  const PresetMenuButton({
    super.key,
    required this.buttonKey,
    required this.onOpen,
    this.tooltip = '자주 쓰는 값',
    this.height = 40,
  });
  final Key buttonKey;
  final void Function(BuildContext btn) onOpen;
  final String tooltip;
  final double height;

  @override
  Widget build(BuildContext context) => Builder(
    builder: (btn) => Tooltip(
      message: tooltip,
      child: InkWell(
        key: buttonKey,
        borderRadius: BorderRadius.circular(8),
        onTap: () => onOpen(btn),
        child: Container(
          width: 48,
          height: height,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: fc.brandSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 34,
            color: fc.brand,
          ),
        ),
      ),
    ),
  );
}

/// ▼ 목록 띄우기: 칸을 위쪽으로 올리고 칸 아래에 펼친다. 고른 값(또는 [top]·[bottom]의 값)을 돌려준다.
Future<String?> showPresetMenu(
  BuildContext btn, {
  required List<PresetItem> items,
  String current = '',
  PresetItem? top,
  PresetItem? bottom,
  double minWidth = 200,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  // 화면 전체 틀(목록 자리 계산용)은 스크롤해도 그대로라 먼저 잡아 둔다
  final overlay = Overlay.of(btn).context.findRenderObject() as RenderBox?;
  await Scrollable.ensureVisible(
    btn,
    alignment: 0.1,
    duration: const Duration(milliseconds: 180),
  );
  if (!btn.mounted) return null;
  final box = btn.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) return null;
  final tl = box.localToGlobal(Offset.zero, ancestor: overlay);
  final topY = tl.dy + box.size.height + 8;
  final below =
      overlay.size.height - topY - MediaQuery.paddingOf(btn).bottom - 8;
  final right = tl.dx + box.size.width;

  PopupMenuItem<String> extra(PresetItem it, IconData icon) => PopupMenuItem(
    key: it.key,
    value: it.value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: fc.brand),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            it.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: fc.brand,
            ),
          ),
        ),
      ],
    ),
  );

  return showMenu<String>(
    context: btn,
    position: RelativeRect.fromLTRB(
      (right - minWidth).clamp(8.0, overlay.size.width),
      topY,
      overlay.size.width - right,
      overlay.size.height - topY,
    ),
    constraints: BoxConstraints(
      minWidth: minWidth,
      maxHeight: below >= 150 ? below : double.infinity,
    ),
    items: [
      if (top != null) ...[
        extra(top, Icons.add_rounded),
        const PopupMenuDivider(),
      ],
      for (final it in items)
        PopupMenuItem<String>(
          key: it.key,
          value: it.value,
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: it.value == current
                    ? Icon(Icons.check_rounded, size: 18, color: fc.brand)
                    : null,
              ),
              Flexible(
                child: Text(
                  it.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: it.value == current
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: fc.text,
                  ),
                ),
              ),
              if (it.badge != null) ...[
                const SizedBox(width: 8),
                Text(
                  it.badge!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: fc.brand,
                  ),
                ),
              ],
            ],
          ),
        ),
      if (bottom != null) ...[
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          key: bottom.key,
          value: bottom.value,
          child: Text(
            bottom.label,
            style: TextStyle(fontSize: 14, color: fc.textSub),
          ),
        ),
      ],
    ],
  );
}

/// 숫자 글을 목록 값과 맞춰 볼 때 쓰는 모양("3.0" → "3", "13.50" → "13.5").
String presetKey(double v) {
  var s = v.toStringAsFixed(3);
  while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
