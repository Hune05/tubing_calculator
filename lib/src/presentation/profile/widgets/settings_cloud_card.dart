import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';
import 'package:tubing_calculator/src/core/utils/settings_cloud.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';

const Color _slate900 = Color(0xFF0F172A);
const Color _slate600 = Color(0xFF475569);
const Color _slate200 = Color(0xFFE2E8F0);
const Color _teal = Color(0xFF007580);
const Color _white = Color(0xFFFFFFFF);

/// 계산기 설정(튜브 벤딩·전선관·튜브 컷팅) 서버 보관 칸.
/// 설정을 저장하면 자동으로 올라가고, 새로 깔면 자동으로 받는다.
/// 여기서는 마지막 보관 시각을 보고, 직접 올리거나 받는다.
class SettingsCloudCard extends StatefulWidget {
  /// 구글 계정이 안 이어져 있을 때 "구글 계정 연결" 단추가 부른다.
  final Future<bool> Function()? onLinkGoogle;

  const SettingsCloudCard({super.key, this.onLinkGoogle});

  @override
  State<SettingsCloudCard> createState() => _SettingsCloudCardState();
}

class _SettingsCloudCardState extends State<SettingsCloudCard> {
  final _sync = SettingsCloudSync.instance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _sync.loadLastSynced();
  }

  String _when(DateTime? t) {
    if (t == null) return "아직 올린 적이 없습니다";
    String two(int v) => v.toString().padLeft(2, '0');
    return "마지막 보관 ${t.month}월 ${t.day}일 ${two(t.hour)}:${two(t.minute)}";
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _teal));
  }

  Future<void> _upload() async {
    setState(() => _busy = true);
    final ok = await _sync.backup();
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(ok ? "계산기 설정을 서버에 올렸습니다." : "올리지 못했습니다. 구글 로그인과 통신을 확인하십시오.");
  }

  Future<void> _download() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        title: const Text("서버에서 불러오기"),
        content: const Text(
          "지금 폰에 있는 계산기 설정(튜브 벤딩·전선관·튜브 컷팅)을 서버에 보관한 설정으로 바꿉니다.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소", style: TextStyle(color: _slate600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "불러오기",
              style: TextStyle(color: _teal, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    final n = await _sync.restore(onlyIfEmpty: false);
    if (n > 0) {
      // 이미 읽어 둔 설정을 새 값으로 다시 읽는다.
      await AppSettingsController().load();
      await MobileBendDataManager().loadSavedSettings();
      await loadGlobalBenderSettings();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(n > 0 ? "서버에 보관한 설정을 불러왔습니다." : "불러올 설정이 없거나 통신이 되지 않습니다.");
  }

  Future<void> _link() async {
    setState(() => _busy = true);
    final ok = await widget.onLinkGoogle!();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _snack("구글 계정을 연결했습니다. 계산기 설정을 서버에 보관합니다.");
  }

  @override
  Widget build(BuildContext context) {
    final bool linked = _sync.signedIn;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_done_outlined, color: _teal, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "계산기 설정 서버 보관",
                  style: TextStyle(
                    color: _slate900,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            linked
                ? "튜브 벤딩·전선관·튜브 컷팅 설정을 저장하면 구글 계정에 같이 올라갑니다. 앱을 새로 깔면 자동으로 받습니다."
                : "구글 계정을 연결하면 튜브 벤딩·전선관·튜브 컷팅 설정을 계정에 보관합니다. 앱을 지웠다 깔아도 설정이 돌아옵니다. 이름은 그대로입니다.",
            style: const TextStyle(color: _slate600, fontSize: 14, height: 1.4),
          ),
          if (!linked && widget.onLinkGoogle != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('settings_cloud_link'),
                onPressed: _busy ? null : _link,
                style: FilledButton.styleFrom(
                  backgroundColor: _teal,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "구글 계정 연결",
                  style: TextStyle(color: _white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
          if (linked) ...[
            const SizedBox(height: 8),
            ValueListenableBuilder<DateTime?>(
              valueListenable: _sync.lastSynced,
              builder: (context, t, _) => Text(
                _when(t),
                key: const Key('settings_cloud_when'),
                style: const TextStyle(
                  color: _slate900,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('settings_cloud_download'),
                    onPressed: _busy ? null : _download,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: const BorderSide(color: _slate200, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "서버에서 불러오기",
                      style: TextStyle(
                        color: _slate900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('settings_cloud_upload'),
                    onPressed: _busy ? null : _upload,
                    style: FilledButton.styleFrom(
                      backgroundColor: _teal,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: _white,
                            ),
                          )
                        : const Text(
                            "지금 올리기",
                            style: TextStyle(
                              color: _white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
