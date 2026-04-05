import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tubing_calculator/src/data/models/order_model.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileChatRoomPage extends StatefulWidget {
  final String currentUser;
  final String roomId;

  final String? chatPartnerName;
  final String? chatPartnerTeam;

  final bool isGroupChat;
  final String? groupTitle;
  final List<String>? groupParticipants;

  final OrderModel? order;
  final bool isReadOnly;

  const MobileChatRoomPage({
    super.key,
    required this.currentUser,
    required this.roomId,
    this.chatPartnerName,
    this.chatPartnerTeam,
    this.isGroupChat = false,
    this.groupTitle,
    this.groupParticipants,
    this.order,
    this.isReadOnly = false,
  });

  @override
  State<MobileChatRoomPage> createState() => _MobileChatRoomPageState();
}

class _MobileChatRoomPageState extends State<MobileChatRoomPage> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _messageLimit = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        setState(() {
          _messageLimit += 20;
        });
        HapticFeedback.lightImpact();
      }
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _sendMessage() async {
    if (_msgCtrl.text.trim().isEmpty) return;

    final text = _msgCtrl.text.trim();
    _msgCtrl.clear();

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .collection('messages')
        .add({
          'senderName': widget.currentUser,
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
          'readBy': [widget.currentUser],
        });

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .set({
          'lastMessage': text,
          'updatedAt': FieldValue.serverTimestamp(),
          'unread': FieldValue.increment(1),
        }, SetOptions(merge: true));
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진을 전송 중입니다...')));

      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(fileName);

      await ref.putFile(File(image.path));
      String downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
            'senderName': widget.currentUser,
            'text': '',
            'imageUrl': downloadUrl,
            'timestamp': FieldValue.serverTimestamp(),
            'readBy': [widget.currentUser],
          });

      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.roomId)
          .set({
            'lastMessage': '📷 사진을 보냈습니다.',
            'updatedAt': FieldValue.serverTimestamp(),
            'unread': FieldValue.increment(1),
          }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('사진 전송에 실패했습니다.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isOrderChat = widget.order != null;
    bool isOrderClosed =
        isOrderChat &&
        (widget.order!.status == "처리 완료" || widget.order!.status == "반려됨");
    bool hideInputArea = widget.isReadOnly || isOrderClosed;

    String appBarTitle = widget.isGroupChat
        ? (widget.groupTitle ?? "단톡방")
        : (widget.chatPartnerName ?? "알 수 없음");
    String appBarSubtitle = widget.isGroupChat
        ? "참여 ${widget.groupParticipants?.length ?? 0}명"
        : (widget.chatPartnerTeam ?? "소속 없음");

    return Scaffold(
      backgroundColor: pureWhite,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slate900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appBarTitle,
              style: const TextStyle(
                color: slate900,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              appBarSubtitle,
              style: const TextStyle(
                color: slate600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.isGroupChat ? LucideIcons.menu : LucideIcons.phone,
              color: slate900,
              size: 22,
            ),
            onPressed: () async {
              HapticFeedback.lightImpact();
              if (!widget.isGroupChat) {
                // 임시 번호입니다. DB에 번호가 있다면 그 번호를 넣으세요.
                final Uri url = Uri.parse('tel:010-0000-0000');
                // 🔥 수정됨: 외부 앱 무조건 호출로 변경 (T전화 충돌 방지)
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('전화를 걸 수 없습니다.')),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('단톡방 메뉴 준비 중입니다.')),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chat_rooms')
                    .doc(widget.roomId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(_messageLimit)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: tossBlue),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "첫 메시지를 보내보세요.",
                        style: TextStyle(color: slate600),
                      ),
                    );
                  }

                  final messages = snapshot.data!.docs;

                  Future.microtask(() {
                    final batch = FirebaseFirestore.instance.batch();
                    bool hasUpdates = false;
                    for (var doc in messages) {
                      final data = doc.data() as Map<String, dynamic>;
                      final List readBy = data['readBy'] ?? [];
                      if (!readBy.contains(widget.currentUser)) {
                        batch.update(doc.reference, {
                          'readBy': FieldValue.arrayUnion([widget.currentUser]),
                        });
                        hasUpdates = true;
                      }
                    }
                    if (hasUpdates) batch.commit();
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final doc = messages[index];
                      final msg = doc.data() as Map<String, dynamic>;
                      final messageId = doc.id;
                      bool isMe = msg['senderName'] == widget.currentUser;

                      bool isSameUserAsPrev = false;
                      if (index < messages.length - 1 &&
                          (messages[index + 1].data() as Map)['senderName'] ==
                              msg['senderName']) {
                        isSameUserAsPrev = true;
                      }

                      return _buildMessageBubble(
                        msg,
                        isMe,
                        isSameUserAsPrev,
                        messageId,
                      );
                    },
                  );
                },
              ),
            ),
            if (!hideInputArea) _buildInputArea(isOrderChat),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    bool isMe,
    bool isSameUserAsPrev,
    String messageId,
  ) {
    final bool hasImage =
        msg['imageUrl'] != null && msg['imageUrl'].toString().isNotEmpty;
    final bool hasText =
        msg['text'] != null && msg['text'].toString().isNotEmpty;

    int totalMembers = widget.isGroupChat
        ? (widget.groupParticipants?.length ?? 2)
        : 2;
    List readBy = msg['readBy'] ?? [msg['senderName']];
    int unreadCount = totalMembers - readBy.length;
    if (unreadCount < 0) unreadCount = 0;

    return GestureDetector(
      onLongPress: () async {
        if (!isMe) return;
        HapticFeedback.heavyImpact();
        final bool? shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: pureWhite,
            title: const Text(
              '메시지 삭제',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text('이 메시지를 삭제하시겠습니까?\n(상대방 창에서도 지워집니다)'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소', style: TextStyle(color: slate600)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (shouldDelete == true && mounted) {
          await FirebaseFirestore.instance
              .collection('chat_rooms')
              .doc(widget.roomId)
              .collection('messages')
              .doc(messageId)
              .delete();
        }
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: isSameUserAsPrev ? 8 : 24),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && !isSameUserAsPrev)
              Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: slate100,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12),
                ),
                child: const Icon(LucideIcons.user, color: slate600, size: 18),
              )
            else if (!isMe && isSameUserAsPrev)
              const SizedBox(width: 44),

            if (isMe)
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (unreadCount > 0)
                      Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: tossBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    Text(
                      _formatTime(msg['timestamp'] as Timestamp?),
                      style: const TextStyle(color: slate600, fontSize: 11),
                    ),
                  ],
                ),
              ),

            Flexible(
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMe && widget.isGroupChat && !isSameUserAsPrev)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 4),
                      child: Text(
                        msg['senderName'] ?? '알 수 없음',
                        style: const TextStyle(
                          color: slate600,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  if (hasImage)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenImageViewer(
                              imageUrl: msg['imageUrl'],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: EdgeInsets.only(bottom: hasText ? 4 : 0),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.6,
                          maxHeight: 250,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            msg['imageUrl'],
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                ? child
                                : Container(
                                    height: 150,
                                    width: 150,
                                    color: slate100,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: tossBlue,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),

                  if (hasText)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? tossBlue : tossGrey,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(
                            isMe
                                ? 20
                                : (isSameUserAsPrev && !hasImage ? 20 : 4),
                          ),
                          bottomRight: Radius.circular(
                            !isMe
                                ? 20
                                : (isSameUserAsPrev && !hasImage ? 20 : 4),
                          ),
                        ),
                      ),
                      child: Text(
                        msg['text'] ?? '',
                        style: TextStyle(
                          color: isMe ? pureWhite : slate900,
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (unreadCount > 0)
                      Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: tossBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    Text(
                      _formatTime(msg['timestamp'] as Timestamp?),
                      style: const TextStyle(color: slate600, fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isOrderChat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        color: pureWhite,
        border: Border(top: BorderSide(color: tossGrey, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(LucideIcons.plusCircle, color: slate600),
            onPressed: () {
              HapticFeedback.lightImpact();
              _pickAndUploadImage();
            },
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: tossGrey,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _msgCtrl,
                minLines: 1,
                maxLines: 5,
                cursorColor: tossBlue,
                style: const TextStyle(fontSize: 16, color: slate900),
                decoration: InputDecoration(
                  hintText: isOrderChat ? "발주 관련 메시지 남기기..." : "메시지 보내기",
                  hintStyle: const TextStyle(color: slate600, fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: tossBlue,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: pureWhite, size: 20),
              onPressed: () {
                HapticFeedback.lightImpact();
                _sendMessage();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}
