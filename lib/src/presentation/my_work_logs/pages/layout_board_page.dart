import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: deprecated_member_use
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ---------------------------------------------------------
// 🎨 토스(Toss) 디자인 시스템 색상
// ---------------------------------------------------------
const Color tossBlue = Color(0xFF007580); // 🚀 마키타 틸로 통일
const Color tossText = Color(0xFF191F28);
const Color tossSubText = Color(0xFF8B95A1);
const Color tossBg = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

// 🚀 치수선 색상 분리
// 🚀 [수정] 수동 측정(센터)이 녹색, 자동 가이드(센터)가 파란색으로
// 서로 달라 헷갈렸음. "센터"는 수동/자동 어디서나 항상 파란색으로 통일.
const Color centerDimColor = tossBlue; // 센터: 파란색(자동 가이드와 통일)
const Color edgeDimColor = Color(0xFFF68657); // 측면: 주황색
const Color guideCenterColor = tossBlue; // 가상선(센터): 파란색

// ---------------------------------------------------------
// 1. 데이터 모델
// ---------------------------------------------------------
enum DimensionType { center, edge }

// 🚀 [정리] 정밀 튜빙 라인 모드는 폰 화면에서 점을 하나하나 정밀하게
// 찍어야 해서 부담이 크다는 판단으로 제거. 모듈 배치/이동, 고정 치수
// 측정 두 가지만 남긴다.
enum BoardMode { placeModule, measureDimension }

// 🚀 [추가] 드래그로 도면에 놓을 모듈의 기본값(이름+가로/세로)을 함께
// 실어 나르기 위한 드래그 페이로드. 예전엔 이름(String)만 옮기고 크기는
// 무조건 80×80으로 고정되어 있어서, ABS 덕트처럼 폭이 정해진 자재를
// 매번 배치 후 수동으로 크기를 고쳐야 했다.
class ModulePreset {
  final String name;
  final double width;
  final double height;
  const ModulePreset(this.name, this.width, this.height);
}

// 🚀 [수정] 실제 현장에서 쓰는 폭(40/60/80/100mm)만 남김.
// 세로(길이)는 배선 경로에 따라 달라지므로 기본값만 두고, 배치 후
// "모듈 속성 편집"에서 실제 길이에 맞게 조정하면 된다.
const List<ModulePreset> kDuctPresets = [
  ModulePreset("ABS덕트 40mm", 40, 200),
  ModulePreset("ABS덕트 60mm", 60, 200),
  ModulePreset("ABS덕트 80mm", 80, 200),
  ModulePreset("ABS덕트 100mm", 100, 200),
];

abstract class MeasurePoint {
  Offset get center;
  Rect get boundingBox;
  String get id;
  Map<String, dynamic> toJson();
}

class PlacedItem implements MeasurePoint {
  @override
  final String id;
  String name;
  Offset position;
  double width;
  double height;
  bool isSelected;

  PlacedItem({
    required this.id,
    required this.name,
    required this.position,
    this.width = 80.0,
    this.height = 80.0,
    this.isSelected = false,
  });

  @override
  Offset get center =>
      Offset(position.dx + width / 2, position.dy + height / 2);

  @override
  Rect get boundingBox =>
      Rect.fromLTWH(position.dx, position.dy, width, height);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'item',
    'id': id,
    'name': name,
    'x': position.dx,
    'y': position.dy,
    'w': width,
    'h': height,
  };

  factory PlacedItem.fromJson(Map<String, dynamic> j) => PlacedItem(
    id: j['id'] as String,
    name: j['name'] as String? ?? "이름 없음",
    position: Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
    width: (j['w'] as num?)?.toDouble() ?? 80.0,
    height: (j['h'] as num?)?.toDouble() ?? 80.0,
  );
}

class WallPoint implements MeasurePoint {
  @override
  final String id;
  final Offset position;

  WallPoint({required this.position})
    : id = "wall_${position.dx}_${position.dy}";

  @override
  Offset get center => position;

  @override
  Rect get boundingBox => Rect.fromLTWH(position.dx, position.dy, 0, 0);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'wall',
    'id': id,
    'x': position.dx,
    'y': position.dy,
  };

  factory WallPoint.fromJson(Map<String, dynamic> j) => WallPoint(
    position: Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
  );
}

// 🚀 [추가] 저장된 p1/p2는 "item"/"wall" 중 하나라 type 필드로 구분해서
// 복원한다. item 쪽은 저장 당시 좌표를 담은 별개의 PlacedItem이라, 불러온
// 뒤 실제 모듈을 옮겨도 이미 찍힌 치수선은 저장 시점 위치에 고정된다.
MeasurePoint _measurePointFromJson(Map<String, dynamic> j) {
  return j['type'] == 'wall' ? WallPoint.fromJson(j) : PlacedItem.fromJson(j);
}

class PlacedDimension {
  final String id;
  final MeasurePoint p1;
  final MeasurePoint p2;
  final DimensionType type;

  PlacedDimension({
    required this.id,
    required this.p1,
    required this.p2,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'p1': p1.toJson(),
    'p2': p2.toJson(),
    'type': type.name,
  };

  factory PlacedDimension.fromJson(Map<String, dynamic> j) => PlacedDimension(
    id: j['id'] as String,
    p1: _measurePointFromJson(Map<String, dynamic>.from(j['p1'] as Map)),
    p2: _measurePointFromJson(Map<String, dynamic>.from(j['p2'] as Map)),
    type: DimensionType.values.byName(j['type'] as String),
  );
}

// 🚀 [정리] 손으로 앵커를 옮기는 기능은 폰에서 쓰기 부담스럽다는 판단으로
// 제거하고, 센터/측면 자동 계산만 남겼다.
({Offset p1, Offset p2, double distance}) computeDimensionEndpoints(
  PlacedDimension dim,
) {
  final Rect r1 = dim.p1.boundingBox;
  final Rect r2 = dim.p2.boundingBox;

  final double dxCenter = (r1.center.dx - r2.center.dx).abs();
  final double dyCenter = (r1.center.dy - r2.center.dy).abs();

  if (dim.type == DimensionType.center) {
    Offset p1 = r1.center;
    Offset p2 = r2.center;
    p2 = dxCenter > dyCenter ? Offset(p2.dx, p1.dy) : Offset(p1.dx, p2.dy);
    return (p1: p1, p2: p2, distance: (p1 - p2).distance);
  }

  if (dxCenter > dyCenter) {
    final bool isR1Left = r1.center.dx < r2.center.dx;
    final double x1 = isR1Left ? r1.right : r1.left;
    final double x2 = isR1Left ? r2.left : r2.right;
    final double y = (r1.center.dy + r2.center.dy) / 2;
    return (p1: Offset(x1, y), p2: Offset(x2, y), distance: (x1 - x2).abs());
  } else {
    final bool isR1Top = r1.center.dy < r2.center.dy;
    final double y1 = isR1Top ? r1.bottom : r1.top;
    final double y2 = isR1Top ? r2.top : r2.bottom;
    final double x = (r1.center.dx + r2.center.dx) / 2;
    return (p1: Offset(x, y1), p2: Offset(x, y2), distance: (y1 - y2).abs());
  }
}

// ---------------------------------------------------------
// 2. 메인 페이지 화면
// ---------------------------------------------------------
class MobileLayoutBoardPage extends StatefulWidget {
  final String? projectId;

