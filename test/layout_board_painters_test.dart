import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart'
    as mob;
// 폰·태블릿 화면을 하나로 합친 뒤에도 예전 비교 테스트를 그대로 두려고 같은 파일을 두 이름으로 읽는다.
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart'
    as tab;

// 배치도의 안내선·모눈 그리기 결과를 지킨다. 화면에 그린 그림의 픽셀을 그대로 비교한다.
// 모바일/태블릿이 같은 그림을 그리는지, 그리고 그림이 예전과 달라지지 않았는지 확인한다.
Future<List<int>> paint(WidgetTester tester, CustomPainter p, Size size) async {
  return (await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    p.paint(canvas, size);
    final img = await rec.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List().toList();
  }))!;
}

int hash(List<int> b) {
  var h = 0x811c9dc5;
  for (final x in b) {
    h = ((h ^ x) * 0x01000193) & 0xffffffff;
  }
  return h;
}

void main() {
  const size = Size(300, 300);
  dimensionTests();

  test('치수 숫자 배율: 줄여 보면 화면에서 11px 아래로 안 작아지고, 확대하면 원래 크기', () {
    // 스키드(2400mm)를 폰 화면에 맞추면 0.13배 안팎: 10mm 글씨가 화면 1.3px였다.
    const double fitZoom = 0.132;
    expect(10 * mob.dimensionMarkScale(fitZoom) * fitZoom, closeTo(11, 1e-9));
    expect(mob.dimensionMarkScale(1.1), 1);
    expect(mob.dimensionMarkScale(3), 1);
    expect(mob.dimensionMarkScale(0.001), 12);
  });

  testWidgets('벽에 바짝 붙은 부품: 치수 숫자를 부품 위가 아니라 도면 안 비킨 자리에 적는다', (tester) async {
    // 오른쪽 벽까지 20mm. 숫자 칸(70mm 안팎)이 사이에 안 들어가 예전엔 부품을 덮었다.
    final item = mob.PlacedItem(
      id: 'a',
      name: 'A',
      position: const Offset(80, 100),
      width: 100,
      height: 100,
    );
    final px = await paint(
      tester,
      mob.SmartGuidePainter(
        item: item,
        allItems: [item],
        panelWidth: 200,
        panelHeight: 300,
        currentType: mob.DimensionType.edge,
      ),
      const Size(320, 300),
    );
    bool inkAt(int x, int y) {
      final i = (y * 320 + x) * 4;
      return px[i] < 200 || px[i + 1] < 200 || px[i + 2] < 200;
    }

    // 부품 오른쪽 안쪽(가로 150~178, 세로 125~175)에는 아무것도 안 그린다.
    var inside = 0;
    for (int y = 125; y < 175; y++) {
      for (int x = 150; x < 178; x++) {
        if (inkAt(x, y)) inside++;
      }
    }
    expect(inside, 0);
    // 숫자 칸은 도면(가로 200) 안, 부품 위나 아래 벽 쪽(가로 140~200)에 있다. 도면 밖은 잘려 안 보인다.
    var beside = 0, beyond = 0;
    for (int y = 0; y < 300; y++) {
      if (y >= 100 && y < 200) continue;
      for (int x = 140; x < 200; x++) {
        if (inkAt(x, y)) beside++;
      }
    }
    for (int y = 0; y < 300; y++) {
      for (int x = 204; x < 320; x++) {
        if (inkAt(x, y)) beyond++;
      }
    }
    expect(beside, greaterThan(20));
    expect(beyond, 0);
  });

  testWidgets('모눈 그리기: 모바일·태블릿 같음, 예전 그림과 같음', (tester) async {
    final a = await paint(tester, mob.GridPainter(gridSize: 10), size);
    final b = await paint(tester, tab.GridPainter(gridSize: 10), size);
    expect(hash(a), hash(b));
    expect(hash(a), gridHash);
  });

  testWidgets('안내선 그리기(센터·측면): 모바일·태블릿 같음, 예전 그림과 같음', (tester) async {
    for (final t in [mob.DimensionType.center, mob.DimensionType.edge]) {
      final item = mob.PlacedItem(
        id: 'a',
        name: 'A',
        position: const Offset(100, 100),
        width: 60,
        height: 40,
      );
      final other1 = mob.PlacedItem(
        id: 'b',
        name: 'B',
        position: const Offset(210, 104),
        width: 50,
        height: 50,
      );
      final other2 = mob.PlacedItem(
        id: 'c',
        name: 'C',
        position: const Offset(96, 30),
        width: 70,
        height: 30,
      );
      final a = await paint(
        tester,
        mob.SmartGuidePainter(
          item: item,
          allItems: [item, other1, other2],
          panelWidth: 300,
          panelHeight: 300,
          currentType: t,
        ),
        size,
      );
      final ti = tab.PlacedItem.fromJson(item.toJson());
      final b = await paint(
        tester,
        tab.SmartGuidePainter(
          item: ti,
          allItems: [
            ti,
            tab.PlacedItem.fromJson(other1.toJson()),
            tab.PlacedItem.fromJson(other2.toJson()),
          ],
          panelWidth: 300,
          panelHeight: 300,
          currentType: tab.DimensionType.values.byName(t.name),
        ),
        size,
      );
      expect(hash(a), hash(b), reason: '$t');
      expect(
        hash(a),
        t == mob.DimensionType.center ? guideCenterHash : guideEdgeHash,
      );
    }
  });
}

