// 철판 가공 설정(10-10, 사용자: "설정 페이지 필요하면 집어넣어, 온갖 설정 다 때려 박지 말고"):
// 작업 화면·입력 창에 섞여 있던 설정을 한곳에 — 자주 쓰는 홀 지름·기본 홀 지름, 재질별 두께 단추, 원판(크기·간격·여유),
// 그리드, 센터선 처음 표시, 업체 공제값(두께별). 저장은 이 기기만. 레이저 절단·절단 + 절곡·스케치가 같이 쓴다.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/app_components.dart'
    show AppSnackKind, showAppSnack;
import '../../core/theme/app_icon_set.dart';
import '../../core/theme/field_view.dart';
import '../electrical/busbar_punch_dies.dart'
    show kDefaultPunchDies, parsePunchDies, punchDieLabel, readPunchDies;
import '../steel_bracket/design_request.dart';
import 'plate_calc.dart';
import 'plate_ui.dart';

const String kPlateSettingsKey = 'plate_settings_v1';
const String kPlateGridKey = 'plate_editor_grid_v1';
const String kPlateCenterKey = 'plate_center_lines_v1';

/// 그림·가공 도면에 홀 크기 글("4-φ13.5", "장공 13.5×40")을 다는가(10-11, 처음은 적용).
const String kPlateHoleSizeKey = 'plate_hole_sizes_v1';
const String kPlateBendTableKey = 'plate_bend_table_v1';

/// 원판(자재 판) 크기(이름, 가로, 세로 mm).
const List<(String, String, double, double)> kPlateSheets = [
  ('48', '4×8 (1219×2438)', 1219, 2438),
  ('510', '5×10 (1524×3048)', 1524, 3048),
];

/// 재질별 두께 단추 처음 값(흔히 쓰는 두께, mm). 업체 재고에 맞춰 설정에서 바꾼다.
const Map<PlateMaterial, List<String>> kPlateThicknessDefaults = {
  PlateMaterial.steel: ['1.6', '2.3', '3.2', '4.5', '6', '9'],
  PlateMaterial.stainless: ['1', '1.5', '2', '3', '4', '5'],
  PlateMaterial.aluminum: ['1', '1.5', '2', '3', '4', '5'],
};

