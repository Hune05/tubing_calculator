// UE H122 (120 시리즈 방폭, 스위치 2개, 바깥 다이얼 설정) 부분(10-02).
// 근거: UE IMP120 23 "Types H122, H122K: 각 마이크로스위치를 같이 또는 따로 범위의 100%까지 설정. 앞(LOW) 스위치를
// 뒤(HIGH)보다 높게 두지 말 것. 바깥 손잡이로 각각 올리고 내림", "H121: 바깥 손잡이와 지침을 눈금에 맞춤",
// 그림 3 2SPDT(HIGH 단자대·LOW 단자대, LOW 배선 반대), 카탈로그 120-B "reference dial(참고 다이얼),
// 스테인리스 변조 방지 다이얼 덮개, 범위 아래 끝은 하강 때·위 끝은 상승 때, single conduit".
// 다이얼 덮개·손잡이 배치는 설명서 그림이 없어 단순화했다(실물 확인).
part of 'ue_switch_guide_page.dart';

class UeH122View {
  final bool cover; // 본체 덮개 닫힘(결선할 때만 엶)
  final bool dialCap; // 위 다이얼 덮개 닫힘
  final String? hot; // dialcap, low, high, term, hub, conn
  final bool lowOn, highOn; // 동작 중
  const UeH122View({this.cover = true, this.dialCap = true, this.hot, this.lowOn = false, this.highOn = false});
}

