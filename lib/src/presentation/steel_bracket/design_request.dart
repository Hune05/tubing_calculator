// 설계팀에 보내기(10-12, 사용자 "외부 업체에 보내는 것보다 내부 설계팀한테 던져주는 식으로"):
// 형강 브라켓·철판 가공 보내기 탭에 "업체에 / 설계팀에"를 두고, 설계팀 쪽은 설계 요청서 PDF(요청 표·요청 사항·
// 현장 사진 + 지금 그림·표는 참고)와 카톡 요약 글을 만든다. 업체용(가공 지시서·DXF)은 그대로.
//  · 사용자 결정(AskUserQuestion): 둘 다 두고 고르게(처음 쪽은 설정), 두 화면 모두, 넘길 것 = 요청서 PDF·현장 사진·카톡 글.
//  · 설정(요청자·받는 곳·보내기 탭 처음)은 두 화면이 같이 쓴다. 요청 내용(현장 위치·필요일·요청 사항·사진)은
//    화면마다 따로 남기고, 저장한 규격·묶음·최근 기록에는 섞지 않는다(요청마다 다른 값이라).
//  · 카톡 바로 보내기는 글만 되므로 사진은 요청서 PDF 안에 넣는다(PDF는 미리보기 "공유하기"로).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/app_components.dart'
    show AppSnackKind, showAppSnack;
import '../../core/theme/field_view.dart';
import '../../core/utils/image_picker_helper.dart';
import '../my_work_logs/models/photo_store.dart' show PhotoImage;
import '../my_work_logs/widgets/fullscreen_photo_viewer.dart';
import '../steel_plate/plate_ui.dart';
import 'bracket_pdf.dart';

const String kDesignSendSettingsKey = 'design_send_settings_v1';

/// 요청서에 넣는 현장 사진 최대 장수.
const int kDesignPhotoMax = 6;

/// 두 화면이 같이 쓰는 설계팀 보내기 설정.
class DesignSendSettings {
  /// 요청자(요청서 "요청" 칸·카톡 글). 비우면 각 화면의 작성자.
  final String requester;

  /// 받는 곳 이름(예: 설계팀, 기계설계팀).
  final String team;

  /// 보내기 탭을 "설계팀에"로 연다.
  final bool designFirst;
  const DesignSendSettings({
    this.requester = '',
    this.team = '설계팀',
    this.designFirst = false,
  });
  static const defaults = DesignSendSettings();

  DesignSendSettings copyWith({
    String? requester,
    String? team,
    bool? designFirst,
  }) => DesignSendSettings(
    requester: requester ?? this.requester,
    team: team ?? this.team,
    designFirst: designFirst ?? this.designFirst,
  );

  String get teamName => team.trim().isEmpty ? '설계팀' : team.trim();

  Map<String, Object> toJson() => {
    'req': requester,
    'team': team,
    'first': designFirst,
  };

  static DesignSendSettings fromJson(Object? o) {
    if (o is! Map) return defaults;
    return DesignSendSettings(
      requester: o['req'] is String ? o['req'] as String : '',
      team: o['team'] is String ? o['team'] as String : '설계팀',
      designFirst: o['first'] == true,
    );
  }

  static Future<DesignSendSettings> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(kDesignSendSettingsKey);
      return raw == null ? defaults : fromJson(jsonDecode(raw));
    } catch (_) {
      return defaults;
    }
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(kDesignSendSettingsKey, jsonEncode(toJson()));
    } catch (_) {}
  }
}

/// 한 화면의 설계 요청 내용(화면마다 따로 남김).
class DesignRequest {
  final String loc;

  /// 필요일 'yyyy-mm-dd'(비우면 없음).
  final String due;
  final String note;
  final List<String> photos;
  const DesignRequest({
    this.loc = '',
    this.due = '',
    this.note = '',
    this.photos = const [],
  });
  static const empty = DesignRequest();

  bool get isEmpty =>
      loc.trim().isEmpty &&
      due.isEmpty &&
      note.trim().isEmpty &&
      photos.isEmpty;

  DesignRequest copyWith({
    String? loc,
    String? due,
    String? note,
    List<String>? photos,
  }) => DesignRequest(
    loc: loc ?? this.loc,
    due: due ?? this.due,
    note: note ?? this.note,
    photos: photos ?? this.photos,
  );

  Map<String, Object> toJson() => {
    'loc': loc,
    'due': due,
    'note': note,
    'ph': photos,
  };

