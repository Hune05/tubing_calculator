// 계산기 설정을 구글 계정 기준으로 서버(Firestore)에 올리고 불러온다.
//
// 설정은 늘 폰(SharedPreferences)에 먼저 저장한다. 서버는 앱을 지웠다 깔거나
// 폰을 바꿨을 때 되살리는 용도다. 통신이 없는 현장에서도 멈추지 않게, 올리기는
// 기다리지 않고(서버가 통신될 때 알아서 보낸다) 불러오기는 짧게만 기다린다.
import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 서버 설정 문서(settings 칸)에 같이 적는 "누가 언제 올렸나" 표시. 설정 칸이 아니라 받을 때 폰 설정에 쓰지 않는다.
/// 2026-09-27: 폰에서 고친 설정이 태블릿에 자동으로 반영되게(같은 구글 계정을 쓰는 다른 기기가 올린 것이 더 새로우면 받는다).
const String kCloudWriterKey = '_writer';
const String kCloudEditedAtKey = '_editedAt';

/// 서버에 올리는 폰 설정 칸(SharedPreferences 키).
/// 튜브 벤딩 · 전선관 · 튜브 컷팅 · 근태 설정만. 작업 목록·기록은 넣지 않는다.
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
  // 벤딩 실측 기록 허용 범위(± mm, 10-13)
  'bend_check_tolerance',
  // 근태 설정(입사일·기본 휴게·토요일 휴일·연차 부여 일수·소정 시각·사규 메모). 보기 방식은 기기마다.
  'attendance_hire_date', 'attendance_default_break',
  'attendance_saturday_holiday', 'attendance_leave_override',
  'attendance_work_start', 'attendance_work_end', 'attendance_rule_note',
  'attendance_clockout_reminder',
];

/// 비어 있는 값으로는 서버 값을 덮지도, 폰 값을 덮지도 않는 칸(근태 설정의 글 칸).
/// 새로 깐 기기에서 근태 설정을 처음 저장하면 이 칸들이 빈 글자인데, 그것이 서버로 올라가
/// 다른 기기의 입사일·소정 시각을 지우면 안 되기 때문이다. 대신 한 기기에서 비운 값은 다른 기기에 전해지지 않는다.
const Set<String> kCloudBlankGuardKeys = {
  'attendance_hire_date',
  'attendance_work_start',
  'attendance_work_end',
  'attendance_rule_note',
};

/// 폰에는 JSON 글 하나로 두지만 서버에는 묶음(map)으로 올리는 칸. 안의 항목(설정 칸·규격)별로 합쳐진다.
/// 10-13: 글 한 칸이라 통째로 오가, 폰에서 시험 벤딩으로 잡은 EMT 22 게인을 태블릿이 다른 규격을 저장하며
/// 옛 값으로 덮었다. Firestore set(merge: true)는 묶음 안쪽도 칸별로 합치므로, 바뀐 항목만 올리면 다른 기기 값이 남는다.
/// 지운 항목은 서버로 퍼뜨리지 않는다(드물고, 다른 기기 값을 지울 위험이 더 크다).
const Set<String> kCloudJsonMapKeys = {
  'conduit_bender_settings_v1',
  'conduit_spec_sets_v1',
  'machine_spec_sets_v1',
};

/// 글(JSON)이나 묶음을 묶음으로 읽는다. 못 읽으면 null.
Map<String, Object?>? cloudJsonMap(Object? v) {
  if (v is Map) return Map<String, Object?>.from(v);
  if (v is String && v.isNotEmpty) {
    try {
      final m = jsonDecode(v);
      if (m is Map) return Map<String, Object?>.from(m);
    } catch (_) {}
  }
  return null;
}

/// 비교용 글: 묶음 안 순서와 30/30.0 차이를 없앤다.
String _canon(Object? v) {
  Object? norm(Object? x) {
    if (x is Map) {
      final keys = x.keys.map((e) => '$e').toList()..sort();
      return {for (final k in keys) k: norm(x[k])};
    }
    if (x is List) return [for (final e in x) norm(e)];
    if (x is num) return x.toDouble();
    return x;
  }

  return jsonEncode(norm(v));
}

