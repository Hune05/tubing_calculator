// 형강 브라켓 제작도(10-10, 사용자: "간단하게 브라켓을 그릴 수 있는 기능을 따로 빼내서 만들어줘 고도화되면 좋고").
// 모양(ㄱ자·삼각(가새)·문형·T자)과 형강 규격·바깥 치수·구멍을 넣으면 그림(치수·구멍·용접 자리), 자를 길이·끝 모양,
// 구멍 위치, 베이스 판, 볼트·앵커, 원자재 본수, 지시서 PDF·카톡 글. 계산은 bracket_calc.dart.
// 화면 틀은 접지바 가공(busbar_ground_page.dart)과 같다: 겉에는 꼭 넣을 칸, 원자재·부재 폭 등은 "자세히".
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/theme/field_view.dart';
import '../../data/models/steel_shape_db.dart';
import '../common/calc_form_parts.dart';
import '../electrical/busbar_lug.dart' show lugBoltFor;
import '../electrical/busbar_punch_dies.dart';
import '../electrical/busbar_saved_specs.dart';
import '../electrical/elec_form_parts.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'bracket_calc.dart';
import 'bracket_painter.dart';
import 'bracket_pdf.dart';

Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

const List<String> kBracketBasis = [
  '치수는 모두 바깥 치수(mm)입니다. ㄱ자·삼각: 가로대 길이 = 기둥 바깥면(벽)에서 가로대 끝까지, 기둥 높이 = 가로대 윗면에서 기둥 끝까지. 문형·T자: 폭 = 양쪽 바깥면 사이, 높이 = 바닥(베이스 판 밑면)에서 가로대 윗면까지.',
  '이음: 기둥 통과는 가로대가 기둥 옆에 붙어 가로대가 부재 폭만큼 짧아집니다. 가로대 통과는 기둥이 가로대 밑에 붙어 기둥이 짧아집니다. 45° 연귀는 두 토막 모두 바깥 치수 그대로이고 맞닿는 끝을 45°로 자릅니다. T자는 가로대가 기둥 위에 얹힙니다.',
  '부재 폭은 그림 면에서 보이는 폭입니다(앵글은 변, 찬넬은 춤, 평철은 폭, 각파이프는 변). 규격을 고르면 자동으로 들어가고, 찬넬을 눕혀 쓰는 경우처럼 다르면 "자세히"에서 고칩니다.',
  '가새: 중심선이 가로대 밑면의 "가로대 쪽 자리"(바깥 모서리에서)와 기둥 안쪽 면의 "기둥 쪽 자리"(위 바깥에서)를 잇습니다. 두 자리가 같으면 45°입니다. 끝은 가로대 면·기둥 면에 맞게 비스듬히 자르고, 긴 변 = 중심선 길이 + 부재 폭 ÷ 2 × (cotθ + tanθ), 짧은 변은 그만큼 짧습니다. 각도절단기 각도는 직각을 0°로 본 값입니다.',
  '구멍은 자리(중심 거리)만 나타냅니다. 기둥 구멍은 벽에 붙는 면, 가로대 구멍은 위 면(U볼트·클램프용)에 뚫습니다. 거리는 자른 토막의 끝에서 잽니다. 구멍 지름 칩은 접지바 가공의 "내 펀치 금형"과 같습니다.',
  '베이스 판(문형·T자): 기둥마다 한 장, 구멍은 판 가장자리에서 구멍 중심까지 거리로 놓습니다. 그림 오른쪽 아래는 위에서 본 판(구멍 자리)입니다. 기본 150 × 150 × 9, 가장자리 25는 임의 값입니다. 앵커 볼트 규격·묻힘 깊이는 설계도를 따르십시오.',
  '무게는 형강 컷팅과 같은 이론 중량(규격 이름으로 계산), 베이스 판은 철 7.85 g/cm³(구멍 안 뺌)입니다. 원자재 본수는 단관 컷팅과 같은 재단 계산(톱날 여유 포함)입니다.',
  '이 화면은 제작 치수만 계산합니다. 하중·용접 강도 계산은 하지 않으니 무거운 배관·기기를 받치는 브라켓은 설계 검토를 받으십시오.',
];

/// 모양 칩 순서와 저장 값(0 ㄱ자, 1 삼각, 2 문형, 3 T자).
const List<(BracketShape, String)> kBracketShapes = [
  (BracketShape.l, 'ㄱ자'),
  (BracketShape.brace, '삼각(가새)'),
  (BracketShape.frame, '문형'),
  (BracketShape.tee, 'T자'),
];

/// 규격 종류 칩: 이름 → 목록.
final List<(String, List<SteelShapeItem>)> kBracketSpecLists = [
  ('앵글', SteelShapeDB.angles),
  ('찬넬', SteelShapeDB.channels),
  ('평철', SteelShapeDB.flatBars),
  ('각파이프', SteelShapeDB.squarePipes),
];