  static DesignRequest fromJson(Object? o) {
    if (o is! Map) return empty;
    String s(String k) => o[k] is String ? o[k] as String : '';
    final ph = o['ph'];
    return DesignRequest(
      loc: s('loc'),
      due: s('due'),
      note: s('note'),
      photos: ph is List
          ? [
              for (final x in ph)
                if (x is String) x,
            ]
          : const [],
    );
  }

  static Future<DesignRequest> load(String key) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(key);
      return raw == null ? empty : fromJson(jsonDecode(raw));
    } catch (_) {
      return empty;
    }
  }

  Future<void> save(String key) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(key, jsonEncode(toJson()));
    } catch (_) {}
  }
}

String designDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 보내기 탭 맨 위: 업체에 / 설계팀에.
Widget designTargetRow(
  String keyPrefix, {
  required bool design,
  required String team,
  required ValueChanged<bool> onChanged,
}) => PlateSegments([
  PlateOption(
    '${keyPrefix}_to_vendor',
    '업체에 보내기',
    !design,
    () => onChanged(false),
  ),
  PlateOption(
    '${keyPrefix}_to_design',
    '$team에 보내기',
    design,
    () => onChanged(true),
  ),
]);

/// 설계 요청 칸: 현장 위치 · 필요일 · 요청 사항 · 현장 사진 · 비우기.
class DesignRequestFields extends StatefulWidget {
  const DesignRequestFields({
    super.key,
    required this.keyPrefix,
    required this.value,
    required this.onChanged,
  });
  final String keyPrefix;
  final DesignRequest value;
  final ValueChanged<DesignRequest> onChanged;

  @override
  State<DesignRequestFields> createState() => _DesignRequestFieldsState();
}

class _DesignRequestFieldsState extends State<DesignRequestFields> {
  late final TextEditingController _loc = TextEditingController(
    text: widget.value.loc,
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.value.note,
  );

  @override
  void didUpdateWidget(DesignRequestFields old) {
    super.didUpdateWidget(old);
    // 밖에서 바뀐 값(비우기·되돌리기)만 칸에 다시 넣는다(입력 중 커서가 튀지 않게)
    if (_loc.text != widget.value.loc) _loc.text = widget.value.loc;
    if (_note.text != widget.value.note) _note.text = widget.value.note;
  }

  @override
  void dispose() {
    _loc.dispose();
    _note.dispose();
    super.dispose();
  }

