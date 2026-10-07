// 근태 관리 화면 조각: 달 합계 카드, 연차 잔여 카드, 날짜 목록 줄, 월 달력.
library;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';

import '../../my_schedule/korean_holidays.dart';
import '../../my_work_logs/models/attendance.dart';
import '../attendance_calc.dart';
import '../attendance_clock.dart';
import '../attendance_pay.dart';
import '../attendance_settings.dart';

const Color _text = AppColors.text;
const Color _sub = AppColors.textSub;
const Color _brand = AppColors.brand;
const Color _white = AppColors.surface;

BoxDecoration _card() =>
    BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14));

Widget _tag(String type, {double fontSize = 11}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
  decoration: BoxDecoration(
    color: type == kAttendanceAbsent ? AppColors.danger : _brand,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    type,
    maxLines: 1,
    style: TextStyle(
      color: Colors.white,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
    ),
  ),
);

// ───────────── 출근·퇴근 카드 ─────────────

/// 월 이동 줄 아래에 늘 보이는 한 줄: 지금 시각으로 출근·퇴근을 한 번에 찍는다.
/// 읽지 못했으면(통신 없음·읽기 실패) 단추를 막는다 - 모르는 채로 찍으면 있던 기록을 덮을 수 있다.
class AttendanceClockCard extends StatelessWidget {
  final ClockStatus? status; // null = 아직 읽는 중이거나 읽지 못함
  final bool loadFailed;
  final DateTime today;
  final VoidCallback onPunchIn;
  final VoidCallback onPunchOut;
  final VoidCallback onEdit;
  final VoidCallback onRetry;
  const AttendanceClockCard({
    super.key,
    required this.status,
    required this.loadFailed,
    required this.today,
    required this.onPunchIn,
    required this.onPunchOut,
    required this.onEdit,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final st = status;
    String title;
    String? sub;
    Widget? action;
    if (loadFailed) {
      title = "출퇴근 기록을 읽지 못했습니다";
      sub = "읽은 뒤에 출근·퇴근을 찍을 수 있습니다.";
      action = OutlinedButton(
        key: const Key('att_clock_retry'),
        onPressed: onRetry,
        child: const Text("출퇴근 다시 읽기"),
      );
    } else if (st == null) {
      title = "출퇴근 기록을 읽는 중";
      action = null;
    } else {
      final r = st.record;
      switch (st.phase) {
        case ClockPhase.ready:
          title = "오늘 출근 전";
          sub = st.yesterdayOpen
              ? "어제 퇴근을 안 찍었습니다. 아래 어제 줄을 눌러 적으십시오"
              : "${today.month}월 ${today.day}일 ${kWeekdayKo[today.weekday - 1]}요일";
          action = _clockButton(
            key: const Key('att_clock_in'),
            label: "출근",
            icon: Icons.login_rounded,
            onTap: onPunchIn,
            color: _brand,
          );
        case ClockPhase.working:
          final e = st.elapsedMin ?? 0;
          title = "${r?.checkIn ?? '--:--'} 출근 · 근무 중";
          sub =
              "${formatMinutes(e)} 지났습니다"
              "${st.day == DateTime(today.year, today.month, today.day) ? '' : ' (어제 출근)'}";
          action = _clockButton(
            key: const Key('att_clock_out'),
            label: "퇴근",
            icon: Icons.logout_rounded,
            onTap: onPunchOut,
            color: _text,
          );
        case ClockPhase.done:
          title = "${r?.checkIn ?? '--:--'} ~ ${r?.checkOut ?? '--:--'}";
          sub = "오늘 근무를 마쳤습니다";
          action = TextButton(
            key: const Key('att_clock_edit'),
            onPressed: onEdit,
            child: const Text("고치기"),
          );
        case ClockPhase.off:
          title = "오늘은 ${r?.type ?? ''}입니다";
          sub = "출퇴근을 적지 않는 날입니다";
          action = TextButton(
            key: const Key('att_clock_edit'),
            onPressed: onEdit,
            child: const Text("고치기"),
          );
      }
    }
    return Container(
      key: const Key('att_clock_card'),
      width: double.infinity,
      color: _white,
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  key: const Key('att_clock_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub,
                    key: const Key('att_clock_sub'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _sub, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action],
        ],
      ),
    );
  }

