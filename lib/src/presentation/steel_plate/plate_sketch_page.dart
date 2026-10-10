// 철판 가공 › 손그림 읽어 만들기(10-10): 종이에 그린 철판 그림 사진을 AI가 읽어 외곽·구멍·두께로 옮기고,
// AI가 안 되거나 통신이 없으면 사진 위에 꼭짓점을 직접 찍는다. 변을 눌러 치수(mm)를 넣고, 직각을 맞추고,
// 귀 처리를 준 뒤 "레이저 절단으로 보내기"로 레이저 절단 화면(자유 모양)에 넘긴다.
// 그림 자료와 고치는 계산은 plate_sketch_model.dart. 화면 손놀림은 구멍 배치 편집과 같다.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/field_view.dart';
import '../../core/utils/ai_plate_sketch.dart';
import '../calculator/widgets/app_dialog.dart';
import '../common/calc_form_parts.dart';
import 'plate_calc.dart';
import 'plate_hole_editor.dart' show PlateNumbersDialog;
import 'plate_page.dart';
import 'plate_sketch_model.dart';

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

enum _Mode { point, hole, dim }

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
  _Mode _mode = _Mode.point;
  int? _selPt, _selHole;
  double _tDia = 13.5;
  bool _showPhoto = true;
  bool _busy = false;
  String? _aiError;
  bool _ready = false;

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
      final raw = p.getString(PlateSketchPage.draftKey);
      final s = raw == null ? null : PlateSketch.fromJson(jsonDecode(raw));
      if (s != null) _s = s;
    } catch (_) {}
    final photo = await widget.loadPhoto();
    if (photo != null && mounted) _setPhoto(photo, keepSketch: true);
    if (!mounted) return;
    setState(() {
      _ready = true;
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
    final rescaled =
        s.scaled != _s.scaled ||
        s.photoAligned != _s.photoAligned ||
        s.frame != _s.frame;
    setState(() {
      _s = s;
      _selPt = null;
      _selHole = null;
      if (rescaled) _fit();
    });
    _saveSoon();
  }

  // ── 사진 ──

  /// 사진을 바로 쓰고(AI 읽기), 그림으로 푸는 것은 뒤에서 한다(다 풀리면 사진 위에 겹쳐 그린다).
  void _setPhoto(Uint8List bytes, {bool keepSketch = false}) {
    setState(() {
      _photo = bytes;
      if (!keepSketch) {
        _s = PlateSketch();
        _aiError = null;
        _selPt = null;
        _selHole = null;
        _mode = _Mode.point;
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
        _s.frame = Rect.fromLTWH(
          0,
          0,
          img.width.toDouble(),
          img.height.toDouble(),
        );
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
          content: AppDialog.message('지금 찍어 둔 꼭짓점·구멍·치수는 지워지고 되돌릴 수 없습니다.'),
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
      _mode = _Mode.dim;
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
  void _startTrace() {
    final img = _img;
    _change(() {
      _s = PlateSketch(
        frame: img == null
            ? const Rect.fromLTWH(0, 0, 400, 300)
            : Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      );
      _mode = _Mode.point;
      _selPt = null;
      _selHole = null;
      _showPhoto = true;
      _fit();
    });
  }

  void _clearSketch() => _change(() {
    final keep = _s.photoAligned ? _s.frame : null;
    final img = _img;
    _s = PlateSketch(
      frame:
          keep ??
          (img == null
              ? const Rect.fromLTWH(0, 0, 400, 300)
              : Rect.fromLTWH(
                  0,
                  0,
                  img.width.toDouble(),
                  img.height.toDouble(),
                )),
      scaled: _s.photoAligned && _s.scaled,
    );
    _selPt = null;
    _selHole = null;
    _mode = _Mode.point;
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
            title: const Text('그림 사진'),
          ),
          body: InteractiveViewer(
            maxScale: 8,
            child: Center(child: Image.memory(photo)),
          ),
        ),
      ),
    );
  }

  // ── 좌표 ──

  void _fit() {
    var r = _s.frame;
    final b = _s.bounds;
    if (b != null) r = r.expandToInclude(b);
    _view = r;
    _zoom = 1;
    _pan = Offset.zero;
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

  // ── 손놀림 ──

  void _onTap(TapUpDetails d) {
    final m = _toModel(d.localPosition);
    switch (_mode) {
      case _Mode.point:
        final hit = _s.hitPoint(m, _tol);
        if (hit != null) {
          setState(() => _selPt = _selPt == hit ? null : hit);
        } else if (_selPt != null) {
          setState(() => _selPt = null);
        } else {
          _change(() => _s.addPoint(m));
        }
      case _Mode.hole:
        final hit = _s.hitHole(m, _tol);
        if (hit != null) {
          setState(() => _selHole = _selHole == hit ? null : hit);
        } else if (_selHole != null) {
          setState(() => _selHole = null);
        } else {
          _change(() {
            _s.holes.add(PlateHoleSpec(u: m.dx, v: m.dy, dia: _tDia));
            _selHole = null;
          });
        }
      case _Mode.dim:
        final h = _s.hitHole(m, _tol);
        if (h != null) {
          _editHole(h);
          return;
        }
        final e = _s.hitEdge(m, _tol);
        if (e != null) _editEdge(e);
    }
  }

  void _onLongPress(LongPressStartDetails d) {
    if (_mode != _Mode.point) return;
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
    if (_mode == _Mode.point) {
      final hit = _s.hitPoint(m, _tol);
      if (hit != null) {
        _push();
        _dragPt = hit;
        _dragFrom = _s.pts[hit];
        setState(() => _selPt = hit);
        return;
      }
    } else if (_mode == _Mode.hole) {
      final hit = _s.hitHole(m, _tol);
      if (hit != null) {
        _push();
        _dragHole = hit;
        final h = _s.holes[hit];
        _dragFrom = Offset(h.u, h.v);
        setState(() => _selHole = hit);
        return;
      }
    }
    _panning = true;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
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
      final h = _s.holes[k];
      final p = _dragFrom + dm;
      setState(() => _s.holes[k] = h.copyWith(u: p.dx, v: p.dy));
      return;
    }
    if (_panning) setState(() => _pan = _pan0 + dv);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    final dragged = _dragPt != null || _dragHole != null;
    _dragPt = null;
    _dragHole = null;
    _panning = false;
    _pinching = false;
    if (dragged) _saveSoon();
  }

  // ── 치수·귀 처리 창 ──

  Future<List<double>?> _numbers(String title, List<(String, double)> f) =>
      showDialog<List<double>>(
        context: context,
        builder: (_) => PlateNumbersDialog(title: title, fields: f),
      );

  Future<void> _editEdge(int i) async {
    final j = (i + 1) % _s.n;
    final r = await _numbers('변 ${i + 1}→${j + 1} 길이', [
      ('길이 (mm)', _s.scaled ? double.parse(_f(_s.edgeLen(i))) : double.nan),
    ]);
    if (r == null || !mounted) return;
    final mm = r.first;
    if (!mm.isFinite || mm <= 0) {
      _say('길이를 mm로 넣으십시오', bad: true);
      return;
    }
    final first = !_s.scaled;
    _push();
    final f = first ? mm / math.max(_s.edgeLen(i), 1e-9) : 1.0;
    setState(() {
      _notice = null;
      _s.setEdge(i, mm);
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
    if (first && mounted) {
      _say('이 치수로 전체 크기를 맞췄습니다. 나머지 변도 눌러 넣으십시오.');
    }
  }

  Future<void> _editHole(int k) async {
    if (!_s.scaled) {
      _say('먼저 변 하나에 치수를 넣으십시오(그래야 mm가 정해집니다)', bad: true);
      return;
    }
    final b = _s.bounds ?? Rect.zero;
    final h = _s.holes[k];
    final r = await _numbers('구멍 ${k + 1}', [
      ('가로 자리 (판 왼쪽 끝에서, mm)', double.parse(_f(h.u - b.left))),
      ('세로 자리 (판 아래 끝에서, mm)', double.parse(_f(h.v - b.top))),
      ('지름 (mm)', h.dia),
      ('장공 길이 (mm, 둥근 구멍은 0)', h.slot),
      ('장공 각도 (°, 가로 0)', h.angle),
    ]);
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
    final c = await showDialog<PlateCorner>(
      context: context,
      builder: (_) =>
          _CornerDialog(title: '꼭짓점 ${k + 1} 귀 처리', initial: _s.corners[k]),
    );
    if (c == null || !mounted) return;
    _change(() => _s.corners[k] = c);
  }

  void _squareUp() {
    if (_s.n < 2) return;
    _push();
    final before = jsonEncode(_s.toJson());
    var k = 0;
    setState(() => k = _s.squareUp());
    if (k == 0) {
      _undo.remove(before);
      _say('바로 세울 변이 없습니다(가로·세로에서 10° 넘게 기운 변은 그대로 둡니다)');
      return;
    }
    _saveSoon();
    _say('변 $k개를 가로·세로로 바로 세웠습니다');
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
    if (!_s.scaled || _s.n < 3) return const [];
    final out = <String>[];
    plateCornerOutline(_s.pts, _s.corners, (w) {
      if (!out.contains(w)) out.add(w);
    });
    return out;
  }

  String _status() {
    final s = _s;
    if (s.n == 0) {
      return _photo == null
          ? '사진을 찍거나 고르십시오. 사진 없이 빈 칸에 판 귀퉁이를 차례로 눌러 그려도 됩니다.'
          : '"AI로 읽기"를 눌러 보십시오. 직접 하려면 사진 속 판 귀퉁이를 한 방향으로 돌며 차례로 누릅니다.';
    }
    final dimsIn = [
      for (var i = 0; i < s.edgeCount; i++)
        if (s.dimOf(i) != null) i,
    ].length;
    switch (_mode) {
      case _Mode.point:
        final k = _selPt;
        if (k != null && k < s.n) {
          return '꼭짓점 ${k + 1}: ${s.corners[k].label}. 끌어 옮기거나 귀 처리·지우기를 누릅니다.';
        }
        return '꼭짓점 ${s.n}개. 빈 곳을 누르면 끝에 더하고, 변을 길게 누르면 그 자리에 끼웁니다.';
      case _Mode.hole:
        if (!s.scaled) return '구멍 자리를 누릅니다. 구멍 크기는 치수를 넣은 뒤에 맞게 보입니다.';
        final k = _selHole;
        if (k != null && k < s.holes.length) {
          final h = s.holes[k];
          return '구멍 ${k + 1}: φ${_f(h.dia)}${h.slot > h.dia ? ' 장공 ${_f(h.slot)}' : ''}. 끌어 옮기거나 지웁니다.';
        }
        return '구멍 ${s.holes.length}개. 빈 곳을 누르면 φ${_f(_tDia)} 구멍을 놓습니다.';
      case _Mode.dim:
        if (!s.scaled) {
          return '변을 눌러 길이(mm)를 넣습니다. 처음 넣는 치수로 전체 크기가 정해집니다.';
        }
        return '변을 누르면 길이를, 구멍을 누르면 자리·지름을 고칩니다. 넣은 치수 $dimsIn곳(✓ 맞음, ! 바뀜).';
    }
  }

  // ── 화면 ──

  @override
  Widget build(BuildContext context) {
    final problems = _problems();
    return FieldViewTheme(
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: fc.background,
          appBar: AppBar(
            backgroundColor: fc.surface,
            foregroundColor: fc.text,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              '손그림 읽어 만들기',
              style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
            ),
            actions: [
              IconButton(
                key: const Key('sk_undo'),
                tooltip: '되돌리기',
                onPressed: _undo.isEmpty ? null : () => _restore(_undo, _redo),
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                key: const Key('sk_redo'),
                tooltip: '다시 하기',
                onPressed: _redo.isEmpty ? null : () => _restore(_redo, _undo),
                icon: const Icon(Icons.redo),
              ),
              IconButton(
                key: const Key('sk_fit'),
                tooltip: '전체 보기',
                onPressed: () => setState(_fit),
                icon: const Icon(Icons.fit_screen_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
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
                            showDims: true,
                            colors: fc,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _panel(problems),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(String key, IconData icon, String label, VoidCallback? onTap) =>
      OutlinedButton.icon(
        key: Key(key),
        style: OutlinedButton.styleFrom(
          foregroundColor: fc.text,
          side: BorderSide(color: fc.line),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  // 아래 칸은 높이를 못박는다(바꿀 때마다 그림이 들썩이지 않게).
  Widget _panel(List<String> problems) {
    final s = _s;
    final sel = _selPt;
    final selH = _selHole;
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: BoxDecoration(
        color: fc.surface,
        border: Border(top: BorderSide(color: fc.line)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _status(),
              key: const Key('sk_status'),
              style: TextStyle(
                color: fc.text,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _notice!,
                  key: const Key('sk_notice'),
                  style: TextStyle(
                    color: _noticeBad ? fc.danger : fc.ok,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ),
            if (_aiError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$_aiError. 사진 위에 직접 따라 찍을 수 있습니다.',
                  key: const Key('sk_ai_error'),
                  style: TextStyle(color: fc.danger, height: 1.35),
                ),
              ),
            if (s.unclear.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'AI가 짐작한 곳: ${s.unclear.join(' / ')}',
                  key: const Key('sk_unclear'),
                  style: TextStyle(color: fc.caution, height: 1.35),
                ),
              ),
            for (final p in problems.take(2))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  p,
                  style: TextStyle(color: fc.danger, height: 1.35),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
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
                if (_photo != null)
                  FilledButton.icon(
                    key: const Key('sk_ai'),
                    style: FilledButton.styleFrom(
                      backgroundColor: fc.brand,
                      foregroundColor: fc.onBrand,
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
                      _busy ? '읽는 중' : 'AI로 읽기',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                if (_photo != null && !s.photoAligned)
                  _btn(
                    'sk_trace',
                    Icons.touch_app_outlined,
                    '사진 위에 따라 찍기',
                    _startTrace,
                  ),
                if (_photo != null && !s.photoAligned)
                  _btn(
                    'sk_photo_view',
                    Icons.image_outlined,
                    '사진 보기',
                    _viewPhoto,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                calcChip(
                  'sk_mode_point',
                  '꼭짓점',
                  _mode == _Mode.point,
                  () => setState(() {
                    _mode = _Mode.point;
                    _selHole = null;
                  }),
                ),
                calcChip(
                  'sk_mode_dim',
                  '치수 넣기',
                  _mode == _Mode.dim,
                  () => setState(() {
                    _mode = _Mode.dim;
                    _selPt = null;
                    _selHole = null;
                  }),
                ),
                calcChip(
                  'sk_mode_hole',
                  '구멍',
                  _mode == _Mode.hole,
                  () => setState(() {
                    _mode = _Mode.hole;
                    _selPt = null;
                  }),
                ),
                if (_img != null && s.photoAligned)
                  calcChip(
                    'sk_show_photo',
                    '사진 겹쳐 보기',
                    _showPhoto,
                    () => setState(() => _showPhoto = !_showPhoto),
                  ),
              ],
            ),
            if (_mode == _Mode.point && sel != null && sel < s.n) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _btn(
                    'sk_corner',
                    Icons.rounded_corner,
                    '귀 처리',
                    () => _editCorner(sel),
                  ),
                  _btn('sk_del', Icons.delete_outline, '꼭짓점 지우기', () {
                    _change(() {
                      _s.removePoint(sel);
                      _selPt = null;
                    });
                  }),
                ],
              ),
            ],
            if (_mode == _Mode.hole) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in const [9.0, 11.0, 13.5, 17.5, 22.0])
                    calcChip(
                      'sk_dia_${(d * 10).round()}',
                      'φ${_f(d)}',
                      _tDia == d,
                      () => setState(() => _tDia = d),
                    ),
                  if (selH != null && selH < s.holes.length)
                    _btn('sk_hole_del', Icons.delete_outline, '구멍 지우기', () {
                      _change(() {
                        _s.holes.removeAt(selH);
                        _selHole = null;
                      });
                    }),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _btn(
                  'sk_square',
                  Icons.square_foot,
                  '직각 맞추기',
                  s.n < 2 ? null : _squareUp,
                ),
                _btn(
                  'sk_clear',
                  Icons.layers_clear_outlined,
                  '그림 지우기',
                  s.n == 0 && s.holes.isEmpty ? null : _clearSketch,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('sk_send'),
                style: FilledButton.styleFrom(
                  backgroundColor: fc.brand,
                  foregroundColor: fc.onBrand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _send,
                icon: const Icon(Icons.arrow_forward),
                label: const Text(
                  '레이저 절단으로 보내기',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 귀 처리 하나를 고르는 창(직각·R·C·따내기와 크기).
class _CornerDialog extends StatefulWidget {
  const _CornerDialog({required this.title, required this.initial});
  final String title;
  final PlateCorner initial;

  @override
  State<_CornerDialog> createState() => _CornerDialogState();
}

class _CornerDialogState extends State<_CornerDialog> {
  late PlateCornerKind _kind = widget.initial.kind;
  late final _a = TextEditingController(
    text: widget.initial.a > 0 ? _f(widget.initial.a) : '10',
  );
  late final _b = TextEditingController(
    text: widget.initial.b > 0 ? _f(widget.initial.b) : _a.text,
  );

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) => AppDialog(
    title: widget.title,
    okText: '적용',
    okKey: const Key('sk_corner_ok'),
    onCancel: () => Navigator.pop(context),
    onOk: () {
      final a = _num(_a), b = _num(_b);
      Navigator.pop(
        context,
        _kind == PlateCornerKind.none || a <= 0
            ? PlateCorner.square
            : PlateCorner(
                _kind,
                a,
                _kind == PlateCornerKind.notch ? (b > 0 ? b : a) : 0,
              ),
      );
    },
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (k, label) in const [
                (PlateCornerKind.none, '직각'),
                (PlateCornerKind.round, 'R 둥글게'),
                (PlateCornerKind.chamfer, 'C 모따기'),
                (PlateCornerKind.notch, '따내기'),
              ])
                ChoiceChip(
                  key: Key('sk_ck_${k.name}'),
                  label: Text(label),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
          if (_kind != PlateCornerKind.none) ...[
            const SizedBox(height: 12),
            TextField(
              key: const Key('sk_ca'),
              controller: _a,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: appFieldTextStyle,
              decoration: appFieldDecoration(switch (_kind) {
                PlateCornerKind.round => 'R (mm)',
                PlateCornerKind.chamfer => 'C (mm)',
                _ => '따내기: 앞 변 쪽 (mm)',
              }),
            ),
          ],
          if (_kind == PlateCornerKind.notch) ...[
            const SizedBox(height: 10),
            TextField(
              key: const Key('sk_cb'),
              controller: _b,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: appFieldTextStyle,
              decoration: appFieldDecoration('따내기: 다음 변 쪽 (mm)'),
            ),
            const SizedBox(height: 6),
            Text(
              '앞 변은 앞 번호 꼭짓점에서 오는 변, 다음 변은 다음 번호 꼭짓점으로 가는 변입니다.',
              style: TextStyle(color: fc.textSub, fontSize: 13, height: 1.35),
            ),
          ],
        ],
      ),
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
    required this.showDims,
    required this.colors,
  });

  final PlateSketch sketch;
  final ui.Image? image;
  final Offset Function(Offset) toScreen;
  final double scale;
  final int? selPt, selHole;
  final bool showDims;
  final FieldPalette colors;

  @override
  void paint(Canvas canvas, Size size) {
    final s = sketch;
    final c = colors;
    // 종이(또는 사진) 자리
    final fr = s.frame;
    final tl = toScreen(Offset(fr.left, fr.bottom));
    final br = toScreen(Offset(fr.right, fr.top));
    final frRect = Rect.fromPoints(tl, br);
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
    } else if (s.photoAligned) {
      canvas.drawRect(frRect, Paint()..color = c.surface);
      canvas.drawRect(
        frRect,
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
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = c.textSub;

    // 외곽: 치수가 정해지고 점이 셋 이상이면 귀 처리까지 그린 실제 외곽
    if (s.n >= 2) {
      final poly = Path()..moveTo(toScreen(s.pts[0]).dx, toScreen(s.pts[0]).dy);
      for (var k = 1; k < s.n; k++) {
        final p = toScreen(s.pts[k]);
        poly.lineTo(p.dx, p.dy);
      }
      if (s.n >= 3) poly.close();
      if (s.scaled && s.n >= 3) {
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
        canvas.drawPath(poly, line);
      }
    }

    // 변 길이
    if (showDims) {
      for (var i = 0; i < s.edgeCount; i++) {
        final a = toScreen(s.pts[i]), b = toScreen(s.edgeEnd(i));
        final mid = (a + b) / 2;
        final v = b - a;
        if (v.distance < 24) continue;
        var nrm = Offset(v.dy, -v.dx) / v.distance;
        // 바깥쪽(그림 가운데에서 먼 쪽)으로
        final cen = s.bounds == null ? mid : toScreen(s.bounds!.center);
        if ((mid + nrm * 10 - cen).distance < (mid - cen).distance) nrm = -nrm;
        final ok = s.edgeMatches(i);
        final txt = s.scaled
            ? '${_f(s.edgeLen(i))}${ok == null ? '' : (ok ? ' ✓' : ' !')}'
            : '변 ${i + 1}';
        final color = ok == false ? c.danger : (ok == true ? c.ok : c.text);
        _label(canvas, mid + nrm * 16, txt, color);
      }
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
        final ax = Offset(math.cos(a), math.sin(a)) * half;
        canvas.drawLine(
          cen - ax,
          cen + ax,
          Paint()
            ..strokeWidth = r * 2
            ..strokeCap = StrokeCap.round
            ..color = c.surface.withValues(alpha: 0.6),
        );
        final path = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: half * 2 + r * 2,
                height: r * 2,
              ),
              Radius.circular(r),
            ),
          );
        canvas.save();
        canvas.translate(cen.dx, cen.dy);
        canvas.rotate(a);
        canvas.drawPath(path, p);
        canvas.restore();
      } else {
        canvas.drawCircle(
          cen,
          r,
          Paint()..color = c.surface.withValues(alpha: 0.6),
        );
        canvas.drawCircle(cen, r, p);
      }
      canvas.drawLine(
        cen - const Offset(4, 0),
        cen + const Offset(4, 0),
        p..strokeWidth = 1,
      );
      canvas.drawLine(cen - const Offset(0, 4), cen + const Offset(0, 4), p);
    }

    // 꼭짓점과 번호
    for (var k = 0; k < s.n; k++) {
      final p = toScreen(s.pts[k]);
      final on = k == selPt;
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
        p + const Offset(14, -14),
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
      width: tp.width + 8,
      height: tp.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(5)),
      Paint()..color = colors.surface.withValues(alpha: 0.85),
    );
    tp.paint(canvas, r.topLeft + const Offset(4, 2));
  }

  @override
  bool shouldRepaint(covariant _SketchPainter old) => true;
}
