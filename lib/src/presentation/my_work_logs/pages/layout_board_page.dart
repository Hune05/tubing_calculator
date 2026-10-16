import 'package:tubing_calculator/src/core/common_widgets/snack_once.dart';
import 'package:tubing_calculator/src/core/utils/quick_firestore.dart';
import 'package:tubing_calculator/src/presentation/common/quick_tool_bar.dart';
import 'package:tubing_calculator/src/presentation/common/pick_style.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'dart:async';
import '../widgets/korean_text.dart';
import 'layout_board/layout_parts_page.dart';
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
import '../../../core/utils/pdf_fonts.dart';

import '../../../core/utils/image_picker_helper.dart' show ImagePickerHelper;
import '../models/photo_store.dart'
    show uploadLayoutBackground, downloadLayoutBackground;
import '../../../core/utils/shared_drawing_inbox.dart' show SharedDrawingInbox;
import '../models/instrument_shape_painter.dart';
import '../models/layout_board_models.dart';
import '../models/layout_plates.dart';
import '../models/skid_presets.dart';
import '../models/elec_presets.dart';
import '../models/skid_route.dart';
import '../models/skid_part_painter.dart';
import 'skid_route_editor_page.dart';
import 'skid_iso_page.dart';
import 'drawing_scale_page.dart';
import '../models/drawing_scale.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import '../models/layout_board_owner.dart';
import '../models/layout_board_painters.dart';
import 'package:tubing_calculator/src/presentation/common/number_text.dart';
import '../widgets/layout_board_ui.dart';
import '../../../core/common_widgets/swipe_to_delete.dart';
import 'package:tubing_calculator/src/core/utils/error_text.dart';

export '../models/layout_board_painters.dart';
export '../models/layout_board_models.dart';
export '../models/instrument_shape_painter.dart';
export '../models/skid_presets.dart';
export '../models/elec_presets.dart';
export '../models/skid_route.dart';
export '../models/skid_part_painter.dart';
export '../models/layout_plates.dart';
export '../widgets/layout_board_ui.dart';

part 'layout_board/layout_board_plates.dart';
part 'layout_board/layout_board_undo_draft.dart';
part 'layout_board/layout_board_save_pdf.dart';
part 'layout_board/layout_board_templates.dart';
part 'layout_board/layout_board_place.dart';
part 'layout_board/layout_board_dimensions.dart';
part 'layout_board/layout_board_select.dart';
part 'layout_board/layout_board_item_sheet.dart';
part 'layout_board/layout_board_background.dart';
part 'layout_board/layout_board_sheets.dart';
part 'layout_board/layout_board_canvas.dart';
part 'layout_board/layout_board_palette.dart';
part 'layout_board/layout_board_skid.dart';

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
// 2026-09-30 사용자 결정: 태블릿·큰 화면도 폰과 같은 방식(아래 팔레트, 부품을 누르면 아래 시트).
// 세로로 든 14.6인치에서 양옆 칸이 도면을 344dp로 눌러 가렸다. 10-13: 양옆 칸 코드는 지웠다.

/// 이어서 할 임시 저장(저장 안 하고 나간 배치도)이 있는지. 카톡으로 받은 도면을 어디에 깔지 물을 때 쓴다.
Future<bool> layoutBoardHasDraft() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('layout_board_draft_v1') != null ||
        prefs.getString('tablet_layout_board_draft_v1') != null;
  } catch (_) {
    return false;
  }
}

// 🚀 데이터 모델과 치수 계산은 models/layout_board_models.dart 로 옮겼다(모바일·태블릿 공용).
// ---------------------------------------------------------
// 2. 메인 페이지 화면
// ---------------------------------------------------------
// ───── 화면 State가 쓰는 상수·순수 함수(part 파일의 확장에서도 보이게 최상위에 둔다, 10-13) ─────
const String _gridPrefsKey = 'layout_grid_mm';

const List<double> _gridChoices = [0, 1, 5, 10];

