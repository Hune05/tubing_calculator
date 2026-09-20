import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/bend_data_manager.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
  });

  group('제원은 한 벌만 둔다', () {
    test('폰에서 고친 반경이 태블릿 화면에도 바로 보인다', () {
      MobileBendDataManager().radius = 38.0;
      expect(BendDataManager().radius, 38.0);
    });

    test('태블릿에서 고친 게인이 폰 화면에도 바로 보인다', () {
      BendDataManager().gain90 = 40.0;
      expect(MobileBendDataManager().gain90, 40.0);
    });

    test('제원 묶음으로 고쳐도 양쪽이 같다', () {
      MobileBendDataManager().updateMachineSpecs(
        radius: 50.0,
        takeUp90: 60.0,
        gain90: 25.0,
        springback: 2.0,
        fittingDepth: 23.0,
        benderOffset: 5.0,
        cutMargin: 1.5,
      );
      final d = BendDataManager();
      expect(d.radius, 50.0);
      expect(d.takeUp90, 60.0);
      expect(d.gain90, 25.0);
      expect(d.springback, 2.0);
      expect(d.fittingDepth, 23.0);
      expect(d.benderOffset, 5.0);
      expect(MachineSpecs().cutMargin, 1.5);
    });

    test('꼬리 길이와 시작·끝 피팅도 같이 본다', () {
      BendDataManager().tail = 120.0;
      BendDataManager().startFit = true;
      expect(MobileBendDataManager().tail, 120.0);
      expect(MobileBendDataManager().startFit, isTrue);
    });

    test('제원이 바뀌면 양쪽 화면 모두에 알린다', () {
      var mobileCalls = 0;
      var deskCalls = 0;
      void onMobile() => mobileCalls++;
      void onDesk() => deskCalls++;
      MobileBendDataManager().addListener(onMobile);
      BendDataManager().addListener(onDesk);
      addTearDown(() {
        MobileBendDataManager().removeListener(onMobile);
        BendDataManager().removeListener(onDesk);
      });

      MachineSpecs().radius = 38.0;
      expect(mobileCalls, greaterThan(0));
      expect(deskCalls, greaterThan(0));
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
      expect(BendDataManager().radius, 38.0);
      expect(MobileBendDataManager().gain90, 40.0);
      expect(MobileBendDataManager().takeUp90, 110.0);
      expect(BendDataManager().fittingDepth, 23.0);
      expect(BendDataManager().tail, 100.0);
      expect(BendDataManager().startFit, isTrue);
      expect(MachineSpecs().cutMargin, 1.5);
    });

    test('적힌 값이 없으면 0으로 본다', () async {
      SharedPreferences.setMockInitialValues({});
      await MachineSpecs().load();
      expect(MachineSpecs().radius, 0.0);
      expect(MachineSpecs().gain90, 0.0);
    });
  });

  group('벤드 목록은 화면마다 따로 둔다', () {
    test('폰 목록과 태블릿 목록이 섞이지 않는다', () {
      BendDataManager().clearBends();
      MobileBendDataManager().clearBends();
      BendDataManager().addBend(500, 90, 0);
      expect(BendDataManager().bendList.length, 1);
      expect(MobileBendDataManager().bendList, isEmpty);
    });
  });
}
