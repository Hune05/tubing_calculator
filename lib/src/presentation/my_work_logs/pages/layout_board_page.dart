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
// ignore: deprecated_member_use
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/image_picker_helper.dart' show ImagePickerHelper;

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
// 🚀 [신규] 대각선 치수 색상 - 센터/측면과 확실히 구분되는 보라색.
const Color diagonalDimColor = Color(0xFF8B5CF6);
// 🚀 [복원] 정렬 안내선 - 거리 표시용 CAD 치수선(파란/주황)과 확실히
// 구분되는 마젠타 색. 예전엔 위치를 강제로 스냅시키는 "자석" 동작
// 때문에 문제가 있었지만, 그건 이미 없앴고(안내만 표시, 위치는 항상
// 손가락/그리드 스냅 그대로), 실제 "다른 모듈이 움직이던" 근본
// 원인은 모듈 위젯에 key가 없어 생긴 별개의 버그였다(고쳤음). 이제
// 안내선만 다시 켠다.
const Color alignGuideColor = Color(0xFFFF3D9A);

// 🚀 [버그 수정] 작은 모듈을 잡기 쉽게 하려고 터치 영역을 시각적
// 크기보다 넓혔었는데, 모듈끼리 붙여놓는 게 정상적인 사용 방식이라
// 보이지 않는 여유 영역끼리 자주 겹쳤다. 그러면 화면에 보이는 모듈을
// 잡으려 해도 실제로는 겹친 여유 영역을 가진 "다른" 모듈이 반응해서
// 엉뚱한 모듈이 따라 붙는 것처럼 보이는 문제가 있었다. 정확한 판정을
// 위해 여유 영역을 없앴다.
const double _kTouchHitPad = 0.0;

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
  // 🚀 [신규] 위치가 확정된 모듈을 잠가서 드래그해도 실수로 옮겨지지
  // 않게 하는 기능.
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
// 복원한다. item 쪽은 저장 당시 좌표를 담은 별개의 PlacedItem이라, 불러온
// 뒤 실제 모듈을 옮겨도 이미 찍힌 치수선은 저장 시점 위치에 고정된다.
MeasurePoint _measurePointFromJson(Map<String, dynamic> j) {
  return j['type'] == 'wall' ? WallPoint.fromJson(j) : PlacedItem.fromJson(j);
}

class PlacedDimension {
  final String id;
  final MeasurePoint p1;
  final MeasurePoint p2;
  // 🚀 [수정] 기존 치수의 기준(센터/측면)을 그 자리에서 바꿀 수 있도록
  // final을 뗐다.
  DimensionType type;
  // 🚀 [신규] 이 치수선에 대한 짧은 메모(예: "케이블 트레이 통과 구간").
  String? note;
  // 🚀 [신규] 최소 유지 간격(mm). 설정해두면 실제 거리가 이 값보다
  // 좁아지는 순간 치수선이 경고색으로 바뀐다(전기 패널 이격거리 확인용).
  double? minGapMm;
  // 🚀 [신규] 대각선 모드 - 켜면 축(가로/세로)에 맞춰 정렬하지 않고
  // 두 중심점을 직선으로 그대로 잇는 실제 직선거리+각도를 측정한다.
  bool isDiagonal;
  // 🚀 [신규] 안전 이격거리처럼 규정과 관련된 중요한 치수선을 표시해
  // 두께/아이콘으로 다른 치수와 구분되게 한다.
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

// 🚀 [정리] 손으로 앵커를 옮기는 기능은 폰에서 쓰기 부담스럽다는 판단으로
// 제거하고, 센터/측면 자동 계산만 남겼다.
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
// 2. 메인 페이지 화면
// ---------------------------------------------------------
class MobileLayoutBoardPage extends StatefulWidget {
  final String? projectId;
  // 🚀 [신규] 작업 일지 작성 화면에서 진입했을 때 true로 넘어온다. 이 경우
  // 저장 시트에 "완성된 배치도를 일지 사진으로 추가" 버튼이 나타나고,
  // 캡처한 사진 경로를 화면을 닫을 때 결과값으로 돌려준다.
  final bool attachToReport;

  const MobileLayoutBoardPage({
    super.key,
    this.projectId,
    this.attachToReport = false,
  });

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
  // 🚀 [신규] 체인 모드 - 켜두면 점을 찍을 때마다 그 점이 다음 구간의
  // 시작점으로 그대로 이어져서, 여러 지점을 순서대로 탭하는 것만으로
  // 연속된 치수선을 한 번에 그릴 수 있다(모듈을 일렬로 배치할 때 유용).
  bool _dimensionChainMode = false;
  // 🚀 [신규] 대각선 모드 - 켜두면 새로 만드는 치수가 축 정렬 없이
  // 두 중심점을 직선으로 그대로 잇는다(실제 대각선 거리+각도).
  bool _dimensionDiagonalMode = false;
  // 🚀 [신규] 치수의 기준/메모/최소 간격을 바꿨을 때 DimensionPainter가
  // 확실히 다시 그려지도록 하는 버전 카운터 (자세한 이유는
  // DimensionPainter의 주석 참고).
  int _dimensionsVersion = 0;
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

  // 🚀 [복원] 모듈을 드래그하는 동안 다른 모듈과 좌/우/중앙(또는
  // 상/하/중앙)이 맞아떨어지면 안내선을 그어준다(위치를 강제로 옮기지는
  // 않음). null이면 표시 안 함.
  double? _alignGuideX;
  double? _alignGuideY;

  // 🚀 [신규] 실제 도면 사진(캐드 출력물, 손그림 등)을 배경으로 깔아두고
  // 그 위에 모듈/치수를 배치할 수 있는 기능. 불투명도를 낮춰서 배경
  // 사진과 겹쳐도 모듈이 잘 보이게 한다.
  String? _backgroundImagePath;
  double _backgroundOpacity = 0.5;

