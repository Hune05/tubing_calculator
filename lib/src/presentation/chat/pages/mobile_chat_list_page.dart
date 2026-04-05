import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:tubing_calculator/src/presentation/chat/pages/mobile_chat_room_page.dart';
import 'package:tubing_calculator/src/presentation/chat/pages/user_selection_page.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileChatListPage extends StatefulWidget {
  final String currentUser;

  const MobileChatListPage({super.key, required this.currentUser});

  @override
  State<MobileChatListPage> createState() => _MobileChatListPageState();
}

class _MobileChatListPageState extends State<MobileChatListPage> {
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    final now = DateTime.now();

    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      final ampm = dt.hour < 12 ? '오전' : '오후';
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      return '$ampm $h:$m';
    } else if (now.difference(dt).inDays == 1 ||
        (now.day - dt.day == 1 && now.month == dt.month)) {
      return '어제';
    } else if (dt.year == now.year) {
      return '${dt.month}월 ${dt.day}일';
    } else {
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    }
  }

  // 🔥 수정됨: 방 전체 삭제가 아니라, 참여자 목록에서 '나'만 제거하도록 변경
  Future<void> _deleteChatRoom(String roomId) async {
    try {
      final firestore = FirebaseFirestore.instance;

      await firestore.collection('chat_rooms').doc(roomId).update({
        'participants': FieldValue.arrayRemove([widget.currentUser]),
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('채팅방을 나갔습니다.')));
      }
    } catch (e) {
      debugPrint("채팅방 나가기 에러: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pureWhite,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          "메시지",
          style: TextStyle(
            color: slate900,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.search, color: slate900),
            onPressed: () => HapticFeedback.lightImpact(),
          ),
          IconButton(
            icon: const Icon(LucideIcons.plus, color: slate900),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      UserSelectionPage(currentUser: widget.currentUser),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🔥 수정됨: 내가 participants 배열에 포함된 채팅방만 가져오기
        stream: FirebaseFirestore.instance
            .collection('chat_rooms')
            .where('participants', arrayContains: widget.currentUser)
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: tossBlue),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("참여 중인 대화가 없습니다.", style: TextStyle(color: slate600)),
            );
          }

          final rooms = snapshot.data!.docs;

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: rooms.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, color: tossGrey, indent: 76),
            itemBuilder: (context, index) {
              final doc = rooms[index];
              final room = doc.data() as Map<String, dynamic>;
              room['id'] = doc.id;

              return _buildChatListItem(room);
            },
          );
        },
      ),
    );
  }

  Widget _buildChatListItem(Map<String, dynamic> room) {
    bool isGroup = room['isGroup'] ?? false;
    int unreadCount = room['unread'] ?? 0;
    bool hasUnread = unreadCount > 0;

    String title = isGroup
        ? (room['groupTitle'] ?? '단톡방')
        : (room['name'] ?? '이름 없음');
    String subtitle = isGroup
        ? "${(room['participants'] as List?)?.length ?? 0}명 참여중"
        : (room['team'] ?? '소속 없음');

    return Dismissible(
      key: Key(room['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade400,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(LucideIcons.trash2, color: pureWhite, size: 28),
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.heavyImpact();
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: pureWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              '채팅방 나가기',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text('채팅방을 나가시겠습니까?\n(상대방에게는 대화방이 유지됩니다)'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소', style: TextStyle(color: slate600)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  '나가기',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        _deleteChatRoom(room['id']);
      },
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();

          if (hasUnread) {
            FirebaseFirestore.instance
                .collection('chat_rooms')
                .doc(room['id'])
                .update({'unread': 0});
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MobileChatRoomPage(
                currentUser: widget.currentUser,
                roomId: room['id'],
                isGroupChat: isGroup,
                chatPartnerName: isGroup ? null : room['name'],
                chatPartnerTeam: isGroup ? null : room['team'],
                groupTitle: isGroup ? room['groupTitle'] : null,
                groupParticipants: isGroup
                    ? List<String>.from(room['participants'] ?? [])
                    : null,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isGroup ? tossBlue.withValues(alpha: 0.1) : slate100,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12),
                ),
                child: Icon(
                  isGroup ? LucideIcons.users : LucideIcons.user,
                  color: isGroup ? tossBlue : slate600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: slate600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room['lastMessage'] ?? '메시지가 없습니다.',
                      style: TextStyle(
                        fontSize: 14,
                        color: hasUnread ? slate900 : slate600,
                        fontWeight: hasUnread
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(room['updatedAt'] as Timestamp?),
                    style: TextStyle(
                      fontSize: 12,
                      color: hasUnread ? tossBlue : slate600,
                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (hasUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tossBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "$unreadCount",
                        style: const TextStyle(
                          color: pureWhite,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
