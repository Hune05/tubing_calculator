// 결선도·기동 회로 읽기(10-03): 전동기 단자함 Y·Δ 결선과 직입·정역·Y-Δ 기동 시퀀스를
// 버튼을 눌러 보며 접점·코일이 바뀌는 순서를 따라가게 한다. 동작 계산은 ladder_sim.dart, 그림은 ladder_painter.dart.
// 결선 근거: Siemens Y-Δ 자료(유리·불리 결선), WEG·ABB 설명서(단자 표기·회전 방향·Y-Δ 정격). docs/전동기_점검_근거.md.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/field_view.dart';
import 'ladder_painter.dart';
import 'ladder_sim.dart';

class CircuitReadingPage extends StatelessWidget {
  const CircuitReadingPage({super.key, this.initialTab = 0});

  /// 0 전동기 결선, 1 직입, 2 정역, 3 Y-Δ.
  final int initialTab;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    initialIndex: initialTab.clamp(0, 3),
    child: Scaffold(
      backgroundColor: fc.background,
      appBar: AppBar(
        title: const Text('결선도·기동 회로'),
        bottom: const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(key: Key('cr_tab_wiring'), text: '전동기 결선'),
            Tab(key: Key('cr_tab_dol'), text: '직입 기동'),
            Tab(key: Key('cr_tab_fr'), text: '정역 운전'),
            Tab(key: Key('cr_tab_yd'), text: 'Y-Δ 기동'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [
          _WiringTab(),
          _LadderTab(circuit: kDolCircuit, steps: _dolSteps, keyPrefix: 'dol'),
          _LadderTab(circuit: kFwdRevCircuit, steps: _frSteps, keyPrefix: 'fr'),
          _LadderTab(circuit: kStarDeltaCircuit, steps: _ydSteps, keyPrefix: 'yd'),
        ],
      ),
    ),
  );
}

const _dolSteps = [
  '기동 PB1을 누르면 MC 코일이 여자됩니다. 주접점이 닫혀 전동기가 돌고, 보조 a접점 13-14도 닫힙니다.',
  'PB1에서 손을 떼도 13-14가 PB1 대신 전기를 이어 줘서 계속 돕니다(자기유지).',
  '정지 PB0(b접점)을 누르면 줄이 끊겨 MC가 떨어지고 13-14도 열려, 다시 누를 때까지 멈춰 있습니다.',
  '과부하로 과부하계전기가 트립하면 95-96이 열려 MC가 떨어집니다. 리셋하기 전에는 기동되지 않습니다.',
];

const _frSteps = [
  'PBF를 누르면 MCF가 여자되어 정회전하고 13-14로 자기유지합니다. 동시에 MCF 21-22(b)가 열려 MCR 줄을 끊습니다.',
  '정회전 중에 PBR을 눌러도 MCR은 붙지 않습니다(전기적 인터록). 두 접촉기가 같이 붙으면 상간 단락입니다.',
  '역회전하려면 PB0으로 먼저 멈춘 뒤 PBR을 누릅니다.',
  '주회로에서 MCR은 세 상 중 두 상을 바꿔 물려 회전 방향을 바꿉니다.',
];

const _ydSteps = [
  'PB1을 누르면 MC-M이 여자·자기유지하고, MC-M 보조 a로 타이머 T와 MC-Y가 여자됩니다. 전동기는 Y 결선으로 기동합니다(기동전류 직입의 1/3).',
  '타이머 시간이 다 되면 T 한시 b접점이 열려 MC-Y가 떨어지고, MC-Y 21-22가 닫힌 뒤 T 한시 a접점으로 MC-Δ가 여자되어 Δ 결선으로 운전합니다.',
  'MC-Δ는 13-14로 자기유지하고 21-22로 타이머를 복귀시킵니다. MC-Y와 MC-Δ는 서로의 21-22로 인터록되어 같이 붙지 않습니다.',
  '주회로: MC-M은 L1·L2·L3을 U1·V1·W1에, MC-Y는 U2·V2·W2를 한 점으로 묶고, MC-Δ는 권선을 Δ로 잇습니다. 유리한 결선은 L1 → U1·V2, L2 → V1·W2, L3 → W1·U2입니다(Siemens).',
  '과부하계전기를 권선과 직렬(MC-M 뒤)에 두면 정격전류의 0.58배로 맞춥니다. Y-Δ는 Δ 정격전압이 전원 전압과 같은 전동기에만 씁니다.',
];

