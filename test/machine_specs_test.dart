import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
  });

  // 옛 태블릿 화면(BendDataManager)은 10-08에 지웠다. 폰 화면은 제원을 MachineSpecs 한 벌로 본다.
  group('제원은 한 벌만 둔다', () {
    test('폰 화면에서 고친 반경·게인이 제원 한 벌에 바로 들어간다', () {
      MobileBendDataManager().radius = 38.0;
      MobileBendDataManager().gain90 = 40.0;
      expect(MachineSpecs().radius, 38.0);
      expect(MachineSpecs().gain90, 40.0);
    });

    test('제원 묶음으로 고쳐도 같다', () {
      MobileBendDataManager().updateMachineSpecs(
        radius: 50.0,
        takeUp90: 60.0,
        gain90: 25.0,
        springback: 2.0,
        fittingDepth: 23.0,
        benderOffset: 5.0,
        cutMargin: 1.5,
      );
      final m = MachineSpecs();
      expect(m.radius, 50.0);
      expect(m.takeUp90, 60.0);
      expect(m.gain90, 25.0);
      expect(m.springback, 2.0);
      expect(m.fittingDepth, 23.0);
      expect(m.benderOffset, 5.0);
      expect(m.cutMargin, 1.5);
    });

    test('제원이 바뀌면 폰 화면에 알린다', () {
      var calls = 0;
      void on() => calls++;
      MobileBendDataManager().addListener(on);
      addTearDown(() => MobileBendDataManager().removeListener(on));
      MachineSpecs().radius = 38.0;
      expect(calls, greaterThan(0));
    });
  });

  group('폰에 적어 둔 제원 읽기', () {
    test('저장된 값을 그대로 읽는다', () async {
      SharedPreferences.setMockInitialValues({
        'bendRadius': 38.0,
        'gain': 40.0,
        'takeUp': 110.0,
        'fittingDepth': 23.0,
        'springback': 2.0,
        'benderOffset': 5.0,
        'cutMargin': 1.5,
        'tail_length': 100.0,
        'start_fit': true,
      });
      await MachineSpecs().load();
      expect(MobileBendDataManager().radius, 38.0);
      expect(MobileBendDataManager().gain90, 40.0);
      expect(MobileBendDataManager().takeUp90, 110.0);
      expect(MobileBendDataManager().fittingDepth, 23.0);
      expect(MobileBendDataManager().tail, 100.0);
      expect(MobileBendDataManager().startFit, isTrue);
      expect(MachineSpecs().cutMargin, 1.5);
    });

    test('적힌 값이 없으면 0으로 본다', () async {
      SharedPreferences.setMockInitialValues({});
      await MachineSpecs().load();
      expect(MachineSpecs().radius, 0.0);
      expect(MachineSpecs().gain90, 0.0);
    });
  });
}
