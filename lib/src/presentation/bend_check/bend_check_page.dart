// 벤딩 실측 기록: 계산한 값과 실제로 잰 값을 남기고, 같은 규격·장비의 지난 차이를 참고로 본다.
// 계산 결과는 바뀌지 않는다(참고만).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_icon_set.dart';
import '../../core/theme/app_tokens.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'bend_check_model.dart';

Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

class BendCheckPage extends StatefulWidget {
  final Future<void> Function(String text) share;
  final DateTime Function()? now;
  const BendCheckPage({super.key, this.share = _defaultShare, this.now});

  @override
  State<BendCheckPage> createState() => _BendCheckPageState();
}

class _BendCheckPageState extends State<BendCheckPage> {
  final _group = TextEditingController();
  final _what = TextEditingController();
  final _calc = TextEditingController();
  final _actual = TextEditingController();
  final _note = TextEditingController();
  List<BendCheck> _all = [];
  bool _loaded = false;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    for (final c in [_group, _what, _calc, _actual, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _reload() async {
    final all = await loadBendChecks();
    if (!mounted) return;
    setState(() {
      _all = all;
      _loaded = true;
      // 처음에는 가장 최근에 쓴 묶음을 채워 둔다.
      if (_group.text.isEmpty && all.isNotEmpty) _group.text = all.first.group;
    });
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _save() async {
    final group = _group.text.trim();
    final calc = _num(_calc);
    final actual = _num(_actual);
    if (group.isEmpty) {
      _toast('튜브 규격·장비를 적어 주십시오');
      return;
    }
    if (calc == null || actual == null) {
      _toast('계산값과 실측값을 숫자로 적어 주십시오');
      return;
    }
    final at = _now;
    await addBendCheck(
      BendCheck(
        id: at.millisecondsSinceEpoch.toString(),
        at: at,
        group: group,
        what: _what.text.trim(),
        calc: calc,
        actual: actual,
        note: _note.text.trim(),
      ),
    );
    HapticFeedback.lightImpact();
    for (final c in [_what, _calc, _actual, _note]) {
      c.clear();
    }
    await _reload();
    _toast('저장했습니다');
  }

  Future<void> _delete(BendCheck c) async {
    await deleteBendCheck(c.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final group = _group.text.trim();
    final stats = group.isEmpty ? null : statsFor(_all, group);
    final calc = _num(_calc);
    final actual = _num(_actual);
    final live = (calc != null && actual != null) ? actual - calc : null;
    final names = groupNames(_all);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('벤딩 실측 기록'),
        actions: [
          IconButton(
            key: const Key('bendcheck_share'),
            tooltip: '카톡으로 보내기',
            icon: const Icon(AppIcons.share),
            onPressed: _all.isEmpty
                ? null
                : () => widget.share(buildBendCheckText(_all)),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const Text(
                  '계산한 값과 실제로 잰 값을 남기면, 같은 규격·장비의 지난 차이를 참고로 보여 줍니다. '
                  '마킹 계산 결과는 바뀌지 않습니다.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSub,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('bendcheck_group'),
                  controller: _group,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: '튜브 규격·장비',
                    hintText: '예: 1/2" SUS · 스웨이지락 수동',
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                ),
                if (names.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final n in names.take(6))
                        ActionChip(
                          key: Key('bendcheck_pick_$n'),
                          label: Text(n, style: const TextStyle(fontSize: 12)),
                          onPressed: () => setState(() => _group.text = n),
                        ),
                    ],
                  ),
                ],
                if (stats != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const Key('bendcheck_reference'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.brandSoft,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          referenceText(stats),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                        if (stats.n < kBendReliableCount)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '기록이 적어 참고만 하십시오.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSub,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  key: const Key('bendcheck_what'),
                  controller: _what,
                  decoration: const InputDecoration(
                    labelText: '무엇을 쟀는지 (선택)',
                    hintText: '예: 90° 1번 마킹',
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _numField('bendcheck_calc', _calc, '계산값 (mm)')),
                    const SizedBox(width: 10),
                    Expanded(child: _numField('bendcheck_actual', _actual, '실측값 (mm)')),
                  ],
                ),
                if (live != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '차이 (실측 − 계산): ${signedMm(live)}',
                      key: const Key('bendcheck_live'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: live.abs() < 0.05
                            ? AppColors.ok
                            : (live > 0 ? AppColors.caution : AppColors.brand),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('bendcheck_note'),
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: '메모 (선택)',
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('bendcheck_save'),
                  onPressed: _save,
                  child: const Text('기록 저장'),
                ),
                const SizedBox(height: 20),
                const Text('지난 기록', style: AppText.title),
                const SizedBox(height: 8),
                if (_all.isEmpty)
                  const Text('아직 기록이 없습니다', style: AppText.sub)
                else
                  for (final c in _all) _recordTile(c),
              ],
            ),
    );
  }

  Widget _numField(String key, TextEditingController c, String label) =>
      TextField(
        key: Key(key),
        controller: c,
        onChanged: (_) => setState(() {}),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.surface,
        ),
      );

  Widget _recordTile(BendCheck c) {
    final d = c.diff;
    return Dismissible(
      key: ObjectKey(c),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.danger,
        child: const Icon(AppIcons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _delete(c),
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        elevation: 0,
        color: AppColors.surface,
        child: ListTile(
          key: Key('bendcheck_record_${c.id}'),
          title: Text(
            '${c.at.month}/${c.at.day} · ${c.group}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            [
              if (c.what.isNotEmpty) c.what,
              '계산 ${_fmt(c.calc)} → 실측 ${_fmt(c.actual)}',
              if (c.note.isNotEmpty) c.note,
            ].join(' · '),
          ),
          trailing: Text(
            signedMm(d),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: d.abs() < 0.05
                  ? AppColors.ok
                  : (d > 0 ? AppColors.caution : AppColors.brand),
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(double v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? r.round().toString() : r.toStringAsFixed(1);
  }
}
