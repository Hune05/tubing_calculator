// 프로필 화면들이 같이 쓰는 검사·서버 읽고 쓰기.
//
// 사용자 문서는 users/{이름}이다(uid가 아니라 이름이 키). 그래서 이름을 바꾸는 일은
// "새 문서에 옛 문서 칸을 옮기는 일"이고, 예전엔 프로필 화면(연필)과 상세 프로필(이름 칸)
// 두 갈래가 따로 움직여 한쪽은 사진·알림 토큰을 안 옮겼다. 여기 [renameUser] 하나로 합친다.
// 통신 없는 현장이 많아 서버 일은 모두 몇 초 뒤 그만두고 폰 값으로 진행한다.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kGuestName = "로그인 필요";
const String kUserNamePrefsKey = 'user_real_name';

/// 이름으로 쓸 수 없으면 까닭(한국어), 쓸 수 있으면 null.
/// 이름이 서버 문서 주소라 '/'는 못 쓰고, 너무 길면 홈 머리글이 넘친다.
String? userNameProblem(String raw) {
  final name = raw.trim();
  if (name.isEmpty) return "이름을 넣으십시오.";
  if (name == kGuestName) return "그 이름은 쓸 수 없습니다.";
  if (name.length > 20) return "이름은 20자까지입니다.";
  if (RegExp(r'[/\\]').hasMatch(name)) return "이름에 / 나 \\ 는 쓸 수 없습니다.";
  if (name == '.' || name == '..') return "그 이름은 쓸 수 없습니다.";
  if (name.startsWith('__') && name.endsWith('__')) return "그 이름은 쓸 수 없습니다.";
  return null;
}

/// 연락처를 숫자만 남겨 010-1234-5678 모양으로. 모양을 모르면 숫자·하이픈만 남긴 것.
String normalizePhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 11) {
    return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
  }
  if (digits.length == 10) {
    return digits.startsWith('02')
        ? '${digits.substring(0, 2)}-${digits.substring(2, 6)}-${digits.substring(6)}'
        : '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
  }
  if (digits.length == 9 && digits.startsWith('02')) {
    return '${digits.substring(0, 2)}-${digits.substring(2, 5)}-${digits.substring(5)}';
  }
  return raw.replaceAll(RegExp(r'[^0-9\-+]'), '').trim();
}

/// 연락처로 볼 수 있는지(숫자 9~11자리).
bool isPhoneLike(String raw) {
  final n = raw.replaceAll(RegExp(r'[^0-9]'), '').length;
  return n >= 9 && n <= 11;
}

/// 프로필의 "로그인" 줄 글. 구글이면 계정 주소를, 아니면 이름만 넣었다고.
String loginMethodLabel({required bool googleLinked, String? email}) {
  if (!googleLinked) return "이름만 넣음 (구글 계정 없음)";
  final e = (email ?? '').trim();
  return e.isEmpty ? "구글 계정" : "구글 계정 · $e";
}

/// 이 이름 문서를 내가 쓸 수 있는지. 쓸 수 없으면 까닭(한국어), 쓸 수 있으면 null.
///
/// 사용자 문서는 이름이 열쇠라, 예전엔 남의 이름을 넣으면 그 사람 문서(사진·연락처·
/// 알림)를 그대로 가져갔다. 이제 문서에 주인 uid를 적어 두고, 다른 uid가 적힌 이름은
/// 막는다. uid가 안 적힌 옛 문서와, 내 uid를 모를 때(로그인 못 함)는 막지 않는다.
String? nameOwnerProblem(Map<String, dynamic>? doc, String? myUid) {
  final owner = (doc?['uid'] as String?)?.trim() ?? '';
  final me = (myUid ?? '').trim();
  if (owner.isEmpty || me.isEmpty || owner == me) return null;
  return "이미 다른 사람이 쓰는 이름입니다. 다른 이름을 넣으십시오.";
}

/// 지금 로그인한 사람의 uid. 없으면(로그인 안 함·읽기 실패) null.
String? currentUid() {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return (uid == null || uid.isEmpty) ? null : uid;
  } catch (_) {
    return null;
  }
}

/// 로그인이 안 되어 있으면 익명으로 로그인해 uid를 받는다. 이미 되어 있으면 그대로.
///
/// "이름만 넣고 시작"한 사람도 uid가 있어야 배치도·재고의 "내 것"이 생긴다.
/// 통신이 없거나 Firebase 콘솔에서 익명 로그인이 꺼져 있으면 null을 주고 예전처럼
/// 이름만으로 쓴다(앱은 그대로 돈다). 다음에 앱을 열 때 다시 시도한다.
Future<String?> ensureSignedIn() async {
  final have = currentUid();
  if (have != null) return have;
  try {
    final cred = await FirebaseAuth.instance.signInAnonymously().timeout(
      const Duration(seconds: 4),
    );
    return cred.user?.uid;
  } catch (e) {
    debugPrint("익명 로그인 건너뜀: $e");
    return null;
  }
}

