/// 앱 확인 창 모양(흰 바탕, 굵은 제목, 아래 두 단추: 회색 취소 · 청록 확인).
/// 보관함 불러오기 창과 같은 모양으로 저장 창·튜브 불러오기 창을 맞춘다.
/// (그냥 AlertDialog를 쓰면 기본 테마가 어두운 바탕·보라 단추로 나왔다.)
library;

import 'package:flutter/material.dart';

const Color _teal = Color(0xFF007580);
const Color _slate900 = Color(0xFF0F172A);
const Color _slate600 = Color(0xFF475569);
const Color _slate100 = Color(0xFFF1F5F9);
const Color _red = Color(0xFFDC2626);

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

  /// 창 안 글(회색, 줄 간격 넉넉히).
  static Widget message(String text) => Text(
    text,
    style: const TextStyle(color: _slate600, fontSize: 15, height: 1.5),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: _slate900,
        ),
      ),
      content: content,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  backgroundColor: _slate100,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  cancelText,
                  style: const TextStyle(
                    color: _slate600,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                key: okKey,
                onPressed: onOk,
                style: ElevatedButton.styleFrom(
                  backgroundColor: destructive ? _red : _teal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  okText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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
