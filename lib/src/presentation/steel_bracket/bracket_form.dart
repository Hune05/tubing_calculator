// 형강 브라켓 입력 묶음(10-11 개편): 화면 입력을 남기는 지도(저장한 규격·최근 기록·묶음이 같이 씀)와 그 지도로
// 계산 입력(BracketInput)을 만드는 것. 화면 없이.
//  · 10-10 처음 판의 열쇠(sh·ct·sp·jt·pn·an·pl·pln·a·b·ba·bb·pd·pf·pp·ad·af·ap·ps·pt·pld·ple·n·w·cs)는 뜻 그대로 읽는다.
//    ps(정사각 판 한 변)는 새 판 가로·세로(pw·pll)가 없을 때만 둘 다로 쓴다.
library;

import '../../data/models/steel_shape_db.dart';
import '../common/number_text.dart';
import 'bracket_calc.dart';

/// 모양 단추 순서와 저장 값(0 ㄱ자, 1 삼각, 2 문형, 3 T자, 4 천장 매달기).
const List<(BracketShape, String)> kBracketShapes = [
  (BracketShape.l, 'ㄱ자'),
  (BracketShape.brace, '삼각(가새)'),
  (BracketShape.frame, '문형'),
  (BracketShape.tee, 'T자'),
  (BracketShape.hanger, '천장 매달기'),
];

/// 규격 종류: 이름 → 목록. 0~3은 10-10 저장 값과 같은 차례(바꾸지 말 것).
final List<(String, List<SteelShapeItem>)> kBracketSpecLists = [
  ('앵글', SteelShapeDB.angles),
  ('찬넬', SteelShapeDB.channels),
  ('평철', SteelShapeDB.flatBars),
  ('각파이프', SteelShapeDB.squarePipes),
  ('H형강', SteelShapeDB.hBeams),
  ('스트럿', SteelShapeDB.struts),
  ('립C형강', SteelShapeDB.lipChannels),
  ('부등변앵글', SteelShapeDB.unequalAngles),
];

/// 종류를 바꿀 때 고르는 흔한 규격.
const List<String> kBracketSpecDefaults = [
  '앵글 50x50x5',
  '찬넬 100x50x5',
  '평철 50x6',
  '각파이프 50x50x2.3',
  'H형강 100x100x6x8',
  '스트럿 41x41x2.5',
  '립C형강 100x50x20x2.3',
  '부등변앵글 100x75x7',
];

/// 규격 이름이 속한 종류 차례(모르면 -1).
int bracketSpecCategory(String label) {
  for (var i = 0; i < kBracketSpecLists.length; i++) {
    if (kBracketSpecLists[i].$2.any((s) => s.label == label)) return i;
  }
  final sp = label.indexOf(' ');
  if (sp > 0) {
    final kind = label.substring(0, sp);
    for (var i = 0; i < kBracketSpecLists.length; i++) {
      if (kBracketSpecLists[i].$1 == kind) return i;
    }
  }
  return -1;
}

/// 표면 처리(지시서·카톡 글).
const List<String> kBracketFinishes = ['무도장', '방청 도장', '용융아연도금'];

/// 전산볼트 단추(M 지름).
const List<int> kBracketRods = [8, 10, 12, 16];

/// 글 칸 열쇠와 처음 값.
const Map<String, String> kBracketTextDefaults = {
  'jn': '',
  'dn': '',
  'rv': '0',
  'a': '300',
  'b': '300',
  'ba': '210',
  'bb': '210',
  'la': '400',
  'pd': '13.5',
  'pf': '80',
  'pp': '180',
  'ps2': '',
  'pg': '',
  'ad': '13.5',
  'af': '50',
  'ap': '100',
  'as2': '',
  'ag': '',
  // 비우면 기둥에 맞춘 자동 크기(점검 33)
  'pw': '',
  'pll': '',
  'pt': '9',
  'pld': '13.5',
  'ple': '25',
  'rh': '80',
  'rl': '40',
  'rt': '6',
  'ww': '',
  'wh': '',
  'wt': '9',
  'wd': '13.5',
  'we': '25',
  're': '50',
  'rtp': '25',
  'rbl': '30',
  'wz': '',
  'vb': '',
  'n': '1',
  'w': '',
  'lk': '',
};

