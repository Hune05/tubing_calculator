// 현장 보기 세 가지: 보통 / 햇빛(고대비) / 야간(어두운) (UI 디자인 제안 D-D).
//
// 현장에서 보는 화면(튜브·전선관 입력·마킹·현장 탭, 아래 탭 줄, 수평계, 각도기, 리모컨)만
// 이 색을 따른다. 사무실 화면(일지·일정·재고 …)은 보통 색 그대로다 — 화면에 직접 적힌 색이
// 아직 많아(약 2,700곳) 앱 전체를 한꺼번에 바꾸면 반쯤만 어두워지기 때문이다.
//
// 쓰는 법: 현장 화면 파일은 색 이름(slate900, pureWhite …)을 상수 대신
// `FieldColors.now`를 읽는 getter로 둔다. 보기를 바꾸면 [FieldViewHost]가 앱 전체를
// 다시 그려 새 색이 들어간다.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'app_tokens.dart';

enum FieldViewMode { normal, sunlight, night }

extension FieldViewModeLabel on FieldViewMode {
  String get label => switch (this) {
    FieldViewMode.normal => '보통',
    FieldViewMode.sunlight => '햇빛',
    FieldViewMode.night => '야간',
  };

  String get description => switch (this) {
    FieldViewMode.normal => '밝은 회색 바탕, 기본 글씨',
    FieldViewMode.sunlight => '흰 바탕에 검은 글씨, 보조 글씨도 진하고 크게',
    FieldViewMode.night => '어두운 바탕, 눈부심 줄임',
  };
}

/// 색 한 벌. 이름은 app_tokens.dart의 AppColors와 같다.
/// 테마에도 실어(ThemeExtension) 공용 부품이 `FieldPalette.ofContext`로 읽는다.
@immutable
class FieldPalette extends ThemeExtension<FieldPalette> {
  final Brightness brightness;
  final Color brand;
  final Color onBrand;
  final Color brandSoft;
  final Color background;
  final Color surface;
  final Color fill;
  final Color line;
  final Color text;
  final Color textSub;
  final Color textFaint;
  final Color ok;
  final Color caution;
  final Color danger;

  /// 작은 글씨에 더할 크기(햇빛은 +3).
  final double smallTextBoost;

  const FieldPalette({
    required this.brightness,
    required this.brand,
    required this.onBrand,
    required this.brandSoft,
    required this.background,
    required this.surface,
    required this.fill,
    required this.line,
    required this.text,
    required this.textSub,
    required this.textFaint,
    required this.ok,
    required this.caution,
    required this.danger,
    this.smallTextBoost = 0,
  });

  /// 보통: 앱 토큰 그대로.
  static const FieldPalette normal = FieldPalette(
    brightness: Brightness.light,
    brand: AppColors.brand,
    onBrand: AppColors.onBrand,
    brandSoft: AppColors.brandSoft,
    background: AppColors.background,
    surface: AppColors.surface,
    fill: AppColors.fill,
    line: AppColors.line,
    text: AppColors.text,
    textSub: AppColors.textSub,
    textFaint: AppColors.textFaint,
    ok: AppColors.ok,
    caution: AppColors.caution,
    danger: AppColors.danger,
  );

  /// 햇빛: 흰 바탕, 검은 글, 보조 글 #333, 선 진하게, 청록·상태 색도 한 단계 진하게.
  static const FieldPalette sunlight = FieldPalette(
    brightness: Brightness.light,
    brand: Color(0xFF005A62),
    onBrand: Color(0xFFFFFFFF),
    brandSoft: Color(0xFFD5EAEC),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    fill: Color(0xFFEDEFF2),
    line: Color(0xFF8A949E),
    text: Color(0xFF000000),
    textSub: Color(0xFF333333),
    textFaint: Color(0xFF4D4D4D),
    ok: Color(0xFF0F6B3B),
    caution: Color(0xFF8A5100),
    danger: Color(0xFFB42318),
    smallTextBoost: 3,
  );

  /// 야간: 바탕 #121417, 글 #E6E8EB, 청록을 밝게(#3FB8C4). 청록 위 글은 어둡게.
  static const FieldPalette night = FieldPalette(
    brightness: Brightness.dark,
    brand: Color(0xFF3FB8C4),
    onBrand: Color(0xFF0B1215),
    brandSoft: Color(0xFF17363A),
    background: Color(0xFF121417),
    surface: Color(0xFF1C1F24),
    fill: Color(0xFF262A30),
    line: Color(0xFF3A4048),
    text: Color(0xFFE6E8EB),
    textSub: Color(0xFFA9B1BA),
    textFaint: Color(0xFF7D8690),
    ok: Color(0xFF3CCB7F),
    caution: Color(0xFFF5A524),
    danger: Color(0xFFF97066),
  );

