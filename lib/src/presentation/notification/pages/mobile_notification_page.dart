import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

// 프로젝트 공통 컬러
const Color tossBlue = Color(0xFF3182F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF5F6B78);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color red500 = Color(0xFFF04452);

// 🚀 [알림 고도화] 예전엔 이 화면이 그냥 최근 20건을 나열만 하고,
// 안읽음/읽음 구분도 없고, 눌러도 아무 반응이 없었다("TODO: 필요시
// 상세 페이지로 이동"). announcements 문서에 readBy(배열) 필드를 추가해서
// "누가 이미 읽었는지"를 실제로 추적하고, 탭하면 상세 내용을 보여주면서
// 그 순간 읽음 처리하도록 바꿨다. 날짜별(오늘/어제/이전)로 묶고, 안읽은
// 항목은 파란 점으로 표시하며, "모두 읽음" 일괄 처리도 추가했다.
class MobileNotificationPage extends StatefulWidget {
  final String currentWorker;

  const MobileNotificationPage({super.key, required this.currentWorker});

  @override
  State<MobileNotificationPage> createState() => _MobileNotificationPageState();
}

class _MobileNotificationPageState extends State<MobileNotificationPage> {
  bool get _hasIdentity =>
      widget.currentWorker.isNotEmpty && widget.currentWorker != "로그인 필요";

  bool _isRead(Map<String, dynamic> data) {
    if (!_hasIdentity) return true;
    final readBy = (data['readBy'] as List?) ?? [];
    return readBy.contains(widget.currentWorker);
  }

  Future<void> _markAsRead(
    DocumentReference ref,
    Map<String, dynamic> data,
  ) async {
    if (!_hasIdentity || _isRead(data)) return;
    await ref.update({
      'readBy': FieldValue.arrayUnion([widget.currentWorker]),
    });
  }

  Future<void> _markAllRead(List<QueryDocumentSnapshot> docs) async {
    if (!_hasIdentity) return;
    final unread = docs.where(
      (d) => !_isRead(d.data() as Map<String, dynamic>),
    );
    if (unread.isEmpty) return;
    HapticFeedback.mediumImpact();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in unread) {
      batch.update(d.reference, {
        'readBy': FieldValue.arrayUnion([widget.currentWorker]),
      });
    }
    await batch.commit();
  }

  ({IconData icon, Color color}) _iconMeta(String title) {
    if (title.contains("회의") || title.contains("회식")) {
      return (icon: LucideIcons.calendarClock, color: const Color(0xFF8A2BE2));
    } else if (title.contains("긴급")) {
      return (icon: LucideIcons.alertTriangle, color: red500);
    }
    return (icon: LucideIcons.clipboardList, color: tossBlue);
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return "오늘";
    if (day == yesterday) return "어제";
    return DateFormat('yyyy년 MM월 dd일').format(day);
  }

  void _showDetail(DocumentReference ref, Map<String, dynamic> data) {
    _markAsRead(ref, data);
    final title = (data['title'] ?? '알림').toString();
    final content = (data['content'] ?? '').toString();
    final createdAt = data['createdAt'] as Timestamp?;
    final meta = _iconMeta(title);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: meta.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(meta.icon, color: meta.color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: slate900,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: slate600),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  DateFormat('yyyy년 MM월 dd일 HH:mm').format(createdAt.toDate()),
                  style: const TextStyle(fontSize: 12, color: slate600),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                content.isEmpty ? "내용이 없습니다." : content,
                style: const TextStyle(
                  fontSize: 15,
                  color: slate900,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pureWhite,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: slate900),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "알림 내역",
          style: TextStyle(
            color: slate900,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🔥 최근 알림 내역을 불러옵니다.
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: tossBlue),
            );
          }

          // 🔥 스트림 에러(권한/색인 문제 등)를 "알림 없음"으로 숨기지 않고 표시
          if (snapshot.hasError) {
            debugPrint("알림 스트림 에러: ${snapshot.error}");
            return _buildErrorState();
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final docs = snapshot.data!.docs;
          final unreadCount = docs
              .where((d) => !_isRead(d.data() as Map<String, dynamic>))
              .length;

          final Map<DateTime, List<QueryDocumentSnapshot>> grouped = {};
          for (final d in docs) {
            final ts =
                (d.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final dt = ts?.toDate() ?? DateTime.now();
            final day = DateTime(dt.year, dt.month, dt.day);
            grouped.putIfAbsent(day, () => []).add(d);
          }
          final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

          return Column(
            children: [
              if (unreadCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "안읽음 $unreadCount건",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: tossBlue,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _markAllRead(docs),
                        child: const Text(
                          "모두 읽음",
                          style: TextStyle(
                            color: slate600,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: days.length,
                  itemBuilder: (context, dayIndex) {
                    final day = days[dayIndex];
                    final dayDocs = grouped[day]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                          child: Text(
                            _dayLabel(day),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: slate600,
                            ),
                          ),
                        ),
                        ...dayDocs.map((doc) => _buildNotificationTile(doc)),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? '알림';
    final content = data['content'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final bool isRead = _isRead(data);
    final meta = _iconMeta(title);

    String dateText = '';
    if (createdAt != null) {
      dateText = DateFormat('HH:mm').format(createdAt.toDate());
    }

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _showDetail(doc.reference, data);
      },
      child: Container(
        color: isRead ? Colors.transparent : tossBlue.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(meta.icon, color: meta.color, size: 22),
                ),
                if (!isRead)
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: tossBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: pureWhite, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                      color: slate900,
                    ),
                  ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      content,
                      style: const TextStyle(fontSize: 14, color: slate600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    dateText,
                    style: TextStyle(
                      fontSize: 12,
                      color: slate600.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.bellOff, size: 48, color: slate100),
          const SizedBox(height: 16),
          const Text(
            "새로운 알림이 없습니다.",
            style: TextStyle(
              color: slate600,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            LucideIcons.alertTriangle,
            size: 48,
            color: Color(0xFFF04438),
          ),
          const SizedBox(height: 16),
          const Text(
            "알림을 불러오지 못했습니다.",
            style: TextStyle(
              color: slate600,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