/// 정수로 읽는 칸(서버가 30을 30.0으로 돌려줘도 정수로 쓴다). 나머지 숫자 칸은 소수(double).
const Set<String> kCloudIntKeys = {'attendance_default_break'};

/// 폰에 저장된 설정을 서버에 올릴 모양으로 모은다. 없는 칸은 뺀다.
Map<String, Object> collectLocalSettings(SharedPreferences prefs) {
  final out = <String, Object>{};
  for (final k in kCloudSettingKeys) {
    final v = prefs.get(k);
    // 빈 글자는 올리지 않는다(kCloudBlankGuardKeys).
    if (v is String && v.isEmpty && kCloudBlankGuardKeys.contains(k)) continue;
    if (v is bool || v is int || v is double || v is String) out[k] = v!;
  }
  return out;
}

/// 같은 값인지 비교할 모양으로 맞춘다(서버는 30.0을 30으로 돌려줄 수 있다).
Object? _normCloudValue(String k, Object? v) {
  if (kCloudJsonMapKeys.contains(k)) {
    final m = cloudJsonMap(v);
    return m == null ? v : _canon(m);
  }
  if (v is num) return kCloudIntKeys.contains(k) ? v.toInt() : v.toDouble();
  return v;
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
    var v = data[k];
    // 서버에 묶음으로 올라간 칸은 폰에는 예전처럼 JSON 글로 둔다(10-13).
    if (v is Map && kCloudJsonMapKeys.contains(k)) v = jsonEncode(v);
    // 서버의 빈 글자로 폰에 있는 값을 지우지 않는다(kCloudBlankGuardKeys).
    if (v is String && v.isEmpty && kCloudBlankGuardKeys.contains(k)) continue;
    if (v is bool) {
      await prefs.setBool(k, v);
    } else if (v is String) {
      await prefs.setString(k, v);
    } else if (v is num) {
      if (kCloudIntKeys.contains(k)) {
        await prefs.setInt(k, v.toInt());
      } else {
        // 서버는 30.0을 30(정수)로 돌려줄 수 있다. 앱은 double로 읽으므로 맞춘다.
        await prefs.setDouble(k, v.toDouble());
      }
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
      // 구글 계정만(익명 로그인은 앱을 다시 깔면 잃는 이름표라 "서버 보관"이 아니다, 10-07).
      final u = FirebaseAuth.instance.currentUser;
      return u == null || u.isAnonymous ? null : u.uid;
    } catch (_) {
      return null; // Firebase가 안 켜진 곳(테스트 등)
    }
  };

  /// 마지막으로 서버에 올리거나 받은 시각(설정 화면에 보여 준다).
  final ValueNotifier<DateTime?> lastSynced = ValueNotifier(null);

  static const String _lastSyncedKey = 'settings_cloud_synced_at';

  /// 이 기기를 가리는 이름표(처음 한 번 만든다). 서버 문서에 "마지막으로 올린 기기"로 적는다.
  static const String _deviceKey = 'settings_cloud_device';

  /// 폰에서 고쳤는데 아직 서버에 못 올린 설정이 있다(통신 없음). 있으면 서버 것으로 덮지 않는다.
  static const String _dirtyKey = 'settings_cloud_dirty';

  /// 마지막으로 올리거나 받은 서버 설정의 "올린 시각(ms)". 이보다 새로운 것이 서버에 있으면 받는다.
  static const String _seenKey = 'settings_cloud_seen_at';

  /// 이 기기가 아는 "서버에 있는 설정 값"(마지막으로 올렸거나 받은 값). 올릴 때는 이것과 다른 칸만 올린다.
  /// 10-07: 예전에는 설정 하나만 바꿔도 이 기기의 설정 전체를 올려, 다른 기기에서 먼저 고친
  /// 게인·반경이 이 기기의 옛 값으로 덮였다가 다시 내려왔다(마킹 값이 틀어짐).
  static const String _baseKey = 'settings_cloud_base_v1';

  Map<String, Object?>? _readBase(SharedPreferences prefs) {
    final raw = prefs.getString(_baseKey);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw);
      return m is Map ? Map<String, Object?>.from(m) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeBase(SharedPreferences prefs, Map<String, Object?> base) =>
      prefs.setString(_baseKey, jsonEncode(base));

  /// 서버에 묶음(map)으로 올라가 있다고 아는 칸. 아니면(예전 글이거나 모르면) 처음 한 번은 전부 올린다
  /// — 글로 된 칸에 일부만 묶음으로 쓰면 나머지 항목이 사라지므로.
  static const String _mapFormKey = 'settings_cloud_map_form_v1';

  Set<String> _mapForm(SharedPreferences prefs) =>
      (prefs.getStringList(_mapFormKey) ?? const []).toSet();

  Future<void> _setMapForm(SharedPreferences prefs, Set<String> keys) =>
      prefs.setStringList(_mapFormKey, keys.toList()..sort());

  /// 서버 문서에서 칸이 묶음인지 글인지 보고 기억한다.
  Future<void> _noteServerForm(SharedPreferences prefs, Map settings) async {
    final form = _mapForm(prefs);
    for (final k in kCloudJsonMapKeys) {
      if (!settings.containsKey(k)) continue;
      if (settings[k] is Map) {
        form.add(k);
      } else {
        form.remove(k);
      }
    }
    await _setMapForm(prefs, form);
  }

  /// 서버 문서의 설정 칸을 "서버에 있는 값"으로 기억한다(앞서 기억한 칸 위에 덮는다).
  Future<void> _rememberServer(SharedPreferences prefs, Map settings) async {
    final base = _readBase(prefs) ?? <String, Object?>{};
    for (final k in kCloudSettingKeys) {
      if (settings.containsKey(k)) base[k] = _normCloudValue(k, settings[k]);
    }
    await _writeBase(prefs, base);
  }

  /// 시각을 바꿔 끼운다(테스트).
  int Function() clock = () => DateTime.now().millisecondsSinceEpoch;

  Future<String> _deviceId(SharedPreferences prefs) async {
    var id = prefs.getString(_deviceKey);
    if (id == null || id.isEmpty) {
      id =
          'd${clock().toRadixString(36)}${Random().nextInt(1 << 30).toRadixString(36)}';
      await prefs.setString(_deviceKey, id);
    }
    return id;
  }

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
  ///
  /// 서버에 있다고 아는 값과 **다른 칸만** 올린다(다른 기기가 고친 칸을 이 기기의 옛 값으로 덮지 않게).
  /// 서버 값을 아직 모르는 기기(처음 쓰는 기기)와 [all](설정 화면의 "올리기" 단추)은 전부 올린다.
  Future<bool> backup({bool all = false}) async {
    final uid = uidProvider();
    if (uid == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final local = collectLocalSettings(prefs);
      if (local.isEmpty) return false;
      final base = all ? null : _readBase(prefs);
      final data = base == null
          ? local
          : {
              for (final e in local.entries)
                if (base[e.key] != _normCloudValue(e.key, e.value))
                  e.key: e.value,
            };
      if (data.isEmpty) {
        // 서버와 같다: 올릴 것이 없다.
        await prefs.setBool(_dirtyKey, false);
        return true;
      }
      // 묶음 칸: 서버가 이미 묶음이면 이 기기가 바꾼 항목만, 아니면 전부를 묶음으로(10-13).
      final form = _mapForm(prefs);
      final upload = <String, Object>{};
      for (final e in data.entries) {
        if (!kCloudJsonMapKeys.contains(e.key)) {
          upload[e.key] = e.value;
          continue;
        }
        final local = cloudJsonMap(e.value);
        if (local == null) {
          upload[e.key] = e.value;
          continue;
        }
        final known = base == null ? null : cloudJsonMap(base[e.key]);
        if (known == null || !form.contains(e.key)) {
          upload[e.key] = local;
          continue;
        }
        final changed = <String, Object?>{
          for (final s in local.entries)
            if (!known.containsKey(s.key) ||
                _canon(known[s.key]) != _canon(s.value))
              s.key: s.value,
        };
        if (changed.isNotEmpty) upload[e.key] = changed;
      }
      // 누가 언제 올렸는지 같이 적는다(다른 기기가 새것인지 가리는 데 쓴다).
      final editedAt = clock();
      final device = await _deviceId(prefs);
      await prefs.setBool(_dirtyKey, true);
      await prefs.setInt(_seenKey, editedAt);
      final withMeta = <String, Object>{
        ...upload,
        kCloudWriterKey: device,
        kCloudEditedAtKey: editedAt,
      };
      // 통신이 없으면 응답이 늦게 온다. 폰 쪽 대기열에는 이미 들어갔으므로
      // 오래 기다리지 않는다. 서버가 받았다고 답했을 때만 "보관함"으로 적는다.
      bool done = false;
      await store
          .write(uid, withMeta)
          .then((_) => done = true)
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      if (done) {
        await prefs.setBool(_dirtyKey, false);
        await _rememberServer(prefs, data);
        // 묶음으로 올린 칸은 이제 서버가 묶음이다(다음부터 바뀐 항목만).
        await _setMapForm(prefs, {
          ...form,
          for (final k in upload.keys)
            if (kCloudJsonMapKeys.contains(k) && upload[k] is Map) k,
        });
        await _markSynced(prefs);
      }
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
  /// 마지막 [restore]에서 서버를 읽었는데 설정 문서가 없었는지(못 읽었으면 false).
  /// 로그인 직후 "서버에 없을 때만" 이 기기 설정을 올리는 데 쓴다(10-08: 받을 칸이 0이기만 하면 올려,
  /// 이 기기의 옛 게인·반경이 다른 기기에서 고친 새 값을 덮었다).
  bool lastRestoreServerMissing = false;

  Future<int> restore({bool overwrite = false}) async {
    lastRestoreServerMissing = false;
    final uid = uidProvider();
    if (uid == null) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      var timedOut = false;
      final doc = await store
          .read(uid)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              timedOut = true;
              return null;
            },
          );
      final settings = doc?['settings'];
      if (settings is! Map) {
        lastRestoreServerMissing = !timedOut;
        return 0;
      }
      // 폰에 이미 있어 그대로 둔 칸(onlyMissing)은 받기 전에 적어 둔다.
      final kept = <String, Object?>{
        if (!overwrite)
          for (final k in kCloudSettingKeys)
            if (prefs.containsKey(k) && settings.containsKey(k))
              k: _normCloudValue(k, prefs.get(k)),
      };
      final n = await applyCloudSettings(
        prefs,
        Map<String, dynamic>.from(settings),
        onlyMissing: !overwrite,
      );
      await _rememberServer(prefs, settings);
      await _noteServerForm(prefs, settings);
      // 그대로 둔 칸은 "서버에 있는 값"을 폰 값으로 적어, 다음 저장 때 이 기기의 옛 값이 서버를
      // 덮지 않게 한다(10-09: 서버 값을 적어 두어 다른 칸만 저장해도 옛 게인·반경이 올라갔다).
      // 서버 값과 다르면 다음 자동 받기(pullIfNewer)가 서버 값으로 맞춘다(10-08 뜻: 서버가 먼저).
      if (kept.isNotEmpty) {
        final base = _readBase(prefs) ?? <String, Object?>{};
        base.addAll(kept);
        await _writeBase(prefs, base);
      }
      // 서버 문서의 올린 시각까지 봤다고 적는다(뒤이은 자동 받기가 방금 받은 것을 또 받지 않게).
      final at = settings[kCloudEditedAtKey];
      if (at is num) await prefs.setInt(_seenKey, at.toInt());
      if (n > 0) await _markSynced(prefs);
      return n;
    } catch (e) {
      debugPrint('설정 서버 불러오기 실패: $e');
      return 0;
    }
  }

  /// 앱을 켜거나 다시 볼 때 부른다. **다른 기기가 올린 설정이 더 새로우면** 서버 값으로 바꿔 받는다
  /// (폰에서 고친 벤딩 제원이 태블릿에도 반영된다). 받은 칸 수를 돌려준다(못 받았으면 0).
  ///
  /// - 이 기기에서 고쳤는데 아직 못 올린 설정이 있으면(통신 없음) 서버 것으로 덮지 않고 그 설정을 올린다.
  /// - 이 기기가 아는 서버 값(base)이 있으면 그것과 달라진 칸만 받는다(다른 기기가 고친 칸, 10-09).
  /// - base가 없을 때(처음)만: 서버에 "올린 기기·시각" 표시가 없는 예전 문서는 받지 않고,
  ///   이 기기가 마지막으로 올린 것이면 받지 않는다.
  Future<int> pullIfNewer() async {
    final uid = uidProvider();
    if (uid == null) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_dirtyKey) ?? false) {
        await backup();
        return 0;
      }
      final doc = await store
          .read(uid)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      final settings = doc?['settings'];
      if (settings is! Map) return 0;
      final base = _readBase(prefs);
      if (base != null) {
        // 이 기기가 아는 서버 값(base)과 달라진 칸만 받는다(다른 기기가 고친 칸).
        // 10-09: 예전에는 "마지막으로 올린 기기가 나"면 받지 않아, 다른 기기가 먼저 고친 게인을
        // 받기 전에 이 기기가 다른 칸을 올리면 그 게인을 영영 못 받았다. 기기마다 시계가 달라
        // 올린 시각 비교가 어긋나는 일도 없어진다.
        final changed = <String, dynamic>{
          for (final k in kCloudSettingKeys)
            if (settings.containsKey(k) &&
                _normCloudValue(k, settings[k]) != base[k])
              k: settings[k],
        };
        // 묶음 칸(10-13): 서버 묶음에서 이 기기가 아는 값과 달라진 항목만 이 기기 값에 덮는다
        // (이 기기에만 있는 항목·이 기기에서 고친 다른 항목은 그대로).
        for (final k in kCloudJsonMapKeys) {
          if (!changed.containsKey(k)) continue;
          final server = cloudJsonMap(changed[k]);
          final known = cloudJsonMap(base[k]);
          final local = cloudJsonMap(prefs.get(k));
          if (server == null || known == null || local == null) continue;
          final merged = {...local};
          for (final e in server.entries) {
            if (!known.containsKey(e.key) ||
                _canon(known[e.key]) != _canon(e.value)) {
              merged[e.key] = e.value;
            }
          }
          changed[k] = jsonEncode(merged);
        }
        final n = changed.isEmpty
            ? 0
            : await applyCloudSettings(prefs, changed);
        await _rememberServer(prefs, settings);
        await _noteServerForm(prefs, settings);
        final at = settings[kCloudEditedAtKey];
        if (at is num) await prefs.setInt(_seenKey, at.toInt());
        if (n > 0) await _markSynced(prefs);
        return n;
      }
      // 서버 값을 처음 알게 되면 기억해 둔다(앱을 고친 뒤 처음 켤 때: 이후 고친 칸만 올라간다).
      await _rememberServer(prefs, settings);
      await _noteServerForm(prefs, settings);
      final writer = settings[kCloudWriterKey];
      final at = settings[kCloudEditedAtKey];
      if (writer is! String || at is! num) return 0;
      final me = await _deviceId(prefs);
      if (writer == me) return 0;
      final seen = prefs.getInt(_seenKey) ?? 0;
      if (at.toInt() <= seen) return 0;
      final n = await applyCloudSettings(
        prefs,
        Map<String, dynamic>.from(settings),
      );
      await _rememberServer(prefs, settings);
      // 받을 칸이 하나도 없어도 "이 시각까지 봤다"고 적는다(같은 문서를 되풀이해 읽지 않게).
      await prefs.setInt(_seenKey, at.toInt());
      if (n > 0) await _markSynced(prefs);
      return n;
    } catch (e) {
      debugPrint('설정 서버 새 값 받기 실패: $e');
      return 0;
    }
  }
}
