// 단관 컷팅 화면: 같은 길이의 짧은 관을 여러 개 자를 때 원자재 몇 본이 들고, 줄자의 어느 눈금에서
// 자르는지 바로 알려 준다. 라인(부속 구성)을 만들지 않고 "길이 × 개수"만 넣는다.
// 계산은 short_pipe_plan.dart(배치는 cutting_optimizer.dart)가 하고, 여기서는 입력·그리기·보내기만 한다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cutting_action_bar.dart';
import '../cutting_math.dart' show fmtMm, parseLengthInput;
import '../cutting_optimizer.dart';
import '../cutting_plan_settings.dart';
import '../cutting_theme.dart';
import '../short_pipe_plan.dart';

const String kShortPipeDraftKey = 'short_pipe_draft_v1';
const String _kStockKey = 'cutting_stock_length';
const String _kKerfKey = 'cutting_blade_kerf';

class _Row {
  final TextEditingController length;
  final TextEditingController qty;
  _Row({String length = '', String qty = ''})
    : length = TextEditingController(text: length),
      qty = TextEditingController(text: qty);
  void dispose() {
    length.dispose();
    qty.dispose();
  }
}

class ShortPipeCuttingPage extends StatefulWidget {
  const ShortPipeCuttingPage({super.key});

  @override
  State<ShortPipeCuttingPage> createState() => _ShortPipeCuttingPageState();
}

