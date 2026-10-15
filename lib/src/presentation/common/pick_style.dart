// 10-15 새 모양: 손으로 만든 고르기 단추(칩·나눔 단추)도 앱 칩(chipTheme)과 같은 색으로.
// 고르면 옅은 청록 바탕 + ✓ + 짙은 청록 글자, 안 고르면 흰 바탕·회색 테두리·짙은 글자.
// (꽉 찬 청록에 흰 글자는 주 단추에만 쓴다.)
// 현장 보기 화면은 fc를, 그 밖의 화면은 기본(FieldPalette.normal = AppColors)을 넘긴다.
import 'package:flutter/material.dart';

import '../../core/theme/field_view.dart';

/// 고른 칸 바탕(옅은 청록).
Color pickFill([FieldPalette p = FieldPalette.normal]) => p.brandSoft;

/// 고른 칸 테두리(옅은 청록과 청록 사이).
Color pickLine([FieldPalette p = FieldPalette.normal]) =>
    Color.lerp(p.brandSoft, p.brand, 0.45)!;

/// 고른 칸 글자·✓(짙은 청록, 야간은 청록 그대로).
Color pickInk([FieldPalette p = FieldPalette.normal]) =>
    p.brightness == Brightness.dark
    ? p.brand
    : Color.lerp(p.brand, Colors.black, 0.25)!;

/// 안 고른 칸 테두리(앱 칸 테두리와 같은 회색).
Color pickIdleLine([FieldPalette p = FieldPalette.normal]) =>
    Color.lerp(p.line, p.textFaint, 0.45)!;

/// 고른 칸 앞에 붙이는 ✓.
Widget pickCheck([FieldPalette p = FieldPalette.normal, double size = 15]) =>
    Icon(Icons.check_rounded, size: size, color: pickInk(p));
