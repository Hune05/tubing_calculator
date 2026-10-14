// 프로젝트 변경 기록 보기(10-15): 누가 언제 무엇을 넣고·고치고·지웠는지. 날짜별로 묶고 종류로 거른다.
import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../models/change_log.dart';

class ChangeLogPage extends StatefulWidget {
  final Map<String, dynamic> log;
  const ChangeLogPage({super.key, required this.log});

  @override
  State<ChangeLogPage> createState() => _ChangeLogPageState();
}

class _ChangeLogPageState extends State<ChangeLogPage> {
  String? _kind; // null = 전체

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  IconData _icon(String kind) => switch (kind) {
    'punch_lists' => Icons.error_outline_rounded,
    'schedules' => Icons.event_note_outlined,
    'phases' => Icons.flag_outlined,
    'daily_reports' => Icons.edit_note_rounded,
    'contacts' => Icons.contacts_outlined,
    _ => Icons.folder_outlined,
  };

  Color _color(String text) {
    if (text.contains('지움')) return AppColors.danger;
    if (text.contains('완료') || text.contains('확정')) return AppColors.ok;
    if (text.contains('추가')) return AppColors.brand;
    return AppColors.textSub;
  }

  @override
  Widget build(BuildContext context) {
    final all = changeLogOf(widget.log);
    final kinds = {for (final e in all) (e['kind'] ?? 'project').toString()};
    final list = [
      for (final e in all)
        if (_kind == null || e['kind'] == _kind) e,
    ];
    final children = <Widget>[];
    String? lastDay;
    for (final e in list) {
      final at = DateTime.tryParse((e['at'] ?? '').toString())?.toLocal();
      final day = at == null
          ? '날짜 모름'
          : '${at.year}.${at.month}.${at.day} (${_weekdays[at.weekday - 1]})';
      if (day != lastDay) {
        lastDay = day;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
            child: Text(
              day,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textSub,
                fontSize: 13,
              ),
            ),
          ),
        );
      }
      final text = (e['text'] ?? '').toString();
      final kind = (e['kind'] ?? 'project').toString();
      final who = (e['who'] ?? '').toString();
      children.add(
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon(kind), size: 18, color: _color(text)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                [
                  if (at != null)
                    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                  if (who.isNotEmpty) who,
                ].join('\n'),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, color: AppColors.textSub),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        scrolledUnderElevation: 0,
        title: Text('${widget.log['name'] ?? '프로젝트'} 변경 기록'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (kinds.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final k in [
                    null,
                    ...kChangeKinds.keys.where(kinds.contains),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        key: Key('change_kind_${k ?? 'all'}'),
                        label: Text(
                          k == null ? '전체 ${all.length}' : kChangeKinds[k]!,
                        ),
                        selected: _kind == k,
                        showCheckmark: false,
                        selectedColor: AppColors.brandSoft,
                        backgroundColor: AppColors.surface,
                        side: BorderSide(
                          color: _kind == k ? AppColors.brand : AppColors.line,
                        ),
                        onSelected: (_) => setState(() => _kind = k),
                      ),
                    ),
                ],
              ),
            ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                child: Text(
                  '남은 변경 기록이 없습니다.\n이 기능을 넣은 뒤(10-15)부터 저장할 때마다 쌓입니다.',
                  textAlign: TextAlign.center,
                  style: AppText.sub,
                ),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}
