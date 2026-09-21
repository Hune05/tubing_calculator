// 계산기 설정 서버 보관: 폰 설정을 모으고, 가짜 서버에 올렸다가 새로 깐 폰에
// 되돌리는지 본다(진짜 서버는 쓰지 않는다).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    docs[uid] = {'settings': Map<String, dynamic>.from(settings)};
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
      'cutting_blade_kerf': 3.0,
      'user_real_name': '작업자',
      'mobile_bend_list': '[...]',
    });
    final prefs = await SharedPreferences.getInstance();
    final m = collectLocalSettings(prefs);
    expect(m['bendRadius'], 38.1);
    expect(m['conduit_bender_settings_v1'], '{"benderType":"hand"}');
    expect(m['cutting_blade_kerf'], 3.0);
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

  test('폰에 이미 설정이 있으면 자동 불러오기는 덮어쓰지 않는다', () async {
    store.docs['uid-A'] = {
      'settings': {'bendRadius': 50.0},
    };
    SharedPreferences.setMockInitialValues({'bendRadius': 38.1});
    expect(await sync.restore(), 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('bendRadius'), 38.1);
    // 직접 "서버에서 불러오기"를 누르면 바꾼다.
    expect(await sync.restore(onlyIfEmpty: false), 1);
    expect(prefs.getDouble('bendRadius'), 50.0);
  });

  test('로그인하지 않았으면 올리지도 받지도 않는다', () async {
    sync.uidProvider = () => null;
    SharedPreferences.setMockInitialValues({'bendRadius': 38.1});
    expect(await sync.backup(), isFalse);
    expect(await sync.restore(onlyIfEmpty: false), 0);
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
