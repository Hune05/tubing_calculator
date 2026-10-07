// 공학용 계산기 안의 "단위 환산" — 갤럭시 계산기가 계산기 안에 내장한 단위
// 변환기 같은 빠른 도구. 자세한 표(배관 호칭·전선 굵기·인치 분수 입력 등)는 이미
// 현장 자료 안 "단위 환산"(unit_converter_page.dart)에 따로 있으니 여기서는 그
// 자료(unit_defs.dart)를 그대로 가져다 써서, 자주 쓰는 몇 분류만 숫자 두 칸(보내는
// 값 → 바뀐 값)으로 빠르게 바꾼다. 분수 입력 같은 특수 칸(textInput)은 빼고 숫자만
// 있는 단위만 고른다.
//
// 분류 고르기는 칩을 여러 줄로 늘어놓지 않고 슬라이더 한 줄로(자리를 덜 차지하게).
// 색은 강한 브랜드 색 대신 회색 계열(무채색)만 쓴다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/theme/field_view.dart';
import '../unit_converter/unit_defs.dart';
import '../common/number_text.dart';

/// 이 화면에서 고를 수 있는 분류(현장에서 자주 쓰는 것 위주).
final List<UnitCategory> kMiniConvertCategories = [
  kLength,
  kMass,
  kPressure,
  kTemperature,
  kArea,
  kVolume,
  kAngle,
  kForce,
  kTorque,
  kPower,
  kEnergy,
];

class MiniUnitConverterPage extends StatefulWidget {
  const MiniUnitConverterPage({super.key});

  @override
  State<MiniUnitConverterPage> createState() => _MiniUnitConverterPageState();
}

class _MiniUnitConverterPageState extends State<MiniUnitConverterPage>
    with RecentCalcHistoryMixin<MiniUnitConverterPage> {
  /// 최근 계산 기록을 폰에 이틀 동안 남기는 칸.
  @override
  String? get calcHistoryStorageKey => 'calc_history_mini_unit';

  late UnitCategory _cat = kMiniConvertCategories.first;
  late List<UnitDef> _units = _numericUnits(_cat);
  late UnitDef _from = _units[0];
  late UnitDef _to = _units.length > 1 ? _units[1] : _units[0];
  final _ctrl = TextEditingController(text: '1');

  /// 기록을 누르면 그때 분류·단위·값으로 되돌린다.
  @override
  String? calcRestoreSnapshot() => jsonEncode({
    'c': _cat.id,
    'f': _from.id,
    't': _to.id,
    'v': _ctrl.text,
  });

  @override
  void calcRestoreApply(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    final cat = kMiniConvertCategories.firstWhere((c) => c.id == m['c']);
    final units = _numericUnits(cat);
    final from = units.firstWhere((u) => u.id == m['f']);
    final to = units.firstWhere((u) => u.id == m['t']);
    _cat = cat;
    _units = units;
    _from = from;
    _to = to;
    _ctrl.text = m['v'] as String;
  }

  List<UnitDef> _numericUnits(UnitCategory c) =>
      c.units.where((u) => !u.textInput).toList();

  double? get _fromValue => parseNumberText(_ctrl.text);

  String get _resultText {
    final v = _fromValue;
    if (v == null) return '—';
    final base = _from.toBase(v);
    // 절대영도보다 낮은 온도처럼 있을 수 없는 값은 비운다(10-07, 큰 단위 환산 화면과 같게).
    if (_cat.belowMin(base)) return '—';
    final r = _to.fromBase(base);
    if (r.isNaN || r.isInfinite) return '—';
    return formatNumber(r);
  }

  void _pickCategory(UnitCategory c) {
    setState(() {
      _cat = c;
      _units = _numericUnits(c);
      _from = _units[0];
      _to = _units.length > 1 ? _units[1] : _units[0];
    });
  }

  void _swap() {
    HapticFeedback.selectionClick();
    setState(() {
      final t = _from;
      _from = _to;
      _to = t;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultText = _resultText;
    if (resultText != '—') {
      logCalc(
        '${_from.symbol} → ${_to.symbol} (${_cat.label})',
        '${_ctrl.text.trim()} ${_from.symbol} → $resultText ${_to.symbol}',
      );
    }
    return FieldViewTheme(
    child: Scaffold(
      backgroundColor: fc.surface,
      appBar: AppBar(
        backgroundColor: fc.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: fc.text,
        title: Text(
          "단위 환산",
          style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
        ),
        actions: [calcHistoryButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _categorySlider(),
            const SizedBox(height: 12),
            _unitCard(
              label: '입력값',
              unit: _from,
              onUnitChanged: (u) => setState(() => _from = u),
              child: TextField(
                key: const Key('unit_from_value'),
                controller: _ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: fc.text,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Center(
              child: IconButton(
                key: const Key('unit_swap'),
                onPressed: _swap,
                icon: Icon(Icons.swap_vert, color: fc.brand),
                tooltip: '단위 맞바꾸기',
              ),
            ),
            _unitCard(
              label: '환산값',
              unit: _to,
              onUnitChanged: (u) => setState(() => _to = u),
              child: Text(
                _resultText,
                key: const Key('unit_to_value'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: fc.brand,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  /// 분류 고르기: 칩을 여러 줄로 늘어놓는 대신 슬라이더 한 줄로(자리를 덜 차지함).
  /// 회색 배경 없이 트랙·손잡이만 있고, 색은 무채색(회색 계열)만 쓴다.
  Widget _categorySlider() {
    final idx = kMiniConvertCategories.indexOf(_cat).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _cat.label,
          key: const Key('unit_cat_label'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: fc.text,
          ),
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: fc.textFaint,
            inactiveTrackColor: fc.line,
            thumbColor: fc.textSub,
            overlayColor: fc.textSub.withValues(alpha: 0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            key: const Key('unit_cat_slider'),
            min: 0,
            max: (kMiniConvertCategories.length - 1).toDouble(),
            divisions: kMiniConvertCategories.length - 1,
            value: idx,
            onChanged: (v) => _pickCategory(kMiniConvertCategories[v.round()]),
          ),
        ),
      ],
    );
  }

  Widget _unitCard({
    required String label,
    required UnitDef unit,
    required ValueChanged<UnitDef> onUnitChanged,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: fc.fill,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: fc.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: fc.textSub)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: child),
            DropdownButton<UnitDef>(
              value: unit,
              underline: const SizedBox.shrink(),
              items: [
                for (final u in _units)
                  DropdownMenuItem(
                    value: u,
                    child: Text(
                      u.symbol,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: fc.text,
                      ),
                    ),
                  ),
              ],
              onChanged: (u) {
                if (u != null) onUnitChanged(u);
              },
            ),
          ],
        ),
      ],
    ),
  );
}
