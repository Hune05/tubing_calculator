// 연차 사용 내역 아래 창: 이번 연차 기간에 쓴 날과 예정인 날, 남은 일수.
library;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';

import '../../my_work_logs/models/attendance.dart';
import '../attendance_calc.dart';
import '../attendance_leave_history.dart';

const Color _text = AppColors.text;
const Color _sub = AppColors.textSub;
const Color _brand = AppColors.brand;

class AttendanceLeaveSheet extends StatelessWidget {
  final LeaveBalance balance;
  final Map<String, String> types;
  final DateTime today;
  const AttendanceLeaveSheet({
    super.key,
    required this.balance,
    required this.types,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final b = balance;
    final entries = leaveHistory(
      types: types,
      periodStart: b.periodStart,
      periodEnd: b.periodEnd,
      today: today,
    );
    final left = daysUntilPeriodEnd(b.periodEnd, today);
    final last = DateTime(
      b.periodEnd.year,
      b.periodEnd.month,
      b.periodEnd.day - 1,
    );
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "연차 사용 내역",
                style: TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${dateKey(b.periodStart)} ~ ${dateKey(last)}",
                style: const TextStyle(color: _sub, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "발생 ${formatLeaveDays(b.granted)}일 · 사용 ${formatLeaveDays(b.used)}일"
                      "${b.planned > 0 ? ' · 예정 ${formatLeaveDays(b.planned)}일' : ''}"
                      " · 남음 ${formatLeaveDays(b.remaining)}일",
                      key: const Key('att_leave_sheet_sum'),
                      style: const TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      left == 0
                          ? "이 연차 기간의 마지막 날입니다."
                          : "이 연차 기간이 끝나는 날까지 $left일 남았습니다.",
                      key: const Key('att_leave_sheet_left'),
                      style: const TextStyle(color: _sub, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      "이 기간에 쓴 연차가 없습니다.",
                      key: Key('att_leave_sheet_empty'),
                      style: TextStyle(color: _sub, fontSize: 13),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.fill),
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      final rest = b.granted - e.usedAfter;
                      return Padding(
                        key: Key('att_leave_row_${dateKey(e.date)}'),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 92,
                              child: Text(
                                "${e.date.month}월 ${e.date.day}일 (${kWeekdayKo[e.date.weekday - 1]})",
                                style: const TextStyle(
                                  color: _text,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                "${e.type} ${formatLeaveDays(e.days)}일"
                                "${e.planned ? ' · 예정' : ''}",
                                style: TextStyle(
                                  color: e.planned ? _sub : _text,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              "남음 ${formatLeaveDays(rest)}일",
                              style: TextStyle(
                                color: rest < 0 ? AppColors.danger : _brand,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 4),
              const Text(
                "남은 일수는 이 기간에 쓴 날과 적어 둔 예정을 모두 뺀 값입니다. 이월·보상은 회사 규정을 따릅니다.",
                style: TextStyle(color: _sub, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
