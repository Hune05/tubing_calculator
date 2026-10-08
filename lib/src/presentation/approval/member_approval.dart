// 사용 승인(10-08 사용자 결정 "승인 대기해", 관리자는 본인 하나).
//
// 처음 들어온 사람(구글이든 이름만이든)은 서버 app_members/{uid}에 "대기"로 적히고, 관리자가
// "사용 승인" 화면에서 승인해야 서버 자료를 쓴다. 바로 막으면 지금 쓰는 사람이 승인 전에
// 갇히므로, 관리자가 app_config/member_approval의 "승인제 켜기"를 켜야 앱이 막는다
// (켜기 전에는 대기 목록에 올리기만 한다). 서버 쪽 막기는 firestore.rules의 approved()가 한다.
//
// 통신이 없는 현장에서는 마지막으로 확인한 상태로 열린다(폰에 적어 둔 값). 한 번도 확인 못
// 했으면 막지 않는다(서버 자료는 규칙이 지킨다).
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/quick_firestore.dart';
import '../profile/profile_tools.dart' show ensureSignedIn;

/// 관리자 계정(재고 관리 마스터와 같은 계정). 규칙(firestore.rules isAdmin)에도 같은 값이 있다.
const String kAdminEmail = 'a01020020271@gmail.com';

const String kMembersCollection = 'app_members';
const String kApprovalConfigPath = 'app_config/member_approval';

enum MemberStatus { approved, pending, rejected, unknown }

MemberStatus memberStatusFromText(String? s) => switch (s) {
  'approved' => MemberStatus.approved,
  'pending' => MemberStatus.pending,
  'rejected' => MemberStatus.rejected,
  _ => MemberStatus.unknown,
};

String memberStatusText(MemberStatus s) => switch (s) {
  MemberStatus.approved => 'approved',
  MemberStatus.pending => 'pending',
  MemberStatus.rejected => 'rejected',
  MemberStatus.unknown => 'unknown',
};

/// 앱이 막아야 하는지. 승인제가 꺼져 있거나 상태를 모르면 막지 않는다.
bool memberBlocked({required bool enforced, required MemberStatus status}) =>
    enforced &&
    (status == MemberStatus.pending || status == MemberStatus.rejected);

/// 지금 로그인한 계정이 관리자인지.
bool isAdminUser([User? user]) {
  try {
    final u = user ?? FirebaseAuth.instance.currentUser;
    return u != null && !u.isAnonymous && u.email == kAdminEmail;
  } catch (_) {
    return false;
  }
}

/// 승인 확인 결과.
class MemberCheck {
  final MemberStatus status;
  final bool enforced;
  const MemberCheck(this.status, this.enforced);
  bool get blocked => memberBlocked(enforced: enforced, status: status);
}

/// 기다리지 않고 보내고, 서버가 거절해도 조용히 넘어간다(다음에 열 때 다시 맞춘다).
void _quiet(Future<void> write) {
  unawaited(writeQuick(write).catchError((_) {}));
}

const _kPrefStatus = 'member_status_v1';
const _kPrefEnforced = 'member_enforced_v1';
const _kPrefUid = 'member_uid_v1';

/// 폰에 적어 둔 마지막 확인 결과(통신 없을 때 쓰는 값). 다른 계정 것이면 모름.
Future<MemberCheck> cachedMemberCheck() async {
  try {
    final p = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final savedUid = p.getString(_kPrefUid);
    final status = uid != null && savedUid == uid
        ? memberStatusFromText(p.getString(_kPrefStatus))
        : MemberStatus.unknown;
    return MemberCheck(status, p.getBool(_kPrefEnforced) ?? false);
  } catch (_) {
    return const MemberCheck(MemberStatus.unknown, false);
  }
}

Future<void> _remember(String uid, MemberCheck c) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPrefUid, uid);
    await p.setString(_kPrefStatus, memberStatusText(c.status));
    await p.setBool(_kPrefEnforced, c.enforced);
  } catch (_) {}
}

/// 서버에서 내 승인 상태를 확인한다. 문서가 없으면 "대기"로 올린다(관리자는 바로 승인).
/// 통신이 없거나 읽기가 막히면 폰에 적어 둔 값을 돌려준다.
Future<MemberCheck> checkMember({required String name}) async {
  final cached = await cachedMemberCheck();
  try {
    final uid = await ensureSignedIn();
    if (uid == null) return cached;
    final db = FirebaseFirestore.instance;
    var enforced = cached.enforced;
    try {
      final cfg = await readDocQuick(db.doc(kApprovalConfigPath));
      if (cfg.exists) enforced = cfg.data()?['enabled'] == true;
    } catch (_) {}

    final ref = db.collection(kMembersCollection).doc(uid);
    final user = FirebaseAuth.instance.currentUser;
    final admin = isAdminUser(user);
    final snap = await readDocQuick(ref);
    MemberStatus status;
    if (snap.exists) {
      status = memberStatusFromText(snap.data()?['status'] as String?);
      // 이름·이메일이 바뀌었으면 관리자가 알아보게 고쳐 둔다(상태는 건드리지 않는다).
      final d = snap.data() ?? {};
      final email = user?.email ?? '';
      if (d['name'] != name || (d['email'] ?? '') != email) {
        _quiet(ref.set({'name': name, 'email': email}, SetOptions(merge: true)));
      }
      if (admin && status != MemberStatus.approved) {
        status = MemberStatus.approved;
        _quiet(ref.set({'status': 'approved'}, SetOptions(merge: true)));
      }
    } else if (snap.metadata.isFromCache) {
      // 폰 사본에 없을 뿐 서버에는 있을 수 있다. 새로 "대기"로 덮지 않는다.
      return cached;
    } else {
      status = admin ? MemberStatus.approved : MemberStatus.pending;
      _quiet(
        ref.set({
          'uid': uid,
          'name': name,
          'email': user?.email ?? '',
          'anonymous': user?.isAnonymous ?? true,
          'status': memberStatusText(status),
          'requestedAt': FieldValue.serverTimestamp(),
        }),
      );
    }
    final result = MemberCheck(status, enforced);
    await _remember(uid, result);
    return result;
  } catch (e) {
    debugPrint('승인 확인 실패: $e');
    return cached;
  }
}

/// 관리자: 승인·거절·되돌리기.
Future<void> setMemberStatus(String uid, MemberStatus status) =>
    writeQuick(
      FirebaseFirestore.instance.collection(kMembersCollection).doc(uid).set({
        'status': memberStatusText(status),
        'decidedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    );

/// 관리자: 승인제 켜기·끄기.
Future<void> setApprovalEnforced(bool on) => writeQuick(
  FirebaseFirestore.instance.doc(kApprovalConfigPath).set({
    'enabled': on,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true)),
);
