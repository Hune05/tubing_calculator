import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart'
    as mob;
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/tablet_layout_board_page.dart'
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
const int guideCenterHash = 4129728922;
const int guideEdgeHash = 1031198377;
