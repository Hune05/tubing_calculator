// 튜브 벤딩 → 라인 컷팅 작업(10-09 고도화 1번): 마킹 탭에서 계산한 자를 길이를 컷팅 작업에 바로 넣는다.
// 예전에는 컷팅 화면에서 같은 길이를 다시 쳐야 했다. 넣으면 그 작업의 컷팅 기록·누적 사용량에 들어가고,
// 튜브는 "출고 대기"에 본수로 남아 목록의 "재고에서 빼기"로 같이 빠진다.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/quick_firestore.dart';
import '../../data/models/cutting_project_model.dart';
import '../../data/ownership.dart';
import 'cutting_firestore_helper.dart';
import 'cutting_stock_deduct.dart';

/// 한 본에서 [cut] 길이 조각이 몇 개 나오는지로 [count]개에 드는 새 원자재 본수.
/// 한 본보다 길면 0(넣지 못한다).
int bentPieceBars(double cut, int count, double barLength) {
  if (cut <= 0 || count <= 0 || barLength <= 0 || cut > barLength) return 0;
  final perBar = (barLength / cut).floor();
  return (count / perBar).ceil();
}

/// 컷팅 기록 한 줄(벤딩한 튜브). 부속 공제는 없다(마킹 계산에 이미 들어 있다).
CutRecord bendCutRecord({
  required String projectId,
  required double cut,
  required int count,
  required String tubeSize,
  DateTime? now,
}) => CutRecord(
  id: '',
  projectId: projectId,
  timestamp: now ?? DateTime.now(),
  tubeSize: tubeSize,
  originalLength: cut,
  startFitting: '벤딩 마킹',
  endFitting: '',
  cutLength: cut,
  multiplier: count,
);

/// 컷팅 작업 하나(고르는 목록에 보일 것).
class CuttingJobChoice {
  final String id;
  final Map<String, dynamic> data;
  const CuttingJobChoice(this.id, this.data);
  String get name => (data['name'] as String?) ?? '이름 없음';
  double get usedMm => (data['totalTubeUsed'] as num?)?.toDouble() ?? 0;
}

/// 내가 볼 수 있는(공용·내 것) 컷팅 작업, 최근 만든 순.
Future<List<CuttingJobChoice>> loadCuttingJobChoices() async {
  final snap = await readQueryQuick(
    FirebaseFirestore.instance
        .collection(kCuttingProjectsCollection)
        .orderBy('createdAt', descending: true),
  );
  final uid = currentUid();
  return [
    for (final d in snap.docs)
      if (canSeeDoc(d.data(), uid)) CuttingJobChoice(d.id, d.data()),
  ];
}

/// 고른 작업에 넣는다. 통신이 없으면 폰에 먼저 적히고 통신될 때 올라간다(기다리지 않는다).
Future<void> sendBendToCuttingJob({
  required CuttingJobChoice job,
  required double cut,
  required int count,
  required String tubeSize,
  required bool keepPending,
}) async {
  var bars = 0;
  if (keepPending) {
    final stock = await loadStockInfo().timeout(
      const Duration(seconds: 6),
      onTimeout: () => const StockInfo(),
    );
    final barLen = (stock.barLengthByName[tubeMaterialName(tubeSize)] ?? 6000)
        .toDouble();
    bars = bentPieceBars(cut, count, barLen);
  }
  final spec = tubeSize.trim().isEmpty ? '' : '튜브 ${tubeSize.trim()}';
  unawaited(
    saveCuttingSession(
      projectId: job.id,
      project: CuttingProject.fromMap(job.id, job.data),
      totalTubeLength: cut * count,
      fittingsList: keepPending
          ? pendingTubeEntries({spec: cut * count}, barsBySpec: {spec: bars})
          : const [],
      cutRecords: [
        bendCutRecord(
          projectId: job.id,
          cut: cut,
          count: count,
          tubeSize: tubeSize.trim(),
        ),
      ],
    ).catchError((Object e) => debugPrint('벤딩 → 컷팅 저장 실패: $e')),
  );
}