  const MobileLayoutBoardPage({super.key, this.projectId});

  @override
  State<MobileLayoutBoardPage> createState() => _MobileLayoutBoardPageState();
}

class _MobileLayoutBoardPageState extends State<MobileLayoutBoardPage>
    with WidgetsBindingObserver {
  double _panelWidth = 600.0;
  double _panelHeight = 800.0;
  final double _gridSize = 5.0;

  BoardMode _mode = BoardMode.placeModule;
  DimensionType _currentDimType = DimensionType.center;
  bool _isSaving = false;
  // 🚀 [추가] 저장된 프로젝트를 불러오는 동안 표시할 로딩 상태, 그리고
  // 한 번이라도 저장/불러오기가 된 프로젝트의 ID. null이면 "아직 서버에
  // 저장된 적 없는 새 도면" - 이 경우 저장을 누르면 새 문서가 생성되고,
  // 이후엔 이 ID로 계속 같은 문서를 갱신(update)한다.
  bool _isLoadingProject = false;
  String? _currentProjectId;
  String _projectName = "";

  final List<PlacedItem> _placedItems = [];
  final List<PlacedDimension> _dimensions = [];

  MeasurePoint? _dimensionStartPoint;
  PlacedItem? _activeItem;
  PlacedItem? _previewItem;
  Offset _dragRawPosition = Offset.zero;

  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _captureKey = GlobalKey();

  // 🚀 [추가] 서버에 정식 저장하기 전에 앱을 껐다 켜거나 화면을 나가면
  // 작업 중이던 배치가 전부 사라지던 문제(휘발성)를 막기 위한 로컬
  // 임시 저장. 주기적으로 + 앱이 백그라운드로 갈 때 기기에만 저장해두고,
  // 정식으로 서버 저장을 하면 더 이상 필요 없으니 지운다.
  static const String _draftPrefsKey = 'layout_board_draft_v1';
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.projectId != null) {
      _loadProject(widget.projectId!);
    } else {
      _checkAndOfferDraftRecovery();
    }
    _draftTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _saveDraftToPrefs(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    _saveDraftToPrefs();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _saveDraftToPrefs();
    }
  }

  bool get _hasAnyContent =>
      _placedItems.isNotEmpty || _dimensions.isNotEmpty;

  Map<String, dynamic> _buildSnapshotJson() => {
    'projectId': _currentProjectId,
    'projectName': _projectName,
    'panelWidth': _panelWidth,
    'panelHeight': _panelHeight,
    'items': _placedItems.map((e) => e.toJson()).toList(),
    'dimensions': _dimensions.map((e) => e.toJson()).toList(),
  };

  Future<void> _saveDraftToPrefs() async {
    if (!_hasAnyContent) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftPrefsKey, jsonEncode(_buildSnapshotJson()));
    } catch (_) {
      // 로컬 임시 저장은 실패해도 사용자 작업 흐름을 막을 필요는 없다.
    }
  }

  Future<void> _clearDraftPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftPrefsKey);
    } catch (_) {}
  }

  void _applySnapshotJson(Map<String, dynamic> data) {
    _currentProjectId = data['projectId'] as String?;
    _projectName = data['projectName'] as String? ?? "";
    _panelWidth = (data['panelWidth'] as num?)?.toDouble() ?? _panelWidth;
    _panelHeight = (data['panelHeight'] as num?)?.toDouble() ?? _panelHeight;
    _placedItems
      ..clear()
      ..addAll(
        ((data['items'] as List?) ?? []).map(
          (e) => PlacedItem.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    _dimensions
      ..clear()
      ..addAll(
        ((data['dimensions'] as List?) ?? []).map(
          (e) =>
              PlacedDimension.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
  }

  // 🚀 [추가] 새 도면으로 들어왔을 때(특정 프로젝트를 불러온 게 아닐 때)
  // 이전에 저장 안 하고 나간 임시 작업이 남아있으면 이어할지 물어본다.
  Future<void> _checkAndOfferDraftRecovery() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftPrefsKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      final bool resume =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: pureWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "이어서 작업하시겠습니까?",
                style: TextStyle(fontWeight: FontWeight.w800, color: tossText),
              ),
              content: const Text(
                "저장하지 않고 나간 작업 내용이 남아있습니다.",
                style: TextStyle(color: tossSubText),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    "새로 시작",
                    style: TextStyle(color: tossSubText),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    "이어하기",
                    style: TextStyle(
                      color: tossBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ) ??
          false;

      if (!mounted) return;
      if (resume) {
        setState(() => _applySnapshotJson(data));
      } else {
        await _clearDraftPrefs();
      }
    } catch (_) {
      // 임시 저장 데이터가 깨져있으면 그냥 무시하고 새로 시작한다.
    }
  }

  Future<void> _loadProject(String id) async {
    setState(() => _isLoadingProject = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('layouts')
          .doc(id)
          .get();
      if (!mounted) return;
      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("프로젝트를 찾을 수 없습니다."),
            backgroundColor: warningRed,
          ),
        );
        return;
      }
      final data = doc.data()!;
      data['projectId'] = doc.id;
      setState(() => _applySnapshotJson(data));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("불러오기 실패: $e"), backgroundColor: warningRed),
      );
    } finally {
      if (mounted) setState(() => _isLoadingProject = false);
    }
  }

  Offset _snapToGrid(Offset offset) {
    double dx = (offset.dx / _gridSize).round() * _gridSize;
    double dy = (offset.dy / _gridSize).round() * _gridSize;
    return Offset(dx, dy);
  }

  void _clearBoard() {
    setState(() {
      _placedItems.clear();
      _dimensions.clear();
      _dimensionStartPoint = null;
      _activeItem = null;
      _previewItem = null;
    });
  }

  Future<Uint8List?> _capturePng() async {
    try {
      RenderRepaintBoundary boundary =
          _captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  Future<void> _shareAsPdf(String projectName) async {
    setState(() => _isSaving = true);
    try {
      final imageBytes = await _capturePng();
      if (imageBytes == null) throw Exception("도면 캡처 실패");

      final pdf = pw.Document();
      final image = pw.MemoryImage(imageBytes);
      String qrData =
          "tubingcalc://layout?project=${projectName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}";

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Smart Panel Layout Report",
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          "Project: $projectName",
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                        pw.Text(
                          "Panel Size: ${_panelWidth.toInt()}mm x ${_panelHeight.toInt()}mm",
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                        pw.Text(
                          "Date: ${DateTime.now().toString().split('.')[0]}",
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      width: 80,
                      height: 80,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrData,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Expanded(
                  child: pw.Center(
                    child: pw.Image(image, fit: pw.BoxFit.contain),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  "* Scan the QR code to open this layout in the Tubing Calculator App.",
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/${projectName}_Layout.pdf");
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: '$projectName 레이아웃 도면입니다.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("PDF 생성 오류: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 🚀 [수정] 예전엔 저장할 때마다 새 문서를 만들어서, 같은 프로젝트를
  // 다시 열어 고치고 저장하면 서버에 중복 문서가 계속 쌓이고 "불러오기"로
  // 되돌아갈 방법도 없었다. 이제 이미 저장/불러온 적 있는 프로젝트면
  // (_currentProjectId) 그 문서를 그대로 갱신(update)하고, 처음 저장하는
  // 새 도면일 때만 새 문서를 만든다.
  Future<void> _saveToFirebase(String projectName) async {
    setState(() => _isSaving = true);
    try {
      final bool isNew = _currentProjectId == null;
      final docRef = isNew
          ? FirebaseFirestore.instance.collection('layouts').doc()
          : FirebaseFirestore.instance
                .collection('layouts')
                .doc(_currentProjectId);
      await docRef.set({
        'projectId': docRef.id,
        'projectName': projectName,
        'panelWidth': _panelWidth,
        'panelHeight': _panelHeight,
        if (isNew) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'items': _placedItems.map((e) => e.toJson()).toList(),
        'dimensions': _dimensions.map((e) => e.toJson()).toList(),
      }, SetOptions(merge: true));
      _currentProjectId = docRef.id;
      _projectName = projectName;
      await _clearDraftPrefs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("프로젝트 저장 완료!"), backgroundColor: tossBlue),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("저장 실패"), backgroundColor: warningRed),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _onAcceptItem(ModulePreset preset, Offset localPosition) {
    HapticFeedback.mediumImpact();
    setState(() {
      for (var item in _placedItems) item.isSelected = false;

      double clampedX = localPosition.dx.clamp(
        0.0,
        math.max(0.0, _panelWidth - preset.width),
      );
      double clampedY = localPosition.dy.clamp(
        0.0,
        math.max(0.0, _panelHeight - preset.height),
      );

      final newItem = PlacedItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: preset.name,
        position: _snapToGrid(Offset(clampedX, clampedY)),
        width: preset.width,
        height: preset.height,
        isSelected: true,
      );

      _placedItems.add(newItem);
      _activeItem = newItem;
      _previewItem = null;
    });
    _showInspectorBottomSheet(_placedItems.last);
  }

  // 🚀 [버그 수정] 벽까지 실제 거리와 무관하게 빈 도면 공간을 탭하면
  // 무조건 "가장 가까운 벽" 지점으로 확정되어 버렸다. 모듈을 살짝
  // 빗맞히거나 그냥 도면 가운데를 눌러도 항상 치수 시작점이 잡히는
  // 게 "시작점이 무조건 벽이 된다" + "그냥 터치만 해도 치수가 생긴다"
  // 두 증상의 원인이었다. 이제 실제로 벽에서 가까울 때(_wallTapTolerance
  // 이내)만 벽 기준점으로 인정하고, 그 밖의 빈 허공 탭은 무시(null)한다.
  static const double _wallTapTolerance = 50.0;

  WallPoint? _getNearestWallPoint(Offset touchPosition) {
    double distLeft = touchPosition.dx;
    double distRight = _panelWidth - touchPosition.dx;
    double distTop = touchPosition.dy;
    double distBottom = _panelHeight - touchPosition.dy;

    double minDist = [
      distLeft,
      distRight,
      distTop,
      distBottom,
    ].reduce(math.min);
    if (minDist > _wallTapTolerance) return null;

    Offset wallPos;
    if (minDist == distLeft)
      wallPos = Offset(0, touchPosition.dy);
    else if (minDist == distRight)
      wallPos = Offset(_panelWidth, touchPosition.dy);
    else if (minDist == distTop)
      wallPos = Offset(touchPosition.dx, 0);
    else
      wallPos = Offset(touchPosition.dx, _panelHeight);

    return WallPoint(position: _snapToGrid(wallPos));
  }

  void _handleDimensionPoint(MeasurePoint point) {
    setState(() {
      if (_dimensionStartPoint == null) {
        _dimensionStartPoint = point;
      } else {
        if (_dimensionStartPoint!.id != point.id) {
          // 🚀 [버그 수정] type을 비교 조건에서 빼먹어서, 같은 두 지점을
          // "센터 기준"으로 한 번 측정하고 나면 "측면 기준"으로는 다시
          // 측정이 안 되고 아무 반응 없이 무시되던 문제. 이게 마치 "첫
          // 치수가 고정되어 안 바뀐다"처럼 보였던 원인이었다. 이제는
          // 같은 두 지점이라도 기준(type)이 다르면 별도 치수로 추가된다.
          bool exists = _dimensions.any(
            (dim) =>
                dim.type == _currentDimType &&
                ((dim.p1.id == _dimensionStartPoint!.id &&
                        dim.p2.id == point.id) ||
                    (dim.p1.id == point.id &&
                        dim.p2.id == _dimensionStartPoint!.id)),
          );

          if (!exists) {
            _dimensions.add(
              PlacedDimension(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                p1: _dimensionStartPoint!,
                p2: point,
                type: _currentDimType,
              ),
            );
            HapticFeedback.heavyImpact();
          }
        }
        _dimensionStartPoint = null;
      }
    });
  }

  void _onTapItem(PlacedItem item) {
    HapticFeedback.lightImpact();
    if (_mode == BoardMode.measureDimension) {
      _handleDimensionPoint(item);
    } else {
      setState(() {
        for (var i in _placedItems) i.isSelected = false;
        item.isSelected = true;
        _activeItem = item;
      });
      _showInspectorBottomSheet(item);
    }
  }

  void _onTapBoard(Offset localPosition) {
    if (_mode == BoardMode.measureDimension) {
      final WallPoint? nearestWall = _getNearestWallPoint(localPosition);
      if (nearestWall == null) return; // 벽에서 너무 먼 빈 허공 탭은 무시
      HapticFeedback.lightImpact();
      _handleDimensionPoint(nearestWall);
    } else {
      setState(() {
        for (var i in _placedItems) i.isSelected = false;
        _activeItem = null;
      });
    }
  }

  Widget _buildBottomSheetHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 5,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSaveActionSheet() {
    // 🚀 [수정] 기존에 불러온 프로젝트를 다시 저장할 땐 그 프로젝트 이름을
    // 그대로 채워줘서, 실수로 다른 이름을 입력해 새 문서로 갈라지는 걸 방지.
    final TextEditingController projectCtrl = TextEditingController(
      text: _projectName.isNotEmpty
          ? _projectName
          : "현장 레이아웃_${DateTime.now().day}일",
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 16,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBottomSheetHandle(),
              const Text(
                "저장 및 공유하기",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: tossText,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: projectCtrl,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tossText,
                ),
                decoration: InputDecoration(
                  labelText: "프로젝트/현장 명칭",
                  filled: true,
                  fillColor: tossBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _saveToFirebase(projectCtrl.text);
                  },
                  icon: const Icon(
                    Icons.cloud_upload_rounded,
                    color: pureWhite,
                  ),
                  label: const Text(
                    "프로젝트 서버에 저장",
                    style: TextStyle(
                      color: pureWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tossBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _shareAsPdf(projectCtrl.text);
                  },
                  icon: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: tossText,
                  ),
                  label: const Text(
                    "QR 도면 PDF로 공유",
                    style: TextStyle(
                      color: tossText,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: tossText, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showInspectorBottomSheet(PlacedItem item) {
    final TextEditingController nameCtrl = TextEditingController(
      text: item.name,
    );
    final TextEditingController widthCtrl = TextEditingController(
      text: item.width.toInt().toString(),
    );
    final TextEditingController heightCtrl = TextEditingController(
      text: item.height.toInt().toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 16,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                color: pureWhite,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBottomSheetHandle(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "모듈 속성 편집",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: tossText,
                          letterSpacing: -0.5,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: tossSubText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 🚀 [여기가 핵심 추가본입니다] 회전 & 복사 버튼
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // 🔄 90도 회전 (가로 세로 길이 교환)
                            setState(() {
                              double temp = item.width;
                              item.width = item.height;
                              item.height = temp;

                              // 회전 후 도면 밖으로 나가지 않게 위치 보정
                              item.position = Offset(
                                item.position.dx.clamp(
                                  0.0,
                                  math.max(0.0, _panelWidth - item.width),
                                ),
                                item.position.dy.clamp(
                                  0.0,
                                  math.max(0.0, _panelHeight - item.height),
                                ),
                              );
                            });
                            // 바텀시트의 텍스트 필드 값도 함께 업데이트
                            setModalState(() {
                              widthCtrl.text = item.width.toInt().toString();
                              heightCtrl.text = item.height.toInt().toString();
                            });
                            HapticFeedback.lightImpact();
                          },
                          icon: const Icon(
                            Icons.rotate_90_degrees_cw_rounded,
                            size: 18,
                            color: tossBlue,
                          ),
                          label: const Text(
                            "90° 회전",
                            style: TextStyle(
                              color: tossBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tossBlue.withValues(alpha: 0.1),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // 📋 모듈 복사
                            setState(() {
                              final newItem = PlacedItem(
                                id: DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                                name: item.name,
                                position: _snapToGrid(
                                  Offset(
                                    (item.position.dx + 20).clamp(
                                      0.0,
                                      math.max(0.0, _panelWidth - item.width),
                                    ),
                                    (item.position.dy + 20).clamp(
                                      0.0,
                                      math.max(0.0, _panelHeight - item.height),
                                    ),
                                  ),
                                ),
                                width: item.width,
                                height: item.height,
                                isSelected: false,
                              );
                              _placedItems.add(newItem);
                            });
                            HapticFeedback.mediumImpact();
                            Navigator.pop(context); // 복제 후 창 닫기

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("'${item.name}' 모듈이 복사되었습니다."),
                                backgroundColor: tossText,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.content_copy_rounded,
                            size: 18,
                            color: tossText,
                          ),
                          label: const Text(
                            "모듈 복제",
                            style: TextStyle(
                              color: tossText,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tossBg,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: tossText,
                    ),
                    decoration: InputDecoration(
                      labelText: "모듈 명칭 (라벨)",
                      filled: true,
                      fillColor: tossBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        item.name = val.isEmpty ? "이름 없음" : val;
                      });
                    },
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    "모듈 크기 (가로 x 세로)",
                    style: TextStyle(
                      color: tossText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCoordinateInput(
                          "가로 너비 (mm)",
                          widthCtrl.text,
                          (val) {
                            setState(() {
                              item.width = (double.tryParse(val) ?? 80.0);
                              item.position = Offset(
                                item.position.dx.clamp(
                                  0.0,
                                  math.max(0.0, _panelWidth - item.width),
                                ),
                                item.position.dy,
                              );
                            });
                          },
                          controller: widthCtrl,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCoordinateInput(
                          "세로 높이 (mm)",
                          heightCtrl.text,
                          (val) {
                            setState(() {
                              item.height = (double.tryParse(val) ?? 80.0);
                              item.position = Offset(
                                item.position.dx,
                                item.position.dy.clamp(
                                  0.0,
                                  math.max(0.0, _panelHeight - item.height),
                                ),
                              );
                            });
                          },
                          controller: heightCtrl,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    "도면 내 절대 위치",
                    style: TextStyle(
                      color: tossText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCoordinateInput(
                          "X 좌표 (mm)",
                          item.position.dx.toInt().toString(),
                          (val) {
                            setState(() {
                              double newX = double.tryParse(val) ?? 0;
                              item.position = Offset(
                                newX.clamp(
                                  0.0,
                                  math.max(0.0, _panelWidth - item.width),
                                ),
                                item.position.dy,
                              );
                            });
                            setModalState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCoordinateInput(
                          "Y 좌표 (mm)",
                          item.position.dy.toInt().toString(),
                          (val) {
                            setState(() {
                              double newY = double.tryParse(val) ?? 0;
                              item.position = Offset(
                                item.position.dx,
                                newY.clamp(
                                  0.0,
                                  math.max(0.0, _panelHeight - item.height),
                                ),
                              );
                            });
                            setModalState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _dimensions.removeWhere(
                            (dim) =>
                                dim.p1.id == item.id || dim.p2.id == item.id,
                          );
                          _placedItems.remove(item);
                          if (_dimensionStartPoint?.id == item.id)
                            _dimensionStartPoint = null;
                          _activeItem = null;
                        });
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete_outline, color: warningRed),
                      label: const Text(
                        "이 모듈 삭제",
                        style: TextStyle(
                          color: warningRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: warningRed, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      setState(() {
        item.isSelected = false;
        _activeItem = null;
      });
    });
  }

  void _showPanelSettingsSheet() {
    final widthCtrl = TextEditingController(
      text: _panelWidth.toInt().toString(),
    );
    final heightCtrl = TextEditingController(
      text: _panelHeight.toInt().toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 16,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBottomSheetHandle(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "레이아웃 크기 설정",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: tossText,
                      letterSpacing: -0.5,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: tossSubText),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                "실제 중판(캐비닛)의 사이즈를 mm 단위로 입력하세요.",
                style: TextStyle(color: tossSubText, fontSize: 14),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _buildCoordinateInput(
                      "가로 (W) mm",
                      widthCtrl.text,
                      (val) {},
                      controller: widthCtrl,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCoordinateInput(
                      "세로 (H) mm",
                      heightCtrl.text,
                      (val) {},
                      controller: heightCtrl,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _panelWidth = double.tryParse(widthCtrl.text) ?? 600.0;
                      _panelHeight = double.tryParse(heightCtrl.text) ?? 800.0;

                      for (var item in _placedItems) {
                        item.position = Offset(
                          item.position.dx.clamp(
                            0.0,
                            math.max(0.0, _panelWidth - item.width),
                          ),
                          item.position.dy.clamp(
                            0.0,
                            math.max(0.0, _panelHeight - item.height),
                          ),
                        );
                      }
                      _dimensions.removeWhere(
                        (dim) => dim.p1 is WallPoint || dim.p2 is WallPoint,
                      );
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tossBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "도면 크기 적용",
                    style: TextStyle(
                      color: pureWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossBg,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "스마트 레이아웃 설계",
              style: TextStyle(
                color: tossText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            if (_projectName.isNotEmpty)
              Text(
                _projectName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: tossSubText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: tossText,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tossBlue,
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip: "저장 및 공유",
              onPressed: _showSaveActionSheet,
              icon: const Icon(Icons.ios_share_rounded, color: tossBlue),
            ),
          IconButton(
            tooltip: "외함 사이즈 설정",
            onPressed: _showPanelSettingsSheet,
            icon: const Icon(Icons.aspect_ratio_rounded, color: tossText),
          ),
          IconButton(
            tooltip: "도면 초기화",
            onPressed: _clearBoard,
            icon: const Icon(Icons.refresh_rounded, color: warningRed),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: InteractiveViewer(
              minScale: 0.1,
              maxScale: 4.0,
              boundaryMargin: const EdgeInsets.all(2000),
              constrained: false,
              child: DragTarget<ModulePreset>(
                onMove: (details) {
                  final RenderBox box =
                      _boardKey.currentContext!.findRenderObject() as RenderBox;
                  Offset localPos = box.globalToLocal(details.offset);
                  double clampedX = localPos.dx.clamp(
                    0.0,
                    math.max(0.0, _panelWidth - details.data.width),
                  );
                  double clampedY = localPos.dy.clamp(
                    0.0,
                    math.max(0.0, _panelHeight - details.data.height),
                  );
                  setState(() {
                    _previewItem = PlacedItem(
                      id: 'preview',
                      name: details.data.name,
                      position: _snapToGrid(Offset(clampedX, clampedY)),
                      width: details.data.width,
                      height: details.data.height,
                    );
                  });
                },
                onLeave: (data) => setState(() => _previewItem = null),
                onAcceptWithDetails: (details) {
                  final RenderBox box =
                      _boardKey.currentContext!.findRenderObject() as RenderBox;
                  _onAcceptItem(
                    details.data,
                    box.globalToLocal(details.offset),
                  );
                },
                builder: (context, candidateData, rejectedData) {
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        onTapUp: (details) =>
                            _onTapBoard(details.localPosition),
                        child: RepaintBoundary(
                          key: _captureKey,
                          child: Container(
                            key: _boardKey,
                            width: _panelWidth,
                            height: _panelHeight,
                            decoration: BoxDecoration(
                              color: pureWhite,
                              border: Border.all(color: tossText, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 30,
                                  offset: const Offset(10, 10),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CustomPaint(
                                  size: Size.infinite,
                                  painter: GridPainter(gridSize: _gridSize),
                                ),
                                CustomPaint(
                                  size: Size.infinite,
                                  painter: DimensionPainter(
                                    dimensions: _dimensions,
                                    activePoint: _dimensionStartPoint,
                                    panelWidth: _panelWidth,
                                    panelHeight: _panelHeight,
                                  ),
                                ),
                                if (_previewItem != null &&
                                    _mode == BoardMode.placeModule) ...[
                                  ..._buildGuidePaints(_previewItem!),
                                  Positioned(
                                    left: _previewItem!.position.dx,
                                    top: _previewItem!.position.dy,
                                    child: Opacity(
                                      opacity: 0.5,
                                      child: _buildBoardItem(_previewItem!),
                                    ),
                                  ),
                                ],

                                if (_activeItem != null &&
                                    _mode == BoardMode.placeModule)
                                  ..._buildGuidePaints(_activeItem!),

                                ..._placedItems.map((item) {
                                  return Positioned(
                                    left: item.position.dx,
                                    top: item.position.dy,
                                    child: GestureDetector(
                                      onPanStart: _mode == BoardMode.placeModule
                                          ? (details) {
                                              setState(() {
                                                _dragRawPosition =
                                                    item.position;
                                                _activeItem = item;
                                                for (var i in _placedItems) {
                                                  i.isSelected = false;
                                                }
                                                item.isSelected = true;
                                              });
                                            }
                                          : null,
                                      onPanUpdate: _mode == BoardMode.placeModule
                                          ? (details) {
                                              setState(() {
                                                _dragRawPosition +=
                                                    details.delta;
                                                double clampedX =
                                                    _dragRawPosition.dx.clamp(
                                                      0.0,
                                                      math.max(
                                                        0.0,
                                                        _panelWidth -
                                                            item.width,
                                                      ),
                                                    );
                                                double clampedY =
                                                    _dragRawPosition.dy.clamp(
                                                      0.0,
                                                      math.max(
                                                        0.0,
                                                        _panelHeight -
                                                            item.height,
                                                      ),
                                                    );
                                                item.position = _snapToGrid(
                                                  Offset(clampedX, clampedY),
                                                );
                                              });
                                            }
                                          : null,
                                      onPanEnd: _mode == BoardMode.placeModule
                                          ? (details) {
                                              setState(() {
                                                _activeItem = null;
                                              });
                                            }
                                          : null,
                                      onTap: () => _onTapItem(item),
                                      child: _buildBoardItem(item),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -30,
                        child: Text(
                          "W: ${_panelWidth.toInt()} mm",
                          style: TextStyle(
                            color: Colors.blueGrey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Positioned(
                        left: -80,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            "H: ${_panelHeight.toInt()} mm",
                            style: TextStyle(
                              color: Colors.blueGrey.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // 하단 컨트롤 패널
          Container(
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🚀 [재구성] 기본 SegmentedButton은 선택된 항목 배경이
                  // 검정(tossText)이라 마키타 톤과 안 어울렸다. 설정 화면의
                  // AUTO/MAN 토글과 같은 방식(알약형 배경 안에 세그먼트,
                  // 선택된 쪽만 마키타 틸로 채움)으로 직접 만들어서 앱
                  // 전체 톤을 통일했다.
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildModeSegmentedControl(),
                  ),
                  // 🚀 [정리] 모듈 배치/이동 중에는 가상선이 항상 나오는 게
                  // 자연스럽다는 판단으로 켜고/끄는 토글 UI 자체를 없앴다.
                  // (안 그러면 매번 껐다 켰다 하며 신경 써야 함) 이제 카드
                  // 안에는 모드별 옵션 패널만 남아서 하단부가 한결 정리됨.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: tossBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: switch (_mode) {
                          BoardMode.measureDimension =>
                            _buildDimensionToolBar(),
                          BoardMode.placeModule => _buildModulePalette(),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
          // 🚀 [추가] 저장된 프로젝트를 불러오는 동안 화면을 덮어서 빈
          // 도면이 잠깐 보였다가 내용이 채워지는 깜빡임을 막는다.
          if (_isLoadingProject)
            Container(
              color: Colors.black.withValues(alpha: 0.15),
              child: const Center(
                child: CircularProgressIndicator(color: tossBlue),
              ),
            ),
        ],
      ),
    );
  }

  // 🚀 [정리] 켜고/끄는 토글 없이, 모듈 배치/이동 중에는 항상 현재
  // 선택된 가상선 색상(_currentDimType)의 가이드선 하나만 그려준다.
  List<Widget> _buildGuidePaints(PlacedItem item) {
    return [
      CustomPaint(
        size: Size.infinite,
        painter: SmartGuidePainter(
          item: item,
          allItems: _placedItems,
          panelWidth: _panelWidth,
          panelHeight: _panelHeight,
          currentType: _currentDimType,
        ),
      ),
    ];
  }

  // 🚀 [추가] 설정 화면의 AUTO/MAN 알약형 토글과 같은 스타일 - 회색
  // 알약 배경 안에서 선택된 세그먼트만 마키타 틸로 채운다. 검정 배경
  // 대신 앱 전체와 통일된 톤을 쓴다.
  Widget _buildModeSegmentedControl() {
    final segments = <(BoardMode, String)>[
      (BoardMode.placeModule, "모듈 배치/이동"),
      (BoardMode.measureDimension, "고정 치수 측정"),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tossBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: segments.map((seg) {
          final isSelected = _mode == seg.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (isSelected) return;
                setState(() {
                  _mode = seg.$1;
                  _dimensionStartPoint = null;
                  _activeItem = null;
                  for (var i in _placedItems) {
                    i.isSelected = false;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? tossBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  seg.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? pureWhite : tossSubText,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 🚀 [재구성] 예전엔 "가상선: 센터/측면" 칩 2개 + 드래그 박스 + 2줄
  // 설명 텍스트가 세로로 쌓여서 공간을 많이 차지했다. 이제 원형 버튼
  // 하나로 색상을 전환하는 방식(탭할 때마다 센터↔측면 전환)으로 줄이고,
  // 드래그 박스와 한 줄에 묶어서 패널 높이를 크게 줄였다. 이 가상선은
  // 모듈 배치/이동 중 항상 표시되며 별도 켜고/끄는 토글은 없다.
  Widget _buildModulePalette() {
    return Padding(
      key: const ValueKey("palette"),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Draggable<ModulePreset>(
                data: const ModulePreset("신규 모듈", 80, 80),
                feedback: Material(
                  color: Colors.transparent,
                  child: Opacity(
                    opacity: 0.8,
                    child: _buildPaletteItem("드래그 중.."),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _buildPaletteItem("배치 중"),
                ),
                child: _buildPaletteItem("신규 모듈"),
              ),
              const SizedBox(width: 14),
              Expanded(child: _buildGuideColorSwitch()),
            ],
          ),
          const SizedBox(height: 16),
          // 🚀 [추가] ABS 배선덕트 - 폭이 정해진 자재라 매번 배치 후 크기를
          // 손으로 고칠 필요 없이 원하는 폭을 바로 드래그해서 놓을 수 있게.
          // (참고용 명목 폭 - 실제 발주 규격 확인 필요, kDuctPresets 주석 참고)
          const Text(
            "ABS 덕트 (폭 mm, 드래그)",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tossSubText,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kDuctPresets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final preset = kDuctPresets[index];
                return Draggable<ModulePreset>(
                  data: preset,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Opacity(
                      opacity: 0.8,
                      child: _buildDuctChip(preset),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: _buildDuctChip(preset),
                  ),
                  child: _buildDuctChip(preset),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuctChip(ModulePreset preset) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tossBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tossSubText.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.view_agenda_outlined, size: 16, color: tossText),
          const SizedBox(width: 6),
          Text(
            preset.width.toInt().toString(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: tossText,
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [추가] "원 버튼식 전환" - 칩 2개 대신 원형 버튼 하나를 탭할 때마다
  // 센터(파란)/측면(주황) 가상선 색상이 서로 전환된다.
  Widget _buildGuideColorSwitch() {
    final bool isCenter = _currentDimType == DimensionType.center;
    final Color color = isCenter ? guideCenterColor : edgeDimColor;
    final String label = isCenter ? "센터(파란색)" : "측면(주황색)";

    return GestureDetector(
      onTap: () => setState(() {
        _currentDimType = isCenter
            ? DimensionType.edge
            : DimensionType.center;
      }),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const Icon(
              Icons.sync_alt_rounded,
              color: pureWhite,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "드래그 시 적용될 가상선",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tossSubText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaletteItem(String defaultName) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tossBlue.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: tossBlue.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_box_rounded, color: tossBlue, size: 22),
            const SizedBox(height: 4),
            Text(
              defaultName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: tossBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 [정리] 배치가 끝난 뒤 치수를 "확인"하는 용도라는 점에 맞춰,
  // 칩 2개 + 안내문 2줄로 나뉘어 있던 걸 한 줄로 압축했다. 기준(센터/
  // 측면) 전환은 모듈 팔레트와 같은 원 버튼식으로 통일하고, 상태
  // 안내는 한 줄만 남기고, "전체 삭제"는 텍스트 버튼 대신 아이콘
  // 버튼으로 줄여서 자리를 덜 차지하게 했다.
  Widget _buildDimensionToolBar() {
    final bool isCenter = _currentDimType == DimensionType.center;
    final Color activeColor = isCenter ? centerDimColor : edgeDimColor;

    return Padding(
      key: const ValueKey("dimension"),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => setState(() {
              _currentDimType = isCenter
                  ? DimensionType.edge
                  : DimensionType.center;
            }),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: activeColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sync_alt_rounded,
                    color: pureWhite,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "측정 기준",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tossSubText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCenter ? "센터(중심)" : "측면(여백)",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: activeColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _dimensionStartPoint == null
                  ? "측정할 두 지점을 순서대로 터치하세요"
                  : "다음 지점을 터치하면 연결됩니다",
              style: const TextStyle(
                color: tossSubText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 🚀 [추가] 첫 지점을 잘못 찍었을 때 두 번째 지점을 억지로 찍어
          // 엉뚱한 치수를 만들지 않고도 취소할 수 있는 버튼.
          if (_dimensionStartPoint != null)
            IconButton(
              tooltip: "첫 지점 취소",
              onPressed: () {
                setState(() {
                  _dimensionStartPoint = null;
                });
              },
              icon: const Icon(
                Icons.undo_rounded,
                color: tossSubText,
                size: 20,
              ),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
            ),
          if (_dimensions.isNotEmpty)
            IconButton(
              tooltip: "치수 전체 삭제",
              onPressed: () {
                setState(() {
                  _dimensions.clear();
                });
              },
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: warningRed,
                size: 20,
              ),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
            ),
        ],
      ),
    );
  }

  Widget _buildBoardItem(PlacedItem item) {
    bool isMeasuringStart =
        _mode == BoardMode.measureDimension &&
        _dimensionStartPoint?.id == item.id;
    Color activeColor = _currentDimType == DimensionType.center
        ? centerDimColor
        : edgeDimColor;

    return Container(
      width: item.width,
      height: item.height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isMeasuringStart
            ? activeColor.withValues(alpha: 0.1)
            : pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMeasuringStart
              ? activeColor
              : (item.isSelected ? tossBlue : Colors.blueGrey.shade300),
          width: isMeasuringStart || item.isSelected ? 3 : 1.5,
        ),
        boxShadow: item.isSelected
            ? [
                BoxShadow(
                  color: tossBlue.withValues(alpha: 0.25),
                  blurRadius: 15,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
      ),
      child: Center(
        child: Text(
          item.name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isMeasuringStart
                ? activeColor
                : (item.isSelected ? tossBlue : tossText),
            height: 1.2,
            letterSpacing: -0.3,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildCoordinateInput(
    String label,
    String value,
    Function(String) onChanged, {
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: tossSubText,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller:
              controller ??
              (TextEditingController(text: value)
                ..selection = TextSelection.collapsed(offset: value.length)),
          keyboardType: TextInputType.number,
          onSubmitted: onChanged,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: tossText,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: tossBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// Helper Painters
// ---------------------------------------------------------

// 🚀 [수정] 산업 도면(CAD)처럼 얇은 치수선 + 끝단 눈금 + 항상 보이는
// 라벨로 통일. 예전엔 두꺼운 색상 알약(pill) 라벨이 10mm 미만
// 거리에서는 아예 안 보였는데, 라벨을 선 옆으로 살짝 띄워서 거리와
// 무관하게 항상 표시되게 한다.
void drawCadDimensionLine(
  Canvas canvas,
  Offset start,
  Offset end,
  double distance,
  Color color,
  String prefix,
) {
  if (distance < 1) return; // 사실상 붙어있으면 표시할 게 없음

  final linePaint = Paint()
    ..color = color
    ..strokeWidth = 1.3
    ..style = PaintingStyle.stroke;
  canvas.drawLine(start, end, linePaint);

  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final len = math.sqrt(dx * dx + dy * dy);
  final double px = len == 0 ? 0 : -dy / len;
  final double py = len == 0 ? 0 : dx / len;

  // 끝단 눈금(CAD 치수선의 tick mark)
  final tick = Offset(px, py) * 5;
  canvas.drawLine(start - tick, start + tick, linePaint);
  canvas.drawLine(end - tick, end + tick, linePaint);

  final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
  final label = mid + Offset(px, py) * 15;

  final textSpan = TextSpan(
    text: "$prefix ${distance.toInt()} mm",
    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
  );
  final textPainter = TextPainter(
    text: textSpan,
    textDirection: TextDirection.ltr,
  )..layout();

  final bgRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: label,
      width: textPainter.width + 10,
      height: textPainter.height + 6,
    ),
    const Radius.circular(4),
  );
  // 라벨-치수선 연결용 짧은 리더선
  canvas.drawLine(mid, label, Paint()..color = color.withValues(alpha: 0.5)..strokeWidth = 1);
  canvas.drawRRect(bgRect, Paint()..color = pureWhite);
  canvas.drawRRect(
    bgRect,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  textPainter.paint(
    canvas,
    Offset(label.dx - textPainter.width / 2, label.dy - textPainter.height / 2),
  );
}

// 🚀 [핵심 해결] 측면 모드에서도 레이캐스트(Raycast) 물리 법칙 완벽 적용
class SmartGuidePainter extends CustomPainter {
  final PlacedItem item;
  final List<PlacedItem> allItems;
  final double panelWidth;
  final double panelHeight;
  final DimensionType currentType;

  SmartGuidePainter({
    required this.item,
    required this.allItems,
    required this.panelWidth,
    required this.panelHeight,
    required this.currentType,
  });

  void _drawGuideLine(
    Canvas canvas,
    Offset start,
    Offset end,
    double distance,
    Color color,
    String prefix,
  ) {
    drawCadDimensionLine(canvas, start, end, distance, color, prefix);
  }

  @override
  void paint(Canvas canvas, Size size) {
    Color c = currentType == DimensionType.center
        ? guideCenterColor
        : edgeDimColor;
    String p = currentType == DimensionType.center ? "센터" : "측면";

    double cx = item.center.dx, cy = item.center.dy;
    double left = item.position.dx, right = item.position.dx + item.width;
    double top = item.position.dy, bottom = item.position.dy + item.height;

    double bL = 0, bR = panelWidth, bT = 0, bB = panelHeight;

    for (var other in allItems) {
      if (other.id == item.id) continue;

      double oLeft = other.position.dx,
          oRight = other.position.dx + other.width;
      double oTop = other.position.dy,
          oBottom = other.position.dy + other.height;

      bool hitVerticalRay = (cx >= oLeft) && (cx <= oRight);
      if (hitVerticalRay) {
        if (currentType == DimensionType.center) {
          if (other.center.dy <= cy && other.center.dy > bT)
            bT = other.center.dy;
          if (other.center.dy >= cy && other.center.dy < bB)
            bB = other.center.dy;
        } else {
          if (oBottom <= top && oBottom > bT) bT = oBottom;
          if (oTop >= bottom && oTop < bB) bB = oTop;
        }
      }

      bool hitHorizontalRay = (cy >= oTop) && (cy <= oBottom);
      if (hitHorizontalRay) {
        if (currentType == DimensionType.center) {
          if (other.center.dx <= cx && other.center.dx > bL)
            bL = other.center.dx;
          if (other.center.dx >= cx && other.center.dx < bR)
            bR = other.center.dx;
        } else {
          if (oRight <= left && oRight > bL) bL = oRight;
          if (oLeft >= right && oLeft < bR) bR = oLeft;
        }
      }
    }

    if (currentType == DimensionType.center) {
      _drawGuideLine(
        canvas,
        Offset(cx, cy),
        Offset(cx, bT),
        (cy - bT).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(cx, cy),
        Offset(cx, bB),
        (bB - cy).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(cx, cy),
        Offset(bL, cy),
        (cx - bL).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(cx, cy),
        Offset(bR, cy),
        (bR - cx).abs(),
        c,
        p,
      );
    } else {
      _drawGuideLine(
        canvas,
        Offset(cx, top),
        Offset(cx, bT),
        (top - bT).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(cx, bottom),
        Offset(cx, bB),
        (bB - bottom).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(left, cy),
        Offset(bL, cy),
        (left - bL).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(right, cy),
        Offset(bR, cy),
        (bR - right).abs(),
        c,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GridPainter extends CustomPainter {
  final double gridSize;
  GridPainter({required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    final lightPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.5;
    final boldPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.2;

    for (double i = 0; i <= size.width; i += gridSize) {
      bool isMajor = (i % (gridSize * 5) == 0);
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        isMajor ? boldPaint : lightPaint,
      );
    }
    for (double i = 0; i <= size.height; i += gridSize) {
      bool isMajor = (i % (gridSize * 5) == 0);
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        isMajor ? boldPaint : lightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DimensionPainter extends CustomPainter {
  final List<PlacedDimension> dimensions;
  final MeasurePoint? activePoint;
  final double panelWidth;
  final double panelHeight;

  DimensionPainter({
    required this.dimensions,
    this.activePoint,
    required this.panelWidth,
    required this.panelHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var dim in dimensions) {
      Color dColor = dim.type == DimensionType.center
          ? centerDimColor
          : edgeDimColor;
      String labelPrefix = dim.type == DimensionType.center ? "센터" : "측면";

      final endpoints = computeDimensionEndpoints(dim);

      drawCadDimensionLine(
        canvas,
        endpoints.p1,
        endpoints.p2,
        endpoints.distance,
        dColor,
        labelPrefix,
      );
    }

    // 🚀 [개선] 예전엔 벽 기준점(WallPoint)일 때만 대기 중 표시를 그려서,
    // 모듈을 첫 지점으로 찍었을 땐 "측정 대기 중"이라는 표시가 전혀
    // 없었다. 그래서 다음 터치가 바로 두 번째 지점으로 이어져 치수가
    // 생기는 게 예상치 못하게 느껴졌다. 이제 첫 지점 종류와 상관없이
    // 항상 표시해서 측정이 진행 중임을 분명히 보여준다.
    if (activePoint != null) {
      canvas.drawCircle(activePoint!.center, 6, Paint()..color = tossText);
      canvas.drawCircle(
        activePoint!.center,
        16,
        Paint()
          ..color = tossText.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill,
      );
    }
  }

  // 🚀 [최적화] 예전엔 무조건 true라 모듈을 드래그해서 setState가 호출될
  // 때마다(프레임마다) 치수선과 무관한데도 이 레이어 전체가 매번 다시
  // 그려졌음(버벅임의 실제 원인). dimensions는 같은 List를 in-place로
  // add/remove하므로 참조 비교 대신 길이로, 나머지는 값이 바뀔 때 항상
  // 재할당되므로 값 비교로 실제 변경 여부를 판단한다.
  @override
  bool shouldRepaint(covariant DimensionPainter oldDelegate) {
    return oldDelegate.dimensions.length != dimensions.length ||
        oldDelegate.activePoint != activePoint ||
        oldDelegate.panelWidth != panelWidth ||
        oldDelegate.panelHeight != panelHeight;
  }
}

