// ignore_for_file: invalid_use_of_protected_member
part of 'daily_report_page.dart';

// 🚀 submit 부분(화면 클래스에서 옮겨 온 메서드들, 동작은 그대로).
extension _DailyReportSubmit on _DailyReportPageState {
  // 🚀 지난 날짜 일지 수정 시 사유를 받는 팝업. 취소하면 null.
  Future<String?> _askEditReason() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "지난 일지 수정 사유",
          style: TextStyle(fontWeight: FontWeight.w800, color: tossText),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              keepWords("지난 날짜의 작업 일지는 함부로 바꾸지 않도록, 수정할 때 사유를 남깁니다."),
              style: TextStyle(color: tossSubText, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 2,
              style: const TextStyle(color: tossText),
              decoration: InputDecoration(
                hintText: "예: 포인트 집계 실수 정정",
                hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
                filled: true,
                fillColor: tossInputBg,
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
              backgroundColor: tossBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(
              context,
              ctrl.text.trim().isEmpty ? "사유 미입력" : ctrl.text.trim(),
            ),
            child: const Text(
              "수정 확정",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() async {
    String ptText = _pointCtrl.text.trim();
    String wpText = _wiringPointCtrl.text.trim();
    String ntText = _noteCtrl.text.trim();

    if (ptText.isEmpty &&
        wpText.isEmpty &&
        ntText.isEmpty &&
        _attachedImages.isEmpty &&
        // 이슈 처리/일정 완료/자재 사용만 골라도 기록으로 인정한다.
        _selectedIssueIds.isEmpty &&
        _completedScheduleIds.isEmpty &&
        _usedMaterialIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(keepWords("작업 내용, 사진, 또는 처리한 이슈/일정을 하나 이상 입력해야 합니다.")),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 🚀 지난 날짜 일지를 수정하는 경우, 사유를 받아 이력에 남기기 전엔
    // 저장을 진행하지 않는다. 취소하면 그대로 화면에 머문다.
    final List<Map<String, dynamic>> editHistory = _isEdit
        ? List<Map<String, dynamic>>.from(
            (widget.existingData!['editHistory'] as List? ?? []).map(
              (e) => Map<String, dynamic>.from(e),
            ),
          )
        : [];

    if (_isPastEdit) {
      final String? reason = await _askEditReason();
      if (reason == null) return;
      editHistory.add({'reason': reason, 'editedAt': DateTime.now()});
    }

    // 끝낸 일정으로 체크한 미완료 일정이 있으면, 프로젝트 일정도 완료로 바꿀지 묻는다.
    bool scheduleNoApply = false;
    final newlyDone = widget.pendingSchedules
        .where(
          (s) =>
              _completedScheduleIds.contains(s['id']?.toString()) &&
              s['isCompleted'] != true,
        )
        .toList();
    if (newlyDone.isNotEmpty) {
      if (!mounted) return;
      final mark = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(keepWords("일정을 완료로 표시하시겠습니까?")),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                keepWords("'오늘 끝낸 일정'으로 체크한 일정입니다. 완료로 바꾸면 진행률에 반영됩니다."),
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 10),
              for (final s in newlyDone.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    keepWords("• ${s['title'] ?? s['type'] ?? ''}"),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              if (newlyDone.length > 4)
                Text(keepWords("외 ${newlyDone.length - 4}건")),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("기록만 남기기"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("완료로 표시"),
            ),
          ],
        ),
      );
      if (mark == null || !mounted) return;
      scheduleNoApply = !mark;
    }

    // 고른 이슈 중 아직 미해결인 것이 있으면, 처리 완료로 표시할지 묻는다.
    final List<String> resolveIds = [];
    final unresolvedPicked = widget.relatedIssueCandidates
        .where(
          (p) =>
              _selectedIssueIds.contains(p['id']?.toString()) &&
              p['is_completed'] != true,
        )
        .toList();
    if (unresolvedPicked.isNotEmpty) {
      if (!mounted) return;
      final mark = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(keepWords("이슈를 완료로 표시하시겠습니까?")),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                keepWords(
                  "'오늘 처리한 이슈'로 고른 미해결 이슈입니다. 처리 완료로 바꾸면 이슈 목록에서도 완료로 정리됩니다.",
                ),
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 10),
              for (final p in unresolvedPicked.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    keepWords(
                      "• ${(p['location']?.toString() ?? '').isEmpty ? '' : '${p['location']} · '}${p['content'] ?? ''}",
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              if (unresolvedPicked.length > 4)
                Text(keepWords("외 ${unresolvedPicked.length - 4}건")),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("기록만 남기기"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("처리 완료로 표시"),
            ),
          ],
        ),
      );
      if (mark == null || !mounted) return;
      if (mark) {
        resolveIds.addAll(unresolvedPicked.map((p) => p['id'].toString()));
      }
    }

