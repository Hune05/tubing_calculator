import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'elec_presets.dart';
import 'fitting_spec.dart';
import 'skid_part_painter.dart';
import 'skid_presets.dart';

// 🚀 배치도 계기 모듈의 정면 모양. 제조사 치수 도면(GS·PDS·카탈로그)의 앞 그림을 보고
// 몸통·뚜껑·목·플랜지·육각·포크의 자리와 비율을 옮겼다. 치수를 재는 그림이 아니라
// 알아보기 위한 그림이다(외곽은 모듈 가로×세로 그대로). 비율은 그림 안에서 0~1로 적는다.

/// 계기 모양 종류. ModulePreset·PlacedItem의 shape 칸에 이 이름을 적는다.
class InstrumentShape {
  // ── 모델별 모양(제조사 도면을 따른 것) ──
  /// 로즈마운트 3051C·2051C 코플래너(PDS 00813-0100-4001 Fig.8).
  static const String rmCoplanar = 'rm_coplanar';

  /// 로즈마운트 3051C 재래식 플랜지(Fig.12): 왼쪽 드레인·벤트, 양옆 플랜지판.
  static const String rmTraditional = 'rm_trad';

  /// 로즈마운트 3051T·2051T 인라인(Fig.15): 브래킷 보스 둘, 아래 육각.
  static const String rmInline = 'rm_inline';

  /// 오토롤 APT3100(C3100 p.12): 앞에서 보이는 타원 플랜지 둘(L·H).
  static const String autrolDp = 'autrol_dp';

  /// 오토롤 APT3200(C3200 p.8): 몸통 아래 목·육각.
  static const String autrolPt = 'autrol_pt';

  /// 요꼬가와 EJA 수평 배관(GS p.14 F05E): 위 몸통(Ø78 창), 아래 타원 플랜지 둘.
  static const String ykHorizontal = 'yk_horizontal';

  /// 요꼬가와 EJA 수직 배관(GS p.14 F04E): 왼쪽 캡슐(아래로 접속구), 오른쪽 몸통.
  static const String ykVertical = 'yk_vertical';

  /// 요꼬가와 EJA530E 인라인(GS p.11).
  static const String ykInline = 'yk_inline';

  /// 로즈마운트 2120 알루미늄 통(PDS p.23 B): 옆에서 본 통, 오른쪽 케이블 입구.
  static const String fork2120 = 'fork_2120';

  /// 로즈마운트 2120 나일론 통(PDS p.23 A): 오른쪽 글랜드가 길게 나옴.
  static const String fork2120Nylon = 'fork_2120n';

  /// 로즈마운트 2130 표준(2130***M).
  static const String fork2130 = 'fork_2130';

  /// 로즈마운트 2130 고온 긴 목(2130***E).
  static const String fork2130Long = 'fork_2130e';

  // ── 예전 이름(저장된 배치도에 남아 있다) ──
  static const String dp = 'dp';
  static const String gp = 'gp';
  static const String dpTraditional = 'dp_trad';
  static const String dpSide = 'dp_side';
  static const String inline = 'inline';
  static const String fork = 'fork';

  /// ABS 배선 덕트: 양쪽 벽에 빗살(전선 빼는 홈), 가운데 뚜껑. 원래 세로로 길다.
  static const String duct = 'duct';

  /// 도면 위에 적는 글자 상자(테두리 없이 글씨만). 자재 수량·간섭 확인에서는 뺀다.
  static const String note = 'note';

  /// 비카 MA 방폭 압력 스위치(PV 31.11 p.8): 옆에서 본 청색 통, 왼쪽 케이블 입구.
  static const String exdSwitch = 'exd_switch';

  /// SOR 방수형(NN·RN, CAT216 p.21·22): 네모 상자, 아래 피스톤 목·육각.
  static const String sorPiston = 'sor_piston';

  /// SOR 작은 다이어프램(4·54).
  static const String sorDiaphragm = 'sor_diaphragm';

  /// SOR 저압 넓은 다이어프램(12·52, Ø94.5 원판).
  static const String sorWide = 'sor_wide';

  /// SOR 101 차압(CAT468 미대조, 고압·저압 접속구 둘을 아래로 그림).
  static const String sorDp = 'sor_dp';

  /// SOR 방폭(B3·B6, CAT216 p.28): 둥근 뚜껑, 아래 네모 설정칸.
  static const String sorExp = 'sor_exp';

  // ── 튜브 피팅(하이록 H-200TF·스웨즈락 MS-01-140, 옆에서 본 모습) ──
  static const String fitUnion = 'fit_union';
  static const String fitElbow = 'fit_elbow';
  static const String fitTee = 'fit_tee';
  static const String fitCross = 'fit_cross';
  static const String fitMale = 'fit_male';
  static const String fitMaleElbow = 'fit_male_elbow';
  static const String fitBulkhead = 'fit_bulkhead';

  // ── 매니폴드·게이지 밸브(정면, 손잡이 다 연 상태) ──
  static const String mv2 = 'mv2';
  static const String mv3 = 'mv3';
  static const String mv3Flange = 'mv3_flange';
  static const String mv5 = 'mv5';
  static const String mv5Flange = 'mv5_flange';
  static const String gv1 = 'gv1';
  static const String gv2 = 'gv2';
  static const String swV2 = 'sw_v2';
  static const String swV3 = 'sw_v3';
  static const String swV5 = 'sw_v5';

  static const Set<String> _landscape = {
    mv2,
    mv3,
    mv3Flange,
    mv5,
    mv5Flange,
    swV2,
    swV3,
    swV5,
    gv1,
    gv2,
    dpSide,
    ykVertical,
    exdSwitch,
    fitUnion,
    fitTee,
    fitMale,
    fitMaleElbow,
    fitBulkhead,
  };

  /// 원래 가로가 긴 모양인지(돌려 놓았는지 가리는 데 쓴다).
  static bool isLandscape(String shape) {
    final String base = baseOf(shape);
    // 스키드 형강·전선관은 길이 방향이 가로, 정션박스는 네모라 돌리지 않는다.
    if (SkidShape.isSkid(base)) return base != SkidShape.jb;
    final Size? mm = fittingSpecSize(base);
    if (mm != null) return mm.width > mm.height;
    return _landscape.contains(base);
  }

  /// 돌린 횟수를 모르는 예전 부품: 칸의 가로·세로가 원래 모양과 반대면 90° 한 번 돌린 것.
  static int inferredQuarterTurns(String shape, Size box) {
    if (box.width == box.height) return 0;
    return (box.width > box.height) != isLandscape(shape) ? 1 : 0;
  }

  // ── 브래킷 꼬리표 ──
  /// 모양 이름 뒤에 붙이면 2인치 파이프 브래킷을 같이 그린다('rm_coplanar+br').
  static const String bracketSuffix = '+br';

  static bool hasBracket(String? shape) =>
      shape != null && shape.endsWith(bracketSuffix);

  /// 꼬리표를 뗀 본디 모양 이름. 모양을 비교하는 곳은 이 값을 쓴다.
  static String baseOf(String shape) => hasBracket(shape)
      ? shape.substring(0, shape.length - bracketSuffix.length)
      : shape;

  /// 브래킷을 붙일 수 있는 계기(트랜스미터).
  static const Set<String> bracketable = {
    ykHorizontal,
    ykVertical,
    ykInline,
    autrolDp,
    autrolPt,
    rmCoplanar,
    rmTraditional,
    rmInline,
  };
}

/// 브래킷 칸 안에서 계기가 차지하는 자리(비율). 칸은 계기보다 가로 ≈60·세로 ≈40 크다고 보고
/// 좌우 ≈17%·위아래 ≈9%를 브래킷(파이프·판)에 준다(정확한 비례는 아니다).
const double _kBracketInsetX = 0.17;
const double _kBracketInsetY = 0.09;

/// 돌리기·뒤집기 규칙. 그리기와 접속점 셈이 같은 규칙을 쓴다.
/// - [turns] 시계 방향 90° 횟수(0~3). [natural]은 돌리기 전 그림 크기(홀수면 가로·세로 바뀜).
/// - 뒤집기는 돌린 뒤 화면 기준 좌우([mirrorInNatural]가 false)로 한다.
///   스키드 부품만 SkidPartPainter처럼 길이 방향(돌리기 전 기준)으로 뒤집는다.
class _Orient {
  final Size box;
  final Size natural;
  final int turns;
  final bool mirror;
  final bool mirrorInNatural;

  const _Orient({
    required this.box,
    required this.natural,
    required this.turns,
    required this.mirror,
    required this.mirrorInNatural,
  });

  /// [quarterTurns]가 null이면 예전처럼 칸 비율로 돌렸는지 어림한다.
  /// 스키드 부품은 늘 어림 규칙(긴 쪽이 가로)을 쓴다.
  factory _Orient.of(String base, Size box, int? quarterTurns, bool mirror) {
    final bool skid = SkidShape.isSkid(base);
    int turns;
    if (quarterTurns == null || skid) {
      turns = InstrumentShape.inferredQuarterTurns(base, box);
    } else {
      turns = quarterTurns % 4;
    }
    return _Orient(
      box: box,
      natural: turns.isOdd ? Size(box.height, box.width) : box,
      turns: turns,
      mirror: mirror,
      mirrorInNatural: skid,
    );
  }

  void apply(Canvas c) {
    if (mirror && !mirrorInNatural) {
      c.translate(box.width, 0);
      c.scale(-1, 1);
    }
    if (turns != 0) {
      c.translate(box.width / 2, box.height / 2);
      c.rotate(turns * math.pi / 2);
      c.translate(-natural.width / 2, -natural.height / 2);
    }
    if (mirror && mirrorInNatural) {
      c.translate(natural.width, 0);
      c.scale(-1, 1);
    }
  }

  /// 돌리기 전 그림의 점을 칸(화면) 자리로.
  Offset map(Offset p) {
    Offset q = p;
    if (mirror && mirrorInNatural) q = Offset(natural.width - q.dx, q.dy);
    q -= Offset(natural.width / 2, natural.height / 2);
    for (int i = 0; i < turns; i++) {
      q = Offset(-q.dy, q.dx); // 화면(y 아래) 기준 시계 방향 90°
    }
    q += Offset(box.width / 2, box.height / 2);
    if (mirror && !mirrorInNatural) q = Offset(box.width - q.dx, q.dy);
    return q;
  }
}

