import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:tubing_calculator/src/data/models/order_model.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color red500 = Color(0xFFF04452);

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

  final List<DocumentSnapshot> _messages = [];
  StreamSubscription<QuerySnapshot>? _realtimeSub;
  StreamSubscription<DocumentSnapshot>? _roomInfoSub; // 🔥 방 정보(이름, 참여자) 감지용

  DocumentSnapshot? _lastDoc;
  bool _isFetching = false;
  bool _hasMore = true;
  static const int _perPage = 20;

  // 🔥 단톡방 상태 관리용 로컬 변수
  late String _currentGroupTitle;
  late List<String> _currentParticipants;

  // 임시 더미 유저 (초대하기 기능용)
  final List<Map<String, String>> mockUsers = [
    {'name': '김반장', 'team': '배관 1팀'},
    {'name': '이소장', 'team': '현장 관리팀'},
    {'name': '박안전', 'team': '안전 관리팀'},
    {'name': '최설비', 'team': '설비팀'},
  ];

  @override
  void initState() {
    super.initState();
    _currentGroupTitle = widget.groupTitle ?? "그룹 채팅방";
    _currentParticipants = widget.groupParticipants ?? [];

    _initRoomInfoStream(); // 🔥 방 이름/참여자 변경 감지 시작
    _initChatStream();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _roomInfoSub?.cancel();
    _msgCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetchMoreMessages();
    }
  }

  // 🔥 방 정보 실시간 감지 (누가 초대되거나 방 이름이 바뀌면 즉시 화면에 반영)
  void _initRoomInfoStream() {
    if (widget.isGroupChat) {
      _roomInfoSub = FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.roomId)
          .snapshots()
          .listen((doc) {
            if (doc.exists && mounted) {
              setState(() {
                _currentGroupTitle = doc.data()?['groupTitle'] ?? "그룹 채팅방";
                _currentParticipants = List<String>.from(
                  doc.data()?['participants'] ?? [],
                );
              });
            }
          });
    }
  }

  void _initChatStream() {
    Query query = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(_perPage);

    _realtimeSub = query.snapshots().listen((snapshot) {
      if (!mounted) return;

      final batch = FirebaseFirestore.instance.batch();
      bool hasUpdates = false;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List readBy = data['readBy'] ?? [];
        if (!readBy.contains(widget.currentUser)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([widget.currentUser]),
          });
          hasUpdates = true;
        }
      }
      if (hasUpdates) {
        batch.update(
          FirebaseFirestore.instance
              .collection('chat_rooms')
              .doc(widget.roomId),
          {'unread': 0},
        );
        batch.commit();
      }

      setState(() {
        if (_messages.isEmpty) {
          _messages.addAll(snapshot.docs);
          if (snapshot.docs.isNotEmpty) _lastDoc = snapshot.docs.last;
          _hasMore = snapshot.docs.length == _perPage;
        } else {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final exists = _messages.any((doc) => doc.id == change.doc.id);
              if (!exists) _messages.insert(0, change.doc);
            } else if (change.type == DocumentChangeType.modified) {
              final index = _messages.indexWhere(
                (doc) => doc.id == change.doc.id,
              );
              if (index != -1) _messages[index] = change.doc;
            } else if (change.type == DocumentChangeType.removed) {
              _messages.removeWhere((doc) => doc.id == change.doc.id);
            }
          }
        }
      });
    });
  }

  Future<void> _fetchMoreMessages() async {
    if (_isFetching || !_hasMore || _lastDoc == null) return;
    setState(() => _isFetching = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.roomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
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
        _messages.addAll(snapshot.docs);
        _lastDoc = snapshot.docs.last;
        _hasMore = snapshot.docs.length == _perPage;
        _isFetching = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    final ampm = dt.hour < 12 ? '오전' : '오후';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$ampm $h:$m';
  }

  bool _isSameDay(Timestamp? t1, Timestamp? t2) {
    if (t1 == null || t2 == null) return false;
    DateTime d1 = t1.toDate();
    DateTime d2 = t2.toDate();
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _getDateDividerText(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    String weekday = weekdays[dt.weekday - 1];
    return '${dt.year}년 ${dt.month}월 ${dt.day}일 $weekday요일';
  }

  // 🌟 [핵심] 시스템 메시지 전송 로직
  Future<void> _sendSystemMessage(String sysText) async {
    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .collection('messages')
        .add({
          'text': sysText,
          'isSystem': true, // 🔥 이 플래그가 있으면 회색 캡슐로 그려집니다
          'timestamp': FieldValue.serverTimestamp(),
          'readBy': [widget.currentUser],
        });

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .set({
          'lastMessage': sysText,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
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
          'isSystem': false,
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
          'lastSender': widget.currentUser,
        }, SetOptions(merge: true));
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();

    // 🔥 서버 비용 절약을 위한 이미지 압축 설정 (핵심 변경점)
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 50,
    );

    if (image == null) return;
    if (!mounted) return;

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
            'isSystem': false,
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
            'lastSender': widget.currentUser,
          }, SetOptions(merge: true));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('사진 전송에 실패했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isOrderChat = widget.order != null;
    bool isOrderClosed =
        isOrderChat &&
        (widget.order!.status == "처리 완료" || widget.order!.status == "반려됨");
    bool hideInputArea = widget.isReadOnly || isOrderClosed;

    // 🔥 로컬 변수로 바뀐 방 이름과 참여자 수를 반영
    String appBarTitle = widget.isGroupChat
        ? _currentGroupTitle
        : (widget.chatPartnerName ?? "알 수 없음");
    String appBarSubtitle = widget.isGroupChat
        ? "참여 ${_currentParticipants.length}명"
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
            // 🔥 단톡방일 때는 메뉴 아이콘, 1:1일 때는 전화 아이콘
            icon: Icon(
              widget.isGroupChat ? LucideIcons.menu : LucideIcons.phone,
              color: slate900,
              size: 22,
            ),
            onPressed: () async {
              HapticFeedback.lightImpact();
              if (widget.isGroupChat) {
                _showGroupChatMenu(); // 🌟 단톡방 메뉴 띄우기
              } else {
                // (1:1 전화 기능 유지)
                if (widget.chatPartnerName == null) return;
                try {
                  final userDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.chatPartnerName)
                      .get();
                  if (!mounted) return;
                  if (userDoc.exists &&
                      userDoc.data()!.containsKey('phoneNumber')) {
                    final String phoneNumber =
                        userDoc.data()!['phoneNumber'] ?? '';
                    if (phoneNumber.isNotEmpty) {
                      final Uri url = Uri.parse('tel:$phoneNumber');
                      if (await canLaunchUrl(url))
                        await launchUrl(url);
                      else
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('전화 앱을 실행할 수 없습니다.')),
                        );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('등록된 전화번호가 없습니다.')),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('등록된 전화번호가 없습니다.')),
                    );
                  }
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('전화번호를 불러오는데 실패했습니다.')),
                    );
                }
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
              child: _messages.isEmpty && _hasMore
                  ? const Center(
                      child: CircularProgressIndicator(color: tossBlue),
                    )
                  : _messages.isEmpty
                  ? const Center(
                      child: Text(
                        "대화를 시작해보세요.",
                        style: TextStyle(color: slate600),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _messages.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: CircularProgressIndicator(color: tossBlue),
                            ),
                          );
                        }

                        final doc = _messages[index];
                        final msg = doc.data() as Map<String, dynamic>;
                        final messageId = doc.id;

                        // 🌟 날짜 변경 감지
                        bool showDateDivider = false;
                        if (index == _messages.length - 1) {
                          showDateDivider = true;
                        } else {
                          final prevMsg =
                              _messages[index + 1].data()
                                  as Map<String, dynamic>;
                          showDateDivider = !_isSameDay(
                            msg['timestamp'] as Timestamp?,
                            prevMsg['timestamp'] as Timestamp?,
                          );
                        }

                        // 🌟 프로필/이름 연속 표시 방지
                        bool isSameUserAsPrev = false;
                        if (!showDateDivider && index < _messages.length - 1) {
                          final prevMsg =
                              _messages[index + 1].data()
                                  as Map<String, dynamic>;
                          if (prevMsg['senderName'] == msg['senderName'] &&
                              prevMsg['isSystem'] != true) {
                            isSameUserAsPrev = true;
                          }
                        }

                        String dateText = _getDateDividerText(
                          msg['timestamp'] as Timestamp?,
                        );

                        return _buildMessageBubble(
                          msg,
                          isSameUserAsPrev,
                          messageId,
                          showDateDivider,
                          dateText,
                          index == _messages.length - 1, // isTopMessage
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
    bool isSameUserAsPrev,
    String messageId,
    bool showDateDivider,
    String dateText,
    bool isTopMessage,
  ) {
    bool isSystem = msg['isSystem'] == true;
    bool isMe = msg['senderName'] == widget.currentUser;

    return Column(
      children: [
        if (showDateDivider)
          Container(
            margin: EdgeInsets.only(top: isTopMessage ? 8 : 24, bottom: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: tossGrey,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              dateText,
              style: const TextStyle(
                color: slate600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        // 🌟 [핵심] 시스템 메시지 UI (가운데 회색 캡슐)
        if (isSystem)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: slate100.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              msg['text'] ?? '',
              style: const TextStyle(
                color: slate600,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        // 일반 대화 메시지 UI
        else
          GestureDetector(
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
                      child: const Text(
                        '취소',
                        style: TextStyle(color: slate600),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('삭제', style: TextStyle(color: red500)),
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
                      child: const Icon(
                        LucideIcons.user,
                        color: slate600,
                        size: 18,
                      ),
                    )
                  else if (!isMe && isSameUserAsPrev)
                    const SizedBox(width: 44),

                  if (isMe) _buildMessageMeta(msg),

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

                        if (msg['imageUrl'] != null &&
                            msg['imageUrl'].toString().isNotEmpty)
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
                              margin: EdgeInsets.only(
                                bottom:
                                    (msg['text'] != null &&
                                        msg['text'].toString().isNotEmpty)
                                    ? 4
                                    : 0,
                              ),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.6,
                                maxHeight: 250,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: msg['imageUrl'],
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    height: 150,
                                    width: 150,
                                    color: slate100,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: tossBlue,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        height: 150,
                                        width: 150,
                                        color: slate100,
                                        child: const Icon(
                                          LucideIcons.imageOff,
                                          color: slate600,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ),

                        if (msg['text'] != null &&
                            msg['text'].toString().isNotEmpty)
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
                                      : (isSameUserAsPrev &&
                                                msg['imageUrl'] == null
                                            ? 20
                                            : 4),
                                ),
                                bottomRight: Radius.circular(
                                  !isMe
                                      ? 20
                                      : (isSameUserAsPrev &&
                                                msg['imageUrl'] == null
                                            ? 20
                                            : 4),
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

                  if (!isMe) _buildMessageMeta(msg),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageMeta(Map<String, dynamic> msg) {
    int totalMembers = widget.isGroupChat ? _currentParticipants.length : 2;
    List readBy = msg['readBy'] ?? [msg['senderName']];
    int unreadCount = totalMembers - readBy.length;
    if (unreadCount < 0) unreadCount = 0;

    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6, bottom: 2),
      child: Column(
        crossAxisAlignment: msg['senderName'] == widget.currentUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
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

  // 🌟 [핵심] 단톡방 메뉴 바텀 시트
  void _showGroupChatMenu() {
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
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: tossGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(LucideIcons.edit2, color: slate900),
                  title: const Text(
                    "채팅방 이름 변경",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditGroupNameDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.userPlus, color: tossBlue),
                  title: const Text(
                    "대화상대 초대",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: tossBlue,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showInviteDialog();
                  },
                ),
                const Divider(color: slate100, height: 1),
                ListTile(
                  leading: const Icon(LucideIcons.logOut, color: red500),
                  title: const Text(
                    "채팅방 나가기",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: red500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _leaveGroupChat();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🌟 방 이름 변경 다이얼로그
  void _showEditGroupNameDialog() {
    TextEditingController nameCtrl = TextEditingController(
      text: _currentGroupTitle,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: pureWhite,
        title: const Text(
          '채팅방 이름 변경',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '새로운 방 이름 입력'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: slate600)),
          ),
          TextButton(
            onPressed: () async {
              String newTitle = nameCtrl.text.trim();
              if (newTitle.isNotEmpty && newTitle != _currentGroupTitle) {
                await FirebaseFirestore.instance
                    .collection('chat_rooms')
                    .doc(widget.roomId)
                    .update({'groupTitle': newTitle});
                await _sendSystemMessage(
                  "${widget.currentUser}님이 채팅방 이름을 '$newTitle'로 변경했습니다.",
                );
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('저장', style: TextStyle(color: tossBlue)),
          ),
        ],
      ),
    );
  }

  // 🌟 인원 초대 다이얼로그
  void _showInviteDialog() {
    // 현재 방에 없는 사람들만 필터링해서 보여주기
    List<Map<String, String>> availableUsers = mockUsers
        .where((user) => !_currentParticipants.contains(user['name']))
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: pureWhite,
        title: const Text(
          '대화상대 초대',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: availableUsers.isEmpty
              ? const Center(child: Text("초대할 사람이 없습니다."))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableUsers.length,
                  itemBuilder: (context, index) {
                    final user = availableUsers[index];
                    return ListTile(
                      leading: const Icon(LucideIcons.user, color: slate600),
                      title: Text(
                        user['name']!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        user['team']!,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await FirebaseFirestore.instance
                            .collection('chat_rooms')
                            .doc(widget.roomId)
                            .update({
                              'participants': FieldValue.arrayUnion([
                                user['name']!,
                              ]),
                            });
                        await _sendSystemMessage(
                          "${widget.currentUser}님이 ${user['name']}님을 초대했습니다.",
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  // 🌟 채팅방 나가기 처리 (나가기 전 시스템 메시지 뿌림)
  Future<void> _leaveGroupChat() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: pureWhite,
        title: const Text(
          '채팅방 나가기',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('나가기를 하면 대화 내용이 모두 삭제되며,\n채팅 목록에서도 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: slate600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('나가기', style: TextStyle(color: red500)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // 1. 나간다는 시스템 메시지 먼저 전송
      await _sendSystemMessage("${widget.currentUser}님이 나갔습니다.");
      // 2. participants 배열에서 내 이름 제거
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.roomId)
          .update({
            'participants': FieldValue.arrayRemove([widget.currentUser]),
          });
      // 3. 목록 화면으로 튕기기
      if (mounted) Navigator.pop(context);
    }
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
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator(color: tossBlue)),
            errorWidget: (context, url, error) => const Center(
              child: Icon(Icons.error, color: Colors.white, size: 40),
            ),
          ),
        ),
      ),
    );
  }
}
