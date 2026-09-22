import 'package:cloud_firestore/cloud_firestore.dart';
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

// 잔재를 어디에 둘지 갈아끼울 수 있게 해 둔다. 앱은 서버(Firestore)를 쓰고, 테스트는 폰(prefs)을 쓴다.
abstract class LeftoverStore {
  Future<List<Leftover>> load();
  Future<void> save(List<Leftover> all);
}

// 폰에만 두는 방식(예전 방식). 테스트와 서버로 옮기기 전 자료를 읽는 데 쓴다.
class PrefsLeftoverStore implements LeftoverStore {
  @override
  Future<List<Leftover>> load() async {
    final p = await SharedPreferences.getInstance();
    return [
      for (final raw in p.getStringList(kLeftoversPrefsKey) ?? const <String>[])
        ?Leftover.decode(raw),
    ];
  }

  @override
  Future<void> save(List<Leftover> all) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(kLeftoversPrefsKey, [
      for (final l in all) l.encode(),
    ]);
  }
}

// 서버에 두는 방식. 문서 하나에 목록을 담는다(개인이 쓰는 앱이라 이게 단순하고 안전하다).
// 통신이 없어도 Firestore가 폰에 캐시를 두고 쓰기를 쌓아 두므로 현장에서 그대로 쓸 수 있다.
const String kLeftoversCollection = 'cutting_leftovers';
const String kLeftoversDocId = 'current';
// 폰에 있던 잔재를 서버로 한 번만 옮기기 위한 표시.
const String kLeftoversMovedPrefsKey = 'cutting_leftovers_moved_to_server_v1';

class FirestoreLeftoverStore implements LeftoverStore {
  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore.instance
      .collection(kLeftoversCollection)
      .doc(kLeftoversDocId);

  @override
  Future<List<Leftover>> load() async {
    final snap = await _doc.get();
    final data = snap.data();
    final raw = (data?['items'] as List?) ?? const [];
    final list = <Leftover>[
      for (final e in raw)
        if (e is Map)
          Leftover(
            (e['label'] as String?) ?? '',
            (e['length'] as num?)?.toDouble() ?? 0,
          ),
    ]..removeWhere((l) => l.length <= 0);
    if (list.isNotEmpty) return list;
    // 서버가 비어 있으면, 폰에 있던 잔재를 한 번 옮긴다(예전 자료를 잃지 않게).
    return _moveFromPhoneIfNeeded();
  }

  Future<List<Leftover>> _moveFromPhoneIfNeeded() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getBool(kLeftoversMovedPrefsKey) == true) return const [];
      final old = await PrefsLeftoverStore().load();
      if (old.isEmpty) {
        await p.setBool(kLeftoversMovedPrefsKey, true);
        return const [];
      }
      await save(old);
      await p.setBool(kLeftoversMovedPrefsKey, true);
      return old;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> save(List<Leftover> all) async {
    // 통신이 없으면 서버 확인이 영영 안 끝나 "잘랐습니다" 단추가 멈췄다. 폰에 먼저 적히므로
    // 8초 넘으면 그냥 진행한다(통신되면 올라간다).
    await _doc
        .set({
          'items': [
            for (final l in all) {'label': l.label, 'length': l.length},
          ],
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 8), onTimeout: () {});
  }
}

// 앱이 쓰는 저장소(테스트는 setUp에서 PrefsLeftoverStore로 바꿔 쓴다).
LeftoverStore leftoverStore = FirestoreLeftoverStore();

Future<List<Leftover>> loadLeftovers() => leftoverStore.load();

Future<void> saveLeftovers(List<Leftover> all) => leftoverStore.save(all);

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

// 재단 계획에서 "여러 길이 섞어 쓰기"를 켜 두었을 때 고른 원자재 길이들(꺼져 있으면 빈 목록).
// 튜브 컷팅 화면과 절단 지시서(PDF)가 같은 설정을 쓴다.
const String kTubeMixPrefsKey = 'cutting_mix_lengths_v1';

Future<List<double>> loadMixLengths([String key = kTubeMixPrefsKey]) async {
  final p = await SharedPreferences.getInstance();
  return [
    for (final v in p.getStringList(key) ?? const <String>[])
      if (double.tryParse(v) != null && double.parse(v) > 0) double.parse(v),
  ];
}

/// 규격별 잔재 요약(몇 개 · 합쳐 몇 mm · 가장 긴 것).
class LeftoverSummary {
  final int count;
  final double totalMm;
  final double longestMm;

  /// 화면에 보여 줄 규격 이름(다듬기 전 그대로).
  final String label;

  const LeftoverSummary({
    required this.count,
    required this.totalMm,
    required this.longestMm,
    this.label = '',
  });

  /// 자재 줄에 한 줄로 붙일 글.
  String get short => "잔재 $count개 · 가장 긴 것 ${longestMm.round()}mm";
}

/// 잔재를 규격별로 묶는다. 열쇠는 규격 이름을 다듬은 것.
///
/// 🚀 [추가] 예전에는 잔재를 따로 골라 봐야 했다. 재고를 보면서 "이 규격에
/// 쓸 만한 잔재가 있나"를 같이 보려고 묶어 둔다.
Map<String, LeftoverSummary> leftoverSummaryBySpec(List<Leftover> all) {
  final byKey = <String, List<double>>{};
  final labels = <String, String>{};
  for (final l in all) {
    final key = leftoverSpecKey(l.label);
    if (key.isEmpty || l.length <= 0) continue;
    (byKey[key] ??= <double>[]).add(l.length);
    labels.putIfAbsent(key, () => l.label.trim());
  }
  return {
    for (final e in byKey.entries)
      e.key: LeftoverSummary(
        count: e.value.length,
        totalMm: e.value.fold(0.0, (a, b) => a + b),
        longestMm: e.value.fold(0.0, (a, b) => b > a ? b : a),
        label: labels[e.key] ?? e.key,
      ),
  };
}

/// 규격 이름을 견주기 좋게 다듬는다(빈칸·따옴표·대소문자).
String leftoverSpecKey(String label) {
  return label
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('″', '"')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
}

/// 자재 이름에 맞는 잔재 요약을 찾는다.
/// 자재 이름이 "튜브 3/8"" 처럼 규격을 담고 있으면 그대로 맞고,
/// 규격이 이름 안에 들어 있기만 해도(예: "찬넬 75x40x5") 찾아 준다.
LeftoverSummary? leftoverFor(
  String materialName,
  Map<String, LeftoverSummary> bySpec,
) {
  final name = leftoverSpecKey(materialName);
  if (name.isEmpty) return null;
  final direct = bySpec[name];
  if (direct != null) return direct;
  for (final e in bySpec.entries) {
    if (e.key.isNotEmpty && name.contains(e.key)) return e.value;
  }
  return null;
}
