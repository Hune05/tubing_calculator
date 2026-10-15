// 형강 브라켓 제작도(10-10, 10-11 개편 — 사용자: "형강 브라켓 쪽도 싹 뜯어고치자, 상용 앱과 비교 분석하고" → "전부 진행해").
// 화면 틀은 철판 가공과 같다(plate_ui.dart): 위 그림 칸(조립도·부재도·3D) + 아래 작업판 탭(모양·부재·구멍·판·결과·보내기).
//  · 계산: bracket_calc.dart(모양·토막·용접·판), bracket_load.dart(하중 참고), 그림: bracket_painter.dart·bracket_piece_drawing.dart.
//  · 입력은 지도 하나(bracket_form.dart)로 남기고 저장한 규격·최근 기록·묶음이 같이 쓴다.
//  · 비교 문서: docs/형강브라켓_상용앱_비교_1011.md.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/app_components.dart'
    show AppSnackKind, showAppConfirm, showAppSnack;
import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/theme/app_icon_set.dart';
import '../../core/theme/field_view.dart';
import '../calculator/widgets/swipe_delete.dart' show calcNavCompact;
import '../common/app_icons.dart';
import '../common/preset_menu.dart';
import '../common/calc_form_parts.dart';
import '../electrical/busbar_lug.dart' show lugBoltFor;
import '../electrical/busbar_punch_dies.dart'
    show kDefaultPunchDies, openPunchDies, punchDieLabel, readPunchDies;
import '../electrical/busbar_saved_specs.dart';
import '../electrical/elec_form_parts.dart';
import '../steel_cutting/screens/steel_cutting_detail_screen.dart';
import '../steel_plate/plate_3d_view.dart';
import '../steel_plate/plate_page.dart';
import '../steel_plate/plate_ui.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'bracket_3d.dart';
import 'bracket_bundle.dart';
import 'bracket_calc.dart';
import 'bracket_export.dart';
import 'bracket_form.dart';
import 'bracket_load.dart';
import 'bracket_painter.dart';
import 'bracket_pdf.dart';
import 'bracket_piece_drawing.dart';
import 'bracket_settings.dart';
import 'design_request.dart';

export 'bracket_form.dart' show kBracketShapes, kBracketSpecLists;

Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

void _defaultOpenPlate(BuildContext context, Map<String, Object?> initial) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PlatePage(bend: false, initial: initial)),
  );
}

/// 근거·약속(? 단추).
const List<String> kBracketBasis = [
  '치수는 모두 바깥 치수(mm)입니다. ㄱ자·삼각: 가로대 길이 = 벽(벽 붙임 판이 있으면 판 뒷면)에서 가로대 끝까지, 기둥 높이 = 가로대 윗면에서 기둥 끝까지. 문형·T자: 폭 = 양쪽 바깥면 사이, 높이 = 바닥(베이스 판 밑면)에서 가로대 윗면까지. 천장 매달기: 천장에서 가로대 윗면까지.',
  '이음: 기둥 통과는 가로대가 기둥 옆에 붙어 가로대가 기둥 폭만큼 짧아집니다. 가로대 통과는 기둥이 가로대 밑에 붙어 기둥이 짧아집니다. 연귀는 두 토막 모두 바깥 치수 그대로이고 맞닿는 끝을 비스듬히 자릅니다(두 부재 폭이 같으면 45°).',
  '방향: 형강을 어느 쪽으로 놓는지에 따라 그림에 보이는 폭이 다릅니다(찬넬 등이 벽에 → 날개 폭, 날개가 벽에 → 춤). 그림 오른쪽 "단면"이 놓은 모양이고, 주황 선이 벽에 붙는 쪽(가로대는 위)입니다.',
  '홀: 기둥 홀은 벽에 붙는 면, 가로대 홀은 위 면에 뚫습니다. 이 면들은 조립도에서 옆으로 보여 점선(숨은선)으로만 나오니, 홀 자리는 부재도(아래 = 홀 뚫는 면)를 보십시오. 거리는 토막 기준 끝(부재도 왼쪽)에서 잽니다. 게이지는 붙는 면의 등 쪽 가장자리(앵글은 등, 찬넬 날개는 웨브 쪽)에서 홀 중심까지이고, 비우면 평평한 곳 가운데입니다.',
  '홀 끝 거리: 홀 중심이 토막 끝에서 홀 지름의 1.2배보다 가까우면 알립니다(EN 1993-1-8 표 3.3 최소값).',
  '용접 기호: 화살표 → 기준선, 아래 삼각은 필릿(화살표 쪽), "z5"는 각장 5mm, 꺾이는 곳 원은 전둘레입니다. 각장을 비우면 이음마다 얇은 쪽 두께(6 넘으면 6)를 씁니다. 같은 이음이 여러 곳이면 한 곳만 그리고 "2곳"으로 적습니다.',
  '판: 베이스 판(문형·T자)은 기둥마다 한 장, 벽 붙임 판(ㄱ자·삼각)은 기둥 뒤에 한 장입니다. 판 크기·두께·가장자리 거리 처음 값은 임의 값이니 설계도를 따르십시오. 앵커 규격·묻힘 깊이도 설계도를 따르십시오.',
  '무게는 형강 컷팅과 같은 이론 중량(규격 이름으로 계산), 판은 철 7.85 g/cm³(홀 안 뺌)입니다. 원자재 본수는 단관 컷팅과 같은 재단 계산(톱날 여유 포함, 설정에서 바꿈)입니다.',
  '하중 확인은 참고값입니다(AISC 허용응력 꼴, 이음을 핀·캔틸레버로 단순하게 봄). 용접·앵커 자체 강도, 비틀림·옆 힘(지진·바람)은 보지 않으니 무거운 배관·기기를 받치는 브라켓은 설계 검토를 받으십시오.',
];

class BracketPage extends StatefulWidget {
  const BracketPage({
    super.key,
    this.share = _defaultShare,
    this.createProject,
    this.openPlate = _defaultOpenPlate,
  });

  /// 결과 글 보내기(시험에서 바꿔 끼운다).
  final Future<void> Function(String text) share;

  /// 형강 컷팅 작업 만들기(시험에서 바꿔 끼운다, null이면 서버).
  final BracketProjectCreator? createProject;

  /// 판을 철판 가공 화면으로 넘기기(시험에서 바꿔 끼운다).
  final void Function(BuildContext context, Map<String, Object?> initial)
  openPlate;

  static const draftKey = 'steel_bracket_draft_v1';
  static const savedKey = 'steel_bracket_saved_v1';

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

  final Map<String, TextEditingController> _c = {
    for (final e in kBracketTextDefaults.entries)
      e.key: TextEditingController(text: e.value),
  };
  final Map<String, Object> _v = Map.of(kBracketValueDefaults);
  BracketSettings _settings = BracketSettings.defaults;
  List<double> _dies = const [];

  /// 설계팀에 보내기(10-12): 같이 쓰는 설정, 이 화면 요청 내용, 보내기 탭에서 고른 쪽.
  static const String _rqKey = 'steel_bracket_design_request_v1';
  DesignSendSettings _ds = DesignSendSettings.defaults;
  DesignRequest _rq = DesignRequest.empty;
  bool _toDesign = false;
  int _tab = 0;

  /// 그림 보기: asm 조립도, piece 부재도, 3d 입체.
  String _view = 'asm';
  int _pieceMark = 1;
  int _bundleCount = 0;

  Timer? _saveTimer;
  bool _draftReady = false;

