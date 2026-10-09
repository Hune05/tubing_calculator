// 10-09: 제원 묶음 이름표에 재질을 붙여 SUS와 구리의 게인·반경을 따로 기억한다.
// 재질 없는 예전 묶음은 앱을 켤 때의 재질로 한 번 옮긴다.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_spec_sets.dart';

void main() {
  test('이름표에 재질이 붙고, 재질이 비면 예전 꼴', () {
    final a = machineSpecKey(benderBrand: 'Swagelok', benderType: '수동 (Hand)', tubeSize: '0.5', tubeMaterial: 'SUS');
    final b = machineSpecKey(benderBrand: 'Swagelok', benderType: '수동 (Hand)', tubeSize: '0.5', tubeMaterial: 'Copper');
    final old = machineSpecKey(benderBrand: 'Swagelok', benderType: '수동 (Hand)', tubeSize: '0.5');
    expect(a, '$old|sus');
    expect(b, '$old|copper');
    expect(a, isNot(b));
  });

  test('예전 묶음을 지금 재질로 옮기고, 이미 있는 것은 덮지 않는다', () async {
    final old = machineSpecKey(benderBrand: 'Swagelok', benderType: '수동 (Hand)', tubeSize: '0.5');
    SharedPreferences.setMockInitialValues({
      kMachineSpecSetsPrefsKey: jsonEncode({
        old: {'bendRadius': 38.1, 'gain': 18.0},
        'swagelok|수동 (hand)|0.375|sus': {'bendRadius': 23.8, 'gain': 9.0},
        'swagelok|수동 (hand)|0.375': {'bendRadius': 99.0, 'gain': 99.0},
      }),
    });
    await migrateMachineSpecSetsToMaterial('SUS');
    final all = await loadMachineSpecSets();
    expect(all.keys.where((k) => k.split('|').length == 3), isEmpty);
    expect(all['$old|sus']!.gain, 18.0);
    expect(all['swagelok|수동 (hand)|0.375|sus']!.gain, 9.0); // 이미 있던 것이 이긴다
    // 다른 재질에는 옮기지 않는다
    expect(all.containsKey('$old|copper'), isFalse);
  });
}