const int gridHash = 3494248389;
const int guideCenterHash = 586061238; // 좁은 사이 숫자는 도면 안 비킨 자리에(2026-09-22)
const int guideEdgeHash = 4074337249;

// ── 치수선 그리기 ──
Future<List<int>> _dims(WidgetTester tester, bool mobile) async {
  // 같은 배치를 두 화면의 클래스로 각각 만들어 그린다.
  Map<String, dynamic> a(String id, double x, double y, double w, double h) => {
    'type': 'item',
    'id': id,
    'name': id,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
  };
  final specs = [
    (
      'd1',
      a('a', 20, 20, 60, 40),
      a('b', 200, 30, 50, 50),
      'center',
      false,
      null,
      false,
      null,
    ),
    (
      'd2',
      a('a', 20, 20, 60, 40),
      a('c', 30, 200, 40, 60),
      'edge',
      false,
      500.0,
      true,
      '메모',
    ),
    (
      'd3',
      a('b', 200, 30, 50, 50),
      a('c', 30, 200, 40, 60),
      'center',
      true,
      null,
      false,
      null,
    ),
  ];
  if (mobile) {
    final dims = [
      for (final s in specs)
        mob.PlacedDimension(
          id: s.$1,
          p1: mob.PlacedItem.fromJson(s.$2),
          p2: mob.PlacedItem.fromJson(s.$3),
          type: mob.DimensionType.values.byName(s.$4),
          isDiagonal: s.$5,
          minGapMm: s.$6,
          isSafetyCritical: s.$7,
          note: s.$8,
        ),
    ];
    return paint(
      tester,
      mob.DimensionPainter(
        dimensions: dims,
        activePoint: dims.first.p1,
        panelWidth: 300,
        panelHeight: 300,
        version: 1,
      ),
      const Size(300, 300),
    );
  }
  final dims = [
    for (final s in specs)
      tab.PlacedDimension(
        id: s.$1,
        p1: tab.PlacedItem.fromJson(s.$2),
        p2: tab.PlacedItem.fromJson(s.$3),
        type: tab.DimensionType.values.byName(s.$4),
        isDiagonal: s.$5,
        minGapMm: s.$6,
        isSafetyCritical: s.$7,
        note: s.$8,
      ),
  ];
  return paint(
    tester,
    tab.DimensionPainter(
      dimensions: dims,
      activePoint: dims.first.p1,
      // 앱은 폰·태블릿 모두 도면 크기를 넘긴다(숫자 칸을 도면 안에 두는 데 쓴다).
      panelWidth: 300,
      panelHeight: 300,
      version: 1,
    ),
    const Size(300, 300),
  );
}

void dimensionTests() {
  testWidgets('치수선 그리기: 모바일·태블릿 같음, 예전 그림과 같음', (tester) async {
    final a = await _dims(tester, true);
    final b = await _dims(tester, false);
    expect(hash(a), hash(b));
    expect(hash(a), dimensionHash);
  });
}

const int dimensionHash = 526321441; // 가장자리 숫자 칸은 도면 안으로(2026-09-22)
