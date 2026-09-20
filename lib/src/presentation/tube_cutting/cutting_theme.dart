import 'package:flutter/material.dart';

// 🚀 [UI 고도화] 컷팅 계산기 관련 화면(계산기 본문·모바일/태블릿 작업
// 목록·기록·다이얼로그)이 저마다 tossBlue/makitaTeal/slate900/textPrimary
// 같은 이름으로 같은 색을 따로 선언해 쓰고 있었고, 다이얼로그마다 헤더
// 스타일도 제각각이었다. 색과 다이얼로그 뼈대를 한 곳에 모아서 어느
// 화면에서 봐도 "같은 기능은 같은 색/같은 생김새"로 보이게 통일한다.
class CuttingColors {
  CuttingColors._();

  static const Color primary = Color(0xFF007580); // 마키타 틸 (주요 액션)
  static const Color primaryDark = Color(0xFF004D54);
  static const Color primarySoft = Color(0xFFE1EEEF); // 틸 배경(칩/배지용)
  static const Color background = Color(0xFFF0F3F5);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE5E8EB);

  static const Color textPrimary = Color(0xFF191F28);
  static const Color textSecondary = Color(0xFF8B95A1);

  static const Color danger = Color(0xFFE0432B); // 삭제/간섭/오류
  static const Color dangerSoft = Color(0xFFFDECEA);
  static const Color warning = Color(0xFFC77700); // 대기/주의
  static const Color warningSoft = Color(0xFFFFF3DF);
  static const Color success = Color(0xFF1D8A4E); // 완료/성공
  static const Color successSoft = Color(0xFFE4F5EA);
}

/// 다이얼로그 상단에 반복해서 쓰는 "동그란 배경 + 아이콘" 헤더.
Widget cuttingDialogIcon(IconData icon, {Color? color}) {
  final c = color ?? CuttingColors.primary;
  return Container(
    width: 52,
    height: 52,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Icon(icon, color: c, size: 26),
  );
}

/// 컷팅 계산기 전 화면이 공통으로 쓰는 확인/취소 다이얼로그. 위험한
/// 동작(삭제 등)은 [danger]를 true로 줘서 아이콘·확인 버튼을 빨간색으로,
/// 그 외에는 브랜드 틸 색으로 통일해서 "이 버튼을 누르면 위험한가
/// 아닌가"를 색만 보고 바로 알 수 있게 한다.
Future<bool> showCuttingConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = "확인",
  String cancelLabel = "취소",
  bool danger = false,
  IconData icon = Icons.help_outline_rounded,
}) async {
  final Color accent = danger ? CuttingColors.danger : CuttingColors.primary;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: CuttingColors.surface,
      // 폰에서도 글이 좁게 접히지 않도록 팝업을 넓게 쓴다.
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          cuttingDialogIcon(icon, color: accent),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: CuttingColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Text(
          message,
          style: const TextStyle(
            color: CuttingColors.textSecondary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            cancelLabel,
            style: const TextStyle(
              color: CuttingColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
  return result == true;
}

/// 성공/실패 스낵바도 화면마다 배경색·아이콘 유무가 달랐다. 아이콘 +
/// 색상 배경으로 통일해서 "잘 됐는지 실패했는지"를 글자를 읽기 전에
/// 색으로 먼저 알 수 있게 한다.
void showCuttingSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isError
          ? CuttingColors.danger
          : CuttingColors.primaryDark,
      content: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// [2번 강화] 구간 삭제/복제처럼 되돌리고 싶을 수 있는 동작 뒤에 띄우는
/// "실행 취소" 스낵바. 예전엔 삭제/복제가 확인 없이 바로 실행돼서, 실수로
/// 누르면 되돌릴 방법이 전혀 없었다.
void showCuttingUndoSnack(
  BuildContext context,
  String message, {
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 4),
}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: CuttingColors.primaryDark,
      duration: duration,
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      action: SnackBarAction(
        label: "실행 취소",
        textColor: CuttingColors.warningSoft,
        onPressed: onUndo,
      ),
    ),
  );
}

/// 톱날 손실(커프) 입력 다이얼로그. 원래 튜브 컷팅 화면 안에만 있었는데,
/// 형강 컷팅(찬넬/앵글)도 같은 톱으로 자르는 같은 물리적 현상이라 그대로
/// 재사용한다. 저장(SharedPreferences 키 등)은 부른 쪽 책임으로 남겨서,
/// 이 함수는 순수하게 "숫자 하나 입력받기"만 담당한다.
Future<double?> showBladeKerfDialog(
  BuildContext context,
  double currentKerf,
) async {
  final ctrl = TextEditingController(
    text: currentKerf == 0.0 ? '' : currentKerf.toString(),
  );
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: CuttingColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          cuttingDialogIcon(Icons.content_cut_rounded),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              "톱날 손실(커프) 설정",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: CuttingColors.textPrimary,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "원자재를 여러 구간으로 자를 때 톱날 두께만큼 소재가 갈려 없어집니다. "
            "절단 1회당 손실량을 넣어두면 총 소모량 계산에 자동으로 더해집니다.\n"
            "(구간별 설치 길이 자체엔 영향 없습니다)",
            style: TextStyle(fontSize: 13, color: CuttingColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: CuttingColors.textPrimary,
            ),
            decoration: InputDecoration(
              suffixText: "mm / 회",
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("취소", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: CuttingColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Navigator.pop(ctx, double.tryParse(ctrl.text) ?? 0.0);
          },
          child: const Text(
            "저장",
            style: TextStyle(
              color: CuttingColors.surface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

/// 프로젝트 목록 카드에서 "아직 재고 차감 안 한 사용량이 있음"을 보여주는
/// 작은 배지. 예전엔 재고 차감 대상이 있는지 목록에서 전혀 알 수 없었다.
class PendingDeductionBadge extends StatelessWidget {
  final int materialCount;

  const PendingDeductionBadge({super.key, required this.materialCount});

  @override
  Widget build(BuildContext context) {
    if (materialCount <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CuttingColors.warningSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: CuttingColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 12,
            color: CuttingColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            "출고 대기 $materialCount건",
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: CuttingColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

/// 컷팅 화면을 감싸서 기본 위젯(팝업 메뉴·다이얼로그·날짜 선택 …)까지 밝은 색으로 맞춘다.
/// 앱 전체 테마는 어두운 테마(main.dart)라서, 감싸지 않으면 ⋮ 메뉴와 기본 창만 검게 나온다.
/// 앱 전체 테마는 건드리지 않고 이 화면들만 바꾼다("내 작업 일지"의 WorkTheme과 같은 방식).
class CuttingTheme extends StatelessWidget {
  final Widget child;
  const CuttingTheme({super.key, required this.child});

  static ThemeData of(BuildContext context) {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: CuttingColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: CuttingColors.primary,
        surface: CuttingColors.surface,
        error: CuttingColors.danger,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: CuttingColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: CuttingColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(
          color: CuttingColors.textPrimary,
          fontSize: 14,
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: CuttingColors.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(
          color: CuttingColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: CuttingColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: CuttingColors.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(data: of(context), child: child);
}
