// 부스바 계산기 공용: 입력 전체를 이름 붙여 보관하고 불러와서 고쳐 쓰는 "저장한 규격" 창.
// 저장은 SharedPreferences(이 기기만). 접지바 화면은 같은 모양을 자체 구현해 둔 것이 따로 있다.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    title: const Text('이름 붙여 저장'),
    content: TextField(
      key: const Key('ss_save_name'),
      controller: _c,
      autofocus: true,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      TextButton(
        key: const Key('ss_save_ok'),
        onPressed: () => Navigator.pop(context, _c.text.trim()),
        child: const Text('저장'),
      ),
    ],
  );
}

Future<bool> _confirm(BuildContext context, String msg, String ok) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        TextButton(
          key: const Key('ss_confirm_ok'),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
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
    backgroundColor: surface,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '저장한 규격',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '지금 넣은 값을 이름 붙여 보관해 두고, 나중에 불러와서 필요한 칸만 고쳐 쓰십시오.',
                style: TextStyle(fontSize: 13, color: textSub),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('ss_save_now'),
                  onPressed: () async {
                    final name = await showDialog<String>(
                      context: ctx,
                      builder: (_) => _NameDialog(initial: defaultName),
                    );
                    if (name == null || name.isEmpty) return;
                    if (list.any((e) => e['name'] == name) &&
                        ctx.mounted &&
                        !await _confirm(ctx, '같은 이름이 있습니다. 덮어쓸까요?', '덮어쓰기')) {
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
                  },
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('지금 값 저장'),
                ),
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    '저장한 규격이 없습니다.',
                    key: const Key('ss_saved_empty'),
                    style: TextStyle(color: textSub),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final e in list)
                        ListTile(
                          key: Key('ss_saved_${e['name']}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            e['name'] as String,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: text,
                            ),
                          ),
                          subtitle: Text(
                            summaryOf(e['data'] as Map<String, dynamic>),
                            style: TextStyle(color: textSub),
                          ),
                          onTap: () {
                            onLoad(e['data'] as Map<String, dynamic>);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '"${e['name']}"을 불러왔습니다. 필요한 칸만 고쳐 쓰십시오.',
                                ),
                              ),
                            );
                          },
                          trailing: IconButton(
                            key: Key('ss_saved_del_${e['name']}'),
                            tooltip: '지우기',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (!await _confirm(
                                ctx,
                                '"${e['name']}" 저장을 지울까요?',
                                '지우기',
                              )) {
                                return;
                              }
                              list.removeWhere((x) => x['name'] == e['name']);
                              await _write(storageKey, list);
                              setSheet(() {});
                            },
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