const _readNotes = [
  'a접점(Normal Open): 평소 열림, 코일이 여자되거나 버튼을 누르면 닫힘. 그림에서 막대 둘.',
  'b접점(Normal Close): 평소 닫힘, 동작하면 열림. 그림에서 막대 둘에 빗금.',
  '보조접점 번호: 끝자리 3-4는 a접점(13-14), 1-2는 b접점(21-22). 과부하계전기는 95-96이 b, 97-98이 a. 코일 단자는 A1-A2.',
  '왼쪽 모선에서 오른쪽 모선까지 닫힌 접점으로 이어지면 그 줄의 코일이 여자됩니다. 그림에서 굵은 색 선이 전기가 통하는 길입니다.',
];

class _LadderTab extends StatefulWidget {
  const _LadderTab({
    required this.circuit,
    required this.steps,
    required this.keyPrefix,
  });

  final LadderCircuit circuit;
  final List<String> steps;
  final String keyPrefix;

  @override
  State<_LadderTab> createState() => _LadderTabState();
}

class _LadderTabState extends State<_LadderTab>
    with AutomaticKeepAliveClientMixin<_LadderTab> {
  static const _timerSec = 3;
  late Map<String, bool> _s = solve(widget.circuit, {});
  final List<String> _log = [];
  Timer? _timer;
  int _left = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _name(String tag) {
    for (final (t, n) in [...widget.circuit.buttons, ...widget.circuit.toggles]) {
      if (t == tag) return n;
    }
    return tag;
  }

  void _addLog(String line) {
    _log.insert(0, line);
    if (_log.length > 8) _log.removeLast();
  }

  /// 타이머 코일이 켜져 있고 아직 다 안 찼으면 시간을 잰다.
  void _syncTimer() {
    final t = widget.circuit.timerTag;
    if (t == null) return;
    final on = _s[t] ?? false, done = _s['$t.done'] ?? false;
    if (on && !done && _timer == null) {
      _left = _timerSec;
      _timer = Timer.periodic(const Duration(seconds: 1), (tm) {
        if (!mounted) return;
        setState(() {
          _left -= 1;
          if (_left <= 0) {
            tm.cancel();
            _timer = null;
            final before = _s;
            _s = solve(widget.circuit, {..._s, '$t.done': true});
            final ch = describeChanges(widget.circuit, before, _s);
            _addLog('타이머 $_timerSec초 경과 → ${ch.join(' → ')}');
            _syncTimer();
          }
        });
      });
    } else if (!on && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  void _press(String tag) {
    final before = _s;
    final (pressed, released) = pressButton(widget.circuit, _s, tag);
    final a = describeChanges(widget.circuit, before, pressed);
    final b = describeChanges(widget.circuit, pressed, released);
    setState(() {
      _s = released;
      final name = _name(tag);
      _addLog(
        a.isEmpty
            ? '$name 누름 → 바뀐 것 없음(줄이 다른 접점으로 끊겨 있음)'
            : '$name 누름 → ${a.join(' → ')}',
      );
      if (b.isNotEmpty) {
        _addLog('$name 뗌 → ${b.join(' → ')}');
      } else if (a.any((x) => x.endsWith('여자'))) {
        _addLog('$name 뗌 → 그대로 유지(자기유지 접점이 대신 이어 줌)');
      }
      _syncTimer();
    });
  }

  void _toggle(String tag) {
    final before = _s;
    setState(() {
      _s = solve(widget.circuit, {..._s, tag: !(_s[tag] ?? false)});
      final ch = describeChanges(widget.circuit, before, _s);
      final on = _s[tag] ?? false;
      _addLog(
        '${_name(tag)} ${on ? "동작" : "리셋"}${ch.isEmpty ? "" : " → ${ch.join(' → ')}"}',
      );
      _syncTimer();
    });
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _s = solve(widget.circuit, {});
      _log.clear();
    });
  }

  Widget _card(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: fc.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: fc.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: fc.text)),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );

  Widget _line(String s, {int? n}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      n == null ? '· $s' : '$n. $s',
      style: TextStyle(fontSize: 14, height: 1.45, color: fc.text),
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = widget.circuit;
    final size = ladderSize(c);
    final p = widget.keyPrefix;
    final t = c.timerTag;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      children: [
        _card(c.title, [
          LayoutBuilder(
            builder: (context, box) {
              final paint = CustomPaint(
                key: Key('${p}_ladder'),
                size: size,
                painter: LadderPainter(
                  circuit: c,
                  state: _s,
                  live: fc.brand,
                  dead: fc.textFaint,
                  text: fc.text,
                  surface: fc.surface,
                ),
              );
              // 넓은 화면은 폭에 맞춰 키우고(최대 1.6배), 좁은 화면은 옆으로 밀어 봅니다.
              if (box.maxWidth >= size.width) {
                final k = (box.maxWidth / size.width).clamp(1.0, 1.6);
                return SizedBox(
                  width: size.width * k,
                  height: size.height * k,
                  child: FittedBox(child: paint),
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: paint,
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (tag, name) in c.buttons)
                FilledButton(
                  key: Key('${p}_btn_$tag'),
                  onPressed: () => _press(tag),
                  child: Text('$name 누르기'),
                ),
              for (final (tag, name) in c.toggles)
                OutlinedButton(
                  key: Key('${p}_tgl_$tag'),
                  onPressed: () => _toggle(tag),
                  child: Text((_s[tag] ?? false) ? '$name 리셋' : name),
                ),
              TextButton(
                key: Key('${p}_reset'),
                onPressed: _reset,
                child: const Text('처음으로'),
              ),
            ],
          ),
          if (t != null && (_s[t] ?? false) && !(_s['$t.done'] ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '타이머 재는 중: $_left초 남음 (실제 설정은 기동 시간에 맞춥니다)',
                key: Key('${p}_timer'),
                style: TextStyle(fontWeight: FontWeight.w800, color: fc.brand),
              ),
            ),
        ]),
        _card('방금 일어난 일', [
          if (_log.isEmpty)
            Text(
              '위 버튼을 눌러 보십시오. 누를 때마다 바뀐 코일과 램프가 순서대로 나옵니다.',
              style: TextStyle(color: fc.textSub),
            )
          else
            for (final l in _log)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  l,
                  key: Key('${p}_log_${_log.indexOf(l)}'),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: _log.indexOf(l) == 0 ? fc.text : fc.textSub,
                    fontWeight: _log.indexOf(l) == 0 ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
        ]),
        _card('동작 순서', [
          for (var i = 0; i < widget.steps.length; i++) _line(widget.steps[i], n: i + 1),
        ]),
        _card('회로 읽는 법', [for (final s in _readNotes) _line(s)]),
      ],
    );
  }
}

