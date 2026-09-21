// 오프셋·새들 계산기가 쓰는 장비 값 한 벌 검사.
// 핵심: 계산기가 더한 첫 구간 길이에서 마킹 화면이 도로 빼는 거리가 같아야
// "1번 마킹 = 시작 거리(+축소값)"가 된다. 예전에는 전선관에서도 튜브 반경으로
// 셋백을 더해서, 직관 150 뒤에 넣은 오프셋의 1번 마킹이 98에 찍혔다.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';

Map<String, dynamic> conduitSettings({
  String benderType = 'hand',
  bool applyShrink = true,
  double setback = 0.0,
}) => {
  'benderType': benderType,
  'takeUp': 152.4,
  'clr': 114.3,
  'gain': 81.2,
  'couplingDepth': 20.0,
  'applySpringback': false,
  'springback': 3.0,
  'degPerNotch': 2.5,
  'ramTravel': 0.0,
  'setback': setback,
  'applyShrink': applyShrink,
};

List<Map<String, dynamic>> bends(List<List<double>> rows) => [
  for (final r in rows) {'length': r[0], 'angle': r[1], 'rotation': r[2]},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('전선관 한 벌', () {
    test('꺾이는 점에서 마킹까지 = 마킹 화면이 빼는 테이크업', () {
      final s = conduitSettings();
      final specs = BendSheetSpecs.conduit(s);
      for (final a in [21.0, 30.0, 45.0, 90.0]) {
        expect(specs.markOffset(a), closeTo(conduitMarkOffset(a, s), 1e-9));
        expect(
          specs.markOffset(a),
          closeTo(scaleTakeUp(152.4, 114.3, a), 1e-9),
        );
      }
      expect(specs.radius, 114.3);
      expect(specs.gain90, 81.2);
      expect(specs.isConduit, isTrue);
    });

    test('직관 150 뒤에 넣은 오프셋: 1번 마킹이 150 + 축소값에 찍힌다', () {
      // 오늘 현장 자료. 21° 오프셋, 빗변 195.3(높이 70).
      final s = conduitSettings();
      final specs = BendSheetSpecs.conduit(s);
      const angle = 21.0, travel = 195.3;
      final run = 70.0 / 0.383864; // h / tan(21°)
      final shrink = travel - run; // ≈ 13
      final firstLen = specs.firstLength(0, angle, shrink);
      final m = calculateConduitMarkings(
        bends([
          [150, 0, 0],
          [firstLen, angle, 0],
          [travel, angle, 180],
          [200, 0, 0],
        ]),
        s,
      );
      expect(m[0]['mark'] as double, closeTo(150, 0.01));
      // 예전에는 97.8이었다(튜브 반경 셋백 7.06 − 테이크업 59.3).
      expect(m[1]['mark'] as double, closeTo(150 + shrink, 0.01));
      expect(m[1]['mark'] as double, greaterThanOrEqualTo(150));
      // 2번 마킹은 빗변에서 앞 벤드 게인만 뺀 만큼 뒤.
      expect(
        (m[2]['mark'] as double) - (m[1]['mark'] as double),
        closeTo(travel - conduitGainForAngle(angle, 81.2), 0.01),
      );
    });

    test('수축량 스위치를 끄면 1번 마킹이 시작 거리 그대로', () {
      final s = conduitSettings(applyShrink: false);
      final specs = BendSheetSpecs.conduit(s);
      expect(specs.shrinkToAdd(13.0), 0.0);
      final m = calculateConduitMarkings(
        bends([
          [150, 0, 0],
          [specs.firstLength(0, 21, 13.0), 21, 0],
          [195.3, 21, 180],
        ]),
        s,
      );
      expect(m[1]['mark'] as double, closeTo(150, 0.01));
    });

    test('스위치 값이 없으면 켜진 것으로 본다', () {
      final s = conduitSettings()..remove('applyShrink');
      expect(BendSheetSpecs.conduit(s).addGeometricShrink, isTrue);
    });

    test('유압(램)은 셋백 설정값을 쓴다', () {
      final s = conduitSettings(benderType: 'ram', setback: 40.0);
      final specs = BendSheetSpecs.conduit(s);
      expect(specs.markOffset(90), closeTo(40.0, 1e-9));
      expect(specs.markOffset(45), closeTo(40.0 * 0.41421356, 1e-6));
      final m = calculateConduitMarkings(
        bends([
          [300, 0, 0],
          [specs.firstLength(0, 45, 0), 45, 0],
        ]),
        s,
      );
      expect(m[1]['mark'] as double, closeTo(300, 0.01));
    });

    test('음수 축소값은 더하지 않는다', () {
      final specs = BendSheetSpecs.conduit(conduitSettings());
      expect(specs.shrinkToAdd(-5), 0.0);
    });
  });

  group('튜브 한 벌', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MachineSpecs().resetForTest();
    });

    test('마킹 화면과 같은 제원(반경·게인)을 본다', () async {
      SharedPreferences.setMockInitialValues({
        'offsetShrink': 5.0,
        'minStraight': 30.0,
        'warnShoeInterference': false,
      });
      MachineSpecs().update(radius: 38.1, gain90: 12.0);
      final specs = await BendSheetSpecs.tube();
      expect(specs.radius, 38.1);
      expect(specs.gain90, 12.0);
      expect(specs.minStraight, 30.0);
      expect(specs.warnShoeInterference, isFalse);
      expect(specs.isConduit, isFalse);
      // 튜브는 셋백을 도로 뺀다.
      expect(specs.markOffset(90), closeTo(38.1, 1e-9));
    });

    test('기하 축소값은 더하지 않고, 설정의 여유만 더한다', () async {
      SharedPreferences.setMockInitialValues({'offsetShrink': 5.0});
      MachineSpecs().update(radius: 38.1, gain90: 12.0);
      final specs = await BendSheetSpecs.tube();
      expect(specs.shrinkToAdd(26.8), 5.0);
      expect(specs.firstMark(100, 26.8), 105.0);
      expect(specs.firstLength(100, 90, 26.8), closeTo(105 + 38.1, 1e-9));
    });

    test('제원이 아직 안 읽혔으면 폰에 적힌 값을 쓴다', () async {
      SharedPreferences.setMockInitialValues({
        'bendRadius': 100.0,
        'gain': 40.0,
      });
      final specs = await BendSheetSpecs.tube();
      expect(specs.radius, 100.0);
      expect(specs.gain90, 40.0);
    });
  });
}
