// 배치도 부품 모양: 명시 돌리기·뒤집기, 접속점, 체크 밸브·포트 커넥터 조각, 브래킷 꼬리표.
// SHAPE_GALLERY_OUT 환경 변수에 폴더를 주면 점검용 그림(rotation.png)도 그 폴더에 쓴다.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/elec_presets.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/fitting_spec.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/instrument_shape_painter.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/layout_board_models.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/skid_part_painter.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/skid_presets.dart';

/// 모든 프리셋(계기·피팅·밸브·전기·덕트·스키드)에서 모양이 다른 것 하나씩.
List<ModulePreset> _allPresets() {
  final seen = <String>{};
  return [
    for (final p in [
      for (final l in kInstrumentPresets.values) ...l,
      for (final l in kFittingPresets.values) ...l,
      for (final l in kValvePresets.values) ...l,
      for (final l in kElecPresets.values) ...l,
      ...kDuctPresets.take(1),
      for (final l in kSkidSteelPresets.values) l.first,
      for (final l in kSkidConduitPresets.values) l.first,
      for (final l in kSkidJbPresets.values) l.first,
      for (final l in kSkidFittingPresets.values) l.first,
    ])
      if (p.shape != null && seen.add(p.shape!)) p,
  ];
}

ModulePreset _find(String name) => [
  for (final l in kInstrumentPresets.values) ...l,
  for (final l in kFittingPresets.values) ...l,
  for (final l in kValvePresets.values) ...l,
].firstWhere((p) => p.name == name);

Future<List<int>> _pixels(Size size, void Function(Canvas c) draw) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));
  draw(c);
  final img = await rec.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
  return (await img.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
}

