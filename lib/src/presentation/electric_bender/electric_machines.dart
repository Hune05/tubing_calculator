// 전동 튜브 벤더 장비 목록(설정 화면 "벤더 장비 제원"의 전동 장비 두 대)과 금형(툴링) 값 보관.
// 근거는 docs/전동벤더_근거.md.
//
// - Swagelok MS-BTB(벤치탑 전동): 슈 반경은 매뉴얼 MS-13-145 3쪽·카탈로그 MS-01-179 3쪽 값만 넣었다.
//   매뉴얼 굽힘 표(bend deduction·length)는 pdf에서 열이 섞여 나와 값을 믿고 옮길 수 없어서 넣지 않았다.
//   게인·스프링백은 매뉴얼 "Calibration" 절차처럼 시험 굽힘으로 채운다.
// - TRACTO-TECHNIK TUBOBEND TB20D: 공개 자료에 금형별 반경·클램프 길이·게인이 없다. 금형 각인 R을 넣고
//   시험 굽힘으로 채운다(2026-09-26 사용자 선택).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 금형 한 벌(관경 + 벤드 슈 반경)과 그 금형으로 잰 값.
class Tooling {
  const Tooling({
    required this.id,
    required this.label,
    required this.odMm,
    required this.radius,
    this.radiusSource = '',
    this.gain90 = 0,
    this.gainSource = '',
    this.springback90 = 0,
    this.springbackSource = '',
    this.clampLen = 0,
    this.lastLegMin = 0,
    this.builtIn = false,
  });

  final String id;

  /// 화면 이름(예: 1/2" · R56).
  final String label;
  final double odMm;

  /// 벤드 슈(금형) 반경 mm.
  final double radius;
  final String radiusSource;

  /// 90° 실측 게인 mm. 0이면 반경으로 계산한 이론값(0.4292 × R)을 쓴다.
  final double gain90;
  final String gainSource;

  /// 90°에서 잰 스프링백(°). 다른 각은 각도에 비례해 어림한다.
  final double springback90;
  final String springbackSource;

  /// 클램프가 무는 곧은 길이 mm(0이면 점검 안 함).
  final double clampLen;

  /// 마지막 다리 최소 길이 mm(0이면 점검 안 함).
  final double lastLegMin;

  /// 장비 목록에 들어 있는 금형(지울 수 없음).
  final bool builtIn;

  Tooling copyWith({
    String? label,
    double? odMm,
    double? radius,
    String? radiusSource,
    double? gain90,
    String? gainSource,
    double? springback90,
    String? springbackSource,
    double? clampLen,
    double? lastLegMin,
  }) => Tooling(
    id: id,
    label: label ?? this.label,
    odMm: odMm ?? this.odMm,
    radius: radius ?? this.radius,
    radiusSource: radiusSource ?? this.radiusSource,
    gain90: gain90 ?? this.gain90,
    gainSource: gainSource ?? this.gainSource,
    springback90: springback90 ?? this.springback90,
    springbackSource: springbackSource ?? this.springbackSource,
    clampLen: clampLen ?? this.clampLen,
    lastLegMin: lastLegMin ?? this.lastLegMin,
    builtIn: builtIn,
  );

  /// 사용자가 채우는 값(내장 금형은 이것만 저장한다).
  Map<String, dynamic> measuredJson() => {
    'gain90': gain90,
    'gainSource': gainSource,
    'springback90': springback90,
    'springbackSource': springbackSource,
    'clampLen': clampLen,
    'lastLegMin': lastLegMin,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'odMm': odMm,
    'radius': radius,
    'radiusSource': radiusSource,
    ...measuredJson(),
  };

  Tooling withMeasured(Map m) {
    double d(String k, double now) => (m[k] as num?)?.toDouble() ?? now;
    String s(String k, String now) => m[k] is String ? m[k] as String : now;
    return copyWith(
      gain90: d('gain90', gain90),
      gainSource: s('gainSource', gainSource),
      springback90: d('springback90', springback90),
      springbackSource: s('springbackSource', springbackSource),
      clampLen: d('clampLen', clampLen),
      lastLegMin: d('lastLegMin', lastLegMin),
    );
  }

  static Tooling? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final label = raw['label'];
    final od = (raw['odMm'] as num?)?.toDouble();
    final r = (raw['radius'] as num?)?.toDouble();
    if (id is! String || label is! String || od == null || r == null) {
      return null;
    }
    if (od <= 0 || r <= 0) return null;
    return Tooling(
      id: id,
      label: label,
      odMm: od,
      radius: r,
      radiusSource: raw['radiusSource'] is String
          ? raw['radiusSource'] as String
          : '',
    ).withMeasured(raw);
  }
}

enum MachineId { msBtb, tb20d }

class ElectricMachine {
  const ElectricMachine({
    required this.id,
    required this.name,
    required this.shortName,
    required this.maker,
    required this.maxAngle,
    required this.manualFeed,
    required this.note,
    this.tooling = const [],
  });

  final MachineId id;
  final String name;
  final String shortName;
  final String maker;

  /// 장비가 꺾을 수 있는 가장 큰 각(°). null이면 모름.
  final double? maxAngle;

  /// 관 이송·회전을 손으로 하는지(마킹 대신 이송·회전·각도 한 줄로도 보여 준다).
  final bool manualFeed;
  final String note;
  final List<Tooling> tooling;
}

const String _btbSource = 'Swagelok MS-13-145 3쪽, MS-01-179 3쪽';

Tooling _btb(String id, String label, double od, double r) => Tooling(
  id: 'btb_$id',
  label: label,
  odMm: od,
  radius: r,
  radiusSource: _btbSource,
  builtIn: true,
);

