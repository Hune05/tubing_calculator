// 공용 부품 한 벌(UI 디자인 제안 D-C, docs/UI디자인_산업용비교_2026-09-25.md).
//
// 창이 102곳, 알림이 350곳 넘게 화면마다 따로 그려져, 같은 "지우기" 창인데 단추 색·모서리·
// 글 크기가 제각각이었다. 단추·확인 창·알림·빈 화면·불러오는 중·숫자 표시를 여기 한 곳에서
// 토큰(app_tokens.dart)으로 그린다. 예전 도우미(showCuttingConfirmDialog, showCuttingSnack,
// AppDialog, confirmDeleteDialog)는 이 부품을 불러 쓰게 바꿔, 부르는 곳을 고치지 않아도
// 모양이 한꺼번에 맞춰진다. 나머지 창·알림은 화면을 고칠 때마다 옮긴다.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

// ───────────────────────── 단추 ─────────────────────────

/// 단추 네 가지.
/// - [primary]: 화면에서 가장 할 일(청록 채움). 한 화면에 하나만.
/// - [secondary]: 그다음 할 일(청록 테두리).
/// - [danger]: 지우기처럼 되돌리기 어려운 일(빨강 채움).
/// - [quiet]: 취소·닫기(회색 바탕, 회색 글).
enum AppButtonKind { primary, secondary, danger, quiet }

/// 앱 단추. 높이 48 이상(장갑 없이 엄지로 누르는 크기), 모서리 12.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final IconData? icon;

  /// true면 가로를 꽉 채운다.
  final bool expand;

  /// 안쪽 Material 단추(ElevatedButton 등)에 달 key. 시험에서 단추 모양을 읽을 때 쓴다.
  final Key? buttonKey;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.primary,
    this.icon,
    this.expand = false,
    this.buttonKey,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.buttonKey,
  }) : kind = AppButtonKind.secondary;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.buttonKey,
  }) : kind = AppButtonKind.danger;

  const AppButton.quiet({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.buttonKey,
  }) : kind = AppButtonKind.quiet;

  static const double minHeight = 48;

  static const TextStyle _labelStyle = TextStyle(
    fontFamily: kAppFontFamily,
    fontSize: 16,
    fontWeight: AppText.bold,
  );

  static final OutlinedBorder _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.medium),
  );

  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: AppSpace.lg,
    vertical: AppSpace.md,
  );

  /// 단추 색(바탕, 글). 시험에서도 쓴다.
  static (Color background, Color foreground) colorsOf(AppButtonKind kind) =>
      switch (kind) {
        AppButtonKind.primary => (AppColors.brand, AppColors.onBrand),
        AppButtonKind.secondary => (AppColors.surface, AppColors.brand),
        AppButtonKind.danger => (AppColors.danger, AppColors.onBrand),
        AppButtonKind.quiet => (AppColors.fill, AppColors.textSub),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colorsOf(kind);
    final text = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final child = icon == null
        ? text
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: AppSpace.sm),
              Flexible(child: text),
            ],
          );
    const minSize = Size(64, minHeight);

    final Widget button = switch (kind) {
      AppButtonKind.primary || AppButtonKind.danger => ElevatedButton(
        key: buttonKey,
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.textFaint,
          elevation: 0,
          minimumSize: minSize,
          padding: _padding,
          shape: _shape,
          textStyle: _labelStyle,
        ),
        child: child,
      ),
      AppButtonKind.secondary => OutlinedButton(
        key: buttonKey,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          side: BorderSide(
            color: onPressed == null ? AppColors.line : AppColors.brand,
            width: 1.5,
          ),
          minimumSize: minSize,
          padding: _padding,
          shape: _shape,
          textStyle: _labelStyle,
        ),
        child: child,
      ),
      AppButtonKind.quiet => TextButton(
        key: buttonKey,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          minimumSize: minSize,
          padding: _padding,
          shape: _shape,
          textStyle: _labelStyle,
        ),
        child: child,
      ),
    };
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

// ───────────────────────── 창 ─────────────────────────

/// 창 머리의 "옅은 동그라미 + 아이콘".
class AppDialogIcon extends StatelessWidget {
  final Widget icon;
  final Color color;
  const AppDialogIcon({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: color, size: 26),
        child: icon,
      ),
    );
  }
}

