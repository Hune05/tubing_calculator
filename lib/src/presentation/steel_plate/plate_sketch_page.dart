// 철판 가공 › 손그림 읽어 만들기(10-10): 종이에 그린 철판 그림 사진을 AI가 읽어 외곽·구멍·두께로 옮기고,
// AI가 안 되거나 통신이 없으면 사진 위(또는 빈 칸)에 꼭짓점을 직접 찍는다. 귀를 차례로 누르고 1번 점을
// 다시 눌러 닫은 뒤, 변의 숫자를 눌러 길이(mm)를 넣는다. 넣은 길이는 잠겨서 다른 변을 고쳐도 그대로이고
// 같은 방향의 잠기지 않은 변이 차이를 받는다(평면도 앱 방식). "레이저 절단으로 보내기"로 넘긴다.
// 같은 날 손봄: 모드(꼭짓점·치수·구멍)를 없애고 누른 곳으로 판단, 구멍 5mm 칸, AI 결과 옆 사진 작게.
// 그림 자료와 고치는 계산은 plate_sketch_model.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_icon_set.dart';
import '../../core/theme/field_view.dart';
import '../../core/utils/ai_plate_sketch.dart';
import '../calculator/widgets/app_dialog.dart';
import '../calculator/widgets/swipe_delete.dart' show calcNavCompact;
import '../common/app_icons.dart';
import '../common/calc_form_parts.dart';
import 'plate_calc.dart';
import 'plate_corner_dialog.dart';
import 'plate_hole_editor.dart' show PlateNumbersDialog;
import 'plate_page.dart';
import 'plate_painter.dart' show plateDrawCenterLines;
import 'plate_sketch_model.dart';
import 'plate_ui.dart';

Future<Uint8List?> _pickPhoto(ImageSource source) async {
  final x = await ImagePicker().pickImage(
    source: source,
    maxWidth: 2000,
    maxHeight: 2000,
    imageQuality: 85,
  );
  return x?.readAsBytes();
}

/// 사진은 앱 문서 폴더에 하나만 둔다(앱을 닫았다 열어도 이어서 따라 찍게).
Future<File> _photoFile() async => File(
  '${(await getApplicationDocumentsDirectory()).path}/plate_sketch_photo.jpg',
);

Future<Uint8List?> _loadPhoto() async {
  try {
    final f = await _photoFile();
    return await f.exists() ? await f.readAsBytes() : null;
  } catch (_) {
    return null;
  }
}

Future<void> _savePhoto(Uint8List? b) async {
  try {
    final f = await _photoFile();
    if (b == null) {
      if (await f.exists()) await f.delete();
    } else {
      await f.writeAsBytes(b, flush: true);
    }
  } catch (_) {}
}

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s == '-0' ? '0' : s;
}

/// 변 [i]의 길이 글 자리(화면): 변 가운데에서 그림 바깥쪽으로 16점. 변이 너무 짧으면 null.
Offset? sketchLabelAt(PlateSketch s, int i, Offset Function(Offset) toScreen) {
  final a = toScreen(s.pts[i]), b = toScreen(s.edgeEnd(i));
  final v = b - a;
  if (v.distance < 24) return null;
  final mid = (a + b) / 2;
  var nrm = Offset(v.dy, -v.dx) / v.distance;
  final bb = s.bounds;
  final cen = bb == null ? mid : toScreen(bb.center);
  if ((mid + nrm * 10 - cen).distance < (mid - cen).distance) nrm = -nrm;
  return mid + nrm * 16;
}

class PlateSketchPage extends StatefulWidget {
  const PlateSketchPage({
    super.key,
    this.parse = callParsePlateSketch,
    this.pickPhoto = _pickPhoto,
    this.loadPhoto = _loadPhoto,
    this.savePhoto = _savePhoto,
    this.openCut,
  });

  final PlateSketchCall parse;
  final Future<Uint8List?> Function(ImageSource source) pickPhoto;
  final Future<Uint8List?> Function() loadPhoto;
  final Future<void> Function(Uint8List? bytes) savePhoto;

  /// 레이저 절단 화면 열기(시험에서 바꿔 끼운다).
  final void Function(BuildContext context, Map<String, Object?> plate)?
  openCut;

  static const draftKey = 'steel_plate_sketch_v1';

  @override
  State<PlateSketchPage> createState() => _PlateSketchPageState();
}