/// 튜브·전선관이 붙는 자리(접속점). 부품 칸 안의 픽셀 좌표(왼쪽 위가 0,0).
/// 그리기와 같은 규칙으로 돌리고 뒤집어서 그림 위 자리와 맞는다.
/// - 계기: 공정 접속구 끝(차압은 둘, 요꼬가와 수직 배관형은 왼쪽 캡슐 아래 둘,
///   인라인·PT·포크·SOR·비카는 아래 나사 끝 하나)
/// - 피팅: 너트·나사·관 팔의 끝마다 하나
/// - 밸브: 양 끝(릴리프는 아래 입구 + 옆 출구)
/// - 매니폴드·게이지 밸브: 양옆 격리 밸브 끝, 직결형은 위 플랜지 가운데도
/// - 전기 부품·덕트·메모·스키드·모르는 모양: 없음
List<Offset> shapeConnectionPoints(
  String? shape,
  Size size, {
  int quarterTurns = 0,
  bool mirror = false,
}) {
  if (shape == null || size.width <= 0 || size.height <= 0) return const [];
  if (ElecShape.isElec(shape)) return const [];
  final String base = InstrumentShape.baseOf(shape);
  if (SkidShape.isSkid(base)) return const [];
  final _Orient o = _Orient.of(base, size, quarterTurns, mirror);
  final Size nat = o.natural;
  List<Offset> pts;
  if (InstrumentShape.hasBracket(shape) &&
      InstrumentShape.bracketable.contains(base)) {
    final Offset at = Offset(
      nat.width * _kBracketInsetX,
      nat.height * _kBracketInsetY,
    );
    final Size sub = Size(
      nat.width * (1 - 2 * _kBracketInsetX),
      nat.height * (1 - 2 * _kBracketInsetY),
    );
    pts = [for (final p in _naturalPoints(base, sub)) p + at];
  } else {
    pts = _naturalPoints(base, nat);
  }
  return [for (final p in pts) o.map(p)];
}

/// 돌리기 전 그림([s] 크기) 안의 접속점.
List<Offset> _naturalPoints(String base, Size s) {
  if (isFittingSpec(base)) return _specPoints(base, s);
  final double w = s.width, h = s.height;
  Offset p(double x, double y) => Offset(w * x, h * y);
  switch (base) {
    // 차압(접속구 둘)
    case InstrumentShape.rmCoplanar:
    case InstrumentShape.dp:
    case InstrumentShape.gp:
      return [p(0.3, 1), p(0.7, 1)]; // 코플래너 플랜지 아래 두 구멍(≈54 간격)
    case InstrumentShape.rmTraditional:
    case InstrumentShape.dpTraditional:
      return [p(0.31, 0.94), p(0.85, 0.94)]; // 양옆 플랜지판 아래
    case InstrumentShape.autrolDp:
      return [p(0.17, 0.82), p(0.83, 0.82)]; // 타원 플랜지 가운데 접속구
    case InstrumentShape.ykHorizontal:
      return [p(0.21, 0.74), p(0.79, 0.74)];
    case InstrumentShape.ykVertical:
    case InstrumentShape.dpSide:
      return [p(0.12, 1), p(0.3, 1)]; // 왼쪽 캡슐 아래 접속구 둘
    case InstrumentShape.sorDp:
      return [p(0.35, 1), p(0.65, 1)];
    // 아래 나사 끝 하나
    case InstrumentShape.rmInline:
    case InstrumentShape.inline:
      return [p(0.48, 1)];
    case InstrumentShape.autrolPt:
    case InstrumentShape.ykInline:
    case InstrumentShape.sorPiston:
    case InstrumentShape.sorDiaphragm:
    case InstrumentShape.sorWide:
    case InstrumentShape.sorExp:
      return [p(0.5, 1)];
    case InstrumentShape.exdSwitch:
      return [p(87 / 161, 1)];
    case InstrumentShape.fork2120:
    case InstrumentShape.fork:
    case InstrumentShape.fork2130:
    case InstrumentShape.fork2130Long:
      // 포크가 시작하는 나사 끝(_fork의 forkT와 같은 셈).
      return [p(0.46, 1 - math.min(69, h * 0.32) / h)];
    case InstrumentShape.fork2120Nylon:
      return [p(0.42, 1 - math.min(69, h * 0.32) / h)];
    // 튜브 피팅(옛 모양)
    case InstrumentShape.fitUnion:
    case InstrumentShape.fitMale:
    case InstrumentShape.fitBulkhead:
      return [p(0, 0.5), p(1, 0.5)];
    case InstrumentShape.fitElbow:
      return [p(1, 0.19), p(0.19, 1)];
    case InstrumentShape.fitTee:
      return [p(0, 0.19), p(1, 0.19), p(0.5, 1)];
    case InstrumentShape.fitCross:
      return [p(0, 0.5), p(1, 0.5), p(0.5, 0), p(0.5, 1)];
    case InstrumentShape.fitMaleElbow:
      return [p(0, 0.17), p(0.83, 1)];
    // 매니폴드·게이지 밸브: 양옆 격리 밸브 끝(+ 직결형 위 플랜지)
    case InstrumentShape.mv2:
    case InstrumentShape.gv1:
    case InstrumentShape.gv2:
    case InstrumentShape.swV2:
    case InstrumentShape.swV3:
    case InstrumentShape.swV5:
      return [p(0, 0.5), p(1, 0.5)];
    case InstrumentShape.mv3:
      return [p(0, 1 - 31 / 78), p(1, 1 - 31 / 78)];
    case InstrumentShape.mv5:
      return [p(0, 1 - 32 / 86), p(1, 1 - 32 / 86)];
    case InstrumentShape.mv3Flange:
      return [p(0, 1 - 31 / 97), p(1, 1 - 31 / 97), p(0.5, 0)];
    case InstrumentShape.mv5Flange:
      return [p(0, 1 - 32 / 113), p(1, 1 - 32 / 113), p(0.5, 0)];
    default:
      return const []; // 덕트·메모·모르는 모양
  }
}

/// 조각 목록 피팅·밸브의 접속점. _fitSpec과 같은 배율·가운데 맞춤.
List<Offset> _specPoints(String spec, Size s) {
  final Size? mm = fittingSpecSize(spec);
  if (mm == null || mm.width <= 0 || mm.height <= 0) return const [];
  final double k = math.min(s.width / mm.width, s.height / mm.height);
  final Offset at = Offset(
    (s.width - mm.width * k) / 2,
    (s.height - mm.height * k) / 2,
  );
  final List<Offset> raw;
  if (spec.startsWith('fv:')) {
    final v = parseValve(spec);
    final double l = valveNum(v, 'L'), top = valveNum(v, 'top');
    final double bot = valveNum(v, 'bot', 10);
    if (v['kind'] == 'relief') {
      final double outY = top - valveNum(v, 'out', top * 0.4);
      raw = [Offset(bot, top), Offset(l + bot, outY)];
    } else {
      final String kind = v['kind'] ?? '';
      final double x0 = kind == 'ball' || kind == 'wing'
          ? 0
          : (mm.width - l) / 2;
      raw = [Offset(x0, top), Offset(x0 + l, top)];
    }
  } else if (spec.startsWith('fs:')) {
    raw = [Offset(0, mm.height / 2), Offset(mm.width, mm.height / 2)];
  } else {
    final (body, arms) = parseElbow(spec);
    final Rect bb = elbowBounds(body, arms);
    raw = [
      for (final a in arms)
        switch (a.dir) {
              'l' => Offset(-a.len, 0),
              'd' => Offset(0, a.len),
              'u' => Offset(0, -a.len),
              'x' => Offset(-a.len * math.sqrt1_2, a.len * math.sqrt1_2),
              _ => Offset(a.len, 0),
            } -
            bb.topLeft,
    ];
  }
  return [for (final p in raw) at + p * k];
}

class InstrumentShapePainter extends CustomPainter {
  final String shape;
  final Color stroke;
  final double strokeWidth;

  /// 시계 방향 90° 돌린 횟수(0~3). 칸은 이미 돌린 크기(90°마다 가로·세로 바뀜)라고 보고,
  /// 그림은 돌리기 전 크기로 그린 뒤 칸 가운데를 축으로 돌린다.
  /// null이면 예전 부품: 칸 비율로 돌렸는지 어림한다(InstrumentShape.inferredQuarterTurns).
  final int? quarterTurns;

  /// 돌린 뒤 화면 기준으로 좌우를 뒤집는다(스키드 부품은 길이 방향으로).
  final bool mirror;

  const InstrumentShapePainter({
    required this.shape,
    this.stroke = const Color(0xFF64748B),
    this.strokeWidth = 1.5,
    this.quarterTurns,
    this.mirror = false,
  });

  static const Color _bodyPlain = Color(0xFFF8FAFC);
  static const Color _metal = AppColors.line;
  static const Color _glass = Color(0xFFDDEFF1);
  static const Color _sorBlue = Color(0xFFCFE3F3);
  static const Color _maBlue = Color(0xFFD6E4F5);

  // 제조사별 몸통 색(옅게, 흑백 인쇄해도 선이 보이게). 피팅·밸브·전기 부품은 그대로.
  static const Color _rmBlue = Color(0xFFD9E8F7); // 로즈마운트 파랑
  static const Color _ykSilver = Color(0xFFE7EAEF); // 요꼬가와 은색
  static const Color _autrolGrey = Color(0xFFEAEBED); // 오토롤 회색

  /// 몸통 색. 제조사 모양이면 그 회사 색, 아니면 흰 바탕.
  Color get _body => switch (InstrumentShape.baseOf(shape)) {
    InstrumentShape.rmCoplanar ||
    InstrumentShape.rmTraditional ||
    InstrumentShape.rmInline ||
    InstrumentShape.dp ||
    InstrumentShape.gp ||
    InstrumentShape.dpTraditional ||
    InstrumentShape.inline ||
    InstrumentShape.fork ||
    InstrumentShape.fork2120 ||
    InstrumentShape.fork2120Nylon ||
    InstrumentShape.fork2130 ||
    InstrumentShape.fork2130Long => _rmBlue,
    InstrumentShape.ykHorizontal ||
    InstrumentShape.ykVertical ||
    InstrumentShape.ykInline ||
    InstrumentShape.dpSide => _ykSilver,
    InstrumentShape.autrolDp || InstrumentShape.autrolPt => _autrolGrey,
    // SOR(_sorBlue)·비카(_maBlue)는 그리는 곳에서 이미 제 색을 칠한다.
    _ => _bodyPlain,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    // 전기 부품은 칸 크기 그대로 그린다(돌리지도 뒤집지도 않는다).
    if (ElecShape.isElec(shape)) {
      _elec(_Box(canvas, size), shape);
      return;
    }
    final String base = InstrumentShape.baseOf(shape);
    final _Orient o = _Orient.of(base, size, quarterTurns, mirror);
    canvas.save();
    o.apply(canvas);
    final Size s = o.natural;
    if (InstrumentShape.hasBracket(shape) &&
        InstrumentShape.bracketable.contains(base)) {
      final _Box b = _Box(canvas, s);
      _bracket(b);
      // 계기는 브래킷 칸 안쪽에.
      canvas.save();
      canvas.translate(s.width * _kBracketInsetX, s.height * _kBracketInsetY);
      final Size sub = Size(
        s.width * (1 - 2 * _kBracketInsetX),
        s.height * (1 - 2 * _kBracketInsetY),
      );
      _drawBase(canvas, sub, base);
      canvas.restore();
    } else {
      _drawBase(canvas, s, base);
    }
    canvas.restore();
  }

