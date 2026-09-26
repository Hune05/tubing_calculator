// 근태(연차·월차·반차·조퇴·특근) - 프로젝트와 무관하게 "사람" 기준으로 따로 관리하고,
// 공수(인·일) 계산에는 날짜만 맞춰 연동한다(필드 헬퍼 4번).
//
// 처음에는 작업 일지 화면 안에 근태 칸을 넣었었다. 그런데 근태(특히 연차·월차)는
// 일지를 아예 쓰지 않는 날도 있어야 하고, 여러 프로젝트에 걸쳐 사람 한 명 기준으로
// 하루에 하나만 있으면 된다 - 그래서 별도의 "근태 관리" 화면(attendance_page.dart)에서
// 날짜별로 기록하고, 공수를 계산하는 쪽(project_phase.dart 등)에서는 보고서의 날짜
// (dateISO)로 그 날 근태를 찾아와 반영한다. 연동은 날짜로만 하고 프로젝트는 안 본다.
//
// 2026-09-26 점검(docs/근태관리_근거.md): 반반차·결근 종류, 휴게(breakMin)·현장 메모(memo)
// 칸을 더했다. 예전 기록에는 이 칸이 없으니 모두 비어 있는 것으로 읽는다. 저장·지우기는
// 서버 응답을 기다리지 않는다(통신 없는 현장에서 창이 멈추던 문제).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tubing_calculator/src/core/utils/send_quietly.dart';
import 'package:tubing_calculator/src/data/ownership.dart';

/// "정상근무"는 화면 목록·요약에 따로 표시하지 않는다(대부분의 날이라 강조할
/// 필요가 없다 - 표시가 있으면 오히려 눈에 덜 띈다).
const String kAttendanceNormal = '정상근무';

/// 결근(출근율·개근 판단에 들어간다). 공수는 0.
const String kAttendanceAbsent = '결근';

const List<String> kAttendanceTypes = [
  kAttendanceNormal,
  '연차',
  '월차',
  '반차',
  '반반차',
  '조퇴',
  '특근',
  kAttendanceAbsent,
];

/// 하루 종일 쉬는 근태(출퇴근 시간이 뜻이 없다 - 입력 칸을 감춘다).
bool isFullDayLeave(String type) => type == '연차' || type == '월차';

/// 일을 안 한 날(출퇴근 칸을 감춘다): 연차·월차·결근.
bool hasNoWorkTime(String type) =>
    isFullDayLeave(type) || type == kAttendanceAbsent;

/// 이 근태가 연차에서 빠지는 일수: 연차·월차 1, 반차 0.5, 반반차 0.25, 나머지 0.
/// 월차는 2004년에 없어진 제도라, 지금 "월차"는 보통 1년 미만 근로자의 월 1일 연차
/// (근로기준법 제60조 제2항)다 - 그래서 연차와 같이 뺀다.
double leaveDaysOf(String type) {
  switch (type) {
    case '연차':
    case '월차':
      return 1;
    case '반차':
      return 0.5;
    case '반반차':
      return 0.25;
  }
  return 0;
}

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class AttendanceRecord {
  final DateTime date;
  final String type;
  final String? checkIn; // "HH:mm"
  final String? checkOut;

  /// 이 날의 휴게시간(분). null이면 근태 설정의 기본 휴게를 쓴다(예전 기록도 null).
  final int? breakMin;

  /// 현장·출장 메모(예: "태안 3호기"). 없으면 null.
  final String? memo;

  const AttendanceRecord({
    required this.date,
    this.type = kAttendanceNormal,
    this.checkIn,
    this.checkOut,
    this.breakMin,
    this.memo,
  });

  /// 출근~퇴근 사이 시간(휴게를 빼지 않은 값). 근로시간은 attendance_calc.dart.
  double? get workedHours => workedHoursOf(checkIn, checkOut);

  Map<String, dynamic> toJson() => {
    'date': dateKey(date),
    'type': type,
    'checkIn': checkIn,
    'checkOut': checkOut,
    if (breakMin != null) 'breakMin': breakMin,
    if (memo != null && memo!.trim().isNotEmpty) 'memo': memo!.trim(),
  };

  static AttendanceRecord fromJson(Map<String, dynamic> j, DateTime date) =>
      AttendanceRecord(
        date: date,
        type: j['type']?.toString() ?? kAttendanceNormal,
        checkIn: j['checkIn']?.toString(),
        checkOut: j['checkOut']?.toString(),
        breakMin: (j['breakMin'] as num?)?.toInt(),
        memo: (j['memo']?.toString().trim().isEmpty ?? true)
            ? null
            : j['memo'].toString().trim(),
      );
}

