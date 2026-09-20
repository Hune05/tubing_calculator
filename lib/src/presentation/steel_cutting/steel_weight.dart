import 'dart:math' as math;

import '../../data/models/steel_cutting_project_model.dart';
import '../tube_cutting/cutting_math.dart' show fmtKg;

export '../tube_cutting/cutting_math.dart' show fmtKg;

// 형강 이론 중량(kg/m). 규격 이름만으로 계산하는 참고값이라 실제 저울 무게와 조금 다를 수 있다
// (제조사·두께 오차, 모서리 둥글림 때문에 ±3% 안팎). 발주·운송 무게는 자재 규격서로 확인해야 한다.
//
// 규격 이름이 "종류 치수" 모양이면 종류 이름으로 알아본다(직접 입력한 규격도 "앵글 50x50x6"처럼 쓰면 계산된다).
// 못 알아보면 null — 화면은 그 규격을 무게 합계에서 뺀다고 알려 준다.

// 강철 1mm² 단면이 1m 길이일 때의 무게(kg). 밀도 7.85g/cm³.
const double _kgPerMm2PerM = 0.00785;

// KS 열간압연 등변 앵글 단위중량(kg/m). 표에 있는 규격은 이 값을 쓴다.
const Map<String, double> _angleKgPerM = {
  '25x25x3': 1.12,
  '30x30x3': 1.36,
  '40x40x3': 1.83,
  '40x40x4': 2.42,
  '45x45x4': 2.74,
  '50x50x4': 3.06,
  '50x50x5': 3.77,
  '60x60x5': 4.55,
  '65x65x6': 5.91,
  '75x75x6': 6.85,
  '75x75x9': 9.96,
  '90x90x7': 9.59,
  '100x100x7': 10.7,
  '100x100x10': 14.9,
  '125x125x9': 17.0,
  '150x150x12': 27.3,
};

// KS 열간압연 ㄷ형강(춤x폭x웨브두께) 단위중량(kg/m). 플랜지 두께가 이름에 없어서 계산식으로는 못 구한다.
const Map<String, double> _rolledChannelKgPerM = {
  '75x40x5': 6.92,
  '100x50x5': 9.36,
  '125x65x6': 13.4,
  '150x75x6.5': 18.6,
  '180x75x7': 21.4,
  '200x80x7.5': 24.6,
  '250x90x9': 34.6,
  '300x90x9': 38.1,
  '300x90x10': 43.8,
  '380x100x10.5': 54.5,
};

// 배관용 탄소강관(SGP) 단위중량(kg/m), 호칭 기준.
const Map<String, double> _sgpKgPerM = {
  '15A': 1.31,
  '20A': 1.68,
  '25A': 2.43,
  '32A': 3.38,
  '40A': 3.89,
  '50A': 5.31,
  '65A': 7.47,
  '80A': 8.79,
  '100A': 12.2,
};

// 전산볼트 피치(mm) — 나사산 때문에 단면이 줄어든 만큼 지름에서 뺀다.
const Map<String, double> _rodPitch = {
  'M6': 1.0,
  'M8': 1.25,
  'M10': 1.5,
  'M12': 1.75,
  'M16': 2.0,
  'M20': 2.5,
};

List<double>? _nums(String size) {
  final parts = size.split(RegExp(r'[xX×*]'));
  final out = <double>[];
  for (final p in parts) {
    final v = double.tryParse(p.trim());
    if (v == null || v <= 0) return null;
    out.add(v);
  }
  return out;
}

