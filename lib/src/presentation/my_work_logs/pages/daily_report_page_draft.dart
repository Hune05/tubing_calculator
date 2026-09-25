// ignore_for_file: invalid_use_of_protected_member
part of 'daily_report_page.dart';

// 🚀 draft 부분(화면 클래스에서 옮겨 온 메서드들, 동작은 그대로).
extension _DailyReportDraft on _DailyReportPageState {
  String? _draftJson() {
    final empty =
        _pointCtrl.text.trim().isEmpty &&
        _wiringPointCtrl.text.trim().isEmpty &&
        _noteCtrl.text.trim().isEmpty &&
        _materialsUsedCtrl.text.trim().isEmpty &&
        _nextDayPlanCtrl.text.trim().isEmpty &&
        _attachedImages.isEmpty;
    if (empty) return null;
    return jsonEncode({
      'savedAt': DateTime.now().toIso8601String(),
      // 고른 일지 날짜(다음 날 이어 써도 그 날짜로 남게).
      'reportDay': _reportDay.toIso8601String().substring(0, 10),
      'points': _pointCtrl.text,
      'wiring': _wiringPointCtrl.text,
      'note': _noteCtrl.text,
      'materials': _materialsUsedCtrl.text,
      'plan': _nextDayPlanCtrl.text,
      'asBuiltReason': _asBuiltCtrl.text,
      'isAsBuilt': _isAsBuilt,
      'workTypes': _selectedWorkTypes.toList(),
      'workers': _workerCount,
      'attendance': _attendanceType,
      'checkIn': _checkIn == null ? null : _formatTimeOfDay(_checkIn!),
      'checkOut': _checkOut == null ? null : _formatTimeOfDay(_checkOut!),
      'overtime': _isOvertime,
      'otStart': _overtimeStart == null
          ? null
          : _formatTimeOfDay(_overtimeStart!),
      'otEnd': _overtimeEnd == null ? null : _formatTimeOfDay(_overtimeEnd!),
      'images': _attachedImages,
      'imageTags': _imageTags,
      'imageCaptions': _imageCaptions,
      'usedMaterials': _usedMaterialIds.toList(),
      'phases': _workedPhaseIds.toList(),
      'doneSchedules': _completedScheduleIds.toList(),
      'issues': _selectedIssueIds.toList(),
      'pinDx': _pinDx,
      'pinDy': _pinDy,
    });
  }

  Future<void> _saveDraft() async {
    if (_submitted || widget.draftKey == null) return;
    final json = _draftJson();
    if (json == null) return;
    // savedAt은 매번 달라지므로 그 값을 빼고 비교해 바뀐 게 있을 때만 쓴다.
    final cmp = json.replaceFirst(RegExp(r'"savedAt":"[^"]*",'), '');
    if (cmp == _lastDraft) return;
    _lastDraft = cmp;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(widget.draftKey!, json);
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    if (widget.draftKey == null) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(widget.draftKey!);
    } catch (_) {}
  }

  Future<void> _offerDraft() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(widget.draftKey!);
      if (raw == null || !mounted) return;
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final saved = DateTime.tryParse(m['savedAt']?.toString() ?? '');
      if (saved == null ||
          DateTime.now().difference(saved) > const Duration(days: 2)) {
        await _clearDraft();
        return;
      }
      final resume = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(keepWords("작성 중이던 작업 일지가 있습니다")),
          content: Text(
            keepWords(
              "${saved.month}/${saved.day} ${saved.hour.toString().padLeft(2, '0')}:${saved.minute.toString().padLeft(2, '0')}에 저장된 임시 내용을 이어서 작성하시겠습니까?",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("새로 시작"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("이어서 쓰기"),
            ),
          ],
        ),
      );
      if (resume == true) {
        _applyDraft(m);
      } else {
        await _clearDraft();
      }
    } catch (_) {}
  }

  List<String> _strList(dynamic v) =>
      (v as List? ?? []).map((e) => e.toString()).toList();

  void _applyDraft(Map<String, dynamic> m) {
    setState(() {
      final day = DateTime.tryParse(m['reportDay']?.toString() ?? '');
      if (day != null) _reportDay = dayOnly(day);
      _pointCtrl.text = m['points']?.toString() ?? '';
      _wiringPointCtrl.text = m['wiring']?.toString() ?? '';
      _noteCtrl.text = m['note']?.toString() ?? '';
      _materialsUsedCtrl.text = m['materials']?.toString() ?? '';
      _nextDayPlanCtrl.text = m['plan']?.toString() ?? '';
      _asBuiltCtrl.text = m['asBuiltReason']?.toString() ?? '';
      _isAsBuilt = m['isAsBuilt'] == true;
      final wt = _strList(m['workTypes']);
      if (wt.isNotEmpty) {
        _selectedWorkTypes
          ..clear()
          ..addAll(wt);
      }
      _workerCount = (m['workers'] as num?)?.toInt() ?? _workerCount;
      _attendanceType = m['attendance']?.toString() ?? _attendanceType;
      _checkIn = _parseTimeOfDay(m['checkIn']);
      _checkOut = _parseTimeOfDay(m['checkOut']);
      _isOvertime = m['overtime'] == true;
      _overtimeStart = _parseTimeOfDay(m['otStart']);
      _overtimeEnd = _parseTimeOfDay(m['otEnd']);
      _attachedImages = _strList(m['images']);
      _imageTags
        ..clear()
        ..addAll(
          Map<String, dynamic>.from(
            (m['imageTags'] as Map?) ?? {},
          ).map((k, v) => MapEntry(k, v.toString())),
        );
      _imageCaptions
        ..clear()
        ..addAll(
          Map<String, dynamic>.from(
            (m['imageCaptions'] as Map?) ?? {},
          ).map((k, v) => MapEntry(k, v.toString())),
        );
      _usedMaterialIds
        ..clear()
        ..addAll(_strList(m['usedMaterials']));
      _workedPhaseIds
        ..clear()
        ..addAll(_strList(m['phases']));
      _completedScheduleIds
        ..clear()
        ..addAll(_strList(m['doneSchedules']));
      _selectedIssueIds
        ..clear()
        ..addAll(_strList(m['issues']));
      _pinDx = (m['pinDx'] as num?)?.toDouble();
      _pinDy = (m['pinDy'] as num?)?.toDouble();
    });
  }
}