String _f(double v) {
  var s = v.toStringAsFixed(2);
  while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// 업체 공제값 표의 두께 키("4.5", "1.25"). 저장·찾기가 같은 것을 쓴다(점검 52: 화면은 소수 첫째 자리로 찾아
/// 1.25T 업체 값이 안 붙었다).
String plateThicknessKey(double t) => _f(t);

/// 두께 글('1.6, 2.3 3.2')을 단추 목록으로(숫자만, 같은 값 하나, 작은 것부터).
List<String> parsePlateThicknesses(String text) {
  final out = <double>{};
  for (final part in text.split(RegExp(r'[,\s·/]+'))) {
    final v = double.tryParse(part.trim());
    if (v != null && v > 0 && v < 100) out.add(v);
  }
  return [for (final v in out.toList()..sort()) _f(v)];
}

class PlateSettings {
  /// 자주 쓰는 홀 지름(홀 창의 지름 단추)과 홀 추가 기본 지름.
  final List<double> dias;
  final double defaultDia;

  /// 재질별 두께 단추.
  final Map<PlateMaterial, List<String>> thick;

  /// 원판: 48 · 510 · custom, 직접 넣은 가로·세로, 부품 간격, 가장자리 여유.
  final String sheet;
  final double sheetW, sheetH, gap, margin;

  const PlateSettings({
    this.dias = kDefaultPunchDies,
    this.defaultDia = 13.5,
    this.thick = kPlateThicknessDefaults,
    this.sheet = '48',
    this.sheetW = 1219,
    this.sheetH = 2438,
    this.gap = 5,
    this.margin = 10,
  });

  static const defaults = PlateSettings();

  (double, double) get sheetSize {
    for (final (id, _, w, h) in kPlateSheets) {
      if (id == sheet) return (w, h);
    }
    return (sheetW, sheetH);
  }

  String get sheetName {
    for (final (id, name, _, _) in kPlateSheets) {
      if (id == sheet) return name;
    }
    return '${_f(sheetW)}×${_f(sheetH)}';
  }

  PlateSettings copyWith({
    List<double>? dias,
    double? defaultDia,
    Map<PlateMaterial, List<String>>? thick,
    String? sheet,
    double? sheetW,
    double? sheetH,
    double? gap,
    double? margin,
  }) => PlateSettings(
    dias: dias ?? this.dias,
    defaultDia: defaultDia ?? this.defaultDia,
    thick: thick ?? this.thick,
    sheet: sheet ?? this.sheet,
    sheetW: sheetW ?? this.sheetW,
    sheetH: sheetH ?? this.sheetH,
    gap: gap ?? this.gap,
    margin: margin ?? this.margin,
  );

  Map<String, Object> toJson() => {
    'dias': dias,
    'dia': defaultDia,
    'thick': {for (final e in thick.entries) e.key.name: e.value},
    'sheet': sheet,
    'sw': sheetW,
    'sh': sheetH,
    'gap': gap,
    'margin': margin,
  };

  static PlateSettings fromJson(Object? o, {List<double>? fallbackDias}) {
    if (o is! Map) {
      return PlateSettings(
        dias: fallbackDias != null && fallbackDias.isNotEmpty
            ? fallbackDias
            : kDefaultPunchDies,
      );
    }
    double n(Object? v, double d) => v is num && v > 0 ? v.toDouble() : d;
    final ds = o['dias'];
    final th = o['thick'];
    return PlateSettings(
      dias: ds is List
          ? parsePunchDies(ds.join(','))
          : (fallbackDias ?? kDefaultPunchDies),
      defaultDia: n(o['dia'], 13.5),
      thick: {
        for (final m in PlateMaterial.values)
          m: th is Map && th[m.name] is List
              ? [for (final v in th[m.name] as List) '$v']
              : kPlateThicknessDefaults[m]!,
      },
      sheet: o['sheet'] is String ? o['sheet'] as String : '48',
      sheetW: n(o['sw'], 1219),
      sheetH: n(o['sh'], 2438),
      gap: o['gap'] is num && (o['gap'] as num) >= 0
          ? (o['gap'] as num).toDouble()
          : 5,
      margin: o['margin'] is num && (o['margin'] as num) >= 0
          ? (o['margin'] as num).toDouble()
          : 10,
    );
  }

  /// 읽기. 처음이면 자주 쓰는 지름은 접지바 "내 펀치 금형"이 있으면 그것, 없으면 볼트 틈새 구멍 지름.
  static Future<PlateSettings> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(kPlateSettingsKey);
      if (raw == null) {
        return PlateSettings.fromJson(
          null,
          fallbackDias: await readPunchDies(),
        );
      }
      return PlateSettings.fromJson(jsonDecode(raw));
    } catch (_) {
      return defaults;
    }
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(kPlateSettingsKey, jsonEncode(toJson()));
    } catch (_) {}
  }
}

/// 두께별 업체 공제값(두께 글 → (내R, 90° 공제값)) 읽기·쓰기.
Future<Map<String, (double, double)>> readPlateBendTable() async {
  try {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(kPlateBendTableKey);
    if (raw == null) return {};
    final m = jsonDecode(raw);
    if (m is! Map) return {};
    final out = <String, (double, double)>{};
    m.forEach((k, v) {
      if (k is String && v is Map && v['r'] is num && v['bd'] is num) {
        out[k] = ((v['r'] as num).toDouble(), (v['bd'] as num).toDouble());
      }
    });
    return out;
  } catch (_) {
    return {};
  }
}

Future<void> writePlateBendTable(Map<String, (double, double)> t) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      kPlateBendTableKey,
      jsonEncode({
        for (final e in t.entries) e.key: {'r': e.value.$1, 'bd': e.value.$2},
      }),
    );
  } catch (_) {}
}

/// 설정 화면. 바뀌면 바로 저장하고, 닫을 때 true를 돌려준다(부른 쪽이 다시 읽는다).
class PlateSettingsPage extends StatefulWidget {
  const PlateSettingsPage({
    super.key,
    this.bendPrefill,
    this.focusBend = false,
  });

