part of 'ue_switch_guide_page.dart';

// SPDT·DPDT·2SPDT 접점 알기(10-02). 근거 UE IMP120 그림 3, 120-B 스위치 옵션표.
// 그림은 원리 그림: 레버(COM)가 N.C.나 N.O. 쪽으로 넘어가고, 닫힌 길만 초록.

const _ctGreen = Color(0xFF16A34A);
const _ctOff = Color(0xFF9AA3AB);

class UeContactPainter extends CustomPainter {
  final int kind; // 0 SPDT, 1 DPDT, 2 2SPDT
  final bool on1, on2;
  const UeContactPainter(this.kind, this.on1, this.on2);

  static double aspect(int kind) => kind == 0 ? 360 / 150 : 360 / 300;

  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    c.save();
    c.scale(size.width / 360, size.height / (kind == 0 ? 150 : 300));
    if (kind == 0) {
      _spdt(c, 10, 14, on1, 'SPDT', '', plunger: true);
    } else if (kind == 1) {
      // DPDT: 접점 두 벌이 플런저 하나로 한 번에 넘어감, 설정점 하나
      _spdt(c, 10, 14, on1, '접점 1', '1', plunger: false);
      _spdt(c, 10, 164, on1, '접점 2', '2', plunger: true);
      final y1 = _leverY(14, on1), y2 = _leverY(164, on1);
      final p = Paint()
        ..color = const Color(0xFF6B737B)
        ..strokeWidth = 2.4;
      for (var y = y1 + 4; y < y2 - 4; y += 9) {
        c.drawLine(Offset(130, y), Offset(130, math.min(y + 5, y2 - 4)), p);
      }
      lpPill(c, '플런저 하나로 같이 움직임', const Offset(200, 153), const Color(0xFF6B737B), size: 7.5);
    } else {
      _spdt(c, 10, 14, on1, '스위치 1', '', plunger: true);
      _spdt(c, 10, 164, on2, '스위치 2', '', plunger: true);
    }
    c.restore();
  }

  // 레버 끝(x=176) 높이: 동작 = N.O.(위), 동작 전 = N.C.(아래)
  static double _tipY(double oy, bool on) => on ? oy + 36 : oy + 84;
  static double _leverY(double oy, bool on) {
    const t = (130 - 44) / (172 - 44);
    return oy + 60 + (_tipY(oy, on) - (oy + 60)) * t;
  }

  void _spdt(Canvas c, double ox, double oy, bool on, String name, String n, {required bool plunger}) {
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(ox + 6, oy + 10, 200, 100), const Radius.circular(10));
    lpShadow(c, body, blur: 5, off: const Offset(0, 3), a: .22);
    c.drawRRect(body, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4F6F8), Color(0xFFDDE2E7)]).createShader(body.outerRect));
    c.drawRRect(body.deflate(1), Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: .8));

    final pivot = Offset(ox + 44, oy + 60);
    final no = Offset(ox + 180, oy + 34), nc = Offset(ox + 180, oy + 86);
    final tNo = Offset(ox + 296, oy + 34), tCom = Offset(ox + 296, oy + 60), tNc = Offset(ox + 296, oy + 86);

    void wire(List<Offset> pts, bool live) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      if (live) {
        c.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = _ctGreen.withValues(alpha: .22));
      }
      c.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = live ? _ctGreen : _ctOff);
    }

    // 고정 접점 → 단자
    wire([no, tNo], on);
    wire([nc, tNc], !on);
    // COM: 레버 축에서 아래로 돌아 단자로 (N.C. 선을 건너는 곳은 뜀 표시)
    final hopX = ox + 250;
    final comPath = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(ox + 26, pivot.dy)
      ..lineTo(ox + 26, oy + 118)
      ..lineTo(hopX, oy + 118)
      ..lineTo(hopX, nc.dy + 6)
      ..arcToPoint(Offset(hopX, nc.dy - 6), radius: const Radius.circular(6), clockwise: false)
      ..lineTo(hopX, tCom.dy)
      ..lineTo(tCom.dx, tCom.dy);
    c.drawPath(comPath, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeJoin = StrokeJoin.round
      ..color = _ctGreen.withValues(alpha: .22));
    c.drawPath(comPath, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round
      ..color = _ctGreen);

    // 고정 접점(은색 머리)
    for (final p in [no, nc]) {
      final r = Rect.fromCenter(center: p.translate(-3, 0), width: 10, height: 12);
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), Paint()..shader = const LinearGradient(colors: [Color(0xFFEDEFF1), Color(0xFF9AA3AB)]).createShader(r));
    }
    lpText(c, 'N.O.$n', no.translate(-4, -14), size: 7, color: const Color(0xFF2B3036), w: FontWeight.w900);
    lpText(c, 'N.C.$n', nc.translate(-4, 14), size: 7, color: const Color(0xFF2B3036), w: FontWeight.w900);

    // 레버(COM, 구리)
    final tip = Offset(ox + 172, _tipY(oy, on));
    c.drawLine(pivot.translate(1, 2), tip.translate(1, 2), Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: .18));
    c.drawLine(pivot, tip, Paint()
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(colors: [Color(0xFFB45309), Color(0xFFF59E0B), Color(0xFFB45309)]).createShader(Rect.fromPoints(pivot, tip)));
    c.drawCircle(tip, 4.5, Paint()..shader = const RadialGradient(colors: [Colors.white, Color(0xFF9AA3AB)]).createShader(Rect.fromCircle(center: tip, radius: 4.5)));
    c.drawCircle(pivot, 6, Paint()..color = const Color(0xFF3A3F45));
    c.drawCircle(pivot, 2.5, Paint()..color = const Color(0xFFCBD2D8));
    lpText(c, 'COM$n', pivot.translate(0, 16), size: 7, color: const Color(0xFF2B3036), w: FontWeight.w900);

    // 플런저: 압력이 설정점을 넘으면 밀어 올림
    if (plunger) {
      final ly = _leverY(oy, on);
      final rod = Rect.fromLTRB(ox + 125, ly + (on ? 3 : 10), ox + 135, oy + 108); // 동작 전엔 레버에 안 닿음
      c.drawRRect(RRect.fromRectAndRadius(rod, const Radius.circular(3)), Paint()..shader = const LinearGradient(colors: [Color(0xFF8E979F), Color(0xFFE2E6EA), Color(0xFF7D868E)]).createShader(rod));
      lpText(c, on ? '플런저가 밀어 올림' : '플런저', Offset(ox + 92, oy + 101), size: 7, color: on ? _ctGreen : AppColors.textSub, w: FontWeight.w900);
    }

    // 단자대
    for (final (p, label, live) in [(tNo, 'N.O.$n', on), (tCom, 'COM$n', true), (tNc, 'N.C.$n', !on)]) {
      lpScrew(c, p, r: 7);
      lpText(c, label, p.translate(32, 0), size: 8, color: live ? const Color(0xFF15803D) : const Color(0xFF6B737B), w: FontWeight.w900);
    }
    lpPill(c, '$name · ${on ? '동작' : '동작 전'}', Offset(ox + 72, oy + 8), on ? _ctGreen : const Color(0xFF6B737B), size: 7.5);
  }

  @override
  bool shouldRepaint(UeContactPainter o) => o.kind != kind || o.on1 != on1 || o.on2 != on2;
}