  static const _tabs = [
    ('shape', '모양'),
    ('member', '부재'),
    ('holes', '홀·판'),
    ('result', '결과'),
    ('send', '보내기'),
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveNow();
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── 입력 남기기 ──

  Map<String, dynamic> _draftMap() => {
    ..._v,
    for (final e in _c.entries) e.key: e.value.text,
  };

  @override
  Map<String, Object?>? historySnapshot() => _draftMap();

  @override
  void applyHistorySnapshot(Map<String, dynamic> m) => _applyMap(m);

  void _applyMap(Map<String, dynamic> raw) {
    // 저장본에 없는 칸은 처음 값으로(지금 화면 값이 섞이지 않게, 점검 29)
    final m = <String, dynamic>{
      ...kBracketTextDefaults,
      ...kBracketValueDefaults,
      'mat': _settings.material,
      'fin': _settings.finish,
      ...bracketUpgradeMap(raw),
    };
    for (final e in kBracketValueDefaults.entries) {
      final v = m[e.key];
      // 빈 글자는 처음 값으로 두되, 가새 규격 빈 글자는 "평철 맞춤"이라는 뜻
      final ok =
          v != null &&
          v.runtimeType == e.value.runtimeType &&
          !(v is String && v.trim().isEmpty && e.key != 'bsp');
      _v[e.key] = ok ? v as Object : e.value;
    }
    _v['sh'] = (_v['sh'] as int).clamp(0, kBracketShapes.length - 1);
    for (final e in _c.entries) {
      final v = m[e.key];
      if (v is String) e.value.text = v;
    }
  }

  Future<void> _loadAll() async {
    final s = await BracketSettings.load();
    final ds = await DesignSendSettings.load();
    final rq = await DesignRequest.load(_rqKey);
    List<double> dies = const [];
    try {
      dies = await readPunchDies();
    } catch (_) {}
    String? raw;
    try {
      final p = await SharedPreferences.getInstance();
      raw = p.getString(BracketPage.draftKey);
    } catch (_) {}
    final bundle = await readBracketBundle();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _ds = ds;
      _rq = rq;
      _toDesign = ds.designFirst;
      _dies = dies;
      _bundleCount = bundle.length;
      if (raw != null) {
        try {
          _applyMap(jsonDecode(raw) as Map<String, dynamic>);
        } catch (_) {}
      } else {
        _v['mat'] = s.material;
        _v['fin'] = s.finish;
      }
    });
    _draftReady = true;
  }

  void _saveSoon() {
    if (!_draftReady) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _saveNow);
  }

  void _saveNow() {
    if (!_draftReady) return;
    final d = jsonEncode(_draftMap());
    SharedPreferences.getInstance()
        .then((p) => p.setString(BracketPage.draftKey, d))
        .catchError((_) => false);
  }

  void _set(VoidCallback f) {
    setState(f);
    _saveSoon();
  }

  void _setV(String k, Object v) => _set(() => _v[k] = v);

  int _i(String k) => _v[k] as int;
  bool _b(String k) => _v[k] as bool;
  String _s(String k) => _v[k] as String;
  double _n(String k) {
    final v = readNum(_c[k]!);
    return v == null || v < 0 ? 0 : v;
  }

  BracketShape get _shape => kBracketShapes[_i('sh')].$1;
  bool get _lLike => _shape == BracketShape.l || _shape == BracketShape.brace;
  bool get _standing =>
      _shape == BracketShape.frame || _shape == BracketShape.tee;
  int get _sets => bracketSetsOf(_draftMap());

  // ── 계산 ──

  BracketPlan? _plan() {
    final m = _draftMap();
    final i = bracketInputFromMap(
      m,
      stock: _settings.stock,
      kerf: _settings.kerf,
    );
    if (i.b <= 0 || (i.a <= 0 && _shape != BracketShape.tee)) return null;
    return bracketPlan(i);
  }

  BracketLoadResult? _loadOf(BracketPlan p) {
    final kg = readNum(_c['lk']!);
    if (kg == null || kg <= 0) return null;
    return bracketLoad(
      p,
      kg: kg,
      mode: BracketLoadMode.values[_i('lm').clamp(0, 2)],
      material: _s('mat'),
    );
  }

  String _fmt(double v, [int d = 1]) => fmt(v, d);

  String get _shapeName => kBracketShapes[_i('sh')].$2;

  String _jointName() {
    if (_shape == BracketShape.tee) return '가로대가 기둥 위에 얹힘';
    if (_shape == BracketShape.hanger) return '전산볼트로 매닮';
    return switch (_i('jt')) {
      0 =>
        _shape == BracketShape.frame
            ? '기둥 통과(가로대가 기둥 사이)'
            : '기둥 통과(가로대가 기둥 옆에 붙음)',
      1 =>
        _shape == BracketShape.frame
            ? '가로대 통과(가로대가 기둥 위에 얹힘)'
            : '가로대 통과(기둥이 가로대 밑에 붙음)',
      3 => 'V컷 꺾기(한 본)',
      _ => '연귀',
    };
  }

  String _holeText(BracketPiece pc) {
    final xs = <double>{for (final h in pc.holes) h.fromEnd}.toList()..sort();
    final zs = <double>{for (final h in pc.holes) h.z}.toList()..sort();
    if (pc.kind == BracketPieceKind.plate) {
      return '${bracketHoleSizeText(pc.holes)} · 판 왼쪽 위에서 가로 ${xs.map(_fmt).join('·')} / 세로 ${zs.map(_fmt).join('·')}';
    }
    final g = pc.member?.view.holesFront == true ? '폭 방향' : '게이지';
    final pipes = _pipeCenters(pc);
    return '${bracketHoleSizeText(pc.holes)} · ${pc.holeFace} · ${pc.holeFrom}에서 ${xs.map(_fmt).join(' · ')} · $g ${zs.map(_fmt).join('/')}${pipes.isEmpty ? '' : ' · $pipes'}';
  }

  /// U볼트 구멍이면 "관 중심 25A 100 · 25A 171"(같은 기준 끝에서).
  String _pipeCenters(BracketPiece pc) {
    final seen = <double>{};
    final out = <String>[];
    for (final h in pc.holes) {
      final at = h.pipeAt;
      if (at == null || !seen.add((at * 10).roundToDouble())) continue;
      out.add('${h.pipe} ${_fmt(at)}');
    }
    return out.isEmpty ? '' : '관 중심 ${out.join(' · ')}';
  }

  String _pieceSize(BracketPiece pc) => switch (pc.kind) {
    BracketPieceKind.plate =>
      '${_fmt(pc.length)} × ${_fmt(pc.width)} × ${_fmt(pc.thick)}t',
    BracketPieceKind.rib =>
      '${_fmt(pc.length)} × ${_fmt(pc.width)} × ${_fmt(pc.thick)}t',
    _ =>
      '${_fmt(pc.length)}mm${pc.short != null ? '(짧은 쪽 ${_fmt(pc.short!)})' : ''}',
  };

  List<String> _weldLines(BracketPlan p) {
    final by = <String, (double, bool, int, bool)>{};
    for (final w in p.welds) {
      final c = by[w.what];
      by[w.what] = (w.size, w.allAround, (c?.$3 ?? 0) + 1, w.groove);
    }
    return [
      for (final e in by.entries)
        // V컷 꺾은 곳은 V 홈 맞대기(점검 24)
        e.value.$4
            ? '${e.key}: 맞대기 용접(세운 변 V 홈) × ${e.value.$3 * _sets}곳'
            : '${e.key}: 필릿 각장 ${_fmt(e.value.$1)}${e.value.$2 ? ' 전둘레' : ' 양면'} × ${e.value.$3 * _sets}곳',
    ];
  }

  /// U볼트 종류("25A U볼트 M10(다리 간격 46)") → 전체 개수.
  Map<String, int> _uBolts(BracketPlan p) {
    final arms = p.members
        .where((m) => m.holes.any((h) => h.pipe != null))
        .length;
    final out = <String, int>{};
    for (final x in p.input.pipes) {
      out[x.uText] = (out[x.uText] ?? 0) + arms * _sets;
    }
    return arms == 0 ? const {} : out;
  }

  List<String> _boltLines(BracketPlan p) {
    String bolt(double d) => lugBoltFor(d) ?? '홀에 맞는 규격';
    final rods = p.pieces.where((x) => x.kind == BracketPieceKind.rod);
    return [
      for (final e in p.wallHoles.entries)
        '벽 고정 홀 φ${_fmt(e.key)} ${e.value}개 → 앵커 볼트 ${bolt(e.key)} ${e.value}개(규격·묻힘 깊이는 설계도)',
      for (final e in p.armHoles.entries)
        p.input.pipes.isEmpty
            ? '가로대 홀 φ${_fmt(e.key)} ${e.value}개 → U볼트·클램프 ${bolt(e.key)}용'
            : '가로대 홀 φ${_fmt(e.key)} ${e.value}개(U볼트 다리 자리)',
      // 관마다 U볼트 한 개(2단 문형이면 가로대마다)
      for (final e in _uBolts(p).entries)
        '${e.key} ${e.value}개 · 너트·평와셔 ${2 * e.value}벌',
      for (final e in p.anchorHoles.entries)
        '베이스 판 앵커 홀 φ${_fmt(e.key)} ${e.value}개 → 앵커 볼트 ${bolt(e.key)} ${e.value}개(규격·묻힘 깊이는 설계도)',
      for (final r in rods)
        '전산볼트 ${r.ks} × ${_fmt(r.length)} ${r.qty * _sets}개 · 너트 ${2 * r.qty * _sets}·평와셔 ${2 * r.qty * _sets}(가로대 위아래) · 천장 앵커(인서트) ${r.qty * _sets}개',
    ];
  }

  List<String> _stockLines(BracketPlan p) => [
    for (final e in p.stock.entries)
      if (e.value.barCount > 0)
        '${e.key}: ${_fmt(e.value.stockLength)}mm 원자재 ${e.value.barCount}본(남는 길이 합 ${_fmt(e.value.bars.fold(0.0, (s, b) => s + b.remainderWithKerf(e.value.kerf)), 0)}mm, 톱날 ${_fmt(e.value.kerf)}mm)',
  ];

  String _specLine(BracketPlan p) {
    final specs = <String>{
      for (final pc in p.pieces)
        if (pc.kind == BracketPieceKind.member) pc.ks,
    };
    return specs.join(' / ');
  }

  String _shareText(BracketPlan p) {
    final m = _draftMap();
    final b = StringBuffer('[형강 브라켓] $_shapeName · ${_specLine(p)} · $_sets개');
    final job = _c['jn']!.text.trim();
    if (job.isNotEmpty) b.write(' · $job');
    b.write('\n치수: ${bracketDimText(m)} (바깥 치수, mm) · ${_jointName()}');
    b.write(
      '\n재질 ${_s('mat')} · ${kBracketFinishes[_i('fin')]} · 공차 ${_settings.tolerance}',
    );
    b.write('\n자를 것:');
    for (final pc in p.pieces) {
      b.write(
        '\n ${pc.title} ${pc.ks} ${_pieceSize(pc)} × ${pc.qty * _sets}${pc.kind == BracketPieceKind.plate || pc.kind == BracketPieceKind.rib ? '장' : '개'}${pc.ends.isEmpty ? '' : ' · ${pc.ends}'}',
      );
    }
    for (final pc in p.pieces.where((x) => x.holes.isNotEmpty)) {
      b.write('\n${pc.markText} 홀: ${_holeText(pc)}');
    }
    for (final l in _weldLines(p)) {
      b.write('\n용접 $l');
    }
    for (final l in _boltLines(p)) {
      b.write('\n$l');
    }
    for (final l in _stockLines(p)) {
      b.write('\n$l');
    }
    b.write('\n무게 약 ${_fmt(p.kgTotal)}kg${p.weightKnown ? '' : ' 이상'}');
    for (final s in p.problems) {
      b.write('\n※ $s');
    }
    return b.toString();
  }

  List<String> _generalNotes(BracketPlan p) {
    final auto = p.welds.where((w) => !w.groove).firstOrNull?.size;
    final fin = _i('fin');
    final pipe = p.members.any(
      (x) => x.profile.kind == BracketProfileKind.pipe,
    );
    return [
      '단위 mm, 치수는 바깥 치수. 따로 적지 않은 치수 공차: ${_settings.tolerance}.',
      if (auto != null)
        '따로 적지 않은 용접: 필릿 각장 ${_fmt(auto)} 전둘레(z = 각장, 다리 길이). 용접 뒤 슬래그·스패터 제거.',
      '홀은 용접 전에 뚫습니다. 홀 자리는 부재도(홀 뚫는 면) 기준.',
      if (fin == 1) '방청 도장: 용접부 슬래그를 떼고 바탕 처리 뒤 도장(횟수·색은 현장 기준).',
      if (fin == 2) '용융아연도금: 도금 뒤 용접·가공 금지(했으면 아연 보수 도장).',
      if (fin == 2 && pipe) '각파이프는 도금할 때 공기·아연이 빠질 홀이 필요합니다(자리·크기는 도금 업체와 정함).',
    ];
  }

  Future<BracketPdfInput> _pdfInput(BracketPlan p) async {
    final asm = await renderBracketPng(p.drawing, height: 1000);
    final pieces = <(String, Uint8List)>[];
    for (final pc in p.pieces) {
      final png = await renderBracketPng(
        bracketPieceDrawing(pc, plate: p.plate),
        // 지시서 칸(폭 약 520pt × 높이 200pt)에 맞춘 가로로 긴 그림이라 글씨가 덜 줄어든다
        height: pc.kind == BracketPieceKind.member ? 560 : 640,
      );
      pieces.add((
        '부재도 ${pc.title} ${pc.ks} · ${_pieceSize(pc)} · 1개당 ${pc.qty} / 전체 ${pc.qty * _sets}',
        png,
      ));
    }
    final load = _loadOf(p);
    final m = _draftMap();
    return BracketPdfInput(
      title: _c['jn']!.text,
      titleBlock: [
        ('도면 번호', _c['dn']!.text.trim().isEmpty ? '-' : _c['dn']!.text.trim()),
        ('개정', _c['rv']!.text.trim().isEmpty ? '-' : _c['rv']!.text.trim()),
        ('재질', _s('mat')),
        ('표면 처리', kBracketFinishes[_i('fin')]),
        ('공차', _settings.tolerance),
        ('수량', '$_sets개 · 약 ${_fmt(p.kgTotal)}kg${p.weightKnown ? '' : ' 이상'}'),
      ],
      summary: [
        ('모양', '$_shapeName · ${_jointName()}'),
        ('부재', _specLine(p)),
        ('치수', '${bracketDimText(m)} (바깥 치수, mm)'),
        if (p.braceAngle != null) ('가새', '기울기 ${_fmt(p.braceAngle!)}°'),
      ],
      drawingCaption: '조립도 (바깥 치수, mm · 동그라미 번호는 품번 · z는 용접 각장)',
      drawingPng: asm,
      drawingHeight: 330,
      moreDrawings: pieces,
      moreHeight: 200,
      moreAfterSections: true,
      author: _settings.author,
      sections: [
        BracketPdfSection(
          '자를 것 · 판',
          const [],
          headers: const [
            '품번',
            '이름',
            '규격',
            '길이·크기(mm)',
            '끝 모양',
            '수량(1개·전체)',
            '무게(kg)',
          ],
          rows: [
            for (final pc in p.pieces)
              [
                pc.markText,
                pc.name,
                // 형강은 단위 중량도(제작도 관례: 규격과 kg/m)
                switch (pc.member?.profile.kgPerM) {
                  final double kg when pc.kind == BracketPieceKind.member =>
                    '${pc.ks}\n${_fmt(kg, 2)}kg/m',
                  _ => pc.ks,
                },
                _pieceSize(pc).replaceAll('mm', ''),
                pc.ends.isEmpty ? '-' : pc.ends,
                '${pc.qty} · ${pc.qty * _sets}',
                pc.kgEach > 0 ? _fmt(pc.kgEach * pc.qty * _sets, 2) : '-',
              ],
          ],
        ),
        if (p.pieces.any((x) => x.holes.isNotEmpty))
          BracketPdfSection(
            '홀',
            const [],
            headers: const ['품번', '뚫는 면', '홀', '기준', '자리(mm)', '게이지·세로'],
            rows: [
              for (final pc in p.pieces.where((x) => x.holes.isNotEmpty))
                [
                  pc.markText,
                  pc.holeFace,
                  bracketHoleSizeText(pc.holes),
                  pc.holeFrom,
                  (<double>{
                        for (final h in pc.holes) h.fromEnd,
                      }.toList()..sort()).map(_fmt).join(' · ') +
                      (_pipeCenters(pc).isEmpty
                          ? ''
                          : '\n(${_pipeCenters(pc)})'),
                  (<double>{
                    for (final h in pc.holes) h.z,
                  }.toList()..sort()).map(_fmt).join(' · '),
                ],
            ],
          ),
        if (p.welds.isNotEmpty) BracketPdfSection('용접', _weldLines(p)),
        if (_boltLines(p).isNotEmpty) BracketPdfSection('볼트·앵커', _boltLines(p)),
        if (_stockLines(p).isNotEmpty) BracketPdfSection('원자재', _stockLines(p)),
        if (load != null)
          BracketPdfSection('하중 확인 (참고값, 설계 검토 대신 못 함)', [
            '가로대 한 단에 ${_c['lk']!.text}kg · ${_loadModeName(_i('lm'))} · 재질 ${_s('mat')}',
            for (final c in load.checks)
              '${c.name} ${bracketLoadPct(c.ratio)}${c.ok ? '' : ' (넘음)'} — ${c.detail}',
            ...load.forces,
            ...load.notes,
          ]),
        BracketPdfSection('일반 노트', _generalNotes(p)),
      ],
      notes: [...p.problems, ...p.notes],
    );
  }

  String _loadModeName(int i) => switch (i) {
    0 => switch (_shape) {
      BracketShape.l || BracketShape.brace => '가로대 끝에 한 점',
      BracketShape.tee => '양 끝에 반씩',
      _ => '가운데 한 점',
    },
    1 => '고르게',
    _ => _i('am') == 0 ? '관마다 나눠' : '홀 자리마다 나눠',
  };

  // ── 보내기 ──

  Future<void> _openSaved() => openSavedSpecs(
    context,
    storageKey: BracketPage.savedKey,
    current: _draftMap,
    summaryOf: (m) => bracketSummaryOf(bracketUpgradeMap(m)),
    defaultName: _c['jn']!.text.trim().isNotEmpty
        ? _c['jn']!.text.trim()
        : '$_shapeName ${_c['a']!.text}×${_c['b']!.text}',
    onLoad: (m) => _set(() => _applyMap(m)),
    surface: fc.surface,
    text: fc.text,
    textSub: fc.textSub,
  );

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BracketSettingsPage()));
    final s = await BracketSettings.load();
    final ds = await DesignSendSettings.load();
    List<double> d = _dies;
    try {
      d = await readPunchDies();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _settings = s;
        _ds = ds;
        _dies = d;
      });
    }
  }

  void _setRq(DesignRequest r) {
    setState(() => _rq = r);
    r.save(_rqKey);
  }

  /// 요청자: 설계팀 설정의 요청자, 비우면 지시서 작성자.
  String get _requester =>
      _ds.requester.trim().isNotEmpty ? _ds.requester.trim() : _settings.author;

  /// 설계팀에: 설계 요청서 PDF(문제가 있어도 그대로 — 설계팀이 고칠 몫이라 주의 칸에) · 카톡 요약 글.
  Future<void> _sendDesign(String what, BracketPlan p) async {
    if (what == 'pdf') {
      await openBracketPdf(
        context,
        () async => designPdfFrom(
          await _pdfInput(p),
          docTitle: '형강 브라켓 설계 요청서',
          settings: _ds,
          request: _rq,
          requester: _requester,
          qty: '$_sets개',
          photos: await designPhotoBytes(_rq.photos),
        ),
        previewTitle: '설계 요청서 미리보기',
        filePrefix: 'bracket_request',
      );
      return;
    }
    final m = _draftMap();
    await widget.share(
      designShareText(
        what: '형강 브라켓',
        job: _c['jn']!.text,
        settings: _ds,
        request: _rq,
        requester: _requester,
        body: [
          '$_shapeName · ${_specLine(p)} · $_sets개',
          '치수: ${bracketDimText(m)} (바깥 치수, mm) · ${_jointName()}',
          '재질 ${_s('mat')} · ${kBracketFinishes[_i('fin')]}',
          if (p.input.pipes.isNotEmpty)
            '가로대 위 관: ${p.input.pipes.map((x) => x.name).join(' · ')}',
          if (!p.ok) '확인할 것 ${p.problems.length}건(요청서 주의 칸)',
        ],
      ),
    );
  }

  Future<void> _openBundle() async {
    final r = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => BracketBundlePage(createProject: widget.createProject),
      ),
    );
    final l = await readBracketBundle();
    if (!mounted) return;
    setState(() => _bundleCount = l.length);
    if (r == null) return;
    final before = _draftMap();
    _set(() => _applyMap(r));
    showAppSnack(
      context,
      '묶음의 브라켓을 불러왔습니다.',
      kind: AppSnackKind.undo,
      onUndo: () {
        if (mounted) _set(() => _applyMap(before));
      },
    );
  }

  Future<void> _addToBundle(BracketPlan p) async {
    final l = await readBracketBundle();
    final m = _draftMap();
    final same = jsonEncode(m);
    if (l.any((e) => jsonEncode(e.map) == same)) {
      if (mounted) {
        showAppSnack(context, '이미 묶음에 있습니다.', kind: AppSnackKind.error);
      }
      return;
    }
    final job = _c['jn']!.text.trim();
    final name = job.isNotEmpty
        ? job
        : '$_shapeName ${_c['a']!.text}×${_c['b']!.text}';
    l.add(
      BracketBundleEntry(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        qty: _sets,
        map: m,
      ),
    );
    await writeBracketBundle(l);
    if (!mounted) return;
    setState(() => _bundleCount = l.length);
    showAppSnack(
      context,
      '"$name" $_sets개를 묶음에 넣었습니다(${l.length}종).',
      undoLabel: '묶음 보기',
      onUndo: _openBundle,
    );
  }

  Future<void> _toSteel(BracketPlan p) async {
    final items = bracketCutItems([('', p, _sets)]);
    if (items.isEmpty) return;
    final job = _c['jn']!.text.trim();
    final name = job.isNotEmpty ? '브라켓 $job' : '브라켓 $_shapeName';
    final go = await showAppConfirm(
      context,
      title: '형강 컷팅에 새 작업 만들기',
      message:
          '"$name" 작업을 새로 만들고 자를 것 ${items.length}줄을 넣습니다. 있던 작업은 건드리지 않습니다.',
      okText: '만들기',
      okKey: const Key('br_steel_ok'),
    );
    if (!go || !mounted) return;
    final make = widget.createProject ?? createBracketSteelProject;
    final pr = await make(name, items, _settings.stock);
    if (!mounted) return;
    if (pr == null) {
      showAppSnack(
        context,
        '작업을 만들지 못했습니다. 다시 해 보십시오.',
        kind: AppSnackKind.error,
      );
      return;
    }
    showAppSnack(
      context,
      '형강 컷팅에 "$name" 작업을 만들었습니다.',
      undoLabel: '열기',
      onUndo: () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SteelCuttingDetailScreen(project: pr),
          ),
        );
      },
    );
  }

  void _toPlate(BracketPlan p) {
    final pl = p.plate;
    if (pl == null) return;
    widget.openPlate(
      context,
      bracketPlateToPlateInitial(
        pl,
        job: _c['jn']!.text,
        qty: pl.qty * _sets,
        material: _s('mat'),
      ),
    );
  }

  Future<void> _send(String what, BracketPlan p) async {
    if (!p.ok && what == 'pdf') {
      final go = await showAppConfirm(
        context,
        title: '만들 수 없는 곳이 있습니다',
        message:
            '${p.problems.take(3).join('\n')}${p.problems.length > 3 ? '\n외 ${p.problems.length - 3}개' : ''}\n\n그래도 지시서를 만들겠습니까?',
        okText: '그래도 만들기',
        okKey: const Key('br_send_anyway'),
      );
      if (!go || !mounted) return;
    }
    switch (what) {
      case 'pdf':
        await openBracketPdf(context, () => _pdfInput(p));
      case 'kakao':
        await widget.share(_shareText(p));
    }
  }

  // ── 화면 부품 ──

  Widget _num(
    String key,
    String label,
    String field, {
    String? unit = 'mm',
    String? hint,
    bool text = false,
    Widget? trailing,
  }) => PlateNumField(
    fieldKey: key,
    label: label,
    controller: _c[field]!,
    unit: unit,
    hint: hint,
    text: text,
    trailing: trailing,
    onChanged: (_) => _set(() {}),
  );

  Widget _label(String s) => Text(
    s,
    style: TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: fc.textSub,
    ),
  );

  Widget _guide(String s, {Color? color}) => Text(
    s,
    style: TextStyle(fontSize: 13, color: color ?? fc.textSub, height: 1.4),
  );

  List<double> get _dieChips => _dies.isEmpty ? kDefaultPunchDies : _dies;

  /// 구멍 지름 칸 안 ▼(10-12, 칸 아래 금형 단추 줄 대신): 내 펀치 금형(없으면 볼트 틈새 구멍) + 금형 넣기·고치기.
  /// 항목 키는 예전 단추 키 그대로.
  Widget _dieMenu(String keyPrefix, String field) => PresetMenuButton(
    buttonKey: Key('${keyPrefix}menu'),
    tooltip: '펀치 금형·볼트 홀',
    onOpen: (btn) async {
      final c = _c[field]!;
      final v = await showPresetMenu(
        btn,
        minWidth: 220,
        current: presetKey(readNum(c) ?? -1),
        items: [
          for (final d in _dieChips)
            PresetItem(
              presetKey(d),
              punchDieLabel(d),
              key: Key('$keyPrefix${(d * 100).round()}'),
            ),
        ],
        bottom: PresetItem(
          '',
          _dies.isEmpty ? '내 금형 넣기' : '내 금형 고치기',
          key: Key('${keyPrefix}edit'),
        ),
      );
      if (v == null || !mounted) return;
      if (v.isEmpty) {
        final r = await openPunchDies(context, _dies);
        if (r != null && mounted) setState(() => _dies = r);
        return;
      }
      _set(() => c.text = v);
    },
  );

  /// 규격 단추(누르면 고르는 창).
  Widget _specButton(String key, String spec, ValueChanged<String> onPick) {
    final p = BracketProfile.parse(spec);
    final kg = p.kgPerM;
    return Material(
      color: fc.fill,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        key: Key(key),
        borderRadius: BorderRadius.circular(6),
        onTap: () async {
          final r = await _pickSpec(spec);
          if (r != null && r.trim().isNotEmpty) onPick(r.trim());
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: fc.text,
                      ),
                    ),
                    Text(
                      p.known
                          ? '${p.ks}${kg == null ? '' : ' · ${fmt(kg, 2)}kg/m'}'
                          : '단면을 모르는 규격(그림 폭을 넣으십시오)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: p.known ? fc.textSub : fc.caution,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '바꾸기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: fc.brand,
                ),
              ),
              Icon(AppIcons.forward, size: 18, color: fc.brand),
            ],
          ),
        ),
      ),
    );
  }

  // 창 안 글 칸 조절기는 창 위젯이 가진다(창이 닫히는 그림 중에 버리면 오류, 10-11)
  Future<String?> _pickSpec(String current) =>
      showPlateSheet<String>(context, (_) => _SpecSheet(current: current));

  /// 방향 단추 줄(방향이 둘 이상일 때만).
  Widget? _orientRow(String key, String spec, BracketRole role, String field) {
    final p = BracketProfile.parse(spec);
    if (p.orientCount < 2) return null;
    final cur = _i(field) < 0 || _i(field) >= p.orientCount
        ? p.defaultOrient(role)
        : _i(field);
    return PlateSegments([
      for (var o = 0; o < p.orientCount; o++)
        PlateOption(
          '${key}_$o',
          p.orientName(o, role),
          cur == o,
          () => _setV(field, o),
        ),
    ], joined: false);
  }

  // ── 위 그림 ──

  Widget _canvas(BracketPlan? p) {
    if (p == null) {
      return Center(
        child: Text(
          '규격과 치수를 넣으면 그림이 나옵니다.',
          style: TextStyle(color: fc.textSub, fontWeight: FontWeight.w700),
        ),
      );
    }
    final tone = FieldColors.isNight ? BracketTone.night : BracketTone.light;
    switch (_view) {
      case '3d':
        return Plate3dView.mesh(
          key: const Key('br_3d'),
          mesh: bracket3dMesh(p),
          info: _specLine(p),
        );
      case 'piece':
        final pc = p.pieceOf(_pieceMark) ?? p.pieces.first;
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                key: const Key('br_view_piece'),
                painter: BracketPainter(
                  drawing: bracketPieceDrawing(pc, plate: p.plate),
                  text: fc.text,
                  sub: fc.textSub,
                  bg: fc.background,
                  tone: tone,
                  topInset: 40,
                ),
              ),
            ),
            // 품번 단추는 그림 왼쪽 위(아래는 구멍 크기 글 자리)
            Positioned(
              left: 10,
              right: 180,
              top: 10,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final x in p.pieces) ...[
                      PlateCanvasButton(
                        key: Key('br_pm_${x.mark}'),
                        label: '${x.markText} ${x.name}',
                        selected: x.mark == pc.mark,
                        onTap: () => setState(() => _pieceMark = x.mark),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      default:
        return CustomPaint(
          key: const Key('br_view'),
          painter: BracketPainter(
            drawing: p.drawing,
            text: fc.text,
            sub: fc.textSub,
            bg: fc.background,
            tone: tone,
            topInset: 30,
            bottomInset: 34,
          ),
          child: const SizedBox.expand(),
        );
    }
  }

  List<Widget> _canvasTools(BracketPlan? p) {
    if (p == null) return const [];
    return [
      PlateViewSwitch([
        PlateOption(
          'br_vm_asm',
          '조립도',
          _view == 'asm',
          () => setState(() => _view = 'asm'),
        ),
        PlateOption(
          'br_vm_piece',
          '부재도',
          _view == 'piece',
          () => setState(() => _view = 'piece'),
        ),
        PlateOption(
          'br_vm_3d',
          '3D',
          _view == '3d',
          () => setState(() => _view = '3d'),
        ),
      ]),
    ];
  }

  String? _canvasHint(BracketPlan? p) {
    if (p == null) return null;
    return switch (_view) {
      'asm' => '동그라미 = 품번 · 주황 = 용접(z 각장) · 점선 = 안 보이는 면 홀',
      'piece' => null,
      _ => null,
    };
  }

  // ── 아래 작업판 ──

  Widget _shapePanel(BracketPlan? p) {
    final guide = switch (_shape) {
      BracketShape.l => '벽(기둥)에 붙이고 가로대 위에 튜브·트레이를 얹습니다.',
      BracketShape.brace => 'ㄱ자에 비스듬한 가새를 더해 무거운 것을 받칩니다.',
      BracketShape.frame => '기둥 둘 위에 가로대. 바닥에 세웁니다(2단이면 아래 가로대 하나 더).',
      BracketShape.tee => '기둥 하나 위에 가로대(가로대 0이면 기둥만).',
      BracketShape.hanger => '천장에서 전산볼트 둘로 가로대를 매답니다.',
    };
    final (la, lb) = switch (_shape) {
      BracketShape.l || BracketShape.brace => ('가로대 길이 (벽에서)', '기둥 높이'),
      BracketShape.frame => ('폭 (바깥)', '높이 (바닥에서)'),
      BracketShape.tee => ('가로대 길이 (0이면 기둥만)', '높이 (바닥에서)'),
      BracketShape.hanger => ('가로대 길이', '천장에서 가로대 윗면까지'),
    };
    return PlatePanel(
      title: '모양과 치수',
      status: guide,
      actions: [
        plateHelpButton(context, 'br_help_shape', '형강 브라켓 약속', kBracketBasis),
      ],
      children: [
        PlateSection('모양', [
          PlateSegments([
            for (var i = 0; i < kBracketShapes.length; i++)
              PlateOption(
                'br_shape_$i',
                kBracketShapes[i].$2,
                _i('sh') == i,
                () => _setV('sh', i),
              ),
          ], joined: false),
        ], first: true),
        PlateSection('치수 (바깥, mm)', [
          PlateFieldGrid([_num('br_a', la, 'a'), _num('br_b', lb, 'b')]),
          if (_shape == BracketShape.brace) ...[
            PlateFieldGrid([
              _num('br_ba', '가새 가로대 쪽 자리 (벽에서)', 'ba'),
              _num('br_bb', '가새 기둥 쪽 자리 (위에서)', 'bb'),
            ]),
            plateActions([
              PlateActionButton(
                key: const Key('br_brace45'),
                icon: Icons.architecture_rounded,
                label: '45°로 맞추기',
                onTap: p == null
                    ? null
                    : () {
                        final post = p.members.firstWhere(
                          (m) => m.name == '기둥',
                        );
                        final arm = p.members.firstWhere(
                          (m) => m.name == '가로대',
                        );
                        final face = (_b('wp') ? _n('wt') : 0) + post.depth;
                        final bb = _n('ba') - face + arm.depth;
                        _set(() => _c['bb']!.text = fmt(bb, 1));
                      },
              ),
            ]),
          ],
          if (_shape == BracketShape.frame) ...[
            _label('가로대 단수'),
            PlateSegments([
              PlateOption('br_lw_0', '1단', !_b('lw'), () => _setV('lw', false)),
              PlateOption('br_lw_1', '2단', _b('lw'), () => _setV('lw', true)),
            ]),
            if (_b('lw'))
              plateRow([
                _num('br_la', '아래 가로대 높이 (바닥에서 윗면)', 'la'),
                const SizedBox.shrink(),
              ]),
          ],
          if (_shape == BracketShape.hanger) ...[
            _label('전산볼트'),
            PlateSegments([
              for (final d in kBracketRods)
                PlateOption(
                  'br_rod_$d',
                  'M$d',
                  _i('rd') == d,
                  () => _setV('rd', d),
                ),
            ]),
            PlateFieldGrid([
              _num('br_re', '가로대 끝에서 볼트', 're'),
              _num('br_rtp', '천장 쪽 물림', 'rtp'),
              _num('br_rbl', '가로대 아래로 나옴', 'rbl'),
            ]),
            _guide('물림·나옴 처음 값은 임의 값입니다(천장 앵커·너트에 맞추십시오).'),
          ],
        ]),
        if (_shape != BracketShape.tee && _shape != BracketShape.hanger)
          PlateSection('이음', [
            PlateSegments([
              for (final (i, label) in const [
                (0, '기둥 통과'),
                (1, '가로대 통과'),
                (2, '연귀'),
                (3, 'V컷 꺾기'),
              ])
                PlateOption(
                  'br_joint_$i',
                  label,
                  _i('jt') == i,
                  () => _setV('jt', i),
                ),
            ]),
            _guide(switch (_i('jt')) {
              0 =>
                '가로대가 기둥 옆에 맞대어 붙습니다. 앵글·찬넬은 가로대 끝 세운 변을 따내고 위 변만 기둥 벽 쪽 변까지 넣어 틈 없이(부재도).',
              1 =>
                '기둥이 가로대 밑에 맞대어 붙습니다. 앵글·찬넬은 기둥 끝을 따내고 벽 쪽 변만 가로대 위 변 밑까지 올려 틈 없이(부재도).',
              2 => '두 토막 모두 두 변 다 45°로(그라인더) 잘라 맞댑니다. 바깥 치수 그대로.',
              _ =>
                '한 본의 세운 변을 90° V로 따내고 꺾어 기둥·가로대를 한 토막으로. 펼친 길이 = 바깥 치수 합 − 꺾는 곳마다 공제값.',
            }),
            if (_i('jt') == 3)
              plateRow([
                _num(
                  'br_vb',
                  '꺾임 공제(꺾는 곳마다)',
                  'vb',
                  hint: p == null || p.members.isEmpty
                      ? '자동'
                      : '자동 ${fmt(2 * p.members.first.view.attachT)}',
                ),
                const SizedBox.shrink(),
              ]),
            if (_i('jt') == 3)
              _guide('자동은 두께 × 2(날카롭게 꺾을 때 어림)입니다. 시험으로 한 번 꺾어 보고 맞추십시오.'),
          ]),
        PlateSection('수량', [
          plateRow([
            _num('br_sets', '만들 개수', 'n', unit: '개'),
            const SizedBox.shrink(),
          ]),
        ]),
      ],
    );
  }

  Widget _memberPanel(BracketPlan? p) {
    final m = _draftMap();
    final main = bracketMainSpec(m);
    final mainP = BracketProfile.parse(main);
    final hanger = _shape == BracketShape.hanger;
    final postRole = _lLike ? BracketRole.wall : BracketRole.none;
    final fillets = [
      for (final w in p?.welds ?? const <BracketWeld>[])
        if (!w.groove) w.size,
    ];
    final autoWeld = fillets.isEmpty
        ? null
        : fillets.reduce((a, b) => a < b ? a : b);
    final armSpec = bracketArmSpec(m);
    final braceSpec = bracketBraceSpec(m);
    return PlatePanel(
      title: '부재',
      status: p == null ? null : _specLine(p),
      actions: [
        plateHelpButton(
          context,
          'br_help_member',
          '부재 약속',
          kBracketBasis.sublist(2, 3) + kBracketBasis.sublist(5, 6),
        ),
      ],
      children: [
        PlateSection(hanger ? '가로대 규격' : '주 부재 (기둥·가로대)', [
          _specButton('br_spec', main, (s) {
            _set(() {
              _v['sp'] = s;
              _v['po'] = -1;
              if (_b('as')) _v['ao'] = -1;
            });
          }),
          // 가로대·가새 규격을 몰라도 그림 폭 칸이 있어야 고친다(점검 28)
          if (!mainP.known ||
              (!hanger && !BracketProfile.parse(armSpec).known) ||
              (_shape == BracketShape.brace &&
                  !BracketProfile.parse(braceSpec).known))
            plateRow([
              _num('br_w', '그림 폭 (모르는 규격)', 'w'),
              const SizedBox.shrink(),
            ]),
          if (!hanger) ...[
            if (_orientRow('br_po', main, postRole, 'po') case final r?) ...[
              _label('기둥 방향'),
              r,
            ],
          ] else if (_orientRow('br_ao', main, BracketRole.top, 'ao')
              case final r?) ...[
            _label('가로대 방향'),
            r,
          ],
        ], first: true),
        if (!hanger)
          PlateSection('가로대', [
            PlateSegments([
              PlateOption(
                'br_as_1',
                '기둥과 같음',
                _b('as'),
                () => _set(() {
                  _v['as'] = true;
                  _v['ao'] = -1;
                }),
              ),
              PlateOption(
                'br_as_0',
                '따로',
                !_b('as'),
                () => _set(() {
                  _v['as'] = false;
                  if (_s('asp') == kBracketValueDefaults['asp'] &&
                      main != _s('asp')) {
                    _v['asp'] = main;
                  }
                }),
              ),
            ]),
            if (!_b('as'))
              _specButton('br_arm_spec', armSpec, (s) {
                _set(() {
                  _v['asp'] = s;
                  _v['ao'] = -1;
                });
              }),
            if (_orientRow('br_ao', armSpec, BracketRole.top, 'ao')
                case final r?) ...[
              _label('가로대 방향'),
              r,
            ],
          ]),
        if (_shape == BracketShape.brace)
          PlateSection('가새', [
            // 현장은 가새를 웬만하면 평철로(10-11 사용자) — 처음은 기둥 폭에 맞춘 평철
            PlateSegments([
              PlateOption(
                'br_bs_auto',
                '평철 맞춤',
                bracketBraceAuto(m),
                () => _set(() {
                  _v['bs'] = false;
                  _v['bsp'] = '';
                  _v['bo'] = -1;
                }),
              ),
              PlateOption(
                'br_bs_1',
                '기둥과 같음',
                _b('bs'),
                () => _set(() {
                  _v['bs'] = true;
                  _v['bo'] = -1;
                }),
              ),
              PlateOption(
                'br_bs_0',
                '직접 고르기',
                !_b('bs') && !bracketBraceAuto(m),
                () => _set(() {
                  _v['bs'] = false;
                  _v['bsp'] = braceSpec;
                }),
              ),
            ]),
            if (bracketBraceAuto(m)) _guide('$braceSpec (기둥 그림 폭에 맞춘 평철)'),
            if (!_b('bs') && !bracketBraceAuto(m))
              _specButton('br_brace_spec', braceSpec, (s) {
                _set(() {
                  _v['bsp'] = s;
                  _v['bo'] = -1;
                });
              }),
            if (_orientRow('br_bo', braceSpec, BracketRole.none, 'bo')
                case final r?) ...[
              _label('가새 방향'),
              r,
            ],
          ]),
        PlateSection('재질', [
          PlateSegments([
            for (final k in kBracketMaterials.keys)
              PlateOption(
                'br_mat_$k',
                k,
                _s('mat') == k,
                () => _setV('mat', k),
              ),
          ]),
          _guide('지시서 재질 칸과 하중 확인(항복 강도)에 씁니다. SS275는 예전 SS400입니다.'),
        ]),
        PlateSection('용접', [
          plateRow([
            _num(
              'br_wz',
              '필릿 각장',
              'wz',
              hint: autoWeld == null ? '자동' : '자동 ${fmt(autoWeld)}',
            ),
            const SizedBox.shrink(),
          ]),
          _guide('비우면 이음마다 얇은 쪽 두께(6 넘으면 6)입니다. 그림 기호 z = 각장(다리 길이).'),
        ]),
      ],
    );
  }

  Widget _armModeRow() => PlateSegments([
    PlateOption('br_am_0', '관 자리 (U볼트)', _i('am') == 0, () => _setV('am', 0)),
    PlateOption('br_am_1', '일자로 직접', _i('am') == 1, () => _setV('am', 1)),
  ]);

  /// 가로대 위 관: 관마다 U볼트 한 쌍(관 중심 ± 다리 간격/2).
  Widget _pipeSection(BracketPlan? plan, BracketSectionView? view) {
    final n = _i('upn');
    final specs = bracketPipeSpecs(_draftMap());
    final pipes = plan?.input.pipes ?? const <BracketPipe>[];
    return PlateSection(
      _shape == BracketShape.hanger
          ? '가로대 위 관 (U볼트, 전산볼트 홀 말고)'
          : '가로대 위 관 (U볼트)',
      [
        _armModeRow(),
        PlateSegments([
          for (var k = 0; k <= kBracketPipeMax; k++)
            PlateOption(
              'br_upn_$k',
              k == 0 ? '없음' : '$k개',
              n == k,
              () => _setV('upn', k),
            ),
        ]),
        if (n > 0) ...[
          for (var k = 0; k < specs.length; k++)
            _pipeTile(k, specs[k], k < pipes.length ? pipes[k] : null),
          if (n > 1)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('br_up_same'),
                onPressed: () => _set(() {
                  for (var k = 1; k < n; k++) {
                    _v['up$k'] = _s('up0');
                  }
                }),
                child: const Text('모두 1번 관과 같게'),
              ),
            ),
          PlateFieldGrid([
            _num('br_uf', '첫 관 중심', 'uf'),
            if (n > 1)
              _num(
                'br_ug',
                '관 사이 (중심)',
                'ug',
                hint: bracketPipeAutoPitchText(specs),
              ),
          ]),
          PlateFieldGrid([
            _num('br_as', '장공 길이', 'as2', hint: '비우면 둥근 홀'),
            _num(
              'br_ag',
              '게이지',
              'ag',
              hint: view == null ? null : '비우면 ${fmt(view.gauge)}',
            ),
          ]),
          _guide(
            '관마다 U볼트 다리 두 개 자리(관 중심 ± 다리 간격/2)에 뚫습니다. 다리 간격 = U볼트 내경 + 나사 지름(표 값). '
            '첫 관은 ${_lLike ? '가로대 끝(벽 반대쪽)' : '왼쪽 바깥(기둥 바깥면)'}에서 잽니다. '
            '관 사이를 비우면 두 관 반지름 + 25, 이웃 U볼트 너트·와셔가 닿으면 그만큼 더 벌립니다(보온·플랜지는 직접 더 넣으십시오).',
          ),
          if (pipes.any((x) => x.approx))
            _guide(
              '전선관·튜브·직접 외경의 U볼트 값은 어림입니다. 가진 U볼트의 다리 간격(다리 중심 사이)을 재서 넣으십시오.',
              color: fc.caution,
            ),
        ],
      ],
    );
  }

  Widget _pipeTile(int k, BracketPipeSpec sp, BracketPipe? p) {
    final m = sp.threadUsed;
    return Material(
      color: fc.fill,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        key: Key('br_up_$k'),
        borderRadius: BorderRadius.circular(6),
        onTap: () async {
          final r = await showPlateSheet<String>(
            context,
            (_) => _PipeSheet(index: k, spec: sp),
          );
          if (r != null) _setV('up$k', r);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${k + 1}번 관 · ${sp.label}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: fc.text,
                      ),
                    ),
                    Text(
                      'U볼트 M$m · 다리 간격 ${fmt(sp.spacingUsed)} · 홀 φ${fmt(bracketUHole(m))}${p == null ? '' : ' · 중심 ${fmt(p.at)}'}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: fc.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '바꾸기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: fc.brand,
                ),
              ),
              Icon(AppIcons.forward, size: 18, color: fc.brand),
            ],
          ),
        ),
      ),
    );
  }

  Widget _holeSection({
    required String title,
    required String p,
    required int max,
    required String firstLabel,
    required String guide,
    required BracketSectionView? view,
    List<Widget> lead = const [],
  }) {
    final n = _i('${p}n');
    final dia = _n('${p}d');
    return PlateSection(title, [
      ...lead,
      PlateSegments([
        for (var k = 0; k <= max; k++)
          PlateOption(
            'br_${p}n_$k',
            k == 0 ? '없음' : '$k개',
            n == k,
            () => _setV('${p}n', k),
          ),
      ]),
      if (n > 0) ...[
        PlateFieldGrid([
          _num(
            'br_${p}d',
            '지름',
            '${p}d',
            trailing: _dieMenu('br_${p}_die_', '${p}d'),
          ),
          _num('br_${p}f', firstLabel, '${p}f'),
        ]),
        PlateFieldGrid([
          if (n > 1) _num('br_${p}p', '피치', '${p}p'),
          _num(
            'br_${p}s',
            '장공 길이',
            '${p}s2',
            hint: n > 1 ? '둥근 홀' : '비우면 둥근 홀',
          ),
          _num(
            'br_${p}g',
            '게이지',
            '${p}g',
            hint: view == null ? null : '비우면 ${fmt(view.gauge)}',
          ),
        ]),
        // 두 줄을 켜 둔 채 규격·지름이 바뀌어도 끌 수 있게 단추를 남긴다(점검 27)
        if (_b('${p}2') ||
            (view != null &&
                !view.holesFront &&
                !view.twoLines &&
                view.width >= 4 * dia))
          PlateSegments([
            PlateOption(
              'br_${p}2_0',
              '한 줄',
              !_b('${p}2'),
              () => _setV('${p}2', false),
            ),
            PlateOption(
              'br_${p}2_1',
              '두 줄(양쪽 게이지)',
              _b('${p}2'),
              () => _setV('${p}2', true),
            ),
          ]),
        _guide(guide),
      ],
    ]);
  }

  Widget _holesPanel(BracketPlan? p) {
    BracketSectionView? viewOf(String name) {
      if (p == null) return null;
      for (final m in p.members) {
        if (m.name == name) return m.view;
      }
      return null;
    }

    final wall = _lLike && _b('wp');
    // 비운 판 크기 칸의 "자동" 값(점검 33)
    final pl = p?.plate;
    final wallPl = pl != null && pl.wall ? pl : null;
    final basePl = pl != null && !pl.wall ? pl : null;
    return PlatePanel(
      title: '홀과 판',
      status: p == null
          ? null
          : '${p.wallHoles.values.fold(0, (s, v) => s + v) + p.armHoles.values.fold(0, (s, v) => s + v) + p.anchorHoles.values.fold(0, (s, v) => s + v)}개 홀(전체)',
      actions: [
        plateHelpButton(
          context,
          'br_help_holes',
          '홀·판 약속',
          kBracketBasis.sublist(3, 5) + kBracketBasis.sublist(6, 7),
        ),
      ],
      children: [
        if (_lLike && !wall)
          _holeSection(
            title: '기둥 홀 (벽 고정)',
            p: 'p',
            max: 4,
            firstLabel: '첫 홀',
            guide: '기둥이 벽에 붙는 면에 뚫습니다. 위 바깥 모서리에서 잽니다.',
            view: viewOf('기둥'),
          ),
        // 가로대 구멍: 관 자리(U볼트 한 쌍씩, 10-12) 또는 일자로 직접(클램프 등)
        if (_i('am') == 1)
          _holeSection(
            title: _shape == BracketShape.hanger
                ? '가로대 홀 (전산볼트 홀 말고)'
                : '가로대 홀',
            p: 'a',
            max: 5,
            firstLabel: '첫 홀',
            guide: _lLike
                ? '가로대 위 면에 같은 피치로 일자로 뚫습니다(클램프 등). 가로대 끝(벽 반대쪽)에서 잽니다.'
                : '가로대 위 면에 같은 피치로 일자로 뚫습니다(클램프 등). 왼쪽 바깥(기둥 바깥면)에서 잽니다.',
            view: viewOf('가로대'),
            lead: [_armModeRow()],
          )
        else
          _pipeSection(p, viewOf('가로대')),
        if (_shape == BracketShape.frame && _b('lw'))
          PlateSection('아래 가로대 홀', [
            PlateSegments([
              PlateOption('br_lh_0', '없음', !_b('lh'), () => _setV('lh', false)),
              PlateOption(
                'br_lh_1',
                '위 가로대와 같게',
                _b('lh'),
                () => _setV('lh', true),
              ),
            ]),
          ]),
        if (_shape == BracketShape.hanger)
          PlateSection('전산볼트 홀', [
            _guide(
              '가로대 위 면, 양 끝에서 ${_c['re']!.text} 자리에 φ${fmt(bracketRodHole(_i('rd').toDouble()))} 두 개(M${_i('rd')}). 부재도에 함께 나옵니다.',
            ),
          ]),
        if (_lLike)
          PlateSection('벽 붙임 판', [
            PlateSegments([
              PlateOption(
                'br_wp_0',
                '안 붙임',
                !_b('wp'),
                () => _setV('wp', false),
              ),
              PlateOption('br_wp_1', '붙임', _b('wp'), () => _setV('wp', true)),
            ]),
            if (_b('wp')) ...[
              PlateFieldGrid([
                _num(
                  'br_ww',
                  '판 폭',
                  'ww',
                  hint: wallPl == null ? '자동' : '자동 ${fmt(wallPl.w)}',
                ),
                _num('br_wh', '판 높이', 'wh', hint: '기둥 높이'),
                _num('br_wt', '두께', 'wt'),
              ]),
              _label('앵커 홀'),
              PlateSegments([
                for (final k in const [0, 2, 4])
                  PlateOption(
                    'br_wn_$k',
                    k == 0 ? '없음' : '$k개',
                    _i('wn') == k,
                    () => _setV('wn', k),
                  ),
              ]),
              if (_i('wn') > 0) ...[
                PlateFieldGrid([
                  _num(
                    'br_wd',
                    '지름',
                    'wd',
                    trailing: _dieMenu('br_wd_die_', 'wd'),
                  ),
                  _num('br_we', '가장자리에서', 'we'),
                ]),
              ],
              _guide(
                '기둥 뒤에 붙여 벽에 앵커로 고정합니다(기둥 홀 대신). 4개는 네 귀, 2개는 양옆 가운데. 처음 값은 임의 값입니다.',
              ),
            ],
          ]),
        if (_standing)
          PlateSection('베이스 판', [
            PlateSegments([
              PlateOption(
                'br_plate_off',
                '안 붙임',
                !_b('pl'),
                () => _setV('pl', false),
              ),
              PlateOption(
                'br_plate_on',
                '붙임',
                _b('pl'),
                () => _setV('pl', true),
              ),
            ]),
            if (_b('pl')) ...[
              PlateFieldGrid([
                _num(
                  'br_pw',
                  '가로 (그림 방향)',
                  'pw',
                  hint: basePl == null ? '자동' : '자동 ${fmt(basePl.w)}',
                ),
                _num(
                  'br_pll',
                  '세로 (앞뒤)',
                  'pll',
                  hint: basePl == null ? '자동' : '자동 ${fmt(basePl.l)}',
                ),
                _num('br_pt', '두께', 'pt'),
              ]),
              _label('앵커 홀'),
              PlateSegments([
                for (final k in const [0, 2, 4])
                  PlateOption(
                    'br_pn_$k',
                    k == 0 ? '없음' : '$k개',
                    _i('pln') == k,
                    () => _setV('pln', k),
                  ),
              ]),
              if (_i('pln') > 0) ...[
                PlateFieldGrid([
                  _num(
                    'br_pld',
                    '지름',
                    'pld',
                    trailing: _dieMenu('br_pld_die_', 'pld'),
                  ),
                  _num('br_ple', '가장자리에서', 'ple'),
                ]),
              ],
              _label('리브(보강판)'),
              PlateSegments([
                for (final k in const [0, 2, 4])
                  PlateOption(
                    'br_rb_$k',
                    k == 0 ? '없음' : '$k장',
                    _i('rb') == k,
                    () => _setV('rb', k),
                  ),
              ]),
              if (_i('rb') > 0)
                PlateFieldGrid([
                  _num('br_rh', '높이', 'rh'),
                  _num('br_rl', '길이 (기둥 면에서)', 'rl'),
                  _num('br_rt', '두께', 'rt'),
                ]),
              _guide('기둥마다 한 장. 2장 리브는 그림 면 양옆, 4장은 앞뒤까지. 처음 값은 임의 값입니다.'),
            ],
          ]),
      ],
    );
  }

  Color _ratioColor(double r) =>
      r > 1 ? fc.danger : (r > 0.7 ? fc.caution : fc.ok);

  Widget _pieceCard(BracketPiece pc) => Material(
    color: fc.fill,
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      key: Key('br_piece_${pc.mark}'),
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() {
        _view = 'piece';
        _pieceMark = pc.mark;
      }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${pc.title}  ${pc.ks}',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: fc.text,
                    ),
                  ),
                ),
                Text(
                  '부재도',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: fc.brand,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${_pieceSize(pc)} × ${pc.qty * _sets}${pc.kind == BracketPieceKind.plate || pc.kind == BracketPieceKind.rib ? '장' : '개'}${pc.ends.isEmpty ? '' : ' · ${pc.ends}'}${pc.kgEach > 0 ? ' · 개당 ${fmt(pc.kgEach, 2)}kg' : ''}',
              style: TextStyle(fontSize: 13.5, color: fc.text, height: 1.35),
            ),
            if (pc.holes.isNotEmpty)
              Text(
                '홀 ${_holeText(pc)}',
                style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.35),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _resultPanel(BracketPlan? p, bool warn) {
    if (p == null) {
      return PlatePanel(
        title: '결과',
        status: '규격과 치수를 넣으면 계산합니다.',
        children: const [],
      );
    }
    final load = _loadOf(p);
    final pieceN = p.pieces.fold(0, (s, x) => s + x.qty) * _sets;
    return PlatePanel(
      title: '결과',
      status: warn ? '고칠 곳 ${p.problems.length}개' : '$_sets개 · 토막·판 $pieceN개',
      statusKey: const Key('br_status'),
      statusColor: warn ? fc.danger : null,
      actions: [
        plateHelpButton(
          context,
          'br_help_result',
          '결과 약속',
          kBracketBasis.sublist(7),
        ),
      ],
      children: [
        PlateSection('요약', [
          KeyedSubtree(
            key: const Key('br_result'),
            child: PlateBigValue(
              value: '약 ${fmt(p.kgTotal)}kg${p.weightKnown ? '' : ' 이상'}',
              caption:
                  '${_specLine(p)} · $_sets개${p.braceAngle != null ? ' · 가새 ${fmt(p.braceAngle!)}°' : ''}',
              warn: warn,
            ),
          ),
          if (p.problems.isNotEmpty) PlateLines(p.problems, color: fc.danger),
          if (p.notes.isNotEmpty) PlateLines(p.notes, color: fc.caution),
        ], first: true),
        PlateSection('자를 것·판 (누르면 부재도)', [
          KeyedSubtree(
            key: const Key('br_pieces'),
            child: Column(
              children: [
                for (final pc in p.pieces) ...[
                  _pieceCard(pc),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ]),
        if (p.welds.isNotEmpty) PlateSection('용접', [PlateLines(_weldLines(p))]),
        if (_boltLines(p).isNotEmpty)
          PlateSection('볼트·앵커', [
            KeyedSubtree(
              key: const Key('br_bolts'),
              child: PlateLines(_boltLines(p)),
            ),
          ]),
        if (_stockLines(p).isNotEmpty)
          PlateSection('원자재', [
            KeyedSubtree(
              key: const Key('br_stock_result'),
              child: PlateLines(_stockLines(p)),
            ),
          ]),
        PlateSection('하중 확인 (참고)', [
          plateRow([
            _num('br_lk', '가로대 한 단에 얹는 무게', 'lk', unit: 'kg', hint: '예) 100'),
            const SizedBox.shrink(),
          ]),
          PlateSegments([
            for (var i = 0; i < 3; i++)
              PlateOption(
                'br_lm_$i',
                _loadModeName(i),
                _i('lm') == i,
                () => _setV('lm', i),
              ),
          ]),
          if (load == null)
            _guide('무게를 넣으면 휨·처짐·가새·앵커 힘을 대략 보여 줍니다. 설계 검토를 대신하지 못합니다.')
          else ...[
            for (final c in load.checks)
              Column(
                key: Key('br_load_${c.name}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PlateInfoRow(
                    c.name,
                    '${bracketLoadPct(c.ratio)}${c.ok ? '' : ' 넘음'}',
                    color: _ratioColor(c.ratio),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 84),
                    child: Text(
                      c.detail,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: fc.textSub,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            if (load.forces.isNotEmpty) PlateLines(load.forces),
            if (load.notes.isNotEmpty)
              PlateLines(load.notes, color: fc.caution),
            _guide(
              '참고값(AISC 허용응력 꼴, 재질 ${_s('mat')}). 용접·앵커 강도와 옆 힘은 보지 않습니다.',
            ),
          ],
        ]),
        PlateSection('작업 순서', [
          PlateLines([
            '자를 것 표대로 형강을 자릅니다. 비스듬한 끝은 표의 각도로(각도절단기 직각 = 0°) 자르고 절단면 버를 갈아 냅니다.',
            '부재도(아래 = 홀 뚫는 면)대로 기준 끝에서 재어 마킹하고 펀치 금형(없는 크기는 드릴)으로 뚫습니다. 용접 전에 뚫어야 기계에 넣기 쉽습니다.',
            '조립도의 단면대로 방향을 맞춰 가접하고 직각·대각선 길이를 재어 틀어짐이 없으면 본용접합니다(주황 기호 자리, z = 각장).',
            if (_shape == BracketShape.brace)
              '가새는 가로대·기둥을 먼저 가접해 직각을 잡은 뒤 끼워 맞춥니다.',
            if (_standing && _b('pl'))
              '베이스 판은 기둥 밑에 직각으로 용접하고, 판 홀이 그림 방향과 맞는지 봅니다.',
            if (_lLike && _b('wp'))
              '벽 붙임 판은 기둥 뒤 가운데에 맞춰 용접하고, 판 홀이 기둥에 가리지 않는지 봅니다.',
            '용접부 슬래그를 떼고 표면 처리(${kBracketFinishes[_i('fin')]})를 합니다.',
          ]),
        ]),
      ],
    );
  }

  Widget _sendPanel(BracketPlan? p) => PlatePanel(
    title: '보내기',
    status: p == null
        ? '규격과 치수를 넣으십시오.'
        : _toDesign
        ? '${_ds.teamName}에 설계 요청서 PDF(요청·현장 사진·참고 그림)와 카톡 글'
        : '지시서 PDF(조립도·부재도·표), 카톡 글, 다른 화면으로',
    children: [
      designTargetRow(
        'br',
        design: _toDesign,
        team: _ds.teamName,
        onChanged: (v) => setState(() => _toDesign = v),
      ),
      const SizedBox(height: 8),
      if (_toDesign) ...[
        PlateSection('설계 요청', [
          _num(
            'br_job',
            '작업 이름',
            'jn',
            unit: null,
            text: true,
            hint: '비워도 됩니다',
          ),
          const SizedBox(height: 12),
          DesignRequestFields(keyPrefix: 'br', value: _rq, onChanged: _setRq),
          _guide(
            '요청자 ${_requester.isEmpty ? '(비움)' : _requester} · 받는 곳 ${_ds.teamName}. 요청자·받는 곳은 설정에서 바꿉니다. 지금 그림·표는 "참고"로 들어갑니다.',
          ),
        ], first: true),
        if (p != null)
          PlateSection('보내기', [
            plateActions([
              PlateActionButton(
                key: const Key('br_rq_pdf'),
                icon: Icons.picture_as_pdf_outlined,
                label: '설계 요청서 PDF',
                primary: true,
                onTap: () => _sendDesign('pdf', p),
              ),
              PlateActionButton(
                key: const Key('br_rq_share'),
                icon: Icons.chat_bubble_outline_rounded,
                label: '카톡 글',
                onTap: () => _sendDesign('kakao', p),
              ),
            ]),
          ]),
      ] else ...[
        PlateSection('도면 정보', [
          _num(
            'br_job',
            '작업 이름 (현장·위치)',
            'jn',
            unit: null,
            text: true,
            hint: '비워도 됩니다',
          ),
          PlateFieldGrid([
            _num(
              'br_dn',
              '도면 번호',
              'dn',
              unit: null,
              text: true,
              hint: '예) BR-01',
            ),
            _num('br_rv', '개정', 'rv', unit: null, text: true),
          ]),
          _label('표면 처리'),
          PlateSegments([
            for (var i = 0; i < kBracketFinishes.length; i++)
              PlateOption(
                'br_fin_$i',
                kBracketFinishes[i],
                _i('fin') == i,
                () => _setV('fin', i),
              ),
          ]),
          _guide(
            '재질 ${_s('mat')}(부재 탭) · 공차 ${_settings.tolerance} · 작성 ${_settings.author.isEmpty ? '(비움)' : _settings.author} — 공차·작성자는 설정에서 바꿉니다.',
          ),
        ], first: true),
        if (p != null)
          PlateSection('보내기', [
            plateActions([
              PlateActionButton(
                key: const Key('br_pdf'),
                icon: Icons.picture_as_pdf_outlined,
                label: '가공 지시서 PDF',
                primary: true,
                onTap: () => _send('pdf', p),
              ),
              PlateActionButton(
                key: const Key('br_share'),
                icon: Icons.chat_bubble_outline_rounded,
                label: '카톡 글',
                onTap: () => _send('kakao', p),
              ),
              if (p.plate != null)
                PlateActionButton(
                  key: const Key('br_to_plate'),
                  icon: Icons.crop_square_rounded,
                  label: '${p.plate!.name} → 철판 가공',
                  onTap: () => _toPlate(p),
                ),
              PlateActionButton(
                key: const Key('br_to_steel'),
                icon: Icons.content_cut_rounded,
                label: '형강 컷팅에 새 작업으로',
                onTap: () => _toSteel(p),
              ),
            ]),
          ]),
        PlateSection('묶음', [
          _guide(
            '한 현장 브라켓 여러 종류를 모아 자를 것·원자재·지시서를 한 번에. 지금 묶음 $_bundleCount종.',
          ),
          plateActions([
            if (p != null)
              PlateActionButton(
                key: const Key('br_bundle_add'),
                icon: Icons.playlist_add_rounded,
                label: '묶음에 넣기',
                onTap: () => _addToBundle(p),
              ),
            PlateActionButton(
              key: const Key('br_bundle_open'),
              icon: Icons.inventory_2_outlined,
              label: '묶음 보기',
              onTap: _openBundle,
            ),
          ]),
        ]),
      ],
    ],
  );

  /// 아래 탭 줄(철판 가공과 같은 모양). 키보드가 떠 있으면 숨긴다.
  Widget? _navBar(int idx) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return null;
    final compact = calcNavCompact(context);
    BottomNavigationBarItem item(String id, String label, int i) {
      final on = i == idx;
      final Widget icon = switch (id) {
        'shape' => AppIcon(AppGlyph.navInput, size: 24, filled: on),
        'member' => AppIcon(AppGlyph.bracket, size: 24, filled: on),
        'holes' => const Icon(Icons.adjust, size: 24),
        'result' => AppIcon(AppGlyph.navMarking, size: 24, filled: on),
        _ => const Icon(AppIcons.send, size: 22),
      };
      return BottomNavigationBarItem(
        icon: Padding(
          padding: EdgeInsets.only(bottom: compact ? 0 : 4),
          child: KeyedSubtree(key: Key('br_tab_$id'), child: icon),
        ),
        label: label,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: fc.surface,
        border: Border(top: BorderSide(color: fc.line)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 4,
            vertical: compact ? 0 : 4,
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            currentIndex: idx,
            selectedItemColor: fc.brand,
            unselectedItemColor: fc.textSub,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
            onTap: (i) {
              HapticFeedback.selectionClick();
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() => _tab = i);
            },
            items: [
              for (var i = 0; i < _tabs.length; i++)
                item(_tabs[i].$1, _tabs[i].$2, i),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String key,
    String value,
    IconData icon,
    String label,
  ) => PopupMenuItem<String>(
    key: Key(key),
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: fc.textSub),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w700, color: fc.text),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = _plan();
    final warn = p != null && !p.ok;
    String? summary;
    if (p != null) {
      // 최근 기록 한 줄(같은 줄은 갈아 끼움)
      summary =
          '브라켓 $_shapeName · ${p.pieces.where((x) => x.kind == BracketPieceKind.member).map((x) => '${x.name} ${fmt(x.length)}').join(' · ')}';
    }
    final idx = _tab.clamp(0, _tabs.length - 1);
    final head = p == null
        ? null
        : '$_shapeName · ${_specLine(p)} · 약 ${fmt(p.kgTotal)}kg';
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveNow();
      },
      child: FieldViewTheme(
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: fc.background,
            appBar: AppBar(
              backgroundColor: fc.surface,
              foregroundColor: fc.text,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '형강 브라켓',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: fc.text,
                    ),
                  ),
                  if (head != null)
                    KeyedSubtree(
                      key: const Key('br_sum'),
                      child: Text(
                        head,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: warn ? fc.danger : fc.brand,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                PlateBarAction(
                  key: const Key('br_saved'),
                  icon: Icons.bookmarks_outlined,
                  label: '저장',
                  onTap: _openSaved,
                ),
                PopupMenuButton<String>(
                  key: const Key('br_more'),
                  tooltip: '더 보기',
                  icon: Icon(Icons.more_vert, color: fc.text),
                  color: fc.surface,
                  onSelected: (v) {
                    switch (v) {
                      case 'history':
                        showCalcHistorySheet(
                          context,
                          calcHistory,
                          title: '최근 계산 기록',
                        );
                      case 'bundle':
                        _openBundle();
                      case 'settings':
                        _openSettings();
                    }
                  },
                  itemBuilder: (_) => [
                    _menuItem(
                      'br_history',
                      'history',
                      Icons.history_rounded,
                      '최근 계산 기록',
                    ),
                    _menuItem(
                      'br_bundle',
                      'bundle',
                      Icons.inventory_2_outlined,
                      '브라켓 묶음',
                    ),
                    _menuItem(
                      'br_settings',
                      'settings',
                      AppIcons.settings,
                      '형강 브라켓 설정',
                    ),
                  ],
                ),
              ],
            ),
            body: elecPageFrame(
              sumKey: 'br_sum',
              summary: summary,
              warn: warn,
              showBar: false,
              body: PlateWorkspace(
                canvasShare: 0.4,
                canvas: KeyedSubtree(
                  key: const ValueKey('br_canvas'),
                  child: _canvas(p),
                ),
                tools: _canvasTools(p),
                hint: _canvasHint(p),
                panel: IndexedStack(
                  index: idx,
                  children: [
                    for (final t in _tabs)
                      KeyedSubtree(
                        key: ValueKey('br_body_${t.$1}'),
                        child: switch (t.$1) {
                          'shape' => _shapePanel(p),
                          'member' => _memberPanel(p),
                          'holes' => _holesPanel(p),
                          'result' => _resultPanel(p, warn),
                          _ => _sendPanel(p),
                        },
                      ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: _navBar(idx),
          ),
        ),
      ),
    );
  }
}

/// 규격 고르기 창: 종류 단추 · 목록 · 직접 적기.
class _SpecSheet extends StatefulWidget {
  const _SpecSheet({required this.current});
  final String current;

  @override
  State<_SpecSheet> createState() => _SpecSheetState();
}

class _SpecSheetState extends State<_SpecSheet> {
  late int _cat;
  late String _pick;
  late final TextEditingController _custom;

  @override
  void initState() {
    super.initState();
    final c0 = bracketSpecCategory(widget.current);
    _cat = c0 < 0 ? 0 : c0;
    _pick = widget.current;
    final inList = kBracketSpecLists.any(
      (l) => l.$2.any((s) => s.label == widget.current),
    );
    _custom = TextEditingController(text: inList ? '' : widget.current);
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = kBracketSpecLists[_cat].$2;
    return PlateSheetFrame(
      title: '규격 고르기',
      okText: '이 규격 쓰기',
      okKey: const Key('br_spec_ok'),
      onOk: () => Navigator.pop(
        context,
        _custom.text.trim().isNotEmpty ? _custom.text.trim() : _pick,
      ),
      children: [
        PlateSegments([
          for (var i = 0; i < kBracketSpecLists.length; i++)
            PlateOption(
              'br_spec_cat_$i',
              kBracketSpecLists[i].$1,
              _cat == i,
              () => setState(() => _cat = i),
            ),
        ], joined: false),
        const SizedBox(height: 10),
        for (final s in list)
          Builder(
            builder: (_) {
              final on = _pick == s.label && _custom.text.trim().isEmpty;
              final p = BracketProfile.parse(s.label);
              final kg = p.kgPerM;
              return Material(
                color: on ? fc.brandSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  key: Key('br_spec_item_${s.label}'),
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => setState(() {
                    _pick = s.label;
                    _custom.clear();
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: fc.text,
                            ),
                          ),
                        ),
                        Text(
                          '${p.ks}${kg == null ? '' : ' · ${fmt(kg, 2)}kg/m'}',
                          style: TextStyle(fontSize: 12.5, color: fc.textSub),
                        ),
                        if (on) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_rounded, color: fc.brand, size: 18),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 12),
        PlateNumField(
          fieldKey: 'br_spec_custom',
          label: '목록에 없으면 직접 적기',
          controller: _custom,
          unit: null,
          text: true,
          hint: '예) 앵글 50x50x6',
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}

/// 관 하나 고르기 창: 종류(강관·전선관·튜브·직접 외경) · 호칭 · 나사 · 다리 간격.
class _PipeSheet extends StatefulWidget {
  const _PipeSheet({required this.index, required this.spec});
  final int index;
  final BracketPipeSpec spec;

  @override
  State<_PipeSheet> createState() => _PipeSheetState();
}

class _PipeSheetState extends State<_PipeSheet> {
  static const _groups = [...kBracketPipeGroups, '직접'];
  late String _group;
  late String _size;
  late int _thread;
  late final TextEditingController _od;
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    final sp = widget.spec;
    final row = sp.row;
    _group = sp.size.startsWith('D') ? '직접' : (row?.group ?? '강관');
    _size = sp.size.startsWith('D') ? '25A' : sp.size;
    _thread = sp.thread;
    _od = TextEditingController(
      text: sp.size.startsWith('D') ? sp.size.substring(1) : '',
    );
    _c = TextEditingController(text: sp.spacing > 0 ? fmt(sp.spacing) : '');
  }

  @override
  void dispose() {
    _od.dispose();
    _c.dispose();
    super.dispose();
  }

  BracketPipeSpec get _spec {
    final od = readNum(_od);
    final size = _group == '직접'
        ? (od == null || od <= 0 ? '' : 'D${fmt(od)}')
        : _size;
    final c = readNum(_c);
    return BracketPipeSpec(
      size,
      thread: _thread,
      spacing: c == null || c < 0 ? 0 : c,
    );
  }

  TextStyle get _sub => TextStyle(fontSize: 13, color: fc.textSub, height: 1.4);

  @override
  Widget build(BuildContext context) {
    final sp = _spec;
    final row = sp.size.isEmpty ? null : sp.row;
    final autoM = row?.thread ?? 10;
    final autoC = row == null ? 0.0 : row.uId + sp.threadUsed;
    return PlateSheetFrame(
      title: '${widget.index + 1}번 관',
      okText: '이 관 쓰기',
      okKey: const Key('br_up_ok'),
      error: row == null ? '관 외경을 넣으십시오.' : null,
      onOk: () {
        if (row == null) return;
        Navigator.pop(context, sp.text);
      },
      children: [
        PlateSegments([
          for (final g in _groups)
            PlateOption(
              'br_upg_$g',
              g,
              _group == g,
              () => setState(() {
                _group = g;
                if (g != '직접' &&
                    !kBracketPipeSizes.any(
                      (r) => r.group == g && r.name == _size,
                    )) {
                  _size = kBracketPipeSizes
                      .firstWhere((r) => r.group == g)
                      .name;
                }
                _c.clear();
              }),
            ),
        ]),
        const SizedBox(height: 10),
        if (_group != '직접')
          PlateSegments([
            for (final r in kBracketPipeSizes.where((r) => r.group == _group))
              PlateOption(
                'br_ups_${r.name}',
                r.name,
                _size == r.name,
                () => setState(() {
                  _size = r.name;
                  _c.clear();
                }),
              ),
          ], joined: false)
        else
          PlateNumField(
            fieldKey: 'br_up_od',
            label: '관 외경',
            controller: _od,
            hint: '예) 48.6',
            onChanged: (_) => setState(() {}),
          ),
        const SizedBox(height: 12),
        Text(
          '나사',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: fc.textSub,
          ),
        ),
        const SizedBox(height: 6),
        PlateSegments([
          PlateOption(
            'br_upm_0',
            '자동 M$autoM',
            _thread == 0,
            () => setState(() => _thread = 0),
          ),
          for (final m in kBracketUThreads)
            PlateOption(
              'br_upm_$m',
              'M$m',
              _thread == m,
              () => setState(() => _thread = m),
            ),
        ], joined: false),
        const SizedBox(height: 12),
        PlateNumField(
          fieldKey: 'br_up_c',
          label: '다리 간격 (다리 중심 사이)',
          controller: _c,
          hint: row == null ? '자동' : '자동 ${fmt(autoC)}',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (row != null)
          Text(
            '${row.name}: 외경 ${fmt(row.od)} · U볼트 내경 ${fmt(row.uId)} + 나사 M${sp.threadUsed} = 다리 간격 ${fmt(autoC)} · 홀 φ${fmt(bracketUHole(sp.threadUsed))}'
            '${row.approx ? ' (U볼트 값은 어림, 가진 U볼트를 재서 고치십시오)' : ''}',
            style: _sub,
          ),
      ],
    );
  }
}
