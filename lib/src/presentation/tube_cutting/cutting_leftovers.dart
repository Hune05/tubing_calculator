import 'package:shared_preferences/shared_preferences.dart';

// 원자재를 자르고 잔재를 기기에 적어 둔다. 다음 재단 계산에서 이 잔재부터
// 먼저 쓰도록 하기 위해서다. 잔재는 규격(예: "튜브 1/2\"")별로 따로 센다 —
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

// 잔재 목록을 규격별로 묶는다(화면에서 규격마다 머리글을 두려고). 규격은 처음 나온 순서, 같은 규격 안에서는
// 긴 잔재부터. [indices]는 원래 목록에서의 위치라서 지울 때 그대로 쓴다.
class LeftoverGroup {
  final String label;
  final List<int> indices;
  final double totalMm;
  const LeftoverGroup(this.label, this.indices, this.totalMm);
}

List<LeftoverGroup> groupLeftoversByLabel(List<Leftover> list) {
  final order = <String>[];
  final idx = <String, List<int>>{};
  for (var i = 0; i < list.length; i++) {
    final l = list[i].label;
    if (!idx.containsKey(l)) order.add(l);
    idx.putIfAbsent(l, () => []).add(i);
  }
  return [
    for (final l in order)
      LeftoverGroup(
        l,
        (idx[l]!..sort((a, b) => list[b].length.compareTo(list[a].length))),
        idx[l]!.fold(0.0, (s, i) => s + list[i].length),
      ),
  ];
}

// 이번 계산에서 쓴 잔재([used])를 빼고 새 잔재([added])를 더한다.
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

// 재단 최적화에서 "여러 길이 섞어 쓰기"를 켜 두었을 때 고른 원자재 길이들(꺼져 있으면 빈 목록).
// 튜브 컷팅 화면과 절단 지시서(PDF)가 같은 설정을 쓴다.
const String kTubeMixPrefsKey = 'cutting_mix_lengths_v1';

Future<List<double>> loadMixLengths([String key = kTubeMixPrefsKey]) async {
  final p = await SharedPreferences.getInstance();
  return [
    for (final v in p.getStringList(key) ?? const <String>[])
      if (double.tryParse(v) != null && double.parse(v) > 0) double.parse(v),
  ];
}
