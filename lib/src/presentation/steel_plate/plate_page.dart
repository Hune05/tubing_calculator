// 철판 가공(10-10): 3t·4t 같은 철판을 레이저로 자르기만 하거나(평판·삼각 리브·자유 모양) 잘라서 꺾는(ㄱ·ㄷ·Z·모자)
// 브라켓의 전개도·꺾기선·구멍·무게를 계산하고, 레이저 업체에 보낼 DXF와 가공 지시서 PDF·카톡 글을 만든다.
// 계산은 plate_calc.dart, 꺾기는 부스바 절곡 계산을 그대로 쓴다. 화면 틀은 형강 브라켓·접지바와 같다.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/common_widgets/swipe_to_delete.dart';
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import '../electrical/busbar_bend_painter.dart' show BusbarShapePainter;
import '../electrical/busbar_punch_dies.dart';
import '../electrical/busbar_saved_specs.dart';
import '../electrical/elec_form_parts.dart';
import '../steel_bracket/bracket_pdf.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'plate_calc.dart';
import 'plate_dxf.dart';
import 'plate_painter.dart';

Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

const List<String> kPlateBasis = [
  '가공: "레이저 절단만"은 평판·삼각 리브·자유 모양을 자르기만 하고, "절단 + 절곡"은 ㄱ·ㄷ·Z·모자로 꺾습니다. 꺾는 것은 전개도(펴 놓은 모양)를 자른 뒤 꺾기선에서 꺾습니다.',
  '꺾음 치수는 모두 바깥 치수입니다. 전개 길이 = 바깥 치수 합 − 꺾는 곳마다 공제값. 공제값(90°) = 2 × (안쪽 반경 + 두께) − π/2 × (안쪽 반경 + k × 두께). k를 모르면 일반값 0.33을 쓰고, 업체가 알려 준 공제값을 넣으면 그 값이 나오게 k를 맞춥니다. 꺾기 계산은 부스바 가공과 같은 식입니다.',
  '안쪽 반경은 비우면 두께와 같게 봅니다. 레이저 업체·절곡기 금형마다 공제값이 다르니 처음 주문 때 업체 값으로 맞추고 "이 두께 값 저장"으로 남겨 두십시오.',
  '꺾기선은 꺾는 부분의 가운데 선입니다. "위로"는 DXF·전개도를 위에서 본 쪽으로 꺾는다는 뜻입니다. 모자는 발 → 다리 → 윗면 → 다리 → 발 차례로 위로·아래로·아래로·위로 꺾습니다.',
  '구멍 자리: 평판·리브·자유 모양은 판의 왼쪽 아래 모서리에서 잰 (가로, 세로)입니다. 꺾음은 면마다 잽니다: 가로는 그 면 시작(첫 면은 판 끝, 다른 면은 앞 면 바깥면)에서, 세로는 아래 가장자리에서. 전개도 자리로 바꿔 DXF에 넣습니다.',
  '구멍은 꺾기선에서 2 × 두께 + 안쪽 반경 이상 떼라고 알립니다(일반 판금 규칙). 구멍이 꺾이는 부분에 걸리거나 판 밖으로 나오거나 서로 겹치면 만들 수 없다고 알립니다.',
  '짧은 면: 바깥 치수가 두께의 5배보다 짧으면 절곡기 V홈(보통 두께의 6~8배)에 걸치지 못할 수 있다고 알립니다. 업체 금형에 따라 다릅니다.',
  'DXF: AutoCAD R12 형식, 단위 mm. CUT 층(외곽·구멍·장공), BEND 층(꺾기선), NOTE 층(꺾는 방향 영문 글). 대부분의 레이저 업체 프로그램이 읽습니다.',
  '무게 = (외곽 넓이 − 구멍 넓이) × 두께 × 밀도(철판 7.85 · 스테인리스 7.93 · 알루미늄 2.70 g/cm³).',
  '이 화면은 제작 치수만 계산합니다. 하중·강도는 계산하지 않습니다.',
];

/// 가공 방식별 모양 칩(모양, 이름).
const List<(PlateShape, String)> kPlateCutShapes = [
  (PlateShape.flat, '평판'),
  (PlateShape.rib, '삼각 리브'),
  (PlateShape.free, '자유 모양'),
];
const List<(PlateShape, String)> kPlateBendShapes = [
  (PlateShape.l, 'ㄱ자'),
  (PlateShape.u, 'ㄷ자'),
  (PlateShape.z, 'Z자'),
  (PlateShape.hat, '모자'),
];

String plateShapeName(PlateShape s) =>
    [...kPlateCutShapes, ...kPlateBendShapes].firstWhere((e) => e.$1 == s).$2;

class PlatePage extends StatefulWidget {
  const PlatePage({super.key, this.share = _defaultShare, this.shareDxf});

  final Future<void> Function(String text) share;

  /// DXF 보내기(시험에서 바꿔 끼운다). null이면 공유 창.
  final Future<void> Function(String dxf)? shareDxf;

  static const draftKey = 'steel_plate_draft_v1';
  static const bendTableKey = 'plate_bend_table_v1';

  @override
  State<PlatePage> createState() => _PlatePageState();
}

