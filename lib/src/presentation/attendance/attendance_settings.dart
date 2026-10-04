// 근태 설정(입사일·기본 휴게·토요일 휴일·연차 부여 일수 직접 입력·보기 방식·사규).
// 폰(SharedPreferences)에 저장하고, 계산기 설정과 같은 서버 문서(settings_cloud.dart)에도 올린다:
// 구글 계정을 연결해 두면 폰을 바꾸거나 태블릿을 써도 같은 설정이 된다(docs/근태관리_근거.md 11절).
// 보기 방식(달력·목록)은 기기마다 다르게 둔다.
//
// 사규(2026-09-29): 회사 지정 휴일, 소정 출근·퇴근 시각, 사규 메모. 기본값은 모두 "없음"이라
// 넣지 않으면 계산 결과가 예전과 똑같다.
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
  static const String workStartKey = 'attendance_work_start';
  static const String workEndKey = 'attendance_work_end';
  static const String ruleNoteKey = 'attendance_rule_note';

  /// 사규 메모 최대 글자 수.
  static const int ruleNoteMax = 2000;

  final DateTime? hireDate;
  final int defaultBreak;
  final bool saturdayIsHoliday;

  /// 연차 기간 시작(yyyy-MM-dd) → 회사가 준 부여 일수.
  final Map<String, double> leaveOverrides;
  final bool calendarView;

  /// 회사 지정 휴일: 날짜(yyyy-MM-dd) → 이름.

  /// 소정 출근·퇴근 시각("HH:mm"), 없으면 null.
  final String? workStart;
  final String? workEnd;

  /// 사규 메모(조항 번호·내용). 계산에는 쓰지 않고 찾아보는 용도.
  final String ruleNote;

  const AttendanceSettings({
    this.hireDate,
    this.defaultBreak = kBreakLegalAuto,
    this.saturdayIsHoliday = false,
    this.leaveOverrides = const {},
    this.calendarView = false,
    this.workStart,
    this.workEnd,
    this.ruleNote = '',
  });

  AttendanceCalcOptions get calcOptions => AttendanceCalcOptions(
    defaultBreak: defaultBreak,
    saturdayIsHoliday: saturdayIsHoliday,
    workStart: workStart,
    workEnd: workEnd,
  );

  /// 사규를 하나라도 넣었는지(사규 보기 창의 빈 상태 판단).
  bool get hasRules =>
      workStart != null || workEnd != null || ruleNote.trim().isNotEmpty;

  AttendanceSettings copyWith({
    DateTime? hireDate,
    bool clearHire = false,
    int? defaultBreak,
    bool? saturdayIsHoliday,
    Map<String, double>? leaveOverrides,
    bool? calendarView,
    String? workStart,
    bool clearWorkStart = false,
    String? workEnd,
    bool clearWorkEnd = false,
    String? ruleNote,
  }) => AttendanceSettings(
    hireDate: clearHire ? null : (hireDate ?? this.hireDate),
    defaultBreak: defaultBreak ?? this.defaultBreak,
    saturdayIsHoliday: saturdayIsHoliday ?? this.saturdayIsHoliday,
    leaveOverrides: leaveOverrides ?? this.leaveOverrides,
    calendarView: calendarView ?? this.calendarView,
    workStart: clearWorkStart ? null : (workStart ?? this.workStart),
    workEnd: clearWorkEnd ? null : (workEnd ?? this.workEnd),
    ruleNote: ruleNote ?? this.ruleNote,
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
        workStart: _validTime(p.getString(workStartKey)),
        workEnd: _validTime(p.getString(workEndKey)),
        ruleNote: p.getString(ruleNoteKey) ?? '',
      );
    } catch (_) {
      return const AttendanceSettings();
    }
  }

  static String? _validTime(String? v) => minutesOfDay(v) == null ? null : v;

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      // 비운 값은 지우지 않고 빈 글자로 둔다(서버로 올려 다른 기기에서도 비워지게).
      await p.setString(hireKey, hireDate == null ? '' : dateKey(hireDate!));
      await p.setInt(breakKey, defaultBreak);
      await p.setBool(saturdayKey, saturdayIsHoliday);
      await p.setString(overrideKey, jsonEncode(leaveOverrides));
      await p.setBool(viewKey, calendarView);
      await p.setString(workStartKey, workStart ?? '');
      await p.setString(workEndKey, workEnd ?? '');
      await p.setString(ruleNoteKey, ruleNote);
    } catch (_) {}
  }
}

/// 기본 휴게 설정 이름.
String defaultBreakLabel(int v) {
  if (v == kBreakLegalAuto) return '법정 최소';
  if (v == 0) return '없음';
  return formatMinutes(v);
}
