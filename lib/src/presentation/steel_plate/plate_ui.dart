// 철판 가공 화면들의 공통 틀(10-10, 사용자: "각 페이지 구성이 정리된 게 아니고 대충 뿌려 놓은 것").
// 탭마다 같은 자리의 위 그림 칸 + 아래 흰 작업판(제목 줄 · 묶음별 칸, 필요하면 맨 아래 고정 단추).
// 작업판 모양은 벤딩 입력판(conduit_input_tab의 아래 입력판)과 같다: 흰 바탕, 위 모서리 둥글게, 위로 그림자.
// 고르는 것은 붙은 단추 줄(PlateSegments), 숫자는 이름이 위에 붙은 작은 칸(PlateNumField)을 한 줄에 나란히.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/common_widgets/text_fields_traversal.dart';
import '../../core/theme/app_icon_set.dart';
import '../../core/theme/field_view.dart';

/// 위 그림 칸 + 아래 작업판. 가로로 넓은 화면이면 그림 왼쪽·작업판 오른쪽.
class PlateWorkspace extends StatelessWidget {
  const PlateWorkspace({
    super.key,
    required this.canvas,
    required this.panel,
    this.canvasShare = 0.42,
    this.tools = const [],
    this.hint,
    this.overlay = const [],
  });

  final Widget canvas;
  final Widget panel;

  /// 세로 화면에서 그림 칸이 차지하는 몫(키보드가 뜨면 줄인다).
  final double canvasShare;

  /// 그림 오른쪽 위 작은 단추들.
  final List<Widget> tools;

  /// 그림 왼쪽 아래 옅은 한 줄.
  final String? hint;

  /// 그림 위에 더 얹는 것(Positioned).
  final List<Widget> overlay;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= 720 && box.maxWidth > box.maxHeight * 1.15;
      final kb = MediaQuery.viewInsetsOf(context).bottom > 0;
      final area = ColoredBox(
        color: fc.background,
        child: Stack(
          children: [
            Positioned.fill(child: canvas),
            if (hint != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 10,
                child: IgnorePointer(
                  child: Text(
                    hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: fc.textSub),
                  ),
                ),
              ),
            if (tools.isNotEmpty)
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < tools.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      tools[i],
                    ],
                  ],
                ),
              ),
            ...overlay,
          ],
        ),
      );
      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: area),
            SizedBox(
              width: math.min(460, box.maxWidth * 0.46),
              child: _PlateSheet(wide: true, child: panel),
            ),
          ],
        );
      }
      final share = kb ? math.min(canvasShare, 0.26) : canvasShare;
      final h = (box.maxHeight * share).clamp(
        math.min(110.0, box.maxHeight * 0.4),
        box.maxHeight * 0.72,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: h.toDouble(), child: area),
          Expanded(child: _PlateSheet(wide: false, child: panel)),
        ],
      );
    },
  );
}

class _PlateSheet extends StatelessWidget {
  const _PlateSheet({required this.wide, required this.child});
  final bool wide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = wide
        ? const BorderRadius.horizontal(left: Radius.circular(20))
        : const BorderRadius.vertical(top: Radius.circular(20));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: fc.text.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: wide ? const Offset(-5, 0) : const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: r, child: child),
    );
  }
}

/// 작업판 안: 제목 줄(제목 + 지금 상태 한 줄 + 오른쪽 단추) · 묶음들(스크롤) · 맨 아래 고정 줄.
class PlatePanel extends StatelessWidget {
  const PlatePanel({
    super.key,
    required this.title,
    this.status,
    this.statusKey,
    this.statusColor,
    this.below = const [],
    this.actions = const [],
    required this.children,
    this.footer,
    this.controller,
  });

  final String title;

  /// 제목 아래 한 줄(지금 상태·고른 것).
  final String? status;
  final Key? statusKey;
  final Color? statusColor;

  /// 상태 줄 아래 알림(빨강·노랑 글 등). 스크롤되지 않게 제목 줄에 붙인다.
  final List<Widget> below;

  /// 제목 줄 오른쪽(도움말 등).
  final List<Widget> actions;

  /// 묶음([PlateSection])들.
  final List<Widget> children;

  /// 맨 아래 고정 줄(이전·다음).
  final Widget? footer;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 10, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: fc.text,
                    ),
                  ),
                  if (status != null && status!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        status!,
                        key: statusKey,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: statusColor ?? fc.textSub,
                          height: 1.35,
                        ),
                      ),
                    ),
                  for (final b in below)
                    Padding(padding: const EdgeInsets.only(top: 3), child: b),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
      Expanded(
        child: FocusTraversalGroup(
          policy: TextFieldsOnlyTraversalPolicy(),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: children,
          ),
        ),
      ),
      if (footer != null)
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: fc.line)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: footer,
        ),
    ],
  );
}

