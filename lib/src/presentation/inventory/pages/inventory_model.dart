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

  /// 세기 시작할 때 서버(장부) 수량. 올릴 때 "센 값 − 이 값"만 더하고 빼서,
  /// 센 뒤 올리기 전에 컷팅 차감 등으로 움직인 것이 지워지지 않게 한다.
  /// 모르면(null) 예전처럼 센 값으로 맞춘다.
  int? bookQty;

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
    this.bookQty,
  });
}
