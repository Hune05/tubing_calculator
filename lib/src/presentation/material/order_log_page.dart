import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

// 🚀 프로젝트 경로에 맞게 수정해주세요!
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);
const Color makitaTeal = Color(0xFF007580);

class OrderLogPage extends StatefulWidget {
  final bool isAdmin;
  final String currentUser;

  const OrderLogPage({
    super.key,
    this.isAdmin = true,
    this.currentUser = "김반장",
  });

  @override
  State<OrderLogPage> createState() => _OrderLogPageState();
}

class _OrderLogPageState extends State<OrderLogPage> {
  final OrderRepository _repo = OrderRepository();
  String _filterStatus = "전체보기";
  List<OrderModel> _currentFilteredLogs = [];

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
        title: const Text(
          "발주 히스토리 (로그)",
          style: TextStyle(
            color: slate900,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _exportAllToCSV,
            icon: const Icon(LucideIcons.download, color: tossBlue, size: 18),
            label: const Text(
              "엑셀 추출",
              style: TextStyle(color: tossBlue, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildLogList()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final List<String> filters = ["전체보기", "처리 완료", "반려됨", "진행중", "발주 대기"];
    return Container(
      color: pureWhite,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: filters.map((status) {
            bool isSelected = _filterStatus == status;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  status,
                  style: TextStyle(
                    color: isSelected ? pureWhite : slate600,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                selected: isSelected,
                selectedColor: slate900,
                backgroundColor: tossGrey,
                showCheckmark: false,
                onSelected: (selected) {
                  HapticFeedback.lightImpact();
                  setState(() => _filterStatus = status);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLogList() {
    return StreamBuilder<List<OrderModel>>(
      stream: _repo.streamOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: tossBlue),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text("기록된 발주 내역이 없습니다.", style: TextStyle(color: slate600)),
          );
        }

        List<OrderModel> logs = snapshot.data!;
        if (!widget.isAdmin) {
          logs = logs
              .where(
                (log) =>
                    log.requester == widget.currentUser ||
                    log.assignee == widget.currentUser,
              )
              .toList();
        }

        if (_filterStatus != "전체보기") {
          logs = logs.where((log) => log.status == _filterStatus).toList();
        }

        logs.sort((a, b) => b.requestDate.compareTo(a.requestDate));

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _currentFilteredLogs = logs;
        });

        if (logs.isEmpty) {
          return Center(
            child: Text(
              "'$_filterStatus' 상태인 내역이 없습니다.",
              style: const TextStyle(color: slate600),
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: logs.length,
          itemBuilder: (context, index) => _buildCompactLogCard(logs[index]),
        );
      },
    );
  }

  Widget _buildCompactLogCard(OrderModel log) {
    Color statusColor = _getStatusColor(log.status);
    String mainTitle = log.items.first.title;
    if (log.items.length > 1) mainTitle += " 외 ${log.items.length - 1}건";

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showOrderDetails(log);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(log.requestDate),
                  style: const TextStyle(
                    color: slate600,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    log.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              mainTitle,
              style: const TextStyle(
                color: slate900,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(LucideIcons.user, size: 14, color: slate600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "요청: ${log.requester} / 담당: ${log.assignee}",
                    style: const TextStyle(color: slate600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 상세 보기 바텀 시트 (채팅/전화 버튼 제거됨)
  void _showOrderDetails(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isRejected = order.status == "반려됨";
        bool isCompleted = order.status == "처리 완료";
        Color statusColor = _getStatusColor(order.status);

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          decoration: const BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "요청: ${order.requester} -> 담당: ${order.assignee}",
                              style: const TextStyle(
                                color: slate600,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _exportOrderData(order),
                                icon: const Icon(
                                  LucideIcons.copy,
                                  color: slate600,
                                  size: 22,
                                ),
                              ),
                              if (widget.isAdmin)
                                IconButton(
                                  onPressed: () => _deleteOrderConfirm(order),
                                  icon: const Icon(
                                    LucideIcons.trash2,
                                    color: warningRed,
                                    size: 22,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "요청 품목 총 ${order.items.length}건",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: slate900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: (isCompleted || isRejected)
                                  ? Colors.grey.shade200
                                  : statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              order.status,
                              style: TextStyle(
                                color: (isCompleted || isRejected)
                                    ? slate600
                                    : statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (isRejected && order.rejectReason != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: warningRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.block,
                                    color: warningRed,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "관리자 반려 사유",
                                    style: TextStyle(
                                      color: warningRed,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                order.rejectReason!,
                                style: const TextStyle(
                                  color: slate900,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // 💡 기존의 _buildContactPartnerCard(채팅/전화)가 삭제되었습니다.
                      ...order.items.map(
                        (item) => Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: slate100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: slate900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow("수량", item.qty),
                              _buildDetailRow(
                                "가공 타입",
                                item.type,
                                isHighlight: item.type != "일반 자재",
                              ),
                              if (item.fabSpec != null)
                                _buildDetailRow("상세/링크", item.fabSpec!),
                              if (item.photos != null &&
                                  item.photos!.isNotEmpty) ...[
                                _buildDetailRow(
                                  "첨부파일",
                                  "${item.photos!.length}장",
                                ),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: item.photos!
                                        .map(
                                          (url) => Container(
                                            width: 100,
                                            height: 100,
                                            margin: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.black12,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: CachedNetworkImage(
                                                imageUrl: url,
                                                fit: BoxFit.cover,
                                                errorWidget:
                                                    (context, url, error) =>
                                                        const Icon(Icons.error),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 32),
                      _buildDetailRow(
                        "작업자 희망일",
                        _formatDate(order.requestDate),
                      ),
                      if (order.expectedDate != null)
                        _buildDetailRow(
                          "확정 입고 예정",
                          _formatDate(order.expectedDate!),
                          isHighlight: true,
                        ),
                      const Text(
                        "전체 요청사항",
                        style: TextStyle(
                          color: slate600,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        order.note ?? "없음",
                        style: const TextStyle(color: slate900, fontSize: 15),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: slate100,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "닫기",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: slate900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: slate600, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: isHighlight ? tossBlue : slate900,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 엑셀 추출 기능 (CSV 복사)
  Future<void> _exportAllToCSV() async {
    HapticFeedback.lightImpact();
    if (_currentFilteredLogs.isEmpty) {
      _showSnackBar("데이터가 없습니다.", isError: true);
      return;
    }
    StringBuffer csv = StringBuffer();
    csv.writeln("요청일자,상태,요청자,담당자,품목,수량,비고");
    for (var log in _currentFilteredLogs) {
      csv.writeln(
        "${_formatDate(log.requestDate)},${log.status},${log.requester},${log.assignee},${log.items.first.title},${log.items.length},${(log.note ?? "").replaceAll(',', ' ')}",
      );
    }
    await Clipboard.setData(ClipboardData(text: csv.toString()));
    if (!mounted) return;
    _showSnackBar("✅ 목록이 복사되었습니다! 엑셀에 붙여넣기 하세요.");
  }

  Future<void> _exportOrderData(OrderModel order) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    StringBuffer buffer = StringBuffer();
    buffer.writeln(
      "📦 [발주 요약]\n요청자: ${order.requester}\n상태: ${order.status}\n일자: ${_formatDate(order.requestDate)}",
    );
    buffer.writeln("\n💬 [채팅 기록]");
    try {
      var chat = await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc("order_${order.id}")
          .collection('messages')
          .orderBy('timestamp')
          .get();
      for (var doc in chat.docs) {
        var d = doc.data();
        buffer.writeln(
          "[${_formatTime(d['timestamp'] as Timestamp?)}] ${d['senderName'] ?? '알림'}: ${d['text']}",
        );
      }
    } catch (e) {
      buffer.writeln("채팅 기록 없음");
    }
    if (!mounted) return;
    Navigator.pop(context);
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    _showSnackBar("내역이 클립보드에 복사되었습니다.");
  }

  Future<void> _deleteOrderConfirm(OrderModel order) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('발주 삭제'),
        content: const Text('기록을 영구히 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .delete();
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar("삭제되었습니다.");
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "처리 완료":
        return Colors.grey.shade600;
      case "반려됨":
        return warningRed;
      case "진행중":
        return makitaTeal;
      default:
        return Colors.orange;
    }
  }

  String _formatDate(DateTime date) =>
      "${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}";

  String _formatTime(Timestamp? t) {
    if (t == null) return '';
    final d = t.toDate();
    return "${d.hour}:${d.minute.toString().padLeft(2, '0')}";
  }

  void _showSnackBar(String m, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: isError ? warningRed : slate900,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
