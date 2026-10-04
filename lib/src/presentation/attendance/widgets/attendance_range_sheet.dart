// 여러 날 한 번에 기록하는 아래 창. 시작일·끝날·종류·시간·휴게·메모를 고르고,
// 쉬는 날 건너뛰기와 덮어쓰기를 정한다. 저장은 화면(attendance_page.dart)이 한다.
library;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/common_widgets/makita_time_picker.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';

import '../../my_work_logs/models/attendance.dart';
import '../attendance_bulk.dart';
import '../attendance_calc.dart';
import '../attendance_settings.dart';
import 'attendance_sheets.dart' show attendanceChoice;

const Color _text = AppColors.text;
const Color _sub = AppColors.textSub;
const Color _brand = AppColors.brand;

/// 창이 돌려주는 값.
class AttendanceRangeResult {
  final DateTime from;
  final DateTime to;
  final AttendanceRecord template; // 날짜는 뜻 없음(저장할 때 날마다 입힌다)
  final bool skipOff;
  final bool overwrite;
  const AttendanceRangeResult({
    required this.from,
    required this.to,
    required this.template,
    required this.skipOff,
    required this.overwrite,
  });
}

class AttendanceRangeSheet extends StatefulWidget {
  final DateTime today;
  final AttendanceCalcOptions options;
  const AttendanceRangeSheet({
    super.key,
    required this.today,
    this.options = const AttendanceCalcOptions(),
  });

  @override
  State<AttendanceRangeSheet> createState() => _AttendanceRangeSheetState();
}

const List<int?> _breakChoices = [null, 0, 30, 60, 90, 120];