class _ShortPipeCuttingPageState extends State<ShortPipeCuttingPage> {
  final _stock = TextEditingController(text: '6000');
  final _kerf = TextEditingController(text: '0');
  final _trim = TextEditingController(text: '0');
  final _ded = TextEditingController(text: '0');
  bool _centerToCenter = false;
  final List<_Row> _rows = [_Row()];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _stock.dispose();
    _kerf.dispose();
    _trim.dispose();
    _ded.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  String _num(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  // 처음에는 튜브 컷팅에서 쓰던 원자재 길이·톱날·끝 다듬기를 이어받고, 이 화면에서 적던 것이 있으면 그것을 되살린다.
  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final plan = await loadCutPlanSettings();
      final draft = p.getString(kShortPipeDraftKey);
      if (!mounted) return;
      setState(() {
        final stock = p.getDouble(_kStockKey);
        if (stock != null && stock > 0) _stock.text = _num(stock);
        final kerf = p.getDouble(_kKerfKey);
        if (kerf != null && kerf >= 0) _kerf.text = _num(kerf);
        if (plan.endTrim > 0) _trim.text = _num(plan.endTrim);
        if (draft != null) {
          try {
            final m = jsonDecode(draft) as Map<String, dynamic>;
            _stock.text = (m['stock'] ?? _stock.text).toString();
            _kerf.text = (m['kerf'] ?? _kerf.text).toString();
            _trim.text = (m['trim'] ?? _trim.text).toString();
            _ded.text = (m['ded'] ?? _ded.text).toString();
            _centerToCenter = m['c2c'] == true;
            final rows = (m['rows'] as List?) ?? const [];
            if (rows.isNotEmpty) {
              for (final r in _rows) {
                r.dispose();
              }
              _rows
                ..clear()
                ..addAll([
                  for (final r in rows)
                    _Row(
                      length: ((r as Map)['len'] ?? '').toString(),
                      qty: (r['qty'] ?? '').toString(),
                    ),
                ]);
            }
          } catch (_) {}
        }
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _save() async {
    if (!_loaded) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        kShortPipeDraftKey,
        jsonEncode({
          'stock': _stock.text,
          'kerf': _kerf.text,
          'trim': _trim.text,
          'ded': _ded.text,
          'c2c': _centerToCenter,
          'rows': [
            for (final r in _rows) {'len': r.length.text, 'qty': r.qty.text},
          ],
        }),
      );
    } catch (_) {}
  }

  void _changed([VoidCallback? fn]) {
    setState(() => fn?.call());
    _save();
  }

  double? _d(TextEditingController c) => parseLengthInput(c.text).value;

  /// 입력으로 만든 계획. 원자재 길이를 못 읽으면 null.
  ShortPipePlan? _plan() {
    final stock = _d(_stock);
    if (stock == null || stock <= 0) return null;
    final rows = <ShortPipeRow>[];
    for (final r in _rows) {
      final len = _d(r.length);
      final q = int.tryParse(r.qty.text.trim());
      if (len == null && (q == null || q <= 0)) continue; // 빈 줄
      rows.add(ShortPipeRow(len ?? 0, q == null || q < 0 ? 0 : q));
    }
    if (rows.every((r) => r.qty <= 0)) return null;
    return planShortPipes(
      rows,
      stockLength: stock,
      kerf: _d(_kerf) ?? 0,
      endTrim: _d(_trim) ?? 0,
      centerToCenter: _centerToCenter,
      endDeduction: _d(_ded) ?? 0,
    );
  }

  Future<void> _copy(ShortPipePlan plan) async {
    await Clipboard.setData(ClipboardData(text: shortPipePlanText(plan)));
    if (mounted) showCuttingSnack(context, '글을 복사했습니다.');
  }

  Future<void> _kakao(ShortPipePlan plan) async {
    final text = shortPipePlanText(plan);
    final ok = await kakaoSender(text);
    if (!ok) await textSharer(text);
  }

  // ── 입력 위젯 ──

  InputDecoration _deco(String label, {String? suffix, String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: true,
        fillColor: CuttingColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );

  Widget _numField(
    TextEditingController c,
    String label, {
    String? suffix,
    Key? key,
    bool integer = false,
  }) => TextField(
    key: key,
    controller: c,
    keyboardType: TextInputType.numberWithOptions(decimal: !integer),
    inputFormatters: [
      FilteringTextInputFormatter.allow(
        integer ? RegExp(r'[0-9]') : RegExp(r'[0-9.,]'),
      ),
    ],
    onChanged: (_) => _changed(),
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    decoration: _deco(label, suffix: suffix),
  );

  Widget _card({required String title, required Widget child, Widget? trailing}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CuttingColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CuttingColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: CuttingColors.textPrimary,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  Widget _settingsCard() => _card(
    title: '원자재와 톱',
    child: Column(
      children: [
        _numField(
          _stock,
          '원자재 길이',
          suffix: 'mm',
          key: const Key('sp_stock'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _numField(
                _kerf,
                '톱날 손실',
                suffix: 'mm',
                key: const Key('sp_kerf'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _numField(
                _trim,
                '끝 다듬기',
                suffix: 'mm',
                key: const Key('sp_trim'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _modeChip(String label, bool selected, VoidCallback onTap, Key key) =>
      ChoiceChip(
        key: key,
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: CuttingColors.primarySoft,
        backgroundColor: CuttingColors.surface,
        surfaceTintColor: Colors.transparent,
        side: BorderSide(
          color: selected ? CuttingColors.primary : CuttingColors.border,
        ),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          color: selected ? CuttingColors.primary : CuttingColors.textSecondary,
        ),
      );

  Widget _rowsCard() => _card(
    title: '자를 단관',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            _modeChip(
              '자를 길이 그대로',
              !_centerToCenter,
              () => _changed(() => _centerToCenter = false),
              const Key('sp_mode_cut'),
            ),
            _modeChip(
              '중심 간 거리(부속 공제)',
              _centerToCenter,
              () => _changed(() => _centerToCenter = true),
              const Key('sp_mode_c2c'),
            ),
          ],
        ),
        if (_centerToCenter) ...[
          const SizedBox(height: 10),
          _numField(
            _ded,
            '한쪽 부속 공제값 (양쪽에 같은 부속)',
            suffix: 'mm',
            key: const Key('sp_ded'),
          ),
        ],
        const SizedBox(height: 12),
        for (var i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _numField(
                    _rows[i].length,
                    _centerToCenter ? '중심 간 거리' : '길이',
                    suffix: 'mm',
                    key: Key('sp_len_$i'),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '×',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: CuttingColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _numField(
                    _rows[i].qty,
                    '개수',
                    suffix: '개',
                    key: Key('sp_qty_$i'),
                    integer: true,
                  ),
                ),
                IconButton(
                  key: Key('sp_del_$i'),
                  tooltip: '이 줄 지우기',
                  icon: const Icon(
                    Icons.remove_circle_outline_rounded,
                    color: CuttingColors.textSecondary,
                  ),
                  onPressed: _rows.length <= 1
                      ? null
                      : () => _changed(() => _rows.removeAt(i).dispose()),
                ),
              ],
            ),
          ),
        TextButton.icon(
          key: const Key('sp_add'),
          onPressed: () => _changed(() => _rows.add(_Row())),
          icon: const Icon(Icons.add_rounded),
          label: const Text('길이 줄 추가'),
        ),
      ],
    ),
  );

  // ── 결과 ──

  Widget _stat(String k, String v, {Color? color}) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color ?? CuttingColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          k,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: CuttingColors.textSecondary,
          ),
        ),
      ],
    ),
  );

