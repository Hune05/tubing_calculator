// 계산기 화면에서 쓰는 "최근 계산 기록" 버튼·시트 — 리모컨 화면의 "최근 전송 기록"과 같은 방식
// (2026-09-29 사용자 요청). 저장 버튼 없이 계산할 때마다 자동으로 쌓인다. 저장 칸을 정한 화면은
// 폰에 이틀 동안 남겨 앱을 다시 열어도 보이고 눌러 되돌릴 수 있다(10-07). "저장한 기록"과는 다른 가벼운 목록.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/field_view.dart';
import 'app_components.dart';

class RecentCalcEntry {
  final String title;
  final String subtitle;
  final DateTime time;
  final VoidCallback? onTap;

  /// 되돌리기용: 기록이 나온 탭의 이름 키와 그때 입력값(JSON 글). 폰에 저장했다가 다시 열어도 되돌린다.
  final String? restoreKey;
  final String? restoreData;
  const RecentCalcEntry({
    required this.title,
    required this.subtitle,
    required this.time,
    this.onTap,
    this.restoreKey,
    this.restoreData,
  });

  Map<String, Object?> toJson() => {
    't': title,
    's': subtitle,
    'at': time.toIso8601String(),
    if (restoreKey != null) 'k': restoreKey,
    if (restoreData != null) 'd': restoreData,
  };
}

/// 폰에 남긴 기록을 얼마 동안 두는지. 어제 계산한 것을 다음 날 현장에서 되돌려 볼 수 있게 이틀(10-07).
const Duration kCalcHistoryKeep = Duration(hours: 48);

/// 기록 쌓기 그 자체(디바운스·중복 방지·최대 개수). 보통은 [RecentCalcHistoryMixin]이
/// 화면마다 하나씩 따로 갖지만, 탭이 여러 화면 파일로 나뉜 계산기(전기 설비 계산처럼)는
/// 이 객체 하나를 만들어 각 탭 State에 나눠 주면 기록을 한 목록으로 합칠 수 있다.
/// [attachStorage]를 부르면 폰에 저장해 앱을 다시 열어도 [kCalcHistoryKeep] 동안 남는다.
class RecentCalcLog {
  final List<RecentCalcEntry> entries = [];

  /// 기록을 눌러 그때 입력값으로 되돌릴 때 그 기록의 탭을 앞으로 띄우는 일.
  /// 탭이 여러 개인 화면(전기 설비 계산)이 정해 준다. 탭 이름 키(요약 줄 키)를 받는다.
  void Function(String tabKey)? openTab;

  /// 탭 이름 키 → 그 탭에 입력값을 다시 넣는 일. 탭 State가 그려질 때 스스로 등록한다.
  final Map<String, void Function(String data)> restorers = {};

  /// 되돌리지 못했을 때 알리는 일(그 화면이 알림을 띄운다). 시험에서도 바꿔 끼운다.
  void Function(String message)? onRestoreFail;

  /// 탭이 준비되지 않아 되돌리지 못했을 때.
  static const String kNotReady = '그 계산 화면이 준비되지 않아 되돌리지 못했습니다. 다시 눌러 보십시오';

  /// 앱이 바뀌어 옛 기록의 입력값을 읽을 수 없을 때.
  static const String kBadData = '앱이 바뀌기 전 기록이라 되돌릴 수 없습니다';

  Timer? _debounce;
  String? _lastKey;
  VoidCallback? _onChange;
  String? _storageKey;
  static const int _maxEntries = 20;

  /// 시험에서 시각을 정할 때.
  static DateTime Function() now = DateTime.now;

