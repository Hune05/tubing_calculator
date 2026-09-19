import 'dart:async';
import '../widgets/korean_text.dart';
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
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/image_picker_helper.dart';

// ---------------------------------------------------------
// 🎨 토스(Toss) 디자인 시스템 색상
// ---------------------------------------------------------
const Color tossBlue = Color(0xFF007580); // 🚀 마키타 틸로 통일
const Color tossText = Color(0xFF191F28);
const Color tossSubText = Color(0xFF8B95A1);
const Color tossBg = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);
// 🚀 [수정] 수동 측정(센터)이 녹색, 자동 가이드(센터)가 파란색으로
// 서로 달라 헷갈렸음. "센터"는 수동/자동 어디서나 항상 파란색으로 통일.
const Color centerDimColor = tossBlue; // 센터 기준: 파란색(자동 가이드와 통일)
const Color edgeDimColor = Color(0xFFF68657); // 측면 기준: 주황색
// 🚀 [신규] 대각선 치수 색상(모바일과 동일).
const Color diagonalDimColor = Color(0xFF8B5CF6);
// 🚀 [복원] 정렬 안내선 색(모바일과 동일) - key 부여로 근본 원인을
// 고쳤으니 다시 켠다(자세한 설명은 모바일 파일 주석 참고).
const Color alignGuideColor = Color(0xFFFF3D9A);
const Color guideColor = tossBlue;
// 🚀 [버그 수정] 모듈끼리 붙여놓으면 보이지 않는 여유 터치 영역끼리
// 겹쳐서 엉뚱한 모듈이 반응하는 문제가 있어 없앴다(모바일과 동일).
const double _kTouchHitPad = 0.0;

// ---------------------------------------------------------
// 1. 데이터 모델
// ---------------------------------------------------------

// 🚀 [정리] 정밀 튜빙 라인 모드는 폰/태블릿에서 점을 하나하나 정밀하게
// 찍어야 해서 부담이 크다는 판단으로 제거.
enum BoardMode { placeModule, measureDimension }

// 🚀 [추가] 드래그로 놓을 모듈의 이름+가로/세로를 함께 실어 나르는 페이로드
// (모바일과 동일한 방식 - 자세한 설명은 그쪽 주석 참고)
class ModulePreset {
  final String name;
  final double width;
  final double height;
  const ModulePreset(this.name, this.width, this.height);
}

// 🚀 [수정] 실제 현장에서 쓰는 폭(40/60/80/100mm)만 남김.
const List<ModulePreset> kDuctPresets = [
  ModulePreset("ABS덕트 40mm", 40, 200),
  ModulePreset("ABS덕트 60mm", 60, 200),
  ModulePreset("ABS덕트 80mm", 80, 200),
  ModulePreset("ABS덕트 100mm", 100, 200),
];

