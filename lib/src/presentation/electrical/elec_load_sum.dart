// 전기 설계 계산 "부하 합산" 탭의 계산과 저장 모양(화면 없이 시험할 수 있게 따로 둠).
// 식: 최대수요전력 = 설비용량 × 수용률, 필요 변압기 용량 = 최대수요 kVA ÷ 부등률 × (1 + 여유).
// 근거와 원문 대조 전 표시는 docs/전기_부하합산_근거.md.
import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

/// 부하 줄 수 상한.
const int kLoadSumMaxRows = 30;

/// 저장한 계산서 수 상한.
const int kLoadSumMaxSheets = 50;

/// 2차 전압 선택지(교류 3상, V).
const List<double> kLoadSumVolts = [380, 440, 480];

/// 설비용량 입력 상한(kW). 자릿수 실수를 걸러 내는 값.
const double kLoadSumMaxKw = 1000000;

/// 부하 한 줄의 입력(칸에 적은 글 그대로).
class LoadRowInput {
  final String name;
  final String kw;
  final String pf;
  final String df;
  const LoadRowInput({
    this.name = '',
    this.kw = '',
    this.pf = '',
    this.df = '',
  });

  bool get isBlank =>
      name.trim().isEmpty &&
      kw.trim().isEmpty &&
      pf.trim().isEmpty &&
      df.trim().isEmpty;

  Map<String, Object?> toJson() => {'n': name, 'kw': kw, 'pf': pf, 'df': df};

  factory LoadRowInput.fromJson(Object? j) {
    if (j is! Map) return const LoadRowInput();
    String s(String k) => j[k] is String ? j[k] as String : '';
    return LoadRowInput(name: s('n'), kw: s('kw'), pf: s('pf'), df: s('df'));
  }
}

/// 부하 계산서 입력 전체(칸에 적은 글 그대로).
class LoadSumInput {
  final List<LoadRowInput> rows;

  /// 줄에 역률·수용률을 비워 두었을 때 쓰는 기본값(%). 비어 있으면 그 줄은 입력 확인.
  final String defaultPf;
  final String defaultDf;

  /// 부등률(1 이상). 비우면 1.0.
  final String diversity;

  /// 장래 증설 여유(%). 비우면 0.
  final String margin;

  /// 2차 전압(V, 3상).
  final double volts;

  /// 선정한 변압기 용량(kVA). 비우면 부하율은 계산하지 않습니다.
  final String selectedKva;
  final String site;
  final String memo;

  const LoadSumInput({
    this.rows = const [],
    this.defaultPf = '',
    this.defaultDf = '',
    this.diversity = '1.0',
    this.margin = '0',
    this.volts = 380,
    this.selectedKva = '',
    this.site = '',
    this.memo = '',
  });

  Map<String, Object?> toJson() => {
    'rows': [for (final r in rows) r.toJson()],
    'dPf': defaultPf,
    'dDf': defaultDf,
    'div': diversity,
    'mar': margin,
    'v': volts,
    'sel': selectedKva,
    'site': site,
    'memo': memo,
  };

  factory LoadSumInput.fromJson(Object? j) {
    if (j is! Map) return const LoadSumInput();
    String s(String k, String d) => j[k] is String ? j[k] as String : d;
    final v = j['v'] is num ? (j['v'] as num).toDouble() : 380.0;
    final rows = <LoadRowInput>[];
    if (j['rows'] is List) {
      for (final r in j['rows'] as List) {
        if (rows.length >= kLoadSumMaxRows) break;
        rows.add(LoadRowInput.fromJson(r));
      }
    }
    return LoadSumInput(
      rows: rows,
      defaultPf: s('dPf', ''),
      defaultDf: s('dDf', ''),
      diversity: s('div', '1.0'),
      margin: s('mar', '0'),
      volts: kLoadSumVolts.contains(v) ? v : 380,
      selectedKva: s('sel', ''),
      site: s('site', ''),
      memo: s('memo', ''),
    );
  }
}

/// 계산을 마친 부하 한 줄.
class LoadLine {
  /// 화면 줄 번호(1부터. 빈 줄도 센다).
  final int no;
  final String name;
  final double kw;
  final double dfPct;
  final double pfPct;

  /// 최대수요 유효전력 P [kW] = 설비용량 × 수용률.
  final double p;

  /// 최대수요 무효전력 Q [kvar] = P × tanφ.
  final double q;

  /// 피상전력 S [kVA] = P ÷ 역률.
  double get s => math.sqrt(p * p + q * q);

  const LoadLine({
    required this.no,
    required this.name,
    required this.kw,
    required this.dfPct,
    required this.pfPct,
    required this.p,
    required this.q,
  });
}

/// 부하 합산 결과. [errors]가 비어 있고 [lines]가 있어야 값이 유효하다([ok]).
class LoadSumResult {
  final List<String> errors;
  final List<LoadLine> lines;
  final double totalKw;
  final double demandKw;
  final double demandKvar;
  final double demandKva;

