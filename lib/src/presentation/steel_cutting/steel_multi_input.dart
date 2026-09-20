import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../tube_cutting/cutting_math.dart' show fmtMm;

// ── 한 줄로 여러 길이 입력 ──
// 같은 규격에 "500x3, 800x2, 1200"처럼 적으면 500mm 3개, 800mm 2개, 1200mm 1개로 읽는다.
// 구분은 쉼표·세미콜론·줄바꿈, 길이와 개수 사이는 x · X · × · * 중 아무거나("개"는 붙여도 된다).
// 소수 길이는 점으로 적는다(쉼표는 구분으로 쓰므로).
class MultiLengthEntry {
  final double length;
  final int qty;
  const MultiLengthEntry(this.length, this.qty);
}

class MultiLengthParse {
  final List<MultiLengthEntry> entries;
  final List<String> bad; // 읽지 못한 토막(그대로)
  const MultiLengthParse(this.entries, this.bad);

  bool get isEmpty => entries.isEmpty && bad.isEmpty;
  int get pieces => entries.fold(0, (s, e) => s + e.qty);
  double get totalMm => entries.fold(0.0, (s, e) => s + e.length * e.qty);
}

final RegExp _multiToken = RegExp(
  r'^(\d+(?:\.\d+)?)\s*(?:mm)?\s*(?:[xX×*]\s*(\d+)\s*(?:개|ea|EA)?)?$',
);

MultiLengthParse parseMultiLengths(String text) {
  final entries = <MultiLengthEntry>[];
  final bad = <String>[];
  for (final raw in text.split(RegExp(r'[,;\n]+'))) {
    final t = raw.trim();
    if (t.isEmpty) continue;
    final m = _multiToken.firstMatch(t);
    if (m == null) {
      bad.add(t);
      continue;
    }
    final len = double.parse(m.group(1)!);
    final qty = m.group(2) == null ? 1 : int.parse(m.group(2)!);
    if (len <= 0 || qty <= 0 || qty > 9999) {
      bad.add(t);
      continue;
    }
    entries.add(MultiLengthEntry(len, qty));
  }
  return MultiLengthParse(entries, bad);
}

// "3건 · 총 6개 · 3300mm" 같은 미리보기 글.
String multiPreviewText(MultiLengthParse p) {
  if (p.entries.isEmpty) return '';
  return '${p.entries.length}건 · 총 ${p.pieces}개 · ${fmtMm(p.totalMm)}mm';
}

// ── 자주 쓰는 길이 ──
// 항목을 저장할 때마다 그 길이를 센다. 항목 추가창에서 많이 쓴 길이 몇 개를 칩으로 보여 준다.
const String kSteelLengthFreqPrefsKey = 'steel_length_freq_v1';
const int kMaxSteelLengthFreq = 40;

String _lenKey(double v) => fmtMm(v);

Future<Map<String, int>> _loadFreq() async {
  try {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(kSteelLengthFreqPrefsKey);
    if (s == null) return {};
    final m = jsonDecode(s) as Map<String, dynamic>;
    return {for (final e in m.entries) e.key: (e.value as num).toInt()};
  } catch (_) {
    return {};
  }
}

// 규격별로도 따로 센다(앵글에 쓰는 길이와 찬넬에 쓰는 길이가 다르다). 규격 이름 → {길이: 횟수}.
const String kSteelLengthFreqByShapePrefsKey = 'steel_length_freq_by_shape_v1';
const int kMaxSteelShapesInFreq = 30;

Future<Map<String, Map<String, int>>> _loadFreqByShape() async {
  try {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(kSteelLengthFreqByShapePrefsKey);
    if (s == null) return {};
    final m = jsonDecode(s) as Map<String, dynamic>;
    return {
      for (final e in m.entries)
        e.key: {
          for (final f in (e.value as Map<String, dynamic>).entries)
            f.key: (f.value as num).toInt(),
        },
    };
  } catch (_) {
    return {};
  }
}

// 길이 [lengths]를 한 번씩 센다(여러 개를 한 번에 넣어도 한 번씩). 규격 이름을 주면 그 규격에서도 센다.
Future<void> bumpSteelLengthUse(
  Iterable<double> lengths, {
  String shapeLabel = '',
}) async {
  final freq = await _loadFreq();
  for (final v in lengths) {
    if (v <= 0) continue;
    freq.update(_lenKey(v), (c) => c + 1, ifAbsent: () => 1);
  }
  _trim(freq, kMaxSteelLengthFreq);
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(kSteelLengthFreqPrefsKey, jsonEncode(freq));
  } catch (_) {}
  if (shapeLabel.trim().isEmpty) return;
  final byShape = await _loadFreqByShape();
  final mine = byShape.putIfAbsent(shapeLabel, () => {});
  for (final v in lengths) {
    if (v <= 0) continue;
    mine.update(_lenKey(v), (c) => c + 1, ifAbsent: () => 1);
  }
  _trim(mine, kMaxSteelLengthFreq);
  // 규격이 너무 많이 쌓이면 적게 쓴 규격부터 버린다.
  if (byShape.length > kMaxSteelShapesInFreq) {
    final keep = byShape.entries.toList()
      ..sort((a, b) => _sum(b.value).compareTo(_sum(a.value)));
    byShape
      ..clear()
      ..addEntries(keep.take(kMaxSteelShapesInFreq));
  }
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(kSteelLengthFreqByShapePrefsKey, jsonEncode(byShape));
  } catch (_) {}
}

int _sum(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);

void _trim(Map<String, int> freq, int max) {
  if (freq.length <= max) return;
  final keep = freq.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  freq
    ..clear()
    ..addEntries(keep.take(max));
}

// 많이 쓴 순서(같으면 짧은 길이 먼저). 두 번 이상 쓴 길이만 보여 준다(한 번 쓴 길이는 우연일 수 있어서).
List<double> _top(Map<String, int> freq, int n) {
  final list = [
    for (final e in freq.entries)
      if (e.value >= 2 && double.tryParse(e.key) != null)
        (double.parse(e.key), e.value),
  ]..sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.compareTo(b.$1));
  return [for (final e in list.take(n)) e.$1];
}

// 자주 쓰는 길이 [n]개. 규격을 주면 그 규격에서 많이 쓴 길이를 먼저 주고, 모자라면 규격을 가리지 않고 많이
// 쓴 길이로 채운다(규격별로 세기 시작하기 전에 쌓아 둔 것도 계속 쓸 수 있다).
Future<List<double>> loadTopSteelLengths({
  int n = 5,
  String shapeLabel = '',
}) async {
  final out = <double>[];
  if (shapeLabel.trim().isNotEmpty) {
    final byShape = await _loadFreqByShape();
    out.addAll(_top(byShape[shapeLabel] ?? const {}, n));
  }
  for (final v in _top(await _loadFreq(), n)) {
    if (out.length >= n) break;
    if (!out.contains(v)) out.add(v);
  }
  return out;
}