/// 설정 화면의 전동 장비 두 대.
final List<ElectricMachine> kElectricMachines = [
  ElectricMachine(
    id: MachineId.msBtb,
    name: 'Swagelok MS-BTB (벤치탑 전동)',
    shortName: 'Swagelok MS-BTB',
    maker: 'Swagelok',
    maxAngle: 180,
    manualFeed: false,
    note:
        '각도는 숫자 바퀴(thumb wheel)로 넣고 토글 스위치로 꺾습니다. 1~180°. 마킹은 관이 휘기 시작하는 자리이며, '
        '벤드 슈의 기준선(reference mark)에 맞춥니다(MS-13-145 4쪽).',
    tooling: [
      _btb('i4', '1/4" · R36', 6.35, 36),
      _btb('i6', '3/8" · R36', 9.525, 36),
      _btb('i6_56', '3/8" · R56', 9.525, 56),
      _btb('i8', '1/2" · R36', 12.7, 36),
      _btb('i8_56', '1/2" · R56', 12.7, 56),
      _btb('i10', '5/8" · R46', 15.875, 46),
      _btb('i12', '3/4" · R56', 19.05, 56),
      _btb('i14', '7/8" · R67', 22.225, 67),
      _btb('i16', '1" · R82', 25.4, 82),
      _btb('i20', '1-1/4" · R112', 31.75, 112),
      _btb('m6', '6mm · R36', 6, 36),
      _btb('m10', '10mm · R36', 10, 36),
      _btb('m12', '12mm · R36', 12, 36),
      _btb('m14', '14mm · R46', 14, 46),
      _btb('m15', '15mm · R46', 15, 46),
      _btb('m16', '16mm · R46', 16, 46),
      _btb('m18', '18mm · R56', 18, 56),
      _btb('m20', '20mm · R67', 20, 67),
      _btb('m22', '22mm · R67', 22, 67),
      _btb('m25', '25mm · R82', 25, 82),
      _btb('m28', '28mm · R112', 28, 112),
      _btb('m30', '30mm · R112', 30, 112),
    ],
  ),
  const ElectricMachine(
    id: MachineId.tb20d,
    name: 'TRACTO-TECHNIK TUBOBEND TB20D',
    shortName: 'TUBOBEND TB20D',
    maker: 'TRACTO-TECHNIK',
    maxAngle: null,
    manualFeed: true,
    note:
        '굽힘 각도만 장비가 하고, 관을 밀어 넣는 것(이송)과 돌리는 것(회전)은 손으로 합니다. 각도 8개를 미리 넣고 차례로 '
        '꺾을 수 있습니다(제조사 자료). 금형별 반경·클램프 길이는 공개 자료에 없어 금형 각인과 시험 굽힘으로 채웁니다.',
  ),
];

ElectricMachine machineById(MachineId id) =>
    kElectricMachines.firstWhere((m) => m.id == id);

/// 장비 목록과 사용자가 채운 값. 폰에만 저장한다.
class ElectricBenderStore {
  static const String key = 'electric_bender_v1';

  MachineId machine = MachineId.msBtb;
  String? toolingId;

  /// 내장 금형에 사용자가 채운 값(금형 id → 값).
  final Map<String, Map<String, dynamic>> measured = {};

  /// 사용자가 더한 금형(장비 → 목록).
  final Map<MachineId, List<Tooling>> custom = {};

  List<Tooling> toolingOf(MachineId id) {
    final m = machineById(id);
    return [
      for (final t in m.tooling)
        measured[t.id] == null ? t : t.withMeasured(measured[t.id]!),
      ...?custom[id],
    ];
  }

  Tooling? get selected {
    final list = toolingOf(machine);
    if (list.isEmpty) return null;
    return list.firstWhere((t) => t.id == toolingId, orElse: () => list.first);
  }

  /// 금형 값을 고치거나 더한다.
  void put(Tooling t) {
    if (t.builtIn) {
      measured[t.id] = t.measuredJson();
      return;
    }
    final list = custom.putIfAbsent(machine, () => []);
    final i = list.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      list[i] = t;
    } else {
      list.add(t);
    }
  }

  void removeCustom(String id) {
    custom[machine]?.removeWhere((t) => t.id == id);
    if (toolingId == id) toolingId = null;
  }

  String toJsonString() => jsonEncode({
    'machine': machine.name,
    'toolingId': toolingId,
    'measured': measured,
    'custom': {
      for (final e in custom.entries)
        e.key.name: [for (final t in e.value) t.toJson()],
    },
  });

  void applyJson(String raw) {
    final m = jsonDecode(raw);
    if (m is! Map) return;
    machine = MachineId.values.firstWhere(
      (v) => v.name == m['machine'],
      orElse: () => machine,
    );
    if (m['toolingId'] is String) toolingId = m['toolingId'] as String;
    final ms = m['measured'];
    if (ms is Map) {
      for (final e in ms.entries) {
        if (e.key is String && e.value is Map) {
          measured[e.key as String] = Map<String, dynamic>.from(e.value as Map);
        }
      }
    }
    final cs = m['custom'];
    if (cs is Map) {
      for (final e in cs.entries) {
        final id = MachineId.values.where((v) => v.name == e.key);
        if (id.isEmpty || e.value is! List) continue;
        custom[id.first] = [
          for (final raw in e.value as List) ?Tooling.fromJson(raw),
        ];
      }
    }
  }

  static Future<ElectricBenderStore> load() async {
    final s = ElectricBenderStore();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw != null) s.applyJson(raw);
    } catch (_) {
      // 읽지 못하면 처음 상태로.
    }
    return s;
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, toJsonString());
    } catch (_) {
      // 저장하지 못해도 계산은 된다.
    }
  }
}