/// 지금 계정이 익명(이름만 넣고 시작)인지.
bool isAnonymousUser() {
  try {
    return FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
  } catch (_) {
    return false;
  }
}

/// 구글 로그인. 익명 계정이면 새로 로그인하지 않고 그 계정에 구글을 이어서 uid를
/// 그대로 둔다(익명 때 만든 "내 것" 재고·배치도를 잃지 않게). 그 구글 계정이 이미
/// 다른 uid로 쓰이고 있으면 그 계정으로 로그인한다.
Future<UserCredential> signInOrLinkGoogle(AuthCredential credential) async {
  final u = FirebaseAuth.instance.currentUser;
  if (u != null && u.isAnonymous) {
    try {
      return await u.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'credential-already-in-use' &&
          e.code != 'email-already-in-use' &&
          e.code != 'provider-already-linked') {
        rethrow;
      }
    }
  }
  return FirebaseAuth.instance.signInWithCredential(credential);
}

/// 사용자 문서 한 벌. 없는 칸은 빈 글.
class UserProfile {
  final String name;
  final String team;
  final String role;
  final String phone;
  final String? photoUrl;
  const UserProfile({
    required this.name,
    this.team = '',
    this.role = '',
    this.phone = '',
    this.photoUrl,
  });

  static UserProfile fromMap(String name, Map<String, dynamic>? m) =>
      UserProfile(
        name: (m?['name'] as String?)?.trim().isNotEmpty == true
            ? (m!['name'] as String).trim()
            : name,
        team: (m?['team'] as String?) ?? '',
        role: (m?['role'] as String?) ?? '',
        phone: (m?['phoneNumber'] as String?) ?? '',
        photoUrl: m?['photoUrl'] as String?,
      );
}

/// 서버·폰 저장. 모두 몇 초 넘으면 그만두고 폰 값으로 진행한다.
class ProfileStore {
  ProfileStore._();
  static final ProfileStore instance = ProfileStore._();

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  static bool isGuest(String? name) =>
      name == null || name.trim().isEmpty || name == kGuestName;

  /// 폰에 적힌 이름.
  Future<String?> savedName() async =>
      (await SharedPreferences.getInstance()).getString(kUserNamePrefsKey);

  Future<void> saveName(String name) async =>
      (await SharedPreferences.getInstance()).setString(
        kUserNamePrefsKey,
        name,
      );

  Future<void> clearName() async =>
      (await SharedPreferences.getInstance()).remove(kUserNamePrefsKey);

  /// 사용자 문서를 읽는다. 서버가 5초 안에 답이 없으면 폰에 남은 것(캐시)으로.
  Future<UserProfile> load(String name) async {
    if (isGuest(name)) return UserProfile(name: name);
    Map<String, dynamic>? data;
    try {
      data = (await _users.doc(name).get().timeout(const Duration(seconds: 5)))
          .data();
    } catch (_) {
      try {
        data =
            (await _users.doc(name).get(const GetOptions(source: Source.cache)))
                .data();
      } catch (e) {
        debugPrint("프로필 읽기 실패: $e");
      }
    }
    return UserProfile.fromMap(name, data);
  }

  /// 팀·직급·연락처를 저장한다(폰에 먼저 적히고, 통신되면 올라간다).
  Future<void> saveFields(
    String name, {
    required String team,
    required String role,
    required String phone,
  }) => _users
      .doc(name)
      .set({
        'name': name,
        'team': team,
        'role': role,
        'phoneNumber': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true))
      .timeout(const Duration(seconds: 5), onTimeout: () {});