/// 360 × 320: H122 앞모습. 위에 다이얼 덮개(나사 둘), 원통 몸체, 오른쪽 전선관 하나, 아래 압력 접속구.
class UeH122Painter extends CustomPainter {
  final UeH122View v;
  const UeH122Painter(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    c.save();
    c.scale(size.width / 360, size.height / 320);
    const ctr = Offset(180, 168);
    // 압력 접속구
    final stem = Rect.fromLTWH(160, 262, 40, 34);
    c.drawRect(stem, Paint()..shader = const LinearGradient(colors: [Color(0xFF8E979F), Color(0xFFE2E6EA), Color(0xFF7D868E)]).createShader(stem));
    c.drawRect(const Rect.fromLTWH(150, 294, 60, 20), Paint()..shader = const LinearGradient(colors: [Color(0xFF9AA3AB), Color(0xFFEDEFF1), Color(0xFF8E979F)]).createShader(const Rect.fromLTWH(150, 294, 60, 20)));
    if (v.hot == 'conn') _glow(c, const Offset(180, 300), 28);
    // 전선관 하나(오른쪽)
    final hub = RRect.fromRectAndRadius(const Rect.fromLTWH(272, 142, 46, 50), const Radius.circular(6));
    c.drawRRect(hub, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFA9C6D8), _ueBlue, _ueBlueDark]).createShader(hub.outerRect));
    c.drawCircle(const Offset(304, 167), 12, Paint()..color = const Color(0xFF15181C));
    if (v.hot == 'hub') _glow(c, const Offset(300, 167), 28);
    // 원통 몸체
    c.drawCircle(ctr + const Offset(3, 6), 110, Paint()
      ..color = Colors.black.withValues(alpha: .28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    c.drawCircle(ctr, 110, Paint()..shader = const RadialGradient(center: Alignment(-.35, -.4), colors: [Color(0xFFC3D8E5), _ueBlue, _ueBlueDark]).createShader(Rect.fromCircle(center: ctr, radius: 110)));
    for (final a in const [-2.4, -0.75, 0.75, 2.4]) {
      final p = ctr + Offset(math.cos(a), math.sin(a)) * 104;
      c.drawCircle(p, 7, Paint()..color = _ueBlueDark);
      c.drawCircle(p, 3, Paint()..color = const Color(0xFF1F2A33));
    }
    // 위 다이얼 덮개(스테인리스, 나사 둘)
    final cap = Path()
      ..moveTo(128, 70)
      ..lineTo(146, 38)
      ..lineTo(214, 38)
      ..lineTo(232, 70)
      ..close();
    c.drawPath(cap.shift(const Offset(2, 3)), Paint()..color = Colors.black.withValues(alpha: .25));
    c.drawPath(cap, Paint()..shader = const LinearGradient(colors: [Color(0xFF9AA3AB), Color(0xFFF1F3F5), Color(0xFF8E979F)]).createShader(const Rect.fromLTWH(128, 38, 104, 32)));
    lpScrew(c, const Offset(150, 58), r: 5);
    lpScrew(c, const Offset(210, 58), r: 5);
    if (!v.dialCap) {
      // 덮개를 열면 손잡이 두 개가 보임
      c.drawPath(cap, Paint()..color = const Color(0xFF2B3036));
      for (final (x, name, on) in [(160.0, 'LOW', v.lowOn), (200.0, 'HIGH', v.highOn)]) {
        c.drawCircle(Offset(x, 54), 10, Paint()..shader = const RadialGradient(colors: [Colors.white, Color(0xFF9AA3AB)]).createShader(Rect.fromCircle(center: Offset(x, 54), radius: 10)));
        c.drawLine(Offset(x, 54), Offset(x, 45), Paint()
          ..color = const Color(0xFFDC2626)
          ..strokeWidth = 2.2);
        lpText(c, name, Offset(x, 30), size: 7.5, color: on ? const Color(0xFF15803D) : AppColors.textSub, w: FontWeight.w900);
      }
    }
    if (v.hot == 'dialcap') _glow(c, const Offset(180, 56), 36);
    if (v.hot == 'low') _glow(c, const Offset(160, 54), 18);
    if (v.hot == 'high') _glow(c, const Offset(200, 54), 18);

    if (v.cover) {
      c.drawCircle(ctr, 92, Paint()..shader = const RadialGradient(center: Alignment(-.3, -.4), colors: [Color(0xFFB7D0DF), _ueBlue]).createShader(Rect.fromCircle(center: ctr, radius: 92)));
      c.drawCircle(ctr, 70, Paint()..color = const Color(0xFF1A1D21));
      lpText(c, 'UE', ctr + const Offset(0, -18), size: 18, color: Colors.white, w: FontWeight.w900);
      lpText(c, 'H122  EXPLOSION-PROOF', ctr + const Offset(0, 6), size: 7, color: const Color(0xFFCBD2D8));
      lpText(c, 'WARNING: DISCONNECT BEFORE OPENING', ctr + const Offset(0, 24), size: 5.5, color: const Color(0xFF9AA3AB));
    } else {
      // 안: 위 HIGH 단자대, 아래 LOW 단자대, 가운데 스위치 둘
      c.drawCircle(ctr, 92, Paint()..shader = const RadialGradient(colors: [Color(0xFFDDE2E7), Color(0xFFAEB6BE)]).createShader(Rect.fromCircle(center: ctr, radius: 92)));
      void block(double y, String title, List<String> names, List<Color> wires, bool on) {
        final r = RRect.fromRectAndRadius(Rect.fromLTWH(118, y, 124, 32), const Radius.circular(5));
        lpShadow(c, r, blur: 3, off: const Offset(0, 2), a: .25);
        c.drawRRect(r, Paint()..color = const Color(0xFFF1EBDD));
        for (var i = 0; i < 3; i++) {
          final x = 146.0 + i * 34;
          lpText(c, names[i], Offset(x, y + 8), size: 7, color: const Color(0xFF1F2328), w: FontWeight.w900);
          lpScrew(c, Offset(x, y + 22), r: 6);
        }
        lpPill(c, title, Offset(98, y + 16), on ? const Color(0xFF16A34A) : const Color(0xFF6B737B), size: 7.5);
      }

      block(98, 'HIGH', const ['N.O.', 'COM.', 'N.C.'], const [], v.highOn);
      block(206, 'LOW', const ['N.C.', 'COM.', 'N.O.'], const [], v.lowOn);
      for (final (y, on) in [(140.0, v.highOn), (172.0, v.lowOn)]) {
        final sw = RRect.fromRectAndRadius(Rect.fromLTWH(136, y, 88, 26), const Radius.circular(4));
        c.drawRRect(sw, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A3F45), Color(0xFF15181C)]).createShader(sw.outerRect));
        lpText(c, on ? 'SPDT  동작' : 'SPDT', Offset(180, y + 13), size: 7.5, color: on ? const Color(0xFF4ADE80) : const Color(0xFFB4BBC2), w: FontWeight.w900);
      }
      if (v.hot == 'term') _glow(c, ctr, 70);
      // 내부 접지(전선관 쪽)
      c.drawCircle(const Offset(254, 168), 6, Paint()..color = const Color(0xFF16A34A));
      lpScrew(c, const Offset(254, 168), r: 4.5);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(UeH122Painter o) => true;
}