class _ContactDemo extends StatefulWidget {
  const _ContactDemo();

  @override
  State<_ContactDemo> createState() => _ContactDemoState();
}

class _ContactDemoState extends State<_ContactDemo> {
  static const _kinds = ['SPDT', 'DPDT', '2SPDT'];
  static const _two = ['압력 낮음 (동작 전)', '압력 높음 (동작)'];
  static const _dual = ['둘 다 동작 전', '1번만 동작', '둘 다 동작'];
  int _kind = 0, _st = 0;

  String _say(bool on, String n) => on ? 'COM$n–N.O.$n 붙음 (통전) · N.C.$n 떨어짐' : 'COM$n–N.C.$n 붙음 (통전) · N.O.$n 떨어짐';

  @override
  Widget build(BuildContext context) {
    final on1 = _kind == 2 ? _st >= 1 : _st == 1;
    final on2 = _kind == 2 ? _st == 2 : on1;
    final states = _kind == 2 ? _dual : _two;
    final lines = switch (_kind) {
      0 => [_say(on1, '')],
      1 => ['접점 1: ${_say(on1, '1')}', '접점 2: ${_say(on1, '2')}'],
      _ => ['스위치 1: ${_say(on1, '')}', '스위치 2: ${_say(on2, '')}'],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        refChips(
          items: _kinds,
          selected: _kinds[_kind],
          onSelected: (v) => setState(() {
            _kind = _kinds.indexOf(v);
            _st = 0;
          }),
        ),
        const SizedBox(height: 8),
        refChips(items: states, selected: states[_st], onSelected: (v) => setState(() => _st = states.indexOf(v))),
        const SizedBox(height: 10),
        _frame(CustomPaint(key: const Key('ue_ct_fig'), painter: UeContactPainter(_kind, on1, on2)), UeContactPainter.aspect(_kind)),
        const SizedBox(height: 8),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(l, key: Key('ue_ct_say_${lines.indexOf(l)}'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
          ),
        const SizedBox(height: 4),
        Text(
          switch (_kind) {
            0 => 'COM이 평소에는 N.C. 쪽에 붙어 있다가, 동작하면 N.O. 쪽으로 넘어가 붙음',
            1 => 'SPDT 2개가 한 번에 같이 동작함. 두 회로는 서로 통하지 않아 따로 쓸 수 있음',
            _ => 'SPDT 2개가 각자 자기 설정값에서 따로 동작함 (H122의 HIGH, LOW)',
          },
          style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSub),
        ),
      ],
    );
  }
}

