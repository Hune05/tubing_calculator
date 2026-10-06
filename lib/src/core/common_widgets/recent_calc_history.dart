// 계산기 화면에서 쓰는 "최근 계산 기록" 버튼·시트 — 리모컨 화면의 "최근 전송 기록"과 같은 방식
// (2026-09-29 사용자 요청). 저장 버튼 없이 계산할 때마다 자동으로 쌓이고, 화면을 나가면
// 사라진다(따로 저장하지 않는다 — "저장한 기록" 탭이 있는 화면과는 다른, 가벼운 세션용 목록).
import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/field_view.dart';

class RecentCalcEntry {
  final String title;
  final String subtitle;
  final DateTime time;
  final VoidCallback? onTap;
  const RecentCalcEntry({
    required this.title,
    required this.subtitle,
    required this.time,
    this.onTap,
  });
}

/// 기록 쌓기 그 자체(디바운스·중복 방지·최대 개수). 보통은 [RecentCalcHistoryMixin]이
/// 화면마다 하나씩 따로 갖지만, 탭이 여러 화면 파일로 나뉜 계산기(전기 설비 계산처럼)는
/// 이 객체 하나를 만들어 각 탭 State에 나눠 주면 기록을 한 목록으로 합칠 수 있다.
class RecentCalcLog {
  final List<RecentCalcEntry> entries = [];

  /// 기록을 눌러 그때 입력값으로 되돌릴 때 그 기록의 탭을 앞으로 띄우는 일.
  /// 탭이 여러 개인 화면(전기 설비 계산)이 정해 준다. 탭 이름 키(요약 줄 키)를 받는다.
  void Function(String tabKey)? openTab;
  Timer? _debounce;
  String? _lastKey;
  VoidCallback? _onChange;
  static const int _maxEntries = 20;

  /// 계산 값이 바뀔 때마다 부른다. 같은 값이 잠깐(700ms) 유지되면 그때 한 번만 기록에 쌓는다
  /// (매 키 입력마다 쌓이는 걸 막기 위한 디바운스). [dedupeKey]가 이전과 같으면 새로 쌓지 않는다.
  void log(
    String title,
    String subtitle, {
    String? dedupeKey,
    VoidCallback? onTap,
  }) {
    final key = dedupeKey ?? '$title|$subtitle';
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      if (key == _lastKey) return;
      _lastKey = key;
      entries.insert(
        0,
        RecentCalcEntry(
          title: title,
          subtitle: subtitle,
          time: DateTime.now(),
          onTap: onTap,
        ),
      );
      if (entries.length > _maxEntries) entries.removeLast();
      _onChange?.call();
    });
  }

  void dispose() => _debounce?.cancel();
}

/// 계산기 State에 섞어 쓰는 믹스인. 자동 기록 쌓기(디바운스)와 버튼 위젯을 준다.
/// 여러 State가 기록 하나를 같이 쓰려면 [calcLog]를 override해서 밖에서 만든
/// [RecentCalcLog]를 돌려주면 된다(기본은 이 State만 쓰는 것 하나를 스스로 만든다).
mixin RecentCalcHistoryMixin<W extends StatefulWidget> on State<W> {
  final RecentCalcLog _ownLog = RecentCalcLog();
  RecentCalcLog get calcLog => _ownLog;
  List<RecentCalcEntry> get calcHistory => calcLog.entries;

  void logCalc(
    String title,
    String subtitle, {
    String? dedupeKey,
    VoidCallback? onTap,
  }) {
    calcLog._onChange = () {
      if (mounted) setState(() {});
    };
    calcLog.log(title, subtitle, dedupeKey: dedupeKey, onTap: onTap);
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
