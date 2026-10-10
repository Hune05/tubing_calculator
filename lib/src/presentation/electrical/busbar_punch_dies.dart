// 접지바 가공(10-10): 내 펀치 금형. 현장 절곡·펀칭기에 있는 금형 지름을 저장해 두면 구멍 지름 칩이 그 값으로
// 나온다. 비우면 기본 칩(볼트 틈새 구멍 M8 9 · M10 11 · M12 13.5 · M16 17.5). 저장은 이 기기만.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../calculator/widgets/app_dialog.dart';

/// 저장 칸 이름.
const String kPunchDiesKey = 'busbar_punch_dies_v1';

/// 금형을 저장하지 않았을 때 쓰는 구멍 지름 칩(mm): KS B ISO 273 보통급 볼트 틈새 구멍.
const List<double> kDefaultPunchDies = [9, 11, 13.5, 17.5];

/// 칩에 보이는 이름: 'φ11 (M10)'. 볼트 틈새 구멍과 같은 지름이면 볼트 호칭을 붙인다.
String punchDieLabel(double d) {
  const bolts = <(double, String)>[
    (6.6, 'M6'),
    (9, 'M8'),
    (11, 'M10'),
    (13.5, 'M12'),
    (17.5, 'M16'),
    (22, 'M20'),
  ];
  final s = _f(d);
  for (final (v, name) in bolts) {
    if ((v - d).abs() < 1e-9) return 'φ$s ($name)';
  }
  return 'φ$s';
}

String _f(double v) {
  var s = v.toStringAsFixed(2);
  while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// 글('9, 11, 13.5')을 지름 목록으로. 0 이하·숫자 아닌 것은 빼고, 같은 값은 하나만, 작은 것부터.
List<double> parsePunchDies(String text) {
  final out = <double>{};
  for (final part in text.split(RegExp(r'[,\s·/]+'))) {
    final v = double.tryParse(part.trim());
    if (v != null && v > 0 && v < 100) out.add(v);
  }
  return out.toList()..sort();
}

Future<List<double>> readPunchDies() async {
  try {
    final p = await SharedPreferences.getInstance();
    final l = p.getStringList(kPunchDiesKey);
    if (l == null) return const [];
    return parsePunchDies(l.join(','));
  } catch (_) {
    return const [];
  }
}

Future<void> writePunchDies(List<double> dies) async {
  try {
    final p = await SharedPreferences.getInstance();
    if (dies.isEmpty) {
      await p.remove(kPunchDiesKey);
    } else {
      await p.setStringList(kPunchDiesKey, [for (final d in dies) _f(d)]);
    }
  } catch (_) {}
}

/// 금형 지름을 고치는 창. 저장한 목록을 돌려준다(취소하면 null, 비우면 빈 목록 = 기본 칩).
Future<List<double>?> openPunchDies(
  BuildContext context,
  List<double> current,
) async {
  final r = await showDialog<List<double>>(
    context: context,
    builder: (_) => _DiesDialog(current: current),
  );
  if (r != null) await writePunchDies(r);
  return r;
}

class _DiesDialog extends StatefulWidget {
  const _DiesDialog({required this.current});
  final List<double> current;

  @override
  State<_DiesDialog> createState() => _DiesDialogState();
}

class _DiesDialogState extends State<_DiesDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.current.map(_f).join(', '),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: '내 펀치 금형',
    okText: '저장',
    okKey: const Key('gb_dies_ok'),
    onCancel: () => Navigator.pop(context),
    onOk: () => Navigator.pop(context, parsePunchDies(_c.text)),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('gb_dies_field'),
          controller: _c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: appFieldTextStyle,
          decoration: appFieldDecoration(
            '금형 지름 (mm, 쉼표로 나눔)',
            hint: '예) 9, 11, 13.5, 17.5',
          ),
        ),
        const SizedBox(height: 12),
        AppDialog.message(
          '기계에 있는 펀치 금형 지름을 넣으면 구멍 지름 칩이 이 값으로 바뀝니다. 비우고 저장하면 기본 칩(M8 9 · M10 11 · M12 13.5 · M16 17.5)으로 돌아갑니다.',
        ),
      ],
    ),
  );
}