class _WiringTab extends StatefulWidget {
  const _WiringTab();

  @override
  State<_WiringTab> createState() => _WiringTabState();
}

class _WiringTabState extends State<_WiringTab> {
  bool _delta = false;

  Widget _line(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text('· $s', style: TextStyle(fontSize: 14, height: 1.45, color: fc.text)),
  );

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
    children: [
      Wrap(
        spacing: 8,
        children: [
          for (final (k, label, d) in [('cr_y', 'Y 결선', false), ('cr_d', 'Δ 결선', true)])
            ChoiceChip(
              key: Key(k),
              label: Text(label),
              selected: _delta == d,
              selectedColor: fc.brand,
              checkmarkColor: fc.onBrand,
              labelStyle: TextStyle(
                color: _delta == d ? fc.onBrand : fc.text,
                fontWeight: FontWeight.w800,
              ),
              onSelected: (_) => setState(() => _delta = d),
            ),
        ],
      ),
      const SizedBox(height: 8),
      AspectRatio(
        aspectRatio: 1.6,
        child: CustomPaint(
          key: const Key('cr_box'),
          painter: TerminalBoxPainter(
            delta: _delta,
            text: fc.text,
            surface: fc.surface,
            accent: fc.brand,
          ),
        ),
      ),
      const SizedBox(height: 8),
      if (_delta) ...[
        _line('Δ: 연결편 셋을 세로로 U1-W2, V1-U2, W1-V2에 겁니다. 권선 하나에 선간전압이 그대로 걸립니다.'),
        _line('명판 "Δ/Y 220/380 V"면 220 V 전원에 Δ로 씁니다.'),
      ] else ...[
        _line('Y: 연결편 둘로 아래 줄 W2·U2·V2를 한데 묶습니다. 권선 하나에 선간전압 ÷ √3이 걸립니다.'),
        _line('명판 "Δ/Y 220/380 V"면 380 V 전원에 Y로 씁니다.'),
      ],
      _line('권선은 U1-U2, V1-V2, W1-W2 셋입니다. 연결편을 떼면 상마다 권선 저항·절연저항을 따로 측정할 수 있습니다.'),
      _line('단자 표기: U1·V1·W1·U2·V2·W2 = (옛 표기) U·V·W·X·Y·Z = (NEMA) T1~T6. X = U2, Y = V2, Z = W2입니다.'),
      _line('L1·L2·L3을 U1·V1·W1에 물리면 축 쪽에서 볼 때 시계 방향으로 돕니다. 아무 두 상이나 바꾸면 반대로 돕니다. 명판 화살표가 우선입니다.'),
      _line('Y-Δ 기동을 하려면 연결편을 모두 떼고 여섯 단자를 기동반으로 뺍니다. Δ 정격전압이 전원 전압과 같아야 합니다(380 V 전원이면 Δ 380 V 정격).'),
    ],
  );
}