/// 360 × 180: 다이얼 덮개를 연 위에서 본 다이얼(참고 눈금) 두 개. 손잡이를 돌리면 지침이 눈금 위를 감.
class UeDialPainter extends CustomPainter {
  final double low, high, max;
  final String? hot;
  const UeDialPainter({required this.low, required this.high, required this.max, this.hot});

  void _dial(Canvas c, Offset ctr, double val, String name, Color col, bool hl) {
    const r = 58.0;
    if (hl) _glow(c, ctr, 62);
    c.drawCircle(ctr, r + 6, Paint()..shader = const LinearGradient(colors: [Color(0xFFDDE2E7), Color(0xFF9AA3AB)]).createShader(Rect.fromCircle(center: ctr, radius: r + 6)));
    c.drawCircle(ctr, r, Paint()..color = Colors.white);
    const a0 = math.pi * .8, sweep = math.pi * 1.4;
    for (var i = 0; i <= 20; i++) {
      final a = a0 + i / 20 * sweep;
      final big = i % 4 == 0; // 0·2·4·6·8·10 (2.5가 "3"으로 찍히지 않게)
      c.drawLine(ctr + Offset(math.cos(a), math.sin(a)) * (r - (big ? 12 : 7)), ctr + Offset(math.cos(a), math.sin(a)) * (r - 2), Paint()
        ..color = const Color(0xFF2B3036)
        ..strokeWidth = big ? 1.6 : .9);
      if (big) lpText(c, (max * i / 20).toStringAsFixed(max * i / 20 % 1 == 0 ? 0 : 1), ctr + Offset(math.cos(a), math.sin(a)) * (r - 21), size: 7, color: const Color(0xFF2B3036));
    }
    final a = a0 + (val / max).clamp(0.0, 1.0) * sweep;
    c.drawLine(ctr, ctr + Offset(math.cos(a), math.sin(a)) * (r - 6), Paint()
      ..color = col
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);
    c.drawCircle(ctr, 11, Paint()..shader = const RadialGradient(colors: [Colors.white, Color(0xFF8E979F)]).createShader(Rect.fromCircle(center: ctr, radius: 11)));
    c.drawLine(ctr + const Offset(-7, 0), ctr + const Offset(7, 0), Paint()
      ..color = const Color(0xFF4A5057)
      ..strokeWidth = 2.4);
    lpText(c, 'bar', ctr + const Offset(0, 26), size: 7, color: AppColors.textSub);
    lpPill(c, '$name ${val.toStringAsFixed(1)}', ctr + Offset(0, r + 14), col, size: 8);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    c.save();
    c.scale(size.width / 360, size.height / 180);
    _dial(c, const Offset(96, 80), low, 'LOW (앞)', const Color(0xFF2563EB), hot == 'low');
    _dial(c, const Offset(264, 80), high, 'HIGH (뒤)', const Color(0xFFDC2626), hot == 'high');
    c.restore();
  }

  @override
  bool shouldRepaint(UeDialPainter o) => o.low != low || o.high != high || o.hot != hot;
}

class _H122Step {
  final String say;
  final UeH122View view;
  final double low, high;
  final String? warn;
  const _H122Step(this.say, this.view, {this.low = 3, this.high = 7, this.warn});
}