    final dateStr = _isEdit
        ? widget.existingData!['date']
        : _DailyReportPageState._mmdd(_reportDay);

    final newReport = {
      "date": dateStr,
      "dateISO": _isEdit
          ? widget.existingData!['dateISO']
          : _reportDay.toIso8601String().substring(0, 10),
      "work_type": _selectedWorkTypes.toList(),
      "worker_count": _workerCount,
      "attendance_type": _attendanceType,
      "check_in": _checkIn != null ? _formatTimeOfDay(_checkIn!) : null,
      "check_out": _checkOut != null ? _formatTimeOfDay(_checkOut!) : null,
      "worked_hours": _workedHours,
      "is_overtime": _isOvertime,
      // 🚀 [추가] 연장/야간 작업 시간대 - 껐으면 기록도 지운다.
      "overtime_start": _isOvertime && _overtimeStart != null
          ? _formatTimeOfDay(_overtimeStart!)
          : null,
      "overtime_end": _isOvertime && _overtimeEnd != null
          ? _formatTimeOfDay(_overtimeEnd!)
          : null,
      "overtime_hours": _isOvertime ? _overtimeHours : null,
      "points": int.tryParse(ptText) ?? 0,
      "wiring_points": int.tryParse(wpText) ?? 0,
      "note": ntText.isEmpty ? "특이사항 없음" : ntText,
      "is_as_built": _isAsBuilt,
      "as_built_reason": _isAsBuilt ? _asBuiltCtrl.text.trim() : "",
      "has_image": _attachedImages.isNotEmpty,
      "image_path": _attachedImages.isNotEmpty ? _attachedImages.first : null,
      "image_paths": List.from(_attachedImages),
      "editHistory": editHistory,
      // 🚀 [추가] 오늘 처리한 이슈 태그.
      "linkedIssueIds": _selectedIssueIds.toList(),
      // 🚀 [추가] 내일 계획 / 오늘 사용한 자재.
      "next_day_plan": _nextDayPlanCtrl.text.trim(),
      "materials_used": _materialsUsedCtrl.text.trim(),
      // 🚀 [추가] 도면 위 작업 위치 핀.
      "locationPinDx": _pinDx,
      "locationPinDy": _pinDy,
      "image_tags": {
        for (final p in _attachedImages)
          if (_imageTags[p] != null) p: _imageTags[p]!,
      },
      "image_captions": {
        for (final p in _attachedImages)
          if ((_imageCaptions[p] ?? '').isNotEmpty) p: _imageCaptions[p]!,
      },
      "usedMaterialIds": _usedMaterialIds.toList(),
      "resolveIssueIds": resolveIds,
      "scheduleNoApply": scheduleNoApply,
      "workedPhaseIds": _workedPhaseIds.toList(),
      "completedScheduleIds": _completedScheduleIds.toList(),
      "completedPhaseIds": _completedPhaseIds.toList(),
    };

    if (!mounted) return;
    _submitted = true;
    _draftTimer?.cancel();
    await _clearDraft();
    if (!mounted) return;
    Navigator.pop(context, newReport);
  }
}
