// 배치도 피팅: 조각 목록으로 적은 피팅의 크기 셈, 모든 피팅이 그려지는지, 규격 거르기.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/fitting_spec.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/instrument_shape_painter.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/layout_board_models.dart';

void main() {
  test('곧은 피팅 크기 = 조각 길이 합 × 가장 굵은 조각', () {
    final s = fittingSpecSize('fs:n:14.2:17.5,h:24.9:22.2')!;
    expect(s.width, closeTo(39.1, 0.001));
    expect(s.height, closeTo(22.2, 0.001));
  });

  test('엘보 크기는 팔 길이와 굵기로 셈한다', () {
    // 오른쪽 너트 끝 31.2, 아래 암나사 22.4, 몸통 17.5
    final s = fittingSpecSize('fl:b=17.5;r=n,31.2,17.5;d=f,22.4,17.5')!;
    expect(s.width, closeTo(17.5 / 2 + 31.2, 0.01));
    expect(s.height, closeTo(17.5 / 2 + 22.4, 0.01));
  });

  test('카탈로그 길이가 그대로 들어간다(하이록 H-200TF)', () {
    ModulePreset find(String n) =>
        kFittingPresets.values.expand((l) => l).firstWhere((p) => p.name == n);
    expect(find('피메일 커넥터 3/8"×3/8" NPT').width, 39.1); // CFC 6-6N L
    expect(find('리듀싱 유니언 1/2"×3/8"').width, 48.5); // CUR 8-6 L
    expect(find('벌크헤드 메일 커넥터 1/2"×1/2" NPT').width, 68.8); // CBMC 8-8N L
  });

  test('모든 피팅이 크기가 있고, 이름에서 관 규격을 읽을 수 있고, 그려진다', () {
    final names = <String>{};
    for (final p in kFittingPresets.values.expand((l) => l)) {
      expect(p.width, greaterThan(0), reason: p.name);
      expect(p.height, greaterThan(0), reason: p.name);
      expect(kFittingSizes, contains(fittingTubeSize(p.name)), reason: p.name);
      expect(names.add(p.name), isTrue, reason: '겹친 이름 ${p.name}');
      for (final size in [Size(p.width, p.height), Size(p.height, p.width)]) {
        final rec = ui.PictureRecorder();
        InstrumentShapePainter(shape: p.shape!).paint(Canvas(rec), size);
        rec.endRecording();
      }
    }
    // 3/8"·1/2"는 1/4"보다 훨씬 많다.
    int count(String s) => kFittingPresets.values
        .expand((l) => l)
        .where((p) => fittingTubeSize(p.name) == s)
        .length;
    expect(count('3/8"'), greaterThan(30));
    expect(count('1/2"'), greaterThan(30));
  });

  test('밸브: 하이록 인라인 밸브가 카탈로그 길이로 들어가고 모두 그려진다', () {
    ModulePreset find(String n) =>
        kValvePresets.values.expand((l) => l).firstWhere((p) => p.name == n);
    expect(find('NV 니들 밸브 1/2" 튜브').width, 97); // NV4H-8T L
    expect(find('110 볼 밸브 3/8" 튜브').width, 125); // L/2 45 + 레버 80
    for (final p in kValvePresets.values.expand((l) => l)) {
      expect(p.width, greaterThan(0), reason: p.name);
      final rec = ui.PictureRecorder();
      InstrumentShapePainter(
        shape: p.shape!,
      ).paint(Canvas(rec), Size(p.width, p.height));
      rec.endRecording();
    }
  });
}
