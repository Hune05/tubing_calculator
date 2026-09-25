// 근태(연차·월차·반차·조퇴·특근)와 공수(투입 인원×일) 계산(필드 헬퍼 4번).
//
// 예전에는 "투입 인원" 숫자만 있어서, 쉬거나 반나절만 나온 날도 똑같이 그 인원수만큼
// 공수(인·일)로 잡혔다. 여기서 근태 구분을 붙여, 공수 계산에서 뺄 건 빼고(연차·월차는
// 일을 안 한 날), 반만 셀 건 반만(반차) 세게 한다. 화면과 떼어 놓아서 검사할 수 있게
// 모두 pure 함수로 둔다.
library;

/// 근태 구분. "정상근무"는 화면 목록·요약에 따로 표시하지 않는다(대부분의 날이라
/// 강조할 필요가 없다 — 표시가 있으면 오히려 눈에 덜 띈다).
const String kAttendanceNormal = '정상근무';
const List<String> kAttendanceTypes = [
  kAttendanceNormal,
  '연차',
  '월차',
  '반차',
  '조퇴',
  '특근',
];

/// 하루 종일 쉬는 근태(출퇴근 시간·작업 내용이 뜻이 없다 — 입력 칸을 감춘다).
bool isFullDayLeave(String type) => type == '연차' || type == '월차';

String attendanceTypeOf(Map<String, dynamic> report) =>
    report['attendance_type']?.toString() ?? kAttendanceNormal;

/// 이 보고서 하루의 공수(인·일). 연차·월차는 0(일을 안 한 날), 반차는 절반,
/// 나머지(정상근무·조퇴·특근)는 투입 인원 그대로.
double manDaysOf(Map<String, dynamic> report) {
  final workers = (report['worker_count'] as num?)?.toInt() ?? 1;
  final type = attendanceTypeOf(report);
  if (isFullDayLeave(type)) return 0;
  if (type == '반차') return workers * 0.5;
  return workers.toDouble();
}

/// 여러 보고서의 공수 합.
double totalManDays(Iterable<Map<String, dynamic>> reports) =>
    reports.fold(0.0, (sum, r) => sum + manDaysOf(r));

/// 화면에 보일 공수 숫자: 정수면 "3", 아니면 "3.5"(소수 첫째 자리까지만).
String formatManDays(num v) {
  final d = v.toDouble();
  return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);
}

/// 목록·요약에 붙일 짧은 근태 표. 정상근무는 빈 문자열(표시 안 함).
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