void main() {
  test('모든 프리셋 모양이 0·90·180·270° × 뒤집기로 그려진다', () {
    for (final p in _allPresets()) {
      for (int q = 0; q < 4; q++) {
        final Size box = q.isOdd
            ? Size(p.height, p.width)
            : Size(p.width, p.height);
        for (final mirror in [false, true]) {
          for (final size in [box, const Size(40, 40), const Size(9, 13)]) {
            final rec = ui.PictureRecorder();
            InstrumentShapePainter(
              shape: p.shape!,
              quarterTurns: q,
              mirror: mirror,
            ).paint(Canvas(rec), size);
            rec.endRecording();
          }
        }
      }
      // 돌린 횟수를 모르는 예전 부품도 그대로 그려진다.
      final rec = ui.PictureRecorder();
      InstrumentShapePainter(
        shape: p.shape!,
      ).paint(Canvas(rec), Size(p.height, p.width));
      rec.endRecording();
    }
  });

  test('명시 90°(칸 가로·세로 바뀜)는 예전 어림 돌리기와 같은 그림이다', () async {
    // 세로가 긴 계기를 가로 칸에 놓으면 예전에는 비율로 90°를 어림했다.
    for (final shape in [
      InstrumentShape.rmCoplanar,
      'fv:needle;L=66.4;top=63.6;bot=14;end=n;bar=64;pipe=17.5',
      InstrumentShape.fitElbow,
    ]) {
      // 엘보는 정사각 칸(예전엔 안 돌렸다), 나머지는 가로 칸(예전엔 90° 어림).
      final size = shape == InstrumentShape.fitElbow
          ? const Size(80, 80)
          : const Size(120, 80);
      final a = await _pixels(
        size,
        (c) => InstrumentShapePainter(shape: shape).paint(c, size),
      );
      final b = await _pixels(
        size,
        (c) => InstrumentShapePainter(
          shape: shape,
          quarterTurns: 1,
        ).paint(c, size),
      );
      // 정사각(엘보)은 예전에 안 돌렸으니 명시 90°와 다르다; 나머지는 같아야 한다.
      int diff = 0;
      for (int k = 0; k < a.length; k += 4) {
        if ((a[k] - b[k]).abs() > 40) diff++;
      }
      if (shape == InstrumentShape.fitElbow) {
        expect(diff, greaterThan(0));
      } else {
        expect(diff, 0, reason: shape);
      }
    }
  });

  test('180° 돌리기는 그림을 위아래·좌우로 뒤집고, 뒤집기는 좌우만', () async {
    const size = Size(100, 60);
    const shape = InstrumentShape.fitMaleElbow; // 왼쪽 너트, 오른쪽 아래 나사
    final a = await _pixels(
      size,
      (c) =>
          InstrumentShapePainter(shape: shape, quarterTurns: 0).paint(c, size),
    );
    final r2 = await _pixels(
      size,
      (c) =>
          InstrumentShapePainter(shape: shape, quarterTurns: 2).paint(c, size),
    );
    final m = await _pixels(
      size,
      (c) => InstrumentShapePainter(shape: shape, mirror: true).paint(c, size),
    );
    final int w = size.width.toInt(), h = size.height.toInt();
    int bad2 = 0, badM = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final j2 = ((h - 1 - y) * w + (w - 1 - x)) * 4;
        final jm = (y * w + (w - 1 - x)) * 4;
        if ((a[i] - r2[j2]).abs() > 40) bad2++;
        if ((a[i] - m[jm]).abs() > 40) badM++;
      }
    }
    expect(bad2, lessThan(w * h * 0.03));
    expect(badM, lessThan(w * h * 0.03));
  });

  test('접속점은 모든 프리셋에서 칸 안(또는 테두리)에 있다', () {
    for (final p in _allPresets()) {
      for (int q = 0; q < 4; q++) {
        final Size box = q.isOdd
            ? Size(p.height, p.width)
            : Size(p.width, p.height);
        for (final mirror in [false, true]) {
          final pts = shapeConnectionPoints(
            p.shape,
            box,
            quarterTurns: q,
            mirror: mirror,
          );
          for (final pt in pts) {
            expect(
              pt.dx,
              inInclusiveRange(-0.01, box.width + 0.01),
              reason: '${p.shape} q$q m$mirror $pt',
            );
            expect(
              pt.dy,
              inInclusiveRange(-0.01, box.height + 0.01),
              reason: '${p.shape} q$q m$mirror $pt',
            );
          }
        }
      }
    }
  });

  test('접속점 개수: 계기·피팅·밸브·매니폴드 대표 모양', () {
    int n(String name) {
      final p = _find(name);
      return shapeConnectionPoints(p.shape, Size(p.width, p.height)).length;
    }

    expect(n('3051CD DPT'), 2); // 차압 둘
    expect(n('3051CD DPT 재래식 플랜지'), 2);
    expect(n('EJA110E DPT 수직배관'), 2);
    expect(n('APT3100 DPT'), 2);
    expect(n('101NN 차압 스위치'), 2);
    expect(n('3051TG PT 인라인'), 1); // 인라인·PT·포크·스위치 하나
    expect(n('APT3200 PT'), 1);
    expect(n('2120 레벨 스위치'), 1);
    expect(n('MA 압력 스위치'), 1);
    expect(n('6NN 압력 스위치'), 1);
    expect(n('유니언 3/8"'), 2); // 피팅 팔마다
    expect(n('유니언 엘보 3/8"'), 2);
    expect(n('유니언 티 3/8"'), 3);
    expect(n('유니언 크로스 3/8"'), 4);
    expect(n('피메일 커넥터 3/8"×3/8" NPT'), 2); // fs:
    expect(n('메일 브랜치 티 3/8"×3/8" NPT'), 3); // fl:
    expect(n('45° 메일 엘보 3/8"×3/8" NPT'), 2);
    expect(n('NV 니들 밸브 3/8" 튜브'), 2); // 밸브 양 끝
    expect(n('RV 릴리프 밸브 1/2" 튜브'), 2); // 입구 + 출구
    expect(n('체크 밸브 3/8" 암나사'), 2);
    expect(n('VM2V 2밸브 매니폴드'), 2);
    expect(n('VM3V 3밸브 매니폴드'), 2);
    expect(n('VM3V1F 3밸브 직결'), 3); // + 플랜지
    expect(n('VM5V1F 5밸브 직결'), 3);
    expect(n('V3 3밸브 매니폴드'), 2);
    expect(n('3051CD DPT (브래킷)'), 2); // 브래킷 붙여도 계기 접속점 그대로
    // 전기·덕트·메모·스키드·모르는 모양은 없다.
    expect(
      shapeConnectionPoints(
        kElecPresets.values.first.first.shape,
        const Size(50, 90),
      ),
      isEmpty,
    );
    expect(
      shapeConnectionPoints(InstrumentShape.duct, const Size(40, 200)),
      isEmpty,
    );
    expect(
      shapeConnectionPoints(InstrumentShape.note, const Size(160, 40)),
      isEmpty,
    );
    expect(
      shapeConnectionPoints(SkidShape.beam, const Size(1000, 100)),
      isEmpty,
    );
    expect(shapeConnectionPoints('없는모양', const Size(80, 80)), isEmpty);
    expect(shapeConnectionPoints(null, const Size(80, 80)), isEmpty);
  });

  test('접속점 자리: 인라인 계기는 아래 가운데, 돌리면 그림을 따라간다', () {
    const size = Size(104, 183);
    final pts = shapeConnectionPoints(InstrumentShape.rmInline, size);
    expect(pts.single.dy, closeTo(183, 0.01));
    expect(pts.single.dx, closeTo(104 * 0.48, 0.01));
    // 시계 방향 90°: 아래 끝이 왼쪽으로 간다(칸은 183×104).
    final r1 = shapeConnectionPoints(
      InstrumentShape.rmInline,
      const Size(183, 104),
      quarterTurns: 1,
    ).single;
    expect(r1.dx, closeTo(0, 0.01));
    expect(r1.dy, closeTo(104 * 0.48, 0.01));
    // 180°: 위 끝으로.
    final r2 = shapeConnectionPoints(
      InstrumentShape.rmInline,
      size,
      quarterTurns: 2,
    ).single;
    expect(r2.dy, closeTo(0, 0.01));
    expect(r2.dx, closeTo(104 * 0.52, 0.01));
    // 뒤집기: x가 반대로.
    final m = shapeConnectionPoints(
      InstrumentShape.rmInline,
      size,
      mirror: true,
    ).single;
    expect(m.dx, closeTo(104 * 0.52, 0.01));
    // 곧은 피팅: 양 끝이 칸 왼쪽·오른쪽 끝(가운데 맞춤이라 세로는 가운데).
    final fs = shapeConnectionPoints(
      'fs:n:14.2:17.5,c:46.6:22.2,n:14.2:17.5',
      const Size(75, 22.2),
    );
    expect(fs[0].dx, closeTo(0, 0.01));
    expect(fs[1].dx, closeTo(75, 0.01));
    expect(fs[0].dy, closeTo(11.1, 0.01));
    // 예전 부품(돌린 횟수 없음)은 칸 비율로 어림한다.
    expect(
      InstrumentShape.inferredQuarterTurns(
        InstrumentShape.rmInline,
        const Size(183, 104),
      ),
      1,
    );
    expect(
      InstrumentShape.inferredQuarterTurns(InstrumentShape.rmInline, size),
      0,
    );
    expect(
      InstrumentShape.inferredQuarterTurns(
        InstrumentShape.fitElbow,
        const Size(38, 38),
      ),
      0,
    );
  });

  test('조각 c(체크 밸브 몸통)·p(포트 커넥터)를 읽고, 크기는 h·s와 같다', () {
    final segs = parseStraight('fs:n:14.2:17.5,c:46.6:22.2,n:14.2:17.5');
    expect(segs.map((s) => s.kind), ['n', 'c', 'n']);
    expect(segs[1].len, 46.6);
    expect(segs[1].h, 22.2);
    expect(fittingSpecSize('fs:c:68:22.2'), fittingSpecSize('fs:h:68:22.2'));
    expect(fittingSpecSize('fs:p:26.7:9.5'), fittingSpecSize('fs:s:26.7:9.5'));
    expect(_find('체크 밸브 3/8" 암나사').shape, 'fs:c:68:22.2');
    expect(_find('체크 밸브 1/2" 암나사').shape, 'fs:c:85:28.6');
    expect(
      _find('체크 밸브 3/8" 튜브').shape,
      'fs:n:14.2:17.5,c:46.6:22.2,n:14.2:17.5',
    );
    expect(_find('포트 커넥터 3/8"').shape, 'fs:p:26.7:9.5');
    expect(_find('포트 커넥터 1/2"').shape, 'fs:p:36.3:12.7');
    expect(_find('체크 밸브 3/8" 암나사').width, 68);
    expect(_find('포트 커넥터 1/2"').width, 36.3);
  });

  test('체크 밸브 몸통에는 화살표가 있다(h 조각과 그림이 다르다)', () async {
    const size = Size(136, 44);
    final h = await _pixels(
      size,
      (c) => InstrumentShapePainter(shape: 'fs:h:68:22.2').paint(c, size),
    );
    final cv = await _pixels(
      size,
      (c) => InstrumentShapePainter(shape: 'fs:c:68:22.2').paint(c, size),
    );
    int diff = 0;
    for (int k = 0; k < h.length; k += 4) {
      if ((h[k] - cv[k]).abs() > 40) diff++;
    }
    expect(diff, greaterThan(30));
  });

  test('브래킷 꼬리표: 프리셋이 있고, 본디 모양이 풀리고, 그려진다', () {
    final br = [
      for (final l in kInstrumentPresets.values)
        for (final p in l)
          if (InstrumentShape.hasBracket(p.shape)) p,
    ];
    expect(br.length, 13);
    for (final p in br) {
      expect(p.name, endsWith(' (브래킷)'));
      final base = InstrumentShape.baseOf(p.shape!);
      expect(InstrumentShape.bracketable, contains(base), reason: p.name);
      final plain = _find(p.name.replaceAll(' (브래킷)', ''));
      expect(plain.shape, base);
      expect(p.width, plain.width + 60, reason: p.name);
      expect(p.height, plain.height + 40, reason: p.name);
      expect(kPresetDepth[p.name], kPresetDepth[plain.name], reason: p.name);
      expect(
        InstrumentShape.isLandscape(p.shape!),
        InstrumentShape.isLandscape(base),
      );
      for (final size in [
        Size(p.width, p.height),
        Size(p.height, p.width),
        const Size(30, 30),
      ]) {
        final rec = ui.PictureRecorder();
        InstrumentShapePainter(shape: p.shape!).paint(Canvas(rec), size);
        rec.endRecording();
      }
    }
    expect(InstrumentShape.baseOf('rm_coplanar+br'), 'rm_coplanar');
    expect(InstrumentShape.baseOf('rm_coplanar'), 'rm_coplanar');
    expect(InstrumentShape.hasBracket('yk_vertical+br'), isTrue);
    expect(InstrumentShape.hasBracket(null), isFalse);
    expect(InstrumentShape.isLandscape('yk_vertical+br'), isTrue);
    // 저장했다 읽어도 꼬리표가 남는다.
    final it = PlacedItem(
      id: 'a',
      name: '3051CD DPT (브래킷)',
      position: Offset.zero,
      shape: 'rm_coplanar+br',
    );
    expect(PlacedItem.fromJson(it.toJson()).shape, 'rm_coplanar+br');
  });

  test('브래킷을 붙이면 그림이 달라진다(파이프·판이 보인다)', () async {
    const size = Size(164, 221);
    final a = await _pixels(
      size,
      (c) => InstrumentShapePainter(shape: 'rm_coplanar').paint(c, size),
    );
    final b = await _pixels(
      size,
      (c) => InstrumentShapePainter(shape: 'rm_coplanar+br').paint(c, size),
    );
    int diff = 0;
    for (int k = 0; k < a.length; k += 4) {
      if ((a[k] - b[k]).abs() > 40) diff++;
    }
    expect(diff, greaterThan(500));
  });

  test('스키드 부품 그림도 위에서 본 모습에 돌린 횟수를 받는다', () {
    for (final shape in [
      SkidShape.beam,
      SkidShape.jb,
      SkidShape.cdLB,
      SkidShape.coupling,
    ]) {
      for (final face in SkidFace.values) {
        for (int q = 0; q < 4; q++) {
          for (final mirror in [false, true]) {
            final rec = ui.PictureRecorder();
            SkidPartPainter(
              shape: shape,
              face: face,
              quarterTurns: q,
              mirror: mirror,
            ).paint(Canvas(rec), const Size(120, 40));
            rec.endRecording();
          }
        }
      }
    }
  });

  test('제조사 색: 로즈마운트·요꼬가와·오토롤 몸통 색이 서로 다르고 옅다', () async {
    const size = Size(100, 170);
    Future<int> center(String shape) async {
      final px = await _pixels(
        size,
        (c) => InstrumentShapePainter(shape: shape).paint(c, size),
      );
      // 뚜껑 원 바깥, 몸통(전자부 목·아래 띠) 자리 한 점(x 30, y 100).
      final i = (100 * 100 + 30) * 4;
      return (px[i] << 16) | (px[i + 1] << 8) | px[i + 2];
    }

    final rm = await center(InstrumentShape.rmCoplanar);
    final yk = await center(InstrumentShape.ykInline);
    final au = await center(InstrumentShape.autrolPt);
    expect(rm, isNot(yk));
    expect(yk, isNot(au));
    for (final c in [rm, yk, au]) {
      // 옅은 색(각 채널 200 이상)이라 흑백 인쇄해도 선이 산다.
      expect((c >> 16) & 0xFF, greaterThan(200));
      expect((c >> 8) & 0xFF, greaterThan(200));
      expect(c & 0xFF, greaterThan(200));
    }
  });

  test('점검용 그림: 돌린 니들 밸브·체크 밸브·매니폴드·SOR 차압·브래킷(환경 변수 있을 때)', () async {
    final out = Platform.environment['SHAPE_GALLERY_OUT'];
    const cell = 220.0, box = 160.0, cols = 4;
    final needle = _find('NV 니들 밸브 3/8" 튜브');
    final items = <(String, String, int, bool)>[
      for (int q = 0; q < 4; q++) ('니들 $q', needle.shape!, q, false),
      for (int q = 0; q < 4; q++) ('니들 $q 뒤집기', needle.shape!, q, true),
      ('체크 튜브', _find('체크 밸브 3/8" 튜브').shape!, 0, false),
      ('체크 암나사', _find('체크 밸브 1/2" 암나사').shape!, 0, false),
      ('체크 180', _find('체크 밸브 3/8" 튜브').shape!, 2, false),
      ('릴리프', _find('RV 릴리프 밸브 1/2" 튜브').shape!, 0, false),
      ('포트 커넥터', _find('포트 커넥터 1/2"').shape!, 0, false),
      ('VM2V', InstrumentShape.mv2, 0, false),
      ('V2', InstrumentShape.swV2, 0, false),
      ('VM3V1F', InstrumentShape.mv3Flange, 0, false),
      ('SOR 101', InstrumentShape.sorDp, 0, false),
      ('3051CD+br', 'rm_coplanar+br', 0, false),
      ('EJA110 수직+br', 'yk_vertical+br', 0, false),
      ('APT3100+br', 'autrol_dp+br', 0, false),
      ('3051TG+br 90', 'rm_inline+br', 1, false),
      ('EJA530+br', 'yk_inline+br', 0, false),
      ('3051CD 재래식+br', 'rm_trad+br', 0, false),
      ('엘보 270', InstrumentShape.fitElbow, 3, false),
      ('메일 브랜치 티 90', _find('메일 브랜치 티 3/8"×3/8" NPT').shape!, 1, true),
      ('3051CD', InstrumentShape.rmCoplanar, 0, false),
      ('EJA530E', InstrumentShape.ykInline, 0, false),
      ('APT3200', InstrumentShape.autrolPt, 0, false),
    ];
    final rows = (items.length / cols).ceil();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(
      Rect.fromLTWH(0, 0, cols * cell, rows * cell),
      Paint()..color = Colors.white,
    );
    final dot = Paint()..color = const Color(0xFFE11D48);
    for (var i = 0; i < items.length; i++) {
      final (label, shape, q, mirror) = items[i];
      final p = _allPresets().firstWhere(
        (e) => e.shape == shape,
        orElse: () => ModulePreset(label, 100, 100, shape: shape),
      );
      final Size nat = Size(p.width, p.height);
      final Size boxMm = q.isOdd ? Size(nat.height, nat.width) : nat;
      final k = box / math.max(boxMm.width, boxMm.height);
      final size = Size(boxMm.width * k, boxMm.height * k);
      final ox = (i % cols) * cell + 30, oy = (i ~/ cols) * cell + 10;
      c.save();
      c.translate(ox + (box - size.width) / 2, oy + (box - size.height) / 2);
      c.drawRect(
        Offset.zero & size,
        Paint()
          ..color = const Color(0xFFCBD5E1)
          ..style = PaintingStyle.stroke,
      );
      InstrumentShapePainter(
        shape: shape,
        quarterTurns: q,
        mirror: mirror,
      ).paint(c, size);
      for (final pt in shapeConnectionPoints(
        shape,
        size,
        quarterTurns: q,
        mirror: mirror,
      )) {
        c.drawCircle(pt, 4, dot);
      }
      c.restore();
      final tp = TextPainter(
        text: TextSpan(
          text: '#$i $label',
          style: const TextStyle(color: Colors.black, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: cell - 10);
      tp.paint(c, Offset(ox - 20, oy + box + 6));
    }
    final pic = rec.endRecording();
    final img = await pic.toImage((cols * cell).toInt(), (rows * cell).toInt());
    expect(img.width, greaterThan(0));
    if (out != null) {
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      await File('$out/rotation.png').writeAsBytes(bytes!.buffer.asUint8List());
      await File('$out/rotation_names.txt').writeAsString(
        [
          for (var i = 0; i < items.length; i++)
            '#$i ${items[i].$1} ${items[i].$2} q${items[i].$3} m${items[i].$4}',
        ].join('\n'),
      );
    }
  });
}
