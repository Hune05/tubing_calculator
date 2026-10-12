// 접지바 가공(10-03): 구리 평강에 구멍을 뚫고 일자로 쓰거나 모자(윗면·다리·발)로 꺾어
// 접지바를 만들 때 절단 길이와 구멍·꺾기 위치. 계산은 busbar_ground.dart.
// 10-10: 현장 절곡·펀칭기로 바로 만드는 것에 맞춤. 겉에는 일자·모자와 꼭 넣을 칸만 두고,
// 두 줄 구멍·끝 L자·러그·구멍 크기 바꾸기·꺾기 보정은 "자세히"에 접어 둔다(켜 둔 값은 그대로 계산에 들어간다).
// 10-12: 부스바 가공처럼 위 그림(구멍 ↔ 꺾은 모양) + 아래 탭(모양·구멍·결과·보내기). "자세히"는 모양·구멍 탭에 나눠 둔다.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/theme/app_icon_set.dart';
import '../../core/theme/field_view.dart';
import '../calculator/widgets/swipe_delete.dart' show calcNavCompact;
import '../common/app_icons.dart';
import '../common/calc_form_parts.dart';
import '../common/preset_menu.dart';
import '../steel_plate/plate_ui.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'busbar_bend.dart' show BusbarBend;
import 'busbar_bend_page.dart'
    show busbarMinRadius, kBusbarK, kBusbarThicks, kBusbarWidths;
import 'busbar_bend_painter.dart' show BusbarShapePainter, busbarBendColor;
import 'busbar_bender_profile.dart';
import 'busbar_ground.dart';
import 'busbar_ground_painter.dart';
import 'busbar_ground_pdf.dart';
import 'busbar_lug.dart';
import 'busbar_punch_dies.dart';
import 'busbar_saved_specs.dart';
import 'elec_form_parts.dart';

Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

