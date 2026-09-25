// 근태 관리(필드 헬퍼 4번) - 작업 일지와 별개로, 사람 기준으로 날짜별 근태
// (정상근무/연차/월차/반차/조퇴/특근)와 출퇴근 시간을 기록한다. 어느 프로젝트의
// 일지를 썼는지와 무관하며, 공수(인·일) 통계 쪽에서는 날짜만 맞춰 이 기록을
// 가져다 쓴다(AttendanceCache 참고).
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tubing_calculator/src/core/common_widgets/makita_time_picker.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/attendance.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_phase.dart'
    show dayOnly;
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/korean_text.dart';

const Color _bg = AppColors.background;
const Color _text = AppColors.text;
const Color _sub = AppColors.textSub;
const Color _white = Color(0xFFFFFFFF);
const Color _brand = AppColors.brand;

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  DateTime _viewedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, AttendanceRecord> _records = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final m = await loadAttendanceMonth(_viewedMonth);
    if (!mounted) return;
    setState(() {
      _records = m;
      _loading = false;
    });
  }

  void _changeMonth(int delta) {
    setState(
      () => _viewedMonth = DateTime(_viewedMonth.year, _viewedMonth.month + delta),
    );
    _load();
  }

  Future<void> _openDay(DateTime day) async {
    final key = dateKey(day);
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AttendanceEditSheet(day: day, existing: _records[key]),
    );
    if (changed == true) {
      // 통계 화면(project_stats_page 등)에서 새로고침 없이 바로 반영되도록.
      await AttendanceCache.refresh();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(
      _viewedMonth.year,
      _viewedMonth.month + 1,
      0,
    ).day;
    final today = dayOnly(DateTime.now());
    final counts = <String, int>{};
    for (final r in _records.values) {
      if (r.type == kAttendanceNormal) continue;
      counts[r.type] = (counts[r.type] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _white,
        foregroundColor: _text,
        elevation: 0,
        title: const Text(
          "근태 관리",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: _white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(AppIcons.back),
                ),
                Text(
                  "${_viewedMonth.year}년 ${_viewedMonth.month}월",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: _text,
                  ),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(AppIcons.forward),
                ),
              ],
            ),
          ),
          if (counts.isNotEmpty)
            Container(
              width: double.infinity,
              color: _white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: counts.entries
                    .map(
                      (e) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${e.key} ${e.value}일",
                          style: const TextStyle(
                            color: _text,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: daysInMonth,
                    itemBuilder: (context, i) {
                      final day = DateTime(
                        _viewedMonth.year,
                        _viewedMonth.month,
                        i + 1,
                      );
                      final r = _records[dateKey(day)];
                      final type = r?.type ?? kAttendanceNormal;
                      final isToday = dayOnly(day) == today;
                      final weekday = const [
                        '월',
                        '화',
                        '수',
                        '목',
                        '금',
                        '토',
                        '일',
                      ][day.weekday - 1];
                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _openDay(day);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _white,
                            borderRadius: BorderRadius.circular(12),
                            border: isToday
                                ? Border.all(color: _brand, width: 1.4)
                                : null,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 56,
                                child: Text(
                                  "${day.day}일 ($weekday)",
                                  style: const TextStyle(
                                    color: _text,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (type != kAttendanceNormal)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _brand,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    type,
                                    style: const TextStyle(
                                      color: _white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              if (r?.checkIn != null || r?.checkOut != null)
                                Text(
                                  "${r?.checkIn ?? '--:--'} ~ ${r?.checkOut ?? '--:--'}",
                                  style: const TextStyle(
                                    color: _sub,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              const SizedBox(width: 6),
                              const Icon(
                                AppIcons.forward,
                                size: 18,
                                color: _sub,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceEditSheet extends StatefulWidget {
  final DateTime day;
  final AttendanceRecord? existing;
  const _AttendanceEditSheet({required this.day, this.existing});

  @override
  State<_AttendanceEditSheet> createState() => _AttendanceEditSheetState();
}

class _AttendanceEditSheetState extends State<_AttendanceEditSheet> {
  late String _type;
  TimeOfDay? _checkIn;
  TimeOfDay? _checkOut;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.type ?? kAttendanceNormal;
    _checkIn = _parseTimeOfDay(widget.existing?.checkIn);
    _checkOut = _parseTimeOfDay(widget.existing?.checkOut);
  }

  TimeOfDay? _parseTimeOfDay(String? v) {
    if (v == null || !v.contains(':')) return null;
    final parts = v.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTimeOfDay(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  double? get _workedHours => workedHoursOf(
    _checkIn != null ? _formatTimeOfDay(_checkIn!) : null,
    _checkOut != null ? _formatTimeOfDay(_checkOut!) : null,
  );

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showMakitaTimePicker(
      context: context,
      title: isStart ? "출근 시간" : "퇴근 시간",
      initialTime:
          (isStart ? _checkIn : _checkOut) ??
          TimeOfDay(hour: isStart ? 8 : 17, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _checkIn = picked;
      } else {
        _checkOut = picked;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await saveAttendance(
      AttendanceRecord(
        date: widget.day,
        type: _type,
        checkIn: isFullDayLeave(_type)
            ? null
            : (_checkIn != null ? _formatTimeOfDay(_checkIn!) : null),
        checkOut: isFullDayLeave(_type)
            ? null
            : (_checkOut != null ? _formatTimeOfDay(_checkOut!) : null),
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    await deleteAttendance(widget.day);
    if (mounted) Navigator.pop(context, true);
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: sel ? _brand : _bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: sel ? _white : _sub,
          fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
          fontSize: 13,
        ),
      ),
    ),
  );

  Widget _timeBox(String label, TimeOfDay? t, bool isStart) => Expanded(
    child: InkWell(
      onTap: () => _pickTime(isStart: isStart),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                t != null ? _formatTimeOfDay(t) : label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: t != null ? _text : _sub,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.access_time_rounded, size: 16, color: _sub),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${widget.day.month}월 ${widget.day.day}일 근태",
              style: const TextStyle(
                color: _text,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kAttendanceTypes
                  .map(
                    (type) => _chip(
                      type,
                      _type == type,
                      () => setState(() => _type = type),
                    ),
                  )
                  .toList(),
            ),
            if (!isFullDayLeave(_type)) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  _timeBox("출근 시간", _checkIn, true),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text("~", style: TextStyle(color: _sub)),
                  ),
                  _timeBox("퇴근 시간", _checkOut, false),
                ],
              ),
              if (_workedHours != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    keepWords(
                      "근무 시간: ${_workedHours!.toStringAsFixed(1)}시간",
                    ),
                    style: const TextStyle(
                      color: _brand,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (widget.existing != null)
                  TextButton(
                    onPressed: _busy ? null : _delete,
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    child: const Text("삭제"),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: _brand),
                  child: const Text("저장"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
