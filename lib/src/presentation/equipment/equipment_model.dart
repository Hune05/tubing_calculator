// 장비 관리 대장: 개인 공구·작업 공구 한 대와 그 이력, 정기 점검 기한 계산, 반출·반납, 걸러 보기.
// 계측기 검교정은 관리 부서가 하므로 여기서는 다루지 않는다(10-02 사용자 결정).
// 화면과 저장은 따로 두고 여기서는 자료와 계산만 한다(전부 시험으로 확인한다).
import 'dart:convert';

/// 장비 분류. [id]를 저장하고 [label]을 보인다.
/// 예전에 저장한 'tool'(공구)은 작업 공구로, 'inst'(계측기)·'safety'(안전장비)는 기타로 읽힌다.
enum EquipCategory {
  personal('personal', '개인 공구'),
  work('tool', '작업 공구'),
  etc('etc', '기타');

  final String id;
  final String label;
  const EquipCategory(this.id, this.label);

  static EquipCategory of(String? id) =>
      values.firstWhere((c) => c.id == id, orElse: () => EquipCategory.etc);
}

/// 장비 상태.
enum EquipStatus {
  ok('ok', '사용 가능'),
  repair('repair', '수리·점검 중'),
  retired('retired', '폐기');

  final String id;
  final String label;
  const EquipStatus(this.id, this.label);

  static EquipStatus of(String? id) =>
      values.firstWhere((s) => s.id == id, orElse: () => EquipStatus.ok);
}

/// 이력 종류.
enum EventType {
  cal('cal', '교정'), // 예전 기록 읽기용(새로 남기지 않음)
  check('check', '점검'),
  repair('repair', '수리'),
  out('out', '반출'),
  back('in', '반납'),
  align('align', '축 정렬'),
  note('note', '메모');

  final String id;
  final String label;
  const EventType(this.id, this.label);

  static EventType of(String? id) =>
      values.firstWhere((t) => t.id == id, orElse: () => EventType.note);
}

const String kResultPass = '양호';
const String kResultFail = '불량';

/// 이력 한 줄.
class EquipEvent {
  final String id;
  final DateTime at;
  final EventType type;
  final String result; // 점검 결과(양호/불량, 예전 기록은 합격/불합격), 그 밖에는 빈 글
  final String by; // 점검자·수리 업체·반출한 사람 등
  final String certNo; // 예전 교정 기록의 성적서 번호
  final String note;
  const EquipEvent({
    required this.id,
    required this.at,
    required this.type,
    this.result = '',
    this.by = '',
    this.certNo = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'type': type.id,
    'result': result,
    'by': by,
    'certNo': certNo,
    'note': note,
  };

  static EquipEvent? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse((raw['at'] ?? '').toString());
    if (at == null) return null;
    return EquipEvent(
      id: (raw['id'] ?? at.microsecondsSinceEpoch).toString(),
      at: at,
      type: EventType.of(raw['type']?.toString()),
      result: (raw['result'] ?? '').toString(),
      by: (raw['by'] ?? '').toString(),
      certNo: (raw['certNo'] ?? '').toString(),
      note: (raw['note'] ?? '').toString(),
    );
  }
}

/// 날짜만(시각 버림).
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// [d]에 [months]개월을 더한다(31일 → 30일뿐인 달이면 그 달 마지막 날).
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final y = total ~/ 12;
  final m = total % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > last ? last : d.day);
}

/// 기한 상태.
enum DueState { none, ok, soon, overdue }

/// 몇 일 안이면 "임박"으로 볼지(월 1회 점검 기준).
const int kDueSoonDays = 7;

class Equipment {
  final String id;
  final String name;
  final String assetNo; // 관리번호(비워도 됨, 있으면 QR에 이 값을 넣는다)
  final EquipCategory category;
  final String maker;
  final String model;
  final String serial;
  final String location; // 보관 위치
  final int intervalMonths; // 정기 점검 주기(개월), 0이면 기한 없음
  final DateTime? lastDone; // 마지막 점검일
  final DateTime? dueOverride; // 직접 정한 다음 기한(없으면 마지막일 + 주기)
  final EquipStatus status;
  final String holder; // 지금 가지고 있는 사람(비면 보관 중)
  final String holderProject;
  final DateTime? checkedOutAt;
  final String note;
  final DateTime createdAt;
  final List<EquipEvent> events; // 최신이 앞