/// 묶음 하나: 작은 제목 + 칸들. 첫 묶음이 아니면 위에 가는 선.
class PlateSection extends StatelessWidget {
  const PlateSection(
    this.title,
    this.children, {
    super.key,
    this.trailing,
    this.first = false,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final bool first;

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(top: first ? 6 : 14),
    padding: EdgeInsets.only(top: first ? 0 : 14),
    decoration: first
        ? null
        : BoxDecoration(
            border: Border(top: BorderSide(color: fc.line)),
          ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: fc.textSub,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          children[i],
        ],
      ],
    ),
  );
}

/// 붙은 단추 줄의 한 칸.
class PlateOption {
  final String key;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// 이름 아래 작은 글(예: 지름 단추의 볼트 "M12").
  final String? sub;
  const PlateOption(
    this.key,
    this.label,
    this.selected,
    this.onTap, {
    this.sub,
  });
}

/// 고르기 단추 줄. 4개까지는 한 줄에 붙여(같은 폭), 더 많으면 알약 모양으로 줄 바꿈.
class PlateSegments extends StatelessWidget {
  const PlateSegments(this.items, {super.key, this.joined});
  final List<PlateOption> items;

  /// null이면 4개까지 붙임.
  final bool? joined;

  @override
  Widget build(BuildContext context) {
    final join = joined ?? items.length <= 4;
    if (!join) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final it in items)
            PlateSegButton(
              key: Key(it.key),
              label: it.label,
              sub: it.sub,
              selected: it.selected,
              onTap: it.onTap,
              pill: true,
            ),
        ],
      );
    }
    return Container(
      height: items.any((it) => it.sub != null) ? 54 : 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: fc.fill,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          for (final it in items)
            Expanded(
              child: PlateSegButton(
                key: Key(it.key),
                label: it.label,
                sub: it.sub,
                selected: it.selected,
                onTap: it.onTap,
              ),
            ),
        ],
      ),
    );
  }
}

/// 단추 줄 한 칸(시험에서 [selected]를 읽는다).
class PlateSegButton extends StatelessWidget {
  const PlateSegButton({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.pill = false,
    this.compact = false,
    this.sub,
  });

  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback? onTap;
  final bool pill;

  /// 그림 위 작은 줄(글 크기만큼).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? fc.onBrand : (onTap == null ? fc.textFaint : fc.text);
    final Widget text = sub == null
        ? Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: fg,
                  height: 1.15,
                ),
              ),
              Text(
                sub!,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? fc.onBrand.withValues(alpha: 0.85)
                      : fc.textSub,
                  height: 1.15,
                ),
              ),
            ],
          );
    return Material(
      color: selected ? fc.brand : (pill ? fc.fill : Colors.transparent),
      borderRadius: BorderRadius.circular(pill ? 10 : 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(pill ? 10 : 8),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: pill || compact
            ? Padding(
                padding: compact
                    ? const EdgeInsets.symmetric(horizontal: 11, vertical: 6)
                    : EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: sub == null ? 10 : 6,
                      ),
                child: text,
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(fit: BoxFit.scaleDown, child: text),
                ),
              ),
      ),
    );
  }
}

/// 이름이 위에 붙은 작은 숫자 칸(단위는 칸 안 오른쪽). [text]면 글 칸.
/// 숫자 칸은 누르면(칸에 들어가면) 들어 있던 값 전체를 골라 둔다: 새로 치면 바로 바뀐다
/// (10-11 사용자: "수치 변경할 때 왜 기준 수치가 안 날아가고 이어 쓰기 되냐").
class PlateNumField extends StatefulWidget {
  const PlateNumField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.controller,
    this.unit = 'mm',
    this.hint,
    this.focus,
    this.onChanged,
    this.text = false,
    this.autofocus = false,
    this.highlight = false,
    this.readOnly = false,
  });

  /// 지금 쓰는 값이라 테두리를 진하게(두께 단추에 없는 값을 넣었을 때 등).
  final bool highlight;

  /// 고칠 수 없는 칸(계산해서 보여 주는 값).
  final bool readOnly;
  final bool autofocus;
  final String fieldKey;

  /// null이면 이름 줄 없이 칸만(옆 단추 줄과 높이를 맞출 때).
  final String? label;
  final TextEditingController controller;
  final String? unit;
  final String? hint;
  final FocusNode? focus;
  final ValueChanged<String>? onChanged;
  final bool text;

  @override
  State<PlateNumField> createState() => _PlateNumFieldState();
}

