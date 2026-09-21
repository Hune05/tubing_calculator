import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'layout_board_models.dart';

/// 지금 앱을 쓰는 사람을 읽는다. 로그인(인증)했으면 uid, 프로필 이름은 폰에 적어 둔
/// 'user_real_name'. 테스트에서는 이 변수를 바꿔 끼워 서버 없이 돌린다.
Future<LayoutOwner> Function() loadLayoutOwner = _loadLayoutOwnerFromApp;

Future<LayoutOwner> _loadLayoutOwnerFromApp() async {
  String? uid;
  String? name;
  try {
    uid = FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {
    uid = null;
  }
  try {
    final prefs = await SharedPreferences.getInstance();
    name = prefs.getString('user_real_name');
  } catch (_) {
    name = null;
  }
  return LayoutOwner(uid: uid, name: name);
}
