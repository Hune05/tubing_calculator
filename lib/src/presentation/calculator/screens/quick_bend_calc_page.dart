// 벤딩 간단 계산(10-07): 예전 "벤딩 리모컨" 자리. 리모컨은 받는 화면이 홈 개편 때 끊겨
// 늘 "태블릿이 받지 않았습니다"로 끝나서, 사용자 지시로 오프셋·롤링 오프셋·킥 값을 바로 셈하는
// 화면으로 바꿨다. 식은 앱에 이미 있는 것을 그대로 쓴다(현장 자료 오프셋 배수, 전선관 킥,
// 롤링 오프셋 시트와 같은 식). 꺾이는 점 사이 기하 값만 보이고, 벤더 마킹(게인·테이크업)은
// 튜브·전선관 계산기가 셈한다.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/common_widgets/recent_calc_history.dart';
import '../../../core/theme/field_view.dart';
import '../../common/calc_form_parts.dart';
import '../../common/number_text.dart';
import '../../conduit/conduit_special_calc.dart';
import '../../reference/page/reference_widgets.dart'
    show refOffsetHypot, refOffsetRun, refOffsetShrink;
import '../../unit_converter/unit_defs.dart' show formatNumber;

/// 자주 쓰는 꺾는 각도(칩).
const List<double> kQuickBendAngles = [22.5, 30, 45, 60];

/// 오프셋 한 번의 기하(높이 H, 각도 θ). 0 < θ < 90, H > 0이 아니면 null.
({double travel, double run, double shrink, double multiplier})? quickOffset(
  double height,
  double angle,
) {
  if (height <= 0 || angle <= 0 || angle >= 90) return null;
  return (
    travel: height * refOffsetHypot(angle),
    run: height * refOffsetRun(angle),
    shrink: height * refOffsetShrink(angle),
    multiplier: refOffsetHypot(angle),
  );
}

/// 롤링 오프셋: 세로 단차(rise)와 옆 단차(roll)로 실제 단차 = √(rise² + roll²),
/// 굴림 각도 = rise 쪽에서 roll 쪽으로 돌린 각(롤링 오프셋 시트와 같은 식).
({double trueOffset, double rollAngle})? quickRolling(double rise, double roll) {
  if (rise < 0 || roll < 0 || (rise == 0 && roll == 0)) return null;
  var a = math.atan2(roll, rise) * 180 / math.pi;
  if (a < 0) a += 360;
  return (trueOffset: math.sqrt(rise * rise + roll * roll), rollAngle: a);
}

class QuickBendCalcPage extends StatefulWidget {
  const QuickBendCalcPage({super.key});

  @override
  State<QuickBendCalcPage> createState() => _QuickBendCalcPageState();
}