const _h122Steps = [
  _H122Step('설정은 덮개를 안 열고 위 다이얼로 함. 그래도 제어실에 알리고 이 스위치가 물린 경보·인터록은 바이패스 (시험 중 동작함)', UeH122View()),
  _H122Step('시험 압력원(핸드 펌프 + 표준 압력계)을 압력 접속구 쪽 시험 포트에 연결하고 원밸브는 잠금. 스패너는 접속구 육각에', UeH122View(hot: 'conn')),
  _H122Step('접점 확인 자리를 정함: 판넬(정션 박스·DCS 입력)에서 HIGH·LOW 접점 상태를 봄. 덮개를 열어 단자에서 보려면 회로를 끊고 엶 (방폭)', UeH122View(hot: 'term'), warn: '방폭: 회로가 살아 있으면 본체 덮개를 열지 말 것'),
  _H122Step('위 다이얼 덮개(스테인리스, 변조 방지)의 나사 둘을 풀고 엶', UeH122View(hot: 'dialcap')),
  _H122Step('앞(LOW) 손잡이를 돌려 지침을 저압 설정값(예 3.0 bar)에 맞춤. 손잡이마다 따로 올리고 내림', UeH122View(dialCap: false, hot: 'low'), low: 3.0),
  _H122Step('뒤(HIGH) 손잡이를 고압 설정값(예 7.0 bar)에 맞춤. LOW는 HIGH보다 높게 두지 말 것', UeH122View(dialCap: false, hot: 'high'), high: 7.0, warn: '설명서: 앞(LOW) 스위치를 뒤(HIGH)보다 높게 설정하지 말 것. 두 스위치는 같이 또는 따로 범위의 100%까지 설정 가능'),
  _H122Step('다이얼은 참고 눈금. 압력을 천천히 올려 HIGH가 동작하는 압력을 표준 압력계로 읽음', UeH122View(dialCap: false, highOn: true), high: 7.0),
  _H122Step('압력을 천천히 내려 HIGH 복귀, 더 내려 LOW가 동작하는 압력을 읽음 (LOW는 하강 때 동작)', UeH122View(dialCap: false, lowOn: true), low: 3.0),
  _H122Step('목표와 다르면 그 손잡이를 조금 돌리고 다시 시험. 2~3번 같은 값이 나오는지 확인', UeH122View(dialCap: false, hot: 'high'), high: 7.2),
  _H122Step('다이얼 덮개를 닫고 나사 조임. 압력원 떼고 원밸브 복구, 바이패스 해제, 결과 기록', UeH122View(hot: 'dialcap')),
];

class _H122Walk extends StatefulWidget {
  const _H122Walk();

  @override
  State<_H122Walk> createState() => _H122WalkState();
}

class _H122WalkState extends State<_H122Walk> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final s = _h122Steps[_i];
    final last = _i == _h122Steps.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _frame(CustomPaint(key: const Key('h122_walk_fig'), painter: UeH122Painter(s.view)), 360 / 320),
        if (!s.view.dialCap) ...[
          const SizedBox(height: 8),
          _frame(CustomPaint(painter: UeDialPainter(low: s.low, high: s.high, max: 10, hot: s.view.hot)), 360 / 180),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(20)),
                child: Text('${_i + 1} / ${_h122Steps.length}', key: const Key('h122_walk_count'), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.brand)),
              ),
              const SizedBox(height: 10),
              Text(s.say, style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.text, fontWeight: FontWeight.w600)),
              if (s.warn != null) ...[const SizedBox(height: 10), refWarnBox(s.warn!)],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: OutlinedButton.icon(key: const Key('h122_walk_prev'), onPressed: _i == 0 ? null : () => setState(() => _i--), icon: const Icon(AppIcons.back), label: const Text('이전'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(key: const Key('h122_walk_next'), onPressed: () => setState(() => _i = last ? 0 : _i + 1), icon: Icon(last ? Icons.replay : AppIcons.forward), label: Text(last ? '처음부터' : '다음'))),
          ],
        ),
      ],
    );
  }
}

/// 시험대: 다이얼 두 개를 돌리고 압력을 올리고 내려 HIGH(상승 동작)·LOW(하강 동작)를 확인.
class _H122Bench extends StatefulWidget {
  const _H122Bench();

  @override
  State<_H122Bench> createState() => _H122BenchState();
}

class _H122BenchState extends State<_H122Bench> {
  static const double _db = 0.3, _div = 0.2, _dialErr = 0.15; // 그림용: 데드밴드, 한 눈금, 다이얼과 실제 차이
  static const double _tLow = 3.0, _tHigh = 7.0;
  double _low = 3.4, _high = 6.6; // 다이얼 지침
  double _p = 5;
  bool _hOn = false, _lOn = false;
  double? _hAt, _lAt;

  double get _hReal => _high + _dialErr;
  double get _lReal => _low + _dialErr;

  void _setP(double v) {
    setState(() {
      final up = v > _p;
      _p = v;
      if (!_hOn && up && _p >= _hReal) {
        _hOn = true;
        _hAt = _hReal; // 천천히 올릴 때 표준기가 읽는 값(빨리 밀어 지나친 값이 아니라)
      } else if (_hOn && !up && _p <= _hReal - _db) {
        _hOn = false;
      }
      if (!_lOn && !up && _p <= _lReal) {
        _lOn = true;
        _lAt = _lReal;
      } else if (_lOn && up && _p >= _lReal + _db) {
        _lOn = false;
      }
    });
  }

