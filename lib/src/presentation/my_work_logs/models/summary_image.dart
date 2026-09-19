import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'project_phase.dart';
import 'report_style.dart';
import 'report_tools.dart';

// 🚀 [현황 요약 이미지] 카톡 대화창에 그대로 올리기 좋은 한 장짜리(1080x1350) 프로젝트
// 현황 카드를 그린다: 진행률, 납기, 단계, 최근 일보, 이슈/자재 현황.
// 위젯 트리를 거치지 않고 캔버스에 직접 그려서 화면 밖에서도 만들 수 있다.
const _teal = Color(0xFF007580);
const _text = Color(0xFF191F28);
const _sub = Color(0xFF8B95A1);
const _red = Color(0xFFF04438);
const _green = Color(0xFF1D8A4E);

Future<File> createSummaryImage(Map<String, dynamic> log) async {
  const w = 1080.0, h = 1350.0, pad = 64.0;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, const Rect.fromLTWH(0, 0, w, h));
  c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);

  TextPainter tp(
    String t,
    double size, {
    Color color = _text,
    FontWeight weight = FontWeight.w500,
    double maxWidth = w - pad * 2,
    int maxLines = 1,
    TextAlign align = TextAlign.left,
  }) {
    final p = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          fontFamily: 'NotoSansKR',
          fontSize: size,
          color: color,
          fontWeight: weight,
          height: 1.25,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    return p;
  }

  final st = ReportStyle.current;
  final progress = projectProgress(log);
  final due = projectDue(log);
  final cur = currentPhase(log);
  final today = dayOnly(DateTime.now());
  final int? diff = due?.difference(today).inDays;

  // ── 머리 띠 ──
  c.drawRect(const Rect.fromLTWH(0, 0, w, 150), Paint()..color = _teal);
  final head = st.company.isEmpty ? '작업 현황' : st.company;
  tp(
    head,
    40,
    color: Colors.white,
    weight: FontWeight.w800,
  ).paint(c, const Offset(pad, 34));
  tp(
    '${today.year}.${today.month}.${today.day} 기준${st.manager.isEmpty ? '' : '  ·  담당 ${st.manager}'}',
    28,
    color: const Color(0xCCFFFFFF),
  ).paint(c, const Offset(pad, 92));

  double y = 190;

  // ── 프로젝트명 ──
  final name = tp(
    log['name']?.toString() ?? '프로젝트',
    58,
    weight: FontWeight.w900,
    maxLines: 2,
  );
  name.paint(c, Offset(pad, y));
  y += name.height + 6;
  final type = log['workType']?.toString() ?? '';
  if (type.isNotEmpty) {
    tp(type, 28, color: _sub).paint(c, Offset(pad, y));
    y += 44;
  }
  y += 14;

  // ── 진행률 + 납기 ──
  final pct = tp(
    '${(progress * 100).round()}%',
    130,
    color: progress >= 1 ? _green : _teal,
    weight: FontWeight.w900,
  );
  pct.paint(c, Offset(pad, y));
  if (diff != null) {
    final label = diff == 0
        ? 'D-Day'
        : diff > 0
        ? '납기 D-$diff'
        : '납기 D+${-diff}';
    final color = diff < 0 && progress < 1
        ? _red
        : (diff <= 7 ? const Color(0xFFC77700) : _teal);
    final t = tp(label, 40, color: color, weight: FontWeight.w900);
    final bw = t.width + 56;
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(w - pad - bw, y + 34, bw, 76),
      const Radius.circular(38),
    );
    c.drawRRect(rr, Paint()..color = color.withValues(alpha: 0.12));
    t.paint(c, Offset(w - pad - bw + 28, y + 34 + (76 - t.height) / 2));
  }
  y += pct.height + 10;
  // 막대
  const barW = w - pad * 2;
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(pad, y, barW, 26),
      const Radius.circular(13),
    ),
    Paint()..color = const Color(0xFFEDEFF2),
  );
  if (progress > 0) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pad, y, (barW * progress).clamp(26.0, barW), 26),
        const Radius.circular(13),
      ),
      Paint()..color = progress >= 1 ? _green : _teal,
    );
  }
  y += 26 + 26;
  if (cur != null) {
    tp(
      '현재 단계: ${cur['name']}',
      32,
      color: _teal,
      weight: FontWeight.w800,
    ).paint(c, Offset(pad, y));
    y += 52;
  }

  // ── 단계 칩 ──
  final phases = phasesOf(log);
  if (phases.isNotEmpty) {
    double x = pad;
    for (final p in phases) {
      final done = phaseIsDone(log, p);
      final isCur = cur != null && cur['id'] == p['id'];
      final color = done ? _green : (isCur ? _teal : _sub);
      final t = tp(
        p['name'].toString(),
        26,
        color: isCur ? Colors.white : color,
        weight: FontWeight.w800,
      );
      final bw = t.width + 40;
      if (x + bw > w - pad) {
        x = pad;
        y += 62;
      }
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, bw, 50),
        const Radius.circular(25),
      );
      c.drawRRect(
        r,
        Paint()..color = isCur ? _teal : color.withValues(alpha: 0.14),
      );
      t.paint(c, Offset(x + 20, y + (50 - t.height) / 2));
      x += bw + 12;
    }
    y += 50 + 34;
  }

  // ── 최근 일보 ──
  c.drawLine(
    Offset(pad, y),
    Offset(w - pad, y),
    Paint()
      ..color = const Color(0xFFEDEFF2)
      ..strokeWidth = 2,
  );
  y += 26;
  tp('최근 작업', 32, weight: FontWeight.w900).paint(c, Offset(pad, y));
  y += 54;
  final reports =
      (log['daily_reports'] as List? ?? []).whereType<Map>().toList()
        ..sort((a, b) => reportDateOf(b).compareTo(reportDateOf(a)));
  if (reports.isEmpty) {
    tp('아직 작성된 일보가 없어요.', 28, color: _sub).paint(c, Offset(pad, y));
    y += 50;
  }
  for (final r in reports.take(3)) {
    final note = (r['note']?.toString() ?? '').trim();
    final line = (note.isEmpty || note == '특이사항 없음')
        ? (r['materials_used']?.toString() ?? '특이사항 없음')
        : note.split('\n').first;
    final d = reportDateOf(r);
    tp(
      '${d.month}/${d.day}',
      30,
      color: _teal,
      weight: FontWeight.w900,
    ).paint(c, Offset(pad, y));
    final t = tp(
      '${r['worker_count'] ?? 1}명 · $line',
      30,
      maxWidth: w - pad * 2 - 130,
      maxLines: 2,
    );
    t.paint(c, Offset(pad + 130, y));
    y += (t.height < 48 ? 48 : t.height) + 18;
  }

  // ── 하단 현황 ──
  y = y < 1130 ? 1130 : y + 10;
  final issues = unresolvedIssueCount(log);
  final urgent = (log['punch_lists'] as List? ?? [])
      .whereType<Map>()
      .where((p) => p['is_completed'] != true && p['priority'] == '긴급')
      .length;
  final lateMat = schedulesOf(
    log,
  ).where((s) => isMaterialSchedule(s) && materialState(s) == 'late').length;
  final delay = delayedPhase(log);

  _StatBox box(String label, String value, Color color, double x) =>
      _StatBox(label, value, color, x);
  final boxes = [
    box(
      '미해결 이슈',
      '$issues건${urgent > 0 ? ' (긴급 $urgent)' : ''}',
      issues > 0 ? _red : _green,
      pad,
    ),
    box('자재 입고 지연', '$lateMat건', lateMat > 0 ? _red : _green, pad + 300),
    box(
      '일정',
      delay == null ? '정상' : '${delay.phase['name']} ${delay.days}일 지연',
      delay == null ? _green : _red,
      pad + 600,
    ),
  ];
  for (final b in boxes) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(b.x, y, 290, 130),
        const Radius.circular(22),
      ),
      Paint()..color = b.color.withValues(alpha: 0.1),
    );
    tp(
      b.label,
      24,
      color: _sub,
      weight: FontWeight.w700,
      maxWidth: 260,
    ).paint(c, Offset(b.x + 20, y + 18));
    tp(
      b.value,
      34,
      color: b.color,
      weight: FontWeight.w900,
      maxWidth: 260,
      maxLines: 2,
    ).paint(c, Offset(b.x + 20, y + 56));
  }

  final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/report_summary_${DateTime.now().millisecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(data!.buffer.asUint8List());
  return file;
}

class _StatBox {
  final String label;
  final String value;
  final Color color;
  final double x;
  _StatBox(this.label, this.value, this.color, this.x);
}
