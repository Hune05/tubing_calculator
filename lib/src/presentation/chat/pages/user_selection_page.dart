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
const Color pureWhite = Color(0xFFFFFFFF);

class UserSelectionPage extends StatefulWidget {
  final String currentUser;

  const UserSelectionPage({super.key, required this.currentUser});

  @override
  State<UserSelectionPage> createState() => _UserSelectionPageState();
}

class _UserSelectionPageState extends State<UserSelectionPage> {
  // 🚀 테스트용 가상 직원 목록
  final List<Map<String, String>> mockUsers = [
    {'name': '김반장', 'team': '배관 1팀'},
    {'name': '이소장', 'team': '현장 관리팀'},
    {'name': '박안전', 'team': '안전 관리팀'},
    {'name': '최설비', 'team': '설비팀'},
  ];

  Future<void> _startChatWith(String targetUser, String targetTeam) async {
    final firestore = FirebaseFirestore.instance;

    // 1. 이미 둘 사이의 1:1 채팅방이 있는지 확인
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

    // 2. 방이 없다면 새로 생성
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

    // 3. 채팅방으로 이동
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
        title: const Text(
          "새로운 채팅",
          style: TextStyle(
            color: slate900,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: mockUsers.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, color: tossGrey, indent: 76),
        itemBuilder: (context, index) {
          final user = mockUsers[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: slate100,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12),
              ),
              child: const Icon(LucideIcons.user, color: slate600, size: 24),
            ),
            title: Text(
              user['name']!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              user['team']!,
              style: const TextStyle(color: slate600, fontSize: 13),
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              _startChatWith(user['name']!, user['team']!);
            },
          );
        },
      ),
    );
  }
}
