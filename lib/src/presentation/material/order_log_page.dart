import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

// 🚀 프로젝트 경로에 맞게 수정해주세요!
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);
const Color makitaTeal = Color(0xFF007580);

class OrderLogPage extends StatefulWidget {
  const OrderLogPage({super.key});

  @override
  State<OrderLogPage> createState() => _OrderLogPageState();
}

class _OrderLogPageState extends State<OrderLogPage> {
  final OrderRepository _repo = OrderRepository();
  String _filterStatus = "전체보기"; // 전체, 완료, 반려, 진행중 등 필터용

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
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildLogList()),
        ],
      ),
    );
  }

  // 🚀 상단 상태 필터 칩
  Widget _buildFilterChips() {
    final List<String> filters = ["전체보기", "처리 완료", "반려됨", "진행중"];

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

  // 🚀 전체 로그 리스트 렌더링 (파이어베이스 실시간 스트림)
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

        // 1. 데이터 가져오기
        List<OrderModel> logs = snapshot.data!;

        // 2. 필터 적용
        if (_filterStatus != "전체보기") {
          logs = logs.where((log) => log.status == _filterStatus).toList();
        }

        // 3. 최신순 정렬 (요청일 기준 내림차순)
        logs.sort((a, b) => b.requestDate.compareTo(a.requestDate));

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
          itemBuilder: (context, index) {
            return _buildCompactLogCard(logs[index]);
          },
        );
      },
    );
  }

  // 🚀 콤팩트한 로그 카드 디자인
  Widget _buildCompactLogCard(OrderModel log) {
    Color statusColor = _getStatusColor(log.status);
    String mainTitle = log.items.first.title;
    if (log.items.length > 1) {
      mainTitle += " 외 ${log.items.length - 1}건";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
        // 🔥 에러 해결: withOpacity 대신 withValues 사용
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${log.requestDate.year}.${log.requestDate.month.toString().padLeft(2, '0')}.${log.requestDate.day.toString().padLeft(2, '0')}",
                style: const TextStyle(
                  color: slate600,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  // 🔥 에러 해결: withOpacity 대신 withValues 사용
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
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "처리 완료":
        return Colors.grey.shade600;
      case "반려됨":
        return warningRed;
      case "진행중":
        return makitaTeal;
      case "발주 확인":
        return tossBlue;
      default:
        return Colors.orange;
    }
  }
}