  /// 절곡 탭 "업체 값 저장"에서 열 때: 넣기 칸에 미리 채울 (두께 글, 내R, 90° 공제값).
  final (String, double, double)? bendPrefill;

  /// 열자마자 업체 공제값 칸으로 내려간다.
  final bool focusBend;

  @override
  State<PlateSettingsPage> createState() => _PlateSettingsPageState();
}

class _PlateSettingsPageState extends State<PlateSettingsPage> {
  PlateSettings _s = PlateSettings.defaults;
  double _grid = 5;
  bool _center = true;
  bool _holeSize = true;
  Map<String, (double, double)> _bd = {};
  bool _ready = false;

  final _dias = TextEditingController();
  final _dia = TextEditingController();
  final _thick = {
    for (final m in PlateMaterial.values) m: TextEditingController(),
  };
  final _sw = TextEditingController();
  final _sh = TextEditingController();
  final _gap = TextEditingController();
  final _margin = TextEditingController();
  final _bt = TextEditingController();
  final _br = TextEditingController();
  final _bdv = TextEditingController();
  final _bendKey = GlobalKey();
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await PlateSettings.load();
    final bd = await readPlateBendTable();
    var grid = 5.0, center = true, holeSize = true;
    try {
      final p = await SharedPreferences.getInstance();
      grid = p.getDouble(kPlateGridKey) ?? 5;
      center = p.getBool(kPlateCenterKey) ?? true;
      holeSize = p.getBool(kPlateHoleSizeKey) ?? true;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _s = s;
      _bd = bd;
      _grid = grid;
      _center = center;
      _holeSize = holeSize;
      _dias.text = s.dias.map(_f).join(', ');
      _dia.text = _f(s.defaultDia);
      for (final m in PlateMaterial.values) {
        _thick[m]!.text = s.thick[m]!.join(', ');
      }
      _sw.text = _f(s.sheetW);
      _sh.text = _f(s.sheetH);
      _gap.text = _f(s.gap);
      _margin.text = _f(s.margin);
      final pre = widget.bendPrefill;
      if (pre != null) {
        _bt.text = pre.$1;
        _br.text = _f(pre.$2);
        _bdv.text = _f(pre.$3);
        _prefilled = true;
      }
      _ready = true;
    });
    if (widget.focusBend) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _bendKey.currentContext;
        if (c != null && c.mounted) {
          Scrollable.ensureVisible(
            c,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _dias,
      _dia,
      ..._thick.values,
      _sw,
      _sh,
      _gap,
      _margin,
      _bt,
      _br,
      _bdv,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _v(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _update(PlateSettings s) {
    setState(() => _s = s);
    s.save();
  }

  Future<void> _setGrid(double g) async {
    setState(() => _grid = g);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(kPlateGridKey, g);
    } catch (_) {}
  }

  Future<void> _setHoleSize(bool v) async {
    setState(() => _holeSize = v);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(kPlateHoleSizeKey, v);
    } catch (_) {}
  }

  Future<void> _setCenter(bool v) async {
    setState(() => _center = v);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(kPlateCenterKey, v);
    } catch (_) {}
  }

  void _addBend() {
    final t = _v(_bt), r = _v(_br), bd = _v(_bdv);
    if (t == null || t <= 0 || r == null || r < 0 || bd == null || bd <= 0) {
      showAppSnack(context, '두께·내R·공제값을 모두 넣으십시오.', kind: AppSnackKind.error);
      return;
    }
    // 나올 수 있는 공제값(K값 0~1)만(점검 53: 아무 값이나 저장되고 절곡 탭에서야 "나올 수 없는 값"이 떴다)
    final hi = plateBendDeduction90(t, r, 0),
        lo = plateBendDeduction90(t, r, 1);
    if (bd < lo - 1e-9 || bd > hi + 1e-9) {
      showAppSnack(
        context,
        '${_f(t)}T·내R ${_f(r)}이면 90° 공제값은 ${_f(lo)} ~ ${_f(hi)} 사이입니다. 업체 값을 다시 확인하십시오.',
        kind: AppSnackKind.error,
      );
      return;
    }
    setState(() {
      _bd[_f(t)] = (r, bd);
      _bt.clear();
      _br.clear();
      _bdv.clear();
      _prefilled = false;
    });
    writePlateBendTable(_bd);
    showAppSnack(context, '${_f(t)}T 업체 값을 저장했습니다. 그 두께를 고르면 이 값을 씁니다.');
  }

  Widget _num(
    String key,
    String? label,
    TextEditingController c,
    ValueChanged<String> on, {
    String? unit = 'mm',
    bool text = false,
    String? hint,
  }) => PlateNumField(
    fieldKey: key,
    label: label,
    controller: c,
    unit: unit,
    text: text,
    hint: hint,
    onChanged: on,
  );

  @override
  Widget build(BuildContext context) => FieldViewTheme(
    child: Builder(
      builder: (context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.pop(context, true);
        },
        child: Scaffold(
          backgroundColor: fc.surface,
          appBar: AppBar(
            backgroundColor: fc.surface,
            foregroundColor: fc.text,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              '철판 가공 설정',
              style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
            ),
          ),
          body: !_ready
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: [
                    PlateSection('홀', [
                      _num(
                        'ps_dias',
                        '자주 쓰는 홀 지름 (쉼표로)',
                        _dias,
                        (t) => _update(_s.copyWith(dias: parsePunchDies(t))),
                        unit: null,
                        text: true,
                        hint: '예) 9, 11, 13.5, 17.5',
                      ),
                      Text(
                        _s.dias.isEmpty
                            ? '비우면 홀 창에 지름 단추가 나오지 않습니다.'
                            : '홀 창 단추: ${_s.dias.map(punchDieLabel).join(' · ')}',
                        style: TextStyle(
                          fontSize: 13,
                          color: fc.textSub,
                          height: 1.35,
                        ),
                      ),
                      plateRow([
                        _num('ps_dia', '홀 추가 기본 지름', _dia, (_) {
                          final v = _v(_dia);
                          if (v != null && v > 0) {
                            _update(_s.copyWith(defaultDia: v));
                          }
                        }),
                        const SizedBox.shrink(),
                      ]),
                    ], first: true),
                    PlateSection('두께 단추 (재질별)', [
                      for (final m in PlateMaterial.values)
                        _num(
                          'ps_thick_${m.name}',
                          kPlateMaterials[m]!.$1,
                          _thick[m]!,
                          (t) => _update(
                            _s.copyWith(
                              thick: {..._s.thick, m: parsePlateThicknesses(t)},
                            ),
                          ),
                          unit: 'T',
                          text: true,
                        ),
                      Text(
                        '처음 값은 흔히 쓰는 두께입니다. 거래하는 업체 재고 두께로 바꿔 쓰십시오. 없는 두께는 모양 탭 칸에 직접 넣습니다.',
                        style: TextStyle(
                          fontSize: 13,
                          color: fc.textSub,
                          height: 1.35,
                        ),
                      ),
                    ]),
                    PlateSection('원판 배치', [
                      PlateSegments([
                        for (final (id, name, w, h) in kPlateSheets)
                          PlateOption(
                            'ps_sheet_$id',
                            name.split(' (').first,
                            _s.sheet == id,
                            () => _update(_s.copyWith(sheet: id)),
                            sub: '${_f(w)}×${_f(h)}',
                          ),
                        PlateOption(
                          'ps_sheet_custom',
                          '직접',
                          _s.sheet == 'custom',
                          () => _update(_s.copyWith(sheet: 'custom')),
                          sub: '가로×세로',
                        ),
                      ]),
                      if (_s.sheet == 'custom')
                        plateRow([
                          _num('ps_sw', '원판 가로', _sw, (_) {
                            final v = _v(_sw);
                            if (v != null && v > 0) {
                              _update(_s.copyWith(sheetW: v));
                            }
                          }),
                          _num('ps_sh', '원판 세로', _sh, (_) {
                            final v = _v(_sh);
                            if (v != null && v > 0) {
                              _update(_s.copyWith(sheetH: v));
                            }
                          }),
                        ]),
                      plateRow([
                        _num('ps_gap', '부품 간격', _gap, (_) {
                          final v = _v(_gap);
                          if (v != null && v >= 0) {
                            _update(_s.copyWith(gap: v));
                          }
                        }),
                        _num('ps_margin', '가장자리 여유', _margin, (_) {
                          final v = _v(_margin);
                          if (v != null && v >= 0) {
                            _update(_s.copyWith(margin: v));
                          }
                        }),
                      ]),
                    ]),
                    PlateSection('홀 편집 화면', [
                      Text(
                        '그리드 (홀을 끌 때 붙는 간격)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: fc.textSub,
                        ),
                      ),
                      PlateSegments([
                        for (final g in const [0.0, 1.0, 5.0, 10.0])
                          PlateOption(
                            'ps_grid_${g.round()}',
                            g == 0 ? '끔' : '${_f(g)}mm',
                            _grid == g,
                            () => _setGrid(g),
                          ),
                      ]),
                      Text(
                        '센터선 (그림·가공 도면)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: fc.textSub,
                        ),
                      ),
                      PlateSegments([
                        PlateOption(
                          'ps_center_on',
                          '보임',
                          _center,
                          () => _setCenter(true),
                        ),
                        PlateOption(
                          'ps_center_off',
                          '숨김',
                          !_center,
                          () => _setCenter(false),
                        ),
                      ]),
                      Text(
                        '홀 크기 글 (그림·가공 도면, 장공은 폭 × 길이)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: fc.textSub,
                        ),
                      ),
                      PlateSegments([
                        PlateOption(
                          'ps_hsize_on',
                          '적용',
                          _holeSize,
                          () => _setHoleSize(true),
                        ),
                        PlateOption(
                          'ps_hsize_off',
                          '미적용',
                          !_holeSize,
                          () => _setHoleSize(false),
                        ),
                      ]),
                    ]),
                    // 설계팀에 보내기(10-12, 형강 브라켓과 같이 씀)
                    const DesignSendSettingsSection(),
                    PlateSection(key: _bendKey, '업체 공제값 (두께별)', [
                      if (_bd.isEmpty)
                        Text(
                          '저장한 값이 없습니다. 아래에 두께·내R·90° 공제값을 넣고 "공제값 넣기"를 누르십시오. 저장한 두께를 고르면 절곡 탭이 이 값을 씁니다.',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: fc.textSub,
                            height: 1.4,
                          ),
                        )
                      else
                        for (final e
                            in (_bd.entries.toList()..sort(
                              (a, b) => (double.tryParse(a.key) ?? 0).compareTo(
                                double.tryParse(b.key) ?? 0,
                              ),
                            )))
                          Row(
                            key: Key('ps_bd_${e.key}'),
                            children: [
                              Expanded(
                                child: PlateInfoRow(
                                  '${e.key}T',
                                  '내R ${_f(e.value.$1)} · 공제값 ${_f(e.value.$2)}',
                                ),
                              ),
                              IconButton(
                                key: Key('ps_bd_del_${e.key}'),
                                tooltip: '지우기',
                                icon: Icon(AppIcons.delete, color: fc.danger),
                                onPressed: () {
                                  setState(() => _bd.remove(e.key));
                                  writePlateBendTable(_bd);
                                },
                              ),
                            ],
                          ),
                      if (_prefilled)
                        Text(
                          '절곡 탭에서 넣은 값을 채워 두었습니다. 맞으면 "공제값 넣기"를 누르십시오.',
                          key: const Key('ps_bd_prefilled'),
                          style: TextStyle(
                            fontSize: 13,
                            color: fc.brand,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      plateRow([
                        _num('ps_bt', '두께', _bt, (_) {}, unit: 'T'),
                        _num('ps_br', '내R', _br, (_) {}),
                        _num('ps_bdv', '90° 공제값', _bdv, (_) {}),
                      ]),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PlateActionButton(
                          key: const Key('ps_bd_add'),
                          icon: AppIcons.add,
                          label: '공제값 넣기',
                          onTap: _addBend,
                        ),
                      ),
                    ]),
                  ],
                ),
        ),
      ),
    ),
  );
}