class _PlatePageState extends State<PlatePage>
    with
        CalcFormParts<PlatePage>,
        RecentCalcHistoryMixin<PlatePage>,
        ElecTabParts<PlatePage> {
  @override
  String? get calcHistoryStorageKey => 'calc_history_steel_plate';

  bool _bend = true;
  PlateShape _shape = PlateShape.l;
  PlateMaterial _mat = PlateMaterial.steel;
  final List<PlateHoleGroup> _holes = [];
  Map<String, (double, double)> _bendTable = {};
  List<double> _dies = const [];

  final _job = TextEditingController();
  final _t = TextEditingController(text: '3');
  final _len = TextEditingController(text: '200');
  final _wid = TextEditingController(text: '100');
  final _cornerR = TextEditingController(text: '0');
  final _l1 = TextEditingController(text: '50');
  final _l2 = TextEditingController(text: '50');
  final _l3 = TextEditingController(text: '50');
  final _angle = TextEditingController(text: '90');
  final _ribA = TextEditingController(text: '100');
  final _ribB = TextEditingController(text: '100');
  final _ribC = TextEditingController(text: '15');
  final _points = TextEditingController(
    text: '0,0\n200,0\n200,80\n120,150\n0,150',
  );
  final _r = TextEditingController();
  final _bd = TextEditingController();
  final _qty = TextEditingController(text: '1');

  Timer? _saveTimer;
  bool _draftReady = false;

  List<TextEditingController> get _fields => [
    _job,
    _t,
    _len,
    _wid,
    _cornerR,
    _l1,
    _l2,
    _l3,
    _angle,
    _ribA,
    _ribB,
    _ribC,
    _points,
    _r,
    _bd,
    _qty,
  ];
  static const _fieldKeys = [
    'jn',
    't',
    'len',
    'wid',
    'cr',
    'l1',
    'l2',
    'l3',
    'ang',
    'ra',
    'rb',
    'rc',
    'pts',
    'r',
    'bd',
    'n',
  ];

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _loadBendTable();
    readPunchDies().then((d) {
      if (mounted && d.isNotEmpty) setState(() => _dies = d);
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveNow();
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  String _draft() => jsonEncode({
    'bend': _bend,
    'sh': _shape.name,
    'mat': _mat.name,
    'holes': [for (final h in _holes) h.toJson()],
    for (var i = 0; i < _fields.length; i++) _fieldKeys[i]: _fields[i].text,
  });

  @override
  Map<String, Object?>? historySnapshot() =>
      jsonDecode(_draft()) as Map<String, dynamic>;

  @override
  void applyHistorySnapshot(Map<String, dynamic> m) => _applyMap(m);

  void _applyMap(Map<String, dynamic> m) {
    if (m['bend'] is bool) _bend = m['bend'] as bool;
    final sh = PlateShape.values.where((s) => s.name == m['sh']);
    if (sh.isNotEmpty) _shape = sh.first;
    final mat = PlateMaterial.values.where((s) => s.name == m['mat']);
    if (mat.isNotEmpty) _mat = mat.first;
    // 가공 방식과 모양이 어긋나면 그 방식의 첫 모양으로
    if (plateShapeBends(_shape) != _bend) {
      _shape = _bend ? PlateShape.l : PlateShape.flat;
    }
    final hs = m['holes'];
    if (hs is List) {
      _holes
        ..clear()
        ..addAll(hs.map(PlateHoleGroup.fromJson).whereType<PlateHoleGroup>());
    }
    for (var i = 0; i < _fields.length; i++) {
      final v = m[_fieldKeys[i]];
      if (v is String) _fields[i].text = v;
    }
  }

  Future<void> _loadDraft() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(PlatePage.draftKey);
      if (raw != null && mounted) {
        setState(() => _applyMap(jsonDecode(raw) as Map<String, dynamic>));
      }
    } catch (_) {}
    _draftReady = true;
  }

  Future<void> _loadBendTable() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(PlatePage.bendTableKey);
      if (raw == null) return;
      final m = jsonDecode(raw);
      if (m is! Map) return;
      final out = <String, (double, double)>{};
      m.forEach((k, v) {
        if (k is String && v is Map && v['r'] is num && v['bd'] is num) {
          out[k] = ((v['r'] as num).toDouble(), (v['bd'] as num).toDouble());
        }
      });
      if (mounted) setState(() => _bendTable = out);
    } catch (_) {}
  }

  Future<void> _saveBendTable() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        PlatePage.bendTableKey,
        jsonEncode({
          for (final e in _bendTable.entries)
            e.key: {'r': e.value.$1, 'bd': e.value.$2},
        }),
      );
    } catch (_) {}
  }

  void _saveSoon() {
    if (!_draftReady) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _saveNow);
  }

  void _saveNow() {
    if (!_draftReady) return;
    final d = _draft();
    SharedPreferences.getInstance()
        .then((p) => p.setString(PlatePage.draftKey, d))
        .catchError((_) => false);
  }

  void _set(VoidCallback f) {
    setState(f);
    _saveSoon();
  }

  double _num(TextEditingController c) {
    final v = readNum(c);
    return v == null || v < 0 ? 0 : v;
  }

  String get _tKey => fmt(_num(_t));

  /// 두께를 바꾸면 저장한 그 두께의 반경·공제값을 채운다(없으면 비움 = 일반값).
  void _setThickness(String v) => _set(() {
    _t.text = v;
    final saved = _bendTable[_tKey];
    _r.text = saved == null ? '' : fmt(saved.$1);
    _bd.text = saved == null ? '' : fmt(saved.$2);
  });

  PlateInput _input() => PlateInput(
    shape: _shape,
    material: _mat,
    t: _num(_t),
    length: _num(_len),
    width: _num(_wid),
    cornerR: _num(_cornerR),
    legs: [_num(_l1), _num(_l2), _num(_l3)],
    angle: readNum(_angle) ?? 90,
    r: readNum(_r),
    bd90: readNum(_bd),
    ribA: _num(_ribA),
    ribB: _num(_ribB),
    ribC: _num(_ribC),
    points: parsePlatePoints(_points.text),
    holes: List.of(_holes),
    qty: _num(_qty).round().clamp(1, 9999),
  );

  bool get _ready => _num(_t) > 0;
  PlatePlan? _plan() => _ready ? platePlan(_input()) : null;
  int get _qtyN => _num(_qty).round().clamp(1, 9999);

  // ── 글 ──

  String _dimsText() => switch (_shape) {
    PlateShape.flat =>
      '${fmt(_num(_len))} × ${fmt(_num(_wid))}${_num(_cornerR) > 0 ? ' · 모서리 R${fmt(_num(_cornerR))}' : ''}',
    PlateShape.rib =>
      '${fmt(_num(_ribA))} × ${fmt(_num(_ribB))}${_num(_ribC) > 0 ? ' · 모서리 따내기 ${fmt(_num(_ribC))}' : ''}',
    PlateShape.free => '꼭짓점 ${parsePlatePoints(_points.text).length}개',
    PlateShape.l =>
      '1면 ${fmt(_num(_l1))} · 2면 ${fmt(_num(_l2))} · 폭 ${fmt(_num(_wid))} · ${fmt(readNum(_angle) ?? 90)}°',
    PlateShape.u || PlateShape.z =>
      '1면 ${fmt(_num(_l1))} · ${_shape == PlateShape.z ? '높이' : '2면'} ${fmt(_num(_l2))} · 3면 ${fmt(_num(_l3))} · 폭 ${fmt(_num(_wid))}',
    PlateShape.hat =>
      '발 ${fmt(_num(_l1))} · 높이 ${fmt(_num(_l2))} · 윗면 ${fmt(_num(_l3))} · 폭 ${fmt(_num(_wid))}',
  };

  String _bendLine(PlatePlan p, int n) {
    final b = p.bends[n];
    return '꺾기 ${n + 1}: 왼쪽 끝에서 ${fmt(b.center, 1)}mm(가운데 선, 꺾는 부분 ${fmt(b.start, 1)}~${fmt(b.end, 1)}) · ${b.turn >= 0 ? '위로' : '아래로'} ${fmt(b.turn.abs())}°';
  }

  String _holeLine(PlatePlan p, PlateHole h) {
    final kind = h.slot > 0
        ? '장공 ${fmt(h.dia)}×${fmt(h.slot)}(${h.slotAlongX ? '가로' : '세로'})'
        : 'φ${fmt(h.dia)}';
    final face = plateShapeBends(_shape)
        ? '${p.faceNames[h.face.clamp(0, p.faceNames.length - 1)]} ${fmt(h.u, 1)}·${fmt(h.v, 1)} → '
        : '';
    return '${h.label} $kind: $face전개도 ${fmt(h.c.dx, 1)} · ${fmt(h.c.dy, 1)}';
  }

  String _bendCond(PlatePlan p) =>
      '안쪽 반경 ${fmt(p.rUsed)} · 공제값(90°) ${fmt(p.bd90Used, 2)}mm · k ${p.kUsed.toStringAsFixed(2)}${readNum(_bd) == null ? '(일반값)' : '(넣은 공제값)'}';

  String _shareText(PlatePlan p) {
    final b = StringBuffer(
      '[철판 가공] ${plateShapeName(_shape)} · ${kPlateMaterials[_mat]!.$1} ${fmt(_num(_t))}t · $_qtyN장',
    );
    if (_job.text.trim().isNotEmpty) b.write(' · ${_job.text.trim()}');
    b.write(
      '\n치수: ${_dimsText()} (mm${plateShapeBends(_shape) ? ', 바깥 치수' : ''})',
    );
    b.write(
      '\n${_bend ? '전개' : '판'} 크기: ${fmt(p.flatLength, 1)} × ${fmt(p.flatWidth, 1)}mm · 장당 약 ${fmt(p.kgEach, 2)}kg',
    );
    if (p.bends.isNotEmpty) {
      b.write('\n${_bendCond(p)}');
      for (var n = 0; n < p.bends.length; n++) {
        b.write('\n ${_bendLine(p, n)}');
      }
    }
    if (p.holes.isNotEmpty) {
      b.write('\n구멍 ${p.holes.length}개(전개도 왼쪽 아래에서 가로 · 세로):');
      for (final h in p.holes) {
        b.write('\n ${_holeLine(p, h)}');
      }
    }
    for (final s in p.problems) {
      b.write('\n※ $s');
    }
    return b.toString();
  }

  Future<BracketPdfInput> _pdfInput(PlatePlan p) async {
    final flat = await renderPainterPng(
      PlatePainter(
        plan: p,
        text: const Color(0xFF1F2933),
        sub: const Color(0xFF55636D),
        bg: Colors.white,
        fontScale: 2.2,
      ),
    );
    final more = <(String, Uint8List)>[];
    if (p.bendPlan != null) {
      final t = _num(_t);
      more.add((
        '꺾은 모양 (옆에서)',
        await renderPainterPng(
          BusbarShapePainter(
            plan: p.bendPlan!,
            rho: p.rUsed + p.kUsed * t,
            thickness: t,
            text: const Color(0xFF1F2933),
            sub: const Color(0xFF55636D),
            line: const Color(0xFFD1D5DB),
          ),
          width: 1200,
          height: 600,
        ),
      ));
    }
    return BracketPdfInput(
      title: _job.text,
      docTitle: '철판 가공 지시서',
      drawingCaption: _bend ? '전개도 (mm, 주황 점선 = 꺾기선)' : '판 모양 (mm)',
      drawingPng: flat,
      moreDrawings: more,
      summary: [
        ('가공', _bend ? '레이저 절단 + 절곡' : '레이저 절단만'),
        ('모양', '${plateShapeName(_shape)} · ${_dimsText()}'),
        ('재질', '${kPlateMaterials[_mat]!.$1} ${fmt(_num(_t))}t'),
        (
          _bend ? '전개 크기' : '판 크기',
          '${fmt(p.flatLength, 1)} × ${fmt(p.flatWidth, 1)} mm',
        ),
        (
          '수량',
          '$_qtyN장 · 장당 약 ${fmt(p.kgEach, 2)}kg · 모두 약 ${fmt(p.kgTotal, 1)}kg',
        ),
        if (p.bends.isNotEmpty) ('꺾기 조건', _bendCond(p)),
      ],
      sections: [
        if (p.bends.isNotEmpty)
          BracketPdfSection(
            '꺾기 (전개도 왼쪽 끝에서, mm)',
            const [],
            headers: const ['번호', '가운데 선', '꺾는 부분', '방향', '각도'],
            rows: [
              for (var n = 0; n < p.bends.length; n++)
                [
                  '${n + 1}',
                  fmt(p.bends[n].center, 1),
                  '${fmt(p.bends[n].start, 1)} ~ ${fmt(p.bends[n].end, 1)}',
                  p.bends[n].turn >= 0 ? '위로' : '아래로',
                  '${fmt(p.bends[n].turn.abs())}°',
                ],
            ],
          ),
        if (p.holes.isNotEmpty)
          BracketPdfSection(
            '구멍 (전개도 왼쪽 아래에서, mm)',
            const [],
            headers: const ['번호', '모양', '가로', '세로', '면 기준'],
            rows: [
              for (final h in p.holes)
                [
                  h.label,
                  h.slot > 0
                      ? '장공 ${fmt(h.dia)}×${fmt(h.slot)}'
                      : 'φ${fmt(h.dia)}',
                  fmt(h.c.dx, 1),
                  fmt(h.c.dy, 1),
                  plateShapeBends(_shape)
                      ? '${p.faceNames[h.face.clamp(0, p.faceNames.length - 1)]} ${fmt(h.u, 1)} · ${fmt(h.v, 1)}'
                      : '-',
                ],
            ],
          ),
      ],
      notes: [...p.problems, ...p.notes],
    );
  }

  Future<void> _sendDxf(PlatePlan p) async {
    if (widget.shareDxf != null) {
      await widget.shareDxf!(plateDxf(p, thickness: _num(_t)));
      return;
    }
    await sharePlateDxf(
      p,
      thickness: _num(_t),
      title: _job.text.trim().isEmpty
          ? '${plateShapeName(_shape)}_${fmt(_num(_t))}t'
          : _job.text.trim(),
      message:
          '철판 가공 DXF · ${kPlateMaterials[_mat]!.$1} ${fmt(_num(_t))}t · $_qtyN장${p.bends.isNotEmpty ? ' · 꺾기 ${p.bends.length}곳(BEND 층, 방향은 NOTE 층)' : ''}',
    );
  }

  Future<void> _openSaved() => openSavedSpecs(
    context,
    storageKey: 'steel_plate_saved_v1',
    current: () => jsonDecode(_draft()) as Map<String, dynamic>,
    summaryOf: (m) {
      final sh = PlateShape.values.where((s) => s.name == m['sh']);
      return '${sh.isEmpty ? '' : plateShapeName(sh.first)} · ${m['t'] ?? ''}t · 구멍 묶음 ${m['holes'] is List ? (m['holes'] as List).length : 0}';
    },
    defaultName: _job.text.trim().isNotEmpty
        ? _job.text.trim()
        : '${plateShapeName(_shape)} ${_t.text}t',
    onLoad: (m) => _set(() => _applyMap(m)),
    surface: fc.surface,
    text: fc.text,
    textSub: fc.textSub,
  );

  // ── 구멍 묶음 ──

  String _groupText(PlateHoleGroup g) {
    final kind = g.slot > g.dia
        ? '장공 ${fmt(g.dia)}×${fmt(g.slot)}(${g.slotAlongX ? '가로' : '세로'})'
        : 'φ${fmt(g.dia)}';
    final faces = plateFaceNames(_shape);
    final face = plateShapeBends(_shape)
        ? '${faces[g.face.clamp(0, faces.length - 1)]} · '
        : '';
    if (g.corners) {
      return '$face네 귀 $kind · 가장자리에서 ${fmt(g.x)} / ${fmt(g.y)}';
    }
    return '$face$kind × ${g.count} · 첫 구멍 ${fmt(g.x)}, ${fmt(g.y)}${g.count > 1 ? ' · ${g.rowAlongX ? '가로' : '세로'} ${fmt(g.pitch)} 간격' : ''}';
  }

  Future<void> _editHole({int? index, PlateHoleGroup? preset}) async {
    final g = await showModalBottomSheet<PlateHoleGroup>(
      context: context,
      isScrollControlled: true,
      backgroundColor: fc.surface,
      builder: (_) => _HoleSheet(
        initial: index != null ? _holes[index] : preset,
        bent: plateShapeBends(_shape),
        flat: _shape == PlateShape.flat,
        faces: plateFaceNames(_shape),
        dies: _dies.isEmpty ? kDefaultPunchDies : _dies,
        text: fc.text,
        sub: fc.textSub,
      ),
    );
    if (g == null || !mounted) return;
    _set(() {
      if (index != null) {
        _holes[index] = g;
      } else {
        _holes.add(g);
      }
    });
  }

  List<Widget> _holeList() => [
    for (var n = 0; n < _holes.length; n++)
      SwipeToDelete(
        key: ValueKey('pl_hole_$n${_holes[n].hashCode}'),
        itemKey: ValueKey('pl_hole_item_$n${_holes[n].hashCode}'),
        onDelete: () {
          final removed = _holes[n];
          final at = n;
          _set(() => _holes.removeAt(n));
          showDeleteUndo(
            context,
            '구멍 묶음 ${at + 1}',
            onUndo: () =>
                _set(() => _holes.insert(at.clamp(0, _holes.length), removed)),
          );
        },
        child: Material(
          color: fc.surface,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            key: Key('pl_hole_$n'),
            dense: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: fc.line),
            ),
            title: Text(
              '구멍 묶음 ${n + 1}',
              style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
            ),
            subtitle: Text(
              _groupText(_holes[n]),
              style: TextStyle(color: fc.textSub),
            ),
            trailing: Icon(Icons.edit_outlined, color: fc.textSub),
            onTap: () => _editHole(index: n),
          ),
        ),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = _plan();
    final warn = p != null && !p.ok;
    String? summary;
    final shapes = _bend ? kPlateBendShapes : kPlateCutShapes;
    final bent = plateShapeBends(_shape);
    final children = <Widget>[
      elecField(
        'pl_job',
        '작업 이름 (선택)',
        _job,
        '지시서 PDF·DXF 파일 이름과 규격 저장 이름에 쓰입니다. 비워도 됩니다.',
        onEdit: _saveSoon,
      ),
      elecSectionTitle('가공'),
      elecChipGroup(
        '가공 방식',
        '레이저 절단만: 평판·삼각 리브·자유 모양을 자르기만 합니다. 절단 + 절곡: 잘라서 ㄱ·ㄷ·Z·모자로 꺾습니다.',
        [
          calcChip('pl_cut', '레이저 절단만', !_bend, () {
            _set(() {
              _bend = false;
              if (plateShapeBends(_shape)) _shape = PlateShape.flat;
            });
          }),
          calcChip('pl_bend', '절단 + 절곡', _bend, () {
            _set(() {
              _bend = true;
              if (!plateShapeBends(_shape)) _shape = PlateShape.l;
            });
          }),
        ],
      ),
      elecChipGroup('모양', _shapeGuide(), [
        for (final (s, name) in shapes)
          calcChip(
            'pl_shape_${s.name}',
            name,
            _shape == s,
            () => _set(() => _shape = s),
          ),
      ]),
      elecSectionTitle('재질·두께'),
      elecChipGroup('재질', '무게 계산에만 씁니다.', [
        for (final m in PlateMaterial.values)
          calcChip(
            'pl_mat_${m.name}',
            kPlateMaterials[m]!.$1,
            _mat == m,
            () => _set(() => _mat = m),
          ),
      ]),
      elecField(
        'pl_t',
        '두께 (mm)',
        _t,
        '철판 두께입니다.',
        onEdit: () => setState(_saveSoon),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final v in const ['2', '3', '4', '6'])
            calcChip(
              'pl_t_$v',
              '${v}t',
              _t.text.trim() == v,
              () => _setThickness(v),
            ),
        ],
      ),
      const SizedBox(height: 8),
      elecSectionTitle(bent ? '치수 (바깥, mm)' : '치수 (mm)'),
      ..._dimFields(),
      elecField(
        'pl_qty',
        '수량 (장)',
        _qty,
        '같은 것을 몇 장 만드는지입니다.',
        onEdit: _saveSoon,
      ),
      elecSectionTitle('구멍·장공'),
      if (_holes.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '구멍이 없습니다. 아래에서 넣습니다.',
            style: TextStyle(color: fc.textSub),
          ),
        ),
      ..._holeList(),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          calcChip('pl_hole_add', '구멍 넣기', false, () => _editHole()),
          if (_shape == PlateShape.flat)
            calcChip(
              'pl_hole_corners',
              '네 귀 구멍',
              false,
              () => _editHole(
                preset: const PlateHoleGroup(
                  dia: 13.5,
                  corners: true,
                  x: 20,
                  y: 20,
                ),
              ),
            ),
          calcChip(
            'pl_hole_slot',
            '장공 넣기',
            false,
            () => _editHole(
              preset: const PlateHoleGroup(dia: 13.5, slot: 30, x: 25, y: 25),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (bent)
        ...elecFold(
          'pl_fold_bendset',
          '꺾기 조건 (안쪽 반경·공제값)',
          [
            elecField(
              'pl_r',
              '안쪽 반경 (mm, 비우면 두께)',
              _r,
              '절곡기 금형의 꺾는 안쪽 반경입니다.',
              onEdit: () => setState(_saveSoon),
            ),
            elecField(
              'pl_bd',
              '90° 공제값 (mm, 비우면 일반값)',
              _bd,
              '업체가 알려 준 공제값(바깥 치수 두 개 합 − 전개 길이)입니다. 넣으면 이 값이 나오게 맞춥니다.',
              onEdit: () => setState(_saveSoon),
            ),
            if (p != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '지금: ${_bendCond(p)}',
                  key: const Key('pl_bendcond'),
                  style: TextStyle(color: fc.textSub, height: 1.35),
                ),
              ),
            elecChipGroup(
              '저장한 공제값',
              _bendTable.isEmpty
                  ? '저장한 값이 없습니다. 업체 값을 넣고 "이 두께 값 저장"을 누르면 두께를 고를 때 채워집니다.'
                  : _bendTable.entries
                        .map(
                          (e) =>
                              '${e.key}t: R${fmt(e.value.$1)} · 공제 ${fmt(e.value.$2)}',
                        )
                        .join(' / '),
              [
                calcChip('pl_bd_save', '이 두께 값 저장', false, () {
                  if (p == null) return;
                  _set(() => _bendTable[_tKey] = (p.rUsed, p.bd90Used));
                  _saveBendTable();
                }),
                if (_bendTable.containsKey(_tKey))
                  calcChip('pl_bd_forget', '이 두께 저장 지우기', false, () {
                    _set(() => _bendTable.remove(_tKey));
                    _saveBendTable();
                  }),
              ],
            ),
          ],
          subtitle: p == null
              ? null
              : '공제 ${fmt(p.bd90Used, 2)} · R${fmt(p.rUsed)}${readNum(_bd) == null ? ' (일반값)' : ''}',
        ),
      const SizedBox(height: 8),
    ];

    if (p == null) {
      children.add(
        calcResult(
          key: const Key('pl_result'),
          big: '— mm',
          caption: '두께와 치수를 넣으면 계산합니다',
          lines: const [],
        ),
      );
    } else {
      final size = '${fmt(p.flatLength, 1)} × ${fmt(p.flatWidth, 1)} mm';
      summary = '철판 ${plateShapeName(_shape)} · ${fmt(_num(_t))}t · $size';
      children.addAll([
        calcResult(
          key: const Key('pl_result'),
          big: size,
          caption:
              '${_bend ? '전개 크기' : '판 크기'} · ${kPlateMaterials[_mat]!.$1} ${fmt(_num(_t))}t · 장당 약 ${fmt(p.kgEach, 2)}kg · $_qtyN장 약 ${fmt(p.kgTotal, 1)}kg',
          warn: warn,
          lines: [
            ...p.problems,
            ...p.notes,
            if (p.bends.isNotEmpty) _bendCond(p),
            for (var n = 0; n < p.bends.length; n++) _bendLine(p, n),
            if (p.holes.isNotEmpty)
              '구멍 ${p.holes.length}개(전개도 자리는 아래 "구멍 자리").',
          ],
        ),
        const SizedBox(height: 12),
        calcLabel(
          _bend ? '전개도' : '판 모양',
          '실제 비율입니다. 주황 점선은 꺾기선(번호·방향·각도), 아래 숫자는 왼쪽 끝에서 꺾기선까지 거리입니다.',
        ),
        const SizedBox(height: 4),
        _box(
          const Key('pl_view'),
          260,
          PlatePainter(plan: p, text: fc.text, sub: fc.textSub, bg: fc.surface),
        ),
        if (p.bendPlan != null) ...[
          const SizedBox(height: 12),
          calcLabel('꺾은 모양', '옆에서 본 실제 비율입니다. 번호는 꺾기 번호와 같습니다.'),
          const SizedBox(height: 4),
          _box(
            const Key('pl_side'),
            170,
            BusbarShapePainter(
              plan: p.bendPlan!,
              rho: p.rUsed + p.kUsed * _num(_t),
              thickness: _num(_t),
              text: fc.text,
              sub: fc.textSub,
              line: fc.line,
            ),
          ),
        ],
        const SizedBox(height: 12),
        ...elecFold(
          'pl_fold_holes',
          '구멍 자리 (전개도 왼쪽 아래에서)',
          [
            if (p.holes.isNotEmpty)
              calcResult(
                key: const Key('pl_holes'),
                big: '구멍 ${p.holes.length}개',
                caption: bent ? '면 기준 → 전개도 자리(가로 · 세로)' : '판 왼쪽 아래에서 가로 · 세로',
                lines: [for (final h in p.holes) _holeLine(p, h)],
              ),
          ],
          open: true,
          subtitle: '${p.holes.length}개',
        ),
        ...elecFold('pl_fold_order', '레이저 업체에 보낼 때', [
          calcResult(
            key: const Key('pl_order'),
            big: '주문 메모',
            caption: 'DXF와 같이 알려 줄 것',
            lines: [
              '재질·두께·수량: ${kPlateMaterials[_mat]!.$1} ${fmt(_num(_t))}t · $_qtyN장.',
              'DXF는 위 오른쪽 단추로 보냅니다. CUT 층만 자르고 BEND 층은 꺾기선(자르지 않음)이라고 알립니다.',
              if (p.bends.isNotEmpty)
                '꺾기 ${p.bends.length}곳: 방향은 DXF를 위에서 본 쪽 기준(NOTE 층 UP/DOWN), 안쪽 반경 ${fmt(p.rUsed)}mm. 업체 공제값이 다르면 그 값을 받아 "꺾기 조건"에 넣고 다시 보냅니다.',
              '구멍 둘레·외곽 버(찌꺼기)는 받은 뒤 갈아 냅니다. 녹 방지 도장은 현장 기준을 따릅니다.',
            ],
          ),
        ]),
      ]);
    }
    children.addAll([
      const SizedBox(height: 12),
      elecBasis('pl_basis', kPlateBasis),
    ]);

    return FieldViewTheme(
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: fc.background,
          appBar: AppBar(
            backgroundColor: fc.surface,
            foregroundColor: fc.text,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              '철판 가공',
              style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
            ),
            actions: [
              if (p != null)
                IconButton(
                  key: const Key('pl_share'),
                  tooltip: '카톡으로 보내기',
                  icon: Icon(Icons.share_outlined, color: fc.text),
                  onPressed: () => widget.share(_shareText(p)),
                ),
              if (p != null)
                IconButton(
                  key: const Key('pl_dxf'),
                  tooltip: 'DXF 보내기 (레이저 업체)',
                  icon: Icon(Icons.architecture_outlined, color: fc.text),
                  onPressed: () => _sendDxf(p),
                ),
              if (p != null)
                IconButton(
                  key: const Key('pl_pdf'),
                  tooltip: '가공 지시서 PDF',
                  icon: Icon(Icons.picture_as_pdf_outlined, color: fc.text),
                  onPressed: () => openBracketPdf(
                    context,
                    () => _pdfInput(p),
                    previewTitle: '철판 가공 지시서 미리보기',
                    filePrefix: 'steel_plate',
                  ),
                ),
              IconButton(
                key: const Key('pl_saved'),
                tooltip: '저장한 규격',
                icon: Icon(Icons.bookmarks_outlined, color: fc.text),
                onPressed: _openSaved,
              ),
              calcHistoryButton(),
            ],
          ),
          body: elecPage(
            children,
            sumKey: 'pl_sum',
            summary: summary,
            warn: warn,
          ),
        ),
      ),
    );
  }

  String _shapeGuide() => switch (_shape) {
    PlateShape.flat => '평판: 사각 판에 구멍·장공. 모서리를 둥글게 할 수 있습니다.',
    PlateShape.rib => '삼각 리브: ㄱ자 안쪽에 용접하는 보강판. 직각 모서리를 따내 용접 자리를 비웁니다.',
    PlateShape.free => '자유 모양: 꼭짓점을 차례로 넣어 아무 모양이나 만듭니다.',
    PlateShape.l => 'ㄱ자: 한 번 꺾습니다(각도를 바꿀 수 있습니다).',
    PlateShape.u => 'ㄷ자: 같은 쪽으로 두 번 꺾습니다.',
    PlateShape.z => 'Z자: 반대쪽으로 두 번 꺾어 단을 만듭니다.',
    PlateShape.hat => '모자: 발 → 다리 → 윗면 → 다리 → 발, 네 번 꺾습니다.',
  };

  List<Widget> _dimFields() {
    Widget f(String key, String label, TextEditingController c, String guide) =>
        elecField(key, label, c, guide, onEdit: _saveSoon);
    return switch (_shape) {
      PlateShape.flat => [
        f('pl_len', '가로 (mm)', _len, '판 가로 길이입니다.'),
        f('pl_wid', '세로 (mm)', _wid, '판 세로 길이입니다.'),
        f('pl_cr', '모서리 R (mm, 0이면 직각)', _cornerR, '네 모서리를 둥글게 자르는 반경입니다.'),
      ],
      PlateShape.rib => [
        f('pl_ra', '가로 변 (mm)', _ribA, '직각을 낀 아래 변 길이입니다.'),
        f('pl_rb', '세로 변 (mm)', _ribB, '직각을 낀 세운 변 길이입니다.'),
        f(
          'pl_rc',
          '모서리 따내기 (mm, 0이면 없음)',
          _ribC,
          'ㄱ자 안쪽 모서리 용접 비드를 피하려고 직각 모서리를 45°로 따내는 길이입니다.',
        ),
      ],
      PlateShape.free => [
        calcLabel(
          '꼭짓점 (가로,세로 한 줄에 하나)',
          '판 외곽 꼭짓점을 차례로 넣습니다. 예) 0,0 다음 줄 200,0. 마지막 점은 첫 점으로 저절로 이어집니다.',
        ),
        const SizedBox(height: 4),
        calcBox(
          child: TextField(
            key: const Key('pl_points'),
            controller: _points,
            maxLines: 7,
            minLines: 4,
            keyboardType: TextInputType.multiline,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: fc.text,
            ),
            decoration: const InputDecoration(border: InputBorder.none),
            onChanged: (_) => setState(_saveSoon),
          ),
        ),
        const SizedBox(height: 8),
      ],
      PlateShape.l => [
        f('pl_l1', '1면 (mm)', _l1, '판 끝에서 2면 바깥면까지입니다.'),
        f('pl_l2', '2면 (mm)', _l2, '판 끝에서 1면 바깥면까지입니다.'),
        f('pl_wid', '폭 (mm)', _wid, '꺾는 선 방향 길이입니다.'),
        f('pl_ang', '꺾는 각도 (°)', _angle, '90이면 직각입니다.'),
      ],
      PlateShape.u => [
        f('pl_l1', '1면 (mm)', _l1, '판 끝에서 2면 바깥면까지입니다.'),
        f('pl_l2', '2면 (mm)', _l2, '양쪽 면 바깥면 사이입니다.'),
        f('pl_l3', '3면 (mm)', _l3, '판 끝에서 2면 바깥면까지입니다.'),
        f('pl_wid', '폭 (mm)', _wid, '꺾는 선 방향 길이입니다.'),
      ],
      PlateShape.z => [
        f('pl_l1', '1면 (mm)', _l1, '판 끝에서 세운 면 바깥면까지입니다.'),
        f('pl_l2', '높이 (mm)', _l2, '1면 아랫면에서 3면 윗면까지(바깥)입니다.'),
        f('pl_l3', '3면 (mm)', _l3, '판 끝에서 세운 면 바깥면까지입니다.'),
        f('pl_wid', '폭 (mm)', _wid, '꺾는 선 방향 길이입니다.'),
      ],
      PlateShape.hat => [
        f('pl_l1', '발 (mm)', _l1, '다리 바깥면에서 발 끝까지입니다(양쪽 같음).'),
        f('pl_l2', '높이 (mm)', _l2, '발 바닥면에서 윗면까지입니다(바깥).'),
        f('pl_l3', '윗면 (mm)', _l3, '양쪽 다리 바깥면 사이입니다.'),
        f('pl_wid', '폭 (mm)', _wid, '꺾는 선 방향 길이입니다.'),
      ],
    };
  }

  Widget _box(Key key, double height, CustomPainter painter) => Container(
    key: key,
    height: height,
    decoration: BoxDecoration(
      color: fc.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: fc.line),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(painter: painter, child: const SizedBox.expand()),
    ),
  );
}