  /// 이 자리 테마의 색 세트(현장 화면 안이면 햇빛·야간, 아니면 보통).
  static FieldPalette ofContext(BuildContext context) =>
      Theme.of(context).extension<FieldPalette>() ?? normal;

  @override
  FieldPalette copyWith() => this;

  @override
  FieldPalette lerp(FieldPalette? other, double t) =>
      other == null || t < 0.5 ? this : other;

  static FieldPalette of(FieldViewMode m) => switch (m) {
    FieldViewMode.normal => normal,
    FieldViewMode.sunlight => sunlight,
    FieldViewMode.night => night,
  };
}

/// 지금 보기. 현장 화면의 색 getter가 읽는다.
abstract final class FieldColors {
  static final ValueNotifier<FieldViewMode> mode = ValueNotifier(
    FieldViewMode.normal,
  );

  static FieldPalette get now => FieldPalette.of(mode.value);
  static bool get isSunlight => mode.value == FieldViewMode.sunlight;
  static bool get isNight => mode.value == FieldViewMode.night;

  /// 폰에 기억하는 이름. 예전 현장 탭의 햇빛 단추(field_high_contrast)는 처음 한 번 옮긴다.
  static const String prefKey = 'field_view_mode';
  static const String legacyHighContrastKey = 'field_high_contrast';

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefKey);
      if (saved != null) {
        mode.value = FieldViewMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => FieldViewMode.normal,
        );
      } else if (prefs.getBool(legacyHighContrastKey) ?? false) {
        mode.value = FieldViewMode.sunlight;
      }
    } catch (_) {}
  }

  static Future<void> set(FieldViewMode m) async {
    mode.value = m;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, m.name);
    } catch (_) {}
  }
}

/// 현장 화면에서 쓰는 짧은 이름: `fc.text`, `fc.surface` …
FieldPalette get fc => FieldColors.now;

/// 보통 보기에서는 예전 색을 그대로 두고, 햇빛·야간에서만 다른 색을 쓸 때.
Color fieldPick(
  Color normal, {
  required Color sunlight,
  required Color night,
}) => switch (FieldColors.mode.value) {
  FieldViewMode.normal => normal,
  FieldViewMode.sunlight => sunlight,
  FieldViewMode.night => night,
};

/// 옅은 상태 바탕(주의·위험·좋음 칩). 보통은 예전 색, 햇빛·야간은 상태 색을 옅게.
Color fieldSoft(Color normal, Color Function(FieldPalette p) role) =>
    FieldColors.mode.value == FieldViewMode.normal
    ? normal
    : role(fc).withValues(alpha: FieldColors.isNight ? 0.18 : 0.12);

/// [fieldSoft]의 테마(자리) 판: 보통이면 예전 색, 아니면 [role]을 옅게.
Color fieldSoftIn(FieldPalette p, Color normal, Color role) =>
    p == FieldPalette.normal
    ? normal
    : role.withValues(alpha: p.brightness == Brightness.dark ? 0.18 : 0.12);

/// 보기가 바뀌면 아래를 모두 다시 그린다(상수로 만든 위젯·그림까지).
/// 보기를 바꾸는 일은 드물어서 한 번 전부 다시 그려도 된다. 입력한 값(State)은 그대로다.
class FieldViewHost extends StatefulWidget {
  final Widget child;
  const FieldViewHost({super.key, required this.child});

  @override
  State<FieldViewHost> createState() => _FieldViewHostState();
}

class _FieldViewHostState extends State<FieldViewHost> {
  @override
  void initState() {
    super.initState();
    FieldColors.mode.addListener(_changed);
  }

  @override
  void dispose() {
    FieldColors.mode.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.renderObject?.markNeedsPaint();
      e.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 현장 화면을 감싸면 기본 위젯(입력칸 글씨·스위치·빙글이·창 …)도 지금 보기 색을 따른다.
class FieldViewTheme extends StatelessWidget {
  final Widget child;
  const FieldViewTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FieldViewMode>(
      valueListenable: FieldColors.mode,
      builder: (context, m, _) =>
          Theme(data: buildAppTheme(FieldPalette.of(m)), child: child),
    );
  }
}

/// 현장 화면 안에 있지만 색을 아직 옮기지 않은 탭(설정·전선관 보관함)을 보통 보기로 둔다.
/// 감싸지 않으면 야간 테마의 밝은 글씨가 흰 카드 위에 나와 안 보인다.
class NormalViewTheme extends StatelessWidget {
  final Widget child;
  const NormalViewTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Theme(data: buildAppTheme(), child: child);
}
