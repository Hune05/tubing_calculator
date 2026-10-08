// 구글 계정 연결(로그인)과 계산기 설정 받기. 설정 화면·프로필의 "구글 계정 연결"과 같은 순서다.
// 승인 대기 화면에서 나갈 길로 쓴다(10-09: 대기 화면에 "다시 확인"뿐이라 이름만 넣고 들어온
// 사람·관리자가 구글 계정으로 바꿀 수 없었다).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/utils/settings_cloud.dart';
import 'profile_tools.dart';
import 'widgets/settings_cloud_card.dart';

const String kGoogleServerClientId =
    '289974993415-lhibiid49ncmb5hev53hnasj7vhkvki3.apps.googleusercontent.com';

Future<void>? _googleReady;

/// 구글 로그인 준비. 로딩·프로필·설정·자재 관리·승인 대기가 각자 initialize를 불렀는데,
/// google_sign_in 7은 "한 번만 부르라"고 한다(두 번째부터는 동작이 정해져 있지 않다).
/// 10-09: 여기 한 곳에서 한 번만 하게 모았다. 실패하면 다음에 다시 한다.
Future<void> ensureGoogleSignInReady() {
  final f = _googleReady ??= GoogleSignIn.instance.initialize(
    serverClientId: kGoogleServerClientId,
  );
  return f.catchError((Object e) {
    _googleReady = null;
    throw e;
  });
}

/// 구글 계정으로 로그인(익명이면 그 계정에 잇는다)하고 서버 설정을 받는다. 실패하면 던진다.
Future<void> linkGoogleAndRestore() async {
  final g = GoogleSignIn.instance;
  await ensureGoogleSignInReady();
  final account = await g.authenticate();
  final credential = GoogleAuthProvider.credential(
    idToken: account.authentication.idToken,
  );
  await signInOrLinkGoogle(credential);
  final got = await restoreCalculatorSettings();
  if (got == 0 && SettingsCloudSync.instance.lastRestoreServerMissing) {
    await SettingsCloudSync.instance.backup();
  }
}