class _PlateSketchPageState extends State<PlateSketchPage>
    with CalcFormParts<PlateSketchPage> {
  PlateSketch _s = PlateSketch();
  Uint8List? _photo;
  ui.Image? _img;
  int? _selPt, _selHole;
  double _tDia = 13.5;
  bool _showPhoto = true;
  bool _busy = false;
  String? _aiError;
  bool _ready = false;

  // 판 가운데 십자선 켜고 끄기(철판 가공 화면과 같은 저장 칸)
  bool _showCenter = true;

  // 알림은 아래 칸 안에 적는다(떠 있는 알림이 "레이저 절단으로 보내기"를 가려 눌리지 않았다).
  String? _notice;
  bool _noticeBad = false;

  final List<String> _undo = [], _redo = [];
  Timer? _saveTimer;

  // 보기: 맞춰 보여 줄 자리(그림 단위), 확대 배율, 화면 가운데에서 옮긴 거리
  Rect _view = const Rect.fromLTWH(0, 0, 400, 300);
  double _zoom = 1;
  Offset _pan = Offset.zero;
  Size _size = Size.zero;

  // 끌기·확대 중 상태
  Offset? _downAt;
  Offset _focal0 = Offset.zero;
  double _zoom0 = 1;
  Offset _pan0 = Offset.zero;
  bool _panning = false, _pinching = false;
  int? _dragPt, _dragHole;
  Offset _dragFrom = Offset.zero;

  /// 손가락으로 긋는 중인 선(그림 단위). 빈 칸이면 외곽, 닫힌 판 안이면 구멍 그림.
  List<Offset>? _ink;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveNow();
    _img?.dispose();
    super.dispose();
  }

  // ── 저장 ──

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _showCenter = p.getBool('plate_center_lines_v1') ?? true;
      final raw = p.getString(PlateSketchPage.draftKey);
      final s = raw == null ? null : PlateSketch.fromJson(jsonDecode(raw));
      if (s != null) _s = s;
    } catch (_) {}
    final photo = await widget.loadPhoto();
    if (photo != null && mounted) _setPhoto(photo, keepSketch: true);
    if (!mounted) return;
    setState(() {
      _ready = true;
      // 빈 그림이면 사진 탭부터, 그린 것이 있으면 그리기 탭에서 이어서
      _tab = _s.n == 0 && _s.holes.isEmpty ? 0 : 1;
      _fit();
    });
  }

  void _saveSoon() {
    if (!_ready) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveNow);
  }

  void _saveNow() {
    if (!_ready) return;
    final d = jsonEncode(_s.toJson());
    SharedPreferences.getInstance()
        .then((p) => p.setString(PlateSketchPage.draftKey, d))
        .catchError((_) => false);
  }

  /// 바꾸기 전에 부른다(되돌리기 쌓기).
  void _push() {
    _undo.add(jsonEncode(_s.toJson()));
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  void _change(VoidCallback f) {
    _push();
    setState(() {
      _notice = null;
      f();
    });
    _saveSoon();
  }

  void _say(String m, {bool bad = false}) => setState(() {
    _notice = m;
    _noticeBad = bad;
  });

  void _restore(List<String> from, List<String> to) {
    if (from.isEmpty) return;
    to.add(jsonEncode(_s.toJson()));
    final s = PlateSketch.fromJson(jsonDecode(from.removeLast()));
    if (s == null) return;
    final refit =
        s.scaled != _s.scaled ||
        s.photoAligned != _s.photoAligned ||
        s.frame != _s.frame;
    setState(() {
      _s = s;
      _selPt = null;
      _selHole = null;
      _notice = null;
      if (refit) {
        _fit();
      } else {
        _fitIfOut();
      }
    });
    _saveSoon();
  }

  // ── 사진 ──

  Rect get _photoFrame {
    final img = _img;
    return img == null
        ? const Rect.fromLTWH(0, 0, 400, 300)
        : Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
  }

  /// 사진을 바로 쓰고(AI 읽기), 그림으로 푸는 것은 뒤에서 한다(다 풀리면 사진 위에 겹쳐 그린다).
  void _setPhoto(Uint8List bytes, {bool keepSketch = false}) {
    setState(() {
      _photo = bytes;
      if (!keepSketch) {
        _s = PlateSketch();
        _aiError = null;
        _selPt = null;
        _selHole = null;
        _fit();
      }
    });
    _decode(bytes);
  }

  Future<void> _decode(Uint8List bytes) async {
    ui.Image? img;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      img = (await codec.getNextFrame()).image;
    } catch (_) {
      img = null;
    }
    if (!mounted || !identical(bytes, _photo)) {
      img?.dispose();
      return;
    }
    setState(() {
      _img?.dispose();
      _img = img;
      // 아직 아무것도 안 찍었으면 그림 자리를 사진 크기로(사진을 고르자마자 앱을 닫아
      // 기본 자리로 저장된 경우도 다시 열 때 바로잡는다)
      if (img != null &&
          _s.n == 0 &&
          _s.holes.isEmpty &&
          _s.photoAligned &&
          !_s.scaled) {
        _s.frame = _photoFrame;
        _fit();
      }
    });
  }

  Future<void> _pick(ImageSource source) async {
    if (_s.n > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AppDialog(
          title: '새 사진으로 시작',
          content: AppDialog.message('지금 찍어 둔 꼭짓점·홀·치수는 지워지고 되돌릴 수 없습니다.'),
          okText: '새로 시작',
          onCancel: () => Navigator.pop(c, false),
          onOk: () => Navigator.pop(c, true),
        ),
      );
      if (ok != true) return;
    }
    Uint8List? bytes;
    try {
      bytes = await widget.pickPhoto(source);
    } catch (_) {
      bytes = null;
    }
    if (bytes == null || !mounted) return;
    // 사진은 되돌리기에 안 들어가므로 옛 그림으로 되돌리지 못하게 비운다(옛 사진과 어긋난다).
    _undo.clear();
    _redo.clear();
    _setPhoto(bytes);
    await widget.savePhoto(bytes);
    _saveSoon();
  }

  Future<void> _readAi() async {
    final photo = _photo;
    if (photo == null || _busy) return;
    setState(() {
      _busy = true;
      _aiError = null;
    });
    PlateSketchResult r;
    try {
      r = await widget.parse(photo);
    } catch (_) {
      r = const PlateSketchResult.fail('통신이 되는지 확인해 주십시오');
    }
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _busy = false;
        _aiError = r.error;
      });
      return;
    }
    _push();
    setState(() {
      _busy = false;
      _s = PlateSketch.fromAi(r);
      _tab = 2; // AI가 읽었으면 치수 확인부터
      _selPt = null;
      _selHole = null;
      _fit();
    });
    _saveSoon();
    _say(
      r.remaining == null
          ? 'AI로 읽었습니다. 치수를 확인하십시오.'
          : 'AI로 읽었습니다. 치수를 확인하십시오(오늘 남은 횟수 ${r.remaining}번).',
    );
  }

  /// AI가 읽은 것을 버리고 사진 위에 직접 따라 찍기.
  void _startTrace() => _change(() {
    _s = PlateSketch(frame: _photoFrame);
    _selPt = null;
    _selHole = null;
    _showPhoto = true;
    _fit();
  });

  void _clearSketch() => _change(() {
    // 사진 위에서 치수를 맞춰 놓았으면 그 축척은 둔다(같은 사진에 다시 찍기). 빈 종이는 처음부터.
    final keepScale = _img != null && _s.photoAligned && _s.scaled;
    _s = PlateSketch(
      frame: keepScale ? _s.frame : _photoFrame,
      scaled: keepScale,
    );
    _selPt = null;
    _selHole = null;
    _fit();
  });

  void _viewPhoto() {
    final photo = _photo;
    if (photo == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('스케치 사진'),
          ),
          body: InteractiveViewer(
            maxScale: 8,
            child: Center(
              child: Image.memory(
                photo,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 좌표 ──

  /// 흰 종이 자리: 사진이 겹쳐 있으면 사진(과 그림), 아니면 그림 둘레를 조금 넉넉히(그림이 없으면 처음 종이).
  /// 10-10: 치수를 넣어 판이 커지면 그림이 처음 종이 밖으로 나가 회색 바탕 위에 걸렸다.
  Rect get _paper {
    final b = _s.bounds;
    if (_s.photoAligned && _img != null) {
      return b == null ? _s.frame : _s.frame.expandToInclude(b);
    }
    if (b == null || _s.n < 2) return _s.frame;
    final m = math.max(math.max(b.width, b.height) * 0.08, 1e-6);
    return _s.scaled ? b.inflate(m) : _s.frame.expandToInclude(b.inflate(m));
  }

  void _fit() {
    _view = _paper;
    _zoom = 1;
    _pan = Offset.zero;
  }

  /// 그림이 화면 밖으로 나가면 다시 맞춘다(치수를 넣어 판이 커졌을 때 등).
  void _fitIfOut() {
    final b = _s.bounds;
    if (b == null || _size.isEmpty) return;
    final vis = Rect.fromPoints(
      _toModel(Offset.zero),
      _toModel(Offset(_size.width, _size.height)),
    ).deflate(12 / _scale);
    if (!vis.contains(b.topLeft) || !vis.contains(b.bottomRight)) _fit();
  }

  double get _base {
    const m = 36.0;
    final w = math.max(_view.width, 1.0), h = math.max(_view.height, 1.0);
    return math.max(
      1e-4,
      math.min((_size.width - 2 * m) / w, (_size.height - 2 * m) / h),
    );
  }

  double get _scale => _base * _zoom;

  Offset _toScreen(Offset m) {
    final s = _scale, c = _view.center;
    return Offset(_size.width / 2, _size.height / 2) +
        _pan +
        Offset((m.dx - c.dx) * s, -(m.dy - c.dy) * s);
  }

  Offset _toModelWith(Offset sc, double zoom, Offset pan) {
    final s = _base * zoom, c = _view.center;
    final d = sc - Offset(_size.width / 2, _size.height / 2) - pan;
    return Offset(d.dx / s + c.dx, -d.dy / s + c.dy);
  }

  Offset _toModel(Offset sc) => _toModelWith(sc, _zoom, _pan);

  double get _tol => 22 / _scale;

  /// 치수가 정해졌으면 판 왼쪽 아래에서 5mm 칸에 붙인다.
  Offset _snapHole(Offset m) {
    final b = _s.bounds;
    if (!_s.scaled || b == null) return m;
    double sn(double v, double o) => o + ((v - o) / 5).round() * 5;
    return Offset(sn(m.dx, b.left), sn(m.dy, b.top));
  }

  /// 화면 자리에서 가까운 변 길이 글(26점 안).
  int? _hitLabel(Offset at) {
    int? best;
    var bd = 26.0;
    for (var i = 0; i < _s.edgeCount; i++) {
      final p = sketchLabelAt(_s, i, _toScreen);
      if (p == null) continue;
      final d = (p - at).distance;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  // ── 탭(10-10 사용자: "손그림도 탭으로 나눠") ──
  // 사진 → 그리기 → 치수 → 구멍 → 보내기. 위 그림은 같이 쓰고, 탭에 따라 그림을 눌렀을 때 하는 일과 아래 단추가 바뀐다.

  static const _tabs = [
    ('photo', '사진'),
    ('draw', '그리기'),
    ('dims', '치수'),
    ('holes', '홀'),
    ('send', '보내기'),
  ];
  int _tab = 0;
  String get _tabId => _tabs[_tab].$1;

  void _goTab(String id) {
    final i = _tabs.indexWhere((t) => t.$1 == id);
    if (i < 0) return;
    setState(() {
      _tab = i;
      _selPt = null;
      _selHole = null;
      _notice = null;
    });
  }

  // ── 손놀림 ──
  // 그리기 탭: 꼭짓점 고르기·끌기(닫기 전 1번 점은 닫기), 빈 곳에 점 더하기·외곽 긋기, 변 길게 눌러 점 끼우기.
  // 치수 탭: 변(숫자)을 누르면 길이. 구멍 탭: 판 안을 누르면 구멍, 동그라미를 그리면 구멍·장공, 구멍 끌기.
  // 어느 탭이든 빈 곳(판 밖) 끌기·두 손가락은 화면 옮기기·확대.

  void _onTap(TapUpDetails d) {
    final at = d.localPosition;
    final m = _toModel(at);
    switch (_tabId) {
      case 'draw':
        final v = _s.hitPoint(m, _tol);
        if (v != null) {
          if (!_s.closed && v == 0 && _s.n >= 3) {
            _closeShape();
            return;
          }
          setState(() => _selPt = _selPt == v ? null : v);
          return;
        }
        if (_selPt != null) {
          setState(() => _selPt = null);
          return;
        }
        if (!_s.closed) _change(() => _s.addPoint(m));
      case 'dims':
        final e = _hitLabel(at) ?? (_s.closed ? _s.hitEdge(m, _tol) : null);
        if (e != null) _editEdge(e);
      case 'holes':
        final h = _s.hitHole(m, _tol);
        if (h != null) {
          setState(() => _selHole = _selHole == h ? null : h);
          return;
        }
        if (_selHole != null) {
          setState(() => _selHole = null);
          return;
        }
        if (!_s.closed) {
          _say('먼저 그리기 탭에서 모양을 닫으십시오.', bad: true);
          return;
        }
        if (!sketchContains(_s.pts, m)) return;
        final p = _snapHole(m);
        _change(
          () => _s.holes.add(PlateHoleSpec(u: p.dx, v: p.dy, dia: _tDia)),
        );
    }
  }

  void _onLongPress(LongPressStartDetails d) {
    if (_tabId != 'draw') return;
    final m = _toModel(d.localPosition);
    if (_s.hitPoint(m, _tol) != null) return;
    final e = _s.hitEdge(m, _tol);
    if (e == null) return;
    _change(() {
      _s.insertOnEdge(e, m);
      _selPt = e + 1;
    });
  }

  void _onScaleStart(ScaleStartDetails d) {
    _focal0 = d.pointerCount == 1 && _downAt != null
        ? _downAt!
        : d.localFocalPoint;
    _zoom0 = _zoom;
    _pan0 = _pan;
    _pinching = d.pointerCount >= 2;
    _panning = false;
    _dragPt = null;
    _dragHole = null;
    if (_pinching) return;
    final m = _toModel(_focal0);
    if (_tabId == 'draw') {
      final v = _s.hitPoint(m, _tol);
      if (v != null) {
        _push();
        _dragPt = v;
        _dragFrom = _s.pts[v];
        setState(() => _selPt = v);
        return;
      }
      // 빈 종이면 외곽을 손가락으로 긋는다
      if (_s.n == 0) {
        _ink = [m];
        return;
      }
    } else if (_tabId == 'holes') {
      final h = _s.hitHole(m, _tol);
      if (h != null) {
        _push();
        _dragHole = h;
        final hh = _s.holes[h];
        _dragFrom = Offset(hh.u, hh.v);
        setState(() => _selHole = h);
        return;
      }
      // 닫힌 판 안이면 구멍(동그라미)을 긋는다
      if (_s.closed && sketchContains(_s.pts, m)) {
        _ink = [m];
        return;
      }
    }
    _panning = true;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final ink = _ink;
    if (ink != null) {
      if (d.pointerCount >= 2) {
        setState(() => _ink = null); // 두 손가락이면 긋기를 그만두고 확대·이동
      } else {
        setState(() => ink.add(_toModel(d.localFocalPoint)));
        return;
      }
    }
    if (d.pointerCount >= 2 || _pinching) {
      _pinching = true;
      final m = _toModelWith(_focal0, _zoom0, _pan0);
      final z = (_zoom0 * d.scale).clamp(0.5, 20.0);
      final s = _base * z, c = _view.center;
      setState(() {
        _zoom = z;
        _pan =
            d.localFocalPoint -
            Offset(_size.width / 2, _size.height / 2) -
            Offset((m.dx - c.dx) * s, -(m.dy - c.dy) * s);
      });
      return;
    }
    final dv = d.localFocalPoint - _focal0;
    final dm = Offset(dv.dx / _scale, -dv.dy / _scale);
    if (_dragPt != null) {
      setState(() => _s.pts[_dragPt!] = _dragFrom + dm);
      return;
    }
    if (_dragHole != null) {
      final k = _dragHole!;
      final p = _snapHole(_dragFrom + dm);
      setState(() => _s.holes[k] = _s.holes[k].copyWith(u: p.dx, v: p.dy));
      return;
    }
    if (_panning) setState(() => _pan = _pan0 + dv);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    final ink = _ink;
    _ink = null;
    if (ink != null) {
      _panning = false;
      _pinching = false;
      // 다른 손가락이 아직 닿아 있으면(확대하려는 것) 그은 것은 버린다
      d.pointerCount == 0 ? _commitInk(ink) : setState(() {});
      return;
    }
    final dragged = _dragPt != null || _dragHole != null;
    _dragPt = null;
    _dragHole = null;
    _panning = false;
    _pinching = false;
    if (dragged) _saveSoon();
  }

  /// 그은 선을 모양으로: 빈 칸이면 외곽 꼭짓점, 판 안의 작은 고리면 구멍·장공.
  void _commitInk(List<Offset> ink) {
    final sc = _scale;
    var len = 0.0;
    for (var i = 1; i < ink.length; i++) {
      len += (ink[i] - ink[i - 1]).distance;
    }
    if (len * sc < 40) {
      setState(() {}); // 너무 짧게 그음(손이 스친 것)
      return;
    }
    if (_s.n == 0) {
      final r = sketchStrokeToPolygon(ink, tol: 14 / sc, closeTol: 44 / sc);
      if (r.pts.length < 2) {
        setState(() {});
        return;
      }
      _push();
      var k = 0;
      setState(() {
        for (final p in r.closed ? sketchNormalizeLoop(r.pts) : r.pts) {
          _s.addPoint(p);
        }
        _selPt = null;
        _selHole = null;
      });
      if (r.closed) {
        // 닫혔으면 바로잡기(가로·세로, 대칭)까지 하고 알린다
        _closeShape(prefix: '그은 선을 ', push: false);
        return;
      }
      setState(() => k = _s.orthogonalize().squared);
      _saveSoon();
      _say(
        '그은 선을 꼭짓점 ${_s.n}개로 바꿨습니다${k > 0 ? '(가로·세로 $k곳 세움)' : ''}. 끝이 시작점과 떨어져 있어 아직 열려 있습니다. 다음 꼭짓점을 누르거나 1번 점을 눌러 닫습니다.',
      );
      return;
    }
    final b = _s.bounds!;
    final loop = sketchLoopShape(ink, closeTol: 44 / sc);
    if (loop == null || loop.major > 0.6 * math.min(b.width, b.height)) {
      setState(() {});
      _say('판 안에 작은 동그라미를 그리면 홀이 됩니다. 화면을 옮기려면 판 밖을 끌거나 두 손가락으로 움직이십시오.');
      return;
    }
    final slot = _s.scaled && loop.minor / loop.major < 0.6;
    // 손가락 동그라미 크기는 대충이라 지름은 고른 펀치 지름으로(구멍을 눌러 고친다). 장공 길이만 그린 대로.
    final dia = _tDia;
    final slotLen = slot
        ? math.max(dia * 1.5, (loop.major / 5).round() * 5.0)
        : 0.0;
    final ang = slot
        ? ((loop.angleDeg / 15).round() * 15 % 180).toDouble()
        : 0.0;
    final c = _snapHole(loop.c);
    _change(
      () => _s.holes.add(
        PlateHoleSpec(u: c.dx, v: c.dy, dia: dia, slot: slotLen, angle: ang),
      ),
    );
    _say(
      slot
          ? '그린 고리를 장공 ${_f(dia)}×${_f(slotLen)}로 바꿨습니다. 홀을 눌러 크기를 고칠 수 있습니다.'
          : '그린 동그라미를 φ${_f(dia)} 홀로 바꿨습니다. 홀을 눌러 크기를 고칠 수 있습니다.',
    );
  }

  // ── 치수·구멍·귀 처리 창 ──

  Future<void> _editEdge(int i) async {
    final j = (i + 1) % _s.n;
    final r = await showDialog<_LenResult>(
      context: context,
      builder: (_) => _LengthDialog(
        title: '변 ${i + 1}→${j + 1} 길이',
        initial: _s.scaled ? _s.edgeLen(i) : null,
        locked: _s.isLocked(i),
      ),
    );
    if (r == null || !mounted) return;
    if (r.unlock) {
      _change(() => _s.unlock(i));
      _say('변 ${i + 1} 잠금을 풀었습니다. 다른 변을 고치면 이 변이 차이를 받을 수 있습니다.');
      return;
    }
    final mm = r.mm;
    if (mm == null || mm <= 0) {
      _say('길이를 mm로 넣으십시오', bad: true);
      return;
    }
    final first = !_s.scaled;
    final before = jsonEncode(_s.toJson());
    final f = first ? mm / math.max(_s.edgeLen(i), 1e-9) : 1.0;
    final res = _s.setEdge(i, mm);
    if (!res.ok) {
      if (res.note != null) _say(res.note!, bad: true);
      return;
    }
    _undo.add(before);
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
    setState(() {
      _notice = null;
      if (!first) _fitIfOut();
      if (first) {
        // 화면이 그대로 보이게 보기 자리도 같은 비율로
        _view = Rect.fromLTRB(
          _view.left * f,
          _view.top * f,
          _view.right * f,
          _view.bottom * f,
        );
      }
    });
    _saveSoon();
    if (first) {
      _say('이 치수로 전체 크기를 맞췄습니다. 나머지 변의 숫자도 눌러 넣으십시오.');
    } else if (res.note != null) {
      // 같이 바뀐 변은 알림, 기울어진 변은 주의
      _say(res.note!, bad: res.note!.contains('기울기'));
    }
  }

  Future<void> _editHole(int k) async {
    if (!_s.scaled) {
      _say('먼저 변 하나에 치수를 넣으십시오(그래야 mm가 정해집니다)', bad: true);
      return;
    }
    final b = _s.bounds ?? Rect.zero;
    final h = _s.holes[k];
    final r = await showDialog<List<double>>(
      context: context,
      builder: (_) => PlateNumbersDialog(
        title: '홀 ${k + 1}',
        fields: [
          ('가로 자리 (판 왼쪽 끝에서, mm)', double.parse(_f(h.u - b.left))),
          ('세로 자리 (판 아래 끝에서, mm)', double.parse(_f(h.v - b.top))),
          ('지름 (mm)', h.dia),
          ('장공 길이 (mm, 원형 홀은 0)', h.slot),
          ('장공 각도 (°, 가로 0)', h.angle),
        ],
      ),
    );
    if (r == null || !mounted) return;
    if (!r[2].isFinite || r[2] <= 0) return;
    _change(
      () => _s.holes[k] = PlateHoleSpec(
        u: b.left + (r[0].isFinite ? r[0] : h.u - b.left),
        v: b.top + (r[1].isFinite ? r[1] : h.v - b.top),
        dia: r[2],
        slot: r[3].isFinite && r[3] > r[2] ? r[3] : 0,
        angle: r[4].isFinite ? r[4] : 0,
      ),
    );
  }

  Future<void> _editCorner(int k) async {
    final c = await showPlateCornerDialog(
      context,
      title: '꼭짓점 ${k + 1} 코너 처리',
      initial: _s.corners[k],
    );
    if (c == null || !mounted) return;
    _change(() => _s.corners[k] = c);
  }

  /// 모양 닫기 + 처음 그림 바로잡기(10-10 사용자: "삐뚤어지게 그려져도 일단 수직 수평으로", "좌우대칭"):
  /// 가로·세로에서 35° 안 변은 세우고 손 떨림 변은 없애고, 거의 좌우 대칭이면 똑같이 맞춘다(되돌리기로 원래대로).
  void _closeShape({String prefix = '', bool push = true}) {
    if (push) _push();
    var sq = 0, rm = 0;
    var sym = false;
    setState(() {
      _notice = null;
      _s.close();
      final o = _s.orthogonalize();
      sq = o.squared;
      rm = o.removed;
      sym = _s.symmetrize(tolFrac: 0.1);
      _selPt = null;
      _selHole = null;
    });
    _saveSoon();
    final fixes = [
      if (sq > 0) '가로·세로 $sq곳 세움',
      if (rm > 0) '짧은 변 $rm개 정리',
      if (sym) '좌우 대칭',
    ];
    _say(
      '${prefix.isEmpty ? '모양을 닫았습니다' : '$prefix꼭짓점 ${_s.n}개로 바꿨습니다'}${fixes.isEmpty ? '' : '(${fixes.join(' · ')})'}. '
      '"다음: 치수"에서 변 길이를 넣으십시오.${sym ? ' 대칭이 아니면 되돌리기를 누르십시오.' : ''}',
    );
  }

  void _squareUp() {
    if (_s.n < 2) return;
    final before = jsonEncode(_s.toJson());
    var o = (squared: 0, removed: 0);
    setState(() => o = _s.orthogonalize());
    if (o.squared == 0 && o.removed == 0) {
      _say('바로 세울 변이 없습니다(가로·세로에서 35° 넘게 기운 변은 그대로 둡니다)');
      return;
    }
    _undo.add(before);
    _redo.clear();
    _saveSoon();
    _say(
      '변 ${o.squared}개를 가로·세로로 세웠습니다${o.removed > 0 ? '(짧은 변 ${o.removed}개 정리)' : ''}',
    );
  }

  /// 좌우 대칭으로 맞출 수 있고 실제로 바뀌는 것이 있는지(없으면 단추를 숨긴다).
  bool get _canMirror {
    if (!_s.closed) return false;
    final c = _s.copy();
    if (!c.symmetrize()) return false;
    for (var k = 0; k < c.n; k++) {
      if ((c.pts[k] - _s.pts[k]).distance > 0.05) return true;
    }
    return false;
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AppDialog(
        title: '그림 지우기',
        content: AppDialog.message('그린 모양·치수·홀을 모두 지웁니다(되돌리기로 살릴 수 있습니다).'),
        okText: '지우기',
        okKey: const Key('sk_clear_ok'),
        destructive: true,
        onCancel: () => Navigator.pop(c, false),
        onOk: () => Navigator.pop(c, true),
      ),
    );
    if (ok == true && mounted) _clearSketch();
  }

  void _mirror() {
    final before = jsonEncode(_s.toJson());
    var ok = false;
    setState(() => ok = _s.symmetrize());
    if (!ok) {
      _say('좌우 짝이 맞지 않아 대칭으로 맞출 수 없습니다(꼭짓점 수·높이가 양쪽이 달라 보입니다)', bad: true);
      return;
    }
    _undo.add(before);
    _redo.clear();
    _saveSoon();
    _say('좌우 대칭으로 맞췄습니다(세로 센터선 기준, 짝끼리 폭·높이 평균). 되돌리기로 원래대로 돌릴 수 있습니다.');
  }

  void _send() {
    final m = _s.toPlateMap();
    if (m == null) {
      _say(
        _s.n < 3 ? '꼭짓점을 3개 이상 찍으십시오' : '변 하나에 치수를 넣어야 크기가 정해집니다',
        bad: true,
      );
      return;
    }
    final open = widget.openCut;
    if (open != null) {
      open(context, m);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlatePage(initial: m)),
    );
  }

  // ── 글 ──

  List<String> _problems() {
    if (!_s.scaled || _s.n < 3 || !_s.closed) return const [];
    final out = <String>[];
    plateCornerOutline(_s.pts, _s.corners, (w) {
      if (!out.contains(w)) out.add(w);
    });
    return out;
  }

  String _status() {
    final s = _s;
    switch (_tabId) {
      case 'photo':
        if (_photo == null) return '종이 스케치가 있으면 사진을 찍거나 고르십시오.';
        if (s.n > 0 && !s.photoAligned) return 'AI가 읽었습니다. 치수 탭에서 확인하십시오.';
        return '"AI로 읽기"를 누르거나, 그리기 탭에서 사진 위에 따라 그리십시오.';
      case 'draw':
        final k = _selPt;
        if (k != null && k < s.n) return '꼭짓점 ${k + 1} · ${s.corners[k].label}';
        if (s.n == 0) return '판 모양을 손가락으로 그으십시오.';
        if (!s.closed) {
          return s.n < 3
              ? '꼭짓점 ${s.n}개 · 다음 꼭짓점을 누르십시오.'
              : '꼭짓점 ${s.n}개 · 1번 점을 누르면 닫힙니다.';
        }
        return '꼭짓점 ${s.n}개 · 점을 끌어 고치고, 변을 길게 눌러 점을 더합니다.';
      case 'dims':
        if (!s.closed) return '그리기 탭에서 모양을 먼저 닫으십시오.';
        if (!s.scaled) return '변을 눌러 길이(mm)를 넣으십시오. 처음 넣는 길이로 크기가 정해집니다.';
        final locked = [
          for (var i = 0; i < s.edgeCount; i++)
            if (s.isLocked(i)) i,
        ].length;
        return '넣은 치수 $locked곳 · ✓ 잠김, ! 바뀜';
      case 'holes':
        if (!s.closed) return '그리기 탭에서 모양을 먼저 닫으십시오.';
        final hk = _selHole;
        if (hk != null && hk < s.holes.length) {
          final h = s.holes[hk];
          return '홀 ${hk + 1} · φ${_f(h.dia)}${h.slot > h.dia ? ' 장공 ${_f(h.slot)}' : ''}';
        }
        return '판 안을 누르면 φ${_f(_tDia)} 홀 · 동그라미는 홀, 길쭉하면 장공 · 홀 ${s.holes.length}개';
      default:
        final m = s.toPlateMap();
        if (m == null) {
          return s.n < 3
              ? '그리기 탭에서 판 모양을 먼저 그리십시오.'
              : '치수 탭에서 변 하나에 길이를 넣으십시오.';
        }
        final b = s.bounds!;
        return '보낼 준비: ${_f(b.width)} × ${_f(b.height)} mm';
    }
  }

  // ── 화면 ──

  @override
  Widget build(BuildContext context) {
    final problems = _problems();
    final hasPhoto = _photo != null;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveNow();
      },
      child: FieldViewTheme(
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: fc.background,
            appBar: AppBar(
              backgroundColor: fc.surface,
              foregroundColor: fc.text,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: Text(
                '스케치로 만들기',
                style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
              ),
              actions: [
                IconButton(
                  key: const Key('sk_undo'),
                  tooltip: '되돌리기',
                  onPressed: _undo.isEmpty
                      ? null
                      : () => _restore(_undo, _redo),
                  icon: const Icon(AppIcons.undo),
                ),
                IconButton(
                  key: const Key('sk_redo'),
                  tooltip: '다시 하기',
                  onPressed: _redo.isEmpty
                      ? null
                      : () => _restore(_redo, _undo),
                  icon: const Icon(AppIcons.redo),
                ),
              ],
            ),
            // 10-10 화면 정리: 철판 가공 화면과 같은 틀(위 그림 칸 + 아래 흰 작업판 + 맨 아래 이전/다음)
            body: PlateWorkspace(
              canvasShare: switch (_tabId) {
                'draw' || 'holes' => 0.6,
                'dims' => 0.5,
                _ => 0.55,
              },
              tools: [
                if (_s.closed)
                  PlateCanvasButton(
                    key: const Key('sk_center'),
                    label: '센터선',
                    selected: _showCenter,
                    onTap: () {
                      setState(() => _showCenter = !_showCenter);
                      final v = _showCenter;
                      SharedPreferences.getInstance()
                          .then((p) => p.setBool('plate_center_lines_v1', v))
                          .catchError((_) => false);
                    },
                  ),
                PlateCanvasButton(
                  key: const Key('sk_fit'),
                  tooltip: '전체 보기',
                  icon: Icons.fit_screen_outlined,
                  onTap: () => setState(_fit),
                ),
              ],
              overlay: [
                // AI가 읽은 그림 옆에 사진을 작게(눌러 크게) — 화면을 옮기지 않고 비교
                if (hasPhoto && !_s.photoAligned)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: GestureDetector(
                      key: const Key('sk_thumb'),
                      onTap: _viewPhoto,
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: fc.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: fc.line, width: 2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.memory(
                          _photo!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Icon(Icons.image_outlined, color: fc.textSub),
                        ),
                      ),
                    ),
                  ),
                if (_img != null && _s.photoAligned)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: PlateCanvasButton(
                      key: const Key('sk_show_photo'),
                      label: '사진',
                      selected: _showPhoto,
                      onTap: () => setState(() => _showPhoto = !_showPhoto),
                    ),
                  ),
              ],
              canvas: LayoutBuilder(
                builder: (context, box) {
                  _size = box.biggest;
                  return Listener(
                    onPointerDown: (e) => _downAt = e.localPosition,
                    child: GestureDetector(
                      key: const Key('sk_canvas'),
                      behavior: HitTestBehavior.opaque,
                      dragStartBehavior: DragStartBehavior.down,
                      onTapUp: _onTap,
                      onLongPressStart: _onLongPress,
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,
                      onScaleEnd: _onScaleEnd,
                      child: CustomPaint(
                        painter: _SketchPainter(
                          sketch: _s,
                          image: _s.photoAligned && _showPhoto ? _img : null,
                          toScreen: _toScreen,
                          scale: _scale,
                          selPt: _selPt,
                          selHole: _selHole,
                          ink: _ink,
                          showCenter: _showCenter,
                          paper: _paper,
                          hint: _tabId == 'draw'
                              ? '여기에 판 모양을 손가락으로 그으십시오'
                              : (_tabId == 'photo'
                                    ? '사진을 찍거나 고르면 여기에 나옵니다'
                                    : '그리기 탭에서 판 모양을 그리십시오'),
                          colors: fc,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  );
                },
              ),
              panel: _panel(problems),
            ),
            bottomNavigationBar: _navBar(),
          ),
        ),
      ),
    );
  }

  /// 아래 탭 줄(벤딩·철판 가공 화면과 같은 모양).
  Widget _navBar() {
    final compact = calcNavCompact(context);
    BottomNavigationBarItem item(String id, String label, int i) {
      final on = i == _tab;
      final Widget icon = switch (id) {
        'photo' => const Icon(AppIcons.camera, size: 22),
        'draw' => AppIcon(AppGlyph.plateSketch, size: 24, filled: on),
        'dims' => AppIcon(AppGlyph.navInput, size: 24, filled: on),
        'holes' => const Icon(Icons.adjust, size: 24),
        _ => const Icon(AppIcons.send, size: 22),
      };
      return BottomNavigationBarItem(
        icon: Padding(
          padding: EdgeInsets.only(bottom: compact ? 0 : 4),
          child: KeyedSubtree(key: Key('sk_tab_$id'), child: icon),
        ),
        label: label,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: fc.surface,
        border: Border(top: BorderSide(color: fc.line)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 4,
            vertical: compact ? 0 : 4,
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            currentIndex: _tab,
            selectedItemColor: fc.brand,
            unselectedItemColor: fc.textSub,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
            onTap: (i) {
              HapticFeedback.selectionClick();
              _goTab(_tabs[i].$1);
            },
            items: [
              for (var i = 0; i < _tabs.length; i++)
                item(_tabs[i].$1, _tabs[i].$2, i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(String key, IconData icon, String label, VoidCallback? onTap) =>
      PlateActionButton(key: Key(key), icon: icon, label: label, onTap: onTap);

  /// 맨 아래 고정 줄: 이전 · 다음(보내기 탭은 "레이저 절단으로 보내기").
  Widget _footer() {
    final prev = _tab > 0 ? _tabs[_tab - 1] : null;
    final next = _tab + 1 < _tabs.length ? _tabs[_tab + 1] : null;
    return PlateFooter(
      backKey: prev == null ? null : 'sk_prev_${prev.$1}',
      onBack: prev == null ? null : () => _goTab(prev.$1),
      nextKey: next == null ? null : 'sk_next_${next.$1}',
      nextLabel: next?.$2,
      onNext: next == null ? null : () => _goTab(next.$1),
      main: _tabId == 'send'
          ? FilledButton.icon(
              key: const Key('sk_send'),
              style: FilledButton.styleFrom(
                backgroundColor: fc.brand,
                foregroundColor: fc.onBrand,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _send,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text(
                '레이저 절단으로 보내기',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            )
          : null,
    );
  }

  List<String> _help() => switch (_tabId) {
    'photo' => [
      '종이 스케치를 찍거나 고른 뒤 "AI로 읽기"를 누르면 모양·치수·홀을 읽어 옵니다(하루 20번).',
      'AI가 못 읽으면 "사진 위에 직접 따라 그리기"로 사진 위에서 꼭짓점을 찍습니다.',
    ],
    'draw' => [
      '빈 칸에서 손가락으로 판 모양을 한 번에 그으면 모양으로 바꿉니다. 삐뚤게 그려도 가로·세로로 바로잡고, 거의 대칭이면 좌우 대칭으로 맞춥니다.',
      '꼭짓점을 차례로 눌러 찍어도 됩니다. 1번 점을 누르면 닫힙니다.',
      '점은 끌어 고치고, 변을 길게 누르면 점을 더합니다. 점을 누르면 코너 처리(R·C·따내기)와 지우기가 나옵니다.',
    ],
    'dims' => [
      '그림의 변 숫자나 아래 목록을 눌러 길이(mm)를 넣습니다. 처음 넣는 길이로 크기가 정해집니다.',
      '방금 넣은 값이 이기고, 맞춰야 하는 다른 변이 따라 바뀝니다. ✓는 넣은 값(잠김), !는 따라 바뀐 값입니다.',
    ],
    'holes' => [
      '판 안을 누르면 고른 지름의 홀을 놓습니다(5mm 칸에 붙음).',
      '손가락으로 동그라미를 그어도 홀이 되고, 길쭉하게 그으면 장공이 됩니다.',
      '홀을 누르면 고르고, 위치·크기를 고치거나 지울 수 있습니다.',
    ],
    _ => [
      '"레이저 절단으로 보내기"를 누르면 레이저 절단 화면의 좌표 입력으로 옮겨 갑니다.',
      '그 화면에 있던 입력은 덮이고, 알림에서 되돌릴 수 있습니다.',
    ],
  };

  /// 탭마다 할 수 있는 것만(그림 칸 몫은 탭마다 못박아 그림이 들썩이지 않게).
  Widget _panel(List<String> problems) {
    final s = _s;
    final hasPhoto = _photo != null;
    final List<Widget> sections;
    switch (_tabId) {
      case 'photo':
        sections = [
          PlateSection('종이 스케치 사진', [
            plateRow([
              _btn(
                'sk_camera',
                Icons.photo_camera_outlined,
                '사진 찍기',
                _busy ? null : () => _pick(ImageSource.camera),
              ),
              _btn(
                'sk_gallery',
                Icons.photo_library_outlined,
                '사진 고르기',
                _busy ? null : () => _pick(ImageSource.gallery),
              ),
            ]),
            if (hasPhoto)
              FilledButton.icon(
                key: const Key('sk_ai'),
                style: FilledButton.styleFrom(
                  backgroundColor: fc.brand,
                  foregroundColor: fc.onBrand,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _busy ? null : _readAi,
                icon: _busy
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: fc.onBrand,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(
                  _busy
                      ? '읽는 중'
                      : (s.n > 0 && !s.photoAligned ? 'AI로 다시 읽기' : 'AI로 읽기'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            if (hasPhoto)
              plateActions([
                _btn(
                  'sk_photo_view',
                  Icons.image_outlined,
                  '사진 크게 보기',
                  _viewPhoto,
                ),
                if (!s.photoAligned && s.n > 0)
                  _btn(
                    'sk_trace',
                    Icons.touch_app_outlined,
                    '사진 위에 직접 따라 그리기',
                    () {
                      _startTrace();
                      _goTab('draw');
                    },
                  ),
              ]),
          ], first: true),
        ];
      case 'draw':
        final sel = _selPt;
        final shapeActs = [
          if (!s.closed && s.n >= 3)
            _btn('sk_close', Icons.check_circle_outline, '모양 닫기', _closeShape),
          if (s.n >= 2)
            _btn('sk_square', Icons.square_foot, '직각 맞추기', _squareUp),
          if (_canMirror) _btn('sk_mirror', Icons.flip, '좌우 대칭', _mirror),
        ];
        sections = [
          if (sel != null && sel < s.n)
            PlateSection('꼭짓점 ${sel + 1}', [
              plateActions([
                _btn(
                  'sk_corner',
                  Icons.rounded_corner,
                  '코너 처리',
                  () => _editCorner(sel),
                ),
                PlateActionButton(
                  key: const Key('sk_del'),
                  icon: AppIcons.delete,
                  label: '꼭짓점 지우기',
                  danger: true,
                  onTap: () => _change(() {
                    _s.removePoint(sel);
                    _selPt = null;
                  }),
                ),
              ]),
            ], first: true)
          else if (shapeActs.isNotEmpty)
            PlateSection('모양 다듬기', [plateActions(shapeActs)], first: true),
          if (s.n > 0 || s.holes.isNotEmpty)
            PlateSection('지우기', [
              Align(
                alignment: Alignment.centerLeft,
                child: PlateActionButton(
                  key: const Key('sk_clear'),
                  icon: Icons.layers_clear_outlined,
                  label: '그림 지우기',
                  danger: true,
                  onTap: _confirmClear,
                ),
              ),
            ], first: sel == null && shapeActs.isEmpty),
        ];
      case 'dims':
        sections = [
          if (s.closed)
            PlateSection('변 길이 (누르면 고침)', [
              Column(
                key: const Key('sk_edges'),
                children: [
                  for (var i = 0; i < s.edgeCount; i++) ...[
                    if (i > 0) Divider(height: 1, color: fc.line),
                    InkWell(
                      key: Key('sk_edge_$i'),
                      onTap: () => _editEdge(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 11,
                          horizontal: 2,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '변 ${i + 1}→${(i + 1) % s.n + 1}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: fc.textSub,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              s.scaled
                                  ? '${_f(s.edgeLen(i))} mm${s.edgeMatches(i) == null ? '' : (s.edgeMatches(i)! ? ' ✓' : ' !')}'
                                  : '길이 넣기',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: s.edgeMatches(i) == false
                                    ? fc.danger
                                    : (s.edgeMatches(i) == true
                                          ? fc.ok
                                          : fc.text),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              AppIcons.forward,
                              size: 16,
                              color: fc.textFaint,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ], first: true),
        ];
      case 'holes':
        final selH = _selHole;
        sections = [
          PlateSection('홀 지름', [
            PlateSegments(joined: false, [
              for (final d in const [9.0, 11.0, 13.5, 17.5, 22.0])
                PlateOption(
                  'sk_dia_${(d * 10).round()}',
                  'φ${_f(d)}',
                  _tDia == d,
                  () => setState(() => _tDia = d),
                ),
            ]),
          ], first: true),
          if (selH != null && selH < s.holes.length)
            PlateSection('홀 ${selH + 1}', [
              plateActions([
                _btn(
                  'sk_hole_edit',
                  Icons.tune,
                  '위치·크기 수정',
                  () => _editHole(selH),
                ),
                PlateActionButton(
                  key: const Key('sk_hole_del'),
                  icon: AppIcons.delete,
                  label: '홀 지우기',
                  danger: true,
                  onTap: () => _change(() {
                    _s.holes.removeAt(selH);
                    _selHole = null;
                  }),
                ),
              ]),
            ]),
        ];
      default:
        final b = s.toPlateMap() == null ? null : s.bounds;
        sections = [
          if (b != null)
            PlateSection('보낼 모양', [
              PlateInfoRow('크기', '${_f(b.width)} × ${_f(b.height)} mm'),
              PlateInfoRow('꼭짓점', '${s.n}개'),
              PlateInfoRow('홀', '${s.holes.length}개'),
              if (s.thickness != null)
                PlateInfoRow('두께', '${_f(s.thickness!)}T'),
            ], first: true),
        ];
    }
    return PlatePanel(
      title: _tabs[_tab].$2,
      status: _status(),
      statusKey: const Key('sk_status'),
      statusColor: fc.text,
      below: [
        if (_notice != null)
          Text(
            _notice!,
            key: const Key('sk_notice'),
            style: TextStyle(
              fontSize: 13.5,
              color: _noticeBad ? fc.danger : fc.ok,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        if (_aiError != null && _tabId == 'photo')
          Text(
            '$_aiError. "다음: 그리기"에서 사진 위에 직접 따라 그릴 수 있습니다.',
            key: const Key('sk_ai_error'),
            style: TextStyle(fontSize: 13.5, color: fc.danger, height: 1.35),
          ),
        if (s.unclear.isNotEmpty && (_tabId == 'photo' || _tabId == 'dims'))
          Text(
            'AI가 짐작한 곳: ${s.unclear.join(' / ')}',
            key: const Key('sk_unclear'),
            style: TextStyle(fontSize: 13.5, color: fc.caution, height: 1.35),
          ),
        if (_tabId == 'dims' || _tabId == 'send')
          for (final p in problems.take(2))
            Text(
              p,
              style: TextStyle(fontSize: 13.5, color: fc.danger, height: 1.35),
            ),
      ],
      actions: [
        plateHelpButton(
          context,
          'sk_help_$_tabId',
          '${_tabs[_tab].$2} 탭',
          _help(),
        ),
      ],
      footer: _footer(),
      children: sections,
    );
  }
}

// 변 길이 창의 결과: 길이를 넣었거나, 잠금을 풀었거나.
class _LenResult {
  final double? mm;
  final bool unlock;
  const _LenResult({this.mm, this.unlock = false});
}

class _LengthDialog extends StatefulWidget {
  const _LengthDialog({
    required this.title,
    required this.initial,
    required this.locked,
  });
  final String title;
  final double? initial;
  final bool locked;

  @override
  State<_LengthDialog> createState() => _LengthDialogState();
}

class _LengthDialogState extends State<_LengthDialog> {
  late final _c = TextEditingController(
    text: widget.initial == null ? '' : _f(widget.initial!),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: widget.title,
    okText: '넣기',
    okKey: const Key('sk_len_ok'),
    onCancel: () => Navigator.pop(context),
    onOk: () => Navigator.pop(
      context,
      _LenResult(mm: double.tryParse(_c.text.trim().replaceAll(',', '.'))),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('sk_len'),
          controller: _c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: appFieldTextStyle,
          decoration: appFieldDecoration('길이 (mm)'),
        ),
        const SizedBox(height: 8),
        Text(
          widget.locked
              ? '넣은 치수라 잠겨 있습니다. 다른 변을 고쳐도 되도록 이 길이는 그대로 둡니다.'
              : '넣으면 잠깁니다. 같은 방향의 다른 변이 차이를 받습니다(잠기지 않은 변 먼저).',
          style: TextStyle(color: fc.textSub, fontSize: 13, height: 1.35),
        ),
        if (widget.locked)
          TextButton(
            key: const Key('sk_len_unlock'),
            onPressed: () =>
                Navigator.pop(context, const _LenResult(unlock: true)),
            child: const Text('잠금 풀기'),
          ),
      ],
    ),
  );
}

class _SketchPainter extends CustomPainter {
  _SketchPainter({
    required this.sketch,
    required this.image,
    required this.toScreen,
    required this.scale,
    required this.selPt,
    required this.selHole,
    required this.colors,
    this.ink,
    this.hint = '',
    this.showCenter = true,
    this.paper,
  });

  final bool showCenter;

  /// 흰 종이 자리(그림 단위). 없으면 [PlateSketch.frame].
  final Rect? paper;

  final List<Offset>? ink;

  /// 빈 종이 가운데 안내 글(탭마다 다름).
  final String hint;
  final PlateSketch sketch;
  final ui.Image? image;
  final Offset Function(Offset) toScreen;
  final double scale;
  final int? selPt, selHole;
  final FieldPalette colors;

  @override
  void paint(Canvas canvas, Size size) {
    final s = sketch;
    final c = colors;
    // 종이(또는 사진) 자리
    final fr = s.frame;
    final frRect = Rect.fromPoints(
      toScreen(Offset(fr.left, fr.bottom)),
      toScreen(Offset(fr.right, fr.top)),
    );
    final img = image;
    if (img != null) {
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        frRect,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = const Color.fromRGBO(0, 0, 0, 0.8),
      );
    } else {
      final pp = paper ?? fr;
      final pr = Rect.fromPoints(
        toScreen(Offset(pp.left, pp.bottom)),
        toScreen(Offset(pp.right, pp.top)),
      );
      canvas.drawRect(pr, Paint()..color = c.surface);
      canvas.drawRect(
        pr,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = c.line,
      );
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round
      ..color = c.brand;

    // 빈 종이 안내
    if (s.n == 0 && img == null && (ink == null || ink!.isEmpty)) {
      final tp = TextPainter(
        text: TextSpan(
          text: hint,
          style: TextStyle(
            color: c.textFaint,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: frRect.width - 24);
      tp.paint(canvas, frRect.center - Offset(tp.width / 2, tp.height / 2));
    }
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = c.textSub;

    // 외곽: 닫고 치수가 정해졌으면 귀 처리까지 그린 실제 외곽, 닫기 전에는 찍은 차례대로 + 1번으로 가는 점선
    if (s.n >= 2) {
      final poly = Path()..moveTo(toScreen(s.pts[0]).dx, toScreen(s.pts[0]).dy);
      for (var k = 1; k < s.n; k++) {
        final p = toScreen(s.pts[k]);
        poly.lineTo(p.dx, p.dy);
      }
      if (s.closed) poly.close();
      if (s.closed && s.scaled) {
        canvas.drawPath(poly, thin);
        final out = plateOutlinePoints(
          plateCornerOutline(s.pts, s.corners, (_) {}),
        );
        if (out.length >= 2) {
          final path = Path()..moveTo(toScreen(out[0]).dx, toScreen(out[0]).dy);
          for (final p in out.skip(1)) {
            final q = toScreen(p);
            path.lineTo(q.dx, q.dy);
          }
          path.close();
          canvas.drawPath(
            path,
            Paint()..color = c.brand.withValues(alpha: 0.10),
          );
          canvas.drawPath(path, line);
        }
      } else {
        if (s.closed) {
          canvas.drawPath(
            poly,
            Paint()..color = c.brand.withValues(alpha: 0.06),
          );
        }
        canvas.drawPath(poly, line);
        if (!s.closed && s.n >= 3) {
          final a = toScreen(s.pts[s.n - 1]), b = toScreen(s.pts[0]);
          final d = b - a, len = d.distance;
          final dash = Paint()
            ..strokeWidth = 1.4
            ..color = c.textSub;
          for (var t = 0.0; t < len; t += 12) {
            canvas.drawLine(
              a + d * (t / len),
              a + d * (math.min(t + 6, len) / len),
              dash,
            );
          }
        }
      }
    }

    // 판 가운데 십자 중심선(닫은 뒤, 변 길이 글 밑으로 지나가게 먼저 그린다)
    final bb = s.bounds;
    if (showCenter && s.closed && bb != null) {
      plateDrawCenterLines(
        canvas,
        toScreen: toScreen,
        minX: bb.left,
        minY: bb.top,
        maxX: bb.right,
        maxY: bb.bottom,
        ext: 44, // 변 이름표(변 가운데 바깥 16점) 너머로
      );
    }

    // 변 길이(누르면 길이 창)
    for (var i = 0; i < s.edgeCount; i++) {
      final at = sketchLabelAt(s, i, toScreen);
      if (at == null) continue;
      final ok = s.edgeMatches(i);
      final txt = s.scaled
          ? '${_f(s.edgeLen(i))}${ok == null ? '' : (ok ? ' ✓' : ' !')}'
          : '변 ${i + 1}';
      final color = ok == false ? c.danger : (ok == true ? c.ok : c.text);
      _label(canvas, at, txt, color, boxed: true);
    }

    // 구멍
    for (var k = 0; k < s.holes.length; k++) {
      final h = s.holes[k];
      final cen = toScreen(Offset(h.u, h.v));
      final r = s.scaled ? math.max(h.dia / 2 * scale, 4.0) : 8.0;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = k == selHole ? 3 : 2
        ..color = k == selHole ? c.caution : c.text;
      if (s.scaled && h.slot > h.dia) {
        final half = (h.slot - h.dia) / 2 * scale;
        final a = -h.angle * math.pi / 180; // 화면은 y가 아래라 각도를 뒤집는다
        canvas.save();
        canvas.translate(cen.dx, cen.dy);
        canvas.rotate(a);
        final rr = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: half * 2 + r * 2,
            height: r * 2,
          ),
          Radius.circular(r),
        );
        canvas.drawRRect(rr, Paint()..color = c.surface.withValues(alpha: 0.6));
        canvas.drawRRect(rr, p);
        canvas.restore();
      } else {
        canvas.drawCircle(
          cen,
          r,
          Paint()..color = c.surface.withValues(alpha: 0.6),
        );
        canvas.drawCircle(cen, r, p);
      }
      final cross = Paint()
        ..strokeWidth = 1
        ..color = p.color;
      canvas.drawLine(
        cen - const Offset(4, 0),
        cen + const Offset(4, 0),
        cross,
      );
      canvas.drawLine(
        cen - const Offset(0, 4),
        cen + const Offset(0, 4),
        cross,
      );
    }

    // 긋는 중인 선
    final k0 = ink;
    if (k0 != null && k0.length >= 2) {
      final path = Path()..moveTo(toScreen(k0[0]).dx, toScreen(k0[0]).dy);
      for (final p in k0.skip(1)) {
        final q = toScreen(p);
        path.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = c.caution,
      );
    }

    // 꼭짓점과 번호(닫기 전 1번 점은 링을 둘러 "여기를 누르면 닫힘"을 보인다)
    for (var k = 0; k < s.n; k++) {
      final p = toScreen(s.pts[k]);
      final on = k == selPt;
      if (!s.closed && k == 0 && s.n >= 3) {
        canvas.drawCircle(
          p,
          14,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = c.ok,
        );
      }
      canvas.drawCircle(
        p,
        on ? 10 : 7,
        Paint()..color = on ? c.caution : c.brand,
      );
      canvas.drawCircle(
        p,
        on ? 10 : 7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = c.surface,
      );
      final corner = s.corners[k];
      _label(
        canvas,
        p + const Offset(16, -16),
        corner.isNone ? '${k + 1}' : '${k + 1} ${corner.label}',
        c.text,
        small: true,
      );
    }
  }

  void _label(
    Canvas canvas,
    Offset at,
    String text,
    Color color, {
    bool small = false,
    bool boxed = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: small ? 12 : 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = Rect.fromCenter(
      center: at,
      width: tp.width + (boxed ? 12 : 8),
      height: tp.height + (boxed ? 8 : 4),
    );
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(6));
    canvas.drawRRect(
      rr,
      Paint()..color = colors.surface.withValues(alpha: boxed ? 0.95 : 0.85),
    );
    // 길이 글은 누를 수 있다는 표시로 테두리
    if (boxed) {
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = colors.line,
      );
    }
    tp.paint(
      canvas,
      Offset(r.center.dx - tp.width / 2, r.center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SketchPainter old) => true;
}
