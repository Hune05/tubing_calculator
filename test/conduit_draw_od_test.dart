// 3D 그림·관끼리 닿음 점검의 관 바깥지름: 후강(Rigid) 호칭("22mm")은 지름이 아니라 호칭이라
// KS C 8401 표의 실제 바깥지름(22 → 26.5)을 쓴다. 그 밖의 종류·표기는 예전처럼 규격 글에서 읽는다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';

void main() {
  test('후강(Rigid): 호칭이 아니라 실제 바깥지름', () {
    const od = {16: 21.0, 22: 26.5, 28: 33.3, 36: 41.9, 42: 47.8, 54: 59.6};
    for (final e in od.entries) {
      expect(
        conduitDrawOuterDiameterMm({
          'conduitType': 'Rigid',
          'conduitSize': '${e.key}mm',
        }),
        e.value,
        reason: '${e.key}mm',
      );
    }
  });

  test('후강이 아닌 종류(EMT 등)나 다른 표기는 예전처럼 규격 글에서 읽는다', () {
    expect(
      conduitDrawOuterDiameterMm({'conduitType': 'EMT', 'conduitSize': '22mm'}),
      22,
    );
    expect(
      conduitDrawOuterDiameterMm({'conduitType': 'EMT', 'conduitSize': 'E25'}),
      25,
    );
    expect(
      conduitDrawOuterDiameterMm({'conduitType': 'Rigid', 'conduitSize': 'G22'}),
      22,
    ); // 후강 표기가 'NNmm'이 아니면 그대로
    expect(conduitDrawOuterDiameterMm({'conduitSize': ''}), 0);
    expect(conduitDrawOuterDiameterMm({}), 0);
  });

  test('표에 없는 후강 호칭(예: 100mm)은 규격 글 그대로', () {
    expect(
      conduitDrawOuterDiameterMm({'conduitType': 'Rigid', 'conduitSize': '100mm'}),
      100,
    );
  });
}
