// 배치도 차단기 묶음(2026-09-27): 카탈로그 확정 값, 이름 중복 없음, 그림 종류별로 그려지는지.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/elec_presets_breakers.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

ModulePreset preset(String n) =>
    kElecPresets.values.expand((l) => l).firstWhere((p) => p.name == n);

void main() {
  test('차단기 묶음의 대표 값은 카탈로그와 같다', () {
    // (이름, 가로, 세로, 깊이)
    final cases = <(String, double, double, double)>[
      ('Susol TS100·160·250 3P (LS)', 105, 160, 86),
      ('Susol TS400·630 4P (LS)', 186.5, 260, 110),
      ('Susol TS800 3P (LS)', 210, 320, 135),
      ('Metasol 250AF 4P (LS)', 140, 165, 68.5),
      ('Metasol 800AF 3P (LS)', 210, 280, 109),
      ('HGM 160·250AF 4P (HD현대)', 140, 165, 68),
      ('HGM 630·800AF 3P (HD현대)', 210, 280, 110),
      ('HGP800 4P (HD현대)', 280, 320, 135),
      ('Tmax XT4 3P (ABB)', 105, 160, 82.5),
      ('Compact NSX100~250 3P (슈나이더)', 105, 161, 86),
      ('NZM2 4P (이튼)', 140, 145, 103),
      ('Susol ACB D프레임 630~2000A 인출형 3P (LS)', 334, 430, 375),
      ('Susol ACB G프레임 고정형 4P (LS)', 981, 300, 295),
      ('HGS·HGN A프레임 인출형 4P (HD현대)', 413, 460, 368.4),
      ('HGS·HGN B프레임 고정형 3P (HD현대)', 408.4, 404.4, 295.8),
      ('Emax 2 E2.2 인출형 4P (ABB)', 407, 425, 383),
      ('Emax 2 E6.2 고정형 3P (ABB)', 762, 371, 270),
      ('3WL 크기 II(~4000A) 고정형 4P (지멘스)', 590, 434, 291),
      ('3WL 크기 III(~6300A) 인출형 3P (지멘스)', 704, 465.5, 471),
      ('IZMX40 인출형 3P (이튼)', 426, 456, 393),
      ('IZM99 고정형 4P (이튼)', 1161, 461, 372),
    ];
    for (final (n, w, h, d) in cases) {
      final p = preset(n);
      expect([p.width, p.height, p.depth], [w, h, d], reason: n);
    }
    expect(preset('MMS-32S 전동기 보호 차단기 (LS)').width, 45);
    expect(preset('MS132 10A 초과 전동기 보호 차단기 (ABB)').height, 97.8);
    expect(preset('GV2ME10 전동기 보호 차단기 (슈나이더)').depth, 78.5);
  });

  test('160AF 이상 2P는 3P와 같은 폭(가운데 극만 뺀 틀)', () {
    for (final f in ['HGM 160·250AF', 'HGM 400AF', 'HGM 630·800AF']) {
      expect(
        preset('$f 2P (HD현대)').width,
        preset('$f 3P (HD현대)').width,
        reason: f,
      );
    }
    expect(
      preset('Metasol 400AF 2P (LS)').width,
      preset('Metasol 400AF 3P (LS)').width,
    );
  });

  test('단일 출처·충돌 값은 넣지 않았다', () {
    final names = kBreakerPresets.values
        .expand((l) => l)
        .map((p) => p.name)
        .join('|');
    for (final bad in [
      '3VA',
      'XT1',
      'XT3',
      'XT5',
      'NZM1',
      'NZM3',
      'Masterpact',
      'NSX400',
      'HGN D',
    ]) {
      expect(names.contains(bad), isFalse, reason: bad);
    }
  });

  test('이름이 겹치지 않고 극수·모양 표기가 맞다', () {
    final all = kBreakerPresets.values.expand((l) => l).toList();
    final names = all.map((p) => p.name).toList();
    expect(names.toSet().length, names.length);
    for (final p in all) {
      expect(ElecShape.isElec(p.shape), isTrue, reason: p.name);
      final m = RegExp(r' (\d)P ').firstMatch(p.name);
      if (m != null) {
        expect(
          ElecShape.pitch(p.shape!),
          double.parse(m.group(1)!),
          reason: p.name,
        );
      }
      expect(p.depth, isNotNull, reason: p.name);
    }
    // 전체 개수가 갑자기 줄지 않게 잡아 둔다.
    expect(all.length, greaterThanOrEqualTo(110));
  });

  test('모양 이름 해석: el_mccb:ls:3 → 모양 ls, 극 수 3', () {
    expect(ElecShape.style('el_mccb:ls:3'), 'ls');
    expect(ElecShape.pitch('el_mccb:ls:3'), 3);
    expect(ElecShape.style('el_tb:10'), isNull);
    expect(ElecShape.pitch('el_tb:10'), 10);
    expect(ElecShape.style('el_mpcb:rocker'), 'rocker');
    expect(ElecShape.pitch('el_mpcb:rocker'), isNull);
    expect(ElecShape.style('el_mccb'), isNull);
  });

  test('모든 차단기 그림이 목록 크기와 작은 크기에서 그려진다', () {
    for (final p in kBreakerPresets.values.expand((l) => l)) {
      for (final size in [
        Size(p.width, p.height),
        const Size(30, 40),
        Size(p.width / 4, p.height / 4),
      ]) {
        final rec = ui.PictureRecorder();
        InstrumentShapePainter(shape: p.shape!).paint(Canvas(rec), size);
        rec.endRecording();
      }
    }
    // 그냥 el_mccb(예전 항목)도 그대로 그려진다.
    final rec = ui.PictureRecorder();
    InstrumentShapePainter(
      shape: ElecShape.mccb,
    ).paint(Canvas(rec), const Size(60, 90));
    rec.endRecording();
  });
}
