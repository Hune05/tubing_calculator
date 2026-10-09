// 배관 플랜지 볼트 표(ASME B16.5)와 조임 순서(ASME PCC-1 부록 F 옛 방식 "Legacy" 별 모양), 10-10.
// 값은 ASME B16.5 볼트 표를 옮긴 것(engineeringtoolbox·projectmaterials 표와 대조해 같음).
// 토크 값은 가스켓·볼트 재질·윤활에 따라 달라 넣지 않는다(회사 절차서·가스켓 제조사 값).

class FlangeBoltRow {
  final String nps; // 호칭(인치)
  final String a; // 호칭(A)
  final int bolts; // 볼트 수
  final String dia; // 볼트 지름(인치)
  final double circleIn; // 볼트 원 지름(인치)
  const FlangeBoltRow(this.nps, this.a, this.bolts, this.dia, this.circleIn);

  /// 볼트 원 지름(mm, 소수 한 자리).
  double get circleMm => (circleIn * 25.4 * 10).roundToDouble() / 10;
}

/// 클래스 → 표(1/2"~24").
const Map<int, List<FlangeBoltRow>> kFlangeBolts = {
  150: [
    FlangeBoltRow('1/2"', '15A', 4, '1/2"', 2.375),
    FlangeBoltRow('3/4"', '20A', 4, '1/2"', 2.75),
    FlangeBoltRow('1"', '25A', 4, '1/2"', 3.125),
    FlangeBoltRow('1-1/4"', '32A', 4, '1/2"', 3.5),
    FlangeBoltRow('1-1/2"', '40A', 4, '1/2"', 3.875),
    FlangeBoltRow('2"', '50A', 4, '5/8"', 4.75),
    FlangeBoltRow('2-1/2"', '65A', 4, '5/8"', 5.5),
    FlangeBoltRow('3"', '80A', 4, '5/8"', 6),
    FlangeBoltRow('3-1/2"', '90A', 8, '5/8"', 7),
    FlangeBoltRow('4"', '100A', 8, '5/8"', 7.5),
    FlangeBoltRow('5"', '125A', 8, '3/4"', 8.5),
    FlangeBoltRow('6"', '150A', 8, '3/4"', 9.5),
    FlangeBoltRow('8"', '200A', 8, '3/4"', 11.75),
    FlangeBoltRow('10"', '250A', 12, '7/8"', 14.25),
    FlangeBoltRow('12"', '300A', 12, '7/8"', 17),
    FlangeBoltRow('14"', '350A', 12, '1"', 18.75),
    FlangeBoltRow('16"', '400A', 16, '1"', 21.25),
    FlangeBoltRow('18"', '450A', 16, '1-1/8"', 22.75),
    FlangeBoltRow('20"', '500A', 20, '1-1/8"', 25),
    FlangeBoltRow('24"', '600A', 20, '1-1/4"', 29.5),
  ],
  300: [
    FlangeBoltRow('1/2"', '15A', 4, '1/2"', 2.625),
    FlangeBoltRow('3/4"', '20A', 4, '5/8"', 3.25),
    FlangeBoltRow('1"', '25A', 4, '5/8"', 3.5),
    FlangeBoltRow('1-1/4"', '32A', 4, '5/8"', 3.875),
    FlangeBoltRow('1-1/2"', '40A', 4, '3/4"', 4.5),
    FlangeBoltRow('2"', '50A', 8, '5/8"', 5),
    FlangeBoltRow('2-1/2"', '65A', 8, '3/4"', 5.875),
    FlangeBoltRow('3"', '80A', 8, '3/4"', 6.625),
    FlangeBoltRow('3-1/2"', '90A', 8, '3/4"', 7.25),
    FlangeBoltRow('4"', '100A', 8, '3/4"', 7.875),
    FlangeBoltRow('5"', '125A', 8, '3/4"', 9.25),
    FlangeBoltRow('6"', '150A', 12, '3/4"', 10.625),
    FlangeBoltRow('8"', '200A', 12, '7/8"', 13),
    FlangeBoltRow('10"', '250A', 16, '1"', 15.25),
    FlangeBoltRow('12"', '300A', 16, '1-1/8"', 17.75),
    FlangeBoltRow('14"', '350A', 20, '1-1/8"', 20.25),
    FlangeBoltRow('16"', '400A', 20, '1-1/4"', 22.5),
    FlangeBoltRow('18"', '450A', 24, '1-1/4"', 24.75),
    FlangeBoltRow('20"', '500A', 24, '1-1/4"', 27),
    FlangeBoltRow('24"', '600A', 24, '1-1/2"', 32),
  ],
  600: [
    FlangeBoltRow('1/2"', '15A', 4, '1/2"', 2.625),
    FlangeBoltRow('3/4"', '20A', 4, '5/8"', 3.25),
    FlangeBoltRow('1"', '25A', 4, '5/8"', 3.5),
    FlangeBoltRow('1-1/4"', '32A', 4, '5/8"', 3.875),
    FlangeBoltRow('1-1/2"', '40A', 4, '3/4"', 4.5),
    FlangeBoltRow('2"', '50A', 8, '5/8"', 5),
    FlangeBoltRow('2-1/2"', '65A', 8, '3/4"', 5.875),
    FlangeBoltRow('3"', '80A', 8, '3/4"', 6.625),
    FlangeBoltRow('3-1/2"', '90A', 8, '7/8"', 7.25),
    FlangeBoltRow('4"', '100A', 8, '7/8"', 8.5),
    FlangeBoltRow('5"', '125A', 8, '1"', 10.5),
    FlangeBoltRow('6"', '150A', 12, '1"', 11.5),
    FlangeBoltRow('8"', '200A', 12, '1-1/8"', 13.75),
    FlangeBoltRow('10"', '250A', 16, '1-1/4"', 17),
    FlangeBoltRow('12"', '300A', 20, '1-1/4"', 19.25),
    FlangeBoltRow('14"', '350A', 20, '1-3/8"', 20.75),
    FlangeBoltRow('16"', '400A', 20, '1-1/2"', 23.75),
    FlangeBoltRow('18"', '450A', 20, '1-5/8"', 25.75),
    FlangeBoltRow('20"', '500A', 24, '1-5/8"', 28.5),
    FlangeBoltRow('24"', '600A', 24, '1-7/8"', 33),
  ],
};

