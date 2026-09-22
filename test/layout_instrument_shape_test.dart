// 배치도 계기 모양: 모든 모양이 어떤 크기(돌린 것 포함)로도 그려지고, 저장했다 읽어도 모양이 남는지.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/instrument_shape_painter.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/layout_board_models.dart';

void main() {
  test('계기 모듈은 모두 모양이 있다', () {
    for (final p in kInstrumentPresets.values.expand((l) => l)) {
      expect(p.shape, isNotNull, reason: p.name);
    }
  });

  test('모든 모양이 원래 크기·돌린 크기·아주 작은 크기로 그려진다', () {
    const shapes = [
      InstrumentShape.dp,
      InstrumentShape.gp,
      InstrumentShape.dpTraditional,
      InstrumentShape.dpSide,
      InstrumentShape.inline,
      InstrumentShape.fork,
      InstrumentShape.duct,
      InstrumentShape.exdSwitch,
      InstrumentShape.sorPiston,
      InstrumentShape.sorDiaphragm,
      InstrumentShape.sorWide,
      InstrumentShape.sorDp,
      InstrumentShape.sorExp,
      InstrumentShape.rmCoplanar,
      InstrumentShape.rmTraditional,
      InstrumentShape.rmInline,
      InstrumentShape.autrolDp,
      InstrumentShape.autrolPt,
      InstrumentShape.ykHorizontal,
      InstrumentShape.ykVertical,
      InstrumentShape.ykInline,
      InstrumentShape.fork2120,
      InstrumentShape.fork2120Nylon,
      InstrumentShape.fork2130,
      InstrumentShape.fork2130Long,
      InstrumentShape.fitUnion,
      InstrumentShape.fitElbow,
      InstrumentShape.fitTee,
      InstrumentShape.fitCross,
      InstrumentShape.fitMale,
      InstrumentShape.fitMaleElbow,
      InstrumentShape.fitBulkhead,
      InstrumentShape.mv2,
      InstrumentShape.mv3,
      InstrumentShape.mv3Flange,
      InstrumentShape.mv5,
      InstrumentShape.mv5Flange,
      InstrumentShape.gv1,
      InstrumentShape.gv2,
      InstrumentShape.swV2,
      InstrumentShape.swV3,
      InstrumentShape.swV5,
      'unknown',
    ];
    for (final shape in shapes) {
      for (final size in const [
        Size(104, 181),
        Size(181, 104),
        Size(120, 418),
        Size(10, 12),
        Size(50, 50),
      ]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        InstrumentShapePainter(shape: shape).paint(canvas, size);
        expect(recorder.endRecording(), isNotNull);
      }
    }
  });

  test('모양은 저장했다 읽어도 남고, 네모 모듈에는 칸이 안 생긴다', () {
    final a = PlacedItem(
      id: 'a',
      name: '3051CD DPT',
      position: const Offset(10, 20),
      width: 104,
      height: 181,
      shape: InstrumentShape.rmCoplanar,
    );
    final back = PlacedItem.fromJson(a.toJson());
    expect(back.shape, InstrumentShape.rmCoplanar);

    final box = PlacedItem(id: 'b', name: '차단기', position: Offset.zero);
    expect(box.toJson().containsKey('shape'), isFalse);
    expect(PlacedItem.fromJson(box.toJson()).shape, isNull);
  });

  test('예전 모양 이름으로 저장된 계기는 이름이 같으면 모델별 모양으로 읽는다', () {
    PlacedItem read(String name, String shape) => PlacedItem.fromJson({
      'id': 'x',
      'name': name,
      'x': 0,
      'y': 0,
      'shape': shape,
    });
    expect(read('EJA110E DPT 수평배관', 'dp').shape, InstrumentShape.ykHorizontal);
    expect(read('APT3100 DPT', 'dp').shape, InstrumentShape.autrolDp);
    expect(read('2130 레벨 스위치 고온', 'fork').shape, InstrumentShape.fork2130Long);
    // 이름을 고친 것은 예전 모양 그대로(그려지기는 한다).
    expect(read('1번 차압계', 'dp').shape, 'dp');
    // 새 이름은 건드리지 않는다.
    expect(read('MA 압력 스위치', 'exd_switch').shape, 'exd_switch');
  });
}
