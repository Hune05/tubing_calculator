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
      _spdt(c, 10, 14, on1, '스위치 1 (설정점 1)', '', plunger: true);
      _spdt(c, 10, 164, on2, '스위치 2 (설정점 2)', '', plunger: true);
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
      lpText(c, on ? '플런저 ↑ (밂)' : '플런저', Offset(ox + 92, oy + 101), size: 7, color: on ? _ctGreen : AppColors.textSub, w: FontWeight.w900);
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
  static const _two = ['동작 전 (압력이 설정점 아래)', '동작 (설정점 넘음)'];
  static const _dual = ['둘 다 동작 전', '1번만 동작', '둘 다 동작'];
  int _kind = 0, _st = 0;

  String _say(bool on, String n) => on ? '닫힘 COM$n–N.O.$n · 열림 COM$n–N.C.$n' : '닫힘 COM$n–N.C.$n · 열림 COM$n–N.O.$n';

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
            0 => 'COM 하나가 N.C.와 N.O. 사이를 오감. 단자 3개, 설정점 하나 (J120·H121 기본)',
            1 => 'SPDT 두 벌이 한 번에 넘어감. 단자 6개, 설정점 하나. 두 회로는 서로 전기가 안 통함 (UE 옵션 1010·1190·1195)',
            _ => 'SPDT 두 개가 따로 동작. 설정점 둘 (H122·H122K 기본, HIGH·LOW)',
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
    ('극 (Pole, P)', '한 번에 같이 움직이는 접점 묶음 수. COM 단자 수와 같음'),
    ('투 (Throw, T)', 'COM이 붙을 수 있는 자리 수. 단투(ST)는 하나, 쌍투(DT)는 둘 (N.O.·N.C.)'),
    ('COM', '공통 단자. 늘 N.O.나 N.C. 어느 한쪽에 붙어 있음'),
    ('N.O. (a접점)', '스위치가 동작 안 했을 때 열림, 동작하면 닫힘'),
    ('N.C. (b접점)', '스위치가 동작 안 했을 때 닫힘, 동작하면 열림'),
    ('c접점', 'COM·N.O.·N.C. 3단자 전환 접점 = SPDT. 1c는 SPDT 하나, 2c는 DPDT'),
  ]),
  const SizedBox(height: 10),
  refTable(
    headers: const ['종류', '단자', '설정점', 'UE 120'],
    flex: const [3, 2, 3, 5],
    rows: const [
      ['SPST', '2', '1', '없음 (켜고 끄기만)'],
      ['SPDT (1c)', '3', '1', 'J120·H121 기본'],
      ['DPDT (2c)', '6', '1 (같이)', '옵션 1010·1190·1195. H122에는 안 됨'],
      ['2SPDT', '3 + 3', '2 (따로)', 'H122·H122K 기본'],
    ],
    footer: '근거: UE 120-B 스위치 옵션표, IMP120 그림 3',
  ),
  const SizedBox(height: 12),
  const _ContactDemo(),
  title('"평상시"가 헷갈리는 이유'),
  ...[
    refStep(1, 'N.O.·N.C.는 스위치가 동작 안 한 상태 기준. 압력이 설정점에 안 닿은 상태, 떼어서 책상에 놓은 상태'),
    refStep(2, '운전 중 평소 상태와 다를 수 있음. 운전 중 상태는 그때 압력이 설정점 위냐 아래냐로 정해짐'),
    refStep(3, '고압 경보 (상승 7 bar 동작), 운전 5 bar: 설정점 아래라 동작 전 그대로. 단자 표시대로 COM–N.C. 닫힘'),
    refStep(4, '저압 경보 (하강 3 bar 동작), 운전 5 bar: 기동하며 압력이 오를 때 이미 넘어감. 운전 중엔 COM–N.O. 닫힘, 3 bar 아래로 떨어지면 COM–N.C.로 돌아옴'),
  ],
  const SizedBox(height: 8),
  refWarnBox('H122 LOW 스위치는 속 배선이 HIGH와 거꾸로 물려 있음 (설명서 그림 3 "REVERSE WIRING"). 단자 표시만 믿지 말고 압력을 걸어 통전으로 확인'),
  title('어느 접점에 물리나'),
  ...rows(const [
    ('기준', '루프도·결선도대로. 어느 접점을 쓸지는 설계에서 정함'),
    ('경보·트립', '정상일 때 닫혀 있고 이상 때 열리게 무는 경우가 많음. 선이 끊어져도 경보가 나게 (페일 세이프). 현장 회로도를 따를 것'),
    ('DPDT 쓰임', '설정점 하나로 회로 둘. 예) DCS 경보 + 현장 경광등, AC 회로와 DC 회로 따로'),
    ('DPDT 주의', '두 접점이 딱 같은 압력에서 안 바뀔 수 있음. 1190은 상승 기준, 1195는 하강 기준으로 맞춘 것 (120-B)'),
    ('2SPDT 쓰임', '설정점 둘. 예) 고압·저압 경보, 펌프 기동·정지'),
  ]),
  title('테스터로 접점 확인'),
  ...[
    refStep(1, '회로 차단, 검전. 방폭 외함은 살아 있을 때 덮개를 안 엶. 정션 박스 단자에서 재도 됨'),
    refStep(2, '멀티미터 통전(부저) 또는 저항(Ω) 레인지'),
    refStep(3, '압력 0 (대기압): COM–N.C. 삐 (0 Ω 가까이), COM–N.O. 무음 (OL)'),
    refStep(4, '압력을 올려 동작시키면 바뀜: COM–N.O. 삐, COM–N.C. OL'),
    refStep(5, '바뀌는 순간 표준기 값 = 동작점. 천천히 내려 다시 바뀌는 값 = 복귀점'),
    refStep(6, 'N.O.–N.C. 사이는 언제나 열림 (COM을 거쳐야만 붙음)'),
  ],
  const SizedBox(height: 8),
  refWarnBox('살아 있는 회로에 통전·저항 레인지로 대지 말 것 (테스터·퓨즈 상함). 살아 있을 땐 전압 레인지: 열린 접점 양끝엔 전압이 걸리고, 닫힌 접점은 0 V 가까이'),
  title('접점 정격'),
  ...rows(const [
    ('표준', '15 A 125/250/480 VAC 저항 부하. DC는 훨씬 낮음: 2 A 30 VDC, 1 A 48 VDC, 0.5 A 125 VDC'),
    ('명판', 'DC 정격은 명판에 안 적혀 있음 (120-B). 정격 넘기면 첫 동작에도 상할 수 있음'),
    ('유도 부하', '솔레노이드·릴레이 코일을 바로 물리면 접점이 빨리 상함. 정격 안인지 꼭 확인, 보통 릴레이를 거침'),
    ('작은 전류', 'DCS 입력처럼 전류가 아주 작은 회로는 금 접점 옵션 (0140, 1180·1190) 을 쓰기도 함'),
  ]),
];