class _PlateNumFieldState extends State<PlateNumField> {
  FocusNode? _own;
  FocusNode? _heard;

  FocusNode get _node => widget.focus ?? (_own ??= FocusNode());

  void _listen() {
    final n = _node;
    if (identical(n, _heard)) return;
    _heard?.removeListener(_onFocus);
    _heard = n..addListener(_onFocus);
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant PlateNumField old) {
    super.didUpdateWidget(old);
    _listen();
  }

  @override
  void dispose() {
    _heard?.removeListener(_onFocus);
    _own?.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_node.hasFocus || widget.readOnly || widget.text) return;
    // 누른 자리에 커서를 놓는 일이 끝난 뒤에 전체를 고른다(바로 고르면 누름이 다시 커서로 바꾼다)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_node.hasFocus) return;
      final c = widget.controller;
      c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label, hint = widget.hint, unit = widget.unit;
    final text = widget.text, readOnly = widget.readOnly;
    final highlight = widget.highlight;
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c, width: w),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: fc.textSub,
            ),
          ),
          const SizedBox(height: 4),
        ],
        TextField(
          key: Key(widget.fieldKey),
          controller: widget.controller,
          focusNode: _node,
          autofocus: widget.autofocus,
          readOnly: readOnly,
          canRequestFocus: !readOnly,
          keyboardType: text
              ? TextInputType.text
              : const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          textAlign: text ? TextAlign.start : TextAlign.right,
          style: TextStyle(
            fontSize: text ? 16 : 18,
            fontWeight: text ? FontWeight.w700 : FontWeight.w800,
            color: fc.text,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: readOnly ? fc.background : fc.fill,
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: fc.textFaint,
            ),
            suffixText: unit,
            suffixStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fc.textSub,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: label == null ? 12 : 13,
            ),
            border: b(Colors.transparent, 0),
            enabledBorder: highlight
                ? b(fc.brand, 1.6)
                : (readOnly ? b(fc.line, 1) : b(Colors.transparent, 0)),
            focusedBorder: readOnly ? b(fc.line, 1) : b(fc.brand, 1.6),
          ),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

/// 칸 여러 개를 한 줄에 같은 폭으로. [flex]로 폭 비율을 바꿀 수 있다.
Widget plateRow(List<Widget> children, {List<int>? flex}) => Row(
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) const SizedBox(width: 10),
      Expanded(flex: flex?[i] ?? 1, child: children[i]),
    ],
  ],
);

/// 칸 여러 개를 폭에 맞춰 놓는다(10-11, 사용자 지적 "폭이 혼자 한 줄"): 칸마다 [minCell] 이상이면 한 줄,
/// 아니면 두 줄로 반씩 나눈다(4개 → 2 × 2, 3개 → 한 줄 유지).
class PlateFieldGrid extends StatelessWidget {
  const PlateFieldGrid(this.children, {super.key, this.minCell = 96});
  final List<Widget> children;
  final double minCell;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final n = children.length;
      final one = (box.maxWidth - 10 * (n - 1)) / n >= minCell;
      if (one || n < 4) return plateRow(children);
      final half = (n / 2).ceil();
      final a = children.sublist(0, half), b = children.sublist(half);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          plateRow(a),
          const SizedBox(height: 10),
          plateRow([
            ...b,
            for (var i = b.length; i < a.length; i++) const SizedBox.shrink(),
          ]),
        ],
      );
    },
  );
}