  /// 제원: 항목과 값 줄(예: 전동기 · 1700 W). 순서대로 보여 준다.
  final List<(String, String)> specs;

  const Equipment({
    required this.id,
    required this.name,
    this.assetNo = '',
    this.category = EquipCategory.work,
    this.maker = '',
    this.model = '',
    this.serial = '',
    this.location = '',
    this.intervalMonths = 0,
    this.lastDone,
    this.dueOverride,
    this.status = EquipStatus.ok,
    this.holder = '',
    this.holderProject = '',
    this.checkedOutAt,
    this.note = '',
    required this.createdAt,
    this.events = const [],
    this.specs = const [],
  });

  bool get isOut => holder.trim().isNotEmpty;
  bool get isRetired => status == EquipStatus.retired;

  /// QR에 넣는 글(관리번호가 있으면 그것, 없으면 앱 안 번호).
  String get qrText => 'FH-EQ:${assetNo.trim().isNotEmpty ? assetNo.trim() : id}';

  /// 다음 점검 기한. 정할 수 없으면 null.
  DateTime? get nextDue {
    if (dueOverride != null) return dayOnly(dueOverride!);
    if (lastDone != null && intervalMonths > 0) {
      return addMonths(dayOnly(lastDone!), intervalMonths);
    }
    return null;
  }

  /// 기한까지 남은 날(지났으면 음수). 기한이 없으면 null.
  int? daysLeft(DateTime now) {
    final due = nextDue;
    if (due == null) return null;
    return due.difference(dayOnly(now)).inDays;
  }

  /// 폐기한 장비는 기한을 따지지 않는다.
  DueState dueState(DateTime now) {
    if (isRetired) return DueState.none;
    final d = daysLeft(now);
    if (d == null) return DueState.none;
    if (d < 0) return DueState.overdue;
    if (d <= kDueSoonDays) return DueState.soon;
    return DueState.ok;
  }

  Equipment copyWith({
    String? name,
    String? assetNo,
    EquipCategory? category,
    String? maker,
    String? model,
    String? serial,
    String? location,
    int? intervalMonths,
    Object? lastDone = _keep,
    Object? dueOverride = _keep,
    EquipStatus? status,
    String? holder,
    String? holderProject,
    Object? checkedOutAt = _keep,
    String? note,
    List<EquipEvent>? events,
    List<(String, String)>? specs,
  }) => Equipment(
    id: id,
    name: name ?? this.name,
    assetNo: assetNo ?? this.assetNo,
    category: category ?? this.category,
    maker: maker ?? this.maker,
    model: model ?? this.model,
    serial: serial ?? this.serial,
    location: location ?? this.location,
    intervalMonths: intervalMonths ?? this.intervalMonths,
    lastDone: identical(lastDone, _keep) ? this.lastDone : lastDone as DateTime?,
    dueOverride: identical(dueOverride, _keep)
        ? this.dueOverride
        : dueOverride as DateTime?,
    status: status ?? this.status,
    holder: holder ?? this.holder,
    holderProject: holderProject ?? this.holderProject,
    checkedOutAt: identical(checkedOutAt, _keep)
        ? this.checkedOutAt
        : checkedOutAt as DateTime?,
    note: note ?? this.note,
    createdAt: createdAt,
    events: events ?? this.events,
    specs: specs ?? this.specs,
  );

