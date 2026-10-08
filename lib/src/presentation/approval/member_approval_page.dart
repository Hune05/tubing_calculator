// 관리자 "사용 승인" 화면: 대기 중인 사람을 승인·거절하고, 승인제를 켜고 끈다.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/common_widgets/app_components.dart';
import '../../core/theme/app_tokens.dart';
import 'member_approval.dart';

class MemberApprovalPage extends StatefulWidget {
  const MemberApprovalPage({super.key});

  @override
  State<MemberApprovalPage> createState() => _MemberApprovalPageState();
}

class _MemberApprovalPageState extends State<MemberApprovalPage> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _members =
      FirebaseFirestore.instance.collection(kMembersCollection).snapshots();
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _config =
      FirebaseFirestore.instance.doc(kApprovalConfigPath).snapshots();
  final Set<String> _busy = {};

  Future<void> _set(String uid, String name, MemberStatus s) async {
    setState(() => _busy.add(uid));
    try {
      await setMemberStatus(uid, s);
      if (!mounted) return;
      showAppSnack(
        context,
        s == MemberStatus.approved ? '승인했습니다: $name' : '거절했습니다: $name',
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, '바꾸지 못했습니다. 통신을 확인하십시오.', kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _busy.remove(uid));
    }
  }

  Future<void> _toggle(bool on, int waiting) async {
    if (on) {
      final ok = await showAppConfirm(
        context,
        title: '승인제를 켜시겠습니까?',
        message: waiting > 0
            ? '아직 승인하지 않은 사람이 $waiting명 있습니다. 켜면 그 사람들은 앱을 열 때 "승인 대기" 화면만 봅니다.'
            : '켜면 승인하지 않은 사람은 앱을 열 때 "승인 대기" 화면만 봅니다.',
        okText: '켜기',
        okKey: const Key('member_enforce_ok'),
      );
      if (!ok) return;
    }
    try {
      await setApprovalEnforced(on);
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, '바꾸지 못했습니다. 통신을 확인하십시오.', kind: AppSnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('사용 승인')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _members,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('목록을 읽지 못했습니다. 통신을 확인하십시오.'));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data!.docs.map((d) => d.data()..['uid'] = d.id).toList();
          rows.sort(memberRowOrder);
          final waiting = rows
              .where((r) => memberStatusFromText(r['status'] as String?) == MemberStatus.pending)
              .length;
          return ListView(
            key: const Key('member_list'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _config,
                builder: (context, cfg) {
                  final on = cfg.data?.data()?['enabled'] == true;
                  return Card(
                    elevation: 0,
                    color: AppColors.surface,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: SwitchListTile(
                      key: const Key('member_enforce'),
                      title: const Text('승인제 켜기', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        on
                            ? '켜짐: 승인하지 않은 사람은 "승인 대기" 화면만 봅니다.'
                            : '꺼짐: 새로 들어온 사람은 목록에 올라오기만 하고 앱은 그대로 씁니다. 지금 쓰는 사람을 모두 승인한 뒤 켜십시오.',
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                      value: on,
                      onChanged: (v) => _toggle(v, waiting),
                    ),
                  );
                },
              ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: Text('아직 들어온 사람이 없습니다.')),
                ),
              for (final r in rows) _row(r),
            ],
          );
        },
      ),
    );
  }

  Widget _row(Map<String, dynamic> r) {
    final uid = r['uid'] as String;
    final name = (r['name'] as String?)?.trim().isNotEmpty == true ? r['name'] as String : '이름 없음';
    final email = (r['email'] as String?) ?? '';
    final status = memberStatusFromText(r['status'] as String?);
    final admin = email == kAdminEmail;
    final busy = _busy.contains(uid);
    final (label, color) = switch (status) {
      MemberStatus.approved => ('승인됨', AppColors.ok),
      MemberStatus.rejected => ('거절', AppColors.danger),
      _ => ('대기', AppColors.caution),
    };
    return Card(
      key: Key('member_$uid'),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      label,
                      if (admin) '관리자',
                      email.isNotEmpty ? email : '이름만 넣고 시작',
                      if (r['requestedAt'] is Timestamp) memberWhen((r['requestedAt'] as Timestamp).toDate()),
                    ].join(' · '),
                    style: TextStyle(fontSize: 12, color: status == MemberStatus.pending ? color : AppColors.textSub),
                  ),
                ],
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (!admin) ...[
              if (status != MemberStatus.approved)
                TextButton(
                  key: Key('member_approve_$uid'),
                  onPressed: () => _set(uid, name, MemberStatus.approved),
                  child: const Text('승인', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              if (status != MemberStatus.rejected)
                TextButton(
                  key: Key('member_reject_$uid'),
                  onPressed: () => _set(uid, name, MemberStatus.rejected),
                  child: const Text('거절', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 목록 순서: 대기 → 승인됨 → 거절, 같은 상태끼리는 최근에 들어온 사람 먼저.
int memberRowOrder(Map<String, dynamic> a, Map<String, dynamic> b) {
  int rank(Map<String, dynamic> r) => switch (memberStatusFromText(r['status'] as String?)) {
    MemberStatus.pending || MemberStatus.unknown => 0,
    MemberStatus.approved => 1,
    MemberStatus.rejected => 2,
  };
  final c = rank(a).compareTo(rank(b));
  if (c != 0) return c;
  DateTime t(Map<String, dynamic> r) =>
      r['requestedAt'] is Timestamp ? (r['requestedAt'] as Timestamp).toDate() : DateTime(2000);
  return t(b).compareTo(t(a));
}

String memberWhen(DateTime d) => '${d.month}/${d.day} 신청';
