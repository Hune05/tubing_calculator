/// 입력 목록 되돌리기 / 다시 하기(튜브·전선관 목록 관리자가 같이 쓴다).
///
/// 🚀 [추가] 예전에는 지운 줄만 잠깐 되돌릴 수 있었다. 이제 넣기·고치기·
/// 순서 바꾸기·지우기·전체 삭제를 모두 한 단계씩 되돌린다. 앱을 끄면 비운다.
library;

import 'package:flutter/foundation.dart';

/// 되돌리기 한 단계: 목록과, 같이 되돌릴 값(꼬리·피팅·방향 등, 없으면 null).
typedef _Step = ({List<Map<String, dynamic>> list, Map<String, dynamic>? extras});

mixin BendListHistory on ChangeNotifier {
  static const int maxSteps = 50;

  final List<_Step> _undo = [];
  final List<_Step> _redo = [];

  /// 목록 말고 같이 되돌릴 값을 읽는다/되살린다. 10-09: 보관함 불러오기·U벤드는 꼬리·피팅·방향도
  /// 바꾸는데 ↶가 목록만 되돌려, 옛 목록이 불러온 도면의 꼬리·피팅으로 셈해졌다.
  /// 평소 목록 고치기에는 담지 않는다(그사이 손으로 바꾼 꼬리를 되돌리면 안 된다).
  Map<String, dynamic> captureHistoryExtras() => const {};
  void restoreHistoryExtras(Map<String, dynamic> extras) {}

  bool _extrasNext = false;

  /// 다음 한 번의 기록에 같이 되돌릴 값도 담는다(목록을 바꾸는 다른 함수를 거칠 때).
  void captureExtrasInNextRecord() => _extrasNext = true;

  /// 관리자가 들고 있는 목록.
  List<Map<String, dynamic>> get historyTarget;
  set historyTarget(List<Map<String, dynamic>> v);

  /// 목록이 바뀐 뒤 폰에 적는다.
  void persistHistoryTarget();

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// 50단계를 넘어 맨 앞에서 버린 단계 수. [undoDepth]를 버려도 줄지 않는 "위치"로 만든다.
  int _dropped = 0;

  /// 지금 위치(쌓인 단계 수 + 버린 단계 수). 지운 줄 "되돌리기" 알림이 그새 다른 일이 없었는지,
  /// 불러온 도면 위치보다 앞으로 되돌렸는지 볼 때 쓴다. 10-07: 예전에는 쌓인 단계 수라 50단계가
  /// 찬 뒤로는 늘 50이어서, 다른 줄이 사라지거나 원본 기억이 잘못 지워졌다.
  int get undoDepth => _dropped + _undo.length;

  static List<Map<String, dynamic>> _copy(List<Map<String, dynamic>> l) => [
    for (final m in l) Map<String, dynamic>.from(m),
  ];

  /// 목록을 바꾸기 직전에 부른다. [withExtras]면 같이 되돌릴 값도 담는다.
  /// [onlyKeys]를 주면 그 칸만 담는다(8차: 전체 지우기는 덮어쓰기 대상만 — 그사이 손으로 바꾼
  /// 꼬리·방향까지 되돌리면 안 된다).
  @protected
  void recordHistory({bool withExtras = false, Set<String>? onlyKeys}) {
    Map<String, dynamic>? extras = (withExtras || _extrasNext)
        ? Map<String, dynamic>.from(captureHistoryExtras())
        : null;
    if (extras != null && onlyKeys != null) {
      extras.removeWhere((k, _) => !onlyKeys.contains(k));
    }
    _extrasNext = false;
    _undo.add((list: _copy(historyTarget), extras: extras));
    if (_undo.length > maxSteps) {
      _undo.removeAt(0);
      _dropped++;
    }
    _redo.clear();
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    final step = _undo.removeLast();
    _redo.add((
      list: _copy(historyTarget),
      extras: _sameKeys(step.extras),
    ));
    historyTarget = step.list;
    if (step.extras != null) restoreHistoryExtras(step.extras!);
    persistHistoryTarget();
    notifyListeners();
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) return false;
    final step = _redo.removeLast();
    _undo.add((
      list: _copy(historyTarget),
      extras: _sameKeys(step.extras),
    ));
    historyTarget = step.list;
    if (step.extras != null) restoreHistoryExtras(step.extras!);
    persistHistoryTarget();
    notifyListeners();
    return true;
  }

  /// 되돌릴 단계가 담은 칸과 같은 칸만 지금 값으로 담는다(다시 하기용).
  Map<String, dynamic>? _sameKeys(Map<String, dynamic>? like) {
    if (like == null) return null;
    final now = captureHistoryExtras();
    return {
      for (final k in like.keys)
        if (now.containsKey(k)) k: now[k],
    };
  }

  void clearHistory() {
    _undo.clear();
    _redo.clear();
  }
}
