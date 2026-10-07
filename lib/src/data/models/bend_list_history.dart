/// 입력 목록 되돌리기 / 다시 하기(튜브·전선관 목록 관리자가 같이 쓴다).
///
/// 🚀 [추가] 예전에는 지운 줄만 잠깐 되돌릴 수 있었다. 이제 넣기·고치기·
/// 순서 바꾸기·지우기·전체 삭제를 모두 한 단계씩 되돌린다. 앱을 끄면 비운다.
library;

import 'package:flutter/foundation.dart';

mixin BendListHistory on ChangeNotifier {
  static const int maxSteps = 50;

  final List<List<Map<String, dynamic>>> _undo = [];
  final List<List<Map<String, dynamic>>> _redo = [];

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

  /// 목록을 바꾸기 직전에 부른다.
  @protected
  void recordHistory() {
    _undo.add(_copy(historyTarget));
    if (_undo.length > maxSteps) {
      _undo.removeAt(0);
      _dropped++;
    }
    _redo.clear();
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    _redo.add(_copy(historyTarget));
    historyTarget = _undo.removeLast();
    persistHistoryTarget();
    notifyListeners();
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) return false;
    _undo.add(_copy(historyTarget));
    historyTarget = _redo.removeLast();
    persistHistoryTarget();
    notifyListeners();
    return true;
  }

  void clearHistory() {
    _undo.clear();
    _redo.clear();
  }
}
