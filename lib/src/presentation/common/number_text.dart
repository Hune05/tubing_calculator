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

/// % 칸에 1 이하를 넣었을 때 칸 아래에 붙이는 안내 글. 없으면 null.
/// - 효율·역률·부하율·이용률처럼 0.85도 85도 같은 뜻으로 읽는 칸: "비율로 읽어 85%로 계산합니다".
/// - 여유·슬립처럼 넣은 그대로 %로 읽는 칸: "0.2%로 계산됩니다. 비율이면 20처럼 넣으십시오".
/// 칸 이름에 "%"가 있고 값이 0 초과 1 이하일 때만 보인다.
String? ratioHintText(String label, String text) {
  if (!label.contains('%')) return null;
  const lenient = ['효율', '역률', '수용률', '부하율', '조명률', '이용률', '시작 전압', 'cosφ'];
  const strict = ['여유', '슬립'];
  final isLenient = lenient.any(label.contains);
  final isStrict = !isLenient && strict.any(label.contains);
  if (!isLenient && !isStrict) return null;
  final v = parseNumberText(text);
  if (v == null || v <= 0 || v > 1) return null;
  String t(double x) {
    var s = x.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }
  if (isLenient) {
    return '${t(v)}은 비율로 읽어 ${t(v * 100)}%로 계산합니다. 퍼센트는 85처럼 넣으십시오.';
  }
  return '이 칸은 %라서 ${t(v)}%로 계산됩니다. 비율이면 ${t(v * 100)}처럼 넣으십시오.';
}

/// % 칸에 1 이하를 넣었을 때 칸 안 숫자 뒤에 붙이는 짧은 글("= 70%"). 실제로 계산에 쓰는 %다.
/// 칸 아래에 줄을 더하면 아래 칸이 밀려서, 칸 높이가 바뀌지 않게 숫자 뒤에 붙인다.
String? ratioSuffixText(String label, String text) {
  final long = ratioHintText(label, text);
  if (long == null) return null;
  final v = parseNumberText(text)!;
  final lenient = long.contains('비율로 읽어');
  var n = (lenient ? v * 100 : v).toStringAsFixed(2);
  n = n.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return '= $n%';
}