  DesignRequest get _v => widget.value;
  String get _p => widget.keyPrefix;

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final cur = DateTime.tryParse(_v.due);
    final d = await showDatePicker(
      context: context,
      initialDate: cur ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d != null && mounted) widget.onChanged(_v.copyWith(due: designDay(d)));
  }

  Future<void> _addPhotos() async {
    final left = kDesignPhotoMax - _v.photos.length;
    if (left <= 0) return;
    final picked = await ImagePickerHelper.pickImages(context, maxCount: left);
    if (picked.isEmpty || !mounted) return;
    widget.onChanged(
      _v.copyWith(
        photos: [..._v.photos, ...picked].take(kDesignPhotoMax).toList(),
      ),
    );
  }

  void _removePhoto(int i) {
    final ph = [..._v.photos]..removeAt(i);
    widget.onChanged(_v.copyWith(photos: ph));
  }

  void _clear() {
    final before = _v;
    widget.onChanged(DesignRequest.empty);
    showAppSnack(
      context,
      '설계 요청 칸을 비웠습니다.',
      kind: AppSnackKind.undo,
      onUndo: () {
        if (mounted) widget.onChanged(before);
      },
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: fc.fill,
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: fc.textFaint,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: fc.brand, width: 1.6),
    ),
  );

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      s,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: fc.textSub,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final v = _v;
    final style = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: fc.text,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlateNumField(
          fieldKey: '${_p}_rq_loc',
          label: '현장 위치 (라인·구역·높이)',
          controller: _loc,
          unit: null,
          text: true,
          hint: '예) 2호기 보일러 3층 EL+12000',
          onChanged: (t) => widget.onChanged(v.copyWith(loc: t)),
        ),
        const SizedBox(height: 12),
        _label('필요일'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: Key('${_p}_rq_due'),
                onPressed: _pickDue,
                icon: const Icon(Icons.event_outlined, size: 20),
                label: Text(v.due.isEmpty ? '고르기 (비워도 됩니다)' : v.due),
              ),
            ),
            if (v.due.isNotEmpty)
              IconButton(
                key: Key('${_p}_rq_due_clear'),
                tooltip: '필요일 지우기',
                onPressed: () => widget.onChanged(v.copyWith(due: '')),
                icon: Icon(Icons.close_rounded, color: fc.textSub),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _label('요청 사항'),
        TextField(
          key: Key('${_p}_rq_note'),
          controller: _note,
          minLines: 3,
          maxLines: 6,
          style: style,
          decoration: _deco('예) 배관 2줄 받칠 브라켓, 기존 H빔에 용접, 보온 50 포함'),
          onChanged: (t) => widget.onChanged(v.copyWith(note: t)),
        ),
        const SizedBox(height: 12),
        _label('현장 사진 (${v.photos.length}/$kDesignPhotoMax, 요청서 PDF에 들어갑니다)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, path) in v.photos.indexed)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    key: Key('${_p}_rq_photo_$i'),
                    onTap: () => FullscreenPhotoViewer.show(
                      context: context,
                      photos: v.photos,
                      initialIndex: i,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: PhotoImage(path, width: 76, height: 76),
                    ),
                  ),
                  Positioned(
                    right: -6,
                    top: -6,
                    child: InkWell(
                      key: Key('${_p}_rq_photo_del_$i'),
                      onTap: () => _removePhoto(i),
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: fc.text,
                        child: Icon(Icons.close, size: 14, color: fc.surface),
                      ),
                    ),
                  ),
                ],
              ),
            if (v.photos.length < kDesignPhotoMax)
              InkWell(
                key: Key('${_p}_rq_photo_add'),
                borderRadius: BorderRadius.circular(8),
                onTap: _addPhotos,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: fc.fill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: fc.brand),
                      const SizedBox(height: 4),
                      Text(
                        '사진 추가',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: fc.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (!v.isEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: Key('${_p}_rq_clear'),
              onPressed: _clear,
              child: const Text('새 요청 (칸 비우기)'),
            ),
          ),
      ],
    );
  }
}

/// 설정 화면에 넣는 구역: 요청자 · 받는 곳 · 보내기 탭 처음.
class DesignSendSettingsSection extends StatefulWidget {
  const DesignSendSettingsSection({super.key, this.authorHint});

  /// 요청자를 비웠을 때 쓰는 이름(형강 브라켓 작성자) 안내.
  final String? authorHint;

  @override
  State<DesignSendSettingsSection> createState() =>
      _DesignSendSettingsSectionState();
}

class _DesignSendSettingsSectionState extends State<DesignSendSettingsSection> {
  DesignSendSettings _s = DesignSendSettings.defaults;
  final _req = TextEditingController();
  final _team = TextEditingController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    DesignSendSettings.load().then((s) {
      if (!mounted) return;
      setState(() {
        _s = s;
        _req.text = s.requester;
        _team.text = s.team;
        _ready = true;
      });
    });
  }

  @override
  void dispose() {
    _req.dispose();
    _team.dispose();
    super.dispose();
  }

  void _update(DesignSendSettings s) {
    setState(() => _s = s);
    s.save();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    return PlateSection('설계팀에 보내기', [
      plateRow([
        PlateNumField(
          fieldKey: 'ds_req',
          label: '요청자',
          controller: _req,
          unit: null,
          text: true,
          hint: widget.authorHint == null || widget.authorHint!.isEmpty
              ? '요청서에 들어갈 이름'
              : '비우면 ${widget.authorHint}',
          onChanged: (t) => _update(_s.copyWith(requester: t)),
        ),
        PlateNumField(
          fieldKey: 'ds_team',
          label: '받는 곳',
          controller: _team,
          unit: null,
          text: true,
          hint: '설계팀',
          onChanged: (t) => _update(_s.copyWith(team: t)),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Text(
          '보내기 탭을 열면 처음 보이는 쪽',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: fc.textSub,
          ),
        ),
      ),
      PlateSegments([
        PlateOption(
          'ds_first_vendor',
          '업체에',
          !_s.designFirst,
          () => _update(_s.copyWith(designFirst: false)),
        ),
        PlateOption(
          'ds_first_design',
          '${_s.teamName}에',
          _s.designFirst,
          () => _update(_s.copyWith(designFirst: true)),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          '형강 브라켓·철판 가공이 같이 씁니다. 설계팀 쪽은 설계 요청서 PDF(요청 표·요청 사항·현장 사진, 그림·표는 참고)와 카톡 요약 글을 만듭니다.',
          style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.4),
        ),
      ),
    ]);
  }
}

