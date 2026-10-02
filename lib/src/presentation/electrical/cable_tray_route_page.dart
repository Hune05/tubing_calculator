// 케이블 트레이 형상 계산기(10-03): 바닥 구조물을 넘어가거나 단을 오르내릴 때
// 트레이를 현장에서 잘라 꺾는 V컷 마킹과 길이. 계산은 cable_tray_route.dart.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'cable_tray.dart' show trayNum;
import 'cable_tray_route.dart';
import 'cable_tray_route_painter.dart';
import 'elec_form_parts.dart';

Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

class CableTrayRoutePage extends StatefulWidget {
  const CableTrayRoutePage({super.key, this.share = _defaultShare});

  /// 결과 글 보내기(시험에서 바꿔 끼운다).
  final Future<void> Function(String text) share;

  static const draftKey = 'cable_tray_route_draft_v1';

  @override
  State<CableTrayRoutePage> createState() => _CableTrayRoutePageState();
}

class _CableTrayRoutePageState extends State<CableTrayRoutePage>
    with
        CalcFormParts<CableTrayRoutePage>,
        RecentCalcHistoryMixin<CableTrayRoutePage>,
        ElecTabParts<CableTrayRoutePage> {
  TrayRouteKind _kind = TrayRouteKind.over;
  double _rail = 100;
  double _angle = 90;
  int _pieces = 1;
  double _stock = 3000;
  final _height = TextEditingController(text: '300');
  final _clear = TextEditingController(text: '50');
  final _length = TextEditingController(text: '400');
  final _side = TextEditingController(text: '50');
  final _toFace = TextEditingController(text: '1000');
  final _tail = TextEditingController(text: '500');
  final _pitch = TextEditingController(text: '150');
  final _minR = TextEditingController();

  Timer? _saveTimer;
  bool _draftReady = false;

  List<TextEditingController> get _fields => [
    _height,
    _clear,
    _length,
    _side,
    _toFace,
    _tail,
    _pitch,
    _minR,
  ];
  static const _fieldKeys = ['h', 'c', 'l', 's', 'f', 't', 'p', 'r'];

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

  // ── 입력값 남기기 ──

  String _draft() => jsonEncode({
    'k': _kind.name,
    'rail': _rail,
    'a': _angle,
    'n': _pieces,
    'st': _stock,
    for (var i = 0; i < _fields.length; i++) _fieldKeys[i]: _fields[i].text,
  });

  Future<void> _loadDraft() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(CableTrayRoutePage.draftKey);
      if (raw != null && mounted) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        setState(() {
          final k = TrayRouteKind.values.where((x) => x.name == m['k']);
          if (k.isNotEmpty) _kind = k.first;
          if (m['rail'] is num &&
              kTrayRailHeights.contains((m['rail'] as num).toDouble()))
            _rail = (m['rail'] as num).toDouble();
          if (m['a'] is num &&
              kTrayRouteAngles.contains((m['a'] as num).toDouble()))
            _angle = (m['a'] as num).toDouble();
          if (m['n'] is int && (m['n'] as int) >= 1 && (m['n'] as int) <= 3)
            _pieces = m['n'] as int;
          if (m['st'] is num &&
              kTrayStockLengths.contains((m['st'] as num).toDouble()))
            _stock = (m['st'] as num).toDouble();
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
        .then((p) => p.setString(CableTrayRoutePage.draftKey, d))
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

  // ── 계산 ──

  /// 바닥면이 올라갈(내려갈) 높이: 넘어가기는 장애물 높이 + 위 여유.
  double get _rise => _kind == TrayRouteKind.over
      ? _num(_height) + _num(_clear)
      : _num(_height);

  TrayRoute? _route() {
    if (_rise <= 0) return null;
    return trayRoute(
      kind: _kind,
      rise: _rise,
      angle: _angle,
      rail: _rail,
      obstacle: _kind == TrayRouteKind.over ? _num(_length) : 0,
      side: _num(_side),
      toFace: _num(_toFace),
      tail: _num(_tail),
      pieces: _pieces,
      pitch: _num(_pitch),
    );
  }

  String _cornerLine(TrayCorner c, int i) {
    final dir = c.up ? '위로' : '아래로';
    final cut = c.up
        ? '윗변 V컷 폭 ${trayNum(c.notch)} (${trayNum(c.markFrom)}~${trayNum(c.markTo)}), 아랫변에서 접음'
        : '아랫변 V컷 폭 ${trayNum(c.notch)} (${trayNum(c.markFrom)}~${trayNum(c.markTo)}), 윗변에서 접음';
    return '${i + 1}. ${trayNum(c.mark)}mm  $dir ${fmt(c.turn.abs())}°  $cut';
  }

  String _shareText(TrayRoute r) {
    final b = StringBuffer(
      '[트레이 형상] ${trayRouteKindLabel(_kind)} ${fmt(_angle)}°',
    );
    if (_pieces > 1) b.write(' (${fmt(_angle / _pieces)}° × $_pieces번)');
    b.write(' · 측판 높이 ${trayNum(_rail)}mm');
    if (_kind == TrayRouteKind.over) {
      b.write(
        '\n장애물: 높이 ${trayNum(_num(_height))} × 길이 ${trayNum(_num(_length))}mm, 위 여유 ${trayNum(_num(_clear))}, 앞뒤 여유 ${trayNum(_num(_side))}',
      );
    } else {
      b.write('\n단 높이 ${trayNum(_num(_height))}mm, 여유 ${trayNum(_num(_side))}');
    }
    b.write('\n자르기 전 길이: ${trayNum(r.material)}mm (측판 아랫변)');
    b.write('\n마킹 (시작점에서, 아랫변 기준):');
    for (var i = 0; i < r.corners.length; i++) {
      b.write('\n ${_cornerLine(r.corners[i], i)}');
    }
    for (final p in r.problems) {
      b.write('\n※ $p');
    }
    return b.toString();
  }

  // ── 화면 ──

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

  Widget _markTile(TrayCorner c, int i) {
    final col = trayCornerColor(c);
    return calcBox(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: col,
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
                    '${trayNum(c.mark)} mm · ${c.up ? '위로' : '아래로'} ${fmt(c.turn.abs())}° (${c.up ? 'IN' : 'OUT'})',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: fc.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.up
                        ? '윗변 V컷 폭 ${trayNum(c.notch)} (${trayNum(c.markFrom)}~${trayNum(c.markTo)})\n아랫변은 남기고 접습니다'
                        : '아랫변 V컷 폭 ${trayNum(c.notch)} (${trayNum(c.markFrom)}~${trayNum(c.markTo)})\n윗변은 남기고 접습니다',
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

  @override
  Widget build(BuildContext context) {
    final r = _route();
    final over = _kind == TrayRouteKind.over;
    String? summary;
    final children = <Widget>[
      elecChipGroup(
        '무엇을',
        '넘어가기: 바닥의 배관·기초·턱을 위로 넘어 다시 바닥으로. 올라가기·내려가기: 높이가 다른 바닥으로 한 번 오르내림.',
        [
          for (final k in TrayRouteKind.values)
            calcChip(
              'tr_k_${k.name}',
              trayRouteKindLabel(k),
              _kind == k,
              () => _set(() => _kind = k),
            ),
        ],
      ),
      elecChipGroup(
        '측판 높이 (mm)',
        'V컷 깊이가 되는 측판 전체 높이입니다. V컷 폭 = 2 × 측판 높이 × tan(꺾는 각 ÷ 2).',
        [
          for (final h in kTrayRailHeights)
            calcChip(
              'tr_rail_${h.toInt()}',
              fmt(h),
              _rail == h,
              () => _set(() => _rail = h),
            ),
        ],
      ),
      elecSectionTitle(over ? '장애물' : '단'),
      elecField(
        'tr_h',
        over ? '장애물 높이 (mm)' : '단 높이 (mm)',
        _height,
        over ? '지금 트레이 바닥면에서 장애물 윗면까지입니다.' : '트레이 바닥면이 올라가거나 내려갈 높이입니다.',
        onEdit: _saveSoon,
      ),
      if (over)
        elecField(
          'tr_clear',
          '위 여유 (mm)',
          _clear,
          '장애물 윗면과 트레이 바닥면 사이를 띄울 거리입니다.',
          onEdit: _saveSoon,
        ),
      if (over)
        elecField(
          'tr_len',
          '장애물 길이 (mm)',
          _length,
          '트레이가 지나가는 방향으로 잰 장애물 길이입니다.',
          onEdit: _saveSoon,
        ),
      elecField(
        'tr_side',
        over ? '앞뒤 여유 (mm)' : '여유 (mm)',
        _side,
        over
            ? '장애물 앞면·뒷면에서 꺾는 곳까지 띄울 거리입니다.'
            : (_kind == TrayRouteKind.up
                  ? '단 앞면에서 띄울 거리입니다.'
                  : '단 끝에서 더 나가서 꺾을 거리입니다.'),
        onEdit: _saveSoon,
      ),
      elecField(
        'tr_face',
        _kind == TrayRouteKind.down
            ? '시작점 → 단 끝 (mm)'
            : (over ? '시작점 → 장애물 앞면 (mm)' : '시작점 → 단 앞면 (mm)'),
        _toFace,
        '마킹을 재기 시작할 트레이 끝(이음 자리)에서 잽니다.',
        onEdit: _saveSoon,
      ),
      elecField(
        'tr_tail',
        '뒤 직선 (mm)',
        _tail,
        '마지막 꺾는 곳 뒤로 더 둘 곧은 길이입니다.',
        onEdit: _saveSoon,
      ),
      elecSectionTitle('꺾기'),
      elecChipGroup('꺾는 각도', '바닥에서 일어서는 각도입니다. 90°는 수직으로 세웁니다.', [
        for (final a in kTrayRouteAngles)
          calcChip(
            'tr_a_${a.toInt()}',
            '${fmt(a)}°',
            _angle == a,
            () => _set(() => _angle = a),
          ),
      ]),
      elecChipGroup(
        '나눠 꺾기',
        '한 곳에서 다 꺾지 않고 작은 각으로 여러 번 꺾어 모서리를 둥글게 합니다(예: 90° = 45° 2번). 굵은 케이블이 모서리에 눌리지 않게 합니다. 중국 제조사 자료는 45° 두 번을 트레이 폭만큼 띄워 꺾습니다(한 곳 자료).',
        [
          for (final n in const [1, 2, 3])
            calcChip(
              'tr_n_$n',
              n == 1 ? '한 번에' : '$n번',
              _pieces == n,
              () => _set(() => _pieces = n),
            ),
        ],
      ),
      if (_pieces > 1)
        elecField(
          'tr_pitch',
          '마디 간격 (mm)',
          _pitch,
          '나눠 꺾을 때 꺾는 곳 사이 거리입니다(바닥면 기준).',
          onEdit: _saveSoon,
        ),
      if (_pieces > 1)
        elecField(
          'tr_minr',
          '케이블 최소 굽힘 반경 (mm)',
          _minR,
          '케이블 트레이 계산기의 "곡률 반경" 값을 넣으면 나눠 꺾은 반경과 견줍니다. 비워도 됩니다.',
          onEdit: _saveSoon,
        ),
      elecChipGroup('트레이 한 개 길이', '자르기 전 길이로 몇 개 드는지 계산합니다(이음 여유 제외).', [
        for (final s in kTrayStockLengths)
          calcChip(
            'tr_st_${s.toInt()}',
            '${fmt(s / 1000)}m',
            _stock == s,
            () => _set(() => _stock = s),
          ),
      ]),
      const SizedBox(height: 8),
    ];

    if (r == null) {
      children.add(
        calcResult(
          key: const Key('tr_result'),
          big: '— mm',
          caption: '높이를 넣으면 계산합니다',
          lines: const [],
        ),
      );
    } else {
      final minR = readNum(_minR);
      final rad = r.radius;
      final radOk = minR == null || minR <= 0 || r.pieces == 1
          ? null
          : rad >= minR - 1e-9;
      summary =
          '${trayRouteKindLabel(_kind)} ${fmt(_angle)}° · 마킹 ${r.corners.length}곳 · ${trayNum(r.material)}mm';
      children.addAll([
        calcResult(
          key: const Key('tr_result'),
          big: '${trayNum(r.material)} mm',
          caption: '자르기 전 트레이 길이 (측판 아랫변) · 마킹 ${r.corners.length}곳',
          warn: !r.ok || radOk == false,
          lines: [
            ...r.problems,
            '경사 곧은 길이 ${trayNum(r.leg)}mm${_angle == 90 ? '' : ' · 한쪽 수평 길이 ${trayNum(r.footprint)}mm'}',
            if (over)
              '윗면 길이 ${trayNum(r.top)}mm (장애물 ${trayNum(_num(_length))} + 앞뒤 여유)',
            '첫 꺾는 곳: 시작점에서 ${trayNum(r.lead)}mm',
            '${fmt(_stock / 1000)}m 트레이 ${r.lengthsNeeded(_stock)}개',
            if (r.pieces > 1)
              '나눠 꺾은 반경 약 R ${trayNum(rad)}mm${radOk == null ? '' : (radOk ? ' · 케이블 최소 굽힘 반경 안입니다' : ' · 케이블 최소 굽힘 반경 R ${trayNum(minR!)}보다 작습니다. 마디 간격을 늘리거나 더 나눠 꺾으십시오')}',
          ],
        ),
        const SizedBox(height: 12),
        calcLabel(
          '옆에서 본 모양',
          '실제 비율입니다. 번호는 아래 마킹 번호와 같고, 청록은 위로 꺾기(윗변 V컷), 주황은 아래로 꺾기(아랫변 V컷)입니다.',
        ),
        const SizedBox(height: 4),
        _drawing(
          const Key('tr_side_view'),
          210,
          TrayRouteSidePainter(
            route: r,
            boxFrom: _num(_toFace),
            boxTo: over ? _num(_toFace) + _num(_length) : null,
            boxHeight: over ? _num(_height) : _num(_height),
            text: fc.text,
            sub: fc.textSub,
            line: fc.line,
            bg: fc.background,
          ),
        ),
        const SizedBox(height: 12),
        calcLabel(
          '자르기 전 마킹',
          '곧은 트레이 측판을 옆에서 본 그림입니다. 거리는 시작점에서 측판 아랫변을 따라 잽니다. 양쪽 측판에 같은 자리로 마킹합니다.',
        ),
        const SizedBox(height: 4),
        _drawing(
          const Key('tr_mark_view'),
          176,
          TrayRouteMarkPainter(
            route: r,
            text: fc.text,
            sub: fc.textSub,
            line: fc.line,
            bg: fc.background,
          ),
        ),
        const SizedBox(height: 12),
        elecSectionTitle('마킹 (시작점에서, 아랫변 기준)'),
        for (var i = 0; i < r.corners.length; i++) _markTile(r.corners[i], i),
        const SizedBox(height: 8),
        calcResult(
          key: const Key('tr_notes'),
          big: '작업 순서',
          caption: '현장에서 잘라 꺾을 때',
          lines: kTrayFieldBendNotes,
        ),
      ]);
    }
    children.addAll([
      const SizedBox(height: 12),
      elecBasis('tr_basis', kTrayRouteBasis),
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
              '케이블 트레이 형상 계산기',
              style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
            ),
            actions: [
              if (r != null)
                IconButton(
                  key: const Key('tr_share'),
                  tooltip: '카톡으로 보내기',
                  icon: Icon(Icons.share_outlined, color: fc.text),
                  onPressed: () => widget.share(_shareText(r)),
                ),
              calcHistoryButton(),
            ],
          ),
          body: elecPage(
            children,
            sumKey: 'tr_sum',
            summary: summary,
            warn: r != null && !r.ok,
          ),
        ),
      ),
    );
  }
}
