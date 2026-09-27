// 배치도 PLC·DCS·배리어·릴레이·전원·스위치 묶음(2026-09-27): 카탈로그 확정 값, 그림, 넣지 않은 것.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/elec_presets_dcs.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

ModulePreset preset(String n) =>
    kElecPresets.values.expand((l) => l).firstWhere((p) => p.name == n);

void main() {
  test('DCS·PLC 대표 값은 데이터시트와 같다', () {
    final cases = <(String, double, double, double)>[
      ('S7-1500 35mm 모듈 (지멘스, CPU 1511·PS 25W·DI 16 HF)', 35, 147, 129),
      ('S7-1500 PS 60W 전원 (지멘스)', 70, 147, 129),
      ('ET 200SP BaseUnit BU15 (지멘스)', 15, 117, 35),
      ('1756-A7 7슬롯 섀시 (로크웰)', 367.6, 158, 145),
      ('1756-A13 13슬롯 섀시 (로크웰)', 587.6, 158, 145),
      ('1756-PA72 전원 (로크웰)', 112, 140, 145),
      ('ANB10D·ANB11D 노드 유닛 19인치 랙 (요꼬가와)', 482.6, 221.5, 205),
      ('FIO 모듈 AAI141·ADV151 등 (요꼬가와)', 32.8, 130, 107.5),
      ('ATA4D계 단자대 (요꼬가와)', 65.6, 114, 72),
      ('A1BD5D DIN 단자판 (요꼬가와)', 210, 85.5, 68),
      ('DeltaV SQ·SX 제어기 (에머슨)', 41.8, 199.3, 162),
      ('AC 800M PM851~PM866 + TP830 (ABB)', 119, 186, 135),
      ('CI854 통신 유닛 + TP854 (ABB)', 59, 185, 127.5),
      ('KFD2-STC4-Ex1 배리어 (P+F, 20mm)', 20, 124, 115),
      ('KFD2-GUT-Ex1.D 배리어 (P+F, 40mm)', 40, 119, 115),
      ('IM33-11Ex-Hi/24VDC 절연 증폭기 (튜르크, 18mm)', 18, 110, 110),
      ('PLC-RSC-24DC/21 릴레이 모듈 (피닉스, 6.2mm)', 6.2, 80, 94),
      ('TRS 24VDC 1CO 릴레이 모듈 (웨이드뮬러, 6.4mm)', 6.4, 90, 88),
      ('QUINT-PS/1AC/24DC/10 전원 (피닉스)', 60, 130, 125),
      ('PRO ECO 120W 24V 5A 전원 (웨이드뮬러)', 40, 125, 100),
      ('SITOP PSU100S 24V 10A 전원 (지멘스)', 70, 125, 120),
      ('EDS-508A 8포트 스위치 (Moxa)', 80.2, 135, 105),
      ('SCALANCE XB005 5포트 스위치 (지멘스)', 45, 100, 87),
    ];
    for (final (n, w, h, d) in cases) {
      final p = preset(n);
      expect([p.width, p.height, p.depth], [w, h, d], reason: n);
    }
  });

  test('단일 출처·충돌 값은 넣지 않았다', () {
    final names = kDcsPresets.values
        .expand((l) => l)
        .map((p) => p.name)
        .join('|');
    for (final bad in [
      'XGT',
      '5069',
      '1734',
      'CHARM',
      'S800 I/O',
      'TU830',
      'C300',
      'MTL',
      'RS20',
      'FL SWITCH',
      'TOZ',
      'G2R',
      'G3NA',
      'LOGO',
      'PSE202U',
      'QUINT-DIODE',
    ]) {
      expect(names.contains(bad), isFalse, reason: bad);
    }
  });

  test('이름 중복 없음, 모양과 극·포트·슬롯 표기', () {
    final all = kDcsPresets.values.expand((l) => l).toList();
    expect(all.map((p) => p.name).toSet().length, all.length);
    for (final p in all) {
      expect(ElecShape.isElec(p.shape), isTrue, reason: p.name);
      expect(p.depth, isNotNull, reason: p.name);
    }
    expect(ElecShape.pitch(preset('1756-A13 13슬롯 섀시 (로크웰)').shape!), 13);
    expect(ElecShape.pitch(preset('EDS-508A 8포트 스위치 (Moxa)').shape!), 8);
    expect(ElecShape.style(preset('EDS-508A 8포트 스위치 (Moxa)').shape!), 'moxa');
    expect(all.length, greaterThanOrEqualTo(40));
  });

  test('모든 그림이 여러 크기에서 그려지고, 예전 el_psu도 그대로 그려진다', () {
    final shapes = [
      for (final p in kDcsPresets.values.expand((l) => l)) p.shape!,
      ElecShape.psu,
    ];
    for (final s in shapes) {
      for (final size in const [
        Size(35, 147),
        Size(30, 30),
        Size(482.6, 221.5),
        Size(6.2, 80),
        Size(120, 30),
      ]) {
        final rec = ui.PictureRecorder();
        InstrumentShapePainter(shape: s).paint(Canvas(rec), size);
        rec.endRecording();
      }
    }
  });
}
