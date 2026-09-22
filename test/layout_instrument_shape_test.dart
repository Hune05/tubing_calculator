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
      shape: InstrumentShape.dp,
    );
    final back = PlacedItem.fromJson(a.toJson());
    expect(back.shape, InstrumentShape.dp);

    final box = PlacedItem(id: 'b', name: '차단기', position: Offset.zero);
    expect(box.toJson().containsKey('shape'), isFalse);
    expect(PlacedItem.fromJson(box.toJson()).shape, isNull);
  });
}
