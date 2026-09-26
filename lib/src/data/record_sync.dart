// 폰에 저장하는 기록(교정 기록·압력시험 기록)을 서버(Firestore)에도 올리고, 같은 이름으로 쓰는
// 다른 폰에서 올린 기록을 받아 합친다(2026-09-26).
//
// - 폰 저장(SharedPreferences)이 먼저다. 화면은 늘 폰 저장을 읽는다(통신 없어도 빠르게 열린다).
// - 저장·지우기 뒤에 서버에 올린다. 기다리지 않는다(통신이 없으면 Firestore가 폰에 쌓았다가
//   통신되면 올린다). 실패해도 폰 저장은 그대로다.
// - 서버 문서: 모음 [RecordSync.collection], 문서 이름 = 기록 id.
//   칸 = 기록 JSON + owner(앱 사용자 이름) + ownerUid + editedAt(저장한 폰 시각, ms)
//   + updatedAt(서버 시각) + deleted(지운 기록 표시).
// - 지우기는 문서를 지우지 않고 기록 내용을 뺀 "지움 표시"(deleted: true)만 남긴다. 그래야 다른 폰이
//   목록을 열 때 그 기록을 지운다(문서를 아예 지우면 "안 올린 기록"과 구별이 안 된다).
// - 합치기: 같은 id면 editedAt이 큰 쪽(나중에 고친 쪽)이 이긴다. 같으면 폰 것을 둔다.
//   editedAt이 없는 문서는 updatedAt(서버 시각)으로 본다.
// - 처음 한 번: 예전에 폰에만 저장한 기록을 모두 올리고, 다 올라가면 폰에 표시해 둔다.
//
// 서버 규칙(firestore.rules)은 고치지 않았다. 이 두 모음은 ownedColls·specialColls에 없으므로
// "로그인한 사람이면 읽고 쓴다" 칸에 든다(docs/4-20mA계산기_근거.md·docs/압력시험계산기_근거.md).
library;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 서버에서 받은 기록 한 건.
class RemoteRecord {
  final String id;

  /// 기록 JSON(owner·editedAt 같은 서버 칸은 뺀 것). 지움 표시면 비어 있을 수 있다.
  final Map<String, dynamic> data;

  /// 저장한 폰의 시각(ms). 합치기에 쓴다.
  final int editedAt;
  final bool deleted;
  const RemoteRecord({
    required this.id,
    required this.data,
    required this.editedAt,
    this.deleted = false,
  });
}

/// 서버에서 받은 목록. [fromServer]가 false면 Firestore가 폰에 쌓아 둔 것(통신 없음)이다.
class RemoteFetch {
  final List<RemoteRecord> docs;
  final bool fromServer;
  const RemoteFetch(this.docs, {this.fromServer = true});
}

/// 서버 쪽. 앱은 Firestore, 테스트는 가짜를 끼운다.
abstract class RecordRemote {
  /// 문서 하나를 통째로 쓴다(서버 시각 updatedAt은 여기서 붙인다).
  Future<void> write(String collection, String id, Map<String, dynamic> fields);

  /// 이 사람(owner = 이름)의 문서를 모두 읽는다.
  Future<RemoteFetch> fetch(String collection, String owner);
}

class FirestoreRecordRemote implements RecordRemote {
  const FirestoreRecordRemote();

