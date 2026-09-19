// ignore_for_file: invalid_use_of_protected_member
part of 'project_schedule_page.dart';

// 🚀 editor 부분(화면 클래스에서 옮겨 온 메서드들, 동작은 그대로).
extension _ProjectScheduleEditor on _ProjectSchedulePageState {
  Future<void> _showEditor({Map<String, dynamic>? existing}) async {
    String type = existing?['type'] ?? kScheduleTypes.first;
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final noteCtrl = TextEditingController(text: existing?['note'] ?? '');
    // 🚀 [추가] "자재 요청"은 등록 시점에 아직 입고일을 모를 수 있다 -
    // 발주만 넣어두고 나중에 거래처가 입고일을 알려주면 그때 채우는
    // 흐름이라, 새로 만들 때는 날짜를 비워둘 수 있게 한다(다른 종류는
    // 날짜가 곧 그 일정의 의미라 계속 필수로 둔다).
    DateTime? dateTime = existing != null
        ? (existing['dateTime'] != null
              ? _asDateTime(existing['dateTime'])
              : null)
        : (type == "자재 요청"
              ? null
              : DateTime.now().add(const Duration(days: 1)));
    // 🚀 [추가] 며칠 전부터 매일 미리 알림을 받을지 - 기본은 0(당일
    // 60~75분 전 1회 알림, 기존과 동일). 검사일정처럼 미리 준비가
    // 필요한 일정은 3일/7일 전부터로 늘려서 쓸 수 있다.
    int reminderLeadDays = existing?['reminderLeadDays'] ?? 0;
    // 🚀 [프로젝트 단계] 이 일정이 속한 단계. 새 일정이면 지금 보고 있는
    // 단계(있으면)를 기본으로 한다.
    String? phaseId = existing != null
        ? existing['phaseId']?.toString()
        : widget.initialPhaseId;
    // 🚀 [기간 일정] 며칠~몇 주에 걸친 작업(설치·시운전 등)은 종료일까지
    // 넣으면 내 일정 관리 달력에 이어진 막대로 보인다. null이면 하루짜리.
    DateTime? endDate = existing?['endDate'] != null
        ? _asDateTime(existing!['endDate'])
        : null;
    // 🚀 검사일정/납기일이 바뀔 때마다 "언제에서 언제로, 왜" 바뀌었는지
    // 쌓아두는 이력. 기존 이력은 그대로 유지하고 새 변경만 추가된다.
    final List<Map<String, dynamic>> changeHistory =
        existing?['changeHistory'] != null
        ? List<Map<String, dynamic>>.from(
            (existing!['changeHistory'] as List).map(
              (e) => Map<String, dynamic>.from(e),
            ),
          )
        : [];

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                decoration: const BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                // 내용은 스크롤되고, 추가/저장 버튼은 아래에 고정해 항상 보이게 한다.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              existing == null ? "일정 추가" : "일정 수정",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: tossText,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "종류",
                              style: TextStyle(
                                color: tossSubText,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: kScheduleTypes.map((t) {
                                final bool selected = t == type;
                                return ChoiceChip(
                                  label: Text(t),
                                  selected: selected,
                                  selectedColor: tossBlue.withValues(
                                    alpha: 0.15,
                                  ),
                                  labelStyle: TextStyle(
                                    color: selected ? tossBlue : tossSubText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  backgroundColor: tossBg,
                                  side: BorderSide.none,
                                  onSelected: (_) => setModalState(() {
                                    type = t;
                                    // 🚀 "자재 요청"이 아닌 종류는 날짜가 필수라
                                    // 비어있으면 기본값(내일)을 채워준다.
                                    if (type != "자재 요청" && dateTime == null) {
                                      dateTime = DateTime.now().add(
                                        const Duration(days: 1),
                                      );
                                    }
                                  }),
                                );
                              }).toList(),
                            ),
                            if (widget.phases.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                "단계",
                                style: TextStyle(
                                  color: tossSubText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final p in [
                                    {'id': null, 'name': '지정 안 함'},
                                    ...widget.phases,
                                  ])
                                    ChoiceChip(
                                      label: Text(p['name'].toString()),
                                      selected: phaseId == p['id']?.toString(),
                                      selectedColor: tossBlue.withValues(
                                        alpha: 0.15,
                                      ),
                                      labelStyle: TextStyle(
                                        color: phaseId == p['id']?.toString()
                                            ? tossBlue
                                            : tossSubText,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      backgroundColor: tossBg,
                                      side: BorderSide.none,
                                      onSelected: (_) => setModalState(
                                        () => phaseId = p['id']?.toString(),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 20),
                            TextField(
                              controller: titleCtrl,
                              style: const TextStyle(
                                color: tossText,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                labelText: "제목 (비워두면 종류로 표시)",
                                filled: true,
                                fillColor: tossBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                final DateTime base =
                                    dateTime ?? DateTime.now();
                                final pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: base,
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 730),
                                  ),
                                );
                                if (pickedDate == null) return;
                                if (!context.mounted) return;
                                final pickedTime = await showMakitaTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(base),
                                );
                                final DateTime newDateTime = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime?.hour ?? 9,
                                  pickedTime?.minute ?? 0,
                                );

                                // 🚀 검사일정/납기일을 "수정"하면서 날짜가 실제로
                                // 바뀌는 경우엔 사유를 받아 이력에 남긴다. 새로
                                // 만드는 중이거나 다른 종류면 그냥 바로 반영한다.
                                final bool isReschedule =
                                    existing != null &&
                                    _ProjectSchedulePageState
                                        ._reschedulableTypes
                                        .contains(type) &&
                                    dateTime != null &&
                                    !dateTime!.isAtSameMomentAs(newDateTime);

                                if (isReschedule) {
                                  if (!context.mounted) return;
                                  final String? reason = await _askChangeReason(
                                    context,
                                  );
                                  if (reason == null) return; // 취소 시 변경 안 함
                                  changeHistory.add({
                                    'from': dateTime,
                                    'to': newDateTime,
                                    'reason': reason,
                                    'changedAt': DateTime.now(),
                                  });
                                }

                                setModalState(() {
                                  dateTime = newDateTime;
                                  // 🚀 날짜를 받았다는 건 입고일이 확정됐다는
                                  // 뜻이니, "자재 요청"이었다면 여기서 바로
                                  // "입고일"로 전환한다.
                                  if (type == "자재 요청") type = "입고일";
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: tossBg,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      dateTime != null
                                          ? _formatDateTime(dateTime!)
                                          : "아직 입고일 모름 (탭해서 입력)",
                                      style: TextStyle(
                                        color: dateTime != null
                                            ? tossText
                                            : tossSubText,
                                        fontWeight: dateTime != null
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.calendar_month_rounded,
                                      color: tossBlue,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (type == "자재 요청" && dateTime != null) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () =>
                                    setModalState(() => dateTime = null),
                                style: TextButton.styleFrom(
                                  foregroundColor: tossSubText,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  "입고일 모름으로 되돌리기",
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                            if (dateTime != null) ...[
                              const SizedBox(height: 16),
                              const Text(
                                "기간 (여러 날에 걸친 작업)",
                                style: TextStyle(
                                  color: tossSubText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final d in [1, 3, 7, 14, 28, 56])
                                    Builder(
                                      builder: (_) {
                                        final DateTime s = DateTime(
                                          dateTime!.year,
                                          dateTime!.month,
                                          dateTime!.day,
                                        );
                                        final int cur = endDate == null
                                            ? 1
                                            : DateTime(
                                                    endDate!.year,
                                                    endDate!.month,
                                                    endDate!.day,
                                                  ).difference(s).inDays +
                                                  1;
                                        final bool selected = cur == d;
                                        return ChoiceChip(
                                          label: Text(
                                            d == 1
                                                ? "당일"
                                                : (d % 7 == 0
                                                      ? "${d ~/ 7}주"
                                                      : "$d일"),
                                          ),
                                          selected: selected,
                                          selectedColor: tossBlue.withValues(
                                            alpha: 0.15,
                                          ),
                                          labelStyle: TextStyle(
                                            color: selected
                                                ? tossBlue
                                                : tossSubText,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          backgroundColor: tossBg,
                                          side: BorderSide.none,
                                          onSelected: (_) => setModalState(
                                            () => endDate = d == 1
                                                ? null
                                                : s.add(Duration(days: d - 1)),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  final DateTime s = DateTime(
                                    dateTime!.year,
                                    dateTime!.month,
                                    dateTime!.day,
                                  );
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        (endDate == null ||
                                            endDate!.isBefore(s))
                                        ? s
                                        : endDate!,
                                    firstDate: s,
                                    lastDate: s.add(const Duration(days: 730)),
                                  );
                                  if (picked != null) {
                                    setModalState(
                                      () =>
                                          endDate = picked == s ? null : picked,
                                    );
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tossBg,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    endDate == null
                                        ? "종료일 없음 (하루 일정)"
                                        : "종료일 ${endDate!.year}.${endDate!.month.toString().padLeft(2, '0')}.${endDate!.day.toString().padLeft(2, '0')}",
                                    style: TextStyle(
                                      color: endDate == null
                                          ? tossSubText
                                          : tossText,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "며칠 전부터 미리 알림",
                                style: TextStyle(
                                  color: tossSubText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [0, 1, 3, 7].map((d) {
                                  final bool selected = reminderLeadDays == d;
                                  return ChoiceChip(
                                    label: Text(d == 0 ? "당일만" : "$d일 전부터"),
                                    selected: selected,
                                    selectedColor: tossBlue.withValues(
                                      alpha: 0.15,
                                    ),
                                    labelStyle: TextStyle(
                                      color: selected ? tossBlue : tossSubText,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    backgroundColor: tossBg,
                                    side: BorderSide.none,
                                    onSelected: (_) => setModalState(
                                      () => reminderLeadDays = d,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextField(
                              controller: noteCtrl,
                              maxLines: 2,
                              style: const TextStyle(color: tossText),
                              decoration: InputDecoration(
                                labelText: "메모 (선택)",
                                filled: true,
                                fillColor: tossBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tossBlue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context, {
                            'id':
                                existing?['id'] ??
                                DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                            'type': type,
                            'title': titleCtrl.text.trim().isNotEmpty
                                ? titleCtrl.text.trim()
                                : type,
                            'dateTime': dateTime,
                            'endDate': endDate,
                            'phaseId': phaseId,
                            'note': noteCtrl.text.trim(),
                            'isCompleted': existing?['isCompleted'] ?? false,
                            // 🚀 입고일을 아직 모르는 "자재 요청"이 "발주한
                            // 지 며칠째"를 알려줄 수 있도록 최초 등록
                            // 시간을 남겨둔다 (수정해도 값은 유지).
                            'requestedAt':
                                existing?['requestedAt'] ?? DateTime.now(),
                            'changeHistory': changeHistory,
                            // 🚀 [추가] 며칠 전부터 미리 알림 받을지.
                            'reminderLeadDays': reminderLeadDays,
                            // 🚀 [수정] 이 화면(수정 모드)에서 새 Map을
                            // 통째로 만들어 기존 항목을 덮어쓰다 보니,
                            // 검사 결과(합격/불합격+코멘트)를 여기서
                            // 안 옮겨주면 단순 제목/메모 수정만 해도
                            // 검사 결과가 사라지는 문제가 있었다. 그대로
                            // 이어서 담아준다.
                            'inspectionResult': existing?['inspectionResult'],
                            'inspectionComment': existing?['inspectionComment'],
                            'inspectionResultAt':
                                existing?['inspectionResultAt'],
                            // 🚀 시간/종류가 바뀔 수 있으니 저장할 때마다
                            // 알림 발송 플래그를 초기화해서, 새 시간
                            // 기준으로 다시 알림이 잡히게 한다.
                            'reminderSent': false,
                            'lastOverdueReminderDate': null,
                            'lastLeadReminderDate': null,
                          });
                        },
                        child: Text(
                          existing == null ? "추가" : "저장",
                          style: const TextStyle(
                            color: pureWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;
    setState(() {
      if (existing != null) {
        final idx = _schedules.indexWhere((s) => s['id'] == existing['id']);
        if (idx != -1) {
          _schedules[idx] = result;
        }
      } else {
        _schedules.add(result);
      }
      _sort();
      _changed = true;
    });
  }

  // 🚀 [추가] 검사일정은 단순 체크가 아니라 "합격/불합격 + 코멘트"를
  // 남기게 해서 나중에 어떤 검사가 어떻게 됐는지 추적할 수 있게 한다.
  // 취소하면 null - 완료 처리를 하지 않는다.
  Future<Map<String, String>?> _askInspectionResult(
    BuildContext context,
  ) async {
    String result = 'PASS';
    final ctrl = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "검사 결과 입력",
            style: TextStyle(fontWeight: FontWeight.w800, color: tossText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text("합격"),
                      selected: result == 'PASS',
                      selectedColor: Colors.green.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: result == 'PASS' ? Colors.green : tossSubText,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: tossBg,
                      side: BorderSide.none,
                      onSelected: (_) => setDialogState(() => result = 'PASS'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text("불합격"),
                      selected: result == 'FAIL',
                      selectedColor: warningRed.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: result == 'FAIL' ? warningRed : tossSubText,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: tossBg,
                      side: BorderSide.none,
                      onSelected: (_) => setDialogState(() => result = 'FAIL'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 2,
                style: const TextStyle(color: tossText),
                decoration: InputDecoration(
                  hintText: "코멘트 (선택)",
                  hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
                  filled: true,
                  fillColor: tossBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("취소", style: TextStyle(color: tossSubText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: result == 'FAIL' ? warningRed : Colors.green,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, {
                'result': result,
                'comment': ctrl.text.trim(),
              }),
              child: const Text(
                "완료 처리",
                style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
