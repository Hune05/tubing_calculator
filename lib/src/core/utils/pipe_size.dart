/// 관 규격 글에서 바깥지름(mm)을 뽑는다.
///
/// 3D 그림에서 관 굵기를 실제대로 그릴 때 쓴다. 앱 곳곳이 규격을 저마다
/// 다른 모양으로 적어 둬서(1/2" · 0.5" · 12.7mm · G22 · E25 · 22mm),
/// 한 곳에서 다 읽게 모아 둔다. 못 읽으면 0.
///
/// 🚀 [고침] 보관함에 저장해 둔 도면에는 제원이 안 남아 있어서, 열어 보면
/// 관 굵기를 몰라 곡선부가 그려지지 않았다. 저장된 규격 글로 굵기를 잡는다.
library;

double pipeSizeToMm(String size) {
  var s = size.trim();
  if (s.isEmpty) return 0.0;

  // "22mm", "12.7 mm"
  final mm = RegExp(r'(\d+(?:\.\d+)?)\s*mm', caseSensitive: false)
      .firstMatch(s);
  if (mm != null) return double.tryParse(mm.group(1)!) ?? 0.0;

  // 인치 표기: 따옴표나 inch가 붙어 있으면 mm로 바꾼다.
  final isInch =
      s.contains('"') ||
      s.contains('”') ||
      s.contains('″') ||
      s.toLowerCase().contains('inch');
  if (isInch) {
    s = s
        .replaceAll('"', '')
        .replaceAll('”', '')
        .replaceAll('″', '')
        .replaceAll(RegExp(r'inch', caseSensitive: false), '')
        .trim();
    // "1/2", "3/4"
    final frac = RegExp(r'^(\d+)\s*/\s*(\d+)').firstMatch(s);
    if (frac != null) {
      final a = double.tryParse(frac.group(1)!) ?? 0;
      final b = double.tryParse(frac.group(2)!) ?? 0;
      if (b > 0) return a / b * 25.4;
    }
    final num = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(s);
    if (num != null) return (double.tryParse(num.group(1)!) ?? 0) * 25.4;
    return 0.0;
  }

  // "G22", "E25" 처럼 글자 뒤 숫자가 곧 지름.
  final letter = RegExp(r'^[A-Za-z]+\s*(\d+(?:\.\d+)?)$').firstMatch(s);
  if (letter != null) return double.tryParse(letter.group(1)!) ?? 0.0;

  // 따옴표 없는 분수는 인치로 본다("1/2").
  final frac = RegExp(r'^(\d+)\s*/\s*(\d+)$').firstMatch(s);
  if (frac != null) {
    final a = double.tryParse(frac.group(1)!) ?? 0;
    final b = double.tryParse(frac.group(2)!) ?? 0;
    if (b > 0) return a / b * 25.4;
  }

  final plain = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(s);
  if (plain == null) return 0.0;
  final v = double.tryParse(plain.group(1)!) ?? 0.0;
  // 1보다 작은 값은 인치로 적은 것으로 본다(0.5 → 12.7mm).
  return v > 0 && v < 1.5 ? v * 25.4 : v;
}