/// 요청서 사진(작게 줄인 JPG). 못 읽은 사진은 뺀다.
Future<List<(String, Uint8List)>> designPhotoBytes(List<String> paths) async {
  final out = <(String, Uint8List)>[];
  for (final (i, p) in paths.indexed) {
    Uint8List? b;
    try {
      b = await FlutterImageCompress.compressWithFile(
        p,
        minWidth: 1000,
        minHeight: 1000,
        quality: 70,
      );
    } catch (_) {}
    if (b == null) {
      try {
        b = await File(p).readAsBytes();
      } catch (_) {}
    }
    if (b != null && b.isNotEmpty) out.add(('사진 ${i + 1}', b));
  }
  return out;
}

/// 업체용 지시서 입력을 설계 요청서로: 맨 위 요청 표·요청 사항, 그림·표는 참고, 업체 몫(원자재·작업 노트·가공비)·서명 칸 뺌.
BracketPdfInput designPdfFrom(
  BracketPdfInput v, {
  required String docTitle,
  required DesignSendSettings settings,
  required DesignRequest request,
  required String requester,
  required String qty,
  required List<(String, Uint8List)> photos,
  DateTime? today,
  Set<String> dropSections = const {'원자재', '일반 노트'},
  Set<String> dropSummary = const {},
}) {
  final day = designDay(today ?? DateTime.now());
  final note = request.note.trim();
  return BracketPdfInput(
    title: v.title,
    docTitle: docTitle,
    titleBlock: [
      ('받는 곳', settings.teamName),
      ('요청자', requester.trim().isEmpty ? '-' : requester.trim()),
      ('요청일', day),
      ('필요일', request.due.isEmpty ? '-' : request.due),
      ('현장 위치', request.loc.trim().isEmpty ? '-' : request.loc.trim()),
      ('수량', qty),
    ],
    summary: [
      for (final r in v.summary)
        if (!dropSummary.contains(r.$1)) r,
    ],
    drawingPng: v.drawingPng,
    drawingCaption: '현장에서 정한 모양(참고) · ${v.drawingCaption}',
    drawingHeight: v.drawingHeight,
    moreDrawings: v.moreDrawings,
    moreHeight: v.moreHeight,
    moreAfterSections: v.moreAfterSections,
    // 요청 사항은 요청 표 바로 아래(그림 앞)
    leadSections: [
      BracketPdfSection('요청 사항', [
        if (note.isEmpty)
          '-'
        else
          ...note.split('\n').where((l) => l.trim().isNotEmpty),
      ]),
    ],
    sections: [
      for (final s in v.sections)
        if (!dropSections.contains(s.title)) s,
    ],
    photos: photos,
    notes: v.notes,
    author: requester,
    // 사내로 던지는 것이라 서명 칸(요청·접수·확인)은 안 넣는다(10-12 사용자 "사내에 보낼 때는 아래 요청 이런 거 필요 없어")
    signs: const [],
  );
}

/// 카톡 요약 글: 어디·무엇·몇 개·언제까지 + 요청 사항.
String designShareText({
  required String what,
  required String job,
  required DesignSendSettings settings,
  required DesignRequest request,
  required String requester,
  required List<String> body,
  DateTime? today,
}) {
  final b = StringBuffer('[설계 요청] $what');
  if (job.trim().isNotEmpty) b.write(' · ${job.trim()}');
  b.write('\n받는 곳 ${settings.teamName}');
  if (requester.trim().isNotEmpty) b.write(' · 요청 ${requester.trim()}');
  b.write(' · ${designDay(today ?? DateTime.now())}');
  if (request.loc.trim().isNotEmpty) b.write('\n현장 위치: ${request.loc.trim()}');
  if (request.due.isNotEmpty) b.write('\n필요일: ${request.due}');
  for (final l in body) {
    b.write('\n$l');
  }
  final note = request.note.trim();
  if (note.isNotEmpty) b.write('\n요청 사항: $note');
  b.write(
    '\n그림·치수${request.photos.isEmpty ? '' : '·현장 사진 ${request.photos.length}장'}은 설계 요청서 PDF로 보냅니다.',
  );
  return b.toString();
}