  /// 종합 역률(0~1) = P ÷ S.
  final double pf;
  final double diversity;
  final double marginPct;
  final double volts;

  /// 필요 변압기 용량 [kVA].
  final double requiredKva;

  /// 필요 용량의 2차 정격전류 [A].
  final double ratedAmps;
  final double? selectedKva;

  /// 부하율 [%] = 필요 용량 ÷ 선정 용량 × 100(여유 포함).
  final double? loadPct;

  /// 여유를 빼고 부등률만 반영한 부하율 [%].
  final double? loadPctNoMargin;

  const LoadSumResult({
    this.errors = const [],
    this.lines = const [],
    this.totalKw = 0,
    this.demandKw = 0,
    this.demandKvar = 0,
    this.demandKva = 0,
    this.pf = 0,
    this.diversity = 1,
    this.marginPct = 0,
    this.volts = 380,
    this.requiredKva = 0,
    this.ratedAmps = 0,
    this.selectedKva,
    this.loadPct,
    this.loadPctNoMargin,
  });

  bool get ok => errors.isEmpty && lines.isNotEmpty;

  /// 부하 줄이 하나도 없다(입력 오류는 아님).
  bool get noLines => errors.isEmpty && lines.isEmpty;

  /// 선정 용량 판정. 선정 용량을 넣지 않았으면 null.
  bool? get pass => loadPct == null ? null : loadPct! <= 100 + 1e-9;
}

double? _num(String s) {
  final v = double.tryParse(s.trim().replaceAll(',', ''));
  if (v == null || v.isNaN || v.isInfinite) return null;
  return v;
}

String _fmtN(double v) {
  var s = v.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s;
}

/// 부하 합산 계산. 잘못된 칸은 자르거나 고쳐 쓰지 않고 [LoadSumResult.errors]로 돌려준다.
LoadSumResult computeLoadSum(LoadSumInput input) {
  final errors = <String>[];
  final lines = <LoadLine>[];

  if (input.rows.length > kLoadSumMaxRows) {
    errors.add('부하는 $kLoadSumMaxRows줄까지 넣을 수 있습니다.');
  }

  // 기본 역률·수용률(비었으면 없음, 있는데 범위 밖이면 오류).
  double? defaultOf(String text, String label) {
    if (text.trim().isEmpty) return null;
    final v = _num(text);
    if (v == null) {
      errors.add('$label: 숫자가 아닙니다.');
      return null;
    }
    if (v <= 0 || v > 100) {
      errors.add('$label: 0 초과 100 이하로 넣으십시오(입력값 ${_fmtN(v)}%).');
      return null;
    }
    return v;
  }

  final defPf = defaultOf(input.defaultPf, '기본 역률');
  final defDf = defaultOf(input.defaultDf, '기본 수용률');

  for (var i = 0; i < input.rows.length && i < kLoadSumMaxRows; i++) {
    final r = input.rows[i];
    if (r.isBlank) continue;
    final no = i + 1;
    final label = r.name.trim().isEmpty ? '$no번 줄' : '$no번 줄(${r.name.trim()})';
    var bad = false;

    double? kw;
    if (r.kw.trim().isEmpty) {
      errors.add('$label: 설비용량(kW)을 넣으십시오.');
      bad = true;
    } else {
      kw = _num(r.kw);
      if (kw == null) {
        errors.add('$label: 설비용량(kW)이 숫자가 아닙니다.');
        bad = true;
      } else if (kw <= 0) {
        errors.add(
          '$label: 설비용량(kW)은 0보다 커야 합니다(입력값 ${_fmtN(kw)}). '
          '음수와 0은 계산하지 않습니다.',
        );
        bad = true;
      } else if (kw > kLoadSumMaxKw) {
        errors.add('$label: 설비용량(kW)이 너무 큽니다. 단위가 kW인지 확인하십시오.');
        bad = true;
      }
    }

    double? pick(String text, double? dflt, String name, String defaultName) {
      if (text.trim().isEmpty) {
        if (dflt != null) return dflt;
        errors.add('$label: $name(%)을 넣거나 $defaultName 칸을 채우십시오.');
        bad = true;
        return null;
      }
      final v = _num(text);
      if (v == null) {
        errors.add('$label: $name(%)이 숫자가 아닙니다.');
        bad = true;
        return null;
      }
      if (v <= 0 || v > 100) {
        errors.add('$label: $name(%)은 0 초과 100 이하로 넣으십시오(입력값 ${_fmtN(v)}).');
        bad = true;
        return null;
      }
      return v;
    }

    final pf = pick(r.pf, defPf, '역률', '기본 역률');
    final df = pick(r.df, defDf, '수용률', '기본 수용률');
    if (bad || kw == null || pf == null || df == null) continue;

    final p = kw * df / 100;
    final phi = math.acos(pf / 100);
    final q = p * math.tan(phi);
    lines.add(
      LoadLine(
        no: no,
        name: r.name.trim(),
        kw: kw,
        dfPct: df,
        pfPct: pf,
        p: p,
        q: q,
      ),
    );
  }

  // 부등률(비우면 1.0).
  var diversity = 1.0;
  if (input.diversity.trim().isNotEmpty) {
    final v = _num(input.diversity);
    if (v == null) {
      errors.add('부등률: 숫자가 아닙니다.');
    } else if (v < 1) {
      errors.add(
        '부등률: 1 이상으로 넣으십시오(입력값 ${_fmtN(v)}). '
        '1보다 작은 값은 수용률과 헷갈린 경우가 많습니다.',
      );
    } else {
      diversity = v;
    }
  }

  // 장래 증설 여유(비우면 0).
  var margin = 0.0;
  if (input.margin.trim().isNotEmpty) {
    final v = _num(input.margin);
    if (v == null) {
      errors.add('장래 증설 여유: 숫자가 아닙니다.');
    } else if (v < 0) {
      errors.add('장래 증설 여유: 0 이상으로 넣으십시오(입력값 ${_fmtN(v)}%).');
    } else {
      margin = v;
    }
  }

  if (!(input.volts > 0)) {
    errors.add('2차 전압을 선택하십시오.');
  }

  // 선정 용량(비우면 판정 안 함).
  double? selected;
  if (input.selectedKva.trim().isNotEmpty) {
    final v = _num(input.selectedKva);
    if (v == null) {
      errors.add('선정 변압기 용량(kVA): 숫자가 아닙니다.');
    } else if (v <= 0) {
      errors.add('선정 변압기 용량(kVA): 0보다 커야 합니다(입력값 ${_fmtN(v)}).');
    } else {
      selected = v;
    }
  }

  if (errors.isNotEmpty || lines.isEmpty) {
    return LoadSumResult(errors: errors, lines: lines);
  }

  var totalKw = 0.0, sp = 0.0, sq = 0.0;
  for (final l in lines) {
    totalKw += l.kw;
    sp += l.p;
    sq += l.q;
  }
  final sKva = math.sqrt(sp * sp + sq * sq);
  final required = sKva / diversity * (1 + margin / 100);
  final amps = required * 1000 / (math.sqrt(3) * input.volts);
  return LoadSumResult(
    lines: lines,
    totalKw: totalKw,
    demandKw: sp,
    demandKvar: sq,
    demandKva: sKva,
    pf: sKva == 0 ? 0 : sp / sKva,
    diversity: diversity,
    marginPct: margin,
    volts: input.volts,
    requiredKva: required,
    ratedAmps: amps,
    selectedKva: selected,
    loadPct: selected == null ? null : required / selected * 100,
    loadPctNoMargin: selected == null
        ? null
        : sKva / diversity / selected * 100,
  );
}