// 🚀 [추가] 서버에 정식 저장하기 전에 앱을 껐다 켜거나 화면을 나가면
// 작업 중이던 배치가 전부 사라지던 문제(휘발성)를 막기 위한 로컬
// 임시 저장. 주기적으로 + 앱이 백그라운드로 갈 때 기기에만 저장해두고,
// 정식으로 서버 저장을 하면 더 이상 필요 없으니 지운다.
const String _draftPrefsKey = 'layout_board_draft_v1';

const String _pdfPaperPrefsKey = 'layout_pdf_paper';

const String _pdfLandscapePrefsKey = 'layout_pdf_landscape';

// 예전 태블릿 화면이 따로 쓰던 임시 저장 자리. 남아 있으면 이어서 열 수 있게 읽기만 한다.
const String _legacyTabletDraftPrefsKey = 'tablet_layout_board_draft_v1';

// 🚀 [신규] 자주 쓰는 모듈 크기(예: 특정 차단기 규격)를 이름 붙여
// 저장해두고 다음 도면에서 바로 드래그해 쓸 수 있는 프리셋 라이브러리.
// 기기 단위로 저장(SharedPreferences)해서 모바일/태블릿 화면 모두,
// 어떤 프로젝트를 열든 항상 같은 목록을 쓴다.
const String _customPresetsPrefsKey = 'layout_board_custom_presets';

// 🚀 [신규] 처음 배치도 화면을 여는 사람은 빈 캔버스만 보고 어떻게
// 시작해야 할지 막막할 수 있어, 기기당 딱 한 번만 짧은 사용법 안내를
// 보여준다("다시 보지 않음" 없이 한 번 확인하면 계속 안 뜬다).
const String _onboardingShownPrefsKey = 'layout_board_onboarding_shown_v1';

/// 부품 목록의 자리·크기·깊이를 한 줄로(바뀌었는지 가리는 열쇠).
void _fingerprintItems(StringBuffer b, Iterable<dynamic> items) {
  for (final it in items) {
    if (it is PlacedItem) {
      b
        ..write(it.id)
        ..write(':')
        ..write(it.position.dx)
        ..write(',')
        ..write(it.position.dy)
        ..write(',')
        ..write(it.width)
        ..write(',')
        ..write(it.height)
        ..write(',')
        ..write(it.depth)
        ..write(',')
        ..write(it.elevation)
        ..write(',')
        ..write(it.shape)
        ..write(',')
        ..write(it.flipped)
        ..write(';');
    } else if (it is Map) {
      b
        ..write(it['id'])
        ..write(':')
        ..write(it['x'])
        ..write(',')
        ..write(it['y'])
        ..write(',')
        ..write(it['w'])
        ..write(',')
        ..write(it['h'])
        ..write(',')
        ..write(it['depth'])
        ..write(',')
        ..write(it['elev'])
        ..write(',')
        ..write(it['shape'])
        ..write(',')
        ..write(it['flip'])
        ..write(';');
    }
  }
}

const int _maxUndoSteps = 30;

const Set<String> _skidSteelShapes = {
  SkidShape.beam,
  SkidShape.channel,
  SkidShape.angle,
  SkidShape.square,
  SkidShape.strut,
};

// 🚀 [버그 수정] 벽까지 실제 거리와 무관하게 빈 도면 공간을 탭하면
// 무조건 "가장 가까운 벽" 지점으로 확정되어 버렸다. 모듈을 살짝
// 빗맞히거나 그냥 도면 가운데를 눌러도 항상 치수 시작점이 잡히는
// 게 "시작점이 무조건 벽이 된다" + "그냥 터치만 해도 치수가 생긴다"
// 두 증상의 원인이었다. 이제 실제로 벽에서 가까울 때(_wallTapTolerance
// 이내)만 벽 기준점으로 인정하고, 그 밖의 빈 허공 탭은 무시(null)한다.
const double _wallTapTolerance = 50.0;

/// 정면·측면에서 잰 치수는 평면 부품의 "이 면에서 본 자리"를 점으로 쓴다(아이디 view_…).
String _viewPointId(String planId) => "view_$planId";

