class ItemData {
  int qty;
  String heatNo;
  String maker;
  String material;
  String location;
  String spec;
  String projectName;
  int minQty;
  String department; // ★ 신규: 담당 부서/팀 추가

  ItemData({
    this.qty = 0,
    this.heatNo = "",
    this.maker = "",
    this.material = "",
    this.location = "",
    this.spec = "",
    this.projectName = "",
    this.minQty = 0,
    this.department = "", // ★ 신규: 기본값 초기화
  });
}
