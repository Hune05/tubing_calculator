// 서버 쓰기를 기다리지 않고 보낸다.
//
// Firestore는 통신이 없어도 폰에 먼저 적고 통신될 때 올린다. 그런데 쓰기를
// await하면 서버가 받았다고 답할 때까지(통신이 올 때까지) 끝나지 않아, 발전소처럼
// 통신이 없는 곳에서는 저장 단추를 눌러도 화면이 안 닫히거나 목록이 안 바뀌었다.
// 폰 안 저장은 따로 먼저 하고, 서버 쪽은 이것으로 보내 둔다. 실패는 기록만 한다.
import 'package:flutter/foundation.dart';

void sendQuietly(Future<void> Function() write, {String what = '서버 저장'}) {
  try {
    write().catchError((Object e) => debugPrint('$what 실패: $e'));
  } catch (e) {
    // 서버가 안 켜진 곳(테스트 등)은 부르는 순간 바로 실패한다.
    debugPrint('$what 실패: $e');
  }
}