/// 로그인한 사람의 근태를 날짜별로 담아 두는 메모리 캐시. 공수 계산 함수들은
/// 매번 서버를 읽지 않고 이 캐시를 본다 - 서버 상태는 WorkProjectRepository.pendingWrites와
/// 같은 방식(정적 캐시 + 새로고침)으로 관리한다.
class AttendanceCache {
  static Map<String, String> byDate = {};

  /// 로그인한 사람의 근태 기록을 전부 읽어 캐시를 채운다. 통신이 안 되면 폰에
  /// 남아 있는 사본으로 채우고, 그것도 안 되거나 로그인을 안 했으면 그대로 둔다.
  static Future<void> refresh() async {
    final uid = currentUid();
    if (uid == null) return;
    final q = _collection().where('uid', isEqualTo: uid);
    final snap = await _getWithCacheFallback(q);
    if (snap == null) return;
    final map = <String, String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final date = data['date']?.toString();
      final type = data['type']?.toString();
      if (date != null && type != null) map[date] = type;
    }
    byDate = map;
  }
}

CollectionReference<Map<String, dynamic>> _collection() =>
    FirebaseFirestore.instance.collection('attendance_records');

/// 서버에서 읽되, 6초 안에 안 오거나 실패하면 폰에 남아 있는 사본(아직 안 올라간
/// 저장 포함)을 읽는다. 둘 다 안 되면 null.
Future<QuerySnapshot<Map<String, dynamic>>?> _getWithCacheFallback(
  Query<Map<String, dynamic>> q,
) async {
  try {
    return await q.get().timeout(const Duration(seconds: 6));
  } catch (_) {}
  try {
    return await q
        .get(const GetOptions(source: Source.cache))
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    return null;
  }
}

/// 문서 아이디: "{uid}__{yyyy-MM-dd}" - 서버 규칙에서 이 uid가 나뿐인지 확인한다.
String _docId(DateTime d, String uid) => '${uid}__${dateKey(d)}';

/// 하루치 근태를 저장한다. 로그인하지 않았으면 false(아무것도 안 함).
/// 서버 응답은 기다리지 않는다: Firestore가 폰에 먼저 적고 통신될 때 올린다.
/// 캐시도 바로 고쳐, 화면을 새로고침 안 해도 통계에 곧장 반영된다.
Future<bool> saveAttendance(AttendanceRecord r) async {
  final uid = currentUid();
  if (uid == null) return false;
  sendQuietly(
    () =>
        _collection().doc(_docId(r.date, uid)).set({...r.toJson(), 'uid': uid}),
    what: '근태 서버 저장',
  );
  AttendanceCache.byDate[dateKey(r.date)] = r.type;
  return true;
}

/// 하루치 근태 기록을 지운다(정상근무로 되돌리는 것과 같다). 로그인하지 않았으면 false.
Future<bool> deleteAttendance(DateTime date) async {
  final uid = currentUid();
  if (uid == null) return false;
  sendQuietly(
    () => _collection().doc(_docId(date, uid)).delete(),
    what: '근태 서버 지우기',
  );
  AttendanceCache.byDate.remove(dateKey(date));
  return true;
}

/// [from]~[to](두 날 포함) 근태 기록 전체. 읽지 못하면 null(빈 기록과 구분한다:
/// 빈 달로 보이면 기록이 사라진 줄 안다).
Future<Map<String, AttendanceRecord>?> loadAttendanceRange(
  DateTime from,
  DateTime to,
) async {
  final uid = currentUid();
  if (uid == null) return {};
  try {
    final q = _collection()
        .where('uid', isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: dateKey(from))
        .where('date', isLessThanOrEqualTo: dateKey(to));
    final snap = await _getWithCacheFallback(q);
    if (snap == null) return null;
    final map = <String, AttendanceRecord>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final d = DateTime.tryParse(data['date']?.toString() ?? '');
      if (d == null) continue;
      map[dateKey(d)] = AttendanceRecord.fromJson(data, d);
    }
    return map;
  } catch (_) {
    return null;
  }
}

