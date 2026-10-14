// 손가락 서명을 그림 파일 대신 획 좌표 글로 적고 읽는다(10-14). 안전 점검(TBM) 참석자 서명과
// 작업 일지 확인 서명이 같이 쓴다. 한 명 1~3KB.
library;

/// 서명 칸 비율(가로:세로 = 1000:400). 좌표는 이 정수 칸에 맞춰 적는다.
const double kSigW = 1000, kSigH = 400;

/// 획 목록(칸 크기 [w]×[h] 안의 좌표)을 글로: "v1:x,y x,y;x,y …". 가까운 점(4칸 안)은 건너뛴다.
String encodeSignature(
  List<List<(double, double)>> strokes,
  double w,
  double h,
) {
  if (w <= 0 || h <= 0) return '';
  final out = <String>[];
  for (final st in strokes) {
    final pts = <String>[];
    int? lx, ly;
    for (var i = 0; i < st.length; i++) {
      final x = (st[i].$1 / w * kSigW).round().clamp(0, kSigW.toInt());
      final y = (st[i].$2 / h * kSigH).round().clamp(0, kSigH.toInt());
      if (lx == x && ly == y) continue;
      final last = i == st.length - 1;
      if (lx != null && !last && (x - lx).abs() + (y - ly!).abs() < 4) {
        continue;
      }
      pts.add('$x,$y');
      lx = x;
      ly = y;
    }
    if (pts.isNotEmpty) out.add(pts.join(' '));
  }
  return out.isEmpty ? '' : 'v1:${out.join(';')}';
}

/// [encodeSignature] 글을 획 목록(가로 0~1000, 세로 0~400)으로. 깨진 글이면 빈 목록.
List<List<(double, double)>> decodeSignature(String sig) {
  if (!sig.startsWith('v1:')) return const [];
  final out = <List<(double, double)>>[];
  for (final st in sig.substring(3).split(';')) {
    final pts = <(double, double)>[];
    for (final p in st.split(' ')) {
      final xy = p.split(',');
      if (xy.length != 2) continue;
      final x = double.tryParse(xy[0]), y = double.tryParse(xy[1]);
      if (x != null && y != null) pts.add((x, y));
    }
    if (pts.isNotEmpty) out.add(pts);
  }
  return out;
}
