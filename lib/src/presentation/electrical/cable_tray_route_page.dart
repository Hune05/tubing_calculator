// 케이블 트레이 가공(10-03): 바닥 구조물을 넘어가거나 단을 오르내릴 때
// 트레이를 현장에서 잘라 꺾는 V컷 마킹과 길이. 계산은 cable_tray_route.dart.
// 10-12: 부스바·접지바처럼 위 그림(꺾은 모양 ↔ 마킹) + 아래 탭(종류·치수·꺾기·결과). 카톡 글은 결과 탭.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/theme/field_view.dart';
import '../calculator/widgets/swipe_delete.dart' show calcNavCompact;
import '../common/app_icons.dart';
import '../common/calc_form_parts.dart';
import '../common/preset_menu.dart';
import '../steel_plate/plate_ui.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'cable_tray.dart' show trayNum, kTrayWidths, kTrayElbowRadii;
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
  /// 최근 계산 기록을 폰에 이틀 동안 남기는 칸.
  @override
  String? get calcHistoryStorageKey => 'calc_history_tray_route';

  TrayRouteKind _kind = TrayRouteKind.over;
  double _rail = 100;
  double _width = 300; // 옆으로 꺾을 때 트레이 폭(측판 사이)
  bool _obsLeft = false; // 장애물이 진행 방향 왼쪽
  double _angle = 90;
  int _pieces = 1;
  bool _elbowMode = false; // 기성 엘보로
  double _elbowR = 300;
  double _stock = 3000;
  // 측판 높이·트레이 폭·꺾는 각도·R은 칸 + ▼(10-12). 칸 글이 맞지 않으면 마지막 맞는 값으로 계산하고 칸 아래에 알린다.
  final _railC = TextEditingController(text: '100');
  final _widthC = TextEditingController(text: '300');
  final _angleC = TextEditingController(text: '90');
  final _elbowRC = TextEditingController(text: '300');
  static bool _okLen(double? v) => v != null && v > 0 && v < 10000;
  static bool _okAngle(double? v) => v != null && v > 0 && v <= 90;
  void _readDims() {
    final r = readNum(_railC), w = readNum(_widthC);
    final a = readNum(_angleC), er = readNum(_elbowRC);
    if (_okLen(r)) _rail = r!;
    if (_okLen(w)) _width = w!;
    if (_okAngle(a)) _angle = a!;
    if (_okLen(er)) _elbowR = er!;
  }

  void _syncDimTexts() {
    _railC.text = fmt(_rail);
    _widthC.text = fmt(_width);
    _angleC.text = fmt(_angle);
    _elbowRC.text = fmt(_elbowR);
  }

  /// 칸 아래 알림(맞지 않는 값이면 지금 계산에 쓰는 값).
  Widget? _badLine(String key, bool ok, String msg) => ok
      ? null
      : Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            msg,
            key: Key(key),
            style: TextStyle(fontSize: 13, color: fc.danger, height: 1.35),
          ),
        );

  /// 칸 안 ▼ 자주 쓰는 값(항목 키는 예전 단추 키 그대로).
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
              key: Key('$keyPrefix${x.toInt()}'),
            ),
        ],
      );
      if (v == null || !mounted) return;
      _set(() {
        c.text = v;
        _readDims();
      });
    },
  );

  /// 숫자 칸(철판 가공과 같은 모양). [onEdit]은 칸 글이 바뀔 때 먼저 한다(측판·폭·각도·R 읽기).
  Widget _f(
    String key,
    String? label,
    TextEditingController c, {
    String? unit = 'mm',
    String? hint,
    Widget? trailing,
    VoidCallback? onEdit,
  }) => PlateNumField(
    fieldKey: key,
    label: label,
    controller: c,
    unit: unit,
    hint: hint,
    trailing: trailing,
    onChanged: (_) => _set(() => onEdit?.call()),
  );

  /// 두 칸 줄. 칸이 하나면 오른쪽 반을 비운다.
  Widget _row(List<Widget> cells) =>
      plateRow([...cells, if (cells.length == 1) const SizedBox.shrink()]);

  Widget _widthField() => _f(
    'tr_w',
    '트레이 폭',
    _widthC,
    onEdit: _readDims,
    trailing: _presetMenu(
      'tr_w_',
      _widthC,
      kTrayWidths,
      fmt,
      tooltip: '표준 트레이 폭',
    ),
  );

  Widget _radiusField(String label) => _f(
    'tr_er',
    label,
    _elbowRC,
    onEdit: _readDims,
    trailing: _presetMenu(
      'tr_er_',
      _elbowRC,
      kTrayElbowRadii,
      fmt,
      tooltip: '흔한 반경',
    ),
  );
  final _height = TextEditingController(text: '300');
  final _clear = TextEditingController(text: '50');
  final _length = TextEditingController(text: '400');
  final _side = TextEditingController(text: '50');
  final _toFace = TextEditingController(text: '1000');
  final _tail = TextEditingController(text: '500');
  final _pitch = TextEditingController(text: '150');
  final _minR = TextEditingController();
  final _tangent = TextEditingController(text: '125');
  final _reach = TextEditingController(text: '1000'); // 가지 내기: 가지 끝까지

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
    _tangent,
    _reach,
  ];
  static const _fieldKeys = [
    'h',
    'c',
    'l',
    's',
    'f',
    't',
    'p',
    'r',
    'et',
    'rc',
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
    for (final c in [_railC, _widthC, _angleC, _elbowRC]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── 입력값 남기기 ──

  String _draft() => jsonEncode({
    'k': _kind.name,
    'rail': _rail,
    'w': _width,
    'ol': _obsLeft,
    'a': _angle,
    'n': _pieces,
    'mk': _elbowMode,
    'etv': 2, // 끝 직선 기본값을 125로 바꾼 뒤 저장
    'er': _elbowR,
    'st': _stock,
    for (var i = 0; i < _fields.length; i++) _fieldKeys[i]: _fields[i].text,
  });

  Future<void> _loadDraft() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(CableTrayRoutePage.draftKey);
      if (raw != null && mounted) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        setState(() => _applyMap(m));
      }
    } catch (_) {}
    _draftReady = true;
  }

  // "최근 계산 기록"을 눌러 되돌릴 때 저장 칸과 같은 모양을 쓴다.
  @override
  Map<String, Object?>? historySnapshot() =>
      jsonDecode(_draft()) as Map<String, dynamic>;

  @override
  void applyHistorySnapshot(Map<String, dynamic> m) => _applyMap(m);

  void _applyMap(Map<String, dynamic> m) {
    final k = TrayRouteKind.values.where((x) => x.name == m['k']);
    if (k.isNotEmpty) _kind = k.first;
    final rail = m['rail'], w = m['w'], a = m['a'], n = m['n'], st = m['st'];
    if (rail is num && _okLen(rail.toDouble())) {
      _rail = rail.toDouble();
    }
    if (w is num && _okLen(w.toDouble())) {
      _width = w.toDouble();
    }
    if (m['ol'] is bool) _obsLeft = m['ol'] as bool;
    if (a is num && _okAngle(a.toDouble())) {
      _angle = a.toDouble();
    }
    if (n is int && n >= 1 && n <= 3) _pieces = n;
    if (m['mk'] is bool) _elbowMode = m['mk'] as bool;
    final er = m['er'];
    if (er is num && _okLen(er.toDouble())) {
      _elbowR = er.toDouble();
    }
    _syncDimTexts();
    if (st is num && kTrayStockLengths.contains(st.toDouble())) {
      _stock = st.toDouble();
    }
    for (var i = 0; i < _fields.length; i++) {
      final v = m[_fieldKeys[i]];
      if (v is String) _fields[i].text = v;
    }
    // 처음 판(기본 100)으로 저장된 값은 대양 표에 맞는 125로
    if (m['etv'] == null && _tangent.text.trim() == '100') {
      _tangent.text = '125';
    }
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
    return v == null || v < 0 || !v.isFinite
        ? 0
        : v; // Infinity를 붙여 넣으면 숫자 글에서 꺼졌다(10-07)
  }

  // ── 계산 ──

  bool get _plan => trayRouteIsPlan(_kind);
  bool get _returns => trayRouteReturns(_kind);

  /// 옆으로 꺾을 때 마킹 기준(장애물 쪽) 측판과 반대쪽 측판.
  String get _refRail => _obsLeft ? '왼쪽 측판' : '오른쪽 측판';
  String get _farRail => _obsLeft ? '오른쪽 측판' : '왼쪽 측판';

  /// 마킹을 재는 테두리 이름.
  String get _refEdge => _plan ? _refRail : '측판 아랫변';

  /// 꺾는 방향 말: 위로·아래로, 옆으로는 왼쪽으로·오른쪽으로(장애물 반대쪽이 c.up).
  String _dir(TrayCorner c) => _dirUp(c.up);

  String _dirUp(bool up) {
    if (!_plan) return up ? '위로' : '아래로';
    return up != _obsLeft ? '왼쪽으로' : '오른쪽으로';
  }

  /// V컷 자리와 접는 쪽.
  String _cutText(TrayCorner c, {String sep = '\n'}) {
    final range =
        'V컷 폭 ${trayNum(c.notch)} (${trayNum(c.markFrom)}~${trayNum(c.markTo)})';
    if (_plan) {
      final cut = c.up ? _farRail : _refRail, keep = c.up ? _refRail : _farRail;
      return '$cut $range$sep$keep은 남기고 접습니다';
    }
    return c.up ? '윗변 $range$sep아랫변은 남기고 접습니다' : '아랫변 $range$sep윗변은 남기고 접습니다';
  }

  String _title(TrayCorner c) =>
      '${trayNum(c.mark)} mm · ${_dir(c)} ${fmt(c.turn.abs())}°${_plan ? '' : ' (${c.up ? 'IN' : 'OUT'})'}';

  /// 바닥면(옆으로는 장애물 쪽 측판)이 옮겨 갈 거리: 돌아오는 경우는 장애물 + 여유.
  double get _rise => _returns ? _num(_height) + _num(_clear) : _num(_height);

  TrayRoute? _route() {
    if (_rise <= 0) return null;
    return trayRoute(
      kind: _kind,
      rise: _rise,
      angle: _angle,
      rail: _plan ? _width : _rail,
      obstacle: _returns ? _num(_length) : 0,
      side: _num(_side),
      toFace: _num(_toFace),
      tail: _num(_tail),
      pieces: _pieces,
      pitch: _num(_pitch),
    );
  }

  TrayElbowRoute? _elbowRoute() {
    if (_rise <= 0) return null;
    return trayElbowRoute(
      kind: _kind,
      rise: _rise,
      angle: _angle,
      rail: _plan ? _width : _rail,
      radius: _elbowR,
      tangent: readNum(_tangent) ?? kTrayElbowTangent,
      obstacle: _returns ? _num(_length) : 0,
      side: _num(_side),
      toFace: _num(_toFace),
      tail: _num(_tail),
    );
  }

  /// 기성 엘보 부품 이름과 설명(번호는 0이 아닌 부품만 센다).
  (String, String) _pieceText(TrayElbowRoute e, int i) {
    final p = e.pieces[i];
    if (p.elbow) {
      return (
        '${trayElbowName(_kind, p.up)} ${fmt(_angle)}° · R${fmt(_elbowR)}',
        '${_dirUp(p.up)} 꺾기 · 양 끝 직선 ${trayNum(e.tangent)} 포함',
      );
    }
    final last = i == e.pieces.length - 1;
    final role = i == 0
        ? '시작점에서 첫 엘보까지'
        : last
        ? '마지막 엘보 뒤'
        : (_returns && i == 4)
        ? (_plan ? '장애물 옆 직선' : '장애물 위 직선')
        : '엘보 사이 직선';
    return ('직선 ${trayNum(p.length)} mm', '$role · 직각으로 잘라 이음판으로 연결');
  }

  String _elbowShareText(TrayElbowRoute e) {
    final b = StringBuffer(
      '[트레이 가공] ${trayRouteKindLabel(_kind)} ${fmt(_angle)}° 기성 엘보 R${fmt(_elbowR)}',
    );
    b.write(
      _plan
          ? ' · 트레이 폭 ${trayNum(_width)}mm · 장애물 ${_obsLeft ? '왼쪽' : '오른쪽'}'
          : ' · 측판 높이 ${trayNum(_rail)}mm',
    );
    b.write('\n엘보 끝 직선 ${trayNum(e.tangent)}mm');
    b.write('\n부품 (시작점부터):');
    var n = 0;
    for (var i = 0; i < e.pieces.length; i++) {
      if (!e.pieces[i].elbow && e.pieces[i].length < 1e-6) continue;
      n++;
      b.write('\n $n. ${_pieceText(e, i).$1}');
    }
    b.write('\n직선 합 ${trayNum(e.straightTotal)}mm');
    for (final p in e.problems) {
      b.write('\n※ $p');
    }
    return b.toString();
  }

  Widget _pieceTile(TrayElbowRoute e, int i, int n) {
    final p = e.pieces[i];
    final col = p.elbow
        ? trayCornerColor(
            TrayCorner(x: 0, y: 0, turn: p.turn, notch: 0, mark: 0),
          )
        : fc.textSub;
    final (title, sub) = _pieceText(e, i);
    return _simpleTile(n, col, title, sub);
  }

  bool get _isTee => _kind == TrayRouteKind.tee;

  TrayTee _teeRoute() => trayTee(
    width: _width,
    radius: _elbowR,
    tangent: readNum(_tangent) ?? kTrayElbowTangent,
    at: _num(_toFace),
    reach: _num(_reach),
    tail: _num(_tail),
  );

  String _teeShareText(TrayTee t) {
    final b = StringBuffer(
      '[트레이 가공] 가지 내기 수평 티 W${fmt(_width)} R${fmt(_elbowR)} · 가지 ${_obsLeft ? '왼쪽' : '오른쪽'}',
    );
    b.write(
      '\n티 A ${trayNum(t.a)} · B ${trayNum(t.b)} (끝 직선 ${trayNum(t.tangent)})',
    );
    b.write('\n티 앞 본선 직선 ${trayNum(t.before)}mm');
    b.write('\n티 뒤 본선 직선 ${trayNum(t.tail)}mm');
    b.write('\n가지 직선 ${trayNum(t.branch)}mm');
    for (final p in t.problems) {
      b.write('\n※ $p');
    }
    return b.toString();
  }

  /// 결과 탭 한 줄(번호 동그라미 + 굵은 글 + 설명). 부품·마킹 목록에 쓴다.
  Widget _simpleTile(int n, Color col, String title, String sub) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: col,
          child: Text(
            '$n',
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
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: fc.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
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

  /// 결과 탭 큰 값 + 알림 줄.
  List<Widget> _bigResult(
    String big,
    String caption,
    List<String> lines, {
    bool warn = false,
  }) => [
    KeyedSubtree(
      key: const Key('tr_result'),
      child: PlateBigValue(value: big, caption: caption, warn: warn),
    ),
    if (lines.isNotEmpty) ...[
      PlateLines(lines, color: warn ? fc.danger : null),
    ],
  ];

  /// 가지 내기(수평 티) 결과: 가지 직선·티 치수·부품 목록·작업 순서.
  List<Widget> _teeResult(TrayTee t) {
    final minR = readNum(_minR);
    final radOk = minR == null || minR <= 0 ? null : _elbowR >= minR - 1e-9;
    var n = 0;
    final side = _obsLeft ? '왼쪽' : '오른쪽';
    return [
      PlateSection(
        '가지 직선',
        _bigResult(
          '가지 직선 ${trayNum(t.branch)} mm',
          '수평 티 W${fmt(_width)} R${fmt(_elbowR)} · A ${trayNum(t.a)} · B ${trayNum(t.b)}',
          [
            ...t.problems,
            '티 앞 본선 직선 ${trayNum(t.before)}mm (시작점 → 티 끝면)',
            '티 뒤 본선 직선 ${trayNum(t.tail)}mm',
            '티 끝면 사이 A = W + 2 × (R + 끝 직선) = ${trayNum(t.a)}mm',
            '가지 끝면까지 B = W + R + 끝 직선 = ${trayNum(t.b)}mm (본선 반대쪽 측판에서). 카탈로그 A·B와 다르면 끝 직선 칸을 맞추십시오.',
            '${fmt(_stock / 1000)}m 트레이 ${t.lengthsNeeded(_stock)}개(직선만, 이음 여유 제외)',
            if (radOk != null)
              radOk
                  ? '티 R${fmt(_elbowR)} ≥ 케이블 최소 굽힘 반경 R ${trayNum(minR!)}입니다.'
                  : '티 R${fmt(_elbowR)}이 케이블 최소 굽힘 반경 R ${trayNum(minR!)}보다 작습니다. 더 큰 티를 쓰십시오.',
          ],
          warn: !t.ok || radOk == false,
        ),
        first: true,
      ),
      PlateSection('부품 (시작점부터)', [
        if (t.before > 1e-6)
          _simpleTile(
            ++n,
            fc.textSub,
            '직선 ${trayNum(t.before)} mm',
            '시작점에서 티까지 · 직각으로 잘라 이음판으로 연결',
          ),
        _simpleTile(
          ++n,
          trayCornerColor(
            const TrayCorner(x: 0, y: 0, turn: 1, notch: 0, mark: 0),
          ),
          '수평 티 W${fmt(_width)} · R${fmt(_elbowR)}',
          '가지 $side · 끝 직선 ${trayNum(t.tangent)} 포함',
        ),
        if (t.tail > 1e-6)
          _simpleTile(
            ++n,
            fc.textSub,
            '직선 ${trayNum(t.tail)} mm',
            '티 뒤 본선 · 직각으로 잘라 이음판으로 연결',
          ),
        if (t.branch > 1e-6)
          _simpleTile(
            ++n,
            fc.textSub,
            '직선 ${trayNum(t.branch)} mm',
            '가지 (티 가지 끝면 → 가지 끝) · 직각으로 잘라 이음판으로 연결',
          ),
      ]),
      const SizedBox(height: 12),
      ...elecFold('tr_fold_notes', '작업 순서', [
        KeyedSubtree(
          key: const Key('tr_notes'),
          child: PlateLines([...kTrayElbowNotes, kTrayTeeSupport]),
        ),
      ], subtitle: '기성 티로 할 때'),
    ];
  }

  /// 기성 엘보 결과(계산 결과·부품 목록·작업 순서).
  List<Widget> _elbowResult(TrayElbowRoute e) {
    final plan = _plan, over = _returns;
    final minR = readNum(_minR);
    final radOk = minR == null || minR <= 0 ? null : _elbowR >= minR - 1e-9;
    var n = 0;
    return [
      PlateSection(
        '엘보·직선',
        _bigResult(
          '엘보 ${e.elbows}개 · 직선 ${e.straights.length}개',
          '기성 엘보 R${fmt(_elbowR)} · 직선 합 ${trayNum(e.straightTotal)}mm',
          [
            ...e.problems,
            e.leg < 1e-6
                ? '엘보 사이 직선 없음. 엘보끼리 바로 잇습니다.'
                : '${plan ? '비스듬한' : '경사'} 직선(엘보 사이) ${trayNum(e.leg)}mm',
            if (_angle != 90)
              '한쪽 ${plan ? '진행 방향' : '수평'} 길이 ${trayNum(e.footprint)}mm',
            if (over)
              '${plan ? '장애물 옆' : '장애물 위'} 직선 ${trayNum(e.top)}mm (장애물 ${trayNum(_num(_length))} + 앞뒤 여유)',
            '첫 엘보: 시작점에서 ${trayNum(e.lead)}mm',
            '${fmt(_stock / 1000)}m 트레이 ${e.lengthsNeeded(_stock)}개(직선만, 이음 여유 제외)',
            if (radOk != null)
              radOk
                  ? '엘보 R${fmt(_elbowR)} ≥ 케이블 최소 굽힘 반경 R ${trayNum(minR!)}입니다.'
                  : '엘보 R${fmt(_elbowR)}이 케이블 최소 굽힘 반경 R ${trayNum(minR!)}보다 작습니다. 더 큰 엘보를 쓰십시오.',
            if (_angle == 90)
              '90° 엘보 한 변 A = ${_plan ? 'R + 트레이 폭(바깥 레일 R2)' : 'R'} + 끝 직선 = ${trayNum(e.sideA)}mm. 카탈로그 A와 다르면 끝 직선 칸을 맞추십시오.',
          ],
          warn: !e.ok || radOk == false,
        ),
        first: true,
      ),
      PlateSection('부품 (시작점부터)', [
        for (var i = 0; i < e.pieces.length; i++)
          if (e.pieces[i].elbow || e.pieces[i].length >= 1e-6)
            _pieceTile(e, i, ++n),
      ]),
      const SizedBox(height: 12),
      ...elecFold('tr_fold_notes', '작업 순서', [
        KeyedSubtree(
          key: const Key('tr_notes'),
          child: PlateLines([
            ...kTrayElbowNotes,
            plan ? kTrayHorizontalElbowSupport : kTrayVerticalElbowSupport,
          ]),
        ),
      ], subtitle: '기성 엘보로 할 때'),
    ];
  }

  /// 현장 꺾기(V컷) 결과: 자르기 전 길이·알림, 마킹, 작업 순서.
  List<Widget> _routeResult(TrayRoute r) {
    final plan = _plan, over = _returns;
    final minR = readNum(_minR);
    final rad = r.radius;
    final radOk = minR == null || minR <= 0 || r.pieces == 1
        ? null
        : rad >= minR - 1e-9;
    return [
      PlateSection(
        '자르기 전 길이',
        _bigResult(
          '${trayNum(r.material)} mm',
          '자르기 전 트레이 길이 ($_refEdge) · 마킹 ${r.corners.length}곳',
          [
            ...r.problems,
            plan
                ? '비스듬한 곧은 길이 ${trayNum(r.leg)}mm${_angle == 90 ? '' : ' · 한쪽 진행 방향 길이 ${trayNum(r.footprint)}mm'}'
                : '경사 곧은 길이 ${trayNum(r.leg)}mm${_angle == 90 ? '' : ' · 한쪽 수평 길이 ${trayNum(r.footprint)}mm'}',
            if (over)
              '${plan ? '장애물 옆 곧은 길이' : '윗면 길이'} ${trayNum(r.top)}mm (장애물 ${trayNum(_num(_length))} + 앞뒤 여유)',
            '첫 꺾는 곳: 시작점에서 ${trayNum(r.lead)}mm',
            '${fmt(_stock / 1000)}m 트레이 ${r.lengthsNeeded(_stock)}개',
            if (r.pieces > 1)
              '나눠 꺾은 반경 약 R ${trayNum(rad)}mm${radOk == null ? '' : (radOk ? ' · 케이블 최소 굽힘 반경 R ${trayNum(minR!)} 이상입니다' : ' · 케이블 최소 굽힘 반경 R ${trayNum(minR!)}보다 작습니다. 마디 간격을 늘리거나 더 나눠 꺾으십시오')}',
          ],
          warn: !r.ok || radOk == false,
        ),
        first: true,
      ),
      PlateSection('마킹 (시작점에서, ${plan ? _refRail : '아랫변'} 기준)', [
        for (var i = 0; i < r.corners.length; i++) _markTile(r.corners[i], i),
      ]),
      const SizedBox(height: 12),
      ...elecFold('tr_fold_notes', '작업 순서', [
        KeyedSubtree(
          key: const Key('tr_notes'),
          child: PlateLines(
            plan ? kTrayFieldBendPlanNotes : kTrayFieldBendNotes,
          ),
        ),
      ], subtitle: '현장에서 잘라 꺾을 때'),
    ];
  }

  String _cornerLine(TrayCorner c, int i) =>
      '${i + 1}. ${trayNum(c.mark)}mm  ${_dir(c)} ${fmt(c.turn.abs())}°  ${_cutText(c, sep: ', ')}';

  String _shareText(TrayRoute r) {
    final b = StringBuffer(
      '[트레이 가공] ${trayRouteKindLabel(_kind)} ${fmt(_angle)}°',
    );
    if (_pieces > 1) b.write(' (${fmt(_angle / _pieces)}° × $_pieces번)');
    b.write(
      _plan
          ? ' · 트레이 폭 ${trayNum(_width)}mm · 장애물 ${_obsLeft ? '왼쪽' : '오른쪽'}'
          : ' · 측판 높이 ${trayNum(_rail)}mm',
    );
    if (_kind == TrayRouteKind.aside) {
      b.write(
        '\n장애물: 들어온 폭 ${trayNum(_num(_height))} × 길이 ${trayNum(_num(_length))}mm, 옆 여유 ${trayNum(_num(_clear))}, 앞뒤 여유 ${trayNum(_num(_side))}',
      );
    } else if (_kind == TrayRouteKind.shift) {
      b.write(
        '\n옮겨 갈 거리 ${trayNum(_num(_height))}mm, 여유 ${trayNum(_num(_side))}',
      );
    } else if (_kind == TrayRouteKind.over) {
      b.write(
        '\n장애물: 높이 ${trayNum(_num(_height))} × 길이 ${trayNum(_num(_length))}mm, 위 여유 ${trayNum(_num(_clear))}, 앞뒤 여유 ${trayNum(_num(_side))}',
      );
    } else {
      b.write('\n단 높이 ${trayNum(_num(_height))}mm, 여유 ${trayNum(_num(_side))}');
    }
    b.write('\n자르기 전 길이: ${trayNum(r.material)}mm ($_refEdge)');
    b.write('\n마킹 (시작점에서, ${_plan ? _refRail : '아랫변'} 기준):');
    for (var i = 0; i < r.corners.length; i++) {
      b.write('\n ${_cornerLine(r.corners[i], i)}');
    }
    for (final p in r.problems) {
      b.write('\n※ $p');
    }
    return b.toString();
  }

  // ── 화면(10-12: 부스바·접지바처럼 위 그림 + 아래 탭 — 사용자 "접지바랑 트레이 가공도 똑같이") ──

  Widget _markTile(TrayCorner c, int i) =>
      _simpleTile(i + 1, trayCornerColor(c), _title(c), _cutText(c));

  static const _tabs = [
    ('kind', '종류'),
    ('size', '치수'),
    ('bend', '꺾기'),
    ('result', '결과'),
  ];
  int _tab = 0;

  /// 위 그림(현장 꺾기만 고름): shape 꺾은 모양, mark 자르기 전 마킹.
  String _view = 'shape';

  Widget _canvas(TrayRoute? r, TrayElbowRoute? e, TrayTee? tt) {
    final over = _returns, plan = _plan;
    final CustomPainter? painter;
    var key = 'tr_side_view';
    if (tt != null) {
      painter = TrayTeePainter(
        tee: tt,
        flip: _obsLeft,
        text: fc.text,
        sub: fc.textSub,
        line: fc.line,
        bg: fc.background,
      );
    } else if (e != null) {
      painter = TrayRouteSidePainter(
        route: e.shape,
        pieces: e.pieces,
        flip: plan && _obsLeft,
        boxFrom: _num(_toFace),
        boxTo: over ? _num(_toFace) + _num(_length) : null,
        boxHeight: _num(_height),
        text: fc.text,
        sub: fc.textSub,
        line: fc.line,
        bg: fc.background,
      );
    } else if (r != null && _view == 'mark') {
      key = 'tr_mark_view';
      painter = TrayRouteMarkPainter(
        route: r,
        flip: plan && _obsLeft,
        farLabel: plan ? _farRail : '측판 윗변',
        refLabel: plan ? '$_refRail (마킹 기준)' : '아랫변 (가로대 쪽, 마킹 기준)',
        text: fc.text,
        sub: fc.textSub,
        line: fc.line,
        bg: fc.background,
      );
    } else if (r != null) {
      painter = TrayRouteSidePainter(
        route: r,
        flip: plan && _obsLeft,
        boxFrom: _num(_toFace),
        boxTo: over ? _num(_toFace) + _num(_length) : null,
        boxHeight: _num(_height),
        text: fc.text,
        sub: fc.textSub,
        line: fc.line,
        bg: fc.background,
      );
    } else {
      painter = null;
    }
    if (painter == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '높이(치수 탭)를 넣으면 그림이 나옵니다.',
            key: const Key('tr_canvas_empty'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: fc.textSub),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 52, 6, 30),
      child: CustomPaint(
        key: Key(key),
        painter: painter,
        child: const SizedBox.expand(),
      ),
    );
  }

  List<Widget> _canvasTools(TrayRoute? r) => r == null
      ? const []
      : [
          PlateViewSwitch([
            PlateOption(
              'tr_vm_shape',
              '꺾은 모양',
              _view != 'mark',
              () => setState(() => _view = 'shape'),
            ),
            PlateOption(
              'tr_vm_mark',
              '마킹',
              _view == 'mark',
              () => setState(() => _view = 'mark'),
            ),
          ]),
        ];

  String? _canvasHint(TrayRoute? r, TrayElbowRoute? e, TrayTee? tt) {
    final plan = _plan;
    if (tt != null) return '위에서 본 실제 비율 · 번호는 결과 탭 부품 번호, 진한 선은 이음 자리';
    if (e != null) {
      return '${plan ? '위' : '옆'}에서 본 실제 비율 · 파랑 = ${plan ? '장애물 반대쪽' : '위로'}, 주황 = ${plan ? '장애물 쪽' : '아래로'} 꺾는 엘보, 회색 = 직선';
    }
    if (r == null) return null;
    if (_view == 'mark') {
      return plan
          ? '곧은 트레이를 위에서 본 그림 · 시작점에서 $_refRail을 따라 잽니다'
          : '곧은 측판을 옆에서 본 그림 · 시작점에서 아랫변을 따라 잽니다(양쪽 측판 같은 자리)';
    }
    return plan
        ? '위에서 본 실제 비율 · 점선은 곧게 갔을 때 자리, 파랑 = $_farRail V컷, 주황 = $_refRail V컷'
        : '옆에서 본 실제 비율 · 파랑 = 위로(윗변 V컷), 주황 = 아래로(아랫변 V컷)';
  }

  // ① 종류: 작업 종류·만드는 방법·트레이(폭 또는 측판 높이)·장애물(가지) 쪽
  Widget _kindPanel() {
    final wide = _plan || _isTee;
    return PlatePanel(
      title: '종류',
      status:
          '${trayRouteKindLabel(_kind)}${_isTee ? '' : ' · ${_elbowMode ? '기성 엘보' : '현장 꺾기 (V컷)'}'}',
      actions: [
        plateHelpButton(context, 'tr_help_kind', '종류 탭', [
          '넘어가기: 바닥의 배관·기초·턱을 위로 넘어 다시 바닥으로. 올라가기·내려가기: 높이가 다른 바닥으로 한 번 오르내림. 옆으로 비켜가기: 기둥·장비를 옆으로 돌아 다시 원래 줄로. 옆으로 옮겨가기: 옆 줄로 한 번 옮겨 계속. 가지 내기: 본선에 수평 티를 넣어 옆으로 가지를 냄.',
          '현장 꺾기: 곧은 트레이를 V컷으로 따서 접습니다. 기성 엘보: 엘보를 사서 직선만 잘라 잇습니다.',
          '측판 높이: V컷 깊이가 되는 측판 전체 높이입니다. V컷 폭 = 2 × 측판 높이 × tan(꺾는 각 ÷ 2). 수직 엘보 IN은 바닥면 반경이 R + 측판 높이입니다.',
          '트레이 폭: 측판 사이 거리(내측 폭)입니다. 옆으로 꺾을 때는 V컷 폭 = 2 × 트레이 폭 × tan(꺾는 각 ÷ 2). 대양 수평 티는 본선과 가지 폭이 같습니다.',
          '장애물 쪽: 시작점에서 진행 방향을 보고 장애물이 있는 쪽입니다. 그쪽 측판을 기준으로 마킹합니다.',
        ]),
      ],
      children: [
        PlateSection('작업 종류', [
          PlateSegments([
            for (final k in TrayRouteKind.values)
              PlateOption(
                'tr_k_${k.name}',
                trayRouteKindLabel(k),
                _kind == k,
                () => _set(() => _kind = k),
              ),
          ]),
        ], first: true),
        if (!_isTee)
          PlateSection('만드는 방법', [
            PlateSegments([
              PlateOption(
                'tr_mk_field',
                '현장 꺾기 (V컷)',
                !_elbowMode,
                () => _set(() => _elbowMode = false),
              ),
              PlateOption(
                'tr_mk_elbow',
                '기성 엘보',
                _elbowMode,
                () => _set(() => _elbowMode = true),
              ),
            ]),
          ]),
        PlateSection('트레이', [
          if (wide) ...[
            _row([_widthField()]),
            ?_badLine(
              'tr_w_bad',
              _okLen(readNum(_widthC)),
              '0보다 큰 폭을 넣으십시오. 지금 계산은 ${fmt(_width)}mm입니다.',
            ),
          ] else ...[
            _row([
              _f(
                'tr_rail',
                '측판 높이',
                _railC,
                onEdit: _readDims,
                trailing: _presetMenu(
                  'tr_rail_',
                  _railC,
                  kTrayRailHeights,
                  fmt,
                  tooltip: '흔한 측판 높이',
                ),
              ),
            ]),
            ?_badLine(
              'tr_rail_bad',
              _okLen(readNum(_railC)),
              '0보다 큰 높이를 넣으십시오. 지금 계산은 ${fmt(_rail)}mm입니다.',
            ),
          ],
        ]),
        if (wide)
          PlateSection(_isTee ? '가지 쪽 (진행 방향 기준)' : '장애물 쪽 (진행 방향 기준)', [
            PlateSegments([
              PlateOption(
                'tr_ol_l',
                '왼쪽',
                _obsLeft,
                () => _set(() => _obsLeft = true),
              ),
              PlateOption(
                'tr_ol_r',
                '오른쪽',
                !_obsLeft,
                () => _set(() => _obsLeft = false),
              ),
            ]),
          ]),
      ],
    );
  }

  // ② 치수: 장애물(단) 크기·여유, 시작점 거리, 뒤 직선. 가지 내기는 가지 자리.
  Widget _sizePanel() {
    final over = _returns, plan = _plan;
    return PlatePanel(
      title: '치수',
      status: _isTee
          ? '시작점 → 가지 중심 ${trayNum(_num(_toFace))}mm'
          : '${over || plan ? '장애물' : '단'} ${trayNum(_num(_height))}mm · 시작점 → ${trayNum(_num(_toFace))}mm',
      actions: [
        plateHelpButton(context, 'tr_help_size', '치수 탭', [
          '시작점은 마킹 기준이 되는 트레이 끝(이음 자리)입니다.',
          '장애물 높이: 지금 트레이 바닥면에서 장애물 윗면까지. 장애물이 들어온 폭: 장애물 쪽 측판 줄에서 트레이 안쪽으로 들어온 장애물 끝까지. 옮겨 갈 거리: 장애물 쪽 측판이 옆으로 옮겨 갈 거리. 단 높이: 트레이 바닥면이 올라가거나 내려갈 높이.',
          '위(옆) 여유: 장애물과 트레이 사이를 띄울 거리. 앞뒤 여유: 장애물 앞면·뒷면에서 꺾는 곳까지 띄울 거리.',
          '뒤 직선: 마지막 꺾는 곳 뒤로 더 둘 곧은 길이입니다.',
          '가지 내기: 시작점에서 가지 트레이 가운데까지, 본선의 가지 쪽 측판에서 가지를 끝낼 곳까지, 티 뒤로 이어 갈 본선 길이를 넣습니다.',
        ]),
      ],
      children: _isTee
          ? [
              PlateSection('가지', [
                plateRow([
                  _f('tr_face', '시작점 → 가지 중심', _toFace),
                  _f('tr_reach', '가지 끝까지', _reach),
                ]),
                _row([_f('tr_tail', '티 뒤 본선 직선', _tail)]),
              ], first: true),
            ]
          : [
              PlateSection(over || plan ? '장애물' : '단', [
                plateRow([
                  _f('tr_h', switch (_kind) {
                    TrayRouteKind.over => '장애물 높이',
                    TrayRouteKind.aside => '장애물이 들어온 폭',
                    TrayRouteKind.shift => '옮겨 갈 거리',
                    _ => '단 높이',
                  }, _height),
                  if (over)
                    _f('tr_clear', plan ? '옆 여유' : '위 여유', _clear)
                  else
                    _f('tr_side', '여유', _side),
                ]),
                if (over) ...[
                  plateRow([
                    _f('tr_len', '장애물 길이', _length),
                    _f('tr_side', '앞뒤 여유', _side),
                  ]),
                ],
              ], first: true),
              PlateSection('시작점', [
                plateRow([
                  _f(
                    'tr_face',
                    _kind == TrayRouteKind.down
                        ? '시작점 → 단 끝'
                        : (over || plan ? '시작점 → 장애물 앞면' : '시작점 → 단 앞면'),
                    _toFace,
                  ),
                  _f('tr_tail', '뒤 직선', _tail),
                ]),
              ]),
            ],
    );
  }

  Widget _stockSection() => PlateSection('트레이 한 개 길이', [
    PlateSegments([
      for (final s in kTrayStockLengths)
        PlateOption(
          'tr_st_${s.toInt()}',
          '${fmt(s / 1000)}m',
          _stock == s,
          () => _set(() => _stock = s),
        ),
    ]),
  ]);

  Widget _minRField(String what) =>
      _f('tr_minr', '케이블 최소 굽힘 반경', _minR, hint: '비워도 됨 · $what과 비교');

  // ③ 꺾기: 꺾는 각도, 나눠 꺾기 또는 엘보(티) R·끝 직선, 케이블 최소 굽힘 반경, 트레이 길이
  Widget _bendPanel() => PlatePanel(
    title: '꺾기',
    status: _isTee
        ? '수평 티 R${fmt(_elbowR)}'
        : '${fmt(_angle)}°${_elbowMode ? ' · 기성 엘보 R${fmt(_elbowR)}' : (_pieces > 1 ? ' · $_pieces번에 나눠' : ' · 한 번에')}',
    actions: [
      plateHelpButton(context, 'tr_help_bend', '꺾기 탭', [
        '꺾는 각도: 바닥에서 일어서는 각도(옆으로는 가던 방향에서 트는 각도)입니다. 0°보다 크고 90° 이하.',
        '나눠 꺾기: 한 곳에서 다 꺾지 않고 작은 각으로 여러 번 꺾어 모서리를 둥글게 합니다(예: 90° = 45° 2번). 굵은 케이블이 모서리에 눌리지 않게 합니다. 마디 간격은 꺾는 곳 사이 거리입니다.',
        '엘보 반경 R: 꺾임 안쪽 테두리 반경으로 계산합니다(대양 수평 엘보 R1 = 안쪽 레일, B-Line 수직 엘보 치수와 같은 기준). 흔히 300·600·900.',
        '끝 직선: 엘보(티) 양 끝 곧은 부분 길이입니다. 대양 카탈로그 표 치수(A·B)는 125로 맞습니다. B-Line 76(3").',
        '케이블 최소 굽힘 반경: 케이블 트레이 규격 선정의 값을 넣으면 반경과 비교합니다. 비워도 됩니다.',
        '트레이 한 개 길이: 자르기 전 길이로 몇 개 드는지 계산합니다(이음 여유 제외).',
      ]),
    ],
    children: _isTee
        ? [
            PlateSection('티', [
              plateRow([
                _radiusField('티 반경 R'),
                _f('tr_tan', '티 끝 직선', _tangent),
              ]),
              ?_badLine(
                'tr_er_bad',
                _okLen(readNum(_elbowRC)),
                '0보다 큰 R을 넣으십시오. 지금 계산은 R${fmt(_elbowR)}입니다.',
              ),
              _row([_minRField('티 R')]),
            ], first: true),
            _stockSection(),
          ]
        : [
            PlateSection('꺾는 각도', [
              _row([
                _f(
                  'tr_ang',
                  null, // 묶음 제목이 "꺾는 각도"
                  _angleC,
                  unit: '°',
                  onEdit: _readDims,
                  trailing: _presetMenu(
                    'tr_a_',
                    _angleC,
                    kTrayRouteAngles,
                    (a) => '${fmt(a)}°',
                    tooltip: '자주 쓰는 각도',
                  ),
                ),
              ]),
              ?_badLine(
                'tr_a_bad',
                _okAngle(readNum(_angleC)),
                '0°보다 크고 90° 이하인 각도를 넣으십시오. 지금 계산은 ${fmt(_angle)}°입니다.',
              ),
            ], first: true),
            if (_elbowMode)
              PlateSection('기성 엘보', [
                plateRow([
                  _radiusField('엘보 반경 R'),
                  _f('tr_tan', '엘보 끝 직선', _tangent),
                ]),
                ?_badLine(
                  'tr_er_bad',
                  _okLen(readNum(_elbowRC)),
                  '0보다 큰 R을 넣으십시오. 지금 계산은 R${fmt(_elbowR)}입니다.',
                ),
                _row([_minRField('엘보 R')]),
              ])
            else
              PlateSection('나눠 꺾기', [
                PlateSegments([
                  for (final n in const [1, 2, 3])
                    PlateOption(
                      'tr_n_$n',
                      n == 1 ? '한 번에' : '$n번',
                      _pieces == n,
                      () => _set(() => _pieces = n),
                    ),
                ]),
                if (_pieces > 1) ...[
                  plateRow([
                    _f('tr_pitch', '마디 간격', _pitch),
                    _minRField('나눠 꺾은 반경'),
                  ]),
                ],
              ]),
            _stockSection(),
          ],
  );

  // ④ 결과: 길이(엘보·티는 부품)·알림, 마킹(부품) 목록, 작업 순서, 카톡 글, 근거
  Widget _resultPanel(TrayRoute? r, TrayElbowRoute? e, TrayTee? tt) {
    final ready = r != null || e != null || tt != null;
    final warn =
        (r != null && !r.ok) || (e != null && !e.ok) || (tt != null && !tt.ok);
    return PlatePanel(
      title: '결과',
      // 길이·개수는 위 제목 줄과 큰 값에 있으니 여기는 기준만
      status: tt != null
          ? '수평 티 · 가지 ${_obsLeft ? '왼쪽' : '오른쪽'}'
          : e != null
          ? '기성 엘보 R${fmt(_elbowR)} · 부품 ${e.pieces.where((p) => p.elbow || p.length >= 1e-6).length}개'
          : r != null
          ? '마킹 ${r.corners.length}곳 · $_refEdge 기준'
          : '높이를 넣으면 계산합니다.',
      statusColor: warn ? fc.danger : null,
      children: [
        if (tt != null)
          ..._teeResult(tt)
        else if (e != null)
          ..._elbowResult(e)
        else if (r != null)
          ..._routeResult(r)
        else
          PlateSection(
            '자르기 전 길이',
            _bigResult('— mm', '높이를 넣으면 계산합니다', const []),
            first: true,
          ),
        if (ready)
          PlateSection('보내기', [
            plateActions([
              PlateActionButton(
                key: const Key('tr_share'),
                icon: Icons.chat_bubble_outline_rounded,
                label: '카톡 글',
                primary: true,
                onTap: () => widget.share(
                  tt != null
                      ? _teeShareText(tt)
                      : (e != null ? _elbowShareText(e) : _shareText(r!)),
                ),
              ),
            ]),
          ]),
        const SizedBox(height: 8),
        elecBasis('tr_basis', kTrayRouteBasis),
      ],
    );
  }

  Widget? _navBar(int idx) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return null;
    final compact = calcNavCompact(context);
    BottomNavigationBarItem item(String id, String label, int i) {
      final on = i == idx;
      final Widget icon = switch (id) {
        'kind' => AppIcon(AppGlyph.trayRoute, size: 24, filled: on),
        'size' => AppIcon(AppGlyph.navInput, size: 24, filled: on),
        'bend' => AppIcon(AppGlyph.protractor, size: 24, filled: on),
        _ => AppIcon(AppGlyph.navMarking, size: 24, filled: on),
      };
      return BottomNavigationBarItem(
        icon: Padding(
          padding: EdgeInsets.only(bottom: compact ? 0 : 4),
          child: KeyedSubtree(key: Key('tr_tab_$id'), child: icon),
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

  @override
  Widget build(BuildContext context) {
    final tt = _isTee ? _teeRoute() : null;
    final r = _elbowMode || _isTee ? null : _route();
    final e = _elbowMode && !_isTee ? _elbowRoute() : null;
    final warn =
        (r != null && !r.ok) || (e != null && !e.ok) || (tt != null && !tt.ok);
    final summary = tt != null
        ? '가지 내기 티 W${fmt(_width)} R${fmt(_elbowR)} · 가지 직선 ${trayNum(tt.branch)}mm'
        : e != null
        ? '${trayRouteKindLabel(_kind)} ${fmt(_angle)}° 기성 엘보 · 엘보 ${e.elbows}개 · 직선 ${trayNum(e.straightTotal)}mm'
        : r != null
        ? '${trayRouteKindLabel(_kind)} ${fmt(_angle)}° · 마킹 ${r.corners.length}곳 · ${trayNum(r.material)}mm'
        : null;
    final idx = _tab.clamp(0, _tabs.length - 1);
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
                  '케이블 트레이 가공',
                  style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
                ),
                if (summary != null)
                  Text(
                    summary,
                    key: const Key('tr_head'),
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
            actions: [calcHistoryButton()],
          ),
          body: elecPageFrame(
            sumKey: 'tr_sum',
            summary: summary,
            warn: warn,
            showBar: false,
            body: PlateWorkspace(
              canvasShare: 0.38,
              canvas: KeyedSubtree(
                key: const ValueKey('tr_canvas'),
                child: _canvas(r, e, tt),
              ),
              tools: _canvasTools(r),
              hint: _canvasHint(r, e, tt),
              panel: IndexedStack(
                index: idx,
                children: [
                  for (final t in _tabs)
                    KeyedSubtree(
                      key: ValueKey('tr_body_${t.$1}'),
                      child: switch (t.$1) {
                        'kind' => _kindPanel(),
                        'size' => _sizePanel(),
                        'bend' => _bendPanel(),
                        _ => _resultPanel(r, e, tt),
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
