/// 저장 대기 목록: 통신이 없어 서버에 아직 못 올린 저장이 "어느 프로젝트의 무엇"인지 보여 준다.
/// "내 알림"의 "오프라인 저장 대기 N건"을 누르면 여기로 온다.
///
/// 저장은 폰에 먼저 쓰이고 연결되면 자동으로 올라간다. 이 화면은 그 기다림을 눈으로 볼 수 있게 할
/// 뿐이고, 여기서 뭔가를 지우거나 다시 보내는 단추는 없다(연결되면 알아서 올라간다).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/data/pending_write_log.dart';
import 'package:tubing_calculator/src/data/repositories/work_project_repository.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/photo_store.dart'
    show countLocalPhotos;

class PendingWritesPage extends StatefulWidget {
  final PendingWriteLog? log;
  final Future<List<Map<String, dynamic>>> Function()? loadProjects;
  final DateTime Function()? now;

  const PendingWritesPage({super.key, this.log, this.loadProjects, this.now});

  @override
  State<PendingWritesPage> createState() => _PendingWritesPageState();
}

class _PendingWritesPageState extends State<PendingWritesPage> {
  late final PendingWriteLog _log =
      widget.log ?? WorkProjectRepository.pendingLog;
  Timer? _tick;

  /// 프로젝트 이름 → 아직 안 올라간 사진 수(폰에 남은 것만).
  Map<String, ({String name, int photos})> _photos = const {};

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    // "12분째" 같은 글이 시간이 가면 바뀌도록.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    try {
      final load =
          widget.loadProjects ?? WorkProjectRepository().fetchCachedProjects;
      final projects = await load();
      final found = <String, ({String name, int photos})>{};
      for (final p in projects) {
        final n = countLocalPhotos([p]);
        if (n > 0) {
          final id = p['id']?.toString() ?? '';
          found[id] = (name: p['name']?.toString() ?? '이름 없는 프로젝트', photos: n);
        }
      }
      if (mounted) setState(() => _photos = found);
    } catch (_) {
      // 폰에 목록이 없거나 못 읽으면 사진 줄만 빠진다.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('저장 대기')),
      body: ValueListenableBuilder<List<PendingWrite>>(
        valueListenable: _log.entries,
        builder: (context, entries, _) {
          final groups = PendingWriteLog.groupByProject(entries);
          final groupIds = {for (final g in groups) g.projectId};
          final photoOnly = [
            for (final e in _photos.entries)
              if (!groupIds.contains(e.key)) e,
          ];
          if (groups.isEmpty && photoOnly.isEmpty) return _empty();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  '통신이 없으면 저장은 폰에 먼저 남고, 연결되면 서버로 자동으로 올라갑니다. '
                  '아래는 아직 올라가지 못한 것입니다.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSub,
                  ),
                ),
              ),
              for (final g in groups)
                _card(
                  name: g.projectName,
                  lines: [
                    '${g.kinds.join(' · ')} ${g.count}건 — ${waitingLabel(g.oldest, _now)} 대기',
                    if (_photos[g.projectId] != null)
                      '사진 ${_photos[g.projectId]!.photos}장도 아직 안 올라갔습니다',
                  ],
                ),
              for (final e in photoOnly)
                _card(
                  name: e.value.name,
                  lines: ['사진 ${e.value.photos}장이 아직 안 올라갔습니다'],
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 12, 4, 0),
                child: Text(
                  '앱을 완전히 껐다 켜면 이 목록은 비지만, 폰에 남은 저장은 연결되면 그대로 올라갑니다.',
                  style: TextStyle(fontSize: 12, color: AppColors.textFaint),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _empty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.cloud_done_outlined, size: 48, color: AppColors.ok),
          SizedBox(height: 16),
          Text(
            '기다리는 저장이 없습니다',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            '모두 서버에 올라갔습니다.',
            style: TextStyle(fontSize: 14, color: AppColors.textSub),
          ),
        ],
      ),
    ),
  );

  Widget _card({required String name, required List<String> lines}) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    color: AppColors.surface,
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            color: Colors.deepOrange,
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.textSub,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
