import 'package:flutter/services.dart';

// 폰 연락처에서 한 명을 골라 이름·전화번호·이메일만 가져온다.
// 폰의 기본 연락처 선택창에서 고른 한 명만 읽고(연락처 전체는 읽지 않는다), 주소·메모·사진 같은
// 나머지는 받지 않는다. 처음 쓸 때 연락처 읽기 권한을 한 번 묻는다. 서버에는 사용자가 저장 단추를
// 눌러야 올라간다.

const MethodChannel _channel = MethodChannel('field/contact_pick');

/// 폰에서 고른 한 명. 번호·이메일이 여러 개면 목록으로 온다(부르는 쪽이 하나를 고른다).
class PhoneContactChoice {
  const PhoneContactChoice({
    required this.name,
    this.phones = const [],
    this.emails = const [],
  });

  final String name;
  final List<String> phones;
  final List<String> emails;
}

/// 목록의 빈 글·중복을 걷고 앞뒤 공백을 자른다(번호의 하이픈은 그대로 둔다).
List<String> cleanContactValues(Iterable<dynamic>? raw) {
  final out = <String>[];
  for (final v in raw ?? const []) {
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && !out.contains(s)) out.add(s);
  }
  return out;
}

/// 네이티브가 돌려준 값을 다듬는다. 이름·번호·이메일이 모두 비면 null.
PhoneContactChoice? parsePickedContact(Map<dynamic, dynamic>? m) {
  if (m == null) return null;
  final name = (m['name'] ?? '').toString().trim();
  final phones = cleanContactValues(m['phones'] as Iterable?);
  final emails = cleanContactValues(m['emails'] as Iterable?);
  if (name.isEmpty && phones.isEmpty && emails.isEmpty) return null;
  return PhoneContactChoice(name: name, phones: phones, emails: emails);
}

/// 폰 연락처 선택창을 열어 고른 한 명을 돌려준다. 취소하면 null.
/// 권한을 거절했거나 선택창을 열 수 없으면 [PlatformException](code: denied·picker·read…)이 난다.
Future<PhoneContactChoice?> pickPhoneContact() async {
  final m = await _channel.invokeMapMethod<dynamic, dynamic>('pick');
  return parsePickedContact(m);
}
