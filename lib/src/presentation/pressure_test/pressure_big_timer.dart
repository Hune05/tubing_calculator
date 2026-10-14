// 압력 시험 유지시간 타이머 크게 보기(10-15): 벤딩 현장 탭 "한 단계씩"처럼 한 화면 가득.
// 경과 시간을 화면 폭에 맞춰 아주 크게, 남은 시간·진행 막대·완료 예정 시각, 시험압력·직전 측정·강하,
// 아래에 큰 단추(시작 / 측정 추가·종료). 화면이 꺼지지 않고(시험 동안 게이지 옆에 세워 두는 용도),
// 위아래 시스템 막대를 숨긴다. 입력 창·알람·저장은 시험 기록 탭의 것을 그대로 부른다.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/common_widgets/app_frame.dart' show kAppSystemUiMode;
import '../../core/theme/field_view.dart';
import '../../core/utils/app_settings_controller.dart';
import 'pressure_units.dart';
import 'test_record.dart';

/// 크게 보기에 그릴 값(1초마다 다시 읽는다).
class PtBigTimerData {
  final DateTime? start;
  final DateTime? end;
  final double holdMin;
  final String line; // 라인 번호(없으면 빈 글)
  final String? design; // 설계압력 글
  final String? target; // 시험압력 글
  final String? startP; // 시작 압력 글(10-15 사용자: 직전 대신 시작 압력)
  final String? startSub; // 시작 시각·온도
  final String? last; // 직전 측정 글(압력)
  final DateTime? lastAt;
  final String? drop; // 시작에서 직전 측정까지 강하 글
  final int reads;
  final DateTime? stabAt; // 안정화 시작(10-15). 시작 전이면 안정화 모양
  final double stabMin;
  const PtBigTimerData({
    required this.start,
    required this.end,
    required this.holdMin,
    this.line = '',
    this.design,
    this.target,
    this.startP,
    this.startSub,
    this.last,
    this.lastAt,
    this.drop,
    this.reads = 0,
    this.stabAt,
    this.stabMin = 0,
  });
}

class PtBigTimerPage extends StatefulWidget {
  final PtBigTimerData Function() data;
  final Future<void> Function() onStart;

  /// 안정화 시작(안정화 시간을 골랐을 때 시작 전 단추, 10-15).
  final Future<void> Function()? onStab;
  final Future<void> Function() onAdd;
  final Future<void> Function() onEnd;

  /// 완료 시각이 지나 울리는 알림 끄기.
  final Future<void> Function() onStopAlarm;
  final DateTime Function() now;

  /// 시험에서는 화면 꺼짐 방지·시스템 막대 바꾸기를 하지 않는다.
  final bool system;
  const PtBigTimerPage({
    super.key,
    required this.data,
    required this.onStart,
    this.onStab,
    required this.onAdd,
    required this.onEnd,
    required this.onStopAlarm,
    required this.now,
    this.system = true,
  });

  @override
  State<PtBigTimerPage> createState() => _PtBigTimerPageState();
}

