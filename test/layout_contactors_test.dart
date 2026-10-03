// 배치도 접촉기·열동·보호 계전기·타이머 묶음(2026-09-27): 카탈로그 확정 값, 그림 종류, 넣지 않은 것.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/elec_presets_contactors.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

ModulePreset preset(String n) =>
    kElecPresets.values.expand((l) => l).firstWhere((p) => p.name == n);

void main() {
  test('접촉기·계전기 대표 값은 카탈로그와 같다', () {
    final cases = <(String, double, double, double)>[
      ('LC1D09·12·18 접촉기 3P (슈나이더)', 45, 77, 86),
      ('LC1D25·32 접촉기 3P (슈나이더)', 45, 85, 92),
      ('LC1D40A·65A 접촉기 3P (슈나이더)', 55, 122, 120),
      ('MT-12 과부하계전기 (LS)', 45, 73.2, 63.7),
      ('MT-32 과부하계전기 (LS)', 45, 74.55, 86.3),
      ('LRD08·16 과부하계전기 (슈나이더)', 45, 66, 70),
      ('GMP40 전자식 전동기 보호 계전기 (LS, 직결형)', 53, 78, 87.5),
      ('GMP60T 전자식 전동기 보호 계전기 (LS)', 72, 67, 69),
      ('GMP60-3T 전자식 전동기 보호 계전기 (LS)', 95.3, 94.6, 97),
      ('EOCR-3DM2 전자식 과전류 계전기 (삼화)', 70, 74.5, 83.8),
      ('H3CR-A·A8 타이머 (옴론, 판 매입 48×48, 소켓 포함 깊이)', 48, 48, 81.5),
      ('AT8N 타이머 (오토닉스, 판 매입 48×48, 소켓 별도)', 48, 48, 64.5),
      ('K8AK-PM 전압 감시 계전기 (옴론, 레일형)', 22.5, 90, 100),
    ];
    for (final (n, w, h, d) in cases) {
      final p = preset(n);
      expect([p.width, p.height, p.depth], [w, h, d], reason: n);
    }
  });

  test('충돌·단일 출처 값은 넣지 않았다', () {
    final names = kContactorPresets.values
        .expand((l) => l)
        .map((p) => p.name)
        .join('|');
    for (final bad in [
      'MC-22',
      'MC-32',
      'MC-40',
      'MT-63',
      'MT-95',
      'AF09',
      'DILM',
      '3RT',
      'H3Y',
      'T48N',
      'ATE',
      'PG-08',
    ]) {
      expect(names.contains(bad), isFalse, reason: bad);
    }
  });

  test('모양 이름과 이름 중복', () {
    final all = kContactorPresets.values.expand((l) => l).toList();
    expect(all.map((p) => p.name).toSet().length, all.length);
    for (final p in all) {
      expect(ElecShape.isElec(p.shape), isTrue, reason: p.name);
      expect(ElecShape.style(p.shape!), isNotNull, reason: p.name);
      expect(p.depth, isNotNull, reason: p.name);
    }
  });

  test('새 그림 다섯 가지와 예전 el_mc가 여러 크기에서 그려진다', () {
    final shapes = [
      for (final p in kContactorPresets.values.expand((l) => l)) p.shape!,
      ElecShape.mc,
    ];
    for (final s in shapes) {
      for (final size in const [
        Size(45, 77),
        Size(30, 30),
        Size(90, 154),
        Size(22.5, 90),
      ]) {
        final rec = ui.PictureRecorder();
        InstrumentShapePainter(shape: s).paint(Canvas(rec), size);
        rec.endRecording();
      }
    }
  });
}
