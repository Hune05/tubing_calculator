import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

// 폰 연락처에서 한 명(번호 하나)을 골라 이름과 전화번호만 가져온다.
// 폰의 기본 연락처 선택창을 쓰므로 연락처 읽기 권한이 필요 없고, 앱은 사용자가 고른 한 건의
// 이름·번호만 받는다(이메일·주소·메모·사진은 받지 않는다). 서버에는 사용자가 저장 단추를 눌러야 올라간다.

typedef PickedContact = ({String name, String phone});

/// 선택창이 돌려준 값을 칸에 넣을 모양으로 다듬는다. 이름과 번호가 둘 다 비면 null.
/// 번호는 앞뒤 공백만 걷고 하이픈은 그대로 둔다(전화·문자 앱이 알아서 읽는다).
PickedContact? normalizePickedContact(String? name, String? phone) {
  final n = (name ?? '').trim();
  final p = (phone ?? '').trim();
  if (n.isEmpty && p.isEmpty) return null;
  return (name: n, phone: p);
}

/// 폰 연락처 선택창을 열어 고른 한 건을 돌려준다. 취소하면 null.
/// 선택창을 열 수 없으면 예외가 난다(부르는 쪽에서 안내한다).
Future<PickedContact?> pickPhoneContact() async {
  final c = await FlutterNativeContactPicker().selectPhoneNumber();
  if (c == null) return null;
  final phone =
      c.selectedPhoneNumber ??
      ((c.phoneNumbers?.isNotEmpty ?? false) ? c.phoneNumbers!.first : null);
  return normalizePickedContact(c.fullName, phone);
}