/// 한 달치 기록(출퇴근 시간까지 필요하므로 문자열 캐시가 아니라 AttendanceRecord 전체).
/// 읽지 못하면 빈 맵.
Future<Map<String, AttendanceRecord>> loadAttendanceMonth(
  DateTime month,
) async {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 0);
  return await loadAttendanceRange(start, end) ?? {};
}

/// 이 보고서가 적힌 날짜의 근태 종류(캐시에 없으면 정상근무). 보고서에 dateISO가
/// 없는 아주 예전 자료는 그냥 정상근무로 본다.
String attendanceTypeOf(Map<String, dynamic> report) {
  final iso = report['dateISO']?.toString();
  if (iso == null || iso.isEmpty) return kAttendanceNormal;
  return AttendanceCache.byDate[iso] ?? kAttendanceNormal;
}

/// 근태 기록은 로그인한 "나"의 것이다. 그래서 보고서 인원(나를 포함한 투입 인원)에서 내 몫만 뺀다.
/// 연차·월차·결근이면 1, 반차 0.5, 반반차 0.25, 나머지(정상근무·조퇴·특근·기록 없음)는 0.
double myAbsenceShare(String type) {
  if (hasNoWorkTime(type)) return 1;
  if (type == '반차') return 0.5;
  if (type == '반반차') return 0.25;
  return 0;
}

/// 이 보고서 하루의 공수(인·일) = 투입 인원 − 내 근태 몫(0 아래로는 안 내려감).
/// 2026-09-26 사용자 지적으로 고침: 예전에는 내가 연차면 그날 작업조 전체가 0, 반차면 전체가
/// 절반이 되어 일한 사람들의 공수가 사라졌다. 이제 3명 중 내가 연차면 2, 반차면 2.5, 반반차면 2.75.
double manDaysOf(Map<String, dynamic> report) {
  final workers = (report['worker_count'] as num?)?.toInt() ?? 1;
  final off = myAbsenceShare(attendanceTypeOf(report));
  final v = workers - off;
  return v < 0 ? 0 : v;
}

/// 여러 보고서의 공수 합.
double totalManDays(Iterable<Map<String, dynamic>> reports) =>
    reports.fold(0.0, (total, r) => total + manDaysOf(r));

/// 화면에 보일 공수 숫자: 정수면 "3", 아니면 "3.5"(소수 첫째 자리까지만).
String formatManDays(num v) {
  final d = v.toDouble();
  return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);
}

/// 목록·요약에 붙일 짧은 근태 표. 정상근무(또는 근태 기록 없음)는 빈 문자열.
String attendanceTag(Map<String, dynamic> report) {
  final type = attendanceTypeOf(report);
  return type == kAttendanceNormal ? '' : type;
}

/// "HH:mm" 두 값의 시간 차(자정을 넘겨도 계산). 하나라도 없거나 둘이 같으면 null
/// (같은 시각을 24시간 근무로 읽던 것을 고쳤다).
double? workedHoursOf(String? checkIn, String? checkOut) {
  final m = stayMinutesOf(checkIn, checkOut);
  return m == null ? null : m / 60.0;
}

/// 출근~퇴근 사이 분(자정 넘김 처리). 하나라도 없거나 둘이 같으면 null.
int? stayMinutesOf(String? checkIn, String? checkOut) {
  final a = minutesOfDay(checkIn);
  final b = minutesOfDay(checkOut);
  if (a == null || b == null) return null;
  var diff = b - a;
  if (diff == 0) return null;
  if (diff < 0) diff += 24 * 60; // 자정 넘김(예: 22:00~06:00)
  return diff;
}

/// "HH:mm" → 그 날 0시부터 분. 모양이 틀리면 null.
int? minutesOfDay(String? v) {
  if (v == null || !v.contains(':')) return null;
  final parts = v.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    return null;
  }
  return h * 60 + m;
}