/// "컷팅 작업에 넣기" 창. [cut]은 마킹 탭의 총 절단 길이(mm), [tubeSize]는 튜브 규격(1/2" 등).
/// 시험에서는 [loadJobs]·[send]를 바꿔 넣는다.
Future<void> showSendToCuttingSheet(
  BuildContext context, {
  required double cut,
  required String tubeSize,
  Future<List<CuttingJobChoice>> Function()? loadJobs,
  Future<void> Function(CuttingJobChoice job, int count, bool keepPending)?
  send,
}) async {
  final picked = await showModalBottomSheet<(CuttingJobChoice, int, bool)>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SendToCuttingSheet(
      cut: cut,
      tubeSize: tubeSize,
      loadJobs: loadJobs ?? loadCuttingJobChoices,
    ),
  );
  if (picked == null || !context.mounted) return;
  final (job, count, keepPending) = picked;
  await (send ??
      (j, c, k) => sendBendToCuttingJob(
        job: j,
        cut: cut,
        count: c,
        tubeSize: tubeSize,
        keepPending: k,
      ))(job, count, keepPending);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          "'${job.name}' 작업에 ${cut.round()}mm × $count개를 넣었습니다. 라인 컷팅의 컷팅 기록에서 보입니다.",
        ),
      ),
    );
}

class _SendToCuttingSheet extends StatefulWidget {
  final double cut;
  final String tubeSize;
  final Future<List<CuttingJobChoice>> Function() loadJobs;
  const _SendToCuttingSheet({
    required this.cut,
    required this.tubeSize,
    required this.loadJobs,
  });

  @override
  State<_SendToCuttingSheet> createState() => _SendToCuttingSheetState();
}

class _SendToCuttingSheetState extends State<_SendToCuttingSheet> {
  late final Future<List<CuttingJobChoice>> _jobs = widget.loadJobs();
  int _count = 1;
  bool _keepPending = true;

  @override
  Widget build(BuildContext context) {
    final size = widget.tubeSize.trim();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "컷팅 작업에 넣기",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${size.isEmpty ? '튜브' : '튜브 $size'} · 자를 길이 ${widget.cut.round()}mm",
                key: const Key('b2c_summary'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSub,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    "개수",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const Key('b2c_minus'),
                    onPressed: _count > 1
                        ? () => setState(() => _count--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    "$_count개",
                    key: const Key('b2c_count'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  IconButton(
                    key: const Key('b2c_plus'),
                    onPressed: _count < 999
                        ? () {
                            HapticFeedback.selectionClick();
                            setState(() => _count++);
                          }
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              SwitchListTile(
                key: const Key('b2c_pending'),
                contentPadding: EdgeInsets.zero,
                value: _keepPending,
                onChanged: (v) => setState(() => _keepPending = v),
                title: const Text(
                  "튜브를 출고 대기에 남기기",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                subtitle: const Text(
                  "컷팅 작업 목록의 \"재고에서 빼기\"로 새 원자재 본수만큼 같이 빠집니다.",
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const Divider(),
              const Text(
                "넣을 작업",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSub,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: FutureBuilder<List<CuttingJobChoice>>(
                  future: _jobs,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final jobs = snap.data ?? const <CuttingJobChoice>[];
                    if (snap.hasError || jobs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          snap.hasError
                              ? "작업 목록을 읽지 못했습니다. 통신을 확인하십시오."
                              : "컷팅 작업이 없습니다. 라인 컷팅에서 먼저 작업을 만드십시오.",
                          key: const Key('b2c_empty'),
                          style: const TextStyle(color: AppColors.textSub),
                        ),
                      );
                    }
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        for (final j in jobs)
                          ListTile(
                            key: Key('b2c_job_${j.id}'),
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.content_cut_rounded,
                              color: AppColors.brand,
                            ),
                            title: Text(
                              j.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              "누적 ${(j.usedMm / 1000).toStringAsFixed(1)} m",
                            ),
                            trailing: const Icon(AppIcons.forward),
                            onTap: () => Navigator.pop(context, (
                              j,
                              _count,
                              _keepPending,
                            )),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
