// 도면 보기: 도면 한 장(PDF·사진·DXF)과 그 위에 올린 표시(체크·문제·구름·펜 등).
// 원본 파일은 절대 바꾸지 않고, 표시는 따로 저장한다(ISO 9001 기록 관리: 원본 보존·식별·이력).
// 표시 색은 준공도 레드라인 관례를 따른다: 빨강 = 추가·변경·틀림, 초록 = 삭제, 파랑 = 메모·질문.

enum DrawingKind { pdf, image, dxf }

/// 표시 종류.
enum MarkKind {
  ok('확인', false),
  wrong('틀림', true),
  question('질문', true),
  issue('문제', true),
  cloud('구름', false),
  arrow('화살표', false),
  rect('네모', false),
  pen('펜', false),
  text('글', false);

  final String label;
  final bool numbered; // 문제 번호를 붙이고 목록에 올리는 것
  const MarkKind(this.label, this.numbered);
}

/// 레드라인 색 약속.
enum MarkColor {
  red('빨강', '추가·변경', 0xFFE53935),
  green('초록', '삭제', 0xFF2E9E3E),
  blue('파랑', '메모', 0xFF1E5FD8);

  final String label;
  final String meaning;
  final int argb;
  const MarkColor(this.label, this.meaning, this.argb);
}

MarkColor defaultColorFor(MarkKind k) => switch (k) {
  MarkKind.ok => MarkColor.green,
  MarkKind.question => MarkColor.blue,
  MarkKind.text => MarkColor.blue,
  _ => MarkColor.red,
};

class MarkEvent {
  final DateTime at;
  final String what;
  final String who;
  const MarkEvent(this.at, this.what, this.who);

  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'what': what, 'who': who};
  static MarkEvent fromJson(Map<String, dynamic> j) => MarkEvent(
    DateTime.tryParse('${j['at']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
    _renamedEvents['${j['what'] ?? ''}'] ?? '${j['what'] ?? ''}',
    '${j['who'] ?? ''}',
  );

  /// 이름을 바꾼 기록 글(예전 글 → 새 글). 예전에 저장한 기록도 새 글로 읽는다(10-03).
  static const Map<String, String> _renamedEvents = {'다시 남음': '해결 취소'};
}

class DrawingMark {
  final String id;
  final int page; // 0부터
  final MarkKind kind;
  final MarkColor color;

  /// 쪽 그림 안 위치(0~1, 왼쪽 위가 0). 다시 그려도(해상도가 바뀌어도) 자리가 맞는다.
  final List<(double, double)> points;
  final String text;
  final int no; // 문제 번호(번호 붙는 종류만, 없으면 0)
  final bool done; // 해결됨
  final String author;
  final DateTime createdAt;
  final List<MarkEvent> history;

  const DrawingMark({
    required this.id,
    required this.page,
    required this.kind,
    required this.color,
    required this.points,
    this.text = '',
    this.no = 0,
    this.done = false,
    this.author = '',
    required this.createdAt,
    this.history = const [],
  });

  DrawingMark copyWith({String? text, bool? done, MarkColor? color, List<(double, double)>? points, List<MarkEvent>? history}) => DrawingMark(
    id: id,
    page: page,
    kind: kind,
    color: color ?? this.color,
    points: points ?? this.points,
    text: text ?? this.text,
    no: no,
    done: done ?? this.done,
    author: author,
    createdAt: createdAt,
    history: history ?? this.history,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'page': page,
    'kind': kind.name,
    'color': color.name,
    'points': [for (final p in points) [p.$1, p.$2]],
    'text': text,
    'no': no,
    'done': done,
    'author': author,
    'createdAt': createdAt.toIso8601String(),
    'history': [for (final h in history) h.toJson()],
  };

  static DrawingMark fromJson(Map<String, dynamic> j) {
    final raw = j['points'];
    return DrawingMark(
      id: '${j['id']}',
      page: (j['page'] as num?)?.toInt() ?? 0,
      kind: MarkKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => MarkKind.issue),
      color: MarkColor.values.firstWhere((c) => c.name == j['color'], orElse: () => MarkColor.red),
      points: raw is List
          ? [
              for (final p in raw)
                if (p is List && p.length >= 2) ((p[0] as num).toDouble(), (p[1] as num).toDouble()),
            ]
          : const [],
      text: '${j['text'] ?? ''}',
      no: (j['no'] as num?)?.toInt() ?? 0,
      done: j['done'] == true,
      author: '${j['author'] ?? ''}',
      createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
      history: j['history'] is List
          ? [for (final h in j['history'] as List) if (h is Map) MarkEvent.fromJson(Map<String, dynamic>.from(h))]
          : const [],
    );
  }
}

/// 다음 문제 번호.
int nextIssueNo(List<DrawingMark> marks) {
  var n = 0;
  for (final m in marks) {
    if (m.no > n) n = m.no;
  }
  return n + 1;
}

/// 번호 붙은 표시(문제 목록) — 번호 차례.
List<DrawingMark> issuesOf(List<DrawingMark> marks) =>
    [for (final m in marks) if (m.kind.numbered) m]..sort((a, b) => a.no.compareTo(b.no));

int openIssueCount(List<DrawingMark> marks) => marks.where((m) => m.kind.numbered && !m.done).length;

