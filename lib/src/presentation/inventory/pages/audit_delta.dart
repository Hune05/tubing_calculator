// 재고조사 한 줄을 서버에 올릴 때의 셈. 화면과 떼어 놓아서 검사할 수 있게 한다.
//
// 예전엔 센 수량으로 서버 수량을 통째로 덮어썼다. 창고에서 세 놓고, 낮에 컷팅에서
// 자재를 빼고, 저녁에 올리면 낮에 뺀 것이 사라졌다. 그래서 "센 값 − 셀 때 장부 값"만
// 더하고 뺀다(센 뒤에 움직인 것은 그대로 남는다).

/// 재고조사 한 줄을 올린 결과.
class AuditDelta {
  /// 서버 수량에 더할 값(빼면 음수). 0이면 수량은 안 건드린다.
  final int delta;

  /// 센 뒤 올리기 전까지 다른 곳(컷팅 차감 등)에서 움직인 양. 장부를 모르면 0.
  final int movedSinceCount;

  /// 올린 뒤 서버 수량.
  final int after;

  /// 0 아래로 내려가서 0으로 맞췄는지.
  final bool clamped;

  const AuditDelta({
    required this.delta,
    required this.movedSinceCount,
    required this.after,
    this.clamped = false,
  });
}

/// [counted]: 센 수량, [book]: 세기 시작할 때 장부 수량(모르면 null),
/// [server]: 올리는 지금 서버 수량.
AuditDelta auditDelta({
  required int counted,
  required int? book,
  required int server,
}) {
  // 장부를 모르면 예전처럼 센 값으로 맞춘다.
  if (book == null) {
    return AuditDelta(
      delta: counted - server,
      movedSinceCount: 0,
      after: counted,
    );
  }
  final moved = server - book;
  final after = server + (counted - book);
  // 센 뒤에 센 것보다 많이 빠졌으면(세기가 틀렸거나 빼기를 먼저 적었거나) 0에서 멈춘다.
  if (after < 0) {
    return AuditDelta(
      delta: -server,
      movedSinceCount: moved,
      after: 0,
      clamped: true,
    );
  }
  return AuditDelta(
    delta: counted - book,
    movedSinceCount: moved,
    after: after,
  );
}
