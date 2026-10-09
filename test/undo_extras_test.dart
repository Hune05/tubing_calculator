// 10-09: 보관함 불러오기·U벤드를 ↶로 되돌려도 꼬리·피팅(튜브), 시작 방향·커플링(전선관)은
// 불러온 값으로 남아 옛 목록이 다른 절단 길이로 셈해졌다. 평소 고치기는 목록만 되돌린다.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_field_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    final m = MobileBendDataManager();
    m.clearHistory();
    m.bendList
      ..clear()
      ..add({'length': 300.0, 'angle': 90.0, 'rotation': 0.0});
    MachineSpecs().update(tail: 0, startFit: false, endFit: false);
  });

  test('튜브: 불러오기를 되돌리면 꼬리·피팅도 그 전 값으로, 다시 하기는 불러온 값으로', () {
    final m = MobileBendDataManager();
    m.replaceAll([
      {'length': 500.0, 'angle': 90.0, 'rotation': 0.0},
    ]);
    // 상세 화면이 불러온 뒤 그 도면의 꼬리·피팅을 넣는다.
    m.startFit = true;
    m.endFit = true;
    m.tail = 300;
    expect(m.undo(), isTrue);
    expect(m.bendList.single['length'], 300.0);
    expect(MachineSpecs().tail, 0);
    expect(MachineSpecs().startFit, isFalse);
    expect(MachineSpecs().endFit, isFalse);
    expect(m.redo(), isTrue);
    expect(m.bendList.single['length'], 500.0);
    expect(MachineSpecs().tail, 300);
    expect(MachineSpecs().endFit, isTrue);
  });

  test('튜브: 평소 줄 넣기를 되돌릴 때는 그사이 손으로 바꾼 꼬리를 건드리지 않는다', () {
    final m = MobileBendDataManager();
    m.addBend({'length': 200.0, 'angle': 0.0, 'rotation': 0.0});
    m.tail = 250;
    expect(m.undo(), isTrue);
    expect(m.bendList.length, 1);
    expect(MachineSpecs().tail, 250);
  });

  test('튜브: U벤드처럼 피팅을 바꾸며 넣은 것은 되돌릴 때 피팅도 돌아온다', () {
    final m = MobileBendDataManager();
    MachineSpecs().update(endFit: true);
    m.captureExtrasInNextRecord();
    m.addMultipleBends([
      {'length': 100.0, 'angle': 90.0, 'rotation': 0.0, 'uBend': 1.0},
      {'length': 100.0, 'angle': 90.0, 'rotation': 0.0, 'uBend': 2.0},
    ]);
    m.endFit = false;
    expect(m.undo(), isTrue);
    expect(MachineSpecs().endFit, isTrue);
    // 담는 것은 한 번뿐: 다음 평소 넣기는 피팅을 담지 않는다.
    m.addBend({'length': 50.0, 'angle': 0.0, 'rotation': 0.0});
    m.endFit = false;
    expect(m.undo(), isTrue);
    expect(MachineSpecs().endFit, isFalse);
  });

  test('전선관: 불러오기를 되돌리면 시작 방향·커플링도 돌아온다', () {
    installConduitHistoryExtras();
    final c = ConduitDataManager();
    c.clearHistory();
    c.bendList
      ..clear()
      ..add({'length': 300.0, 'angle': 90.0});
    conduitStartDir.value = 'RIGHT';
    conduitUseCoupling.value = false;
    c.replaceAll([
      {'length': 500.0, 'angle': 90.0},
    ]);
    conduitStartDir.value = 'UP';
    conduitUseCoupling.value = true;
    expect(c.undo(), isTrue);
    expect(conduitStartDir.value, 'RIGHT');
    expect(conduitUseCoupling.value, isFalse);
    expect(c.redo(), isTrue);
    expect(conduitStartDir.value, 'UP');
    expect(conduitUseCoupling.value, isTrue);
  });

  test('전체 지우기를 ↶로 살리면 불러온 도면(덮어쓰기 대상)도 돌아온다(튜브·전선관)', () {
    final m = MobileBendDataManager();
    m.replaceAll([
      {'length': 500.0, 'angle': 90.0, 'rotation': 0.0},
    ]);
    m.setSource(7);
    m.clearBends();
    expect(m.sourceHistoryId, isNull);
    expect(m.undo(), isTrue);
    expect(m.bendList.single['length'], 500.0);
    expect(m.sourceHistoryId, 7);

    installConduitHistoryExtras();
    final c = ConduitDataManager();
    c.clearHistory();
    c.replaceAll([
      {'length': 400.0, 'angle': 90.0},
    ]);
    c.setSource('d1');
    c.clearBends();
    expect(c.sourceDrawingId, isNull);
    expect(c.undo(), isTrue);
    expect(c.sourceDrawingId, 'd1');
  });
  test('전체 지우기를 ↶ 해도 그사이 바꾼 꼬리는 되돌리지 않는다(8차)', () {
    final m = MobileBendDataManager();
    m.replaceAll([
      {'length': 500.0, 'angle': 90.0, 'rotation': 0.0},
    ]);
    m.setSource(9);
    m.clearBends();
    m.tail = 50;
    expect(m.undo(), isTrue);
    expect(MachineSpecs().tail, 50);
    expect(m.sourceHistoryId, 9);
  });
}