// 90° 돌리기(가로·세로 바꾸기). 도면 밖으로 나가지 않게 위치를 맞춘다.
// ───── DIN 레일 붙이기 ─────
bool _isRail(PlacedItem it) =>
    it.shape == 'el_rail' || it.name.contains("DIN 레일");

/// 레일에 다는 전기 부품(단자대·차단기·릴레이 …). 레일 자체는 아니다.
bool _isRailPart(PlacedItem it) =>
    it.shape != null && it.shape!.startsWith('el_') && !_isRail(it);

/// 작업 배치도 화면 하나. 폰·태블릿·폴드 모두 같은 모양(아래 팔레트 + 아래 시트)이다.
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

  /// 카톡 등에서 공유로 받은 도면 사진. 열리면 지금 탭 배경에 깔고 축척 맞추기를 띄운다.
  final String? sharedDrawingPath;

  /// 이어하기를 묻지 않고 정해 둔다: true 이어하기, false 새로 시작, null 물어보기.
  final bool? resumeDraft;

  const LayoutBoardPage({
    super.key,
    this.projectId,
    this.attachToReport = false,
    this.initialKind = kLayoutKindCabinet,
    this.sharedDrawingPath,
    this.resumeDraft,
  });

  @override
  State<LayoutBoardPage> createState() => _LayoutBoardPageState();
}

