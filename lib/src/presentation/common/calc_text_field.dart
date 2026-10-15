// 10-15 새 모양: 글 칸(단위 이름 등)도 숫자 칸(calcField)처럼 — 이름은 칸 위에 작게,
// 값은 네모 칸(앱 칸 테두리)에. 예전: 상자 안에 이름 왼쪽·테두리 없는 칸 오른쪽.
// "?" 도움말은 화면의 calcHelp를 [help]로 넘긴다(없으면 null).
import 'package:flutter/material.dart';

import '../../core/theme/field_view.dart';

Widget calcTextField({
  required Key key,
  required String label,
  required TextEditingController controller,
  Widget? help,
  String? hint,
  ValueChanged<String>? onChanged,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: fc.textSub,
              ),
            ),
          ),
          ?help,
        ],
      ),
      if (help == null) const SizedBox(height: 4),
      TextField(
        key: key,
        controller: controller,
        textInputAction: TextInputAction.next,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: fc.text,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: fc.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          hintText: hint,
          hintStyle: TextStyle(fontSize: 14, color: fc.textFaint),
        ),
        onChanged: onChanged,
      ),
    ],
  ),
);
