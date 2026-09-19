import 'package:shared_preferences/shared_preferences.dart';

// 원자재를 자르고 남은 토막을 기기에 적어 둔다. 다음 재단 계산에서 이 토막부터
// 먼저 쓰도록 하기 위해서다. 토막은 규격(예: "튜브 1/2\"")별로 따로 센다 —
// 규격이 다르면 서로 대신 쓸 수 없다.

const String kLeftoversPrefsKey = 'cutting_leftovers_v1';

class Leftover {
  final String label; // 규격. 규격 구분이 없는 화면은 빈 문자열
  final double length; // mm
  const Leftover(this.label, this.length);

  @override
  bool operator ==(Object other) =>
      other is Leftover && other.label == label && other.length == length;

  @override
  int get hashCode => Object.hash(label, length);

  // 저장 형식: "길이\u001F규격"
  String encode() => '${length.toStringAsFixed(0)}\u001F$label';

  static Leftover? decode(String raw) {
    final i = raw.indexOf('\u001F');
    if (i < 0) return null;
    final len = double.tryParse(raw.substring(0, i));
    if (len == null || len <= 0) return null;
    return Leftover(raw.substring(i + 1), len);
  }
}

Future<List<Leftover>> loadLeftovers() async {
  final p = await SharedPreferences.getInstance();
  return [
    for (final raw in p.getStringList(kLeftoversPrefsKey) ?? const <String>[])
      ?Leftover.decode(raw),
  ];
}

Future<void> saveLeftovers(List<Leftover> all) async {
  final p = await SharedPreferences.getInstance();
  await p.setStringList(kLeftoversPrefsKey, [for (final l in all) l.encode()]);
}

// 이번 계산에서 쓴 토막([used])을 빼고 새로 남는 토막([added])을 더한다.
// 같은 길이가 여러 개면 쓴 개수만큼만 뺀다.
List<Leftover> applyLeftoverChange(
  List<Leftover> current, {
  List<Leftover> used = const [],
  List<Leftover> added = const [],
}) {
  final out = [...current];
  for (final u in used) {
    final i = out.indexOf(u);
    if (i >= 0) out.removeAt(i);
  }
  out.addAll(added);
  return out;
}
