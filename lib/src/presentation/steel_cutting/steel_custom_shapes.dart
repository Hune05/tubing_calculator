import 'package:shared_preferences/shared_preferences.dart';

// "내 규격": 목록에 없어서 직접 입력한 규격 이름을 이 폰에 적어 두었다가, 다음부터 규격 선택창의
// "내 규격"에서 골라 쓰게 한다(매번 다시 치지 않도록). 이름만 저장한다 — 길이·수량은 항목마다 다르다.
const String kCustomSteelShapesPrefsKey = 'steel_custom_shapes_v1';
const int kMaxCustomSteelShapes = 60;

Future<List<String>> loadCustomSteelShapes() async {
  try {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(kCustomSteelShapesPrefsKey) ?? const <String>[];
  } catch (_) {
    return const <String>[];
  }
}

// 이름에서 앞뒤 공백을 빼고 여러 칸 공백을 한 칸으로 줄인다. 비면 빈 글자.
String cleanCustomShapeLabel(String raw) =>
    raw.trim().replaceAll(RegExp(r'\s+'), ' ');

// 맨 앞에 넣는다(방금 쓴 것이 위로). 같은 이름은 하나만 둔다. 갱신된 목록을 돌려준다.
Future<List<String>> addCustomSteelShape(String label) async {
  final clean = cleanCustomShapeLabel(label);
  final list = [...await loadCustomSteelShapes()];
  if (clean.isEmpty) return list;
  list.remove(clean);
  list.insert(0, clean);
  if (list.length > kMaxCustomSteelShapes) {
    list.removeRange(kMaxCustomSteelShapes, list.length);
  }
  try {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(kCustomSteelShapesPrefsKey, list);
  } catch (_) {}
  return list;
}

Future<List<String>> removeCustomSteelShape(String label) async {
  final list = [...await loadCustomSteelShapes()]..remove(label);
  try {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(kCustomSteelShapesPrefsKey, list);
  } catch (_) {}
  return list;
}