// ─────────────── 저장한 계산서(폰 안에만, 서버에 올리지 않음) ───────────────

/// 저장한 계산서 목록의 저장 칸 이름.
const String kLoadSheetsKey = 'elec_load_sheets_v1';

/// 저장한 계산서 하나.
class LoadSheet {
  final String name;
  final DateTime savedAt;
  final LoadSumInput input;
  const LoadSheet({
    required this.name,
    required this.savedAt,
    required this.input,
  });

  Map<String, Object?> toJson() => {
    'name': name,
    'at': savedAt.toIso8601String(),
    'input': input.toJson(),
  };

  static LoadSheet? fromJson(Object? j) {
    if (j is! Map || j['name'] is! String) return null;
    final at = DateTime.tryParse(j['at'] is String ? j['at'] as String : '');
    return LoadSheet(
      name: j['name'] as String,
      savedAt: at ?? DateTime.fromMillisecondsSinceEpoch(0),
      input: LoadSumInput.fromJson(j['input']),
    );
  }
}

/// 목록을 글로 바꾼다.
String encodeLoadSheets(List<LoadSheet> sheets) =>
    jsonEncode([for (final s in sheets) s.toJson()]);

/// 글에서 목록을 읽는다. 깨진 글이면 빈 목록.
List<LoadSheet> decodeLoadSheets(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  try {
    final j = jsonDecode(raw);
    if (j is! List) return [];
    return [for (final e in j) ?LoadSheet.fromJson(e)];
  } catch (_) {
    return [];
  }
}

/// 저장 칸 읽기·쓰기(SharedPreferences). 실패하면 빈 목록·false.
class LoadSheetStore {
  static Future<List<LoadSheet>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return decodeLoadSheets(prefs.getString(kLoadSheetsKey));
    } catch (_) {
      return [];
    }
  }

  static Future<bool> save(List<LoadSheet> sheets) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(kLoadSheetsKey, encodeLoadSheets(sheets));
    } catch (_) {
      return false;
    }
  }
}