class DrawingDoc {
  final String id;
  final String name; // 파일 이름
  final DrawingKind kind;
  final String ext; // 원본 확장자
  final int pages;
  final List<(int, int)> pageSizes; // 그린 쪽 그림 크기(px)
  final List<double> pageDpi; // PDF 쪽을 그린 해상도(쪽마다)
  final DateTime addedAt;
  final DateTime openedAt;
  final String drawingNo; // 도번
  final String rev;
  final String title; // 도면명
  final int openIssues; // 목록에 보여 줄 열린 문제 수(표시 저장 때 맞춘다)

  const DrawingDoc({
    required this.id,
    required this.name,
    required this.kind,
    required this.ext,
    required this.pages,
    required this.pageSizes,
    this.pageDpi = const [],
    required this.addedAt,
    required this.openedAt,
    this.drawingNo = '',
    this.rev = '',
    this.title = '',
    this.openIssues = 0,
  });

  String get displayName => title.isNotEmpty ? title : name;

  DrawingDoc copyWith({String? name, DateTime? openedAt, String? drawingNo, String? rev, String? title, int? openIssues}) => DrawingDoc(
    id: id,
    name: name ?? this.name,
    kind: kind,
    ext: ext,
    pages: pages,
    pageSizes: pageSizes,
    pageDpi: pageDpi,
    addedAt: addedAt,
    openedAt: openedAt ?? this.openedAt,
    drawingNo: drawingNo ?? this.drawingNo,
    rev: rev ?? this.rev,
    title: title ?? this.title,
    openIssues: openIssues ?? this.openIssues,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'ext': ext,
    'pages': pages,
    'pageSizes': [for (final s in pageSizes) [s.$1, s.$2]],
    'pageDpi': pageDpi,
    'addedAt': addedAt.toIso8601String(),
    'openedAt': openedAt.toIso8601String(),
    'drawingNo': drawingNo,
    'rev': rev,
    'title': title,
    'openIssues': openIssues,
  };

  static DrawingDoc fromJson(Map<String, dynamic> j) {
    final at = DateTime.tryParse('${j['addedAt']}');
    if (j['id'] == null || at == null) throw const FormatException('도면 정보가 아닙니다');
    final ps = j['pageSizes'];
    return DrawingDoc(
      id: '${j['id']}',
      name: '${j['name'] ?? ''}',
      kind: DrawingKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => DrawingKind.image),
      ext: '${j['ext'] ?? ''}',
      pages: (j['pages'] as num?)?.toInt() ?? 1,
      pageSizes: ps is List
          ? [for (final s in ps) if (s is List && s.length >= 2) ((s[0] as num).toInt(), (s[1] as num).toInt())]
          : const [],
      pageDpi: j['pageDpi'] is List ? [for (final v in j['pageDpi'] as List) if (v is num) v.toDouble()] : const [],
      addedAt: at,
      openedAt: DateTime.tryParse('${j['openedAt']}') ?? at,
      drawingNo: '${j['drawingNo'] ?? ''}',
      rev: '${j['rev'] ?? ''}',
      title: '${j['title'] ?? ''}',
      openIssues: (j['openIssues'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 파일 이름으로 종류를 정한다. DWG는 null(읽지 못함), 모르는 것도 null.
DrawingKind? kindForName(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.pdf')) return DrawingKind.pdf;
  if (n.endsWith('.dxf')) return DrawingKind.dxf;
  if (n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.webp') || n.endsWith('.bmp') || n.endsWith('.gif') || n.endsWith('.heic')) {
    return DrawingKind.image;
  }
  return null;
}

bool isDwgName(String name) => name.toLowerCase().endsWith('.dwg');

/// DWG를 받았을 때 알려 줄 글.
const String kDwgHelp =
    'DWG는 오토데스크 전용 형식이라 이 앱에서 바로 열 수 없습니다.\n'
    '· 보낸 사람에게 PDF(또는 DXF)로 다시 받는 것이 가장 빠릅니다.\n'
    '· PC가 있으면 무료 프로그램(ODA File Converter)으로 DXF로 바꿔 보내면 이 앱에서 열립니다.';

String _two(int n) => n.toString().padLeft(2, '0');
String markDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

/// 문제 목록을 글로(카톡 보내기).
String buildIssueText(DrawingDoc doc, List<DrawingMark> marks) {
  final issues = issuesOf(marks);
  final b = StringBuffer('[도면 확인] ${doc.displayName}');
  final head = [if (doc.drawingNo.isNotEmpty) '도번 ${doc.drawingNo}', if (doc.rev.isNotEmpty) 'REV ${doc.rev}'].join(' · ');
  if (head.isNotEmpty) b.write('\n$head');
  final open = issues.where((m) => !m.done).length;
  b.write('\n문제 ${issues.length}건 (남은 것 $open건)');
  for (final m in issues) {
    b.write('\n${m.no}. [${m.kind.label}${m.done ? '·해결' : ''}]${doc.pages > 1 ? ' ${m.page + 1}쪽' : ''} ${m.text.isEmpty ? '(내용 없음)' : m.text}');
  }
  final oks = marks.where((m) => m.kind == MarkKind.ok).length;
  if (oks > 0) b.write('\n확인 표시 $oks곳');
  return b.toString();
}