class _LayoutBoardPageState extends State<LayoutBoardPage>
    with WidgetsBindingObserver {
  double _panelWidth = 600.0;

  double _panelHeight = 800.0;

  // 모눈 맞춤(mm). 0이면 끔. 더보기 → "모눈 맞춤"에서 고르고 폰에 저장한다.
  double _gridSize = 5.0;

  BoardMode _mode = BoardMode.placeModule;

  DimensionType _currentDimType = DimensionType.center;

  // 모듈을 끌 때 보여 줄 안내선. 센터선과 외곽선을 따로 켜고 끌 수 있다.
  // (좁은 화면의 동그란 단추는 둘 중 하나로 바꾸고, 넓은 화면은 둘 다 켤 수도 있다.)
  bool _showCenterGuide = true;

  bool _showEdgeGuide = false;

  // 🚀 [신규] 체인 모드 - 켜두면 점을 찍을 때마다 그 점이 다음 구간의
  // 시작점으로 그대로 이어져서, 여러 지점을 순서대로 탭하는 것만으로
  // 연속된 치수선을 한 번에 그릴 수 있다(모듈을 일렬로 배치할 때 유용).
  bool _dimensionChainMode = false;

  // 기준점 모드 - 첫 점을 그대로 두고 다음 점마다 새 치수를 낸다(한 기준에서 여러 부품까지, 누적 치수).
  bool _dimensionBaselineMode = false;
  // 10-16: 잴 방향 — null 자동(긴 쪽), 'h' 가로, 'v' 세로.
  String? _dimAxis;

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
  // 10-16: 길게 누른 채 끌기(예전엔 0.5초 넘게 누르고 끌면 "여러 개 고르기"가 먼저 잡혀 끌기가 취소됐다).
  Offset _lpDragLast = Offset.zero;
  bool _lpDragMoved = false;
  // 10-16: 이미 다른 부품과 겹친 채로 끌기 시작하면 빠져나올 때까지 겹침 막기를 풀어 둔다
  // (예전엔 어느 쪽으로 움직여도 겹쳐서 꼼짝하지 않았다 — 돌리기·크기 바꾸기·옛 저장본에서 생긴다).
  bool _dragFromOverlap = false;

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

  // 서버에 올린 배경 사진 주소. 사진을 바꾸면 비우고, 저장할 때 다시 올린다.
  String? _backgroundImageUrl;

  double _backgroundOpacity = 0.5;

  // 배경 사진 밝기(1 = 그대로, 1.6까지 밝게)와 흑백. 흐린 복사 도면을 읽기 좋게.
  double _backgroundBrightness = 1.0;

  bool _backgroundGray = false;

  /// 축척 맞추기로 정한 배경 사진 자리(도면 mm). 없으면 예전처럼 판에 맞춰 깐다.
  Rect? _backgroundRect;

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

  bool _pdfCapture = false;

  Size? _viewportSize;

  // PDF 표제란 칸. 도면 번호·리비전은 도면(문서)에, 용지·방향은 폰에 기억한다.
  String _drawingNo = "";

  String _revision = "";

  String _pdfPaper = 'A4';

  bool _pdfLandscape = false;

  Timer? _draftTimer;

  List<ModulePreset> _customPresets = [];

  // 부품 목록 찾기(10-13): 최근 쓴 부품 이름(앞이 최근, 8개까지)과 즐겨찾기 이름. 폰에 기억한다.
  List<String> _recentParts = [];
  Set<String> _favParts = {};

  // 끌 때 안내선(옆 부품의 왼·가운데·오른 선)에 가까우면 붙인다(10-13). 더보기에서 끌 수 있다.
  bool _snapToGuides = true;

  // 🚀 [신규] 프리셋이 많아지면 원하는 걸 찾기 번거로워질 수 있어 이름
  // 검색으로 바로 필터링할 수 있게 했다.
  final TextEditingController _presetSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGridPref();
    SharedPreferences.getInstance()
        .then((p) {
          _pdfPaper = p.getString(_pdfPaperPrefsKey) ?? 'A4';
          _pdfLandscape = p.getBool(_pdfLandscapePrefsKey) ?? false;
        })
        .catchError((_) {});
    WidgetsBinding.instance.addObserver(this);
    _loadCustomPresets();
    _loadPartPrefs();
    // 🚀 확대/이동할 때마다 미니맵의 "현재 보는 영역" 표시가 따라
    // 움직이도록 다시 그려준다.
    // 미니맵·배율 글자는 스스로 다시 그린다(ValueListenableBuilder). 화면 전체는 글씨 배율이
    // 눈에 띄게 바뀔 만큼(3% 넘게) 확대·축소됐을 때만 다시 그린다(예전엔 손가락 한 번에 수십 번).
    _viewerController.addListener(() {
      if (!mounted) return;
      final double z = _viewZoom;
      if ((z - _lastBuiltZoom).abs() > _lastBuiltZoom * 0.03) {
        _lastBuiltZoom = z;
        setState(() {});
      }
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
        if (widget.sharedDrawingPath != null && mounted) {
          _takeSharedDrawing(widget.sharedDrawingPath!);
        }
        _maybeShowOnboarding();
      });
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

  String _plateId = kPlateMain;

  bool _sidePlatesOn = false;

  /// 도면 종류(kLayoutKindCabinet·kLayoutKindSkid).
  String _kind = kLayoutKindCabinet;

  /// 새 스키드 도면: 크기를 스키드 기본(길이 × 폭)으로.
  /// 다음 그리기에서 도면 전체가 화면에 들어오게 맞춘다(스키드처럼 큰 도면).
  bool _fitPending = false;

  /// 중판 면에서 문 안쪽까지(mm). 넣으면 이보다 깊은 부품을 알려 준다.
  double? _cabinetDepth;

  final Map<String, Map<String, dynamic>> _plateStore = {};

  final Map<String, List<List<Map<String, dynamic>>>> _plateUndo = {};

  /// 이번 그리기에서 문제가 있는(간섭·깊이 초과) 모듈 id.
  Set<String> _problemIds = const {};

  /// 마지막으로 화면 전체를 그린 확대 배율(확대 리스너가 견준다).
  double _lastBuiltZoom = 1.0;

  // ───── 저장본과 차이 보기: 불러오거나 저장한 때의 부품 자리(판별 id → 네모·이름) ─────
  Map<String, Map<String, Rect>> _savedRects = {};

  Map<String, Map<String, String>> _savedNames = {};

  bool _showSavedDiff = false;

  // 간섭 확인·정면 셈은 부품이 바뀔 때만 다시 한다(예전엔 그릴 때마다 전부 다시 셌다).
  String _clashKey = '';

  ClashReport? _clashCache;

  String _proxyKey = '';

  List<({PlacedItem it, Rect rect, SkidFace face, bool mirror, double covered})>
  _proxyCache = const [];

  // ───── 스키드: 전선관 경로와 형강·정션박스가 겹치는지(경로 토막을 관 굵기 상자로 견준다) ─────
  String _routeClashKey = '';

  List<({ConduitRoute route, PlacedItem item})> _routeClashCache = const [];

  /// 테스트에서 모든 탭(판)의 저장 모양을 본다.
  @visibleForTesting
  /// 시험용: 끌 때 안내선에 붙는 자리(10-13).
  Offset debugSnapAlignment(String id, Offset proposed) =>
      _snapToAlignment(_placedItems.firstWhere((i) => i.id == id), proposed);

  /// 시험용: 겹치지 않는 가까운 빈자리(10-13).
  Offset debugFreeSpotNear(String id, Offset wanted) =>
      _freeSpotNear(_placedItems.firstWhere((i) => i.id == id), wanted);

  /// 시험용: 여러 개 선택에 든 부품 id.
  Set<String> debugMultiSelected() => {..._multiSelectedIds};

  /// 시험용: 안내선에 붙이기 켜고 끄기.
  void debugSetSnapGuides(bool v) => _snapToGuides = v;

  Map<String, Map<String, dynamic>> debugPlates() => _allPlates();

  /// 시험용: 여러 개 고르기로 고른 부품 id.
  @visibleForTesting
  Set<String> get debugMultiSelectedIds => _multiSelectedIds;

  // 🚀 [신규] 실행 취소/다시 실행. 모듈 배치/이동/삭제/회전/치수 추가·
  // 삭제 등 "한 번의 사용자 조작" 직전마다 현재 상태를 스냅샷으로
  // 쌓아두고, 되돌릴 땐 그 스냅샷으로 복원한다. items/dimensions만
  // 다루고(패널 크기 등은 그대로 유지) 30단계까지 기억한다.
  final List<Map<String, dynamic>> _undoStack = [];

  final List<Map<String, dynamic>> _redoStack = [];

  // 🚀 [신규] 서버에 저장하기 직전, 이미 저장된 적 있는 프로젝트라면
  // 마지막으로 저장된 버전과 비교해서 뭐가 옮겨지고 추가/삭제됐는지
  // 보여주고 확인시킨다. 처음 저장하는 새 프로젝트는 비교 대상이
  // 없으니 그냥 통과시킨다.
  /// 내가 이 도면을 열거나 저장한 때의 저장 표시. 서버 것이 다르면 그 사이 다른 기기가 저장한 것이다.
  String? _lastSaveToken;

  /// 저장 중인 템플릿 문서 이름(통신이 없어 기다리는 사이 다시 눌러도 사본이 생기지 않게).
  String? _templateDocId;

  /// 시험용: 템플릿 적용·되돌리기·판 부품 수.
  @visibleForTesting
  void debugApplyTemplate(Map<String, dynamic> data) => _applyTemplate(data);

  @visibleForTesting
  void debugUndo() => _undo();

  @visibleForTesting
  Rect? get debugBackgroundRect => _backgroundRect;

  @visibleForTesting
  void debugSetBackgroundRect(Rect? r) => setState(() => _backgroundRect = r);

  @visibleForTesting
  void debugPushUndo() => _pushUndo();

  @visibleForTesting
  void debugShowPanelSettings() => _showPanelSettingsSheet();

  @visibleForTesting
  Future<void> debugOfferProjectDraft(String id) => _offerProjectDraft(id);

  @visibleForTesting
  int debugPlateItemCount(String id) => id == _plateId
      ? _placedItems.length
      : ((_plateStore[id]?['items'] as List?)?.length ?? 0);

  // 경로 끌기: 선 위에 보이지 않는 손잡이를 토막마다 깔아, 끌면 경로 시작 자리가 옮겨진다.
  ConduitRoute? _draggingRoute;

  Offset? _routeDragLast;

  /// 끌고 있는 경로에서 손가락으로 잡은 토막(가상선을 이 토막에서 잰다).
  int _routeDragSeg = 0;

  @override
  Widget build(BuildContext context) {
    _problemIds = _sidePlatesOn || _cabinetDepth != null
        ? _clashReportCached().problemIds(_plateId)
        : (_isSkid && _routes.isNotEmpty
              ? _skidRouteClashProblemIds()
              : const {});

    return QuickBarSuppress(
      child: Scaffold(
        backgroundColor: tossBg,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            Column(
              children: [
                if (_showTabs) _buildPlateTabs(),
                Expanded(child: _buildBoardCanvas()),
                // 하단 컨트롤 패널
                _buildBottomPanel(),
              ],
            ),
            _buildMultiSelectBar(),
            // 🚀 [신규] 미니맵 - 확대해서 작업 중일 때 전체 도면에서 지금
            // 보고 있는 위치를 놓치지 않도록 구석에 작게 띄운다.
            if (_placedItems.isNotEmpty && _viewportSize != null)
              Positioned(
                top: 12 + (_showTabs ? 48 : 0),
                right: 12,
                // 확대·이동은 미니맵과 배율 글자만 다시 그린다(예전엔 화면 전체를 다시 그렸다).
                child: ValueListenableBuilder<Matrix4>(
                  valueListenable: _viewerController,
                  builder: (_, _, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      (_minimapOpen ?? false)
                          ? Tooltip(
                              message: "미니맵 접기",
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _minimapOpen = false),
                                child: _buildMinimap(),
                              ),
                            )
                          : _buildMinimapButton(),
                      const SizedBox(height: 4),
                      _buildZoomLabel(),
                    ],
                  ),
                ),
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
      ),
    );
  }

  final List<ConduitRoute> _routes = [];

  String? _proxyDragId;

  Offset _proxyRaw = Offset.zero;

  /// 가려진 부품(더 가까운 부품 뒤에 반 넘게 가려진 것)을 점선으로 보일지. 도면 하나에 하나.
  bool _showHiddenParts = true;

  // 피팅 고르기 창에서 마지막으로 고른 관 규격(창을 다시 열어도 그대로).
  String _fittingSize = '1/2"';

  // ───── 크기 손잡이(2배 넘게 키웠을 때) ─────
  ({double w, double h})? _resizeStart;

  Offset _resizeRaw = Offset.zero;
}

