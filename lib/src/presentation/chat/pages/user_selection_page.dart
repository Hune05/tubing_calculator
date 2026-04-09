import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:tubing_calculator/src/presentation/chat/pages/mobile_chat_room_page.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color slate300 = Color(0xFFD1D6DB);
const Color pureWhite = Color(0xFFFFFFFF);

class UserSelectionPage extends StatefulWidget {
  final String currentUser;
  final bool isGroupMode;

  const UserSelectionPage({
    super.key,
    required this.currentUser,
    this.isGroupMode = false,
  });

  @override
  State<UserSelectionPage> createState() => _UserSelectionPageState();
}

class _UserSelectionPageState extends State<UserSelectionPage> {
  // 🔥 가짜 데이터(mockUsers) 삭제 완료!
  // 🔥 대신 선택된 유저의 '이름'만 저장하도록 Set을 심플하게 변경했습니다.
  final Set<String> _selectedUserNames = {};

  Future<void> _start1on1ChatWith(String targetUser, String targetTeam) async {
    final firestore = FirebaseFirestore.instance;

    final existingRooms = await firestore
        .collection('chat_rooms')
        .where('isGroup', isEqualTo: false)
        .where('participants', arrayContains: widget.currentUser)
        .get();

    String? roomId;
    for (var doc in existingRooms.docs) {
      List<dynamic> participants = doc['participants'];
      if (participants.contains(targetUser)) {
        roomId = doc.id;
        break;
      }
    }

    if (roomId == null) {
      final newRoom = await firestore.collection('chat_rooms').add({
        'isGroup': false,
        'name': targetUser,
        'team': targetTeam,
        'participants': [widget.currentUser, targetUser],
        'lastMessage': '새로운 대화가 시작되었습니다.',
        'updatedAt': FieldValue.serverTimestamp(),
        'unread': 0,
      });
      roomId = newRoom.id;
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MobileChatRoomPage(
          currentUser: widget.currentUser,
          roomId: roomId!,
          isGroupChat: false,
          chatPartnerName: targetUser,
          chatPartnerTeam: targetTeam,
        ),
      ),
    );
  }

  Future<void> _createGroupChat() async {
    if (_selectedUserNames.isEmpty) return;
    HapticFeedback.mediumImpact();

    // 1. 선택된 유저 이름 리스트에 내 이름 추가
    List<String> participantNames = _selectedUserNames.toList();
    participantNames.add(widget.currentUser);

    String defaultGroupTitle = "그룹 채팅방";

    // 2. Firestore에 단톡방 생성
    final firestore = FirebaseFirestore.instance;
    final newRoom = await firestore.collection('chat_rooms').add({
      'isGroup': true,
      'groupTitle': defaultGroupTitle,
      'participants': participantNames,
      'lastMessage': '새로운 그룹 대화가 시작되었습니다.',
      'updatedAt': FieldValue.serverTimestamp(),
      'unread': 0,
    });

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MobileChatRoomPage(
          currentUser: widget.currentUser,
          roomId: newRoom.id,
          isGroupChat: true,
          groupTitle: defaultGroupTitle,
          groupParticipants: participantNames,
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
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slate900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isGroupMode ? "대화 상대 선택" : "새로운 채팅",
          style: const TextStyle(
            color: slate900,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // 🔥 가짜 리스트 대신 StreamBuilder로 Firestore의 users 컬렉션을 실시간으로 감시합니다!
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("유저 목록을 불러오는데 실패했습니다."));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: tossBlue),
            );
          }

          // 🔥 전체 유저 중에서 '나 자신(currentUser)'은 목록에서 제외합니다.
          final userDocs = snapshot.data!.docs
              .where((doc) => doc.id != widget.currentUser)
              .toList();

          if (userDocs.isEmpty) {
            return const Center(
              child: Text(
                "아직 가입한 다른 작업자가 없습니다.",
                style: TextStyle(color: slate600, fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: userDocs.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, color: tossGrey, indent: 76),
            itemBuilder: (context, index) {
              final data = userDocs[index].data() as Map<String, dynamic>;

              // DB에 이름이나 팀이 비어있을 경우를 대비한 안전장치
              final String userName = data['name'] ?? userDocs[index].id;
              final String userTeam =
                  data['team']?.toString().isNotEmpty == true
                  ? data['team']
                  : '소속 없음';

              final bool isSelected = _selectedUserNames.contains(userName);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                trailing: widget.isGroupMode
                    ? Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? tossBlue : pureWhite,
                          border: Border.all(
                            color: isSelected ? tossBlue : slate300,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: pureWhite,
                              )
                            : null,
                      )
                    : null,
                leading: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: slate100,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Icon(
                    LucideIcons.user,
                    color: slate600,
                    size: 24,
                  ),
                ),
                title: Text(
                  userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  userTeam,
                  style: const TextStyle(color: slate600, fontSize: 13),
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (widget.isGroupMode) {
                    setState(() {
                      if (isSelected) {
                        _selectedUserNames.remove(userName);
                      } else {
                        _selectedUserNames.add(userName);
                      }
                    });
                  } else {
                    _start1on1ChatWith(userName, userTeam);
                  }
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: widget.isGroupMode
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _selectedUserNames.isEmpty
                        ? null
                        : _createGroupChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tossBlue,
                      disabledBackgroundColor: slate100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _selectedUserNames.isEmpty
                          ? "상대를 선택해주세요"
                          : "${_selectedUserNames.length}명과 대화 시작하기",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _selectedUserNames.isEmpty
                            ? slate600
                            : pureWhite,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
