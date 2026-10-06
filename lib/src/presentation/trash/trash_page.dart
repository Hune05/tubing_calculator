// 휴지통 화면(10-02): 지운 것을 30일 동안 보여 주고 복원·완전 삭제·비우기를 한다.
import 'package:flutter/material.dart';

import '../../core/common_widgets/app_components.dart';
import '../../core/common_widgets/swipe_to_delete.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/trash/trash_store.dart';
import 'trash_kinds.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  List<TrashEntry> _list = [];
  bool _loaded = false;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await loadTrash();
    if (mounted) {
      setState(() {
        _list = list;
        _loaded = true;
      });
    }
  }

  Future<void> _restore(TrashEntry e) async {
    setState(() => _busy.add(e.id));
    try {
      await restoreTrash(e);
      if (!mounted) return;
      setState(() => _list.removeWhere((x) => x.id == e.id));
      showAppSnack(context, '복원했습니다: ${e.title}');
    } catch (err) {
      if (!mounted) return;
      showAppSnack(context, '복원하지 못했습니다. 통신을 확인하십시오.', kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _busy.remove(e.id));
    }
  }

  Future<bool> _confirmPurge(TrashEntry e) => showAppConfirm(
    context,
    title: '완전히 삭제하시겠습니까?',
    message: "'${e.title}' 항목을 휴지통에서도 지웁니다. 되돌릴 수 없습니다.",
    okText: '삭제',
    destructive: true,
    okKey: const Key('trash_purge_ok'),
  );

  Future<void> _purge(TrashEntry e) async {
    setState(() => _list.removeWhere((x) => x.id == e.id));
    await purgeTrash(e);
  }

  Future<void> _emptyAll() async {
    final ok = await showAppConfirm(
      context,
      title: '휴지통을 비우시겠습니까?',
      message: '휴지통에 있는 ${_list.length}개를 모두 완전히 지웁니다. 되돌릴 수 없습니다.',
      okText: '비우기',
      destructive: true,
      okKey: const Key('trash_empty_ok'),
    );
    if (!ok) return;
    await emptyTrash();
    if (!mounted) return;
    setState(() => _list = []);
    showAppSnack(context, '휴지통을 비웠습니다');
  }

  String _when(DateTime d) {
    final n = TrashStore.now();
    if (d.year == n.year && d.month == n.month && d.day == n.day) {
      return '오늘 ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.month}월 ${d.day}일';
  }

  @override
  Widget build(BuildContext context) {
    final now = TrashStore.now();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('휴지통'),
        actions: [
          if (_list.isNotEmpty)
            TextButton(
              key: const Key('trash_empty'),
              onPressed: _emptyAll,
              child: const Text('비우기', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              key: const Key('trash_list'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    '지운 것은 $kTrashKeepDays일 동안 여기 있다가 저절로 지워집니다. 이 폰에서 지운 것만 보입니다. 왼쪽으로 밀면 완전히 지웁니다.',
                    style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSub),
                  ),
                ),
                if (_list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 48, color: AppColors.textFaint),
                        SizedBox(height: 10),
                        Text('휴지통이 비었습니다', key: Key('trash_none'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                for (final e in _list) _row(e, now),
              ],
            ),
    );
  }

  Widget _row(TrashEntry e, DateTime now) {
    final (kindLabel, icon) = trashKindLabel(e.kind);
    final left = e.daysLeft(now);
    final busy = _busy.contains(e.id);
    return SwipeToDelete(
      itemKey: ValueKey('trash_${e.id}'),
      confirm: () => _confirmPurge(e),
      onDelete: () => _purge(e),
      enabled: !busy,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSub, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title.isEmpty ? kindLabel : e.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      [kindLabel, if (e.subtitle.isNotEmpty) e.subtitle, '${_when(e.deletedAt)} 삭제'].join(' · '),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSub),
                    ),
                    Text(
                      left == 0 ? '오늘 완전히 지워집니다' : '$left일 뒤 완전히 지워집니다',
                      style: TextStyle(fontSize: 12, color: left <= 3 ? AppColors.danger : AppColors.textFaint),
                    ),
                  ],
                ),
              ),
              busy
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                  : TextButton(
                      key: Key('trash_restore_${e.id}'),
                      onPressed: () => _restore(e),
                      child: const Text('복원', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
