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

  /// 이 날 앞쪽에서 가장 가까이 적은 기록("같게" 단추에 쓴다). 없으면 단추를 안 보인다.
  final AttendanceRecord? previous;
  const AttendanceEditSheet({
    super.key,
    required this.day,
    this.existing,
    this.options = const AttendanceCalcOptions(),
    this.previous,
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
    // 새 기록이면 사규의 소정 출근·퇴근 시각으로 미리 채운다(고칠 수 있다).
    _checkIn = _parse(
      e?.checkIn ?? (e == null ? widget.options.workStart : null),
    );
    _checkOut = _parse(
      e?.checkOut ?? (e == null ? widget.options.workEnd : null),
    );
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

  /// 전에 적은 기록의 종류·시간·휴게·메모를 이 날에 가져온다(저장은 따로 누른다).
  void _copyPrevious() {
    final p = widget.previous;
    if (p == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _type = kAttendanceTypes.contains(p.type) ? p.type : kAttendanceNormal;
      _checkIn = _parse(p.checkIn);
      _checkOut = _parse(p.checkOut);
      _breakMin = p.breakMin;
      _memo.text = p.memo ?? '';
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

  /// 사규 인정 조출·연장 한 줄(1시간 단위로 내림, 버린 끝수도 알려 준다). 없으면 null.
  String? _companyLine() {
    if (hasNoWorkTime(_type)) return null;
    final c = companyOvertime(_draft(), widget.options);
    if (c == null) return null;
    String part(String label, int v, int drop) {
      final base = "$label ${formatMinutes(v)}";
      return drop > 0 ? "$base (${formatMinutes(drop)} 버림)" : base;
    }

    return "사규 인정: ${part('조출', c.early, c.earlyDrop)} · ${part('연장', c.late, c.lateDrop)}";
  }

  /// 사규 소정 시각과 비교한 한 줄: "사규 소정 08:00~17:00 · 출근 12분 늦음". 소정 시각이 없으면 null.
  String? _scheduleHint() {
    final ws = widget.options.workStart;
    final we = widget.options.workEnd;
    final sm = minutesOfDay(ws);
    final em = minutesOfDay(we);
    if (sm == null && em == null) return null;
    final parts = <String>["사규 소정 ${ws ?? '--:--'}~${we ?? '--:--'}"];
    final ci = _checkIn == null ? null : _checkIn!.hour * 60 + _checkIn!.minute;
    final co = _checkOut == null
        ? null
        : _checkOut!.hour * 60 + _checkOut!.minute;
    if (sm != null && ci != null && ci > sm) {
      parts.add("출근 ${formatMinutes(ci - sm)} 늦음");
    }
    if (em != null &&
        co != null &&
        sm != null &&
        em > sm &&
        co >= sm &&
        co < em) {
      parts.add("퇴근 ${formatMinutes(em - co)} 일찍");
    }
    return parts.join(" · ");
  }

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
                if (hn.isEmpty && isBridgeDay(d))
                  const Text(
                    "퐁당일",
                    style: TextStyle(
                      color: _sub,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
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
            if (widget.previous != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('att_copy_prev'),
                onPressed: _copyPrevious,
                icon: const Icon(Icons.content_copy_rounded, size: 16),
                label: Text(
                  "${widget.previous!.date.month}월 ${widget.previous!.date.day}일 기록과 같게",
                ),
              ),
            ],
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
            if (isBridgeDay(d) && holidayName(d).isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                "퐁당일입니다(앞뒤가 쉬는 날). 회사에서 연차로 쉬게 하는 날이면 '연차'를 고르십시오.",
                key: Key('att_bridge_hint'),
                style: TextStyle(color: _sub, fontSize: 12, height: 1.4),
              ),
            ],
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
              if (_scheduleHint() != null) ...[
                const SizedBox(height: 6),
                Text(
                  _scheduleHint()!,
                  key: const Key('att_schedule_hint'),
                  style: const TextStyle(
                    color: _sub,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
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
              if (_companyLine() != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _companyLine()!,
                    key: const Key('att_company_ot'),
                    style: const TextStyle(
                      color: _sub,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
  late final TextEditingController _ruleNote;
  late final TextEditingController _wage;

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
    _ruleNote = TextEditingController(text: widget.settings.ruleNote);
    _wage = TextEditingController(
      text: widget.settings.hourlyWage?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _grant.dispose();
    _ruleNote.dispose();
    _wage.dispose();
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

  Future<void> _pickRuleTime({required bool isStart}) async {
    final cur = minutesOfDay(isStart ? _s.workStart : _s.workEnd);
    final picked = await showMakitaTimePicker(
      context: context,
      title: isStart ? "소정 출근 시간" : "소정 퇴근 시간",
      initialTime: cur == null
          ? TimeOfDay(hour: isStart ? 8 : 17, minute: 0)
          : TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
    );
    if (picked == null || !mounted) return;
    final v =
        "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
    setState(
      () => _s = isStart ? _s.copyWith(workStart: v) : _s.copyWith(workEnd: v),
    );
  }

  Widget _ruleTimeBox({
    required String key,
    required String label,
    required String? value,
    required bool isStart,
  }) => Expanded(
    child: OutlinedButton(
      key: Key(key),
      onPressed: () => _pickRuleTime(isStart: isStart),
      child: Text(
        value == null ? "$label 정하지 않음" : "$label $value",
        style: TextStyle(
          color: value == null ? _sub : _text,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

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
    // 통상시급: 숫자만 읽는다. 비우거나 0이면 끈다(예상 수당이 안 보인다).
    final wage = int.tryParse(_wage.text.trim().replaceAll(',', ''));
    s = (wage == null || wage <= 0)
        ? s.copyWith(clearWage: true)
        : s.copyWith(hourlyWage: wage);
    Navigator.pop(context, s.copyWith(ruleNote: _ruleNote.text.trim()));
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
            _help(
              "연차 잔여를 입사일 기준으로 계산합니다(근로기준법 제60조). 구글 계정을 연결해 두면 다른 기기에도 같은 설정이 됩니다.",
            ),
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
            const SizedBox(height: 18),
            _sectionLabel("사규"),
            Row(
              children: [
                _ruleTimeBox(
                  key: 'att_rule_start',
                  label: "출근",
                  value: _s.workStart,
                  isStart: true,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text("~", style: TextStyle(color: _sub)),
                ),
                _ruleTimeBox(
                  key: 'att_rule_end',
                  label: "퇴근",
                  value: _s.workEnd,
                  isStart: false,
                ),
              ],
            ),
            if (_s.workStart != null || _s.workEnd != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('att_rule_time_clear'),
                  onPressed: () => setState(
                    () => _s = _s.copyWith(
                      clearWorkStart: true,
                      clearWorkEnd: true,
                    ),
                  ),
                  child: const Text("소정 시간 지우기"),
                ),
              ),
            _help(
              "회사가 정한 출근·퇴근 시간입니다. 새 기록을 열 때 이 시간으로 미리 채우고, 늦은 출근·이른 퇴근을 알려 줍니다. "
              "출근·퇴근을 다 넣으면 소정 출근 전(조출)과 소정 퇴근 후(연장)를 1시간 단위로 내려서(나머지는 버림) "
              "'사규 인정' 시간으로 따로 보여 줍니다. 평일만 세고, 법정 연장·야간·휴일 계산과는 별개입니다.",
            ),
            SwitchListTile(
              key: const Key('att_clockout_reminder'),
              contentPadding: EdgeInsets.zero,
              value: _s.clockOutReminder,
              activeThumbColor: _brand,
              onChanged: _s.workEnd == null
                  ? null
                  : (v) =>
                        setState(() => _s = _s.copyWith(clockOutReminder: v)),
              title: const Text(
                "퇴근 안 찍으면 알림",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _s.workEnd == null
                    ? "소정 퇴근 시간을 넣으면 쓸 수 있습니다."
                    : "출근만 찍고 소정 퇴근 시각 30분 뒤에도 퇴근이 없으면 폰이 알려 줍니다.",
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('att_rule_note'),
              controller: _ruleNote,
              maxLines: 5,
              minLines: 3,
              maxLength: AttendanceSettings.ruleNoteMax,
              decoration: const InputDecoration(
                labelText: "사규 메모",
                hintText: "예: 퐁당일은 연차 소진 / 지각 기준 / 조퇴 처리 …",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            _help(
              "조항이나 내용을 적어 두면 근태 화면의 사규 보기(책 아이콘)에서 다시 볼 수 있습니다. 계산에는 쓰지 않습니다.",
            ),
            const SizedBox(height: 18),
            _sectionLabel("통상시급(선택)"),
            TextField(
              key: const Key('att_wage'),
              controller: _wage,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "비우면 예상 수당을 안 보입니다",
                suffixText: "원",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            _help(
              "넣으면 한 달 합계에 연장·야간·휴일 예상 수당을 보여 줍니다(참고용). "
              "급여 정보라 이 기기에만 저장하고 서버에는 올리지 않습니다.",
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

// ───────────── 사규 보기 ─────────────

/// 설정에 넣은 사규(소정 출근·퇴근 시각, 사규 메모)를 읽기만 하는 창.
class AttendanceRulesSheet extends StatelessWidget {
  final AttendanceSettings settings;
  final VoidCallback onOpenSettings;
  const AttendanceRulesSheet({
    super.key,
    required this.settings,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final hasTime = s.workStart != null || s.workEnd != null;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          key: const Key('att_rules_sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "사규",
              style: TextStyle(
                color: _text,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 14),
            if (!s.hasRules)
              const Text(
                "넣어 둔 사규가 없습니다. 설정에서 소정 출근·퇴근 시간과 사규 메모를 넣을 수 있습니다.",
                style: TextStyle(color: _sub, fontSize: 13, height: 1.4),
              ),
            if (hasTime) ...[
              _sectionLabel("소정 근무시간"),
              Text(
                "${s.workStart ?? '--:--'} ~ ${s.workEnd ?? '--:--'}",
                key: const Key('att_rules_time'),
                style: const TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (s.ruleNote.trim().isNotEmpty) ...[
              _sectionLabel("사규 메모"),
              SelectableText(
                s.ruleNote,
                key: const Key('att_rules_note'),
                style: const TextStyle(color: _text, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              "연차는 입사일 기준으로 계산합니다. 회사가 퐁당일을 연차로 쉬게 하면 그날 근태를 '연차'로 기록하십시오.",
              style: TextStyle(color: _sub, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('att_rules_edit'),
                onPressed: onOpenSettings,
                child: const Text("설정에서 고치기"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
