// 근태(연차·월차·반차·조퇴·특근) - 프로젝트와 무관하게 "사람" 기준으로 따로 관리하고,
// 공수(인·일) 계산에는 날짜만 맞춰 연동한다(필드 헬퍼 4번).
//
// 처음에는 작업 일지 화면 안에 근태 칸을 넣었었다. 그런데 근태(특히 연차·월차)는
// 일지를 아예 쓰지 않는 날도 있어야 하고, 여러 프로젝트에 걸쳐 사람 한 명 기준으로
// 하루에 하나만 있으면 된다 - 그래서 별도의 "근태 관리" 화면(attendance_page.dart)에서
// 날짜별로 기록하고, 공수를 계산하는 쪽(project_phase.dart 등)에서는 보고서의 날짜
// (dateISO)로 그 날 근태를 찾아와 반영한다. 연동은 날짜로만 하고 프로젝트는 안 본다.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tubing_calculator/src/data/ownership.dart';

/// "정상근무"는 화면 목록·요약에 따로 표시하지 않는다(대부분의 날이라 강조할
/// 필요가 없다 - 표시가 있으면 오히려 눈에 덜 띈다).
const String kAttendanceNormal = '정상근무';
const List<String> kAttendanceTypes = [
  kAttendanceNormal,
  '연차',
  '월차',
  '반차',
  '조퇴',
  '특근',
];

/// 하루 종일 쉬는 근태(출퇴근 시간이 뜻이 없다 - 입력 칸을 감춘다).
bool isFullDayLeave(String type) => type == '연차' || type == '월차';

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class AttendanceRecord {
  final DateTime date;
  final String type;
  final String? checkIn; // "HH:mm"
  final String? checkOut;
  const AttendanceRecord({
    required this.date,
    this.type = kAttendanceNormal,
    this.checkIn,
    this.checkOut,
  });

  double? get workedHours => workedHoursOf(checkIn, checkOut);

  Map<String, dynamic> toJson() => {
    'date': dateKey(date),
    'type': type,
    'checkIn': checkIn,
    'checkOut': checkOut,
  };

  static AttendanceRecord fromJson(Map<String, dynamic> j, DateTime date) =>
      AttendanceRecord(
        date: date,
        type: j['type']?.toString() ?? kAttendanceNormal,
        checkIn: j['checkIn']?.toString(),
        checkOut: j['checkOut']?.toString(),
      );
}

/// 로그인한 사람의 근태를 날짜별로 담아 두는 메모리 캐시. 공수 계산 함수들은
/// 매번 서버를 읽지 않고 이 캐시를 본다 - 서버 상태는 WorkProjectRepository.pendingWrites와
/// 같은 방식(정적 캐시 + 새로고침)으로 관리한다.
class AttendanceCache {
  static Map<String, String> byDate = {};

  /// 로그인한 사람의 근태 기록을 전부 읽어 캐시를 채운다. 통신이 안 되거나
  /// 로그인을 안 했으면 조용히 그대로 둔다(전부 정상근무로 보이는 것과 같다).
  static Future<void> refresh() async {
    final uid = currentUid();
    if (uid == null) return;
    try {
      final snap = await _collection()
          .where('uid', isEqualTo: uid)
          .get()
          .timeout(const Duration(seconds: 6));
      final map = <String, String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final date = data['date']?.toString();
        final type = data['type']?.toString();
        if (date != null && type != null) map[date] = type;
      }
      byDate = map;
    } catch (_) {}
  }
}

CollectionReference<Map<String, dynamic>> _collection() =>
    FirebaseFirestore.instance.collection('attendance_records');

/// 문서 아이디: "{uid}__{yyyy-MM-dd}" - 서버 규칙에서 이 uid가 나뿐인지 확인한다.
String _docId(DateTime d, String uid) => '${uid}__${dateKey(d)}';

/// 하루치 근태를 서버에 저장한다(로그인 안 했으면 아무 것도 하지 않음). 저장하면서
/// 캐시도 바로 갱신해, 화면을 새로고침 안 해도 통계에 곧장 반영된다.
Future<void> saveAttendance(AttendanceRecord r) async {
  final uid = currentUid();
  if (uid == null) return;
  await _collection().doc(_docId(r.date, uid)).set({...r.toJson(), 'uid': uid});
  AttendanceCache.byDate[dateKey(r.date)] = r.type;
}

/// 하루치 근태 기록을 지운다(정상근무로 되돌리는 것과 같다).
Future<void> deleteAttendance(DateTime date) async {
  final uid = currentUid();
  if (uid == null) return;
  await _collection().doc(_docId(date, uid)).delete();
  AttendanceCache.byDate.remove(dateKey(date));
}

/// 근태 관리 화면에서 한 달치를 보여 줄 때 쓴다(출퇴근 시간까지 필요하므로
/// 문자열 캐시가 아니라 AttendanceRecord 전체를 읽어 온다).
Future<Map<String, AttendanceRecord>> loadAttendanceMonth(
  DateTime month,
) async {
  final uid = currentUid();
  if (uid == null) return {};
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 0);
  try {
    final snap = await _collection()
        .where('uid', isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: dateKey(start))
        .where('date', isLessThanOrEqualTo: dateKey(end))
        .get()
        .timeout(const Duration(seconds: 6));
    final map = <String, AttendanceRecord>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final d = DateTime.tryParse(data['date']?.toString() ?? '');
      if (d == null) continue;
      map[dateKey(d)] = AttendanceRecord.fromJson(data, d);
    }
    return map;
  } catch (_) {
    return {};
  }
}

/// 이 보고서가 적힌 날짜의 근태 종류(캐시에 없으면 정상근무). 보고서에 dateISO가
/// 없는 아주 예전 자료는 그냥 정상근무로 본다.
String attendanceTypeOf(Map<String, dynamic> report) {
  final iso = report['dateISO']?.toString();
  if (iso == null || iso.isEmpty) return kAttendanceNormal;
  return AttendanceCache.byDate[iso] ?? kAttendanceNormal;
}

/// 이 보고서 하루의 공수(인·일). 그 날짜에 연차·월차가 잡혀 있으면 0(일을 안 한
/// 날), 반차면 절반, 나머지(정상근무·조퇴·특근 또는 근태 기록이 없음)는 투입
/// 인원 그대로.
double manDaysOf(Map<String, dynamic> report) {
  final workers = (report['worker_count'] as num?)?.toInt() ?? 1;
  final type = attendanceTypeOf(report);
  if (isFullDayLeave(type)) return 0;
  if (type == '반차') return workers * 0.5;
  return workers.toDouble();
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

/// "HH:mm" 두 값의 시간 차(자정을 넘겨도 계산). 하나라도 없으면 null.
double? workedHoursOf(String? checkIn, String? checkOut) {
  final a = _minutesOfDay(checkIn);
  final b = _minutesOfDay(checkOut);
  if (a == null || b == null) return null;
  var diff = b - a;
  if (diff <= 0) diff += 24 * 60; // 자정 넘김(예: 22:00~06:00)
  return diff / 60.0;
}

int? _minutesOfDay(String? v) {
  if (v == null || !v.contains(':')) return null;
  final parts = v.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}
