// 배치도 판넬 미터·CT·퓨즈/PE 단자 묶음(2026-09-27): 카탈로그 확정 값, 그림, 넣지 않은 것.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/elec_presets_meters.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

ModulePreset preset(String n) =>
    kElecPresets.values.expand((l) => l).firstWhere((p) => p.name == n);

void main() {
  test('미터·CT·단자 대표 값은 카탈로그와 같다', () {
    final cases = <(String, double, double, double?)>[
      ('WYPMN48 디지털 미터 96×48 (운영, 판넬 구멍 91×45)', 96, 48, null),
      ('WYTM-3AA·3AV 디지털 미터 96×96 (운영, 판넬 구멍 92×92)', 96, 96, 80),
      ('WY-W08 광각 아날로그 미터 80×80 (운영, 구멍 Ø66)', 80, 80, null),
      ('WY-W11 광각 아날로그 미터 110×110 (운영, 구멍 Ø100)', 110, 110, null),
      ('METSECT5CC 변류기 (슈나이더, 관통 Ø21)', 44, 66, 37),
      ('METSECT5MA 변류기 (슈나이더, 관통 Ø27·부스바 창 25.5×15.5)', 56, 80, 63),
      ('ST 4-HESI 퓨즈 단자 (피닉스, 5×20)', 6.2, 61.5, 62.5),
      ('PT 4-PE·ST 4-PE 접지 단자 (피닉스)', 6.2, 56, 36.5),
      ('UT 4-PE 접지 단자 (피닉스)', 6.2, 47.7, 47.5),
    ];
    for (final (n, w, h, d) in cases) {
      final p = preset(n);
      expect([p.width, p.height, p.depth], [w, h, d], reason: n);
    }
  });

  test('판넬 부속(팬·히터·덕트·글랜드·조명·접지 바)과 단일 출처는 넣지 않았다', () {
    final names = kMeterPresets.values
        .expand((l) => l)
        .map((p) => p.name)
        .join('|');
    for (final bad in [
      '팬',
      '히터',
      '덕트',
      '글랜드',
      '조명',
      '접지 바',
      'MT4W',
      'PM2120',
      'WYCR',
      'HY-SQ4',
      'WSI',
    ]) {
      expect(names.contains(bad), isFalse, reason: bad);
    }
  });

  test('이름 중복 없음, 모양 표기', () {
    final all = kMeterPresets.values.expand((l) => l).toList();
    expect(all.map((p) => p.name).toSet().length, all.length);
    for (final p in all) {
      expect(ElecShape.isElec(p.shape), isTrue, reason: p.name);
      expect(ElecShape.style(p.shape!), isNotNull, reason: p.name);
    }
  });

  test('모든 그림이 여러 크기에서 그려진다', () {
    for (final p in kMeterPresets.values.expand((l) => l)) {
      for (final size in [
        Size(p.width, p.height),
        const Size(30, 30),
        const Size(6, 60),
      ]) {
        final rec = ui.PictureRecorder();
        InstrumentShapePainter(shape: p.shape!).paint(Canvas(rec), size);
        rec.endRecording();
      }
    }
  });
}