/// 종류를 바꿀 때 고르는 흔한 규격(목록에 없으면 50x… 첫 규격).
const List<String> kBracketSpecDefaults = [
  '앵글 50x50x5',
  '찬넬 100x50x5',
  '평철 50x6',
  '각파이프 50x50x2.3',
];

class BracketPage extends StatefulWidget {
  const BracketPage({super.key, this.share = _defaultShare});

  /// 결과 글 보내기(시험에서 바꿔 끼운다).
  final Future<void> Function(String text) share;

  static const draftKey = 'steel_bracket_draft_v1';

  @override
  State<BracketPage> createState() => _BracketPageState();
}

class _BracketPageState extends State<BracketPage>
    with
        CalcFormParts<BracketPage>,
        RecentCalcHistoryMixin<BracketPage>,
        ElecTabParts<BracketPage> {
  @override
  String? get calcHistoryStorageKey => 'calc_history_steel_bracket';

  int _shape = 0;
  int _cat = 0;
  String _spec = '앵글 50x50x5';
  int _joint = 0; // 0 기둥 통과, 1 가로대 통과, 2 45° 연귀
  int _postN = 2, _armN = 0;
  bool _plate = true;
  int _plateN = 4;
  List<double> _dies = const [];

  final _job = TextEditingController();
  final _a = TextEditingController(text: '300');
  final _b = TextEditingController(text: '300');
  final _braceA = TextEditingController(text: '210');
  final _braceB = TextEditingController(text: '210');
  final _postDia = TextEditingController(text: '13.5');
  final _postFirst = TextEditingController(text: '80');
  final _postPitch = TextEditingController(text: '150');
  final _armDia = TextEditingController(text: '13.5');
  final _armFirst = TextEditingController(text: '50');
  final _armPitch = TextEditingController(text: '100');
  final _plateSize = TextEditingController(text: '150');
  final _plateT = TextEditingController(text: '9');
  final _plateDia = TextEditingController(text: '13.5');
  final _plateEdge = TextEditingController(text: '25');
  final _sets = TextEditingController(text: '1');
  final _width = TextEditingController(); // 비우면 규격에서
  final _custom = TextEditingController(); // 규격 직접 적기
  final _stock = TextEditingController(text: '6000');
  final _kerf = TextEditingController(text: '2');

  Timer? _saveTimer;
  bool _draftReady = false;

  List<TextEditingController> get _fields => [
    _job,
    _a,
    _b,
    _braceA,
    _braceB,
    _postDia,
    _postFirst,
    _postPitch,
    _armDia,
    _armFirst,
    _armPitch,
    _plateSize,
    _plateT,
    _plateDia,
    _plateEdge,
    _sets,
    _width,
    _custom,
    _stock,
    _kerf,
  ];
  static const _fieldKeys = [
    'jn',
    'a',
    'b',
    'ba',
    'bb',
    'pd',
    'pf',
    'pp',
    'ad',
    'af',
    'ap',
    'ps',
    'pt',
    'pld',
    'ple',
    'n',
    'w',
    'cs',
    'st',
    'kf',
  ];

  @override
  void initState() {
    super.initState();
    _loadDraft();
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
    'sh': _shape,
    'ct': _cat,
    'sp': _spec,
    'jt': _joint,
    'pn': _postN,
    'an': _armN,
    'pl': _plate,
    'pln': _plateN,
    for (var i = 0; i < _fields.length; i++) _fieldKeys[i]: _fields[i].text,
  });

  @override
  Map<String, Object?>? historySnapshot() =>
      jsonDecode(_draft()) as Map<String, dynamic>;

  @override
  void applyHistorySnapshot(Map<String, dynamic> m) => _applyMap(m);

  void _applyMap(Map<String, dynamic> m) {
    int? pick(String k, int max) {
      final v = m[k];
      return v is int && v >= 0 && v <= max ? v : null;
    }

    _shape = pick('sh', 3) ?? _shape;
    _cat = pick('ct', kBracketSpecLists.length - 1) ?? _cat;
    if (m['sp'] is String && (m['sp'] as String).trim().isNotEmpty) {
      _spec = m['sp'] as String;
    }
    _joint = pick('jt', 2) ?? _joint;
    _postN = pick('pn', 3) ?? _postN;
    _armN = pick('an', 5) ?? _armN;
    if (m['pl'] is bool) _plate = m['pl'] as bool;
    final pln = m['pln'];
    if (pln is int && (pln == 0 || pln == 2 || pln == 4)) _plateN = pln;
    for (var i = 0; i < _fields.length; i++) {
      final v = m[_fieldKeys[i]];
      if (v is String) _fields[i].text = v;
    }
  }

  Future<void> _loadDraft() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(BracketPage.draftKey);
      if (raw != null && mounted) {
        setState(() => _applyMap(jsonDecode(raw) as Map<String, dynamic>));
      }
    } catch (_) {}
    _draftReady = true;
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
        .then((p) => p.setString(BracketPage.draftKey, d))
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

  BracketShape get _shapeEnum => kBracketShapes[_shape].$1;
  bool get _lLike => _shape <= 1;

  /// 실제로 쓰는 규격: 직접 적은 것이 있으면 그것.
  String get _specUsed =>
      _custom.text.trim().isNotEmpty ? _custom.text.trim() : _spec;

  /// 부재 폭: 직접 넣은 값, 없으면 규격 첫 치수.
  double get _d => readNum(_width) ?? bracketMemberWidth(_specUsed) ?? 0;

  List<double> get _dieChips => _dies.isEmpty ? kDefaultPunchDies : _dies;

  Future<void> _editDies() async {
    final r = await openPunchDies(context, _dies);
    if (r != null && mounted) setState(() => _dies = r);
  }

  BracketInput _input() => BracketInput(
    shape: _shapeEnum,
    spec: _specUsed,
    d: _d,
    a: _num(_a),
    b: _num(_b),
    joint: BracketJoint.values[_joint],
    braceA: _num(_braceA),
    braceB: _num(_braceB),
    postHoles: _lLike
        ? HoleRow(
            count: _postN,
            dia: _num(_postDia),
            first: _num(_postFirst),
            pitch: _num(_postPitch),
          )
        : const HoleRow(),
    armHoles: HoleRow(
      count: _armN,
      dia: _num(_armDia),
      first: _num(_armFirst),
      pitch: _num(_armPitch),
    ),
    plate: !_lLike && _plate,
    plateSize: _num(_plateSize),
    plateT: _num(_plateT),
    plateHoles: _plateN,
    plateHoleDia: _num(_plateDia),
    plateEdge: _num(_plateEdge),
    sets: _num(_sets).round().clamp(1, 999),
    stockLength: _num(_stock),
    kerf: _num(_kerf),
  );

  bool get _ready => _d > 0 && _num(_a) >= 0 && _num(_b) > 0;

  BracketPlan? _plan() => _ready ? bracketPlan(_input()) : null;

  int get _setCount => _num(_sets).round().clamp(1, 999);

  // ── 글 ──

  String _jointName() {
    if (_shape == 3) return '가로대가 기둥 위에 얹힘';
    return switch (_joint) {
      0 => _shape == 2 ? '기둥 통과(가로대가 기둥 사이)' : '기둥 통과(가로대가 기둥 옆에 붙음)',
      1 => _shape == 2 ? '가로대 통과(가로대가 기둥 위에 얹힘)' : '가로대 통과(기둥이 가로대 밑에 붙음)',
      _ => '45° 연귀',
    };
  }

  String _pieceLine(BracketPiece p) =>
      '${p.name} ${fmt(p.length, 1)}mm${p.short != null ? '(짧은 변 ${fmt(p.short!, 1)})' : ''} × ${p.qty * _setCount}개 · ${p.ends}';

  String _holeLine(BracketPiece p) =>
      '${p.name} 구멍 φ${fmt(p.holes.first.dia)} (${p.holeFrom}에서): ${p.holes.map((h) => fmt(h.fromEnd, 1)).join(' · ')}mm';

  List<String> _boltLines(BracketPlan p) => [
    for (final e in p.boltHoles.entries)
      '볼트 구멍 φ${fmt(e.key)} ${e.value}개 → 볼트 ${lugBoltFor(e.key) ?? "구멍에 맞는 규격"} ${e.value}세트(볼트·너트·평와셔 2·스프링 와셔)',
    for (final e in p.anchorHoles.entries)
      '베이스 판 앵커 구멍 φ${fmt(e.key)} ${e.value}개 → 앵커 볼트 ${lugBoltFor(e.key) ?? "구멍에 맞는 규격"} ${e.value}개(규격·묻힘 깊이는 설계도)',
  ];

  List<String> _stockLines(BracketPlan p) => [
    for (final e in p.stock.entries)
      if (e.value.barCount > 0)
        '${e.key}: ${fmt(e.value.stockLength)}mm 원자재 ${e.value.barCount}본(남는 길이 합 ${fmt(e.value.bars.fold(0.0, (s, b) => s + b.remainderWithKerf(e.value.kerf)), 0)}mm, 톱날 ${fmt(e.value.kerf)}mm)',
  ];

  String? _plateLine(BracketPlan p) {
    final pl = p.plate;
    if (pl == null) return null;
    final holes = pl.holes.isEmpty
        ? '구멍 없음'
        : '구멍 φ${fmt(pl.holeDia)} ${pl.holes.length}개, 구멍 중심 사이 ${fmt(pl.size - 2 * _num(_plateEdge), 1)}mm(가장자리에서 ${fmt(_num(_plateEdge))})';
    return '베이스 판 ${fmt(pl.size)} × ${fmt(pl.size)} × ${fmt(pl.t)}t × ${pl.qty * _setCount}장 · $holes';
  }

  String _shareText(BracketPlan p) {
    final b = StringBuffer(
      '[형강 브라켓] ${kBracketShapes[_shape].$2} · $_specUsed · $_setCount개',
    );
    if (_job.text.trim().isNotEmpty) b.write(' · ${_job.text.trim()}');
    b.write('\n치수: ${_dimText()} (바깥 치수, mm) · ${_jointName()}');
    b.write('\n자를 것:');
    for (final pc in p.pieces) {
      b.write('\n ${_pieceLine(pc)}');
    }
    for (final pc in p.pieces.where((x) => x.holes.isNotEmpty)) {
      b.write('\n${_holeLine(pc)}');
    }
    final pl = _plateLine(p);
    if (pl != null) b.write('\n$pl');
    for (final l in _boltLines(p)) {
      b.write('\n$l');
    }
    for (final l in _stockLines(p)) {
      b.write('\n$l');
    }
    b.write('\n무게 약 ${fmt(p.kgTotal, 1)}kg${p.weightKnown ? '' : ' 이상'}');
    for (final s in p.problems) {
      b.write('\n※ $s');
    }
    return b.toString();
  }

  String _dimText() => switch (_shape) {
    0 => '가로대 ${fmt(_num(_a))} · 기둥 ${fmt(_num(_b))}',
    1 =>
      '가로대 ${fmt(_num(_a))} · 기둥 ${fmt(_num(_b))} · 가새 자리 ${fmt(_num(_braceA))} / ${fmt(_num(_braceB))}',
    2 => '폭 ${fmt(_num(_a))} · 높이 ${fmt(_num(_b))}',
    _ =>
      _num(_a) > 0
          ? '가로대 ${fmt(_num(_a))} · 높이 ${fmt(_num(_b))}'
          : '기둥만 · 높이 ${fmt(_num(_b))}',
  };

  Future<BracketPdfInput> _pdfInput(BracketPlan p) async {
    final png = await renderBracketPng(p.drawing);
    return BracketPdfInput(
      title: _job.text,
      summary: [
        ('모양', '${kBracketShapes[_shape].$2} · ${_jointName()}'),
        ('재료', '$_specUsed (그림 면 폭 ${fmt(_d)}mm)'),
        ('치수', '${_dimText()} (바깥 치수, mm)'),
        (
          '수량',
          '$_setCount개 · 약 ${fmt(p.kgTotal, 1)}kg${p.weightKnown ? '' : ' 이상'}',
        ),
        if (p.braceAngle != null) ('가새', '기울기 ${fmt(p.braceAngle!, 1)}°'),
      ],
      drawingPng: png,
      sections: [
        BracketPdfSection(
          '자를 것',
          const [],
          headers: const ['토막', '규격', '길이(mm)', '끝 모양', '개수'],
          rows: [
            for (final pc in p.pieces)
              [
                pc.name,
                pc.spec,
                pc.short == null
                    ? fmt(pc.length, 1)
                    : '${fmt(pc.length, 1)}\n(짧은 변 ${fmt(pc.short!, 1)})',
                pc.ends,
                '${pc.qty * _setCount}',
              ],
          ],
        ),
        if (p.pieces.any((x) => x.holes.isNotEmpty) || p.plate != null)
          BracketPdfSection('구멍', [
            for (final pc in p.pieces.where((x) => x.holes.isNotEmpty))
              _holeLine(pc),
            ?_plateLine(p),
          ]),
        if (_boltLines(p).isNotEmpty) BracketPdfSection('볼트·앵커', _boltLines(p)),
        if (_stockLines(p).isNotEmpty) BracketPdfSection('원자재', _stockLines(p)),
      ],
      notes: [...p.problems, ...p.notes],
    );
  }

  Future<void> _openSaved() => openSavedSpecs(
    context,
    storageKey: 'steel_bracket_saved_v1',
    current: () => jsonDecode(_draft()) as Map<String, dynamic>,
    summaryOf: (m) {
      final sh = m['sh'] is int && (m['sh'] as int) <= 3
          ? kBracketShapes[m['sh'] as int].$2
          : '';
      final sp = (m['cs'] is String && (m['cs'] as String).trim().isNotEmpty)
          ? m['cs'] as String
          : (m['sp'] is String ? m['sp'] as String : '');
      return '$sh · $sp · ${m['a'] ?? ''} × ${m['b'] ?? ''}';
    },
    defaultName: _job.text.trim().isNotEmpty
        ? _job.text.trim()
        : '${kBracketShapes[_shape].$2} ${_a.text}×${_b.text}',
    onLoad: (m) => _set(() => _applyMap(m)),
    surface: fc.surface,
    text: fc.text,
    textSub: fc.textSub,
  );

  // ── 화면 부품 ──

  Widget _dieChipRow(String keyPrefix, TextEditingController c) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final v in _dieChips)
        calcChip(
          '$keyPrefix${(v * 100).round()}',
          punchDieLabel(v),
          readNum(c) == v,
          () => _set(() => c.text = fmt(v, 3)),
        ),
      calcChip(
        '${keyPrefix}edit',
        _dies.isEmpty ? '내 금형 넣기' : '내 금형 고치기',
        false,
        _editDies,
      ),
    ],
  );

  /// 줄 구멍 입력: 개수 칩·지름(금형 칩)·첫 구멍·피치.
  List<Widget> _holeInputs({
    required String key,
    required String title,
    required String guide,
    required int count,
    required ValueChanged<int> onCount,
    required TextEditingController dia,
    required TextEditingController first,
    required TextEditingController pitch,
    required String firstLabel,
    int max = 3,
  }) => [
    elecChipGroup(title, guide, [
      for (var n = 0; n <= max; n++)
        calcChip(
          '${key}_n$n',
          n == 0 ? '없음' : '$n개',
          count == n,
          () => _set(() => onCount(n)),
        ),
    ]),
    if (count > 0) ...[
      elecField(
        '${key}_dia',
        '구멍 지름 (mm)',
        dia,
        '볼트가 지나는 구멍 지름입니다.',
        onEdit: _saveSoon,
      ),
      _dieChipRow('${key}_d_', dia),
      const SizedBox(height: 8),
      elecField(
        '${key}_first',
        firstLabel,
        first,
        '첫 구멍 중심까지 거리입니다.',
        onEdit: _saveSoon,
      ),
      if (count > 1)
        elecField(
          '${key}_pitch',
          '구멍 피치 (mm)',
          pitch,
          '구멍 중심 사이 거리입니다.',
          onEdit: _saveSoon,
        ),
    ],
  ];

  Widget _pieceTable(BracketPlan p) => KeyedSubtree(
    key: const Key('br_pieces'),
    child: calcBox(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final pc in p.pieces)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pc.name}  ${fmt(pc.length, 1)} mm  × ${pc.qty * _setCount}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: fc.text,
                      ),
                    ),
                    Text(
                      '${pc.spec} · ${pc.ends}${pc.short != null ? ' · 짧은 변 ${fmt(pc.short!, 1)}mm' : ''}${pc.kgEach > 0 ? ' · 개당 ${fmt(pc.kgEach, 2)}kg' : ''}',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: fc.textSub,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = _plan();
    final warn = p != null && !p.ok;
    String? summary;
    final specList = kBracketSpecLists[_cat].$2;
    final shapeGuide = switch (_shape) {
      0 => 'ㄱ자: 벽(기둥)에 붙이고 가로대 위에 튜브·트레이를 얹습니다.',
      1 => '삼각: ㄱ자에 비스듬한 가새를 더해 무거운 것을 받칩니다.',
      2 => '문형: 기둥 둘 위에 가로대. 바닥에 세우는 서포트입니다.',
      _ => 'T자: 기둥 하나 위에 가로대(가로대 0이면 기둥만).',
    };
    final children = <Widget>[
      elecField(
        'br_job',
        '작업 이름 (선택)',
        _job,
        '지시서 PDF 제목과 규격 저장 이름에 쓰입니다. 비워도 됩니다.',
        onEdit: _saveSoon,
      ),
      elecSectionTitle('모양'),
      elecChipGroup('모양', shapeGuide, [
        for (var i = 0; i < kBracketShapes.length; i++)
          calcChip(
            'br_shape_$i',
            kBracketShapes[i].$2,
            _shape == i,
            () => _set(() => _shape = i),
          ),
      ]),
      elecSectionTitle('재료'),
      elecChipGroup('형강 종류', '쓸 형강 종류를 고르고 아래에서 규격을 고릅니다.', [
        for (var i = 0; i < kBracketSpecLists.length; i++)
          calcChip(
            'br_cat_$i',
            kBracketSpecLists[i].$1,
            _cat == i,
            () => _set(() {
              _cat = i;
              final list = kBracketSpecLists[i].$2;
              if (!list.any((s) => s.label == _spec)) {
                // 종류를 바꾸면 그 종류의 흔한 규격으로
                final want = kBracketSpecDefaults[i];
                final pick = list.firstWhere(
                  (s) => s.label == want,
                  orElse: () => list.firstWhere(
                    (s) => s.label.contains('50x'),
                    orElse: () => list.first,
                  ),
                );
                _spec = pick.label;
              }
            }),
          ),
      ]),
      calcDropdown<String>(
        'br_spec',
        '규격',
        specList.any((s) => s.label == _spec) ? _spec : specList.first.label,
        [for (final s in specList) s.label],
        (s) => s,
        (s) => _set(() => _spec = s),
        '목록에 없으면 "자세히"의 "규격 직접 적기"에 넣습니다.',
      ),
      if (_custom.text.trim().isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '직접 적은 규격 "${_custom.text.trim()}"을 씁니다(자세히).',
            style: TextStyle(fontSize: 13, color: fc.textSub),
          ),
        ),
      elecSectionTitle('치수 (바깥, mm)'),
      if (_lLike) ...[
        elecField(
          'br_a',
          '가로대 길이 (mm)',
          _a,
          '기둥 바깥면(벽)에서 가로대 끝까지입니다.',
          onEdit: _saveSoon,
        ),
        elecField(
          'br_b',
          '기둥 높이 (mm)',
          _b,
          '가로대 윗면에서 기둥 끝까지입니다.',
          onEdit: _saveSoon,
        ),
      ] else ...[
        elecField(
          'br_a',
          _shape == 2 ? '폭 (mm)' : '가로대 길이 (mm, 0이면 기둥만)',
          _a,
          _shape == 2 ? '양쪽 기둥 바깥면 사이입니다.' : '가로대 끝에서 끝까지입니다. 기둥은 가운데에 섭니다.',
          onEdit: _saveSoon,
        ),
        elecField(
          'br_b',
          '높이 (mm)',
          _b,
          '바닥(베이스 판 밑면)에서 가로대 윗면까지입니다.',
          onEdit: _saveSoon,
        ),
      ],
      if (_shape == 1) ...[
        elecField(
          'br_ba',
          '가새 가로대 쪽 자리 (mm)',
          _braceA,
          '바깥 모서리에서 가새 중심선이 가로대 밑면에 닿는 곳까지입니다.',
          onEdit: _saveSoon,
        ),
        elecField(
          'br_bb',
          '가새 기둥 쪽 자리 (mm)',
          _braceB,
          '위 바깥 모서리에서 가새 중심선이 기둥 안쪽 면에 닿는 곳까지입니다. 가로대 쪽과 같으면 45°입니다.',
          onEdit: _saveSoon,
        ),
        Wrap(
          spacing: 8,
          children: [
            calcChip('br_brace45', '45°로 맞추기', false, () {
              _set(() => _braceB.text = _braceA.text);
            }),
          ],
        ),
        const SizedBox(height: 8),
      ],
      if (_shape != 3)
        elecChipGroup(
          '이음',
          '기둥 통과: 가로대가 기둥 옆에 붙어 가로대가 짧아집니다. 가로대 통과: 기둥이 가로대 밑에 붙어 기둥이 짧아집니다. 45° 연귀: 맞닿는 끝을 45°로 자릅니다.',
          [
            for (final (i, label) in const [
              (0, '기둥 통과'),
              (1, '가로대 통과'),
              (2, '45° 연귀'),
            ])
              calcChip(
                'br_joint_$i',
                label,
                _joint == i,
                () => _set(() => _joint = i),
              ),
          ],
        ),
      elecField(
        'br_sets',
        '만들 개수',
        _sets,
        '같은 브라켓을 몇 개 만드는지입니다. 자를 것·볼트·원자재에 곱합니다.',
        onEdit: _saveSoon,
      ),
      elecSectionTitle('구멍'),
      if (_lLike)
        ..._holeInputs(
          key: 'br_ph',
          title: '기둥 구멍 (벽 붙임)',
          guide: '기둥이 벽·기둥에 닿는 면에 뚫는 볼트 구멍입니다. 위 바깥 모서리에서 잽니다.',
          count: _postN,
          onCount: (n) => _postN = n,
          dia: _postDia,
          first: _postFirst,
          pitch: _postPitch,
          firstLabel: '위 끝에서 첫 구멍까지 (mm)',
        ),
      ..._holeInputs(
        key: 'br_ah',
        title: '가로대 구멍 (U볼트·클램프)',
        guide: _lLike
            ? '가로대 위 면에 뚫는 구멍입니다. 가로대 끝(벽 반대쪽)에서 잽니다.'
            : '가로대 위 면에 뚫는 구멍입니다. 가로대 왼쪽 끝에서 잽니다.',
        count: _armN,
        onCount: (n) => _armN = n,
        dia: _armDia,
        first: _armFirst,
        pitch: _armPitch,
        firstLabel: _lLike ? '가로대 끝에서 첫 구멍까지 (mm)' : '왼쪽 끝에서 첫 구멍까지 (mm)',
        max: 5,
      ),
      if (!_lLike) ...[
        elecSectionTitle('베이스 판'),
        elecChipGroup('베이스 판', '기둥 밑에 용접하는 판입니다. 바닥에 앵커로 고정합니다.', [
          calcChip(
            'br_plate_on',
            '붙임',
            _plate,
            () => _set(() => _plate = true),
          ),
          calcChip(
            'br_plate_off',
            '안 붙임',
            !_plate,
            () => _set(() => _plate = false),
          ),
        ]),
        if (_plate) ...[
          elecField(
            'br_ps',
            '판 한 변 (mm)',
            _plateSize,
            '정사각 판의 한 변입니다. 기본 150은 임의 값입니다.',
            onEdit: _saveSoon,
          ),
          elecField(
            'br_pt',
            '판 두께 (mm)',
            _plateT,
            '기둥 길이에서 이 두께만큼 뺍니다. 기본 9는 임의 값입니다.',
            onEdit: _saveSoon,
          ),
          elecChipGroup('앵커 구멍', '4개는 네 귀, 2개는 그림 면 좌우 가운데입니다.', [
            for (final n in const [0, 2, 4])
              calcChip(
                'br_pn_$n',
                n == 0 ? '없음' : '$n개',
                _plateN == n,
                () => _set(() => _plateN = n),
              ),
          ]),
          if (_plateN > 0) ...[
            elecField(
              'br_pld',
              '앵커 구멍 지름 (mm)',
              _plateDia,
              '앵커 볼트가 지나는 구멍입니다.',
              onEdit: _saveSoon,
            ),
            _dieChipRow('br_pld_d_', _plateDia),
            const SizedBox(height: 8),
            elecField(
              'br_ple',
              '가장자리에서 구멍까지 (mm)',
              _plateEdge,
              '판 가장자리에서 구멍 중심까지입니다. 기본 25는 임의 값입니다.',
              onEdit: _saveSoon,
            ),
          ],
        ],
      ],
      const SizedBox(height: 4),
      ...elecFold('br_fold_more', '자세히', [
        elecField(
          'br_custom',
          '규격 직접 적기 (비우면 위에서 고른 것)',
          _custom,
          '"앵글 50x50x6"처럼 종류와 치수를 적으면 무게도 계산합니다.',
          onEdit: () => setState(_saveSoon),
        ),
        elecField(
          'br_w',
          '부재 폭 (mm, 비우면 규격에서 ${fmt(bracketMemberWidth(_specUsed) ?? 0)})',
          _width,
          '그림 면에서 보이는 부재 폭입니다. 찬넬을 눕혀 쓰는 경우처럼 규격 첫 치수와 다르면 넣습니다.',
          onEdit: _saveSoon,
        ),
        elecField(
          'br_stock',
          '원자재 길이 (mm)',
          _stock,
          '원자재 한 본 길이입니다. 0이면 본수를 계산하지 않습니다.',
          onEdit: _saveSoon,
        ),
        elecField(
          'br_kerf',
          '톱날 여유 (mm)',
          _kerf,
          '한 번 자를 때 없어지는 길이입니다. 기본 2는 임의 값입니다.',
          onEdit: _saveSoon,
        ),
        elecChipGroup(
          '내 펀치 금형',
          '구멍 지름 칩에 나오는 값입니다. 접지바 가공과 같이 씁니다. 지금: ${_dieChips.map((d) => fmt(d)).join(' · ')}${_dies.isEmpty ? '(기본)' : ''}',
          [
            calcChip(
              'br_dies',
              _dies.isEmpty ? '내 금형 넣기' : '내 금형 고치기',
              false,
              _editDies,
            ),
          ],
        ),
      ], subtitle: '규격 직접 적기 · 부재 폭 · 원자재 길이 · 톱날 여유'),
      const SizedBox(height: 8),
    ];

    if (p == null) {
      children.add(
        calcResult(
          key: const Key('br_result'),
          big: '— mm',
          caption: '규격과 치수를 넣으면 계산합니다',
          lines: const [],
        ),
      );
    } else {
      summary =
          '브라켓 ${kBracketShapes[_shape].$2} · ${p.pieces.map((x) => '${x.name} ${fmt(x.length, 1)}').join(' · ')}';
      children.addAll([
        calcResult(
          key: const Key('br_result'),
          big: p.pieces.map((x) => '${x.name} ${fmt(x.length, 1)}').join(' · '),
          caption:
              '자를 길이(mm) · $_setCount개 · 약 ${fmt(p.kgTotal, 1)}kg${p.weightKnown ? '' : ' 이상'}',
          warn: warn,
          lines: [
            ...p.problems,
            ...p.notes,
            '$_specUsed · 부재 폭 ${fmt(_d)}mm · ${_jointName()}.',
            if (p.braceAngle != null)
              '가새 기울기 ${fmt(p.braceAngle!, 1)}° · 긴 변 ${fmt(p.pieces.last.length, 1)} / 짧은 변 ${fmt(p.pieces.last.short ?? 0, 1)}mm.',
            ?_plateLine(p),
          ],
        ),
        const SizedBox(height: 12),
        calcLabel('그림', '실제 비율입니다. 주황 삼각은 용접 자리, 흰 원은 구멍 자리(중심 거리)입니다.'),
        const SizedBox(height: 4),
        Container(
          key: const Key('br_view'),
          height: 300,
          decoration: BoxDecoration(
            color: fc.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: fc.line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CustomPaint(
              painter: BracketPainter(
                drawing: p.drawing,
                text: fc.text,
                sub: fc.textSub,
                bg: fc.surface,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...elecFold(
          'br_fold_pieces',
          '자를 것',
          [_pieceTable(p)],
          open: true,
          subtitle: '${p.pieces.fold(0, (s, x) => s + x.qty) * _setCount}토막',
        ),
        ...elecFold('br_fold_holes', '구멍 위치 (토막 끝에서 중심까지)', [
          if (p.pieces.any((x) => x.holes.isNotEmpty) || p.plate != null)
            calcResult(
              key: const Key('br_holes'),
              big: '구멍',
              caption: '자른 토막 끝에서 잰 거리',
              lines: [
                for (final pc in p.pieces.where((x) => x.holes.isNotEmpty))
                  _holeLine(pc),
                ?_plateLine(p),
                ..._boltLines(p),
              ],
            ),
        ], open: true),
        ...elecFold('br_fold_stock', '원자재', [
          if (_stockLines(p).isNotEmpty)
            calcResult(
              key: const Key('br_stock_result'),
              big: '${p.stock.values.fold(0, (s, r) => s + r.barCount)}본',
              caption: '자를 것 전부를 원자재에 배치',
              lines: _stockLines(p),
            ),
        ]),
        const SizedBox(height: 8),
        ...elecFold('br_fold_notes', '작업 순서', [
          calcResult(
            key: const Key('br_notes'),
            big: '작업 순서',
            caption: '현장에서 만들 때',
            lines: [
              '자를 것 표대로 형강을 자릅니다. ${_joint == 2 && _shape != 3 ? "연귀 끝은 45°로, " : ""}${_shape == 1 ? "가새 양 끝은 표의 각도로 비스듬히 자르고, " : ""}절단면 버를 갈아 냅니다.',
              '구멍 자리를 토막 끝에서 재어 마킹하고 펀치 금형(없는 크기는 드릴)으로 뚫습니다. 용접 전에 뚫어야 기계에 넣기 쉽습니다.',
              '바깥 치수에 맞춰 직각을 보고 가접한 뒤 대각선 길이를 재어 틀어짐이 없으면 본용접합니다(그림의 주황 삼각 자리).',
              if (_shape == 1) '가새는 가로대·기둥을 먼저 가접해 직각을 잡은 뒤 끼워 맞춥니다.',
              if (!_lLike && _plate)
                '베이스 판은 기둥 밑에 직각으로 용접하고, 판 구멍이 그림 방향과 맞는지 봅니다.',
              '용접부 슬래그를 떼고 녹 방지 도장(현장 기준)을 합니다.',
            ],
          ),
        ]),
      ]);
    }
    children.addAll([
      const SizedBox(height: 12),
      elecBasis('br_basis', kBracketBasis),
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
              '형강 브라켓',
              style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
            ),
            actions: [
              if (p != null)
                IconButton(
                  key: const Key('br_share'),
                  tooltip: '카톡으로 보내기',
                  icon: Icon(Icons.share_outlined, color: fc.text),
                  onPressed: () => widget.share(_shareText(p)),
                ),
              if (p != null)
                IconButton(
                  key: const Key('br_pdf'),
                  tooltip: '가공 지시서 PDF',
                  icon: Icon(Icons.picture_as_pdf_outlined, color: fc.text),
                  onPressed: () => openBracketPdf(context, () => _pdfInput(p)),
                ),
              IconButton(
                key: const Key('br_saved'),
                tooltip: '저장한 규격',
                icon: Icon(Icons.bookmarks_outlined, color: fc.text),
                onPressed: _openSaved,
              ),
              calcHistoryButton(),
            ],
          ),
          body: elecPage(
            children,
            sumKey: 'br_sum',
            summary: summary,
            warn: warn,
          ),
        ),
      ),
    );
  }
}
