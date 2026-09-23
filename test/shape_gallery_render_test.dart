// 배치도 부품 모양을 그림 파일로 뽑는다(모양 점검용). SHAPE_GALLERY_OUT 환경 변수에
// 폴더를 주면 그 폴더에 instrument.png / skid.png 를 쓴다. 없으면 그리기만 하고 끝.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/elec_presets.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/instrument_shape_painter.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/layout_board_models.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/skid_part_painter.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/skid_presets.dart';

const double _cell = 220;
const double _box = 160;
const int _cols = 4;
const int _perSheet = 16;

void _label(Canvas c, String text, Offset at, double w) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(color: Colors.black, fontSize: 11),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: w);
  tp.paint(c, at);
}

Future<void> _save(ui.Picture pic, int w, int h, String path) async {
  final img = await pic.toImage(w, h);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
}

void main() {
  final out = Platform.environment['SHAPE_GALLERY_OUT'];

  test('계기·피팅·밸브·전기·덕트 모양', () async {
    final presets = <ModulePreset>[
      for (final l in kInstrumentPresets.values) ...l,
      for (final l in kFittingPresets.values) ...l,
      for (final l in kValvePresets.values) ...l,
      for (final l in kElecPresets.values) ...l,
      ...kDuctPresets.take(2),
    ];
    // 모양마다 하나만(첫 프리셋).
    final seen = <String>{};
    final picks = <ModulePreset>[
      for (final p in presets)
        if (p.shape != null && seen.add(p.shape!)) p,
    ];
    for (var sheet = 0; sheet * _perSheet < picks.length; sheet++) {
      final part = picks.skip(sheet * _perSheet).take(_perSheet).toList();
      final rows = (part.length / _cols).ceil();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(
        Rect.fromLTWH(0, 0, _cols * _cell, rows * _cell),
        Paint()..color = Colors.white,
      );
      for (var i = 0; i < part.length; i++) {
        final p = part[i];
        final ox = (i % _cols) * _cell + 30;
        final oy = (i ~/ _cols) * _cell + 10;
        final k = _box / (p.width > p.height ? p.width : p.height);
        final w = p.width * k, h = p.height * k;
        c.save();
        c.translate(ox + (_box - w) / 2, oy + (_box - h) / 2);
        InstrumentShapePainter(
          shape: p.shape!,
          strokeWidth: 1.5,
        ).paint(c, Size(w, h));
        c.restore();
        _label(
          c,
          '#${sheet * _perSheet + i} ${p.shape} ${p.width.toInt()}x${p.height.toInt()}',
          Offset(ox - 20, oy + _box + 6),
          _cell - 10,
        );
      }
      final pic = rec.endRecording();
      if (out != null) {
        await _save(
          pic,
          (_cols * _cell).toInt(),
          (rows * _cell).toInt(),
          '$out/instrument_$sheet.png',
        );
      }
    }
    if (out != null) {
      await File('$out/instrument_names.txt').writeAsString(
        [
          for (var i = 0; i < picks.length; i++)
            '#$i ${picks[i].shape} ${picks[i].name} ${picks[i].width.toInt()}x${picks[i].height.toInt()}',
        ].join('\n'),
      );
    }
    expect(picks, isNotEmpty);
  });

  test('스키드 부품 모양(위·옆·끝 세 면)', () async {
    final presets = <ModulePreset>[
      for (final l in kSkidSteelPresets.values) l.first,
      for (final l in kSkidConduitPresets.values) l.first,
      for (final l in kSkidJbPresets.values) l.first,
      for (final l in kSkidFittingPresets.values) ...l.take(1),
    ];
    final seen = <String>{};
    final picks = <ModulePreset>[
      for (final p in presets)
        if (p.shape != null && seen.add(p.shape!)) p,
    ];
    const faces = [SkidFace.top, SkidFace.side, SkidFace.end];
    const perSheet = 6;
    for (var sheet = 0; sheet * perSheet < picks.length; sheet++) {
      final part = picks.skip(sheet * perSheet).take(perSheet).toList();
      final rows = part.length;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(
        Rect.fromLTWH(0, 0, 4 * _cell, rows * _cell),
        Paint()..color = Colors.white,
      );
      for (var r = 0; r < part.length; r++) {
        final p = part[r];
        final oy = r * _cell + 10;
        _label(
          c,
          '#${sheet * perSheet + r} ${p.shape}\n${p.width.toInt()}x${p.height.toInt()}'
          ' d${p.depth?.toInt() ?? '-'}',
          Offset(8, oy + 60),
          _cell - 16,
        );
        for (var f = 0; f < faces.length; f++) {
          final ox = (f + 1) * _cell + 30;
          final double pw = faces[f] == SkidFace.end ? p.height : p.width;
          final double ph = faces[f] == SkidFace.top
              ? p.height
              : (p.depth ?? p.height);
          final k = _box / (pw > ph ? pw : ph);
          final w = pw * k, h = ph * k;
          c.save();
          c.translate(ox + (_box - w) / 2, oy + (_box - h) / 2);
          SkidPartPainter(
            shape: p.shape!,
            face: faces[f],
            strokeWidth: 1.5,
          ).paint(c, Size(w, h));
          c.restore();
          _label(
            c,
            const ['top', 'side', 'end'][f],
            Offset(ox, oy + _box + 6),
            60,
          );
        }
      }
      final pic = rec.endRecording();
      if (out != null) {
        await _save(
          pic,
          (4 * _cell).toInt(),
          (rows * _cell).toInt(),
          '$out/skid_$sheet.png',
        );
      }
    }
    if (out != null) {
      await File('$out/skid_names.txt').writeAsString(
        [
          for (var i = 0; i < picks.length; i++)
            '#$i ${picks[i].shape} ${picks[i].name} ${picks[i].width.toInt()}x${picks[i].height.toInt()} d${picks[i].depth?.toInt()}',
        ].join('\n'),
      );
    }
    expect(picks, isNotEmpty);
  });
}
