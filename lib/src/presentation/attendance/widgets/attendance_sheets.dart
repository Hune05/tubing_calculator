// 근태 관리 아래 창 두 개: 하루 기록 고치기, 근태 설정.
// 창은 고른 값만 돌려주고 저장은 화면(attendance_page.dart)이 한다(통신 없어도 바로 닫힌다).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tubing_calculator/src/core/common_widgets/makita_time_picker.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';

import '../../my_schedule/korean_holidays.dart';
import '../../my_work_logs/models/attendance.dart';
import '../attendance_calc.dart';
import '../attendance_settings.dart';

const Color _text = AppColors.text;
const Color _sub = AppColors.textSub;
const Color _brand = AppColors.brand;

/// 하루 창의 결과: 저장할 기록, 또는 지우기.
class AttendanceSheetResult {
  final AttendanceRecord? save;
  final bool delete;
  const AttendanceSheetResult.save(AttendanceRecord r)
    : save = r,
      delete = false;
  const AttendanceSheetResult.delete() : save = null, delete = true;
}

/// 고름 상태를 화면 읽기에도 알리는 칩(ChoiceChip).
Widget attendanceChoice({
  Key? key,
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) => ChoiceChip(
  key: key,
  label: Text(label),
  selected: selected,
  showCheckmark: false,
  onSelected: (_) {
    HapticFeedback.selectionClick();
    onTap();
  },
  selectedColor: _brand,
  backgroundColor: AppColors.fill,
  side: BorderSide.none,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  labelStyle: TextStyle(
    color: selected ? Colors.white : _sub,
    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
    fontSize: 13,
  ),
);

Widget _sectionLabel(String t) => Padding(
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

// ───────────── 하루 기록 ─────────────

class AttendanceEditSheet extends StatefulWidget {
  final DateTime day;
  final AttendanceRecord? existing;
  final AttendanceCalcOptions options;
  const AttendanceEditSheet({
    super.key,
    required this.day,
    this.existing,
    this.options = const AttendanceCalcOptions(),
  });

  @override
  State<AttendanceEditSheet> createState() => _AttendanceEditSheetState();
}

/// 날마다 고르는 휴게(분). null = 설정의 기본 휴게.
const List<int?> _breakChoices = [null, 0, 30, 60, 90, 120];

class _AttendanceEditSheetState extends State<AttendanceEditSheet> {
  late String _type;
  TimeOfDay? _checkIn;
  TimeOfDay? _checkOut;
  int? _breakMin;
  late final TextEditingController _memo;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? kAttendanceNormal;
    if (!kAttendanceTypes.contains(_type)) _type = kAttendanceNormal;
    _checkIn = _parse(e?.checkIn);
    _checkOut = _parse(e?.checkOut);
    _breakMin = e?.breakMin;
    _memo = TextEditingController(text: e?.memo ?? '');
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

  AttendanceRecord _draft() {
    final noTime = hasNoWorkTime(_type);
    final memo = _memo.text.trim();
    return AttendanceRecord(
      date: widget.day,
      type: _type,
      checkIn: noTime ? null : _fmt(_checkIn),
      checkOut: noTime ? null : _fmt(_checkOut),
      breakMin: noTime ? null : _breakMin,
      memo: memo.isEmpty ? null : memo,
    );
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

  Widget _timeBox(String label, TimeOfDay? t, bool isStart) => Expanded(
    child: InkWell(
      key: Key(isStart ? 'att_check_in' : 'att_check_out'),
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

  String _breakChoiceLabel(int? v) {
    if (v == null) {
      return "기본(${defaultBreakLabel(widget.options.defaultBreak)})";
    }
    if (v == 0) return "없음";
    return formatMinutes(v);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.day;
    final hn = holidayName(d);
    final rest = isRestDay(d, widget.options);
    final noTime = hasNoWorkTime(_type);
    final work = noTime ? null : computeDay(_draft(), widget.options);
    final extras = <String>[
      if (work != null && work.dailyOver > 0)
        "연장 ${formatMinutes(work.dailyOver)}",
      if (work != null && work.night > 0) "야간 ${formatMinutes(work.night)}",
      if (work != null && work.holiday > 0) "휴일 ${formatMinutes(work.holiday)}",
    ];

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
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  "${d.month}월 ${d.day}일 (${kWeekdayKo[d.weekday - 1]}) 근태",
                  style: TextStyle(
                    color: rest ? AppColors.danger : _text,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                if (hn.isNotEmpty)
                  Text(
                    hn,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in kAttendanceTypes)
                  attendanceChoice(
                    key: Key('att_type_$t'),
                    label: t,
                    selected: _type == t,
                    onTap: () => setState(() => _type = t),
                  ),
              ],
            ),
            if (!noTime) ...[
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
              const SizedBox(height: 14),
              _sectionLabel("휴게시간"),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final b in _breakChoices)
                    attendanceChoice(
                      key: Key('att_break_${b ?? 'default'}'),
                      label: _breakChoiceLabel(b),
                      selected: _breakMin == b,
                      onTap: () => setState(() => _breakMin = b),
                    ),
                ],
              ),
              if (work != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    [
                      "근로 ${formatMinutes(work.work)}",
                      work.breakMin == 0
                          ? "휴게 없음"
                          : "휴게 ${formatMinutes(work.breakMin)}",
                      "출근~퇴근 ${formatMinutes(work.stay)}",
                      ...extras,
                    ].join(" · "),
                    key: const Key('att_day_result'),
                    style: const TextStyle(
                      color: _brand,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            TextField(
              key: const Key('att_memo'),
              controller: _memo,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: "현장 메모",
                hintText: "예: 태안 3호기, 출장",
                border: OutlineInputBorder(),
                isDense: true,
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.existing != null)
                  TextButton(
                    key: const Key('att_delete'),
                    onPressed: () => Navigator.pop(
                      context,
                      const AttendanceSheetResult.delete(),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    child: const Text("기록 지우기"),
                  ),
                const Spacer(),
                FilledButton(
                  key: const Key('att_save'),
                  onPressed: () => Navigator.pop(
                    context,
                    AttendanceSheetResult.save(_draft()),
                  ),
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

// ───────────── 근태 설정 ─────────────

class AttendanceSettingsSheet extends StatefulWidget {
  final AttendanceSettings settings;
  final DateTime today;

  /// 이번 연차 기간(입사일이 있을 때). 부여 일수 직접 입력 칸에 쓴다.
  final LeaveBalance? balance;
  const AttendanceSettingsSheet({
    super.key,
    required this.settings,
    required this.today,
    this.balance,
  });

  @override
  State<AttendanceSettingsSheet> createState() =>
      _AttendanceSettingsSheetState();
}

class _AttendanceSettingsSheetState extends State<AttendanceSettingsSheet> {
  late AttendanceSettings _s = widget.settings;
  late final TextEditingController _grant;

  String? get _periodKey {
    final b = widget.balance;
    if (b == null || _s.hireDate != widget.settings.hireDate) return null;
    return dateKey(b.periodStart);
  }

  @override
  void initState() {
    super.initState();
    final k = _periodKey;
    final v = k == null ? null : widget.settings.leaveOverrides[k];
    _grant = TextEditingController(text: v == null ? '' : formatLeaveDays(v));
  }

  @override
  void dispose() {
    _grant.dispose();
    super.dispose();
  }

  Future<void> _pickHire() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _s.hireDate ?? widget.today,
      firstDate: DateTime(1970),
      lastDate: DateTime(widget.today.year + 1, 12, 31),
      helpText: "입사일",
    );
    if (d != null && mounted) setState(() => _s = _s.copyWith(hireDate: d));
  }

  void _done() {
    var s = _s;
    final k = _periodKey;
    if (k != null) {
      final m = Map<String, double>.from(s.leaveOverrides);
      final v = double.tryParse(_grant.text.trim().replaceAll(',', '.'));
      if (v == null || v < 0 || v > 60) {
        m.remove(k);
      } else {
        m[k] = v;
      }
      s = s.copyWith(leaveOverrides: m);
    }
    Navigator.pop(context, s);
  }

  Widget _help(String t) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      t,
      style: const TextStyle(color: _sub, fontSize: 12, height: 1.4),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final hire = _s.hireDate;
    final b = widget.balance;
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
              "근태 설정",
              style: TextStyle(
                color: _text,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            _sectionLabel("입사일"),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  hire == null ? "넣지 않음" : dateKey(hire),
                  key: const Key('att_hire_value'),
                  style: TextStyle(
                    color: hire == null ? _sub : _text,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                OutlinedButton(
                  key: const Key('att_hire_pick'),
                  onPressed: _pickHire,
                  child: Text(hire == null ? "입사일 넣기" : "바꾸기"),
                ),
                if (hire != null)
                  TextButton(
                    onPressed: () =>
                        setState(() => _s = _s.copyWith(clearHire: true)),
                    child: const Text("지우기"),
                  ),
              ],
            ),
            _help("연차 잔여를 입사일 기준으로 계산합니다(근로기준법 제60조). 이 폰에만 저장됩니다."),
            if (b != null && _periodKey != null) ...[
              const SizedBox(height: 16),
              _sectionLabel("이번 기간 부여 일수"),
              TextField(
                key: const Key('att_grant'),
                controller: _grant,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: "비우면 법 기준 ${formatLeaveDays(b.lawGranted)}일",
                  suffixText: "일",
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              _help("회사가 회계연도(1월 1일) 기준이거나 연차를 더 준 경우, 회사에서 받은 일수를 넣으십시오."),
            ],
            const SizedBox(height: 18),
            _sectionLabel("기본 휴게시간"),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in const [kBreakLegalAuto, 0, 60])
                  attendanceChoice(
                    key: Key('att_default_break_$v'),
                    label: defaultBreakLabel(v),
                    selected: _s.defaultBreak == v,
                    onTap: () =>
                        setState(() => _s = _s.copyWith(defaultBreak: v)),
                  ),
              ],
            ),
            _help(
              "법정 최소: 출근~퇴근이 4시간 이상이면 30분, 8시간 30분 이상이면 1시간을 뺍니다(제54조). "
              "점심 1시간을 늘 쉬면 1시간을 고르십시오. 날마다 따로 바꿀 수 있습니다.",
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              key: const Key('att_saturday'),
              contentPadding: EdgeInsets.zero,
              value: _s.saturdayIsHoliday,
              activeThumbColor: _brand,
              onChanged: (v) =>
                  setState(() => _s = _s.copyWith(saturdayIsHoliday: v)),
              title: const Text(
                "토요일 근무를 휴일근로로 계산",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                "회사가 토요일을 휴일로 정한 경우만 켜십시오. 보통 토요일은 휴무일이라 연장으로 계산합니다.",
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('att_settings_save'),
                onPressed: _done,
                style: FilledButton.styleFrom(backgroundColor: _brand),
                child: const Text("저장"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
