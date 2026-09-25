import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/error_log.dart';
import '../../../data/repositories/work_project_repository.dart';
import '../models/backup_tools.dart' show lastAutoBackup;
import '../models/report_tools.dart'
    show areNotificationsAllowed, canScheduleExactAlarms, pendingReminderIds;
import '../widgets/korean_text.dart';

const Color _teal = AppColors.brand;
const Color _text = AppColors.text;
const Color _sub = AppColors.textSub;
const Color _bg = AppColors.background;
const Color _ok = AppColors.ok;
const Color _warn = Color(0xFFB54708);
const Color _bad = AppColors.danger;

// 🚀 [앱 상태] 알림·서버·백업·저장 대기와 최근 오류를 한 화면에 모아 보여 준다.
// 무언가 이상할 때 여기서 원인을 좁히고, 오류 기록을 복사해 보낼 수 있다.
class AppStatusPage extends StatefulWidget {
  // 테스트에서 바꿔 끼우는 조회 함수들(기본은 실제 조회).
  final Future<bool> Function()? notificationsAllowed;
  final Future<bool> Function()? exactAllowed;
  final Future<int> Function()? pendingCount;
  final Future<bool> Function()? serverReachable;
  final Future<DateTime?> Function()? lastBackup;
  final int Function()? pendingWrites;
  final Future<List<ErrorEntry>> Function()? errorsLoader;
  final Future<void> Function()? errorsClearer;
  const AppStatusPage({
    super.key,
    this.notificationsAllowed,
    this.exactAllowed,
    this.pendingCount,
    this.serverReachable,
    this.lastBackup,
    this.pendingWrites,
    this.errorsLoader,
    this.errorsClearer,
  });

  @override
  State<AppStatusPage> createState() => _AppStatusPageState();
}

enum _Level { ok, warn, bad, unknown }

class _Row {
  final String label;
  final String value;
  final _Level level;
  const _Row(this.label, this.value, this.level);
}

class _AppStatusPageState extends State<AppStatusPage> {
  List<_Row>? _rows;
  List<ErrorEntry> _errors = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<T?> _try<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final allowed = await _try(
      widget.notificationsAllowed ?? areNotificationsAllowed,
    );
    final exact = await _try(widget.exactAllowed ?? canScheduleExactAlarms);
    final pending = await _try(
      widget.pendingCount ?? () async => (await pendingReminderIds()).length,
    );
    final server = await _try(
      widget.serverReachable ??
          () async {
            await FirebaseFirestore.instance
                .collection(kWorkProjectsCollection)
                .limit(1)
                .get(const GetOptions(source: Source.server))
                .timeout(const Duration(seconds: 6));
            return true;
          },
    );
    final backup = await _try(widget.lastBackup ?? lastAutoBackup);
    final waiting = widget.pendingWrites != null
        ? widget.pendingWrites!()
        : WorkProjectRepository.pendingWrites.value;
    final errors = await _try(widget.errorsLoader ?? loadErrors) ?? const [];

    String ago(DateTime t) {
      final d = DateTime.now().difference(t);
      if (d.inMinutes < 60) return '${t.month}/${t.day} (${d.inMinutes}분 전)';
      if (d.inHours < 24) return '${t.month}/${t.day} (${d.inHours}시간 전)';
      return '${t.month}/${t.day} (${d.inDays}일 전)';
    }

    final rows = <_Row>[
      _Row(
        '알림 권한',
        allowed == null ? '확인하지 못함' : (allowed ? '허용됨' : '꺼져 있음 — 폰 설정에서 켜십시오'),
        allowed == null ? _Level.unknown : (allowed ? _Level.ok : _Level.bad),
      ),
      _Row(
        '정확한 시간 알림',
        exact == null
            ? '확인하지 못함'
            : (exact ? '허용됨' : '허용 안 됨 — 알림이 최대 1시간 늦을 수 있습니다'),
        exact == null ? _Level.unknown : (exact ? _Level.ok : _Level.warn),
      ),
      _Row(
        '예약된 알림',
        pending == null ? '확인하지 못함' : '$pending개',
        pending == null ? _Level.unknown : _Level.ok,
      ),
      _Row(
        '서버 연결',
        server == null ? '연결하지 못함 — 통신을 확인하십시오' : '연결됨',
        server == null ? _Level.bad : _Level.ok,
      ),
      _Row(
        '마지막 클라우드 백업',
        backup == null ? '아직 없음' : ago(backup),
        backup == null
            ? _Level.warn
            : (DateTime.now().difference(backup).inDays > 14
                  ? _Level.warn
                  : _Level.ok),
      ),
      _Row(
        '서버로 올리는 중',
        waiting == 0 ? '없음' : '$waiting건 (네트워크가 연결되면 자동으로 올라갑니다)',
        waiting == 0 ? _Level.ok : _Level.warn,
      ),
    ];
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _errors = errors;
      _loading = false;
    });
  }

  Color _color(_Level l) => switch (l) {
    _Level.ok => _ok,
    _Level.warn => _warn,
    _Level.bad => _bad,
    _Level.unknown => _sub,
  };

  IconData _icon(_Level l) => switch (l) {
    _Level.ok => Icons.check_circle_rounded,
    _Level.warn => Icons.info_outline_rounded,
    _Level.bad => Icons.error_rounded,
    _Level.unknown => Icons.help_outline_rounded,
  };

  Future<void> _copyErrors() async {
    await Clipboard.setData(ClipboardData(text: errorsAsText(_errors)));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(keepWords("오류 기록을 복사했습니다."))));
  }

  Future<void> _clearErrors() async {
    await (widget.errorsClearer ?? clearErrors)();
    await _load();
  }

  Widget _card(List<Widget> children) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "앱 상태",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: "다시 확인",
            icon: const Icon(AppIcons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _rows == null
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _card([
                  const Text(
                    "지금 상태",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: _teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final r in _rows!)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _icon(r.level),
                            size: 18,
                            color: _color(r.level),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.label,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _text,
                                  ),
                                ),
                                Text(
                                  keepWords(r.value),
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: _color(r.level),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ]),
                _card([
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "최근 오류 기록",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _teal,
                          ),
                        ),
                      ),
                      Text(
                        "${_errors.length}건",
                        style: const TextStyle(fontSize: 12, color: _sub),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_errors.isEmpty)
                    const Text(
                      "기록된 오류가 없습니다.",
                      style: TextStyle(fontSize: 13, color: _sub),
                    )
                  else ...[
                    for (final e in _errors.reversed.take(8))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          "${e.at.month}/${e.at.day} "
                          "${e.at.hour.toString().padLeft(2, '0')}:"
                          "${e.at.minute.toString().padLeft(2, '0')}  [${e.where}]\n${e.message}",
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: _text,
                          ),
                        ),
                      ),
                    if (_errors.length > 8)
                      Text(
                        "나머지 ${_errors.length - 8}건은 복사하면 함께 들어갑니다.",
                        style: const TextStyle(fontSize: 12, color: _sub),
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: _copyErrors,
                          child: const Text("오류 기록 복사"),
                        ),
                        TextButton(
                          onPressed: _clearErrors,
                          child: const Text("기록 지우기"),
                        ),
                      ],
                    ),
                  ],
                ]),
              ],
            ),
    );
  }
}