  /// 이 이름을 내가 쓰겠다고 적는다. 다른 사람(uid)이 이미 쓰는 이름이면 까닭을 준다.
  /// 통신이 없어 확인을 못 하면 막지 않는다(현장에서 시작은 되게). 문서에 내 uid를 적는다.
  Future<String?> claimName(String name) async {
    if (isGuest(name)) return null;
    final uid = await ensureSignedIn();
    Map<String, dynamic>? data;
    try {
      data = (await _users.doc(name).get().timeout(const Duration(seconds: 3)))
          .data();
    } catch (_) {
      data = null; // 확인 못 함 — 막지 않는다
    }
    final problem = nameOwnerProblem(data, uid);
    if (problem != null) return problem;
    if (uid != null) {
      // 기다리지 않는다(통신 없으면 폰에 적혀 있다가 나중에 올라간다). 이름 넣기 창이
      // 통신 없는 곳에서 오래 멈추지 않게.
      _users
          .doc(name)
          .set({
            'name': name,
            'uid': uid,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .catchError((e) => debugPrint("이름 주인 적기 실패: $e"));
    }
    return null;
  }

  /// 이 폰의 알림 토큰을 그 이름 문서에 올린다.
  /// 그 이름 문서에 다른 사람 uid가 적혀 있으면 올리지 않는다(남의 알림을 가로채지 않게).
  Future<void> saveToken(String name) async {
    if (isGuest(name)) return;
    try {
      final uid = currentUid();
      if (uid != null) {
        try {
          final snap = await _users
              .doc(name)
              .get()
              .timeout(const Duration(seconds: 5));
          if (nameOwnerProblem(snap.data(), uid) != null) return;
        } catch (_) {
          // 확인 못 하면 예전처럼 올린다(통신 없으면 어차피 폰에 머문다).
        }
      }
      final token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      if (token == null) return;
      await _users
          .doc(name)
          .set({
            'fcmToken': token,
            if (uid != null) 'uid': uid,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5), onTimeout: () {});
    } catch (e) {
      debugPrint("알림 토큰 저장 실패: $e");
    }
  }

  /// 로그아웃할 때 토큰을 지운다 — 같이 쓰는 폰에서 남의 알림이 오지 않게.
  Future<void> clearToken(String name) async {
    if (isGuest(name)) return;
    try {
      await _users
          .doc(name)
          .update({'fcmToken': FieldValue.delete()})
          .timeout(const Duration(seconds: 5), onTimeout: () {});
    } catch (e) {
      debugPrint("알림 토큰 지우기 실패: $e");
    }
  }

  /// users/{옛 이름}의 칸(사진·팀·연락처)을 users/{새 이름}에 복사한다. 옛 문서는 둔다.
  Future<void> copyDoc(String oldName, String newName) async {
    if (isGuest(oldName) || oldName == newName) return;
    try {
      final snap = await _users
          .doc(oldName)
          .get()
          .timeout(const Duration(seconds: 5));
      final data = snap.data();
      if (data == null || data.isEmpty) return;
      await _users
          .doc(newName)
          .set({
            ...data,
            'name': newName,
            // 새 이름 문서의 주인은 지금 나(옛 문서에 uid가 없었어도).
            if (currentUid() != null) 'uid': currentUid(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5), onTimeout: () {});
    } catch (e) {
      debugPrint("사용자 문서 복사 실패: $e");
    }
  }

  /// 이름 바꾸기 한 갈래: 구글 표시 이름 → 폰 → 문서 복사 → 토큰.
  /// 예전 이름으로 적은 일정·기록은 예전 이름으로 남는다(부르는 쪽이 안내한다).
  Future<void> renameUser(String oldName, String newName) async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u != null) {
        await u
            .updateDisplayName(newName)
            .timeout(const Duration(seconds: 5), onTimeout: () {});
      }
    } catch (e) {
      debugPrint("구글 표시 이름 바꾸기 실패: $e");
    }
    await saveName(newName);
    await copyDoc(oldName, newName);
    await saveToken(newName);
  }

  /// 프로필 사진을 올리고 주소를 문서에 적는다. 통신 없으면 20초 뒤 실패(null).
  Future<String?> uploadPhoto(String name, File file) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$name.jpg');
      await ref.putFile(file).timeout(const Duration(seconds: 20));
      final url = await ref.getDownloadURL().timeout(
        const Duration(seconds: 8),
      );
      await _users
          .doc(name)
          .set({
            'photoUrl': url,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5), onTimeout: () {});
      return url;
    } catch (e) {
      debugPrint("프로필 사진 올리기 실패: $e");
      return null;
    }
  }

  /// 프로필 사진을 지운다(문서 칸 + 저장소 파일). 파일 지우기가 안 돼도 칸은 지운다.
  Future<bool> deletePhoto(String name) async {
    try {
      await _users
          .doc(name)
          .update({'photoUrl': FieldValue.delete()})
          .timeout(const Duration(seconds: 5), onTimeout: () {});
      try {
        await FirebaseStorage.instance
            .ref()
            .child('profile_photos')
            .child('$name.jpg')
            .delete()
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint("프로필 사진 지우기 실패: $e");
      return false;
    }
  }
}
