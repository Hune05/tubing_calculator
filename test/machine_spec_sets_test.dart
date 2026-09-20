// 규격·장비별 제원 묶음.
// 3/8"로 맞춰 둔 반경·게인을 1/2"로 바꿨다가 돌아오면 그대로 나와야 한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_spec_sets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('이름표', () {
    test('벤더·장비·규격을 묶어 만든다', () {
      final a = machineSpecKey(
        benderBrand: 'Swagelok',
        benderType: '수동 (Hand)',
        tubeSize: '12.7',
      );
      final b = machineSpecKey(
        benderBrand: 'Swagelok',
        benderType: '수동 (Hand)',
        tubeSize: '9.52',
      );
      expect(a, isNot(b));
    });

    test('빈칸·대소문자가 달라도 같은 이름표', () {
      expect(
        machineSpecKey(
          benderBrand: ' swagelok ',
          benderType: '수동  (Hand)',
          tubeSize: '12.7',
        ),
        machineSpecKey(
          benderBrand: 'Swagelok',
          benderType: '수동 (Hand)',
          tubeSize: '12.7',
        ),
      );
    });

    test('장비 타입이 다르면 다른 이름표', () {
      expect(
        machineSpecKey(
          benderBrand: 'Swagelok',
          benderType: '수동 (Hand)',
          tubeSize: '12.7',
        ),
        isNot(
          machineSpecKey(
            benderBrand: 'Swagelok',
            benderType: '전동 (Electric)',
            tubeSize: '12.7',
          ),
        ),
      );
    });
  });

  group('적어 두고 꺼내기', () {
    test('넣어 둔 제원이 그대로 나온다', () async {
      const set = MachineSpecSet(
        bendRadius: 38.1,
        takeUp: 25,
        gain: 12,
        springback: 2,
        autoFields: {'radius'},
      );
      await saveMachineSpecSet('a', set);
      final got = await loadMachineSpecSet('a');
      expect(got, isNotNull);
      expect(got!.bendRadius, 38.1);
      expect(got.takeUp, 25);
      expect(got.gain, 12);
      expect(got.springback, 2);
      expect(got.autoFields, {'radius'});
    });

    test('규격을 바꿨다 돌아와도 각각 그대로다', () async {
      await saveMachineSpecSet(
        '3/8',
        const MachineSpecSet(bendRadius: 38.1, gain: 12),
      );
      await saveMachineSpecSet(
        '1/2',
        const MachineSpecSet(bendRadius: 50.8, gain: 20),
      );
      expect((await loadMachineSpecSet('3/8'))!.gain, 12);
      expect((await loadMachineSpecSet('1/2'))!.gain, 20);
    });

    test('같은 이름표로 다시 적으면 덮어쓴다', () async {
      await saveMachineSpecSet('a', const MachineSpecSet(gain: 12));
      await saveMachineSpecSet('a', const MachineSpecSet(gain: 20));
      expect((await loadMachineSpecSet('a'))!.gain, 20);
    });

    test('넣어 둔 적 없는 이름표는 없다고 한다', () async {
      expect(await loadMachineSpecSet('없음'), isNull);
    });

    test('값이 다 0이면 적지 않는다', () async {
      await saveMachineSpecSet('빈것', const MachineSpecSet());
      expect(await loadMachineSpecSet('빈것'), isNull);
    });

    test('이름표가 비어 있으면 적지 않는다', () async {
      await saveMachineSpecSet('  ', const MachineSpecSet(gain: 12));
      expect(await loadMachineSpecSets(), isEmpty);
    });

    test('여러 조합을 한꺼번에 들고 있는다', () async {
      await saveMachineSpecSet('a', const MachineSpecSet(gain: 1));
      await saveMachineSpecSet('b', const MachineSpecSet(gain: 2));
      await saveMachineSpecSet('c', const MachineSpecSet(gain: 3));
      final all = await loadMachineSpecSets();
      expect(all.length, 3);
    });

    test('적힌 글이 깨져 있어도 앱이 멈추지 않는다', () async {
      SharedPreferences.setMockInitialValues({
        kMachineSpecSetsPrefsKey: '이건 JSON이 아니다',
      });
      expect(await loadMachineSpecSets(), isEmpty);
    });
  });
}
