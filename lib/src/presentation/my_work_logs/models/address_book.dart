import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tubing_calculator/src/data/ownership.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/send_quietly.dart';

// 🚀 [공용 주소록] 같은 협력사/자재 업체를 프로젝트마다 다시 적지 않도록, 연락처를
// 주소록에 저장해 두고 어느 프로젝트에서든 불러온다. Firestore
// (my_project_settings/address_book)와 이 기기에 같이 보관한다.
const _kKey = 'address_book_v1';

// 사람마다 따로(점검 25번). 처음에는 예전에 같이 쓰던 문서를 이어받는다.
DocumentReference<Map<String, dynamic>> get _doc =>
    mySettingsDoc('address_book');

String _key(Map e) => '${e['name']}|${e['phone']}';

List<Map<String, dynamic>> _fromList(dynamic v) => (v as List? ?? [])
    .whereType<Map>()
    .map((e) => Map<String, dynamic>.from(e))
    .toList();

Future<List<Map<String, dynamic>>> _loadLocal() async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getStringList(_kKey) ?? [];
  return raw.map((s) {
    final parts = s.split('');
    return <String, dynamic>{
      'name': parts.isNotEmpty ? parts[0] : '',
      'phone': parts.length > 1 ? parts[1] : '',
      'role': parts.length > 2 ? parts[2] : '기타',
    };
  }).toList();
}

Future<void> _saveLocal(List<Map<String, dynamic>> l) async {
  final p = await SharedPreferences.getInstance();
  await p.setStringList(
    _kKey,
    l.map((e) => '${e['name']}${e['phone']}${e['role']}').toList(),
  );
}

Future<List<Map<String, dynamic>>> loadAddressBook() async {
  final local = await _loadLocal();
  try {
    final cloud = _fromList((await readMySettings('address_book'))?['items']);
    final seen = cloud.map(_key).toSet();
    final merged = [...cloud, ...local.where((e) => !seen.contains(_key(e)))];
    await _saveLocal(merged);
    if (merged.length != cloud.length) {
      sendQuietly(() => _doc.set({'items': merged}));
    }
    return merged;
  } catch (_) {
    return local;
  }
}

Future<void> saveAddress(Map<String, dynamic> entry) async {
  final all = await _loadLocal();
  if (all.any((e) => _key(e) == _key(entry))) return;
  all.add({
    'name': entry['name'],
    'phone': entry['phone'],
    'role': entry['role'],
  });
  await _saveLocal(all);
  // 통신이 없어도 목록이 바로 바뀌게 서버는 기다리지 않는다.
  sendQuietly(() => _doc.set({'items': all}), what: '주소록 서버 저장');
}

Future<void> removeAddress(Map entry) async {
  final all = await _loadLocal();
  all.removeWhere((e) => _key(e) == _key(entry));
  await _saveLocal(all);
  // 통신이 없어도 목록이 바로 바뀌게 서버는 기다리지 않는다.
  sendQuietly(() => _doc.set({'items': all}), what: '주소록 서버 저장');
}
