// 폰에 있는 것 먼저 보이고, 서버 것은 뒤에서 받아 바꾼다(UI 디자인 제안 D-F).
//
// 예전에는 목록 화면이 서버 응답(통신이 없으면 최대 6초)을 기다리는 동안 빈 화면이었다.
// Procore·Fieldwire처럼 폰에 남아 있는 목록을 바로 그리고, 새 목록이 오면 바꿔 끼운다.
// 폰에 아무것도 없을 때만 목록 모양(LoadingList)을 보인다.
library;

/// [cached]로 폰에 있는 것을 먼저 읽어 비어 있지 않으면 `onData(값, fresh: false)`,
/// 이어서 [fresh]로 서버 것을 읽어 `onData(값, fresh: true)`.
///
/// - 폰 읽기가 실패하거나 비었으면 건너뛴다(서버 것만 기다린다).
/// - 서버 읽기가 실패하면 [onError]. 먼저 보인 폰 목록은 그대로 둔다.
Future<void> loadCacheFirst<T>({
  required Future<T?> Function() cached,
  required Future<T> Function() fresh,
  required void Function(T data, {required bool fresh}) onData,
  required bool Function(T data) isEmpty,
  void Function(Object error, {required bool hadCache})? onError,
}) async {
  var hadCache = false;
  try {
    final c = await cached();
    if (c != null && !isEmpty(c)) {
      hadCache = true;
      onData(c, fresh: false);
    }
  } catch (_) {
    // 폰에 없거나 읽지 못함: 서버 것을 기다린다.
  }
  try {
    final f = await fresh();
    onData(f, fresh: true);
  } catch (e) {
    onError?.call(e, hadCache: hadCache);
  }
}
