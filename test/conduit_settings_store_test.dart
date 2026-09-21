// 전선관 설정이 폰에 남는지 검사. 예전에는 앱을 끄면 기본값으로 돌아갔다.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> defaults;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    defaults = Map<String, dynamic>.from(globalBenderSettings.value);
  });

  tearDown(() {
    globalBenderSettings.value = defaults;
  });

  test('저장한 값을 다시 읽으면 그대로다', () async {
    globalBenderSettings.value = {
      ...globalBenderSettings.value,
      'takeUp': 133.0,
      'clr': 120.5,
      'gain': 70.0,
      'applyShrink': false,
      'benderType': 'chicago',
      'springback': 2.0,
    };
    await saveGlobalBenderSettings();

    globalBenderSettings.value = defaults;
    expect(globalBenderSettings.value['takeUp'], 152.4);

    await loadGlobalBenderSettings();
    final s = globalBenderSettings.value;
    expect(s['takeUp'], 133.0);
    expect(s['clr'], 120.5);
    expect(s['gain'], 70.0);
    expect(s['applyShrink'], isFalse);
    expect(s['benderType'], 'chicago');
    // 숫자가 정수로 바뀌어 화면이 죽지 않게 double로 남아야 한다.
    expect(s['springback'], isA<double>());
    expect(s['couplingDepth'], isA<double>());
    expect(s['degPerNotch'], isA<double>());
  });

  test('적힌 게 없으면 기본값 그대로', () async {
    await loadGlobalBenderSettings();
    expect(globalBenderSettings.value['takeUp'], 152.4);
  });

  test('적힌 글이 깨져 있어도 멈추지 않는다', () async {
    SharedPreferences.setMockInitialValues({
      kConduitSettingsPrefsKey: '이건 JSON이 아니다',
    });
    await loadGlobalBenderSettings();
    expect(globalBenderSettings.value['takeUp'], 152.4);
  });
}
