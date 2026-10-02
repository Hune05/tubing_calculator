// 접지바 구멍 계산기(10-03): 구리 평강에 구멍을 뚫어 접지바를 만들 때 자르는 길이와 구멍 위치.
// 계산은 busbar_ground.dart.
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
import 'elec_form_parts.dart';

Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

const List<String> kGroundBarBasis = [
  '구멍 줄: 폭 가운데 한 줄, 구멍 중심 피치가 같습니다. 구멍 수로 정하면 길이 = 2 × 끝 여유 + (구멍 수 − 1) × 피치. 길이로 정하면 들어가는 만큼 뚫고 남는 길이는 양 끝에 똑같이 나눕니다.',
  '구멍 지름 7/16"(약 11.1mm)는 NEMA 접지바(3/8" 볼트용)에서 제조사 자료 세 곳이 같습니다. 5/16"(약 7.9mm)는 통신 접지바(1/4" 볼트용)입니다.',
  '구멍 피치 3/4"(19.05)·1"(25.4)는 NEMA 2구멍 러그, 1-3/4"(44.45)는 NEMA 러그 패드, 5/8"(15.875)는 통신 접지바(BICSI·EIA/TIA 607) 구멍 줄입니다. 쓸 러그·터미널의 구멍 간격에 맞추십시오.',
  '끝 여유는 정해진 규격 값을 찾지 못했습니다. 기본 25mm는 임의 값이니 설계도나 러그 크기에 맞추십시오. 구멍이 끝 면을 뚫거나 서로 겹치는 경우만 알립니다.',
  '무게는 구리 밀도 8.9 g/cm³로 구멍을 뺀 부피에 곱한 근사값입니다.',
  '끝 L 꺾기: 두께 방향(눕혀 꺾기) 90°, 부스바 절곡 계산기와 같은 식(중립선 반경 r + k·t)입니다. 탭 길이는 바깥 치수, 최소 안쪽 반경은 CDA 한 곳 자료(두께 10mm 이하 1배)입니다. k 기본 0.4는 범위(0.33~0.5)의 가운데 값이니 시험 조각으로 맞추십시오.',
  '모자(챙 달림): 몸체 양쪽 다리를 90°로 내리고 다리 끝을 바깥으로 다시 꺾어 바닥에 대는 챙을 만듭니다. 치수는 모두 바깥 치수(챙 길이는 다리 바깥면까지, 높이는 챙 바닥면에서 윗면까지)이고 자르는 길이 = 2 × 챙 + 2 × 높이 + 몸체 폭 − 4 × 굽힘 공제입니다. 꺾기 4곳 모두 같은 식입니다.',
  '탭·챙 구멍은 평평한 길이(끝에서 꺾기 시작선까지) 가운데에 모아 뚫습니다. 구멍 지름·피치는 접지 구멍과 같은 규격 값을 쓰되 취부 볼트에 맞게 고칠 수 있습니다.',
  '넣지 않은 것: 2열 구멍, 스프링백, 모서리 둥글림, 구멍 면취, 챙이 서로 다른 모자.',
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
  int _mCount = 0; // 탭·챙 구멍 수
  double _k = 0.4;
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
  final _mDia = TextEditingController(text: '11.1');
  final _mPitch = TextEditingController(text: '25.4');

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
    _mDia,
    _mPitch,
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
    'md',
    'mp',
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
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  String _draft() => jsonEncode({
    'bl': _byLength,
    'tb': _tabs,
    'mc': _mCount,
    'k': _k,
    for (var i = 0; i < _fields.length; i++) _fieldKeys[i]: _fields[i].text,
  });

  Future<void> _loadDraft() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(GroundBarPage.draftKey);
      if (raw != null && mounted) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        setState(() {
          if (m['bl'] is bool) _byLength = m['bl'] as bool;
          final tb = m['tb'], kk = m['k'];
          final mc = m['mc'];
          if (tb is int && tb >= 0 && tb <= 4) _tabs = tb;
          if (mc is int && mc >= 0 && mc <= 3) _mCount = mc;
          if (kk is num && kBusbarK.contains(kk.toDouble())) _k = kk.toDouble();
          for (var i = 0; i < _fields.length; i++) {
            final v = m[_fieldKeys[i]];
            if (v is String) _fields[i].text = v;
          }
        });
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

  GroundBarPlan? _plan() {
    if (!_ready) return null;
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
      hat: _tabs == 4,
      hatHeight: _num(_hatH),
      hatFlange: _num(_hatF),
      tabHoleCount: _tabs == 0 ? 0 : _mCount,
      tabHoleDia: _num(_mDia),
      tabHolePitch: _num(_mPitch),
      r: readNum(_radius),
      k: _k,
    );
  }

  double get _r => readNum(_radius) ?? _num(_thick);

  String? get _radiusWarn {
    if (_tabs == 0) return null;
    final min = busbarMinRadius(_num(_thick));
    if (_r + 1e-9 >= min) return null;
    return 'L 꺾기 안쪽 반경 ${fmt(_r)}mm가 최소 반경 ${fmt(min)}mm(CDA, 두께 ${fmt(_num(_thick))}mm 기준)보다 작습니다. 모서리가 갈라질 수 있습니다.';
  }

  /// 구멍 위치 한 줄 규칙: 첫 구멍·피치·마지막 구멍.
  String _ruleText(GroundBarPlan p) =>
      '첫 구멍 ${fmt(p.positions.first, 1)} → 피치 ${fmt(_num(_pitch))} × ${p.holes - 1}칸 → 마지막 구멍 ${fmt(p.positions.last, 1)}';

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

  String _shareText(GroundBarPlan p) {
    final b = StringBuffer(
      '[접지바] 구리 ${fmt(_num(_thick))}×${fmt(_num(_width))}mm · 구멍 φ${fmt(_num(_hole))} ${p.holes}개 피치 ${fmt(_num(_pitch))}',
    );
    b.write('\n자르는 길이: ${fmt(p.length, 1)}mm (약 ${fmt(p.weightKg, 2)}kg)');
    b.write('\n구멍 중심선: 폭 가운데 ${fmt(p.centerLine, 1)}mm');
    if (p.bends.isNotEmpty) {
      final tab = _tabs == 4
          ? '모자 높이 ${fmt(_num(_hatH))} · 챙 ${fmt(_num(_hatF))}'
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
    if (p.tabHoles.isNotEmpty) {
      b.write(
        '\n${p.hat ? '챙' : '탭'} 구멍 φ${fmt(p.tabHoleDia)} (왼쪽 끝에서 중심): ${p.tabHoles.map((v) => fmt(v, 1)).join(' · ')}',
      );
    }
    if (p.holes > 0) {
      b.write('\n구멍 위치 (왼쪽 끝에서 중심까지): ${_ruleText(p)}');
      for (final (label, vals) in groundHoleRows(p)) {
        b.write('\n $label ${vals.map((v) => fmt(v, 1)).join(' · ')}');
      }
    }
    for (final s in p.problems) {
      b.write('\n※ $s');
    }
    return b.toString();
  }

  Widget _bendTile(BusbarBend b, int i, GroundBarPlan p) {
    final side = _bendName(i, p);
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
                    '$side · 시작선 ${fmt(b.start, 1)} mm',
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

  Widget _tabHoleBox(GroundBarPlan p) {
    final half = p.tabHoles.length ~/ 2;
    final both = p.hat || _tabs == 3;
    final left = both || _tabs == 1
        ? p.tabHoles.sublist(0, both ? half : p.tabHoles.length)
        : <double>[];
    final right = both
        ? p.tabHoles.sublist(half)
        : (_tabs == 2 ? p.tabHoles : <double>[]);
    Widget row(String label, List<double> v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 84,
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
              v.map((x) => fmt(x, 1)).join('   '),
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
    return KeyedSubtree(
      key: const Key('gb_tab_holes'),
      child: calcBox(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (left.isNotEmpty) row('왼쪽', left),
              if (right.isNotEmpty) row('오른쪽', right),
              Text(
                '펼친 막대 왼쪽 끝에서 잰 구멍 중심입니다. 오른쪽은 오른쪽 끝에서 같은 거리입니다.',
                style: TextStyle(fontSize: 13, color: fc.textSub),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 구멍 위치: 규칙 한 줄 + 5개씩 묶은 표 + 마지막 구멍 검산.
  Widget _holeBox(GroundBarPlan p) {
    final rows = groundHoleRows(p);
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
              '피치가 같아 첫 구멍만 재고 피치 간격으로 이어 찍으면 됩니다. 아래는 하나씩 재는 값(5개씩 묶음)입니다.',
              style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.35),
            ),
            const SizedBox(height: 8),
            for (final (label, vals) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 64,
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
                        vals.map((v) => fmt(v, 1)).join('   '),
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: fc.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
      elecChipGroup(
        '무엇으로 정하나',
        '구멍 수: 구멍 수와 피치로 자르는 길이를 계산합니다. 막대 길이: 가진 막대 길이에 구멍이 몇 개 들어가는지 계산합니다.',
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
      elecField(
        'gb_w',
        '폭 (mm)',
        _width,
        '구리 부스바 폭입니다. 구멍은 폭 가운데에 뚫습니다.',
        onEdit: _saveSoon,
      ),
      elecSectionTitle('구멍'),
      elecField(
        'gb_hole',
        '구멍 지름 (mm)',
        _hole,
        '볼트가 지나는 구멍 지름입니다. 7/16"(11.1)는 NEMA 접지바 3/8" 볼트용입니다.',
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
        '막대 끝 면에서 첫 구멍 중심까지입니다. 규격 값을 못 찾아 임의 기본값입니다.',
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
          '구멍 수 (개)',
          _count,
          '뚫을 구멍 개수입니다.',
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
          '챙 길이 (mm)',
          _hatF,
          '다리 바깥면에서 챙 끝까지 길이입니다. 양쪽 챙이 같습니다.',
          onEdit: _saveSoon,
        ),
      if (_tabs != 0)
        elecChipGroup(
          _tabs == 4 ? '챙 구멍 수 (취부용, 각 챙)' : '탭 구멍 수 (각 탭)',
          '탭·챙의 평평한 길이 가운데에 모아 뚫습니다. 0이면 뚫지 않습니다.',
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
          _tabs == 4 ? '챙 구멍 지름 (mm)' : '탭 구멍 지름 (mm)',
          _mDia,
          '취부·접지 러그 볼트가 지나는 구멍 지름입니다.',
          onEdit: _saveSoon,
        ),
      if (_tabs != 0 && _mCount > 1)
        elecField(
          'gb_mpitch',
          _tabs == 4 ? '챙 구멍 피치 (mm)' : '탭 구멍 피치 (mm)',
          _mPitch,
          '탭·챙 구멍 중심 사이 거리입니다.',
          onEdit: _saveSoon,
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
      summary =
          '접지바 ${fmt(_num(_thick))}×${fmt(_num(_width))} · ${fmt(p.length, 1)}mm · 구멍 ${p.holes}개';
      children.addAll([
        calcResult(
          key: const Key('gb_result'),
          big: '${fmt(p.length, 1)} mm',
          caption: '자르는 길이 · 구멍 ${p.holes}개 · 약 ${fmt(p.weightKg, 2)}kg',
          warn: warn || _radiusWarn != null,
          lines: [
            ...p.problems,
            ?_radiusWarn,
            if (p.holes > 0) '구멍 중심선은 폭 가운데 ${fmt(p.centerLine, 1)}mm입니다.',
            if (_byLength && p.holes > 0)
              '남는 길이는 양 끝 여유에 똑같이 나눴습니다(양 끝 ${fmt(p.endLeft, 1)} / ${fmt(p.endRight, 1)}mm).',
            if (p.hat)
              '모자: 높이 ${fmt(_num(_hatH))} · 챙 ${fmt(_num(_hatF))} · 몸체 바깥 폭 ${fmt(p.hatWidth, 1)}mm. 꺾기 4곳, 접지 구멍 줄은 몸체 곧은 구간 ${fmt(p.flatStart, 1)}~${fmt(p.flatEnd, 1)}mm에 있습니다.'
            else if (p.bends.isNotEmpty)
              'L 꺾기 ${p.bends.length}곳. 구멍 줄은 곧은 구간 ${fmt(p.flatStart, 1)}~${fmt(p.flatEnd, 1)}mm에 있습니다.',
            if (p.tabHoles.isNotEmpty)
              '${p.hat ? "챙" : "탭"} 구멍 ${p.tabHoles.length}개(φ${fmt(p.tabHoleDia)}): 평평한 길이 ${fmt(p.tabFlat, 1)}mm 가운데에 있습니다.',
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
        calcLabel('위에서 본 모양', '실제 비율입니다. 아래 숫자는 끝 여유와 구멍 피치(mm)입니다.'),
        const SizedBox(height: 4),
        _drawing(
          const Key('gb_view'),
          150,
          GroundBarPainter(
            plan: p,
            width: _num(_width),
            holeDia: _num(_hole),
            text: fc.text,
            sub: fc.textSub,
            bg: fc.background,
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
        if (p.tabHoles.isNotEmpty) ...[
          elecSectionTitle('${p.hat ? "챙" : "탭"} 구멍 위치 (왼쪽 끝에서 중심까지)'),
          _tabHoleBox(p),
        ],
        const SizedBox(height: 8),
        calcResult(
          key: const Key('gb_notes'),
          big: '작업 순서',
          caption: '현장에서 만들 때',
          lines: [
            '구리 막대를 자르는 길이로 자릅니다. 절단면 버를 갈아 냅니다.',
            '폭 가운데에 중심선을 긋고, 왼쪽 끝에서 구멍 위치를 재어 센터 펀치를 칩니다.',
            '작은 드릴로 먼저 뚫은 뒤 구멍 지름으로 넓힙니다. 구리는 절삭유를 씁니다.',
            '구멍 둘레 버를 정리합니다.',
            if (_tabs != 0 && _mCount > 0)
              '${_tabs == 4 ? "챙" : "탭"} 구멍도 같은 방법으로 뚫습니다.',
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
