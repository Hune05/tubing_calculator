import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';

import 'instrument_shape_painter.dart';

// 🚀 배치도(모바일·태블릿 두 화면)가 함께 쓰는 데이터 모양과 치수 계산.
// 예전에는 두 화면 파일에 똑같은 코드가 각각 들어 있었다. 저장 형식이나 치수 계산 규칙을
// 바꿀 때는 이 파일 하나만 고치면 되고, test/layout_board_models_test.dart가 규칙을 지킨다.

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

  /// 계기 모양(InstrumentShape). 없으면 네모 모듈.
  final String? shape;
  const ModulePreset(this.name, this.width, this.height, {this.shape});
}

// 🚀 배선 덕트 크기 = 폭×높이(mm). 도면(정면)에는 폭만큼 놓이고, 세로(길이)는 기본 200에서
// 놓은 뒤 "모듈 속성 편집"에서 실제 길이로 고친다. 크기 목록은 국내 판넬 덕트 영신프라텍 DG 표준형
// (yspt.co.kr, 길이 2m, 백색·회색) 24가지. 자주 쓰는 10가지를 먼저 보인다(국내 판넬 부품몰 재고 기준).
const List<ModulePreset> kDuctPresets = [
  ModulePreset("ABS덕트 25×40", 25, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 30×40", 30, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 40×40", 40, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 40×60", 40, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 60×60", 60, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 60×80", 60, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 80×80", 80, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 80×100", 80, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 100×80", 100, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 100×100", 100, 200, shape: InstrumentShape.duct),
];

/// 덕트 나머지 크기(DG 표준형에서 kDuctPresets를 뺀 것).
const List<ModulePreset> kDuctMorePresets = [
  ModulePreset("ABS덕트 20×35", 20, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 60×40", 60, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 25×60", 25, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 30×60", 30, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 50×60", 50, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 80×60", 80, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 100×60", 100, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 30×80", 30, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 40×80", 40, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 50×80", 50, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 40×100", 40, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 60×100", 60, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 100×150", 100, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 150×100", 150, 200, shape: InstrumentShape.duct),
];

/// 덕트 고르기 창에 나오는 묶음(이름 → 크기 목록).
const Map<String, List<ModulePreset>> kDuctPresetGroups = {
  "자주 쓰는 크기 (폭×높이)": kDuctPresets,
  "그 밖의 크기": kDuctMorePresets,
};

/// 계기(트랜스미터·스위치) 모듈. 정면에서 본 몸통 크기(2인치 브래킷 빼고)다.
/// 제조사 도면의 외곽 치수를 mm로 옮겼다(2026-09 판). 제조사 이름 순서가 화면에 나오는 순서다.
/// "≈"는 도면에 숫자가 없어 비례로 잰 값(±5mm 안팎).
///
/// 출처
/// - 요꼬가와: GS 01C31B01-01EN p.14(EJA110E), GS 01C31E01-01EN p.12(EJA430E),
///   GS 01C31F01-01EN p.11(EJA530E, 접속 코드 7). 수평 배관의 가로 115는 ≈.
/// - 오토롤(듀온시스템): 카탈로그 C3100-E05C p.12(APT3100), C3200-E05C p.8(APT3200).
/// - 로즈마운트: PDS 00813-0100-4001 p.97·100·102(3051), 00813-0100-4101 p.88·96(2051),
///   00813-0100-4030 p.23(2120 나사형 표준 길이), 00813-0100-4130 p.23(2130).
///   3051 재래식 플랜지 세로 200은 ≈(2051은 197).
/// - 로즈마운트 상표 압력 스위치는 없다(에머슨 압력 스위치는 ASCO 상표).
/// - 비카(WIKA) MA: PV 31.11(04/2022) p.8 MA·MAG·MAH 앞 그림. 가로 161 = 87+74(케이블 입구
///   포함, 브래킷 빼고). 세로 121 = 뚜껑 위~입구 중심 71(p.9) + 다이어프램 접속구 끝까지 50(p.8).
///   피스톤 감지는 +18(68), 용접 다이어프램 피스톤은 +38(88).
/// - SOR: CAT216(Form 216, 07.26) p.21 NN·p.22 RN·p.28 B3, CAT468 p.14(101 차압 NN).
///   세로는 상자 위~1/4" NPT 접속구 끝(1/2" NPT 피스톤형은 +13). 가로는 오른쪽 배관 허브 포함.
///   스위치 한 벌(SPDT)·두 벌(DPDT) 외곽은 같다. 청색은 카탈로그에 없고 현장 모습 기준.
const Map<String, List<ModulePreset>> kInstrumentPresets = {
  "요꼬가와": [
    ModulePreset("EJA110E DPT 수직배관", 175, 138, shape: InstrumentShape.dpSide),
    ModulePreset("EJA110E DPT 수평배관", 115, 175, shape: InstrumentShape.dp),
    ModulePreset("EJA430E PT 수직배관", 175, 138, shape: InstrumentShape.dpSide),
    ModulePreset("EJA430E PT 수평배관", 115, 175, shape: InstrumentShape.gp),
    ModulePreset("EJA530E PT 인라인", 95, 159, shape: InstrumentShape.inline),
  ],
  "오토롤": [
    ModulePreset("APT3100 DPT", 86, 194, shape: InstrumentShape.dp),
    ModulePreset("APT3200 PT", 86, 160, shape: InstrumentShape.inline),
  ],
  "로즈마운트": [
    ModulePreset("3051CD DPT", 104, 181, shape: InstrumentShape.dp),
    ModulePreset(
      "3051CD DPT 재래식 플랜지",
      115,
      200,
      shape: InstrumentShape.dpTraditional,
    ),
    ModulePreset("3051CG PT", 104, 181, shape: InstrumentShape.gp),
    ModulePreset("3051TG PT 인라인", 104, 183, shape: InstrumentShape.inline),
    ModulePreset("2051CD DPT", 98, 179, shape: InstrumentShape.dp),
    ModulePreset("2051TG PT 인라인", 98, 183, shape: InstrumentShape.inline),
    ModulePreset("2120 레벨 스위치", 120, 220, shape: InstrumentShape.fork),
    ModulePreset("2120 레벨 스위치 나일론", 141, 196, shape: InstrumentShape.fork),
    ModulePreset("2130 레벨 스위치", 120, 251, shape: InstrumentShape.fork),
    ModulePreset("2130 레벨 스위치 고온", 120, 418, shape: InstrumentShape.fork),
  ],
  "SOR": [
    ModulePreset("6NN 압력 스위치", 108, 147, shape: InstrumentShape.sorPiston),
    ModulePreset("12NN 압력 스위치 저압", 108, 150, shape: InstrumentShape.sorWide),
    ModulePreset("54NN 압력 스위치", 108, 151, shape: InstrumentShape.sorDiaphragm),
    ModulePreset("6RN 압력 스위치", 107, 172, shape: InstrumentShape.sorPiston),
    ModulePreset("54RN 압력 스위치", 107, 176, shape: InstrumentShape.sorDiaphragm),
    ModulePreset("6B3 방폭 압력 스위치", 150, 225, shape: InstrumentShape.sorExp),
    ModulePreset("101NN 차압 스위치", 108, 154, shape: InstrumentShape.sorDp),
  ],
  "비카": [ModulePreset("MA 압력 스위치", 161, 121, shape: InstrumentShape.exdSwitch)],
};

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

  /// 계기 모양(InstrumentShape). 없으면 네모 모듈.
  String? shape;

  PlacedItem({
    required this.id,
    required this.name,
    required this.position,
    this.width = 80.0,
    this.height = 80.0,
    this.isSelected = false,
    this.isLocked = false,
    this.shape,
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
    if (shape != null) 'shape': shape,
  };

  factory PlacedItem.fromJson(Map<String, dynamic> j) => PlacedItem(
    id: j['id'] as String,
    name: j['name'] as String? ?? "이름 없음",
    position: Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
    width: (j['w'] as num?)?.toDouble() ?? 80.0,
    height: (j['h'] as num?)?.toDouble() ?? 80.0,
    isLocked: j['locked'] as bool? ?? false,
    shape: j['shape'] as String?,
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
// 3. 서버(layouts 모음)에 저장하는 칸과 불러오기
// ---------------------------------------------------------
// 저장된 배치도의 칸 이름은 절대 바꾸거나 빼지 않는다. 예전에 저장한 배치도가
// 그대로 열려야 하기 때문이다(test/layout_board_compat_test.dart가 지킨다).
// 새 칸을 더할 때는 여기에만 더하고, 읽을 때는 그 칸이 없어도 되게 만든다.

/// layouts 문서에 저장하는 칸(저장 시각 칸은 서버 시각이라 부르는 쪽에서 붙인다).
Map<String, dynamic> layoutSaveFields({
  required String projectId,
  required String projectName,
  required double panelWidth,
  required double panelHeight,
  required List<PlacedItem> items,
  required List<PlacedDimension> dimensions,
  required String? backgroundImagePath,
  required double backgroundOpacity,
}) => {
  'projectId': projectId,
  'projectName': projectName,
  'panelWidth': panelWidth,
  'panelHeight': panelHeight,
  'items': items.map((e) => e.toJson()).toList(),
  'dimensions': dimensions.map((e) => e.toJson()).toList(),
  'backgroundImagePath': backgroundImagePath,
  'backgroundOpacity': backgroundOpacity,
};

/// 저장된 문서(또는 임시 저장·템플릿)의 items 칸을 모듈 목록으로 읽는다. 칸이 없으면 빈 목록.
List<PlacedItem> layoutItemsFromData(Map<String, dynamic> data) =>
    ((data['items'] as List?) ?? const [])
        .map((e) => PlacedItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

/// 저장된 문서의 dimensions 칸을 치수선 목록으로 읽는다. 칸이 없으면 빈 목록.
List<PlacedDimension> layoutDimensionsFromData(Map<String, dynamic> data) =>
    ((data['dimensions'] as List?) ?? const [])
        .map(
          (e) => PlacedDimension.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

// ---------------------------------------------------------
// 4. 만든 사람 칸(목록에 내 배치도만 보이게)
// ---------------------------------------------------------
// 예전 배치도에는 만든 사람 칸이 없다. 그래서 새 칸 두 개(ownerUid, ownerName)는
// 새 문서를 처음 저장할 때만 붙이고, 칸이 없는 예전 배치도는 누구 목록에나 예전처럼 보인다.
// 남이 만든 예전 배치도를 고쳐 저장해도 칸을 붙이지 않는다(붙이면 그 사람 목록에서 사라진다).

/// 만든 사람 칸 이름. 이미 있는 칸 이름과 겹치지 않는다.
const String kLayoutOwnerUidField = 'ownerUid';
const String kLayoutOwnerNameField = 'ownerName';

/// 지금 앱을 쓰는 사람. uid는 로그인(인증)했을 때만, name은 프로필 이름.
class LayoutOwner {
  final String? uid;
  final String? name;
  const LayoutOwner({this.uid, this.name});

  bool get isEmpty =>
      (uid == null || uid!.isEmpty) && (name == null || name!.isEmpty);
}

/// 새 문서를 저장할 때 덧붙이는 만든 사람 칸. 아는 것이 없으면 빈 맵.
Map<String, dynamic> layoutOwnerFields(LayoutOwner me) => {
  if (me.uid != null && me.uid!.isNotEmpty) kLayoutOwnerUidField: me.uid,
  if (me.name != null && me.name!.isNotEmpty) kLayoutOwnerNameField: me.name,
};

/// 목록에 이 배치도를 보여 줄지.
/// - 만든 사람 칸이 없는 예전 배치도: 보여 준다.
/// - uid가 양쪽에 다 있으면 uid로 비교한다.
/// - 아니면 이름이 양쪽에 다 있을 때 이름으로 비교한다.
/// - 비교할 것이 없으면(로그인도 이름도 없음) 예전처럼 보여 준다.
bool layoutVisibleTo(Map<String, dynamic> data, LayoutOwner me) {
  final String docUid = (data[kLayoutOwnerUidField] as String?)?.trim() ?? '';
  final String docName = (data[kLayoutOwnerNameField] as String?)?.trim() ?? '';
  if (docUid.isEmpty && docName.isEmpty) return true;
  final String myUid = me.uid?.trim() ?? '';
  final String myName = me.name?.trim() ?? '';
  if (docUid.isNotEmpty && myUid.isNotEmpty) return docUid == myUid;
  if (docName.isNotEmpty && myName.isNotEmpty) return docName == myName;
  return true;
}

/// 문서가 마지막으로 고쳐진 때(updatedAt, 없으면 createdAt). 둘 다 없으면 1970년.
DateTime layoutEditedAt(Map<String, dynamic> data) {
  final Object? ts = data['updatedAt'] ?? data['createdAt'];
  if (ts is Timestamp) return ts.toDate();
  if (ts is DateTime) return ts;
  return DateTime.fromMillisecondsSinceEpoch(0);
}

/// "다른 도면에서 가져오기"에 보여 줄 도면. 목록 화면과 같은 규칙으로 내 배치도만,
/// 지금 열어 둔 도면은 빼고, 최근 고친 순으로 늘어놓는다.
List<T> layoutImportCandidates<T>(
  Iterable<T> docs, {
  required LayoutOwner me,
  required String? currentId,
  required Map<String, dynamic> Function(T) dataOf,
  required String Function(T) idOf,
}) {
  final list = docs
      .where((d) => idOf(d) != currentId && layoutVisibleTo(dataOf(d), me))
      .toList();
  list.sort(
    (a, b) => layoutEditedAt(dataOf(b)).compareTo(layoutEditedAt(dataOf(a))),
  );
  return list;
}