class _QuickBendCalcPageState extends State<QuickBendCalcPage>
    with
        SingleTickerProviderStateMixin,
        CalcFormParts<QuickBendCalcPage>,
        RecentCalcHistoryMixin<QuickBendCalcPage> {
  @override
  String? get calcHistoryStorageKey => 'calc_history_quick_bend';

  late final TabController _tabs = TabController(length: 3, vsync: this);

  final _offH = TextEditingController();
  final _offAngle = TextEditingController(text: '45');
  final _rise = TextEditingController();
  final _roll = TextEditingController();
  final _rollAngle = TextEditingController(text: '45');
  final _kickH = TextEditingController();
  final _kickAngle = TextEditingController(text: '30');

  Map<String, TextEditingController> get _fields => {
    'offH': _offH,
    'offA': _offAngle,
    'rise': _rise,
    'roll': _roll,
    'rollA': _rollAngle,
    'kickH': _kickH,
    'kickA': _kickAngle,
  };

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// 기록을 누르면 그때 탭과 입력값으로 되돌린다.
  @override
  String? calcRestoreSnapshot() => jsonEncode({
    'tab': _tabs.index,
    for (final e in _fields.entries) e.key: e.value.text,
  });

  @override
  void calcRestoreApply(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    for (final e in _fields.entries) {
      final v = m[e.key];
      if (v is String) e.value.text = v;
    }
    final tab = m['tab'];
    if (tab is int && tab >= 0 && tab < _tabs.length) _tabs.index = tab;
  }

  double? _n(TextEditingController c) => parseNumberText(c.text);
  String _mm(double v) => '${formatNumber(double.parse(v.toStringAsFixed(1)))} mm';
  String _deg(double v) => '${formatNumber(double.parse(v.toStringAsFixed(1)))}°';

  @override
  Widget build(BuildContext context) => FieldViewTheme(
    child: Builder(
      builder: (context) => Scaffold(
        backgroundColor: fc.background,
        appBar: AppBar(
          key: const Key('quick_bend_header'),
          backgroundColor: fc.surface,
          foregroundColor: fc.text,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            '벤딩 간단 계산',
            style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
          ),
          actions: [calcHistoryButton()],
          bottom: TabBar(
            controller: _tabs,
            labelColor: fc.brand,
            unselectedLabelColor: fc.textSub,
            indicatorColor: fc.brand,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            tabs: const [
              Tab(key: Key('qb_tab_offset'), text: '오프셋'),
              Tab(key: Key('qb_tab_rolling'), text: '롤링 오프셋'),
              Tab(key: Key('qb_tab_kick'), text: '킥'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            controller: _tabs,
            children: [_offsetTab(), _rollingTab(), _kickTab()],
          ),
        ),
      ),
    ),
  );

  Widget _page(List<Widget> children) => GestureDetector(
    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
    behavior: HitTestBehavior.translucent,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        ...children,
        const SizedBox(height: 10),
        Text(
          '꺾이는 점 사이의 기하 값입니다. 벤더 마킹(게인·테이크업)은 튜브·전선관 벤딩 마킹에서 셈합니다.',
          style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.45),
        ),
      ],
    ),
  );

  /// 각도 칸 + 자주 쓰는 각도 칩.
  Widget _angle(String key, TextEditingController c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      calcField('${key}_angle', '꺾는 각도 (°)', c, '한 번 꺾는 각도입니다. 0 초과 90 미만.'),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final a in kQuickBendAngles)
            calcChip(
              '${key}_chip_${formatNumber(a)}',
              '${formatNumber(a)}°',
              _n(c) == a,
              () => setState(() => c.text = formatNumber(a)),
            ),
        ],
      ),
      const SizedBox(height: 10),
    ],
  );

  Widget _empty() =>
      calcResult(big: '—', caption: '위 칸에 값을 넣으십시오', lines: const []);

  Widget _bad() => calcResult(
    big: '입력 확인',
    caption: '높이는 0보다 크고, 각도는 0 초과 90 미만이어야 합니다.',
    lines: const [],
    warn: true,
  );

  Widget _offsetTab() {
    final h = _n(_offH), a = _n(_offAngle);
    Widget result;
    if (h == null || a == null) {
      result = _empty();
    } else {
      final r = quickOffset(h, a);
      if (r == null) {
        result = _bad();
      } else {
        if (_tabs.index == 0) {
          logCalc('오프셋', '높이 ${_mm(h)} · ${_deg(a)} → 빗변 ${_mm(r.travel)}');
        }
        result = calcResult(
          key: const Key('qb_offset_result'),
          big: _mm(r.travel),
          caption: '빗변(Travel) · 두 꺾이는 점 사이',
          lines: [
            '빗변 = 높이 × ${formatNumber(double.parse(r.multiplier.toStringAsFixed(3)))}(1 ÷ sin${_deg(a)}) = ${_mm(r.travel)}',
            '진행 거리(Run) = 높이 ÷ tan${_deg(a)} = ${_mm(r.run)}',
            '수축(Shrink) = 높이 × tan(${_deg(a / 2)}) = ${_mm(r.shrink)} · 관이 그만큼 덜 나갑니다',
          ],
        );
      }
    }
    return _page([
      calcField('qb_off_h', '오프셋 높이 (mm)', _offH, '옮겨야 할 단차(중심선 기준)입니다.'),
      _angle('qb_off', _offAngle),
      result,
    ]);
  }

  Widget _rollingTab() {
    final rise = _n(_rise), roll = _n(_roll), a = _n(_rollAngle);
    Widget result;
    if (rise == null || roll == null || a == null) {
      result = _empty();
    } else {
      final t = quickRolling(rise, roll);
      final r = t == null ? null : quickOffset(t.trueOffset, a);
      if (t == null || r == null) {
        result = _bad();
      } else {
        if (_tabs.index == 1) {
          logCalc(
            '롤링 오프셋',
            '세로 ${_mm(rise)} · 옆 ${_mm(roll)} · ${_deg(a)} → 빗변 ${_mm(r.travel)}',
          );
        }
        result = calcResult(
          key: const Key('qb_rolling_result'),
          big: _mm(r.travel),
          caption: '빗변(Travel) · 두 꺾이는 점 사이',
          lines: [
            '실제 단차 = √(세로² + 옆²) = ${_mm(t.trueOffset)}',
            '굴림 각도 = 세로 쪽에서 옆 쪽으로 ${_deg(t.rollAngle)}',
            '빗변 = 실제 단차 ÷ sin${_deg(a)} = ${_mm(r.travel)}',
            '진행 거리(Run) = 실제 단차 ÷ tan${_deg(a)} = ${_mm(r.run)}',
            '수축(Shrink) = 실제 단차 × tan(${_deg(a / 2)}) = ${_mm(r.shrink)}',
          ],
        );
      }
    }
    return _page([
      calcField('qb_roll_rise', '세로 단차 (mm)', _rise, '위아래로 옮기는 거리입니다.'),
      calcField('qb_roll_roll', '옆 단차 (mm)', _roll, '옆으로 옮기는 거리입니다.'),
      _angle('qb_roll', _rollAngle),
      result,
    ]);
  }

  Widget _kickTab() {
    final h = _n(_kickH), a = _n(_kickAngle);
    Widget result;
    if (h == null || a == null) {
      result = _empty();
    } else {
      final k = conduitKick(height: h, angle: a);
      if (k == null) {
        result = _bad();
      } else {
        if (_tabs.index == 2) {
          logCalc('킥', '높이 ${_mm(h)} · ${_deg(a)} → 비스듬한 길이 ${_mm(k.travel)}');
        }
        result = calcResult(
          key: const Key('qb_kick_result'),
          big: _mm(k.travel),
          caption: '비스듬한 관 길이(Travel)',
          lines: [
            '비스듬한 길이 = 높이 ÷ sin${_deg(a)} = ${_mm(k.travel)}',
            '앞으로 가는 거리(Run) = 높이 ÷ tan${_deg(a)} = ${_mm(k.run)}',
            '축소값 = 비스듬한 길이 − 앞으로 가는 거리 = ${_mm(k.shrink)}',
          ],
        );
      }
    }
    return _page([
      calcField('qb_kick_h', '킥 높이 (mm)', _kickH, '한 번 꺾어 올릴 높이입니다.'),
      _angle('qb_kick', _kickAngle),
      result,
    ]);
  }
}