  static const Object _keep = Object();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'assetNo': assetNo,
    'category': category.id,
    'maker': maker,
    'model': model,
    'serial': serial,
    'location': location,
    'interval': intervalMonths,
    'lastDone': lastDone?.toIso8601String(),
    'dueOverride': dueOverride?.toIso8601String(),
    'status': status.id,
    'holder': holder,
    'holderProject': holderProject,
    'checkedOutAt': checkedOutAt?.toIso8601String(),
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'events': [for (final e in events) e.toJson()],
    if (specs.isNotEmpty) 'specs': [for (final s in specs) [s.$1, s.$2]],
  };

  static Equipment fromJson(Map<String, dynamic> j) {
    final created = DateTime.tryParse((j['createdAt'] ?? '').toString());
    final events = <EquipEvent>[];
    final raw = j['events'];
    if (raw is List) {
      for (final e in raw) {
        final ev = EquipEvent.fromJson(e);
        if (ev != null) events.add(ev);
      }
    }
    events.sort((a, b) => b.at.compareTo(a.at));
    final name = (j['name'] ?? '').toString();
    if (name.isEmpty || j['id'] == null) {
      throw const FormatException('장비 자료가 아닙니다');
    }
    return Equipment(
      id: j['id'].toString(),
      name: name,
      assetNo: (j['assetNo'] ?? '').toString(),
      category: EquipCategory.of(j['category']?.toString()),
      maker: (j['maker'] ?? '').toString(),
      model: (j['model'] ?? '').toString(),
      serial: (j['serial'] ?? '').toString(),
      location: (j['location'] ?? '').toString(),
      intervalMonths: (j['interval'] as num?)?.toInt() ?? 0,
      lastDone: DateTime.tryParse((j['lastDone'] ?? '').toString()),
      dueOverride: DateTime.tryParse((j['dueOverride'] ?? '').toString()),
      status: EquipStatus.of(j['status']?.toString()),
      holder: (j['holder'] ?? '').toString(),
      holderProject: (j['holderProject'] ?? '').toString(),
      checkedOutAt: DateTime.tryParse((j['checkedOutAt'] ?? '').toString()),
      note: (j['note'] ?? '').toString(),
      createdAt: created ?? DateTime.now(),
      events: events,
      specs: specsFromJson(j['specs']),
    );
  }
}

/// 저장된 제원 줄 읽기(망가진 줄은 건너뛴다).
List<(String, String)> specsFromJson(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final r in raw)
      if (r is List && r.length >= 2 && '${r[0]}'.trim().isNotEmpty) ('${r[0]}'.trim(), '${r[1]}'.trim()),
  ];
}

/// 제원을 한 줄 글로(목록·CSV·카톡).
String specsLine(List<(String, String)> specs) => [for (final s in specs) '${s.$1} ${s.$2}'.trim()].join(' · ');

// ── 이력을 남기는 동작(새 장비를 돌려준다) ──

String _eventId(DateTime at, int n) => '${at.microsecondsSinceEpoch}_$n';

List<EquipEvent> _prepend(Equipment e, EquipEvent ev) => [ev, ...e.events];

/// 점검을 기록한다. 양호이면 마지막일이 [at]로 바뀌고 다음 기한은 주기로 다시 계산된다
/// (직접 정한 기한은 지운다). 불량이면 마지막일은 그대로 두고 "수리·점검 중"으로 바꾼다.
/// [nextDue]를 주면 그 날짜를 다음 기한으로 직접 정한다.
Equipment recordInspection(
  Equipment e, {
  required DateTime at,
  EventType type = EventType.check,
  String result = kResultPass,
  String by = '',
  String certNo = '',
  String note = '',
  DateTime? nextDue,
}) {
  assert(type == EventType.cal || type == EventType.check);
  final ev = EquipEvent(
    id: _eventId(at, e.events.length),
    at: dayOnly(at),
    type: type,
    result: result,
    by: by.trim(),
    certNo: certNo.trim(),
    note: note.trim(),
  );
  if (result == kResultFail) {
    return e.copyWith(status: EquipStatus.repair, events: _prepend(e, ev));
  }
  return e.copyWith(
    lastDone: dayOnly(at),
    dueOverride: nextDue == null ? null : dayOnly(nextDue),
    // 수리 중이던 장비가 점검 양호면 다시 쓸 수 있다.
    status: e.status == EquipStatus.repair ? EquipStatus.ok : e.status,
    events: _prepend(e, ev),
  );
}

/// 축 정렬을 했다는 기록. 점검 기한과 상태는 바꾸지 않는다.
Equipment recordAlignment(Equipment e, {required DateTime at, String note = ''}) => e.copyWith(
  events: _prepend(
    e,
    EquipEvent(
      id: _eventId(at, e.events.length),
      at: dayOnly(at),
      type: EventType.align,
      note: note.trim(),
    ),
  ),
);