/// 구멍 묶음 넣기·고치기 창.
class _HoleSheet extends StatefulWidget {
  const _HoleSheet({
    required this.initial,
    required this.bent,
    required this.flat,
    required this.faces,
    required this.dies,
    required this.text,
    required this.sub,
  });
  final PlateHoleGroup? initial;
  final bool bent, flat;
  final List<String> faces;
  final List<double> dies;
  final Color text, sub;

  @override
  State<_HoleSheet> createState() => _HoleSheetState();
}

class _HoleSheetState extends State<_HoleSheet> {
  late final PlateHoleGroup? g = widget.initial;
  late bool _slot = (g?.slot ?? 0) > 0;
  late bool _slotX = g?.slotAlongX ?? true;
  late bool _corners = (g?.corners ?? false) && widget.flat;
  late bool _rowX = g?.rowAlongX ?? true;
  late int _face = (g?.face ?? 0).clamp(0, widget.faces.length - 1);
  late final _dia = TextEditingController(text: fmtSheet(g?.dia ?? 13.5));
  late final _slotLen = TextEditingController(
    text: fmtSheet((g?.slot ?? 0) > 0 ? g!.slot : 30),
  );
  late final _x = TextEditingController(text: fmtSheet(g?.x ?? 25));
  late final _y = TextEditingController(text: fmtSheet(g?.y ?? 25));
  late final _n = TextEditingController(text: '${g?.count ?? 1}');
  late final _pitch = TextEditingController(text: fmtSheet(g?.pitch ?? 50));

