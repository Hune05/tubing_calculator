// 형강 브라켓 설정(10-11 개편, 사용자 원칙: 가끔 바꾸는 값은 작업 화면에 섞지 말고 설정 페이지로): 원자재 길이·톱날 여유,
// 지시서 작성자·공차 글, 새 브라켓의 재질·표면 처리 처음 값, 내 펀치 금형(접지바 가공과 같이 씀). 저장은 이 기기만.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/field_view.dart';
import '../electrical/busbar_punch_dies.dart'
    show kDefaultPunchDies, openPunchDies, punchDieLabel, readPunchDies;
import '../steel_plate/plate_ui.dart';
import 'bracket_form.dart';
import 'bracket_load.dart' show kBracketMaterials;

const String kBracketSettingsKey = 'steel_bracket_settings_v1';

/// 공차 처음 글: 용접 구조물 일반 공차 B급(ISO 13920). 업체·현장 기준이 있으면 설정에서 바꾼다.
const String kBracketToleranceDefault = 'ISO 13920 B급(용접 구조물 일반 공차)';

String _f(double v) {
  var s = v.toStringAsFixed(2);
  while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

class BracketSettings {
  final double stock, kerf;
  final String tolerance, author, material;
  final int finish;
  const BracketSettings({
    this.stock = 6000,
    this.kerf = 2,
    this.tolerance = kBracketToleranceDefault,
    this.author = '',
    this.material = 'SS275',
    this.finish = 0,
  });

  static const defaults = BracketSettings();

  BracketSettings copyWith({
    double? stock,
    double? kerf,
    String? tolerance,
    String? author,
    String? material,
    int? finish,
  }) => BracketSettings(
    stock: stock ?? this.stock,
    kerf: kerf ?? this.kerf,
    tolerance: tolerance ?? this.tolerance,
    author: author ?? this.author,
    material: material ?? this.material,
    finish: finish ?? this.finish,
  );

  Map<String, Object> toJson() => {
    'stock': stock,
    'kerf': kerf,
    'tol': tolerance,
    'author': author,
    'mat': material,
    'fin': finish,
  };

  static BracketSettings fromJson(Object? o) {
    if (o is! Map) return defaults;
    double n(String k, double d) {
      final v = o[k];
      return v is num && v >= 0 ? v.toDouble() : d;
    }

    String s(String k, String d) {
      final v = o[k];
      return v is String ? v : d;
    }

    final mat = s('mat', 'SS275');
    final fin = o['fin'];
    return BracketSettings(
      stock: n('stock', 6000),
      kerf: n('kerf', 2),
      tolerance: s('tol', kBracketToleranceDefault),
      author: s('author', ''),
      material: kBracketMaterials.containsKey(mat) ? mat : 'SS275',
      finish: fin is int && fin >= 0 && fin < kBracketFinishes.length ? fin : 0,
    );
  }

  static Future<BracketSettings> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(kBracketSettingsKey);
      return raw == null ? defaults : fromJson(jsonDecode(raw));
    } catch (_) {
      return defaults;
    }
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(kBracketSettingsKey, jsonEncode(toJson()));
    } catch (_) {}
  }
}

class BracketSettingsPage extends StatefulWidget {
  const BracketSettingsPage({super.key});

  @override
  State<BracketSettingsPage> createState() => _BracketSettingsPageState();
}