// ---------------------------------------------------------
// Helper Painters
// ---------------------------------------------------------

// 🚀 SmartGuidePainter·GridPainter 는 models/layout_board_painters.dart 로 옮겼다(모바일·태블릿 공용).

/// 가려진 부품 테두리(숨은선): 회색 점선 네모.
/// PDF 표준 축척 중 [plateW]×[plateH](mm)가 [availW]×[availH](pt) 안에 들어가는 가장 큰 것(1:N의 N).
double pdfStandardScale(
  double plateW,
  double plateH,
  double availW,
  double availH,
) {
  const double ptPerMm = 72 / 25.4;
  for (final n in const [1, 2, 2.5, 5, 10, 20, 25, 50, 100, 200, 500]) {
    if (plateW / n * ptPerMm <= availW && plateH / n * ptPerMm <= availH) {
      return n.toDouble();
    }
  }
  return 1000;
}

/// 아래 시트 안에서 "되돌리기" 알림이 보이게 하는 자리. 화면 알림은 시트 밑에 깔려
/// 안 보여서 시트 안에 알림 자리를 따로 둔다. [builder]가 받는 context로
/// [showDeleteUndo]를 부른다.
Widget _sheetUndoHost(WidgetBuilder builder) => ScaffoldMessenger(
  child: Scaffold(
    backgroundColor: Colors.transparent,
    resizeToAvoidBottomInset: false,
    body: Builder(builder: builder),
  ),
);

/// 도면 캡처 배율: 기본 3배, 긴 변이 6000px를 넘지 않게 줄인다(기기 그림 한계 8192px 아래).
double layoutCapturePixelRatio(Size logical) {
  final longest = math.max(logical.width, logical.height);
  if (longest <= 0) return 3.0;
  return math.max(0.5, math.min(3.0, 6000 / longest));
}