/// 표(결과·절곡선·홀 위치): 머리 줄 + 줄마다 칸. 숫자 칸은 오른쪽 정렬.
class PlateTable extends StatelessWidget {
  const PlateTable({
    super.key,
    required this.headers,
    required this.rows,
    this.flex,
    this.numeric,
    this.rowKeys,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final List<int>? flex;

  /// 줄마다 열쇠(시험에서 줄을 찾는다).
  final List<Key>? rowKeys;

  /// 칸마다 숫자(오른쪽 정렬)인가.
  final List<bool>? numeric;

  @override
  Widget build(BuildContext context) {
    Widget cell(String s, int i, {bool head = false}) => Expanded(
      flex: flex?[i] ?? 1,
      child: Text(
        s,
        textAlign: (numeric?[i] ?? false) ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: head ? 12 : 14,
          fontWeight: head ? FontWeight.w700 : FontWeight.w800,
          color: head ? fc.textSub : fc.text,
          height: 1.3,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    Widget line(List<String> cs, {bool head = false, Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cs.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            cell(cs[i], i, head: head),
          ],
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: fc.fill,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: line(headers, head: true),
          ),
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) Divider(height: 1, color: fc.line),
            line(
              rows[r],
              key: rowKeys != null && r < rowKeys!.length ? rowKeys![r] : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// 계산해서 보여 주는 값 칸(고칠 수 없음). [PlateNumField]를 그대로 써서 옆 숫자 칸과 높이·모양이 같다
/// (InputDecorator로 따로 그리면 입력 칸보다 1점 낮아 줄이 어긋났다, 10-11 실기기).
class PlateValueField extends StatefulWidget {
  const PlateValueField({
    super.key,
    required this.label,
    required this.value,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;

  @override
  State<PlateValueField> createState() => _PlateValueFieldState();
}

class _PlateValueFieldState extends State<PlateValueField> {
  late final _c = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(PlateValueField old) {
    super.didUpdateWidget(old);
    if (_c.text != widget.value) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.key;
    return PlateNumField(
      fieldKey: '${k is ValueKey ? k.value : widget.label}_value',
      label: widget.label,
      controller: _c,
      unit: widget.unit,
      readOnly: true,
    );
  }
}

/// 위 막대 단추(아이콘 + 아래 작은 이름, 10-11 사용자 지적 "아이콘만 있어 뭔지 모름").
class PlateBarAction extends StatelessWidget {
  const PlateBarAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkResponse(
    onTap: onTap,
    radius: 28,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: fc.text),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: fc.textSub,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 맨 아래 고정 줄: 왼쪽 "이전", 오른쪽 "다음: …"(또는 [main]).
class PlateFooter extends StatelessWidget {
  const PlateFooter({
    super.key,
    this.backKey,
    this.backLabel,
    this.onBack,
    this.nextKey,
    this.nextLabel,
    this.onNext,
    this.main,
  });

  final String? backKey, backLabel;
  final VoidCallback? onBack;
  final String? nextKey, nextLabel;
  final VoidCallback? onNext;
  final Widget? main;

  @override
  Widget build(BuildContext context) {
    final right =
        main ??
        (onNext == null
            ? null
            : FilledButton(
                key: nextKey == null ? null : Key(nextKey!),
                style: FilledButton.styleFrom(
                  backgroundColor: fc.brand,
                  foregroundColor: fc.onBrand,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onNext,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        '다음: ${nextLabel ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(AppIcons.forward, size: 18),
                  ],
                ),
              ));
    return Row(
      children: [
        if (onBack != null)
          OutlinedButton(
            key: backKey == null ? null : Key(backKey!),
            style: OutlinedButton.styleFrom(
              foregroundColor: fc.text,
              side: BorderSide(color: fc.line),
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onBack,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(AppIcons.back, size: 18),
                const SizedBox(width: 2),
                Text(
                  backLabel ?? '이전',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        if (onBack != null && right != null) const SizedBox(width: 10),
        if (right != null) Expanded(child: right) else const Spacer(),
      ],
    );
  }
}

/// 그림 위 작은 단추(글 또는 아이콘). [selected]면 진한 바탕.
class PlateCanvasButton extends StatelessWidget {
  const PlateCanvasButton({
    super.key,
    this.icon,
    this.label,
    this.selected = false,
    this.tooltip,
    required this.onTap,
  });

  final IconData? icon;
  final String? label;
  final bool selected;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? fc.onBrand : (onTap == null ? fc.textFaint : fc.text);
    Widget w = Material(
      color: selected ? fc.brand : fc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? fc.brand : fc.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: label == null ? 8 : 11,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Icon(icon, size: 18, color: fg),
              if (icon != null && label != null) const SizedBox(width: 4),
              if (label != null)
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (tooltip != null) w = Tooltip(message: tooltip!, child: w);
    return w;
  }
}

/// 그림 보기 바꾸기(판·전개도·옆모습·3D): 붙은 작은 단추 줄.
class PlateViewSwitch extends StatelessWidget {
  const PlateViewSwitch(this.items, {super.key});
  final List<PlateOption> items;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: fc.surface,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: fc.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final it in items)
          PlateSegButton(
            key: Key(it.key),
            label: it.label,
            selected: it.selected,
            onTap: it.onTap,
            compact: true,
          ),
      ],
    ),
  );
}

/// 작업판 안 단추(테두리). [danger]면 빨간 글.
class PlateActionButton extends StatelessWidget {
  const PlateActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
    if (primary) {
      return FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: fc.brand,
          foregroundColor: fc.onBrand,
          minimumSize: const Size(0, 44),
          shape: shape,
        ),
        onPressed: onTap,
        child: child,
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: danger ? fc.danger : fc.text,
        side: BorderSide(
          color: danger ? fc.danger.withValues(alpha: 0.5) : fc.line,
        ),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: shape,
      ),
      onPressed: onTap,
      child: child,
    );
  }
}

/// 단추 여러 개를 줄 바꿈으로.
Widget plateActions(List<Widget> buttons) =>
    Wrap(spacing: 8, runSpacing: 8, children: buttons);

/// 큰 값 한 줄(결과 탭 무게 등) + 아래 작은 글.
class PlateBigValue extends StatelessWidget {
  const PlateBigValue({
    super.key,
    required this.value,
    this.caption,
    this.warn = false,
  });

  final String value;
  final String? caption;
  final bool warn;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: warn ? fc.danger : fc.brand,
          height: 1.1,
        ),
      ),
      if (caption != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            caption!,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: fc.textSub,
              height: 1.35,
            ),
          ),
        ),
    ],
  );
}