/// 글 칸이 아닌 값 열쇠와 처음 값(int·bool·String).
const Map<String, Object> kBracketValueDefaults = {
  'sh': 0,
  'sp': '앵글 50x50x5',
  'as': true,
  'asp': '앵글 50x50x5',
  // 가새: 처음은 평철(기둥 폭에 맞춤, bsp 빈 글자) — 10-11 사용자 "기둥 빼고 가새는 웬만하면 평철"
  'bs': false,
  'bsp': '',
  'po': -1,
  'ao': -1,
  'bo': -1,
  'jt': 0,
  'lw': false,
  'lh': false,
  'pn': 2,
  'p2': false,
  'an': 0,
  'a2': false,
  'pl': true,
  'pln': 4,
  'rb': 0,
  'wp': false,
  'wn': 4,
  'rd': 12,
  'mat': 'SS275',
  'fin': 0,
  'lm': 1,
  'v': 3,
};

/// 저장된 지도를 지금 열쇠로 고친다(10-10 판: cs 직접 적은 규격 → sp, ps 정사각 판 → pw·pll, pl·pln 그대로).
Map<String, dynamic> bracketUpgradeMap(Map<String, dynamic> m) {
  final out = Map<String, dynamic>.of(m);
  final cs = out['cs'];
  if (cs is String && cs.trim().isNotEmpty) {
    out['sp'] = cs.trim();
  }
  out.remove('cs');
  final ps = out['ps'];
  if (ps is String && ps.trim().isNotEmpty && !out.containsKey('pw')) {
    out['pw'] = ps;
    out['pll'] = ps;
  }
  out.remove('ps');
  // 10-10 판은 가로대가 기둥과 같은 규격뿐이었다
  if (!out.containsKey('as') && out['sp'] is String) {
    out['as'] = true;
    out['asp'] = out['sp'];
  }
  // 10-10 판은 놓는 방향 없이 부재 폭 하나('w', 비우면 규격 첫 숫자)로 그렸다 → 그 폭이 되는 방향으로(점검 31)
  final sp = out['sp'];
  if (!out.containsKey('po') && sp is String && sp.trim().isNotEmpty) {
    final p = BracketProfile.parse(sp);
    final wv = out['w'];
    final old =
        (wv is String && wv.trim().isNotEmpty ? parseNumberText(wv) : null) ??
        _firstNumber(sp);
    if (p.known && old != null && old > 0 && p.orientCount > 1) {
      final shape = bracketShapeOf(out);
      final lLike = shape == BracketShape.l || shape == BracketShape.brace;
      int near(BracketRole r) {
        var best = p.defaultOrient(r);
        var gap = (p.view(best, r).depth - old).abs();
        for (var o = 0; o < p.orientCount; o++) {
          final g = (p.view(o, r).depth - old).abs();
          if (g < gap - 1e-9) {
            best = o;
            gap = g;
          }
        }
        return best;
      }

      out['po'] = near(lLike ? BracketRole.wall : BracketRole.none);
      out['ao'] = near(BracketRole.top);
    }
  }
  // 판 2 전(10-11 앞 빌드)의 가새는 기둥과 같은 앵글이 처음 값이었다 → 현장처럼 평철 맞춤으로.
  // 사용자가 직접 고른 가새 규격(bs = false + bsp)은 그대로 둔다(점검 30).
  final ver = out['v'] is int ? out['v'] as int : 0;
  if (ver < 2 && out['bs'] != false) {
    out['bs'] = false;
    out['bsp'] = '';
  }
  // 판 3 전은 판 크기 처음 값이 150이었다 → 비움(자동). 자동은 150보다 작아지지 않아 작은 기둥은 그대로다(점검 33).
  if (ver < 3) {
    for (final k in const ['pw', 'pll', 'ww']) {
      if (out[k] == '150') out[k] = '';
    }
  }
  out['v'] = 3;
  return out;
}

/// 규격 이름의 첫 숫자('찬넬 100x50x5x7.5' → 100). 없으면 null.
double? _firstNumber(String spec) {
  final t = spec.trim();
  final sp = t.indexOf(' ');
  if (sp <= 0) return null;
  final v = double.tryParse(
    t.substring(sp + 1).split(RegExp(r'[xX×*]')).first.trim(),
  );
  return v == null || v <= 0 ? null : v;
}

