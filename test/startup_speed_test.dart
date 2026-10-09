// 켜기 속도(10-09): 로딩 화면을 짧게, 옛 Hive 상자는 옮기기가 끝난 폰에서 열지 않고 실패해도 앱은 켜진다.
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/startup_guard.dart';
import 'package:tubing_calculator/src/data/repositories/work_project_repository.dart';
import 'package:tubing_calculator/src/presentation/menu/page/mobile_loading_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('로딩 화면은 0.5초 안팎만 붙잡는다(예전 1.5초 + 0.8초)', () {
    expect(kLoadingMinShow.inMilliseconds, lessThanOrEqualTo(500));
    expect(kLoadingFadeOut.inMilliseconds, lessThanOrEqualTo(300));
  });

  test('옮기기가 끝난 폰은 옛 Hive 상자를 열지 않는다', () async {
    SharedPreferences.setMockInitialValues({kHiveProjectsMigratedFlag: true});
    await openLegacyHiveIfNeeded();
    expect(Hive.isBoxOpen('projectsBox'), isFalse);
  });

  test('옛 상자를 열다 오류가 나도 시작 준비는 넘어간다', () async {
    var after = false;
    await startupStep(
      '옛 저장소',
      () async => throw StateError('깨진 파일'),
      timeout: const Duration(seconds: 1),
    );
    after = true;
    expect(after, isTrue);
  });
}