  /// 돌리기 전 크기 [s]에 본디 모양 [shape]를 그린다.
  void _drawBase(Canvas canvas, Size s, String shape) {
    final _Box b = _Box(canvas, s);
    switch (shape) {
      case InstrumentShape.rmCoplanar:
      case InstrumentShape.dp:
      case InstrumentShape.gp:
        _rmCoplanar(b);
      case InstrumentShape.rmTraditional:
      case InstrumentShape.dpTraditional:
        _rmTraditional(b);
      case InstrumentShape.rmInline:
      case InstrumentShape.inline:
        _rmInline(b);
      case InstrumentShape.autrolDp:
        _autrolDp(b);
      case InstrumentShape.autrolPt:
        _autrolPt(b);
      case InstrumentShape.ykHorizontal:
        _ykHorizontal(b);
      case InstrumentShape.ykVertical:
      case InstrumentShape.dpSide:
        _ykVertical(b);
      case InstrumentShape.ykInline:
        _ykInline(b);
      case InstrumentShape.fork2120:
      case InstrumentShape.fork:
        _fork(b, gland: false, longNeck: false);
      case InstrumentShape.fork2120Nylon:
        _fork(b, gland: true, longNeck: false);
      case InstrumentShape.fork2130:
        _fork(b, gland: false, longNeck: false, sideEntry: true);
      case InstrumentShape.fork2130Long:
        _fork(b, gland: false, longNeck: true, sideEntry: true);
      case InstrumentShape.duct:
        _duct(b);
      case InstrumentShape.exdSwitch:
        _exdSwitch(b);
      case InstrumentShape.sorPiston:
      case InstrumentShape.sorDiaphragm:
      case InstrumentShape.sorWide:
      case InstrumentShape.sorDp:
        _sorBox(b, shape);
      case InstrumentShape.sorExp:
        _sorExp(b);
      case InstrumentShape.fitUnion:
        _fitUnion(b);
      case InstrumentShape.fitElbow:
        _fitElbow(b);
      case InstrumentShape.fitTee:
        _fitTee(b);
      case InstrumentShape.fitCross:
        _fitCross(b);
      case InstrumentShape.fitMale:
        _fitMale(b);
      case InstrumentShape.fitMaleElbow:
        _fitMaleElbow(b);
      case InstrumentShape.fitBulkhead:
        _fitBulkhead(b);
      case InstrumentShape.mv2:
        _mv2(b);
      case InstrumentShape.mv3:
        _mv35(b, five: false);
      case InstrumentShape.mv3Flange:
        _mv35(b, five: false, flange: true);
      case InstrumentShape.mv5:
        _mv35(b, five: true);
      case InstrumentShape.mv5Flange:
        _mv35(b, five: true, flange: true);
      case InstrumentShape.gv1:
        _gv1(b);
      case InstrumentShape.gv2:
        _gv2(b);
      case InstrumentShape.swV2:
        _swV(b, 2);
      case InstrumentShape.swV3:
        _swV(b, 3);
      case InstrumentShape.swV5:
        _swV(b, 5);
      default:
        if (SkidShape.isSkid(shape)) {
          _skid(b, shape);
        } else if (isFittingSpec(shape)) {
          _fitSpec(canvas, s, shape);
        } else {
          _part(canvas, Offset.zero & s, _body, radius: 4);
        }
    }
  }

  /// 2인치 파이프 브래킷: 뒤에 세로 파이프, 계기 아래쪽에 가로 브래킷 판, 판 양 끝 U볼트 너트.
  /// 비례는 ≈(로즈마운트 PDS 브래킷 그림을 보고 어림). 계기는 이 위에 그린다.
  void _bracket(_Box b) {
    final Canvas c = b.c;
    // 세로 파이프(2" OD ≈ 계기 폭 절반쯤): 위·아래로 칸 끝까지.
    const double pipeHalf = 0.17;
    _part(c, b.r(0.5 - pipeHalf, 0, 0.5 + pipeHalf, 1), _metal, radius: 2);
    c.drawLine(
      b.p(0.5 - pipeHalf * 0.55, 0),
      b.p(0.5 - pipeHalf * 0.55, 1),
      _thin,
    );
    c.drawLine(
      b.p(0.5 + pipeHalf * 0.55, 0),
      b.p(0.5 + pipeHalf * 0.55, 1),
      _thin,
    );
    // 브래킷 판(계기 아래쪽 뒤, 칸 폭 전부).
    const double plateT = 0.6, plateB = 0.76;
    _part(c, b.r(0, plateT, 1, plateB), _bodyPlain, radius: 1);
    // 판 양 끝 U볼트 너트(계기 옆으로 보인다).
    for (final x in [0.02, 1 - _kBracketInsetX + 0.02]) {
      _hexV(
        c,
        b.r(x, plateT + 0.03, x + _kBracketInsetX - 0.04, plateB - 0.03),
      );
    }
  }

  Paint get _line => Paint()
    ..color = stroke
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth;

