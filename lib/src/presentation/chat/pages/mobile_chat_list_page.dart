import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  final ScrollController _scrollController = ScrollController();

  final List<DocumentSnapshot> _rooms = [];
  StreamSubscription<QuerySnapshot>? _realtimeSub;
  DocumentSnapshot? _lastDoc;
  bool _isFetching = false;
  bool _hasMore = true;
  static const int _perPage = 20;

  @override
  void initState() {
    super.initState();
    _initRoomsStream();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetchMoreRooms();
    }
  }

  void _initRoomsStream() {
    Query query = FirebaseFirestore.instance
        .collection('chat_rooms')
        .where('participants', arrayContains: widget.currentUser)
        .orderBy('updatedAt', descending: true)
        .limit(_perPage);

    _realtimeSub = query.snapshots().listen(
      (snapshot) {
        if (!mounted) return;

        setState(() {
          if (_rooms.isEmpty) {
            _rooms.addAll(snapshot.docs);
            if (snapshot.docs.isNotEmpty) _lastDoc = snapshot.docs.last;
            _hasMore = snapshot.docs.length == _perPage;
          } else {
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final exists = _rooms.any((doc) => doc.id == change.doc.id);
                if (!exists) _rooms.insert(0, change.doc);
              } else if (change.type == DocumentChangeType.modified) {
                final index = _rooms.indexWhere(
                  (doc) => doc.id == change.doc.id,
                );
                if (index != -1) _rooms[index] = change.doc;
              } else if (change.type == DocumentChangeType.removed) {
                _rooms.removeWhere((doc) => doc.id == change.doc.id);
              }
            }

            // 🔥 시간 null 처리 완벽 방어
            _rooms.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;

              final aTime = aData['updatedAt'] as Timestamp?;
              final bTime = bData['updatedAt'] as Timestamp?;

              final aDate = aTime?.toDate() ?? DateTime.now();
              final bDate = bTime?.toDate() ?? DateTime.now();

              return bDate.compareTo(aDate);
            });
          }
        });
      },
      onError: (error) {
        // 🔥 에러 발생 시 무한 로딩 방지 및 로그 출력
        debugPrint("채팅방 목록 스트림 에러 (색인 필요 확인): $error");
        if (mounted) {
          setState(() {
            _hasMore = false;
            _isFetching = false;
          });
        }
      },
    );
  }

  Future<void> _fetchMoreRooms() async {
    if (_isFetching || !_hasMore || _lastDoc == null) return;

    setState(() => _isFetching = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('participants', arrayContains: widget.currentUser)
          .orderBy('updatedAt', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(_perPage);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isFetching = false;
        });
        return;
      }

      setState(() {
        for (var doc in snapshot.docs) {
          if (!_rooms.any((r) => r.id == doc.id)) {
            _rooms.add(doc);
          }
        }
        _lastDoc = snapshot.docs.last;
        _hasMore = snapshot.docs.length == _perPage;
        _isFetching = false;
      });
    } catch (e) {
      debugPrint("과거 채팅방 목록 호출 에러: $e");
      if (mounted) setState(() => _isFetching = false);
    }
  }

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
          // 🔥 아이콘 변경 및 바텀시트 호출 연결
          IconButton(
            icon: const Icon(LucideIcons.messageSquarePlus, color: slate900),
            onPressed: () {
              HapticFeedback.lightImpact();
              _showCreateChatBottomSheet(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _rooms.isEmpty && _hasMore
          ? const Center(child: CircularProgressIndicator(color: tossBlue))
          : _rooms.isEmpty
          ? const Center(
              child: Text(
                "참 참여 중인 대화가 없습니다.",
                style: TextStyle(color: slate600),
              ),
            )
          : ListView.separated(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              itemCount: _rooms.length + (_hasMore ? 1 : 0),
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: tossGrey, indent: 76),
              itemBuilder: (context, index) {
                if (index == _rooms.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(color: tossBlue),
                    ),
                  );
                }

                final doc = _rooms[index];
                final room = doc.data() as Map<String, dynamic>;
                room['id'] = doc.id;

                return _buildChatListItem(room);
              },
            ),
    );
  }

  Widget _buildRoomAvatar(bool isGroup, String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black12),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: slate100,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: tossBlue,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => _buildDefaultAvatar(isGroup),
          ),
        ),
      );
    }
    return _buildDefaultAvatar(isGroup);
  }

  Widget _buildDefaultAvatar(bool isGroup) {
    return Container(
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
    );
  }

  Widget _buildChatListItem(Map<String, dynamic> room) {
    bool isGroup = room['isGroup'] ?? false;
    int unreadCount = room['unread'] ?? 0;

    // 🔥 내가 보낸 메시지면 알림 배지 끄기
    bool isMyLastMessage = room['lastSender'] == widget.currentUser;
    bool hasUnread = unreadCount > 0 && !isMyLastMessage;

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
        // 🔥 화면에서 즉시 지워서 잔상 방지
        setState(() {
          _rooms.removeWhere((r) => r.id == room['id']);
        });
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
              _buildRoomAvatar(isGroup, room['imageUrl']),
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

  // 🔥 새로운 대화 생성을 위한 바텀 시트 메뉴
  void _showCreateChatBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 손잡이 (핸들)
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: tossGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 20, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "새로운 대화",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: slate900,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: slate100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.user, color: slate900),
                  ),
                  title: const Text(
                    "1:1 개인 채팅",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: const Text(
                    "동료와 1:1로 대화합니다.",
                    style: TextStyle(color: slate600, fontSize: 13),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserSelectionPage(
                          currentUser: widget.currentUser,
                          isGroupMode: false, // 1:1 모드
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tossBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.users, color: tossBlue),
                  ),
                  title: const Text(
                    "팀/그룹 채팅 생성",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: const Text(
                    "여러 명과 동시에 소통할 단톡방을 만듭니다.",
                    style: TextStyle(color: slate600, fontSize: 13),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // 🔥 이제 준비 중 스낵바 대신 바로 다중 선택 페이지로 넘어갑니다!
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserSelectionPage(
                          currentUser: widget.currentUser,
                          isGroupMode: true, // 🔥 그룹 모드로 열기!
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