  @override
  Future<void> write(
    String collection,
    String id,
    Map<String, dynamic> fields,
  ) => FirebaseFirestore.instance.collection(collection).doc(id).set({
    ...fields,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<RemoteFetch> fetch(String collection, String owner) async {
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .where('owner', isEqualTo: owner)
        .get();
    return RemoteFetch([
      for (final d in snap.docs) recordFromServerDoc(d.id, d.data()),
    ], fromServer: !snap.metadata.isFromCache);
  }
}

/// 서버 문서 → [RemoteRecord]. 서버 칸(owner·ownerUid·editedAt·updatedAt·deleted)은 기록 JSON에서 뺀다.
RemoteRecord recordFromServerDoc(String id, Map<String, dynamic> raw) {
  final data = Map<String, dynamic>.of(raw);
  final edited = data.remove('editedAt');
  final updated = data.remove('updatedAt');
  final deleted = data.remove('deleted') == true;
  data.remove('owner');
  data.remove('ownerUid');
  data['id'] = id;
  var at = edited is num ? edited.toInt() : 0;
  if (at <= 0 && updated is Timestamp) at = updated.millisecondsSinceEpoch;
  return RemoteRecord(id: id, data: data, editedAt: at, deleted: deleted);
}

/// 기록 주인: 앱 사용자 이름(users/{이름}와 같은 이름)과 로그인 uid.
class RecordOwner {
  final String name;
  final String? uid;
  const RecordOwner(this.name, [this.uid]);
}

RecordRemote? _defaultRemote() {
  try {
    return Firebase.apps.isEmpty ? null : const FirestoreRecordRemote();
  } catch (_) {
    return null;
  }
}

Future<RecordOwner?> _defaultOwner() async {
  String? uid;
  try {
    uid = FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {
    uid = null;
  }
  if (uid == null || uid.isEmpty) return null; // 로그인 안 함: 서버 규칙이 막는다
  final p = await SharedPreferences.getInstance();
  final name = (p.getString('user_real_name') ?? '').trim();
  if (name.isEmpty || name == '로그인 필요') return null;
  return RecordOwner(name, uid);
}

/// 서버 쪽을 고른다. Firebase가 준비되지 않았으면 null(폰에만 저장). 테스트에서 바꿔 끼운다.
RecordRemote? Function() recordRemote = _defaultRemote;

/// 기록 주인을 읽는다. 이름이 없거나 로그인하지 않았으면 null(폰에만 저장). 테스트에서 바꿔 끼운다.
Future<RecordOwner?> Function() recordOwner = _defaultOwner;

/// 서버 읽기·쓰기를 이만큼만 기다린다(통신 없는 현장에서 화면이 멈추지 않게).
Duration recordSyncTimeout = const Duration(seconds: 8);

/// editedAt에 쓰는 폰 시각(ms). 테스트에서 바꿔 끼운다.
int Function() recordSyncClock = _wallClock;

int _wallClock() => DateTime.now().millisecondsSinceEpoch;

/// 목록 화면에 보일 상태.
class RecordSyncStatus {
  /// 서버에 올릴 수 있는 상태인지(Firebase 준비·로그인·이름).
  final bool enabled;

  /// 아직 서버에 올라가지 않은 저장·지우기 건수.
  final int pending;
  const RecordSyncStatus({required this.enabled, required this.pending});
}

/// 목록 위 한 줄 글. 기존 "폰에만 저장된 것 N건 · 통신되면 서버로 올라갑니다." 말과 맞췄다.
String recordSyncText(RecordSyncStatus s) {
  if (!s.enabled) return '폰에만 저장됩니다. 로그인하면 서버에도 저장됩니다.';
  if (s.pending > 0) {
    return '폰에만 저장된 것 ${s.pending}건 · 통신되면 서버로 올라갑니다.';
  }
  return '서버에 저장되어 있습니다. 같은 이름으로 쓰는 다른 폰에서도 보입니다.';
}

/// 기록 목록 하나(폰 저장 키 [key])를 서버 모음 [collection]과 맞춘다.
class RecordSync {
  /// 폰 저장 키(기록 JSON 목록).
  final String key;
  final String collection;

  /// 서버에서 받은 기록 JSON을 읽을 수 있는지(망가진 것은 폰에 넣지 않는다).
  final bool Function(Map<String, dynamic>) isValid;

  RecordSync({
    required this.key,
    required this.collection,
    required this.isValid,
  });

  /// 기록마다 {e: editedAt, p: 올릴 것 있음, d: 지움}. 폰 저장 키 옆에 둔다.
  String get metaKey => '${key}_sync';

  /// 처음 한 번 올리기(예전 기록)를 마쳤는지.
  String get uploadedKey => '${key}_sync_uploaded';

  static final Set<Future<void>> _inFlight = {};

  /// 올리는 중인 것이 모두 끝날 때까지 기다린다(테스트용).
  static Future<void> idle() async {
    while (_inFlight.isNotEmpty) {
      await Future.wait(_inFlight.toList());
    }
  }

  static void _track(Future<void> f) {
    _inFlight.add(f);
    f.whenComplete(() => _inFlight.remove(f));
  }

  static int _now() => recordSyncClock();

  Map<String, Map<String, dynamic>> _readMeta(SharedPreferences p) {
    try {
      final j = jsonDecode(p.getString(metaKey) ?? '{}');
      if (j is! Map) return {};
      return {
        for (final e in j.entries)
          if (e.value is Map)
            e.key.toString(): Map<String, dynamic>.from(e.value as Map),
      };
    } catch (_) {
      return {};
    }
  }

  void _writeMeta(SharedPreferences p, Map<String, Map<String, dynamic>> m) {
    unawaited(p.setString(metaKey, jsonEncode(m)));
  }

  List<Map<String, dynamic>> _readList(SharedPreferences p) {
    try {
      final j = jsonDecode(p.getString(key) ?? '[]');
      if (j is! List) return [];
      return [
        for (final e in j)
          if (e is Map && e['id'] is String) Map<String, dynamic>.from(e),
      ];
    } catch (_) {
      return [];
    }
  }

  /// 한 기록의 editedAt을 새로 매긴다(같은 ms에 두 번 저장해도 커지게).
  int _stamp(Map<String, Map<String, dynamic>> meta, String id) {
    final prev = (meta[id]?['e'] as num?)?.toInt() ?? 0;
    final now = _now();
    return now > prev ? now : prev + 1;
  }

  /// 폰에 저장한 뒤 부른다. 서버에 올리는 것은 기다리지 않는다.
  Future<void> saved(String id) async {
    final p = await SharedPreferences.getInstance();
    final meta = _readMeta(p);
    meta[id] = {'e': _stamp(meta, id), 'p': true};
    _writeMeta(p, meta);
    _track(_push(id));
  }

  /// 폰에서 지운 뒤 부른다. 서버에는 지움 표시를 올린다(기다리지 않는다).
  Future<void> removed(String id) async {
    final p = await SharedPreferences.getInstance();
    final meta = _readMeta(p);
    meta[id] = {'e': _stamp(meta, id), 'p': true, 'd': true};
    _writeMeta(p, meta);
    _track(_push(id));
  }

  /// 지금 상태(서버에 묻지 않고 폰 표시만 본다).
  Future<RecordSyncStatus> status() async {
    final remote = recordRemote();
    RecordOwner? owner;
    if (remote != null) {
      try {
        owner = await recordOwner();
      } catch (_) {
        owner = null;
      }
    }
    final p = await SharedPreferences.getInstance();
    return RecordSyncStatus(
      enabled: remote != null && owner != null,
      pending: _pendingCount(p),
    );
  }

  int _pendingCount(SharedPreferences p) {
    final meta = _readMeta(p);
    var n = 0;
    for (final m in meta.values) {
      if (m['p'] == true) n++;
    }
    // 올린 적 없는 예전 기록(표시가 없는 것)
    for (final r in _readList(p)) {
      if (!meta.containsKey(r['id'])) n++;
    }
    return n;
  }

  /// 한 기록(또는 지움 표시)을 올린다. 올라가면 표시를 지운다. 실패하면 표시를 남긴다.
  Future<bool> _push(String id) async {
    try {
      final remote = recordRemote();
      if (remote == null) return false;
      final owner = await recordOwner();
      if (owner == null) return false;
      final p = await SharedPreferences.getInstance();
      final meta = _readMeta(p);
      final m = meta[id];
      final e = (m?['e'] as num?)?.toInt() ?? _now();
      final gone = m?['d'] == true;
      Map<String, dynamic>? json;
      if (!gone) {
        for (final r in _readList(p)) {
          if (r['id'] == id) json = r;
        }
        if (json == null) return false; // 그사이 지워졌다(지움 표시가 따로 올라간다)
      }
      final fields = <String, dynamic>{
        ...?json,
        'id': id,
        'owner': owner.name,
        'ownerUid': owner.uid ?? '',
        'editedAt': e,
        'deleted': gone,
      };
      await remote.write(collection, id, fields).timeout(recordSyncTimeout);
      // 올라갔다. 그사이 또 고치지 않았으면 표시를 정리한다.
      final now = _readMeta(p);
      if ((now[id]?['e'] as num?)?.toInt() == e) {
        if (gone) {
          now.remove(id);
        } else {
          now[id] = {'e': e};
        }
        _writeMeta(p, now);
      }
      return true;
    } catch (_) {
      return false; // 통신 없음·권한 없음: 표시를 남겨 다음에 다시 올린다
    }
  }

  /// 목록 화면을 열 때 부른다. 서버의 내 기록을 폰에 합치고, 폰에만 있는 것을 올린다.
  /// 통신이 없거나 로그인하지 않았으면 폰 저장은 그대로 두고 상태만 돌려준다.
  Future<RecordSyncStatus> syncNow() async {
    final remote = recordRemote();
    RecordOwner? owner;
    if (remote != null) {
      try {
        owner = await recordOwner();
      } catch (_) {
        owner = null;
      }
    }
    final p = await SharedPreferences.getInstance();
    if (remote == null || owner == null) {
      return RecordSyncStatus(enabled: false, pending: _pendingCount(p));
    }
    RemoteFetch? got;
    try {
      got = await remote
          .fetch(collection, owner.name)
          .timeout(recordSyncTimeout);
    } catch (_) {
      got = null;
    }
    if (got == null) {
      return RecordSyncStatus(enabled: true, pending: _pendingCount(p));
    }

    // 여기부터 기다림 없이 읽고 고쳐 쓴다(그사이 다른 저장이 끼어들지 않게).
    final list = _readList(p);
    final meta = _readMeta(p);
    final toPush = <String>{};
    final seen = <String>{};
    int indexOf(String id) => list.indexWhere((r) => r['id'] == id);
    for (final r in got.docs) {
      seen.add(r.id);
      final i = indexOf(r.id);
      final m = meta[r.id];
      if (m == null && i < 0) {
        // 이 폰에 없던 기록(다른 폰에서 올린 것)
        if (!r.deleted && isValid(r.data)) {
          list.add(r.data);
          meta[r.id] = {'e': r.editedAt};
        }
        continue;
      }
      final le = (m?['e'] as num?)?.toInt() ?? 0; // 표시 없는 예전 기록은 0
      if (r.editedAt > le) {
        // 서버 것이 나중: 서버 것으로
        if (r.deleted) {
          if (i >= 0) list.removeAt(i);
          meta.remove(r.id);
        } else if (isValid(r.data)) {
          if (i >= 0) {
            list[i] = r.data;
          } else {
            list.add(r.data);
          }
          meta[r.id] = {'e': r.editedAt};
        }
      } else if (r.editedAt == le) {
        // 같다: 이미 올라간 것. 폰 목록에서 빠졌으면(지움 표시 없이) 서버 것을 되살린다.
        if (i < 0 && m?['d'] != true && !r.deleted && isValid(r.data)) {
          list.add(r.data);
        }
        if (got.fromServer) {
          if (m?['d'] == true) {
            meta.remove(r.id);
          } else {
            meta[r.id] = {'e': le};
          }
        } else if (m?['p'] == true) {
          toPush.add(r.id);
        }
      } else {
        toPush.add(r.id); // 폰 것이 나중: 다시 올린다
      }
    }
    // 서버에 없는 폰 기록: 올린다(처음 한 번 올리기 포함)
    for (final r in list) {
      final id = r['id'] as String;
      if (seen.contains(id)) continue;
      final m = meta[id];
      if (m == null) {
        meta[id] = {'e': _now(), 'p': true};
      } else if (m['p'] != true) {
        meta[id] = {...m, 'p': true};
      }
      toPush.add(id);
    }
    // 서버에 없는 지움 표시: 올린 적 없는 기록이면 지울 것도 없다
    for (final id in [
      for (final e in meta.entries)
        if (e.value['d'] == true && !seen.contains(e.key)) e.key,
    ]) {
      if (got.fromServer) {
        meta.remove(id);
      } else {
        toPush.add(id);
      }
    }
    unawaited(p.setString(key, jsonEncode(list)));
    _writeMeta(p, meta);

    final results = await Future.wait([for (final id in toPush) _push(id)]);
    if (got.fromServer && results.every((ok) => ok)) {
      await p.setBool(uploadedKey, true);
    }
    return RecordSyncStatus(enabled: true, pending: _pendingCount(p));
  }
}
