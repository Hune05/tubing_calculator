/// 앱 확인 창 모양(흰 바탕, 굵은 제목, 아래 두 단추: 회색 취소 · 청록 확인).
/// 보관함 불러오기 창과 같은 모양으로 저장 창·튜브 불러오기 창을 맞춘다.
/// (그냥 AlertDialog를 쓰면 기본 테마가 어두운 바탕·보라 단추로 나왔다.)
library;

import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_components.dart';

const Color _teal = AppColors.brand;
const Color _slate900 = AppColors.text;
const Color _slate600 = AppColors.textSub;
const Color _slate100 = AppColors.background;

/// (D-C) 모양은 공용 창(AppConfirmDialog)이 그린다. 부르는 곳을 고치지 않도록 이름과
/// 인자는 그대로 둔다.
class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final String cancelText;
  final String okText;
  final VoidCallback onCancel;
  final VoidCallback onOk;
  final Key? okKey;

  /// 지우기처럼 되돌리기 어려운 일이면 확인 단추를 빨갛게.
  final bool destructive;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onCancel,
    required this.onOk,
    this.cancelText = '취소',
    this.okText = '확인',
    this.okKey,
    this.destructive = false,
  });

  /// 창 안 글(진한 글씨, 줄 간격 넉넉히).
  static Widget message(String text) => AppConfirmDialog.message(text);

  @override
  Widget build(BuildContext context) {
    return AppConfirmDialog(
      title: title,
      content: content,
      okText: okText,
      cancelText: cancelText,
      onOk: onOk,
      onCancel: onCancel,
      destructive: destructive,
      okKey: okKey,
    );
  }
}

/// 입력칸 모양(회색 바탕, 둥근 모서리).
InputDecoration appFieldDecoration(String label, {String? hint}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: _slate100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      labelStyle: const TextStyle(color: _slate600),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      floatingLabelStyle: const TextStyle(
        color: _teal,
        fontWeight: FontWeight.bold,
      ),
    );

/// 입력칸 글씨(진하게). 기본 테마 글씨가 흐리게 나와서 따로 준다.
const TextStyle appFieldTextStyle = TextStyle(
  color: _slate900,
  fontSize: 16,
  fontWeight: FontWeight.w600,
);

/// 지우기 전에 한 번 묻는다(빨간 "삭제" 단추). 삭제를 눌렀을 때만 true.
Future<bool> confirmDeleteDialog(
  BuildContext context, {
  required String message,
  String title = "삭제 확인",
}) {
  return showAppConfirm(
    context,
    title: title,
    message: message,
    okText: "삭제",
    destructive: true,
    okKey: const Key('confirm_delete_ok'),
  );
}