  void _turn(bool high, int dir) {
    setState(() {
      if (high) {
        _high = (_high + dir * _div).clamp(0.0, 10.0);
        _hAt = null;
      } else {
        final n = (_low + dir * _div).clamp(0.0, 10.0);
        if (n > _high) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('LOW를 HIGH보다 높게 두지 마십시오 (설명서)')));
          return;
        }
        _low = n;
        _lAt = null;
      }
    });
  }

  Widget _row(String name, double? at, double target) {
    final err = at == null ? null : at - target;
    return refDataRow(name, at == null ? (name.startsWith('HIGH') ? '압력을 올려 보십시오' : '압력을 내려 보십시오') : '${at.toStringAsFixed(2)} bar (목표 ${target.toStringAsFixed(1)}과 ${err! >= 0 ? '+' : ''}${err.toStringAsFixed(2)})');
  }

  @override
  Widget build(BuildContext context) {
    final hErr = _hAt == null ? null : _hAt! - _tHigh;
    final lErr = _lAt == null ? null : _lAt! - _tLow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('목표: HIGH는 7.0 bar로 오르면, LOW는 3.0 bar로 내리면 동작', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
        const SizedBox(height: 8),
        _frame(CustomPaint(key: const Key('h122_bench_dial'), painter: UeDialPainter(low: _low, high: _high, max: 10)), 360 / 180),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(key: const Key('h122_low_dn'), onPressed: () => _turn(false, -1), child: const Text('LOW −')),
            OutlinedButton(key: const Key('h122_low_up'), onPressed: () => _turn(false, 1), child: const Text('LOW +')),
            OutlinedButton(key: const Key('h122_high_dn'), onPressed: () => _turn(true, -1), child: const Text('HIGH −')),
            OutlinedButton(key: const Key('h122_high_up'), onPressed: () => _turn(true, 1), child: const Text('HIGH +')),
          ],
        ),
        const SizedBox(height: 10),
        _frame(CustomPaint(painter: _H122BenchPainter(_p, _hOn, _lOn)), 360 / 120),
        Text('시험 압력 ${_p.toStringAsFixed(2)} bar', key: const Key('h122_bench_p'), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSub)),
        Slider(key: const Key('h122_bench_slider'), min: 0, max: 10, divisions: 200, value: _p, onChanged: _setP),
        _row('HIGH 동작점', _hAt, _tHigh),
        refGap(),
        _row('LOW 동작점', _lAt, _tLow),
        const SizedBox(height: 8),
        if (hErr != null && hErr.abs() > 0.1) refWarnBox(hErr < 0 ? 'HIGH가 일찍 동작함 → HIGH 손잡이를 올림(+)' : 'HIGH가 늦게 동작함 → HIGH 손잡이를 내림(−)'),
        if (lErr != null && lErr.abs() > 0.1) ...[const SizedBox(height: 6), refWarnBox(lErr > 0 ? 'LOW가 일찍(높은 압력에서) 동작함 → LOW 손잡이를 내림(−)' : 'LOW가 늦게 동작함 → LOW 손잡이를 올림(+)')],
        if (hErr != null && lErr != null && hErr.abs() <= 0.1 && lErr.abs() <= 0.1) refTipBox('둘 다 목표 안 (±0.1 bar). 다이얼 덮개를 닫고 기록'),
        const SizedBox(height: 8),
        const Text('※ 그림용: 범위 0~10 bar, 한 눈금 0.2 bar, 데드밴드 0.3 bar, 다이얼과 실제가 0.15 bar 다르게 정한 흉내입니다. 다이얼은 참고 눈금이라 실제 동작점은 꼭 표준 압력계로 확인합니다. 실제 눈금 간격·데드밴드는 모델표(120-B)에 있습니다.', style: TextStyle(fontSize: 12, color: AppColors.textSub)),
      ],
    );
  }
}

