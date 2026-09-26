// 전동 벤딩 계산기(홈 "배관·튜브"). 설정의 전동 장비 두 대(Swagelok MS-BTB, TUBOBEND TB20D)를 골라
// 그 금형의 반경·시험 굽힘 값으로 마킹 위치·넣을 각도·굴림을 낸다. 계산은 electric_bend_plan.dart
// (튜브 벤딩 엔진을 그대로 부름), 장비·금형 자료는 electric_machines.dart, 근거는 docs/전동벤더_근거.md.
// 벤드 목록은 'electric_bender_bends_v1'에 저장하고, 처음 열 때 옛 전동 계산기 목록(saved_electric_bend_list)을 가져온다.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/engine/bend_geometry.dart' show gainFromMeasured;
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import 'electric_bend_plan.dart';
import 'electric_machines.dart';

const String kElectricBendsKey = 'electric_bender_bends_v1';
const String _oldListKey = 'saved_electric_bend_list';

/// 방향 코드(옛 전동 계산기와 같음) → 이름.
final Map<double, String> kDirNames = {
  0: '위',
  180: '아래',
  270: '왼쪽',
  90: '오른쪽',
  360: '앞',
  450: '뒤',
};

String _f(double v, [int d = 1]) {
  var s = (v + (v >= 0 ? 1e-9 : -1e-9)).toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  if (s == '-0') s = '0';
  return s;
}

String _today() {
  final n = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${n.year}-${two(n.month)}-${two(n.day)}';
}

class _Row {
  _Row({String len = '', String ang = '', this.dir = 90})
    : len = TextEditingController(text: len),
      ang = TextEditingController(text: ang);
  final TextEditingController len;
  final TextEditingController ang;
  double dir;

  void dispose() {
    len.dispose();
    ang.dispose();
  }
}

class ElectricBenderPage extends StatefulWidget {
  const ElectricBenderPage({super.key});

  @override
  State<ElectricBenderPage> createState() => _ElectricBenderPageState();
}

