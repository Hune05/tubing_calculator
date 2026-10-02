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
      lpText(c, on ? '플런저 ↑' : '플런저', Offset(ox + 92, oy + 101), size: 7, color: on ? _ctGreen : AppColors.textSub, w: FontWeight.w900);
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

  String _say(bool on, String n) => on ? 'COM$n–N.O.$n closed · N.C.$n open' : 'COM$n–N.C.$n closed · N.O.$n open';

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
            0 => '평소 COM–N.C., 동작하면 COM–N.O.',
            1 => 'SPDT 2개가 같이 동작. 두 회로는 서로 분리됨',
            _ => 'SPDT 2개가 각자 set point에서 따로 동작 (H122 HIGH · LOW)',
          },
          style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSub),
        ),
      ],
    );
  }
}

List<Widget> contactSection(Widget Function(String) title, List<Widget> Function(List<(String, String)>) rows) => [
  title('접점: SPDT · DPDT'),
  ...rows(const [
    ('COM', 'Common'),
    ('N.O.', 'Normal Open. 동작하면 COM과 붙음'),
    ('N.C.', 'Normal Close. 동작하면 COM과 떨어짐'),
  ]),
  const SizedBox(height: 10),
  refTable(
    headers: const ['종류', '접점', 'Set point', 'UE 120'],
    flex: const [2, 4, 2, 3],
    rows: const [
      ['SPDT', 'COM · N.O. · N.C.', '1', 'J120, H121'],
      ['DPDT', 'SPDT × 2, 같이 동작', '1', '옵션 (H122 안 됨)'],
      ['2SPDT', 'SPDT × 2, 따로 동작', '2', 'H122 (HIGH · LOW)'],
    ],
    footer: '출처: UE 120-B, IMP120 Fig.3',
  ),
  const SizedBox(height: 12),
  const _ContactDemo(),
  const SizedBox(height: 10),
  refTipBox('Normal = 압력이 set point에 안 닿은 상태 (운전 중 상태 아님). 저압 경보는 운전 압력에서 이미 동작해 있어서 COM–N.O.가 붙어 있음'),
  const SizedBox(height: 8),
  refWarnBox('H122 LOW 스위치는 내부 배선이 반대 (IMP120 Fig.3 "REVERSE WIRING"). 단자 표시만 믿지 말고 압력 걸어서 테스터로 확인'),
  title('결선 · 확인'),
  ...rows(const [
    ('결선', '루프도대로. 경보·트립은 보통 fail-safe (정상 시 closed, 알람 시 open)'),
    ('DPDT', '같은 set point로 두 회로 (예: DCS + 경광등). 두 접점 전환 시점이 조금 다를 수 있음'),
    ('테스터', '회로 차단 후 통전 모드. 0 bar에서 COM–N.C. 삐. 올려서 동작하면 COM–N.O. 삐. 바뀌는 순간이 동작점, 내려서 돌아오는 값이 복귀점'),
    ('살아 있는 회로', '통전·Ω 레인지 금지. V 레인지로 (open 접점 양단에 전압, closed는 0 V)'),
    ('접점 용량', '15 A 125/250/480 VAC (resistive). DC는 2 A 30 V, 1 A 48 V, 0.5 A 125 V (명판에 DC 표기 없음)'),
    ('유도 부하', '솔레노이드·릴레이 코일 직결 시 용량 확인. 보통 릴레이 거쳐서 씀'),
  ]),
];
