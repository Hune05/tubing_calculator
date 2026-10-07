// 계산기 설정 서버 보관: 폰 설정을 모으고, 가짜 서버에 올렸다가 새로 깐 폰에
// 되돌리는지 본다(진짜 서버는 쓰지 않는다).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';
import 'package:tubing_calculator/src/core/utils/settings_cloud.dart';
import 'package:tubing_calculator/src/presentation/profile/widgets/settings_cloud_card.dart';

class FakeStore implements SettingsCloudStore {
  final Map<String, Map<String, dynamic>> docs = {};
  bool hang = false; // 통신 없는 현장처럼 답이 안 온다
  int writes = 0;

  @override
  Future<Map<String, dynamic>?> read(String uid) {
    if (hang) return Completer<Map<String, dynamic>?>().future;
    return Future.value(docs[uid]);
  }

  @override
  Future<void> write(String uid, Map<String, Object> settings) {
    writes++;
    if (hang) return Completer<void>().future;
    // Firestore set(merge: true)처럼 칸별로 합친다.
    final old = Map<String, dynamic>.from(docs[uid]?['settings'] ?? {});
    docs[uid] = {
      'settings': {...old, ...settings},
    };
    return Future.value();
  }
}

void main() {
  late FakeStore store;
  final sync = SettingsCloudSync.instance;

  setUp(() {
    store = FakeStore();
    sync.store = store;
    sync.uidProvider = () => 'uid-A';
    sync.lastSynced.value = null;
  });

  test('폰 설정을 모을 때 계산기 설정만, 작업 목록 같은 것은 빼고 모은다', () async {
    SharedPreferences.setMockInitialValues({
      'bendRadius': 38.1,
      'gain': 12.0,
      'isInch': false,
      'conduit_bender_settings_v1': '{"benderType":"hand"}',
      'cutting_blade_kerf': 0.0,
      'cutting_blade_kerf_steel': 3.0,
      'user_real_name': '작업자',
      'mobile_bend_list': '[...]',
    });
    final prefs = await SharedPreferences.getInstance();
    final m = collectLocalSettings(prefs);
    expect(m['bendRadius'], 38.1);
    expect(m['conduit_bender_settings_v1'], '{"benderType":"hand"}');
    // 튜브·형강 톱날 손실을 따로 보관한다.
    expect(m['cutting_blade_kerf'], 0.0);
    expect(m['cutting_blade_kerf_steel'], 3.0);
    expect(m.containsKey('user_real_name'), isFalse);
    expect(m.containsKey('mobile_bend_list'), isFalse);
  });

  test('올렸다가 앱을 새로 깔면(폰이 비면) 그대로 되돌아온다', () async {
    SharedPreferences.setMockInitialValues({
      'bendRadius': 38.1,
      'gain': 12.0,
      'fittingDepth': 23.0,
      'isInch': false,
      'conduit_bender_settings_v1': '{"couplingAllowance":50.0}',
      'cutting_stock_length': 6000.0,
    });
    expect(await sync.backup(), isTrue);
    expect(sync.lastSynced.value, isNotNull);

    // 앱을 지웠다 깐 폰
    SharedPreferences.setMockInitialValues({});
    final n = await sync.restore();
    expect(n, 6);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('bendRadius'), 38.1);
    expect(prefs.getDouble('gain'), 12.0);
    expect(prefs.getDouble('fittingDepth'), 23.0);
    expect(prefs.getBool('isInch'), isFalse);
    expect(
      prefs.getString('conduit_bender_settings_v1'),
      '{"couplingAllowance":50.0}',
    );
    expect(prefs.getDouble('cutting_stock_length'), 6000.0);
  });

  test('서버가 정수(30)로 돌려줘도 double로 쓴다', () async {
    store.docs['uid-A'] = {
      'settings': {'bendRadius': 30, 'gain': 0},
    };
    SharedPreferences.setMockInitialValues({});
    await sync.restore();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('bendRadius'), 30.0);
  });

  test('서버에 설정 문서가 있으면 받을 칸이 0이어도 "없음"으로 보지 않는다(로그인 뒤 옛 값을 올리지 않게, 10-08)', () async {
    store.docs['uid-A'] = {
      'settings': {'bendRadius': 50.0},
    };
    SharedPreferences.setMockInitialValues({'bendRadius': 38.1});
    expect(await sync.restore(), 0);
    expect(sync.lastRestoreServerMissing, isFalse);
    store.docs.remove('uid-A');
    expect(await sync.restore(), 0);
    expect(sync.lastRestoreServerMissing, isTrue);
  });

  test('폰에 있는 칸은 그대로 두고, 없는 칸만 서버 것으로 채운다', () async {
    store.docs['uid-A'] = {
      'settings': {'bendRadius': 50.0, 'gain': 12.0},
    };
    SharedPreferences.setMockInitialValues({'bendRadius': 38.1});
    expect(await sync.restore(), 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('bendRadius'), 38.1);
    expect(prefs.getDouble('gain'), 12.0);
    // 직접 "서버에서 불러오기"를 누르면 폰 값도 바꾼다.
    expect(await sync.restore(overwrite: true), 2);
    expect(prefs.getDouble('bendRadius'), 50.0);
  });

  test('새 폰에서 컷팅만 써 보고 로그인해도 벤딩 제원을 받고, 서버 제원도 안 지워진다', () async {
    // 예전 폰에서 올린 벤딩 제원
    store.docs['uid-A'] = {
      'settings': {'bendRadius': 38.1, 'gain': 12.0, 'fittingDepth': 23.0},
    };
    // 새 폰: 컷팅 톱날 손실만 넣어 봄
    SharedPreferences.setMockInitialValues({'cutting_blade_kerf': 2.0});
    expect(await sync.restore(), 3);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('bendRadius'), 38.1);
    expect(prefs.getDouble('cutting_blade_kerf'), 2.0);

    // 통신이 없어 못 받은 채로 컷팅 설정만 올려도 서버의 벤딩 제원은 남는다.
    SharedPreferences.setMockInitialValues({'cutting_blade_kerf': 3.0});
    await sync.backup();
    final saved = store.docs['uid-A']!['settings'] as Map;
    expect(saved['bendRadius'], 38.1);
    expect(saved['cutting_blade_kerf'], 3.0);
  });

  test('받은 설정을 이미 읽어 둔 설정에도 넣어, 다음 저장 때 옛 값으로 덮이지 않는다', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // 화면 켜 두기(wakelock) 채널은 테스트에 없으므로 "됐다"고만 답한다.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (_) async => const StandardMessageCodec().encodeMessage(<Object?>[]),
        );
    SharedPreferences.setMockInitialValues({});
    final ctrl = AppSettingsController();
    await ctrl.load(); // 앱이 먼저 기본값(0)을 읽어 둠
    expect(ctrl.bendRadius, 0.0);
    await Future<void>.delayed(Duration.zero);
    // 읽기만 했을 때 기본값 0을 폰에 적으면 "이미 있다"며 불러오기를 건너뛴다.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('gain'), isFalse);
    store.docs['uid-A'] = {
      'settings': {'bendRadius': 38.1, 'gain': 12.0},
    };
    expect(await restoreCalculatorSettings(), 2);
    expect(ctrl.bendRadius, 38.1);
    expect(ctrl.gain, 12.0);
  });

  test('로그인하지 않았으면 올리지도 받지도 않는다', () async {
    sync.uidProvider = () => null;
    SharedPreferences.setMockInitialValues({'bendRadius': 38.1});
    expect(await sync.backup(), isFalse);
    expect(await sync.restore(overwrite: true), 0);
    expect(store.writes, 0);
  });

  test('다른 구글 계정의 설정은 섞이지 않는다', () async {
    SharedPreferences.setMockInitialValues({'bendRadius': 38.1});
    await sync.backup();
    sync.uidProvider = () => 'uid-B';
    SharedPreferences.setMockInitialValues({});
    expect(await sync.restore(), 0);
  });

  test('통신이 없으면 오래 멈추지 않고, "보관함"으로 적지도 않는다', () {
    fakeAsyncRun(() async {
      store.hang = true;
      SharedPreferences.setMockInitialValues({'bendRadius': 38.1});
      final ok = await sync.backup();
      expect(ok, isFalse);
      expect(sync.lastSynced.value, isNull);
      SharedPreferences.setMockInitialValues({});
      expect(await sync.restore(), 0);
    });
  });

  testWidgets('프로필 칸: 폭 320에서 넘치지 않고 시각·단추가 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) =>
        errors.add(d.exceptionAsString().split('\n').first);
    try {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsCloudCard())),
      );
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = old;
    }
    expect(errors, isEmpty);
    expect(find.text('아직 올린 적이 없습니다'), findsOneWidget);
    expect(find.byKey(const Key('settings_cloud_upload')), findsOneWidget);
    expect(find.byKey(const Key('settings_cloud_download')), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  group('폰↔태블릿 자동 반영', () {
    var t = 1000;
    setUp(() {
      t = 1000;
      sync.clock = () => t++;
    });
    tearDown(() {
      sync.clock = () => DateTime.now().millisecondsSinceEpoch;
    });

    /// 기기 하나의 저장 내용을 새 기기 것으로 바꿔 끼운다.
    void usePhone(Map<String, Object> v) =>
        SharedPreferences.setMockInitialValues(v);

    Future<Map<String, Object>> snap() async {
      final p = await SharedPreferences.getInstance();
      return {for (final k in p.getKeys()) k: p.get(k)!};
    }

    test('폰에서 고친 설정을 태블릿이 앱을 켤 때 받는다', () async {
      usePhone({'bendRadius': 38.1, 'isInch': false});
      expect(await sync.backup(), isTrue);
      expect(store.docs['uid-A']!['settings']['_writer'], isA<String>());

      usePhone({'bendRadius': 20.0, 'isInch': true});
      expect(await sync.pullIfNewer(), greaterThan(0));
      final p = await SharedPreferences.getInstance();
      expect(p.getDouble('bendRadius'), 38.1);
      expect(p.getBool('isInch'), isFalse);
      // 같은 것을 또 받지 않는다.
      expect(await sync.pullIfNewer(), 0);
    });

    test('내가 올린 것은 다시 받지 않는다', () async {
      usePhone({'bendRadius': 38.1});
      await sync.backup();
      expect(await sync.pullIfNewer(), 0);
    });

    test('태블릿에서 나중에 고치면 폰이 그것을 받는다', () async {
      usePhone({'bendRadius': 38.1});
      await sync.backup();
      final phone = await snap();

      usePhone({'bendRadius': 20.0});
      await sync.pullIfNewer(); // 태블릿: 폰 것을 받는다
      SharedPreferences.setMockInitialValues({
        ...await snap(),
        'bendRadius': 45.0,
      });
      await sync.backup(); // 태블릿에서 고쳐 올린다
      final tablet = await snap();

      usePhone(phone);
      expect(await sync.pullIfNewer(), greaterThan(0));
      expect(
        (await SharedPreferences.getInstance()).getDouble('bendRadius'),
        45.0,
      );
      expect(
        tablet['settings_cloud_device'],
        isNot(phone['settings_cloud_device']),
      );
    });

    test('이 기기에서 고친 것이 아직 못 올라갔으면 서버 것으로 덮지 않고 올린다', () async {
      usePhone({'bendRadius': 38.1});
      await sync.backup();

      usePhone({'bendRadius': 50.0, 'settings_cloud_dirty': true});
      expect(await sync.pullIfNewer(), 0);
      expect(
        (await SharedPreferences.getInstance()).getDouble('bendRadius'),
        50.0,
      );
      expect(store.docs['uid-A']!['settings']['bendRadius'], 50.0);
      expect(
        (await SharedPreferences.getInstance()).getBool('settings_cloud_dirty'),
        isFalse,
      );
    });

    test('올린 기기·시각 표시가 없는 예전 서버 문서는 켤 때 받지 않는다', () async {
      store.docs['uid-A'] = {
        'settings': {'bendRadius': 38.1},
      };
      usePhone({'bendRadius': 20.0});
      expect(await sync.pullIfNewer(), 0);
      expect(
        (await SharedPreferences.getInstance()).getDouble('bendRadius'),
        20.0,
      );
    });

    test('구글 계정이 없거나 통신이 없으면 아무것도 바꾸지 않는다', () async {
      usePhone({'bendRadius': 20.0});
      sync.uidProvider = () => null;
      expect(await sync.pullIfNewer(), 0);
      sync.uidProvider = () => 'uid-A';
      store.hang = true;
      // 서버가 답이 없으면 5초 뒤 포기한다.
      expect(await sync.pullIfNewer().timeout(const Duration(seconds: 12)), 0);
      expect(
        (await SharedPreferences.getInstance()).getDouble('bendRadius'),
        20.0,
      );
    });

    test('다른 칸을 저장해도 다른 기기가 먼저 고친 게인을 옛 값으로 덮지 않는다(고친 칸만 올린다)', () async {
      // 폰·태블릿 모두 gain 12, kerf 2로 맞춰 둔 상태
      usePhone({'gain': 12.0, 'cutting_blade_kerf': 2.0});
      await sync.backup();
      final phone0 = await snap();
      usePhone({'gain': 12.0, 'cutting_blade_kerf': 2.0});
      await sync.pullIfNewer();
      final tablet0 = await snap();

      // 폰에서 게인을 고쳐 올린다.
      SharedPreferences.setMockInitialValues({...phone0, 'gain': 15.0});
      await sync.backup();
      final phone1 = await snap();

      // 태블릿은 아직 옛 게인(12)인 채로 톱날 손실만 고쳐 저장한다.
      SharedPreferences.setMockInitialValues({...tablet0, 'cutting_blade_kerf': 3.0});
      await sync.backup();
      final saved = store.docs['uid-A']!['settings'] as Map;
      expect(saved['gain'], 15.0); // 폰이 고친 게인이 그대로
      expect(saved['cutting_blade_kerf'], 3.0);

      // 폰이 다시 받아도 게인은 15, 톱날 손실은 3
      usePhone(phone1);
      await sync.pullIfNewer();
      final p = await SharedPreferences.getInstance();
      expect(p.getDouble('gain'), 15.0);
      expect(p.getDouble('cutting_blade_kerf'), 3.0);
    });

    test('설정 화면의 올리기 단추(all)는 전부 올린다', () async {
      usePhone({'gain': 12.0, 'bendRadius': 38.1});
      await sync.backup();
      store.docs['uid-A']!['settings'].remove('bendRadius');
      SharedPreferences.setMockInitialValues({...await snap()});
      await sync.backup(); // 바뀐 칸이 없어 올리지 않는다
      expect((store.docs['uid-A']!['settings'] as Map).containsKey('bendRadius'), isFalse);
      await sync.backup(all: true);
      expect(store.docs['uid-A']!['settings']['bendRadius'], 38.1);
    });

    test('화면 구성(폰·태블릿)은 기기마다 다르게 둔다: 올리는 칸에 없다', () {
      expect(kCloudSettingKeys.any((k) => k.contains('screen')), isFalse);
      expect(kCloudSettingKeys.any((k) => k.contains('layout')), isFalse);
    });
  });

  testWidgets('구글 계정이 안 이어져 있으면 연결 단추만 보인다', (tester) async {
    sync.uidProvider = () => null;
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsCloudCard(onLinkGoogle: () async => true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings_cloud_link')), findsOneWidget);
    expect(find.byKey(const Key('settings_cloud_upload')), findsNothing);
  });
}

/// 5초 기다림을 실제로 기다리지 않게 시간을 앞당겨 돌린다.
void fakeAsyncRun(Future<void> Function() body) {
  // flutter_test의 FakeAsync를 쓰지 않고, 짧게 끝나는지만 본다.
  final done = body().timeout(const Duration(seconds: 12));
  expectLater(done, completes);
}
