import 'dart:async';
import '../widgets/korean_text.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
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
import '../models/instrument_shape_painter.dart';
import '../models/layout_board_models.dart';
import '../models/layout_plates.dart';
import '../models/skid_presets.dart';
import '../models/elec_presets.dart';
import '../models/skid_route.dart';
import 'skid_route_editor_page.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import '../models/layout_board_owner.dart';
import '../models/layout_board_painters.dart';
import '../widgets/layout_board_ui.dart';
export '../models/layout_board_painters.dart';
export '../models/layout_board_models.dart';
export '../models/instrument_shape_painter.dart';
export '../models/skid_presets.dart';
export '../models/elec_presets.dart';
export '../models/skid_route.dart';
export '../models/layout_plates.dart';
export '../widgets/layout_board_ui.dart';

// 색(전선관 계산기와 같은 slate + 틸)과 카드·확인 창은 widgets/layout_board_ui.dart에 있다.

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

/// 이 폭(dp) 이상이면 왼쪽 자재 칸·가운데 도면·오른쪽 편집 칸을 나란히 보여 준다.
/// 폴드를 편 화면(세로 약 670dp)이나 세로로 세운 태블릿은 양옆 칸을 빼면 도면이
/// 너무 좁아져서, 가로로 넉넉한 화면에서만 나란히 놓는다.
const double kLayoutBoardWideWidth = 900;
const double _kWideSidebarWidth = 260;
const double _kWideInspectorWidth = 320;

/// 화면 폭으로 넓은 모양을 쓸지 정한다(테스트에서도 같은 기준을 쓴다).
bool layoutBoardUsesWideLayout(Size size) =>
    size.width >= kLayoutBoardWideWidth;

// 🚀 데이터 모델과 치수 계산은 models/layout_board_models.dart 로 옮겼다(모바일·태블릿 공용).
// ---------------------------------------------------------
// 2. 메인 페이지 화면
// ---------------------------------------------------------
/// 작업 배치도 화면 하나. 폰·태블릿·폴드 모두 이 화면을 쓰고, 화면 폭에 따라
/// 모양만 달라진다(좁으면 아래 팔레트 + 바텀시트, 넓으면 왼쪽 자재 칸 + 오른쪽 편집 칸).
/// 작업 내용은 모두 이 State 하나에 있어서, 폴드를 펴고 접어도 저장 안 한
/// 배치가 그대로 남는다.
class LayoutBoardPage extends StatefulWidget {
  final String? projectId;
  // 🚀 [신규] 작업 일지 작성 화면에서 진입했을 때 true로 넘어온다. 이 경우
  // 저장 시트에 "완성된 배치도를 일지 사진으로 추가" 버튼이 나타나고,
  // 캡처한 사진 경로를 화면을 닫을 때 결과값으로 돌려준다.
  final bool attachToReport;

  /// 새 도면일 때 종류(캐비닛·스키드). 불러온 도면·이어한 임시 저장은 그 문서의 종류를 쓴다.
  final String initialKind;

  const LayoutBoardPage({
    super.key,
    this.projectId,
    this.attachToReport = false,
    this.initialKind = kLayoutKindCabinet,
  });

  @override
  State<LayoutBoardPage> createState() => _LayoutBoardPageState();
}

