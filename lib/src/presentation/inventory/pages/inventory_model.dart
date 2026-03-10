class ItemData {
  int qty;
  String heatNo;
  String maker;
  String material;
  String location; // ★ 신규: 보관 위치 속성 추가

  ItemData({
    this.qty = 0,
    this.heatNo = "",
    this.maker = "",
    this.material = "",
    this.location = "", // ★ 신규: 기본값 빈 문자열로 초기화
  });
}