  Widget _summaryCard(ShortPipePlan p) => _card(
    title: '결과',
    trailing: CutActionBar(
      actions: [
        CutActionSpec(
          key: const Key('sp_kakao'),
          label: '카톡 보내기',
          icon: const Icon(Icons.send_rounded, size: 18, color: Colors.black87),
          background: const Color(0xFFFEE500),
          onPressed: () => _kakao(p),
        ),
        CutActionSpec(
          key: const Key('sp_copy'),
          label: '글 복사',
          icon: const Icon(
            Icons.copy_rounded,
            size: 19,
            color: CuttingColors.primary,
          ),
          onPressed: () => _copy(p),
        ),
      ],
    ),
    child: Row(
      children: [
        _stat('원자재', '${p.barCount}본', color: CuttingColors.primary),
        _stat('단관', '${p.pieceCount}개'),
        _stat('이용률', '${(p.usage * 100).toStringAsFixed(0)}%'),
      ],
    ),
  );

  Widget _problemCard(List<String> problems) => Container(
    key: const Key('sp_problems'),
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: CuttingColors.dangerSoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: CuttingColors.danger.withValues(alpha: 0.4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final t in problems)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              t,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: CuttingColors.danger,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _barCard(int index, StockBarPlan bar, ShortPipePlan p) {
    final marks = barCutMarks(bar, p.kerf);
    final rest = bar.remainderWithKerf(p.kerf);
    final scale = bar.stockLength <= 0 ? 1.0 : bar.stockLength;
    int flexOf(double mm) => (mm / scale * 1000).round().clamp(1, 100000);
    final segs = <Widget>[];
    if (bar.trim > 0) {
      segs.add(
        Expanded(
          flex: flexOf(bar.trim),
          child: Container(color: CuttingColors.border),
        ),
      );
    }
    for (var i = 0; i < bar.pieces.length; i++) {
      final len = bar.pieces[i];
      segs.add(
        Expanded(
          flex: flexOf(len + (i == bar.pieces.length - 1 ? 0 : p.kerf)),
          child: Container(
            margin: const EdgeInsets.only(right: 1),
            alignment: Alignment.center,
            color: i.isEven
                ? CuttingColors.primary
                : CuttingColors.primary.withValues(alpha: 0.65),
            child: len / scale >= 0.07
                ? FittedBox(
                    child: Text(
                      fmtMm(len),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      );
    }
    if (rest > 0) {
      segs.add(
        Expanded(
          flex: flexOf(rest),
          child: Container(
            alignment: Alignment.center,
            color: CuttingColors.background,
          ),
        ),
      );
    }
    return Container(
      key: Key('sp_bar_$index'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CuttingColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CuttingColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  '${index + 1}번 원자재',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              if (rest >= 1)
                Text(
                  '잔재 ${fmtMm(rest.floorToDouble())}mm',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: rest >= kMinLeftoverMm
                        ? CuttingColors.success
                        : CuttingColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(height: 30, child: Row(children: segs)),
          ),
          const SizedBox(height: 10),
          for (final m in marks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${m.index + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: CuttingColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${fmtMm(m.length)}mm',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Text(
                    '자르는 선 ',
                    style: TextStyle(
                      fontSize: 12,
                      color: CuttingColors.textSecondary,
                    ),
                  ),
                  Text(
                    fmtMm(m.cutAt),
                    key: Key('sp_mark_${index}_${m.index}'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: CuttingColors.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan();
    return CuttingTheme(
      child: Scaffold(
        backgroundColor: CuttingColors.background,
        appBar: AppBar(
          backgroundColor: CuttingColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          title: const Text(
            '단관 컷팅',
            style: TextStyle(
              color: CuttingColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          iconTheme: const IconThemeData(color: CuttingColors.textPrimary),
        ),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _settingsCard(),
            _rowsCard(),
            if (plan == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '길이와 개수를 넣으면 원자재가 몇 본 들고 어디서 자르는지 나옵니다.',
                  key: Key('sp_empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CuttingColors.textSecondary),
                ),
              )
            else ...[
              if (plan.problems.isNotEmpty) _problemCard(plan.problems),
              if (plan.barCount > 0) _summaryCard(plan),
              for (var i = 0; i < plan.result.bars.length; i++)
                _barCard(i, plan.result.bars[i], plan),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