class _LayoutBoardPageState extends State<LayoutBoardPage>
    with WidgetsBindingObserver {
  double _panelWidth = 600.0;
  double _panelHeight = 800.0;
  final double _gridSize = 5.0;

  BoardMode _mode = BoardMode.placeModule;
  DimensionType _currentDimType = DimensionType.center;
  // 모듈을 끌 때 보여 줄 안내선. 센터선과 외곽선을 따로 켜고 끌 수 있다.
  // (좁은 화면의 동그란 단추는 둘 중 하나로 바꾸고, 넓은 화면은 둘 다 켤 수도 있다.)
  bool _showCenterGuide = true;
  bool _showEdgeGuide = false;
  // 지난번 그릴 때 넓은 모양이었는지. 모양이 바뀌는 순간을 알아채는 데 쓴다.
  bool? _lastWide;
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
  // 미니맵을 펼쳤는지. null이면 넓은 화면은 펴고, 폰 폭은 접어 둔다.
  bool? _minimapOpen;
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
  // 도면이 보이는 칸. 계기 목록에서 고른 것을 지금 보이는 가운데에 놓을 때 쓴다.
  final GlobalKey _viewerKey = GlobalKey();
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
  // 예전 태블릿 화면이 따로 쓰던 임시 저장 자리. 남아 있으면 이어서 열 수 있게 읽기만 한다.
  static const String _legacyTabletDraftPrefsKey =
      'tablet_layout_board_draft_v1';
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

  // 넓은 화면 오른쪽 칸의 모듈 이름 칸. 고른 모듈이 바뀔 때만 글을 바꿔 넣는다.
  final TextEditingController _inspectorNameCtrl = TextEditingController();
  String? _inspectorNameFor;

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
      _checkAndOfferDraftRecovery().then((resumed) {
        if (!resumed &&
            widget.initialKind == kLayoutKindSkid &&
            mounted &&
            !_hasAnyContent) {
          setState(_startNewSkid);
        }
        _maybeShowOnboarding();
      });
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
                keepWords(
                  _isWide
                      ? "① 왼쪽 팔레트에서 모듈을 도면 위로 끌어다 놓습니다."
                      : "① 아래 팔레트에서 모듈을 도면 위로 끌어다 놓습니다.",
                ),
                style: TextStyle(color: tossText, fontSize: 14, height: 1.6),
              ),
              Text(
                keepWords("② '고정 치수 측정' 모드에서 두 지점을 순서대로 탭하면 거리가 자동으로 표시됩니다."),
                style: TextStyle(color: tossText, fontSize: 14, height: 1.6),
              ),
              Text(
                keepWords("③ 상단의 '다중 선택'을 켜면 여러 모듈을 한 번에 옮기거나 정렬할 수 있습니다."),
                style: TextStyle(color: tossText, fontSize: 14, height: 1.6),
              ),
              Text(
                keepWords("④ ⋮ 더보기 메뉴에서 색상 범례, 배경 사진, 자재 수량 등을 확인할 수 있습니다."),
                style: TextStyle(color: tossText, fontSize: 14, height: 1.6),
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
    _inspectorNameCtrl.dispose();
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

  bool get _hasAnyContent =>
      _routes.isNotEmpty ||
      _placedItems.isNotEmpty ||
      _dimensions.isNotEmpty ||
      _plateStore.values.any(
        (p) =>
            ((p['items'] as List?)?.isNotEmpty ?? false) ||
            ((p['dimensions'] as List?)?.isNotEmpty ?? false),
      );

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

  // ───────────────────────── 좌·우 측판 ─────────────────────────
  // 화면에 보이는 판(_plateId)의 모듈·치수·크기는 늘 쓰던 칸(_placedItems 등)에 있고,
  // 안 보이는 판은 _plateStore에 저장 모양(JSON)으로 들어 있다. 판을 바꿀 때 서로 옮긴다.

  String _plateId = kPlateMain;
  bool _sidePlatesOn = false;

  /// 도면 종류(kLayoutKindCabinet·kLayoutKindSkid).
  String _kind = kLayoutKindCabinet;
  bool get _isSkid => _kind == kLayoutKindSkid;

  /// 새 스키드 도면: 크기를 스키드 기본(길이 × 폭)으로.
  /// 다음 그리기에서 도면 전체가 화면에 들어오게 맞춘다(스키드처럼 큰 도면).
  bool _fitPending = false;

  void _fitBoardToView() {
    final Size? v = _viewportSize;
    if (v == null || _panelWidth <= 0 || _panelHeight <= 0) return;
    final double vh = v.height;
    final double k = math.min(v.width / _panelWidth, vh / _panelHeight) * 0.92;
    final double dx = (v.width - _panelWidth * k) / 2;
    final double dy = (vh - _panelHeight * k) / 2;
    _viewerController.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(k, k, 1, 1);
  }

  void _startNewSkid() {
    _fitPending = true;
    _kind = kLayoutKindSkid;
    _sidePlatesOn = false;
    _panelWidth = kSkidDefaultLength;
    _panelHeight = kSkidDefaultWidth;
  }

  /// 중판 면에서 문 안쪽까지(mm). 넣으면 이보다 깊은 부품을 알려 준다.
  double? _cabinetDepth;
  final Map<String, Map<String, dynamic>> _plateStore = {};
  final Map<String, List<List<Map<String, dynamic>>>> _plateUndo = {};

  /// 이번 그리기에서 문제가 있는(간섭·깊이 초과) 모듈 id.
  Set<String> _problemIds = const {};

  Map<String, dynamic> _captureActivePlate() => {
    ...?_plateStore[_plateId],
    'panelWidth': _panelWidth,
    'panelHeight': _panelHeight,
    'items': _placedItems.map((e) => e.toJson()).toList(),
    'dimensions': _dimensions.map((e) => e.toJson()).toList(),
    'backgroundImagePath': _backgroundImagePath,
    'backgroundOpacity': _backgroundOpacity,
  };

  Map<String, Map<String, dynamic>> _allPlates() => {
    ..._plateStore,
    _plateId: _captureActivePlate(),
  };

  // 새 판(탭) 기본 크기. 캐비닛 측판 = 가로 300 × 중판 세로.
  // 스키드 정면 = 스키드 길이 × 높이, 좌·우측면 = 스키드 폭 × 높이.
  Map<String, dynamic> _newSidePlate([String? id]) {
    final main = _allPlates()[kPlateMain];
    final double mainW =
        (main?['panelWidth'] as num?)?.toDouble() ?? _panelWidth;
    final double mainH =
        (main?['panelHeight'] as num?)?.toDouble() ?? _panelHeight;
    final double w = !_isSkid ? 300.0 : (id == kSkidViewFront ? mainW : mainH);
    return {
      'panelWidth': w,
      'panelHeight': _isSkid ? kSkidDefaultHeight : mainH,
      'items': <dynamic>[],
      'dimensions': <dynamic>[],
      'backgroundOpacity': 0.5,
    };
  }

  /// 탭 순서와 이름(캐비닛: 좌측판·중판·우측판, 스키드: 평면·정면·좌측면·우측면).
  List<String> get _tabOrder => _isSkid ? kSkidViewOrder : kPlateOrder;
  String _tabLabel(String id) => _isSkid ? skidViewLabel(id) : plateLabel(id);
  bool get _showTabs => _isSkid || _sidePlatesOn;

  void _loadPlateFields(Map<String, dynamic> d) {
    _panelWidth = (d['panelWidth'] as num?)?.toDouble() ?? _panelWidth;
    _panelHeight = (d['panelHeight'] as num?)?.toDouble() ?? _panelHeight;
    _placedItems
      ..clear()
      ..addAll(layoutItemsFromData(d));
    _dimensions
      ..clear()
      ..addAll(layoutDimensionsFromData(d));
    _backgroundImagePath = d['backgroundImagePath'] as String?;
    _backgroundOpacity = (d['backgroundOpacity'] as num?)?.toDouble() ?? 0.5;
  }

  /// 보이는 판을 [id]로 바꾼다(setState 안에서 부른다). 되돌리기 기록도 판마다 따로.
  void _switchPlate(String id) {
    if (id == _plateId) return;
    _plateStore[_plateId] = _captureActivePlate();
    _plateUndo[_plateId] = [List.of(_undoStack), List.of(_redoStack)];
    final target = _plateStore.remove(id) ?? _newSidePlate(id);
    _plateId = id;
    _plateStore[id] = {
      for (final k in const ['bottomOffset', 'gap'])
        if (target[k] != null) k: target[k],
    };
    _loadPlateFields(target);
    final st = _plateUndo[id];
    _undoStack
      ..clear()
      ..addAll(st?[0] ?? const []);
    _redoStack
      ..clear()
      ..addAll(st?[1] ?? const []);
    _activeItem = null;
    _previewItem = null;
    _dimensionStartPoint = null;
    _inspectorNameFor = null;
    _viewerController.value = Matrix4.identity();
    if (_isSkid) _fitPending = true;
  }

  /// 저장할 때 붙이는 측판 칸(예전 앱은 이 칸을 모르고 중판만 읽는다).
  Map<String, dynamic> _sidePlateFields(
    Map<String, Map<String, dynamic>> plates,
  ) => {
    'kind': _kind,
    if (_routes.isNotEmpty) 'routes': _routes.map((r) => r.toJson()).toList(),
    'sidePlatesOn': _sidePlatesOn,
    if (_cabinetDepth != null) 'cabinetDepth': _cabinetDepth,
    'sidePlates': {
      for (final e in plates.entries)
        if (e.key != kPlateMain) e.key: e.value,
    },
  };

  /// 저장된 문서의 측판 칸을 읽는다(중판은 늘 쓰던 칸에서 따로 읽는다).
  void _applySidePlateFields(Map<String, dynamic> data) {
    _plateStore.clear();
    _plateUndo.clear();
    _plateId = kPlateMain;
    final side = data['sidePlates'];
    if (side is Map) {
      side.forEach((id, p) {
        if (p is Map && id != kPlateMain) {
          _plateStore[id.toString()] = Map<String, dynamic>.from(p);
        }
      });
    }
    _routes
      ..clear()
      ..addAll([
        for (final r in (data['routes'] as List?) ?? const [])
          if (r is Map) ConduitRoute.fromJson(Map<String, dynamic>.from(r)),
      ]);
    _sidePlatesOn = data['sidePlatesOn'] == true;
    _kind = data['kind'] == kLayoutKindSkid
        ? kLayoutKindSkid
        : kLayoutKindCabinet;
    if (_kind == kLayoutKindSkid) _fitPending = true;
    _cabinetDepth = (data['cabinetDepth'] as num?)?.toDouble();
  }

  ClashReport _clashReport() {
    final plates = _allPlates();
    PlateData? side(String id) => _sidePlatesOn && plates[id] != null
        ? PlateData.fromJson(plates[id]!)
        : null;
    return checkCabinetClashes(
      main: PlateData.fromJson(plates[kPlateMain]!),
      left: side(kPlateLeft),
      right: side(kPlateRight),
      cabinetDepth: _cabinetDepth,
    );
  }

  void _toggleSidePlates() {
    setState(() {
      if (_sidePlatesOn && _plateId != kPlateMain) _switchPlate(kPlateMain);
      _sidePlatesOn = !_sidePlatesOn;
    });
    _saveDraftToPrefs();
  }

  Widget _buildPlateTabs() {
    return Container(
      color: pureWhite,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          for (final id in _tabOrder) ...[
            Expanded(
              child: ChoiceChip(
                key: ValueKey("plate_tab_$id"),
                label: SizedBox(
                  width: double.infinity,
                  child: Text(
                    _tabLabel(id),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ),
                // 탭이 넷(스키드)이면 좁아서 안쪽 여백을 줄인다.
                labelPadding: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                selected: id == _plateId,
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: id == _plateId ? pureWhite : tossText,
                ),
                selectedColor: tossBlue,
                backgroundColor: pureWhite,
                side: BorderSide(color: id == _plateId ? tossBlue : layoutLine),
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => _switchPlate(id));
                },
              ),
            ),
            if (id != _tabOrder.last) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  void _showCabinetSettingsSheet() {
    String num0(double? v) => v == null
        ? ""
        : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());
    final plates = _allPlates();
    double? field(String id, String k) => (plates[id]?[k] as num?)?.toDouble();
    final depthCtrl = TextEditingController(text: num0(_cabinetDepth));
    final ctrls = {
      for (final id in const [kPlateLeft, kPlateRight])
        for (final k in const ['bottomOffset', 'gap'])
          '$id.$k': TextEditingController(text: num0(field(id, k) ?? 0)),
    };
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBottomSheetHandle(),
              const Text(
                "측판·깊이 설정",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: tossText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                keepWords(
                  "측판 크기는 측판 탭에서 '외함 사이즈 설정'으로 따로 바꿉니다. 간섭 확인은 좌측판 오른쪽 끝·우측판 왼쪽 끝이 중판 쪽이라고 보고 셈합니다.",
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: tossSubText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _buildCoordinateInput(
                "캐비닛 깊이 (중판 면~문 안쪽, mm, 비우면 확인 안 함)",
                depthCtrl.text,
                (_) {},
                controller: depthCtrl,
              ),
              for (final id in const [kPlateLeft, kPlateRight]) ...[
                const SizedBox(height: 16),
                _panelLabel(plateLabel(id)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildCoordinateInput(
                        "바닥 높이 차 (mm)",
                        ctrls['$id.bottomOffset']!.text,
                        (_) {},
                        controller: ctrls['$id.bottomOffset'],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCoordinateInput(
                        "중판~벽 틈 (mm)",
                        ctrls['$id.gap']!.text,
                        (_) {},
                        controller: ctrls['$id.gap'],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tossBlue,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    final d = double.tryParse(depthCtrl.text.trim());
                    _cabinetDepth = d == null || d <= 0 ? null : d;
                    for (final id in const [kPlateLeft, kPlateRight]) {
                      final base = id == _plateId
                          ? (_plateStore[id] ?? {})
                          : (_plateStore[id] ?? _newSidePlate());
                      _plateStore[id] = {
                        ...base,
                        for (final k in const ['bottomOffset', 'gap'])
                          k: double.tryParse(ctrls['$id.$k']!.text.trim()) ?? 0,
                      };
                    }
                  });
                  _saveDraftToPrefs();
                },
                child: const Text(
                  "적용",
                  style: TextStyle(
                    color: pureWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClashSheet() {
    final r = _clashReport();
    String dText(double? d) => d == null ? "-" : d.toInt().toString();
    final lines = <String>[
      for (final c in r.clashes)
        "${plateLabel(c.plateA)} · ${c.a.name}  ↔  ${plateLabel(c.plateB)} · ${c.b.name}",
      for (final it in r.tooDeep)
        "중판 · ${it.name}: 깊이 ${dText(it.depth)}mm가 캐비닛 깊이 ${dText(_cabinetDepth)}mm보다 깊습니다",
    ];
    final missing = r.noDepth.entries.where((e) => e.value > 0).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lines.isEmpty ? "부딪히는 부품이 없습니다" : "부딪히는 곳 ${lines.length}건",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: lines.isEmpty ? tossText : warningRed,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final l in lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          keepWords(l),
                          style: const TextStyle(
                            fontSize: 15,
                            color: tossText,
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  keepWords(
                    "깊이를 안 넣은 부품은 빼고 견줬습니다: ${missing.map((e) => "${plateLabel(e.key)} ${e.value}개").join(", ")}. 모듈을 눌러 깊이를 넣으십시오.",
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: tossSubText,
                    height: 1.4,
                  ),
                ),
              ],
              if (!_sidePlatesOn && _cabinetDepth == null) ...[
                const SizedBox(height: 8),
                Text(
                  keepWords("측판을 켜거나 캐비닛 깊이를 넣어야 견줄 것이 있습니다."),
                  style: const TextStyle(fontSize: 14, color: tossSubText),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "닫기",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: tossBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 중판은 예전처럼 맨 위 칸에, 측판은 sidePlates 칸에 적는다.
  Map<String, dynamic> _buildSnapshotJson() {
    final plates = _allPlates();
    final main = plates[kPlateMain]!;
    return {
      'projectId': _currentProjectId,
      'projectName': _projectName,
      for (final k in const [
        'panelWidth',
        'panelHeight',
        'items',
        'dimensions',
        'backgroundImagePath',
        'backgroundOpacity',
      ])
        k: main[k],
      ..._sidePlateFields(plates),
    };
  }

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
    if (_isSkid) 'routes': _routes.map((r) => r.toJson()).toList(),
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
    final routes = snap['routes'];
    if (routes is List) {
      _routes
        ..clear()
        ..addAll([
          for (final r in routes)
            if (r is Map) ConduitRoute.fromJson(Map<String, dynamic>.from(r)),
        ]);
    }
    _activeItem = null;
    _previewItem = null;
    _dimensionStartPoint = null;
  }

  void _undo() {
    // 모듈을 누르기만 해도 편집 전 모습을 한 번 남겨 둔다. 아무것도 안 바꿨으면
    // 그 기록은 지금과 똑같아서 되돌리기를 눌러도 아무 일이 없어 보였다. 그런 기록은 건너뛴다.
    final String now = jsonEncode(_captureUndoState());
    while (_undoStack.isNotEmpty && jsonEncode(_undoStack.last) == now) {
      _undoStack.removeLast();
    }
    if (_undoStack.isEmpty) {
      setState(() {});
      return;
    }
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
                    keepWords("되돌리기 기록 (${_undoStack.length}단계)"),
                    style: const TextStyle(
                      color: tossText,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
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
                      return layoutSheetRow(
                        icon: Icons.history_rounded,
                        label: "$stepsBack단계 전으로 되돌리기",
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
      await prefs.remove(_legacyTabletDraftPrefsKey);
    } catch (_) {}
  }

  void _applySnapshotJson(Map<String, dynamic> data) {
    _currentProjectId = data['projectId'] as String?;
    _projectName = data['projectName'] as String? ?? "";
    _applySidePlateFields(data);
    _panelWidth = (data['panelWidth'] as num?)?.toDouble() ?? _panelWidth;
    _panelHeight = (data['panelHeight'] as num?)?.toDouble() ?? _panelHeight;
    _placedItems
      ..clear()
      ..addAll(layoutItemsFromData(data));
    _dimensions
      ..clear()
      ..addAll(layoutDimensionsFromData(data));
    _backgroundImagePath = data['backgroundImagePath'] as String?;
    _backgroundOpacity = (data['backgroundOpacity'] as num?)?.toDouble() ?? 0.5;
  }

  // 🚀 [추가] 새 도면으로 들어왔을 때(특정 프로젝트를 불러온 게 아닐 때)
  // 이전에 저장 안 하고 나간 임시 작업이 남아있으면 이어할지 물어본다.
  Future<bool> _checkAndOfferDraftRecovery() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getString(_draftPrefsKey) ??
          prefs.getString(_legacyTabletDraftPrefsKey);
      if (raw == null) return false;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return false;
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
                keepWords("저장하지 않고 나간 작업 내용이 있습니다."),
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

      if (!mounted) return false;
      if (resume) {
        setState(() => _applySnapshotJson(data));
      } else {
        await _clearDraftPrefs();
      }
      return resume;
    } catch (_) {
      // 임시 저장 데이터가 깨져있으면 그냥 무시하고 새로 시작한다.
      return false;
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
                  style: const TextStyle(color: warningRed, fontSize: 14),
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
                          fontSize: 14,
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
              fontSize: 14,
            ),
          ),
          Text(
            names.join(', '),
            style: const TextStyle(color: tossSubText, fontSize: 14),
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

      // 측판을 켰으면 좌측판·중판·우측판을 한 장씩 찍는다(판을 바꿔 그린 뒤 찍고 되돌린다).
      final String startPlate = _plateId;
      final Set<String> made = {..._plateStore.keys, _plateId};
      final List<String> plateIds = _isSkid
          ? _tabOrder
                .where((id) => id == kPlateMain || made.contains(id))
                .toList()
          : (_sidePlatesOn ? kPlateOrder : [_plateId]);
      final shots =
          <(String, Uint8List, double, double, List<PlacedDimension>)>[];
      for (final id in plateIds) {
        if (id != _plateId) {
          setState(() => _switchPlate(id));
          await WidgetsBinding.instance.endOfFrame;
          await WidgetsBinding.instance.endOfFrame;
        }
        final bytes = await _capturePng();
        if (bytes == null) throw Exception("도면 캡처 실패");
        shots.add((id, bytes, _panelWidth, _panelHeight, List.of(_dimensions)));
      }
      if (_plateId != startPlate && mounted) {
        setState(() => _switchPlate(startPlate));
      }

      final pdf = pw.Document();
      String qrData = "tubingcalc://layout?project=$_currentProjectId";
      for (final (plateId, imageBytes, plateW, plateH, plateDims) in shots) {
        final image = pw.MemoryImage(imageBytes);
        final String plateName = _isSkid
            ? switch (plateId) {
                kSkidViewFront => "Front View",
                kPlateLeft => "Left View",
                kPlateRight => "Right View",
                _ => "Plan View",
              }
            : switch (plateId) {
                kPlateLeft => "Left Side Plate",
                kPlateRight => "Right Side Plate",
                _ => _sidePlatesOn ? "Main Plate" : "",
              };

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
                            "${plateName.isEmpty ? "" : "$plateName - "}Panel Size: ${plateW.toInt()}mm x ${plateH.toInt()}mm",
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
        if (plateDims.isNotEmpty) {
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
                        ...plateDims.asMap().entries.map((entry) {
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
      // 새 문서일 때만 만든 사람 칸을 붙인다(예전 배치도는 고쳐 저장해도 칸을 붙이지 않는다).
      final LayoutOwner owner = isNew
          ? await loadLayoutOwner()
          : const LayoutOwner();
      final docRef = isNew
          ? FirebaseFirestore.instance.collection('layouts').doc()
          : FirebaseFirestore.instance
                .collection('layouts')
                .doc(_currentProjectId);
      final plates = _allPlates();
      final main = plates[kPlateMain]!;
      await docRef.set({
        ...layoutSaveFields(
          projectId: docRef.id,
          projectName: projectName,
          panelWidth: (main['panelWidth'] as num).toDouble(),
          panelHeight: (main['panelHeight'] as num).toDouble(),
          items: layoutItemsFromData(main),
          dimensions: layoutDimensionsFromData(main),
          backgroundImagePath: main['backgroundImagePath'] as String?,
          backgroundOpacity:
              (main['backgroundOpacity'] as num?)?.toDouble() ?? 0.5,
        ),
        ..._sidePlateFields(plates),
        if (isNew) ...layoutOwnerFields(owner),
        if (isNew) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
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
            labelStyle: const TextStyle(
              color: tossSubText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            floatingLabelStyle: const TextStyle(
              color: tossBlue,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
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
                                fontSize: 14,
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
          ..addAll(layoutItemsFromData(data));
        _dimensions
          ..clear()
          ..addAll(layoutDimensionsFromData(data));
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

  // 가져올 도면 후보: 목록 화면과 같이 내 배치도(만든 사람 칸이 없는 예전 배치도 포함)만,
  // 최근 고친 순. 예전엔 updatedAt으로 서버 정렬을 걸어서 이 칸이 없는 예전 배치도가 빠졌다.
  Future<List<QueryDocumentSnapshot>> _loadImportSources() async {
    final LayoutOwner me = await loadLayoutOwner();
    final snap = await FirebaseFirestore.instance.collection('layouts').get();
    return layoutImportCandidates(
      snap.docs,
      me: me,
      currentId: _currentProjectId,
      dataOf: (d) => d.data() as Map<String, dynamic>,
      idOf: (d) => d.id,
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
                  child: FutureBuilder<List<QueryDocumentSnapshot>>(
                    future: _loadImportSources(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(color: tossBlue),
                          ),
                        );
                      }
                      final docs =
                          snapshot.data ?? const <QueryDocumentSnapshot>[];
                      if (docs.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            keepWords("가져올 수 있는 다른 도면이 없습니다."),
                            style: TextStyle(color: tossSubText, fontSize: 15),
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
                                fontSize: 14,
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
                                fontSize: 14,
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
                        height: 44,
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
                            minimumSize: const Size(40, 40),
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
          shape: src.shape,
          depth: src.depth,
          elevation: src.elevation,
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
      for (var item in _placedItems) {
        item.isSelected = false;
      }

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
        shape: preset.shape,
        depth: preset.depthOrGuess,
      );

      _placedItems.add(newItem);
      _activeItem = newItem;
      _previewItem = null;
    });
    if (!_isWide) _showInspectorBottomSheet(_placedItems.last);
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
    if (_isWide) {
      // 넓은 화면: 오른쪽 편집 칸이 이 모듈을 잡는 시점에 한 번만 되돌리기
      // 기록을 남긴다(이름·크기를 몇 번 고쳐도 되돌리기 한 번으로 돌아가게).
      if (_activeItem?.id != item.id) _pushUndo();
      setState(() {
        for (var i in _placedItems) {
          i.isSelected = false;
        }
        item.isSelected = true;
        _activeItem = item;
      });
      return;
    }
    setState(() {
      for (var i in _placedItems) {
        i.isSelected = false;
      }
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
      // 스키드: 경로 선 가까이를 누르면 그 경로 입력을 연다.
      if (_isSkid) {
        final ConduitRoute? hit = _findRouteNear(localPosition);
        if (hit != null) {
          HapticFeedback.lightImpact();
          _showRouteEditor(hit);
          return;
        }
      }
      setState(() {
        for (var i in _placedItems) {
          i.isSelected = false;
        }
        _activeItem = null;
        _multiSelectedIds = {};
      });
    }
  }

  // 경로 끌기: 선 위에 보이지 않는 손잡이를 토막마다 깔아, 끌면 경로 시작 자리가 옮겨진다.
  ConduitRoute? _draggingRoute;
  Offset? _routeDragLast;

  List<Widget> _buildRouteHandles() {
    final plan = _planItems;
    final (planW, planH) = _planSize;
    final double scale = _viewerController.value.getMaxScaleOnAxis();
    final out = <Widget>[];
    for (final r in _routes) {
      final pts = r
          .points(plan)
          .map(
            (v) => projectToView(
              v,
              _plateId,
              planW: planW,
              planH: planH,
              viewH: _panelHeight,
            ),
          )
          .toList();
      final double th = math.max(24 / (scale <= 0 ? 1 : scale), r.od + 6);
      for (int i = 0; i + 1 < pts.length; i++) {
        final Offset a = pts[i], b = pts[i + 1];
        final double len = (b - a).distance + th;
        if (len <= th) continue;
        final Offset mid = (a + b) / 2;
        out.add(
          Positioned(
            key: ValueKey("route_handle_${r.id}_$i"),
            left: mid.dx - len / 2,
            top: mid.dy - th / 2,
            child: Transform.rotate(
              angle: math.atan2(b.dy - a.dy, b.dx - a.dx),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // 손가락을 댄 자리부터 따라오게(처음 움직인 만큼이 빠지지 않게).
                dragStartBehavior: DragStartBehavior.down,
                onTap: () => _showRouteEditor(r),
                onPanStart: (d) => _startRouteDrag(r, d.globalPosition),
                onPanUpdate: (d) => _updateRouteDrag(d.globalPosition),
                onPanEnd: (_) => _endRouteDrag(),
                child: SizedBox(width: len, height: th),
              ),
            ),
          ),
        );
      }
    }
    return out;
  }

  Offset? _boardLocal(Offset global) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global);
  }

  void _startRouteDrag(ConduitRoute r, Offset global) {
    _pushUndo();
    // 시작 부품에 붙어 있던 경로는 끌면 그 자리(부품 가운데·높이)에서 떨어져 나온다.
    if (r.startItemId != null) {
      final start = r.startPoint(_planItems);
      r
        ..startItemId = null
        ..x = start.x
        ..y = start.y
        ..z = start.z;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            keepWords("경로가 시작 부품에서 떨어졌습니다. 경로를 눌러 시작 부품을 다시 고를 수 있습니다."),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    _draggingRoute = r;
    _routeDragLast = _boardLocal(global);
    HapticFeedback.selectionClick();
  }

  void _updateRouteDrag(Offset global) {
    final r = _draggingRoute;
    final now = _boardLocal(global);
    if (r == null || now == null || _routeDragLast == null) return;
    final Offset d = now - _routeDragLast!;
    _routeDragLast = now;
    setState(() {
      switch (_plateId) {
        case kSkidViewFront:
          r.x += d.dx;
          r.z -= d.dy;
        case kPlateLeft:
          r.y += d.dx;
          r.z -= d.dy;
        case kPlateRight:
          r.y -= d.dx;
          r.z -= d.dy;
        default:
          r.x += d.dx;
          r.y += d.dy;
      }
    });
  }

  void _endRouteDrag() {
    final r = _draggingRoute;
    if (r == null) return;
    double snap(double v) => (v / _gridSize).round() * _gridSize;
    setState(() {
      r
        ..x = snap(r.x)
        ..y = snap(r.y)
        ..z = snap(r.z);
    });
    _draggingRoute = null;
    _routeDragLast = null;
    _saveDraftToPrefs();
  }

  /// 지금 탭에서 [p](도면 mm) 가까이 지나는 경로. 손가락 폭(화면 24px)이나 관 굵기 안이면 잡는다.
  ConduitRoute? _findRouteNear(Offset p) {
    final plan = _planItems;
    final (planW, planH) = _planSize;
    final double scale = _viewerController.value.getMaxScaleOnAxis();
    ConduitRoute? best;
    double bestD = double.infinity;
    for (final r in _routes) {
      final pts = r
          .points(plan)
          .map(
            (v) => projectToView(
              v,
              _plateId,
              planW: planW,
              planH: planH,
              viewH: _panelHeight,
            ),
          )
          .toList();
      final double tol = math.max(24 / (scale <= 0 ? 1 : scale), r.od / 2 + 5);
      for (int i = 0; i + 1 < pts.length; i++) {
        final double d = _distanceToSegment(p, pts[i], pts[i + 1]);
        if (d <= tol && d < bestD) {
          bestD = d;
          best = r;
        }
      }
    }
    return best;
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
                        fontSize: 14,
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
                        fontSize: 14,
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
                        fontSize: 14,
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
                            constraints: const BoxConstraints(
                              minHeight: 48,
                              minWidth: 64,
                            ),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
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
                                fontSize: 14,
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tossText,
                        ),
                      ),
                      subtitle: Text(
                        keepWords("축에 맞추지 않고 실제 직선거리+각도로 표시"),
                        style: TextStyle(fontSize: 14, color: tossSubText),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tossText,
                        ),
                      ),
                      subtitle: Text(
                        keepWords("굵은 선 + 🛡 표시로 다른 치수와 구분"),
                        style: TextStyle(fontSize: 14, color: tossSubText),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
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
                          minimumSize: const Size(40, 40),
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
        constraints: const BoxConstraints(minHeight: 52),
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
            fontSize: 14,
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
          shape: item.shape,
          depth: item.depth,
          elevation: item.elevation,
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
            (acc, i) => acc + i.width,
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
            (acc, i) => acc + i.height,
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
                    labelStyle: const TextStyle(
                      color: tossSubText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    floatingLabelStyle: const TextStyle(
                      color: tossBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
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
                  height: 48,
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
                      minimumSize: const Size(40, 40),
                      backgroundColor: tossBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
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
                      minimumSize: const Size(40, 40),
                      side: const BorderSide(color: layoutLine, width: 1.5),
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
                    height: 48,
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
                        minimumSize: const Size(40, 40),
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
    final TextEditingController depthCtrl = TextEditingController(
      text: _depthText(_isSkid ? item.elevation : item.depth),
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
                              minimumSize: const Size(40, 40),
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
                                  shape: item.shape,
                                  depth: item.depth,
                                  elevation: item.elevation,
                                );
                                _placedItems.add(newItem);
                              });
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context); // 복제 후 창 닫기

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    keepWords("'${item.name}' 모듈을 복사했습니다."),
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
                              minimumSize: const Size(40, 40),
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
                                fontSize: 14,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(40, 40),
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
                                fontSize: 14,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(40, 40),
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
                            fontSize: 14,
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
                            fontSize: 14,
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
                        labelText: "모듈 이름",
                        labelStyle: const TextStyle(
                          color: tossSubText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        floatingLabelStyle: const TextStyle(
                          color: tossBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
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
                    const SizedBox(height: 16),
                    _buildCoordinateInput(
                      _isSkid
                          ? "바닥에서 높이 (mm, 부품 가운데까지)"
                          : "깊이 (mm, 판에서 앞으로 튀어나온 길이)",
                      depthCtrl.text,
                      (val) {
                        setState(() {
                          if (_isSkid) {
                            item.elevation = _parseDepth(val);
                          } else {
                            item.depth = _parseDepth(val);
                          }
                        });
                      },
                      controller: depthCtrl,
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
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _dimensions.removeWhere(
                              (dim) =>
                                  dim.p1.id == item.id || dim.p2.id == item.id,
                            );
                            _placedItems.remove(item);
                            if (_dimensionStartPoint?.id == item.id) {
                              _dimensionStartPoint = null;
                            }
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
                          minimumSize: const Size(40, 40),
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
      if (!mounted) return;
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
                              fontSize: 14,
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
                              minimumSize: const Size(40, 40),
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
                                minimumSize: const Size(40, 40),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: tossText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 14,
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
                  style: TextStyle(fontSize: 14, color: tossSubText),
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
                      separatorBuilder: (_, _) =>
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
                        fontSize: 14,
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
                          minimumSize: const Size(40, 40),
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
                          minimumSize: const Size(40, 40),
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
                  height: 48,
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
                      minimumSize: const Size(40, 40),
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

  bool get _isWide => layoutBoardUsesWideLayout(MediaQuery.sizeOf(context));

  // 폭이 바뀌어 모양이 넘어가는 순간(폴드 펴기·접기, 화면 돌리기) 처리.
  // 배치·치수·되돌리기 기록 같은 작업 내용은 이 State에 그대로 있으니
  // 건드리지 않고, 화면에만 붙어 있던 것(선택 표시, 확대 위치)만 정리한다.
  void _onLayoutShapeChanged(bool wide) {
    _viewerController.value = Matrix4.identity();
    _viewportSize = null;
    if (!wide) {
      // 좁은 화면에는 오른쪽 편집 칸이 없으니 선택만 풀어 둔다.
      _activeItem = null;
      for (final i in _placedItems) {
        i.isSelected = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = _isWide;
    if (_lastWide != null && _lastWide != wide) _onLayoutShapeChanged(wide);
    _lastWide = wide;
    _problemIds = _sidePlatesOn || _cabinetDepth != null
        ? _clashReport().problemIds(_plateId)
        : const {};

    return Scaffold(
      backgroundColor: tossBg,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLeftSidebar(),
                Expanded(
                  child: Column(
                    children: [
                      _buildWideModeBar(),
                      if (_showTabs) _buildPlateTabs(),
                      Expanded(child: _buildBoardCanvas(wide)),
                    ],
                  ),
                ),
                _buildRightInspector(),
              ],
            )
          else
            Column(
              children: [
                if (_showTabs) _buildPlateTabs(),
                Expanded(child: _buildBoardCanvas(wide)),
                // 하단 컨트롤 패널
                _buildBottomPanel(),
              ],
            ),
          _buildMultiSelectBar(wide),
          // 🚀 [신규] 미니맵 - 확대해서 작업 중일 때 전체 도면에서 지금
          // 보고 있는 위치를 놓치지 않도록 구석에 작게 띄운다.
          if (_placedItems.isNotEmpty && _viewportSize != null)
            Positioned(
              top: (wide ? 96 : 12) + (_showTabs ? 48 : 0),
              right: wide ? _kWideInspectorWidth + 12 : 12,
              child: (_minimapOpen ?? wide)
                  ? Tooltip(
                      message: "미니맵 접기",
                      child: GestureDetector(
                        onTap: () => setState(() => _minimapOpen = false),
                        child: _buildMinimap(),
                      ),
                    )
                  : _buildMinimapButton(),
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

  // 위 막대: 자주 쓰는 것(되돌리기·다시 실행·저장)만 둔다. 나머지는 "더보기"
  // 바텀시트에 모으고, 전체 지우기 같은 위험한 것은 그 안에서도 따로 떼어 확인을 받는다.
  PreferredSizeWidget _buildAppBar() {
    final bool canUndo = _undoStack.isNotEmpty;
    final bool canRedo = _redoStack.isNotEmpty;
    // 폰 폭에서는 저장 단추를 아이콘만 두어 제목 자리를 넓힌다.
    final bool narrowBar = MediaQuery.of(context).size.width < 600;
    return AppBar(
      backgroundColor: tossBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      centerTitle: false,
      titleSpacing: 0,
      leadingWidth: 52,
      shape: const Border(bottom: BorderSide(color: layoutLine)),
      leading: IconButton(
        tooltip: "뒤로",
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: tossText,
          size: 22,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      // 제목은 배치도 이름 하나만 쓴다. 폰 폭은 단추 넷이 자리를 차지하므로
      // 두 줄까지 접어서 이름이 잘리지 않게 한다.
      title: Text(
        _projectName.isNotEmpty ? _projectName : "작업 배치도",
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: tossText,
          fontSize: narrowBar ? 16 : 18,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          height: 1.2,
        ),
      ),
      actions: [
        // 길게 누르면 되돌리기 기록이 열린다. 같은 것을 "더보기"에서도 연다.
        GestureDetector(
          onLongPress: canUndo ? _showUndoHistorySheet : null,
          child: IconButton(
            tooltip: "되돌리기",
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: canUndo ? _undo : null,
            icon: Icon(
              Icons.undo_rounded,
              size: 24,
              color: canUndo ? tossText : tossSubText.withValues(alpha: 0.35),
            ),
          ),
        ),
        IconButton(
          tooltip: "다시 실행",
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: canRedo ? _redo : null,
          icon: Icon(
            Icons.redo_rounded,
            size: 24,
            color: canRedo ? tossText : tossSubText.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(width: 4),
        if (_isSaving)
          const SizedBox(
            width: 76,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: tossBlue,
                ),
              ),
            ),
          )
        else if (narrowBar)
          Tooltip(
            message: "저장·공유",
            child: SizedBox(
              width: 44,
              height: 44,
              child: FilledButton(
                onPressed: _showSaveActionSheet,
                style: FilledButton.styleFrom(
                  backgroundColor: tossBlue,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(
                  Icons.save_alt_rounded,
                  size: 22,
                  color: pureWhite,
                ),
              ),
            ),
          )
        else
          Tooltip(
            message: "저장·공유",
            child: FilledButton.icon(
              onPressed: _showSaveActionSheet,
              style: FilledButton.styleFrom(
                backgroundColor: tossBlue,
                minimumSize: const Size(72, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.save_alt_rounded,
                size: 20,
                color: pureWhite,
              ),
              label: const Text(
                "저장",
                style: TextStyle(
                  color: pureWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        IconButton(
          tooltip: "더보기",
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: _showMoreSheet,
          icon: const Icon(Icons.more_vert_rounded, color: tossText, size: 24),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // 위 막대 "더보기": 자주 안 쓰는 것을 묶어 둔 바텀시트.
  // 맨 아래 빨간 칸의 전체 지우기는 한 번 더 묻고 지운다(되돌리기로도 돌아온다).
  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        void run(VoidCallback action) {
          Navigator.pop(ctx);
          action();
        }

        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              maxWidth: 560,
            ),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tossBg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _moreSection("도면", [
                    layoutSheetRow(
                      icon: Icons.aspect_ratio_rounded,
                      label: _isSkid ? "스키드 크기 (길이 × 폭)" : "외함 사이즈 설정",
                      caption:
                          "${_showTabs ? "${_tabLabel(_plateId)} " : ""}지금 ${_panelWidth.toInt()} × ${_panelHeight.toInt()} mm",
                      onTap: () => run(_showPanelSettingsSheet),
                    ),
                    if (!_isSkid) ...[
                      layoutSheetRow(
                        icon: Icons.view_column_outlined,
                        label: "좌·우 측판",
                        caption: _sidePlatesOn
                            ? "켜짐 · 위 탭으로 판을 바꿉니다"
                            : "꺼짐 · 켜면 측판에 전기 부품을 따로 배치합니다",
                        onTap: () => run(_toggleSidePlates),
                      ),
                      layoutSheetRow(
                        icon: Icons.layers_outlined,
                        label: "측판·깊이 설정",
                        caption: _cabinetDepth == null
                            ? "캐비닛 깊이·측판 높이 차"
                            : "캐비닛 깊이 ${_cabinetDepth!.toInt()} mm",
                        onTap: () => run(_showCabinetSettingsSheet),
                      ),
                      layoutSheetRow(
                        icon: Icons.warning_amber_rounded,
                        label: "간섭 확인",
                        caption: "중판·측판 부품이 부딪히는지, 문보다 깊은지",
                        onTap: () => run(_showClashSheet),
                      ),
                    ],
                    layoutSheetRow(
                      icon: Icons.image_outlined,
                      label: "배경 사진",
                      caption: _backgroundImagePath != null ? "깔려 있습니다" : null,
                      onTap: () => run(_showBackgroundSheet),
                    ),
                    layoutSheetRow(
                      icon: Icons.inventory_2_outlined,
                      label: "자재 수량",
                      onTap: () => run(_showMaterialSummarySheet),
                    ),
                    layoutSheetRow(
                      icon: Icons.palette_outlined,
                      label: "색상 범례",
                      onTap: () => run(_showColorLegendDialog),
                    ),
                  ]),
                  _moreSection("기록", [
                    layoutSheetRow(
                      icon: Icons.history_rounded,
                      label: "되돌리기 기록",
                      caption: _undoStack.isEmpty
                          ? "되돌릴 것이 없습니다"
                          : "${_undoStack.length}단계까지 골라서 한 번에 되돌립니다",
                      onTap: _undoStack.isEmpty
                          ? null
                          : () => run(_showUndoHistorySheet),
                    ),
                  ]),
                  _moreSection("템플릿", [
                    layoutSheetRow(
                      icon: Icons.bookmark_add_outlined,
                      label: "템플릿으로 저장",
                      onTap: () => run(_saveAsTemplate),
                    ),
                    layoutSheetRow(
                      icon: Icons.library_books_outlined,
                      label: "템플릿 불러오기",
                      onTap: () => run(_showTemplateLibrarySheet),
                    ),
                    layoutSheetRow(
                      icon: Icons.move_down_outlined,
                      label: "다른 도면에서 모듈 가져오기",
                      onTap: () => run(_showImportModulesFlow),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // 위험한 것은 따로 뗀 빨간 칸에 둔다.
                  Container(
                    decoration: BoxDecoration(
                      color: pureWhite,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: warningRed.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        layoutSheetRow(
                          icon: Icons.straighten_rounded,
                          label: "치수선 전체 지우기",
                          danger: true,
                          onTap: _dimensions.isEmpty
                              ? null
                              : () => run(_confirmClearDimensions),
                        ),
                        const Divider(height: 1, color: layoutLine),
                        layoutSheetRow(
                          icon: Icons.delete_sweep_outlined,
                          label: "도면 전체 지우기",
                          caption: "모듈과 치수선을 모두 지웁니다",
                          danger: true,
                          onTap: _hasAnyContent
                              ? () => run(_confirmClearBoard)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _moreSection(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: tossSubText,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            decoration: layoutCardDecoration(),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: layoutLine),
                  rows[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearBoard() async {
    final ok = await confirmLayoutDanger(
      context,
      title: "도면 전체 지우기",
      message:
          "모듈 ${_placedItems.length}개와 치수선 ${_dimensions.length}개를 모두 지웁니다. 지운 뒤에도 되돌리기로 돌아올 수 있습니다.",
      confirmLabel: "전체 지우기",
    );
    if (ok && mounted) _clearBoard();
  }

  Future<void> _confirmClearDimensions() async {
    final ok = await confirmLayoutDanger(
      context,
      title: "치수선 전체 지우기",
      message:
          "치수선 ${_dimensions.length}개를 모두 지웁니다. 모듈은 그대로 둡니다. 지운 뒤에도 되돌리기로 돌아올 수 있습니다.",
      confirmLabel: "전체 지우기",
    );
    if (!ok || !mounted) return;
    _pushUndo();
    setState(() {
      _dimensions.clear();
      _dimensionStartPoint = null;
      _dimensionsVersion++;
    });
  }

  // 도면(확대·이동, 모듈 끌어 놓기, 치수 찍기). 좁은 화면·넓은 화면이 같이 쓴다.
  Widget _buildBoardCanvas(bool wide) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 🚀 [신규] 미니맵에서 "지금 보고 있는 영역"을
        // 계산하려면 뷰포트의 실제 화면 크기가 필요하다.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _viewportSize != constraints.biggest) {
            setState(() => _viewportSize = constraints.biggest);
          }
          if (mounted && _fitPending && _viewportSize != null) {
            _fitPending = false;
            setState(_fitBoardToView);
          }
        });
        return InteractiveViewer(
          key: _viewerKey,
          transformationController: _viewerController,
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
                  shape: details.data.shape,
                );
              });
            },
            onLeave: (data) => setState(() => _previewItem = null),
            onAcceptWithDetails: (details) {
              final RenderBox box =
                  _boardKey.currentContext!.findRenderObject() as RenderBox;
              _onAcceptItem(details.data, box.globalToLocal(details.offset));
            },
            builder: (context, candidateData, rejectedData) {
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  GestureDetector(
                    onTapUp: (details) => _onTapBoard(details.localPosition),
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
                            if (_backgroundImagePath != null &&
                                File(_backgroundImagePath!).existsSync())
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
                                panelWidth: _panelWidth,
                                panelHeight: _panelHeight,
                                version: _dimensionsVersion,
                              ),
                            ),
                            if (_isSkid) _buildSkidOverlay(),
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

                            if (_isSkid && _mode == BoardMode.placeModule)
                              ..._buildRouteHandles(),
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
                                left: item.position.dx - _kTouchHitPad,
                                top: item.position.dy - _kTouchHitPad,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanStart: canDrag
                                      ? (details) {
                                          // 드래그 한 번 = undo 한 단계
                                          // (onPanUpdate마다 쌓으면 되돌리기가
                                          // 프레임 단위로 쪼개져 버린다).
                                          final bool isGroupDrag =
                                              _multiSelectMode &&
                                              _multiSelectedIds.contains(
                                                item.id,
                                              ) &&
                                              _multiSelectedIds.length > 1;
                                          _pushUndo();
                                          setState(() {
                                            _dragRawPosition = item.position;
                                            _activeItem = item;
                                            if (isGroupDrag) {
                                              _groupDragAnchorOrigin =
                                                  item.position;
                                              _groupDragOrigins = {
                                                for (final i in _placedItems)
                                                  if (_multiSelectedIds
                                                      .contains(i.id))
                                                    i.id: i.position,
                                              };
                                              double minX = double.infinity;
                                              double minY = double.infinity;
                                              double maxRight =
                                                  -double.infinity;
                                              double maxBottom =
                                                  -double.infinity;
                                              for (final i in _placedItems) {
                                                if (!_multiSelectedIds.contains(
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
                                                  i.position.dx + i.width,
                                                );
                                                maxBottom = math.max(
                                                  maxBottom,
                                                  i.position.dy + i.height,
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
                                              _groupDragAnchorOrigin = null;
                                              _groupDragOrigins = {};
                                              _groupOriginBounds = null;
                                              if (!_multiSelectMode) {
                                                for (var i in _placedItems) {
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
                                            _dragRawPosition += details.delta;
                                            final bool isGroupDrag =
                                                _groupDragOrigins.isNotEmpty &&
                                                _groupDragOrigins.containsKey(
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
                                              final Offset rawDelta =
                                                  _dragRawPosition -
                                                  _groupDragAnchorOrigin!;
                                              final double minDx = -bounds.left;
                                              double maxDx =
                                                  _panelWidth - bounds.right;
                                              if (maxDx < minDx) {
                                                maxDx = minDx;
                                              }
                                              final double minDy = -bounds.top;
                                              double maxDy =
                                                  _panelHeight - bounds.bottom;
                                              if (maxDy < minDy) {
                                                maxDy = minDy;
                                              }
                                              final Offset
                                              clampedDelta = Offset(
                                                rawDelta.dx.clamp(minDx, maxDx),
                                                rawDelta.dy.clamp(minDy, maxDy),
                                              );
                                              final Offset snappedDelta =
                                                  _snapToGrid(clampedDelta);
                                              // 🚀 [버그 수정] 그룹
                                              // 전체를 이 delta만큼
                                              // 옮겼을 때 선택되지
                                              // 않은 다른 모듈과
                                              // 겹치면 이번 프레임의
                                              // 이동은 통째로
                                              // 취소한다(그룹끼리는
                                              // 서로 겹침 검사에서
                                              // 제외).
                                              bool wouldCollide = false;
                                              for (final entry
                                                  in _groupDragOrigins
                                                      .entries) {
                                                final PlacedItem it =
                                                    _placedItems.firstWhere(
                                                      (x) => x.id == entry.key,
                                                    );
                                                final Offset newPos =
                                                    entry.value + snappedDelta;
                                                if (_overlapsAny(
                                                  it,
                                                  newPos,
                                                  excludeIds: _multiSelectedIds,
                                                )) {
                                                  wouldCollide = true;
                                                  break;
                                                }
                                              }
                                              if (wouldCollide) {
                                                return;
                                              }
                                              for (final i in _placedItems) {
                                                if (!_multiSelectedIds.contains(
                                                      i.id,
                                                    ) ||
                                                    i.isLocked) {
                                                  continue;
                                                }
                                                final Offset? origin =
                                                    _groupDragOrigins[i.id];
                                                if (origin == null) {
                                                  continue;
                                                }
                                                i.position =
                                                    origin + snappedDelta;
                                              }
                                            } else {
                                              double clampedX = _dragRawPosition
                                                  .dx
                                                  .clamp(
                                                    0.0,
                                                    math.max(
                                                      0.0,
                                                      _panelWidth - item.width,
                                                    ),
                                                  );
                                              double clampedY = _dragRawPosition
                                                  .dy
                                                  .clamp(
                                                    0.0,
                                                    math.max(
                                                      0.0,
                                                      _panelHeight -
                                                          item.height,
                                                    ),
                                                  );
                                              final gridSnapped = _snapToGrid(
                                                Offset(clampedX, clampedY),
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
                                              final aligned = _snapToAlignment(
                                                item,
                                                gridSnapped,
                                              );
                                              final Offset xOnly = Offset(
                                                aligned.dx,
                                                item.position.dy,
                                              );
                                              if (!_overlapsAny(item, xOnly)) {
                                                item.position = xOnly;
                                              }
                                              final Offset yOnly = Offset(
                                                item.position.dx,
                                                aligned.dy,
                                              );
                                              if (!_overlapsAny(item, yOnly)) {
                                                item.position = yOnly;
                                              }
                                            }
                                          });
                                        }
                                      : null,
                                  onPanEnd: canDrag
                                      ? (details) {
                                          setState(() {
                                            // 넓은 화면에서는 오른쪽 칸이 이 모듈을 계속 보여 주도록 선택을 남긴다.
                                            if (!wide) _activeItem = null;
                                            _alignGuideX = null;
                                            _alignGuideY = null;
                                            _groupDragAnchorOrigin = null;
                                            _groupDragOrigins = {};
                                            _groupOriginBounds = null;
                                          });
                                        }
                                      : null,
                                  onTap: () => _onTapItem(item),
                                  child: Container(
                                    width: item.width + _kTouchHitPad * 2,
                                    height: item.height + _kTouchHitPad * 2,
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
                                              padding: const EdgeInsets.all(3),
                                              decoration: const BoxDecoration(
                                                color: tossText,
                                                shape: BoxShape.circle,
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
                                        Icons.dashboard_customize_outlined,
                                        size: 36,
                                        color: tossSubText.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        keepWords(
                                          wide
                                              ? "왼쪽에서 모듈을 끌어다\n놓아 배치를 시작하십시오"
                                              : "아래에서 모듈을 끌어다\n놓아 배치를 시작하십시오",
                                        ),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: tossSubText.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontSize: 14,
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
                                          "샘플 배치 불러오기",
                                          style: TextStyle(
                                            color: tossBlue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(40, 40),
                                          side: const BorderSide(
                                            color: tossBlue,
                                          ),
                                          backgroundColor: pureWhite,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
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
    );
  }

  // 좁은 화면 아래 칸: 전선관 계산기 입력 칸처럼 흰 판 위에 모드 전환과 도구.
  Widget _buildBottomPanel() {
    // 폰을 가로로 눕히면 세로가 짧아 도면이 안 보일 수 있어, 아래 칸은 화면 높이의
    // 절반까지만 쓰고 넘치는 부분은 위아래로 굴린다.
    final double maxH = MediaQuery.sizeOf(context).height * 0.5;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildModeSegmentedControl(),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: switch (_mode) {
                    BoardMode.measureDimension => _buildDimensionToolBar(),
                    BoardMode.placeModule => _buildModulePalette(),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 넓은 화면 도면 위쪽: 모드 전환만 둔다(안내선·여러 개 선택은 왼쪽 칸에 있다).
  Widget _buildWideModeBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: tossBg,
        border: Border(bottom: BorderSide(color: layoutLine)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _buildModeSegmentedControl(),
        ),
      ),
    );
  }

  // 🚀 [신규] 다중 선택 도구모음 - 2개 이상 선택 시 그룹 이동/
  // 복제/잠금/정렬/삭제를 한 번에 할 수 있게 하단에 띄운다.
  // 🚀 [개선] 선택하는 순간 뚝 나타나던 걸 부드럽게 슬라이드 인/
  // 아웃 되도록 항상 트리에 두고 위치만 애니메이션한다.
  Widget _buildMultiSelectBar(bool wide) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: wide ? _kWideSidebarWidth : 0,
      right: wide ? _kWideInspectorWidth : 0,
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
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
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
                            margin: const EdgeInsets.symmetric(horizontal: 4),
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
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: "선택 해제",
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
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
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftSidebar() {
    return Container(
      width: _kWideSidebarWidth,
      decoration: const BoxDecoration(
        color: pureWhite,
        border: Border(right: BorderSide(color: layoutLine)),
      ),
      // 칸이 길어져도 넘치지 않게 세로로 굴린다. 모듈은 옆(도면 쪽)으로 끌 때만
      // 집히게(affinity: 가로) 해서, 위아래로 밀면 칸이 굴러가고 옆으로 밀면 모듈이 끌린다.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "자재 라이브러리",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: tossText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              keepWords("오른쪽 도면으로 끌어다 놓습니다. 놓은 모듈을 누르면 오른쪽 칸에서 이름과 크기를 고칩니다."),
              style: const TextStyle(
                color: tossSubText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _dragTile(
              const ModulePreset("신규 모듈", 80, 80),
              (_) => _buildPaletteItem("신규 박스 모듈", large: true),
              affinity: Axis.horizontal,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _panelLabel("ABS 덕트 (폭×높이)")),
                TextButton(
                  onPressed: () => _showPresetSheet(
                    title: "덕트 놓기",
                    help:
                        "폭×높이(mm)입니다. 도면에는 폭만큼 놓이고, 길이는 놓은 뒤 세로 칸에서 고칩니다. 누르면 지금 보이는 도면 가운데에 놓습니다.",
                    groups: kDuctPresetGroups,
                  ),
                  child: const Text(
                    "크기 전부",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 🚀 ABS 배선덕트 - 폭이 정해진 자재라 배치 후 크기를 손으로 고칠
            // 필요 없이 원하는 폭을 바로 끌어다 놓는다(참고용 명목 폭,
            // kDuctPresets 주석 참고).
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in kDuctPresets)
                  _dragTile(
                    preset,
                    (_) => _buildDuctChip(preset, width: 104),
                    affinity: Axis.horizontal,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isSkid) ...[
              _panelLabel("스키드"),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _showRoutesSheet,
                icon: const Icon(Icons.route_rounded, size: 20),
                label: const Text(
                  "전선관 경로",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 6),
              for (final e in [
                ("형강", "형강 놓기", kSkidSteelPresets),
                ("정션박스", "정션박스 놓기", kSkidJbPresets),
              ]) ...[
                OutlinedButton(
                  onPressed: () => _openSkidSheet(e.$2, e.$3),
                  child: Text(
                    e.$1,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 14),
            ],
            OutlinedButton.icon(
              onPressed: _openElecSheet,
              icon: const Icon(Icons.electrical_services_rounded, size: 20),
              label: const Text(
                "전기 부품 (단자대·차단기·전원)",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 14),
            _panelLabel("밸브·피팅"),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openValveSheet,
                    icon: const Icon(Icons.tune_rounded, size: 20),
                    label: const Text(
                      "밸브",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openFittingSheet,
                    icon: const Icon(Icons.plumbing_rounded, size: 20),
                    label: const Text(
                      "피팅",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _panelLabel("계기 (정면 크기, 브래킷 빼고)"),
            for (final brand in kInstrumentPresets.entries) ...[
              const SizedBox(height: 10),
              Text(
                brand.key,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tossText,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in brand.value)
                    _dragTile(
                      preset,
                      (_) => _buildInstrumentChip(preset, width: 228),
                      affinity: Axis.horizontal,
                    ),
                ],
              ),
            ],
            if (_customPresets.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildPresetArea(wide: true),
            ],
            const SizedBox(height: 20),
            const Divider(height: 1, color: layoutLine),
            const SizedBox(height: 16),
            _panelLabel("끌 때 보이는 가상선"),
            const SizedBox(height: 8),
            _toolToggle(
              icon: Icons.center_focus_strong_rounded,
              label: "센터선",
              selected: _showCenterGuide,
              color: guideCenterColor,
              onTap: () => setState(() => _showCenterGuide = !_showCenterGuide),
            ),
            const SizedBox(height: 8),
            _toolToggle(
              icon: Icons.border_outer_rounded,
              label: "외곽선",
              selected: _showEdgeGuide,
              color: edgeDimColor,
              onTap: () => setState(() => _showEdgeGuide = !_showEdgeGuide),
            ),
            const SizedBox(height: 16),
            _panelLabel("선택"),
            const SizedBox(height: 8),
            _buildMultiSelectToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildRightInspector() {
    final PlacedItem? item = _activeItem;
    // 이름 칸은 모듈이 바뀔 때만 새로 만든다(그릴 때마다 만들면 고치던 글자 자리가 튄다).
    if (item != null && _inspectorNameFor != item.id) {
      _inspectorNameFor = item.id;
      _inspectorNameCtrl.text = item.name;
    }
    final bool measuring = _mode == BoardMode.measureDimension;
    return Container(
      width: _kWideInspectorWidth,
      decoration: const BoxDecoration(
        color: pureWhite,
        border: Border(left: BorderSide(color: layoutLine)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              measuring ? "치수 재기" : "모듈 편집",
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: tossText,
              ),
            ),
            const SizedBox(height: 12),
            if (measuring)
              _buildDimensionInspector()
            else if (item == null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: tossBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  keepWords("도면에서 모듈을 누르면 여기서 이름·크기·위치를 고칩니다."),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: tossSubText,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              )
            else ...[
              _panelLabel("모듈 이름"),
              const SizedBox(height: 8),
              TextField(
                controller: _inspectorNameCtrl,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: tossText,
                ),
                decoration: _inspectorFieldDecoration(),
                onChanged: (val) =>
                    setState(() => item.name = val.isEmpty ? "이름 없음" : val),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _inspectorButton(
                      icon: Icons.rotate_90_degrees_cw_rounded,
                      label: "90° 회전",
                      onTap: () => _rotateItem(item),
                      accent: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _inspectorButton(
                      icon: Icons.content_copy_rounded,
                      label: "복제",
                      onTap: () => _duplicateItem(item),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _panelLabel("크기 (mm)"),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildInspectorInput(
                      "가로",
                      fieldKey: ValueKey("${item.id}_가로"),
                      item.width.toInt().toString(),
                      (val) {
                        _pushUndo();
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
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInspectorInput(
                      "세로",
                      fieldKey: ValueKey("${item.id}_세로"),
                      item.height.toInt().toString(),
                      (val) {
                        _pushUndo();
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
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInspectorInput(
                _isSkid ? "바닥에서 높이 (가운데까지)" : "깊이 (앞으로 튀어나온 길이)",
                fieldKey: ValueKey("${item.id}_${_isSkid ? "높이" : "깊이"}"),
                _depthText(_isSkid ? item.elevation : item.depth),
                (val) {
                  _pushUndo();
                  setState(() {
                    if (_isSkid) {
                      item.elevation = _parseDepth(val);
                    } else {
                      item.depth = _parseDepth(val);
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              _panelLabel("위치 (mm, 왼쪽 위 기준)"),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildInspectorInput(
                      "X",
                      fieldKey: ValueKey("${item.id}_X"),
                      item.position.dx.toInt().toString(),
                      (val) {
                        _pushUndo();
                        setState(() {
                          final double newX = double.tryParse(val) ?? 0;
                          item.position = Offset(
                            newX.clamp(
                              0.0,
                              math.max(0.0, _panelWidth - item.width),
                            ),
                            item.position.dy,
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInspectorInput(
                      "Y",
                      fieldKey: ValueKey("${item.id}_Y"),
                      item.position.dy.toInt().toString(),
                      (val) {
                        _pushUndo();
                        setState(() {
                          final double newY = double.tryParse(val) ?? 0;
                          item.position = Offset(
                            item.position.dx,
                            newY.clamp(
                              0.0,
                              math.max(0.0, _panelHeight - item.height),
                            ),
                          );
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _inspectorButton(
                icon: Icons.star_border_rounded,
                label: "이 크기를 내 프리셋으로 저장",
                onTap: () {
                  _saveAsCustomPreset(item.name, item.width, item.height);
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(keepWords("내 프리셋에 저장했습니다.")),
                      backgroundColor: tossText,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              // 위치가 정해진 모듈을 잠가서 잘못 끌려 옮겨지지 않게 한다.
              _inspectorButton(
                icon: item.isLocked
                    ? Icons.lock_rounded
                    : Icons.lock_open_rounded,
                label: item.isLocked ? "잠금 풀기" : "이 모듈 위치 잠그기",
                onTap: () {
                  setState(() => item.isLocked = !item.isLocked);
                  HapticFeedback.lightImpact();
                },
              ),
              const SizedBox(height: 8),
              // 레이어 순서(앞/뒤): 목록 맨 뒤에 있을수록 맨 위에 그려진다.
              Row(
                children: [
                  Expanded(
                    child: _inspectorButton(
                      icon: Icons.flip_to_front_rounded,
                      label: "맨 앞으로",
                      onTap: () {
                        _pushUndo();
                        setState(() {
                          _placedItems.remove(item);
                          _placedItems.add(item);
                        });
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _inspectorButton(
                      icon: Icons.flip_to_back_rounded,
                      label: "맨 뒤로",
                      onTap: () {
                        _pushUndo();
                        setState(() {
                          _placedItems.remove(item);
                          _placedItems.insert(0, item);
                        });
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 모듈 하나 지우기는 되돌리기로 돌아오므로 따로 묻지 않는다.
              _inspectorButton(
                icon: Icons.delete_outline_rounded,
                label: "모듈 삭제",
                danger: true,
                onTap: () {
                  _pushUndo();
                  setState(() {
                    _dimensions.removeWhere(
                      (dim) => dim.p1.id == item.id || dim.p2.id == item.id,
                    );
                    _placedItems.remove(item);
                    if (_dimensionStartPoint?.id == item.id) {
                      _dimensionStartPoint = null;
                    }
                    _activeItem = null;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDimensionInspector() {
    final bool isCenter = _currentDimType == DimensionType.center;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panelLabel("재는 기준"),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _toolToggle(
                icon: Icons.center_focus_strong_rounded,
                label: "센터 기준",
                selected: isCenter,
                color: centerDimColor,
                onTap: () =>
                    setState(() => _currentDimType = DimensionType.center),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _toolToggle(
                icon: Icons.border_outer_rounded,
                label: "측면 기준",
                selected: !isCenter,
                color: edgeDimColor,
                onTap: () =>
                    setState(() => _currentDimType = DimensionType.edge),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // 체인: 점을 계속 이어 누르면 치수선이 이어진다.
            Expanded(
              child: _toolToggle(
                icon: Icons.link_rounded,
                label: "체인",
                selected: _dimensionChainMode,
                color: tossBlue,
                onTap: () =>
                    setState(() => _dimensionChainMode = !_dimensionChainMode),
              ),
            ),
            const SizedBox(width: 8),
            // 대각선: 축에 맞추지 않고 두 점을 곧게 잇는다(거리+각도).
            Expanded(
              child: _toolToggle(
                icon: Icons.turn_slight_right_rounded,
                label: "대각선",
                selected: _dimensionDiagonalMode,
                color: diagonalDimColor,
                onTap: () => setState(
                  () => _dimensionDiagonalMode = !_dimensionDiagonalMode,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tossBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            keepWords(_dimensionHint()),
            style: TextStyle(
              color: _dimensionStartPoint == null
                  ? tossSubText
                  : (isCenter ? centerDimColor : edgeDimColor),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ),
        // 첫 지점을 잘못 찍었을 때 두 번째 지점을 억지로 찍지 않고 취소한다.
        if (_dimensionStartPoint != null) ...[
          const SizedBox(height: 8),
          _inspectorButton(
            icon: Icons.undo_rounded,
            label: "첫 지점 취소",
            onTap: () => setState(() => _dimensionStartPoint = null),
          ),
        ],
        if (_dimensions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            "배치된 치수선 ${_dimensions.length}개",
            style: const TextStyle(
              color: tossText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            keepWords("치수선을 누르면 지우기·기준 바꾸기·메모를 합니다. 전체 지우기는 위 막대 더보기에 있습니다."),
            style: const TextStyle(
              color: tossSubText,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  // 치수 재기 안내 한 줄(좁은 화면 아래 칸과 넓은 화면 오른쪽 칸이 같이 쓴다).
  String _dimensionHint() {
    if (_dimensionStartPoint != null) return "다음 지점을 누르면 치수선이 이어집니다.";
    if (_dimensionChainMode) return "체인: 지점을 계속 누르면 이어서 잽니다.";
    return "잴 두 지점(모듈 또는 벽면)을 차례로 누르십시오. 치수선을 누르면 고칩니다.";
  }

  // 모듈 이름 밑 한 줄: 캐비닛은 깊이, 스키드는 바닥에서 높이.
  String? _itemCaption(PlacedItem item) {
    final double? v = _isSkid ? item.elevation : item.depth;
    if (v == null) return null;
    return "${_isSkid ? "높이" : "깊이"} ${v.toInt()}";
  }

  // 깊이 칸: 빈칸이면 모름(null), 숫자면 mm.
  String _depthText(double? d) => d == null
      ? ""
      : (d == d.roundToDouble() ? d.toInt().toString() : d.toString());
  double? _parseDepth(String v) {
    final d = double.tryParse(v.trim());
    return d == null || d <= 0 ? null : d;
  }

  Widget _buildInspectorInput(
    String label,
    String value,
    Function(String) onChanged, {
    Key? fieldKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: tossSubText,
          ),
        ),
        const SizedBox(height: 6),
        // 모듈마다 칸을 새로 만든다(치던 값이 다른 모듈로 넘어가지 않게).
        _InspectorNumberField(
          key: fieldKey,
          value: value,
          onCommit: onChanged,
          decoration: _inspectorFieldDecoration(),
        ),
      ],
    );
  }

  InputDecoration _inspectorFieldDecoration() => InputDecoration(
    filled: true,
    fillColor: tossBg,
    isDense: false,
    constraints: const BoxConstraints(minHeight: 52),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: layoutLine),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: layoutLine),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: tossBlue, width: 2),
    ),
  );

  // 오른쪽 칸 단추(높이 48 이상, 글씨 15).
  Widget _inspectorButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool danger = false,
    bool accent = false,
  }) {
    final Color fg = danger ? warningRed : (accent ? tossBlue : tossText);
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22, color: fg),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(40, 40),
          backgroundColor: accent
              ? tossBlue.withValues(alpha: 0.08)
              : pureWhite,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          side: BorderSide(
            color: danger
                ? warningRed
                : (accent ? tossBlue.withValues(alpha: 0.4) : layoutLine),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiBarIcon(
    IconData icon,
    VoidCallback? onPressed, {
    Color color = pureWhite,
    String? tooltip,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(
        icon,
        color: onPressed == null ? color.withValues(alpha: 0.3) : color,
        size: 26,
      ),
    );
  }

  // 잠금·정렬처럼 아이콘만으로는 뜻이 바로 오지 않는 것에 짧은 글을 붙인다.
  Widget _buildMultiBarLabeledIcon(
    IconData icon,
    String label,
    VoidCallback? onPressed,
  ) {
    final bool enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: enabled ? pureWhite : pureWhite.withValues(alpha: 0.3),
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: enabled
                      ? pureWhite.withValues(alpha: 0.9)
                      : pureWhite.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🚀 [신규] 미니맵 - 전체 도면을 축소해서 보여주고, InteractiveViewer의
  // 변환행렬을 역산해 지금 화면에 실제로 보이는 영역을 겹쳐 그린다.
  // 접어 둔 미니맵: 작은 단추 하나. 눌러야 펴져서 그 밑 모듈을 가리지 않는다.
  Widget _buildMinimapButton() {
    return Tooltip(
      message: "미니맵 펴기",
      child: Material(
        color: pureWhite.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: tossSubText.withValues(alpha: 0.4)),
        ),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _minimapOpen = true),
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.map_outlined, color: tossText, size: 24),
          ),
        ),
      ),
    );
  }

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
      for (final type in [
        if (_showCenterGuide) DimensionType.center,
        if (_showEdgeGuide) DimensionType.edge,
      ])
        CustomPaint(
          size: Size.infinite,
          painter: SmartGuidePainter(
            item: item,
            allItems: _placedItems,
            panelWidth: _panelWidth,
            panelHeight: _panelHeight,
            currentType: type,
          ),
        ),
    ];
  }

  // 모드 전환(모듈 배치/이동 ↔ 고정 치수 측정): 전선관 계산기처럼 회색 판 안에서
  // 고른 쪽만 틸로 채운다.
  Widget _buildModeSegmentedControl() {
    final segments = <(BoardMode, String, IconData)>[
      (BoardMode.placeModule, "모듈 배치/이동", Icons.open_with_rounded),
      (BoardMode.measureDimension, "고정 치수 측정", Icons.straighten_rounded),
    ];

    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tossBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: layoutLine),
      ),
      child: Row(
        children: segments.map((seg) {
          final isSelected = _mode == seg.$1;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (isSelected) return;
                  HapticFeedback.selectionClick();
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
                  decoration: BoxDecoration(
                    color: isSelected ? tossBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          seg.$3,
                          size: 20,
                          color: isSelected ? pureWhite : tossSubText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          seg.$2,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? pureWhite : tossSubText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 좁은 화면 모듈 배치 도구: 끌어다 놓을 것 한 줄 + 가상선·여러 개 선택 단추 + 내 프리셋.
  Widget _buildModulePalette() {
    return Column(
      key: const ValueKey("palette"),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _panelLabel("끌어다 도면에 놓습니다"),
        const SizedBox(height: 8),
        // 단추가 늘어 좁은 폰에서는 옆으로 민다(신규 모듈은 위로 끌어 놓는다).
        SizedBox(
          height: 64,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _dragTile(
                  const ModulePreset("신규 모듈", 80, 80),
                  (_) => _buildPaletteItem("신규 모듈"),
                  affinity: Axis.vertical,
                ),
                const SizedBox(width: 8),
                if (_isSkid) ...[
                  _buildSkidButton(
                    "skid_steel",
                    Icons.view_stream_rounded,
                    "형강",
                    "형강 놓기",
                    kSkidSteelPresets,
                  ),
                  const SizedBox(width: 8),
                  // 전선관은 "경로"로 그린다(따로 놓는 막대는 경로와 이어지지 않아 헷갈렸다).
                  _buildRouteButton(),
                  const SizedBox(width: 8),
                  _buildSkidButton(
                    "skid_jb",
                    Icons.inbox_outlined,
                    "JB",
                    "정션박스 놓기",
                    kSkidJbPresets,
                  ),
                ] else ...[
                  _buildDuctButton(),
                  const SizedBox(width: 8),
                  _buildElecButton(),
                ],
                const SizedBox(width: 8),
                _buildInstrumentButton(),
                const SizedBox(width: 8),
                _buildValveButton(),
                const SizedBox(width: 8),
                _buildFittingButton(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildGuideColorSwitch()),
            const SizedBox(width: 8),
            Expanded(child: _buildMultiSelectToggle()),
          ],
        ),
        if (_customPresets.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildPresetArea(wide: false),
        ],
      ],
    );
  }

  // 여러 개 선택 켜기/끄기(예전엔 위 막대에 있었다).
  Widget _buildMultiSelectToggle() {
    return _toolToggle(
      icon: Icons.library_add_check_rounded,
      label: "여러 개 선택",
      selected: _multiSelectMode,
      color: tossBlue,
      onTap: _toggleMultiSelectMode,
    );
  }

  // 내 프리셋: 이름 검색(4개 이상일 때), 끌어다 놓을 목록, 지우기 단추가 있는 "관리".
  Widget _buildPresetArea({required bool wide}) {
    final String q = _presetSearchQuery.toLowerCase();
    final List<ModulePreset> filtered = q.isEmpty
        ? _customPresets
        : _customPresets
              .where((p) => p.name.toLowerCase().contains(q))
              .toList();
    Widget tile(ModulePreset p) => GestureDetector(
      onLongPress: () => _confirmDeleteCustomPreset(_customPresets.indexOf(p)),
      child: _dragTile(
        p,
        (_) => _buildCustomPresetChip(p, width: wide ? 228 : null),
        affinity: wide ? Axis.horizontal : null,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _panelLabel("내 프리셋 ${_customPresets.length}개")),
            TextButton.icon(
              onPressed: _showPresetManageSheet,
              style: TextButton.styleFrom(
                minimumSize: const Size(40, 40),
                foregroundColor: tossBlue,
              ),
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text(
                "관리",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        if (_customPresets.length > 3) ...[
          TextField(
            controller: _presetSearchCtrl,
            onChanged: (v) => setState(() => _presetSearchQuery = v.trim()),
            style: const TextStyle(fontSize: 15, color: tossText),
            decoration: _inspectorFieldDecoration().copyWith(
              hintText: "프리셋 이름 검색",
              hintStyle: const TextStyle(fontSize: 15, color: tossSubText),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 22,
                color: tossSubText,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              suffixIcon: _presetSearchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: "검색 지우기",
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: tossSubText,
                      ),
                      onPressed: () {
                        _presetSearchCtrl.clear();
                        setState(() => _presetSearchQuery = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "찾는 프리셋이 없습니다",
              style: TextStyle(fontSize: 14, color: tossSubText),
            ),
          )
        else if (wide)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final p in filtered) tile(p)],
          )
        else
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => tile(filtered[i]),
            ),
          ),
      ],
    );
  }

  // 내 프리셋 관리: 길게 누르지 않아도 줄마다 지우기 단추로 지운다.
  void _showPresetManageSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
              maxWidth: 560,
            ),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Text(
                    "내 프리셋 관리",
                    style: TextStyle(
                      color: tossText,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    keepWords("이 폰에만 저장됩니다. 지우면 끌어다 놓는 목록에서 빠집니다."),
                    style: const TextStyle(color: tossSubText, fontSize: 14),
                  ),
                ),
                if (_customPresets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      "저장된 프리셋이 없습니다",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tossSubText, fontSize: 15),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _customPresets.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: layoutLine),
                      itemBuilder: (context, i) {
                        final p = _customPresets[i];
                        return ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 60),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20, right: 8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: tossBlue,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: tossText,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        "${p.width.toInt()} × ${p.height.toInt()} mm",
                                        style: const TextStyle(
                                          color: tossSubText,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: "프리셋 삭제",
                                  constraints: const BoxConstraints(
                                    minWidth: 52,
                                    minHeight: 52,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: warningRed,
                                    size: 26,
                                  ),
                                  onPressed: () async {
                                    await _confirmDeleteCustomPreset(i);
                                    setSheet(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomPresetChip(ModulePreset preset, {double? width}) {
    return Container(
      height: 56,
      width: width,
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tossBlue.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 20, color: tossBlue),
          const SizedBox(width: 6),
          _flexIf(
            width != null,
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tossText,
                  ),
                ),
                Text(
                  "${preset.width.toInt()}×${preset.height.toInt()}",
                  style: const TextStyle(fontSize: 14, color: tossSubText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 폭이 정해졌을 때만 Flexible로 감싼다(가로로 굴리는 목록 안에서는 폭이 끝없어 Flexible을 못 쓴다).
  Widget _flexIf(bool flex, Widget child) =>
      flex ? Flexible(child: child) : child;

  Future<void> _confirmDeleteCustomPreset(int index) async {
    if (index < 0 || index >= _customPresets.length) return;
    final preset = _customPresets[index];
    final ok = await confirmLayoutDanger(
      context,
      title: "프리셋 삭제",
      message: "'${preset.name}' 프리셋을 지웁니다.",
      confirmLabel: "삭제",
    );
    if (ok && mounted) await _deleteCustomPreset(index);
  }

  // 좁은 화면 "계기" 단추: 누르면 제조사별 목록이 뜨고, 고르면 지금 보이는 도면 가운데에 놓는다.
  // (아래 칸 높이를 늘리면 도면이 좁아져서 끌어다 놓기 대신 목록으로 둔다.)
  Widget _buildInstrumentButton() => _buildSheetButton(
    key: const ValueKey("instrument_button"),
    icon: Icons.speed_rounded,
    label: "계기",
    onTap: () => _showPresetSheet(
      title: "계기 놓기",
      help: "정면에서 본 몸통 크기입니다(2인치 브래킷 빼고). 누르면 지금 보이는 도면 가운데에 놓습니다.",
      groups: kInstrumentPresets,
    ),
  );

  void _openFittingSheet() => _showPresetSheet(
    title: "피팅 놓기",
    help:
        "하이록·스웨즈락 튜브 피팅을 옆에서 본 크기입니다(1/4\"·3/8\"·1/2\"는 두 회사 치수가 같습니다). 누르면 지금 보이는 도면 가운데에 놓습니다.",
    groups: kFittingPresets,
    sizeFilter: true,
  );

  void _openValveSheet() => _showPresetSheet(
    title: "밸브 놓기",
    help: "매니폴드 밸브를 정면(손잡이 쪽)에서 본 크기입니다. 누르면 지금 보이는 도면 가운데에 놓습니다.",
    groups: kValvePresets,
  );

  Widget _buildFittingButton() => _buildSheetButton(
    key: const ValueKey("fitting_button"),
    icon: Icons.plumbing_rounded,
    label: "피팅",
    onTap: _openFittingSheet,
  );

  Widget _buildValveButton() => _buildSheetButton(
    key: const ValueKey("valve_button"),
    icon: Icons.tune_rounded,
    label: "밸브",
    onTap: _openValveSheet,
  );

  // ───────────────────────── 스키드 전선관 경로 ─────────────────────────
  // 경로는 평면 기준(탭과 상관없이 하나)이고, 탭마다 그 방향에서 본 선으로 그린다.

  final List<ConduitRoute> _routes = [];

  List<PlacedItem> get _planItems => _plateId == kPlateMain
      ? _placedItems
      : layoutItemsFromData(_plateStore[kPlateMain] ?? const {});

  (double, double) get _planSize {
    if (_plateId == kPlateMain) return (_panelWidth, _panelHeight);
    final m = _plateStore[kPlateMain];
    return (
      (m?['panelWidth'] as num?)?.toDouble() ?? _panelWidth,
      (m?['panelHeight'] as num?)?.toDouble() ?? _panelHeight,
    );
  }

  Widget _buildSkidOverlay() {
    final plan = _planItems;
    final (planW, planH) = _planSize;
    Offset proj(vm.Vector3 p) => projectToView(
      p,
      _plateId,
      planW: planW,
      planH: planH,
      viewH: _panelHeight,
    );
    final routes = [
      for (final r in _routes)
        (r.name, r.points(plan).map(proj).toList(), r.od),
    ];
    final ghosts = skidGhosts(
      plan,
      _plateId,
      planH: planH,
      viewH: _panelHeight,
    );
    final version = jsonEncode([
      _plateId,
      _panelHeight,
      planW,
      planH,
      _routes.map((r) => r.toJson()).toList(),
      if (_plateId != kPlateMain)
        plan
            .map(
              (e) => [
                e.id,
                e.position.dx,
                e.position.dy,
                e.width,
                e.height,
                e.elevation,
              ],
            )
            .toList()
      else
        _routes.map((r) => r.startItemId).toList(),
      if (_plateId == kPlateMain)
        plan
            .where((e) => _routes.any((r) => r.startItemId == e.id))
            .map((e) => [e.position.dx, e.position.dy, e.elevation])
            .toList(),
    ]);
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: SkidOverlayPainter(
          routes: routes,
          ghosts: ghosts,
          version: version,
        ),
      ),
    );
  }

  Widget _buildRouteButton() => _buildSheetButton(
    key: const ValueKey("skid_route"),
    icon: Icons.route_rounded,
    label: "경로",
    onTap: _showRoutesSheet,
  );

  void _showRoutesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "전선관 경로",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: tossText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  keepWords(
                    "전선관은 경로로 그립니다. 시작 부품에서 계산기 입력 탭처럼 한 줄씩 넣고, 구조물은 특수 벤딩의 오프셋으로 비켜 갑니다. 도면에서 경로 선을 눌러도 고칠 수 있습니다.",
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: tossSubText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final r in _routes)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.route_rounded,
                            color: tossBlue,
                          ),
                          title: Text(
                            "${r.name} · 후강 ${r.size}",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: tossText,
                            ),
                          ),
                          subtitle: Text(
                            "${r.bends.length}줄 · 꺾이는 점 사이 합 ${r.totalLength.toInt()} mm",
                            style: const TextStyle(
                              fontSize: 14,
                              color: tossSubText,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: "지우기",
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: warningRed,
                            ),
                            onPressed: () async {
                              final ok = await confirmLayoutDanger(
                                context,
                                title: "경로 지우기",
                                message: "'${r.name}' 경로를 지웁니다.",
                                confirmLabel: "지우기",
                              );
                              if (!ok || !mounted) return;
                              setState(() => _routes.remove(r));
                              setSheet(() {});
                              _saveDraftToPrefs();
                            },
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _showRouteEditor(r);
                          },
                        ),
                      if (_routes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            "아직 경로가 없습니다.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: tossSubText, fontSize: 15),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  key: const ValueKey("route_new"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tossBlue,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showRouteEditor(null);
                  },
                  icon: const Icon(Icons.add_rounded, color: pureWhite),
                  label: const Text(
                    "새 경로",
                    style: TextStyle(
                      color: pureWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 경로 입력 화면(위 작은 도면 + 아래 전선관 계산기 입력 탭)을 연다.
  Future<void> _showRouteEditor(ConduitRoute? original) async {
    final route =
        original ??
        ConduitRoute(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: "경로 ${_routes.length + 1}",
        );
    final saved = await SkidRouteEditorPage.open(
      context,
      route: route,
      plates: _allPlates(),
      otherRoutes: [
        for (final r in _routes)
          if (r.id != route.id) r,
      ],
      initialView: _plateId,
    );
    if (saved == null || !mounted) return;
    setState(() {
      final i = _routes.indexWhere((e) => e.id == saved.id);
      if (i >= 0) {
        _routes[i] = saved;
      } else {
        _routes.add(saved);
      }
    });
    _saveDraftToPrefs();
  }

  // 스키드 평면 모듈 단추(형강·전선관·정션박스). 길이는 1000으로 놓이고 놓은 뒤 고친다.
  Widget _buildSkidButton(
    String key,
    IconData icon,
    String label,
    String title,
    Map<String, List<ModulePreset>> groups,
  ) => _buildSheetButton(
    key: ValueKey(key),
    icon: icon,
    label: label,
    onTap: () => _openSkidSheet(title, groups),
  );

  void _openSkidSheet(
    String title,
    Map<String, List<ModulePreset>> groups,
  ) => _showPresetSheet(
    title: title,
    help: groups == kSkidJbPresets
        ? "위에서 본 가로×세로(mm)입니다. 누르면 지금 보이는 도면 가운데에 놓습니다. 바닥에서 높이는 놓은 뒤 편집 칸에 넣으십시오."
        : "위에서 본 폭(mm)으로, 길이 1000으로 놓입니다. 놓은 뒤 편집 칸에서 실제 길이로 고치고, 세로로 쓰려면 돌리십시오.",
    groups: groups,
  );

  void _openElecSheet() => _showPresetSheet(
    title: "전기 부품 놓기",
    help:
        "DIN 레일에 다는 부품을 정면에서 본 크기입니다(깊이는 판 면에서, 레일 포함). 누르면 지금 보이는 도면 가운데에 놓습니다.",
    groups: kElecPresets,
  );

  Widget _buildElecButton() => _buildSheetButton(
    key: const ValueKey("elec_button"),
    icon: Icons.electrical_services_rounded,
    label: "전기",
    onTap: _openElecSheet,
  );

  Widget _buildDuctButton() => _buildSheetButton(
    key: const ValueKey("duct_button"),
    icon: Icons.view_week_rounded,
    label: "덕트",
    onTap: () => _showPresetSheet(
      title: "덕트 놓기",
      help:
          "폭×높이(mm)입니다. 도면에는 폭만큼 놓이고, 길이는 놓은 뒤 세로 칸에서 고칩니다. 누르면 지금 보이는 도면 가운데에 놓습니다.",
      groups: kDuctPresetGroups,
    ),
  );

  Widget _buildSheetButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: pureWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: tossSubText.withValues(alpha: 0.3), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: tossBlue),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: tossText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 피팅 고르기 창에서 마지막으로 고른 관 규격(창을 다시 열어도 그대로).
  String _fittingSize = '1/2"';

  Future<void> _showPresetSheet({
    required String title,
    required String help,
    required Map<String, List<ModulePreset>> groups,
    bool sizeFilter = false,
  }) async {
    final ModulePreset? picked = await showModalBottomSheet<ModulePreset>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: sizeFilter ? 0.8 : 0.6,
          maxChildSize: 0.9,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: tossText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                keepWords(help),
                style: const TextStyle(
                  fontSize: 14,
                  color: tossSubText,
                  height: 1.4,
                ),
              ),
              if (sizeFilter) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final size in kFittingSizes)
                      ChoiceChip(
                        key: ValueKey("fitting_size_$size"),
                        label: Text(size),
                        selected: size == _fittingSize,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: size == _fittingSize ? pureWhite : tossText,
                        ),
                        selectedColor: tossBlue,
                        backgroundColor: pureWhite,
                        side: BorderSide(
                          color: size == _fittingSize ? tossBlue : layoutLine,
                        ),
                        onSelected: (_) {
                          setState(() => _fittingSize = size);
                          setSheet(() {});
                        },
                      ),
                  ],
                ),
              ],
              for (final brand in groups.entries)
                if (!sizeFilter ||
                    brand.value.any(
                      (p) => fittingTubeSize(p.name) == _fittingSize,
                    )) ...[
                  const SizedBox(height: 16),
                  _panelLabel(brand.key),
                  for (final p in brand.value)
                    if (!sizeFilter || fittingTubeSize(p.name) == _fittingSize)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _instrumentThumb(p, box: 48),
                        title: Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: tossText,
                          ),
                        ),
                        // 덕트는 이름에 폭×높이가 있고 도면 세로(길이)는 놓은 뒤 고치므로 크기를 따로 안 적는다.
                        trailing: p.shape == InstrumentShape.duct
                            ? null
                            : Text(
                                "${p.width.toInt()}×${p.height.toInt()}",
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: tossSubText,
                                ),
                              ),
                        onTap: () => Navigator.pop(ctx, p),
                      ),
                ],
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _onAcceptItem(picked, _visibleBoardCenter(picked));
  }

  // 지금 화면에 보이는 도면 가운데(모듈 왼쪽 위 자리). 못 구하면 도면 한가운데.
  Offset _visibleBoardCenter(ModulePreset p) {
    final half = Offset(p.width / 2, p.height / 2);
    try {
      final viewer = _viewerKey.currentContext!.findRenderObject() as RenderBox;
      final board = _boardKey.currentContext!.findRenderObject() as RenderBox;
      final g = viewer.localToGlobal(viewer.size.center(Offset.zero));
      return board.globalToLocal(g) - half;
    } catch (_) {
      return Offset(_panelWidth / 2, _panelHeight / 2) - half;
    }
  }

  // 계기 한 칸: 모델 이름과 정면 가로×세로(mm).
  Widget _buildInstrumentChip(ModulePreset preset, {double? width}) {
    return Container(
      height: 56,
      width: width,
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tossSubText.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _instrumentThumb(preset, box: 40),
          const SizedBox(width: 8),
          _flexIf(
            width != null,
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tossText,
                    height: 1.2,
                  ),
                ),
                Text(
                  "${preset.width.toInt()}×${preset.height.toInt()}",
                  style: const TextStyle(
                    fontSize: 14,
                    color: tossSubText,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuctChip(ModulePreset preset, {double width = 76}) {
    return Container(
      height: 64,
      width: width,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tossSubText.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "ABS 덕트",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tossSubText,
              height: 1.1,
            ),
          ),
          Text(
            preset.name.replaceFirst("ABS덕트 ", ""),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: tossText,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // 좁은 화면 가상선 단추: 누를 때마다 센터선(틸) ↔ 외곽선(주황)으로 바뀐다.
  Widget _buildGuideColorSwitch() {
    final bool isCenter = !_showEdgeGuide;
    return _toolToggle(
      icon: Icons.sync_alt_rounded,
      label: isCenter ? "가상선: 센터" : "가상선: 측면",
      selected: true,
      color: isCenter ? guideCenterColor : edgeDimColor,
      onTap: () => setState(() {
        _showCenterGuide = !isCenter;
        _showEdgeGuide = isCenter;
      }),
    );
  }

  Widget _buildPaletteItem(String defaultName, {bool large = false}) {
    // 넓은 화면의 왼쪽 칸에서는 크게 보인다. 끄는 동안 떠다니는 복사본으로도
    // 쓰이므로 폭은 늘 고정값이어야 한다(무한 폭이면 오류가 난다).
    return Container(
      width: large ? 228 : 64,
      height: large ? 56 : 56,
      decoration: BoxDecoration(
        color: tossBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tossBlue.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Center(
        child: large
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_box_rounded, color: tossBlue, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    defaultName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: tossBlue,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_box_rounded, color: tossBlue, size: 20),
                  const SizedBox(height: 2),
                  Text(
                    defaultName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: tossBlue,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // 켜고 끄는 도구 단추(높이 44, 글씨 14). 알약 모양 대신 모서리만 둥근 네모.
  Widget _toolToggle({
    required IconData icon,
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      toggled: selected,
      child: Material(
        color: selected ? color.withValues(alpha: 0.10) : pureWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? color : layoutLine,
            width: selected ? 2 : 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: selected ? color : tossSubText),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: selected ? color : tossSubText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 칸 안의 작은 제목(14, 굵게).
  Widget _panelLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: tossSubText,
    ),
  );

  // 도면으로 끌어다 놓는 것 하나. affinity를 주면 그 방향으로 끌 때만 집힌다.
  Widget _dragTile(
    ModulePreset preset,
    Widget Function(bool dragging) builder, {
    Axis? affinity,
  }) {
    return Draggable<ModulePreset>(
      data: preset,
      affinity: affinity,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.8, child: builder(true)),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: builder(true)),
      child: builder(false),
    );
  }

  // 90° 돌리기(가로·세로 바꾸기). 도면 밖으로 나가지 않게 위치를 맞춘다.
  void _rotateItem(PlacedItem item) {
    _pushUndo();
    setState(() {
      final double temp = item.width;
      item.width = item.height;
      item.height = temp;
      item.position = Offset(
        item.position.dx.clamp(0.0, math.max(0.0, _panelWidth - item.width)),
        item.position.dy.clamp(0.0, math.max(0.0, _panelHeight - item.height)),
      );
    });
    HapticFeedback.lightImpact();
  }

  // 모듈 하나 복제: 오른쪽 아래로 20mm 비켜 놓고, 넓은 화면에서는 복제본을 고른다.
  void _duplicateItem(PlacedItem item) {
    _pushUndo();
    final newItem = PlacedItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
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
      shape: item.shape,
      depth: item.depth,
      elevation: item.elevation,
    );
    setState(() {
      _placedItems.add(newItem);
      if (_isWide) {
        item.isSelected = false;
        newItem.isSelected = true;
        _activeItem = newItem;
      }
    });
    HapticFeedback.mediumImpact();
  }

  // 좁은 화면 치수 재기 도구: 기준·체인·대각선 단추 한 줄 + 안내 + 첫 지점 취소.
  // 치수선 전체 지우기는 위 막대 "더보기"의 빨간 칸으로 옮겼다(확인을 받는다).
  Widget _buildDimensionToolBar() {
    final bool isCenter = _currentDimType == DimensionType.center;
    return Column(
      key: const ValueKey("dimension"),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              flex: 4,
              child: _toolToggle(
                icon: Icons.sync_alt_rounded,
                label: isCenter ? "센터 기준" : "측면 기준",
                selected: true,
                color: isCenter ? centerDimColor : edgeDimColor,
                onTap: () => setState(() {
                  _currentDimType = isCenter
                      ? DimensionType.edge
                      : DimensionType.center;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _toolToggle(
                icon: Icons.link_rounded,
                label: "체인",
                selected: _dimensionChainMode,
                color: tossBlue,
                onTap: () =>
                    setState(() => _dimensionChainMode = !_dimensionChainMode),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _toolToggle(
                icon: Icons.turn_slight_right_rounded,
                label: "대각선",
                selected: _dimensionDiagonalMode,
                color: diagonalDimColor,
                onTap: () => setState(
                  () => _dimensionDiagonalMode = !_dimensionDiagonalMode,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                keepWords(_dimensionHint()),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: tossSubText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
            // 첫 지점을 잘못 찍었을 때 두 번째 지점을 억지로 찍지 않고 취소한다.
            if (_dimensionStartPoint != null)
              TextButton.icon(
                onPressed: () => setState(() => _dimensionStartPoint = null),
                style: TextButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  foregroundColor: tossText,
                ),
                icon: const Icon(Icons.undo_rounded, size: 22),
                label: const Text(
                  "첫 지점 취소",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBoardItem(PlacedItem item) {
    bool isMeasuringStart =
        _mode == BoardMode.measureDimension &&
        _dimensionStartPoint?.id == item.id;
    Color activeColor = _currentDimType == DimensionType.center
        ? centerDimColor
        : edgeDimColor;

    if (item.shape != null) {
      return _buildInstrumentItem(item, isMeasuringStart, activeColor);
    }

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
              : (item.isSelected
                    ? tossBlue
                    : (_problemIds.contains(item.id)
                          ? warningRed
                          : Colors.blueGrey.shade300)),
          width:
              isMeasuringStart ||
                  item.isSelected ||
                  _problemIds.contains(item.id)
              ? 3
              : 1.5,
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
          _itemCaption(item) == null
              ? item.name
              : "${item.name}\n${_itemCaption(item)}",
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

  // 계기 모듈: 네모 대신 정면 모양을 그리고, 이름은 가운데 흰 띠에 적는다.
  Widget _buildInstrumentItem(
    PlacedItem item,
    bool isMeasuringStart,
    Color activeColor,
  ) {
    final Color color = isMeasuringStart
        ? activeColor
        : (item.isSelected
              ? tossBlue
              : (_problemIds.contains(item.id)
                    ? warningRed
                    : const Color(0xFF64748B)));
    // 피팅처럼 작은 것은 이름 띠가 그림을 다 가려서, 글씨를 줄이고 띠를 비친다.
    final bool small = math.min(item.width, item.height) < 60;
    return SizedBox(
      width: item.width,
      height: item.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: InstrumentShapePainter(
                shape: item.shape!,
                stroke: color,
                strokeWidth:
                    item.isSelected ||
                        isMeasuringStart ||
                        _problemIds.contains(item.id)
                    ? 2.5
                    : 1.5,
              ),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              color: pureWhite.withValues(alpha: small ? 0.55 : 0.85),
              child: Text(
                _itemCaption(item) == null ||
                        small ||
                        item.shape == InstrumentShape.duct
                    ? item.name
                    : "${item.name}\n${_itemCaption(item)}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: small ? 8 : 11,
                  fontWeight: FontWeight.w800,
                  color: isMeasuringStart
                      ? activeColor
                      : (item.isSelected ? tossBlue : tossText),
                  height: 1.15,
                  letterSpacing: -0.3,
                ),
                maxLines: small ? 2 : 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 목록·자재 칸에 쓰는 계기 작은 그림(가로·세로 비율 그대로).
  Widget _instrumentThumb(ModulePreset p, {double box = 44}) {
    final double k = box / math.max(p.width, p.height);
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: SizedBox(
          width: p.width * k,
          height: p.height * k,
          child: CustomPaint(
            painter: InstrumentShapePainter(
              shape: p.shape ?? '',
              strokeWidth: 1,
            ),
          ),
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
            fontSize: 14,
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

// 🚀 SmartGuidePainter·GridPainter 는 models/layout_board_painters.dart 로 옮겼다(모바일·태블릿 공용).

// 넓은 화면 오른쪽 칸의 숫자 입력 칸(크기·위치).
// 예전엔 그릴 때마다 입력 칸을 새로 만들어서, 값을 치다가 다른 칸을 누르면 친 값이 사라졌다.
// 이제 칸 하나를 계속 쓰고, 완료를 누르거나 다른 곳을 누를 때(포커스가 빠질 때) 값을 넣는다.
class _InspectorNumberField extends StatefulWidget {
  final String value;
  final void Function(String) onCommit;
  final InputDecoration decoration;

  const _InspectorNumberField({
    super.key,
    required this.value,
    required this.onCommit,
    required this.decoration,
  });

  @override
  State<_InspectorNumberField> createState() => _InspectorNumberFieldState();
}

class _InspectorNumberFieldState extends State<_InspectorNumberField> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      // 화면에서 빠지는 중(폭이 바뀌어 칸이 사라지거나 화면을 닫음)에는 넣지 않는다.
      if (!_focus.hasFocus && mounted && _active) _commit();
    });
  }

  bool _active = true;

  @override
  void deactivate() {
    _active = false;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
  }

  @override
  void didUpdateWidget(covariant _InspectorNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 치는 중이 아닐 때만 바깥 값(끌어서 옮긴 위치, 되돌리기 등)을 따라간다.
    if (!_focus.hasFocus && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  void _commit() {
    if (_ctrl.text.trim().isEmpty) {
      _ctrl.text = widget.value;
      return;
    }
    if (_ctrl.text != widget.value) widget.onCommit(_ctrl.text);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      keyboardType: TextInputType.number,
      onSubmitted: (_) => _commit(),
      onTapOutside: (_) => _focus.unfocus(),
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: tossText,
      ),
      decoration: widget.decoration,
    );
  }
}
