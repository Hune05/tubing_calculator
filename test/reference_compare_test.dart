// 앱 계산기와 독립 기준 모델(test/reference_model/)을 같은 입력으로 돌려 차이를 센다.
//
// 이 검사는 차이가 나도 실패하지 않는다. 차이 난 것은 표로 찍고 마지막에 요약 줄을
// 찍는다. 판정(앱이 틀림 / 관행값이라 다름 / 정의가 달라 비교 불가)은 사람이
// 정해 넣은 것이고, 근거 숫자는 같은 줄에 적는다.
//
// 돌리기: flutter test test/reference_compare_test.dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/core/engine/tube_bending_engine.dart';
import 'package:tubing_calculator/src/core/utils/fitting_data.dart';
import 'package:tubing_calculator/src/data/models/bender_spec_data.dart';
import 'package:tubing_calculator/src/data/models/smart_fitting_db.dart';
import 'package:tubing_calculator/src/presentation/calculator/bend_check.dart';
import 'package:tubing_calculator/src/presentation/calculator/segment_length_check.dart';
import 'package:tubing_calculator/src/presentation/calculator/tube_marking_rules.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_quick_u_bend_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_rolling_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/u_bend_plan.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_math.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_optimizer.dart';

import 'reference_model/compare_table.dart';
import 'reference_model/conduit_reference.dart';
import 'reference_model/cutting_reference.dart';
import 'reference_model/tube_reference.dart';

// ── 규격 ──
// 스웨즈락 수동 벤더 반경(fitting_data.dart 표 값). 1/4·3/8·1/2·3/4·1".
const Map<String, double> kTubeRadius = {
  '1/4"': 14.3,
  '3/8"': 23.8,
  '1/2"': 38.1,
  '3/4"': 57.2,
  '1"': 76.2,
};
const Map<String, String> kTubeOdKey = {
  '1/4"': '0.25',
  '3/8"': '0.375',
  '1/2"': '0.5',
  '3/4"': '0.75',
  '1"': '1.0',
};
const List<double> kAngles = [15, 22.5, 30, 45, 60, 90];
const List<double> kOffsetHeights = [25, 50, 100, 150, 200, 300];

// ── 앱 쪽 도우미 ──
double r1(double v) => double.parse(v.toStringAsFixed(1));

Map<String, dynamic> runEngine(
  List<List<double>> rows, {
  required double radius,
  double gain90 = 0,
  double zero = 0,
  double tail = 0,
  double springback = 0,
}) => TubeBendingEngine(
  radius: radius,
  userGain90: gain90,
  springbackDeg: springback,
).calculate([
  for (final r in rows) BendInstruction(length: r[0], angle: r[1], rotation: r[2]),
], zero, tail: tail);

/// 엔진 결과에서 벤드(각 > 0) 마킹만.
List<double> engineMarks(Map<String, dynamic> res) => [
  for (final s in res['steps'] as List<StepResult>)
    if (s.setback > 0) s.markingPoint,
];

double engineCut(Map<String, dynamic> res) => res['totalCutLength'] as double;

List<RefBend> toRef(List<List<double>> rows) => [
  for (final r in rows) RefBend(r[0], r[1]),
];

/// 오프셋 시트(mobile_offset_bottom_sheet.dart _executeAdd)가 목록에 넣는 두 줄.
/// 시트의 셈(빗변 = H/sin, 전진 = H/tan, 축소 = 빗변 − 전진, 0.1mm 반올림)을 그대로
/// 옮겼다. 시트 함수는 화면 안(private)이라 직접 못 부른다.
List<List<double>> sheetOffsetRows(
  BendSheetSpecs specs,
  double start,
  double h,
  double a, {
  double rot1 = 0,
  double rot2 = 180,
}) {
  final rad = a * math.pi / 180;
  final travel = h / math.sin(rad);
  final run = h / math.tan(rad);
  final shrink = r1(travel - run);
  final firstLen = r1(specs.firstLength(start, r1(a), shrink));
  return [
    [firstLen, r1(a), rot1],
    [r1(travel), r1(a), rot2],
  ];
}

/// 새들 시트(mobile_saddle_bottom_sheet.dart _execute3Point)가 넣는 세 줄.
List<List<double>> sheetSaddle3Rows(
  BendSheetSpecs specs,
  double start,
  double h,
  double a3,
) {
  final side = a3 / 2;
  final radSide = side * math.pi / 180;
  final travel = h / math.sin(radSide);
  final run = h / math.tan(radSide);
  final shrink = r1(travel * 2 - run * 2);
  final firstLen = r1(specs.firstLength(start, side, shrink));
  return [
    [firstLen, side, 0],
    [r1(travel), a3, 180],
    [r1(travel), side, 0],
  ];
}

/// 새들 시트 _execute4Point가 넣는 네 줄.
List<List<double>> sheetSaddle4Rows(
  BendSheetSpecs specs,
  double start,
  double h,
  double w,
  double a4,
) {
  final rad = a4 * math.pi / 180;
  final travel = h / math.sin(rad);
  final run = h / math.tan(rad);
  final shrink = r1((travel * 2 + w) - (run * 2 + w));
  final firstLen = r1(specs.firstLength(start, a4, shrink));
  return [
    [firstLen, a4, 0],
    [r1(travel), a4, 180],
    [r1(w), a4, 180],
    [r1(travel), a4, 0],
  ];
}

BendSheetSpecs tubeSpecs(double radius, {double gain90 = 0}) => BendSheetSpecs(
  radius: radius,
  gain90: gain90,
  markOffset: (a) => bendSetback(radius, a),
);

/// 전선관 설정 한 벌(conduit_settings_page.dart 기본값 모양 + 표 값).
Map<String, dynamic> conduitSettings({
  String benderType = 'hand',
  String maker = 'Greenlee',
  String type = 'EMT',
  required String size,
  bool applyShrink = true,
}) {
  final spec = benderSpecData[benderType]![maker]![type]![size]!;
  return {
    'benderType': benderType,
    'manufacturer': maker,
    'conduitType': type,
    'conduitSize': size,
    'applyShrink': applyShrink,
    'applySpringback': false,
    'springback': 3.0,
    'clr': spec['clr'] ?? 0.0,
    'takeUp': spec['takeUp'] ?? 0.0,
    'gain': spec['gain'] ?? 0.0,
    'ramTravel': spec['ramTravel'] ?? 0.0,
    'setback': spec['setback'] ?? 0.0,
    'degPerNotch': spec['degPerNotch'] ?? 2.5,
    'bladeKerf': 0.0,
    'couplingAllowance': 50.0,
  };
}