/// 규격 이름("앵글 40x40x3")의 1m당 이론 중량(kg). 모르면 null.
double? steelKgPerM(String shapeLabel) {
  final label = shapeLabel.trim();
  final space = label.indexOf(' ');
  if (space <= 0) return null;
  final kind = label.substring(0, space);
  final size = label.substring(space + 1).trim();

  double? area(double? mm2) => mm2 == null || mm2 <= 0 ? null : mm2;
  double? fromArea(double? mm2) {
    final a = area(mm2);
    return a == null ? null : a * _kgPerMm2PerM;
  }

  switch (kind) {
    case '앵글':
      final table = _angleKgPerM[size.toLowerCase()];
      if (table != null) return table;
      final n = _nums(size);
      if (n == null || n.length != 3) return null;
      return fromArea(n[2] * (n[0] + n[1] - n[2]));
    case '부등변앵글':
      final n = _nums(size);
      if (n == null || n.length != 3) return null;
      return fromArea(n[2] * (n[0] + n[1] - n[2]));
    case '찬넬':
      final table = _rolledChannelKgPerM[size.toLowerCase()];
      if (table != null) return table;
      final n = _nums(size);
      if (n == null || n.length != 3) return null;
      // 경량 찬넬(ㄷ자, 두께 일정): 웹 + 플랜지 두 개.
      return fromArea(n[2] * (n[0] + 2 * n[1] - 2 * n[2]));
    case '립C형강':
      final n = _nums(size);
      if (n == null || n.length != 4) return null;
      // 높이x폭x립xt: 웹 + 플랜지 2 + 립 2, 모서리 4곳은 겹치니 뺀다.
      return fromArea(n[3] * (n[0] + 2 * n[1] + 2 * n[2] - 4 * n[3]));
    case '스트럿':
      final n = _nums(size);
      if (n == null || n.length != 3) return null;
      // 폭x높이xt: 바닥 + 옆면 2 + 안쪽으로 접힌 입술 2(약 10mm로 본다).
      const lip = 10.0;
      return fromArea(n[2] * (n[0] + 2 * n[1] + 2 * lip - 4 * n[2]));
    case '평철':
      final n = _nums(size);
      if (n == null || n.length != 2) return null;
      return fromArea(n[0] * n[1]);
    case '각파이프':
      final n = _nums(size);
      if (n == null || n.length != 3) return null;
      return fromArea(2 * n[2] * (n[0] + n[1] - 2 * n[2]));
    case '강관':
      final m = RegExp(r'^(\d+A)').firstMatch(size);
      if (m == null) return null;
      return _sgpKgPerM[m.group(1)];
    case '환봉':
      final v = double.tryParse(size.replaceAll(RegExp(r'^[Φφ⌀]\s*'), ''));
      if (v == null || v <= 0) return null;
      return fromArea(math.pi / 4 * v * v);
    case '전산볼트':
      final key = size.toUpperCase();
      final pitch = _rodPitch[key];
      final d = double.tryParse(key.replaceFirst('M', ''));
      if (pitch == null || d == null) return null;
      final eff = d - 0.65 * pitch;
      return fromArea(math.pi / 4 * eff * eff);
    case 'H형강':
      final n = _nums(size);
      if (n == null || n.length != 4) return null;
      // 높이x폭x웨브t x플랜지t.
      return fromArea(2 * n[1] * n[3] + (n[0] - 2 * n[3]) * n[2]);
  }
  return null;
}

/// 길이 [lengthMm]인 조각의 이론 중량(kg). 모르는 규격은 null.
double? steelWeightKg(String shapeLabel, double lengthMm) {
  final u = steelKgPerM(shapeLabel);
  return u == null ? null : u * lengthMm / 1000;
}

/// 프로젝트 목록 줄에 보이는 무게 글("약 12.0kg"). 세트 수를 곱하고, 무게를 모르는 규격이 섞여 있으면
/// 그만큼 더 나가니 "이상"을 붙인다. 아무것도 모르면 빈 글자.
String steelProjectWeightText(SteelCuttingProject project) {
  var kg = 0.0;
  var known = 0;
  var unknown = 0;
  for (final i in project.items) {
    final w = steelWeightKg(i.shapeLabel, i.length * i.qty);
    if (w == null) {
      unknown++;
    } else {
      kg += w * project.setMultiplier;
      known++;
    }
  }
  if (known == 0) return '';
  return '약 ${fmtKg(kg)}kg${unknown > 0 ? ' 이상' : ''}';
}

/// 규격 선택창에 붙이는 형태 설명. 립(입술)이 있는지 없는지가 무게에 크게 영향을 준다.
/// 목록의 경량 찬넬(두께 3.2 이하)은 립 없는 ㄷ형, 립C형강은 립 있는 C형이다. 해당 없으면 빈 글자.
String steelShapeNote(String shapeLabel) {
  final label = shapeLabel.trim();
  if (label.startsWith('립C형강 ')) return '립 있는 C형';
  if (label.startsWith('찬넬 ')) {
    final size = label.substring(3).trim().toLowerCase();
    if (_rolledChannelKgPerM.containsKey(size)) return '';
    final n = _nums(size);
    if (n != null && n.length == 3 && n[2] <= 3.2) {
      return '립 없는 ㄷ형 (립 있으면 립C형강)';
    }
  }
  return '';
}
