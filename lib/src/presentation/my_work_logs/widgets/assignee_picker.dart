// 이슈 담당자 고르기: "나"·사용자 목록(users 문서 이름) 칩 + 직접 적기.
// 서버를 5초 안에 못 읽으면 칩 없이 적는 칸만 나온다(통신 없는 현장).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const Color tossInputBg = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color tossSubText = Color(0xFF5F6B78);

/// 사용자 이름 목록(한 번 읽으면 화면 사이에 재사용).
class AssigneeNames {
  AssigneeNames._();
  static List<String>? _cache;

  static Future<List<String>> load() async {
    final c = _cache;
    if (c != null) return c;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .get()
          .timeout(const Duration(seconds: 5));
      final names = <String>{
        for (final d in snap.docs)
          if ((d.data()['name']?.toString() ?? d.id).trim().isNotEmpty)
            (d.data()['name']?.toString() ?? d.id).trim(),
      }.toList()..sort();
      _cache = names;
      return names;
    } catch (_) {
      return const [];
    }
  }

  /// 테스트에서 바꿔 끼운다.
  @visibleForTesting
  static void setForTest(List<String>? names) => _cache = names;
}

/// 등록 화면에 넣는 칩 + 입력 칸.
class AssigneePicker extends StatefulWidget {
  final String value;
  final String me;
  final ValueChanged<String> onChanged;
  const AssigneePicker({
    super.key,
    required this.value,
    required this.me,
    required this.onChanged,
  });

  @override
  State<AssigneePicker> createState() => _AssigneePickerState();
}

class _AssigneePickerState extends State<AssigneePicker> {
  List<String> _names = const [];
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.value,
  );

  @override
  void initState() {
    super.initState();
    AssigneeNames.load().then((n) {
      if (mounted) setState(() => _names = n);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _set(String v) {
    _ctrl.text = v;
    widget.onChanged(v);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final options = <String>{
      if (widget.me.isNotEmpty) widget.me,
      ..._names,
    }.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip("없음", widget.value.isEmpty, () => _set('')),
            for (final n in options)
              _chip(
                n == widget.me ? "나 ($n)" : n,
                widget.value == n,
                () => _set(n),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _ctrl,
          onChanged: (v) {
            widget.onChanged(v.trim());
            setState(() {});
          },
          decoration: InputDecoration(
            hintText: "목록에 없으면 이름을 적으십시오",
            filled: true,
            fillColor: tossInputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF007580) : tossInputBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? pureWhite : tossSubText,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// 상세 화면에서 담당자를 바꾸는 창. 고르면 이름(없음이면 빈 글), 취소면 null.
Future<String?> pickAssignee(
  BuildContext context, {
  required String current,
  required String me,
}) async {
  String value = current;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: pureWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "담당자",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: 12),
              AssigneePicker(
                value: current,
                me: me,
                onChanged: (v) => value = v,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, value.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007580),
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text(
                    "정하기",
                    style: TextStyle(
                      color: pureWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
