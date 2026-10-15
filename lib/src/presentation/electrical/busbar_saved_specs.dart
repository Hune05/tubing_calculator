// 부스바 계산기 공용: 입력 전체를 이름 붙여 보관하고 불러와서 고쳐 쓰는 "저장한 규격" 창.
// 저장은 SharedPreferences(이 기기만). 접지바 화면은 같은 모양을 자체 구현해 둔 것이 따로 있다.
// 10-11 철판 가공 입력 창과 같은 틀로 바꿈(손잡이 · 제목 줄 닫기 · 카드 목록 · 맨 아래 "지금 값 저장").
library;

import 'package:tubing_calculator/src/core/common_widgets/snack_once.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/field_view.dart';

Future<List<Map<String, dynamic>>> _read(String key) async {
  try {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null) return [];
    final l = jsonDecode(raw);
    if (l is! List) return [];
    return [
      for (final e in l)
        if (e is Map && e['name'] is String && e['data'] is Map)
          Map<String, dynamic>.from(e),
    ];
  } catch (_) {
    return [];
  }
}

Future<void> _write(String key, List<Map<String, dynamic>> l) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode(l));
  } catch (_) {}
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: fc.surface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    title: Text(
      '이름 붙여 저장',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: fc.text,
      ),
    ),
    content: TextField(
      key: const Key('ss_save_name'),
      controller: _c,
      autofocus: true,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: fc.text,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: fc.fill,
        hintText: '예) 브라켓 A',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: fc.brand, width: 1.6),
        ),
      ),
      onSubmitted: (_) => Navigator.pop(context, _c.text.trim()),
    ),
    actions: [
      TextButton(
        style: TextButton.styleFrom(foregroundColor: fc.textSub),
        onPressed: () => Navigator.pop(context),
        child: const Text('취소', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      FilledButton(
        key: const Key('ss_save_ok'),
        style: FilledButton.styleFrom(
          backgroundColor: fc.brand,
          foregroundColor: fc.onBrand,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        onPressed: () => Navigator.pop(context, _c.text.trim()),
        child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    ],
  );
}

Future<bool> _confirm(BuildContext context, String msg, String ok) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: fc.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      content: Text(
        msg,
        style: TextStyle(fontSize: 15, color: fc.text, height: 1.4),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: fc.textSub),
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            '취소',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          key: const Key('ss_confirm_ok'),
          style: TextButton.styleFrom(foregroundColor: fc.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  return r == true;
}

/// 저장한 때: "10-11 14:05 저장".
String _when(Object? at) {
  final d = at is String ? DateTime.tryParse(at) : null;
  if (d == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)} 저장';
}

/// "저장한 규격" 창. [current]는 지금 입력 전체, [onLoad]는 고른 규격을 화면에 채운다.
Future<void> openSavedSpecs(
  BuildContext context, {
  required String storageKey,
  required Map<String, dynamic> Function() current,
  required String Function(Map<String, dynamic>) summaryOf,
  required String defaultName,
  required void Function(Map<String, dynamic>) onLoad,
  required Color surface,
  required Color text,
  required Color textSub,
}) async {
  var list = await _read(storageKey);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        Future<void> saveNow() async {
          final name = await showDialog<String>(
            context: ctx,
            builder: (_) => _NameDialog(initial: defaultName),
          );
          if (name == null || name.isEmpty) return;
          if (list.any((e) => e['name'] == name) &&
              ctx.mounted &&
              !await _confirm(ctx, '같은 이름이 있습니다. 덮어쓰시겠습니까?', '덮어쓰기')) {
            return;
          }
          final l = await _read(storageKey);
          l.removeWhere((e) => e['name'] == name);
          l.insert(0, {
            'name': name,
            'at': DateTime.now().toIso8601String(),
            'data': current(),
          });
          await _write(storageKey, l);
          list = await _read(storageKey);
          setSheet(() {});
        }

        Widget card(Map<String, dynamic> e) {
          final when = _when(e['at']);
          return Material(
            key: Key('ss_saved_${e['name']}'),
            color: fc.fill,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                onLoad(e['data'] as Map<String, dynamic>);
                Navigator.pop(ctx);
                showSnackOnce(
                  ScaffoldMessenger.of(context),
                  SnackBar(
                    content: Text('"${e['name']}"을 불러왔습니다. 필요한 칸만 고쳐 쓰십시오.'),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e['name'] as String,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            summaryOf(e['data'] as Map<String, dynamic>),
                            style: TextStyle(
                              fontSize: 13,
                              color: textSub,
                              height: 1.3,
                            ),
                          ),
                          if (when.isNotEmpty)
                            Text(
                              when,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: fc.textFaint,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: Key('ss_saved_del_${e['name']}'),
                      tooltip: '지우기',
                      icon: Icon(Icons.delete_outline, color: fc.textSub),
                      onPressed: () async {
                        if (!await _confirm(
                          ctx,
                          '"${e['name']}" 저장을 지우시겠습니까?',
                          '지우기',
                        )) {
                          return;
                        }
                        list.removeWhere((x) => x['name'] == e['name']);
                        await _write(storageKey, list);
                        setSheet(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
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
                padding: const EdgeInsets.fromLTRB(20, 4, 6, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '저장한 규격',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: text,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('ss_close'),
                      tooltip: '닫기',
                      icon: Icon(Icons.close, color: textSub),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  '지금 입력값을 이름 붙여 보관해 두고, 나중에 불러와서 필요한 칸만 고쳐 쓰십시오.',
                  style: TextStyle(fontSize: 13, color: textSub, height: 1.35),
                ),
              ),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Icon(
                        Icons.bookmarks_outlined,
                        size: 34,
                        color: fc.textFaint,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '저장한 규격이 없습니다.',
                        key: const Key('ss_saved_empty'),
                        style: TextStyle(
                          color: textSub,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => card(list[i]),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: fc.line)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: FilledButton.icon(
                  key: const Key('ss_save_now'),
                  style: FilledButton.styleFrom(
                    backgroundColor: fc.brand,
                    foregroundColor: fc.onBrand,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: saveNow,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text(
                    '지금 값 저장',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