/// 볼트 수 → 조임 순서(볼트 번호는 12시 방향이 1, 시계 방향으로 2, 3 …).
/// 마주 보는 볼트를 잇달아 조이고 90° 돌아 다음 한 쌍을 조인다(네 개가 한 묶음).
const Map<int, List<int>> kFlangeTightenOrder = {
  4: [1, 3, 2, 4],
  8: [1, 5, 3, 7, 2, 6, 4, 8],
  12: [1, 7, 4, 10, 2, 8, 5, 11, 3, 9, 6, 12],
  16: [1, 9, 5, 13, 3, 11, 7, 15, 2, 10, 6, 14, 4, 12, 8, 16],
  20: [1, 11, 6, 16, 3, 13, 8, 18, 5, 15, 10, 20, 2, 12, 7, 17, 4, 14, 9, 19],
  24: [
    1, 13, 7, 19, 4, 16, 10, 22, 2, 14, 8, 20, //
    5, 17, 11, 23, 3, 15, 9, 21, 6, 18, 12, 24,
  ],
};

/// 순서를 네 개씩 묶은 글. 예: "1-5-3-7 · 2-6-4-8"
String flangeOrderText(int bolts) {
  final o = kFlangeTightenOrder[bolts];
  if (o == null) return '';
  return [
    for (int i = 0; i < o.length; i += 4) o.skip(i).take(4).join('-'),
  ].join(' · ');
}