  /// 계산 값이 바뀔 때마다 부른다. 같은 값이 잠깐(700ms) 유지되면 그때 한 번만 기록에 쌓는다
  /// (매 키 입력마다 쌓이는 걸 막기 위한 디바운스). [dedupeKey]가 이전과 같으면 새로 쌓지 않는다.
  /// [restoreKey]·[restoreData]를 주면 기록을 눌러 그때 입력값으로 되돌릴 수 있다([restore]).
  void log(
    String title,
    String subtitle, {
    String? dedupeKey,
    VoidCallback? onTap,
    String? restoreKey,
    String? restoreData,
  }) {
    final key = dedupeKey ?? '$title|$subtitle';
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      if (key == _lastKey) return;
      _lastKey = key;
      entries.insert(
        0,
        _entry(title, subtitle, now(), onTap, restoreKey, restoreData),
      );
      if (entries.length > _maxEntries) entries.removeLast();
      _onChange?.call();
      _save();
    });
  }

  RecentCalcEntry _entry(
    String title,
    String subtitle,
    DateTime at,
    VoidCallback? onTap,
    String? k,
    String? d,
  ) => RecentCalcEntry(
    title: title,
    subtitle: subtitle,
    time: at,
    restoreKey: k,
    restoreData: d,
    onTap: d == null ? onTap : () => restore(k ?? '', d),
  );

  /// 기록 하나를 되돌린다: 그 탭을 앞으로 띄우고, 그 탭이 준비되면(앱을 다시 연 뒤에는 탭이 아직
  /// 그려지지 않았을 수 있다) 입력값을 넣는다. 조금 기다려도 준비되지 않거나, 앱이 바뀌어 옛 입력값을
  /// 읽지 못하면 그만두고 [onRestoreFail]로 알린다(빨간 오류 화면 대신).
  void restore(String key, String data, {int tries = 30}) {
    openTab?.call(key);
    void attempt(int left) {
      final r = restorers[key];
      if (r != null) {
        try {
          r(data);
        } catch (_) {
          onRestoreFail?.call(kBadData);
        }
        return;
      }
      if (left <= 0) {
        onRestoreFail?.call(kNotReady);
        return;
      }
      Timer(const Duration(milliseconds: 50), () => attempt(left - 1));
    }

    attempt(tries);
  }

  /// 폰 저장 칸 [key]에 기록을 남기고, 남아 있던 기록(이틀 안)을 읽어 붙인다.
  Future<void> attachStorage(String key) async {
    if (_storageKey == key) return;
    _storageKey = key;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(key);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      final cut = now().subtract(kCalcHistoryKeep);
      final loaded = <RecentCalcEntry>[];
      for (final m in list) {
        if (m is! Map) continue;
        final at = DateTime.tryParse('${m['at']}');
        if (at == null || at.isBefore(cut)) continue;
        if (m['t'] is! String || m['s'] is! String) continue;
        loaded.add(
          _entry(
            m['t'] as String,
            m['s'] as String,
            at,
            null,
            m['k'] as String?,
            m['d'] as String?,
          ),
        );
      }
      // 이 화면을 연 뒤에 이미 쌓인 기록이 있으면 그 뒤에 붙인다.
      entries.addAll(loaded.take(_maxEntries - entries.length));
      _onChange?.call();
    } catch (_) {
      // 못 읽어도 새 기록은 쌓인다.
    }
  }

  Future<void> _save() async {
    final key = _storageKey;
    if (key == null) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        key,
        jsonEncode([for (final e in entries) e.toJson()]),
      );
    } catch (_) {}
  }

  void dispose() => _debounce?.cancel();
}