class _AttendanceRangeSheetState extends State<AttendanceRangeSheet> {
  late DateTime _from = widget.today;
  late DateTime _to = widget.today;
  String _type = kAttendanceNormal;
  TimeOfDay? _checkIn;
  TimeOfDay? _checkOut;
  int? _breakMin;
  bool _skipOff = true;
  bool _overwrite = false;
  final TextEditingController _memo = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkIn = _parse(widget.options.workStart);
    _checkOut = _parse(widget.options.workEnd);
  }

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  TimeOfDay? _parse(String? v) {
    final m = minutesOfDay(v);
    return m == null ? null : TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  String? _fmt(TimeOfDay? t) => t == null
      ? null
      : "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  String _dateText(DateTime d) =>
      "${d.month}월 ${d.day}일 (${kWeekdayKo[d.weekday - 1]})";

  Future<void> _pickDate({required bool isFrom}) async {
    final cur = isFrom ? _from : _to;
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(widget.today.year - 2),
      lastDate: DateTime(widget.today.year + 1, 12, 31),
      helpText: isFrom ? "시작일" : "끝날",
    );
    if (d == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = d;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = d;
        if (_to.isBefore(_from)) _from = _to;
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showMakitaTimePicker(
      context: context,
      title: isStart ? "출근 시간" : "퇴근 시간",
      initialTime:
          (isStart ? _checkIn : _checkOut) ??
          TimeOfDay(hour: isStart ? 8 : 17, minute: 0),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _checkIn = picked;
      } else {
        _checkOut = picked;
      }
    });
  }

  Widget _dateBox(String label, DateTime d, bool isFrom) => Expanded(
    child: InkWell(
      key: Key(isFrom ? 'att_range_from' : 'att_range_to'),
      onTap: () => _pickDate(isFrom: isFrom),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _sub, fontSize: 11)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _dateText(d),
                style: const TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _timeBox(String label, TimeOfDay? t, bool isStart) => Expanded(
    child: InkWell(
      key: Key(isStart ? 'att_range_in' : 'att_range_out'),
      onTap: () => _pickTime(isStart: isStart),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                t != null ? _fmt(t)! : label,
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

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        color: _text,
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
    ),
  );

  String _breakLabel(int? v) {
    if (v == null) {
      return "기본(${defaultBreakLabel(widget.options.defaultBreak)})";
    }
    if (v == 0) return "없음";
    return formatMinutes(v);
  }

  // 이 창에서는 이미 있는 기록을 아직 모른다(저장할 때 읽어서 가린다). 개수는 쉬는 날만 뺀다.
  BulkPlan _plan() =>
      planBulk(from: _from, to: _to, skipOff: _skipOff, overwrite: true);

  @override
  Widget build(BuildContext context) {
    final noTime = hasNoWorkTime(_type);
    final plan = _plan();
    final String preview;
    if (plan.invalid) {
      preview = "끝날이 시작일보다 앞입니다.";
    } else if (plan.tooLong) {
      preview = "한 번에 $kBulkMaxDays일까지만 기록할 수 있습니다.";
    } else if (plan.days.isEmpty) {
      preview = "기록할 날이 없습니다(모두 쉬는 날).";
    } else {
      preview =
          "${plan.days.length}일에 기록합니다"
          "${plan.skippedOff.isEmpty ? '' : ' (쉬는 날 ${plan.skippedOff.length}일 빼고)'}.";
    }
    final canSave = !plan.invalid && !plan.tooLong && plan.days.isNotEmpty;
    final memo = _memo.text.trim();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
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
            const Text(
              "여러 날 한 번에 기록",
              style: TextStyle(
                color: _text,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "연달아 쉬거나 같은 시간으로 일한 날을 한꺼번에 적습니다.",
              style: TextStyle(color: _sub, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _dateBox("시작일", _from, true),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text("~", style: TextStyle(color: _sub)),
                ),
                _dateBox("끝날", _to, false),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in kAttendanceTypes)
                  attendanceChoice(
                    key: Key('att_range_type_$t'),
                    label: t,
                    selected: _type == t,
                    onTap: () => setState(() => _type = t),
                  ),
              ],
            ),
            if (!noTime) ...[
              const SizedBox(height: 14),
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
              const SizedBox(height: 12),
              _label("휴게시간"),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final b in _breakChoices)
                    attendanceChoice(
                      key: Key('att_range_break_${b ?? 'default'}'),
                      label: _breakLabel(b),
                      selected: _breakMin == b,
                      onTap: () => setState(() => _breakMin = b),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              key: const Key('att_range_memo'),
              controller: _memo,
              maxLength: 40,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: "현장 메모(선택)",
                hintText: "예: 태안 3호기, 휴가",
                border: OutlineInputBorder(),
                isDense: true,
                counterText: '',
              ),
            ),
            SwitchListTile(
              key: const Key('att_range_skip_off'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _skipOff,
              activeThumbColor: _brand,
              onChanged: (v) => setState(() => _skipOff = v),
              title: const Text(
                "토·일·공휴일은 빼기",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            SwitchListTile(
              key: const Key('att_range_overwrite'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _overwrite,
              activeThumbColor: _brand,
              onChanged: (v) => setState(() => _overwrite = v),
              title: const Text(
                "이미 적은 날도 바꾸기",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: const Text(
                "끄면 기록이 있는 날은 그대로 둡니다.",
                style: TextStyle(color: _sub, fontSize: 12),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              preview,
              key: const Key('att_range_preview'),
              style: TextStyle(
                color: canSave ? _brand : AppColors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('att_range_save'),
                onPressed: canSave
                    ? () => Navigator.pop(
                        context,
                        AttendanceRangeResult(
                          from: _from,
                          to: _to,
                          template: AttendanceRecord(
                            date: _from,
                            type: _type,
                            checkIn: noTime ? null : _fmt(_checkIn),
                            checkOut: noTime ? null : _fmt(_checkOut),
                            breakMin: noTime ? null : _breakMin,
                            memo: memo.isEmpty ? null : memo,
                          ),
                          skipOff: _skipOff,
                          overwrite: _overwrite,
                        ),
                      )
                    : null,
                style: FilledButton.styleFrom(backgroundColor: _brand),
                child: Text(canSave ? "${plan.days.length}일 기록" : "기록"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