/// 수리했다는 기록(상태는 "수리·점검 중"으로).
Equipment recordRepair(Equipment e, {required DateTime at, String by = '', String note = ''}) {
  final ev = EquipEvent(
    id: _eventId(at, e.events.length),
    at: dayOnly(at),
    type: EventType.repair,
    by: by.trim(),
    note: note.trim(),
  );
  return e.copyWith(status: EquipStatus.repair, events: _prepend(e, ev));
}

/// 수리·점검이 끝나 다시 쓸 수 있게 한다.
Equipment markUsable(Equipment e, {required DateTime at}) => e.copyWith(
  status: EquipStatus.ok,
  events: _prepend(
    e,
    EquipEvent(
      id: _eventId(at, e.events.length),
      at: dayOnly(at),
      type: EventType.note,
      note: '수리·점검 끝, 다시 사용 가능',
    ),
  ),
);

/// 폐기한다(이력은 남는다).
Equipment retire(Equipment e, {required DateTime at, String note = ''}) => e.copyWith(
  status: EquipStatus.retired,
  holder: '',
  holderProject: '',
  checkedOutAt: null,
  events: _prepend(
    e,
    EquipEvent(
      id: _eventId(at, e.events.length),
      at: dayOnly(at),
      type: EventType.note,
      note: note.trim().isEmpty ? '폐기' : '폐기: ${note.trim()}',
    ),
  ),
);

/// 반출한다. 이미 반출 중이거나 폐기·수리 중이면 null(하지 않는다).
Equipment? checkOut(
  Equipment e, {
  required DateTime at,
  required String who,
  String project = '',
  String note = '',
}) {
  if (e.isOut || e.status != EquipStatus.ok || who.trim().isEmpty) return null;
  final ev = EquipEvent(
    id: _eventId(at, e.events.length),
    at: at,
    type: EventType.out,
    by: who.trim(),
    note: [if (project.trim().isNotEmpty) project.trim(), if (note.trim().isNotEmpty) note.trim()].join(' · '),
  );
  return e.copyWith(
    holder: who.trim(),
    holderProject: project.trim(),
    checkedOutAt: at,
    events: _prepend(e, ev),
  );
}

/// 반납한다. 반출 중이 아니면 null.
Equipment? checkIn(Equipment e, {required DateTime at, String note = ''}) {
  if (!e.isOut) return null;
  final ev = EquipEvent(
    id: _eventId(at, e.events.length),
    at: at,
    type: EventType.back,
    by: e.holder,
    note: note.trim(),
  );
  return e.copyWith(
    holder: '',
    holderProject: '',
    checkedOutAt: null,
    events: _prepend(e, ev),
  );
}

// ── 목록 보기 ──

/// 목록 걸러 보기.
enum LedgerView { all, due, out }

/// 기한이 급한 순(만료 → 임박 → 정상 → 기한 없음), 같으면 이름순. 폐기한 것은 맨 뒤.
List<Equipment> sortLedger(List<Equipment> all, DateTime now) {
  int rank(Equipment e) {
    if (e.isRetired) return 9;
    return switch (e.dueState(now)) {
      DueState.overdue => 0,
      DueState.soon => 1,
      DueState.ok => 2,
      DueState.none => 3,
    };
  }

  final list = [...all];
  list.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    final da = a.daysLeft(now), db = b.daysLeft(now);
    if (da != null && db != null && da != db) return da.compareTo(db);
    return a.name.compareTo(b.name);
  });
  return list;
}

String _norm(String s) => s.replaceAll(RegExp(r'\s+'), '').toLowerCase();

/// 검색어·분류·보기 조건으로 거른다(폐기한 장비는 "전체"에서만 보인다).
List<Equipment> filterLedger(
  List<Equipment> all,
  DateTime now, {
  String query = '',
  EquipCategory? category,
  LedgerView view = LedgerView.all,
}) {
  final q = _norm(query);
  final out = <Equipment>[];
  for (final e in all) {
    if (category != null && e.category != category) continue;
    switch (view) {
      case LedgerView.all:
        break;
      case LedgerView.due:
        final s = e.dueState(now);
        if (s != DueState.overdue && s != DueState.soon) continue;
      case LedgerView.out:
        if (!e.isOut) continue;
    }
    if (q.isNotEmpty) {
      final hay = _norm(
        '${e.name} ${e.assetNo} ${e.maker} ${e.model} ${e.serial} ${e.location} ${e.holder} ${e.holderProject} ${e.category.label}',
      );
      if (!hay.contains(q)) continue;
    }
    out.add(e);
  }
  return sortLedger(out, now);
}