/// 가새 평철 맞춤: 기둥 그림 폭과 같은 폭의 평철(두께 6 먼저), 없으면 그보다 좁은 것 중 가장 넓은 것.
String bracketAutoBraceSpec(String mainSpec, {int orient = -1}) {
  final p = BracketProfile.parse(mainSpec);
  final d = p.known
      ? p
            .view(
              orient < 0 || orient >= p.orientCount
                  ? p.defaultOrient(BracketRole.wall)
                  : orient,
              BracketRole.wall,
            )
            .depth
      : 50.0;
  (double, double)? dims(SteelShapeItem s) {
    final n = s.label.split(' ').last.split('x');
    final w = double.tryParse(n.first), t = double.tryParse(n.last);
    return w == null || t == null ? null : (w, t);
  }

  String? best;
  (double, double)? bestD;
  for (final s in SteelShapeDB.flatBars) {
    final wt = dims(s);
    if (wt == null || wt.$1 > d + 1e-9) continue;
    final b = bestD;
    if (b == null ||
        wt.$1 > b.$1 + 1e-9 ||
        ((wt.$1 - b.$1).abs() < 1e-9 && (wt.$2 - 6).abs() < (b.$2 - 6).abs())) {
      best = s.label;
      bestD = wt;
    }
  }
  return best ?? '평철 50x6';
}

double _num(Map<String, dynamic> m, String k, [double d = 0]) {
  final v = m[k] ?? kBracketTextDefaults[k];
  final x = v is String ? parseNumberText(v) : (v is num ? v.toDouble() : null);
  return x == null || x < 0 ? d : x;
}

double? _opt(Map<String, dynamic> m, String k) {
  final v = m[k];
  if (v is! String || v.trim().isEmpty) return null;
  final x = parseNumberText(v);
  return x == null || x < 0 ? null : x;
}

int _int(Map<String, dynamic> m, String k) {
  final v = m[k];
  return v is int ? v : kBracketValueDefaults[k] as int;
}

bool _bool(Map<String, dynamic> m, String k) {
  final v = m[k];
  return v is bool ? v : kBracketValueDefaults[k] as bool;
}

String _str(Map<String, dynamic> m, String k) {
  final v = m[k];
  return v is String && v.trim().isNotEmpty
      ? v.trim()
      : kBracketValueDefaults[k] as String;
}

/// 가새 평철 맞춤을 쓰는가(직접 고르지 않음).
bool bracketBraceAuto(Map<String, dynamic> m) {
  final v = m['bsp'];
  return !_bool(m, 'bs') && (v is! String || v.trim().isEmpty);
}

BracketShape bracketShapeOf(Map<String, dynamic> m) =>
    kBracketShapes[_int(m, 'sh').clamp(0, kBracketShapes.length - 1)].$1;

/// 주 부재·가로대·가새 규격.
String bracketMainSpec(Map<String, dynamic> m) => _str(m, 'sp');

/// 천장 매달기는 가로대가 주 부재 하나뿐이라 숨은 "가로대 따로" 값을 쓰지 않는다(점검 21).
String bracketArmSpec(Map<String, dynamic> m) =>
    _bool(m, 'as') || bracketShapeOf(m) == BracketShape.hanger
    ? bracketMainSpec(m)
    : _str(m, 'asp');
String bracketBraceSpec(Map<String, dynamic> m) {
  if (_bool(m, 'bs')) return bracketMainSpec(m);
  final v = m['bsp'];
  if (v is String && v.trim().isNotEmpty) return v.trim();
  return bracketAutoBraceSpec(bracketMainSpec(m), orient: _int(m, 'po'));
}

/// 만들 개수(1~999).
int bracketSetsOf(Map<String, dynamic> m) =>
    _num(m, 'n', 1).round().clamp(1, 999);

