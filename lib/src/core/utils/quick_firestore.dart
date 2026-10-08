// 통신이 없는 현장에서도 멈추지 않는 Firestore 읽기·쓰기(10-08).
//
// 발전소처럼 통신이 없으면 Firestore 쓰기는 폰에 먼저 적히지만, await하면 서버 답이 올 때까지
// 끝나지 않는다. 읽기도 서버를 기다리다 한참 멈춘다. 화면마다 따로 시간 제한을 붙이다 보니
// 빠진 곳이 계속 나왔다. 새 코드는 이 함수들을 쓴다.
// - 기다리지 않고 보내기만 할 때는 send_quietly.dart의 sendQuietly.
// - 끝날 때까지 기다리되 정해진 시간만: writeQuick.
// - 서버를 잠깐 읽고 안 되면 폰 사본: readDocQuick / readQueryQuick.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// 쓰기 기다림 기본값. 폰에는 이미 적혔으므로 이만큼 지나면 넘어간다.
const Duration kQuickWriteWait = Duration(seconds: 8);

/// 읽기 기다림 기본값. 넘으면 폰 사본을 읽는다.
const Duration kQuickReadWait = Duration(seconds: 5);

/// [write]를 [wait]까지만 기다린다. 시간이 지나면 조용히 넘어간다(폰에는 적혀 있고 통신되면 올라간다).
/// 서버가 거절한 오류(권한 등)는 그대로 던진다.
Future<void> writeQuick(Future<void> write, {Duration wait = kQuickWriteWait}) =>
    write.timeout(wait, onTimeout: () {});

/// 문서 하나를 서버에서 [wait]까지 읽고, 안 되면 폰 사본을 읽는다.
Future<DocumentSnapshot<Map<String, dynamic>>> readDocQuick(
  DocumentReference<Map<String, dynamic>> ref, {
  Duration wait = kQuickReadWait,
}) async {
  try {
    return await ref.get().timeout(wait);
  } catch (_) {
    return ref.get(const GetOptions(source: Source.cache));
  }
}

/// 쿼리를 서버에서 [wait]까지 읽고, 안 되면 폰 사본을 읽는다.
Future<QuerySnapshot<Map<String, dynamic>>> readQueryQuick(
  Query<Map<String, dynamic>> q, {
  Duration wait = kQuickReadWait,
}) async {
  try {
    return await q.get().timeout(wait);
  } catch (_) {
    return q.get(const GetOptions(source: Source.cache));
  }
}
