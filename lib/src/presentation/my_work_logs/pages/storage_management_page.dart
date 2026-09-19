import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../models/backup_tools.dart';
import '../models/report_tools.dart' show loadPdfCleanupRecord, runPdfCleanup;
import '../models/photo_store.dart';

const Color _teal = Color(0xFF007580);
const Color _text = Color(0xFF191F28);
const Color _sub = Color(0xFF8B95A1);
const Color _bg = Color(0xFFF2F4F6);

// 🚀 [저장 공간 관리] 앱이 만든 임시 파일(사진 압축본, 내보내기 PDF/CSV)과 일보 임시
// 저장을 확인하고 정리한다. 아직 클라우드에 안 올라간 원본 사진은 절대 지우지
// 않는다(일보에 로컬 경로로 연결돼 있어서).
// 앱이 만든 임시 파일 이름인지. PDF는 이름 형식(프로젝트_보고서_날짜.pdf)이 바뀌어도
// 임시 파일로 센다(공유용으로 만든 것뿐이라 지워도 안전).
bool isAppTempFileName(String name) =>
    RegExp(
      r'^(up_|dl_|report_|stats_)\d*.*\.(jpg|png|pdf|csv|json)$',
    ).hasMatch(name) ||
    name.toLowerCase().endsWith('.pdf');

class StorageManagementPage extends StatefulWidget {
  final List<Map<String, dynamic>> logs;
  final VoidCallback? onRestored;
  const StorageManagementPage({super.key, required this.logs, this.onRestored});

  @override
  State<StorageManagementPage> createState() => _StorageManagementPageState();
}

class _StorageManagementPageState extends State<StorageManagementPage> {
  bool _loading = true;
  int _tempBytes = 0;
  int _tempCount = 0;
  int _drafts = 0;
  int _pendingPhotos = 0;
  ({DateTime? lastRun, int lastRemoved, int total})? _cleanup;

