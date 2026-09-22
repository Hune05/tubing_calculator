import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../cutting_action_bar.dart' show kakaoSender, textSharer;
import '../cutting_leftover_log.dart';
import '../cutting_leftovers.dart';
import '../cutting_theme.dart';

// 잔재 기록 화면: 재단 계획에서 잔재를 저장한 때마다 한 카드(쓴 잔재 / 새로 생긴 잔재). 최신이 위.
class LeftoverLogPage extends StatelessWidget {
  // 테스트에서 저장소 없이 그릴 수 있게 기록을 직접 넘길 수도 있다. 없으면 폰에서 읽는다.
  final List<LeftoverLogEntry>? entries;
  // "최근 7일" 같은 기간 기준 시각(테스트용). 없으면 지금.
  final DateTime? now;
  // 글에 함께 넣을 지금 남은 잔재(테스트용). 없으면 폰에서 읽는다.
  final List<Leftover>? currentLeftovers;

  const LeftoverLogPage({
    super.key,
    this.entries,
    this.now,
    this.currentLeftovers,
  });

  Future<(List<LeftoverLogEntry>, List<Leftover>)> _load() async => (
    entries ?? await loadLeftoverLog(),
    currentLeftovers ?? await loadLeftovers(),
  );

  @override
  Widget build(BuildContext context) {
    return CuttingTheme(
      child: Scaffold(
        backgroundColor: CuttingColors.surface,
        appBar: AppBar(
          backgroundColor: CuttingColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(color: CuttingColors.textPrimary),
          title: const Text(
            "잔재 기록",
            style: TextStyle(
              color: CuttingColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
        ),
        body: FutureBuilder<(List<LeftoverLogEntry>, List<Leftover>)>(
          future: _load(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: CuttingColors.primary),
              );
            }
            return _LogList(
              entries: snap.data!.$1,
              current: snap.data!.$2,
              now: now,
            );
          },
        ),
      ),
    );
  }
}

class _LogList extends StatefulWidget {
  final List<LeftoverLogEntry> entries;
  final List<Leftover> current;
  final DateTime? now;
  const _LogList({required this.entries, this.current = const [], this.now});

  @override
  State<_LogList> createState() => _LogListState();
}

class _LogListState extends State<_LogList> {
  int? _days; // null이면 전체 기간
  String? _label; // null이면 전체 규격

  Widget _chip(Key key, String text, bool selected, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: selected ? CuttingColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ),
      );

  // 앞에 떠 있던 알림을 걷고 새로 보여 준다(복사 뒤 바로 카톡을 눌러도 기다리지 않게).
  void _snack(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    showCuttingSnack(context, message, isError: isError);
  }

  String _text(List<LeftoverLogEntry> shown, String? label) {
    final parts = [
      if (_days != null) '최근 $_days일',
      if (label != null) label.isEmpty ? '규격 미지정' : label,
    ];
    return buildLeftoverLogText(
      entries: shown,
      filterText: parts.join(' · '),
      current: widget.current,
    );
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _snack(context, "잔재 기록을 글로 복사했습니다. 메신저에 붙여넣으십시오.");
  }

  Future<void> _kakao(String text) async {
    if (await kakaoSender(text)) return;
    if (!mounted) return;
    try {
      await textSharer(text);
      if (!mounted) return;
      _snack(context, "카카오톡을 찾지 못해 공유창으로 보냈습니다.");
    } catch (e) {
      if (!mounted) return;
      _snack(context, "보내기 실패: $e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.entries;
    if (all.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "아직 잔재 기록이 없습니다.\n재단 계획에서 '잘랐습니다 (잔재 저장)'를 누르면 남습니다.",
            textAlign: TextAlign.center,
            style: TextStyle(color: CuttingColors.textSecondary),
          ),
        ),
      );
    }
    final labels = leftoverLogLabels(all);
    final activeLabel = labels.contains(_label) ? _label : null;
    final entries = filterLeftoverLog(
      all,
      days: _days,
      label: activeLabel,
      now: widget.now,
    );
    final filters = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final d in const <int?>[null, 7, 30])
                  _chip(
                    Key('log_days_${d ?? 'all'}'),
                    d == null ? '전체 기간' : '최근 $d일',
                    _days == d,
                    () => setState(() => _days = d),
                  ),
              ],
            ),
          ),
          if (labels.length > 1) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip(
                    const Key('log_label_all'),
                    '전체 규격',
                    activeLabel == null,
                    () => setState(() => _label = null),
                  ),
                  for (final l in labels)
                    _chip(
                      Key('log_label_$l'),
                      l.isEmpty ? '규격 미지정' : l,
                      activeLabel == l,
                      () => setState(() => _label = l),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
    final text = _text(entries, activeLabel);
    final actions = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: CuttingColors.primaryDark,
            ),
            key: const Key('leftover_log_copy'),
            onPressed: () => _copy(text),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text("글 복사"),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: CuttingColors.primaryDark,
            ),
            key: const Key('leftover_log_kakao'),
            onPressed: () => _kakao(text),
            icon: const Icon(Icons.chat_bubble_rounded, size: 18),
            label: const Text("카톡 보내기"),
          ),
        ],
      ),
    );
    final Widget body = entries.isEmpty
        ? const Center(
            child: Text(
              "이 조건에 맞는 기록이 없습니다.",
              key: Key('leftover_log_none'),
              style: TextStyle(color: CuttingColors.textSecondary),
            ),
          )
        : _cards(entries);
    return Column(
      children: [
        filters,
        actions,
        Expanded(child: body),
      ],
    );
  }

  Widget _cards(List<LeftoverLogEntry> entries) {
    return ListView.separated(
      key: const Key('leftover_log_list'),
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final e = entries[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CuttingColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CuttingColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      fmtLogWhen(e.at),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: CuttingColors.textPrimary,
                      ),
                    ),
                  ),
                  if (e.source.isNotEmpty)
                    Flexible(
                      child: Text(
                        e.source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: CuttingColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _line('쓴 잔재', describeLeftovers(e.used), Colors.grey.shade700),
              const SizedBox(height: 4),
              _line('새 잔재', describeLeftovers(e.added), CuttingColors.success),
            ],
          ),
        );
      },
    );
  }

  Widget _line(String label, String text, Color color) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 52,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: CuttingColors.textPrimary,
          ),
        ),
      ),
    ],
  );
}