  Widget _clockButton({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) => FilledButton.icon(
    key: key,
    onPressed: onTap,
    icon: Icon(icon, size: 20),
    label: Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
    ),
    style: FilledButton.styleFrom(
      backgroundColor: color,
      minimumSize: const Size(112, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

// ───────────── 달 합계 ─────────────

class AttendanceSummaryCard extends StatelessWidget {
  final DateTime month;
  final MonthSummary summary;
  final AttendanceSettings settings;

  /// 퇴근 시각이 빠진 지난 날 수(0이면 안 보인다).
  final int missingCheckOut;

  /// 연간 보기를 여는 동작(없으면 링크를 안 보인다).
  final VoidCallback? onOpenYear;
  const AttendanceSummaryCard({
    super.key,
    required this.month,
    required this.summary,
    required this.settings,
    this.missingCheckOut = 0,
    this.onOpenYear,
  });

  Widget _stat(String k, String v, {Color color = _text, Key? key}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              k,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _sub, fontSize: 12),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                v,
                key: key,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final counts = s.typeCounts.entries
        .map((e) => "${e.key} ${e.value}회")
        .join(" · ");
    final over = s.weeksOver52;
    final pay = estimateExtraPay(s, settings.hourlyWage);
    final noHolidayTable = month.year > lastHolidayYear;
    final stats = <Widget>[
      _stat("근로시간", formatMinutes(s.work), key: const Key('att_sum_work')),
      _stat("연장", formatMinutes(s.overtime), key: const Key('att_sum_over')),
      _stat("야간", formatMinutes(s.night), key: const Key('att_sum_night')),
      _stat("휴일", formatMinutes(s.holiday), key: const Key('att_sum_holiday')),
      _stat(
        "가산 시간",
        formatMinutes(s.premiumMinutes),
        color: _brand,
        key: const Key('att_sum_premium'),
      ),
      if (settings.calcOptions.hasCompanyOvertime) ...[
        _stat(
          "사규 조출",
          formatMinutes(s.companyEarly),
          color: _brand,
          key: const Key('att_sum_company_early'),
        ),
        _stat(
          "사규 연장",
          formatMinutes(s.companyLate),
          color: _brand,
          key: const Key('att_sum_company_late'),
        ),
      ],
      _stat(
        "연차 사용",
        "${formatLeaveDays(s.leaveUsed)}일",
        key: const Key('att_sum_leave'),
      ),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "${month.month}월 합계",
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              if (onOpenYear != null)
                TextButton(
                  key: const Key('att_open_year'),
                  onPressed: onOpenYear,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text("연간 보기"),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            s.timedDays == 0
                ? "출퇴근 시간을 적으면 근로·연장·야간·휴일 시간을 계산합니다."
                : "출퇴근 시간을 적은 ${s.timedDays}일 기준 · 휴게 ${defaultBreakLabel(settings.defaultBreak)} 차감",
            style: const TextStyle(color: _sub, fontSize: 12),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 300 ? 3 : 2;
              final w = (c.maxWidth - 8 * (cols - 1)) / cols;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final x in stats) SizedBox(width: w, child: x)],
              );
            },
          ),
          if (pay != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "예상 수당 약 ${formatWon(pay.total)}",
                    key: const Key('att_sum_pay'),
                    style: const TextStyle(
                      color: _brand,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    "연장 ${formatWon(pay.overtime)} · 야간 ${formatWon(pay.night)} · 휴일 ${formatWon(pay.holiday)}",
                    key: const Key('att_sum_pay_detail'),
                    style: const TextStyle(color: _text, fontSize: 12),
                  ),
                  Text(
                    "통상시급 ${formatWon(pay.wage)} 기준(연장 1.5배·야간 0.5배·휴일 1.5배, 8시간 넘는 휴일 2배). "
                    "참고용이며 회사 급여 기준과 다를 수 있습니다.",
                    style: const TextStyle(
                      color: _sub,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (counts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              counts,
              key: const Key('att_sum_counts'),
              style: const TextStyle(
                color: _text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (missingCheckOut > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "퇴근 시각을 안 적은 날이 $missingCheckOut일 있습니다. 그 날은 근로시간에 들어가지 않습니다.",
                key: const Key('att_sum_missing_out'),
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          for (final w in over)
            Container(
              key: Key('att_over52_${dateKey(w.monday)}'),
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    AppIcons.warning,
                    size: 16,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "${w.monday.month}월 ${w.monday.day}일 주: 근로 ${formatMinutes(w.work)}, "
                      "연장 ${formatMinutes(w.limitOver)}. 1주 연장 12시간(주 52시간)을 초과합니다(제53조).",
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (noHolidayTable)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "이 해의 공휴일 표가 없어 일요일만 휴일로 계산합니다.",
                style: TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            "휴일은 일요일·공휴일${settings.saturdayIsHoliday ? '·토요일' : ''}입니다. "
            "가산 시간은 연장·야간·휴일 50%, 휴일 8시간 초과 100%로 계산합니다(제56조). "
            "5명 미만 사업장은 가산·52시간·연차 조항이 적용되지 않습니다.",
            style: const TextStyle(color: _sub, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ───────────── 연차 잔여 ─────────────

class AttendanceLeaveCard extends StatelessWidget {
  final LeaveBalance? balance;
  final bool hasHireDate;
  final VoidCallback onOpenSettings;

  /// 연차 사용 내역을 여는 동작(없으면 단추를 안 보인다).
  final VoidCallback? onOpenHistory;
  const AttendanceLeaveCard({
    super.key,
    required this.balance,
    required this.hasHireDate,
    required this.onOpenSettings,
    this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    final b = balance;
    if (!hasHireDate || b == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: _card(),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasHireDate
                    ? "입사일이 오늘 뒤로 되어 있습니다. 설정에서 입사일을 확인하십시오."
                    : "입사일을 넣으면 연차 잔여를 계산합니다.",
                style: const TextStyle(color: _sub, fontSize: 13),
              ),
            ),
            TextButton(
              key: const Key('att_leave_setup'),
              onPressed: onOpenSettings,
              child: const Text("입사일 넣기"),
            ),
          ],
        ),
      );
    }
    final endInclusive = DateTime(
      b.periodEnd.year,
      b.periodEnd.month,
      b.periodEnd.day - 1,
    );
    final negative = b.remaining < 0;
    return InkWell(
      onTap: onOpenSettings,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.all(14),
        decoration: _card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "연차 잔여",
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  "${formatLeaveDays(b.remaining)}일",
                  key: const Key('att_leave_remaining'),
                  style: TextStyle(
                    color: negative ? AppColors.danger : _brand,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "발생 ${formatLeaveDays(b.granted)}일 · 사용 ${formatLeaveDays(b.used)}일"
              "${b.planned > 0 ? ' · 예정 ${formatLeaveDays(b.planned)}일' : ''}",
              key: const Key('att_leave_detail'),
              style: const TextStyle(
                color: _text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              "기간 ${dateKey(b.periodStart)} ~ ${dateKey(endInclusive)}",
              style: const TextStyle(color: _sub, fontSize: 12),
            ),
            Text(
              b.overrideGranted != null
                  ? "회사 부여 ${formatLeaveDays(b.overrideGranted!)}일로 계산합니다(법 기준 ${formatLeaveDays(b.lawGranted)}일)."
                  : b.basis,
              style: const TextStyle(color: _sub, fontSize: 12),
            ),
            if (b.nextAccrual != null)
              Text(
                "다음 1일 발생: ${b.nextAccrual!.month}월 ${b.nextAccrual!.day}일(그 달에 결근이 없을 때)",
                style: const TextStyle(color: _sub, fontSize: 12),
              ),
            if (b.years == 0)
              const Text(
                "1년 미만에 생긴 연차는 입사 1년이 되는 날 없어집니다(제60조 제7항).",
                style: TextStyle(color: _sub, fontSize: 12),
              ),
            if (negative)
              const Text(
                "쓴 연차가 발생보다 많습니다. 회사 부여 일수를 설정에서 확인하십시오.",
                style: TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            if (onOpenHistory != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('att_leave_history'),
                  onPressed: onOpenHistory,
                  child: const Text("사용 내역 보기"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────── 날짜 목록 줄 ─────────────

class AttendanceDayRow extends StatelessWidget {
  final DateTime day;
  final AttendanceRecord? record;
  final DayWork? work;
  final bool isToday;
  final bool isRest;
  final VoidCallback onTap;

  /// 출근만 있고 퇴근을 안 적은 지난 날("퇴근 입력 필요"를 붙인다).
  final bool missingCheckOut;
  const AttendanceDayRow({
    super.key,
    required this.day,
    required this.record,
    required this.work,
    required this.isToday,
    required this.isRest,
    required this.onTap,
    this.missingCheckOut = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = record;
    final type = r?.type ?? kAttendanceNormal;
    final hn = holidayName(day);
    final note = [
      if (hn.isNotEmpty) hn,
      if (hn.isEmpty && isBridgeDay(day)) '퐁당일',
      if (r?.memo != null) r!.memo!,
    ];
    final hasTime = r?.checkIn != null || r?.checkOut != null;
    final w = work;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(12),
          border: isToday ? Border.all(color: _brand, width: 1.4) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  "${day.day}일 (${kWeekdayKo[day.weekday - 1]})",
                  style: TextStyle(
                    color: isRest ? AppColors.danger : _text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (type != kAttendanceNormal || note.isNotEmpty)
                    Row(
                      children: [
                        if (type != kAttendanceNormal) ...[
                          _tag(type),
                          const SizedBox(width: 6),
                        ],
                        if (note.isNotEmpty)
                          Flexible(
                            child: Text(
                              note.join(" · "),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: hn.isNotEmpty && r?.memo == null
                                    ? AppColors.danger
                                    : _sub,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  if (hasTime)
                    Padding(
                      padding: EdgeInsets.only(
                        top: type != kAttendanceNormal || note.isNotEmpty
                            ? 3
                            : 0,
                      ),
                      child: Text(
                        "${r?.checkIn ?? '--:--'} ~ ${r?.checkOut ?? '--:--'}"
                        "${w == null ? '' : ' · 근로 ${formatMinutes(w.work)}'}"
                        "${missingCheckOut ? ' · 퇴근 입력 필요' : ''}",
                        key: missingCheckOut
                            ? Key('att_missing_out_${dateKey(day)}')
                            : null,
                        maxLines: 2,
                        style: TextStyle(
                          color: missingCheckOut ? AppColors.danger : _sub,
                          fontSize: 12,
                          fontWeight: missingCheckOut
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(AppIcons.forward, size: 18, color: _sub),
          ],
        ),
      ),
    );
  }
}

// ───────────── 월 달력 ─────────────

class AttendanceMonthCalendar extends StatelessWidget {
  final DateTime month;
  final DateTime today;
  final Map<String, AttendanceRecord> records;
  final Map<String, DayWork?> works;
  final AttendanceCalcOptions options;
  final ValueChanged<DateTime> onTapDay;
  const AttendanceMonthCalendar({
    super.key,
    required this.month,
    required this.today,
    required this.records,
    required this.works,
    required this.options,
    required this.onTapDay,
  });

  static const _heads = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday % 7; // 일요일 = 0
    final cells = lead + days;
    final rows = (cells / 7).ceil();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      decoration: _card(),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      _heads[i],
                      style: TextStyle(
                        color: i == 0 ? AppColors.danger : _sub,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var row = 0; row < rows; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(child: _cell(row * 7 + col - lead + 1, days)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(int dayNo, int days) {
    if (dayNo < 1 || dayNo > days) return const SizedBox(height: 58);
    final d = DateTime(month.year, month.month, dayNo);
    final key = dateKey(d);
    final r = records[key];
    final w = works[key];
    final rest = isRestDay(d, options);
    final isToday = d == today;
    final type = r?.type ?? kAttendanceNormal;
    String? hours;
    if (w != null) {
      final h = w.work / 60;
      hours = h == h.roundToDouble()
          ? "${h.toInt()}시간"
          : "${h.toStringAsFixed(1)}시간";
    }
    return InkWell(
      key: Key('att_cal_$key'),
      onTap: () => onTapDay(d),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 58,
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        decoration: BoxDecoration(
          color: type != kAttendanceNormal
              ? AppColors.brandSoft
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isToday ? Border.all(color: _brand, width: 1.4) : null,
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "$dayNo",
                style: TextStyle(
                  color: rest ? AppColors.danger : _text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            if (type != kAttendanceNormal)
              FittedBox(fit: BoxFit.scaleDown, child: _tag(type, fontSize: 10))
            else if (hours != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  hours,
                  style: const TextStyle(
                    color: _sub,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