  Paint get _thin => Paint()
    ..color = stroke
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.6, strokeWidth * 0.6);

  void _part(Canvas c, Rect r, Color fill, {double radius = 2}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    c.drawRRect(rr, Paint()..color = fill);
    c.drawRRect(rr, _line);
  }

  void _circle(Canvas c, Offset center, double r, Color fill) {
    c.drawCircle(center, r, Paint()..color = fill);
    c.drawCircle(center, r, _line);
  }

  void _oval(Canvas c, Rect r, Color fill) {
    c.drawOval(r, Paint()..color = fill);
    c.drawOval(r, _line);
  }

  void _poly(Canvas c, List<Offset> pts, Color fill) {
    final p = Path()..addPolygon(pts, true);
    c.drawPath(p, Paint()..color = fill);
    c.drawPath(p, _line);
  }

  /// 둥근 나사 뚜껑: 바깥 원, 안쪽 원, 둘레에 손잡이 홈 8개.
  void _ribCover(Canvas c, Offset center, double r, {bool lcd = false}) {
    _circle(c, center, r, _body);
    for (int i = 0; i < 8; i++) {
      final double a = i * math.pi / 4 + math.pi / 8;
      c.drawLine(
        center + Offset(math.cos(a), math.sin(a)) * r * 0.8,
        center + Offset(math.cos(a), math.sin(a)) * r,
        _thin,
      );
    }
    _circle(c, center, r * 0.78, _glass);
    if (lcd) {
      _part(
        c,
        Rect.fromCenter(center: center, width: r * 0.9, height: r * 0.55),
        _body,
        radius: 1,
      );
    } else {
      _circle(c, center, r * 0.5, _body);
    }
  }

  /// 육각(세로 줄 둘로 면을 나눈다).
  void _hex(Canvas c, Rect hex) {
    _part(c, hex, _metal, radius: 1);
    final double third = hex.width / 3;
    for (final x in [hex.left + third, hex.right - third]) {
      c.drawLine(Offset(x, hex.top), Offset(x, hex.bottom), _thin);
    }
  }

  /// 나사(빗금).
  void _thread(Canvas c, Rect t) {
    _part(c, t, _metal, radius: 0);
    final int n = math.max(2, (t.height / 5).floor());
    for (int i = 1; i < n; i++) {
      final double y = t.top + t.height * i / n;
      c.drawLine(Offset(t.left, y + 1.2), Offset(t.right, y - 1.2), _thin);
    }
  }

  // ───────────────────────── 로즈마운트 3051·2051 ─────────────────────────

  /// 로즈마운트 몸통: 둥근 뚜껑 + 위 양쪽 배관 귀(사다리꼴) + 아래 띠.
  void _rmHousing(_Box b, double l, double t, double r, double bottom) {
    final Canvas c = b.c;
    final double w = (r - l) * b.w;
    // 위 양쪽 귀
    for (final left in [true, false]) {
      final double x0 = left ? l : r - 0.2 * (r - l);
      final double x1 = left ? l + 0.2 * (r - l) : r;
      final double inner = left ? x1 : x0;
      final double outer = left ? x0 : x1;
      _poly(c, [
        b.p(outer, t + 0.02),
        b.p(inner, t),
        b.p(inner, t + (bottom - t) * 0.45),
        b.p(outer, t + (bottom - t) * 0.38),
      ], _metal);
    }
    _part(
      c,
      b.r(
        l + 0.14 * (r - l),
        t + (bottom - t) * 0.04,
        r - 0.14 * (r - l),
        bottom,
      ),
      _body,
      radius: 3,
    );
    final double rad = math.min(w * 0.4, (bottom - t) * b.h * 0.47);
    _ribCover(c, b.p((l + r) / 2, t + (bottom - t) * 0.5), rad);
  }

  /// 전자부 목(네모)과 아래 가운데 접지 나사.
  void _rmModule(_Box b, double l, double t, double r, double bottom) {
    _part(b.c, b.r(l, t, r, bottom), _body, radius: 1);
    _circle(
      b.c,
      b.p((l + r) / 2, bottom - (bottom - t) * 0.18),
      math.min(b.w, b.h) * 0.03,
      _metal,
    );
  }

  void _rmCoplanar(_Box b) {
    _rmHousing(b, 0, 0, 1, 0.45);
    _rmModule(b, 0.19, 0.45, 0.83, 0.63);
    // 센서 몸통(V 홈 둘)과 코플래너 플랜지
    _part(b.c, b.r(0.2, 0.63, 0.82, 0.74), _metal, radius: 1);
    for (final x in [0.33, 0.69]) {
      _poly(b.c, [
        b.p(x - 0.07, 0.63),
        b.p(x + 0.07, 0.63),
        b.p(x, 0.71),
      ], _body);
    }
    _part(b.c, b.r(0.2, 0.74, 0.82, 0.93), _metal, radius: 2);
    _circle(b.c, b.p(0.46, 0.85), math.min(b.w, b.h) * 0.06, _body);
    // 볼트 머리 둘
    _part(b.c, b.r(0.24, 0.93, 0.37, 1), _metal, radius: 1);
    _part(b.c, b.r(0.65, 0.93, 0.78, 1), _metal, radius: 1);
  }

  void _rmTraditional(_Box b) {
    // Fig.12: 왼쪽 드레인·벤트 29, 플랜지 86. 몸통은 플랜지 위 가운데.
    _rmHousing(b, 0.14, 0, 1, 0.41);
    _rmModule(b, 0.3, 0.41, 0.86, 0.58);
    _part(b.c, b.r(0.33, 0.58, 0.83, 0.66), _metal, radius: 1);
    // 가운데 몸통과 양옆 재래식 플랜지판(볼트 머리)
    _part(b.c, b.r(0.36, 0.66, 0.8, 0.88), _metal, radius: 1);
    for (final x in [0.26, 0.8]) {
      _part(b.c, b.r(x, 0.62, x + 0.1, 0.94), _metal, radius: 2);
      _part(b.c, b.r(x + 0.1, 0.66, x + 0.14, 0.72), _body, radius: 1);
      _part(b.c, b.r(x + 0.1, 0.84, x + 0.14, 0.9), _body, radius: 1);
    }
    // 왼쪽 드레인·벤트 밸브
    _part(b.c, b.r(0.1, 0.75, 0.26, 0.81), _metal, radius: 1);
    _part(b.c, b.r(0, 0.74, 0.1, 0.82), _metal, radius: 1);
  }

  void _rmInline(_Box b) {
    _rmHousing(b, 0, 0, 1, 0.45);
    _rmModule(b, 0.19, 0.45, 0.83, 0.64);
    // 브래킷 보스 둘(작은 구멍)
    _part(b.c, b.r(0.3, 0.64, 0.66, 0.79), _metal, radius: 6);
    _circle(b.c, b.p(0.38, 0.715), math.min(b.w, b.h) * 0.035, _body);
    _circle(b.c, b.p(0.58, 0.715), math.min(b.w, b.h) * 0.035, _body);
    _part(b.c, b.r(0.42, 0.79, 0.54, 0.84), _metal, radius: 0);
    _hex(b.c, b.r(0.34, 0.84, 0.62, 1));
  }

  // ───────────────────────── 오토롤 ─────────────────────────

  /// 오토롤 몸통: 네모 몸통 위 작은 귀, 큰 둥근 뚜껑 안 LCD, 아래 띠(접지 보스).
  void _autrolHousing(_Box b, double bottom) {
    final double coverB = bottom * 0.78;
    _part(b.c, b.r(0.02, 0.04 * bottom, 0.98, coverB), _body, radius: 3);
    _part(b.c, b.r(0.08, 0, 0.18, 0.05 * bottom), _metal, radius: 1);
    _part(b.c, b.r(0.82, 0, 0.92, 0.05 * bottom), _metal, radius: 1);
    final double rad = math.min(b.w * 0.46, coverB * b.h * 0.47);
    _ribCover(b.c, b.p(0.5, coverB * 0.52), rad, lcd: true);
    _part(b.c, b.r(0.1, coverB, 0.9, bottom), _body, radius: 1);
    _circle(
      b.c,
      b.p(0.5, bottom - (bottom - coverB) * 0.35),
      math.min(b.w, b.h) * 0.05,
      _metal,
    );
  }

  /// 앞에서 보이는 타원 플랜지(볼트 구멍 위아래, 가운데 접속구).
  void _ovalFlange(_Box b, double l, double t, double r, double bottom) {
    _oval(b.c, b.r(l, t, r, bottom), _metal);
    final double cx = (l + r) / 2;
    final double rr = math.min((r - l) * b.w, (bottom - t) * b.h) * 0.13;
    _circle(b.c, b.p(cx, t + (bottom - t) * 0.2), rr, _body);
    _circle(b.c, b.p(cx, t + (bottom - t) * 0.8), rr, _body);
    _circle(b.c, b.p(cx, (t + bottom) / 2), rr * 1.5, _body);
    _circle(b.c, b.p(cx, (t + bottom) / 2), rr * 0.8, _metal);
  }

  void _autrolDp(_Box b) {
    // C3100 p.12: 몸통 114 / 캡슐 80(합 194).
    _autrolHousing(b, 0.59);
    _part(b.c, b.r(0.4, 0.59, 0.6, 0.66), _metal, radius: 0);
    _part(b.c, b.r(0.1, 0.66, 0.9, 0.98), _metal, radius: 2);
    _ovalFlange(b, 0, 0.64, 0.34, 1);
    _ovalFlange(b, 0.66, 0.64, 1, 1);
  }

  void _autrolPt(_Box b) {
    // C3200 p.8: 몸통 114 / 전체 160.
    _autrolHousing(b, 0.71);
    _part(b.c, b.r(0.33, 0.71, 0.67, 0.86), _metal, radius: 1);
    _hex(b.c, b.r(0.3, 0.86, 0.7, 0.93));
    _thread(b.c, b.r(0.4, 0.93, 0.6, 1));
  }

  // ───────────────────────── 요꼬가와 EJA ─────────────────────────

  /// 요꼬가와 몸통을 정면에서: 네모 몸통 위 Ø78 창 뚜껑, 오른쪽 위 배관 입구.
  void _ykHousingFront(_Box b, double l, double t, double r, double bottom) {
    _part(b.c, b.r(l, t + (bottom - t) * 0.05, r, bottom), _body, radius: 4);
    _part(
      b.c,
      b.r(r - 0.1 * (r - l), t + (bottom - t) * 0.1, r, t + (bottom - t) * 0.3),
      _metal,
      radius: 1,
    );
    final double rad = math.min((r - l) * b.w * 0.42, (bottom - t) * b.h * 0.5);
    final Offset cc = b.p((l + r) / 2, t + (bottom - t) * 0.5);
    _ribCover(b.c, cc, rad, lcd: true);
  }

  void _ykHorizontal(_Box b) {
    // F05E: 위 몸통 약 95폭, 아래 캡슐 + 앞으로 보이는 접속구 둘.
    _ykHousingFront(b, 0.08, 0, 0.92, 0.5);
    _part(b.c, b.r(0.4, 0.5, 0.6, 0.56), _metal, radius: 0);
    _part(b.c, b.r(0.12, 0.56, 0.88, 0.92), _metal, radius: 3);
    _ovalFlange(b, 0.02, 0.56, 0.4, 0.92);
    _ovalFlange(b, 0.6, 0.56, 0.98, 0.92);
    // 아래 배수 플러그
    _part(b.c, b.r(0.2, 0.92, 0.28, 1), _metal, radius: 1);
    _part(b.c, b.r(0.72, 0.92, 0.8, 1), _metal, radius: 1);
  }

  void _ykVertical(_Box b) {
    // F04E(원래 가로): 왼쪽 캡슐(접속구 아래로), 가운데 목, 오른쪽 몸통(Ø78 뚜껑).
    _part(b.c, b.r(0.02, 0.18, 0.4, 0.84), _metal, radius: 3);
    b.c.drawLine(b.p(0.21, 0.18), b.p(0.21, 0.84), _thin);
    for (final x in [0.1, 0.32]) {
      for (final y in [0.26, 0.76]) {
        _circle(b.c, b.p(x, y), math.min(b.w, b.h) * 0.03, _body);
      }
    }
    _part(b.c, b.r(0.08, 0.84, 0.16, 1), _metal, radius: 0);
    _part(b.c, b.r(0.26, 0.84, 0.34, 1), _metal, radius: 0);
    _part(b.c, b.r(0.4, 0.4, 0.5, 0.6), _metal, radius: 0);
    // 옆에서 본 몸통: 앞 뚜껑(창) 쪽이 왼쪽, 단자함 뚜껑이 오른쪽.
    _part(b.c, b.r(0.5, 0.08, 0.98, 0.82), _body, radius: 5);
    _ribCover(
      b.c,
      b.p(0.74, 0.45),
      math.min(b.w * 0.22, b.h * 0.37),
      lcd: true,
    );
  }

  void _ykInline(_Box b) {
    // GS 01C31F01 p.11: 몸통 126 / 전체 159.
    _ykHousingFront(b, 0.02, 0, 0.98, 0.62);
    _part(b.c, b.r(0.36, 0.62, 0.64, 0.72), _metal, radius: 1);
    _part(b.c, b.r(0.26, 0.72, 0.74, 0.78), _metal, radius: 1);
    _hex(b.c, b.r(0.3, 0.78, 0.7, 0.88));
    _thread(b.c, b.r(0.4, 0.88, 0.6, 1));
  }

  // ───────────────────────── 로즈마운트 2120·2130 포크 ─────────────────────────

  /// 옆에서 본 통: 위 톱니 뚜껑, 아래로 좁아지는 몸통, 옆 케이블 입구, 목·육각·나사·포크.
  void _fork(
    _Box b, {
    required bool gland,
    required bool longNeck,
    bool sideEntry = false,
  }) {
    final Canvas c = b.c;
    final double h = b.h;
    // 포크 69mm(도면 1칸 = 1mm), 작게 줄였을 때는 비율로.
    final double forkT = 1 - math.min(69, h * 0.32) / h;
    final double headB = longNeck ? 0.2 : (gland ? 0.5 : 0.48);
    final double bodyR = gland ? 0.78 : 0.86;
    final double bodyL = gland ? 0.06 : 0.06;
    // 뚜껑(톱니)
    final double lidB = headB * 0.28;
    _part(c, b.r(bodyL, 0, bodyR, lidB), _body, radius: 3);
    final int ribs = 9;
    for (int i = 1; i < ribs; i++) {
      final double x = bodyL + (bodyR - bodyL) * i / ribs;
      c.drawLine(b.p(x, lidB * 0.2), b.p(x, lidB * 0.85), _thin);
    }
    _part(
      c,
      b.r(bodyL - 0.02, lidB, bodyR + 0.02, lidB * 1.25),
      _metal,
      radius: 1,
    );
    // 몸통(아래로 좁아짐)
    _poly(c, [
      b.p(bodyL + 0.02, lidB * 1.25),
      b.p(bodyR - 0.02, lidB * 1.25),
      b.p(bodyR - 0.02, headB * 0.8),
      b.p((bodyL + bodyR) / 2 + 0.14, headB),
      b.p((bodyL + bodyR) / 2 - 0.14, headB),
      b.p(bodyL + 0.02, headB * 0.8),
    ], _body);
    final double cx = (bodyL + bodyR) / 2;
    // 케이블 입구
    if (gland) {
      _part(
        c,
        b.r(bodyR - 0.02, headB * 0.5, 0.92, headB * 0.64),
        _metal,
        radius: 1,
      );
      _part(c, b.r(0.92, headB * 0.47, 1, headB * 0.67), _metal, radius: 1);
    } else {
      final Offset e = sideEntry
          ? b.p(bodyR - 0.02, headB * 0.5)
          : b.p(bodyR - 0.02, headB * 0.5);
      final double er = math.min(b.w * 0.12, h * headB * 0.12);
      _circle(c, e, er, _metal);
      _circle(c, e, er * 0.55, _body);
    }
    // 목(고온형은 길다)
    final double hexT = forkT - 0.1;
    if (hexT > headB) {
      _part(c, b.r(cx - 0.1, headB, cx + 0.1, hexT), _metal, radius: 0);
    }
    _hex(c, b.r(cx - 0.17, hexT, cx + 0.17, hexT + 0.045));
    _thread(c, b.r(cx - 0.12, hexT + 0.045, cx + 0.12, forkT));
    // 두 갈래 포크(가늘게)
    for (final dx in [-0.05, 0.05]) {
      _part(
        c,
        b.r(cx + dx - 0.035, forkT, cx + dx + 0.035, 1),
        _metal,
        radius: b.w * 0.035,
      );
    }
  }

  // ───────────────────────── 덕트·스위치 ─────────────────────────

  void _duct(_Box b) {
    final Canvas c = b.c;
    final double w = b.w, h = b.h;
    _part(c, Offset.zero & Size(w, h), _metal, radius: 1);
    // 양쪽 벽 두께와 빗살 간격(실물 홈 간격 20~25mm, 도면 1칸 = 1mm).
    final double wall = math.min(w * 0.2, 10);
    final double pitch = math.max(12, h / 40);
    for (double y = pitch; y < h - pitch / 2; y += pitch) {
      c.drawLine(Offset(0, y), Offset(wall, y), _thin);
      c.drawLine(Offset(w - wall, y), Offset(w, y), _thin);
    }
    _part(c, Rect.fromLTRB(wall, 0, w - wall, h), _body, radius: 0);
  }

  // 비카 MA 정면(PV 31.11 p.8 왼쪽 그림): 가운데 선이 왼쪽에서 87/161 자리.
  void _exdSwitch(_Box b) {
    final double cx = 87 / 161;
    _part(b.c, b.r(0.36, 0, 0.82, 0.1), _maBlue, radius: 2);
    _part(b.c, b.r(0.14, 0.08, 1, 0.2), _maBlue, radius: 2);
    _part(b.c, b.r(0.14, 0.2, 1, 0.78), _maBlue, radius: 3);
    _part(b.c, b.r(0, 0.4, 0.15, 0.64), _metal, radius: 2);
    _circle(b.c, b.p(0.075, 0.52), math.min(b.w, b.h) * 0.05, _body);
    _part(b.c, b.r(0.9, 0.44, 0.97, 0.6), _body);
    final Rect base = b.r(0.12, 0.78, 1, 0.86);
    _part(b.c, base, _metal, radius: 1);
    for (final px in [0.22, 0.4, 0.72, 0.9]) {
      b.c.drawLine(b.p(px, 0.78), b.p(px, 0.86), _thin);
    }
    _hex(b.c, b.r(cx - 0.08, 0.86, cx + 0.08, 0.93));
    _thread(b.c, b.r(cx - 0.04, 0.93, cx + 0.04, 1));
  }

  // SOR NN·RN(CAT216 p.21·22): 앞에서는 뚜껑 판(나사 4개·안쪽 테두리)과
  // 상자 아래 양쪽 긴 구멍만 보인다. 배관 허브는 옆면이라 앞에서 안 보인다.
  void _sorBox(_Box b, String kind) {
    final bool piston = kind == InstrumentShape.sorPiston;
    final double boxB = piston ? 0.63 : 0.6;
    _part(b.c, b.r(0, 0, 1, boxB), _sorBlue, radius: b.w * 0.07);
    _part(
      b.c,
      b.r(0.1, boxB * 0.08, 0.9, boxB * 0.72),
      _sorBlue,
      radius: b.w * 0.04,
    );
    final double sr = math.min(b.w, b.h) * 0.03;
    for (final dx in [0.06, 0.94]) {
      for (final dy in [0.05, 0.78]) {
        _circle(b.c, b.p(dx, boxB * dy), sr, _body);
      }
    }
    // 아래 양쪽 긴 구멍(설치용)
    for (final x in [0.1, 0.66]) {
      _oval(b.c, b.r(x, boxB * 0.82, x + 0.24, boxB * 0.95), _body);
    }
    const double cx = 0.5;
    switch (kind) {
      case InstrumentShape.sorWide:
        _part(b.c, b.r(0.36, boxB, 0.64, 0.7), _metal, radius: 0);
        _part(b.c, b.r(0.06, 0.7, 0.94, 0.85), _metal, radius: 3);
        for (final px in [0.14, 0.38, 0.62, 0.86]) {
          _circle(b.c, b.p(px, 0.83), math.min(b.w, b.h) * 0.02, _body);
        }
        _hex(b.c, b.r(cx - 0.12, 0.85, cx + 0.12, 0.92));
        _thread(b.c, b.r(cx - 0.06, 0.92, cx + 0.06, 1));
      case InstrumentShape.sorDiaphragm:
        _part(b.c, b.r(0.36, boxB, 0.64, 0.68), _metal, radius: 0);
        _part(b.c, b.r(0.25, 0.68, 0.75, 0.84), _metal, radius: 6);
        _hex(b.c, b.r(cx - 0.12, 0.84, cx + 0.12, 0.92));
        _thread(b.c, b.r(cx - 0.06, 0.92, cx + 0.06, 1));
      case InstrumentShape.sorDp:
        // 101 차압: 상자 아래 목·육각, 넓은 다이어프램 몸통, 그 아래 고압·저압 접속구 둘.
        // CAT468 미대조, 접속구 둘로 그림(예전엔 옆 허브 하나였다).
        _part(b.c, b.r(0.4, boxB, 0.6, 0.66), _metal, radius: 0);
        _hex(b.c, b.r(0.36, 0.66, 0.64, 0.71));
        _part(b.c, b.r(0.16, 0.71, 0.84, 0.9), _metal, radius: 6);
        for (final px in [0.35, 0.65]) {
          _hex(b.c, b.r(px - 0.08, 0.9, px + 0.08, 0.95));
          _thread(b.c, b.r(px - 0.05, 0.95, px + 0.05, 1));
        }
      default:
        _part(b.c, b.r(0.34, boxB, 0.66, 0.9), _metal, radius: 0);
        _hex(b.c, b.r(cx - 0.16, 0.9, cx + 0.16, 0.96));
        _thread(b.c, b.r(cx - 0.07, 0.96, cx + 0.07, 1));
    }
  }

  // SOR B3·B6(CAT216 p.28): 둥근 뚜껑과 양옆 보스, 아래 설정칸(구멍 4), 목, 육각.
  void _sorExp(_Box b) {
    _part(b.c, b.r(0, 0.2, 0.14, 0.3), _metal, radius: 1);
    _part(b.c, b.r(0.86, 0.2, 1, 0.3), _metal, radius: 1);
    final double rad = math.min(b.w * 0.4, b.h * 0.24);
    final Offset cc = b.p(0.5, 0.25);
    _circle(b.c, cc, rad, _sorBlue);
    _circle(b.c, cc, rad * 0.86, _sorBlue);
    // 뚜껑 위 긴 구멍 무늬
    for (final dx in [-0.35, 0.35]) {
      for (final dy in [-0.4, 0.0, 0.4]) {
        _oval(
          b.c,
          Rect.fromCenter(
            center: cc + Offset(dx * rad, dy * rad),
            width: rad * 0.18,
            height: rad * 0.3,
          ),
          _body,
        );
      }
    }
    final Rect set = b.r(0.24, 0.5, 0.76, 0.72);
    _part(b.c, set, _sorBlue, radius: 3);
    for (final dx in [0.3, 0.7]) {
      for (final dy in [0.54, 0.68]) {
        _circle(b.c, b.p(dx, dy), math.min(b.w, b.h) * 0.02, _body);
      }
    }
    _part(b.c, b.r(0.39, 0.72, 0.61, 0.9), _metal, radius: 0);
    _hex(b.c, b.r(0.36, 0.9, 0.64, 0.96));
    _thread(b.c, b.r(0.44, 0.96, 0.56, 1));
  }

  // ───────────────────────── 튜브 피팅(하이록·스웨즈락) ─────────────────────────
  // 옆에서 본 모습: 너트(육각, 면 셋)·몸통 육각·나사. 너트 길이는 관 1/4" 12.7,
  // 3/8" 14.2, 1/2" 17.5(두 회사 같다). 비율은 모듈 가로·세로에서 잡는다.

  /// 축이 가로인 육각(모서리 방향으로 본 면 셋: 가로 줄 둘).
  void _hexH(Canvas c, Rect r) {
    _part(c, r, _metal, radius: 1);
    for (final y in [r.top + r.height * 0.25, r.bottom - r.height * 0.25]) {
      c.drawLine(Offset(r.left, y), Offset(r.right, y), _thin);
    }
  }

  /// 축이 세로인 육각(세로 줄 둘).
  void _hexV(Canvas c, Rect r) {
    _part(c, r, _metal, radius: 1);
    for (final x in [r.left + r.width * 0.25, r.right - r.width * 0.25]) {
      c.drawLine(Offset(x, r.top), Offset(x, r.bottom), _thin);
    }
  }

  /// 가로 나사(세로 빗금).
  void _threadH(Canvas c, Rect t) {
    _part(c, t, _metal, radius: 0);
    final int n = math.max(2, (t.width / 4).floor());
    for (int i = 1; i < n; i++) {
      final double x = t.left + t.width * i / n;
      c.drawLine(Offset(x - 1, t.top), Offset(x + 1, t.bottom), _thin);
    }
  }

  // 유니언: 너트 | 몸통 육각 | 너트 (CUA / -6).
  void _fitUnion(_Box b) {
    const double nut = 0.31;
    _hexH(b.c, b.r(0, 0, nut, 1));
    _hexH(b.c, b.r(1 - nut, 0, 1, 1));
    _hexH(b.c, b.r(nut, 0.06, 1 - nut, 0.94));
  }

  // 유니언 엘보: 왼쪽 위 몸통, 오른쪽·아래로 너트 (CLA / -9).
  void _fitElbow(_Box b) {
    const double body = 0.38, nut = 0.38;
    _part(b.c, b.r(body, body * 0.15, 1 - nut, body * 0.85), _metal, radius: 0);
    _part(b.c, b.r(body * 0.15, body, body * 0.85, 1 - nut), _metal, radius: 0);
    _part(b.c, b.r(0, 0, body, body), _metal, radius: 2);
    _hexH(b.c, b.r(1 - nut, -0.04, 1, body + 0.04));
    _hexV(b.c, b.r(-0.04, 1 - nut, body + 0.04, 1));
  }

  // 유니언 티: 가운데 위 몸통, 양옆·아래로 너트 (CTA / -3).
  void _fitTee(_Box b) {
    // 원래 가로가 길다(2A × (A+h/2)).
    const double nutW = 0.24;
    final double body = 0.38 * b.h / b.w; // 몸통 폭(가로 비율)
    const double bodyH = 0.38;
    _part(
      b.c,
      b.r(nutW, bodyH * 0.15, 1 - nutW, bodyH * 0.85),
      _metal,
      radius: 0,
    );
    _part(
      b.c,
      b.r(0.5 - body * 0.35, bodyH, 0.5 + body * 0.35, 0.62),
      _metal,
      radius: 0,
    );
    _part(
      b.c,
      b.r(0.5 - body / 2, 0, 0.5 + body / 2, bodyH),
      _metal,
      radius: 2,
    );
    _hexH(b.c, b.r(0, -0.04, nutW, bodyH + 0.04));
    _hexH(b.c, b.r(1 - nutW, -0.04, 1, bodyH + 0.04));
    _hexV(b.c, b.r(0.5 - body / 2 - 0.02, 0.62, 0.5 + body / 2 + 0.02, 1));
  }

  // 유니언 크로스: 가운데 몸통, 네 방향 너트 (CXA / -4).
  void _fitCross(_Box b) {
    const double nut = 0.24, body = 0.2;
    _part(
      b.c,
      b.r(nut, 0.5 - body * 0.35, 1 - nut, 0.5 + body * 0.35),
      _metal,
      radius: 0,
    );
    _part(
      b.c,
      b.r(0.5 - body * 0.35, nut, 0.5 + body * 0.35, 1 - nut),
      _metal,
      radius: 0,
    );
    _part(
      b.c,
      b.r(0.5 - body / 2, 0.5 - body / 2, 0.5 + body / 2, 0.5 + body / 2),
      _metal,
      radius: 2,
    );
    _hexH(b.c, b.r(0, 0.5 - body / 2 - 0.02, nut, 0.5 + body / 2 + 0.02));
    _hexH(b.c, b.r(1 - nut, 0.5 - body / 2 - 0.02, 1, 0.5 + body / 2 + 0.02));
    _hexV(b.c, b.r(0.5 - body / 2 - 0.02, 0, 0.5 + body / 2 + 0.02, nut));
    _hexV(b.c, b.r(0.5 - body / 2 - 0.02, 1 - nut, 0.5 + body / 2 + 0.02, 1));
  }

  // 메일 커넥터: 너트 | 몸통 육각 | 수나사 (CMC / -1).
  void _fitMale(_Box b) {
    _hexH(b.c, b.r(0, 0, 0.34, 1));
    _hexH(b.c, b.r(0.34, 0, 0.52, 1));
    _threadH(b.c, b.r(0.52, 0.2, 1, 0.8));
  }

  // 메일 엘보: 왼쪽 너트 → 오른쪽 위 몸통, 아래로 수나사 (CLMA / -2).
  void _fitMaleElbow(_Box b) {
    const double body = 0.34;
    const double nut = 0.36;
    _part(b.c, b.r(nut, body * 0.15, 1 - body, body * 0.85), _metal, radius: 0);
    _part(b.c, b.r(1 - body, 0, 1, body), _metal, radius: 2);
    _hexH(b.c, b.r(0, -0.02, nut, body + 0.02));
    _threadV(b.c, b.r(1 - body * 0.82, body, 1 - body * 0.18, 1));
  }

  /// 세로 나사(가로 빗금).
  void _threadV(Canvas c, Rect t) => _thread(c, t);

  // 벌크헤드 유니언: 너트 | 몸통 육각 | 나사 몸통 + 잠금 너트 | 너트 (CBU / -61).
  void _fitBulkhead(_Box b) {
    const double nut = 0.23;
    _threadH(b.c, b.r(0.33, 0.14, 1 - nut, 0.86));
    _hexH(b.c, b.r(0, 0.05, nut, 0.95));
    _hexH(b.c, b.r(nut, 0, 0.33, 1));
    _hexH(b.c, b.r(0.55, 0, 0.64, 1));
    _hexH(b.c, b.r(1 - nut, 0.05, 1, 0.95));
  }

  // ───────────────────────── 매니폴드·게이지 밸브 ─────────────────────────
  // 스탠드에 단 모습을 앞(손잡이 쪽)에서 본 그림 = 하이록 H-120MV(2023) "Top" 그림.
  // 양옆 격리 밸브는 세로 T 손잡이, 앞으로 나온 균압·벤트 밸브는 손잡이 끝(T 막대)이 보인다.
  // 손잡이는 다 연 상태(카탈로그 "Open" 치수)로 그린다.

  /// 옆으로 나온 밸브(격리): 보닛 → 축 → 세로 T 손잡이. [y]는 가운데.
  void _stemSide(_Box b, double y, double from, double to) {
    final bool right = to > from;
    final double len = (to - from).abs();
    final double bh = 0.1 * b.w / b.h;
    double x(double f) => right ? from + len * f : from - len * f;
    Rect span(double f0, double f1, double half) {
      final double a = x(f0), c = x(f1);
      return b.r(math.min(a, c), y - half, math.max(a, c), y + half);
    }

    _hexH(b.c, span(0, 0.38, bh * 0.55));
    _part(b.c, span(0.38, 0.58, bh * 0.4), _metal, radius: 0);
    _part(b.c, span(0.58, 0.66, bh * 0.55), _metal, radius: 1);
    _part(b.c, span(0.66, 0.88, bh * 0.14), _metal, radius: 0);
    _part(b.c, span(0.88, 1, bh * 1.3), _metal, radius: 3);
  }

  void _block(
    _Box b,
    double l,
    double t,
    double r,
    double bottom, {
    bool bolts = false,
  }) {
    _part(b.c, b.r(l, t, r, bottom), _metal, radius: 2);
    if (bolts) {
      final double br = math.min(b.w, b.h) * 0.03;
      for (final px in [0.14, 0.86]) {
        for (final py in [0.12, 0.88]) {
          _circle(b.c, b.p(l + (r - l) * px, t + (bottom - t) * py), br, _body);
        }
      }
    }
  }

  /// 앞으로 나온 밸브의 손잡이 끝: 가로 T 막대와 가운데 축 머리. [x]·[y]는 가운데.
  /// [lenMm]·[mmW]·[mmH]로 그림 크기에 맞춰 줄인다(손잡이 45mm, 막대 굵기 8mm).
  void _handleFacing(
    _Box b,
    double x,
    double y, {
    required double mmW,
    required double mmH,
    double lenMm = 45,
  }) {
    final double half = b.w * lenMm / mmW / 2;
    final double th = b.h * 8 / mmH;
    final Offset c = b.p(x, y);
    _part(
      b.c,
      Rect.fromCenter(center: c, width: half * 2, height: th),
      _metal,
      radius: th / 2,
    );
    _circle(b.c, c, th * 0.7, _body);
  }

  /// 블록 윗면·아랫면의 NPT 접속구(옆에서 보여 빗금 칸).
  void _npt(_Box b, double l, double r, double t, double bottom) {
    _part(b.c, b.r(l, t, r, bottom), _body, radius: 0);
    final int n = math.max(3, ((r - l) * b.w / 3).floor());
    for (int i = 1; i < n; i++) {
      final double x = l + (r - l) * i / n;
      b.c.drawLine(b.p(x, t), b.p(x, bottom), _thin);
    }
  }

  /// 설치 구멍.
  void _hole(_Box b, double x, double y) =>
      _circle(b.c, b.p(x, y), math.min(b.w, b.h) * 0.035, _body);

  // 하이록 VM2VTV8N(p.18 Top 104×64): 왼쪽 블록 51, 오른쪽 격리, 앞으로 벤트.
  void _mv2(_Box b) {
    const double bodyR = 51 / 104;
    _stemSide(b, 0.5, bodyR, 1);
    _block(b, 0, 0, bodyR, 1);
    _npt(b, 0.02, 0.1, 0.25, 0.75); // 옆 접속구
    _npt(b, 0.2, 0.34, 0, 0.1); // 위 계기 쪽
    _npt(b, 0.2, 0.34, 0.9, 1); // 아래 공정 쪽
    _hole(b, 0.16, 0.13);
    _hole(b, 0.16, 0.87);
    // 앞으로 나온 벤트 밸브: 손잡이(Ø≈40)를 끝에서 본 점선 원으로 크게, 가운데 T 막대.
    _dashedCircle(
      b.c,
      b.p(bodyR * 0.6, 0.5),
      math.min(b.w * 20 / 104, b.h * 0.42),
    );
    _handleFacing(b, bodyR * 0.6, 0.5, mmW: 104, mmH: 64, lenMm: 40);
  }

  // 하이록 VM3V·VM5V(p.23·28 Top): 가운데 블록 86, 양옆 격리, 앞으로 균압(·벤트).
  // 1-플랜지 직결형은 위쪽에 계기 플랜지판이 붙는다.
  void _mv35(_Box b, {required bool five, bool flange = false}) {
    const double bodyL = 53 / 192, bodyR = 139 / 192;
    final double hMm = five ? (flange ? 113 : 86) : (flange ? 97 : 78);
    final double flangeB = flange ? 1 - (five ? 86 : 78) / hMm : 0;
    final double isoY = 1 - (five ? 32 : 31) / hMm;
    _stemSide(b, isoY, bodyL, 0);
    _stemSide(b, isoY, bodyR, 1);
    _block(b, bodyL, flangeB, bodyR, 1);
    if (flange) {
      _part(b.c, b.r(bodyL, 0, bodyR, flangeB), _body, radius: 1);
      _hole(b, 0.5, flangeB * 0.5);
    }
    // 공정 쪽(아래) 접속구 둘, 원격형은 계기 쪽(위)도 둘.
    for (final x in [bodyL + 0.02, bodyR - 0.11]) {
      _npt(b, x, x + 0.09, 1 - 10 / hMm, 1);
      if (!flange) _npt(b, x, x + 0.09, flangeB, flangeB + 10 / hMm);
    }
    _hole(b, 0.5 - 12 / 192, isoY);
    _hole(b, 0.5 + 12 / 192, isoY);
    final double midT = flangeB + (1 - flangeB) * 0.28;
    if (five) {
      _handleFacing(b, 0.5 - 22 / 192, midT, mmW: 192, mmH: hMm, lenMm: 36);
      _handleFacing(b, 0.5 + 22 / 192, midT, mmW: 192, mmH: hMm, lenMm: 36);
      _handleFacing(
        b,
        0.5,
        flangeB + (1 - flangeB) * 0.84,
        mmW: 192,
        mmH: hMm,
        lenMm: 30,
      );
    } else {
      _handleFacing(b, 0.5, midT, mmW: 192, mmH: hMm);
    }
  }

  // 하이록 VGVTVF8N 게이지 밸브(p.11, L 67 × 육각 32): 앞으로 손잡이.
  void _gv1(_Box b) {
    _hexH(b.c, b.r(0, 0, 1, 1));
    _npt(b, 0, 0.14, 0.2, 0.8);
    _npt(b, 0.86, 1, 0.2, 0.8);
    _handleFacing(b, 0.5, 0.5, mmW: 67, mmH: 32, lenMm: 40);
  }

  // 하이록 VGV2TV-F8N 게이지 2밸브(p.13, L 78 × 32 네모): 앞으로 벤트, 뒤로 격리.
  void _gv2(_Box b) {
    _part(b.c, b.r(0, 0, 1, 1), _metal, radius: 1);
    _npt(b, 0, 0.14, 0.2, 0.8);
    _npt(b, 0.86, 1, 0.2, 0.8);
    _handleFacing(b, 0.5, 0.5, mmW: 78, mmH: 32, lenMm: 40);
  }

  // 스웨즈락 V 시리즈(MS-02-445 p.6·10·12 Top을 격리 축이 가로가 되게 돌린 것).
  void _swV(_Box b, int valves) {
    switch (valves) {
      case 2: // SS-V2BF8 97×64: 오른쪽 블록 54, 왼쪽 격리, 앞으로 벤트
        const double l = 1 - 54 / 97;
        _stemSide(b, 0.5, l, 0);
        _block(b, l, 0, 1, 1);
        _hole(b, l + 0.1, 0.15);
        _hole(b, l + 0.1, 0.85);
        // 앞으로 나온 벤트 밸브 손잡이를 점선 원으로(2밸브로 보이게).
        _dashedCircle(
          b.c,
          b.p((l + 1) / 2 + 0.05, 0.5),
          math.min(b.w * 20 / 97, b.h * 0.42),
        );
        _handleFacing(b, (l + 1) / 2 + 0.05, 0.5, mmW: 97, mmH: 64, lenMm: 32);
      case 3: // SS-V3NBF8 229×48
        const double l = 70 / 229, r = 159 / 229;
        _stemSide(b, 0.5, l, 0);
        _stemSide(b, 0.5, r, 1);
        _block(b, l, 0, r, 1);
        _hole(b, l + 0.04, 0.5);
        _hole(b, r - 0.04, 0.5);
        _handleFacing(b, 0.5, 0.5, mmW: 229, mmH: 48, lenMm: 32);
      default: // SS-V5NBF8 226×56
        const double l = 70 / 226, r = 156 / 226;
        _stemSide(b, 0.5, l, 0);
        _stemSide(b, 0.5, r, 1);
        _block(b, l, 0, r, 1);
        _handleFacing(b, 0.5 - 0.05, 0.3, mmW: 226, mmH: 56, lenMm: 20);
        _handleFacing(b, 0.5 + 0.05, 0.3, mmW: 226, mmH: 56, lenMm: 20);
        _handleFacing(b, 0.5, 0.72, mmW: 226, mmH: 56, lenMm: 20);
    }
  }

  // ───────────────────────── 조각 목록으로 적은 피팅(fitting_spec.dart) ─────────────────────────

  void _fitSpec(Canvas c, Size s, String shape) {
    final Size? mm = fittingSpecSize(shape);
    if (mm == null || mm.width <= 0 || mm.height <= 0) return;
    // 가로·세로 같은 배율로(모양이 찌그러지지 않게), 칸 가운데에.
    final double k = math.min(s.width / mm.width, s.height / mm.height);
    c.save();
    c.translate((s.width - mm.width * k) / 2, (s.height - mm.height * k) / 2);
    if (shape.startsWith('fv:')) {
      _valveSpec(c, k, parseValve(shape), mm);
    } else if (shape.startsWith('fs:')) {
      _fitStraight(c, k, mm, parseStraight(shape));
    } else {
      final (body, arms) = parseElbow(shape);
      final Rect bb = elbowBounds(body, arms);
      c.translate(-bb.left * k, -bb.top * k);
      _fitElbowSpec(c, k, body, arms);
    }
    c.restore();
  }

  /// 한 조각을 [x0]~[x1](가로, 픽셀) 자리에 가운데 선 [cy], 높이 [hPx]로 그린다.
  void _fitSeg(
    Canvas c,
    String kind,
    double x0,
    double x1,
    double cy,
    double hPx,
  ) {
    final Rect r = Rect.fromLTRB(x0, cy - hPx / 2, x1, cy + hPx / 2);
    switch (kind) {
      case 'n':
      case 'h':
      case 'f':
      case 'l':
        _hexH(c, r);
      case 'c':
        // 체크 밸브 몸통: 육각에 흐름 화살표(왼쪽→오른쪽).
        _hexH(c, r);
        final double inset = math.min((x1 - x0) * 0.18, hPx * 0.5);
        _arrow(c, Offset(x0 + inset, cy), Offset(x1 - inset, cy), hPx * 0.3);
      case 't':
        _threadH(c, r);
      case 'p':
        // 포트 커넥터: 관은 조금 가늘게, 가운데 턱(짧은 굵은 고리)은 조각 높이 그대로.
        _part(
          c,
          Rect.fromLTRB(x0, cy - hPx * 0.38, x1, cy + hPx * 0.38),
          _metal,
          radius: 0,
        );
        final double ring = math.min((x1 - x0) * 0.22, hPx * 0.7);
        _part(
          c,
          Rect.fromCenter(
            center: Offset((x0 + x1) / 2, cy),
            width: ring,
            height: hPx,
          ),
          _metal,
          radius: 1,
        );
      default:
        _part(c, r, _metal, radius: 0);
    }
  }

  /// 흐름 화살표: 줄과 채운 화살촉. [head]는 화살촉 길이(픽셀).
  void _arrow(Canvas c, Offset from, Offset to, double head) {
    final Offset d = to - from;
    final double len = d.distance;
    if (len <= 0) return;
    final Offset u = d / len;
    final Offset n = Offset(-u.dy, u.dx);
    final double hl = math.min(head, len * 0.6);
    final Offset tail = to - u * hl;
    c.drawLine(from, tail, _line);
    final Path tip = Path()
      ..addPolygon([to, tail + n * hl * 0.5, tail - n * hl * 0.5], true);
    c.drawPath(tip, Paint()..color = stroke);
  }

  /// 점선 동그라미(앞으로 나온 손잡이를 끝에서 본 모습).
  void _dashedCircle(Canvas c, Offset o, double r) {
    if (r <= 0) return;
    const int n = 12;
    for (int i = 0; i < n; i++) {
      c.drawArc(
        Rect.fromCircle(center: o, radius: r),
        i * 2 * math.pi / n,
        math.pi / n,
        false,
        _line,
      );
    }
  }

  void _fitStraight(Canvas c, double k, Size mm, List<FitSeg> segs) {
    final double cy = mm.height * k / 2;
    double x = 0;
    for (final s in segs) {
      _fitSeg(c, s.kind, x, x + s.len * k, cy, s.h * k);
      x += s.len * k;
    }
  }

  void _fitElbowSpec(Canvas c, double k, double body, List<FitArm> arms) {
    for (final a in arms) {
      c.save();
      final double angle = switch (a.dir) {
        'l' => math.pi,
        'd' => math.pi / 2,
        'u' => -math.pi / 2,
        'x' => math.pi * 3 / 4,
        _ => 0.0,
      };
      c.rotate(angle);
      // 가운데에서 +x 쪽으로 뻗은 팔을 그린다.
      final double from = body / 2 * k * 0.9, to = a.len * k;
      final double th = a.thick * k;
      switch (a.kind) {
        case 'n':
          final double nut = math.min(a.thick * 0.8 * k, (to - from) * 0.7);
          _part(
            c,
            Rect.fromLTRB(from, -th * 0.28, to - nut, th * 0.28),
            _metal,
            radius: 0,
          );
          _fitSeg(c, 'n', to - nut, to, 0, th);
        case 't':
          _part(
            c,
            Rect.fromLTRB(
              from,
              -th * 0.35,
              from + (to - from) * 0.2,
              th * 0.35,
            ),
            _metal,
            radius: 0,
          );
          _fitSeg(c, 't', from + (to - from) * 0.2, to, 0, th);
        default:
          _fitSeg(c, 'h', from, to, 0, th);
      }
      c.restore();
    }
    final double bs = body * k;
    _part(
      c,
      Rect.fromCenter(center: Offset.zero, width: bs, height: bs),
      _metal,
      radius: 2,
    );
  }

  // ───────────────────────── 인라인 밸브(fitting_spec.dart "fv:") ─────────────────────────
  // 하이록 밸브 카탈로그 앞 그림(손잡이가 위): 관 줄 위의 몸통, 양 끝 너트·암나사·수나사,
  // 위로 보닛·축·손잡이. 좌표는 mm, 관 가운데 선이 y = top.

  void _valveSpec(Canvas c, double k, Map<String, String> v, Size mm) {
    final String kind = v['kind'] ?? '';
    final double l = valveNum(v, 'L');
    final double top = valveNum(v, 'top');
    final double bot = valveNum(v, 'bot', 10);
    final double pipe = valveNum(v, 'pipe', 17);
    final String end = v['end'] ?? 'n';
    Offset p(double x, double y) => Offset(x * k, y * k);
    Rect r(double l0, double t0, double r0, double b0) =>
        Rect.fromLTRB(l0 * k, t0 * k, r0 * k, b0 * k);

    if (kind == 'relief') {
      // 입구는 아래(가운데 x = bot), 출구는 오른쪽, 위로 스프링 통·조절 육각·둥근 뚜껑.
      final double cx = bot, outY = top - valveNum(v, 'out', top * 0.4);
      final double inTop = top - pipe * 0.9;
      _part(
        c,
        r(
          cx + bot * 0.8,
          outY - pipe * 0.3,
          l + bot - pipe * 0.8,
          outY + pipe * 0.3,
        ),
        _metal,
        radius: 0,
      );
      _hexH(
        c,
        r(l + bot - pipe * 0.8, outY - pipe / 2, l + bot, outY + pipe / 2),
      );
      _part(
        c,
        r(cx - bot * 0.45, outY + bot * 0.8, cx + bot * 0.45, inTop),
        _metal,
        radius: 0,
      );
      _hexV(c, r(cx - pipe / 2, inTop, cx + pipe / 2, top));
      _part(
        c,
        r(0, outY - bot * 0.9, 2 * bot, outY + bot * 0.9),
        _metal,
        radius: 2,
      );
      _part(
        c,
        r(cx - bot * 0.6, bot * 1.5, cx + bot * 0.6, outY - bot * 0.9),
        _body,
        radius: 2,
      );
      _hexV(c, r(cx - bot * 0.75, bot * 0.9, cx + bot * 0.75, bot * 1.5));
      c.drawOval(
        r(cx - bot * 0.5, 0, cx + bot * 0.5, bot),
        Paint()..color = _metal,
      );
      c.drawOval(r(cx - bot * 0.5, 0, cx + bot * 0.5, bot), _line);
      // 출구 관에 흐름 화살표(몸통 → 출구). 관이 짧으면 끝 너트까지 걸쳐 그린다.
      final double ax0 = cx + bot * 0.95;
      double ax1 = l + bot - pipe * 0.85;
      if (ax1 - ax0 < pipe * 0.5) ax1 = l + bot - pipe * 0.15;
      _arrow(c, p(ax0, outY), p(ax1, outY), pipe * 0.3 * k);
      return;
    }

    final double x0 = kind == 'ball' || kind == 'wing' ? 0 : (mm.width - l) / 2;
    final double sx = x0 + l / 2; // 축(손잡이) 자리
    // 몸통
    final double bw = switch (kind) {
      'ball' => math.max(l * 0.32, bot * 2),
      'wing' => math.min(l * 0.42, bot * 2.4),
      _ => math.min(l * 0.42, 32.0),
    };
    // 양 끝
    for (final left in [true, false]) {
      final double a = left ? x0 : sx + bw / 2;
      final double b = left ? sx - bw / 2 : x0 + l;
      if (b <= a) continue;
      final double nutLen = math.min(pipe * 0.8, (b - a) * 0.7);
      switch (end) {
        case 'f':
          _hexH(c, r(a, top - pipe / 2, b, top + pipe / 2));
        case 'm':
          final double tx0 = left ? a : a + (b - a) * 0.3;
          final double tx1 = left ? b - (b - a) * 0.3 : b;
          _threadH(c, r(tx0, top - pipe * 0.4, tx1, top + pipe * 0.4));
          _hexH(
            c,
            r(left ? tx1 : a, top - pipe / 2, left ? b : tx0, top + pipe / 2),
          );
        default:
          final double nx0 = left ? a : b - nutLen;
          final double nx1 = left ? a + nutLen : b;
          _part(
            c,
            r(
              left ? nx1 : a,
              top - pipe * 0.3,
              left ? b : nx0,
              top + pipe * 0.3,
            ),
            _metal,
            radius: 0,
          );
          _hexH(c, r(nx0, top - pipe / 2, nx1, top + pipe / 2));
      }
    }
    final double bodyTop = top - bot;
    if (kind == 'ball') {
      _hexH(c, r(sx - bw / 2, bodyTop, sx + bw / 2, top + bot));
    } else {
      _part(
        c,
        r(sx - bw / 2, bodyTop, sx + bw / 2, top + bot),
        _metal,
        radius: 2,
      );
      c.drawLine(p(sx - bw / 2, top), p(sx + bw / 2, top), _thin);
    }

    switch (kind) {
      case 'ball':
        // 짧은 축 위에서 비스듬히 올라 관과 나란히 뻗는 납작한 레버.
        final double reach = valveNum(v, 'reach', 80);
        final double th = math.min(6.0, top * 0.12);
        _part(c, r(sx - 3, 1.5 * th, sx + 3, bodyTop), _metal, radius: 0);
        final Path lever = Path()
          ..moveTo(sx * k, (bodyTop - 2) * k)
          ..lineTo((sx + 10) * k, th * k)
          ..lineTo((sx + reach) * k, th * k)
          ..lineTo((sx + reach) * k, 0)
          ..lineTo((sx + 10 - th) * k, 0)
          ..lineTo((sx - th) * k, (bodyTop - 2) * k)
          ..close();
        c.drawPath(lever, Paint()..color = _metal);
        c.drawPath(lever, _line);
      case 'wing':
        // 보닛·패널 너트, 그 위 날개 손잡이(관과 나란히 한쪽으로).
        final double reach = valveNum(v, 'reach', 50);
        final double bonW = bw * 0.55;
        _hexV(c, r(sx - bonW / 2, top * 0.35, sx + bonW / 2, bodyTop));
        _part(
          c,
          r(sx - bonW * 0.35, top * 0.15, sx + bonW * 0.35, top * 0.35),
          _metal,
          radius: 0,
        );
        _part(
          c,
          r(sx - bonW * 0.5, 0, sx + reach, top * 0.17),
          _body,
          radius: top * 0.08,
        );
        for (
          double x = sx + reach * 0.3;
          x < sx + reach * 0.95;
          x += reach * 0.15
        ) {
          c.drawLine(p(x, top * 0.03), p(x, top * 0.14), _thin);
        }
      default:
        // 니들·유니언 보닛·토글: 보닛(나사) → 패킹 육각 → 가는 축 → 손잡이.
        final double bonW = bw * (kind == 'gb' ? 0.7 : 0.5);
        final double y1 = bodyTop - (top - bot) * 0.3;
        _threadV(c, r(sx - bonW / 2, y1, sx + bonW / 2, bodyTop));
        final double y2 = y1 - (top - bot) * 0.18;
        _hexV(c, r(sx - bonW * 0.6, y2, sx + bonW * 0.6, y1));
        if (kind == 'gb') {
          _hexV(c, r(sx - bonW * 0.8, bodyTop - 8, sx + bonW * 0.8, bodyTop));
        }
        final double th = math.min(7.0, top * 0.1);
        _part(c, r(sx - 2, th, sx + 2, y2), _metal, radius: 0);
        if (kind == 'toggle') {
          final Path lever = Path()
            ..moveTo((sx - 2) * k, y2 * k)
            ..lineTo((sx + 26) * k, 0)
            ..lineTo((sx + 32) * k, th * 0.8 * k)
            ..lineTo((sx + 4) * k, y2 * k)
            ..close();
          c.drawPath(lever, Paint()..color = _metal);
          c.drawPath(lever, _line);
        } else {
          final double bar = valveNum(v, 'bar', 60);
          _part(
            c,
            r(sx - bar / 2, 0, sx + bar / 2, th),
            _metal,
            radius: th / 2,
          );
        }
    }
  }

  // ───────────────────────── 스키드 평면(위에서 본 모습) ─────────────────────────
  // 형강은 길이 방향이 가로. H형강 = 플랜지 판(가운데 웨브 점선), 찬넬 = 한쪽 끝 웨브,
  // 앵글 = 한쪽 끝 다리, 각파이프 = 안쪽 테두리, 스트럿 = 가운데 홈. 전선관은 관 두 줄과
  // 가운데 점선, 정션박스는 뚜껑 나사 넷.

  void _dashed(Canvas c, Offset a, Offset b) {
    final double len = (b - a).distance;
    if (len <= 0) return;
    final Offset d = (b - a) / len;
    const double dash = 8, gap = 5;
    for (double t = 0; t < len; t += dash + gap) {
      c.drawLine(a + d * t, a + d * math.min(t + dash, len), _thin);
    }
  }

  void _skid(_Box b, String shape) {
    final Canvas c = b.c;
    final double w = b.w, h = b.h;
    // 전선관 부속(곤질레다·커플링·유니온)은 스키드 부품 그림(위에서 본 모습)을 쓴다.
    if (SkidShape.isFitting(shape)) {
      drawSkidPart(c, Size(w, h), shape, SkidFace.top, stroke, strokeWidth);
      return;
    }
    switch (shape) {
      case SkidShape.conduit:
        _part(c, Rect.fromLTWH(0, 0, w, h), _metal, radius: h / 2);
        _dashed(c, Offset(0, h / 2), Offset(w, h / 2));
      case SkidShape.jb:
        _part(c, Rect.fromLTWH(0, 0, w, h), _body, radius: 3);
        _part(
          c,
          Rect.fromLTWH(w * 0.06, h * 0.06, w * 0.88, h * 0.88),
          _body,
          radius: 2,
        );
        final double r = math.min(w, h) * 0.03 + 1;
        for (final dx in [0.12, 0.88]) {
          for (final dy in [0.12, 0.88]) {
            _circle(c, b.p(dx, dy), r, _metal);
          }
        }
      case SkidShape.beam:
        _part(c, Rect.fromLTWH(0, 0, w, h), _metal, radius: 0);
        _dashed(c, Offset(0, h / 2), Offset(w, h / 2));
      case SkidShape.channel:
        _part(c, Rect.fromLTWH(0, 0, w, h), _metal, radius: 0);
        c.drawLine(Offset(0, h * 0.12), Offset(w, h * 0.12), _thin);
      case SkidShape.angle:
        _part(c, Rect.fromLTWH(0, 0, w, h), _metal, radius: 0);
        c.drawLine(Offset(0, h * 0.15), Offset(w, h * 0.15), _thin);
      case SkidShape.square:
        _part(c, Rect.fromLTWH(0, 0, w, h), _metal, radius: 1);
        c.drawLine(Offset(0, h * 0.12), Offset(w, h * 0.12), _thin);
        c.drawLine(Offset(0, h * 0.88), Offset(w, h * 0.88), _thin);
      case SkidShape.strut:
        _part(c, Rect.fromLTWH(0, 0, w, h), _metal, radius: 0);
        _part(c, Rect.fromLTWH(0, h * 0.3, w, h * 0.4), _body, radius: 0);
    }
  }

  // ───────────────────────── 전기 부품(DIN 레일) 정면 ─────────────────────────
  // 칸 크기 그대로(돌리지 않는다). 단자대·차단기는 극마다 세로 줄.

  void _elec(_Box b, String shape) {
    final Canvas c = b.c;
    final double w = b.w, h = b.h;
    final double? n = ElecShape.pitch(shape);
    final double? pitch = n == null || n < 1 ? null : w / n;
    final String kind = shape.split(':').first;
    void poles(double top, double bottom) {
      if (pitch == null || pitch <= 0) return;
      for (double x = pitch; x < w - 0.5; x += pitch) {
        c.drawLine(Offset(x, top), Offset(x, bottom), _thin);
      }
    }

    switch (kind) {
      case ElecShape.tb:
        _part(c, Rect.fromLTWH(0, 0, w, h), _body, radius: 1);
        poles(0, h);
        // 위아래 나사, 가운데 표시판 홈
        c.drawLine(Offset(0, h * 0.2), Offset(w, h * 0.2), _thin);
        c.drawLine(Offset(0, h * 0.8), Offset(w, h * 0.8), _thin);
        _part(c, Rect.fromLTWH(0, h * 0.42, w, h * 0.16), _metal, radius: 0);
      case ElecShape.mcb:
        _part(c, Rect.fromLTWH(0, 0, w, h), _body, radius: 2);
        _part(c, Rect.fromLTWH(0, h * 0.22, w, h * 0.56), _body, radius: 1);
        poles(0, h);
        final double pw = pitch ?? w;
        for (double x = pw / 2; x < w; x += pw) {
          _part(
            c,
            Rect.fromCenter(
              center: Offset(x, h * 0.45),
              width: pw * 0.4,
              height: h * 0.16,
            ),
            _metal,
            radius: 1,
          );
        }
      case ElecShape.mccb:
        _part(c, Rect.fromLTWH(0, 0, w, h), _body, radius: 2);
        _part(
          c,
          Rect.fromLTWH(w * 0.1, h * 0.25, w * 0.8, h * 0.5),
          _body,
          radius: 2,
        );
        _part(
          c,
          Rect.fromLTWH(w * 0.38, h * 0.35, w * 0.24, h * 0.3),
          _metal,
          radius: 2,
        );
        c.drawLine(Offset(0, h * 0.12), Offset(w, h * 0.12), _thin);
        c.drawLine(Offset(0, h * 0.88), Offset(w, h * 0.88), _thin);
      case ElecShape.psu:
        _part(c, Rect.fromLTWH(0, 0, w, h), _body, radius: 2);
        for (double x = w * 0.15; x < w * 0.86; x += w * 0.1) {
          c.drawLine(Offset(x, h * 0.3), Offset(x, h * 0.62), _thin);
        }
        _part(
          c,
          Rect.fromLTWH(w * 0.05, 0, w * 0.9, h * 0.14),
          _metal,
          radius: 1,
        );
        _part(
          c,
          Rect.fromLTWH(w * 0.05, h * 0.86, w * 0.9, h * 0.14),
          _metal,
          radius: 1,
        );
      case ElecShape.relay:
        _part(c, Rect.fromLTWH(0, 0, w, h), _metal, radius: 2);
        _part(
          c,
          Rect.fromLTWH(w * 0.04, h * 0.3, w * 0.92, h * 0.4),
          _glass,
          radius: 2,
        );
      case ElecShape.mc:
        _part(c, Rect.fromLTWH(0, 0, w, h), _body, radius: 2);
        _part(
          c,
          Rect.fromLTWH(w * 0.15, h * 0.25, w * 0.7, h * 0.5),
          _body,
          radius: 2,
        );
        _part(
          c,
          Rect.fromLTWH(w * 0.35, h * 0.4, w * 0.3, h * 0.2),
          _metal,
          radius: 1,
        );
        c.drawLine(Offset(0, h * 0.15), Offset(w, h * 0.15), _thin);
        c.drawLine(Offset(0, h * 0.85), Offset(w, h * 0.85), _thin);
      case ElecShape.spd:
        _part(c, Rect.fromLTWH(0, 0, w, h), _metal, radius: 1);
        _part(
          c,
          Rect.fromLTWH(w * 0.08, h * 0.18, w * 0.84, h * 0.64),
          _body,
          radius: 2,
        );
      case ElecShape.iso:
        _part(c, Rect.fromLTWH(0, 0, w, h), _body, radius: 2);
        _part(
          c,
          Rect.fromLTWH(w * 0.1, h * 0.12, w * 0.8, h * 0.2),
          _glass,
          radius: 1,
        );
        c.drawLine(Offset(0, h * 0.85), Offset(w, h * 0.85), _thin);
      case ElecShape.rail:
        _part(c, Rect.fromLTWH(0, 0, w, h), _metal, radius: 0);
        for (double x = 12; x < w - 12; x += 25) {
          _part(c, Rect.fromLTWH(x, h * 0.4, 12, h * 0.2), _body, radius: 2);
        }
      default:
        _part(c, Rect.fromLTWH(0, 0, w, h), _body, radius: 2);
    }
  }

  @override
  bool shouldRepaint(covariant InstrumentShapePainter old) =>
      old.shape != shape ||
      old.stroke != stroke ||
      old.strokeWidth != strokeWidth ||
      old.quarterTurns != quarterTurns ||
      old.mirror != mirror;
}

/// 그림 안에서 0~1 비율로 자리를 적는 도우미.
class _Box {
  final Canvas c;
  final double w;
  final double h;
  _Box(this.c, Size s) : w = s.width, h = s.height;

  Offset p(double x, double y) => Offset(w * x, h * y);
  Rect r(double l, double t, double rr, double b) =>
      Rect.fromLTRB(w * l, h * t, w * rr, h * b);
}