/// 대장 머리에 보이는 개수.
class LedgerSummary {
  final int total; // 폐기 제외
  final int overdue;
  final int soon;
  final int out;
  final int repair;
  const LedgerSummary(this.total, this.overdue, this.soon, this.out, this.repair);
}

LedgerSummary summarize(List<Equipment> all, DateTime now) {
  var total = 0, overdue = 0, soon = 0, out = 0, repair = 0;
  for (final e in all) {
    if (e.isRetired) continue;
    total++;
    switch (e.dueState(now)) {
      case DueState.overdue:
        overdue++;
      case DueState.soon:
        soon++;
      default:
    }
    if (e.isOut) out++;
    if (e.status == EquipStatus.repair) repair++;
  }
  return LedgerSummary(total, overdue, soon, out, repair);
}

/// "D-12", "오늘까지", "3일 지남", "" (기한 없음).
String dueLabel(Equipment e, DateTime now) {
  final d = e.daysLeft(now);
  if (d == null || e.isRetired) return '';
  if (d < 0) return '${-d}일 지남';
  if (d == 0) return '오늘까지';
  return 'D-$d';
}

/// 점검 주기 글: 0 없음, 1 매월, 12 1년, 그 밖에 N개월.
String intervalLabel(int m) => m == 0 ? '없음' : (m == 1 ? '매월' : (m % 12 == 0 ? '${m ~/ 12}년' : '$m개월'));