class _ElectricBenderPageState extends State<ElectricBenderPage>
    with CalcFormParts<ElectricBenderPage>, WidgetsBindingObserver {
  ElectricBenderStore _store = ElectricBenderStore();
  final List<_Row> _rows = [_Row()];
  final _tail = TextEditingController();
  final _fit = TextEditingController();
  final _kerf = TextEditingController();
  bool _loaded = false;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final store = await ElectricBenderStore.load();
    List<_Row>? rows;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kElectricBendsKey);
      if (raw != null) {
        final m = jsonDecode(raw);
        if (m is Map) {
          rows = _rowsFrom(m['rows']);
          _tail.text = m['tail'] is String ? m['tail'] as String : '';
          _fit.text = m['fit'] is String ? m['fit'] as String : '';
          _kerf.text = m['kerf'] is String ? m['kerf'] as String : '';
        }
      } else {
        // 옛 전동 계산기 목록을 가져온다(길이·각도·방향).
        final old = prefs.getString(_oldListKey);
        if (old != null) {
          final list = jsonDecode(old);
          if (list is List) {
            rows = [
              for (final e in list)
                if (e is Map)
                  _Row(
                    len: _f((e['length'] as num?)?.toDouble() ?? 0),
                    ang: _f((e['angle'] as num?)?.toDouble() ?? 0),
                    dir: _dirOf(e['rotation']),
                  ),
            ];
          }
        }
      }
    } catch (_) {
      // 읽지 못하면 빈 목록으로.
    }
    if (!mounted) return;
    setState(() {
      _store = store;
      if (rows != null && rows.isNotEmpty) {
        for (final r in _rows) {
          r.dispose();
        }
        _rows
          ..clear()
          ..addAll(rows);
      }
      _loaded = true;
    });
  }

  static double _dirOf(Object? v) {
    final d = (v as num?)?.toDouble() ?? 90;
    return kDirNames.containsKey(d) ? d : 90;
  }

  static List<_Row>? _rowsFrom(Object? raw) {
    if (raw is! List) return null;
    return [
      for (final e in raw)
        if (e is Map)
          _Row(
            len: e['len'] is String ? e['len'] as String : '',
            ang: e['ang'] is String ? e['ang'] as String : '',
            dir: _dirOf(e['dir']),
          ),
    ];
  }

  String _draftJson() => jsonEncode({
    'rows': [
      for (final r in _rows)
        {'len': r.len.text, 'ang': r.ang.text, 'dir': r.dir},
    ],
    'tail': _tail.text,
    'fit': _fit.text,
    'kerf': _kerf.text,
  });

  void _saveNow() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_loaded) return;
    final json = _draftJson();
    SharedPreferences.getInstance()
        .then((p) => p.setString(kElectricBendsKey, json))
        .catchError((_) => false);
    _store.save();
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (!_loaded) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _saveNow);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _saveNow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveNow();
    for (final r in _rows) {
      r.dispose();
    }
    _tail.dispose();
    _fit.dispose();
    _kerf.dispose();
    super.dispose();
  }

  double? _n(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', ''));

  ElectricMachine get _machine => machineById(_store.machine);

  /// 입력한 벤드 목록(길이가 없는 줄은 뺀다).
  List<Map<String, double>> get _bends => [
    for (final r in _rows)
      if ((_n(r.len) ?? 0) > 0)
        {'length': _n(r.len)!, 'angle': _n(r.ang) ?? 0, 'rotation': r.dir},
  ];

  // ─────────────── 화면 ───────────────

  Widget _chips(String title, String guide, List<Widget> chips) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
            ),
          ),
          const SizedBox(width: 6),
          calcHelp(title, guide),
        ],
      ),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: chips),
      const SizedBox(height: 12),
    ],
  );

  Widget _note(String text, {Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.only(top: 10),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.45),
    ),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: fc.text,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => FieldViewTheme(
    child: Builder(
      builder: (context) => Scaffold(
        backgroundColor: fc.background,
        appBar: AppBar(
          backgroundColor: fc.surface,
          foregroundColor: fc.text,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            '전동 벤딩 계산기',
            style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
          ),
        ),
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            behavior: HitTestBehavior.translucent,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                ..._machinePart(),
                _section('벤드 목록'),
                ..._bendPart(),
                _section('결과'),
                ..._resultPart(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _machinePart() {
    final m = _machine;
    final list = _store.toolingOf(m.id);
    final t = _store.selected;
    return [
      _chips('장비', m.note, [
        for (final x in kElectricMachines)
          calcChip('eb_machine_${x.id.name}', x.shortName, x.id == m.id, () {
            setState(() {
              _store.machine = x.id;
              _store.toolingId = null;
            });
          }),
      ]),
      if (list.isEmpty)
        calcBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '이 장비는 금형 값이 없습니다. "금형 더하기"로 금형에 새겨진 관경과 반경(R)을 넣으십시오.',
              key: const Key('eb_no_tooling'),
              style: TextStyle(color: fc.textSub, height: 1.4),
            ),
          ),
        )
      else
        calcDropdown<String>(
          'eb_tooling',
          '금형 (관경 · 반경)',
          t!.id,
          [for (final x in list) x.id],
          (id) => list.firstWhere((x) => x.id == id).label,
          (id) => setState(() => _store.toolingId = id),
          '벤드 슈(금형)에 새겨진 관경과 반경입니다. 같은 관경에 반경이 둘 있으면(예: 1/2" R36·R56) 장비에 끼운 슈를 고르십시오.',
        ),
      if (t != null) _toolingCard(t),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (t != null)
            calcToggle('eb_trial', '시험 굽힘으로 맞추기', () => _openTrial(t)),
          if (t != null) calcToggle('eb_edit', '값 고치기', () => _openEdit(t)),
          calcToggle('eb_addtool', '금형 더하기', () => _openEdit(null)),
        ],
      ),
    ];
  }

  Widget _toolingCard(Tooling t) {
    final theoGain = 0.4292 * t.radius;
    String line(String a, String b) => '$a: $b';
    final lines = [
      line(
        '반경',
        'R${_f(t.radius)}mm${t.radiusSource.isEmpty ? '' : ' (${t.radiusSource})'}',
      ),
      line(
        '게인(90°)',
        t.gain90 > 0
            ? '${_f(t.gain90)}mm (${t.gainSource.isEmpty ? '직접 넣음' : t.gainSource})'
            : '이론값 ${_f(theoGain)}mm (0.4292 × R). 시험 굽힘으로 맞추십시오',
      ),
      line(
        '스프링백(90°)',
        t.springback90 > 0
            ? '${_f(t.springback90)}° (${t.springbackSource.isEmpty ? '직접 넣음' : t.springbackSource})'
            : '넣지 않음. 넣을 각도가 설계각과 같게 나옵니다',
      ),
      line('클램프 물림', t.clampLen > 0 ? '${_f(t.clampLen)}mm' : '넣지 않음(점검 안 함)'),
      line(
        '마지막 다리 최소',
        t.lastLegMin > 0 ? '${_f(t.lastLegMin)}mm' : '넣지 않음(점검 안 함)',
      ),
    ];
    return Container(
      key: const Key('eb_tooling_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                l,
                style: TextStyle(fontSize: 13, color: fc.text, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _bendPart() => [
    _note(
      '길이는 교차점 기준입니다: 1번 줄은 관 끝(피팅 끝)에서 1번 벤드 꼭짓점까지, 2번 줄부터는 앞 꼭짓점에서 이번 꼭짓점까지. '
      '방향은 그 벤드에서 관이 꺾여 나가는 쪽입니다. 각도를 비우거나 0이면 곧은 관입니다.',
    ),
    const SizedBox(height: 8),
    for (int i = 0; i < _rows.length; i++) _rowEditor(i),
    Align(
      alignment: Alignment.centerLeft,
      child: calcToggle('eb_add', '+ 벤드 더하기', () {
        setState(() => _rows.add(_Row(dir: _rows.last.dir)));
      }),
    ),
    calcField(
      'eb_tail',
      '마지막 다리 (mm)',
      _tail,
      '마지막 벤드 꼭짓점에서 관 끝(피팅 끝)까지입니다. 비우면 마지막 벤드에서 끝납니다.',
    ),
    calcField(
      'eb_fit',
      '피팅 삽입 깊이 (mm, 선택)',
      _fit,
      '양 끝을 피팅에 끼울 때 관이 들어가는 깊이입니다. 넣으면 양 끝 길이에 더합니다. 피팅 카탈로그의 삽입 깊이를 넣으십시오.',
    ),
    calcField(
      'eb_kerf',
      '톱날 손실 (mm, 선택)',
      _kerf,
      '자를 때 톱날 두께만큼 없어지는 길이입니다. 자를 길이에만 더합니다.',
    ),
  ];

  Widget _rowEditor(int i) {
    final r = _rows[i];
    TextStyle st = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: fc.text,
    );
    InputDecoration deco(String label) => InputDecoration(
      labelText: label,
      isDense: true,
      border: InputBorder.none,
    );
    return Container(
      key: Key('eb_row_$i'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${i + 1}',
              style: TextStyle(fontWeight: FontWeight.w900, color: fc.textSub),
            ),
          ),
          Expanded(
            flex: 4,
            child: TextField(
              key: Key('eb_len_$i'),
              controller: r.len,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: st,
              decoration: deco('길이 mm'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: TextField(
              key: Key('eb_ang_$i'),
              controller: r.ang,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: st,
              decoration: deco('각도 °'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 4,
            child: DropdownButton<double>(
              key: Key('eb_dir_$i'),
              value: r.dir,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: fc.surface,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: fc.text,
              ),
              items: [
                for (final e in kDirNames.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => r.dir = v);
              },
            ),
          ),
          IconButton(
            key: Key('eb_del_$i'),
            tooltip: '이 줄 지우기',
            icon: Icon(Icons.close, color: fc.textSub),
            onPressed: _rows.length <= 1
                ? null
                : () => setState(() => _rows.removeAt(i).dispose()),
          ),
        ],
      ),
    );
  }

  List<Widget> _resultPart() {
    final t = _store.selected;
    final m = _machine;
    if (t == null) {
      return [calcResult(big: '—', caption: '금형을 먼저 더하십시오', lines: const [])];
    }
    final bends = _bends;
    if (bends.isEmpty) {
      return [calcResult(big: '—', caption: '벤드 길이를 넣으십시오', lines: const [])];
    }
    final plan = planElectricBends(
      tooling: t,
      machine: m,
      bends: bends,
      tail: _n(_tail) ?? 0,
      fittingDepth: _n(_fit) ?? 0,
      kerf: _n(_kerf) ?? 0,
    );
    if (plan.error != null) {
      return [
        calcResult(
          key: const Key('eb_result'),
          big: '계산할 수 없음',
          caption: '입력을 확인하십시오',
          warn: true,
          lines: [plan.error!],
        ),
      ];
    }
    final hasBend = plan.rows.any((r) => !r.isStraight);
    return [
      calcResult(
        key: const Key('eb_result'),
        big: '${_f(plan.totalCut)} mm',
        caption: '자를 길이',
        warn: plan.warnings.isNotEmpty,
        lines: [
          if ((_n(_kerf) ?? 0) > 0)
            '톱날 손실 ${_f(_n(_kerf)!)}mm 포함 (관 길이 ${_f(plan.pureCut)}mm)',
          if (hasBend) '마지막 벤드 뒤 곧은 길이 ${_f(plan.afterLast)}mm',
          t.gain90 > 0
              ? '게인: ${t.gainSource.isEmpty ? '직접 입력' : t.gainSource}'
              : '게인: 이론값(시험 굽힘 전). 첫 관은 넉넉히 잘라 확인하십시오.',
        ],
      ),
      if (plan.warnings.isNotEmpty)
        Container(
          key: const Key('eb_warn'),
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: fieldSoft(Colors.red.shade50, (p) => p.danger),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final w in plan.warnings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '· $w',
                    style: TextStyle(
                      fontSize: 13,
                      color: fc.danger,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
      const SizedBox(height: 10),
      for (int i = 0; i < plan.rows.length; i++)
        if (!plan.rows[i].isStraight) _bendCard(plan.rows[i], m),
      _note(
        '마킹은 관 끝에서 잰 자리이며, 관이 휘기 시작하는 곳입니다. '
        '${m.id == MachineId.msBtb ? 'MS-BTB는 이 마킹을 벤드 슈의 기준선(reference mark)에 맞춥니다. ' : ''}'
        '장비마다 기준선과 실제로 휘기 시작하는 자리가 몇 mm 다를 수 있어, 새 금형은 시험 굽힘으로 한 번 확인하십시오.',
        key: const Key('eb_note_mark'),
      ),
      _note(
        '넣을 각도 = 설계각 + 스프링백. 스프링백은 90°에서 잰 값을 각도에 비례해 어림한 값입니다. '
        '작은 각은 덜, 큰 각은 더 튀므로 중요한 벤드는 그 각도로 한 번 꺾어 보십시오(Swagelok MS-13-145).',
      ),
    ];
  }

  Widget _bendCard(ElectricBendRow r, ElectricMachine m) {
    final st = TextStyle(fontSize: 14, color: fc.text, height: 1.45);
    return Container(
      key: Key('eb_bend_${r.no}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${r.no}번 벤드 · 설계 ${_f(r.designAngle)}°',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: fc.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '마킹: 관 끝에서 ${_f(r.mark)}mm'
            '${r.no > 1 ? ' (앞 마킹에서 ${_f(r.fromPrev)}mm)' : ''}',
            style: st,
          ),
          Text(
            '넣을 각도: ${_f(r.setAngle)}°'
            '${r.springback > 0 ? ' (스프링백 +${_f(r.springback)}°)' : ''}',
            style: st.copyWith(fontWeight: FontWeight.w800, color: fc.brand),
          ),
          if (r.no > 1) Text('굴림: 앞 벤드에서 ${_f(r.roll, 0)}°', style: st),
          if (m.manualFeed)
            Text(
              '손 이송: 밀기 ${_f(r.straight)}mm · 돌리기 ${_f(r.roll, 0)}° · 각도 ${_f(r.setAngle)}°',
              style: st.copyWith(color: fc.textSub),
            ),
        ],
      ),
    );
  }

  // ─────────────── 창 ───────────────

  Future<void> _openEdit(Tooling? t) async {
    final res = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: fc.surface,
      builder: (_) => FieldViewTheme(child: _EditSheet(tooling: t)),
    );
    if (!mounted || res == null) return;
    setState(() {
      if (res is Tooling) {
        _store.put(res);
        _store.toolingId = res.id;
      } else if (res == 'delete' && t != null) {
        _store.removeCustom(t.id);
      }
    });
    _saveNow();
  }

  Future<void> _openTrial(Tooling t) async {
    final res = await showModalBottomSheet<Tooling>(
      context: context,
      isScrollControlled: true,
      backgroundColor: fc.surface,
      builder: (_) => FieldViewTheme(child: _TrialSheet(tooling: t)),
    );
    if (!mounted || res == null) return;
    setState(() => _store.put(res));
    _saveNow();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${res.label}에 저장했습니다: 게인 ${_f(res.gain90)}mm, 스프링백 ${_f(res.springback90)}°',
          ),
        ),
      );
  }
}

