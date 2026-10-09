// 도면 보기 화면: 두 손가락으로 확대·이동, 두 번 눌러 맞춤, 쪽 넘기기. 도구로 확인·틀림·질문·문제 핀·
// 개정 구름·화살표·네모·펜·글을 올리고, 문제 목록에서 해결 표시·카톡 보내기·PDF 내보내기를 한다.
import 'package:tubing_calculator/src/core/common_widgets/snack_once.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/common_widgets/swipe_to_delete.dart';
import '../../core/theme/app_icon_set.dart';
import '../../core/theme/app_tokens.dart';
import '../steel_cutting/screens/steel_pdf_preview_page.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'drawing_export.dart';
import 'drawing_mark_painter.dart';
import 'drawing_models.dart';
import 'drawing_store.dart';
import 'package:tubing_calculator/src/core/utils/error_text.dart';

Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

/// 도구: null이면 보기(이동).
enum _Tool { pan, ok, wrong, question, issue, cloud, arrow, rect, pen, text }

extension on _Tool {
  MarkKind? get kind => switch (this) {
    _Tool.pan => null,
    _Tool.ok => MarkKind.ok,
    _Tool.wrong => MarkKind.wrong,
    _Tool.question => MarkKind.question,
    _Tool.issue => MarkKind.issue,
    _Tool.cloud => MarkKind.cloud,
    _Tool.arrow => MarkKind.arrow,
    _Tool.rect => MarkKind.rect,
    _Tool.pen => MarkKind.pen,
    _Tool.text => MarkKind.text,
  };
  IconData get icon => switch (this) {
    _Tool.pan => LucideIcons.hand,
    _Tool.ok => LucideIcons.checkCircle2,
    _Tool.wrong => LucideIcons.xCircle,
    _Tool.question => LucideIcons.helpCircle,
    _Tool.issue => LucideIcons.mapPin,
    _Tool.cloud => LucideIcons.cloud,
    _Tool.arrow => LucideIcons.moveUpRight,
    _Tool.rect => LucideIcons.square,
    _Tool.pen => LucideIcons.pencil,
    _Tool.text => LucideIcons.type,
  };
  String get label => this == _Tool.pan ? '보기' : kind!.label;
  bool get drag => this == _Tool.cloud || this == _Tool.arrow || this == _Tool.rect || this == _Tool.pen;
}

class DrawingViewerPage extends StatefulWidget {
  final DrawingDoc doc;

  /// 시험에서 바꾼다(파일 없이).
  final Future<List<DrawingMark>> Function(String id)? loadMarks;
  final Future<void> Function(DrawingDoc doc, List<DrawingMark> marks)? saveMarks;
  final Future<String> Function(DrawingDoc doc, int page)? pagePath;
  final Future<void> Function(String text) share;
  final DateTime Function()? now;

  const DrawingViewerPage({
    super.key,
    required this.doc,
    this.loadMarks,
    this.saveMarks,
    this.pagePath,
    this.share = _defaultShare,
    this.now,
  });

  @override
  State<DrawingViewerPage> createState() => _DrawingViewerPageState();
}

class _DrawingViewerPageState extends State<DrawingViewerPage> {
  late DrawingDoc _doc = widget.doc;
  List<DrawingMark> _marks = [];
  int _page = 0;
  String? _pageFile;
  bool _pageBusy = true;
  String? _pageError;
  _Tool _tool = _Tool.pan;
  MarkColor? _color; // null이면 도구마다 기본 색
  String? _selected;
  String _author = '';

  // 보기 변환: 화면 = 쪽 * _scale + _offset
  double _scale = 1;
  Offset _offset = Offset.zero;
  Size _view = Size.zero;
  bool _fitted = false;

  // 손가락
  final Map<int, Offset> _pts = {};
  double? _pinchDist;
  Offset? _pinchFocal;
  Offset? _downAt;
  bool _moved = false;
  DrawingMark? _draft;
  DateTime? _lastTap;

  DateTime get _now => (widget.now ?? DateTime.now)();