String dateLabel(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 처음 등록할 때 고를 수 있는 예시(이름, 분류, 점검 주기 개월). 전동공구는 월 1회 정기 점검,
/// 손공구·계측기는 기한 없음(계측기 검교정은 관리 부서가 따로 한다).
const List<({String name, EquipCategory category, int months})> kEquipPresets = [
  (name: 'DEWALT D28730 (고속절단기)', category: EquipCategory.work, months: 1),
  (name: 'DEWALT DCS377 (충전 밴드쏘)', category: EquipCategory.work, months: 1),
  (name: 'REMS 타이거 SR (컷쏘)', category: EquipCategory.work, months: 1),
  (name: 'REMS 아미고 (전동 나사 절삭기)', category: EquipCategory.work, months: 1),
  (name: 'REMS 아미고 2 (전동 나사 절삭기)', category: EquipCategory.work, months: 1),
  (name: '공성 KSU N80A (3" 나사 절삭기)', category: EquipCategory.work, months: 1),
  (name: 'DEWALT DCD806 (해머 드릴)', category: EquipCategory.personal, months: 1),
  (name: 'DEWALT DCD801 (드릴 드라이버)', category: EquipCategory.personal, months: 1),
  (name: 'DEWALT DCF870 (임팩 드라이버)', category: EquipCategory.personal, months: 1),
  (name: 'HIOKI DT4282 (멀티미터)', category: EquipCategory.personal, months: 0),
  (name: '튜브 벤더', category: EquipCategory.personal, months: 0),
  (name: '튜브 커터', category: EquipCategory.personal, months: 0),
  (name: '토크 렌치', category: EquipCategory.personal, months: 0),
];

/// 예시를 고르면 함께 채우는 제조사·모델·제원. 제원은 제조사가 공개한 값.
const Map<String, ({String maker, String model, List<(String, String)> specs})> kEquipPresetDetails = {
  // HIOKI 값은 사용자가 준 DT4281/DT4282 설명서.
  'HIOKI DT4282 (멀티미터)': (
    maker: 'HIOKI',
    model: 'DT4282',
    specs: [
      ('전류 범위', 'μA 6000 μA, mA 600 mA, A 10 A'),
      ('DC mA 정확도', '±0.05% rdg ±5 dgt (60 mA 범위)'),
      ('4-20mA %', '±0.1% rdg ±20 dgt'),
      ('퓨즈', '630 mA / 1000 V, 11 A / 1000 V'),
      ('전원', 'AA 4개'),
      ('크기·중량', '93 × 197 × 53 mm, 약 650 g'),
    ],
  ),
  // 공성 값은 사용자가 준 제원(같은 구조인 REX N80A 설명서를 씀).
  '공성 KSU N80A (3" 나사 절삭기)': (
    maker: '공성',
    model: 'KSU N80A[3"]-A',
    specs: [
      ('작업 범위', '1/2"~3" (나사 절삭·절단·리밍)'),
      ('전원', 'AC 220 V (50/60 Hz)'),
      ('모터', '단상 750 W 콘덴서 모터'),
      ('회전수', '3단: 12 / 16.5 / 33.5 rpm'),
      ('중량', '115 kg'),
      ('크기', '940 × 530 × 560 mm'),
    ],
  ),
  // 아미고·아미고 2 값은 REMS 설명서(아미고·아미고 E·아미고 2·컴팩트 묶음) 1장 제원표.
  'REMS 아미고 (전동 나사 절삭기)': (
    maker: 'REMS',
    model: 'Amigo',
    specs: [
      ('전동기', '1200 W'),
      ('전원', '230 V 6 A / 110 V 12 A'),
      ('사용률', 'S3 20% (10분 중 2분 가동)'),
      ('회전수', '35~27 rpm'),
      ('관용 나사', '1/8~1 1/4" (16~40 mm)'),
      ('볼트 나사', '6~30 mm (1/4~1")'),
      ('중량', '본체 3.5 kg, 지지대 1.3 kg'),
      ('과부하 보호', '있음 (버튼 복귀)'),
    ],
  ),
  'REMS 아미고 2 (전동 나사 절삭기)': (
    maker: 'REMS',
    model: 'Amigo 2',
    specs: [
      ('전동기', '1700 W'),
      ('전원', '230 V 8.3 A / 110 V 16.6 A'),
      ('사용률', 'S3 20% (10분 중 2분 가동)'),
      ('회전수', '30~18 rpm'),
      ('관용 나사', '1/8~2" (16~50 mm)'),
      ('볼트 나사', '6~30 mm (1/4~1")'),
      ('중량', '본체 6.5 kg, 지지대 2.9 kg'),
    ],
  ),
  'REMS 타이거 SR (컷쏘)': (
    maker: 'REMS',
    model: 'Tiger SR',
    specs: [
      ('전동기', '1400 W'),
      ('전원', '230 V 6.4 A / 110 V 12.8 A'),
      ('중량', '3.1 kg'),
      ('스트로크', '700~2200회/분 (다이얼 조절)'),
      ('가이드 홀더 2"', '1/8~2"'),
      ('가이드 홀더 4"', '2 1/2~4"'),
      ('가이드 홀더 6"', '5~6"'),
    ],
  ),
  // DEWALT 값은 사용자가 준 각 장비 설명서 제원표.
  'DEWALT D28730 (고속절단기)': (
    maker: 'DEWALT',
    model: 'D28730',
    specs: [
      ('전원', '220~240 V, 2300 W'),
      ('무부하 회전수', '4200 rpm'),
      ('절단석', 'Ø355 × 25.4 × 3.0 mm'),
      ('절단 능력 (90°)', '파이프 125 mm, 앵글 120 × 120 mm'),
      ('중량', '16 kg'),
    ],
  ),
  'DEWALT DCS377 (충전 밴드쏘)': (
    maker: 'DEWALT',
    model: 'DCS377',
    specs: [
      ('전압', '20V MAX (18 V)'),
      ('절단 능력', '1-3/4" (약 44 mm)'),
      ('날 속도', '150~380 SFPM (약 46~116 m/분)'),
      ('톱날', '0.5 × 12.7 × 686~692 mm'),
    ],
  ),
  'DEWALT DCD806 (해머 드릴)': (
    maker: 'DEWALT',
    model: 'DCD806',
    specs: [
      ('전압', '18 V'),
      ('회전수', '0~650 / 0~2000 rpm'),
      ('타격수', '0~11050 / 0~34000회/분'),
      ('최대 토크', '90 / 27 Nm'),
      ('척', '1.5~13 mm'),
      ('중량', '1.34 kg (배터리 제외)'),
    ],
  ),
  'DEWALT DCD801 (드릴 드라이버)': (
    maker: 'DEWALT',
    model: 'DCD801',
    specs: [
      ('전압', '18 V'),
      ('회전수', '0~650 / 0~2000 rpm'),
      ('최대 토크', '90 / 27 Nm'),
      ('척', '1.5~13 mm'),
      ('중량', '1.28 kg (배터리 제외)'),
    ],
  ),
  'DEWALT DCF870 (임팩 드라이버)': (
    maker: 'DEWALT',
    model: 'DCF870',
    specs: [
      ('전압', '18 V'),
      ('출력', '500 W'),
      ('회전수', '0~1100 / 0~3000 rpm'),
      ('최대 토크', '56 Nm'),
      ('척', '1/4" 육각'),
      ('중량', '1.0 kg (배터리 제외)'),
    ],
  ),
};

// ── 내보내기 글 ──

String _q(String s) => '"${s.replaceAll('"', '""').replaceAll('\n', ' ')}"';

/// 엑셀에서 열 수 있는 CSV(맨 앞 BOM).
String buildLedgerCsv(List<Equipment> all, DateTime now) {
  final b = StringBuffer('﻿관리번호,장비명,분류,제조사,모델,시리얼,보관 위치,상태,점검 주기(개월),마지막 점검일,다음 점검일,기한 상태,사용자,프로젝트,메모,제원')
    ..writeln();
  for (final e in sortLedger(all, now)) {
    final st = switch (e.dueState(now)) {
      DueState.overdue => '만료',
      DueState.soon => '임박',
      DueState.ok => '정상',
      DueState.none => '',
    };
    b.writeln(
      [
        _q(e.assetNo),
        _q(e.name),
        _q(e.category.label),
        _q(e.maker),
        _q(e.model),
        _q(e.serial),
        _q(e.location),
        _q(e.status.label),
        e.intervalMonths,
        e.lastDone == null ? '' : dateLabel(e.lastDone!),
        e.nextDue == null ? '' : dateLabel(e.nextDue!),
        st,
        _q(e.holder),
        _q(e.holderProject),
        _q(e.note),
        _q(specsLine(e.specs)),
      ].join(','),
    );
  }
  return b.toString();
}

/// 카톡으로 보내는 "기한 지난·임박 장비" 글.
String buildDueText(List<Equipment> all, DateTime now) {
  final list = filterLedger(all, now, view: LedgerView.due);
  if (list.isEmpty) return '[공구 점검 기한] 기한이 지났거나 $kDueSoonDays일 안에 오는 장비가 없습니다.';
  final b = StringBuffer('[공구 점검 기한] ${now.month}/${now.day} 기준');
  for (final e in list) {
    final no = e.assetNo.isEmpty ? '' : '${e.assetNo} ';
    b.write('\n${e.dueState(now) == DueState.overdue ? '⚠ ' : '· '}$no${e.name} · 점검 기한 ${dateLabel(e.nextDue!)} (${dueLabel(e, now)})');
  }
  return b.toString();
}

/// 장비 한 대 이력을 글로(공유용).
String buildEquipmentText(Equipment e, DateTime now) {
  final b = StringBuffer('[장비] ${e.assetNo.isEmpty ? '' : '${e.assetNo} '}${e.name}');
  if (e.maker.isNotEmpty || e.model.isNotEmpty) b.write('\n${[e.maker, e.model].where((s) => s.isNotEmpty).join(' ')}');
  if (e.serial.isNotEmpty) b.write('\n시리얼 ${e.serial}');
  if (e.nextDue != null) b.write('\n다음 점검 ${dateLabel(e.nextDue!)} (${dueLabel(e, now)})');
  if (e.isOut) b.write('\n반출 중: ${e.holder}${e.holderProject.isEmpty ? '' : ' · ${e.holderProject}'}');
  for (final ev in e.events.take(10)) {
    b.write('\n${dateLabel(ev.at)} ${ev.type.label}${ev.result.isEmpty ? '' : ' ${ev.result}'}${ev.by.isEmpty ? '' : ' (${ev.by})'}${ev.certNo.isEmpty ? '' : ' 성적서 ${ev.certNo}'}');
  }
  return b.toString();
}

/// 장비 목록 JSON(백업·시험용).
String ledgerToJson(List<Equipment> all) => jsonEncode([for (final e in all) e.toJson()]);