  // 🚀 [신규] 다중 선택 - 켜져 있는 동안 모듈을 탭하면 편집창 대신
  // 선택 목록에 추가/제거된다. 2개 이상 선택하면 하단 도구모음에서
  // 그룹 이동/복제/잠금/정렬/삭제를 한 번에 할 수 있다.
  bool _multiSelectMode = false;
  Set<String> _multiSelectedIds = {};
  Offset? _groupDragAnchorOrigin;
  Map<String, Offset> _groupDragOrigins = {};
  // 🚀 [버그 수정] 그룹 드래그 중 항목마다 따로 도면 경계에 clamp를
  // 걸면, 폭이 서로 다른 모듈들이 경계에 닿는 시점이 제각각이라 어떤
  // 모듈은 먼저 멈추고 다른 모듈은 계속 움직여서 서로 겹쳐버렸다.
  // 이제 그룹 전체의 바운딩 박스 기준으로 딱 한 번만 delta를 clamp해서
  // 선택된 모듈들 사이의 상대 위치가 항상 그대로 유지되게 한다.
  Rect? _groupOriginBounds;

  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _captureKey = GlobalKey();

  // 🚀 [신규] 미니맵 - 확대해서 작업할 때 지금 전체 도면 중 어디를 보고
  // 있는지 놓치기 쉬워서, 구석에 작은 축소 지도로 현재 보는 영역을
  // 표시한다. InteractiveViewer의 변환행렬(확대/이동)을 추적해야 해서
  // 컨트롤러를 직접 연결해둔다.
  final TransformationController _viewerController = TransformationController();
  Size? _viewportSize;

  // 🚀 [추가] 서버에 정식 저장하기 전에 앱을 껐다 켜거나 화면을 나가면
  // 작업 중이던 배치가 전부 사라지던 문제(휘발성)를 막기 위한 로컬
  // 임시 저장. 주기적으로 + 앱이 백그라운드로 갈 때 기기에만 저장해두고,
  // 정식으로 서버 저장을 하면 더 이상 필요 없으니 지운다.
  static const String _draftPrefsKey = 'layout_board_draft_v1';
  Timer? _draftTimer;