  static String fmtSheet(double v) {
    var s = v.toStringAsFixed(2);
    while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  @override
  void dispose() {
    for (final c in [_dia, _slotLen, _x, _y, _n, _pitch]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _v(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Widget _chip(String key, String label, bool sel, VoidCallback onTap) =>
      ChoiceChip(
        key: Key(key),
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(onTap),
      );

  Widget _field(String key, String label, TextEditingController c) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      key: Key(key),
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, isDense: true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final xLabel = _corners
        ? '가장자리에서 가로 거리 (mm)'
        : widget.bent
        ? '면 시작에서 (mm)'
        : '왼쪽 끝에서 첫 구멍 (mm)';
    final yLabel = _corners
        ? '가장자리에서 세로 거리 (mm)'
        : widget.bent
        ? '아래 가장자리에서 (mm)'
        : '아래 끝에서 첫 구멍 (mm)';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initial == null ? '구멍 넣기' : '구멍 고치기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: widget.text,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  _chip('hs_round', '둥근 구멍', !_slot, () => _slot = false),
                  _chip('hs_slot', '장공', _slot, () => _slot = true),
                ],
              ),
              const SizedBox(height: 8),
              _field('hs_dia', _slot ? '장공 폭 (mm)' : '구멍 지름 (mm)', _dia),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in widget.dies)
                    ActionChip(
                      key: Key('hs_die_${(d * 100).round()}'),
                      label: Text(punchDieLabel(d)),
                      onPressed: () => setState(() => _dia.text = fmtSheet(d)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_slot) ...[
                _field('hs_slotlen', '장공 전체 길이 (mm)', _slotLen),
                Wrap(
                  spacing: 8,
                  children: [
                    _chip('hs_slotx', '가로로 긴 장공', _slotX, () => _slotX = true),
                    _chip(
                      'hs_sloty',
                      '세로로 긴 장공',
                      !_slotX,
                      () => _slotX = false,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (widget.bent) ...[
                Text('구멍이 있는 면', style: TextStyle(color: widget.sub)),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var k = 0; k < widget.faces.length; k++)
                      _chip(
                        'hs_face_$k',
                        widget.faces[k],
                        _face == k,
                        () => _face = k,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (widget.flat)
                Wrap(
                  spacing: 8,
                  children: [
                    _chip('hs_row', '줄로 놓기', !_corners, () => _corners = false),
                    _chip('hs_corners', '네 귀', _corners, () => _corners = true),
                  ],
                ),
              const SizedBox(height: 8),
              _field('hs_x', xLabel, _x),
              _field('hs_y', yLabel, _y),
              if (!_corners) ...[
                _field('hs_n', '개수', _n),
                _field('hs_pitch', '피치 (다음 구멍까지, mm)', _pitch),
                Wrap(
                  spacing: 8,
                  children: [
                    _chip('hs_rowx', '가로로 늘어놓기', _rowX, () => _rowX = true),
                    _chip('hs_rowy', '세로로 늘어놓기', !_rowX, () => _rowX = false),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('hs_ok'),
                  onPressed: () {
                    final dia = _v(_dia);
                    if (dia == null || dia <= 0) return;
                    Navigator.pop(
                      context,
                      PlateHoleGroup(
                        face: widget.bent ? _face : 0,
                        dia: dia,
                        slot: _slot ? (_v(_slotLen) ?? 0) : 0,
                        slotAlongX: _slotX,
                        corners: _corners,
                        count: (_v(_n) ?? 1).round().clamp(1, 99),
                        x: _v(_x) ?? 0,
                        y: _v(_y) ?? 0,
                        pitch: _v(_pitch) ?? 0,
                        rowAlongX: _rowX,
                      ),
                    );
                  },
                  child: Text(widget.initial == null ? '넣기' : '고치기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
