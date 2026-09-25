// ignore_for_file: invalid_use_of_protected_member
part of 'project_schedule_page.dart';

// 🚀 calendar 부분(화면 클래스에서 옮겨 온 메서드들, 동작은 그대로).
extension _ProjectScheduleCalendar on _ProjectSchedulePageState {
  // 🚀 [신규] "_calendarMonth" 기준 달의 일정을 텍스트로 정리해 클립보드에
  // 복사한다(작업 일지 달력의 내보내기와 동일한 패턴) - 카카오톡 등에
  // 붙여넣어 공유할 수 있다.
  void _exportMonth() {
    final int year = _calendarMonth.year;
    final int month = _calendarMonth.month;

    final List<Map<String, dynamic>> inMonth = [];
    final List<Map<String, dynamic>> undated = [];
    for (final s in _schedules) {
      if (s['dateTime'] == null) {
        undated.add(s);
        continue;
      }
      final DateTime dt = _asDateTime(s['dateTime']);
      if (dt.year == year && dt.month == month) inMonth.add(s);
    }
    inMonth.sort(
      (a, b) =>
          _asDateTime(a['dateTime']).compareTo(_asDateTime(b['dateTime'])),
    );

    final Map<String, int> countByType = {};
    int passCount = 0;
    int failCount = 0;
    for (final s in inMonth) {
      final String type = s['type'] ?? '기타';
      countByType[type] = (countByType[type] ?? 0) + 1;
      if (s['inspectionResult'] == 'PASS') passCount++;
      if (s['inspectionResult'] == 'FAIL') failCount++;
    }

    final buffer = StringBuffer();
    buffer.writeln("📋 [${widget.projectName}] $year년 $month월 일정 요약");
    for (final entry in countByType.entries) {
      buffer.writeln("${entry.key}: ${entry.value}건");
    }
    if (passCount > 0 || failCount > 0) {
      buffer.writeln("검사 결과: 합격 $passCount건 / 불합격 $failCount건");
    }
    buffer.writeln();

    buffer.writeln("[상세]");
    for (final s in inMonth) {
      final DateTime dt = _asDateTime(s['dateTime']);
      final String label = s['title'] ?? s['type'] ?? '';
      final String dateStr =
          "${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}";
      String line = "$dateStr ${s['type'] ?? ''} - $label";
      if (s['isCompleted'] == true) {
        if (s['inspectionResult'] != null) {
          line += s['inspectionResult'] == 'FAIL' ? " (불합격)" : " (합격)";
        } else {
          line += " (완료)";
        }
      }
      buffer.writeln(line);
      final comment = s['inspectionComment']?.toString() ?? '';
      if (comment.isNotEmpty) buffer.writeln("   ↳ $comment");
    }

    if (undated.isNotEmpty) {
      buffer.writeln();
      buffer.writeln("입고일 미정 자재 요청: ${undated.length}건");
      for (final s in undated) {
        buffer.writeln("- ${s['title'] ?? s['type'] ?? ''}");
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(keepWords("이번 달 일정 요약을 클립보드에 복사했습니다.")),
        backgroundColor: tossBlue,
      ),
    );
  }

  // 🚀 [신규] 일정 달력 뷰. 작업 일지와 달리 이 화면의 일정은 dateTime에
  // 연도까지 정확히 들어있어서 실제 날짜 기준으로 정확히 그릴 수 있다.
  // 날짜가 아직 없는 "자재 요청"은 달력에 넣을 수 없어 아래 별도
  // 목록으로 보여준다.
  Widget _buildCalendarBody() {
    final int daysInMonth = DateTime(
      _calendarMonth.year,
      _calendarMonth.month + 1,
      0,
    ).day;
    final int leadingBlanks =
        DateTime(_calendarMonth.year, _calendarMonth.month, 1).weekday - 1;

    // 이 달에 해당하는(연/월 일치) 일정만 날짜별로 묶는다.
    final Map<int, List<Map<String, dynamic>>> byDay = {};
    final List<Map<String, dynamic>> undated = [];
    for (final s in _visibleSchedules) {
      if (s['dateTime'] == null) {
        undated.add(s);
        continue;
      }
      final DateTime dt = _asDateTime(s['dateTime']);
      if (dt.year == _calendarMonth.year && dt.month == _calendarMonth.month) {
        byDay.putIfAbsent(dt.day, () => []).add(s);
      }
    }

    Color dotColorFor(Map<String, dynamic> s) {
      if (s['isCompleted'] == true) return Colors.green;
      final DateTime dt = _asDateTime(s['dateTime']);
      return dt.isBefore(DateTime.now()) ? warningRed : tossBlue;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(() {
                  _calendarMonth = DateTime(
                    _calendarMonth.year,
                    _calendarMonth.month - 1,
                  );
                }),
                icon: const Icon(AppIcons.back),
              ),
              Text(
                "${_calendarMonth.year}년 ${_calendarMonth.month}월",
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: tossText,
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _calendarMonth = DateTime(
                    _calendarMonth.year,
                    _calendarMonth.month + 1,
                  );
                }),
                icon: const Icon(AppIcons.forward),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: ["월", "화", "수", "목", "금", "토", "일"]
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        color: tossSubText,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final int day = index - leadingBlanks + 1;
            final items = byDay[day] ?? const [];

            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: items.isEmpty ? null : () => _showDaySchedules(day, items),
              child: Container(
                decoration: BoxDecoration(
                  color: items.isNotEmpty
                      ? tossBlue.withValues(alpha: 0.08)
                      : pureWhite,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "$day",
                      style: TextStyle(
                        fontWeight: items.isNotEmpty
                            ? FontWeight.w800
                            : FontWeight.normal,
                        color: items.isNotEmpty ? tossText : tossSubText,
                        fontSize: 13,
                      ),
                    ),
                    if (items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Wrap(
                          spacing: 2,
                          children: items
                              .take(3)
                              .map(
                                (s) => Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: dotColorFor(s),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        if (undated.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            "날짜 미정",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: tossSubText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...undated.map(
            (s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: pureWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () => _showEditor(existing: s),
                child: Text(
                  s['title'] ?? s['type'] ?? '',
                  style: const TextStyle(
                    color: tossText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showDaySchedules(int day, List<Map<String, dynamic>> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: const BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${_calendarMonth.year}.${_calendarMonth.month.toString().padLeft(2, '0')}.${day.toString().padLeft(2, '0')}",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tossText,
              ),
            ),
            const SizedBox(height: 16),
            ...items.map((item) {
              final bool isCompleted = item['isCompleted'] == true;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _toggleComplete(item);
                  },
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isCompleted ? Colors.green : tossBlue,
                  ),
                ),
                title: Text(
                  item['title'] ?? item['type'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tossText,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(
                  item['type'] ?? '',
                  style: const TextStyle(color: tossSubText, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined, color: tossSubText),
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditor(existing: item);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