  // 🚀 [신규] 자주 쓰는 모듈 크기(예: 특정 차단기 규격)를 이름 붙여
  // 저장해두고 다음 도면에서 바로 드래그해 쓸 수 있는 프리셋 라이브러리.
  // 기기 단위로 저장(SharedPreferences)해서 모바일/태블릿 화면 모두,
  // 어떤 프로젝트를 열든 항상 같은 목록을 쓴다.
  static const String _customPresetsPrefsKey = 'layout_board_custom_presets';
  List<ModulePreset> _customPresets = [];
  // 🚀 [신규] 프리셋이 많아지면 원하는 걸 찾기 번거로워질 수 있어 이름
  // 검색으로 바로 필터링할 수 있게 했다.
  final TextEditingController _presetSearchCtrl = TextEditingController();
  String _presetSearchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCustomPresets();
    // 🚀 확대/이동할 때마다 미니맵의 "현재 보는 영역" 표시가 따라
    // 움직이도록 다시 그려준다.
    _viewerController.addListener(() {
      if (mounted) setState(() {});
    });
    if (widget.projectId != null) {
      _loadProject(widget.projectId!);
    } else {
      // 🚀 [신규] 새 도면을 열 때만(불러온 프로젝트가 아닐 때) 처음
      // 한 번 사용법을 간단히 안내한다 - 이어할 임시 저장 확인이 먼저
      // 끝난 뒤에 보여줘서 다이얼로그가 겹치지 않게 한다.
      _checkAndOfferDraftRecovery().then((_) => _maybeShowOnboarding());
    }
    _draftTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _saveDraftToPrefs(),
    );
  }

  // 🚀 [신규] 처음 배치도 화면을 여는 사람은 빈 캔버스만 보고 어떻게
  // 시작해야 할지 막막할 수 있어, 기기당 딱 한 번만 짧은 사용법 안내를
  // 보여준다("다시 보지 않음" 없이 한 번 확인하면 계속 안 뜬다).
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                keepWords("① 아래 팔레트에서 모듈을 도면 위로 끌어다 놓습니다."),
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

  // 🚀 [신규] 완전히 빈 도면을 처음 여는 사람이 기능을 눌러보며 익힐 수
  // 있도록, 간단한 예시 배치를 한 번에 불러오는 버튼용 데이터.
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

  // 🚀 [신규] 실행 취소/다시 실행. 모듈 배치/이동/삭제/회전/치수 추가·
  // 삭제 등 "한 번의 사용자 조작" 직전마다 현재 상태를 스냅샷으로
  // 쌓아두고, 되돌릴 땐 그 스냅샷으로 복원한다. items/dimensions만
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
    _activeItem = null;
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

  // 🚀 [신규] 히스토리 목록에서 특정 단계를 눌렀을 때 - 그 지점까지
  // 한 번에 여러 단계를 되돌린다(_undo()를 stepsBack번 반복하는 것과
  // 동일하되, 화면 리렌더는 한 번만 일어나게 묶었다).
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    keepWords("실행 취소 히스토리 (${_undoStack.length}단계)"),
                    style: const TextStyle(
                      color: tossText,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _undoStack.length,
                    itemBuilder: (context, i) {
                      // 최근 단계가 위로 오도록 뒤에서부터 보여준다.
                      final int stepsBack = i + 1;
                      return ListTile(
                        leading: const Icon(
                          Icons.history_rounded,
                          color: tossBlue,
                        ),
                        title: Text(
                          "$stepsBack단계 전으로 이동",
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

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
          (e) => PlacedDimension.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    _backgroundImagePath = data['backgroundImagePath'] as String?;
    _backgroundOpacity = (data['backgroundOpacity'] as num?)?.toDouble() ?? 0.5;
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

  Offset _snapToGrid(Offset offset) {
    double dx = (offset.dx / _gridSize).round() * _gridSize;
    double dy = (offset.dy / _gridSize).round() * _gridSize;
    return Offset(dx, dy);
  }

  // 🚀 [복원] 드래그 중인 모듈의 좌/중앙/우(또는 상/중앙/하)가 다른
  // 모듈의 같은 기준선에 근접하면 안내선을 그어준다. 위치를 강제로
  // 옮기지는 않는다(그냥 눈에 보이는 힌트) - 실제로 "다른 모듈이
  // 움직이던" 문제는 이 안내선 때문이 아니라 모듈 위젯에 key가 없어
  // 생긴 별개의 버그였고, 이미 고쳤다(각 모듈의 Positioned에
  // ValueKey(item.id) 부여).
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
  // 위에 완전히 겹쳐 놓을 수 있었다(패널 모듈은 실제 물건이라 서로
  // 같은 자리를 차지할 수 없어야 한다). 후보 위치가 다른 모듈과
  // 겹치는지 검사해서, 겹치면 그 위치로는 이동을 아예 허용하지 않는다.
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

  // 🚀 [신규] 작업 일지 작성 화면에서 이 도구를 열었을 때, 완성된 배치도를
  // PNG로 캡처해서 그 파일 경로를 결과값으로 들고 화면을 닫는다 - 일지
  // 쪽에서는 이 경로를 "현장 사진 첨부" 목록에 그대로 추가하면 된다.
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

  pw.Widget _pdfCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // 🚀 [신규] 최소 유지 간격을 설정해둔 치수 중, 저장/공유하는 지금
  // 시점에도 여전히 기준을 못 만족하는 것들을 모아서 알려준다.
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

  // 🚀 위반 항목이 있으면 저장/공유 전에 한 번 더 확인시킨다. 위반이
  // 없으면 바로 true(계속 진행), 사용자가 "취소"를 누르면 false.
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

  // 🚀 [신규] 서버에 저장하기 직전, 이미 저장된 적 있는 프로젝트라면
  // 마지막으로 저장된 버전과 비교해서 뭐가 옮겨지고 추가/삭제됐는지
  // 보여주고 확인시킨다. 처음 저장하는 새 프로젝트는 비교 대상이
  // 없으니 그냥 통과시킨다.
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
        return true; // 변경 사항 없음
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
            width: 320,
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
      return true; // 비교 실패 시 저장 자체는 막지 않는다.
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

  Future<void> _shareAsPdf(String projectName) async {
    setState(() => _isSaving = true);
    try {
      // 🚀 [버그 수정] QR에 실제 존재하지 않는 이름+시간 조합 문자열을
      // 넣어서, 스캔해도 절대 못 찾는 죽은 링크였다. QR로 다시 이 도면을
      // 열 수 있으려면 서버에 저장된 실제 프로젝트여야 하므로, 아직
      // 저장 전이면 먼저 저장해서 진짜 문서 ID를 확보한다.
      if (_currentProjectId == null) {
        await _saveToFirebase(projectName);
        if (_currentProjectId == null) {
          throw Exception("프로젝트 저장에 실패해 QR을 만들 수 없습니다");
        }
      }
      if (!mounted) return;
      setState(() => _isSaving = true);

      final imageBytes = await _capturePng();
      if (imageBytes == null) throw Exception("도면 캡처 실패");

      final pdf = pw.Document();
      final image = pw.MemoryImage(imageBytes);
      String qrData = "tubingcalc://layout?project=$_currentProjectId";

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

      // 🚀 [신규] 치수선이 있으면 도면 사진 뒤에 번호별 치수 목록표를
      // 추가 페이지로 붙여서, 도면이 복잡해도 사진 속 번호 배지와
      // 대조해가며 확인할 수 있게 한다.
      if (_dimensions.isNotEmpty) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    keepWords("치수 목록표 (Dimension Schedule)"),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColors.grey400,
                      width: 0.5,
                    ),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(40),
                      1: const pw.FixedColumnWidth(70),
                      2: const pw.FixedColumnWidth(80),
                      3: const pw.FlexColumnWidth(),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey200,
                        ),
                        children: [
                          _pdfCell("번호", bold: true),
                          _pdfCell("기준", bold: true),
                          _pdfCell("거리(mm)", bold: true),
                          _pdfCell("메모", bold: true),
                        ],
                      ),
                      ..._dimensions.asMap().entries.map((entry) {
                        final int i = entry.key;
                        final PlacedDimension dim = entry.value;
                        final endpoints = computeDimensionEndpoints(dim);
                        return pw.TableRow(
                          children: [
                            _pdfCell("${i + 1}"),
                            _pdfCell(
                              dim.type == DimensionType.center ? "센터" : "측면",
                            ),
                            _pdfCell(endpoints.distance.toInt().toString()),
                            _pdfCell(dim.note ?? ""),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      }

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
      ).showSnackBar(SnackBar(content: Text(keepWords("PDF 생성 오류: $e"))));
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

  // 🚀 [신규] 레이아웃 템플릿 라이브러리 - 자주 쓰는 배치 구성을
  // 별도의 "템플릿"으로 저장해두고, 새 프로젝트를 시작할 때 바로
  // 불러와 쓸 수 있게 한다. 특정 프로젝트에 종속되지 않는 재사용
  // 가능한 참고 배치라서 layouts와는 별도 컬렉션에 저장한다(배경
  // 사진은 기기 로컬 경로라 다른 기기/프로젝트에서 못 여니 제외).
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    "템플릿 불러오기",
                    style: TextStyle(
                      color: tossText,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Flexible(
                  child: FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('layout_templates')
                        .orderBy('createdAt', descending: true)
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(color: tossBlue),
                          ),
                        );
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            keepWords(
                              "저장된 템플릿이 없습니다.\n'더보기 > 템플릿으로 저장'으로 먼저 만들어 보십시오.",
                            ),
                            style: TextStyle(color: tossSubText),
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final data = docs[i].data() as Map<String, dynamic>;
                          final int itemCount =
                              (data['items'] as List?)?.length ?? 0;
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
                              "모듈 $itemCount개",
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
                const SizedBox(height: 8),
              ],
            ),
          ),
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
    // 🚀 현재 작업 중인 내용이 있으면 덮어써도 되는지 먼저 확인한다.
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

  // 🚀 [신규] 다른 프로젝트 도면에서 모듈 가져오기 - 이전에 저장해둔
  // 다른 배치도의 모듈 중 원하는 것만 골라 지금 도면으로 복사해 온다.
  // 1단계: 가져올 원본 도면 선택 → 2단계: 그 안의 모듈 체크박스 선택.
  void _showImportModulesFlow() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    "가져올 도면 선택",
                    style: TextStyle(
                      color: tossText,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Flexible(
                  child: FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('layouts')
                        .orderBy('updatedAt', descending: true)
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(color: tossBlue),
                          ),
                        );
                      }
                      final docs = (snapshot.data?.docs ?? [])
                          .where((d) => d.id != _currentProjectId)
                          .toList();
                      if (docs.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            keepWords("가져올 수 있는 다른 도면이 없습니다."),
                            style: TextStyle(color: tossSubText),
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final data = docs[i].data() as Map<String, dynamic>;
                          final int itemCount =
                              (data['items'] as List?)?.length ?? 0;
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
                              "모듈 $itemCount개",
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImportItemPicker(Map<String, dynamic> sourceData) {
    final List<PlacedItem> sourceItems = ((sourceData['items'] as List?) ?? [])
        .map((e) => PlacedItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final Set<String> selectedIds = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.7,
                ),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Text(
                        keepWords(
                          "가져올 모듈 선택 (${sourceData['projectName'] ?? ''})",
                        ),
                        style: const TextStyle(
                          color: tossText,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
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
                              "${item.width.toInt()}×${item.height.toInt()}mm",
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
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
                      ),
                    ),
                  ],
                ),
              ),
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
        // 겹치는 자리면 조금씩 옮겨가며 빈 자리를 찾는다.
        while (_overlapsAny(newItem, newItem.position)) {
          final Offset moved = _snapToGrid(
            Offset(newItem.position.dx + 20, newItem.position.dy + 20),
          );
          if (moved.dx > _panelWidth - newItem.width ||
              moved.dy > _panelHeight - newItem.height) {
            break; // 더 옮길 자리가 없으면 겹친 채로 둔다(사용자가 직접 조정).
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

  void _onAcceptItem(ModulePreset preset, Offset localPosition) {
    HapticFeedback.mediumImpact();
    _pushUndo();
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
        // 이어가서 계속 탭하는 것만으로 연속 치수선이 만들어지게 한다.
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
    setState(() {
      for (var i in _placedItems) i.isSelected = false;
      item.isSelected = true;
      _activeItem = item;
    });
    _showInspectorBottomSheet(item);
  }

  void _onTapBoard(Offset localPosition) {
    if (_mode == BoardMode.measureDimension) {
      // 🚀 [신규] 측정 시작 전(첫 지점을 아직 안 찍은 상태)에 기존
      // 치수선 근처를 탭하면, 새 측정을 시작하는 대신 그 치수선을
      // 삭제/기준 전환/메모/최소 간격 설정할 수 있는 창을 연다.
      if (_dimensionStartPoint == null) {
        final PlacedDimension? hitDim = _findDimensionNear(localPosition);
        if (hitDim != null) {
          HapticFeedback.lightImpact();
          _showDimensionActionsSheet(hitDim);
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
        _activeItem = null;
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

  // 🚀 [신규] 번호 배지(치수선의 p1 지점에 그려짐)는 선 자체보다 좀 더
  // 넉넉한 반경으로 우선 인식해서, 목록표에서 확인한 번호를 도면에서
  // 다시 찾아 탭할 때 더 잘 잡히게 한다.
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
  // 설정을 한 곳에서 처리하는 바텀시트.
  void _showDimensionActionsSheet(PlacedDimension dim) {
    // 🚀 이 창 안에서 기준/메모/최소 간격을 몇 번을 고치든, 열기 직전
    // 상태 하나만 기억해서 "편집 취소"가 한 번에 되게 한다(모듈 편집
    // 바텀시트와 동일 원칙).
    _pushUndo();
    final TextEditingController noteCtrl = TextEditingController(
      text: dim.note ?? "",
    );
    final TextEditingController minGapCtrl = TextEditingController(
      text: dim.minGapMm != null ? dim.minGapMm!.toInt().toString() : "",
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final endpoints = computeDimensionEndpoints(dim);
            return SingleChildScrollView(
              child: Container(
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
                    Text(
                      "치수선 - ${endpoints.distance.toInt()} mm",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: tossText,
                      ),
                    ),
                    const SizedBox(height: 20),
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
                    // 🚀 [신규] 자주 쓰는 최소 간격값을 바로 고를 수 있는
                    // 프리셋 칩.
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
                    const SizedBox(height: 20),
                    // 🚀 [신규] 대각선 모드 - 이 치수를 축 정렬 없이 두
                    // 중심점 사이 실제 직선거리+각도로 바꾼다.
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
                    // 🚀 [신규] 안전 이격거리 등 규정과 관련된 중요한
                    // 치수선을 굵은 선 + 방패 아이콘으로 강조 표시한다.
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
                      title: const Text(
                        "안전 이격거리로 강조 표시",
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
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _pushUndo();
                          setState(() {
                            _dimensions.removeWhere((d) => d.id == dim.id);
                          });
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: warningRed,
                        ),
                        label: const Text(
                          "이 치수선 삭제",
                          style: TextStyle(
                            color: warningRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: warningRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
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
  // 균등하게 배분한다(3개 이상일 때만 의미 있음) - 파워포인트 등에서
  // 흔히 쓰는 정렬/분포 도구와 동일한 개념.
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    children: [
                      const Text(
                        "정렬 / 간격 배분",
                        style: TextStyle(
                          color: tossText,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
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
          child: SingleChildScrollView(
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
                    onPressed: () async {
                      Navigator.pop(context);
                      if (!await _confirmChangesBeforeSave()) return;
                      if (!await _confirmMinGapViolationsIfAny()) return;
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
                    onPressed: () async {
                      Navigator.pop(context);
                      if (!await _confirmMinGapViolationsIfAny()) return;
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
                if (widget.attachToReport) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _attachToDailyReportPhoto();
                      },
                      icon: const Icon(
                        Icons.add_photo_alternate_rounded,
                        color: tossBlue,
                      ),
                      label: const Text(
                        "완성된 배치도, 일지 사진으로 추가",
                        style: TextStyle(
                          color: tossBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: tossBlue, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showInspectorBottomSheet(PlacedItem item) {
    // 🚀 이 편집창 안에서 이름/회전/크기 등을 몇 번을 고치든, 열기
    // 직전 상태 하나만 기억해서 "편집 취소"가 한 번에 되게 한다
    // (텍스트 입력마다 undo를 쌓으면 되돌리기가 너무 잘게 쪼개진다).
    _pushUndo();
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
              // 🚀 [버그 수정] 편집창에 버튼이 계속 늘어나면서(회전/복제/
              // 프리셋 저장/잠금/레이어 순서까지) 키보드가 뜨면 남는
              // 세로 공간이 부족해 화면 밖으로 넘치는 오버플로우가 났다 -
              // 스크롤 가능하게 감싸서 내용이 많아도 넘치지 않고 스크롤
              // 되게 한다.
              child: SingleChildScrollView(
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
                                heightCtrl.text = item.height
                                    .toInt()
                                    .toString();
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
                                        math.max(
                                          0.0,
                                          _panelHeight - item.height,
                                        ),
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
                                  content: Text(
                                    keepWords("'${item.name}' 모듈이 복사되었습니다."),
                                  ),
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
                    const SizedBox(height: 12),

                    // 🚀 [신규] 레이어 순서(앞/뒤) 조정 - 모듈이 서로 겹칠 때
                    // 어느 것이 위로 보일지 정할 수 있게 한다. 리스트 맨
                    // 뒤에 있을수록 화면 맨 위에 그려진다.
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _placedItems.remove(item);
                                _placedItems.add(item);
                              });
                              setModalState(() {});
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                              setState(() {
                                _placedItems.remove(item);
                                _placedItems.insert(0, item);
                              });
                              setModalState(() {});
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 🚀 [신규] 지금 이 모듈의 이름/크기를 "내 프리셋"으로
                    // 저장 - 다음 도면에서 팔레트에서 바로 드래그해 쓸 수
                    // 있다(예: 자주 쓰는 차단기 규격).
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          _saveAsCustomPreset(
                            nameCtrl.text.trim().isNotEmpty
                                ? nameCtrl.text.trim()
                                : item.name,
                            item.width,
                            item.height,
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
                    // 🚀 [신규] 위치가 확정된 모듈을 잠가서 실수로 드래그해
                    // 옮겨지지 않게 한다.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() => item.isLocked = !item.isLocked);
                          setModalState(() {});
                          HapticFeedback.lightImpact();
                        },
                        icon: Icon(
                          item.isLocked
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          size: 18,
                          color: item.isLocked ? warningRed : tossSubText,
                        ),
                        label: Text(
                          item.isLocked ? "잠금 해제" : "이 모듈 위치 잠그기",
                          style: TextStyle(
                            color: item.isLocked ? warningRed : tossSubText,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

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
                        icon: const Icon(
                          Icons.delete_outline,
                          color: warningRed,
                        ),
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

  // 🚀 [신규] 실제 도면 사진(카톡으로 받은 배치도, 손그림 등)을 배경으로
  // 깔아두고 그 위에 모듈을 배치할 수 있게 하는 바텀시트. 불투명도를
  // 조절해서 사진과 모듈이 겹쳐도 알아보기 쉽게 한다.
  void _showBackgroundSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: const BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D6DB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const Text(
                      "배경 사진",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: tossText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      keepWords(
                        "카톡으로 받은 실제 도면 사진을 배경에 깔고 그 위에 모듈을\n배치할 수 있습니다.",
                      ),
                      style: TextStyle(
                        fontSize: 13,
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
            );
          },
        );
      },
    );
  }

  // 🚀 [신규] 배치된 모듈을 이름별로 모아 세어서 보여준다 - 자재 발주
  // 전에 "무엇이 몇 개 필요한지" 한눈에 확인하고, 텍스트로 복사하거나
  // 카톡 등으로 바로 공유할 수 있게 했다.
  // 🚀 [신규] 치수/가이드선에 쓰이는 색이 많아져서(센터/측면/대각선/
  // 정렬가이드/경고 등) 처음 쓰는 사람은 헷갈릴 수 있어, 각 색이 뭘
  // 뜻하는지 바로 확인할 수 있는 범례를 추가했다.
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
          width: 340,
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

  void _showMaterialSummarySheet() {
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
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
                  "자재 수량",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: tossText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  keepWords("배치된 모듈을 이름별로 모아 세었습니다."),
                  style: TextStyle(fontSize: 13, color: tossSubText),
                ),
                const SizedBox(height: 16),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        "배치된 모듈이 없습니다.",
                        style: TextStyle(color: tossSubText),
                      ),
                    ),
                  )
                else
                  Flexible(
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
                      "${_placedItems.length}개",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: tossText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: entries.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: buildSummaryText()),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(keepWords("자재 목록을 복사했습니다.")),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.copy_rounded, color: tossText),
                        label: const Text(
                          "텍스트 복사",
                          style: TextStyle(
                            color: tossText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: tossText.withValues(alpha: 0.2),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: entries.isEmpty
                            ? null
                            : () {
                                // ignore: deprecated_member_use
                                Share.share(buildSummaryText());
                              },
                        icon: const Icon(
                          Icons.ios_share_rounded,
                          color: pureWhite,
                        ),
                        label: const Text(
                          "공유하기",
                          style: TextStyle(
                            color: pureWhite,
                            fontWeight: FontWeight.bold,
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
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
          child: SingleChildScrollView(
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
                Text(
                  keepWords("실제 중판(캐비닛)의 사이즈를 mm 단위로 입력하십시오."),
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
                      _pushUndo();
                      setState(() {
                        _panelWidth = double.tryParse(widthCtrl.text) ?? 600.0;
                        _panelHeight =
                            double.tryParse(heightCtrl.text) ?? 800.0;

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
          // 🚀 [신규] 길게 누르면 실행 취소 히스토리 목록을 열어 원하는
          // 시점으로 한 번에 이동할 수 있다(짧게 누르면 기존처럼 한
          // 단계만 되돌린다).
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
              tooltip: "저장 및 공유",
              onPressed: _showSaveActionSheet,
              icon: const Icon(Icons.ios_share_rounded, color: tossBlue),
            ),
          // 🚀 [버그 수정] AppBar 아이콘이 하나둘 늘어나다 보니(자재 수량/
          // 배경 사진/외함 크기/초기화까지) 좁은 화면에서 화면 밖으로
          // 잘리거나 아이콘끼리 겹치는 오버플로우가 났다 - 자주 안 쓰는
          // 것들은 "더보기" 메뉴 하나로 모았다.
          PopupMenuButton<String>(
            tooltip: "더보기",
            icon: const Icon(Icons.more_vert_rounded, color: tossText),
            onSelected: (value) {
              switch (value) {
                case 'material':
                  _showMaterialSummarySheet();
                  break;
                case 'background':
                  _showBackgroundSheet();
                  break;
                case 'panel':
                  _showPanelSettingsSheet();
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
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 🚀 [신규] 미니맵에서 "지금 보고 있는 영역"을
                    // 계산하려면 뷰포트의 실제 화면 크기가 필요하다.
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
                      constrained: false,
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
                                      border: Border.all(
                                        color: tossText,
                                        width: 3,
                                      ),
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
                                          painter: GridPainter(
                                            gridSize: _gridSize,
                                          ),
                                        ),
                                        CustomPaint(
                                          size: Size.infinite,
                                          painter: DimensionPainter(
                                            dimensions: _dimensions,
                                            activePoint: _dimensionStartPoint,
                                            panelWidth: _panelWidth,
                                            panelHeight: _panelHeight,
                                            version: _dimensionsVersion,
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
                                              child: _buildBoardItem(
                                                _previewItem!,
                                              ),
                                            ),
                                          ),
                                        ],

                                        if (_activeItem != null &&
                                            _mode == BoardMode.placeModule)
                                          ..._buildGuidePaints(_activeItem!),

                                        // 🚀 [복원] 안내선 자체는 문제가
                                        // 없었다 - 아래 _placedItems.map()의
                                        // Positioned에 key가 있는 한, 이
                                        // 위젯들이 조건부로 나타났다 사라져도
                                        // 더 이상 목록 순서가 밀려서 엉뚱한
                                        // 모듈에 제스처가 연결되는 일이
                                        // 없다.
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
                                            // 🚀 [버그 수정] 이 Positioned에
                                            // key가 없으면, 정렬 가이드선이
                                            // 조건부로 Stack children 목록에
                                            // 끼어들거나 빠질 때(예: 드래그
                                            // 도중 안내선이 나타남/사라짐)
                                            // 목록의 순서(인덱스)가 밀리면서
                                            // 플러터가 "같은 자리에 있던"
                                            // 엘리먼트를 다른 모듈 것으로
                                            // 착각해 재사용할 수 있었다.
                                            // 그러면 지금 드래그 중이던
                                            // 제스처가 엉뚱한 모듈의
                                            // onPanUpdate로 연결되어, 실제로
                                            // 다른(엉뚱한) 모듈의 위치가
                                            // 바뀌는 것처럼 보였다. id 기반
                                            // key를 달아 항상 같은 모듈에
                                            // 같은 엘리먼트가 매칭되게
                                            // 고정한다.
                                            key: ValueKey(item.id),
                                            left:
                                                item.position.dx -
                                                _kTouchHitPad,
                                            top:
                                                item.position.dy -
                                                _kTouchHitPad,
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onPanStart: canDrag
                                                  ? (details) {
                                                      // 드래그 한 번 = undo 한 단계
                                                      // (onPanUpdate마다 쌓으면 되돌리기가
                                                      // 프레임 단위로 쪼개져 버린다).
                                                      final bool isGroupDrag =
                                                          _multiSelectMode &&
                                                          _multiSelectedIds
                                                              .contains(
                                                                item.id,
                                                              ) &&
                                                          _multiSelectedIds
                                                                  .length >
                                                              1;
                                                      _pushUndo();
                                                      setState(() {
                                                        _dragRawPosition =
                                                            item.position;
                                                        _activeItem = item;
                                                        if (isGroupDrag) {
                                                          _groupDragAnchorOrigin =
                                                              item.position;
                                                          _groupDragOrigins = {
                                                            for (final i
                                                                in _placedItems)
                                                              if (_multiSelectedIds
                                                                  .contains(
                                                                    i.id,
                                                                  ))
                                                                i.id:
                                                                    i.position,
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
                                                                .contains(
                                                                  i.id,
                                                                )) {
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
                                                          _groupDragOrigins =
                                                              {};
                                                          _groupOriginBounds =
                                                              null;
                                                          if (!_multiSelectMode) {
                                                            for (var i
                                                                in _placedItems) {
                                                              i.isSelected =
                                                                  false;
                                                            }
                                                            item.isSelected =
                                                                true;
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
                                                          // 🚀 [버그 수정] 각 모듈마다 따로 화면
                                                          // 경계에 맞춰 자르면(clamp) 폭이 서로
                                                          // 다른 모듈들이 경계에 닿는 시점이 달라
                                                          // 어떤 건 멈추고 어떤 건 계속 움직여서
                                                          // 서로 겹쳐버렸다 - 선택된 모듈 전체의
                                                          // 바운딩 박스 기준으로 delta를 딱 한 번만
                                                          // 잘라서, 항상 같은 delta를 모두에게
                                                          // 적용해 서로의 상대 위치를 유지한다.
                                                          final Rect bounds =
                                                              _groupOriginBounds!;
                                                          final Offset
                                                          rawDelta =
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
                                                          // 옮겼을 때 선택되지
                                                          // 않은 다른 모듈과
                                                          // 겹치면 이번 프레임의
                                                          // 이동은 통째로
                                                          // 취소한다(그룹끼리는
                                                          // 서로 겹침 검사에서
                                                          // 제외).
                                                          bool wouldCollide =
                                                              false;
                                                          for (final entry
                                                              in _groupDragOrigins
                                                                  .entries) {
                                                            final PlacedItem
                                                            it = _placedItems
                                                                .firstWhere(
                                                                  (x) =>
                                                                      x.id ==
                                                                      entry.key,
                                                                );
                                                            final Offset
                                                            newPos =
                                                                entry.value +
                                                                snappedDelta;
                                                            if (_overlapsAny(
                                                              it,
                                                              newPos,
                                                              excludeIds:
                                                                  _multiSelectedIds,
                                                            )) {
                                                              wouldCollide =
                                                                  true;
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
                                                            final Offset?
                                                            origin =
                                                                _groupDragOrigins[i
                                                                    .id];
                                                            if (origin ==
                                                                null) {
                                                              continue;
                                                            }
                                                            i.position =
                                                                origin +
                                                                snappedDelta;
                                                          }
                                                        } else {
                                                          double
                                                          clampedX = _dragRawPosition
                                                              .dx
                                                              .clamp(
                                                                0.0,
                                                                math.max(
                                                                  0.0,
                                                                  _panelWidth -
                                                                      item.width,
                                                                ),
                                                              );
                                                          double
                                                          clampedY = _dragRawPosition
                                                              .dy
                                                              .clamp(
                                                                0.0,
                                                                math.max(
                                                                  0.0,
                                                                  _panelHeight -
                                                                      item.height,
                                                                ),
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
                                                          // 한쪽이 막혀도
                                                          // 다른 쪽으로는
                                                          // 벽을 따라
                                                          // 미끄러지듯
                                                          // 움직일 수 있게
                                                          // 한다.
                                                          final aligned =
                                                              _snapToAlignment(
                                                                item,
                                                                gridSnapped,
                                                              );
                                                          final Offset
                                                          xOnly = Offset(
                                                            aligned.dx,
                                                            item.position.dy,
                                                          );
                                                          if (!_overlapsAny(
                                                            item,
                                                            xOnly,
                                                          )) {
                                                            item.position =
                                                                xOnly;
                                                          }
                                                          final Offset
                                                          yOnly = Offset(
                                                            item.position.dx,
                                                            aligned.dy,
                                                          );
                                                          if (!_overlapsAny(
                                                            item,
                                                            yOnly,
                                                          )) {
                                                            item.position =
                                                                yOnly;
                                                          }
                                                        }
                                                      });
                                                    }
                                                  : null,
                                              onPanEnd: canDrag
                                                  ? (details) {
                                                      setState(() {
                                                        _activeItem = null;
                                                        _alignGuideX = null;
                                                        _alignGuideY = null;
                                                        _groupDragAnchorOrigin =
                                                            null;
                                                        _groupDragOrigins = {};
                                                        _groupOriginBounds =
                                                            null;
                                                      });
                                                    }
                                                  : null,
                                              onTap: () => _onTapItem(item),
                                              child: Container(
                                                width:
                                                    item.width +
                                                    _kTouchHitPad * 2,
                                                height:
                                                    item.height +
                                                    _kTouchHitPad * 2,
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
                                                                shape: BoxShape
                                                                    .circle,
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
                                        // 🚀 [신규] 완전히 빈 도면일 때, 처음
                                        // 여는 사람이 뭘 해야 할지 막막하지
                                        // 않도록 샘플 배치를 눌러보게 안내.
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
                                                    color: tossSubText
                                                        .withValues(alpha: 0.5),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    keepWords(
                                                      "아래에서 모듈을 끌어다\n놓아 배치를 시작하십시오",
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: tossSubText
                                                          .withValues(
                                                            alpha: 0.7,
                                                          ),
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  OutlinedButton.icon(
                                                    onPressed:
                                                        _loadSampleLayout,
                                                    icon: const Icon(
                                                      Icons
                                                          .auto_awesome_rounded,
                                                      size: 16,
                                                      color: tossBlue,
                                                    ),
                                                    label: const Text(
                                                      "샘플 배치 불러보기",
                                                      style: TextStyle(
                                                        color: tossBlue,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    style: OutlinedButton.styleFrom(
                                                      side: const BorderSide(
                                                        color: tossBlue,
                                                      ),
                                                      backgroundColor:
                                                          pureWhite,
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
                    );
                  },
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
          // 🚀 [신규] 다중 선택 도구모음 - 2개 이상 선택 시 그룹 이동/
          // 복제/잠금/정렬/삭제를 한 번에 할 수 있게 하단에 띄운다.
          // 🚀 [개선] 선택하는 순간 뚝 나타나던 걸 부드럽게 슬라이드 인/
          // 아웃 되도록 항상 트리에 두고 위치만 애니메이션한다.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: _multiSelectedIds.isNotEmpty ? 0 : -200,
            child: IgnorePointer(
              ignoring: _multiSelectedIds.isEmpty,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _multiSelectedIds.isNotEmpty ? 1 : 0,
                child: SafeArea(
                  top: false,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                      children: [
                        Text(
                          keepWords("${_multiSelectedIds.length}개 선택"),
                          style: const TextStyle(
                            color: pureWhite,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
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
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  color: pureWhite.withValues(alpha: 0.2),
                                ),
                                _buildMultiBarIcon(
                                  Icons.copy_rounded,
                                  _duplicateSelectedGroup,
                                ),
                                // 🚀 [신규] 잠금/정렬은 아이콘만으로는 뜻이
                                // 바로 와닿지 않을 수 있어 짧은 라벨을 같이
                                // 붙였다(이동/복제/삭제는 아이콘만으로도
                                // 충분히 익숙한 동작이라 그대로 둠).
                                _buildMultiBarLabeledIcon(
                                  _selectedGroup.isNotEmpty &&
                                          _selectedGroup.every(
                                            (i) => i.isLocked,
                                          )
                                      ? Icons.lock_open_rounded
                                      : Icons.lock_outline_rounded,
                                  _selectedGroup.isNotEmpty &&
                                          _selectedGroup.every(
                                            (i) => i.isLocked,
                                          )
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
                              ],
                            ),
                          ),
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
          // 🚀 [신규] 미니맵 - 확대해서 작업 중일 때 전체 도면에서 지금
          // 보고 있는 위치를 놓치지 않도록 구석에 작게 띄운다.
          if (_placedItems.isNotEmpty && _viewportSize != null)
            Positioned(top: 12, right: 12, child: _buildMinimap()),
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
  // 짧은 텍스트 라벨을 함께 보여준다.
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

  // 🚀 [신규] 미니맵 - 전체 도면을 축소해서 보여주고, InteractiveViewer의
  // 변환행렬을 역산해 지금 화면에 실제로 보이는 영역을 겹쳐 그린다.
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
                    child: Opacity(opacity: 0.8, child: _buildDuctChip(preset)),
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
          if (_customPresets.isNotEmpty) ...[
            const SizedBox(height: 16),
            // 🚀 [신규] 내가 저장해둔 자주 쓰는 모듈 크기 - 모듈 편집창의
            // "프리셋으로 저장"으로 추가되며, 길게 눌러 삭제할 수 있다.
            const Text(
              "내 프리셋 (길게 눌러 삭제)",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tossSubText,
              ),
            ),
            const SizedBox(height: 8),
            // 🚀 [신규] 프리셋이 늘어나면 찾기 번거로워질 수 있어 이름
            // 검색창을 추가했다(프리셋 4개 이상일 때만 표시).
            if (_customPresets.length > 3) ...[
              TextField(
                controller: _presetSearchCtrl,
                onChanged: (v) => setState(() => _presetSearchQuery = v.trim()),
                style: const TextStyle(fontSize: 13, color: tossText),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: "프리셋 이름 검색",
                  hintStyle: const TextStyle(fontSize: 12, color: tossSubText),
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Builder(
              builder: (context) {
                final List<ModulePreset> filtered = _presetSearchQuery.isEmpty
                    ? _customPresets
                    : _customPresets
                          .where(
                            (p) => p.name.toLowerCase().contains(
                              _presetSearchQuery.toLowerCase(),
                            ),
                          )
                          .toList();
                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      "검색 결과가 없습니다",
                      style: TextStyle(fontSize: 12, color: tossSubText),
                    ),
                  );
                }
                return SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final preset = filtered[index];
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
                    },
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomPresetChip(ModulePreset preset) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tossBg,
        borderRadius: BorderRadius.circular(12),
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
        _currentDimType = isCenter ? DimensionType.edge : DimensionType.center;
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
  Widget _buildDimensionChip({
    required bool selected,
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : tossBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? color : tossSubText),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: selected ? color : tossSubText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDimensionToolBar() {
    final bool isCenter = _currentDimType == DimensionType.center;
    final Color activeColor = isCenter ? centerDimColor : edgeDimColor;

    return Padding(
      key: const ValueKey("dimension"),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 🚀 [수정] 칩 3개(기준/체인/대각선)가 좁은 화면에서 넘치지
              // 않도록 가로 스크롤 영역으로 묶고, 취소/전체삭제 아이콘은
              // 항상 오른쪽에 고정해서 보이게 했다.
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDimensionChip(
                        selected: true,
                        color: activeColor,
                        icon: Icons.sync_alt_rounded,
                        label: isCenter ? "센터 기준" : "측면 기준",
                        onTap: () => setState(() {
                          _currentDimType = isCenter
                              ? DimensionType.edge
                              : DimensionType.center;
                        }),
                      ),
                      const SizedBox(width: 8),
                      // 🚀 [신규] 체인 모드 - 켜면 점을 계속 이어서 탭하는
                      // 것만으로 연속 치수선이 만들어진다.
                      _buildDimensionChip(
                        selected: _dimensionChainMode,
                        color: tossBlue,
                        icon: Icons.link_rounded,
                        label: "체인",
                        onTap: () => setState(() {
                          _dimensionChainMode = !_dimensionChainMode;
                        }),
                      ),
                      const SizedBox(width: 8),
                      // 🚀 [신규] 대각선 모드 - 켜면 축 정렬 없이 실제
                      // 직선거리+각도를 측정한다.
                      _buildDimensionChip(
                        selected: _dimensionDiagonalMode,
                        color: diagonalDimColor,
                        icon: Icons.turn_slight_right_rounded,
                        label: "대각선",
                        onTap: () => setState(() {
                          _dimensionDiagonalMode = !_dimensionDiagonalMode;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              // 🚀 [추가] 첫 지점을 잘못 찍었을 때 두 번째 지점을 억지로
              // 찍어 엉뚱한 치수를 만들지 않고도 취소할 수 있는 버튼.
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
                    _pushUndo();
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
          const SizedBox(height: 8),
          Text(
            _dimensionStartPoint == null
                ? (_dimensionChainMode
                      ? "체인 모드: 지점을 계속 탭하면 이어서 측정됩니다"
                      : "측정할 두 지점을 순서대로 터치하십시오 (치수선을 탭하면 편집)")
                : "다음 지점을 터치하면 연결됩니다",
            style: const TextStyle(
              color: tossSubText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
  // 라벨-치수선 연결용 짧은 리더선
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
  // 🚀 [신규] dimensions 리스트는 계속 같은 객체를 그 자리에서 바꿔쓰기
  // 때문에(add/remove 제외) 기준/메모/최소 간격만 바뀌었을 땐 길이 비교로
  // 감지가 안 된다. 그런 변경이 있을 때마다 이 값을 1씩 올려서 확실히
  // 다시 그려지게 한다.
  final int version;

  DimensionPainter({
    required this.dimensions,
    this.activePoint,
    required this.panelWidth,
    required this.panelHeight,
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

      // 🚀 [신규] 대각선 모드면 축 기준 대신 실제 각도를 라벨에 표시한다.
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

      // 🚀 [신규] 안전 이격거리처럼 규정과 관련된 치수는 굵은 선 +
      // 방패 아이콘 표시로 다른 치수와 구분되게 한다.
      if (dim.isSafetyCritical) {
        labelPrefix = "🛡 $labelPrefix";
      }

      // 🚀 [신규] 최소 유지 간격을 설정해뒀는데 현재 거리가 그보다
      // 좁아지면(모듈을 옮기다가 실시간으로) 경고색으로 바뀌어 즉시
      // 눈에 띄게 한다(가장 시급한 정보이므로 다른 라벨보다 우선).
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

      // 🚀 [신규] 치수선마다 번호 배지를 달아서, 도면이 복잡해져도
      // 사진/PDF로 내보낸 치수 목록표와 대조해볼 수 있게 한다.
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
        oldDelegate.panelHeight != panelHeight ||
        oldDelegate.version != version;
  }
}