const List<String> kGroundBarBasis = [
  '모양: 일자는 절곡하지 않고 그대로 판넬에 댑니다. 모자는 윗면(접지 홀 줄) 양쪽을 다리로 90° 내리고 다리 끝을 바깥으로 다시 절곡해 발을 만듭니다(절곡 4곳). 발 홀로 판넬에 바로 취부합니다. 끝만 ㄱ자로 절곡하는 모양은 "자세히"에 있습니다.',
  '모자 치수는 모두 바깥 치수입니다. 발 길이는 다리 바깥면에서 발 끝까지, 높이는 발 바닥면에서 윗면까지입니다. 전개 길이 = 왼쪽 발 + 오른쪽 발 + 2 × 높이 + 윗면 바깥 폭 − 4 × 공제값입니다.',
  '홀 줄: 한 줄은 폭 가운데입니다. 홀 수로 정하면 길이 = 2 × 끝 여유 + (홀 수 − 1) × 피치. 부스바 길이로 정하면 들어가는 만큼 뚫고 남는 길이는 양 끝에 똑같이 나눕니다.',
  '홀 지름 칩은 볼트 틈새 홀(KS B ISO 273 보통급) M8 9 · M10 11 · M12 13.5 · M16 17.5mm입니다. "내 금형"에 기계 펀치 금형 지름을 저장하면 그 값이 칩으로 나옵니다.',
  '홀 피치 칩(20~50mm)과 끝 여유 기본 25mm는 고르기 쉽게 둔 값이고 규격 값이 아닙니다. 쓸 러그 홀 간격과 설계도에 맞추십시오. 홀이 끝 면을 뚫거나 서로 겹치는 경우만 알립니다.',
  '절곡: 두께 방향(평절곡) 90°, 부스바 가공과 같은 식(중립선 반경 = 내R + K값 × 두께)입니다. 내R은 기계 금형 반경을 넣고, 비우면 두께 1배로 계산합니다. 최소 내R은 CDA 한 곳 자료(두께 10mm 이하 1배)입니다. K값 기본 0.4는 범위(0.33~0.5)의 가운데 값이라 처음 만드는 치수는 잔재로 한 번 시험 절곡해 보고 맞추십시오.',
  '홀 가장자리 ~ 절곡 시작선 거리는 2 × 두께 + 내R 이상이어야 절곡할 때 홀이 덜 늘어납니다(일반 판금 규칙). 기본 발 길이 60mm는 두께 6mm·홀 11mm 하나일 때 이 거리를 넘깁니다.',
  '발·탭 홀(취부)은 직선부(끝에서 절곡 시작선까지) 가운데에 모아 뚫습니다. 일자는 양 끝에 취부 홀을 따로 뚫습니다: 끝에서 첫 취부 홀까지(기본 25mm), 마지막 취부 홀에서 첫 접지 홀까지(기본 50mm). 그 쪽은 끝 여유 대신 이 거리를 쓰고, 그만큼 전개 길이가 늘어납니다. 두 기본값은 임의 값입니다.',
  '중량은 구리 밀도 8.9 g/cm³로 홀을 뺀 부피에 곱한 근사값입니다.',
  '자세히: 두 줄 홀, 끝 ㄱ자 절곡, 오른쪽 발 길이 따로, 취부 홀 줄·뚫을 쪽, 러그 홀 간격·놓는 방법·패드 두께, 홀 크기 개별 수정, K값·벤더 보정이 있습니다. 접어 둬도 켜 둔 값은 계산에 들어가고 "자세히" 제목 아래에 보입니다.',
  '두 줄: 대칭은 두 줄 홀이 같은 자리에 마주 보고, 비대칭(엇갈림)은 B줄을 길이 방향으로 옮깁니다(비우면 반 피치). 엇갈린 만큼 홀 줄이 길어집니다. 두 줄 줄 간격 기본 20mm는 임의 값입니다.',
  '접지 러그 홀: 접지 홀을 쓰지 않고 부스바 가운데에 따로 뚫습니다. 1홀 러그는 홀 하나, 2홀 러그는 러그 홀 간격만큼 떨어진 홀 둘입니다(NEMA 2홀 러그 간격 3/4"·1"·1-3/4"). 볼트 세트 = 볼트 + 너트 + 평와셔 2 + 스프링 와셔 1(홀 하나). 조임 토크와 산화방지제는 러그·볼트 제조사 값을 따르며 이 앱은 값을 정하지 않습니다.',
  '홀 사이 최소 간격: 홀 피치·줄 간격은 12mm보다 작게 넣어도 12mm로 올려 계산하고 알립니다(홀 중심 사이 기준).',
  '판넬 취부: 모자 접지바를 발 홀로 판넬에 설치할 때 판넬 홀 가로 간격(왼쪽 홀 0 기준)과 볼트 세트를 계산합니다. 판넬 두께 기본 3mm는 임의 값입니다.',
  '스프링백: 벤더 프로필을 고르면 스프링백 비율로 기계에서 절곡할 각도를 알려 줍니다. 프로필이 없으면 보정하지 않습니다.',
  '넣지 않은 것: 3줄 이상, 모서리 둥글림, 홀 면취.',
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
  /// 최근 계산 기록을 폰에 이틀 동안 남기는 칸.
  @override
  String? get calcHistoryStorageKey => 'calc_history_ground_bar';

  bool _byLength = false; // false = 구멍 수로, true = 막대 길이로
  int _tabs = 0; // 모양: 0 일자, 4 모자(윗면·다리·발). "자세히"의 끝 L자: 1 왼쪽, 2 오른쪽, 3 양쪽
  int _mCount = 1; // 취부 구멍 수(일자는 끝 하나에, 모자는 발 하나에, L은 탭 하나에, 줄마다)
  int _rowMode = 0; // 0 한 줄, 1 두 줄 대칭, 2 두 줄 비대칭(엇갈림)
  int _tabRowMode = 0; // 발·탭 구멍 줄(접지 구멍과 따로)
  int _tabSides = 3; // 발·탭 구멍을 뚫을 쪽: 1 왼쪽, 2 오른쪽, 3 양쪽(모자·양쪽 L일 때만 씀)
  List<double> _dies = const []; // 내 펀치 금형 지름(비면 기본 칩)
  int _lug = 0; // 접지 러그: 0 없음, 1 1구멍, 2 2구멍
  bool _packGround = true; // 접지 구멍을 왼쪽(뒤)으로 몰고 러그 구멍은 그 뒤 가운데에
  double _k = 0.4;
  double _spring = 1.0; // 스프링백 비율(기계 세팅 ÷ 목표), 1이면 보정 없음
  String? _profileName; // 적용 중인 벤더 프로필 이름
  final Map<String, double> _overrides = {}; // 구멍 번호 → 지름
  String? _selHole;
  final _thick = TextEditingController(text: '6');
  final _width = TextEditingController(text: '50');
  final _hole = TextEditingController(text: '11');
  final _pitch = TextEditingController(text: '25');
  final _end = TextEditingController(text: '25');
  final _count = TextEditingController(text: '10');
  final _length = TextEditingController(text: '500');
  // 10-10: 탭·발 기본 60. 50·40이면 기본 취부 구멍 하나가 꺾기 시작선에 너무 가까웠다(2T + R 미달).
  final _tabL = TextEditingController(text: '60');
  final _tabR = TextEditingController(text: '60');
  final _radius = TextEditingController(); // 비우면 두께 1배
  final _hatH = TextEditingController(text: '40');
  final _hatF = TextEditingController(text: '60');
  final _hatFR = TextEditingController(); // 비우면 왼쪽 발과 같음
  final _mDia = TextEditingController(text: '11');
  final _mPitch = TextEditingController(text: '25');
  final _gap = TextEditingController(text: '20');
  final _shift = TextEditingController(); // 비우면 반 피치
  final _ovDia = TextEditingController();
  final _tabGap = TextEditingController(text: '20');
  final _lugSpacing = TextEditingController(text: '25.4');
  final _panelT = TextEditingController(text: '3'); // 취부면(판넬) 두께
  final _lugDia = TextEditingController(text: '11'); // 러그 구멍 지름
  final _jobName = TextEditingController(); // 작업 이름(지시서·저장 이름)
  final _lugPad = TextEditingController(text: '5');
  // 일자 취부 구멍(10-10): 끝에서 첫 취부 구멍까지, 마지막 취부 구멍에서 첫 접지 구멍까지
  final _mountEnd = TextEditingController(text: '25');
  final _mountGap = TextEditingController(text: '50');

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
    _mountEnd,
    _mountGap,
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
    'me',
    'mg',
  ];

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _loadDies();
  }

  Future<void> _loadDies() async {
    final d = await readPunchDies();
    if (mounted && d.isNotEmpty) setState(() => _dies = d);
  }

  /// 구멍 지름 칩: 저장한 내 금형, 없으면 기본(볼트 틈새 구멍).
  List<double> get _dieChips => _dies.isEmpty ? kDefaultPunchDies : _dies;

  Future<void> _editDies() async {
    final r = await openPunchDies(context, _dies);
    if (r != null && mounted) setState(() => _dies = r);
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
    'sp': _spring,
    'pn': _profileName,
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
  // "최근 계산 기록"을 눌러 되돌릴 때 저장 칸과 같은 모양을 쓴다.
  @override
  Map<String, Object?>? historySnapshot() =>
      jsonDecode(_draft()) as Map<String, dynamic>;

  @override
  void applyHistorySnapshot(Map<String, dynamic> m) => _applyMap(m);

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
          if (kk is num && kk >= kBenderKMin && kk <= kBenderKMax) {
            _k = kk.toDouble();
          }
          final sp = m['sp'], pn = m['pn'];
          _spring = sp is num && sp >= 0.8 && sp <= 1.5 ? sp.toDouble() : 1.0;
          _profileName = pn is String ? pn : null;
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
  void _applyProfile(BenderProfile p) => _set(() {
    _radius.text = fmt(p.radius, 2);
    _k = p.k;
    _spring = p.spring;
    _profileName = p.name;
  });

  Future<void> _openProfiles() => openBenderProfiles(
    context,
    thickness: _num(_thick),
    radius: _r,
    onApply: _applyProfile,
    surface: fc.surface,
    text: fc.text,
    textSub: fc.textSub,
  );

  /// 기계에서 꺾을 각도 안내(스프링백 비율이 1이 아닐 때). 같은 각도는 한 줄로 묶는다.
  List<String> _springLines(Iterable<double> turns) {
    if (_spring == 1.0) return const [];
    final seen = <double>{};
    return [
      for (final tdeg in turns)
        if (seen.add(tdeg.abs()))
          '스프링백 보정(×${fmt(_spring, 3)}): 목표 ${fmt(tdeg.abs())}° → 기계에서 ${fmt(benderMachineAngle(tdeg.abs(), _spring), 1)}°로 절곡',
    ];
  }

  String _savedSummary(Map<String, dynamic> data) {
    final t = data['t'] is String ? data['t'] as String : '';
    final w = data['w'] is String ? data['w'] as String : '';
    final shape = switch (data['tb']) {
      1 => '왼쪽 ㄱ자',
      2 => '오른쪽 ㄱ자',
      3 => '양쪽 ㄱ자',
      4 => '모자',
      _ => '일자',
    };
    final lug = switch (data['lg']) {
      1 => ' · 러그 1홀',
      2 => ' · 러그 2홀',
      _ => '',
    };
    return '${t}T×$w · $shape$lug';
  }

  Future<void> _openSavedSheet() => openSavedSpecs(
    context,
    storageKey: 'busbar_ground_saved_v1',
    current: () => jsonDecode(_draft()) as Map<String, dynamic>,
    summaryOf: _savedSummary,
    defaultName: _jobName.text.trim().isNotEmpty
        ? _jobName.text.trim()
        : '${_thick.text}T×${_width.text} 접지바',
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
      tabHoleCount: _mCount,
      tabHoleDia: _num(_mDia),
      tabHolePitch: _num(_mPitch),
      tabRows: _tabRowMode == 0 ? 1 : 2,
      tabRowGap: _num(_tabGap),
      tabStaggered: _tabRowMode == 2,
      // 10-10: 뚫을 쪽 칩은 모자·양쪽 L일 때만 보인다. 다른 모양에서 숨은 값(왼쪽만 등)이 들어가
      // 오른쪽 L 탭 구멍이 말없이 0개가 됐다.
      tabSides: _tabs == 1 || _tabs == 2 ? 3 : _tabSides,
      mountEnd: _num(_mountEnd),
      mountGap: _num(_mountGap),
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
    return '내R ${fmt(_r)}mm가 최소 내R ${fmt(min)}mm(CDA, 두께 ${fmt(_num(_thick))}mm 기준)보다 작습니다. 모서리가 갈라질 수 있습니다.';
  }

  String get _tabName => _tabs == 4 ? '발' : (_tabs == 0 ? '취부' : '탭');

  /// 취부 구멍이 놓이는 한 곳: 모자는 발, 일자는 끝, L자는 탭("왼쪽 끝 1개", "발 하나에").
  String get _sideUnit => _tabs == 4 ? '발' : (_tabs == 0 ? '끝' : '탭');

  /// 구멍 위치 한 줄 규칙: 첫 구멍·피치·마지막 구멍(A줄).
  String _ruleText(GroundBarPlan p) =>
      '첫 홀 ${fmt(p.positions.first, 1)} → 피치 ${fmt(p.pitchUsed)} × ${p.holes - 1}칸 → 마지막 홀 ${fmt(p.positions.last, 1)}';

  /// 두 줄 설명: 막대 한쪽 가장자리에서 줄 위치와 B줄 엇갈림.
  String _rowText(GroundBarPlan p) {
    if (p.rows == 1) return '홀 줄은 폭 가운데 ${fmt(p.rowY.first, 1)}mm입니다.';
    return '${_rowMode == 1 ? "두 줄 대칭" : "두 줄 비대칭(엇갈림)"}: 부스바 한쪽 가장자리에서 A줄 ${fmt(p.rowY[0], 1)} · B줄 ${fmt(p.rowY[1], 1)}mm'
        '${p.stagger > 0 ? ", B줄은 길이 방향으로 ${fmt(p.stagger, 1)}mm 옮김" : ""}.';
  }

  String _bendName(int i, GroundBarPlan p) {
    if (p.hat) {
      return const ['왼쪽 발 → 다리', '왼쪽 다리 → 윗면', '윗면 → 오른쪽 다리', '오른쪽 다리 → 발'][i];
    }
    final side = p.bends.length == 2
        ? (i == 0 ? '왼쪽' : '오른쪽')
        : (_tabs == 1 ? '왼쪽' : '오른쪽');
    return '$side 탭';
  }

  String _bendText(BusbarBend b, int i, GroundBarPlan p) =>
      '${i + 1}. ${_bendName(i, p)} 절곡 시작선 ${fmt(b.start, 1)} · 끝선 ${fmt(b.end, 1)}mm';

  /// 구멍 가장자리 ~ 꺾기 시작선 거리(구멍 종류별). 꺾을 때 구멍이 늘어나는지 가늠하는 값.
  // 10-09: 모자랄 때 "✗"는 PDF 글꼴에 없어 네모로 나와 "부족"으로 쓴다.
  String _edgeLine(GroundBarPlan p) {
    String one(String name, double d, double req) =>
        '$name ${fmt(d, 1)}mm (필요 ${fmt(req, 1)}mm 이상 ${d >= req - 1e-9 ? "✓" : "부족"})';
    final parts = [
      if (p.minEdgeBody != null) one('접지·러그 홀', p.minEdgeBody!, p.reqEdgeBody),
      if (p.minEdgeTab != null) one('$_tabName 홀', p.minEdgeTab!, p.reqEdgeTab),
    ];
    return '홀 가장자리 ~ 절곡 시작선 거리: ${parts.join(' · ')}. 필요 거리 = 2 × T + R(홀 지름 25.4 이상은 2.5 × T + R, 일반 판금 규칙).';
  }

  /// 발·탭 구멍 수 설명: 어느 쪽에 몇 개인지 풀어 쓴다(쪽은 구멍 번호 tL-·tR-로 가린다).
  String _tabHoleSummary(GroundBarPlan p) {
    final l = p.tabHoleList.where((h) => h.id.startsWith('tL-')).length;
    final r = p.tabHoleList.where((h) => h.id.startsWith('tR-')).length;
    final flat = p.flatTabL > 0 && l > 0 ? p.flatTabL : p.flatTabR;
    final parts = [
      if (l > 0) '왼쪽 $_sideUnit $l개',
      if (r > 0) '오른쪽 $_sideUnit $r개',
    ];
    final where = _tabs == 0
        ? '끝에서 ${fmt(_num(_mountEnd))}mm에 있고, 첫 접지 홀까지 ${fmt(_num(_mountGap))}mm 띄웠습니다.'
        : '직선부 ${fmt(flat, 1)}mm 가운데에 있습니다.';
    return '$_tabName 홀 φ${fmt(_num(_mDia))}: ${parts.join(' + ')}(합계 ${p.tabHoleList.length}개). $where';
  }

  String _holeLine(GroundHole h) =>
      '${h.label} ${fmt(h.x, 1)}${h.custom ? " φ${fmt(h.dia)}" : ""}';

  /// 구멍 위치 표 한 줄: 번호 · 왼쪽 끝에서 · 폭 방향 · 지름(바꾼 구멍은 * 표시).
  List<String> _holeRow(GroundHole h) => [
    h.label,
    fmt(h.x, 1),
    fmt(h.y, 1),
    '${fmt(h.dia)}${h.custom ? " *" : ""}',
  ];

  /// 접지바 가공 지시서(PDF)에 넣을 내용. 글은 화면에 보이는 것과 같은 말을 쓴다.
  GroundPdfInput _pdfInput(GroundBarPlan p) {
    final t = _num(_thick), w = _num(_width);
    final shape = switch (_tabs) {
      1 => '왼쪽 끝 ㄱ자 절곡 (탭 ${fmt(_num(_tabL))}mm)',
      2 => '오른쪽 끝 ㄱ자 절곡 (탭 ${fmt(_num(_tabR))}mm)',
      3 => '양쪽 끝 ㄱ자 절곡 (탭 ${fmt(_num(_tabL))} / ${fmt(_num(_tabR))}mm)',
      4 =>
        '모자: 높이 ${fmt(_num(_hatH))}, 발 ${fmt(_num(_hatF))} / ${fmt(readNum(_hatFR) ?? _num(_hatF))}mm',
      _ => '일자 (절곡하지 않음)',
    };
    final custom = [
      ...p.groundHoles,
      ...p.tabHoleList,
      ...p.lugHoleList,
    ].where((h) => h.custom).toList();
    final summary = <(String, String)>[
      ('재료', '구리 평강 ${fmt(t)}T × ${fmt(w)} mm'),
      ('모양', shape),
      ('전개 길이', '${fmt(p.length, 1)} mm (약 ${fmt(p.weightKg, 2)} kg)'),
      (
        '접지 홀',
        'φ${fmt(_num(_hole))} · ${p.rows == 2 ? "${p.holes}개 × 2줄" : "${p.holes}개"} · 피치 ${fmt(p.pitchUsed)}mm',
      ),
      if (p.holes > 0) ('홀 줄', _rowText(p)),
      if (p.tabHoleList.isNotEmpty)
        ('$_tabName 홀', _tabHoleSummary(p).replaceFirst('$_tabName 홀 ', '')),
      if (p.lugHoleList.isNotEmpty)
        (
          '러그 홀',
          '${_lug == 2 ? "2홀" : "1홀"} 러그 · ${p.lugHoleList.length}개 · φ${fmt(_num(_lugDia))}${_lug == 2 ? " · 홀 간격 ${fmt(_num(_lugSpacing))}mm" : ""} (접지 홀과 따로)',
        ),
      if (p.bends.isNotEmpty)
        ('절곡 조건', '내R ${fmt(_r)}mm · K값 ${fmt(_k, 2)} · 평절곡 90°'),
      if (custom.isNotEmpty)
        ('크기 바꾼 홀', custom.map((h) => '${h.label} φ${fmt(h.dia)}').join(' · ')),
    ];
    final sections = <GroundPdfSection>[
      if (p.holes > 0)
        GroundPdfSection(
          '접지 홀 위치 (왼쪽 끝에서 중심까지, mm)',
          [
            _ruleText(p),
            '검산: 마지막 접지 홀에서 ${_tabs == 4 || _tabs & 2 != 0 ? "절곡 시작선" : "끝"}까지 ${fmt(p.endRight, 1)}mm.',
          ],
          headers: const ['번호', '왼쪽 끝에서(mm)', '폭 방향(mm)', '지름(mm)'],
          rows: [for (final h in p.groundHoles) _holeRow(h)],
        ),
      if (p.tabHoleList.isNotEmpty)
        GroundPdfSection(
          '$_tabName 홀 위치 (왼쪽 끝에서 중심까지, mm)',
          const [],
          headers: const ['번호', '왼쪽 끝에서(mm)', '폭 방향(mm)', '지름(mm)'],
          rows: [for (final h in p.tabHoleList) _holeRow(h)],
        ),
      if (p.lugHoleList.isNotEmpty)
        GroundPdfSection(
          '접지 러그 홀 위치 (접지 홀과 따로, 왼쪽 끝에서 중심까지, mm)',
          [
            '볼트 세트 ${p.lugHoleList.length}개 = ${_lugParts(p.lugHoleList.length).join(" · ")}',
            '체결 두께(그립) ${fmt(_num(_lugPad) + t, 1)}mm = 러그 패드 ${fmt(_num(_lugPad), 1)} + 부스바 ${fmt(t, 1)}.',
          ],
          headers: const ['번호', '왼쪽 끝에서(mm)', '폭 방향(mm)', '지름(mm)'],
          rows: [for (final h in p.lugHoleList) _holeRow(h)],
        ),
      if (_panel(p).isNotEmpty)
        GroundPdfSection('판넬 취부 자리 (가장 왼쪽 홀 = 0, mm)', [
          for (final h in _panel(p))
            '${h.hole.label}   가로 ${fmt(h.x, 1)} · 세로 ${fmt(h.y, 1)} (부스바 A쪽 가장자리 기준)',
          if (_panel(p).length > 1)
            '왼쪽 홀과 오른쪽 홀 가로 간격 ${fmt(_panel(p).last.x - _panel(p).first.x, 1)}mm (홀 중심 사이).',
          '볼트 세트 ${p.tabHoleList.length}개 = 볼트 ${lugBoltFor(_num(_mDia)) ?? "홀에 맞는 규격"} ${p.tabHoleList.length}개 · 너트 · 평와셔 2개 · 스프링 와셔 1개(개당).',
          '체결 두께(그립) ${fmt(t + _num(_panelT), 1)}mm = 부스바 ${fmt(t, 1)} + 판넬 ${fmt(_num(_panelT), 1)}.',
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
        ..._springLines(p.bends.map((b) => b.turn)),
        if (p.minEdgeBody != null || p.minEdgeTab != null) _edgeLine(p),
      ],
    );
  }

  String _shareText(GroundBarPlan p) {
    final b = StringBuffer(
      '[접지바] 구리 ${fmt(_num(_thick))}T×${fmt(_num(_width))}mm · 홀 φ${fmt(_num(_hole))} ${p.rows == 2 ? "${p.holes}개 × 2줄" : "${p.holes}개"} 피치 ${fmt(p.pitchUsed)}',
    );
    b.write('\n전개 길이: ${fmt(p.length, 1)}mm (약 ${fmt(p.weightKg, 2)}kg)');
    b.write('\n${_rowText(p)}');
    if (p.bends.isNotEmpty) {
      final tab = _tabs == 4
          ? '모자 높이 ${fmt(_num(_hatH))} · 발 ${fmt(_num(_hatF))} / ${fmt(readNum(_hatFR) ?? _num(_hatF))}'
          : _tabs == 3
          ? '탭 양쪽 ${fmt(_num(_tabL))} / ${fmt(_num(_tabR))}'
          : '탭 ${fmt(_num(_tabs == 1 ? _tabL : _tabR))}';
      b.write(
        '\n절곡 (왼쪽 끝에서, ${tab}mm 바깥 치수, 내R ${fmt(_r)}, K값 ${fmt(_k, 2)}):',
      );
      for (var i = 0; i < p.bends.length; i++) {
        b.write('\n ${_bendText(p.bends[i], i, p)}');
      }
    }
    if (p.tabHoleList.isNotEmpty) {
      b.write(
        '\n$_tabName 홀 φ${fmt(_num(_mDia))} (왼쪽 끝에서 중심): ${p.tabHoleList.map(_holeLine).join(" · ")}',
      );
    }
    if (p.holes > 0) {
      b.write('\n접지 홀 위치 (왼쪽 끝에서 중심까지): ${_ruleText(p)}');
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
        '\n판넬 취부 홀(왼쪽 홀 0 기준): ${pts.map((h) => "${h.hole.label} 가로 ${fmt(h.x, 1)}/세로 ${fmt(h.y, 1)}").join(" · ")}',
      );
    }
    final groups = _lugGroups(p);
    if (groups.isNotEmpty) {
      b.write(
        '\n접지 러그 ${_lug == 2 ? "2홀" : "1홀"} ${groups.length}개(접지 홀과 따로, 폭 가운데 ${fmt(p.lugHoleList.first.y, 1)}mm 추가 홀 φ${fmt(_num(_lugDia))}):',
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
        '\n크기 바꾼 홀: ${custom.map((h) => "${h.label} φ${fmt(h.dia)}").join(" · ")}',
      );
    }
    for (final l in _springLines(p.bends.map((b) => b.turn))) {
      b.write('\n$l');
    }
    for (final s in p.problems) {
      b.write('\n※ $s');
    }
    return b.toString();
  }

  // ── 화면 부품(10-12: 철판 가공처럼 위 그림 + 아래 탭 — 사용자 "접지바랑 트레이 가공도 똑같이") ──

  Widget _f(
    String key,
    String label,
    TextEditingController c, {
    String? unit = 'mm',
    String? hint,
    Widget? trailing,
  }) => PlateNumField(
    fieldKey: key,
    label: label,
    controller: c,
    unit: unit,
    hint: hint,
    trailing: trailing,
    onChanged: (_) => _set(() {}),
  );

  /// 두 칸 줄. 칸이 하나면 오른쪽 반을 비운다.
  Widget _row(List<Widget> cells) =>
      plateRow([...cells, if (cells.length == 1) const SizedBox.shrink()]);

  Widget _note(String s, {Key? key}) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      s,
      key: key,
      style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.4),
    ),
  );

  /// 결과 탭 안 작은 결과(판넬 취부·러그): 굵은 한 줄 + 설명 + 줄 글.
  Widget _subResult(
    Key key,
    String big,
    String caption,
    List<String> lines, {
    bool warn = false,
  }) => KeyedSubtree(
    key: key,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            big,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: warn ? fc.danger : fc.text,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              caption,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fc.textSub,
              ),
            ),
          ),
          PlateLines(lines),
        ],
      ),
    ),
  );

  Widget _bendTile(BusbarBend b, int i, GroundBarPlan p) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
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
                '절곡 시작선 ${fmt(b.start, 1)} → 절곡 끝선 ${fmt(b.end, 1)} (절곡부 ${fmt(b.end - b.start, 1)}mm). 90°로 절곡합니다.',
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
  );

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

  /// 발·탭 구멍: 왼쪽·오른쪽, 줄마다.
  Widget _tabHoleBox(GroundBarPlan p) {
    final rows = <Widget>[];
    for (final (side, tag) in const [('왼쪽', 'tL-'), ('오른쪽', 'tR-')]) {
      final hs = p.tabHoleList.where((h) => h.id.startsWith(tag)).toList();
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
          final rh = hs.where((h) => h.id.startsWith('$tag$rl')).toList();
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...rows,
          _note(
            '${_tabs == 0 ? "부스바" : "전개도"} 왼쪽 끝 기준 홀 중심 위치입니다. 폭 방향은 ${p.tabRows == 1 ? "가운데" : "A줄 ${fmt(p.tabRowY[0], 1)} · B줄 ${fmt(p.tabRowY[1], 1)}mm"}입니다.',
          ),
        ],
      ),
    );
  }

  /// 접지 구멍: 규칙 한 줄 + 5개씩 묶은 표 + 마지막 구멍 검산.
  Widget _holeBox(GroundBarPlan p) {
    final two = p.rows == 2;
    final rowsA = groundHoleRows(p.positions, prefix: two ? 'A' : '');
    final rowsB = two ? groundHoleRows(p.positionsB, prefix: 'B') : [];
    return Column(
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
        _note(
          two
              ? '${_rowText(p)} 피치가 같아 첫 홀만 측정하고 피치 간격으로 이어 찍으면 됩니다. 아래는 홀별 위치(5개씩 묶음)입니다.'
              : '피치가 같아 첫 홀만 측정하고 피치 간격으로 이어 찍으면 됩니다. 아래는 홀별 위치(5개씩 묶음)입니다.',
        ),
        const SizedBox(height: 6),
        for (final (label, vals) in rowsA)
          _valueRow(label, [
            for (final v in vals) fmt(v, 1),
          ], labelWidth: two ? 76 : 64),
        if (two) const SizedBox(height: 4),
        for (final (label, vals) in rowsB)
          _valueRow(label, [for (final v in vals) fmt(v, 1)], labelWidth: 76),
        _note(
          '검산: 마지막 홀에서 ${_tabs == 4 || _tabs & 2 != 0 ? '절곡 시작선' : '끝'}까지 ${fmt(p.endRight, 1)}mm가 남아야 합니다.',
        ),
      ],
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
      '볼트 ${bolt ?? "홀에 맞는 규격"} $bolts개',
      '너트 $bolts개',
      '평와셔 ${bolts * 2}개',
      '스프링 와셔 $bolts개',
    ];
  }

  /// 러그 겉 입력(10-10 겉으로 꺼냄, 일자·모자 모두 큰 외부 러그를 단다): 러그 종류·구멍 지름.
  List<Widget> _lugMain() => [
    PlateSegments([
      for (final (i, label) in const [(0, '안 붙임'), (1, '1홀 러그'), (2, '2홀 러그')])
        PlateOption('gb_lug_$i', label, _lug == i, () {
          _set(() {
            if (_lug == 0 && i != 0) {
              // 외부 접지 러그는 크다: 처음 켤 때 큰 러그 기본값(M12 구멍, 1-3/4" 간격)
              if (const ['11', '11.1'].contains(_lugDia.text.trim())) {
                _lugDia.text = '13.5';
              }
              if (_lugSpacing.text.trim() == '25.4') {
                _lugSpacing.text = '44.45';
              }
            }
            _lug = i;
          });
        }),
    ]),
    if (_lug != 0) ...[
      _row([
        _f(
          'gb_lugdia',
          '러그 홀 지름',
          _lugDia,
          trailing: _dieMenu('gb_lugd_', _lugDia),
        ),
      ]),
    ],
  ];

  /// 러그 더 넣을 것("자세히" 안): 2구멍 러그 구멍 간격·접지 구멍 놓는 방법·패드 두께.
  List<Widget> _lugMore() {
    if (_lug == 0) return const [];
    return [
      _row([
        if (_lug == 2)
          _f(
            'gb_lugsp',
            '러그 홀 간격',
            _lugSpacing,
            trailing: _presetMenu(
              'gb_lsp_',
              _lugSpacing,
              kLugSpacings,
              (v) => switch (v) {
                19.05 => '3/4" (19.05)',
                25.4 => '1" (25.4)',
                _ => '1-3/4" (44.45)',
              },
              tooltip: '러그 홀 간격',
            ),
          ),
        _f('gb_lugpad', '러그 패드 두께', _lugPad),
      ]),
      PlateSegments([
        PlateOption(
          'gb_pack_on',
          '왼쪽으로 몰기',
          _packGround,
          () => _set(() => _packGround = true),
        ),
        PlateOption(
          'gb_pack_off',
          '가운데 균등',
          !_packGround,
          () => _set(() => _packGround = false),
        ),
      ]),
      _note(
        '왼쪽으로 몰기: 접지 홀을 왼쪽 끝부터 놓고 러그 홀은 남는 자리 가운데에 둡니다. 가운데 균등: 접지 홀을 가운데에 고르게 놓고 러그 홀을 그 가운데에 겹쳐 둡니다(겹치면 알림).',
      ),
    ];
  }

  /// 러그 결과(결과 탭 접는 칸): 구멍 위치·볼트 세트·붙이는 방법. 러그를 안 켜면 빈 목록.
  List<Widget> _lugResults(GroundBarPlan p) {
    final groups = _lugGroups(p);
    if (p.holes == 0 || groups.isEmpty) return const [];
    final bolts = p.lugHoleList.length;
    return [
      _subResult(
        const Key('gb_lug_result'),
        '러그 홀 $bolts개 · 볼트 세트 $bolts',
        '접지 러그 ${groups.length}개 · 폭 가운데 ${fmt(p.lugHoleList.first.y, 1)}mm · 접지 홀과 따로',
        [
          for (final e in groups.entries) _lugLine(e.key, e.value),
          _packGround
              ? '접지 홀은 왼쪽 끝으로 몰았고, 러그 홀은 접지 홀과 따로 남는 자리 가운데에 같은 줄로 추가했습니다(전개도 왼쪽 끝 기준 거리).'
              : '러그 홀은 접지 홀을 쓰지 않고 부스바 가운데에 추가한 홀입니다(전개도 왼쪽 끝 기준 거리).',
          '볼트 세트 $bolts개 = ${_lugParts(bolts).join(' · ')}',
          '체결 두께(그립) ${fmt(_num(_lugPad) + _num(_thick), 1)}mm = 러그 패드 ${fmt(_num(_lugPad), 1)} + 부스바 ${fmt(_num(_thick), 1)}. 볼트 길이는 여기에 평와셔 2장·스프링 와셔·너트 두께와 나사 2~3산을 더한 것 이상으로 고릅니다(와셔·너트 두께는 제품마다 다릅니다).',
        ],
        warn: !p.ok,
      ),
      _subResult(const Key('gb_lug_notes'), '러그 취부 방법', '접지 러그를 접지바에 붙일 때', const [
        '러그 패드와 부스바 접촉면의 도장·산화막을 닦아 냅니다(구리는 광이 날 때까지, 도장 부스바는 접촉 자리만 벗깁니다).',
        '접촉면에 산화방지제(컴파운드)를 얇게 바르고 러그 패드를 부스바에 평평하게 댑니다.',
        '볼트는 평와셔를 끼워 러그 쪽에서 넣고, 반대쪽에서 평와셔 → 스프링 와셔 → 너트 순으로 체결합니다. 너트를 한쪽에 몰면 러그가 틀어지니 2홀 러그는 두 볼트를 번갈아 조입니다.',
        '조임 토크는 러그·볼트 제조사 값이나 사내 기준을 따릅니다(이 앱은 값을 정하지 않습니다). 규정 토크로 조인 뒤 표시선(페인트 마킹)을 긋습니다.',
        '체결 후 러그가 헐겁지 않은지, 케이블 중량이 볼트에 걸리지 않는지 확인합니다.',
      ]),
    ];
  }

  // ── 접지바 취부(발·탭 구멍으로 설치) ──

  List<PanelHole> _panel(GroundBarPlan p) => panelPattern(
    p,
    flangeLeft: _num(_hatF),
    flangeRight: readNum(_hatFR) ?? _num(_hatF),
  );

  /// 결과 한 줄: 모자 양쪽 발·일자 양 끝에 취부 구멍이 있으면 판넬에 마킹할 가로 간격(왼쪽 끝 구멍 ~ 오른쪽 끝 구멍).
  String? _panelSpanLine(GroundBarPlan p) {
    final pts = _panel(p);
    if (pts.length < 2 ||
        !pts.any((h) => h.hole.id.startsWith('tL-')) ||
        !pts.any((h) => h.hole.id.startsWith('tR-'))) {
      return null;
    }
    return '판넬 홀 가로 간격 ${fmt(pts.last.x - pts.first.x, 1)}mm(${_tabs == 0 ? "양 끝 취부 홀" : "양쪽 발 끝 홀"} 중심 사이). 볼트 세트·판넬 두께는 아래 "판넬 취부"에 있습니다.';
  }

  List<Widget> _mountSection(GroundBarPlan p) {
    if (p.tabHoleList.isEmpty) return const [];
    final holes = p.tabHoleList;
    final bolt = lugBoltFor(_num(_mDia));
    final grip = _num(_thick) + _num(_panelT);
    final pts = _panel(p);
    final only = holes.length;
    // 볼트가 지나는 부스바 부분: 모자는 발, L자는 탭, 일자는 부스바 그대로
    final part = p.hat
        ? '발'
        : (p.flatTabL == 0 && p.flatTabR == 0 ? '부스바' : '탭');
    return [
      _row([_f('gb_panelt', '취부면(판넬) 두께', _panelT)]),
      _note('접지바를 올려 볼트로 조일 판넬(또는 앵글) 두께입니다. 기본값 3은 임의 값입니다.'),
      const SizedBox(height: 10),
      _subResult(
        const Key('gb_mount_result'),
        '취부 홀 $only개 · 볼트 세트 $only',
        '접지바를 $_tabName 홀로 판넬에 취부',
        [
          if (pts.isNotEmpty) ...[
            '판넬에 뚫을 홀 자리(가장 왼쪽 홀 = 0, 부스바 A쪽 가장자리 기준 세로):',
            for (final h in pts)
              '   ${h.hole.label}  가로 ${fmt(h.x, 1)} · 세로 ${fmt(h.y, 1)}mm',
            if (pts.length > 1 && pts.first.x != pts.last.x)
              '왼쪽 홀과 오른쪽 홀 가로 간격 ${fmt(pts.last.x - pts.first.x, 1)}mm(홀 중심 사이). 이 간격으로 판넬에 마킹합니다.',
          ] else
            '탭 홀은 접지바를 절곡하기 전 위치입니다. 절곡한 뒤 탭이 닿는 면의 홀 자리는 현장에서 탭을 대고 마킹합니다.',
          '볼트 세트 $only개 = 볼트 ${bolt ?? "홀에 맞는 규격"} $only개 · 너트 $only개 · 평와셔 ${only * 2}개 · 스프링 와셔 $only개 (판넬에 탭이 있으면 너트는 뺍니다)',
          '체결 두께(그립) ${fmt(grip, 1)}mm = ${part == '부스바' ? '부스바' : '$part(부스바)'} ${fmt(_num(_thick), 1)} + 판넬 ${fmt(_num(_panelT), 1)}. 볼트 길이는 여기에 와셔·너트 두께와 나사 2~3산을 더한 것 이상으로 고릅니다.',
          if (_mDia.text.trim().isNotEmpty)
            '판넬 홀은 $_tabName 홀과 같은 φ${fmt(_num(_mDia))}로 뚫거나, 판넬에 탭을 낼 때는 볼트 호칭에 맞는 드릴을 씁니다.',
        ],
      ),
      _subResult(
        const Key('gb_mount_notes'),
        '접지바 취부 방법',
        '${p.hat ? "모자 접지바" : (part == '부스바' ? "일자 접지바" : "탭 접지바")}를 판넬에 설치할 때',
        [
          '판넬 마킹: 위 가로 간격으로 판넬에 홀 자리를 긋고, 접지바를 대어 홀이 맞는지 확인한 뒤 뚫습니다.',
          '접촉면 처리: 접지바 바닥과 판넬 접촉 자리의 도장·산화막을 벗겨 금속면을 드러내고 산화방지제를 얇게 바릅니다(구리와 도금 강판이 닿는 곳은 접촉 부식에 주의).',
          '체결: 볼트에 평와셔를 끼워 ${part == '부스바' ? '부스바와' : '$part과'} 판넬을 지나게 한 뒤 반대쪽에서 평와셔 → 스프링 와셔 → 너트 순으로 조입니다. 양쪽 ${part == '부스바' ? '끝' : part} 볼트를 번갈아 조여 접지바가 비틀리지 않게 합니다.',
          '조임 토크는 볼트·접지바 제조사 값이나 사내 기준을 따릅니다(이 앱은 값을 정하지 않습니다). 조인 뒤 표시선을 긋습니다.',
          '절연 접지바(판넬과 따로 접지해야 하는 것)는 판넬과 닿는 곳에 절연 받침을 끼우고 절연 볼트 세트를 씁니다. 판넬 접지로 쓰는 일반 접지바는 금속 접촉으로 취부합니다.',
          '취부 뒤 접지 러그를 붙이고 러그·접지바·판넬 접촉 저항을 점검합니다.',
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
      calcDropdown<String>(
        'gb_ov_sel',
        '홀 고르기',
        sel.id,
        [for (final h in all) h.id],
        (id) => name(all.firstWhere((h) => h.id == id)),
        (id) => _set(() => _selHole = id),
        '크기를 따로 줄 홀을 고릅니다. 접지 홀은 번호(두 줄이면 A·B줄), $_tabName 홀은 왼쪽·오른쪽 번호입니다.',
      ),
      _row([
        PlateNumField(
          fieldKey: 'gb_ovdia',
          label: '이 홀 지름',
          controller: _ovDia,
          unit: 'mm',
          hint: '기본과 같으면 기본으로',
        ),
      ]),
      plateActions([
        PlateActionButton(
          key: const Key('gb_ov_apply'),
          icon: Icons.check_rounded,
          label: '이 홀에 적용',
          primary: true,
          onTap: () {
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
          },
        ),
        PlateActionButton(
          key: const Key('gb_ov_reset'),
          icon: Icons.undo_rounded,
          label: '이 홀 기본으로',
          onTap: () => _set(() => _overrides.remove(sel.id)),
        ),
        PlateActionButton(
          key: const Key('gb_ov_clear'),
          icon: Icons.restart_alt_rounded,
          label: '전부 기본으로',
          onTap: () => _set(_overrides.clear),
        ),
      ]),
      if (p.customCount > 0)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            '바꾼 홀 ${p.customCount}개: ${[...p.groundHoles, ...p.tabHoleList, ...p.lugHoleList].where((h) => h.custom).map((h) => "${h.label} φ${fmt(h.dia)}").join(" · ")}',
            key: const Key('gb_ov_list'),
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: fc.text,
              height: 1.4,
            ),
          ),
        ),
    ];
  }

  /// 칸 안 ▼ 자주 쓰는 값(10-12, 칸 아래 단추 줄 대신). 항목 키는 예전 단추 키 그대로.
  Widget _presetMenu(
    String keyPrefix,
    TextEditingController c,
    List<double> values,
    String Function(double) label, {
    String tooltip = '자주 쓰는 값',
  }) => PresetMenuButton(
    buttonKey: Key('${keyPrefix}menu'),
    tooltip: tooltip,
    onOpen: (btn) async {
      final v = await showPresetMenu(
        btn,
        current: presetKey(readNum(c) ?? -1),
        items: [
          for (final x in values)
            PresetItem(
              presetKey(x),
              label(x),
              key: Key('$keyPrefix${(x * 100).round()}'),
            ),
        ],
      );
      if (v == null || !mounted) return;
      _set(() => c.text = v);
      _saveSoon();
    },
  );

  /// 구멍 지름 ▼: 내 펀치 금형(없으면 볼트 틈새 구멍) + 맨 아래 금형 넣기·고치기.
  Widget _dieMenu(String keyPrefix, TextEditingController c) =>
      PresetMenuButton(
        buttonKey: Key('${keyPrefix}menu'),
        tooltip: '펀치 금형·볼트 홀',
        onOpen: (btn) async {
          final v = await showPresetMenu(
            btn,
            minWidth: 220,
            current: presetKey(readNum(c) ?? -1),
            items: [
              for (final x in _dieChips)
                PresetItem(
                  presetKey(x),
                  punchDieLabel(x),
                  key: Key('$keyPrefix${(x * 100).round()}'),
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
            await _editDies();
            return;
          }
          _set(() => c.text = v);
          _saveSoon();
        },
      );

  // ── 탭 ──

  static const _panes = [
    ('shape', '모양'),
    ('holes', '홀'),
    ('result', '결과'),
    ('send', '보내기'),
  ];
  int _pane = 0;

  /// 위 그림: top 위에서 본 구멍 자리, shape 꺾은 모양(꺾을 때만).
  String _view = 'top';

  void _pickShape(int i) => _set(() {
    // 일자는 양 끝 취부 구멍, 모자는 발 구멍으로 판넬에 다니 처음 고를 때 1개를 켜 둔다.
    if ((i == 0 || i == 4) && _tabs != i && _mCount == 0) _mCount = 1;
    _tabs = i;
    // 꺾는 모양을 고르면 위 그림을 꺾은 모양으로
    _view = i == 0 ? 'top' : 'shape';
  });

  /// "자세히" 제목 아래 요약: 켜 둔 것이 있으면 무엇인지 보여 준다(접어 둬도 계산에 들어가므로).
  String _shapeMoreSummary() {
    final on = <String>[
      if (_tabs >= 1 && _tabs <= 3)
        const ['', '왼쪽 ㄱ자', '오른쪽 ㄱ자', '양쪽 ㄱ자'][_tabs],
      if (_tabs == 4 && (readNum(_hatFR) ?? 0) > 0) '오른쪽 발 따로',
      if (_tabs != 0 && _profileName != null)
        '벤더 $_profileName'
      else if (_tabs != 0 && _k != 0.4)
        'K값 ${fmt(_k, 2)}',
    ];
    return on.isEmpty ? '끝 ㄱ자 · 오른쪽 발 따로 · 절곡 보정' : '켜 둔 것: ${on.join(' · ')}';
  }

  String _holesMoreSummary(GroundBarPlan? p) {
    final custom = p?.customCount ?? 0;
    final on = <String>[
      if (_rowMode == 1) '두 줄 대칭' else if (_rowMode == 2) '두 줄 엇갈림',
      if (_mCount > 0 && _tabRowMode != 0) '$_tabName 홀 두 줄',
      if ((_tabs == 0 || _tabs == 3 || _tabs == 4) &&
          _mCount > 0 &&
          _tabSides != 3)
        '$_tabName 홀 ${_tabSides == 1 ? "왼쪽만" : "오른쪽만"}',
      if (_lug != 0 && !_packGround) '러그 가운데 균등',
      if (custom > 0) '크기 바꾼 홀 $custom개',
    ];
    return on.isEmpty
        ? '두 줄 홀 · 러그 간격 · 홀 크기 · 내 금형'
        : '켜 둔 것: ${on.join(' · ')}';
  }

  String get _shapeName => switch (_tabs) {
    1 => '왼쪽 ㄱ자',
    2 => '오른쪽 ㄱ자',
    3 => '양쪽 ㄱ자',
    4 => '모자',
    _ => '일자',
  };

  Widget _canvas(GroundBarPlan? p) {
    if (p == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '두께·폭과 홀 칸을 넣으면 그림이 나옵니다.',
            key: const Key('gb_canvas_empty'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: fc.textSub),
          ),
        ),
      );
    }
    final shape = _view == 'shape' && p.bendPlan != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 52, 10, 30),
      child: CustomPaint(
        key: Key(shape ? 'gb_shape_view' : 'gb_view'),
        painter: shape
            ? BusbarShapePainter(
                plan: p.bendPlan!,
                rho: _r + _k * _num(_thick),
                thickness: _num(_thick),
                innerRadius: _r,
                startHeadingDeg: p.startHeading,
                text: fc.text,
                sub: fc.textSub,
                line: fc.line,
              )
            : GroundBarPainter(
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
        child: const SizedBox.expand(),
      ),
    );
  }

  List<Widget> _canvasTools(GroundBarPlan? p) => p?.bendPlan == null
      ? const []
      : [
          PlateViewSwitch([
            PlateOption(
              'gb_vm_top',
              '평면도',
              _view != 'shape',
              () => setState(() => _view = 'top'),
            ),
            PlateOption(
              'gb_vm_shape',
              '측면도',
              _view == 'shape',
              () => setState(() => _view = 'shape'),
            ),
          ]),
        ];

  String? _canvasHint(GroundBarPlan? p) => p == null
      ? null
      : _view == 'shape' && p.bendPlan != null
      ? '측면도 실제 비율 · 번호는 결과 탭 절곡 번호'
      : '평면도 실제 비율 · 아래 숫자는 끝 여유와 홀 피치(mm), 주황 테두리는 크기를 바꾼 홀';

  // ① 모양: 부스바 두께·폭, 일자·모자(끝 L자는 자세히), 모자·탭 치수, 안쪽 반경
  Widget _shapePanel(GroundBarPlan? p) {
    final lShape = _tabs >= 1 && _tabs <= 3;
    return PlatePanel(
      title: '모양',
      status:
          '구리 평강 ${fmt(_num(_thick))}T × ${fmt(_num(_width))} · $_shapeName',
      actions: [
        plateHelpButton(context, 'gb_help_shape', '모양 탭', [
          '일자: 절곡하지 않고 판넬에 바로 댑니다. 모자: 윗면(접지 홀 줄) 양쪽을 다리로 내리고 다리 끝을 바깥으로 절곡해 발을 만듭니다(절곡 4곳). 발 홀로 판넬에 취부합니다.',
          '모자 높이는 발 바닥면(판넬에 닿는 면)에서 윗면까지, 발 길이는 다리 바깥면에서 발 끝까지입니다(바깥 치수).',
          '끝만 ㄱ자로 절곡하는 모양, 오른쪽 발 길이 따로, K값·벤더 프로필은 아래 "자세히"에 있습니다. 접어 둬도 켜 둔 값은 계산에 들어갑니다.',
          '내R은 기계 금형 반경을 넣고, 비우면 두께 1배로 계산합니다.',
        ]),
      ],
      children: [
        PlateSection('부스바 (구리 평강)', [
          plateRow([
            _f(
              'gb_t',
              '두께',
              _thick,
              trailing: _presetMenu(
                'gb_tv_',
                _thick,
                kBusbarThicks,
                fmt,
                tooltip: '자주 쓰는 두께',
              ),
            ),
            _f(
              'gb_w',
              '폭',
              _width,
              trailing: _presetMenu(
                'gb_wv_',
                _width,
                kBusbarWidths,
                fmt,
                tooltip: '자주 쓰는 폭',
              ),
            ),
          ]),
        ], first: true),
        PlateSection('모양', [
          PlateSegments([
            PlateOption('gb_tab_0', '일자', _tabs == 0, () => _pickShape(0)),
            PlateOption('gb_tab_4', '모자', _tabs == 4, () => _pickShape(4)),
            if (lShape) PlateOption('gb_tab_lnow', _shapeName, true, () {}),
          ]),
          if (_tabs == 4) ...[
            plateRow([
              _f('gb_hath', '모자 높이', _hatH),
              _f('gb_hatf', '발 길이', _hatF),
            ]),
          ],
          if (lShape) ...[
            _row([
              if (_tabs & 1 != 0) _f('gb_tabl', '왼쪽 탭 길이', _tabL),
              if (_tabs & 2 != 0) _f('gb_tabr', '오른쪽 탭 길이', _tabR),
            ]),
          ],
        ]),
        if (_tabs != 0)
          PlateSection('절곡', [
            _row([_f('gb_r', '내R', _radius, hint: '비우면 ${fmt(_num(_thick))}')]),
          ]),
        const SizedBox(height: 12),
        ...elecFold(
          'gb_fold_shape',
          '자세히',
          _shapeMore(),
          subtitle: _shapeMoreSummary(),
        ),
      ],
    );
  }

  /// 모양 탭 "자세히": 끝 L자·오른쪽 발 따로·꺾기 보정(k·벤더 프로필).
  List<Widget> _shapeMore() => [
    PlateSection('끝만 ㄱ자로 절곡', [
      PlateSegments([
        for (final (i, label) in const [
          (1, '왼쪽 ㄱ자'),
          (2, '오른쪽 ㄱ자'),
          (3, '양쪽 ㄱ자'),
        ])
          PlateOption('gb_tab_$i', label, _tabs == i, () => _pickShape(i)),
      ]),
      _note(
        '부스바 끝을 ㄱ자로 90° 세웁니다(평절곡). 탭 길이는 바깥 치수입니다. 일자·모자로 돌아가려면 위 "모양"에서 고릅니다.',
      ),
    ], first: true),
    if (_tabs == 4)
      PlateSection('오른쪽 발', [
        _row([_f('gb_hatfr', '오른쪽 발 길이', _hatFR, hint: '비우면 왼쪽과 같음')]),
      ]),
    if (_tabs != 0)
      PlateSection('절곡 보정', [
        PlateSegments([
          for (final k in kBusbarK)
            PlateOption(
              'gb_kf_${(k * 100).round()}',
              fmt(k, 2),
              _k == k,
              () => _set(() => _k = k),
            ),
          if (!kBusbarK.contains(_k))
            PlateOption('gb_kf_custom', fmt(_k, 3), true, () {}),
        ]),
        _note(
          'K값: 절곡할 때 길이가 변하지 않는 선(중립선) 위치입니다. 구리 부스바 범위 0.33~0.5. 잔재로 시험 절곡해 맞춥니다.',
        ),
        plateActions([
          PlateActionButton(
            key: const Key('gb_profile'),
            icon: Icons.tune_rounded,
            label: _profileName == null
                ? '벤더 프로필 고르기·만들기'
                : '적용: $_profileName',
            primary: _profileName != null,
            onTap: _openProfiles,
          ),
          if (_profileName != null)
            PlateActionButton(
              key: const Key('gb_profile_off'),
              icon: Icons.close_rounded,
              label: '해제',
              onTap: () => _set(() {
                _profileName = null;
                _spring = 1.0;
              }),
            ),
        ]),
      ]),
  ];

  // ② 구멍: 접지 구멍(지름·피치·수/막대 길이·끝 여유), 취부(발·탭) 구멍, 접지 러그
  Widget _holesPanel(GroundBarPlan? p) {
    final tabTitle = _tabs == 4
        ? '발 홀 (취부)'
        : (_tabs == 0 ? '취부 홀 (양 끝)' : '탭 홀');
    return PlatePanel(
      title: '홀',
      status: p == null
          ? '홀 지름·피치와 홀 수를 넣으십시오.'
          : [
              '접지 홀 ${p.groundHoles.length}개',
              if (p.tabHoleList.isNotEmpty)
                '$_tabName 홀 ${p.tabHoleList.length}개',
              if (p.lugHoleList.isNotEmpty) '러그 홀 ${p.lugHoleList.length}개',
            ].join(' · '),
      actions: [
        plateHelpButton(context, 'gb_help_holes', '홀 탭', [
          '홀 지름 ▼ 목록은 볼트 틈새 홀(M8 9 · M10 11 · M12 13.5 · M16 17.5)이고, "내 금형"에 기계 펀치 금형 지름을 저장하면 그 값으로 바뀝니다.',
          '피치는 홀 중심 사이 거리입니다. 쓸 러그의 홀 간격에 맞춥니다.',
          '끝 여유: 직선부 끝(절곡했으면 절곡 끝선)에서 첫 홀 중심까지입니다. 기본 25는 임의 값입니다.',
          '홀 수로: 홀 수와 피치로 전개 길이를 계산합니다. 부스바 길이로: 가지고 있는 부스바에 홀이 몇 개 들어가는지 계산합니다.',
          '취부 홀: 일자는 부스바 양 끝에, 모자는 발에, ㄱ자는 탭에 판넬 취부용 홀을 따로 뚫습니다(한 곳에 넣은 개수만큼). 일자는 끝에서 첫 취부 홀까지, 마지막 취부 홀에서 첫 접지 홀까지 거리를 넣습니다.',
          '접지 러그: 접지 홀과 따로 부스바 가운데에 러그 홀을 추가로 뚫습니다. 2홀 러그는 러그 홀 간격만큼 떨어진 홀 둘입니다(NEMA 2홀 러그).',
          '두 줄 홀, 취부 홀 줄·뚫을 쪽, 러그 간격·놓는 방법·패드, 홀 크기 개별 수정, 내 펀치 금형은 아래 "자세히"에 있습니다.',
        ]),
      ],
      children: [
        PlateSection(_tabs == 4 ? '접지 홀 (윗면)' : '접지 홀', [
          plateRow([
            _f('gb_hole', '홀 지름', _hole, trailing: _dieMenu('gb_hd_', _hole)),
            _f(
              'gb_pitch',
              '피치',
              _pitch,
              trailing: _presetMenu(
                'gb_pp_',
                _pitch,
                kGroundPitches,
                fmt,
                tooltip: '자주 쓰는 피치',
              ),
            ),
          ]),
          PlateSegments([
            PlateOption(
              'gb_by_count',
              '홀 수로',
              !_byLength,
              () => _set(() => _byLength = false),
            ),
            PlateOption(
              'gb_by_len',
              '부스바 길이로',
              _byLength,
              () => _set(() => _byLength = true),
            ),
          ]),
          plateRow([
            _byLength
                ? _f('gb_len', '부스바 길이', _length)
                : _f('gb_n', '홀 수 (한 줄)', _count, unit: '개'),
            _f('gb_end', '끝 여유', _end),
          ]),
        ], first: true),
        PlateSection('$tabTitle · $_sideUnit 하나에', [
          PlateSegments([
            for (final n in const [0, 1, 2, 3])
              PlateOption(
                'gb_mc_$n',
                n == 0 ? '없음' : '$n개',
                _mCount == n,
                () => _set(() => _mCount = n),
              ),
          ]),
          if (_mCount > 0) ...[
            _row([
              _f(
                'gb_mdia',
                '$_tabName 홀 지름',
                _mDia,
                trailing: _dieMenu('gb_md_', _mDia),
              ),
              if (_mCount > 1) _f('gb_mpitch', '$_tabName 홀 피치', _mPitch),
            ]),
            if (_tabs == 0) ...[
              plateRow([
                _f('gb_mend', '끝 → 취부 홀', _mountEnd),
                _f('gb_mgap', '취부 → 첫 접지 홀', _mountGap),
              ]),
            ],
          ],
        ]),
        PlateSection('접지 러그 홀 (외부 러그)', _lugMain()),
        const SizedBox(height: 12),
        ...elecFold(
          'gb_fold_more',
          '자세히',
          _holesMore(p),
          subtitle: _holesMoreSummary(p),
        ),
      ],
    );
  }

  /// 구멍 탭 "자세히": 두 줄 구멍·취부 구멍 줄·뚫을 쪽·러그 더·구멍 하나 크기·내 펀치 금형.
  List<Widget> _holesMore(GroundBarPlan? p) => [
    PlateSection('접지 홀 줄', [
      PlateSegments([
        for (final (i, label) in const [
          (0, '한 줄'),
          (1, '두 줄 · 대칭'),
          (2, '두 줄 · 비대칭'),
        ])
          PlateOption(
            'gb_rm_$i',
            label,
            _rowMode == i,
            () => _set(() => _rowMode = i),
          ),
      ]),
      if (_twoRows) ...[
        _row([
          _f('gb_gap', '줄 간격', _gap),
          if (_rowMode == 2) _f('gb_shift', 'B줄 엇갈림', _shift, hint: '비우면 반 피치'),
        ]),
      ],
    ], first: true),
    if (_mCount > 0)
      PlateSection('$_tabName 홀 줄 (접지 홀과 따로)', [
        PlateSegments([
          for (final (i, label) in const [
            (0, '한 줄'),
            (1, '두 줄 · 대칭'),
            (2, '두 줄 · 비대칭'),
          ])
            PlateOption(
              'gb_trm_$i',
              label,
              _tabRowMode == i,
              () => _set(() => _tabRowMode = i),
            ),
        ]),
        if (_tabRowMode != 0) ...[
          _row([_f('gb_tabgap', '$_tabName 홀 줄 간격', _tabGap)]),
        ],
      ]),
    if ((_tabs == 0 || _tabs == 3 || _tabs == 4) && _mCount > 0)
      PlateSection('$_tabName 홀을 뚫을 쪽', [
        PlateSegments([
          for (final (i, label) in const [(3, '양쪽'), (1, '왼쪽만'), (2, '오른쪽만')])
            PlateOption(
              'gb_tsd_$i',
              label,
              _tabSides == i,
              () => _set(() => _tabSides = i),
            ),
        ]),
      ]),
    if (_lug != 0) PlateSection('접지 러그 (간격·놓는 방법·패드)', _lugMore()),
    if (p != null &&
        p.groundHoles.length + p.tabHoleList.length + p.lugHoleList.length > 0)
      PlateSection('홀 크기 개별 수정', _sizeEditor(p)),
    PlateSection('내 펀치 금형', [
      Text(
        '홀 지름 ▼ 목록:${_dieChips.map((d) => fmt(d)).join(' · ')}${_dies.isEmpty ? ' (기본)' : ''}',
        style: TextStyle(fontSize: 14, color: fc.text, height: 1.4),
      ),
      plateActions([
        PlateActionButton(
          key: const Key('gb_dies_more'),
          icon: Icons.edit_outlined,
          label: _dies.isEmpty ? '내 금형 넣기' : '내 금형 고치기',
          onTap: _editDies,
        ),
      ]),
    ]),
  ];

  // ③ 결과: 절단 길이·알림, 꺾기·구멍 위치, 판넬 취부·러그(접음), 작업 순서, 근거
  Widget _resultPanel(GroundBarPlan? p) {
    final warn = p != null && !p.ok;
    return PlatePanel(
      title: '결과',
      status: p == null
          ? '치수를 넣으면 계산합니다.'
          : '$_shapeName · 홀 ${p.groundHoles.length}개 · 약 ${fmt(p.weightKg, 2)}kg',
      statusColor: warn ? fc.danger : null,
      children: [
        PlateSection('전개 길이', [
          KeyedSubtree(
            key: const Key('gb_result'),
            child: PlateBigValue(
              value: p == null ? '— mm' : '${fmt(p.length, 1)} mm',
              caption: p == null ? '치수를 넣으면 계산합니다' : '이 길이로 절단합니다',
              warn: warn || _radiusWarn != null,
            ),
          ),
          if (p != null) ...[
            PlateLines([
              ...p.problems,
              ...p.notes,
              ?_radiusWarn,
              ..._springLines(p.bends.map((b) => b.turn)),
              if (p.holes > 0) _rowText(p),
              if (_byLength &&
                  p.holes > 0 &&
                  !(_packGround && p.lugHoleList.isNotEmpty))
                '남는 길이는 양 끝 여유에 똑같이 나눴습니다(양 끝 ${fmt(p.endLeft, 1)} / ${fmt(p.endRight, 1)}mm).'
              else if (p.holes > 0 && _packGround && p.lugHoleList.isNotEmpty)
                '접지 홀 ${p.holes}개를 왼쪽 끝에서부터 놓고, 오른쪽 남는 자리에 러그 홀을 가운데로 두었습니다.',
              if (p.hat)
                '모자: 높이 ${fmt(_num(_hatH))} · 발 ${fmt(_num(_hatF))} / ${fmt(readNum(_hatFR) ?? _num(_hatF))} · 윗면 바깥 폭 ${fmt(p.hatWidth, 1)}mm. 절곡 4곳, 접지 홀 줄은 윗면 직선부 ${fmt(p.flatStart, 1)}~${fmt(p.flatEnd, 1)}mm에 있습니다.'
              else if (p.bends.isNotEmpty)
                'ㄱ자 절곡 ${p.bends.length}곳. 홀 줄은 직선부 ${fmt(p.flatStart, 1)}~${fmt(p.flatEnd, 1)}mm에 있습니다.',
              if (p.tabHoleList.isNotEmpty) _tabHoleSummary(p),
              ?_panelSpanLine(p),
              if (p.minEdgeBody != null || p.minEdgeTab != null) _edgeLine(p),
              if (p.lugHoleList.isNotEmpty)
                '접지 러그 홀 ${p.lugHoleList.length}개를 접지 홀과 따로 부스바 가운데(폭 ${fmt(p.lugHoleList.first.y, 1)}mm)에 추가했습니다.',
            ], color: warn ? fc.danger : null),
          ],
        ], first: true),
        if (p != null) ...[
          if (p.bends.isNotEmpty)
            PlateSection('절곡 (왼쪽 끝에서)', [
              KeyedSubtree(
                key: const Key('gb_bends'),
                child: Column(
                  children: [
                    for (var i = 0; i < p.bends.length; i++)
                      _bendTile(p.bends[i], i, p),
                  ],
                ),
              ),
            ]),
          if (p.holes > 0) PlateSection('접지 홀 위치 (왼쪽 끝에서 중심까지)', [_holeBox(p)]),
          if (p.tabHoleList.isNotEmpty)
            PlateSection('$_tabName 홀 위치 (왼쪽 끝에서 중심까지)', [_tabHoleBox(p)]),
          const SizedBox(height: 12),
          ...elecFold(
            'gb_fold_mount',
            '판넬 취부 ($_tabName 홀로 설치)',
            _mountSection(p),
          ),
          ...elecFold(
            'gb_fold_lug',
            '접지 러그 홀 (가운데에 추가)',
            _lugResults(p),
            subtitle: '${p.lugHoleList.length}개',
          ),
          ...elecFold('gb_fold_notes', '작업 순서', [
            KeyedSubtree(
              key: const Key('gb_notes'),
              child: PlateLines([
                '구리 부스바를 전개 길이로 절단합니다. 절단면 버를 갈아 냅니다.',
                '왼쪽 끝을 기준으로 홀 중심${_tabs != 0 ? "과 절곡 시작선" : ""}을 마킹합니다. 줄자는 왼쪽 끝에 한 번 대고 표의 누적 치수로 찍습니다.',
                '기계에 홀 지름과 같은 펀치 금형을 끼우고 마킹 중심에 맞춰 뚫습니다. 맞는 금형이 없는 크기는 드릴로 뚫습니다.',
                '홀 둘레 버를 정리합니다.',
                if (_mCount > 0) '$_tabName 홀도 같은 방법으로 뚫습니다.',
                if (_tabs == 4)
                  '홀을 다 뚫은 뒤 절곡 시작선 4곳을 차례로 절곡합니다. 가운데에서 바깥으로: 다리 두 곳을 먼저 내리고 발을 바깥으로 절곡하면 벤더에 걸리지 않습니다.'
                else if (_tabs != 0)
                  '홀을 다 뚫은 뒤 절곡 시작선에 맞춰 탭을 90°로 절곡합니다(홀을 먼저 뚫어야 평평한 채로 작업합니다).',
                if (_tabs != 0) '처음 만드는 치수는 잔재로 한 번 시험 절곡해 보고 길이를 맞춥니다.',
                '접촉면을 닦아 접지 러그를 붙입니다.',
              ]),
            ),
          ]),
        ],
        const SizedBox(height: 8),
        elecBasis('gb_basis', kGroundBarBasis),
      ],
    );
  }

  // ④ 보내기: 작업 이름 · 카톡 글 · 가공 지시서 PDF
  Widget _sendPanel(GroundBarPlan? p) => PlatePanel(
    title: '보내기',
    status: p == null ? '치수를 넣으면 보낼 수 있습니다.' : '카톡 글 · 가공 도면 PDF',
    children: [
      PlateSection('가공 도면', [
        PlateNumField(
          fieldKey: 'gb_job',
          label: '작업 이름 (선택)',
          controller: _jobName,
          unit: null,
          text: true,
          hint: '도면 PDF 제목·저장 이름',
          onChanged: (_) => _saveSoon(),
        ),
      ], first: true),
      if (p != null)
        PlateSection('보내기', [
          plateActions([
            PlateActionButton(
              key: const Key('gb_share'),
              icon: Icons.chat_bubble_outline_rounded,
              label: '카톡 글',
              primary: true,
              onTap: () => widget.share(_shareText(p)),
            ),
            PlateActionButton(
              key: const Key('gb_pdf'),
              icon: Icons.picture_as_pdf_outlined,
              label: '가공 도면 PDF',
              onTap: () => openGroundBarPdf(context, _pdfInput(p)),
            ),
          ]),
        ]),
    ],
  );

  Widget? _navBar(int idx) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return null;
    final compact = calcNavCompact(context);
    BottomNavigationBarItem item(String id, String label, int i) {
      final on = i == idx;
      final Widget icon = switch (id) {
        'shape' => AppIcon(AppGlyph.groundBar, size: 24, filled: on),
        'holes' => AppIcon(AppGlyph.navInput, size: 24, filled: on),
        'result' => AppIcon(AppGlyph.navMarking, size: 24, filled: on),
        _ => const Icon(AppIcons.send, size: 22),
      };
      return BottomNavigationBarItem(
        icon: Padding(
          padding: EdgeInsets.only(bottom: compact ? 0 : 4),
          // 키 gb_tab_*는 모양 칩이 이미 쓰므로 아래 탭은 gb_nav_*
          child: KeyedSubtree(key: Key('gb_nav_$id'), child: icon),
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
              setState(() => _pane = i);
            },
            items: [
              for (var i = 0; i < _panes.length; i++)
                item(_panes[i].$1, _panes[i].$2, i),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _plan();
    final warn = p != null && !p.ok;
    final summary = p == null
        ? null
        : '접지바 ${fmt(_num(_thick))}T×${fmt(_num(_width))} · ${fmt(p.length, 1)}mm · 홀 ${p.groundHoles.length}개';
    final idx = _pane.clamp(0, _panes.length - 1);
    return FieldViewTheme(
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
                  '접지바 가공',
                  style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
                ),
                if (summary != null)
                  Text(
                    summary,
                    key: const Key('gb_head'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: warn ? fc.danger : fc.brand,
                    ),
                  ),
              ],
            ),
            actions: [
              PlateBarAction(
                key: const Key('gb_saved'),
                icon: Icons.bookmarks_outlined,
                label: '저장',
                onTap: _openSavedSheet,
              ),
              calcHistoryButton(),
            ],
          ),
          body: elecPageFrame(
            sumKey: 'gb_sum',
            summary: summary,
            warn: warn,
            showBar: false,
            body: PlateWorkspace(
              canvasShare: 0.38,
              canvas: KeyedSubtree(
                key: const ValueKey('gb_canvas'),
                child: _canvas(p),
              ),
              tools: _canvasTools(p),
              hint: _canvasHint(p),
              panel: IndexedStack(
                index: idx,
                children: [
                  for (final t in _panes)
                    KeyedSubtree(
                      key: ValueKey('gb_body_${t.$1}'),
                      child: switch (t.$1) {
                        'shape' => _shapePanel(p),
                        'holes' => _holesPanel(p),
                        'result' => _resultPanel(p),
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
    );
  }
}
