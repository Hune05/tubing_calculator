// 접지바 구멍 계산기(10-03): 구리 평강에 구멍을 한 줄·두 줄로 뚫고 끝을 L 탭·챙 달린 모자로 꺾어
// 접지바를 만들 때 자르는 길이와 구멍·꺾기 위치. 계산은 busbar_ground.dart.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'busbar_bend.dart' show BusbarBend;
import 'busbar_bend_page.dart' show busbarMinRadius, kBusbarK;
import 'busbar_bend_painter.dart' show BusbarShapePainter, busbarBendColor;
import 'busbar_ground.dart';
import 'busbar_ground_painter.dart';
import 'busbar_ground_pdf.dart';
import 'busbar_lug.dart';
import 'busbar_saved_specs.dart';
import 'elec_form_parts.dart';

Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

const List<String> kGroundBarBasis = [
  '구멍 줄: 한 줄은 폭 가운데, 두 줄은 가운데에서 줄 간격의 반씩 위아래입니다. 구멍 중심 피치가 같습니다. 구멍 수(한 줄)로 정하면 길이 = 2 × 끝 여유 + (구멍 수 − 1) × 피치. 길이로 정하면 들어가는 만큼 뚫고 남는 길이는 양 끝에 똑같이 나눕니다.',
  '두 줄: 대칭은 두 줄 구멍이 같은 자리에 마주 보고, 비대칭(엇갈림)은 B줄을 길이 방향으로 옮깁니다(비우면 반 피치). 엇갈린 만큼 구멍 줄이 길어집니다. 탭·챙 구멍도 같은 줄 수로 뚫고, 엇갈림은 탭 피치의 반입니다.',
  '구멍 크기: 구멍마다 지름을 따로 정할 수 있습니다. 바꾼 구멍은 위에서 본 그림에 주황 테두리로 보입니다. 폭 밖으로 나오거나 이웃 구멍과 겹치면 알립니다.',
  '구멍 지름 7/16"(약 11.1mm)는 NEMA 접지바(3/8" 볼트용)에서 제조사 자료 세 곳이 같습니다. 5/16"(약 7.9mm)는 통신 접지바(1/4" 볼트용)입니다.',
  '구멍 피치 3/4"(19.05)·1"(25.4)는 NEMA 2구멍 러그, 1-3/4"(44.45)는 NEMA 러그 패드, 5/8"(15.875)는 통신 접지바(BICSI·EIA/TIA 607) 구멍 줄입니다. 쓸 러그·터미널의 구멍 간격에 맞추십시오.',
  '끝 여유와 두 줄 줄 간격은 정해진 규격 값을 찾지 못했습니다. 기본 25mm·20mm는 임의 값이니 설계도나 러그 크기에 맞추십시오. 구멍이 끝 면을 뚫거나 서로 겹치는 경우만 알립니다.',
  '무게는 구리 밀도 8.9 g/cm³로 구멍을 뺀 부피에 곱한 근사값입니다.',
  '끝 L 꺾기: 두께 방향(눕혀 꺾기) 90°, 부스바 절곡 계산기와 같은 식(중립선 반경 r + k·t)입니다. 탭 길이는 바깥 치수, 최소 안쪽 반경은 CDA 한 곳 자료(두께 10mm 이하 1배)입니다. k 기본 0.4는 범위(0.33~0.5)의 가운데 값이니 시험 조각으로 맞추십시오.',
  '모자(챙 달림): 몸체 양쪽 다리를 90°로 내리고 다리 끝을 바깥으로 다시 꺾어 바닥에 대는 챙을 만듭니다. 치수는 모두 바깥 치수(챙 길이는 다리 바깥면까지, 높이는 챙 바닥면에서 윗면까지)이고 자르는 길이 = 왼쪽 챙 + 오른쪽 챙 + 2 × 높이 + 몸체 폭 − 4 × 굽힘 공제입니다. 챙은 왼쪽·오른쪽 길이를 따로 줄 수 있습니다.',
  '탭·챙(취부) 구멍은 평평한 길이(끝에서 꺾기 시작선까지) 가운데에 모아 뚫습니다. 줄 수·줄 간격·뚫을 챙(왼쪽·오른쪽·양쪽)은 접지 구멍과 따로 정합니다.',
  '접지 러그 구멍: 접지 구멍을 쓰지 않고 부스바 가운데(길이 방향 곧은 구간 가운데, 폭 가운데)에 따로 추가로 뚫습니다. 러그 1구멍은 구멍 하나, 2구멍은 러그 구멍 간격만큼 떨어진 구멍 둘이고, 러그가 여럿이면 러그 사이 간격으로 가운데에서 양쪽으로 놓습니다. 접지 구멍 한 줄과 같은 높이라 겹치면 알리니 접지 구멍을 두 줄(줄 간격은 러그 구멍 지름보다 넉넉히)로 하십시오. 볼트 세트 = 볼트 + 너트 + 평와셔 2 + 스프링 와셔 1(구멍 하나). 볼트 규격은 NEMA 접지바 7/16" 구멍 = 3/8" 볼트, 5/16" 구멍 = 1/4" 볼트, 그 밖에는 ISO 273 보통급 틈새 구멍(M6 6.6·M8 9·M10 11·M12 13.5·M16 17.5)으로 짐작합니다. 조임 토크와 산화방지제 종류는 러그·볼트 제조사 값을 따르며 이 앱은 값을 정하지 않습니다.',
  '구멍 사이 최소 간격: 구멍 피치·줄 간격(접지·취부)은 12mm보다 작게 넣어도 12mm로 올려 계산하고 알립니다(구멍 중심 사이 기준).',
  '접지바 취부: 모자 접지바를 챙 구멍으로 판넬에 설치할 때 판넬 구멍 가로 간격(왼쪽 구멍 0 기준)과 볼트 세트를 계산합니다. 판넬 두께 기본 3mm는 임의 값입니다.',
  '넣지 않은 것: 3줄 이상, 스프링백, 모서리 둥글림, 구멍 면취.',
];

class GroundBarPage extends StatefulWidget {
  const GroundBarPage({super.key, this.share = _defaultShare});

  /// 결과 글 보내기(시험에서 바꿔 끼운다).
  final Future<void> Function(String text) share;

  static const draftKey = 'busbar_ground_draft_v1';

  @override
  State<GroundBarPage> createState() => _GroundBarPageState();
}