  Size get _pageSize {
    final s = _page < _doc.pageSizes.length ? _doc.pageSizes[_page] : (4000, 2828);
    return Size(s.$1.toDouble(), s.$2.toDouble());
  }

  @override
  void initState() {
    super.initState();
    (widget.loadMarks ?? DrawingStore.loadMarks)(_doc.id).then((v) {
      if (mounted) setState(() => _marks = v);
    });
    SharedPreferences.getInstance().then((p) {
      final n = (p.getString('user_real_name') ?? '').trim();
      if (mounted) _author = n == '로그인 필요' ? '' : n;
    });
    // 연 시각을 들고 있는 도면에도 넣는다(10-07: 표시 저장이 옛 열람 시각을 다시 써 목록 순서가 밀렸다).
    _doc = _doc.copyWith(openedAt: _now);
    if (widget.saveMarks == null) {
      DrawingStore.put(_doc);
    }
    _loadPage();
  }

  Future<void> _loadPage() async {
    setState(() {
      _pageBusy = true;
      _pageError = null;
    });
    try {
      final f = await (widget.pagePath ?? DrawingStore.ensurePage)(_doc, _page);
      if (!mounted) return;
      setState(() {
        _pageFile = f;
        _pageBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pageBusy = false;
        _pageError = loggedReason('도면 쪽 그리기', e);
      });
    }
  }

  Future<void> _persist() async {
    await (widget.saveMarks ?? DrawingStore.saveMarks)(_doc, _marks);
    _doc = _doc.copyWith(openIssues: openIssueCount(_marks));
  }

  void _fit() {
    if (_view.isEmpty) return;
    final ps = _pageSize;
    final s = math.min(_view.width / ps.width, _view.height / ps.height) * 0.97;
    setState(() {
      _scale = s;
      _offset = Offset((_view.width - ps.width * s) / 2, (_view.height - ps.height * s) / 2);
    });
  }

  Offset _toPage(Offset screen) => (screen - _offset) / _scale;
  (double, double) _norm(Offset page) {
    final ps = _pageSize;
    return ((page.dx / ps.width).clamp(0.0, 1.0), (page.dy / ps.height).clamp(0.0, 1.0));
  }

  double get _minScale {
    final ps = _pageSize;
    return math.min(_view.width / ps.width, _view.height / ps.height) * 0.5;
  }

  void _zoomAt(Offset focal, double factor) {
    final ns = (_scale * factor).clamp(_minScale, 8.0);
    final pagePt = _toPage(focal);
    setState(() {
      _scale = ns;
      _offset = focal - pagePt * ns;
    });
  }

  // ── 손가락 처리 ──

  void _down(PointerDownEvent e) {
    _pts[e.pointer] = e.localPosition;
    if (_pts.length == 2) {
      _draft = null; // 두 손가락이면 그리기를 멈추고 확대·이동
      final v = _pts.values.toList();
      _pinchDist = (v[0] - v[1]).distance;
      _pinchFocal = (v[0] + v[1]) / 2;
      setState(() {});
      return;
    }
    if (_pts.length == 1) {
      _downAt = e.localPosition;
      _moved = false;
      if (_tool.drag) {
        final kind = _tool.kind!;
        setState(() {
          _draft = DrawingMark(
            id: 'draft',
            page: _page,
            kind: kind,
            color: _color ?? defaultColorFor(kind),
            points: [_norm(_toPage(e.localPosition)), _norm(_toPage(e.localPosition))],
            createdAt: _now,
          );
        });
      }
    }
  }