List<Map<String, dynamic>> conduitRows(List<List<double>> rows) => [
  for (final r in rows) {'length': r[0], 'angle': r[1], 'rotation': r[2]},
];

List<double> conduitMarks(List<Map<String, dynamic>> m) => [
  for (final x in m)
    if ((x['angle'] as double) > 0) x['mark'] as double,
];

String f1(double v) => v.toStringAsFixed(1);

void main() {
  final t = CompareTable(threshold: 0.5);

  tearDownAll(t.printReport);

  // ────────────────────────────────────────────────────────────────
  group('튜브 · 기하(셋백·호·게인)', () {
    test('반경 5가지 × 각도 6가지', () {
      for (final e in kTubeRadius.entries) {
        for (final a in kAngles) {
          t.add(
            calc: '튜브 셋백',
            input: '${e.key} R${e.value} $a°',
            app: bendSetback(e.value, a),
            ref: refSetback(e.value, a),
          );
          t.add(
            calc: '튜브 호',
            input: '${e.key} R${e.value} $a°',
            app: bendArcLength(e.value, a),
            ref: refBendAllowance(e.value, a),
          );
          t.add(
            calc: '튜브 게인',
            input: '${e.key} R${e.value} $a°',
            app: geometricGain(e.value, a),
            ref: refGain(e.value, a),
          );
        }
      }
    });

    test('실측 게인 각도 환산(90° 12mm 기준)', () {
      for (final a in kAngles) {
        t.add(
          calc: '튜브 실측게인 환산',
          input: '게인90=12 → $a°',
          app: scaleMeasuredGain(12, a),
          ref: refGainMeasured(38.1, a, 12),
        );
      }
    });

    test('스웨즈락 제원 표(fitting_data.dart)의 게인이 반경과 맞는지', () {
      for (final e in kTubeRadius.entries) {
        final spec = FittingData.getBenderSpec('Swagelok', kTubeOdKey[e.key]!)!;
        t.add(
          calc: '튜브 제원 표 게인90',
          input: '${e.key} 표 R${spec.bendRadius}',
          app: spec.gain,
          ref: refGain(spec.bendRadius, 90),
          verdict: Verdict.appWrong,
          why:
              '표 게인 ${spec.gain} vs 반경 기하 ${f1(refGain(spec.bendRadius, 90))}'
              '(같은 반경 38.1인 5/8"은 16.3으로 적혀 있다)',
        );
        t.add(
          calc: '튜브 제원 표 테이크업',
          input: e.key,
          app: spec.takeUp,
          ref: spec.bendRadius,
          verdict: Verdict.definition,
          why: '설명서: 90° 테이크업 = 반경',
        );
      }
      t.note(
        '튜브 설정의 "테이크업"(MachineSpecs.takeUp90)은 마킹 엔진이 읽지 않는다. '
        '엔진은 반경만 쓴다(tube_bending_engine.dart:133 bendSetback(radius, …)). '
        '표에서는 테이크업 = 반경이라 값이 같지만, 사용자가 테이크업만 고치면 아무 일도 없다.',
      );
    });
  });

  // ────────────────────────────────────────────────────────────────
  group('튜브 · 마킹·절단(엔진 vs 기준)', () {
    test('벤드 하나 + 꼬리 200', () {
      for (final e in kTubeRadius.entries) {
        for (final a in kAngles) {
          for (final len in [150.0, 300.0, 500.0]) {
            final rows = [
              [len, a, 0.0],
            ];
            final res = runEngine(rows, radius: e.value, tail: 200);
            final ref = refTubeMarks(toRef(rows), radius: e.value, tail: 200);
            t.add(
              calc: '튜브 마킹',
              input: '${e.key} [$len, $a°] 꼬리200 1번',
              app: engineMarks(res)[0],
              ref: ref.marks[0],
            );
            t.add(
              calc: '튜브 절단',
              input: '${e.key} [$len, $a°] 꼬리200',
              app: engineCut(res),
              ref: ref.cutLength,
            );
          }
        }
      }
    });

    test('90° 두 번(500/600) + 꼬리 300, 실측 게인 있는 것도', () {
      for (final e in kTubeRadius.entries) {
        for (final g in [0.0, 12.0]) {
          final rows = [
            [500.0, 90.0, 0.0],
            [600.0, 90.0, 360.0],
          ];
          final res = runEngine(rows, radius: e.value, tail: 300, gain90: g);
          final ref = refTubeMarks(
            toRef(rows),
            radius: e.value,
            tail: 300,
            gain90: g,
          );
          final m = engineMarks(res);
          for (var i = 0; i < 2; i++) {
            t.add(
              calc: '튜브 마킹',
              input: '${e.key} 90°×2 게인90=$g ${i + 1}번',
              app: m[i],
              ref: ref.marks[i],
            );
          }
          t.add(
            calc: '튜브 절단',
            input: '${e.key} 90°×2 게인90=$g',
            app: engineCut(res),
            ref: ref.cutLength,
          );
        }
      }
    });

    test('피팅 삽입 깊이·벤더 원점', () {
      for (final e in kTubeRadius.entries) {
        final depth = FittingData.getInsertionDepth('Swagelok', kTubeOdKey[e.key]!);
        final list = [
          {'length': 300.0, 'angle': 90.0, 'rotation': 0.0},
          {'length': 400.0, 'angle': 45.0, 'rotation': 180.0},
        ];
        final fitted = tubeFittedLengths(
          list,
          startFit: true,
          endFit: true,
          fittingDepth: depth,
          tail: 250,
        );
        final rows = [
          for (var i = 0; i < list.length; i++)
            [fitted.lengths[i], list[i]['angle']!, list[i]['rotation']!],
        ];
        final res = runEngine(rows, radius: e.value, tail: fitted.tail, zero: 5);
        final ref = refTubeMarks(
          [const RefBend(300, 90), const RefBend(400, 45)],
          radius: e.value,
          tail: 250,
          zero: 5,
          startInsert: depth,
          endInsert: depth,
        );
        final m = engineMarks(res);
        for (var i = 0; i < 2; i++) {
          t.add(
            calc: '튜브 마킹(피팅·원점)',
            input: '${e.key} 깊이$depth 원점5 ${i + 1}번',
            app: m[i],
            ref: ref.marks[i],
          );
        }
        t.add(
          calc: '튜브 절단(피팅·원점)',
          input: '${e.key} 깊이$depth 원점5',
          app: engineCut(res),
          ref: ref.cutLength,
        );
      }
    });

    test('오프셋(시트가 넣는 줄 → 엔진) vs 기준', () {
      for (final e in kTubeRadius.entries) {
        final specs = tubeSpecs(e.value);
        for (final h in kOffsetHeights) {
          for (final a in [15.0, 22.5, 30.0, 45.0, 60.0]) {
            final rows = sheetOffsetRows(specs, 100, h, a);
            final res = runEngine(rows, radius: e.value, tail: 200);
            final o = refOffset(h, a);
            // 기준: 1번 마킹은 시작 거리(100) 자리, 2번은 교차점 치수 그대로.
            final ref = refTubeMarks(
              [RefBend(100 + refSetback(e.value, a), a), RefBend(o.travel, a)],
              radius: e.value,
              tail: 200,
            );
            final m = engineMarks(res);
            t.add(
              calc: '튜브 오프셋 1번',
              input: '${e.key} H$h $a° 시작100',
              app: m[0],
              ref: 100,
            );
            t.add(
              calc: '튜브 오프셋 2번',
              input: '${e.key} H$h $a° 시작100',
              app: m[1],
              ref: ref.marks[1],
            );
            t.add(
              calc: '튜브 오프셋 절단',
              input: '${e.key} H$h $a° 시작100 꼬리200',
              app: engineCut(res),
              ref: ref.cutLength,
            );
            // 시트의 빗변·수축 셈(0.1 반올림) vs 기준
            t.add(
              calc: '튜브 오프셋 빗변',
              input: 'H$h $a°',
              app: rows[1][0],
              ref: o.travel,
            );
          }
        }
      }
    });

    test('3점 새들·4점 새들(시트가 넣는 줄 → 엔진) vs 기준', () {
      for (final e in kTubeRadius.entries) {
        final specs = tubeSpecs(e.value);
        for (final h in [50.0, 100.0, 200.0]) {
          for (final a3 in [45.0, 60.0, 90.0]) {
            final rows = sheetSaddle3Rows(specs, 150, h, a3);
            final res = runEngine(rows, radius: e.value, tail: 200);
            final s = refSaddle3(h, a3);
            final ref = refTubeMarks(
              [
                RefBend(150 + refSetback(e.value, s.sideAngle), s.sideAngle),
                RefBend(s.travel, a3),
                RefBend(s.travel, s.sideAngle),
              ],
              radius: e.value,
              tail: 200,
            );
            final m = engineMarks(res);
            for (var i = 0; i < 3; i++) {
              t.add(
                calc: '튜브 3점새들 ${i + 1}번',
                input: '${e.key} H$h 가운데$a3° 시작150',
                app: m[i],
                ref: i == 0 ? 150 : ref.marks[i],
              );
            }
            t.add(
              calc: '튜브 3점새들 절단',
              input: '${e.key} H$h 가운데$a3°',
              app: engineCut(res),
              ref: ref.cutLength,
            );
          }
          for (final a4 in [30.0, 45.0]) {
            final rows = sheetSaddle4Rows(specs, 150, h, 200, a4);
            final res = runEngine(rows, radius: e.value, tail: 200);
            final s = refSaddle4(h, 200, a4);
            final ref = refTubeMarks(
              [
                RefBend(150 + refSetback(e.value, a4), a4),
                RefBend(s.travel, a4),
                RefBend(200, a4),
                RefBend(s.travel, a4),
              ],
              radius: e.value,
              tail: 200,
            );
            final m = engineMarks(res);
            for (var i = 0; i < 4; i++) {
              t.add(
                calc: '튜브 4점새들 ${i + 1}번',
                input: '${e.key} H$h W200 $a4°',
                app: m[i],
                ref: i == 0 ? 150 : ref.marks[i],
              );
            }
            t.add(
              calc: '튜브 4점새들 절단',
              input: '${e.key} H$h W200 $a4°',
              app: engineCut(res),
              ref: ref.cutLength,
            );
          }
        }
      }
    });

    test('킥·롤링 오프셋·U벤드·평행 보정', () {
      const r = 38.1;
      for (final h in [50.0, 100.0, 200.0]) {
        for (final a in [15.0, 22.5, 30.0, 45.0, 60.0]) {
          // 퀵 킥 시트(mobile_quick_kick_bottom_sheet.dart build) 식을 그대로 옮김.
          final rad = a * math.pi / 180;
          final travel = h / math.sin(rad);
          final takeOff = r * math.tan((a / 2) * math.pi / 180);
          final k = refKick(h, a, r);
          t.add(calc: '킥 빗변', input: 'H$h $a°', app: travel, ref: k.travel);
          t.add(
            calc: '킥 마킹(빗변−공제)',
            input: 'H$h $a° R$r',
            app: travel - takeOff,
            ref: k.mark,
          );
        }
      }
      // 롤링 오프셋: rollingOffsetBends(공개) → 엔진.
      for (final (rise, roll) in [(150.0, 200.0), (100.0, 0.0), (0.0, 120.0), (60.0, 60.0)]) {
        for (final a in [22.5, 30.0, 45.0, 60.0]) {
          final trueOffset = math.sqrt(rise * rise + roll * roll);
          final rad = a * math.pi / 180;
          final travel = trueOffset / math.sin(rad);
          final advance = trueOffset / math.tan(rad);
          var rollAngle = math.atan2(roll, rise) * 180 / math.pi;
          if (rollAngle < 0) rollAngle += 360;
          final ref = refRolling(rise, roll, a);
          t.add(
            calc: '롤링 참오프셋',
            input: '수직$rise 수평$roll',
            app: trueOffset,
            ref: ref.trueOffset,
          );
          t.add(
            calc: '롤링 굴림각',
            input: '수직$rise 수평$roll',
            app: rollAngle,
            ref: ref.rollDeg,
            unit: '°',
          );
          final bends = rollingOffsetBends(
            specs: tubeSpecs(r),
            startDistance: 120,
            travel: travel,
            angle: a,
            advance: advance,
            rotation: 0,
          );
          final res = runEngine(
            [for (final (l, an, ro) in bends) [l, an, ro]],
            radius: r,
            tail: 200,
          );
          final refM = refTubeMarks(
            [RefBend(120 + refSetback(r, a), a), RefBend(ref.travel, a)],
            radius: r,
            tail: 200,
          );
          final m = engineMarks(res);
          t.add(calc: '롤링 1번 마킹', input: '수직$rise 수평$roll $a°', app: m[0], ref: 120);
          t.add(
            calc: '롤링 2번 마킹',
            input: '수직$rise 수평$roll $a°',
            app: m[1],
            ref: refM.marks[1],
          );
        }
      }
      // 오프셋 역산(높이 + 빗변 → 각): 시트 식 asin(H/빗변) 그대로.
      for (final h in [50.0, 100.0, 200.0]) {
        for (final tr in [120.0, 200.0, 400.0]) {
          if (h > tr) continue;
          t.add(
            calc: '오프셋 역산 각도',
            input: 'H$h 빗변$tr',
            app: math.asin(h / tr) * 180 / math.pi,
            ref: refOffsetAngleFromTravel(h, tr)!,
            unit: '°',
          );
        }
      }
      // U벤드: 실측 게인은 반경별 기하 게인의 75%와 100%로 넣어 본다.
      for (final e in kTubeRadius.entries) {
        final g90 = refGain(e.value, 90);
        for (final g in [0.0, r1(0.75 * g90), g90]) {
          final ref = refUBend(
            radius: e.value,
            startStraight: 200,
            returnStraight: 150,
            gain90: g,
          );
          t.add(
            calc: 'U벤드 먹는 길이',
            input: '${e.key} 게인90=${f1(g)}',
            app: uBendAllowance(radius: e.value, measuredGain90: g),
            ref: ref.arc,
            verdict: Verdict.definition,
            why:
                '앱은 90° 두 번(2·(2R−게인90)), 기준은 실효 반경의 호 π·R실효'
                '(R실효 = 게인90/(2−π/2) = ${f1(refRadiusFromGain90(g))})',
          );
          // 목록에 넣은 U자 → 엔진 절단 vs 기준
          final segs = uBendSegments(
            startStraight: 200,
            returnStraight: 150,
            radius: e.value,
            turn: 0,
            travel: 90,
          );
          final res = runEngine(
            [for (final s in segs) [s['length']!, s['angle']!, s['rotation']!]],
            radius: e.value,
            gain90: g,
          );
          t.add(
            calc: 'U벤드 절단(목록)',
            input: '${e.key} 앞200 뒤150 게인90=${f1(g)}',
            app: engineCut(res),
            ref: ref.cutLength,
            verdict: Verdict.definition,
            why: '위와 같은 까닭(실측 게인의 해석)',
          );
          t.add(
            calc: 'U벤드 최고점',
            input: '${e.key} 앞200 OD12.7',
            app: uBendApex(startStraight: 200, radius: e.value, odMm: 12.7),
            ref: 200 + e.value + 12.7 / 2,
          );
        }
      }
      // 평행 보정(폰 시트 식: 간격 × n × tan(θ/2))
      for (final a in [22.5, 30.0, 45.0, 60.0, 90.0]) {
        for (final n in [1, 2, 3]) {
          t.add(
            calc: '평행 보정',
            input: '간격50 $n번 $a°',
            app: 50 * n * math.tan((a / 2) * math.pi / 180),
            ref: refParallelStagger(50, n, a),
          );
        }
      }
      t.note(
        '태블릿용 parallel_shrink_bottom_sheet.dart:88-89는 90°에서 tan 45°=1 대신 '
        '1.5708(π/2)을 곱한다(간격 50 → +78.5, 기준 +50). 이 파일은 어디서도 '
        '부르지 않는 죽은 파일이다(offset_bottom_sheet.dart·saddle_bottom_sheet.dart·'
        'rolling_offset_bottom_sheet.dart도 같이 죽어 있고, 그 안에는 예전 셈'
        '(게인 비례 환산, 첫 구간=축소값, 새들 게인 더하기)이 남아 있다).',
      );
    });
  });

  // ────────────────────────────────────────────────────────────────
  group('튜브 · 극단 입력·경고 기준(관찰)', () {
    test('반경 0·꼬리·170°·음수·NaN', () {
      // 반경 0
      final r0 = runEngine([
        [300.0, 90.0, 0.0],
        [400.0, 90.0, 360.0],
      ], radius: 0, tail: 200);
      final r0Marks = [
        for (final s in r0['steps'] as List<StepResult>) f1(s.markingPoint),
      ];
      t.note(
        '반경 0: 엔진이 경고 없이 마킹 ${r0Marks.join('·')}, '
        '절단 ${f1(engineCut(r0))}을 낸다(셋백·게인이 0이라 치수를 그대로 더한다). '
        '경고 ${(r0['warnings'] as List).length}건. 제원이 비어 있다는 말이 없다.',
      );
      // 반경 0인데 실측 게인만 있으면
      final r0g = runEngine([
        [300.0, 90.0, 0.0],
        [400.0, 90.0, 360.0],
      ], radius: 0, gain90: 12, tail: 200);
      final r0gMarks = [
        for (final s in r0g['steps'] as List<StepResult>) f1(s.markingPoint),
      ];
      t.note(
        '반경 0 + 실측 게인 12: 마킹 ${r0gMarks.join('·')}, 절단 ${f1(engineCut(r0g))}, '
        '경고 ${(r0g['warnings'] as List).length}건. 벤드가 먹는 길이가 2·0 − 12 = −12로 '
        '음수인데(휘는 데 길이가 음수로 들 수는 없다) 그대로 셈한다. 반경이 비었다는 말이 없다.',
      );
      // 꼬리 0 vs 50 (R100, 500 90°)
      final tail0 = runEngine([[500.0, 90.0, 0.0]], radius: 100);
      final tail50 = runEngine([[500.0, 90.0, 0.0]], radius: 100, tail: 50);
      final tail100 = runEngine([[500.0, 90.0, 0.0]], radius: 100, tail: 100);
      t.note(
        'R100 [500, 90°]: 꼬리 0 → 절단 ${f1(engineCut(tail0))}(경고 '
        '${(tail0['warnings'] as List).length}건), 꼬리 50 → 절단 ${f1(engineCut(tail50))}'
        '(경고 ${(tail50['warnings'] as List).length}건), 꼬리 100 → '
        '${f1(engineCut(tail100))}. 꼬리를 0에서 50으로 늘리면 절단이 오히려 '
        '${f1(engineCut(tail0) - engineCut(tail50))}mm 짧아진다. '
        '꼬리 0은 "호 끝에서 끝"(=꼬리 100과 같은 값)으로 보고, 0<꼬리<셋백은 경고를 낸다.',
      );
      // 170°
      final a170 = runEngine([
        [500.0, 170.0, 0.0],
        [500.0, 170.0, 180.0],
      ], radius: 38.1, tail: 500);
      final ref170 = refTubeMarks(
        [const RefBend(500, 170), const RefBend(500, 170)],
        radius: 38.1,
        tail: 500,
      );
      t.note(
        '170°(입력 탭 상한) R38.1 [500,170°][500,170°] 꼬리500: 앱 절단 '
        '${f1(engineCut(a170))}, 기준 ${f1(ref170.cutLength)}, 셋백 '
        '${f1(bendSetback(38.1, 170))}, 경고 ${(a170['warnings'] as List).length}건'
        '(곧은 부분 ${f1((a170['steps'] as List<StepResult>)[1].straightPart)}). '
        '기하로는 맞고 경고도 난다.',
      );
      // 179.8° (엔진 상한 179.9 바로 아래)
      final a1798 = runEngine([[500.0, 179.8, 0.0]], radius: 100, tail: 300);
      t.note(
        '179.8° R100 [500]: 절단 ${f1(engineCut(a1798))}(음수), badCutLengthText → '
        '"${badCutLengthText(engineCut(a1798))}". 화면은 막지만 엔진 자체는 값을 낸다.',
      );
      // 음수 길이
      final neg = runEngine([
        [-100.0, 90.0, 0.0],
        [300.0, 90.0, 360.0],
      ], radius: 38.1, tail: 200);
      t.note(
        '음수 길이 [-100, 90°]: 마킹 ${engineMarks(neg).map(f1).join('·')}, 절단 '
        '${f1(engineCut(neg))}, 경고 ${(neg['warnings'] as List).length}건'
        '("곧은 부분 음수"로만 잡힌다. 길이가 음수라는 말은 없다).',
      );
      // NaN
      final nan = runEngine([[double.nan, 90.0, 0.0]], radius: 38.1, tail: 200);
      t.note(
        'NaN 길이: 절단 ${engineCut(nan)}, 경고 ${(nan['warnings'] as List).length}건. '
        '각도 NaN은 엔진 검사(<=0, >=179.9)를 모두 지나간다(tube_marking_rules.dart 주석과 같다).',
      );
      // 0° 만 있는 목록, 빈 목록
      final empty = runEngine([], radius: 38.1, tail: 200);
      t.note('빈 목록 + 꼬리 200: 절단 ${f1(engineCut(empty))} (꼬리만 더한다).');
    });

    test('최소 물림 길이 경고가 빠진 곳', () {
      const r = 38.1;
      const minStraight = 30.0; // 1/2" 표 값
      // 마킹 탭 점검: 곧은 부분 3.8mm인데 경고 없음
      final short = checkBends(
        [
          {'length': 300.0, 'angle': 90.0, 'rotation': 0.0},
          {'length': 80.0, 'angle': 90.0, 'rotation': 360.0},
        ],
        radius: r,
        startDir: 'RIGHT',
        tail: 200,
        outerDiameter: 12.7,
      );
      final straight = 80 - 2 * bendSetback(r, 90);
      final seg = checkSegmentLength(
        existing: [
          {'length': 300.0, 'angle': 90.0},
        ],
        length: 80,
        angle: 90,
        tubeOdMm: 12.7,
        minStraight: minStraight,
        warnShoeInterference: true,
      );
      t.note(
        '마킹 탭 점검(checkBends) R38.1 [300,90°][80,90°]: 벤드 사이 곧은 부분 '
        '${f1(straight)}mm(최소 물림 $minStraight) — 경고 ${short.warnings.length}건. '
        '0보다만 크면 아무 말이 없다. 입력 탭의 checkSegmentLength는 넣는 구간 길이'
        '(교차점 치수 80)로 비교해서 ${seg.shoeInterference ? '잡는다' : '안 잡는다'}'
        '(80 ≥ 30이라 통과. 실제 곧은 부분은 ${f1(straight)}).',
      );
      // 오프셋 시트 경고: 빗변(교차점 치수)으로 비교
      for (final h in [30.0, 40.0, 50.0]) {
        const a = 45.0;
        final travel = h / math.sin(a * math.pi / 180);
        final between = travel - 2 * bendSetback(r, a);
        t.note(
          '오프셋 시트 물림 경고(45° H$h R38.1): 빗변 ${f1(travel)} vs 최소 $minStraight → '
          '${travel < minStraight ? '경고' : '경고 없음'}. 실제 벤드 사이 곧은 부분은 '
          '${f1(between)}mm${between < minStraight ? '(물림 부족인데 못 잡음)' : ''}.',
        );
      }
      t.note(
        '누설 기준(segment_length_check.dart:43 minFittingStraightMm 21/24/30/32/38)과 '
        '제원 표 최소 직선(fitting_data.dart minStraight 20/25/30/45/60)은 출처가 적혀 '
        '있지 않다. 스웨즈락 설명서의 "벤드 앞 최소 직선" 표와 대조하지 못했다.',
      );
    });
  });

  // ────────────────────────────────────────────────────────────────
  group('전선관 · 수동 벤더(Greenlee EMT/Rigid) vs 기준', () {
    test('제원 표(bender_spec_data.dart) vs 관행 표', () {
      for (final size in [16, 22, 28, 36]) {
        final s = benderSpecData['hand']!['Greenlee']!['EMT']!['${size}mm']!;
        t.add(
          calc: '전선관 표 테이크업(EMT)',
          input: '${size}mm',
          app: s['takeUp'] as double,
          ref: refEmtTakeUpMm[size]!,
        );
        t.add(
          calc: '전선관 표 게인90(EMT)',
          input: '${size}mm',
          app: s['gain'] as double,
          ref: refEmtGain90Mm[size]!,
        );
        t.add(
          calc: '전선관 표 CLR(EMT)',
          input: '${size}mm',
          app: s['clr'] as double,
          ref: refEmtClrMm[size]!,
        );
        // 표 게인 vs CLR 기하 게인 — 정의가 다르다(표 게인은 등 기준).
        t.add(
          calc: '전선관 표 게인90 vs CLR 기하',
          input: '${size}mm CLR${s['clr']}',
          app: s['gain'] as double,
          ref: refGain(s['clr'] as double, 90),
          verdict: Verdict.definition,
          why: '표 게인은 관 등(바깥면)까지 잰 다리 기준, 기하 게인은 중심선 교차점 기준',
        );
      }
      for (final size in [16, 22, 28]) {
        final s = benderSpecData['hand']!['Greenlee']!['Rigid']!['${size}mm']!;
        t.add(
          calc: '전선관 표 테이크업(Rigid)',
          input: '${size}mm',
          app: s['takeUp'] as double,
          ref: refRigidTakeUpMm[size]!,
        );
      }
      t.note(
        '수동 벤더 42mm·54mm 줄(테이크업 304.8·355.6, EMT)과 Rigid 36·42·54mm 줄은 '
        '내가 아는 Greenlee 수동 벤더 제품군(1/2"~1-1/4" EMT, 1/2"~1" Rigid)에 없다. '
        '출처를 못 댔다. 시카고 벤더 테이크업은 수동 값을 베낀 근사치라고 파일에 적혀 있다.',
      );
      t.note(
        '전선관 설정 기본값(conduit_settings_page.dart:36) 22mm 게인은 81.2인데 '
        '제원 표(bender_spec_data.dart:11)는 82.5다. 처음 켰을 때와 표를 다시 불러왔을 때 값이 다르다.',
      );
    });

    test('90° 스텁·백투백·총 절단', () {
      for (final type in ['EMT', 'Rigid']) {
        for (final size in [16, 22, 28, 36, 42, 54]) {
          final s = conduitSettings(type: type, size: '${size}mm');
          final takeUp = s['takeUp'] as double;
          final gain = s['gain'] as double;
          final clr = s['clr'] as double;
          // 스텁 300 + 다리 700
          final list = conduitRows([
            [300, 90, 0],
            [700, 0, 0],
          ]);
          final m = conduitMarks(calculateConduitMarkings(list, s));
          t.add(
            calc: '전선관 90° 스텁 마킹',
            input: '$type ${size}mm 스텁300',
            app: m[0],
            ref: refStubMark(300, takeUp),
          );
          final cut = conduitTotalCut(list, s);
          t.add(
            calc: '전선관 90° 절단',
            input: '$type ${size}mm 300/700',
            app: cut,
            ref: refConduitCut90([300, 700], gain),
          );
          // 같은 치수를 교차점 기준으로 보면(CLR 기하) 절단이 다르다.
          final geo = refTubeMarks(
            [const RefBend(300, 90)],
            radius: clr,
            tail: 700,
          );
          t.add(
            calc: '전선관 90° 절단 vs 교차점 기하',
            input: '$type ${size}mm 300/700 CLR$clr',
            app: cut,
            ref: geo.cutLength,
            verdict: Verdict.definition,
            why:
                '앱 파일 머리말은 길이를 "꺾이는 점에서 꺾이는 점"이라 하고, '
                '표 게인 $gain은 등 기준(기하 게인 ${f1(refGain(clr, 90))})',
          );
          // 같은 반경을 튜브 엔진에 넣으면 마킹이 다르다(테이크업 = 반경 + 고정분).
          final tube = runEngine([[300.0, 90.0, 0.0]], radius: clr, tail: 700);
          t.add(
            calc: '전선관 vs 튜브 같은 반경 90° 마킹',
            input: '$type ${size}mm CLR$clr 스텁300',
            app: m[0],
            ref: engineMarks(tube)[0],
            verdict: Verdict.definition,
            why: '전선관 테이크업 $takeUp = 반경 $clr + 고정분 ${f1(takeUp - clr)}',
          );
          // 백투백: 두 번째 마킹
          final bb = conduitRows([
            [300, 90, 0],
            [400, 90, 0],
            [200, 0, 0],
          ]);
          final bbm = conduitMarks(calculateConduitMarkings(bb, s));
          final refBB = refBackToBackMarks(
            stub1ToBack: 300,
            backToBack: 400,
            takeUp: takeUp,
          );
          t.add(
            calc: '전선관 백투백 2번(화살표)',
            input: '$type ${size}mm 300/400',
            app: bbm[1],
            ref: refBB.secondArrow,
            verdict: Verdict.definition,
            why:
                '앱 = 300+400−게인$gain−테이크업(교차점 치수), 관행 = 등에서 등까지 400을 '
                '별표(${f1(refBB.secondStar)})나 화살표에. 별표 기준은 앱에 없다',
          );
        }
      }
    });

    test('오프셋(시트 → 마킹 셈) vs 관행 배수·정확값', () {
      for (final size in [16, 22, 28, 36]) {
        final s = conduitSettings(size: '${size}mm');
        final specs = BendSheetSpecs.conduit(s);
        final clr = s['clr'] as double;
        final gain90 = s['gain'] as double;
        for (final h in kOffsetHeights) {
          for (final a in [22.5, 30.0, 45.0, 60.0]) {
            final rows = sheetOffsetRows(specs, 300, h, a);
            final list = conduitRows([
              ...rows,
              [400, 0, 0],
            ]);
            final m = conduitMarks(calculateConduitMarkings(list, s));
            final trade = refConduitOffsetTrade(300, h, a);
            final exact = refConduitOffsetExact(300, h, a);
            t.add(
              calc: '전선관 오프셋 1번(관행)',
              input: '${size}mm H$h $a° 장애물300',
              app: m[0],
              ref: trade.mark1,
              verdict: Verdict.convention,
              why:
                  '수축: 앱 tan(θ/2)=${f1(m[0] - 300)} vs 관행 배수 ${f1(trade.shrink)}',
            );
            t.add(
              calc: '전선관 오프셋 1번(정확값)',
              input: '${size}mm H$h $a° 장애물300',
              app: m[0],
              ref: exact.mark1,
            );
            final gap = m[1] - m[0];
            t.add(
              calc: '전선관 오프셋 마킹 간격(관행)',
              input: '${size}mm H$h $a°',
              app: gap,
              ref: trade.travel,
              verdict: Verdict.convention,
              why:
                  '관행 = H×배수 ${f1(trade.travel)}(게인 안 뺌), 앱 = 빗변 '
                  '${f1(exact.travel)} − 게인(θ) ${f1(conduitGainForAngle(a, gain90))}',
            );
            // 기하로 보면 접점 간격 = 빗변 − CLR 기하 게인(θ).
            final geoGap = exact.travel - refGain(clr, a);
            t.add(
              calc: '전선관 오프셋 마킹 간격(기하)',
              input: '${size}mm H$h $a° CLR$clr',
              app: gap,
              ref: geoGap,
              verdict: Verdict.appWrong,
              why:
                  '표 게인 $gain90(등 기준)을 각도 비율로 줄인 '
                  '${f1(conduitGainForAngle(a, gain90))} vs CLR 기하 게인 '
                  '${f1(refGain(clr, a))}. 표 게인의 등(OD) 몫까지 같이 줄였다',
            );
          }
        }
      }
    });

    test('3벤드 새들 45°·60° 가운데 vs 관행·정확값', () {
      for (final size in [16, 22, 28]) {
        final s = conduitSettings(size: '${size}mm');
        final specs = BendSheetSpecs.conduit(s);
        for (final h in [50.0, 100.0, 200.0]) {
          for (final a3 in [45.0, 60.0]) {
            // 시트의 "장애물 앞 시작 거리"는 첫 옆 벤드가 시작하는 자리(1번 마킹).
            // 앱 모델(마킹 = 꺾이는 점 − 테이크업)에서 새들 가운데가 장애물 중심
            // 600에 오려면 시작 거리 = 600 − 옆 전진 − 테이크업(옆 각)이다.
            final side = refSaddle3(h, a3);
            final markOff = conduitMarkOffset(side.sideAngle, s);
            final start = 600 - side.run - markOff;
            final rows = sheetSaddle3Rows(specs, start, h, a3);
            final list = conduitRows([
              ...rows,
              [300, 0, 0],
            ]);
            final m = conduitMarks(calculateConduitMarkings(list, s));
            final trade = refConduitSaddle3Trade(600, h, a3)!;
            final exact = refConduitSaddle3Exact(600, h, a3);
            // 앱이 찍은 1번 마킹으로 만들면 가운데 꺾이는 점은 어디에 오나.
            final centerHoriz = m[0] + markOff + side.run;
            t.add(
              calc: '전선관 3점새들 가운데 위치',
              input: '${size}mm H$h 가운데$a3° 중심600',
              app: centerHoriz,
              ref: 600,
              verdict: Verdict.appWrong,
              why:
                  '1번 마킹은 앞에서 줄어드는 것이 없는데 총 수축 ${f1(side.totalShrink)}'
                  '(양쪽 몫)을 더해서 가운데가 그만큼 지나간다. 관행은 가운데 마킹 눈금에 '
                  '${f1(trade.shrink)}(한쪽 몫 ${f1(exact.shrink / 2)})을 더한다',
            );
            t.add(
              calc: '전선관 3점새들 1번 마킹(관행)',
              input: '${size}mm H$h 가운데$a3° 중심600',
              app: m[0],
              ref: trade.mark1,
              verdict: Verdict.convention,
              why:
                  '관행 1번 = 중심 + ${f1(trade.shrink)} − H×${a3 == 45 ? 2.5 : 2.0}, '
                  '앱 = 시작 거리 + 총 수축 ${f1(side.totalShrink)}',
            );
            t.add(
              calc: '전선관 3점새들 옆↔가운데 간격(관행)',
              input: '${size}mm H$h 가운데$a3°',
              app: m[1] - m[0],
              ref: trade.sideDistance,
              verdict: Verdict.convention,
              why:
                  '관행 H×${a3 == 45 ? 2.5 : 2.0}, 앱 = 빗변 ${f1(side.travel)} − 게인(${side.sideAngle}°) '
                  '+ 테이크업 차(${side.sideAngle}°↔$a3°)',
            );
          }
        }
      }
    });

    test('유압(램)·시카고 — 개념만', () {
      final ram = conduitSettings(benderType: 'ram', type: 'Rigid', size: '22mm');
      final chi = conduitSettings(benderType: 'chicago', type: 'Rigid', size: '22mm');
      for (final a in [22.5, 30.0, 45.0, 60.0, 90.0]) {
        t.add(
          calc: '램 마킹 거리(셋백 환산)',
          input: '22mm Rigid 셋백90=${ram['setback']} $a°',
          app: conduitMarkOffset(a, ram),
          ref: refRamSetbackShape(ram['setback'] as double, a),
        );
        final list = conduitRows([
          [500, a, 0],
          [500, 0, 0],
        ]);
        final item = calculateConduitMarkings(list, chi).first;
        t.add(
          calc: '시카고 노치 수',
          input: '22mm $a° 노치당${chi['degPerNotch']}°',
          app: (item['notches'] as int).toDouble(),
          ref: refChicagoNotches(a, chi['degPerNotch'] as double).toDouble(),
          unit: '개',
        );
      }
      t.note(
        '유압(램) 벤더는 제조사 표가 각도별 셋백을 따로 준다. 앱은 90° 셋백 하나를 '
        'tan(θ/2)로 줄인다(conduit_marking_logic.dart:55). 표가 없어 값으로는 비교 못 했다. '
        '램 이동량은 sin(θ/2) 비율 어림값이고 화면에 어림값이라고 적혀 있다.',
      );
      t.note(
        '시카고 벤더 테이크업은 bender_spec_data.dart:72 주석대로 수동 벤더 값을 그대로 '
        '옮긴 근사치다. 시카고 벤더는 관을 슈에 물리는 자리(훅)부터 재는 방식이라 '
        '수동 벤더 화살표 기준 테이크업과 같다고 볼 근거가 없다.',
      );
    });

    test('전선관 극단 입력: 90° 넘는 각의 게인 환산', () {
      final s = conduitSettings(size: '22mm');
      final clr = s['clr'] as double;
      final gain90 = s['gain'] as double;
      for (final a in [100.0, 120.0, 150.0, 170.0]) {
        t.add(
          calc: '전선관 게인(θ) 90° 넘는 각',
          input: '22mm EMT 게인90=$gain90 $a°',
          app: conduitGainForAngle(a, gain90),
          ref: refGain(clr, a),
          verdict: Verdict.appWrong,
          why: '표 게인 비율 환산이 각이 커질수록 CLR 기하 게인보다 급히 커진다',
        );
        final list = conduitRows([
          [300, a, 0],
          [300, 0, 0],
        ]);
        t.add(
          calc: '전선관 절단 90° 넘는 각',
          input: '22mm EMT [300,$a°][300]',
          app: conduitTotalCut(list, s),
          ref: refTubeMarks([RefBend(300, a)], radius: clr, tail: 300).cutLength,
          verdict: Verdict.appWrong,
          why: '170°(입력 상한)에서는 절단이 음수가 된다',
        );
      }
      final takeUp170 = conduitMarkOffset(170, s);
      t.note(
        '22mm EMT 170°: 테이크업 환산 ${f1(takeUp170)}mm(90° 152.4), 게인 환산 '
        '${f1(conduitGainForAngle(170, gain90))}mm — 입력 탭이 170°까지 받는다'
        '(conduit_input_tab.dart:32).',
      );
      t.note(
        '전선관 설정의 referenceMark("화살표 (일반)")·bendRadiusWarning 값은 저장만 되고 '
        '어느 셈에도 쓰이지 않는다(lib 전체에서 conduit_settings_page.dart 밖에 참조 없음). '
        'couplingDepth(20)는 main_navigation_page.dart:351에서 읽기만 한다.',
      );
    });
  });

  // ────────────────────────────────────────────────────────────────
  group('컷팅 vs 기준', () {
    test('절단 길이 = 중심 간 거리 − 양쪽 공제', () {
      final items = SmartFittingDB.getByMakerAndSize('Swagelok', '1/2"');
      for (final a in items) {
        for (final b in items) {
          for (final c2c in [300.0, 1000.0, 2588.0]) {
            t.add(
              calc: '컷팅 절단(mm 입력)',
              input: '${a.name}↔${b.name} $c2c',
              app: cutLengthMm(
                c2cInput: c2c,
                inputIsInch: false,
                startDeduction: a.deduction,
                endDeduction: b.deduction,
              ),
              ref: refCutLength(
                c2c: c2c,
                inch: false,
                startDeduction: a.deduction,
                endDeduction: b.deduction,
              ),
            );
          }
          t.add(
            calc: '컷팅 절단(인치 입력)',
            input: '${a.name}↔${b.name} 40"',
            app: cutLengthMm(
              c2cInput: 40,
              inputIsInch: true,
              startDeduction: a.deduction,
              endDeduction: b.deduction,
            ),
            ref: refCutLength(
              c2c: 40,
              inch: true,
              startDeduction: a.deduction,
              endDeduction: b.deduction,
            ),
          );
        }
      }
      final sizes = <String, int>{};
      for (final f in SmartFittingDB.allFittings) {
        sizes[f.tubeOD] = (sizes[f.tubeOD] ?? 0) + 1;
      }
      t.note(
        '부속 DB(smart_fitting_db.dart): 규격별 개수 $sizes. 스웨즈락 1/2"만 있고 '
        '1/4·3/8·3/4·1"과 Hy-Lok·Parker는 "직접 입력"뿐이다. 공제값(예: 일자 유니온 12.0, '
        '엘보 25.9)은 제조사 도면과 대조하지 못했다. FittingItem.insertionDepth는 '
        '커스텀 항목 말고는 0이고 셈에 쓰이지 않는다.',
      );
    });

    test('원자재 배치: 본수 ≤ FFD, ≥ 하한, 톱날 셈', () {
      final rnd = math.Random(20260923);
      var worse = 0;
      var underBound = 0;
      var cases = 0;
      for (var k = 0; k < 40; k++) {
        final n = 3 + rnd.nextInt(14);
        final pieces = [
          for (var i = 0; i < n; i++) 200.0 + rnd.nextInt(3800),
        ];
        for (final kerf in [0.0, 3.0]) {
          final app = optimizeCutting(pieces: pieces, stockLength: 6000, kerf: kerf);
          final ffd = refFirstFitDecreasing(pieces, 6000, kerf: kerf);
          final lb = refLowerBoundBars(pieces, 6000);
          cases++;
          if (app.barCount > ffd.bars.length) worse++;
          if (app.barCount < lb) underBound++;
          // 남는 길이 셈(톱날 × 조각 수)
          for (final bar in app.bars) {
            t.add(
              calc: '컷팅 남는 길이',
              input: '조각${bar.pieces.length}개 톱날$kerf',
              app: bar.remainderWithKerf(kerf),
              ref: refBarRemainder(bar.pieces, 6000, kerf).clamp(0.0, 6000.0),
            );
          }
        }
      }
      t.note(
        '원자재 배치 무작위 $cases건: 앱 본수가 긴 것부터 넣기(FFD)보다 많은 경우 $worse건, '
        '이론 하한(총길이÷원자재 올림)보다 적은 경우 $underBound건. '
        '톱날은 앱·기준 모두 조각마다 한 번씩(보수적) 뺀다.',
      );
      // 톱날 손실을 구간 절단 길이에는 안 넣는다.
      t.note(
        '컷팅 화면은 톱날 손실을 구간 절단 길이(cutLengthMm)에는 넣지 않고 누적 사용량에만 '
        '(구간 수 × 세트 수 × 톱날) 더한다(cutting_main_screen.dart:2067). 잘라야 할 치수 '
        '자체는 그대로다.',
      );
    });
  });
}