class _PtBigTimerPageState extends State<PtBigTimerPage> {
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (widget.system) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      WakelockPlus.enable();
    }
    // 이미 완료 시각이 지나 울리고 있으면 이 화면을 연 것으로 멈춘다(기록 탭과 같은 규칙).
    widget.onStopAlarm();
  }

  @override
  void dispose() {
    _tick?.cancel();
    if (widget.system) {
      SystemChrome.setEnabledSystemUIMode(kAppSystemUiMode);
      WakelockPlus.toggle(enable: AppSettingsController().keepScreenOn);
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) async {
    if (_busy) return;
    _busy = true;
    try {
      await f();
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data();
    final s = d.start, e = d.end;
    final now = widget.now();
    // 안정화 중(10-15): 시계는 안정화 경과, 막대·글은 안정화 기준.
    final stab = d.stabAt != null && s == null;
    final stabHold = Duration(milliseconds: (d.stabMin * 60000).round());
    final stabDue = d.stabAt?.add(stabHold);
    final stabDone = stab && !now.isBefore(stabDue!);
    final elapsed = stab ? now.difference(d.stabAt!) : (s == null ? Duration.zero : (e ?? now).difference(s));
    final hold = Duration(milliseconds: (d.holdMin * 60000).round());
    final done = !stab && s != null && elapsed >= hold;
    final running = s != null && e == null;
    final frac = stab
        ? (stabHold.inMilliseconds <= 0 ? 1.0 : (elapsed.inMilliseconds / stabHold.inMilliseconds).clamp(0.0, 1.0))
        : (s == null || hold.inMilliseconds <= 0 ? 0.0 : (elapsed.inMilliseconds / hold.inMilliseconds).clamp(0.0, 1.0));
    final due = s?.add(hold);
    final Color main = stab ? fc.text : (e != null && !done ? fc.danger : (done ? fc.brand : fc.text));
    final status = stab
        ? (stabDone ? '안정화 끝' : '안정화 중')
        : s == null ? '시작 전' : (e != null ? (done ? '종료 · 유지시간 채움' : '종료 · 유지시간 못 채움') : (done ? '유지시간 완료' : '유지 중'));
    final remain = stab
        ? (stabDone ? '게이지를 읽고 [시작]' : '안정화 남은 ${ptClock(stabDue!.difference(now))}')
        : s == null
        ? '유지시간 ${ptFmt(d.holdMin, 1)}분'
        : (done ? '유지시간 ${ptFmt(d.holdMin, 1)}분 완료' : (e != null ? '유지시간 ${ptFmt(d.holdMin, 1)}분 미만' : '남은 ${ptClock(hold - elapsed)}'));

    final clock = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        ptClock(elapsed),
        key: const Key('pt_big_elapsed'),
        maxLines: 1,
        style: TextStyle(
          fontSize: 200,
          height: 1.0,
          fontWeight: FontWeight.w900,
          color: main,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    final remainText = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        remain,
        key: const Key('pt_big_remain'),
        maxLines: 1,
        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: stab ? (stabDone ? fc.brand : fc.caution) : (done ? fc.brand : fc.textSub)),
      ),
    );
    final bar = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 14,
            backgroundColor: fc.line,
            valueColor: AlwaysStoppedAnimation(stab ? (stabDone ? fc.brand : fc.caution) : (done ? fc.brand : fc.caution)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          [
            if (stab) '안정화 ${ptFmt(d.stabMin, 1)}분 · 시작 ${ptHm(d.stabAt!)} · 끝 예정 ${ptHm(stabDue!)}' else ...[
            '유지 ${ptFmt(d.holdMin, 1)}분',
            if (s != null) '시작 ${ptHm(s)}',
            if (running && due != null) '완료 예정 ${ptHm(due)}',
            if (e != null) '종료 ${ptHm(e)}',
            ],
          ].join(' · '),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fc.textSub),
        ),
      ],
    );
    Widget info(String k, String? v, {String? sub, Key? key}) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: fc.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: fc.line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(k, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fc.textSub)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(v ?? '—', key: key, maxLines: 1, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: fc.text)),
            ),
            if (sub != null) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: fc.textSub)),
          ],
        ),
      ),
    );
    // 2 × 2: 위 줄 설계·시험압력(정해진 값), 아래 줄 시작 압력·강하(잰 값). 10-15 사용자: 설계·시험압력도 보이게.
    final infos = Column(
      children: [
        Row(
          children: [
            info('설계압력', d.design, key: const Key('pt_big_design')),
            const SizedBox(width: 8),
            info('시험압력', d.target, key: const Key('pt_big_target')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            info('시작 압력', d.startP, sub: d.startSub, key: const Key('pt_big_start_p')),
            const SizedBox(width: 8),
            info('강하', d.drop, sub: d.drop == null || d.lastAt == null ? null : '시작 → ${ptHm(d.lastAt!)} 측정', key: const Key('pt_big_drop')),
          ],
        ),
      ],
    );

    ButtonStyle big(bool primary) => (primary
            ? FilledButton.styleFrom(backgroundColor: fc.brand, foregroundColor: fc.onBrand)
            : OutlinedButton.styleFrom(foregroundColor: fc.brand, side: BorderSide(color: fc.brand, width: 1.6)))
        .copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(0, 64)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        );
    final ringing = running && done;
    final buttons = stab
        ? [
            Expanded(
              child: FilledButton(
                key: const Key('pt_big_start'),
                style: big(true),
                onPressed: () => _run(widget.onStart),
                child: Text(stabDone ? '압력 확인하고 시작' : '지금 시작'),
              ),
            ),
          ]
        : s == null && d.stabMin > 0 && widget.onStab != null
        ? [
            Expanded(
              child: FilledButton(
                key: const Key('pt_big_stab'),
                style: big(true),
                onPressed: () => _run(widget.onStab!),
                child: Text('안정화 시작 (${ptFmt(d.stabMin, 1)}분)'),
              ),
            ),
          ]
        : s == null
        ? [Expanded(child: FilledButton(key: const Key('pt_big_start'), style: big(true), onPressed: () => _run(widget.onStart), child: const Text('시작')))]
        : running
        ? [
            Expanded(child: OutlinedButton(key: const Key('pt_big_add'), style: big(false), onPressed: () => _run(widget.onAdd), child: const Text('측정 추가'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(key: const Key('pt_big_end'), style: big(true), onPressed: () => _run(widget.onEnd), child: const Text('종료'))),
          ]
        : [Expanded(child: OutlinedButton(key: const Key('pt_big_close2'), style: big(false), onPressed: () => Navigator.pop(context), child: const Text('닫기')))];

    final top = Row(
      children: [
        IconButton(
          key: const Key('pt_big_close'),
          tooltip: '작게 보기',
          icon: Icon(Icons.close_fullscreen_rounded, color: fc.text, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            d.line.trim().isEmpty ? '유지시간 타이머' : d.line.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: fc.text),
          ),
        ),
        Container(
          key: const Key('pt_big_status'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: (stab ? (stabDone ? fc.brand : fc.caution) : main).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
          child: Text(status, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: stab ? (stabDone ? fc.brand : fc.caution) : main)),
        ),
        if (ringing) ...[
          const SizedBox(width: 6),
          IconButton(
            key: const Key('pt_big_alarm_off'),
            tooltip: '알람 끄기',
            icon: Icon(Icons.notifications_off_rounded, color: fc.brand, size: 28),
            onPressed: () => _run(widget.onStopAlarm),
          ),
        ],
      ],
    );

    return FieldViewTheme(
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: fc.background,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth > box.maxHeight;
                if (wide) {
                  // 가로: 왼쪽 큰 시계, 오른쪽 값·단추
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
                    child: Column(
                      children: [
                        top,
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                flex: 6,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Flexible(child: clock),
                                      remainText,
                                      const SizedBox(height: 10),
                                      bar,
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    infos,
                                    const SizedBox(height: 14),
                                    Row(children: buttons),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                // 세로: 위 시계(가운데 크게), 아래 값·단추
                return Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 16),
                  child: Column(
                    children: [
                      top,
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: math.min(box.maxHeight * 0.28, box.maxWidth * 0.42), child: clock),
                              remainText,
                              const SizedBox(height: 18),
                              bar,
                            ],
                          ),
                        ),
                      ),
                      Padding(padding: const EdgeInsets.only(left: 8), child: infos),
                      const SizedBox(height: 14),
                      Padding(padding: const EdgeInsets.only(left: 8), child: Row(children: buttons)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
