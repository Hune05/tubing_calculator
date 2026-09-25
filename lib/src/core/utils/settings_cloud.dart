// 계산기 설정을 구글 계정 기준으로 서버(Firestore)에 올리고 불러온다.
//
// 설정은 늘 폰(SharedPreferences)에 먼저 저장한다. 서버는 앱을 지웠다 깔거나
// 폰을 바꿨을 때 되살리는 용도다. 통신이 없는 현장에서도 멈추지 않게, 올리기는
// 기다리지 않고(서버가 통신될 때 알아서 보낸다) 불러오기는 짧게만 기다린다.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 서버에 올리는 폰 설정 칸(SharedPreferences 키).
/// 튜브 벤딩 · 전선관 · 튜브 컷팅 설정만. 작업 목록·기록은 넣지 않는다.
const List<String> kCloudSettingKeys = [
  // 튜브 벤딩 (SettingsManager.saveSettings)
  'isInch', 'useHaptic', 'saveHistory', 'tubeMaterial', 'benderBrand',
  'measurementMode', 'defaultRotation', 'fittingType', 'benderMark',
  'tubeOD', 'tubeWT', 'bendRadius', 'takeUp', 'springback', 'gain',
  'minStraight', 'benderOffset', 'fittingDepth', 'markThickness',
  'offsetShrink', 'cutMargin', 'auto_radius', 'auto_takeUp', 'auto_gain',
  'auto_minStraight', 'auto_offset', 'auto_fittingDepth', 'benderType',
  'keepScreenOn', 'warnShoeInterference',
  // 튜브 마킹 탭 피팅·꼬리
  'start_fit', 'end_fit', 'tail_length',
  // 전선관 (JSON 한 덩어리)
  'conduit_bender_settings_v1',
  // 규격별로 기억해 둔 제원(튜브·전선관, JSON 한 덩어리씩)
  'machine_spec_sets_v1', 'conduit_spec_sets_v1',
  // 튜브 컷팅
  'cutting_blade_kerf', 'cutting_stock_length',
  // 형강 컷팅(톱날 손실을 튜브와 따로)
  'cutting_blade_kerf_steel',
];

/// 폰에 저장된 설정을 서버에 올릴 모양으로 모은다. 없는 칸은 뺀다.
Map<String, Object> collectLocalSettings(SharedPreferences prefs) {
  final out = <String, Object>{};
  for (final k in kCloudSettingKeys) {
    final v = prefs.get(k);
    if (v is bool || v is int || v is double || v is String) out[k] = v!;
  }
  return out;
}

/// 서버에서 받은 설정을 폰에 쓴다. 모르는 칸·모양이 다른 값은 건너뛴다.
/// [onlyMissing]이면 폰에 없는 칸만 채운다(폰에서 고친 값이 먼저).
/// 쓴 칸 수를 돌려준다.
Future<int> applyCloudSettings(
  SharedPreferences prefs,
  Map<String, dynamic> data, {
  bool onlyMissing = false,
}) async {
  int n = 0;
  for (final k in kCloudSettingKeys) {
    if (onlyMissing && prefs.containsKey(k)) continue;
    final v = data[k];
    if (v is bool) {
      await prefs.setBool(k, v);
    } else if (v is String) {
      await prefs.setString(k, v);
    } else if (v is num) {
      // 서버는 30.0을 30(정수)로 돌려줄 수 있다. 앱은 double로 읽으므로 맞춘다.
      await prefs.setDouble(k, v.toDouble());
    } else {
      continue;
    }
    n++;
  }
  return n;
}

/// 서버 쪽 저장소. 테스트에서는 가짜로 바꿔 끼운다.
abstract class SettingsCloudStore {
  Future<Map<String, dynamic>?> read(String uid);
  Future<void> write(String uid, Map<String, Object> settings);
}

/// Firestore `user_settings/{구글 계정 uid}` 문서 하나.
class FirestoreSettingsStore implements SettingsCloudStore {
  static const String collection = 'user_settings';

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection(collection).doc(uid);

  @override
  Future<Map<String, dynamic>?> read(String uid) async {
    final snap = await _doc(uid).get();
    return snap.data();
  }

  /// 칸별로 합쳐 쓴다. 이 폰에 없는 칸(다른 폰에서 올린 벤딩 제원 등)은 서버에 그대로 남는다.
  @override
  Future<void> write(String uid, Map<String, Object> settings) => _doc(uid).set(
    {'settings': settings, 'updatedAt': FieldValue.serverTimestamp()},
    SetOptions(merge: true),
  );
}

/// 설정 올리기·불러오기. 로그인(구글)하지 않았으면 아무것도 하지 않는다.
class SettingsCloudSync {
  SettingsCloudSync._();
  static final SettingsCloudSync instance = SettingsCloudSync._();

  SettingsCloudStore store = FirestoreSettingsStore();

  /// 지금 로그인한 구글 계정. 테스트에서 바꿔 끼운다.
  String? Function() uidProvider = () {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null; // Firebase가 안 켜진 곳(테스트 등)
    }
  };

  /// 마지막으로 서버에 올리거나 받은 시각(설정 화면에 보여 준다).
  final ValueNotifier<DateTime?> lastSynced = ValueNotifier(null);

  static const String _lastSyncedKey = 'settings_cloud_synced_at';

  bool get signedIn => uidProvider() != null;

  Future<void> loadLastSynced() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastSyncedKey);
    lastSynced.value = ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _markSynced(SharedPreferences prefs) async {
    final now = DateTime.now();
    await prefs.setInt(_lastSyncedKey, now.millisecondsSinceEpoch);
    lastSynced.value = now;
  }

  /// 폰 설정을 서버에 올린다. 설정 저장 뒤에 부른다(기다리지 않아도 된다).
  /// 통신이 없으면 Firestore가 들고 있다가 통신될 때 보낸다.
  Future<bool> backup() async {
    final uid = uidProvider();
    if (uid == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = collectLocalSettings(prefs);
      if (data.isEmpty) return false;
      // 통신이 없으면 응답이 늦게 온다. 폰 쪽 대기열에는 이미 들어갔으므로
      // 오래 기다리지 않는다. 서버가 받았다고 답했을 때만 "보관함"으로 적는다.
      bool done = false;
      await store
          .write(uid, data)
          .then((_) => done = true)
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      if (done) await _markSynced(prefs);
      return done;
    } catch (e) {
      debugPrint('설정 서버 저장 실패: $e');
      return false;
    }
  }

  /// 서버 설정을 폰에 받는다. 기본은 폰에 없는 칸만 채운다(새로 깔았거나,
  /// 새 폰에서 컷팅만 써 본 뒤 로그인해도 벤딩 제원을 받는다). [overwrite]이면
  /// 폰 값도 서버 값으로 바꾼다("서버에서 불러오기" 단추). 받은 칸 수, 못 받았으면 0.
  ///
  /// 이미 화면에 읽어 둔 설정은 그대로이므로, 1 이상이면 부른 쪽에서 다시 읽게 한다
  /// (안 그러면 다음 저장 때 옛 값으로 덮인다).
  Future<int> restore({bool overwrite = false}) async {
    final uid = uidProvider();
    if (uid == null) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final doc = await store
          .read(uid)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      final settings = doc?['settings'];
      if (settings is! Map) return 0;
      final n = await applyCloudSettings(
        prefs,
        Map<String, dynamic>.from(settings),
        onlyMissing: !overwrite,
      );
      if (n > 0) await _markSynced(prefs);
      return n;
    } catch (e) {
      debugPrint('설정 서버 불러오기 실패: $e');
      return 0;
    }
  }
}
