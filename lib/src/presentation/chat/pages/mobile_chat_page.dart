import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileChatPage extends StatefulWidget {
  final String currentUser;
  final String roomName;

  const MobileChatPage({
    super.key,
    required this.currentUser,
    this.roomName = "현장 통합 채팅방",
  });

  @override
  State<MobileChatPage> createState() => _MobileChatPageState();
}

class _MobileChatPageState extends State<MobileChatPage> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<DocumentSnapshot> _messages = [];
  StreamSubscription<QuerySnapshot>? _realtimeSub;
  DocumentSnapshot? _lastDoc;
  bool _isFetching = false;
  bool _hasMore = true;
  static const int _perPage = 20;

  @override
  void initState() {
    super.initState();
    _initChatStream();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _messageCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetchMoreMessages();
    }
  }

  void _initChatStream() {
    Query query = FirebaseFirestore.instance
        .collection('global_chats')
        .orderBy('timestamp', descending: true)
        .limit(_perPage);

    _realtimeSub = query.snapshots().listen((snapshot) {
      if (!mounted) return;

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
          .collection('global_chats')
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
    if (_messageCtrl.text.trim().isEmpty) return;

    final String message = _messageCtrl.text.trim();
    _messageCtrl.clear();

    await FirebaseFirestore.instance.collection('global_chats').add({
      'sender': widget.currentUser,
      'text': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossGrey,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slate900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.roomName,
              style: const TextStyle(
                color: slate900,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const Text(
              "실시간 서버 연동 중 🟢",
              style: TextStyle(
                color: tossBlue,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty && _hasMore
                ? const Center(
                    child: CircularProgressIndicator(color: tossBlue),
                  )
                : _messages.isEmpty
                ? const Center(
                    child: Text(
                      "채팅 내역이 없습니다.",
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

                      final chat =
                          _messages[index].data() as Map<String, dynamic>;
                      final isMe = chat['sender'] == widget.currentUser;

                      return _buildChatBubble(
                        text: chat['text'] ?? '',
                        sender: chat['sender'] ?? '알 수 없음',
                        time: _formatTime(chat['timestamp'] as Timestamp?),
                        isMe: isMe,
                      );
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatBubble({
    required String text,
    required String sender,
    required String time,
    required bool isMe,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              backgroundColor: slate900,
              radius: 16,
              child: Text(
                sender.isNotEmpty ? sender[0] : '?',
                style: const TextStyle(
                  color: pureWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(
                      sender,
                      style: const TextStyle(
                        fontSize: 12,
                        color: slate600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? tossBlue : pureWhite,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isMe ? pureWhite : slate900,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(time, style: const TextStyle(fontSize: 10, color: slate600)),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: pureWhite,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: tossGrey,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageCtrl,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: "현장 상황을 전파하세요...",
                  hintStyle: TextStyle(color: slate600),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _sendMessage();
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: tossBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: pureWhite, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