/// 앱 창 뼈대 하나: 흰 바탕, 모서리 20, 제목(아이콘 있으면 왼쪽에), 본문, 아래 두 단추
/// (왼쪽 회색 취소 · 오른쪽 청록 확인, 지우기면 빨강). 알림 창(단추 하나)도 같은 모양.
class AppConfirmDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final String okText;

  /// null이면 단추 하나(알림 창).
  final String? cancelText;
  final VoidCallback onOk;
  final VoidCallback? onCancel;
  final bool destructive;
  final Widget? icon;
  final Key? okKey;

  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onOk,
    this.onCancel,
    this.okText = '확인',
    this.cancelText = '취소',
    this.destructive = false,
    this.icon,
    this.okKey,
  });

  /// 창 본문 글(진한 글씨 — 확인할 숫자가 햇빛 아래서도 읽히게).
  static Widget message(String text) => Text(text, style: AppText.body);

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? AppColors.danger : AppColors.brand;
    final titleText = Text(title, style: AppText.title);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      // 폰에서도 글이 좁게 접히지 않도록 창을 넓게 쓴다.
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.xl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      title: icon == null
          ? titleText
          : Row(
              children: [
                AppDialogIcon(icon: icon!, color: accent),
                const SizedBox(width: AppSpace.md),
                Expanded(child: titleText),
              ],
            ),
      content: SingleChildScrollView(child: content),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        0,
        AppSpace.xl,
        AppSpace.xl,
      ),
      actions: [
        Row(
          children: [
            if (cancelText != null) ...[
              Expanded(
                child: AppButton.quiet(
                  label: cancelText!,
                  onPressed: onCancel ?? () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: AppSpace.md),
            ],
            Expanded(
              child: AppButton(
                buttonKey: okKey,
                label: okText,
                kind: destructive
                    ? AppButtonKind.danger
                    : AppButtonKind.primary,
                onPressed: onOk,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 묻는 창. 확인을 눌렀을 때만 true(바깥을 눌러 닫아도 false).
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String okText = '확인',
  String cancelText = '취소',
  bool destructive = false,
  Widget? icon,
  Key? okKey,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppConfirmDialog(
      title: title,
      content: AppConfirmDialog.message(message),
      okText: okText,
      cancelText: cancelText,
      destructive: destructive,
      icon: icon,
      okKey: okKey,
      onCancel: () => Navigator.pop(ctx, false),
      onOk: () => Navigator.pop(ctx, true),
    ),
  );
  return ok == true;
}

/// 알리는 창(단추 하나, "확인"을 눌러야 닫힌다). 놓치면 안 되는 결과에 쓴다.
Future<void> showAppNotice(
  BuildContext context, {
  required String title,
  required String message,
  String okText = '확인',
  Widget? icon,
  Key? dialogKey,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AppConfirmDialog(
      key: dialogKey,
      title: title,
      content: AppConfirmDialog.message(message),
      okText: okText,
      cancelText: null,
      icon: icon,
      onOk: () => Navigator.pop(ctx),
    ),
  );
}

// ───────────────────────── 알림(스낵바) ─────────────────────────

/// 알림 세 가지: 잘 됨(진한 청록), 안 됨(빨강), 되돌리기(진한 회색 + "되돌리기").
enum AppSnackKind { success, error, undo }

/// 알림이 떠 있는 시간. 되돌리기는 누를 틈을 주려고 조금 길게.
const Duration kAppSnackDuration = Duration(seconds: 4);
const Duration kAppUndoSnackDuration = Duration(seconds: 6);

/// 잘 됨 알림 바탕(진한 청록 — 흰 글씨 대비 약 9:1).
const Color kAppSnackSuccess = Color(0xFF004D54);

/// 앱 알림. 떠 있는 모양, 아이콘 + 굵은 흰 글씨.
/// 되돌리기 알림은 [onUndo]를 준다. 단추가 있어도 시간이 지나면 사라진다(persist: false —
/// Flutter는 단추 달린 알림을 기본으로 계속 띄워 화면을 가렸다).
void showAppSnack(
  BuildContext context,
  String message, {
  AppSnackKind kind = AppSnackKind.success,
  VoidCallback? onUndo,
  String undoLabel = '되돌리기',
  Duration? duration,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final hasUndo = onUndo != null;
  final (Color bg, IconData icon) = switch (kind) {
    AppSnackKind.success => (
      kAppSnackSuccess,
      Icons.check_circle_outline_rounded,
    ),
    AppSnackKind.error => (AppColors.danger, Icons.error_outline_rounded),
    AppSnackKind.undo => (AppColors.text, Icons.undo_rounded),
  };
  if (hasUndo) messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      backgroundColor: bg,
      duration:
          duration ?? (hasUndo ? kAppUndoSnackDuration : kAppSnackDuration),
      persist: false,
      content: Row(
        children: [
          Icon(icon, color: AppColors.onBrand, size: 20),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: kAppFontFamily,
                color: AppColors.onBrand,
                fontSize: 15,
                fontWeight: AppText.bold,
              ),
            ),
          ),
        ],
      ),
      action: hasUndo
          ? SnackBarAction(
              label: undoLabel,
              textColor: const Color(0xFF7FD4DC), // 어두운 바탕 위 옅은 청록
              onPressed: onUndo,
            )
          : null,
    ),
  );
}

