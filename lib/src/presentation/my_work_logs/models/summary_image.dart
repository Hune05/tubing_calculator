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
const _text = Color(0xFF191F28);
const _sub = Color(0xFF8B95A1);
const _red = Color(0xFFF04438);
const _green = Color(0xFF1D8A4E);

Future<File> createSummaryImage(Map<String, dynamic> log) async {
  const w = 1080.0, pad = 64.0;
  // 최근 일보의 가장 최근 사진 한 장을 대표 사진으로 쓴다.
  ui.Image? hero;
  final sorted = (log['daily_reports'] as List? ?? []).whereType<Map>().toList()
    ..sort((a, b) => reportDateOf(b).compareTo(reportDateOf(a)));
  for (final r in sorted) {
    final imgs = (r['image_paths'] as List? ?? []);
    if (imgs.isEmpty) continue;
    final bytes = await loadPhotoBytes(imgs.first.toString());
    if (bytes == null) continue;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      hero = (await codec.getNextFrame()).image;
      break;
    } catch (_) {}
  }
  final h = hero == null ? 1350.0 : 1690.0;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Rect.fromLTWH(0, 0, w, h));
  c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);

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
  // 프로젝트마다 고정된 색(목록/달력과 같은 색)을 테마로 쓴다.
  final theme = colorForProject(
    log['id']?.toString() ?? log['name']?.toString() ?? '',
  );
  final company = headerOverride(log, 'company') ?? st.company;
  final manager = headerOverride(log, 'manager') ?? st.manager;
  final progress = projectProgress(log);
  final due = projectDue(log);
  final cur = currentPhase(log);
  final today = dayOnly(DateTime.now());
  final int? diff = due?.difference(today).inDays;

  // ── 머리 띠 ──
  c.drawRect(const Rect.fromLTWH(0, 0, w, 150), Paint()..color = theme);
  final head = company.isEmpty ? '작업 현황' : company;
  tp(
    head,
    40,
    color: Colors.white,
    weight: FontWeight.w800,
  ).paint(c, const Offset(pad, 34));
  tp(
    '${today.year}.${today.month}.${today.day} 기준${manager.isEmpty ? '' : '  ·  담당 ${manager}'}',
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
    color: progress >= 1 ? _green : theme,
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
        : (diff <= 7 ? const Color(0xFFC77700) : theme);
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
      Paint()..color = progress >= 1 ? _green : theme,
    );
  }
  y += 26 + 26;
  if (cur != null) {
    tp(
      '현재 단계: ${cur['name']}',
      32,
      color: theme,
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
      final color = done ? _green : (isCur ? theme : _sub);
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
        Paint()..color = isCur ? theme : color.withValues(alpha: 0.14),
      );
      t.paint(c, Offset(x + 20, y + (50 - t.height) / 2));
      x += bw + 12;
    }
    y += 50 + 34;
  }

  // ── 대표 사진 ──
  if (hero != null) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(pad, y, w - pad * 2, 340),
      const Radius.circular(24),
    );
    c.save();
    c.clipRRect(r);
    paintImage(canvas: c, rect: r.outerRect, image: hero, fit: BoxFit.cover);
    c.restore();
    y += 340 + 34;
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
    tp('아직 작성된 일보가 없습니다.', 28, color: _sub).paint(c, Offset(pad, y));
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
      color: theme,
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
  y = y < h - 220 ? h - 220 : y + 10;
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

// 🚀 [오늘의 전체 현황 이미지] 진행중인 프로젝트들을 한 장에 모은다(최대 8개).
Future<File> createOverviewImage(List<Map<String, dynamic>> logs) async {
  final active = logs.where((l) => l['status'] != 'DONE').take(8).toList();
  const w = 1080.0, pad = 64.0, rowH = 176.0;
  final h = 230 + (active.isEmpty ? 1 : active.length) * rowH + 90;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Rect.fromLTWH(0, 0, w, h));
  c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);

  TextPainter tp(
    String t,
    double size, {
    Color color = _text,
    FontWeight weight = FontWeight.w500,
    double maxWidth = w - pad * 2,
  }) => TextPainter(
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
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);

  final st = ReportStyle.current;
  final today = dayOnly(DateTime.now());
  const head = Color(0xFF007580);
  c.drawRect(Rect.fromLTWH(0, 0, w, 170), Paint()..color = head);
  tp(
    st.company.isEmpty ? '오늘의 전체 현황' : st.company,
    40,
    color: Colors.white,
    weight: FontWeight.w800,
  ).paint(c, const Offset(pad, 36));
  tp(
    '${today.year}.${today.month}.${today.day} 기준 · 진행중 ${active.length}건',
    28,
    color: const Color(0xCCFFFFFF),
  ).paint(c, const Offset(pad, 100));

  double y = 210;
  if (active.isEmpty) {
    tp('진행중인 프로젝트가 없습니다.', 30, color: _sub).paint(c, Offset(pad, y));
  }
  for (final l in active) {
    final color = colorForProject(
      l['id']?.toString() ?? l['name']?.toString() ?? '',
    );
    final progress = projectProgress(l);
    final due = projectDue(l);
    final cur = currentPhase(l);
    final diff = due?.difference(today).inDays;
    final issues = unresolvedIssueCount(l);
    final delay = delayedPhase(l);

    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pad, y, 12, rowH - 24),
        const Radius.circular(6),
      ),
      Paint()..color = color,
    );
    tp(
      l['name']?.toString() ?? '이름 없음',
      36,
      weight: FontWeight.w900,
      maxWidth: 640,
    ).paint(c, Offset(pad + 34, y));
    final pct = tp(
      '${(progress * 100).round()}%',
      40,
      color: progress >= 1 ? _green : color,
      weight: FontWeight.w900,
    );
    pct.paint(c, Offset(w - pad - pct.width, y - 2));
    // 막대
    const bx = pad + 34, bw = w - pad * 2 - 34;
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(bx, 0, bw, 16).shift(Offset(0, y + 62)),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFEDEFF2),
    );
    if (progress > 0) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, y + 62, (bw * progress).clamp(16.0, bw), 16),
          const Radius.circular(8),
        ),
        Paint()..color = progress >= 1 ? _green : color,
      );
    }
    final info = [
      if (cur != null) '${cur['name']}',
      if (diff != null)
        diff == 0
            ? 'D-Day'
            : diff > 0
            ? 'D-$diff'
            : 'D+${-diff}',
      if (issues > 0) '이슈 $issues',
      if (delay != null) '${delay.phase['name']} ${delay.days}일 지연',
    ].join('  ·  ');
    tp(
      info.isEmpty ? '진행 정보 없음' : info,
      28,
      color: delay != null || (diff != null && diff < 0) ? _red : _sub,
      weight: FontWeight.w700,
      maxWidth: w - pad * 2 - 34,
    ).paint(c, Offset(pad + 34, y + 92));
    y += rowH;
  }

  final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/report_overview_${DateTime.now().millisecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(data!.buffer.asUint8List());
  return file;
}
