// 배치도 계기 모듈: 크기가 모두 들어 있고 이름이 겹치지 않는지.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/layout_board_models.dart';

void main() {
  test('계기 모듈은 네 제조사, 크기는 모두 양수, 이름은 겹치지 않는다', () {
    expect(kInstrumentPresets.keys, ['요꼬가와', '오토롤', '로즈마운트', '비카']);
    final names = <String>{};
    for (final list in kInstrumentPresets.values) {
      expect(list, isNotEmpty);
      for (final p in list) {
        expect(p.width, greaterThan(0), reason: p.name);
        expect(p.height, greaterThan(0), reason: p.name);
        expect(names.add(p.name), isTrue, reason: '겹친 이름 ${p.name}');
      }
    }
  });

  test('제조사 도면 값 몇 개를 그대로 옮겼다', () {
    ModulePreset find(String n) => kInstrumentPresets.values
        .expand((l) => l)
        .firstWhere((p) => p.name == n);
    expect(
      [find('EJA110E DPT 수직배관').width, find('EJA110E DPT 수직배관').height],
      [175, 138],
    );
    expect([find('APT3100 DPT').width, find('APT3100 DPT').height], [86, 194]);
    expect([find('3051CD DPT').width, find('3051CD DPT').height], [104, 181]);
    expect([find('2120 레벨 스위치').width, find('2120 레벨 스위치').height], [120, 220]);
    expect([find('MA 압력 스위치').width, find('MA 압력 스위치').height], [161, 121]);
  });

  test('ABS 덕트는 빗살 모양으로 그린다', () {
    for (final p in kDuctPresets) {
      expect(p.shape, 'duct', reason: p.name);
    }
  });
}