/// 지도 → 계산 입력. [stock]·[kerf]는 설정 값.
BracketInput bracketInputFromMap(
  Map<String, dynamic> m, {
  double stock = 6000,
  double kerf = 2,
}) {
  final shape = bracketShapeOf(m);
  final lLike = shape == BracketShape.l || shape == BracketShape.brace;
  final standing = shape == BracketShape.frame || shape == BracketShape.tee;
  final wall = lLike && _bool(m, 'wp');
  HoleRow row(String p, int count, bool two) => HoleRow(
    count: count,
    dia: _num(m, '${p}d'),
    first: _num(m, '${p}f'),
    pitch: _num(m, '${p}p'),
    slot: _opt(m, '${p}s2') ?? 0,
    gauge: _opt(m, '${p}g'),
    two: two,
  );
  final main = bracketMainSpec(m);
  final arm = bracketArmSpec(m);
  final brace = bracketBraceSpec(m);
  return BracketInput(
    shape: shape,
    spec: main,
    armSpec: arm == main ? null : arm,
    braceSpec: brace == main ? null : brace,
    postOrient: _int(m, 'po'),
    armOrient: _int(m, 'ao'),
    braceOrient: _int(m, 'bo'),
    fallbackD: _num(m, 'w'),
    a: _num(m, 'a'),
    b: _num(m, 'b'),
    joint: BracketJoint.values[_int(m, 'jt').clamp(0, 3)],
    braceA: _num(m, 'ba'),
    braceB: _num(m, 'bb'),
    postHoles: lLike && !wall
        ? row('p', _int(m, 'pn'), _bool(m, 'p2'))
        : const HoleRow(),
    armHoles: row('a', _int(m, 'an'), _bool(m, 'a2')),
    lowerAt: shape == BracketShape.frame && _bool(m, 'lw') ? _num(m, 'la') : 0,
    lowerHoles: _bool(m, 'lh'),
    basePlate: standing && _bool(m, 'pl'),
    base: BracketPlateInput(
      w: _num(m, 'pw'),
      l: _num(m, 'pll'),
      t: _num(m, 'pt'),
      holes: _int(m, 'pln'),
      dia: _num(m, 'pld'),
      edge: _num(m, 'ple'),
      ribs: _int(m, 'rb'),
      ribH: _num(m, 'rh'),
      ribL: _num(m, 'rl'),
      ribT: _num(m, 'rt'),
    ),
    wallPlate: wall,
    wall: BracketPlateInput(
      w: _num(m, 'ww'),
      l: _opt(m, 'wh') ?? 0,
      t: _num(m, 'wt'),
      holes: _int(m, 'wn'),
      dia: _num(m, 'wd'),
      edge: _num(m, 'we'),
    ),
    rodSpec: '전산볼트 M${_int(m, 'rd')}',
    rodEdge: _num(m, 're'),
    rodTop: _num(m, 'rtp'),
    rodBelow: _num(m, 'rbl'),
    weld: _opt(m, 'wz') ?? 0,
    vBend: _opt(m, 'vb') ?? 0,
    sets: bracketSetsOf(m),
    stockLength: stock,
    kerf: kerf,
  );
}

/// 치수 글(카톡·요약): "가로대 300 · 기둥 300".
String bracketDimText(Map<String, dynamic> m) {
  String f(String k) => _fmt(_num(m, k));
  return switch (bracketShapeOf(m)) {
    BracketShape.l => '가로대 ${f('a')} · 기둥 ${f('b')}',
    BracketShape.brace =>
      '가로대 ${f('a')} · 기둥 ${f('b')} · 가새 자리 ${f('ba')} / ${f('bb')}',
    BracketShape.frame =>
      '폭 ${f('a')} · 높이 ${f('b')}${_bool(m, 'lw') ? ' · 아래 가로대 ${f('la')}' : ''}',
    BracketShape.tee =>
      _num(m, 'a') > 0 ? '가로대 ${f('a')} · 높이 ${f('b')}' : '기둥만 · 높이 ${f('b')}',
    BracketShape.hanger =>
      '가로대 ${f('a')} · 천장에서 ${f('b')} · 볼트 M${_int(m, 'rd')}',
  };
}

/// 저장 목록·묶음 한 줄: "ㄱ자 · 앵글 50x50x5 · 300 × 300".
String bracketSummaryOf(Map<String, dynamic> m) {
  final sh =
      kBracketShapes[_int(m, 'sh').clamp(0, kBracketShapes.length - 1)].$2;
  return '$sh · ${bracketMainSpec(m)} · ${_fmt(_num(m, 'a'))} × ${_fmt(_num(m, 'b'))}';
}

String _fmt(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}