List<Widget> contactSection(Widget Function(String) title, List<Widget> Function(List<(String, String)>) rows) => [
  title('접점 알기: SPDT · DPDT'),
  ...rows(const [
    ('COM', '공통 단자. 전선 하나는 항상 여기에 물림'),
    ('N.O. (a접점)', '평소에는 떨어져 있다가, 스위치가 동작하면 COM과 붙음'),
    ('N.C. (b접점)', '평소에는 COM과 붙어 있다가, 스위치가 동작하면 떨어짐'),
    ('SPDT (1c 접점)', '단자 3개 (COM, N.O., N.C.). 스위치 1개, 설정값 1개'),
    ('DPDT (2c 접점)', '단자 6개. SPDT 2개가 한 번에 같이 동작. 설정값은 1개'),
    ('2SPDT', 'SPDT 2개가 각자 따로 동작. 설정값 2개 (HIGH, LOW)'),
  ]),
  const SizedBox(height: 8),
  refTipBox('이름 읽는 법: SPDT = Single Pole Double Throw. 앞의 S(1개)·D(2개)는 스위치가 몇 개 묶였는지, 뒤의 DT는 COM이 N.O.와 N.C. 두 곳으로 갈 수 있다는 뜻'),
  const SizedBox(height: 10),
  refTable(
    headers: const ['종류', '단자 수', '설정값', 'UE 120 시리즈'],
    flex: const [3, 2, 2, 4],
    rows: const [
      ['SPDT (1c)', '3개', '1개', 'J120, H121 기본'],
      ['DPDT (2c)', '6개', '1개', '옵션 (H122는 안 됨)'],
      ['2SPDT', '3개 + 3개', '2개', 'H122 기본'],
    ],
    footer: '출처: UE 카탈로그 120-B, 설명서 IMP120 그림 3',
  ),
  const SizedBox(height: 12),
  const _ContactDemo(),
  title('주의: "평소"의 뜻'),
  ...[
    refStep(1, 'N.O.(평소 열림), N.C.(평소 닫힘)의 "평소"는 스위치가 동작하지 않은 상태. 압력이 0이거나 설정값보다 낮은 상태를 말함'),
    refStep(2, '운전 중인 평소 상태를 말하는 것이 아님. 운전 압력이 설정값보다 높으면, 운전 중에는 이미 동작해 있음'),
    refStep(3, '예) 고압 경보, 설정 7 bar, 운전 5 bar. 설정값까지 안 올라갔으니 동작 전 상태. COM과 N.C.가 붙어 있음'),
    refStep(4, '예) 저압 경보, 설정 3 bar, 운전 5 bar. 압력이 오르면서 설정값을 지날 때 이미 동작함. 운전 중에는 COM과 N.O.가 붙어 있고, 압력이 3 bar 밑으로 떨어지면 다시 COM과 N.C.가 붙음'),
  ],
  const SizedBox(height: 8),
  refWarnBox('H122 LOW 스위치는 안쪽 배선이 HIGH와 반대로 되어 있음 (설명서 그림 3). 단자 이름만 보고 판단하지 말고, 압력을 걸어 테스터로 직접 확인할 것'),
  title('결선할 때'),
  ...rows(const [
    ('기준', '루프도·결선도에 나온 대로 물림. 어느 접점을 쓸지는 설계에서 정함'),
    ('경보·트립 회로', '정상일 때 붙어 있고, 이상이 생기면 떨어지게 무는 경우가 많음. 선이 끊어져도 경보가 뜨게 하려는 것 (페일 세이프)'),
    ('DPDT를 쓰는 곳', '같은 설정값으로 두 군데에 신호를 줄 때. 예) DCS 경보와 현장 경광등'),
    ('DPDT 주의', '두 접점이 정확히 같은 압력에서 바뀌지 않을 수 있음 (카탈로그 120-B)'),
    ('2SPDT를 쓰는 곳', '설정값이 2개 필요할 때. 예) 고압 경보와 저압 경보, 펌프 기동과 정지'),
  ]),
  title('테스터로 접점 확인'),
  ...[
    refStep(1, '회로를 차단하고 검전. 방폭 함은 전기가 살아 있을 때 열지 않음. 정션 박스 단자에서 재도 됨'),
    refStep(2, '테스터를 통전(삐 소리) 또는 저항(Ω)에 놓음'),
    refStep(3, '압력 0일 때: COM과 N.C.에 대면 삐 소리, COM과 N.O.에 대면 소리 없음 (OL)'),
    refStep(4, '압력을 올려 스위치가 동작하면 반대로 바뀜: COM과 N.O.에서 삐 소리'),
    refStep(5, '소리가 바뀌는 순간의 표준 압력계 값이 동작점. 천천히 내려서 다시 바뀌는 값이 복귀점'),
    refStep(6, 'N.O.와 N.C. 사이는 언제 대도 소리가 안 남. 정상임'),
  ],
  const SizedBox(height: 8),
  refWarnBox('전기가 살아 있는 회로에 통전·저항 레인지로 대지 말 것 (테스터·퓨즈 손상). 살아 있으면 전압 레인지로 잼: 떨어진 접점 양쪽에는 전압이 나오고, 붙은 접점은 0 V 가까이 나옴'),
  title('접점 용량'),
  ...rows(const [
    ('기본 용량', 'AC 125/250/480 V에서 15 A (저항 부하 기준)'),
    ('DC', 'AC보다 훨씬 작음. 30 V 2 A, 48 V 1 A, 125 V 0.5 A. 명판에는 DC 용량이 안 적혀 있음 (카탈로그 120-B)'),
    ('솔레노이드·릴레이 코일', '바로 물리면 접점이 빨리 상함. 용량 안인지 꼭 확인. 보통은 릴레이를 거쳐서 씀'),
    ('용량 초과', '명판 용량을 넘기면 한 번 동작에도 접점이 상할 수 있음 (설명서)'),
    ('아주 작은 전류', 'DCS 입력처럼 전류가 아주 작은 회로는 금도금 접점 옵션을 쓰기도 함 (0140, 1180, 1190)'),
  ]),
];