  void _move(PointerMoveEvent e) {
    final prev = _pts[e.pointer];
    _pts[e.pointer] = e.localPosition;
    if (_pts.length >= 2) {
      final v = _pts.values.toList();
      final dist = (v[0] - v[1]).distance;
      final focal = (v[0] + v[1]) / 2;
      if (_pinchDist != null && _pinchFocal != null && _pinchDist! > 0) {
        final factor = dist / _pinchDist!;
        final ns = (_scale * factor).clamp(_minScale, 8.0);
        final pagePt = _toPage(_pinchFocal!);
        setState(() {
          _scale = ns;
          _offset = focal - pagePt * ns;
        });
      }
      _pinchDist = dist;
      _pinchFocal = focal;
      _moved = true;
      return;
    }
    if (prev == null) return;
    if (_downAt != null && (e.localPosition - _downAt!).distance > 8) _moved = true;
    if (_draft != null) {
      final p = _norm(_toPage(e.localPosition));
      setState(() {
        _draft = _draft!.copyWith(points: _draft!.kind == MarkKind.pen ? [..._draft!.points, p] : [_draft!.points.first, p]);
      });
    } else if (_tool == _Tool.pan || !_tool.drag) {
      if (_moved) setState(() => _offset += e.localPosition - prev);
    }
  }

  void _up(PointerEvent e) {
    final wasPinch = _pts.length >= 2;
    _pts.remove(e.pointer);
    if (_pts.length < 2) {
      _pinchDist = null;
      _pinchFocal = null;
    }
    if (wasPinch || _pts.isNotEmpty) {
      if (_pts.isEmpty) _draft = null;
      return;
    }
    final at = e.localPosition;
    if (_draft != null) {
      final d = _draft!;
      _draft = null;
      final ps = _pageSize;
      final a = Offset(d.points.first.$1 * ps.width, d.points.first.$2 * ps.height);
      final b = Offset(d.points.last.$1 * ps.width, d.points.last.$2 * ps.height);
      if ((a - b).distance * _scale < 12 && d.kind != MarkKind.pen) {
        setState(() {});
        return; // 너무 작으면 버린다
      }
      _add(d.kind, d.points);
      return;
    }
    if (_moved) return;
    // 눌렀다 뗌(탭)
    final now = DateTime.now();
    final dbl = _lastTap != null && now.difference(_lastTap!).inMilliseconds < 300;
    _lastTap = now;
    final pagePt = _toPage(at);
    if (_tool == _Tool.pan) {
      if (dbl) {
        _lastTap = null;
        _fit();
        return;
      }
      final hit = hitMark(_marks, _page, pagePt, _pageSize, slop: 14 / _scale, viewScale: _scale);
      setState(() => _selected = hit?.id);
      if (hit != null) _openMark(hit);
      return;
    }
    final kind = _tool.kind!;
    if (!_tool.drag) _add(kind, [_norm(pagePt)]);
  }

  Future<void> _add(MarkKind kind, List<(double, double)> pts) async {
    var text = '';
    if (kind.numbered || kind == MarkKind.text) {
      final t = await _askText(kind, '');
      if (t == null) {
        setState(() {});
        return; // 취소
      }
      text = t;
      if (kind == MarkKind.text && text.isEmpty) return;
    }
    final m = DrawingMark(
      id: '${_now.microsecondsSinceEpoch}',
      page: _page,
      kind: kind,
      color: _color ?? defaultColorFor(kind),
      points: pts,
      text: text,
      no: kind.numbered ? nextIssueNo(_marks) : 0,
      author: _author,
      createdAt: _now,
      history: [MarkEvent(_now, '만듦', _author)],
    );
    setState(() => _marks = [..._marks, m]);
    await _persist();
  }

