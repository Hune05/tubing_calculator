import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'schedule_logic.dart';

// 🚀 내 일정 검색 창: 제목·종류·프로젝트 이름으로 찾고, 누르면 그 날짜로 이동한다.
// 넓은 창(좌우 여백만 남김)에 결과를 날짜와 함께 보여 준다.
class ScheduleSearchDialog extends StatefulWidget {
  final List<SearchEntry> entries;
  // 테스트에서 "지금"을 바꿔 끼운다.
  final DateTime? nowForTest;
  // 달력에 종류·프로젝트 필터를 걸어 두었으면 true. 검색은 그 안에서만 찾으므로 한 줄로 알려 준다.
  final bool filtered;
  const ScheduleSearchDialog({
    super.key,
    required this.entries,
    this.nowForTest,
    this.filtered = false,
  });

  @override
  State<ScheduleSearchDialog> createState() => _ScheduleSearchDialogState();
}

class _ScheduleSearchDialogState extends State<ScheduleSearchDialog> {
  String _q = '';

  static const _wd = ['월', '화', '수', '목', '금', '토', '일'];

  String _dateLabel(DateTime d) {
    final hm =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final base = '${d.year}년 ${d.month}월 ${d.day}일 (${_wd[d.weekday - 1]})';
    return (d.hour == 0 && d.minute == 0) ? base : '$base $hm';
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.nowForTest ?? DateTime.now();
    final results = searchAgenda(widget.entries, _q, now: now);
    // 키보드가 올라오면 결과 목록을 줄여서 창이 화면 밖으로 넘치지 않게 한다.
    final media = MediaQuery.of(context);
    final listMax = math.max(
      120.0,
      math.min(340.0, (media.size.height - media.viewInsets.bottom) * 0.4),
    );
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "일정 검색",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('schedule_search_field'),
              autofocus: true,
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: "제목·종류·프로젝트 이름으로 찾기",
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            if (widget.filtered) ...[
              const SizedBox(height: 8),
              const Text(
                "종류·프로젝트 필터를 걸어 두어서 그 안에서만 찾습니다.",
                style: TextStyle(fontSize: 13, color: Color(0xFF4E5968)),
              ),
            ],
            const SizedBox(height: 10),
            if (_q.trim().isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  "찾을 말을 입력하십시오.",
                  style: TextStyle(color: AppColors.textSub),
                ),
              )
            else if (results.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  "맞는 일정이 없습니다.",
                  style: TextStyle(color: AppColors.textSub),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: listMax),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final e = results[i];
                    final past = e.date.isBefore(
                      DateTime(now.year, now.month, now.day),
                    );
                    return InkWell(
                      key: ValueKey('schedule_result_$i'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context, e),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: past
                                    ? AppColors.textSub
                                    : AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_dateLabel(e.date)}  ·  ${e.category}'
                              '${e.projectName == null ? '' : '  ·  ${e.projectName}'}'
                              '${past ? '  ·  지난 일정' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "닫기",
                  style: TextStyle(color: AppColors.brand),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
