// 근태 설정(입사일·기본 휴게·토요일 휴일·연차 부여 일수 직접 입력·보기 방식).
// 폰(SharedPreferences)에만 저장한다: 폰을 바꾸면 다시 넣어야 한다(docs/근태관리_근거.md 7절).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../my_work_logs/models/attendance.dart';
import 'attendance_calc.dart';

class AttendanceSettings {
  static const String hireKey = 'attendance_hire_date';
  static const String breakKey = 'attendance_default_break';
  static const String saturdayKey = 'attendance_saturday_holiday';
  static const String overrideKey = 'attendance_leave_override';
  static const String viewKey = 'attendance_view_calendar';

  final DateTime? hireDate;
  final int defaultBreak;
  final bool saturdayIsHoliday;

  /// 연차 기간 시작(yyyy-MM-dd) → 회사가 준 부여 일수.
  final Map<String, double> leaveOverrides;
  final bool calendarView;

  const AttendanceSettings({
    this.hireDate,
    this.defaultBreak = kBreakLegalAuto,
    this.saturdayIsHoliday = false,
    this.leaveOverrides = const {},
    this.calendarView = false,
  });

  AttendanceCalcOptions get calcOptions => AttendanceCalcOptions(
    defaultBreak: defaultBreak,
    saturdayIsHoliday: saturdayIsHoliday,
  );

  AttendanceSettings copyWith({
    DateTime? hireDate,
    bool clearHire = false,
    int? defaultBreak,
    bool? saturdayIsHoliday,
    Map<String, double>? leaveOverrides,
    bool? calendarView,
  }) => AttendanceSettings(
    hireDate: clearHire ? null : (hireDate ?? this.hireDate),
    defaultBreak: defaultBreak ?? this.defaultBreak,
    saturdayIsHoliday: saturdayIsHoliday ?? this.saturdayIsHoliday,
    leaveOverrides: leaveOverrides ?? this.leaveOverrides,
    calendarView: calendarView ?? this.calendarView,
  );

  static Future<AttendanceSettings> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final overrides = <String, double>{};
      final raw = p.getString(overrideKey);
      if (raw != null) {
        try {
          final m = jsonDecode(raw);
          if (m is Map) {
            m.forEach((k, v) {
              if (v is num) overrides[k.toString()] = v.toDouble();
            });
          }
        } catch (_) {}
      }
      final b = p.getInt(breakKey) ?? kBreakLegalAuto;
      return AttendanceSettings(
        hireDate: DateTime.tryParse(p.getString(hireKey) ?? ''),
        defaultBreak: (b == kBreakLegalAuto || (b >= 0 && b <= 240))
            ? b
            : kBreakLegalAuto,
        saturdayIsHoliday: p.getBool(saturdayKey) ?? false,
        leaveOverrides: overrides,
        calendarView: p.getBool(viewKey) ?? false,
      );
    } catch (_) {
      return const AttendanceSettings();
    }
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (hireDate == null) {
        await p.remove(hireKey);
      } else {
        await p.setString(hireKey, dateKey(hireDate!));
      }
      await p.setInt(breakKey, defaultBreak);
      await p.setBool(saturdayKey, saturdayIsHoliday);
      await p.setString(overrideKey, jsonEncode(leaveOverrides));
      await p.setBool(viewKey, calendarView);
    } catch (_) {}
  }
}

/// 기본 휴게 설정 이름.
String defaultBreakLabel(int v) {
  if (v == kBreakLegalAuto) return '법정 최소';
  if (v == 0) return '없음';
  return formatMinutes(v);
}
