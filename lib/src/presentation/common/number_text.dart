// 칸에 적은 글을 숫자로 읽는 공용 규칙(전기 설비 계산의 모든 숫자 칸).
// 쉼표를 칸마다 다르게 읽던 것(어디는 지우고 어디는 소수점으로)을 하나로 맞춘다.

final RegExp _thousands = RegExp(r'^[−-]?\d{1,3}(,\d{3})+(\.\d+)?$');

/// 숫자 글 → 숫자. 읽을 수 없으면 null.
/// - "1,500", "1,500.5": 쉼표는 천 단위 구분이라 지운다.
/// - "1,5", "0,85": 쉼표가 하나이고 뒤가 세 자리가 아니면 소수점으로 읽는다(1.5, 0.85).
/// - "1.500,5": 마지막 쉼표가 마지막 점 뒤에 있으면 쉼표를 소수점으로 읽는다.
double? parseNumberText(String text) {
  var s = text.trim().replaceAll('−', '-').replaceAll(' ', '');
  if (s.isEmpty) return null;
  if (!s.contains(',')) return double.tryParse(s);
  if (_thousands.hasMatch(s)) return double.tryParse(s.replaceAll(',', ''));
  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastDot >= 0 && lastComma > lastDot) {
    // 1.500,5 → 1500.5
    return double.tryParse(s.replaceAll('.', '').replaceAll(',', '.'));
  }
  if (lastDot < 0 && s.indexOf(',') == lastComma) {
    // 쉼표 하나: 소수점
    return double.tryParse(s.replaceAll(',', '.'));
  }
  return double.tryParse(s.replaceAll(',', ''));
}