/// 이름 | 값 한 줄(결과 표).
class PlateInfoRow extends StatelessWidget {
  const PlateInfoRow(this.name, this.value, {super.key, this.color});
  final String name;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 84,
        child: Text(
          name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: fc.textSub,
            height: 1.35,
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color ?? fc.text,
            height: 1.35,
          ),
        ),
      ),
    ],
  );
}

/// 줄 글 여러 개(알림·목록). [color]가 없으면 보통 글.
class PlateLines extends StatelessWidget {
  const PlateLines(this.lines, {super.key, this.color, this.bullet = true});
  final List<String> lines;
  final Color? color;
  final bool bullet;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final l in lines)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            bullet ? '· $l' : l,
            style: TextStyle(
              fontSize: 13.5,
              color: color ?? fc.text,
              height: 1.4,
            ),
          ),
        ),
    ],
  );
}

/// 제목 줄 "?" — 이 탭에서 하는 일 설명을 아래 창으로.
Widget plateHelpButton(
  BuildContext context,
  String key,
  String title,
  List<String> lines,
) => IconButton(
  key: Key(key),
  tooltip: '설명',
  icon: Icon(AppIcons.help, color: fc.textSub),
  onPressed: () => showModalBottomSheet<void>(
    context: context,
    backgroundColor: fc.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: fc.text,
              ),
            ),
            const SizedBox(height: 10),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '· $l',
                  style: TextStyle(fontSize: 14, color: fc.text, height: 1.45),
                ),
              ),
          ],
        ),
      ),
    ),
  ),
);

/// 가공 입력 창(아래에서 올라옴)을 띄운다(10-10 입력 창 정리: 홀·코너·변 길이 창이 같은 틀).
Future<T?> showPlateSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: fc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: builder,
    );

/// 가공 입력 창 틀: 손잡이 · 제목 줄(닫기) · 미리보기 그림 · 묶음(스크롤) · 안 되는 이유 · 맨 아래 취소/확인.
class PlateSheetFrame extends StatelessWidget {
  const PlateSheetFrame({
    super.key,
    required this.title,
    this.preview,
    this.previewHeight = 170,
    this.info,
    required this.children,
    required this.okText,
    this.okKey,
    required this.onOk,
    this.error,
    this.extra,
  });

  final String title;
  final Widget? preview;
  final double previewHeight;

  /// 미리보기 아래 한 줄(예: "새 홀 6개 · 판 밖 1개").
  final Widget? info;
  final List<Widget> children;
  final String okText;
  final Key? okKey;

  /// null이면 확인 단추를 끈다([error]에 이유).
  final VoidCallback? onOk;
  final String? error;

  /// 취소 왼쪽에 더 두는 것(예: 잠금 풀기).
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: fc.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 6, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: fc.text,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('ps_close'),
                    tooltip: '닫기',
                    icon: Icon(AppIcons.close, color: fc.textSub),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (preview != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: previewHeight,
                decoration: BoxDecoration(
                  color: fc.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: preview,
              ),
            if (info != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: info,
              ),
            // 입력 칸은 한 번에 다 만든다(화면 밖 칸도 있어야 다음 칸으로 넘어가고 값을 읽는다)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Text(
                  error!,
                  key: const Key('ps_error'),
                  style: TextStyle(
                    fontSize: 13,
                    color: fc.danger,
                    height: 1.35,
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: fc.line)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  if (extra != null) ...[extra!, const SizedBox(width: 8)],
                  OutlinedButton(
                    key: const Key('ps_cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: fc.text,
                      side: BorderSide(color: fc.line),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '취소',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: okKey,
                      style: FilledButton.styleFrom(
                        backgroundColor: fc.brand,
                        foregroundColor: fc.onBrand,
                        disabledBackgroundColor: fc.fill,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: onOk,
                      child: Text(
                        okText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
