import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';

import '../models/report_tools.dart';

const Color _teal = Color(0xFF007580);
const Color _text = Color(0xFF191F28);
const Color _sub = Color(0xFF8B95A1);
const Color _bg = Color(0xFFF2F4F6);
const String _pkg = 'com.example.tubing_calculator';

// 🚀 [알림 점검] 예약 알림(일보/주간 보고)이 안 올 때 원인을 찾는 화면.
// 알림 권한 확인, 즉시 테스트 알림, 배터리 제한 해제 안내를 한 곳에 모았다.
class NotificationCheckPage extends StatefulWidget {
  const NotificationCheckPage({super.key});

  @override
  State<NotificationCheckPage> createState() => _NotificationCheckPageState();
}

class _NotificationCheckPageState extends State<NotificationCheckPage>
    with WidgetsBindingObserver {
  bool? _allowed;
  String? _msg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 설정 화면에 다녀오면 상태를 다시 읽는다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    bool ok = true;
    try {
      ok = await areNotificationsAllowed();
    } catch (_) {}
    if (mounted) setState(() => _allowed = ok);
  }

  Future<void> _test() async {
    try {
      await showTestNotification();
      if (mounted) {
        setState(() => _msg = "테스트 알림을 보냈어요. 상단바에 보이나요? 안 보이면 위 알림 설정을 확인하세요.");
      }
    } catch (e) {
      if (mounted) setState(() => _msg = "테스트 알림 실패: $e");
    }
  }

  Future<void> _open(
    String action, {
    Map<String, dynamic>? args,
    String? data,
  }) async {
    try {
      await AndroidIntent(action: action, arguments: args, data: data).launch();
    } catch (_) {
      if (mounted) {
        setState(() => _msg = "설정 화면을 열지 못했어요. 폰 설정에서 직접 찾아 주세요.");
      }
    }
  }

  Widget _card(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 12),
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

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 15,
        color: _teal,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ok = _allowed;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "알림 점검",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _card([
            _title("1. 알림 권한"),
            Row(
              children: [
                Icon(
                  ok == null
                      ? Icons.hourglass_empty_rounded
                      : (ok ? Icons.check_circle_rounded : Icons.error_rounded),
                  color: ok == null
                      ? _sub
                      : (ok
                            ? const Color(0xFF1B9E5A)
                            : const Color(0xFFE5484D)),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ok == null
                        ? "확인 중…"
                        : (ok ? "알림이 허용돼 있어요." : "알림이 꺼져 있어요. 아래 버튼으로 켜 주세요."),
                    style: const TextStyle(fontSize: 13, color: _text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _open(
                'android.settings.APP_NOTIFICATION_SETTINGS',
                args: {'android.provider.extra.APP_PACKAGE': _pkg},
              ),
              child: const Text("앱 알림 설정 열기"),
            ),
          ]),
          _card([
            _title("2. 테스트 알림"),
            const Text(
              "지금 바로 알림 한 개를 보내 봐요. 보이면 알림 자체는 정상이에요.",
              style: TextStyle(fontSize: 13, height: 1.4, color: _sub),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _test,
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
              ),
              child: const Text("테스트 알림 보내기"),
            ),
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _msg!,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: _text,
                  ),
                ),
              ),
          ]),
          _card([
            _title("3. 예약 알림이 안 올 때 (배터리 제한)"),
            const Text(
              "일보·주간 보고 알림은 정해진 시각에 폰이 앱을 깨워서 보내요. 삼성 등 일부 폰은 "
              "절전 기능이 앱을 재워서 예약 알림이 오지 않을 수 있어요.\n\n"
              "• 설정 → 배터리 → 백그라운드 사용 제한에서 이 앱을 빼 주세요.\n"
              "• 앱 정보 → 배터리 → '제한 없음'(또는 최적화 안 함)으로 바꿔 주세요.",
              style: TextStyle(fontSize: 13, height: 1.5, color: _sub),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _open(
                'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
              ),
              child: const Text("배터리 최적화 설정 열기"),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: () => _open(
                'android.settings.APPLICATION_DETAILS_SETTINGS',
                data: 'package:$_pkg',
              ),
              child: const Text("앱 정보 열기"),
            ),
          ]),
        ],
      ),
    );
  }
}
