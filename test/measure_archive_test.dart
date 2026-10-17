// 도면별 실측 보관(10-17 점검): 다른 도면을 열었다 돌아와도 실측·각도가 되살아나는지.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/field/field_progress_bus.dart';

void main() {
  test('도면 A 실측 → 도면 B로 바꿔도 A 실측이 남는다', () async {
    SharedPreferences.setMockInitialValues({});
    await writeFieldMeasured(progressKey: kTubeFieldProgressKey, signature: 'A', step: 0, diff: 3, id: 'a0');
    await writeAngleMeasured('A', 0, 91);
    // 도면 B에서 실측(진행 칸이 B로 바뀜)
    await writeFieldMeasured(progressKey: kTubeFieldProgressKey, signature: 'B', step: 1, diff: -2, id: 'b1');
    await writeAngleMeasured('B', 1, 88);
    expect(await readFieldMeasured(kTubeFieldProgressKey, 'B'), {1: -2.0});
    // A로 돌아오면 보관에서
    expect(await readFieldMeasured(kTubeFieldProgressKey, 'A'), {0: 3.0});
    expect(await readFieldMeasuredIds(kTubeFieldProgressKey, 'A'), {0: 'a0'});
    expect(await readAngleMeasured('A'), {0: 91.0});
    expect(await readAngleMeasured('B'), {1: 88.0});
    // 각도 지우기
    await writeAngleMeasured('A', 0, null);
    expect(await readAngleMeasured('A'), isEmpty);
  });

  test('예전(한 도면) 각도 모양도 읽는다', () async {
    SharedPreferences.setMockInitialValues({
      kTubeAngleKey: '{"sig":"OLD","angles":{"2":92.5}}',
    });
    expect(await readAngleMeasured('OLD'), {2: 92.5});
    await writeAngleMeasured('NEW', 0, 90);
    expect(await readAngleMeasured('OLD'), {2: 92.5});
    expect(await readAngleMeasured('NEW'), {0: 90.0});
  });
}