// 🚀 [추가] 치수 측정 기준 (모바일과 동일하게 센터/측면 두 가지 지원)
enum DimensionType { center, edge }

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
  // 🚀 [신규] 위치가 확정된 모듈을 잠가서 드래그해도 실수로 옮겨지지
  // 않게 하는 기능(모바일과 동일).
  bool isLocked;

  PlacedItem({
    required this.id,
    required this.name,
    required this.position,
    this.width = 80.0,
    this.height = 80.0,
    this.isSelected = false,
    this.isLocked = false,
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
    'locked': isLocked,
  };

  factory PlacedItem.fromJson(Map<String, dynamic> j) => PlacedItem(
    id: j['id'] as String,
    name: j['name'] as String? ?? "이름 없음",
    position: Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
    width: (j['w'] as num?)?.toDouble() ?? 80.0,
    height: (j['h'] as num?)?.toDouble() ?? 80.0,
    isLocked: j['locked'] as bool? ?? false,
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
// 복원한다 (모바일 화면과 동일한 방식).
MeasurePoint _measurePointFromJson(Map<String, dynamic> j) {
  return j['type'] == 'wall' ? WallPoint.fromJson(j) : PlacedItem.fromJson(j);
}

class PlacedDimension {
  final String id;
  final MeasurePoint p1;
  final MeasurePoint p2;
  // 🚀 [수정] 기존 치수의 기준(센터/측면)을 그 자리에서 바꿀 수 있도록
  // final을 뗐다(모바일과 동일).
  DimensionType type;
  // 🚀 [신규] 이 치수선에 대한 짧은 메모.
  String? note;
  // 🚀 [신규] 최소 유지 간격(mm) - 실제 거리가 이보다 좁아지면 경고색.
  double? minGapMm;
  // 🚀 [신규] 대각선 모드 - 켜면 축 정렬 없이 두 중심점을 직선으로
  // 그대로 잇는 실제 직선거리+각도를 측정한다(모바일과 동일).
  bool isDiagonal;
  // 🚀 [신규] 안전 이격거리처럼 규정과 관련된 중요한 치수선 표시.
  bool isSafetyCritical;

  PlacedDimension({
    required this.id,
    required this.p1,
    required this.p2,
    required this.type,
    this.note,
    this.minGapMm,
    this.isDiagonal = false,
    this.isSafetyCritical = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'p1': p1.toJson(),
    'p2': p2.toJson(),
    'type': type.name,
    'note': note,
    'minGapMm': minGapMm,
    'isDiagonal': isDiagonal,
    'isSafetyCritical': isSafetyCritical,
  };

  factory PlacedDimension.fromJson(Map<String, dynamic> j) => PlacedDimension(
    id: j['id'] as String,
    p1: _measurePointFromJson(Map<String, dynamic>.from(j['p1'] as Map)),
    p2: _measurePointFromJson(Map<String, dynamic>.from(j['p2'] as Map)),
    type: DimensionType.values.byName(j['type'] as String),
    note: j['note'] as String?,
    minGapMm: (j['minGapMm'] as num?)?.toDouble(),
    isDiagonal: j['isDiagonal'] as bool? ?? false,
    isSafetyCritical: j['isSafetyCritical'] as bool? ?? false,
  );
}

// 🚀 [정리] 손으로 앵커를 옮기는 기능은 태블릿에서도 제거하고, 센터/측면
// 자동 계산만 남겼다 (모바일과 동일).
({Offset p1, Offset p2, double distance}) computeDimensionEndpoints(
  PlacedDimension dim,
) {
  final Rect r1 = dim.p1.boundingBox;
  final Rect r2 = dim.p2.boundingBox;

  // 🚀 [신규] 대각선 모드면 축 정렬 없이 두 중심점을 직선 그대로 잇는다.
  if (dim.isDiagonal) {
    final Offset p1 = r1.center;
    final Offset p2 = r2.center;
    return (p1: p1, p2: p2, distance: (p1 - p2).distance);
  }

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
// 2. 메인 페이지 화면 (Tablet Layout)
// ---------------------------------------------------------
class TabletLayoutBoardPage extends StatefulWidget {
  // 🚀 [추가] 프로젝트 목록에서 저장된 도면을 불러올 때 사용 (모바일과 동일).
  final String? projectId;
  // 🚀 [신규] 작업 일지 작성 화면에서 진입했을 때 true (모바일과 동일 개념).
  final bool attachToReport;

  const TabletLayoutBoardPage({
    super.key,
    this.projectId,
    this.attachToReport = false,
  });

  @override
  State<TabletLayoutBoardPage> createState() => _TabletLayoutBoardPageState();
}

class _TabletLayoutBoardPageState extends State<TabletLayoutBoardPage>
    with WidgetsBindingObserver {
  double _panelWidth = 600.0;
  double _panelHeight = 800.0;

  // 🚀 [핵심] 스냅 단위를 5mm로 초정밀화
  final double _gridSize = 5.0;

  BoardMode _mode = BoardMode.placeModule;
  DimensionType _currentDimType = DimensionType.center;
  // 🚀 [신규] 체인 모드(모바일과 동일 개념) - 켜두면 점을 계속 이어서
  // 탭하는 것만으로 연속된 치수선을 만들 수 있다.
  bool _dimensionChainMode = false;
  // 🚀 [신규] 대각선 모드(모바일과 동일 개념).
  bool _dimensionDiagonalMode = false;
  // 🚀 [신규] 치수의 기준/메모/최소 간격을 바꿨을 때 DimensionPainter가
  // 확실히 다시 그려지도록 하는 버전 카운터(모바일과 동일한 이유).
  int _dimensionsVersion = 0;
  // 🚀 [추가] 모듈 배치/이동 중 자동으로 뜨는 가이드선을 모드 전환 없이
  // 그때그때 켜고 끌 수 있는 토글. 센터선/외곽선은 독립적으로 켤 수
  // 있어서 둘 다 동시에 볼 수도 있다.
  bool _showCenterGuide = true;
  bool _showEdgeGuide = false;

  // 🚀 [추가] 저장/불러오기 상태 (모바일과 동일한 개념)
  bool _isSaving = false;
  bool _isLoadingProject = false;
  String? _currentProjectId;
  String _projectName = "";

  final List<PlacedItem> _placedItems = [];
  final List<PlacedDimension> _dimensions = [];

  MeasurePoint? _dimensionStartPoint;
  PlacedItem? _selectedItem;
  // 🚀 [추가] 사이드바에서 새 모듈을 도면 위로 끌고 오는 중에도 미리보기와
  // 가이드선을 보여주기 위한 임시 아이템(모바일과 동일)
  PlacedItem? _previewItem;
  Offset _dragRawPosition = Offset.zero;

  // 🚀 [복원] 정렬 안내선(모바일과 동일).
  double? _alignGuideX;
  double? _alignGuideY;

  // 🚀 [신규] 다중 선택(모바일과 동일 개념).
  bool _multiSelectMode = false;
  Set<String> _multiSelectedIds = {};
  Offset? _groupDragAnchorOrigin;
  Map<String, Offset> _groupDragOrigins = {};
  // 🚀 [버그 수정] 그룹 드래그 중 항목마다 따로 화면 경계에 clamp를
  // 걸면 폭이 서로 다른 모듈들이 겹쳐버리는 문제가 있었다(모바일과
  // 동일 버그, 같이 수정) - 그룹 전체 바운딩 박스 기준으로 delta를
  // 딱 한 번만 잘라서 상대 위치를 항상 유지한다.
  Rect? _groupOriginBounds;

  // 🚀 [신규] 실제 도면 사진을 배경으로 깔아두고 그 위에 모듈을 배치하는
  // 기능(모바일과 동일).
  String? _backgroundImagePath;
  double _backgroundOpacity = 0.5;

  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _captureKey = GlobalKey();

  // 🚀 [신규] 미니맵(모바일과 동일 개념).
  final TransformationController _viewerController = TransformationController();
  Size? _viewportSize;

  // 🚀 [추가] 서버에 정식 저장하기 전 휘발성을 막는 로컬 임시 저장
  // (모바일 화면과 동일한 방식 - 자세한 설명은 그쪽 주석 참고)
  static const String _draftPrefsKey = 'tablet_layout_board_draft_v1';
  Timer? _draftTimer;

  // 🚀 [신규] 자주 쓰는 모듈 크기 프리셋(모바일과 동일 개념·같은 저장
  // 키를 써서 모바일/태블릿 어느 화면에서 저장하든 서로 공유된다).
  static const String _customPresetsPrefsKey = 'layout_board_custom_presets';
  List<ModulePreset> _customPresets = [];
  // 🚀 [신규] 프리셋 검색(모바일과 동일 개념).
  final TextEditingController _presetSearchCtrl = TextEditingController();
  String _presetSearchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCustomPresets();
    // 🚀 확대/이동할 때마다 미니맵이 따라 움직이도록 다시 그려준다.
    _viewerController.addListener(() {
      if (mounted) setState(() {});
    });
    if (widget.projectId != null) {
      _loadProject(widget.projectId!);
    } else {
      // 🚀 [신규] 새 도면을 열 때만 처음 한 번 사용법을 간단히 안내한다
      // (모바일과 동일 - 임시 저장 확인이 먼저 끝난 뒤에 보여준다).
      _checkAndOfferDraftRecovery().then((_) => _maybeShowOnboarding());
    }
    _draftTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _saveDraftToPrefs(),
    );
  }

  // 🚀 [신규] 처음 배치도 화면을 여는 사람을 위한 사용법 안내(모바일과
  // 같은 SharedPreferences 키를 써서, 폰/태블릿 어느 쪽에서 한 번
  // 봤으면 다른 쪽에서도 다시 뜨지 않는다).
  static const String _onboardingShownPrefsKey =
      'layout_board_onboarding_shown_v1';

  Future<void> _maybeShowOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_onboardingShownPrefsKey) == true) return;
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "작업 배치도 사용법",
            style: TextStyle(color: tossText, fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  keepWords("① 왼쪽 팔레트에서 모듈을 도면 위로 끌어다 놓습니다."),
                  style: TextStyle(color: tossText, fontSize: 13, height: 1.6),
                ),
                Text(
                  keepWords("② '고정 치수 측정' 모드에서 두 지점을 순서대로 탭하면 거리가 자동으로 표시됩니다."),
                  style: TextStyle(color: tossText, fontSize: 13, height: 1.6),
                ),
                Text(
                  keepWords("③ 상단의 '다중 선택'을 켜면 여러 모듈을 한 번에 옮기거나 정렬할 수 있습니다."),
                  style: TextStyle(color: tossText, fontSize: 13, height: 1.6),
                ),
                Text(
                  keepWords("④ ⋮ 더보기 메뉴에서 색상 범례, 배경 사진, 자재 수량 등을 확인할 수 있습니다."),
                  style: TextStyle(color: tossText, fontSize: 13, height: 1.6),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "확인",
                style: TextStyle(color: tossBlue, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      await prefs.setBool(_onboardingShownPrefsKey, true);
    } catch (_) {}
  }

  Future<void> _loadCustomPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_customPresetsPrefsKey);
      if (raw == null) return;
      final List<dynamic> list = jsonDecode(raw);
      if (!mounted) return;
      setState(() {
        _customPresets = list
            .map(
              (e) => ModulePreset(
                e['name'] as String,
                (e['width'] as num).toDouble(),
                (e['height'] as num).toDouble(),
              ),
            )
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _saveCustomPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _customPresetsPrefsKey,
        jsonEncode(
          _customPresets
              .map(
                (p) => {'name': p.name, 'width': p.width, 'height': p.height},
              )
              .toList(),
        ),
      );
    } catch (_) {}
  }

  Future<void> _saveAsCustomPreset(
    String name,
    double width,
    double height,
  ) async {
    setState(() {
      _customPresets = [..._customPresets, ModulePreset(name, width, height)];
    });
    await _saveCustomPresets();
  }

  Future<void> _deleteCustomPreset(int index) async {
    setState(() {
      _customPresets = [..._customPresets]..removeAt(index);
    });
    await _saveCustomPresets();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    _saveDraftToPrefs();
    _presetSearchCtrl.dispose();
    _viewerController.dispose();
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

  bool get _hasAnyContent => _placedItems.isNotEmpty || _dimensions.isNotEmpty;

  // 🚀 [신규] 빈 도면을 처음 여는 사람이 눌러볼 수 있는 예시 배치
  // (모바일과 동일).
  void _loadSampleLayout() {
    _pushUndo();
    setState(() {
      _placedItems.clear();
      _dimensions.clear();
      final PlacedItem a = PlacedItem(
        id: 'sample_a',
        name: '차단기 A',
        position: const Offset(40, 40),
        width: 80,
        height: 80,
      );
      final PlacedItem b = PlacedItem(
        id: 'sample_b',
        name: '차단기 B',
        position: const Offset(180, 40),
        width: 80,
        height: 80,
      );
      final PlacedItem duct = PlacedItem(
        id: 'sample_duct',
        name: 'ABS덕트 60mm',
        position: const Offset(40, 160),
        width: 60,
        height: 200,
      );
      _placedItems.addAll([a, b, duct]);
      _dimensions.add(
        PlacedDimension(
          id: 'sample_dim_1',
          p1: a,
          p2: b,
          type: DimensionType.edge,
          note: '이격거리 예시',
        ),
      );
    });
    HapticFeedback.mediumImpact();
  }

  Map<String, dynamic> _buildSnapshotJson() => {
    'projectId': _currentProjectId,
    'projectName': _projectName,
    'panelWidth': _panelWidth,
    'panelHeight': _panelHeight,
    'items': _placedItems.map((e) => e.toJson()).toList(),
    'dimensions': _dimensions.map((e) => e.toJson()).toList(),
    'backgroundImagePath': _backgroundImagePath,
    'backgroundOpacity': _backgroundOpacity,
  };

  // 🚀 [신규] 실행 취소/다시 실행 (모바일과 동일한 방식). 모듈 배치/이동/삭제/
  // 회전/치수 추가·삭제 등 "한 번의 사용자 조작" 직전마다 현재 상태를
  // 스냅샷으로 쌓아두고, 되돌릴 땐 그 스냅샷으로 복원한다. items/dimensions만
  // 다루고(패널 크기 등은 그대로 유지) 30단계까지 기억한다.
  final List<Map<String, dynamic>> _undoStack = [];
  final List<Map<String, dynamic>> _redoStack = [];
  static const int _maxUndoSteps = 30;

  Map<String, dynamic> _captureUndoState() => {
    'items': _placedItems.map((e) => e.toJson()).toList(),
    'dimensions': _dimensions.map((e) => e.toJson()).toList(),
  };

  // 실제로 뭔가 바꾸기 "직전"에 호출한다.
  void _pushUndo() {
    _undoStack.add(_captureUndoState());
    if (_undoStack.length > _maxUndoSteps) _undoStack.removeAt(0);
    _redoStack.clear(); // 새 조작을 하면 이전에 되돌렸던 redo 기록은 무효
  }

  void _restoreUndoState(Map<String, dynamic> snap) {
    _placedItems
      ..clear()
      ..addAll(
        (snap['items'] as List).map(
          (e) => PlacedItem.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    _dimensions
      ..clear()
      ..addAll(
        (snap['dimensions'] as List).map(
          (e) => PlacedDimension.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    _selectedItem = null;
    _previewItem = null;
    _dimensionStartPoint = null;
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(_captureUndoState());
      _restoreUndoState(_undoStack.removeLast());
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_captureUndoState());
      _restoreUndoState(_redoStack.removeLast());
    });
  }

  // 🚀 [신규] 히스토리 목록에서 특정 단계로 한 번에 이동한다(모바일과
  // 동일 개념).
  void _jumpToHistoryEntry(int stepsBack) {
    if (stepsBack < 1 || stepsBack > _undoStack.length) return;
    setState(() {
      for (int i = 0; i < stepsBack; i++) {
        _redoStack.add(_captureUndoState());
        _restoreUndoState(_undoStack.removeLast());
      }
    });
  }

  void _showUndoHistorySheet() {
    if (_undoStack.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            keepWords("실행 취소 히스토리 (${_undoStack.length}단계)"),
            style: const TextStyle(
              color: tossText,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          content: SizedBox(
            width: 340,
            height: 400,
            child: ListView.builder(
              itemCount: _undoStack.length,
              itemBuilder: (context, i) {
                final int stepsBack = i + 1;
                return ListTile(
                  leading: const Icon(Icons.history_rounded, color: tossBlue),
                  title: Text(
                    keepWords("$stepsBack단계 전으로 이동"),
                    style: const TextStyle(
                      color: tossText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _jumpToHistoryEntry(stepsBack);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("닫기", style: TextStyle(color: tossSubText)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveDraftToPrefs() async {
    if (!_hasAnyContent) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftPrefsKey, jsonEncode(_buildSnapshotJson()));
    } catch (_) {}
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
          (e) => PlacedDimension.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    _backgroundImagePath = data['backgroundImagePath'] as String?;
    _backgroundOpacity = (data['backgroundOpacity'] as num?)?.toDouble() ?? 0.5;
  }

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
              content: Text(
                keepWords("저장하지 않고 나간 작업 내용이 남아있습니다."),
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
    } catch (_) {}
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
          SnackBar(
            content: Text(keepWords("프로젝트를 찾을 수 없습니다.")),
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
        SnackBar(
          content: Text(keepWords("불러오기 실패: $e")),
          backgroundColor: warningRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingProject = false);
    }
  }

  // 🚀 [수정] 저장할 때마다 새 문서를 만들지 않고, 이미 저장/불러온
  // 프로젝트면 그 문서를 갱신(update)한다 (모바일과 동일한 로직).
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
        'backgroundImagePath': _backgroundImagePath,
        'backgroundOpacity': _backgroundOpacity,
      }, SetOptions(merge: true));
      _currentProjectId = docRef.id;
      _projectName = projectName;
      await _clearDraftPrefs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(keepWords("프로젝트 저장 완료!")),
          backgroundColor: tossBlue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(keepWords("저장 실패")),
          backgroundColor: warningRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 🚀 [신규] 레이아웃 템플릿 라이브러리(모바일과 동일 개념).
  void _saveAsTemplate() {
    if (!_hasAnyContent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(keepWords("템플릿으로 저장할 내용이 없습니다."))));
      return;
    }
    final TextEditingController nameCtrl = TextEditingController(
      text: _projectName.isNotEmpty ? _projectName : "새 템플릿",
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "템플릿으로 저장",
          style: TextStyle(color: tossText, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: tossText, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: "템플릿 이름",
            filled: true,
            fillColor: tossBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: tossSubText)),
          ),
          TextButton(
            onPressed: () async {
              final String name = nameCtrl.text.trim().isEmpty
                  ? "이름 없는 템플릿"
                  : nameCtrl.text.trim();
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance
                    .collection('layout_templates')
                    .add({
                      'name': name,
                      'panelWidth': _panelWidth,
                      'panelHeight': _panelHeight,
                      'items': _placedItems.map((e) => e.toJson()).toList(),
                      'dimensions': _dimensions.map((e) => e.toJson()).toList(),
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(keepWords("템플릿으로 저장했습니다.")),
                    backgroundColor: tossBlue,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(keepWords("템플릿 저장 실패: $e")),
                    backgroundColor: warningRed,
                  ),
                );
              }
            },
            child: const Text(
              "저장",
              style: TextStyle(color: tossBlue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showTemplateLibrarySheet() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "템플릿 불러오기",
            style: TextStyle(color: tossText, fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 400,
            height: 420,
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('layout_templates')
                  .orderBy('createdAt', descending: true)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: tossBlue),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      keepWords(
                        "저장된 템플릿이 없습니다.\n'더보기 > 템플릿으로 저장'으로 먼저 만들어 보십시오.",
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tossSubText),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final int itemCount = (data['items'] as List?)?.length ?? 0;
                    return ListTile(
                      leading: const Icon(
                        Icons.dashboard_customize_rounded,
                        color: tossBlue,
                      ),
                      title: Text(
                        data['name'] as String? ?? "이름 없는 템플릿",
                        style: const TextStyle(
                          color: tossText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        keepWords("모듈 $itemCount개"),
                        style: const TextStyle(
                          color: tossSubText,
                          fontSize: 12,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: warningRed,
                        ),
                        onPressed: () async {
                          await docs[i].reference.delete();
                          if (context.mounted) Navigator.pop(ctx);
                        },
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _applyTemplate(data);
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("닫기", style: TextStyle(color: tossSubText)),
            ),
          ],
        );
      },
    );
  }

  void _applyTemplate(Map<String, dynamic> data) {
    void doApply() {
      _pushUndo();
      setState(() {
        _panelWidth = (data['panelWidth'] as num?)?.toDouble() ?? _panelWidth;
        _panelHeight =
            (data['panelHeight'] as num?)?.toDouble() ?? _panelHeight;
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
      });
    }

    if (!_hasAnyContent) {
      doApply();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "템플릿 적용",
          style: TextStyle(color: tossText, fontWeight: FontWeight.bold),
        ),
        content: Text(
          keepWords(
            "템플릿을 불러오면 지금 작업 중인 배치는 사라집니다(실행 취소로 되돌릴 수 있습니다). 계속하시겠습니까?",
          ),
          style: TextStyle(color: tossSubText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: tossSubText)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              doApply();
            },
            child: const Text(
              "적용",
              style: TextStyle(color: tossBlue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [신규] 저장 전 변경 사항 비교(모바일과 동일 개념).
  Future<bool> _confirmChangesBeforeSave() async {
    if (_currentProjectId == null) return true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('layouts')
          .doc(_currentProjectId)
          .get();
      final data = doc.data();
      if (data == null) return true;

      final List<PlacedItem> savedItems = ((data['items'] as List?) ?? [])
          .map((e) => PlacedItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final Map<String, PlacedItem> savedById = {
        for (final i in savedItems) i.id: i,
      };
      final Map<String, PlacedItem> currentById = {
        for (final i in _placedItems) i.id: i,
      };

      final List<String> added = [];
      final List<String> removed = [];
      final List<String> moved = [];

      for (final entry in currentById.entries) {
        final PlacedItem? prev = savedById[entry.key];
        if (prev == null) {
          added.add(entry.value.name);
        } else if (prev.position != entry.value.position ||
            prev.width != entry.value.width ||
            prev.height != entry.value.height) {
          moved.add(entry.value.name);
        }
      }
      for (final entry in savedById.entries) {
        if (!currentById.containsKey(entry.key)) removed.add(entry.value.name);
      }

      final int savedDimCount = (data['dimensions'] as List?)?.length ?? 0;
      final int dimDelta = _dimensions.length - savedDimCount;

      if (added.isEmpty && removed.isEmpty && moved.isEmpty && dimDelta == 0) {
        return true;
      }

      if (!mounted) return true;
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "저장 전 변경 사항 확인",
            style: TextStyle(color: tossText, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (moved.isNotEmpty) _diffLine("이동됨", moved, tossBlue),
                  if (added.isNotEmpty) _diffLine("추가됨", added, tossBlue),
                  if (removed.isNotEmpty) _diffLine("삭제됨", removed, warningRed),
                  if (dimDelta != 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        dimDelta > 0
                            ? "치수선 $dimDelta개 추가됨"
                            : "치수선 ${-dimDelta}개 삭제됨",
                        style: const TextStyle(
                          color: tossSubText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("취소", style: TextStyle(color: tossSubText)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                "저장",
                style: TextStyle(color: tossBlue, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      return proceed ?? false;
    } catch (_) {
      return true;
    }
  }

  Widget _diffLine(String label, List<String> names, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label (${names.length})",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            names.join(', '),
            style: const TextStyle(color: tossSubText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // 🚀 [신규] 다른 프로젝트 도면에서 모듈 가져오기(모바일과 동일 개념).
  void _showImportModulesFlow() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "가져올 도면 선택",
            style: TextStyle(color: tossText, fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 400,
            height: 420,
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('layouts')
                  .orderBy('updatedAt', descending: true)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: tossBlue),
                  );
                }
                final docs = (snapshot.data?.docs ?? [])
                    .where((d) => d.id != _currentProjectId)
                    .toList();
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      keepWords("가져올 수 있는 다른 도면이 없습니다."),
                      style: TextStyle(color: tossSubText),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final int itemCount = (data['items'] as List?)?.length ?? 0;
                    return ListTile(
                      leading: const Icon(
                        Icons.dashboard_customize_rounded,
                        color: tossBlue,
                      ),
                      title: Text(
                        data['projectName'] as String? ?? "이름 없는 도면",
                        style: const TextStyle(
                          color: tossText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        keepWords("모듈 $itemCount개"),
                        style: const TextStyle(
                          color: tossSubText,
                          fontSize: 12,
                        ),
                      ),
                      enabled: itemCount > 0,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showImportItemPicker(data);
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("취소", style: TextStyle(color: tossSubText)),
            ),
          ],
        );
      },
    );
  }

  void _showImportItemPicker(Map<String, dynamic> sourceData) {
    final List<PlacedItem> sourceItems = ((sourceData['items'] as List?) ?? [])
        .map((e) => PlacedItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final Set<String> selectedIds = {};

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: pureWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                keepWords("가져올 모듈 선택 (${sourceData['projectName'] ?? ''})"),
                style: const TextStyle(
                  color: tossText,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              content: SizedBox(
                width: 400,
                height: 420,
                child: ListView.builder(
                  itemCount: sourceItems.length,
                  itemBuilder: (context, i) {
                    final item = sourceItems[i];
                    final bool selected = selectedIds.contains(item.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (v) {
                        setModalState(() {
                          if (v == true) {
                            selectedIds.add(item.id);
                          } else {
                            selectedIds.remove(item.id);
                          }
                        });
                      },
                      title: Text(
                        item.name,
                        style: const TextStyle(
                          color: tossText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        keepWords(
                          "${item.width.toInt()}×${item.height.toInt()}mm",
                        ),
                        style: const TextStyle(
                          color: tossSubText,
                          fontSize: 12,
                        ),
                      ),
                      activeColor: tossBlue,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("취소", style: TextStyle(color: tossSubText)),
                ),
                ElevatedButton(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          _importSelectedModules(
                            sourceItems.where(
                              (i) => selectedIds.contains(i.id),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tossBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    keepWords("선택한 모듈 ${selectedIds.length}개 가져오기"),
                    style: const TextStyle(
                      color: pureWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _importSelectedModules(Iterable<PlacedItem> items) {
    _pushUndo();
    setState(() {
      for (final src in items) {
        final PlacedItem newItem = PlacedItem(
          id: 'import_${DateTime.now().microsecondsSinceEpoch}_${src.id}',
          name: src.name,
          position: _snapToGrid(
            Offset(
              src.position.dx.clamp(
                0.0,
                math.max(0.0, _panelWidth - src.width),
              ),
              src.position.dy.clamp(
                0.0,
                math.max(0.0, _panelHeight - src.height),
              ),
            ),
          ),
          width: src.width,
          height: src.height,
        );
        while (_overlapsAny(newItem, newItem.position)) {
          final Offset moved = _snapToGrid(
            Offset(newItem.position.dx + 20, newItem.position.dy + 20),
          );
          if (moved.dx > _panelWidth - newItem.width ||
              moved.dy > _panelHeight - newItem.height) {
            break;
          }
          newItem.position = moved;
        }
        _placedItems.add(newItem);
      }
    });
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(keepWords("모듈 ${items.length}개를 가져왔습니다.")),
        backgroundColor: tossBlue,
      ),
    );
  }

  // 🚀 [신규] 최소 유지 간격을 설정해둔 치수 중, 저장하는 지금 시점에도
  // 여전히 기준을 못 만족하는 것들을 모아서 알려준다(모바일과 동일).
  List<String> _collectMinGapViolations() {
    final List<String> violations = [];
    for (int i = 0; i < _dimensions.length; i++) {
      final dim = _dimensions[i];
      if (dim.minGapMm == null) continue;
      final endpoints = computeDimensionEndpoints(dim);
      if (endpoints.distance < dim.minGapMm!) {
        violations.add(
          "#${i + 1}: 현재 ${endpoints.distance.toInt()}mm (기준 ${dim.minGapMm!.toInt()}mm 이상)",
        );
      }
    }
    return violations;
  }

  Future<bool> _confirmMinGapViolationsIfAny() async {
    final violations = _collectMinGapViolations();
    if (violations.isEmpty) return true;
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "이격거리 미달 경고",
          style: TextStyle(color: warningRed, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              keepWords("최소 간격 기준을 만족하지 못하는 치수선이 ${violations.length}건 있습니다:"),
              style: const TextStyle(color: tossText),
            ),
            const SizedBox(height: 8),
            ...violations.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  "• $v",
                  style: const TextStyle(color: warningRed, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소", style: TextStyle(color: tossSubText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "그래도 저장",
              style: TextStyle(color: warningRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  void _showSaveDialog() {
    final TextEditingController nameCtrl = TextEditingController(
      text: _projectName.isNotEmpty
          ? _projectName
          : "현장 레이아웃_${DateTime.now().day}일",
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "프로젝트 서버에 저장",
          style: TextStyle(fontWeight: FontWeight.w800, color: tossText),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: tossText, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: "프로젝트/현장 명칭",
            filled: true,
            fillColor: tossBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          if (widget.attachToReport)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _attachToDailyReportPhoto();
              },
              icon: const Icon(
                Icons.add_photo_alternate_rounded,
                color: tossBlue,
                size: 18,
              ),
              label: const Text(
                "일지 사진으로 추가",
                style: TextStyle(color: tossBlue, fontWeight: FontWeight.bold),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소", style: TextStyle(color: tossSubText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: tossBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              if (!await _confirmChangesBeforeSave()) return;
              if (!await _confirmMinGapViolationsIfAny()) return;
              _saveToFirebase(nameCtrl.text.trim());
            },
            child: const Text(
              "저장",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [신규] 작업 일지 작성 화면에서 이 도구를 열었을 때, 완성된 배치도를
  // PNG로 캡처해서 그 파일 경로를 결과값으로 들고 화면을 닫는다(모바일과
  // 동일 개념 - 일지 쪽 "현장 사진 첨부" 목록에 그대로 추가된다).
  Future<Uint8List?> _capturePng() async {
    try {
      final boundary =
          _captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  Future<void> _attachToDailyReportPhoto() async {
    setState(() => _isSaving = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null) throw Exception("도면 캡처 실패");
      final dir = await getTemporaryDirectory();
      final file = File(
        "${dir.path}/layout_${DateTime.now().millisecondsSinceEpoch}.png",
      );
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      Navigator.pop(context, file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(keepWords("사진 저장 실패: $e")),
          backgroundColor: warningRed,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  // 🚀 스냅 헬퍼 함수 (이제 5mm 단위로 움직임)
  Offset _snapToGrid(Offset offset) {
    double dx = (offset.dx / _gridSize).round() * _gridSize;
    double dy = (offset.dy / _gridSize).round() * _gridSize;
    return Offset(dx, dy);
  }

  // 🚀 [복원] 정렬 안내선(모바일과 동일 로직) - 위치를 강제로 옮기지
  // 않고 안내만 한다.
  Offset _snapToAlignment(PlacedItem dragging, Offset proposed) {
    const double snapThreshold = 6.0;
    final double left = proposed.dx;
    final double right = proposed.dx + dragging.width;
    final double centerX = proposed.dx + dragging.width / 2;
    final double top = proposed.dy;
    final double bottom = proposed.dy + dragging.height;
    final double centerY = proposed.dy + dragging.height / 2;

    bool rangesOverlap(
      double aStart,
      double aEnd,
      double bStart,
      double bEnd,
    ) => aStart < bEnd && bStart < aEnd;

    double? guideX;
    double? guideY;

    for (final other in _placedItems) {
      if (other.id == dragging.id) continue;
      final double oLeft = other.position.dx;
      final double oRight = other.position.dx + other.width;
      final double oCenterX = other.center.dx;
      final double oTop = other.position.dy;
      final double oBottom = other.position.dy + other.height;
      final double oCenterY = other.center.dy;

      final bool yOverlaps = rangesOverlap(top, bottom, oTop, oBottom);
      final bool xOverlaps = rangesOverlap(left, right, oLeft, oRight);

      if (guideX == null && !yOverlaps) {
        if ((left - oLeft).abs() <= snapThreshold) {
          guideX = oLeft;
        } else if ((right - oRight).abs() <= snapThreshold) {
          guideX = oRight;
        } else if ((centerX - oCenterX).abs() <= snapThreshold) {
          guideX = oCenterX;
        }
      }
      if (guideY == null && !xOverlaps) {
        if ((top - oTop).abs() <= snapThreshold) {
          guideY = oTop;
        } else if ((bottom - oBottom).abs() <= snapThreshold) {
          guideY = oBottom;
        } else if ((centerY - oCenterY).abs() <= snapThreshold) {
          guideY = oCenterY;
        }
      }
    }

    _alignGuideX = guideX;
    _alignGuideY = guideY;
    return proposed;
  }

  // 🚀 [버그 수정] 정렬 스냅뿐 아니라 그냥 드래그로도 모듈을 다른 모듈
  // 위에 완전히 겹쳐 놓을 수 있었다(모바일과 동일 버그, 같이 수정).
  // 후보 위치가 다른 모듈과 겹치면 그 위치로는 이동을 허용하지 않는다.
  bool _overlapsAny(
    PlacedItem dragging,
    Offset candidate, {
    Set<String>? excludeIds,
  }) {
    final Rect rect = Rect.fromLTWH(
      candidate.dx,
      candidate.dy,
      dragging.width,
      dragging.height,
    );
    for (final other in _placedItems) {
      if (other.id == dragging.id) continue;
      if (excludeIds != null && excludeIds.contains(other.id)) continue;
      final Rect otherRect = Rect.fromLTWH(
        other.position.dx,
        other.position.dy,
        other.width,
        other.height,
      );
      if (rect.overlaps(otherRect)) return true;
    }
    return false;
  }

  void _clearBoard() {
    _pushUndo();
    setState(() {
      _placedItems.clear();
      _dimensions.clear();
      _dimensionStartPoint = null;
      _selectedItem = null;
    });
  }

  void _onAcceptItem(ModulePreset preset, Offset localPosition) {
    _pushUndo();
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
      _selectedItem = newItem;
    });
  }

  // 🚀 [버그 수정] 모바일 화면과 동일한 문제 - 벽까지 거리와 무관하게
  // 빈 도면 공간을 탭하면 무조건 "가장 가까운 벽" 지점으로 확정되어
  // 버그처럼 보였다. 벽에서 실제로 가까울 때만 인정하고 나머지는 무시.
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
    if (minDist == distLeft) {
      wallPos = Offset(0, touchPosition.dy);
    } else if (minDist == distRight) {
      wallPos = Offset(_panelWidth, touchPosition.dy);
    } else if (minDist == distTop) {
      wallPos = Offset(touchPosition.dx, 0);
    } else {
      wallPos = Offset(touchPosition.dx, _panelHeight);
    }

    return WallPoint(position: _snapToGrid(wallPos));
  }

  void _handleDimensionPoint(MeasurePoint point) {
    setState(() {
      if (_dimensionStartPoint == null) {
        _dimensionStartPoint = point;
      } else {
        if (_dimensionStartPoint!.id != point.id) {
          // 🚀 [버그 수정] type 비교 누락으로 같은 두 지점을 "센터 기준"
          // 으로 한 번 측정하면 "측면 기준"으로는 다시 측정되지 않던
          // 문제 (모바일 화면과 동일한 버그, 같이 수정).
          bool exists = _dimensions.any(
            (dim) =>
                dim.type == _currentDimType &&
                dim.isDiagonal == _dimensionDiagonalMode &&
                ((dim.p1.id == _dimensionStartPoint!.id &&
                        dim.p2.id == point.id) ||
                    (dim.p1.id == point.id &&
                        dim.p2.id == _dimensionStartPoint!.id)),
          );

          if (!exists) {
            _pushUndo();
            _dimensions.add(
              PlacedDimension(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                p1: _dimensionStartPoint!,
                p2: point,
                type: _currentDimType,
                isDiagonal: _dimensionDiagonalMode,
              ),
            );
            HapticFeedback.heavyImpact();
          }
        }
        // 🚀 체인 모드면 방금 찍은 점을 다음 구간의 시작점으로 그대로
        // 이어간다(모바일과 동일).
        _dimensionStartPoint = _dimensionChainMode ? point : null;
      }
    });
  }

  void _onTapItem(PlacedItem item) {
    HapticFeedback.lightImpact();
    if (_mode == BoardMode.measureDimension) {
      _handleDimensionPoint(item);
      return;
    }
    if (_multiSelectMode) {
      setState(() {
        if (_multiSelectedIds.contains(item.id)) {
          _multiSelectedIds = {..._multiSelectedIds}..remove(item.id);
          item.isSelected = false;
        } else {
          _multiSelectedIds = {..._multiSelectedIds, item.id};
          item.isSelected = true;
        }
      });
      return;
    }
    // 🚀 인스펙터 패널이 이 모듈을 편집 대상으로 잡는 "시작 시점"에
    // 스냅샷 한 번만 남긴다 - 이후 이름/크기/좌표를 몇 번을 고치든
    // "선택 취소" 한 번으로 전부 되돌아가게(모바일 바텀시트와 동일 원칙).
    if (_selectedItem?.id != item.id) _pushUndo();
    setState(() {
      for (var i in _placedItems) i.isSelected = false;
      item.isSelected = true;
      _selectedItem = item;
    });
  }

  void _onTapBoard(Offset localPosition) {
    if (_mode == BoardMode.measureDimension) {
      // 🚀 [신규] 측정 시작 전에 기존 치수선 근처를 탭하면 삭제/기준
      // 전환/메모/최소 간격 설정을 할 수 있는 창을 연다(모바일과 동일).
      if (_dimensionStartPoint == null) {
        final PlacedDimension? hitDim = _findDimensionNear(localPosition);
        if (hitDim != null) {
          HapticFeedback.lightImpact();
          _showDimensionActionsDialog(hitDim);
          return;
        }
      }
      final WallPoint? nearestWall = _getNearestWallPoint(localPosition);
      if (nearestWall == null) return; // 벽에서 너무 먼 빈 허공 탭은 무시
      HapticFeedback.lightImpact();
      _handleDimensionPoint(nearestWall);
    } else {
      setState(() {
        for (var i in _placedItems) i.isSelected = false;
        _selectedItem = null;
        _multiSelectedIds = {};
      });
    }
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final Offset ab = b - a;
    final double abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLenSq == 0) return (p - a).distance;
    double t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / abLenSq;
    t = t.clamp(0.0, 1.0);
    final Offset proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - proj).distance;
  }

  // 🚀 [신규] 번호 배지(p1 지점에 그려짐)는 선 자체보다 좀 더 넉넉한
  // 반경으로 우선 인식한다(모바일과 동일).
  PlacedDimension? _findDimensionNear(Offset pos) {
    const double segmentTolerance = 14.0;
    const double badgeTolerance = 16.0;
    PlacedDimension? closest;
    double closestDist = double.infinity;
    for (final dim in _dimensions) {
      final endpoints = computeDimensionEndpoints(dim);
      final double badgeDist = (pos - endpoints.p1).distance;
      if (badgeDist <= badgeTolerance && badgeDist < closestDist) {
        closestDist = badgeDist;
        closest = dim;
        continue;
      }
      final double segDist = _distanceToSegment(
        pos,
        endpoints.p1,
        endpoints.p2,
      );
      if (segDist <= segmentTolerance && segDist < closestDist) {
        closestDist = segDist;
        closest = dim;
      }
    }
    return closest;
  }

  // 🚀 [신규] 치수선 하나를 탭했을 때 - 삭제/기준 전환/메모/최소 간격
  // 설정을 한 곳에서 처리하는 다이얼로그(모바일 바텀시트와 동일 기능,
  // 태블릿은 다른 모달들과 통일해서 Dialog로).
  void _showDimensionActionsDialog(PlacedDimension dim) {
    _pushUndo();
    final TextEditingController noteCtrl = TextEditingController(
      text: dim.note ?? "",
    );
    final TextEditingController minGapCtrl = TextEditingController(
      text: dim.minGapMm != null ? dim.minGapMm!.toInt().toString() : "",
    );
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final endpoints = computeDimensionEndpoints(dim);
            return AlertDialog(
              backgroundColor: pureWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                keepWords("치수선 - ${endpoints.distance.toInt()} mm"),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: tossText,
                ),
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "측정 기준",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tossSubText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDimTypeChoiceChip(
                            "센터 기준",
                            DimensionType.center,
                            dim,
                            setModalState,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDimTypeChoiceChip(
                            "측면 기준",
                            DimensionType.edge,
                            dim,
                            setModalState,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "메모",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tossSubText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteCtrl,
                      style: const TextStyle(fontSize: 14, color: tossText),
                      decoration: InputDecoration(
                        hintText: "예: 케이블 트레이 통과 구간",
                        filled: true,
                        fillColor: tossBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) {
                        setState(() {
                          dim.note = v.trim().isEmpty ? null : v.trim();
                          _dimensionsVersion++;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      keepWords("최소 유지 간격 (mm) - 이보다 좁아지면 경고 표시"),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tossSubText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minGapCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 14,
                              color: tossText,
                            ),
                            decoration: InputDecoration(
                              hintText: "예: 30",
                              filled: true,
                              fillColor: tossBg,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (v) {
                              final parsed = double.tryParse(v);
                              setState(() {
                                dim.minGapMm = parsed;
                                _dimensionsVersion++;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            minGapCtrl.clear();
                            setModalState(() {});
                            setState(() {
                              dim.minGapMm = null;
                              _dimensionsVersion++;
                            });
                          },
                          child: const Text(
                            "해제",
                            style: TextStyle(
                              color: tossSubText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 🚀 [신규] 자주 쓰는 최소 간격값 프리셋.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [20, 30, 50, 100].map((v) {
                        final bool selected = dim.minGapMm == v.toDouble();
                        return GestureDetector(
                          onTap: () {
                            minGapCtrl.text = v.toString();
                            setModalState(() {});
                            setState(() {
                              dim.minGapMm = v.toDouble();
                              _dimensionsVersion++;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? tossBlue.withValues(alpha: 0.12)
                                  : tossBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected ? tossBlue : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            child: Text(
                              "${v}mm",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: selected ? tossBlue : tossSubText,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    // 🚀 [신규] 대각선 모드 - 축 정렬 없이 실제 직선거리+
                    // 각도로 바꾼다.
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: dim.isDiagonal,
                      activeThumbColor: diagonalDimColor,
                      onChanged: (v) {
                        setState(() {
                          dim.isDiagonal = v;
                          _dimensionsVersion++;
                        });
                        setModalState(() {});
                      },
                      title: const Text(
                        "대각선 모드",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tossText,
                        ),
                      ),
                      subtitle: Text(
                        keepWords("축에 맞추지 않고 실제 직선거리+각도로 표시"),
                        style: TextStyle(fontSize: 11, color: tossSubText),
                      ),
                    ),
                    // 🚀 [신규] 안전 이격거리 강조 표시.
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: dim.isSafetyCritical,
                      activeThumbColor: warningRed,
                      onChanged: (v) {
                        setState(() {
                          dim.isSafetyCritical = v;
                          _dimensionsVersion++;
                        });
                        setModalState(() {});
                      },
                      title: Text(
                        keepWords("안전 이격거리로 강조 표시"),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tossText,
                        ),
                      ),
                      subtitle: Text(
                        keepWords("굵은 선 + 🛡 표시로 다른 치수와 구분"),
                        style: TextStyle(fontSize: 11, color: tossSubText),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _pushUndo();
                    setState(() {
                      _dimensions.removeWhere((d) => d.id == dim.id);
                    });
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "이 치수선 삭제",
                    style: TextStyle(
                      color: warningRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "닫기",
                    style: TextStyle(
                      color: tossSubText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDimTypeChoiceChip(
    String label,
    DimensionType type,
    PlacedDimension dim,
    StateSetter setModalState,
  ) {
    final bool selected = dim.type == type;
    final Color color = type == DimensionType.center
        ? centerDimColor
        : edgeDimColor;
    return GestureDetector(
      onTap: () {
        setState(() {
          dim.type = type;
          _dimensionsVersion++;
        });
        setModalState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : tossBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : tossSubText,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _multiSelectMode = !_multiSelectMode;
      if (!_multiSelectMode) {
        _multiSelectedIds = {};
        for (var i in _placedItems) {
          i.isSelected = false;
        }
      }
    });
  }

  List<PlacedItem> get _selectedGroup =>
      _placedItems.where((i) => _multiSelectedIds.contains(i.id)).toList();

  void _nudgeSelected(Offset direction) {
    final items = _selectedGroup.where((i) => !i.isLocked).toList();
    if (items.isEmpty) return;
    _pushUndo();
    setState(() {
      for (final i in items) {
        i.position = Offset(
          (i.position.dx + direction.dx * _gridSize).clamp(
            0.0,
            math.max(0.0, _panelWidth - i.width),
          ),
          (i.position.dy + direction.dy * _gridSize).clamp(
            0.0,
            math.max(0.0, _panelHeight - i.height),
          ),
        );
      }
    });
  }

  void _duplicateSelectedGroup() {
    final items = _selectedGroup;
    if (items.isEmpty) return;
    _pushUndo();
    final newIds = <String>{};
    setState(() {
      for (final item in items) {
        final newItem = PlacedItem(
          id: 'dup_${DateTime.now().microsecondsSinceEpoch}_${item.id}',
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
          isSelected: true,
        );
        _placedItems.add(newItem);
        newIds.add(newItem.id);
      }
      for (final i in _placedItems) {
        i.isSelected = newIds.contains(i.id);
      }
      _multiSelectedIds = newIds;
    });
    HapticFeedback.mediumImpact();
  }

  void _toggleLockSelected() {
    final items = _selectedGroup;
    if (items.isEmpty) return;
    final bool allLocked = items.every((i) => i.isLocked);
    _pushUndo();
    setState(() {
      for (final i in items) {
        i.isLocked = !allLocked;
      }
    });
    HapticFeedback.lightImpact();
  }

  void _deleteSelectedGroup() {
    if (_multiSelectedIds.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "선택 모듈 삭제",
          style: TextStyle(color: tossText, fontWeight: FontWeight.bold),
        ),
        content: Text(
          keepWords("선택한 모듈 ${_multiSelectedIds.length}개를 삭제하시겠습니까?"),
          style: const TextStyle(color: tossSubText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: tossSubText)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final ids = _multiSelectedIds;
              _pushUndo();
              setState(() {
                _dimensions.removeWhere(
                  (d) => ids.contains(d.p1.id) || ids.contains(d.p2.id),
                );
                _placedItems.removeWhere((i) => ids.contains(i.id));
                _multiSelectedIds = {};
              });
            },
            child: const Text(
              "삭제",
              style: TextStyle(color: warningRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [신규] 선택된 모듈 2개 이상을 한쪽으로 맞추거나(정렬), 간격을
  // 균등하게 배분한다(3개 이상일 때만 의미 있음).
  void _applyAlignment(String action) {
    final items = _selectedGroup.where((i) => !i.isLocked).toList();
    if (items.length < 2) return;
    _pushUndo();
    setState(() {
      switch (action) {
        case 'left':
          final double minX = items.map((i) => i.position.dx).reduce(math.min);
          for (final i in items) {
            i.position = Offset(minX, i.position.dy);
          }
          break;
        case 'right':
          final double maxRight = items
              .map((i) => i.position.dx + i.width)
              .reduce(math.max);
          for (final i in items) {
            i.position = Offset(maxRight - i.width, i.position.dy);
          }
          break;
        case 'top':
          final double minY = items.map((i) => i.position.dy).reduce(math.min);
          for (final i in items) {
            i.position = Offset(i.position.dx, minY);
          }
          break;
        case 'bottom':
          final double maxBottom = items
              .map((i) => i.position.dy + i.height)
              .reduce(math.max);
          for (final i in items) {
            i.position = Offset(i.position.dx, maxBottom - i.height);
          }
          break;
        case 'distributeH':
          if (items.length < 3) break;
          final sorted = [...items]
            ..sort((a, b) => a.position.dx.compareTo(b.position.dx));
          final first = sorted.first;
          final last = sorted.last;
          final double totalSpan =
              (last.position.dx + last.width) - first.position.dx;
          final double totalWidth = sorted.fold<double>(
            0,
            (sum, i) => sum + i.width,
          );
          final double gap = (totalSpan - totalWidth) / (sorted.length - 1);
          double cursor = first.position.dx + first.width + gap;
          for (int k = 1; k < sorted.length - 1; k++) {
            sorted[k].position = Offset(cursor, sorted[k].position.dy);
            cursor += sorted[k].width + gap;
          }
          break;
        case 'distributeV':
          if (items.length < 3) break;
          final sortedV = [...items]
            ..sort((a, b) => a.position.dy.compareTo(b.position.dy));
          final firstV = sortedV.first;
          final lastV = sortedV.last;
          final double totalSpanV =
              (lastV.position.dy + lastV.height) - firstV.position.dy;
          final double totalHeightV = sortedV.fold<double>(
            0,
            (sum, i) => sum + i.height,
          );
          final double gapV =
              (totalSpanV - totalHeightV) / (sortedV.length - 1);
          double cursorV = firstV.position.dy + firstV.height + gapV;
          for (int k = 1; k < sortedV.length - 1; k++) {
            sortedV[k].position = Offset(sortedV[k].position.dx, cursorV);
            cursorV += sortedV[k].height + gapV;
          }
          break;
      }
    });
  }

  void _showAlignmentSheet() {
    if (_selectedGroup.length < 2) return;
    showDialog(
      context: context,
      builder: (ctx) {
        Widget actionTile(IconData icon, String label, String action) {
          return ListTile(
            leading: Icon(icon, color: tossBlue),
            title: Text(
              label,
              style: const TextStyle(
                color: tossText,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _applyAlignment(action);
            },
          );
        }

        return AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "정렬 / 간격 배분",
            style: TextStyle(color: tossText, fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                actionTile(
                  Icons.align_horizontal_left_rounded,
                  "왼쪽 정렬",
                  'left',
                ),
                actionTile(
                  Icons.align_horizontal_right_rounded,
                  "오른쪽 정렬",
                  'right',
                ),
                actionTile(Icons.align_vertical_top_rounded, "위쪽 정렬", 'top'),
                actionTile(
                  Icons.align_vertical_bottom_rounded,
                  "아래쪽 정렬",
                  'bottom',
                ),
                actionTile(
                  Icons.align_horizontal_center_rounded,
                  "가로 간격 균등 분배 (3개 이상)",
                  'distributeH',
                ),
                actionTile(
                  Icons.align_vertical_center_rounded,
                  "세로 간격 균등 분배 (3개 이상)",
                  'distributeV',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🚀 [신규] 배치된 모듈을 이름별로 모아 세어서 보여준다(모바일과
  // 동일 기능, 태블릿은 Dialog로).
  // 🚀 [신규] 색상 범례(모바일과 동일 기능).
  void _showColorLegendDialog() {
    Widget row(Color color, String label, String desc) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: tossText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 12,
                      color: tossSubText,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "색상 범례",
          style: TextStyle(color: tossText, fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row(centerDimColor, "파란색", "센터(중심) 기준 치수선/가이드선"),
                row(edgeDimColor, "주황색", "측면(여백) 기준 치수선"),
                row(diagonalDimColor, "보라색", "대각선 모드 치수선(직선거리+각도)"),
                row(alignGuideColor, "마젠타색", "모듈을 옮길 때 뜨는 정렬 안내선"),
                row(warningRed, "빨간색", "최소 간격 위반 경고, 삭제 등 위험/주의 표시"),
                row(tossText, "🛡 방패 표시", "안전 이격거리로 강조된 치수선(굵은 선)"),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "확인",
              style: TextStyle(color: tossBlue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showMaterialSummaryDialog() {
    final Map<String, int> counts = {};
    for (final item in _placedItems) {
      counts[item.name] = (counts[item.name] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String buildSummaryText() {
      final buf = StringBuffer();
      buf.writeln(
        "[${_projectName.isNotEmpty ? _projectName : '작업 배치도'} 자재 수량]",
      );
      for (final e in entries) {
        buf.writeln("- ${e.key} x ${e.value}개");
      }
      buf.writeln("총 모듈 ${_placedItems.length}개");
      return buf.toString();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "자재 수량",
          style: TextStyle(fontWeight: FontWeight.w800, color: tossText),
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                keepWords("배치된 모듈을 이름별로 모아 세었습니다."),
                style: TextStyle(fontSize: 13, color: tossSubText),
              ),
              const SizedBox(height: 16),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    "배치된 모듈이 없습니다.",
                    style: TextStyle(color: tossSubText),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: tossBg),
                    itemBuilder: (context, index) {
                      final e = entries[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.key,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: tossText,
                                ),
                              ),
                            ),
                            Text(
                              "${e.value}개",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: tossBlue,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: tossBg),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    "총 모듈 수",
                    style: TextStyle(
                      fontSize: 13,
                      color: tossSubText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    keepWords("${_placedItems.length}개"),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: tossText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("닫기", style: TextStyle(color: tossSubText)),
          ),
          TextButton(
            onPressed: entries.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(text: buildSummaryText()),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(keepWords("자재 목록을 복사했습니다."))),
                    );
                  },
            child: const Text(
              "텍스트 복사",
              style: TextStyle(color: tossText, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: tossBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: entries.isEmpty
                ? null
                : () {
                    // ignore: deprecated_member_use
                    Share.share(buildSummaryText());
                  },
            child: const Text(
              "공유하기",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [신규] 실제 도면 사진을 배경으로 깔아두고 그 위에 모듈을 배치할 수
  // 있게 하는 다이얼로그(모바일 바텀시트와 동일 기능, 태블릿은 Dialog로).
  void _showBackgroundSheet() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: pureWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                "배경 사진",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: tossText,
                  letterSpacing: -0.5,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      keepWords(
                        "카톡으로 받은 실제 도면 사진을 배경에 깔고 그 위에\n모듈을 배치할 수 있습니다.",
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: tossSubText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_backgroundImagePath != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Image.file(
                            File(_backgroundImagePath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.opacity_rounded,
                            size: 18,
                            color: tossSubText,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "투명도",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: tossText,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _backgroundOpacity,
                              min: 0.15,
                              max: 1.0,
                              activeColor: tossBlue,
                              onChanged: (v) {
                                setModalState(() => _backgroundOpacity = v);
                                setState(() => _backgroundOpacity = v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final path = await ImagePickerHelper.pickImage(
                                context,
                              );
                              if (path != null) {
                                setModalState(
                                  () => _backgroundImagePath = path,
                                );
                                setState(() => _backgroundImagePath = path);
                              }
                            },
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                              color: tossBlue,
                            ),
                            label: Text(
                              _backgroundImagePath == null ? "사진 선택" : "사진 변경",
                              style: const TextStyle(
                                color: tossBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: tossBlue),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        if (_backgroundImagePath != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setModalState(
                                  () => _backgroundImagePath = null,
                                );
                                setState(() => _backgroundImagePath = null);
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                color: warningRed,
                              ),
                              label: const Text(
                                "배경 제거",
                                style: TextStyle(
                                  color: warningRed,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: warningRed),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "닫기",
                    style: TextStyle(
                      color: tossSubText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 외함 크기 설정 팝업 (태블릿용 Dialog)
  void _showPanelSettingsDialog() {
    final widthCtrl = TextEditingController(
      text: _panelWidth.toInt().toString(),
    );
    final heightCtrl = TextEditingController(
      text: _panelHeight.toInt().toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            "전체 외함 크기 설정",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: tossText,
              letterSpacing: -0.5,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                keepWords("실제 중판(캐비닛)의 사이즈를 mm 단위로 입력하십시오."),
                style: TextStyle(color: tossSubText, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildInputBox("가로 (W)", widthCtrl)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInputBox("세로 (H)", heightCtrl)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "취소",
                style: TextStyle(
                  color: tossSubText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _pushUndo();
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "적용",
                style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputBox(String label, TextEditingController controller) {
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
        const SizedBox(height: 6),
        TextField(
          controller: controller
            ..selection = TextSelection.collapsed(
              offset: controller.text.length,
            ),
          keyboardType: TextInputType.number,
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
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // 3. UI 컴포넌트 빌드
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossBg,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "스마트 패널 설계 도면",
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
        actions: [
          // 🚀 [신규] 길게 누르면 히스토리 목록을 연다(모바일과 동일).
          GestureDetector(
            onLongPress: _undoStack.isEmpty ? null : _showUndoHistorySheet,
            child: IconButton(
              tooltip: "실행 취소 (길게 눌러 히스토리)",
              onPressed: _undoStack.isEmpty ? null : _undo,
              icon: Icon(
                Icons.undo_rounded,
                color: _undoStack.isEmpty
                    ? tossSubText.withValues(alpha: 0.4)
                    : tossText,
              ),
            ),
          ),
          IconButton(
            tooltip: "다시 실행",
            onPressed: _redoStack.isEmpty ? null : _redo,
            icon: Icon(
              Icons.redo_rounded,
              color: _redoStack.isEmpty
                  ? tossSubText.withValues(alpha: 0.4)
                  : tossText,
            ),
          ),
          IconButton(
            tooltip: "다중 선택",
            onPressed: _toggleMultiSelectMode,
            icon: Icon(
              Icons.library_add_check_rounded,
              color: _multiSelectMode ? tossBlue : tossText,
            ),
          ),
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
              tooltip: "프로젝트 서버에 저장",
              onPressed: _showSaveDialog,
              icon: const Icon(Icons.save_rounded, color: tossBlue),
            ),
          // 🚀 [버그 수정] AppBar 아이콘/버튼이 계속 늘어나서(자재 수량/
          // 배경 사진/외함 크기/초기화까지) 좁은 화면에서 오버플로우가
          // 났다 - 자주 안 쓰는 것들은 "더보기" 메뉴 하나로 모았다.
          PopupMenuButton<String>(
            tooltip: "더보기",
            icon: const Icon(Icons.more_vert_rounded, color: tossText),
            onSelected: (value) {
              switch (value) {
                case 'material':
                  _showMaterialSummaryDialog();
                  break;
                case 'background':
                  _showBackgroundSheet();
                  break;
                case 'panel':
                  _showPanelSettingsDialog();
                  break;
                case 'clear':
                  _clearBoard();
                  break;
                case 'legend':
                  _showColorLegendDialog();
                  break;
                case 'save_template':
                  _saveAsTemplate();
                  break;
                case 'load_template':
                  _showTemplateLibrarySheet();
                  break;
                case 'import_modules':
                  _showImportModulesFlow();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'legend',
                child: ListTile(
                  leading: Icon(Icons.palette_outlined, color: tossText),
                  title: Text("색상 범례"),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'save_template',
                child: ListTile(
                  leading: Icon(Icons.bookmark_add_outlined, color: tossText),
                  title: Text("템플릿으로 저장"),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'load_template',
                child: ListTile(
                  leading: Icon(Icons.library_books_outlined, color: tossText),
                  title: Text("템플릿 불러오기"),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'import_modules',
                child: ListTile(
                  leading: Icon(Icons.move_down_outlined, color: tossText),
                  title: Text("다른 도면에서 모듈 가져오기"),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'material',
                child: ListTile(
                  leading: Icon(Icons.inventory_2_outlined, color: tossText),
                  title: Text("자재 수량"),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'background',
                child: ListTile(
                  leading: Icon(
                    Icons.image_outlined,
                    color: _backgroundImagePath != null ? tossBlue : tossText,
                  ),
                  title: const Text("배경 사진"),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'panel',
                child: ListTile(
                  leading: Icon(Icons.aspect_ratio_rounded, color: tossText),
                  title: Text("외함 사이즈 설정"),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.refresh_rounded, color: warningRed),
                  title: Text("도면 초기화", style: TextStyle(color: warningRed)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              _buildLeftSidebar(),
              Expanded(child: _buildMainBoard()),
              _buildRightInspector(),
            ],
          ),
          // 🚀 [신규] 다중 선택 도구모음(모바일과 동일 기능).
          // 🚀 [개선] 선택하는 순간 뚝 나타나던 걸 부드럽게 슬라이드
          // 인/아웃 되도록 항상 트리에 두고 위치만 애니메이션한다.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: _multiSelectedIds.isNotEmpty ? 24 : -200,
            child: IgnorePointer(
              ignoring: _multiSelectedIds.isEmpty,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _multiSelectedIds.isNotEmpty ? 1 : 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                    decoration: BoxDecoration(
                      color: tossText,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          keepWords("${_multiSelectedIds.length}개 선택"),
                          style: const TextStyle(
                            color: pureWhite,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildMultiBarIcon(
                          Icons.keyboard_arrow_up_rounded,
                          () => _nudgeSelected(const Offset(0, -1)),
                        ),
                        _buildMultiBarIcon(
                          Icons.keyboard_arrow_down_rounded,
                          () => _nudgeSelected(const Offset(0, 1)),
                        ),
                        _buildMultiBarIcon(
                          Icons.keyboard_arrow_left_rounded,
                          () => _nudgeSelected(const Offset(-1, 0)),
                        ),
                        _buildMultiBarIcon(
                          Icons.keyboard_arrow_right_rounded,
                          () => _nudgeSelected(const Offset(1, 0)),
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: pureWhite.withValues(alpha: 0.2),
                        ),
                        _buildMultiBarIcon(
                          Icons.copy_rounded,
                          _duplicateSelectedGroup,
                        ),
                        // 🚀 [신규] 잠금/정렬은 짧은 라벨을 함께 표시해서
                        // 뜻을 바로 알 수 있게 했다(모바일과 동일).
                        _buildMultiBarLabeledIcon(
                          _selectedGroup.isNotEmpty &&
                                  _selectedGroup.every((i) => i.isLocked)
                              ? Icons.lock_open_rounded
                              : Icons.lock_outline_rounded,
                          _selectedGroup.isNotEmpty &&
                                  _selectedGroup.every((i) => i.isLocked)
                              ? "잠금 해제"
                              : "잠금",
                          _toggleLockSelected,
                        ),
                        _buildMultiBarLabeledIcon(
                          Icons.align_horizontal_left_rounded,
                          "정렬",
                          _multiSelectedIds.length >= 2
                              ? _showAlignmentSheet
                              : null,
                        ),
                        _buildMultiBarIcon(
                          Icons.delete_outline_rounded,
                          _deleteSelectedGroup,
                          color: warningRed,
                        ),
                        IconButton(
                          tooltip: "선택 해제",
                          onPressed: () {
                            setState(() {
                              for (final i in _placedItems) {
                                i.isSelected = false;
                              }
                              _multiSelectedIds = {};
                            });
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            color: pureWhite,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 🚀 [신규] 미니맵(모바일과 동일 기능).
          if (_placedItems.isNotEmpty && _viewportSize != null)
            Positioned(top: 12, right: 336, child: _buildMinimap()),
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

  Widget _buildMultiBarIcon(
    IconData icon,
    VoidCallback? onPressed, {
    Color color = pureWhite,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: onPressed == null ? color.withValues(alpha: 0.3) : color,
        size: 22,
      ),
    );
  }

  // 🚀 [신규] 잠금/정렬처럼 아이콘만으로는 뜻이 바로 와닿지 않는 동작에
  // 짧은 텍스트 라벨을 함께 보여준다(모바일과 동일).
  Widget _buildMultiBarLabeledIcon(
    IconData icon,
    String label,
    VoidCallback? onPressed,
  ) {
    final bool enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled ? pureWhite : pureWhite.withValues(alpha: 0.3),
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: enabled
                    ? pureWhite.withValues(alpha: 0.85)
                    : pureWhite.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 [신규] 미니맵(모바일과 동일 로직).
  Widget _buildMinimap() {
    const double miniW = 96;
    final double scale = miniW / _panelWidth;
    final double miniH = _panelHeight * scale;

    Rect? viewportRect;
    if (_viewportSize != null) {
      try {
        final Matrix4 inverse = Matrix4.inverted(_viewerController.value);
        final Offset topLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
        final Offset bottomRight = MatrixUtils.transformPoint(
          inverse,
          Offset(_viewportSize!.width, _viewportSize!.height),
        );
        viewportRect = Rect.fromPoints(topLeft, bottomRight);
      } catch (_) {}
    }

    return Container(
      width: miniW,
      height: miniH,
      decoration: BoxDecoration(
        color: pureWhite.withValues(alpha: 0.92),
        border: Border.all(color: tossSubText.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          ..._placedItems.map(
            (item) => Positioned(
              left: item.position.dx * scale,
              top: item.position.dy * scale,
              width: math.max(1.5, item.width * scale),
              height: math.max(1.5, item.height * scale),
              child: Container(color: tossBlue.withValues(alpha: 0.5)),
            ),
          ),
          if (viewportRect != null)
            Positioned(
              left: (viewportRect.left * scale).clamp(0.0, miniW),
              top: (viewportRect.top * scale).clamp(0.0, miniH),
              width: (viewportRect.width * scale).clamp(4.0, miniW),
              height: (viewportRect.height * scale).clamp(4.0, miniH),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: warningRed, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLeftSidebar() {
    return Container(
      width: 240,
      color: pureWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: tossBg.withValues(alpha: 0.5),
            child: const Text(
              "자재 라이브러리",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: tossText,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              // 🚀 [수정] 항목이 딱 2개(박스 1개 + 안내문)뿐이라 스크롤이
              // 필요 없는데도 ListView를 써서, 세로 드래그 제스처를 리스트
              // 스크롤이 항상 먼저 가로채 모듈이 전혀 드래그되지 않는
              // 문제가 있었다(실기기 태블릿에서 확인됨). 스크롤이 필요
              // 없는 Column으로 바꿔 이 제스처 경합 자체를 없앤다.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    child: _buildPaletteItem("신규 박스 모듈"),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    keepWords(
                      "위 박스를 우측 도면으로 드래그하여 배치하십시오.\n배치 후 터치하면 우측 패널에서 명칭과 크기를 수정할 수 있습니다.",
                    ),
                    style: TextStyle(
                      color: tossSubText,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 🚀 [추가] ABS 배선덕트 - 폭이 정해진 자재라 배치 후
                  // 크기를 손으로 고칠 필요 없이 원하는 폭을 바로 드래그.
                  // ⚠️ 참고용 명목 폭이며 발주 전 사양서 대조 필요
                  // (kDuctPresets 주석 참고). Wrap을 쓴 이유는 위
                  // _buildPaletteItem 수정 사유와 같음 - 가로 스크롤
                  // ListView를 쓰면 사이드바(왼쪽)에서 도면(오른쪽)으로
                  // 드래그하는 방향이 스크롤 방향과 겹쳐서 실기기에서
                  // 드래그 대신 스크롤로 먹혀버릴 수 있다.
                  const Text(
                    "ABS 덕트 (폭 mm)",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tossText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kDuctPresets.map((preset) {
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
                    }).toList(),
                  ),
                  if (_customPresets.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    // 🚀 [신규] 내가 저장해둔 자주 쓰는 모듈 크기 - 모듈
                    // 편집 패널의 "프리셋으로 저장"으로 추가되며, 길게
                    // 눌러 삭제할 수 있다. ABS 덕트와 같은 이유로 Wrap 사용.
                    const Text(
                      "내 프리셋 (길게 눌러 삭제)",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tossText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 🚀 [신규] 프리셋이 늘어나면 찾기 번거로워질 수 있어
                    // 이름 검색창을 추가했다(4개 이상일 때만 표시).
                    if (_customPresets.length > 3) ...[
                      TextField(
                        controller: _presetSearchCtrl,
                        onChanged: (v) =>
                            setState(() => _presetSearchQuery = v.trim()),
                        style: const TextStyle(fontSize: 13, color: tossText),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: "프리셋 이름 검색",
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: tossSubText,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: tossSubText,
                          ),
                          suffixIcon: _presetSearchQuery.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: tossSubText,
                                  ),
                                  onPressed: () {
                                    _presetSearchCtrl.clear();
                                    setState(() => _presetSearchQuery = '');
                                  },
                                ),
                          filled: true,
                          fillColor: tossBg,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Builder(
                      builder: (context) {
                        final List<ModulePreset> filtered =
                            _presetSearchQuery.isEmpty
                            ? _customPresets
                            : _customPresets
                                  .where(
                                    (p) => p.name.toLowerCase().contains(
                                      _presetSearchQuery.toLowerCase(),
                                    ),
                                  )
                                  .toList();
                        if (filtered.isEmpty) {
                          return const Text(
                            "검색 결과가 없습니다",
                            style: TextStyle(fontSize: 12, color: tossSubText),
                          );
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: filtered.map((preset) {
                            return GestureDetector(
                              onLongPress: () => _confirmDeleteCustomPreset(
                                _customPresets.indexOf(preset),
                              ),
                              child: Draggable<ModulePreset>(
                                data: preset,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Opacity(
                                    opacity: 0.8,
                                    child: _buildCustomPresetChip(preset),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: _buildCustomPresetChip(preset),
                                ),
                                child: _buildCustomPresetChip(preset),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomPresetChip(ModulePreset preset) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tossBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tossBlue.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: tossBlue),
          const SizedBox(width: 6),
          Text(
            preset.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: tossText,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            "${preset.width.toInt()}×${preset.height.toInt()}",
            style: const TextStyle(fontSize: 10, color: tossSubText),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCustomPreset(int index) {
    final preset = _customPresets[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "프리셋 삭제",
          style: TextStyle(color: tossText, fontWeight: FontWeight.bold),
        ),
        content: Text(
          keepWords("'${preset.name}' 프리셋을 삭제하시겠습니까?"),
          style: const TextStyle(color: tossSubText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: tossSubText)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteCustomPreset(index);
            },
            child: const Text(
              "삭제",
              style: TextStyle(color: warningRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuctChip(ModulePreset preset) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tossBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tossSubText.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.view_agenda_outlined, size: 14, color: tossText),
          const SizedBox(width: 6),
          Text(
            preset.width.toInt().toString(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: tossText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaletteItem(String defaultName) {
    // 🚀 [수정] width: double.infinity였는데, 사이드바 안에서는 부모
    // Column의 stretch 정렬로 어차피 꽉 차 보여서 문제없었지만, 이
    // 위젯을 Draggable의 feedback(드래그 중 화면에 떠다니는 복사본)으로
    // 쓰면 Overlay가 무한 폭 제약을 줘서 "BoxConstraints forces an
    // infinite width" 예외가 터지고 그 뒤로 레이아웃이 전부 깨져 드래그
    // 자체가 동작하지 않았다(실기기 로그로 확인). 고정 폭으로 바꾸면
    // 사이드바에서도(부모가 stretch라 그대로 꽉 차 보임) feedback으로
    // 써도 둘 다 문제없다.
    return Container(
      width: 208,
      height: 90,
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
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
            const Icon(Icons.add_box_rounded, color: tossBlue, size: 28),
            const SizedBox(height: 6),
            Text(
              defaultName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tossBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 [추가] 센터선/외곽선 토글에 따라 최대 2개(둘 다 켜면 동시에)의
  // 가이드선 페인터를 만들어준다.
  List<Widget> _buildGuidePaints(PlacedItem item) {
    return [
      if (_showCenterGuide)
        CustomPaint(
          size: Size.infinite,
          painter: SmartGuidePainter(
            item: item,
            allItems: _placedItems,
            panelWidth: _panelWidth,
            panelHeight: _panelHeight,
            currentType: DimensionType.center,
          ),
        ),
      if (_showEdgeGuide)
        CustomPaint(
          size: Size.infinite,
          painter: SmartGuidePainter(
            item: item,
            allItems: _placedItems,
            panelWidth: _panelWidth,
            panelHeight: _panelHeight,
            currentType: DimensionType.edge,
          ),
        ),
    ];
  }

  Widget _buildMainBoard() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: pureWhite,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SegmentedButton<BoardMode>(
                  segments: const [
                    ButtonSegment(
                      value: BoardMode.placeModule,
                      label: Text(
                        "모듈 배치/이동",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: Icon(Icons.pan_tool_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: BoardMode.measureDimension,
                      label: Text(
                        "고정 치수 측정",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: Icon(Icons.straighten_rounded, size: 16),
                    ),
                  ],
                  selected: {_mode},
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((
                      Set<WidgetState> states,
                    ) {
                      if (states.contains(WidgetState.selected))
                        return tossText;
                      return pureWhite;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((
                      Set<WidgetState> states,
                    ) {
                      if (states.contains(WidgetState.selected))
                        return pureWhite;
                      return tossText;
                    }),
                  ),
                  onSelectionChanged: (Set<BoardMode> newSelection) {
                    setState(() {
                      _mode = newSelection.first;
                      _dimensionStartPoint = null;
                      for (var i in _placedItems) i.isSelected = false;
                      _selectedItem = null;
                    });
                  },
                ),
                Container(
                  height: 32,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.grey.shade300,
                ),
                // 🚀 [수정] 가이드선 토글을 별도 그룹으로 시각적으로 묶어서
                // "모드 선택"과 구분되는 하나의 컨트롤 묶음으로 읽히게 함
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tossBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: tossSubText,
                        ),
                      ),
                      FilterChip(
                        label: const Text("센터선"),
                        selected: _showCenterGuide,
                        selectedColor: guideColor.withValues(alpha: 0.15),
                        checkmarkColor: guideColor,
                        backgroundColor: pureWhite,
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          color: _showCenterGuide ? guideColor : tossSubText,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) =>
                            setState(() => _showCenterGuide = val),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text("외곽선"),
                        selected: _showEdgeGuide,
                        selectedColor: edgeDimColor.withValues(alpha: 0.15),
                        checkmarkColor: edgeDimColor,
                        backgroundColor: pureWhite,
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          color: _showEdgeGuide ? edgeDimColor : tossSubText,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) =>
                            setState(() => _showEdgeGuide = val),
                      ),
                    ],
                  ),
                ),
                if (_mode == BoardMode.measureDimension &&
                    _dimensions.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () => setState(() => _dimensions.clear()),
                    icon: const Icon(
                      Icons.cleaning_services_rounded,
                      size: 16,
                      color: warningRed,
                    ),
                    label: const Text(
                      "치수 삭제",
                      style: TextStyle(
                        color: warningRed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // 도면 캔버스
        Expanded(
          // 🚀 실제 드래그 불가 원인은 팔레트 아이템의 width:double.infinity가
          // Draggable feedback으로 쓰일 때 무한 폭 제약 크래시를 일으킨
          // 것이었음(_buildPaletteItem에서 수정). 그 크래시가 원인이었으므로
          // InteractiveViewer(핀치줌)는 원래대로 되돌린다.
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 🚀 [신규] 미니맵에서 "지금 보고 있는 영역"을 계산하려면
              // 뷰포트의 실제 화면 크기가 필요하다.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _viewportSize != constraints.biggest) {
                  setState(() => _viewportSize = constraints.biggest);
                }
              });
              return InteractiveViewer(
                transformationController: _viewerController,
                minScale: 0.1,
                maxScale: 4.0,
                boundaryMargin: const EdgeInsets.all(2000),
                child: Center(
                  child: DragTarget<ModulePreset>(
                    onMove: (details) {
                      final RenderBox box =
                          _boardKey.currentContext!.findRenderObject()
                              as RenderBox;
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
                          _boardKey.currentContext!.findRenderObject()
                              as RenderBox;
                      _onAcceptItem(
                        details.data,
                        box.globalToLocal(details.offset),
                      );
                      setState(() => _previewItem = null);
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
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 30,
                                      offset: const Offset(10, 10),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    if (_backgroundImagePath != null &&
                                        File(
                                          _backgroundImagePath!,
                                        ).existsSync())
                                      Positioned.fill(
                                        child: Opacity(
                                          opacity: _backgroundOpacity,
                                          child: Image.file(
                                            File(_backgroundImagePath!),
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    CustomPaint(
                                      size: Size.infinite,
                                      painter: GridPainter(gridSize: _gridSize),
                                    ),

                                    CustomPaint(
                                      size: Size.infinite,
                                      painter: DimensionPainter(
                                        dimensions: _dimensions,
                                        activePoint: _dimensionStartPoint,
                                        version: _dimensionsVersion,
                                      ),
                                    ),
                                    if (_selectedItem != null &&
                                        _mode == BoardMode.placeModule)
                                      ..._buildGuidePaints(_selectedItem!),

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

                                    // 🚀 [복원] 안내선(모바일과 동일 -
                                    // 아래 Positioned에 key가 있으니 안전).
                                    if (_alignGuideX != null)
                                      Positioned(
                                        left: _alignGuideX,
                                        top: 0,
                                        bottom: 0,
                                        child: IgnorePointer(
                                          child: Container(
                                            width: 1.4,
                                            color: alignGuideColor,
                                          ),
                                        ),
                                      ),
                                    if (_alignGuideY != null)
                                      Positioned(
                                        top: _alignGuideY,
                                        left: 0,
                                        right: 0,
                                        child: IgnorePointer(
                                          child: Container(
                                            height: 1.4,
                                            color: alignGuideColor,
                                          ),
                                        ),
                                      ),

                                    ..._placedItems.map((item) {
                                      final bool canDrag =
                                          _mode == BoardMode.placeModule &&
                                          !item.isLocked;
                                      return Positioned(
                                        // 🚀 [버그 수정] key가 없으면 정렬
                                        // 안내선이 조건부로 Stack children에
                                        // 끼어들거나 빠질 때 목록 순서가
                                        // 밀리면서, 드래그 중이던 제스처가
                                        // 엉뚱한 모듈로 연결될 수 있었다
                                        // (모바일과 동일 버그, 같이 수정).
                                        // id 기반 key로 항상 같은 모듈에
                                        // 같은 엘리먼트가 매칭되게 고정한다.
                                        key: ValueKey(item.id),
                                        left: item.position.dx - _kTouchHitPad,
                                        top: item.position.dy - _kTouchHitPad,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onPanStart: canDrag
                                              ? (details) {
                                                  // 드래그 한 번 = undo 한 단계
                                                  final bool isGroupDrag =
                                                      _multiSelectMode &&
                                                      _multiSelectedIds
                                                          .contains(item.id) &&
                                                      _multiSelectedIds.length >
                                                          1;
                                                  _pushUndo();
                                                  setState(() {
                                                    _dragRawPosition =
                                                        item.position;
                                                    if (isGroupDrag) {
                                                      _groupDragAnchorOrigin =
                                                          item.position;
                                                      _groupDragOrigins = {
                                                        for (final i
                                                            in _placedItems)
                                                          if (_multiSelectedIds
                                                              .contains(i.id))
                                                            i.id: i.position,
                                                      };
                                                      double minX =
                                                          double.infinity;
                                                      double minY =
                                                          double.infinity;
                                                      double maxRight =
                                                          -double.infinity;
                                                      double maxBottom =
                                                          -double.infinity;
                                                      for (final i
                                                          in _placedItems) {
                                                        if (!_multiSelectedIds
                                                            .contains(i.id)) {
                                                          continue;
                                                        }
                                                        minX = math.min(
                                                          minX,
                                                          i.position.dx,
                                                        );
                                                        minY = math.min(
                                                          minY,
                                                          i.position.dy,
                                                        );
                                                        maxRight = math.max(
                                                          maxRight,
                                                          i.position.dx +
                                                              i.width,
                                                        );
                                                        maxBottom = math.max(
                                                          maxBottom,
                                                          i.position.dy +
                                                              i.height,
                                                        );
                                                      }
                                                      _groupOriginBounds =
                                                          Rect.fromLTRB(
                                                            minX,
                                                            minY,
                                                            maxRight,
                                                            maxBottom,
                                                          );
                                                    } else {
                                                      _groupDragAnchorOrigin =
                                                          null;
                                                      _groupDragOrigins = {};
                                                      _groupOriginBounds = null;
                                                      if (!_multiSelectMode) {
                                                        _selectedItem = item;
                                                        for (var i
                                                            in _placedItems) {
                                                          i.isSelected = false;
                                                        }
                                                        item.isSelected = true;
                                                      }
                                                    }
                                                  });
                                                }
                                              : null,
                                          onPanUpdate: canDrag
                                              ? (details) {
                                                  setState(() {
                                                    _dragRawPosition +=
                                                        details.delta;
                                                    final bool isGroupDrag =
                                                        _groupDragOrigins
                                                            .isNotEmpty &&
                                                        _groupDragOrigins
                                                            .containsKey(
                                                              item.id,
                                                            );
                                                    if (isGroupDrag) {
                                                      // 🚀 [버그 수정] 항목마다 따로 clamp하면
                                                      // 폭이 다른 모듈들이 겹쳐버렸다 - 그룹
                                                      // 바운딩 박스 기준으로 delta를 한 번만
                                                      // 잘라서 모두에게 같은 delta를 적용한다.
                                                      final Rect bounds =
                                                          _groupOriginBounds!;
                                                      final Offset rawDelta =
                                                          _dragRawPosition -
                                                          _groupDragAnchorOrigin!;
                                                      final double minDx =
                                                          -bounds.left;
                                                      double maxDx =
                                                          _panelWidth -
                                                          bounds.right;
                                                      if (maxDx < minDx) {
                                                        maxDx = minDx;
                                                      }
                                                      final double minDy =
                                                          -bounds.top;
                                                      double maxDy =
                                                          _panelHeight -
                                                          bounds.bottom;
                                                      if (maxDy < minDy) {
                                                        maxDy = minDy;
                                                      }
                                                      final Offset
                                                      clampedDelta = Offset(
                                                        rawDelta.dx.clamp(
                                                          minDx,
                                                          maxDx,
                                                        ),
                                                        rawDelta.dy.clamp(
                                                          minDy,
                                                          maxDy,
                                                        ),
                                                      );
                                                      final Offset
                                                      snappedDelta =
                                                          _snapToGrid(
                                                            clampedDelta,
                                                          );
                                                      // 🚀 [버그 수정] 그룹
                                                      // 전체를 이 delta만큼
                                                      // 옮겼을 때 선택 안 된
                                                      // 다른 모듈과 겹치면 이번
                                                      // 프레임 이동을 통째로
                                                      // 취소한다.
                                                      bool wouldCollide = false;
                                                      for (final entry
                                                          in _groupDragOrigins
                                                              .entries) {
                                                        final PlacedItem it =
                                                            _placedItems
                                                                .firstWhere(
                                                                  (x) =>
                                                                      x.id ==
                                                                      entry.key,
                                                                );
                                                        final Offset newPos =
                                                            entry.value +
                                                            snappedDelta;
                                                        if (_overlapsAny(
                                                          it,
                                                          newPos,
                                                          excludeIds:
                                                              _multiSelectedIds,
                                                        )) {
                                                          wouldCollide = true;
                                                          break;
                                                        }
                                                      }
                                                      if (wouldCollide) {
                                                        return;
                                                      }
                                                      for (final i
                                                          in _placedItems) {
                                                        if (!_multiSelectedIds
                                                                .contains(
                                                                  i.id,
                                                                ) ||
                                                            i.isLocked) {
                                                          continue;
                                                        }
                                                        final Offset? origin =
                                                            _groupDragOrigins[i
                                                                .id];
                                                        if (origin == null) {
                                                          continue;
                                                        }
                                                        i.position =
                                                            origin +
                                                            snappedDelta;
                                                      }
                                                    } else {
                                                      double clampedX =
                                                          _dragRawPosition.dx
                                                              .clamp(
                                                                0,
                                                                _panelWidth -
                                                                    item.width,
                                                              );
                                                      double clampedY =
                                                          _dragRawPosition.dy
                                                              .clamp(
                                                                0,
                                                                _panelHeight -
                                                                    item.height,
                                                              );
                                                      final gridSnapped =
                                                          _snapToGrid(
                                                            Offset(
                                                              clampedX,
                                                              clampedY,
                                                            ),
                                                          );
                                                      // 🚀 [복원] 안내선
                                                      // 계산만 하고(위치는
                                                      // 안 바꿈), 겹치는
                                                      // 자리로는 이동을
                                                      // 막되 X/Y를 각각
                                                      // 따로 검사해서
                                                      // 한쪽이 막혀도 다른
                                                      // 쪽으로는 벽을 따라
                                                      // 미끄러지듯 움직이게
                                                      // 한다.
                                                      final aligned =
                                                          _snapToAlignment(
                                                            item,
                                                            gridSnapped,
                                                          );
                                                      final Offset xOnly =
                                                          Offset(
                                                            aligned.dx,
                                                            item.position.dy,
                                                          );
                                                      if (!_overlapsAny(
                                                        item,
                                                        xOnly,
                                                      )) {
                                                        item.position = xOnly;
                                                      }
                                                      final Offset yOnly =
                                                          Offset(
                                                            item.position.dx,
                                                            aligned.dy,
                                                          );
                                                      if (!_overlapsAny(
                                                        item,
                                                        yOnly,
                                                      )) {
                                                        item.position = yOnly;
                                                      }
                                                    }
                                                  });
                                                }
                                              : null,
                                          onPanEnd: canDrag
                                              ? (details) {
                                                  setState(() {
                                                    _alignGuideX = null;
                                                    _alignGuideY = null;
                                                    _groupDragAnchorOrigin =
                                                        null;
                                                    _groupDragOrigins = {};
                                                    _groupOriginBounds = null;
                                                  });
                                                }
                                              : null,
                                          onTap: () => _onTapItem(item),
                                          child: Container(
                                            width:
                                                item.width + _kTouchHitPad * 2,
                                            height:
                                                item.height + _kTouchHitPad * 2,
                                            color: Colors.transparent,
                                            padding: const EdgeInsets.all(
                                              _kTouchHitPad,
                                            ),
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                _buildBoardItem(item),
                                                if (item.isLocked)
                                                  Positioned(
                                                    right: -2,
                                                    top: -2,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            3,
                                                          ),
                                                      decoration:
                                                          const BoxDecoration(
                                                            color: tossText,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                      child: const Icon(
                                                        Icons.lock_rounded,
                                                        size: 10,
                                                        color: pureWhite,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                    // 🚀 [신규] 완전히 빈 도면일 때 샘플 배치를
                                    // 눌러보게 안내한다(모바일과 동일).
                                    if (_placedItems.isEmpty &&
                                        _dimensions.isEmpty &&
                                        !_isLoadingProject)
                                      Positioned.fill(
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons
                                                    .dashboard_customize_outlined,
                                                size: 36,
                                                color: tossSubText.withValues(
                                                  alpha: 0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                keepWords(
                                                  "왼쪽에서 모듈을 끌어다\n놓아 배치를 시작하십시오",
                                                ),
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: tossSubText.withValues(
                                                    alpha: 0.7,
                                                  ),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.4,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              OutlinedButton.icon(
                                                onPressed: _loadSampleLayout,
                                                icon: const Icon(
                                                  Icons.auto_awesome_rounded,
                                                  size: 16,
                                                  color: tossBlue,
                                                ),
                                                label: const Text(
                                                  "샘플 배치 불러보기",
                                                  style: TextStyle(
                                                    color: tossBlue,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(
                                                    color: tossBlue,
                                                  ),
                                                  backgroundColor: pureWhite,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBoardItem(PlacedItem item) {
    bool isMeasuringStart =
        _mode == BoardMode.measureDimension &&
        _dimensionStartPoint?.id == item.id;

    return Container(
      width: item.width,
      height: item.height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isMeasuringStart ? tossBlue.withValues(alpha: 0.1) : pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMeasuringStart
              ? tossBlue
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
            color: isMeasuringStart || item.isSelected ? tossBlue : tossText,
            height: 1.2,
            letterSpacing: -0.3,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildRightInspector() {
    return Container(
      width: 320,
      color: pureWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: tossBg.withValues(alpha: 0.5),
            child: const Text(
              "정밀 제어 패널",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: tossText,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _mode == BoardMode.measureDimension
                  ? _buildDimensionInspector()
                  : _selectedItem == null
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Text(
                          keepWords("도면에서 모듈을 선택하면\n상세 수치를 조절할 수 있습니다."),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: tossSubText, height: 1.5),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "모듈 명칭 (라벨)",
                          style: TextStyle(
                            color: tossSubText,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller:
                              TextEditingController(text: _selectedItem!.name)
                                ..selection = TextSelection.collapsed(
                                  offset: _selectedItem!.name.length,
                                ),
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
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) => setState(
                            () => _selectedItem!.name = val.isEmpty
                                ? "이름 없음"
                                : val,
                          ),
                        ),
                        const SizedBox(height: 28),

                        const Text(
                          "모듈 크기 (W x H)",
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
                              child: _buildInspectorInput(
                                "가로 (mm)",
                                _selectedItem!.width.toInt().toString(),
                                (val) {
                                  setState(() {
                                    _selectedItem!.width =
                                        (double.tryParse(val) ?? 80.0);
                                    _selectedItem!.position = Offset(
                                      _selectedItem!.position.dx.clamp(
                                        0.0,
                                        math.max(
                                          0.0,
                                          _panelWidth - _selectedItem!.width,
                                        ),
                                      ),
                                      _selectedItem!.position.dy,
                                    );
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildInspectorInput(
                                "세로 (mm)",
                                _selectedItem!.height.toInt().toString(),
                                (val) {
                                  setState(() {
                                    _selectedItem!.height =
                                        (double.tryParse(val) ?? 80.0);
                                    _selectedItem!.position = Offset(
                                      _selectedItem!.position.dx,
                                      _selectedItem!.position.dy.clamp(
                                        0.0,
                                        math.max(
                                          0.0,
                                          _panelHeight - _selectedItem!.height,
                                        ),
                                      ),
                                    );
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),
                        const Text(
                          "절대 위치 (X, Y)",
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
                              child: _buildInspectorInput(
                                "X (mm)",
                                _selectedItem!.position.dx.toInt().toString(),
                                (val) {
                                  setState(() {
                                    double newX = double.tryParse(val) ?? 0;
                                    _selectedItem!.position = Offset(
                                      newX.clamp(
                                        0.0,
                                        math.max(
                                          0.0,
                                          _panelWidth - _selectedItem!.width,
                                        ),
                                      ),
                                      _selectedItem!.position.dy,
                                    );
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildInspectorInput(
                                "Y (mm)",
                                _selectedItem!.position.dy.toInt().toString(),
                                (val) {
                                  setState(() {
                                    double newY = double.tryParse(val) ?? 0;
                                    _selectedItem!.position = Offset(
                                      _selectedItem!.position.dx,
                                      newY.clamp(
                                        0.0,
                                        math.max(
                                          0.0,
                                          _panelHeight - _selectedItem!.height,
                                        ),
                                      ),
                                    );
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        // 🚀 [신규] 지금 이 모듈의 이름/크기를 "내
                        // 프리셋"으로 저장 - 다음 도면에서 사이드바에서
                        // 바로 드래그해 쓸 수 있다.
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              _saveAsCustomPreset(
                                _selectedItem!.name,
                                _selectedItem!.width,
                                _selectedItem!.height,
                              );
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(keepWords("내 프리셋에 저장했습니다.")),
                                  backgroundColor: tossText,
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.star_border_rounded,
                              size: 18,
                              color: tossBlue,
                            ),
                            label: const Text(
                              "이 크기를 내 프리셋으로 저장",
                              style: TextStyle(
                                color: tossBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                        // 🚀 [신규] 위치가 확정된 모듈을 잠가서 실수로
                        // 드래그해 옮겨지지 않게 한다.
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              setState(
                                () => _selectedItem!.isLocked =
                                    !_selectedItem!.isLocked,
                              );
                              HapticFeedback.lightImpact();
                            },
                            icon: Icon(
                              _selectedItem!.isLocked
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              size: 18,
                              color: _selectedItem!.isLocked
                                  ? warningRed
                                  : tossSubText,
                            ),
                            label: Text(
                              _selectedItem!.isLocked ? "잠금 해제" : "이 모듈 위치 잠그기",
                              style: TextStyle(
                                color: _selectedItem!.isLocked
                                    ? warningRed
                                    : tossSubText,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        // 🚀 [신규] 레이어 순서(앞/뒤) 조정 - 리스트 맨 뒤에
                        // 있을수록 화면 맨 위에 그려진다.
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final item = _selectedItem!;
                                  _pushUndo();
                                  setState(() {
                                    _placedItems.remove(item);
                                    _placedItems.add(item);
                                  });
                                  HapticFeedback.lightImpact();
                                },
                                icon: const Icon(
                                  Icons.flip_to_front_rounded,
                                  size: 18,
                                  color: tossText,
                                ),
                                label: const Text(
                                  "맨 앞으로",
                                  style: TextStyle(
                                    color: tossText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: tossText.withValues(alpha: 0.2),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final item = _selectedItem!;
                                  _pushUndo();
                                  setState(() {
                                    _placedItems.remove(item);
                                    _placedItems.insert(0, item);
                                  });
                                  HapticFeedback.lightImpact();
                                },
                                icon: const Icon(
                                  Icons.flip_to_back_rounded,
                                  size: 18,
                                  color: tossText,
                                ),
                                label: const Text(
                                  "맨 뒤로",
                                  style: TextStyle(
                                    color: tossText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: tossText.withValues(alpha: 0.2),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _pushUndo();
                              setState(() {
                                _dimensions.removeWhere(
                                  (dim) =>
                                      dim.p1.id == _selectedItem!.id ||
                                      dim.p2.id == _selectedItem!.id,
                                );
                                _placedItems.remove(_selectedItem);
                                if (_dimensionStartPoint?.id ==
                                    _selectedItem!.id)
                                  _dimensionStartPoint = null;
                                _selectedItem = null;
                              });
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: warningRed,
                            ),
                            label: const Text(
                              "모듈 삭제",
                              style: TextStyle(
                                color: warningRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: warningRed,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
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

  // 🚀 [추가] 고정 치수 측정 컨트롤(우측 패널) - 모바일과 동일하게
  // 센터/측면 기준을 전환할 수 있다.
  Widget _buildDimensionInspector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "측정 기준",
          style: TextStyle(
            color: tossText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text("센터(중심) 기준"),
              selected: _currentDimType == DimensionType.center,
              selectedColor: centerDimColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: _currentDimType == DimensionType.center
                    ? centerDimColor
                    : tossSubText,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (val) {
                setState(() => _currentDimType = DimensionType.center);
              },
            ),
            ChoiceChip(
              label: const Text("측면(여백) 기준"),
              selected: _currentDimType == DimensionType.edge,
              selectedColor: edgeDimColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: _currentDimType == DimensionType.edge
                    ? edgeDimColor
                    : tossSubText,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (val) {
                setState(() => _currentDimType = DimensionType.edge);
              },
            ),
            // 🚀 [신규] 체인 모드 - 켜면 점을 계속 이어서 탭하는 것만으로
            // 연속된 치수선을 만들 수 있다(모바일과 동일).
            ChoiceChip(
              label: const Text("체인 모드"),
              avatar: Icon(
                Icons.link_rounded,
                size: 16,
                color: _dimensionChainMode ? tossBlue : tossSubText,
              ),
              selected: _dimensionChainMode,
              selectedColor: tossBlue.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: _dimensionChainMode ? tossBlue : tossSubText,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (val) {
                setState(() => _dimensionChainMode = val);
              },
            ),
            // 🚀 [신규] 대각선 모드 - 켜면 축 정렬 없이 실제 직선거리+
            // 각도를 측정한다(모바일과 동일).
            ChoiceChip(
              label: const Text("대각선 모드"),
              avatar: Icon(
                Icons.turn_slight_right_rounded,
                size: 16,
                color: _dimensionDiagonalMode ? diagonalDimColor : tossSubText,
              ),
              selected: _dimensionDiagonalMode,
              selectedColor: diagonalDimColor.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: _dimensionDiagonalMode ? diagonalDimColor : tossSubText,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (val) {
                setState(() => _dimensionDiagonalMode = val);
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          _dimensionStartPoint != null
              ? "💡 다음 측정 지점을 탭하면 치수선이 연결됩니다."
              : _dimensionChainMode
              ? "💡 체인 모드: 지점을 계속 탭하면 이어서 측정됩니다."
              : _dimensions.isNotEmpty
              ? "💡 치수선을 탭하면 삭제/기준 전환/메모/최소 간격을 설정할 수 있습니다."
              : "💡 측정할 두 지점(모듈 or 벽면)을 순서대로 도면에서 탭하십시오.",
          style: TextStyle(
            color: _dimensionStartPoint == null
                ? tossSubText
                : (_currentDimType == DimensionType.center
                      ? centerDimColor
                      : edgeDimColor),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _currentDimType == DimensionType.center
              ? "⚠️ 현재 '센터(중앙점)' 간의 거리를 측정 중입니다."
              : "⚠️ 현재 박스 '끝단(측면/여백)' 간의 거리를 측정 중입니다.",
          style: TextStyle(
            color: _currentDimType == DimensionType.center
                ? centerDimColor
                : edgeDimColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        // 🚀 [추가] 첫 지점을 잘못 찍었을 때 두 번째 지점을 억지로 찍어
        // 엉뚱한 치수를 만들지 않고도 취소할 수 있는 버튼.
        if (_dimensionStartPoint != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _dimensionStartPoint = null;
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              foregroundColor: tossSubText,
            ),
            icon: const Icon(Icons.undo_rounded, size: 16),
            label: const Text(
              "첫 지점 취소",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        if (_dimensions.isNotEmpty) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              const Text(
                "배치된 치수선",
                style: TextStyle(
                  color: tossText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  _pushUndo();
                  setState(() => _dimensions.clear());
                },
                child: const Text(
                  "전체 삭제",
                  style: TextStyle(
                    color: warningRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInspectorInput(
    String label,
    String value,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: tossSubText,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: TextEditingController(text: value)
            ..selection = TextSelection.collapsed(offset: value.length),
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
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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
  String prefix, {
  double strokeWidth = 1.3,
}) {
  if (distance < 1) return; // 사실상 붙어있으면 표시할 게 없음

  final linePaint = Paint()
    ..color = color
    ..strokeWidth = strokeWidth
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
  canvas.drawLine(
    mid,
    label,
    Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1,
  );
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

// 🚀 [수정] 모바일과 동일하게 센터/측면 기준을 전환할 수 있도록 확장
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
    Color c = currentType == DimensionType.center ? guideColor : edgeDimColor;
    String p = currentType == DimensionType.center ? "센터" : "측면";

    double left = item.position.dx;
    double right = item.position.dx + item.width;
    double top = item.position.dy;
    double bottom = item.position.dy + item.height;
    double cx = item.center.dx;
    double cy = item.center.dy;

    double bL = 0, bR = panelWidth, bT = 0, bB = panelHeight;

    for (var other in allItems) {
      if (other.id == item.id) continue;
      double oLeft = other.position.dx;
      double oRight = other.position.dx + other.width;
      double oTop = other.position.dy;
      double oBottom = other.position.dy + other.height;

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

// 🚀 [핵심] 실제 엔지니어링 모눈종이처럼 렌더링 (5mm 얇게, 25mm 굵게)
class GridPainter extends CustomPainter {
  final double gridSize;
  GridPainter({required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    // 5mm 마다 그려질 얇은 선
    final lightPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.5;
    // 25mm (5칸) 마다 그려질 굵은 선
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

// 🚀 [수정] 모바일과 동일하게 센터/측면 두 기준의 치수선을 지원
class DimensionPainter extends CustomPainter {
  final List<PlacedDimension> dimensions;
  final MeasurePoint? activePoint;
  // 🚀 [신규] dimensions 리스트는 같은 객체를 그 자리에서 바꿔쓰기
  // 때문에(add/remove 제외) 기준/메모/최소 간격만 바뀌었을 땐 길이
  // 비교로 감지가 안 된다. 그런 변경마다 이 값을 올려서 다시 그려지게
  // 한다(모바일과 동일 이유).
  final int version;

  DimensionPainter({
    required this.dimensions,
    this.activePoint,
    this.version = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < dimensions.length; i++) {
      final dim = dimensions[i];
      final endpoints = computeDimensionEndpoints(dim);

      Color dColor = dim.type == DimensionType.center
          ? centerDimColor
          : edgeDimColor;
      String labelPrefix = dim.type == DimensionType.center ? "센터" : "측면";

      // 🚀 [신규] 대각선 모드면 실제 각도를 라벨에 표시한다.
      if (dim.isDiagonal) {
        dColor = diagonalDimColor;
        final double angleDeg =
            math.atan2(
              endpoints.p2.dy - endpoints.p1.dy,
              endpoints.p2.dx - endpoints.p1.dx,
            ) *
            180 /
            math.pi;
        final double normalized = angleDeg < 0 ? angleDeg + 360 : angleDeg;
        labelPrefix = "대각 ${normalized.toInt()}°";
      }

      // 🚀 [신규] 안전 이격거리 등 규정과 관련된 치수는 방패 아이콘으로
      // 구분되게 한다.
      if (dim.isSafetyCritical) {
        labelPrefix = "🛡 $labelPrefix";
      }

      // 🚀 [신규] 최소 유지 간격보다 현재 거리가 좁아지면 경고색으로.
      final bool violatesMinGap =
          dim.minGapMm != null && endpoints.distance < dim.minGapMm!;
      if (violatesMinGap) {
        dColor = warningRed;
        labelPrefix = "⚠ 최소 ${dim.minGapMm!.toInt()}mm 미달";
      }

      drawCadDimensionLine(
        canvas,
        endpoints.p1,
        endpoints.p2,
        endpoints.distance,
        dColor,
        labelPrefix,
        strokeWidth: dim.isSafetyCritical ? 2.4 : 1.3,
      );

      // 🚀 [신규] 치수선마다 번호 배지를 단다.
      final Offset badgeCenter = endpoints.p1;
      canvas.drawCircle(badgeCenter, 8, Paint()..color = dColor);
      final numberSpan = TextSpan(
        text: "${i + 1}",
        style: const TextStyle(
          color: pureWhite,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      );
      final numberPainter = TextPainter(
        text: numberSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      numberPainter.paint(
        canvas,
        Offset(
          badgeCenter.dx - numberPainter.width / 2,
          badgeCenter.dy - numberPainter.height / 2,
        ),
      );

      // 🚀 [신규] 메모가 있으면 선 아래쪽에 작게 표시.
      if (dim.note != null && dim.note!.trim().isNotEmpty) {
        final Offset mid = Offset(
          (endpoints.p1.dx + endpoints.p2.dx) / 2,
          (endpoints.p1.dy + endpoints.p2.dy) / 2,
        );
        final noteSpan = TextSpan(
          text: dim.note,
          style: const TextStyle(
            color: tossSubText,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
          ),
        );
        final notePainter = TextPainter(
          text: noteSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        notePainter.paint(
          canvas,
          Offset(mid.dx - notePainter.width / 2, mid.dy + 12),
        );
      }
    }

    // 🚀 [개선] 벽 기준점일 때만 대기 표시를 그려서 모듈을 첫 지점으로
    // 찍었을 땐 측정 대기 중이란 표시가 없었다. 종류 상관없이 표시.
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

  // 🚀 [최적화] 무조건 true였던 탓에 모듈 드래그로 setState가 프레임마다
  // 호출될 때 치수선과 무관하게 이 레이어 전체가 매번 다시 그려졌음
  // (버벅임의 실제 원인). dimensions는 같은 List를 in-place로 add/remove
  // 하므로 참조 비교 대신 길이로, activePoint는 항상 재할당되므로 값
  // 비교로 실제 변경 여부를 판단한다.
  @override
  bool shouldRepaint(covariant DimensionPainter oldDelegate) {
    return oldDelegate.dimensions.length != dimensions.length ||
        oldDelegate.activePoint != activePoint ||
        oldDelegate.version != version;
  }
}
