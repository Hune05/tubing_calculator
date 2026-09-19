import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/photo_store.dart';

const Color _teal = Color(0xFF007580);
const Color _text = Color(0xFF191F28);
const Color _sub = Color(0xFF8B95A1);
const Color _bg = Color(0xFFF2F4F6);

// 🚀 [저장 공간 관리] 앱이 만든 임시 파일(사진 압축본, 내보내기 PDF/CSV)과 일보 임시
// 저장을 확인하고 정리한다. 아직 클라우드에 안 올라간 원본 사진은 절대 지우지
// 않는다(일보에 로컬 경로로 연결돼 있어서).
class StorageManagementPage extends StatefulWidget {
  final List<Map<String, dynamic>> logs;
  const StorageManagementPage({super.key, required this.logs});

  @override
  State<StorageManagementPage> createState() => _StorageManagementPageState();
}

class _StorageManagementPageState extends State<StorageManagementPage> {
  bool _loading = true;
  int _tempBytes = 0;
  int _tempCount = 0;
  int _drafts = 0;
  int _pendingPhotos = 0;

  static final _tempPattern = RegExp(
    r'^(up_|dl_|report_|stats_)\d*.*\.(jpg|png|pdf|csv)$',
  );

  Future<List<File>> _tempFiles() async {
    final dir = await getTemporaryDirectory();
    final out = <File>[];
    if (!await dir.exists()) return out;
    await for (final e in dir.list()) {
      if (e is File &&
          _tempPattern.hasMatch(e.path.split(RegExp(r'[\\/]')).last)) {
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
    if (!mounted) return;
    setState(() {
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

  Future<void> _clearDrafts() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("임시 저장 삭제"),
        content: const Text("저장하지 않고 남아 있는 일보 임시 저장 내용이 모두 삭제돼요."),
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