class _GroundBarPageState extends State<GroundBarPage>
    with
        CalcFormParts<GroundBarPage>,
        RecentCalcHistoryMixin<GroundBarPage>,
        ElecTabParts<GroundBarPage> {
  bool _byLength = false; // false = 구멍 수로, true = 막대 길이로
  int _tabs = 0; // 끝 꺾기: 0 없음, 1 왼쪽 L, 2 오른쪽 L, 3 양쪽 L, 4 모자(챙 달림)
  int _mCount = 0; // 탭·챙 구멍 수(줄마다)
  int _rowMode = 0; // 0 한 줄, 1 두 줄 대칭, 2 두 줄 비대칭(엇갈림)
  int _tabRowMode = 0; // 탭·챙 구멍 줄(접지 구멍과 따로)
  int _tabSides = 3; // 취부 구멍을 뚫을 챙: 1 왼쪽, 2 오른쪽, 3 양쪽
  int _lug = 0; // 접지 러그: 0 없음, 1 1구멍, 2 2구멍
  bool _packGround = true; // 접지 구멍을 왼쪽(뒤)으로 몰고 러그 구멍은 그 뒤 가운데에
  double _k = 0.4;
  final Map<String, double> _overrides = {}; // 구멍 번호 → 지름
  String? _selHole;
  final _thick = TextEditingController(text: '6');
  final _width = TextEditingController(text: '50');
  final _hole = TextEditingController(text: '11.1');
  final _pitch = TextEditingController(text: '25.4');
  final _end = TextEditingController(text: '25');
  final _count = TextEditingController(text: '10');
  final _length = TextEditingController(text: '500');
  final _tabL = TextEditingController(text: '50');
  final _tabR = TextEditingController(text: '50');
  final _radius = TextEditingController(); // 비우면 두께 1배
  final _hatH = TextEditingController(text: '40');
  final _hatF = TextEditingController(text: '40');
  final _hatFR = TextEditingController(); // 비우면 왼쪽 챙과 같음
  final _mDia = TextEditingController(text: '11.1');
  final _mPitch = TextEditingController(text: '25.4');
  final _gap = TextEditingController(text: '20');
  final _shift = TextEditingController(); // 비우면 반 피치
  final _ovDia = TextEditingController();
  final _tabGap = TextEditingController(text: '20');
  final _lugSpacing = TextEditingController(text: '25.4');
  final _panelT = TextEditingController(text: '3'); // 취부면(판넬) 두께
  final _lugDia = TextEditingController(text: '11.1'); // 러그 구멍 지름
  final _jobName = TextEditingController(); // 작업 이름(지시서·저장 이름)
  final _lugPad = TextEditingController(text: '5');

  Timer? _saveTimer;
  bool _draftReady = false;

  List<TextEditingController> get _fields => [
    _thick,
    _width,
    _hole,
    _pitch,
    _end,
    _count,
    _length,
    _tabL,
    _tabR,
    _radius,
    _hatH,
    _hatF,
    _hatFR,
    _mDia,
    _mPitch,
    _gap,
    _shift,
    _tabGap,
    _lugSpacing,
    _lugPad,
    _panelT,
    _lugDia,
    _jobName,
  ];
  static const _fieldKeys = [
    't',
    'w',
    'h',
    'p',
    'e',
    'n',
    'l',
    'tl',
    'tr',
    'r',
    'hh',
    'hf',
    'hr',
    'md',
    'mp',
    'rg',
    'sh',
    'tg',
    'ls',
    'lp',
    'pnl',
    'ld',
    'jn',
  ];

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveNow();
    for (final c in [..._fields, _ovDia]) {
      c.dispose();
    }
    super.dispose();
  }

  String _draft() => jsonEncode({
    'bl': _byLength,
    'tb': _tabs,
    'mc': _mCount,
    'rm': _rowMode,
    'trm': _tabRowMode,
    'tsd': _tabSides,
    'lg': _lug,
    'pk': _packGround,
    'k': _k,
    'ov': _overrides,
    for (var i = 0; i < _fields.length; i++) _fieldKeys[i]: _fields[i].text,
  });

  Future<void> _loadDraft() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(GroundBarPage.draftKey);
      if (raw != null && mounted) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        setState(() => _applyMap(m));
      }
    } catch (_) {}
    _draftReady = true;
  }

  /// 저장된 값(입력칸·칩)을 화면 상태에 넣는다. setState 안에서 부른다.
  void _applyMap(Map<String, dynamic> m) {
    {
      {
        {
          if (m['bl'] is bool) _byLength = m['bl'] as bool;
          final tb = m['tb'], mc = m['mc'], rm = m['rm'], kk = m['k'];
          if (tb is int && tb >= 0 && tb <= 4) _tabs = tb;
          if (mc is int && mc >= 0 && mc <= 3) _mCount = mc;
          if (rm is int && rm >= 0 && rm <= 2) _rowMode = rm;
          final trm = m['trm'], tsd = m['tsd'], lg = m['lg'];
          if (trm is int && trm >= 0 && trm <= 2) _tabRowMode = trm;
          if (tsd is int && tsd >= 1 && tsd <= 3) _tabSides = tsd;
          if (lg is int && lg >= 0 && lg <= 2) _lug = lg;
          if (m['pk'] is bool) _packGround = m['pk'] as bool;
          if (kk is num && kBusbarK.contains(kk.toDouble())) _k = kk.toDouble();
          final ov = m['ov'];
          if (ov is Map) {
            _overrides.clear();
            ov.forEach((key, v) {
              if (key is String && v is num && v > 0) {
                _overrides[key] = v.toDouble();
              }
            });
          }
          for (var i = 0; i < _fields.length; i++) {
            final v = m[_fieldKeys[i]];
            if (v is String) _fields[i].text = v;
          }
        }
      }
    }
  }

  // ── 저장한 규격(공용 창 busbar_saved_specs.dart) ──

  /// 목록 한 줄에 보이는 요약: 두께×폭 · 끝 모양 · 러그.
  String _savedSummary(Map<String, dynamic> data) {
    final t = data['t'] is String ? data['t'] as String : '';
    final w = data['w'] is String ? data['w'] as String : '';
    final shape = switch (data['tb']) {
      1 => '왼쪽 L',
      2 => '오른쪽 L',
      3 => '양쪽 L',
      4 => '모자',
      _ => '곧은 막대',
    };
    final lug = switch (data['lg']) {
      1 => ' · 러그 1구멍',
      2 => ' · 러그 2구멍',
      _ => '',
    };
    return '$t×$w · $shape$lug';
  }

  Future<void> _openSavedSheet() => openSavedSpecs(
    context,
    storageKey: 'busbar_ground_saved_v1',
    current: () => jsonDecode(_draft()) as Map<String, dynamic>,
    summaryOf: _savedSummary,
    defaultName: _jobName.text.trim().isNotEmpty
        ? _jobName.text.trim()
        : '${_thick.text}×${_width.text} 접지바',
    onLoad: (m) => _set(() {
      _applyMap(m);
      _selHole = null;
      _ovDia.clear();
    }),
    surface: fc.surface,
    text: fc.text,
    textSub: fc.textSub,
  );

  void _saveSoon() {
    if (!_draftReady) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _saveNow);
  }

  void _saveNow() {
    if (!_draftReady) return;
    final d = _draft();
    SharedPreferences.getInstance()
        .then((p) => p.setString(GroundBarPage.draftKey, d))
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

  bool get _ready =>
      _num(_thick) > 0 &&
      _num(_width) > 0 &&
      _num(_hole) > 0 &&
      _num(_pitch) > 0 &&
      (_byLength ? _num(_length) > 0 : _num(_count) >= 1);

  bool get _twoRows => _rowMode != 0;

  GroundBarPlan? _plan() {
    if (!_ready) return null;
    final fr = readNum(_hatFR);
    final sh = readNum(_shift);
    return groundBar(
      t: _num(_thick),
      w: _num(_width),
      holeDia: _num(_hole),
      pitch: _num(_pitch),
      endDist: _num(_end),
      count: _byLength ? null : _num(_count).floor(),
      length: _byLength ? _num(_length) : null,
      tabLeft: _tabs & 1 != 0 ? _num(_tabL) : 0,
      tabRight: _tabs & 2 != 0 ? _num(_tabR) : 0,
      r: readNum(_radius),
      k: _k,
      hat: _tabs == 4,
      hatHeight: _num(_hatH),
      hatFlange: _num(_hatF),
      hatFlangeRight: fr != null && fr > 0 ? fr : null,
      rows: _twoRows ? 2 : 1,
      rowGap: _num(_gap),
      staggered: _rowMode == 2,
      shift: sh != null && sh > 0 ? sh : null,
      tabHoleCount: _tabs == 0 ? 0 : _mCount,
      tabHoleDia: _num(_mDia),
      tabHolePitch: _num(_mPitch),
      tabRows: _tabRowMode == 0 ? 1 : 2,
      tabRowGap: _num(_tabGap),
      tabStaggered: _tabRowMode == 2,
      tabSides: _tabSides,
      lugHoles: _lug,
      lugSpacing: _num(_lugSpacing),
      lugCount: _lug == 0 ? 0 : 1,
      lugHoleDia: _num(_lugDia),
      packGround: _packGround,
      overrides: Map.of(_overrides),
    );
  }

  double get _r => readNum(_radius) ?? _num(_thick);

  String? get _radiusWarn {
    if (_tabs == 0) return null;
    final min = busbarMinRadius(_num(_thick));
    if (_r + 1e-9 >= min) return null;
    return 'L 꺾기 안쪽 반경 ${fmt(_r)}mm가 최소 반경 ${fmt(min)}mm(CDA, 두께 ${fmt(_num(_thick))}mm 기준)보다 작습니다. 모서리가 갈라질 수 있습니다.';
  }

  String get _tabName => _tabs == 4 ? '챙' : '탭';

  /// 구멍 위치 한 줄 규칙: 첫 구멍·피치·마지막 구멍(A줄).
  String _ruleText(GroundBarPlan p) =>
      '첫 구멍 ${fmt(p.positions.first, 1)} → 피치 ${fmt(p.pitchUsed)} × ${p.holes - 1}칸 → 마지막 구멍 ${fmt(p.positions.last, 1)}';

  /// 두 줄 설명: 막대 한쪽 가장자리에서 줄 위치와 B줄 엇갈림.
  String _rowText(GroundBarPlan p) {
    if (p.rows == 1) return '구멍 줄은 폭 가운데 ${fmt(p.rowY.first, 1)}mm입니다.';
    return '${_rowMode == 1 ? "두 줄 대칭" : "두 줄 비대칭(엇갈림)"}: 막대 한쪽 가장자리에서 A줄 ${fmt(p.rowY[0], 1)} · B줄 ${fmt(p.rowY[1], 1)}mm'
        '${p.stagger > 0 ? ", B줄은 길이 방향으로 ${fmt(p.stagger, 1)}mm 옮김" : ""}.';
  }

  String _bendName(int i, GroundBarPlan p) {
    if (p.hat) {
      return const ['왼쪽 챙 → 다리', '왼쪽 다리 → 몸체', '몸체 → 오른쪽 다리', '오른쪽 다리 → 챙'][i];
    }
    final side = p.bends.length == 2
        ? (i == 0 ? '왼쪽' : '오른쪽')
        : (_tabs == 1 ? '왼쪽' : '오른쪽');
    return '$side 탭';
  }

  String _bendText(BusbarBend b, int i, GroundBarPlan p) =>
      '${i + 1}. ${_bendName(i, p)} 꺾기 시작선 ${fmt(b.start, 1)} · 끝선 ${fmt(b.end, 1)}mm';

  /// 구멍 가장자리 ~ 꺾기 시작선 거리(구멍 종류별). 꺾을 때 구멍이 늘어나는지 가늠하는 값.
  String _edgeLine(GroundBarPlan p) {
    final t = _num(_thick);
    String one(String name, double d) =>
        '$name ${fmt(d, 1)}mm(두께의 ${fmt(t > 0 ? d / t : 0, 1)}배)';
    final parts = [
      if (p.minEdgeBody != null) one('접지·러그 구멍', p.minEdgeBody!),
      if (p.minEdgeTab != null) one('$_tabName 구멍', p.minEdgeTab!),
    ];
    return '구멍 가장자리 ~ 꺾기 시작선 거리: ${parts.join(' · ')}. 가까울수록 꺾을 때 구멍이 늘어날 수 있습니다.';
  }

  /// 탭·챙 구멍 수 설명: 어느 쪽에 몇 개인지 풀어 쓴다.
  String _tabHoleSummary(GroundBarPlan p) {
    final l = p.tabHoleList.where((h) => h.label.startsWith('왼쪽')).length;
    final r = p.tabHoleList.where((h) => h.label.startsWith('오른쪽')).length;
    final flat =
        p.flatTabL > 0 && p.tabHoleList.any((h) => h.label.startsWith('왼쪽'))
        ? p.flatTabL
        : p.flatTabR;
    final parts = [
      if (l > 0) '왼쪽 $_tabName $l개',
      if (r > 0) '오른쪽 $_tabName $r개',
    ];
    return '$_tabName 구멍 φ${fmt(_num(_mDia))}: ${parts.join(' + ')}(합계 ${p.tabHoleList.length}개). 평평한 길이 ${fmt(flat, 1)}mm 가운데에 있습니다.';
  }

  String _holeLine(GroundHole h) =>
      '${h.label} ${fmt(h.x, 1)}${h.custom ? " φ${fmt(h.dia)}" : ""}';

  /// 접지바 가공 지시서(PDF)에 넣을 내용. 글은 화면에 보이는 것과 같은 말을 쓴다.
  GroundPdfInput _pdfInput(GroundBarPlan p) {
    final t = _num(_thick), w = _num(_width);
    final shape = switch (_tabs) {
      1 => '왼쪽 끝 L 꺾기 (탭 ${fmt(_num(_tabL))}mm)',
      2 => '오른쪽 끝 L 꺾기 (탭 ${fmt(_num(_tabR))}mm)',
      3 => '양쪽 끝 L 꺾기 (탭 ${fmt(_num(_tabL))} / ${fmt(_num(_tabR))}mm)',
      4 =>
        '모자(챙 달림): 높이 ${fmt(_num(_hatH))}, 챙 ${fmt(_num(_hatF))} / ${fmt(readNum(_hatFR) ?? _num(_hatF))}mm',
      _ => '곧은 막대(꺾지 않음)',
    };
    final custom = [
      ...p.groundHoles,
      ...p.tabHoleList,
      ...p.lugHoleList,
    ].where((h) => h.custom).toList();
    final summary = <(String, String)>[
      ('재료', '구리 평강 ${fmt(t)} × ${fmt(w)} mm'),
      ('끝 모양', shape),
      ('자르는 길이', '${fmt(p.length, 1)} mm (약 ${fmt(p.weightKg, 2)} kg)'),
      (
        '접지 구멍',
        'φ${fmt(_num(_hole))} · ${p.rows == 2 ? "${p.holes}개 × 2줄" : "${p.holes}개"} · 피치 ${fmt(p.pitchUsed)}mm',
      ),
      if (p.holes > 0) ('구멍 줄', _rowText(p)),
      if (p.tabHoleList.isNotEmpty)
        ('$_tabName 구멍', _tabHoleSummary(p).replaceFirst('$_tabName 구멍 ', '')),
      if (p.lugHoleList.isNotEmpty)
        (
          '러그 구멍',
          '${_lug == 2 ? "2구멍" : "1구멍"} 러그 · ${p.lugHoleList.length}개 · φ${fmt(_num(_lugDia))}${_lug == 2 ? " · 구멍 간격 ${fmt(_num(_lugSpacing))}mm" : ""} (접지 구멍과 따로)',
        ),
      if (p.bends.isNotEmpty)
        ('꺾기 조건', '안쪽 반경 ${fmt(_r)}mm · k ${fmt(_k, 2)} · 눕혀 꺾기 90°'),
      if (custom.isNotEmpty)
        (
          '크기 바꾼 구멍',
          custom.map((h) => '${h.label} φ${fmt(h.dia)}').join(' · '),
        ),
    ];
    final sections = <GroundPdfSection>[
      if (p.holes > 0)
        GroundPdfSection('접지 구멍 위치 (왼쪽 끝에서 중심까지, mm)', [
          _ruleText(p),
          for (final (label, vals) in groundHoleRows(
            p.positions,
            prefix: p.rows == 2 ? 'A' : '',
          ))
            '$label   ${vals.map((v) => fmt(v, 1)).join("   ")}',
          if (p.rows == 2)
            for (final (label, vals) in groundHoleRows(
              p.positionsB,
              prefix: 'B',
            ))
              '$label   ${vals.map((v) => fmt(v, 1)).join("   ")}',
          '검산: 마지막 접지 구멍에서 ${_tabs == 4 || _tabs & 2 != 0 ? "꺾기 시작선" : "끝"}까지 ${fmt(p.endRight, 1)}mm.',
        ]),
      if (p.tabHoleList.isNotEmpty)
        GroundPdfSection('$_tabName 구멍 위치 (왼쪽 끝에서 중심까지, mm)', [
          for (final h in p.tabHoleList)
            '${h.label}   ${fmt(h.x, 1)}   (폭 방향 ${fmt(h.y, 1)}mm, φ${fmt(h.dia)})',
        ]),
      if (p.lugHoleList.isNotEmpty)
        GroundPdfSection('접지 러그 구멍 위치 (접지 구멍과 따로, 왼쪽 끝에서 중심까지, mm)', [
          for (final h in p.lugHoleList)
            '${h.label}   ${fmt(h.x, 1)}   (폭 방향 ${fmt(h.y, 1)}mm, φ${fmt(h.dia)})',
          '볼트 세트 ${p.lugHoleList.length}개 = ${_lugParts(p.lugHoleList.length).join(" · ")}',
          '볼트가 지나는 두께(그립) ${fmt(_num(_lugPad) + t, 1)}mm = 러그 패드 ${fmt(_num(_lugPad), 1)} + 부스바 ${fmt(t, 1)}.',
        ]),
      if (_panel(p).isNotEmpty)
        GroundPdfSection('판넬 취부 자리 (가장 왼쪽 구멍 = 0, mm)', [
          for (final h in _panel(p))
            '${h.hole.label}   가로 ${fmt(h.x, 1)} · 세로 ${fmt(h.y, 1)} (막대 A쪽 가장자리 기준)',
          if (_panel(p).length > 1)
            '왼쪽 구멍과 오른쪽 구멍 가로 간격 ${fmt(_panel(p).last.x - _panel(p).first.x, 1)}mm (구멍 중심 사이).',
          '볼트 세트 ${p.tabHoleList.length}개 = 볼트 ${lugBoltFor(_num(_mDia)) ?? "구멍에 맞는 규격"} ${p.tabHoleList.length}개 · 너트 · 평와셔 2개 · 스프링 와셔 1개(개당).',
          '볼트가 지나는 두께(그립) ${fmt(t + _num(_panelT), 1)}mm = 부스바 ${fmt(t, 1)} + 판넬 ${fmt(_num(_panelT), 1)}.',
        ]),
    ];
    return GroundPdfInput(
      title: _jobName.text,
      plan: p,
      thickness: t,
      width: w,
      rho: _r + _k * t,
      summary: summary,
      bendRows: [
        for (var i = 0; i < p.bends.length; i++)
          [
            '${i + 1}',
            _bendName(i, p),
            fmt(p.bends[i].start, 1),
            fmt(p.bends[i].end, 1),
          ],
      ],
      sections: sections,
      notes: [
        ...p.problems,
        ...p.notes,
        ?_radiusWarn,
        if (p.minEdgeBody != null || p.minEdgeTab != null) _edgeLine(p),
      ],
    );
  }

  String _shareText(GroundBarPlan p) {
    final b = StringBuffer(
      '[접지바] 구리 ${fmt(_num(_thick))}×${fmt(_num(_width))}mm · 구멍 φ${fmt(_num(_hole))} ${p.rows == 2 ? "${p.holes}개 × 2줄" : "${p.holes}개"} 피치 ${fmt(p.pitchUsed)}',
    );
    b.write('\n자르는 길이: ${fmt(p.length, 1)}mm (약 ${fmt(p.weightKg, 2)}kg)');
    b.write('\n${_rowText(p)}');
    if (p.bends.isNotEmpty) {
      final tab = _tabs == 4
          ? '모자 높이 ${fmt(_num(_hatH))} · 챙 ${fmt(_num(_hatF))} / ${fmt(readNum(_hatFR) ?? _num(_hatF))}'
          : _tabs == 3
          ? '탭 양쪽 ${fmt(_num(_tabL))} / ${fmt(_num(_tabR))}'
          : '탭 ${fmt(_num(_tabs == 1 ? _tabL : _tabR))}';
      b.write(
        '\n꺾기 (왼쪽 끝에서, ${tab}mm 바깥 치수, 안쪽 반경 ${fmt(_r)}, k ${fmt(_k, 2)}):',
      );
      for (var i = 0; i < p.bends.length; i++) {
        b.write('\n ${_bendText(p.bends[i], i, p)}');
      }
    }
    if (p.tabHoleList.isNotEmpty) {
      b.write(
        '\n$_tabName 구멍 φ${fmt(_num(_mDia))} (왼쪽 끝에서 중심): ${p.tabHoleList.map(_holeLine).join(" · ")}',
      );
    }
    if (p.holes > 0) {
      b.write('\n접지 구멍 위치 (왼쪽 끝에서 중심까지): ${_ruleText(p)}');
      for (final (label, vals) in groundHoleRows(
        p.positions,
        prefix: p.rows == 2 ? 'A' : '',
      )) {
        b.write('\n $label ${vals.map((v) => fmt(v, 1)).join(' · ')}');
      }
      if (p.rows == 2) {
        for (final (label, vals) in groundHoleRows(p.positionsB, prefix: 'B')) {
          b.write('\n $label ${vals.map((v) => fmt(v, 1)).join(' · ')}');
        }
      }
    }
    final pts = _panel(p);
    if (pts.isNotEmpty) {
      b.write(
        '\n판넬 취부 구멍(왼쪽 구멍 0 기준): ${pts.map((h) => "${h.hole.label} 가로 ${fmt(h.x, 1)}/세로 ${fmt(h.y, 1)}").join(" · ")}',
      );
    }
    final groups = _lugGroups(p);
    if (groups.isNotEmpty) {
      b.write(
        '\n접지 러그 ${_lug == 2 ? "2구멍" : "1구멍"} ${groups.length}개(접지 구멍과 따로, 폭 가운데 ${fmt(p.lugHoleList.first.y, 1)}mm 추가 구멍 φ${fmt(_num(_lugDia))}):',
      );
      for (final e in groups.entries) {
        b.write('\n ${_lugLine(e.key, e.value)}');
      }
      b.write(
        '\n볼트 세트 ${p.lugHoleList.length}개 = ${_lugParts(p.lugHoleList.length).join(" · ")}',
      );
    }
    final custom = [
      ...p.groundHoles,
      ...p.tabHoleList,
      ...p.lugHoleList,
    ].where((h) => h.custom).toList();
    if (custom.isNotEmpty) {
      b.write(
        '\n크기 바꾼 구멍: ${custom.map((h) => "${h.label} φ${fmt(h.dia)}").join(" · ")}',
      );
    }
    for (final s in p.problems) {
      b.write('\n※ $s');
    }
    return b.toString();
  }

  // ── 화면 부품 ──

  Widget _bendTile(BusbarBend b, int i, GroundBarPlan p) {
    return calcBox(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: busbarBendColor(b.turn),
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_bendName(i, p)} · 시작선 ${fmt(b.start, 1)} mm',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: fc.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '꺾기 시작선 ${fmt(b.start, 1)} → 끝선 ${fmt(b.end, 1)} (호 ${fmt(b.end - b.start, 1)}mm). 90°로 꺾습니다.',
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
    );
  }

  Widget _valueRow(String label, List<String> vals, {double labelWidth = 64}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: fc.textSub,
                ),
              ),
            ),
            Expanded(
              child: Text(
                vals.join('   '),
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: fc.text,
                ),
              ),
            ),
          ],
        ),
      );

  /// 탭·챙 구멍: 왼쪽·오른쪽, 줄마다.
  Widget _tabHoleBox(GroundBarPlan p) {
    final rows = <Widget>[];
    for (final side in const ['왼쪽', '오른쪽']) {
      final hs = p.tabHoleList.where((h) => h.label.startsWith(side)).toList();
      if (hs.isEmpty) continue;
      if (p.tabRows == 1) {
        rows.add(
          _valueRow(side, [
            for (final h in hs)
              fmt(h.x, 1) + (h.custom ? ' (φ${fmt(h.dia)})' : ''),
          ], labelWidth: 70),
        );
      } else {
        for (final rl in const ['A', 'B']) {
          final rh = hs.where((h) => h.label.contains(' $rl')).toList();
          rows.add(
            _valueRow('$side $rl', [
              for (final h in rh)
                fmt(h.x, 1) + (h.custom ? ' (φ${fmt(h.dia)})' : ''),
            ], labelWidth: 84),
          );
        }
      }
    }
    return KeyedSubtree(
      key: const Key('gb_tab_holes'),
      child: calcBox(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...rows,
              Text(
                '펼친 막대 왼쪽 끝에서 잰 구멍 중심입니다. 폭 방향은 ${p.tabRows == 1 ? "가운데" : "A줄 ${fmt(p.tabRowY[0], 1)} · B줄 ${fmt(p.tabRowY[1], 1)}mm"}입니다.',
                style: TextStyle(fontSize: 13, color: fc.textSub),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 접지 구멍: 규칙 한 줄 + 5개씩 묶은 표 + 마지막 구멍 검산.
  Widget _holeBox(GroundBarPlan p) {
    final two = p.rows == 2;
    final rowsA = groundHoleRows(p.positions, prefix: two ? 'A' : '');
    final rowsB = two ? groundHoleRows(p.positionsB, prefix: 'B') : [];
    return calcBox(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _ruleText(p),
              key: const Key('gb_rule'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: fc.text,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              two
                  ? '${_rowText(p)} 피치가 같아 첫 구멍만 재고 피치 간격으로 이어 찍으면 됩니다. 아래는 하나씩 재는 값(5개씩 묶음)입니다.'
                  : '피치가 같아 첫 구멍만 재고 피치 간격으로 이어 찍으면 됩니다. 아래는 하나씩 재는 값(5개씩 묶음)입니다.',
              style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.35),
            ),
            const SizedBox(height: 8),
            for (final (label, vals) in rowsA)
              _valueRow(label, [
                for (final v in vals) fmt(v, 1),
              ], labelWidth: two ? 76 : 64),
            if (two) const SizedBox(height: 4),
            for (final (label, vals) in rowsB)
              _valueRow(label, [
                for (final v in vals) fmt(v, 1),
              ], labelWidth: 76),
            const SizedBox(height: 4),
            Text(
              '검산: 마지막 구멍에서 ${_tabs == 4 || _tabs & 2 != 0 ? '꺾기 시작선' : '끝'}까지 ${fmt(p.endRight, 1)}mm가 남아야 합니다.',
              style: TextStyle(fontSize: 13, color: fc.textSub),
            ),
          ],
        ),
      ),
    );
  }

  // ── 접지 러그 구멍(접지 구멍과 따로, 부스바 가운데에 추가) ──

  /// 러그 번호(1부터) → 그 러그의 구멍들.
  Map<int, List<GroundHole>> _lugGroups(GroundBarPlan p) {
    final m = <int, List<GroundHole>>{};
    for (final h in p.lugHoleList) {
      final k = int.parse(h.id.substring(1, h.id.indexOf('-')));
      m.putIfAbsent(k, () => []).add(h);
    }
    return m;
  }

  String _lugLine(int k, List<GroundHole> hs) =>
      '러그 $k: 왼쪽 끝에서 ${hs.map((h) => fmt(h.x, 1)).join(' · ')}${hs.any((h) => h.custom) ? ' (φ${hs.map((h) => fmt(h.dia)).join("/")})' : ''}';

  List<String> _lugParts(int bolts) {
    final bolt = lugBoltFor(_num(_lugDia));
    return [
      '볼트 ${bolt ?? "구멍에 맞는 규격"} $bolts개',
      '너트 $bolts개',
      '평와셔 ${bolts * 2}개',
      '스프링 와셔 $bolts개',
    ];
  }

  List<Widget> _lugSection(GroundBarPlan p) {
    if (p.holes == 0) return const [];
    final groups = _lugGroups(p);
    final bolts = p.lugHoleList.length;
    return [
      elecSectionTitle('접지 러그 구멍 (가운데에 추가)'),
      elecChipGroup(
        '러그 종류',
        '접지 러그를 달 구멍을 접지 구멍과 따로 부스바 가운데(길이·폭)에 추가로 뚫습니다. 1구멍: 러그당 구멍 하나. 2구멍: 러그 구멍 간격만큼 떨어진 구멍 둘(NEMA 2구멍 러그).',
        [
          for (final (i, label) in const [
            (0, '안 붙임'),
            (1, '1구멍 러그'),
            (2, '2구멍 러그'),
          ])
            calcChip('gb_lug_$i', label, _lug == i, () {
              _set(() {
                if (_lug == 0 && i != 0) {
                  // 외부 접지 러그는 크다: 처음 켤 때 큰 러그 기본값(M12 구멍, 1-3/4" 간격)
                  if (_lugDia.text.trim() == '11.1') _lugDia.text = '13.5';
                  if (_lugSpacing.text.trim() == '25.4') {
                    _lugSpacing.text = '44.45';
                  }
                }
                _lug = i;
              });
            }),
        ],
      ),
      if (_lug != 0) ...[
        elecField(
          'gb_lugdia',
          '러그 구멍 지름 (mm)',
          _lugDia,
          '러그 볼트가 지나는 구멍 지름입니다. ${_lug == 2 ? "2구멍 러그의 구멍 둘 모두" : "1구멍 러그의 구멍"}에 적용됩니다. 접지 구멍과 다르게 줄 수 있고, 구멍마다 따로 바꾸려면 아래 "구멍 크기 바꾸기"를 씁니다.',
          onEdit: _saveSoon,
        ),
        _presetChips(
          'gb_lugd_',
          _lugDia,
          const [11.1, 13.5, 17.5],
          (v) => switch (v) {
            11.1 => 'φ11.1 (3/8")',
            13.5 => 'φ13.5 (M12)',
            _ => 'φ17.5 (M16)',
          },
        ),
        const SizedBox(height: 8),
        if (_lug == 2) ...[
          elecField(
            'gb_lugsp',
            '러그 구멍 간격 (mm)',
            _lugSpacing,
            '2구멍 러그의 두 구멍 중심 사이 거리입니다(NEMA 3/4"=19.05, 1"=25.4, 1-3/4"=44.45). 구멍 중심 사이 최소 12mm입니다.',
            onEdit: _saveSoon,
          ),
          _presetChips(
            'gb_lsp_',
            _lugSpacing,
            kLugSpacings,
            (v) => switch (v) {
              19.05 => '3/4" (19)',
              25.4 => '1" (25.4)',
              _ => '1-3/4" (44.5)',
            },
          ),
          const SizedBox(height: 8),
        ],
        elecChipGroup(
          '접지 구멍 놓는 방법',
          '뒤로 몰기: 기본 접지 구멍을 왼쪽 끝에서부터 한 줄로 촘촘히 놓고, 큰 러그 구멍은 그 뒤 남는 자리 가운데에 같은 줄로 둡니다. 가운데 균등: 접지 구멍을 막대 가운데에 고르게 놓고 러그 구멍을 그 가운데에 겹쳐 둡니다(겹치면 알림)..',
          [
            calcChip(
              'gb_pack_on',
              '뒤로 몰기',
              _packGround,
              () => _set(() => _packGround = true),
            ),
            calcChip(
              'gb_pack_off',
              '가운데 균등',
              !_packGround,
              () => _set(() => _packGround = false),
            ),
          ],
        ),
        const SizedBox(height: 8),
        elecField(
          'gb_lugpad',
          '러그 패드 두께 (mm)',
          _lugPad,
          '러그 볼트 자리(패드)의 두께입니다. 러그 규격서 값을 넣으십시오. 5는 임의 기본값입니다.',
          onEdit: _saveSoon,
        ),
        if (groups.isNotEmpty)
          calcResult(
            key: const Key('gb_lug_result'),
            big: '러그 구멍 $bolts개 · 볼트 세트 $bolts',
            caption:
                '접지 러그 ${groups.length}개 · 폭 가운데 ${fmt(p.lugHoleList.first.y, 1)}mm · 접지 구멍과 따로',
            warn: !p.ok,
            lines: [
              for (final e in groups.entries) _lugLine(e.key, e.value),
              _packGround
                  ? '접지 구멍은 왼쪽 끝으로 몰았고, 러그 구멍은 접지 구멍과 따로 그 뒤 남는 자리 가운데에 같은 줄로 추가했습니다(펼친 막대 왼쪽 끝에서 잰 거리).'
                  : '러그 구멍은 접지 구멍을 쓰지 않고 부스바 가운데에 추가한 구멍입니다(펼친 막대 왼쪽 끝에서 잰 거리).',
              '볼트 세트 $bolts개 = ${_lugParts(bolts).join(' · ')}',
              '볼트가 지나는 두께(그립) ${fmt(_num(_lugPad) + _num(_thick), 1)}mm = 러그 패드 ${fmt(_num(_lugPad), 1)} + 부스바 ${fmt(_num(_thick), 1)}. 볼트 길이는 여기에 평와셔 2장·스프링 와셔·너트 두께와 나사 2~3산을 더한 것 이상으로 고릅니다(와셔·너트 두께는 제품마다 다릅니다).',
            ],
          ),
        if (groups.isNotEmpty)
          calcResult(
            key: const Key('gb_lug_notes'),
            big: '러그 취부 방법',
            caption: '접지 러그를 접지바에 붙일 때',
            lines: const [
              '러그 패드와 부스바 접촉면의 도장·산화막을 닦아 냅니다(구리는 광이 날 때까지, 도장 부스바는 접촉 자리만 벗깁니다).',
              '접촉면에 산화방지제(컴파운드)를 얇게 바르고 러그 패드를 부스바에 평평하게 댑니다.',
              '볼트는 평와셔를 끼워 러그 쪽에서 넣고, 반대쪽에서 평와셔 → 스프링 와셔 → 너트 순으로 체결합니다. 너트를 한쪽에 몰면 러그가 틀어지니 2구멍 러그는 두 볼트를 번갈아 조입니다.',
              '조임 토크는 러그·볼트 제조사 값이나 사내 기준을 따릅니다(이 앱은 값을 정하지 않습니다). 규정 토크로 조인 뒤 표시선(페인트 마킹)을 긋습니다.',
              '체결 후 러그가 헐겁지 않은지, 케이블 무게가 볼트에 걸리지 않는지 확인합니다.',
            ],
          ),
      ],
    ];
  }

  // ── 접지바 취부(챙·탭 구멍으로 설치) ──

  List<PanelHole> _panel(GroundBarPlan p) => panelPattern(
    p,
    flangeLeft: _num(_hatF),
    flangeRight: readNum(_hatFR) ?? _num(_hatF),
  );

  List<Widget> _mountSection(GroundBarPlan p) {
    if (p.tabHoleList.isEmpty) return const [];
    final holes = p.tabHoleList;
    final bolt = lugBoltFor(_num(_mDia));
    final grip = _num(_thick) + _num(_panelT);
    final pts = _panel(p);
    final only = holes.length;
    return [
      elecSectionTitle('접지바 취부 (${p.hat ? "챙으로 판넬에" : "탭으로"} 설치)'),
      elecField(
        'gb_panelt',
        '취부면(판넬) 두께 (mm)',
        _panelT,
        '접지바를 올려 볼트로 조일 판넬(또는 앵글) 두께입니다. 3은 임의 기본값이니 실제 두께를 넣으십시오.',
        onEdit: _saveSoon,
      ),
      calcResult(
        key: const Key('gb_mount_result'),
        big: '취부 구멍 $only개 · 볼트 세트 $only',
        caption: '접지바를 ${p.hat ? "챙" : "탭"} 구멍으로 취부',
        lines: [
          if (pts.isNotEmpty) ...[
            '판넬에 뚫을 구멍 자리(가장 왼쪽 구멍 = 0, 막대 A쪽 가장자리 기준 세로):',
            for (final h in pts)
              '   ${h.hole.label}  가로 ${fmt(h.x, 1)} · 세로 ${fmt(h.y, 1)}mm',
            if (pts.length > 1 && pts.first.x != pts.last.x)
              '왼쪽 구멍과 오른쪽 구멍 가로 간격 ${fmt(pts.last.x - pts.first.x, 1)}mm(구멍 중심 사이). 이 간격으로 판넬에 마킹합니다.',
          ] else
            '탭 구멍은 접지바를 꺾기 전 위치입니다. 꺾은 뒤 탭이 닿는 면의 구멍 자리는 현장에서 탭을 대고 마킹합니다.',
          '볼트 세트 $only개 = 볼트 ${bolt ?? "구멍에 맞는 규격"} $only개 · 너트 $only개 · 평와셔 ${only * 2}개 · 스프링 와셔 $only개 (판넬에 탭이 있으면 너트는 뺍니다)',
          '볼트가 지나는 두께(그립) ${fmt(grip, 1)}mm = ${p.hat ? "챙" : "탭"}(부스바) ${fmt(_num(_thick), 1)} + 판넬 ${fmt(_num(_panelT), 1)}. 볼트 길이는 여기에 와셔·너트 두께와 나사 2~3산을 더한 것 이상으로 고릅니다.',
          if (_mDia.text.trim().isNotEmpty)
            '판넬 구멍은 ${p.hat ? "챙" : "탭"} 구멍과 같은 φ${fmt(_num(_mDia))}로 뚫거나, 판넬에 탭을 낼 때는 볼트 호칭에 맞는 드릴을 씁니다.',
        ],
      ),
      calcResult(
        key: const Key('gb_mount_notes'),
        big: '접지바 취부 방법',
        caption: '${p.hat ? "챙 달린 모자 접지바" : "탭 접지바"}를 판넬에 설치할 때',
        lines: [
          '판넬 마킹: 위 가로 간격으로 판넬에 구멍 자리를 긋고, 접지바를 대어 구멍이 맞는지 확인한 뒤 뚫습니다.',
          '접촉면 처리: 접지바 바닥과 판넬 접촉 자리의 도장·산화막을 벗겨 금속면을 드러내고 산화방지제를 얇게 바릅니다(구리와 도금 강판이 닿는 곳은 접촉 부식에 주의).',
          '체결: 볼트에 평와셔를 끼워 ${p.hat ? "챙" : "탭"}과 판넬을 지나게 한 뒤 반대쪽에서 평와셔 → 스프링 와셔 → 너트 순으로 조입니다. 양쪽 챙 볼트를 번갈아 조여 접지바가 비틀리지 않게 합니다.',
          '조임 토크는 볼트·접지바 제조사 값이나 사내 기준을 따릅니다(이 앱은 값을 정하지 않습니다). 조인 뒤 표시선을 긋습니다.',
          '절연 접지바(판넬과 따로 접지해야 하는 것)는 판넬과 닿는 곳에 절연 받침을 끼우고 절연 볼트 세트를 씁니다. 판넬 접지로 쓰는 일반 접지바는 금속 접촉으로 취부합니다.',
          '취부 뒤 접지바 위에 접지 러그를 붙이고(위 "접지 러그 구멍") 러그·접지바·판넬 접촉 저항을 점검합니다.',
        ],
      ),
    ];
  }

  /// 구멍별 크기 바꾸기: 구멍을 고르고 지름을 넣어 적용.
  List<Widget> _sizeEditor(GroundBarPlan p) {
    final all = [...p.groundHoles, ...p.tabHoleList, ...p.lugHoleList];
    if (all.isEmpty) return const [];
    final sel = all.firstWhere(
      (h) => h.id == _selHole,
      orElse: () => all.first,
    );
    String name(GroundHole h) =>
        '${h.id.startsWith('g') ? '접지' : (h.id.startsWith('u') ? '' : _tabName)} ${h.label} · φ${fmt(h.dia)}${h.custom ? ' (바꿈)' : ''}';
    return [
      elecSectionTitle('구멍 크기 바꾸기'),
      calcDropdown<String>(
        'gb_ov_sel',
        '구멍 고르기',
        sel.id,
        [for (final h in all) h.id],
        (id) => name(all.firstWhere((h) => h.id == id)),
        (id) => _set(() => _selHole = id),
        '크기를 따로 줄 구멍을 고릅니다. 접지 구멍은 번호(두 줄이면 A·B줄), 탭·챙 구멍은 왼쪽·오른쪽 번호입니다.',
      ),
      elecField(
        'gb_ovdia',
        '이 구멍 지름 (mm)',
        _ovDia,
        '고른 구멍에만 적용할 지름입니다. 기본 지름과 같게 넣으면 기본으로 돌아갑니다.',
        onEdit: () {},
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            calcChip('gb_ov_apply', '이 구멍에 적용', false, () {
              final v = readNum(_ovDia);
              if (v == null || v <= 0) return;
              final base = sel.id.startsWith('g')
                  ? _num(_hole)
                  : (sel.id.startsWith('u') ? _num(_lugDia) : _num(_mDia));
              _set(() {
                _selHole = sel.id;
                if ((v - base).abs() < 1e-9) {
                  _overrides.remove(sel.id);
                } else {
                  _overrides[sel.id] = v;
                }
              });
            }),
            calcChip('gb_ov_reset', '이 구멍 기본으로', false, () {
              _set(() => _overrides.remove(sel.id));
            }),
            calcChip('gb_ov_clear', '전부 기본으로', false, () {
              _set(_overrides.clear);
            }),
          ],
        ),
      ),
      if (p.customCount > 0)
        calcBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '바꾼 구멍 ${p.customCount}개: ${[...p.groundHoles, ...p.tabHoleList, ...p.lugHoleList].where((h) => h.custom).map((h) => "${h.label} φ${fmt(h.dia)}").join(" · ")}',
              key: const Key('gb_ov_list'),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: fc.text,
                height: 1.4,
              ),
            ),
          ),
        ),
    ];
  }

  Widget _presetChips(
    String keyPrefix,
    TextEditingController c,
    List<double> values,
    String Function(double) label,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final v in values)
        calcChip(
          '$keyPrefix${(v * 100).round()}',
          label(v),
          readNum(c) == v,
          () => _set(() => c.text = fmt(v, 3)),
        ),
    ],
  );

  Widget _drawing(Key key, double height, CustomPainter painter) => Container(
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

  @override
  Widget build(BuildContext context) {
    final p = _plan();
    final warn = p != null && !p.ok;
    String? summary;
    final children = <Widget>[
      elecField(
        'gb_job',
        '작업 이름 (선택)',
        _jobName,
        '지시서 PDF 제목과 규격 저장 이름에 쓰입니다. 비워도 됩니다.',
        onEdit: _saveSoon,
      ),
      elecChipGroup(
        '무엇으로 정하나',
        '구멍 수: 한 줄 구멍 수와 피치로 자르는 길이를 계산합니다. 막대 길이: 가진 막대 길이에 구멍이 몇 개 들어가는지 계산합니다.',
        [
          calcChip(
            'gb_by_count',
            '구멍 수로',
            !_byLength,
            () => _set(() => _byLength = false),
          ),
          calcChip(
            'gb_by_len',
            '막대 길이로',
            _byLength,
            () => _set(() => _byLength = true),
          ),
        ],
      ),
      elecSectionTitle('부스바'),
      elecField('gb_t', '두께 (mm)', _thick, '구리 부스바 두께입니다.', onEdit: _saveSoon),
      elecField('gb_w', '폭 (mm)', _width, '구리 부스바 폭입니다.', onEdit: _saveSoon),
      elecSectionTitle('구멍'),
      elecChipGroup(
        '구멍 줄',
        '한 줄: 폭 가운데. 두 줄 대칭: 두 줄 구멍이 같은 자리에 마주 봅니다. 두 줄 비대칭: 두 줄이 엇갈립니다(B줄을 길이 방향으로 옮김).',
        [
          for (final (i, label) in const [
            (0, '한 줄'),
            (1, '두 줄 · 대칭'),
            (2, '두 줄 · 비대칭'),
          ])
            calcChip(
              'gb_rm_$i',
              label,
              _rowMode == i,
              () => _set(() => _rowMode = i),
            ),
        ],
      ),
      if (_twoRows)
        elecField(
          'gb_gap',
          '줄 간격 (mm)',
          _gap,
          '두 줄 구멍 중심 사이 거리입니다. 폭 가운데에서 위아래로 반씩 놓습니다.',
          onEdit: _saveSoon,
        ),
      if (_rowMode == 2)
        elecField(
          'gb_shift',
          'B줄 엇갈림 (mm, 비우면 반 피치)',
          _shift,
          'B줄을 A줄보다 길이 방향으로 옮기는 거리입니다. 비우면 피치의 반입니다.',
          onEdit: _saveSoon,
        ),
      elecField(
        'gb_hole',
        '구멍 지름 (mm)',
        _hole,
        '볼트가 지나는 구멍 지름입니다. 7/16"(11.1)는 NEMA 접지바 3/8" 볼트용입니다. 구멍마다 따로 바꾸려면 아래 "구멍 크기 바꾸기"를 씁니다.',
        onEdit: _saveSoon,
      ),
      _presetChips(
        'gb_hd_',
        _hole,
        kGroundHoleDias,
        (v) => v == 7.9 ? 'φ7.9 (5/16")' : 'φ11.1 (7/16")',
      ),
      const SizedBox(height: 8),
      elecField(
        'gb_pitch',
        '구멍 피치 (mm)',
        _pitch,
        '구멍 중심 사이 거리입니다. 쓸 러그의 구멍 간격에 맞춥니다.',
        onEdit: _saveSoon,
      ),
      _presetChips(
        'gb_pp_',
        _pitch,
        kGroundPitches,
        (v) => switch (v) {
          15.875 => '5/8" (15.9)',
          19.05 => '3/4" (19)',
          25.4 => '1" (25.4)',
          _ => '1-3/4" (44.5)',
        },
      ),
      const SizedBox(height: 8),
      elecField(
        'gb_end',
        '끝 여유 (mm)',
        _end,
        '곧은 구간 끝에서 첫 구멍 중심까지입니다. 규격 값을 못 찾아 임의 기본값입니다.',
        onEdit: _saveSoon,
      ),
      if (_byLength)
        elecField(
          'gb_len',
          '막대 길이 (mm)',
          _length,
          '가진 구리 막대의 자른 길이입니다.',
          onEdit: _saveSoon,
        )
      else
        elecField(
          'gb_n',
          '구멍 수 (한 줄, 개)',
          _count,
          '한 줄에 뚫을 구멍 개수입니다. 두 줄이면 줄마다 이 개수입니다.',
          onEdit: _saveSoon,
        ),
      elecSectionTitle('끝 꺾기'),
      elecChipGroup(
        '끝 모양',
        'L 탭: 막대 끝을 L자로 꺾어 세웁니다. 모자: 몸체(구멍 줄) 양쪽 다리를 90°로 내리고 다리 끝을 바깥으로 다시 꺾어 바닥에 대는 챙을 만듭니다(꺾기 4곳, 챙에 취부 구멍). 모두 두께 방향(눕혀 꺾기) 90°이고 치수는 바깥 치수입니다. 끝 여유는 꺾기 끝선에서 첫 구멍까지로 잽니다.',
        [
          for (final (i, label) in const [
            (0, '없음'),
            (1, '왼쪽 L'),
            (2, '오른쪽 L'),
            (3, '양쪽 L'),
            (4, '모자 (챙 달림)'),
          ])
            calcChip(
              'gb_tab_$i',
              label,
              _tabs == i,
              () => _set(() => _tabs = i),
            ),
        ],
      ),
      if (_tabs & 1 != 0)
        elecField(
          'gb_tabl',
          '왼쪽 탭 길이 (mm)',
          _tabL,
          '왼쪽 끝에서 꺾인 바깥 모서리까지 길이(바깥 치수)입니다.',
          onEdit: _saveSoon,
        ),
      if (_tabs & 2 != 0)
        elecField(
          'gb_tabr',
          '오른쪽 탭 길이 (mm)',
          _tabR,
          '오른쪽 끝에서 꺾인 바깥 모서리까지 길이(바깥 치수)입니다.',
          onEdit: _saveSoon,
        ),
      if (_tabs == 4)
        elecField(
          'gb_hath',
          '모자 높이 (mm)',
          _hatH,
          '챙 바닥면(취부면)에서 몸체 윗면까지 높이입니다(바깥 치수).',
          onEdit: _saveSoon,
        ),
      if (_tabs == 4)
        elecField(
          'gb_hatf',
          '왼쪽 챙 길이 (mm)',
          _hatF,
          '왼쪽 다리 바깥면에서 챙 끝까지 길이입니다.',
          onEdit: _saveSoon,
        ),
      if (_tabs == 4)
        elecField(
          'gb_hatfr',
          '오른쪽 챙 길이 (mm, 비우면 왼쪽과 같음)',
          _hatFR,
          '오른쪽 다리 바깥면에서 챙 끝까지 길이입니다. 비우면 왼쪽 챙과 같습니다.',
          onEdit: _saveSoon,
        ),
      if (_tabs != 0)
        elecChipGroup(
          _tabs == 4 ? '챙 구멍 수 (취부용, 줄마다)' : '탭 구멍 수 (줄마다)',
          '탭·챙의 평평한 길이 가운데에 모아 뚫습니다. 줄 수는 위 "구멍 줄"을 따릅니다. 0이면 뚫지 않습니다.',
          [
            for (final n in const [0, 1, 2, 3])
              calcChip(
                'gb_mc_$n',
                n == 0 ? '없음' : '$n개',
                _mCount == n,
                () => _set(() => _mCount = n),
              ),
          ],
        ),
      if (_tabs != 0 && _mCount > 0)
        elecField(
          'gb_mdia',
          '$_tabName 구멍 지름 (mm)',
          _mDia,
          '취부·접지 러그 볼트가 지나는 구멍 지름입니다.',
          onEdit: _saveSoon,
        ),
      if (_tabs != 0 && _mCount > 1)
        elecField(
          'gb_mpitch',
          '$_tabName 구멍 피치 (mm)',
          _mPitch,
          '탭·챙 구멍 중심 사이 거리입니다.',
          onEdit: _saveSoon,
        ),
      if (_tabs != 0 && _mCount > 0)
        elecChipGroup(
          '$_tabName 구멍 줄 (접지 구멍과 따로)',
          '$_tabName 구멍을 몇 줄로 뚫을지 정합니다. 한 줄이면 각 $_tabName에 위 "구멍 수"만큼입니다. 두 줄이면 그 두 배입니다(대칭은 마주 보고, 비대칭은 엇갈림).',
          [
            for (final (i, label) in const [
              (0, '한 줄'),
              (1, '두 줄 · 대칭'),
              (2, '두 줄 · 비대칭'),
            ])
              calcChip(
                'gb_trm_$i',
                label,
                _tabRowMode == i,
                () => _set(() => _tabRowMode = i),
              ),
          ],
        ),
      if (_tabs != 0 && _mCount > 0 && _tabRowMode != 0)
        elecField(
          'gb_tabgap',
          '$_tabName 구멍 줄 간격 (mm)',
          _tabGap,
          '$_tabName 두 줄 구멍 중심 사이 거리입니다. 폭 가운데에서 위아래로 반씩입니다.',
          onEdit: _saveSoon,
        ),
      if ((_tabs == 3 || _tabs == 4) && _mCount > 0)
        elecChipGroup(
          '$_tabName 구멍을 뚫을 곳',
          '양쪽: 왼쪽·오른쪽 $_tabName 모두. 한쪽만 뚫으려면 그쪽을 고릅니다.',
          [
            for (final (i, label) in const [(3, '양쪽'), (1, '왼쪽만'), (2, '오른쪽만')])
              calcChip(
                'gb_tsd_$i',
                label,
                _tabSides == i,
                () => _set(() => _tabSides = i),
              ),
          ],
        ),
      if (_tabs != 0)
        elecField(
          'gb_r',
          '꺾기 안쪽 반경 (mm, 비우면 ${fmt(_num(_thick))})',
          _radius,
          '꺾는 곳 안쪽 반경입니다. 비우면 두께 1배로 계산합니다.',
          onEdit: _saveSoon,
        ),
      if (_tabs != 0)
        elecChipGroup(
          '중립선 계수 k',
          '꺾을 때 길이가 변하지 않는 선 위치입니다. 구리 부스바 범위 0.33~0.5. 시험 조각으로 맞춥니다.',
          [
            for (final k in kBusbarK)
              calcChip(
                'gb_kf_${(k * 100).round()}',
                fmt(k, 2),
                _k == k,
                () => _set(() => _k = k),
              ),
          ],
        ),
      const SizedBox(height: 8),
    ];
    if (p == null) {
      children.add(
        calcResult(
          key: const Key('gb_result'),
          big: '— mm',
          caption: '치수를 넣으면 계산합니다',
          lines: const [],
        ),
      );
    } else {
      final total = p.groundHoles.length;
      summary =
          '접지바 ${fmt(_num(_thick))}×${fmt(_num(_width))} · ${fmt(p.length, 1)}mm · 구멍 $total개';
      children.addAll([
        calcResult(
          key: const Key('gb_result'),
          big: '${fmt(p.length, 1)} mm',
          caption: '자르는 길이 · 구멍 $total개 · 약 ${fmt(p.weightKg, 2)}kg',
          warn: warn || _radiusWarn != null,
          lines: [
            ...p.problems,
            ...p.notes,
            ?_radiusWarn,
            if (p.holes > 0) _rowText(p),
            if (_byLength &&
                p.holes > 0 &&
                !(_packGround && p.lugHoleList.isNotEmpty))
              '남는 길이는 양 끝 여유에 똑같이 나눴습니다(양 끝 ${fmt(p.endLeft, 1)} / ${fmt(p.endRight, 1)}mm).'
            else if (p.holes > 0 && _packGround && p.lugHoleList.isNotEmpty)
              '접지 구멍 ${p.holes}개를 왼쪽 끝에서부터 놓고, 오른쪽 남는 자리에 러그 구멍을 가운데로 두었습니다.',
            if (p.hat)
              '모자: 높이 ${fmt(_num(_hatH))} · 챙 ${fmt(_num(_hatF))} / ${fmt(readNum(_hatFR) ?? _num(_hatF))} · 몸체 바깥 폭 ${fmt(p.hatWidth, 1)}mm. 꺾기 4곳, 접지 구멍 줄은 몸체 곧은 구간 ${fmt(p.flatStart, 1)}~${fmt(p.flatEnd, 1)}mm에 있습니다.'
            else if (p.bends.isNotEmpty)
              'L 꺾기 ${p.bends.length}곳. 구멍 줄은 곧은 구간 ${fmt(p.flatStart, 1)}~${fmt(p.flatEnd, 1)}mm에 있습니다.',
            if (p.tabHoleList.isNotEmpty) _tabHoleSummary(p),
            if (p.minEdgeBody != null || p.minEdgeTab != null) _edgeLine(p),
            if (p.lugHoleList.isNotEmpty)
              '접지 러그 구멍 ${p.lugHoleList.length}개를 접지 구멍과 따로 부스바 가운데(폭 ${fmt(p.lugHoleList.first.y, 1)}mm)에 추가했습니다.',
          ],
        ),
        if (p.bendPlan != null) ...[
          const SizedBox(height: 12),
          calcLabel('꺾은 뒤 모양', '옆에서 본 실제 비율입니다. 번호는 아래 꺾기 번호와 같습니다.'),
          const SizedBox(height: 4),
          _drawing(
            const Key('gb_shape_view'),
            170,
            BusbarShapePainter(
              plan: p.bendPlan!,
              rho: _r + _k * _num(_thick),
              thickness: _num(_thick),
              startHeadingDeg: p.startHeading,
              text: fc.text,
              sub: fc.textSub,
              line: fc.line,
            ),
          ),
        ],
        const SizedBox(height: 12),
        calcLabel(
          '위에서 본 모양',
          '실제 비율입니다. 아래 숫자는 끝 여유와 구멍 피치(mm)입니다. 주황 테두리는 크기를 바꾼 구멍입니다.',
        ),
        const SizedBox(height: 4),
        _drawing(
          const Key('gb_view'),
          p.rows == 2 ? 170 : 150,
          GroundBarPainter(
            plan: p,
            width: _num(_width),
            holeDia: _num(_hole),
            text: fc.text,
            sub: fc.textSub,
            bg: fc.background,
            lugNumbers: {
              for (final e in _lugGroups(p).entries)
                for (final h in e.value) h.id: e.key,
            },
          ),
        ),
        const SizedBox(height: 12),
        if (p.bends.isNotEmpty) ...[
          elecSectionTitle('꺾기 (왼쪽 끝에서)'),
          for (var i = 0; i < p.bends.length; i++) _bendTile(p.bends[i], i, p),
          const SizedBox(height: 4),
        ],
        if (p.holes > 0) ...[
          elecSectionTitle('접지 구멍 위치 (왼쪽 끝에서 중심까지)'),
          _holeBox(p),
        ],
        if (p.tabHoleList.isNotEmpty) ...[
          elecSectionTitle('$_tabName 구멍 위치 (왼쪽 끝에서 중심까지)'),
          _tabHoleBox(p),
        ],
        ..._lugSection(p),
        ..._mountSection(p),
        ..._sizeEditor(p),
        const SizedBox(height: 8),
        calcResult(
          key: const Key('gb_notes'),
          big: '작업 순서',
          caption: '현장에서 만들 때',
          lines: [
            '구리 막대를 자르는 길이로 자릅니다. 절단면 버를 갈아 냅니다.',
            '폭 방향 줄 위치를 긋고, 왼쪽 끝에서 구멍 위치를 재어 센터 펀치를 칩니다.',
            '작은 드릴로 먼저 뚫은 뒤 구멍 지름으로 넓힙니다. 크기를 바꾼 구멍은 그 지름으로 뚫습니다. 구리는 절삭유를 씁니다.',
            '구멍 둘레 버를 정리합니다.',
            if (_tabs != 0 && _mCount > 0) '$_tabName 구멍도 같은 방법으로 뚫습니다.',
            if (_tabs == 4)
              '구멍을 다 뚫은 뒤 꺾기 시작선 4곳을 차례로 꺾습니다. 가운데에서 바깥으로: 다리 두 곳을 먼저 내리고 챙을 바깥으로 꺾으면 벤더에 걸리지 않습니다.'
            else if (_tabs != 0)
              '구멍을 다 뚫은 뒤 꺾기 시작선에 맞춰 탭을 90°로 꺾습니다(구멍 뚫기를 먼저 해야 평평한 채로 작업합니다).',
            '접촉면을 닦아 접지 러그를 붙입니다.',
          ],
        ),
      ]);
    }
    children.addAll([
      const SizedBox(height: 12),
      elecBasis('gb_basis', kGroundBarBasis),
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
              '접지바 구멍 계산기',
              style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
            ),
            actions: [
              if (p != null)
                IconButton(
                  key: const Key('gb_share'),
                  tooltip: '카톡으로 보내기',
                  icon: Icon(Icons.share_outlined, color: fc.text),
                  onPressed: () => widget.share(_shareText(p)),
                ),
              if (p != null)
                IconButton(
                  key: const Key('gb_pdf'),
                  tooltip: '가공 지시서 PDF',
                  icon: Icon(Icons.picture_as_pdf_outlined, color: fc.text),
                  onPressed: () => openGroundBarPdf(context, _pdfInput(p)),
                ),
              IconButton(
                key: const Key('gb_saved'),
                tooltip: '저장한 규격',
                icon: Icon(Icons.bookmarks_outlined, color: fc.text),
                onPressed: _openSavedSheet,
              ),
              calcHistoryButton(),
            ],
          ),
          body: elecPage(
            children,
            sumKey: 'gb_sum',
            summary: summary,
            warn: warn,
          ),
        ),
      ),
    );
  }
}