/// 금형 값 고치기·더하기 창. [tooling]이 null이면 새 금형.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.tooling});
  final Tooling? tooling;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> with CalcFormParts<_EditSheet> {
  late final Tooling? t = widget.tooling;
  late final _label = TextEditingController(text: t?.label ?? '');
  late final _od = TextEditingController(text: t == null ? '' : _f(t!.odMm, 3));
  late final _r = TextEditingController(text: t == null ? '' : _f(t!.radius));
  late final _gain = TextEditingController(
    text: t == null || t!.gain90 <= 0 ? '' : _f(t!.gain90, 2),
  );
  late final _sb = TextEditingController(
    text: t == null || t!.springback90 <= 0 ? '' : _f(t!.springback90, 2),
  );
  late final _clamp = TextEditingController(
    text: t == null || t!.clampLen <= 0 ? '' : _f(t!.clampLen),
  );
  late final _last = TextEditingController(
    text: t == null || t!.lastLegMin <= 0 ? '' : _f(t!.lastLegMin),
  );
  String? _err;

  @override
  void dispose() {
    for (final c in [_label, _od, _r, _gain, _sb, _clamp, _last]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _n(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', ''));

  void _save() {
    final builtIn = t?.builtIn ?? false;
    final od = _n(_od), r = _n(_r);
    if (!builtIn &&
        (_label.text.trim().isEmpty ||
            od == null ||
            od <= 0 ||
            r == null ||
            r <= 0)) {
      setState(() => _err = '이름, 관 외경, 반경을 넣으십시오.');
      return;
    }
    final base =
        t ??
        Tooling(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          label: _label.text.trim(),
          odMm: od!,
          radius: r!,
        );
    final gain = _n(_gain) ?? 0, sb = _n(_sb) ?? 0;
    Navigator.pop(
      context,
      base.copyWith(
        label: builtIn ? null : _label.text.trim(),
        odMm: builtIn ? null : od,
        radius: builtIn ? null : r,
        radiusSource: builtIn ? null : '금형 각인(직접 넣음)',
        gain90: gain < 0 ? 0 : gain,
        gainSource: gain != (t?.gain90 ?? 0) ? '직접 넣음 ${_today()}' : null,
        springback90: sb < 0 ? 0 : sb,
        springbackSource: sb != (t?.springback90 ?? 0)
            ? '직접 넣음 ${_today()}'
            : null,
        clampLen: (_n(_clamp) ?? 0) < 0 ? 0 : (_n(_clamp) ?? 0),
        lastLegMin: (_n(_last) ?? 0) < 0 ? 0 : (_n(_last) ?? 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final builtIn = t?.builtIn ?? false;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t == null ? '금형 더하기' : '${t!.label} 값 고치기',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: fc.text,
                ),
              ),
              const SizedBox(height: 10),
              if (!builtIn) ...[
                calcBox(
                  child: TextField(
                    key: const Key('eb_e_label'),
                    controller: _label,
                    decoration: const InputDecoration(
                      labelText: '이름 (예: 1/2" · R35)',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                calcField(
                  'eb_e_od',
                  '관 외경 (mm)',
                  _od,
                  '1/2"는 12.7, 3/8"는 9.525, 1/4"는 6.35입니다.',
                ),
                calcField(
                  'eb_e_r',
                  '금형 반경 R (mm)',
                  _r,
                  '벤드 다이(금형)에 새겨진 굽힘 반경(관 중심선 반경)입니다.',
                ),
              ] else
                Text(
                  '반경 R${_f(t!.radius)}mm는 ${t!.radiusSource} 값이라 고치지 않습니다.',
                  style: TextStyle(color: fc.textSub, fontSize: 13),
                ),
              calcField(
                'eb_e_gain',
                '게인 90° (mm, 선택)',
                _gain,
                '90°로 한 번 꺾어 잰 게인입니다(두 다리 합 − 자른 길이). 모르면 비우고 "시험 굽힘으로 맞추기"를 쓰십시오.',
              ),
              calcField(
                'eb_e_sb',
                '스프링백 90° (°, 선택)',
                _sb,
                '90°를 넣고 꺾었을 때 덜 꺾인 각도입니다. 예: 90을 넣어 86이 나오면 4.',
              ),
              calcField(
                'eb_e_clamp',
                '클램프 물림 길이 (mm, 선택)',
                _clamp,
                '클램프가 관을 무는 곧은 길이입니다. 넣으면 벤드 사이 곧은 부분이 이보다 짧을 때 알립니다.',
              ),
              calcField(
                'eb_e_last',
                '마지막 다리 최소 (mm, 선택)',
                _last,
                '마지막 벤드 뒤 곧은 길이가 이보다 짧으면 롤러가 관에서 빠져 각이 안 나옵니다. 장비 매뉴얼 값을 넣으십시오.',
              ),
              if (_err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_err!, style: TextStyle(color: fc.danger)),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (t != null && !builtIn)
                    TextButton(
                      key: const Key('eb_e_delete'),
                      onPressed: () => Navigator.pop(context, 'delete'),
                      child: Text(
                        '이 금형 지우기',
                        style: TextStyle(color: fc.danger),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    key: const Key('eb_e_save'),
                    onPressed: _save,
                    child: const Text('저장'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 시험 굽힘 창: 한 번 꺾어 잰 값으로 게인·스프링백.
class _TrialSheet extends StatefulWidget {
  const _TrialSheet({required this.tooling});
  final Tooling tooling;

  @override
  State<_TrialSheet> createState() => _TrialSheetState();
}

class _TrialSheetState extends State<_TrialSheet>
    with CalcFormParts<_TrialSheet> {
  final _cut = TextEditingController();
  final _a = TextEditingController();
  final _b = TextEditingController();
  final _set = TextEditingController(text: '90');
  final _got = TextEditingController();

  @override
  void dispose() {
    for (final c in [_cut, _a, _b, _set, _got]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _n(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', ''));

  ({double? gain, double? sb}) get _calc {
    final cut = _n(_cut), a = _n(_a), b = _n(_b);
    final set = _n(_set), got = _n(_got);
    final angle = got ?? set;
    double? gain;
    if (cut != null && a != null && b != null && angle != null) {
      final g = gainFromMeasured(
        legA: a,
        legB: b,
        cutLength: cut,
        angleDeg: angle,
      );
      gain = g > 0 ? g : null;
    }
    double? sb;
    if (set != null && got != null) {
      sb = springback90FromTrial(set: set, got: got);
    }
    return (gain: gain, sb: sb);
  }

  @override
  Widget build(BuildContext context) {
    final c = _calc;
    final t = widget.tooling;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${t.label} 시험 굽힘',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: fc.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '곧은 관을 자르고 가운데쯤에서 한 번 꺾습니다. 두 다리를 관 끝에서 꼭짓점(두 다리 중심선이 만나는 점)까지 재어 넣으십시오. '
                '90°가 가장 정확합니다.',
                style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.4),
              ),
              const SizedBox(height: 10),
              calcField('eb_t_cut', '자른 길이 (mm)', _cut, '꺾기 전에 자른 관 길이입니다.'),
              calcField(
                'eb_t_a',
                '다리 A (mm)',
                _a,
                '한쪽 관 끝에서 꼭짓점까지. 바깥면을 재면 관 반지름만큼 더 나오니 중심선 기준으로 넣으십시오.',
              ),
              calcField('eb_t_b', '다리 B (mm)', _b, '다른 쪽 관 끝에서 꼭짓점까지.'),
              calcField('eb_t_set', '장비에 넣은 각도 (°)', _set, '장비에 넣고 꺾은 각도입니다.'),
              calcField(
                'eb_t_got',
                '나온 각도 (°)',
                _got,
                '각도기로 잰 실제 각도입니다. 넣은 각보다 작으면 그 차이가 스프링백입니다.',
              ),
              const SizedBox(height: 4),
              calcResult(
                key: const Key('eb_t_result'),
                big: c.gain == null ? '—' : '${_f(c.gain!, 2)} mm',
                caption: '게인 (90° 기준으로 환산)',
                lines: [
                  if (c.sb != null)
                    '스프링백 ${_f(c.sb!, 2)}° (90° 기준으로 환산)'
                  else
                    '넣은 각도와 나온 각도를 넣으면 스프링백이 나옵니다.',
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const Key('eb_t_save'),
                  onPressed: c.gain == null && c.sb == null
                      ? null
                      : () {
                          final src = '시험 굽힘 ${_today()}';
                          Navigator.pop(
                            context,
                            t.copyWith(
                              gain90: c.gain,
                              gainSource: c.gain == null ? null : src,
                              springback90: c.sb,
                              springbackSource: c.sb == null ? null : src,
                            ),
                          );
                        },
                  child: const Text('이 금형에 저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