  Future<String?> _askText(MarkKind kind, String initial) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TextSheet(
      title: kind == MarkKind.text ? '글 넣기' : '${kind.label} 내용',
      hint: switch (kind) {
        MarkKind.wrong => '예: 배관 사이즈 1/2" → 3/4" 틀림',
        MarkKind.question => '예: 밸브 방향 확인 필요',
        MarkKind.issue => '예: 서포트 간섭, 현장과 다름',
        _ => '글',
      },
      initial: initial,
      optional: kind != MarkKind.text,
    ),
  );

  Future<void> _openMark(DrawingMark m) async {
    final out = await showModalBottomSheet<_MarkAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MarkSheet(mark: m, pages: _doc.pages),
    );
    if (!mounted) return;
    if (out == null) {
      setState(() => _selected = null);
      return;
    }
    DrawingMark? next;
    switch (out.type) {
      case _ActType.delete:
        // 잘못 눌러 지웠을 때 "되돌리기"로 같은 표시(같은 번호·자리)를 다시 넣는다(10-02).
        final at = _marks.indexWhere((x) => x.id == m.id);
        setState(() {
          _marks = [for (final x in _marks) if (x.id != m.id) x];
          _selected = null;
        });
        await _persist();
        if (!mounted) return;
        showDeleteUndo(
          context,
          [m.kind.numbered ? '${m.kind.label} ${m.no}' : m.kind.label, if (m.text.trim().isNotEmpty) m.text.trim()].join(' '),
          onUndo: () {
            if (!mounted || _marks.any((x) => x.id == m.id)) return;
            setState(() {
              final next = [..._marks];
              next.insert(at < 0 ? next.length : at.clamp(0, next.length), m);
              _marks = next;
            });
            _persist();
          },
        );
        return;
      case _ActType.save:
        final events = [...m.history];
        if (out.text != m.text) events.add(MarkEvent(_now, '내용 고침', _author));
        if (out.done != m.done) events.add(MarkEvent(_now, out.done ? '해결' : '해결 취소', _author));
        if (out.color != m.color) events.add(MarkEvent(_now, '색 바꿈(${out.color.label})', _author));
        next = m.copyWith(text: out.text, done: out.done, color: out.color, history: events);
    }
    setState(() {
      _marks = [for (final x in _marks) x.id == m.id ? next! : x];
      _selected = null;
    });
    await _persist();
  }

  bool get _pageHasMarks => _marks.any((m) => m.page == _page);

  /// 이 쪽의 마지막 표시만 지운다(10-07: 이 쪽에 표시가 없으면 다른 쪽 표시를 알림 없이 지웠다).
  void _undo() {
    if (!_pageHasMarks) return;
    final mine = _marks.lastWhere((m) => m.page == _page);
    setState(() => _marks = [for (final x in _marks) if (x.id != mine.id) x]);
    _persist();
  }

  Future<void> _goPage(int p) async {
    if (p < 0 || p >= _doc.pages || p == _page) return;
    setState(() {
      _page = p;
      _selected = null;
      _fitted = false;
    });
    await _loadPage();
  }

  Future<void> _showIssues() async {
    final go = await showModalBottomSheet<DrawingMark>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _IssueSheet(
        doc: _doc,
        marks: _marks,
        onToggle: (m) async {
          final n = m.copyWith(done: !m.done, history: [...m.history, MarkEvent(_now, m.done ? '해결 취소' : '해결', _author)]);
          setState(() => _marks = [for (final x in _marks) x.id == m.id ? n : x]);
          await _persist();
          return _marks;
        },
        onShare: () => widget.share(buildIssueText(_doc, _marks)),
        onExport: _export,
      ),
    );
    if (go == null || !mounted) return;
    if (go.page != _page) await _goPage(go.page);
    // 그 자리로 옮겨 가운데에 둔다
    final ps = _pageSize;
    final at = Offset(go.points.first.$1 * ps.width, go.points.first.$2 * ps.height);
    setState(() {
      _scale = math.max(_scale, math.min(_view.width / ps.width, _view.height / ps.height) * 2.5);
      _offset = Offset(_view.width / 2, _view.height / 2) - at * _scale;
      _selected = go.id;
    });
  }

  bool _exporting = false;

  /// 쪽이 많으면 오래 걸려, 만드는 동안 몇 쪽째인지 띄우고 다시 누르지 못하게 한다
  /// (10-07: 아무 표시 없이 멈춘 것처럼 보였고, 다시 누르면 내보내기가 겹쳐 돌았다).
  Future<void> _export() async {
    if (_exporting) return;
    _exporting = true;
    final done = ValueNotifier<int>(0);
    final rootNav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          key: const Key('dv_export_busy'),
          content: Row(
            children: [
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
              const SizedBox(width: 16),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: done,
                  builder: (_, n, _) => Text('PDF를 만드는 중입니다 (${math.min(n + 1, _doc.pages)} / ${_doc.pages}쪽)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    var busyOpen = true;
    void closeBusy() {
      if (!busyOpen) return;
      busyOpen = false;
      rootNav.pop();
    }

    try {
      final bytes = await buildMarkedPdf(
        doc: _doc,
        marks: _marks,
        pagePath: (p) async {
          final path = await (widget.pagePath ?? DrawingStore.ensurePage)(_doc, p);
          done.value = p + 1;
          return path;
        },
        now: _now,
        author: _author,
      );
      closeBusy();
      if (!mounted) return;
      final base = (_doc.drawingNo.isNotEmpty ? _doc.drawingNo : _doc.displayName).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName = '${base}_확인.pdf';
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SteelPdfPreviewPage(
            bytes: bytes,
            fileName: fileName,
            title: '표시한 도면',
            onShare: () async {
              final dir = await getTemporaryDirectory();
              final f = File('${dir.path}/$fileName');
              await f.writeAsBytes(bytes);
              // ignore: deprecated_member_use
              await Share.shareXFiles([XFile(f.path)], text: '${_doc.displayName} 확인');
            },
          ),
        ),
      );
    } catch (e) {
      closeBusy();
      if (mounted) showSnackOnce(ScaffoldMessenger.of(context), SnackBar(content: Text(failText('PDF를 만들지 못했습니다', e))));
    } finally {
      closeBusy();
      _exporting = false;
    }
  }

  Future<void> _editInfo() async {
    final out = await showModalBottomSheet<DrawingDoc>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _InfoSheet(doc: _doc),
    );
    if (out == null) return;
    setState(() => _doc = out);
    if (widget.saveMarks == null) await DrawingStore.put(out);
  }

  @override
  Widget build(BuildContext context) {
    final open = openIssueCount(_marks);
    return Scaffold(
      backgroundColor: const Color(0xFF3A3F46),
      // 글 넣을 때 자판이 올라와도 도면 크기·확대를 그대로 둔다
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_doc.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (_doc.drawingNo.isNotEmpty || _doc.rev.isNotEmpty)
              Text(
                [if (_doc.drawingNo.isNotEmpty) _doc.drawingNo, if (_doc.rev.isNotEmpty) 'REV ${_doc.rev}'].join(' · '),
                style: const TextStyle(fontSize: 12, color: AppColors.textSub),
              ),
          ],
        ),
        actions: [
          IconButton(key: const Key('dv_info'), icon: const Icon(AppIcons.info), onPressed: _editInfo),
          IconButton(
            key: const Key('dv_issues'),
            onPressed: _showIssues,
            icon: Badge(
              isLabelVisible: open > 0,
              label: Text('$open'),
              child: const Icon(LucideIcons.listChecks),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final v = Size(c.maxWidth, c.maxHeight);
                if (v != _view) {
                  // 처음이거나 가로 폭이 바뀔 때(돌림)만 다시 맞춘다
                  if ((v.width - _view.width).abs() > 1) _fitted = false;
                  _view = v;
                }
                if (!_fitted && !_view.isEmpty) {
                  _fitted = true;
                  final ps = _pageSize;
                  _scale = math.min(_view.width / ps.width, _view.height / ps.height) * 0.97;
                  _offset = Offset((_view.width - ps.width * _scale) / 2, (_view.height - ps.height * _scale) / 2);
                }
                return _canvas();
              },
            ),
          ),
          _toolbar(),
        ],
      ),
    );
  }

  Widget _canvas() {
    final ps = _pageSize;
    return ClipRect(
      child: Listener(
        key: const Key('dv_canvas'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        onPointerSignal: (s) {
          if (s is PointerScrollEvent) _zoomAt(s.localPosition, s.scrollDelta.dy < 0 ? 1.15 : 1 / 1.15);
        },
        child: Stack(
          children: [
            Positioned(
              left: _offset.dx,
              top: _offset.dy,
              width: ps.width * _scale,
              height: ps.height * _scale,
              child: Container(
                decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 3))]),
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: ps.width,
                    height: ps.height,
                    child: Stack(
                      children: [
                        if (_pageFile != null)
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: Image.file(File(_pageFile!), fit: BoxFit.fill, filterQuality: FilterQuality.medium, gaplessPlayback: true, errorBuilder: (_, _, _) => const SizedBox()),
                            ),
                          ),
                        Positioned.fill(
                          child: CustomPaint(
                            key: const Key('dv_marks'),
                            painter: DrawingMarksPainter(marks: _marks, page: _page, selectedId: _selected, draft: _draft, viewScale: _scale),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_pageBusy) const Center(child: CircularProgressIndicator()),
            if (_pageError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('이 쪽을 그리지 못했습니다.\n$_pageError', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                ),
              ),
            Positioned(left: 8, top: 8, child: _legend()),
            if (_doc.pages > 1)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      IconButton(key: const Key('dv_prev'), visualDensity: VisualDensity.compact, icon: const Icon(LucideIcons.chevronLeft, color: Colors.white, size: 20), onPressed: _page > 0 ? () => _goPage(_page - 1) : null),
                      Text('${_page + 1} / ${_doc.pages}', key: const Key('dv_page'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      IconButton(key: const Key('dv_next'), visualDensity: VisualDensity.compact, icon: const Icon(LucideIcons.chevronRight, color: Colors.white, size: 20), onPressed: _page < _doc.pages - 1 ? () => _goPage(_page + 1) : null),
                    ],
                  ),
                ),
              ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Column(
                children: [
                  _roundBtn('dv_zoom_in', LucideIcons.plus, () => _zoomAt(Offset(_view.width / 2, _view.height / 2), 1.5)),
                  const SizedBox(height: 6),
                  _roundBtn('dv_zoom_out', LucideIcons.minus, () => _zoomAt(Offset(_view.width / 2, _view.height / 2), 1 / 1.5)),
                  const SizedBox(height: 6),
                  _roundBtn('dv_fit', LucideIcons.maximize, _fit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundBtn(String key, IconData icon, VoidCallback onTap) => Material(
    color: Colors.black.withValues(alpha: 0.55),
    shape: const CircleBorder(),
    child: IconButton(key: Key(key), icon: Icon(icon, color: Colors.white, size: 20), onPressed: onTap),
  );

  Widget _legend() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in MarkColor.values) ...[
          Container(width: 9, height: 9, decoration: BoxDecoration(color: Color(c.argb), shape: BoxShape.circle)),
          const SizedBox(width: 3),
          Text(c.meaning, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(width: 8),
        ],
      ],
    ),
  );

  Widget _toolbar() {
    final kind = _tool.kind;
    final color = _color ?? (kind == null ? null : defaultColorFor(kind));
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kind != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tool.drag ? '끌어서 그립니다. 두 손가락은 확대·이동' : '누른 자리에 놓습니다. 두 손가락은 확대·이동',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSub),
                      ),
                    ),
                    for (final c in MarkColor.values)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: InkWell(
                          key: Key('dv_color_${c.name}'),
                          onTap: () => setState(() => _color = c),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color == c ? Color(c.argb) : Colors.transparent,
                              border: Border.all(color: Color(c.argb), width: 1.5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(c.meaning, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color == c ? Colors.white : Color(c.argb))),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      children: [
                        for (final t in _Tool.values)
                          _toolBtn(t),
                      ],
                    ),
                  ),
                  IconButton(key: const Key('dv_undo'), tooltip: null, icon: const Icon(LucideIcons.undo2), onPressed: _pageHasMarks ? _undo : null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolBtn(_Tool t) {
    final on = _tool == t;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: InkWell(
        key: Key('dv_tool_${t.name}'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() {
          _tool = t;
          _color = null;
          _selected = null;
        }),
        child: Container(
          width: 56,
          decoration: BoxDecoration(color: on ? AppColors.brandSoft : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(t.icon, size: 20, color: on ? AppColors.brand : AppColors.text),
              const SizedBox(height: 2),
              Text(t.label, style: TextStyle(fontSize: 11, fontWeight: on ? FontWeight.w900 : FontWeight.w600, color: on ? AppColors.brand : AppColors.textSub)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 글 넣기 창 ──

class _TextSheet extends StatefulWidget {
  final String title, hint, initial;
  final bool optional;
  const _TextSheet({required this.title, required this.hint, required this.initial, required this.optional});

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: AppText.title),
          const SizedBox(height: 8),
          TextField(key: const Key('dv_text_field'), controller: _c, autofocus: true, minLines: 1, maxLines: 4, decoration: InputDecoration(hintText: widget.hint)),
          if (widget.optional)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('비워 두고 넣어도 됩니다. 나중에 눌러서 적을 수 있습니다.', style: TextStyle(fontSize: 12, color: AppColors.textSub)),
            ),
          const SizedBox(height: 10),
          FilledButton(key: const Key('dv_text_ok'), onPressed: () => Navigator.pop(context, _c.text.trim()), child: const Text('넣기')),
        ],
      ),
    ),
  );
}

// ── 표시 하나 고치기 ──

enum _ActType { save, delete }

class _MarkAction {
  final _ActType type;
  final String text;
  final bool done;
  final MarkColor color;
  const _MarkAction(this.type, this.text, this.done, this.color);
}

class _MarkSheet extends StatefulWidget {
  final DrawingMark mark;
  final int pages;
  const _MarkSheet({required this.mark, required this.pages});

  @override
  State<_MarkSheet> createState() => _MarkSheetState();
}

class _MarkSheetState extends State<_MarkSheet> {
  late final _c = TextEditingController(text: widget.mark.text);
  late bool _done = widget.mark.done;
  late MarkColor _color = widget.mark.color;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mark;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${m.no > 0 ? '${m.no}. ' : ''}${m.kind.label}${widget.pages > 1 ? ' · ${m.page + 1}쪽' : ''}', style: AppText.title),
            Text('${m.author.isEmpty ? '' : '${m.author} · '}${markDate(m.createdAt)}', style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
            const SizedBox(height: 8),
            TextField(key: const Key('dv_mark_text'), controller: _c, minLines: 1, maxLines: 4, decoration: const InputDecoration(labelText: '내용')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final c in MarkColor.values)
                  ChoiceChip(label: Text('${c.label} ${c.meaning}'), selected: _color == c, onSelected: (_) => setState(() => _color = c)),
              ],
            ),
            if (m.kind.numbered)
              SwitchListTile(
                key: const Key('dv_mark_done'),
                contentPadding: EdgeInsets.zero,
                title: const Text('해결됨'),
                value: _done,
                onChanged: (v) => setState(() => _done = v),
              ),
            if (m.history.isNotEmpty) ...[
              const SizedBox(height: 4),
              const Text('기록', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSub)),
              for (final h in m.history)
                Text('${markDate(h.at)}  ${h.what}${h.who.isEmpty ? '' : ' · ${h.who}'}', style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  key: const Key('dv_mark_delete'),
                  onPressed: () => Navigator.pop(context, _MarkAction(_ActType.delete, _c.text, _done, _color)),
                  icon: const Icon(AppIcons.delete, size: 18, color: AppColors.danger),
                  label: const Text('지우기', style: TextStyle(color: AppColors.danger)),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('dv_mark_save'),
                  onPressed: () => Navigator.pop(context, _MarkAction(_ActType.save, _c.text.trim(), _done, _color)),
                  child: const Text('저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 문제 목록 ──

class _IssueSheet extends StatefulWidget {
  final DrawingDoc doc;
  final List<DrawingMark> marks;
  final Future<List<DrawingMark>> Function(DrawingMark m) onToggle;
  final VoidCallback onShare;
  final Future<void> Function() onExport;
  const _IssueSheet({required this.doc, required this.marks, required this.onToggle, required this.onShare, required this.onExport});

  @override
  State<_IssueSheet> createState() => _IssueSheetState();
}

class _IssueSheetState extends State<_IssueSheet> {
  late List<DrawingMark> _marks = widget.marks;
  bool _openOnly = false;

  @override
  Widget build(BuildContext context) {
    final all = issuesOf(_marks);
    final list = _openOnly ? all.where((m) => !m.done).toList() : all;
    final open = all.where((m) => !m.done).length;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, sc) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(
              children: [
                Expanded(child: Text('문제 목록  ${all.length}건 · 남은 것 $open건', style: AppText.title)),
                FilterChip(key: const Key('dv_open_only'), label: const Text('남은 것만'), selected: _openOnly, onSelected: (v) => setState(() => _openOnly = v)),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('틀림·질문·문제 표시를 하면 여기에 모입니다.', style: AppText.sub))
                : ListView(
                    controller: sc,
                    children: [
                      for (final m in list)
                        ListTile(
                          key: Key('dv_issue_${m.no}'),
                          leading: CircleAvatar(
                            radius: 15,
                            backgroundColor: Color(m.color.argb).withValues(alpha: m.done ? 0.35 : 1),
                            child: Text('${m.no}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                          ),
                          title: Text(
                            m.text.isEmpty ? '(내용 없음)' : m.text,
                            style: TextStyle(decoration: m.done ? TextDecoration.lineThrough : null, fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('${m.kind.label}${widget.doc.pages > 1 ? ' · ${m.page + 1}쪽' : ''} · ${markDate(m.createdAt)}${m.author.isEmpty ? '' : ' · ${m.author}'}'),
                          trailing: Checkbox(
                            key: Key('dv_issue_done_${m.no}'),
                            value: m.done,
                            onChanged: (_) async {
                              final v = await widget.onToggle(m);
                              if (mounted) setState(() => _marks = v);
                            },
                          ),
                          onTap: () => Navigator.pop(context, m),
                        ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('dv_issue_share'),
                      onPressed: widget.onShare,
                      icon: const Icon(AppIcons.share, size: 18),
                      label: const Text('목록 보내기'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('dv_export'),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onExport();
                      },
                      icon: const Icon(AppIcons.pdf, size: 18),
                      label: const Text('표시한 PDF 보내기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 도면 정보(표제란) ──

class _InfoSheet extends StatefulWidget {
  final DrawingDoc doc;
  const _InfoSheet({required this.doc});

  @override
  State<_InfoSheet> createState() => _InfoSheetState();
}

class _InfoSheetState extends State<_InfoSheet> {
  late final _no = TextEditingController(text: widget.doc.drawingNo);
  late final _rev = TextEditingController(text: widget.doc.rev);
  late final _title = TextEditingController(text: widget.doc.title);

  @override
  void dispose() {
    _no.dispose();
    _rev.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('도면 정보 (표제란)', style: AppText.title),
            const SizedBox(height: 4),
            Text('파일 ${d.name} · ${d.pages}쪽 · 가져온 때 ${markDate(d.addedAt)}', style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
            const Text('원본 파일은 바꾸지 않고, 표시는 따로 저장합니다.', style: TextStyle(fontSize: 12, color: AppColors.textSub)),
            const SizedBox(height: 8),
            TextField(key: const Key('dv_info_title'), controller: _title, decoration: const InputDecoration(labelText: '도면명 (비우면 파일 이름)')),
            Row(
              children: [
                Expanded(child: TextField(key: const Key('dv_info_no'), controller: _no, decoration: const InputDecoration(labelText: '도번'))),
                const SizedBox(width: 8),
                SizedBox(width: 90, child: TextField(key: const Key('dv_info_rev'), controller: _rev, decoration: const InputDecoration(labelText: 'REV'))),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('dv_info_ok'),
              onPressed: () => Navigator.pop(context, d.copyWith(drawingNo: _no.text.trim(), rev: _rev.text.trim(), title: _title.text.trim())),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}