// ───────────────────────── 빈 화면 ─────────────────────────

/// 목록이 비었을 때: 아이콘 + 한 줄 제목 + (있으면) 설명 + (있으면) 할 일 단추.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  /// 이 높이보다 좁으면 아이콘을 빼고 글만 보인다(폰 입력 탭처럼 아래 입력판이 화면을
  /// 거의 다 차지할 때 글이 입력판 밑에 가려지지 않게).
  static const double compactBelow = 220;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxHeight < compactBelow;
        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(compact ? AppSpace.lg : AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!compact) ...[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.brandSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 36, color: AppColors.brand),
                  ),
                  const SizedBox(height: AppSpace.lg),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppText.subtitle.copyWith(fontWeight: AppText.bold),
                ),
                if (message != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: AppText.sub.copyWith(fontSize: 14),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  SizedBox(height: compact ? AppSpace.md : AppSpace.xl),
                  AppButton(
                    label: actionLabel!,
                    icon: actionIcon,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────── 불러오는 중 ─────────────────────────

/// 목록을 불러오는 동안 가운데 빙글이 대신 "카드 모양 회색 칸"을 보여 준다.
/// 무엇이 나올지 자리가 먼저 보여, 다 불러왔을 때 화면이 덜 튄다.
class LoadingList extends StatefulWidget {
  final int count;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  const LoadingList({
    super.key,
    this.count = 5,
    this.itemHeight = 84,
    this.padding = const EdgeInsets.all(AppSpace.lg),
  });

  @override
  State<LoadingList> createState() => _LoadingListState();
}

class _LoadingListState extends State<LoadingList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(AppRadius.small / 2),
        ),
      ),
    );

    return Semantics(
      label: '불러오는 중',
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.55, end: 1).animate(_pulse),
        child: ListView.builder(
          padding: widget.padding,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.count,
          itemBuilder: (_, i) => Container(
            height: widget.itemHeight,
            margin: const EdgeInsets.only(bottom: AppSpace.md),
            padding: const EdgeInsets.all(AppSpace.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.large),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                bar(i.isEven ? 0.55 : 0.7, 14),
                const SizedBox(height: AppSpace.md),
                bar(i.isEven ? 0.35 : 0.45, 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 숫자 표시 ─────────────────────────

/// 계측값: 큰 숫자 + 작은 단위. 숫자는 자리 맞춤(값이 바뀌어도 글자 폭이 같아 흔들리지 않음).
/// [large]면 40, 아니면 28. 좁으면 줄여서 한 줄에 넣는다.
class NumberDisplay extends StatelessWidget {
  final String value;
  final String? unit;
  final String? label;
  final bool large;
  final Color? color;
  final TextAlign align;

  const NumberDisplay({
    super.key,
    required this.value,
    this.unit,
    this.label,
    this.large = false,
    this.color,
    this.align = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final numStyle = (large ? AppText.numberLarge : AppText.number).copyWith(
      color: color,
    );
    final unitStyle = AppText.subtitle.copyWith(
      color: AppColors.textSub,
      fontSize: large ? 18 : 15,
    );
    final cross = switch (align) {
      TextAlign.center => CrossAxisAlignment.center,
      TextAlign.end || TextAlign.right => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };
    final fitAlign = switch (align) {
      TextAlign.center => Alignment.center,
      TextAlign.end || TextAlign.right => Alignment.centerRight,
      _ => Alignment.centerLeft,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: cross,
      children: [
        if (label != null) Text(label!, style: AppText.caption),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: fitAlign,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value, style: numStyle),
                if (unit != null) ...[
                  const TextSpan(text: ' '),
                  TextSpan(text: unit, style: unitStyle),
                ],
              ],
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
