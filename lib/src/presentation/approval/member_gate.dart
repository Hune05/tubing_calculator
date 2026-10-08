// 홈 앞에서 승인 상태를 보고, 승인제가 켜져 있는데 아직 승인 전이면 "승인 대기" 화면을
// 보인다(member_approval.dart). 확인하는 동안에는 홈을 그대로 보이고(통신 없는 현장에서
// 앱이 안 열리면 안 된다), 결과가 "막기"일 때만 바꾼다.
import 'package:flutter/material.dart';

import '../../core/common_widgets/app_components.dart';
import '../../core/theme/app_tokens.dart';
import 'member_approval.dart';

class MemberGate extends StatefulWidget {
  final String name;
  final Widget child;

  /// 시험용: 서버 대신 쓰는 확인 함수.
  final Future<MemberCheck> Function(String name)? check;
  final Future<MemberCheck> Function()? cached;

  const MemberGate({
    super.key,
    required this.name,
    required this.child,
    this.check,
    this.cached,
  });

  @override
  State<MemberGate> createState() => _MemberGateState();
}

class _MemberGateState extends State<MemberGate> {
  MemberCheck? _result;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    // 폰에 적어 둔 값부터 보이고(통신 없을 때), 서버 확인이 오면 바꾼다.
    (widget.cached ?? cachedMemberCheck)().then((c) {
      if (mounted && _result == null) setState(() => _result = c);
    });
    _recheck();
  }

  Future<void> _recheck() async {
    if (_checking) return;
    if (mounted) _checking = true;
    if (_result != null) setState(() {});
    try {
      final r = await (widget.check ?? (n) => checkMember(name: n))(widget.name);
      if (mounted) setState(() => _result = r);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    if (r == null || !r.blocked) return widget.child;
    return MemberWaitingPage(
      name: widget.name,
      rejected: r.status == MemberStatus.rejected,
      checking: _checking,
      onRecheck: _recheck,
    );
  }
}

/// 승인 대기(또는 거절) 화면.
class MemberWaitingPage extends StatelessWidget {
  final String name;
  final bool rejected;
  final bool checking;
  final VoidCallback onRecheck;

  const MemberWaitingPage({
    super.key,
    required this.name,
    required this.rejected,
    required this.checking,
    required this.onRecheck,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('member_waiting'),
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(rejected ? '사용 거절' : '승인 대기')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  rejected ? Icons.block_rounded : Icons.hourglass_top_rounded,
                  size: 56,
                  color: rejected ? AppColors.danger : AppColors.textSub,
                ),
                const SizedBox(height: 16),
                Text(
                  rejected ? '사용이 거절되었습니다' : '승인 대기 중입니다',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  rejected
                      ? '관리자에게 문의하십시오.'
                      : '관리자가 승인하면 쓸 수 있습니다.\n승인된 뒤 아래 단추를 누르십시오.',
                  style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textSub),
                  textAlign: TextAlign.center,
                ),
                if (name.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '이름: $name',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSub),
                  ),
                ],
                const SizedBox(height: 28),
                AppButton(
                  key: const Key('member_recheck'),
                  label: checking ? '확인 중…' : '다시 확인',
                  icon: Icons.refresh_rounded,
                  onPressed: checking ? null : onRecheck,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