class _H122BenchPainter extends CustomPainter {
  final double p;
  final bool hOn, lOn;
  const _H122BenchPainter(this.p, this.hOn, this.lOn);

  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    c.save();
    c.scale(size.width / 360, size.height / 120);
    // 압력 막대
    const l = 20.0, r = 230.0, y = 60.0;
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(l, y - 8, r, y + 8), const Radius.circular(8)), Paint()..color = AppColors.line);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(l, y - 8, l + (r - l) * (p / 10).clamp(0.0, 1.0), y + 8), const Radius.circular(8)), Paint()..color = AppColors.brand);
    for (final (v, s) in const [(0.0, '0'), (3.0, '3'), (5.0, '5'), (7.0, '7'), (10.0, '10 bar')]) {
      lpText(c, s, Offset(l + (r - l) * v / 10, y + 22), size: 7.5, color: AppColors.textSub);
    }
    lpText(c, '시험 압력', const Offset(48, 34), size: 8, color: AppColors.textSub, w: FontWeight.w800);
    // 램프 둘
    for (final (x, name, on, col) in [(270.0, 'HIGH', hOn, const Color(0xFFDC2626)), (326.0, 'LOW', lOn, const Color(0xFF2563EB))]) {
      if (on) {
        c.drawCircle(Offset(x, 56), 18, Paint()
          ..color = col.withValues(alpha: .45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      }
      c.drawCircle(Offset(x, 56), 12, Paint()..color = on ? col : const Color(0xFFCBD2D8));
      lpText(c, name, Offset(x, 82), size: 8.5, color: on ? col : AppColors.textSub, w: FontWeight.w900);
      lpText(c, on ? '동작' : '대기', Offset(x, 96), size: 7.5, color: AppColors.textSub);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_H122BenchPainter o) => o.p != p || o.hOn != hOn || o.lOn != lOn;
}

List<Widget> h122Section(Widget Function(String) title, List<Widget> Function(List<(String, String)>) rows) => [
  refIntroBadge('H122: 원통형 방폭 외함, 스위치 2개(HIGH·LOW), 위 다이얼로 덮개를 안 열고 설정. 본체 덮개는 결선할 때만 엽니다. 근거 UE IMP120·120-B, 다이얼 덮개·손잡이 모양은 단순화했습니다.'),
  title('겉모습'),
  _frame(const CustomPaint(key: Key('h122_fig'), painter: UeH122Painter(UeH122View())), 360 / 320),
  const SizedBox(height: 10),
  ...rows(const [
    ('다이얼 덮개', '위쪽 스테인리스 덮개, 나사 둘 (변조 방지, 개스킷 있음). 열면 손잡이 둘'),
    ('LOW 손잡이 (앞)', '앞 마이크로스위치. 보통 저압 경보 (하강 때 동작)'),
    ('HIGH 손잡이 (뒤)', '뒤 마이크로스위치. 보통 고압 경보 (상승 때 동작)'),
    ('다이얼', '참고 눈금 (reference dial). 눈금 간격은 모델마다 다름 (120-B "Dial Divisions")'),
    ('본체 덮개', '나사식 둥근 덮개. 결선할 때만 엶 (회로 차단 후)'),
    ('전선관', '하나 (single conduit, 3/4" NPT)'),
  ]),
  title('따라하기: 다이얼로 설정'),
  const _H122Walk(),
  title('시험대: 직접 해 보기 (스위치 2개)'),
  const _H122Bench(),
  title('안쪽 (결선할 때만)'),
  _frame(const CustomPaint(key: Key('h122_inside'), painter: UeH122Painter(UeH122View(cover: false))), 360 / 320),
  const SizedBox(height: 10),
  refTable(
    headers: const ['단자대', '순서', '배선 색 (설명서 그림 3)'],
    flex: const [2, 4, 4],
    rows: const [
      ['HIGH (위)', 'N.O. · COM. · N.C.', '주황 · 노랑 · 빨강'],
      ['LOW (아래)', 'N.C. · COM. · N.O.', '검정 · 보라 · 파랑'],
    ],
    footer: '※ 2SPDT: LOW 스위치는 배선이 반대로 되어 있음 (단자 순서가 HIGH와 거꾸로). 단자 이름을 보고 물릴 것',
  ),
  const SizedBox(height: 10),
  ...rows(const [
    ('결선 순서', '회로 차단 → 본체 덮개 엶 → 단자대에 직접 결선 → 내부 접지 단자(전선관 옆)에 접지 → 덮개를 손으로 끝까지 (O-링)'),
    ('범위 끝', '설정 범위 아래 끝은 하강 때, 위 끝은 상승 때 기준 (120-B 모델표)'),
    ('설정 한계', '두 스위치는 같이 또는 따로 범위의 100%까지. LOW는 HIGH보다 높게 두지 말 것'),
    ('전선·조임', '구리 90 ℃ 이상, 14 AWG(약 2.0 mm²)까지, 7~17 in·lb (약 0.8~1.9 N·m). 명판 접점 정격을 넘기지 말 것'),
    ('방폭 실링', '전선관은 함에서 18" (약 450 mm) 안에 실링, 덮개 나사산 윤활제는 닦지 말 것'),
  ]),
];
