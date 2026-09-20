import 'package:flutter/material.dart';

import '../cutting_leftover_log.dart';
import '../cutting_theme.dart';

const List<String> _wd = ['월', '화', '수', '목', '금', '토', '일'];

String _fmtWhen(DateTime t) =>
    '${t.month}월 ${t.day}일(${_wd[t.weekday - 1]}) '
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

// 잔재 기록 화면: 재단 최적화에서 잔재를 저장한 때마다 한 카드(쓴 잔재 / 새로 생긴 잔재). 최신이 위.
class LeftoverLogPage extends StatelessWidget {
  // 테스트에서 저장소 없이 그릴 수 있게 기록을 직접 넘길 수도 있다. 없으면 폰에서 읽는다.
  final List<LeftoverLogEntry>? entries;

  const LeftoverLogPage({super.key, this.entries});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: entries != null
          ? _LogList(entries: entries!)
          : FutureBuilder<List<LeftoverLogEntry>>(
              future: loadLeftoverLog(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: CuttingColors.primary,
                    ),
                  );
                }
                return _LogList(entries: snap.data!);
              },
            ),
    );
  }
}

class _LogList extends StatelessWidget {
  final List<LeftoverLogEntry> entries;
  const _LogList({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "아직 잔재 기록이 없습니다.\n재단 최적화에서 '잘랐습니다 (잔재 저장)'를 누르면 남습니다.",
            textAlign: TextAlign.center,
            style: TextStyle(color: CuttingColors.textSecondary),
          ),
        ),
      );
    }
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
                      _fmtWhen(e.at),
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