  Future<List<File>> _tempFiles() async {
    final dir = await getTemporaryDirectory();
    final out = <File>[];
    if (!await dir.exists()) return out;
    await for (final e in dir.list()) {
      if (e is File && isAppTempFileName(e.path.split(RegExp(r'[\\/]')).last)) {
        out.add(e);
      }
    }
    return out;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    int bytes = 0;
    final files = await _tempFiles();
    for (final f in files) {
      try {
        bytes += await f.length();
      } catch (_) {}
    }
    final p = await SharedPreferences.getInstance();
    final drafts = p.getKeys().where((k) => k.startsWith('report_draft_'));
    final cleanup = await loadPdfCleanupRecord();
    if (!mounted) return;
    setState(() {
      _cleanup = cleanup;
      _tempBytes = bytes;
      _tempCount = files.length;
      _drafts = drafts.length;
      _pendingPhotos = countLocalPhotos(widget.logs);
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadAuto();
  }

  String _mb(int b) => b < 1024 * 1024
      ? "${(b / 1024).round()}KB"
      : "${(b / 1024 / 1024).toStringAsFixed(1)}MB";

  Future<void> _clearTemp() async {
    for (final f in await _tempFiles()) {
      try {
        await f.delete();
      } catch (_) {}
    }
    await _load();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _backup() async {
    try {
      final f = await createBackupFile(widget.logs);
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(f.path)], text: '내 프로젝트 백업');
    } catch (e) {
      _toast("백업 실패: $e");
    }
  }

  Future<void> _restore() async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final pf = res.files.first;
      final text = pf.bytes != null
          ? utf8.decode(pf.bytes!)
          : await File(pf.path!).readAsString();
      await _restoreText(text);
    } on FormatException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast("복원 실패: $e");
    }
  }

  Future<void> _restoreText(String text) async {
    final prev = parseBackup(text);
    if (!mounted) return;
    final when = prev.exportedAt == null
        ? ''
        : '\n(백업 시각: ${prev.exportedAt!.year}.${prev.exportedAt!.month}.${prev.exportedAt!.day})';
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("백업에서 복원"),
        content: Text(
          "프로젝트 ${prev.projects}건, 템플릿 ${prev.templates}개가 들어 있습니다.$when\n\n"
          "같은 프로젝트가 이미 있으면 백업 내용으로 덮어씁니다. 계속하시겠습니까?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("복원"),
          ),
        ],
      ),
    );
    if (go != true) return;
    final n = await restoreBackup(prev);
    _toast("프로젝트 $n건을 복원했습니다.");
    widget.onRestored?.call();
  }

  bool _autoOn = true;
  DateTime? _lastAuto;
  bool _cloudBusy = false;

  Future<void> _loadAuto() async {
    final on = await autoBackupEnabled();
    final last = await lastAutoBackup();
    if (mounted) {
      setState(() {
        _autoOn = on;
        _lastAuto = last;
      });
    }
  }

  Future<void> _backupNow() async {
    setState(() => _cloudBusy = true);
    final ok = await uploadCloudBackup(widget.logs);
    await _loadAuto();
    if (mounted) setState(() => _cloudBusy = false);
    _toast(ok ? "클라우드에 백업했습니다." : "백업에 실패했습니다. 네트워크를 확인해 주십시오.");
  }

  Future<void> _restoreFromCloud() async {
    try {
      setState(() => _cloudBusy = true);
      final list = await listCloudBackups();
      if (!mounted) return;
      setState(() => _cloudBusy = false);
      if (list.isEmpty) {
        _toast("클라우드에 저장된 백업이 없습니다.");
        return;
      }
      final pick = await showModalBottomSheet<int>(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "복원할 백업 선택",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              for (int i = 0; i < list.length; i++)
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: Text(_fmtBackupName(list[i].name)),
                  onTap: () => Navigator.pop(ctx, i),
                ),
            ],
          ),
        ),
      );
      if (pick == null) return;
      final text = await downloadBackupText(list[pick]);
      await _restoreText(text);
    } on FormatException catch (e) {
      _toast(e.message);
    } catch (e) {
      if (mounted) setState(() => _cloudBusy = false);
      _toast("불러오기 실패: $e");
    }
  }

  String _fmtBackupName(String n) {
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})').firstMatch(n);
    return m == null ? n : '${m[1]}.${m[2]}.${m[3]} ${m[4]}:${m[5]}';
  }

  // 3일을 기다리지 않고, 공유하려고 만든 PDF를 지금 전부 지운다(보고서 데이터는 그대로).
  Future<void> _cleanPdfsNow() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("임시 PDF를 지금 정리하시겠습니까?"),
        content: const Text(
          "공유하려고 만들어 둔 PDF 파일만 삭제합니다. 보고서 데이터와 사진은 그대로 유지됩니다. "
          "이미 보낸 PDF는 상대방에게 그대로 남아 있습니다.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("정리"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final dir = await getTemporaryDirectory();
    // 방금 만든 파일까지 지우려고 기준 시각을 1초 뒤로 잡는다.
    final n = await runPdfCleanup(
      dir,
      maxAge: Duration.zero,
      now: DateTime.now().add(const Duration(seconds: 1)),
    );
    _toast(n == 0 ? "정리할 PDF가 없습니다." : "PDF $n개를 정리했습니다.");
    await _load();
  }

  String _cleanupDesc() {
    final c = _cleanup;
    const base = "공유하려고 만든 PDF는 3일이 지나면 앱을 열 때 자동으로 지워요.";
    if (c == null || c.lastRun == null) return "${base} 아직 정리한 적이 없어요.";
    final t = c.lastRun!;
    return "${base} 마지막 정리 ${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}"
        "(${c.lastRemoved}개 삭제)";
  }

  Future<void> _clearDrafts() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("임시 저장 삭제"),
        content: const Text("저장하지 않고 남아 있는 일보 임시 저장 내용이 모두 삭제됩니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("삭제"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys().where((k) => k.startsWith('report_draft_'))) {
      await p.remove(k);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    Widget card(String title, String value, String desc, {Widget? action}) =>
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: _text,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: _teal,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(color: _sub, fontSize: 12, height: 1.4),
              ),
              if (action != null) ...[const SizedBox(height: 8), action],
            ],
          ),
        );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "저장 공간 관리",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                card(
                  "임시 PDF 자동 정리",
                  "${_cleanup?.total ?? 0}개 정리됨",
                  _cleanupDesc(),
                  action: Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: _cleanPdfsNow,
                      child: const Text("지금 PDF 모두 정리"),
                    ),
                  ),
                ),
                card(
                  "임시 파일",
                  "${_mb(_tempBytes)} ($_tempCount개)",
                  "사진 압축본, 내보낸 PDF/CSV처럼 앱이 만든 임시 파일이에요. 지워도 데이터에는 영향이 없어요.",
                  action: Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: _tempCount == 0 ? null : _clearTemp,
                      child: const Text("임시 파일 지우기"),
                    ),
                  ),
                ),
                card(
                  "일보 임시 저장",
                  "$_drafts건",
                  "작성 중 저장하지 않은 일보의 자동 저장본이에요. 2일이 지난 것은 앱을 열 때 자동으로 정리돼요.",
                  action: Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: _drafts == 0 ? null : _clearDrafts,
                      child: const Text("모두 삭제"),
                    ),
                  ),
                ),
                card(
                  "클라우드 자동 백업",
                  _lastAuto == null
                      ? "아직 없음"
                      : "${_lastAuto!.month}/${_lastAuto!.day} ${_lastAuto!.hour.toString().padLeft(2, '0')}:${_lastAuto!.minute.toString().padLeft(2, '0')}",
                  "앱을 열 때 마지막 백업이 7일 이상 지났으면 자동으로 클라우드에 백업하고 최근 5개만 보관해요.",
                  action: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("주간 자동 백업"),
                        value: _autoOn,
                        onChanged: (v) async {
                          await setAutoBackupEnabled(v);
                          setState(() => _autoOn = v);
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: _cloudBusy ? null : _restoreFromCloud,
                            child: const Text("클라우드에서 복원"),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _cloudBusy ? null : _backupNow,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _teal,
                            ),
                            child: _cloudBusy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "지금 백업",
                                    style: TextStyle(color: Colors.white),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                card(
                  "데이터 백업 / 복원",
                  "${widget.logs.length}건",
                  "내 프로젝트 전체와 단계 템플릿, 자재 즐겨찾기를 파일 하나로 내보내고 다시 불러와요. 사진은 클라우드에 올라간 것만 복원 후에도 보여요.",
                  action: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _restore,
                        child: const Text("복원"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _backup,
                        style: ElevatedButton.styleFrom(backgroundColor: _teal),
                        child: const Text(
                          "백업 내보내기",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                card(
                  "업로드 대기 사진",
                  "$_pendingPhotos장",
                  _pendingPhotos == 0
                      ? "모든 사진이 클라우드에 올라가 있어요."
                      : "아직 클라우드에 올라가지 않은 사진이에요. 이 사진의 원본은 지우지 않아요. 프로젝트 목록의 '다시 시도'로 올릴 수 있어요.",
                ),
              ],
            ),
    );
  }
}