class _BracketSettingsPageState extends State<BracketSettingsPage> {
  BracketSettings _s = BracketSettings.defaults;
  List<double> _dies = const [];
  bool _ready = false;
  final _stock = TextEditingController();
  final _kerf = TextEditingController();
  final _tol = TextEditingController();
  final _author = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await BracketSettings.load();
    final d = await readPunchDies();
    if (!mounted) return;
    setState(() {
      _s = s;
      _dies = d;
      _stock.text = _f(s.stock);
      _kerf.text = _f(s.kerf);
      _tol.text = s.tolerance;
      _author.text = s.author;
      _ready = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_stock, _kerf, _tol, _author]) {
      c.dispose();
    }
    super.dispose();
  }

  void _update(BracketSettings s) {
    setState(() => _s = s);
    s.save();
  }

  double? _v(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

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
              '형강 브라켓 설정',
              style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
            ),
          ),
          body: !_ready
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: [
                    PlateSection('지시서', [
                      PlateNumField(
                        fieldKey: 'bs_author',
                        label: '작성자',
                        controller: _author,
                        unit: null,
                        text: true,
                        hint: '지시서 작성 칸에 들어갑니다',
                        onChanged: (t) =>
                            _update(_s.copyWith(author: t.trim())),
                      ),
                      PlateNumField(
                        fieldKey: 'bs_tol',
                        label: '따로 적지 않은 치수 공차',
                        controller: _tol,
                        unit: null,
                        text: true,
                        hint: kBracketToleranceDefault,
                        onChanged: (t) => _update(
                          _s.copyWith(
                            tolerance: t.trim().isEmpty
                                ? kBracketToleranceDefault
                                : t.trim(),
                          ),
                        ),
                      ),
                    ], first: true),
                    PlateSection('새 브라켓 처음 값', [
                      Text(
                        '재질',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: fc.textSub,
                        ),
                      ),
                      PlateSegments([
                        for (final m in kBracketMaterials.keys)
                          PlateOption(
                            'bs_mat_$m',
                            m,
                            _s.material == m,
                            () => _update(_s.copyWith(material: m)),
                          ),
                      ]),
                      Text(
                        '표면 처리',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: fc.textSub,
                        ),
                      ),
                      PlateSegments([
                        for (var i = 0; i < kBracketFinishes.length; i++)
                          PlateOption(
                            'bs_fin_$i',
                            kBracketFinishes[i],
                            _s.finish == i,
                            () => _update(_s.copyWith(finish: i)),
                          ),
                      ]),
                    ]),
                    PlateSection('원자재', [
                      plateRow([
                        PlateNumField(
                          fieldKey: 'bs_stock',
                          label: '원자재 한 본 길이',
                          controller: _stock,
                          onChanged: (_) {
                            final v = _v(_stock);
                            if (v != null && v >= 0) {
                              _update(_s.copyWith(stock: v));
                            }
                          },
                        ),
                        PlateNumField(
                          fieldKey: 'bs_kerf',
                          label: '톱날 여유',
                          controller: _kerf,
                          onChanged: (_) {
                            final v = _v(_kerf);
                            if (v != null && v >= 0) {
                              _update(_s.copyWith(kerf: v));
                            }
                          },
                        ),
                      ]),
                      Text(
                        '원자재 길이를 0으로 하면 본수를 계산하지 않습니다. 톱날 여유 기본 2는 임의 값입니다.',
                        style: TextStyle(
                          fontSize: 13,
                          color: fc.textSub,
                          height: 1.35,
                        ),
                      ),
                    ]),
                    PlateSection('구멍', [
                      Text(
                        '내 펀치 금형(구멍 지름 단추): ${(_dies.isEmpty ? kDefaultPunchDies : _dies).map(punchDieLabel).join(' · ')}${_dies.isEmpty ? ' (기본)' : ''}. 접지바 가공과 같이 씁니다.',
                        style: TextStyle(
                          fontSize: 13,
                          color: fc.textSub,
                          height: 1.35,
                        ),
                      ),
                      plateActions([
                        PlateActionButton(
                          key: const Key('bs_dies'),
                          icon: Icons.tune_rounded,
                          label: _dies.isEmpty ? '내 금형 넣기' : '내 금형 고치기',
                          onTap: () async {
                            final r = await openPunchDies(context, _dies);
                            if (r != null && mounted) setState(() => _dies = r);
                          },
                        ),
                      ]),
                    ]),
                  ],
                ),
        ),
      ),
    ),
  );
}
