// 10-15 통일: 글 칸(단위 이름 등)도 숫자 칸(calcField)처럼 — 칸 이름은 테두리에 걸치기(labelText),
// 값은 네모 칸(앱 테마 테두리)에. 예전: 이름을 칸 위에 따로 적었다.
// "?" 도움말은 화면의 calcHelp를 [help]로 넘긴다(없으면 null) — 칸 안 맨 오른쪽에 둔다.
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
  // 위 8: 테두리에 걸친 이름이 위 칸과 겹치지 않게.
  padding: const EdgeInsets.only(top: 8, bottom: 10),
  child: TextField(
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
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      hintText: hint,
      hintStyle: TextStyle(fontSize: 14, color: fc.textFaint),
      suffixIcon: help,
      suffixIconConstraints: help == null
          ? null
          : const BoxConstraints(minWidth: 36, minHeight: 36),
    ),
    onChanged: onChanged,
  ),
);