/// 계산기 State에 섞어 쓰는 믹스인. 자동 기록 쌓기(디바운스)와 버튼 위젯을 준다.
/// 여러 State가 기록 하나를 같이 쓰려면 [calcLog]를 override해서 밖에서 만든
/// [RecentCalcLog]를 돌려주면 된다(기본은 이 State만 쓰는 것 하나를 스스로 만든다).
/// [calcHistoryStorageKey]를 정하면 이 State가 가진 기록을 폰에 남긴다(이틀).
mixin RecentCalcHistoryMixin<W extends StatefulWidget> on State<W> {
  final RecentCalcLog _ownLog = RecentCalcLog();
  RecentCalcLog get calcLog => _ownLog;
  List<RecentCalcEntry> get calcHistory => calcLog.entries;

  /// 기록이 바뀌면 다시 그린다. setState를 쓰지 않는 까닭: setState를 덮어써 "사용자가 값을 건드림"으로
  /// 보는 화면(유량 계산)이 있어, 기록을 읽은 것만으로 저장된 입력값을 안 불러오게 됐다.
  void _redraw() {
    if (mounted) (context as Element).markNeedsBuild();
  }

  /// 폰에 남길 저장 칸 이름. null이면 화면을 나가면 사라진다.
  String? get calcHistoryStorageKey => null;

  /// 화면 하나짜리 계산기의 되돌리기: 지금 입력값을 글(JSON)로 돌려주면 기록마다 함께 남고,
  /// 기록을 누르면 [calcRestoreApply]로 그 값을 넣은 뒤 "원래대로"를 띄운다. null이면 되돌리기 없음.
  String? calcRestoreSnapshot() => null;

  /// [calcRestoreSnapshot]이 만든 글을 칸에 다시 넣는다(setState 안에서 불린다).
  void calcRestoreApply(String raw) {}

  static const String _selfKey = '_self';

  void _restoreSelf(String raw) {
    if (!mounted) return;
    final before = calcRestoreSnapshot();
    try {
      setState(() => calcRestoreApply(raw));
    } catch (_) {
      // 옛 기록을 반쯤 넣다 멈추면 칸이 뒤섞이니 누르기 전 값으로 되돌려 놓고 알린다.
      if (before != null) setState(() => calcRestoreApply(before));
      rethrow;
    }
    showAppSnack(
      context,
      '그때 입력값으로 되돌렸습니다',
      kind: AppSnackKind.undo,
      undoLabel: '원래대로',
      onUndo: before == null
          ? null
          : () {
              if (mounted) setState(() => calcRestoreApply(before));
            },
    );
  }

  @override
  void initState() {
    super.initState();
    final k = calcHistoryStorageKey;
    // 밖에서 받은 기록(여러 탭이 같이 쓰는 것)은 그 주인이 저장한다.
    if (k != null && identical(calcLog, _ownLog)) {
      _ownLog._onChange = _redraw;
      _ownLog.attachStorage(k);
    }
    if (identical(calcLog, _ownLog)) {
      _ownLog.restorers[_selfKey] = _restoreSelf;
      _ownLog.onRestoreFail = (m) {
        if (mounted) showAppSnack(context, m, kind: AppSnackKind.error);
      };
    }
  }

  void logCalc(
    String title,
    String subtitle, {
    String? dedupeKey,
    VoidCallback? onTap,
    String? restoreKey,
    String? restoreData,
  }) {
    calcLog._onChange = _redraw;
    if (restoreKey == null && identical(calcLog, _ownLog)) {
      final snap = calcRestoreSnapshot();
      if (snap != null) {
        restoreKey = _selfKey;
        restoreData = snap;
      }
    }
    calcLog.log(
      title,
      subtitle,
      dedupeKey: dedupeKey,
      onTap: onTap,
      restoreKey: restoreKey,
      restoreData: restoreData,
    );
  }

  @override
  void dispose() {
    _ownLog.dispose();
    super.dispose();
  }

  Widget calcHistoryButton({Key? key, String title = '최근 계산 기록'}) => IconButton(
    key: key ?? const Key('calc_history_button'),
    icon: Icon(Icons.history_rounded, color: fc.text),
    tooltip: title,
    onPressed: () => showCalcHistorySheet(context, calcHistory, title: title),
  );
}

/// [title]이 "최근 계산 기록"이 기본이지만, 마킹 계산처럼 "최근 마킹 기록"처럼
/// 화면에 맞는 말로 바꿔 부를 수 있다. 리모컨의 "최근 전송 기록"처럼 화면 반 정도를
/// 크게 차지하도록(2026-09-29 사용자 요청 — 처음 버전은 내용만큼만 작게 떴었다).
void showCalcHistorySheet(
  BuildContext context,
  List<RecentCalcEntry> entries, {
  String title = '최근 계산 기록',
}) {
  // 칸에 초점이 남아 있으면 창을 닫을 때 그 칸으로 돌아가 키보드가 다시 올라와
  // 되돌린 값과 "원래대로" 알림을 가린다. 창을 열기 전에 키보드를 닫는다.
  FocusManager.instance.primaryFocus?.unfocus();
  showModalBottomSheet(
    context: context,
    backgroundColor: fc.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.6,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: fc.line,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                title,
                key: const Key('calc_history_title'),
                style: TextStyle(
                  color: fc.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Text(
                          '아직 계산한 기록이 없습니다.',
                          key: const Key('calc_history_empty'),
                          style: TextStyle(
                            color: fc.textSub,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: fc.line,
                          indent: 24,
                          endIndent: 24,
                        ),
                        itemBuilder: (context, i) {
                          final e = entries[i];
                          return ListTile(
                            key: Key('calc_history_item_$i'),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                            title: Text(
                              e.title,
                              style: TextStyle(
                                color: fc.text,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${e.subtitle}\n${_fmtTime(e.time)}',
                                style: TextStyle(
                                  color: fc.textSub,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            trailing: e.onTap == null
                                ? null
                                : Icon(
                                    Icons.replay_rounded,
                                    color: fc.brand,
                                    size: 20,
                                  ),
                            onTap: e.onTap == null
                                ? null
                                : () {
                                    Navigator.pop(sheetContext);
                                    e.onTap!();
                                  },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

String _fmtTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
