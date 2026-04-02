import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';

// 🚀 프로젝트 경로에 맞게 임포트 확인해주세요!
import '../../data/models/cart_item_model.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color makitaTeal = Color(0xFF007580);
const Color warningRed = Color(0xFFF04438);

class MaterialOrderPage extends StatefulWidget {
  final bool isAdmin;
  final String currentUser;

  const MaterialOrderPage({
    super.key,
    this.isAdmin = true,
    this.currentUser = "김반장",
  });

  @override
  State<MaterialOrderPage> createState() => _MaterialOrderPageState();
}

class _MaterialOrderPageState extends State<MaterialOrderPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrderRepository _repo = OrderRepository();

  final List<CartItemModel> _cartItems = [];

  DateTime? _selectedDate;
  String? _selectedManager;
  String _processingType = "일반 자재";

  final TextEditingController _itemCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _fabSpecCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  List<String> _attachedPhotos = [];
  final List<String> _managers = ["김반장", "이소장", "박주임", "최공무"];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _itemCtrl.dispose();
    _qtyCtrl.dispose();
    _fabSpecCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "발주 대기":
        return Colors.orange;
      case "발주 확인":
        return tossBlue;
      case "진행중":
        return makitaTeal;
      case "반려됨":
        return warningRed;
      case "처리 완료":
        return Colors.grey;
      default:
        return slate600;
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Map<String, dynamic>? _calculateDDay(DateTime? expectedDate) {
    if (expectedDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      expectedDate.year,
      expectedDate.month,
      expectedDate.day,
    );
    final diff = target.difference(today).inDays;

    if (diff == 0)
      return {"text": "D-Day", "color": warningRed, "isUrgent": true};
    if (diff > 0)
      return {"text": "D-$diff", "color": tossBlue, "isUrgent": false};
    return {
      "text": "D+${diff.abs()} (지연)",
      "color": warningRed,
      "isUrgent": true,
    };
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
        title: const Text(
          "자재 발주",
          style: TextStyle(
            color: slate900,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: tossBlue,
          indicatorWeight: 3,
          labelColor: tossBlue,
          unselectedLabelColor: slate600,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          tabs: const [
            Tab(text: "신규 발주"),
            Tab(text: "발주 진행 현황"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildRequestTab(), _buildStatusTab()],
      ),
    );
  }

  // ==========================================
  // 1. 신규 발주 요청 탭
  // ==========================================
  Widget _buildRequestTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.packagePlus, color: tossBlue),
                    SizedBox(width: 8),
                    Text(
                      "발주할 품목 추가",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: slate900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSimpleInput("자재명", "예: 3/8 SUS 튜브", _itemCtrl),
                _buildSimpleInput("수량", "예: 50 (ea/m)", _qtyCtrl),
                _buildProcessingOptions(),
                _buildPhotoAttachment(),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _addToCart();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tossBlue,
                      side: const BorderSide(color: tossBlue, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "목록에 담기",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          if (_cartItems.isNotEmpty) ...[
            Text(
              "담긴 품목 (${_cartItems.length}건)",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: slate900,
              ),
            ),
            const SizedBox(height: 12),
            ..._cartItems.asMap().entries.map((entry) {
              int idx = entry.key;
              CartItemModel item = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: slate900,
                                ),
                              ),
                              if (item.photos != null &&
                                  item.photos!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  LucideIcons.image,
                                  size: 14,
                                  color: tossBlue,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "수량: ${item.qty} | ${item.type}",
                            style: const TextStyle(
                              color: slate600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: warningRed,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() => _cartItems.removeAt(idx));
                      },
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 32),
          ],

          const Text(
            "전체 발주 정보",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: slate900,
            ),
          ),
          const SizedBox(height: 16),
          _buildManagerSelector(),
          _buildDateSelector(),
          _buildSimpleInput("전체 요청사항 (선택)", "예: A동 3층 현장 도착 요망", _noteCtrl),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _submitOrder();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _cartItems.isEmpty ? slate600 : tossBlue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _cartItems.isEmpty
                    ? "품목을 먼저 담아주세요"
                    : "${_cartItems.length}건 발주 요청하기",
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: pureWhite,
                ),
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  void _addToCart() {
    if (_itemCtrl.text.trim().isEmpty || _qtyCtrl.text.trim().isEmpty) {
      _showSnackBar("자재명과 수량을 입력해주세요.", isError: true);
      return;
    }
    setState(() {
      _cartItems.add(
        CartItemModel(
          title: _itemCtrl.text.trim(),
          qty: _qtyCtrl.text.trim(),
          type: _processingType,
          fabSpec: _processingType != "일반 자재" ? _fabSpecCtrl.text : null,
          photos: List.from(_attachedPhotos),
        ),
      );
      _itemCtrl.clear();
      _qtyCtrl.clear();
      _fabSpecCtrl.clear();
      _processingType = "일반 자재";
      _attachedPhotos.clear();
    });
    _showSnackBar("품목이 담겼습니다.");
  }

  Widget _buildSimpleInput(
    String label,
    String hint,
    TextEditingController ctrl,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: slate600,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          TextField(
            controller: ctrl,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: slate900,
            ),
            cursorColor: tossBlue,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Colors.black26,
                fontWeight: FontWeight.w400,
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.black12),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: tossBlue, width: 2),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagerSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "발주 수신자 (담당자 지정)",
            style: TextStyle(
              color: slate600,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _showManagerBottomSheet();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedManager ?? "담당자를 선택해주세요",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: _selectedManager == null
                          ? FontWeight.w400
                          : FontWeight.w600,
                      color: _selectedManager == null
                          ? Colors.black26
                          : slate900,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _selectedManager == null ? Colors.black26 : tossBlue,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManagerBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: const BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "담당자 지정",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: slate900,
              ),
            ),
            const SizedBox(height: 16),
            ..._managers.map(
              (manager) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  manager,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: slate900,
                  ),
                ),
                trailing: _selectedManager == manager
                    ? const Icon(Icons.check_circle, color: tossBlue)
                    : null,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedManager = manager);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    String dateText = _selectedDate == null
        ? "납기 희망일을 선택해주세요"
        : "${_selectedDate!.year}년 ${_selectedDate!.month}월 ${_selectedDate!.day}일";
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "납기 희망 일정",
            style: TextStyle(
              color: slate600,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              HapticFeedback.lightImpact();
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: _selectedDate == null
                          ? FontWeight.w400
                          : FontWeight.w600,
                      color: _selectedDate == null ? Colors.black26 : slate900,
                    ),
                  ),
                  Icon(
                    Icons.calendar_month_rounded,
                    color: _selectedDate == null ? Colors.black26 : tossBlue,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingOptions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "가공 여부",
            style: TextStyle(
              color: slate600,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTypeChip("일반 자재"),
              const SizedBox(width: 8),
              _buildTypeChip("브라켓 제작"),
              const SizedBox(width: 8),
              _buildTypeChip("레이저 가공"),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _processingType != "일반 자재"
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextField(
                      controller: _fabSpecCtrl,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: slate900,
                      ),
                      cursorColor: makitaTeal,
                      decoration: InputDecoration(
                        hintText:
                            "가공 치수, 홀 타공 사이즈 등을 적어주세요.\n(예: 100x100, 10파이 2홀)",
                        hintStyle: const TextStyle(
                          color: Colors.black26,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: makitaTeal.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: makitaTeal,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label) {
    bool isSelected = _processingType == label;
    bool isSpecial = label != "일반 자재";
    Color activeColor = isSpecial ? makitaTeal : tossBlue;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _processingType = label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.1) : pureWhite,
            border: Border.all(
              color: isSelected ? activeColor : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? activeColor : slate600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoAttachment() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "사진 및 도면 첨부",
                style: TextStyle(
                  color: slate600,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                "${_attachedPhotos.length}/3",
                style: const TextStyle(color: slate600, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (_attachedPhotos.length < 3) {
                      _showImageSourceDialog();
                    } else {
                      _showSnackBar("사진은 최대 3장까지 첨부 가능합니다.", isError: true);
                    }
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: slate100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.black12,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.camera, color: slate600, size: 24),
                        SizedBox(height: 4),
                        Text(
                          "추가",
                          style: TextStyle(
                            color: slate600,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ..._attachedPhotos.asMap().entries.map((entry) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: slate600.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: FileImage(File(entry.value)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: -6,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _attachedPhotos.removeAt(entry.key));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: slate900,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: pureWhite,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera, color: tossBlue),
              title: const Text(
                "카메라로 촬영",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const Divider(color: Colors.black12),
            ListTile(
              leading: const Icon(LucideIcons.image, color: tossBlue),
              title: const Text(
                "갤러리에서 선택",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() => _attachedPhotos.add(image.path));
      }
    } catch (e) {
      _showSnackBar("사진을 가져오는 중 오류가 발생했습니다.", isError: true);
    }
  }

  // ==========================================
  // 2. 발주 진행 현황 탭
  // ==========================================
  Widget _buildStatusTab() {
    return StreamBuilder<List<OrderModel>>(
      stream: _repo.streamOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: tossBlue),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "데이터를 불러오지 못했습니다.\n${snapshot.error}",
              style: const TextStyle(color: warningRed),
            ),
          );
        }

        final orders = snapshot.data ?? [];

        List<OrderModel> displayOrders = orders.where((order) {
          if (widget.isAdmin) return order.assignee == widget.currentUser;
          return order.requester == widget.currentUser;
        }).toList();

        if (displayOrders.isEmpty) {
          return const Center(
            child: Text(
              "표시할 발주 내역이 없습니다.",
              style: TextStyle(color: slate600, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: displayOrders.length,
          itemBuilder: (context, index) {
            final order = displayOrders[index];
            return _buildStatusCard(order);
          },
        );
      },
    );
  }

  Widget _buildStatusCard(OrderModel order) {
    String mainTitle = order.items.first.title;
    if (order.items.length > 1) {
      mainTitle += " 외 ${order.items.length - 1}건";
    }

    bool isSpecial = order.items.any((item) => item.type != "일반 자재");
    bool hasAnyPhoto = order.items.any(
      (item) => item.photos != null && item.photos!.isNotEmpty,
    );

    Map<String, dynamic>? dDayInfo = _calculateDDay(order.expectedDate);
    bool isUrgent = dDayInfo?['isUrgent'] ?? false;
    bool isCompleted = order.status == "처리 완료";
    bool isRejected = order.status == "반려됨";
    Color statusColor = _getStatusColor(order.status);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showOrderDetails(order);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.circular(20),
          border: isSpecial
              ? Border.all(color: makitaTeal.withValues(alpha: 0.3), width: 1)
              : Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                mainTitle,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: slate900,
                                  letterSpacing: -0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasAnyPhoto) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                LucideIcons.image,
                                size: 16,
                                color: tossBlue,
                              ),
                            ],
                            if (dDayInfo != null &&
                                !isCompleted &&
                                !isRejected) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: dDayInfo['color'],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  dDayInfo['text'],
                                  style: const TextStyle(
                                    color: pureWhite,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        isSpecial
                            ? Icons.precision_manufacturing
                            : Icons.inventory_2_outlined,
                        size: 16,
                        color: slate600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "총 ${order.items.length}품목",
                        style: const TextStyle(
                          color: slate600,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.person_outline,
                        size: 16,
                        color: slate600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.isAdmin
                            ? "요청: ${order.requester}"
                            : "담당: ${order.assignee}",
                        style: const TextStyle(
                          color: slate600,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 16,
                        color: slate600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.expectedDate != null
                            ? "입고 예정: ${_formatDate(order.expectedDate!)}"
                            : "희망일: ${_formatDate(order.requestDate)}",
                        style: TextStyle(
                          color: order.expectedDate != null
                              ? slate900
                              : slate600,
                          fontSize: 13,
                          fontWeight: order.expectedDate != null
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isUrgent && !isCompleted && !isRejected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: warningRed.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.alertCircle,
                      size: 16,
                      color: warningRed,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dDayInfo!['text'] == "D-Day"
                          ? "오늘 입고 예정입니다. 수령 상태를 확인해주세요!"
                          : "입고가 지연되고 있습니다. 관리자 확인 요망!",
                      style: const TextStyle(
                        color: warningRed,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            if (isRejected && order.rejectReason != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: warningRed.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.block, size: 16, color: warningRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "반려 사유: ${order.rejectReason}",
                        style: const TextStyle(
                          color: warningRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  void _showOrderDetails(OrderModel order) {
    DateTime? tempExpectedDate = order.expectedDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          bool isWaiting = order.status == "발주 대기";
          bool isRejected = order.status == "반려됨";
          Color statusColor = _getStatusColor(order.status);

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            decoration: const BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
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
                            Text(
                              "요청: ${order.requester} -> 담당: ${order.assignee}",
                              style: const TextStyle(
                                color: slate600,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              order.status,
                              style: TextStyle(
                                color: (order.status == "처리 완료" || isRejected)
                                    ? slate600
                                    : statusColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "요청 품목 총 ${order.items.length}건",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: slate900,
                            letterSpacing: -0.5,
                          ),
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
                                        fontSize: 14,
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
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        ...order.items.map((item) {
                          return Container(
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
                                  _buildDetailRow("상세 스펙", item.fabSpec!),

                                if (item.photos != null &&
                                    item.photos!.isNotEmpty) ...[
                                  _buildDetailRow(
                                    "첨부파일",
                                    "${item.photos!.length}장 (아래 확인)",
                                  ),
                                  const SizedBox(height: 8),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: item.photos!.map((url) {
                                        bool isNetwork = url.startsWith('http');
                                        return Container(
                                          width: 120,
                                          height: 120,
                                          margin: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: slate100,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.black12,
                                            ),
                                            image: isNetwork
                                                ? DecorationImage(
                                                    image: NetworkImage(url),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          // 🚀 [에러 수정 완료] 플러터 기본 아이콘으로 교체!
                                          child: !isNetwork
                                              ? const Icon(
                                                  Icons
                                                      .image_not_supported_rounded,
                                                  color: slate600,
                                                  size: 32,
                                                )
                                              : null,
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),

                        const Divider(height: 32, color: Colors.black12),
                        _buildDetailRow(
                          "작업자 희망일",
                          _formatDate(order.requestDate),
                        ),
                        if (tempExpectedDate != null)
                          _buildDetailRow(
                            "확정 입고 예정",
                            _formatDate(tempExpectedDate!),
                            isHighlight: true,
                          ),

                        const SizedBox(height: 16),
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
                          style: const TextStyle(
                            color: slate900,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 32),

                        if (widget.isAdmin && isWaiting) ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: tossBlue.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: tossBlue.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      LucideIcons.calendarCheck,
                                      size: 20,
                                      color: tossBlue,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      "입고 예정일 지정 (확인용)",
                                      style: TextStyle(
                                        color: tossBlue,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                InkWell(
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 180),
                                      ),
                                    );
                                    if (picked != null)
                                      setModalState(
                                        () => tempExpectedDate = picked,
                                      );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: pureWhite,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: tossBlue.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          tempExpectedDate == null
                                              ? "달력을 눌러 날짜 선택"
                                              : _formatDate(tempExpectedDate!),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: tempExpectedDate == null
                                                ? FontWeight.w500
                                                : FontWeight.w700,
                                            color: tempExpectedDate == null
                                                ? slate600
                                                : slate900,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.calendar_month_rounded,
                                          color: tossBlue,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ],
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.only(top: 16, bottom: 32),
                  decoration: const BoxDecoration(
                    color: pureWhite,
                    border: Border(top: BorderSide(color: Colors.black12)),
                  ),
                  child: widget.isAdmin && !isRejected
                      ? _buildAdminActionButtons(order, tempExpectedDate)
                      : SizedBox(
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
      ),
    );
  }

  void _showRejectDialog(OrderModel order) {
    final TextEditingController reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.block, color: warningRed),
            SizedBox(width: 8),
            Text(
              "발주 반려",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: slate900,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "작업자에게 전달할 반려 사유를 적어주세요.",
              style: TextStyle(color: slate600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              cursorColor: warningRed,
              decoration: InputDecoration(
                filled: true,
                fillColor: tossGrey,
                hintText: "예: B동 창고에 재고 있습니다.",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: warningRed, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "취소",
              style: TextStyle(color: slate600, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) {
                _showSnackBar("반려 사유를 입력해주세요.", isError: true);
                return;
              }
              Navigator.pop(context);
              Navigator.pop(context);

              final updatedOrder = order.copyWith(
                status: "반려됨",
                rejectReason: reasonCtrl.text.trim(),
              );
              await _repo.updateOrder(updatedOrder);
              _showSnackBar("발주가 반려 처리되었습니다.", isError: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: warningRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "반려 확정",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActionButtons(
    OrderModel order,
    DateTime? tempExpectedDate,
  ) {
    String currentStatus = order.status;
    if (currentStatus == "처리 완료") return const SizedBox.shrink();

    String actionText = "";
    Color btnColor = tossBlue;
    bool isApproveEnabled = true;

    if (currentStatus == "발주 대기") {
      actionText = "확인 및 발주 진행";
      btnColor = tossBlue;
      isApproveEnabled = tempExpectedDate != null;
    } else if (currentStatus == "발주 확인") {
      actionText = "배송/제작 진행중 처리";
      btnColor = makitaTeal;
    } else if (currentStatus == "진행중") {
      actionText = "현장 수령 및 처리 완료";
      btnColor = Colors.green;
    }

    return Row(
      children: [
        if (currentStatus == "발주 대기") ...[
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showRejectDialog(order);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: warningRed,
                  side: const BorderSide(color: Colors.black12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "반려",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: !isApproveEnabled
                  ? null
                  : () async {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);

                      OrderModel updatedOrder = order;
                      if (currentStatus == "발주 대기") {
                        updatedOrder = order.copyWith(
                          expectedDate: tempExpectedDate,
                          status: "발주 확인",
                        );
                        _showSnackBar("발주 내용 확인 및 입고 예정일이 지정되었습니다.");
                      } else if (currentStatus == "발주 확인") {
                        updatedOrder = order.copyWith(status: "진행중");
                        _showSnackBar("상태가 [진행중]으로 변경되었습니다.");
                      } else if (currentStatus == "진행중") {
                        updatedOrder = order.copyWith(status: "처리 완료");
                        _showSnackBar("현장 수령 및 발주 처리가 완료되었습니다.");
                      }

                      await _repo.updateOrder(updatedOrder);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                disabledBackgroundColor: slate100,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                actionText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isApproveEnabled ? pureWhite : slate600,
                ),
              ),
            ),
          ),
        ),
      ],
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
              style: const TextStyle(
                color: slate600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
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

  void _submitOrder() async {
    if (_cartItems.isEmpty) {
      _showSnackBar("먼저 품목을 장바구니에 담아주세요.", isError: true);
      return;
    }
    if (_selectedManager == null) {
      _showSnackBar("발주를 수신할 담당자를 선택해주세요.", isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: tossBlue)),
    );

    try {
      List<CartItemModel> updatedCartItems = [];

      for (var item in _cartItems) {
        List<String> uploadedPhotoUrls = [];
        if (item.photos != null) {
          for (String localPath in item.photos!) {
            String downloadUrl = await _repo.uploadImage(localPath);
            uploadedPhotoUrls.add(downloadUrl);
          }
        }

        updatedCartItems.add(
          CartItemModel(
            title: item.title,
            qty: item.qty,
            type: item.type,
            fabSpec: item.fabSpec,
            photos: uploadedPhotoUrls,
          ),
        );
      }

      final newOrder = OrderModel(
        id: '',
        requester: widget.currentUser,
        assignee: _selectedManager!,
        items: updatedCartItems,
        status: "발주 대기",
        requestDate: _selectedDate ?? DateTime.now(),
        note: _noteCtrl.text.isNotEmpty ? _noteCtrl.text : null,
      );

      await _repo.addOrder(newOrder);

      if (mounted) {
        Navigator.pop(context);
        _showSnackBar(
          "총 ${_cartItems.length}건의 발주 알림이 $_selectedManager 담당자에게 전송되었습니다.",
        );

        setState(() {
          _cartItems.clear();
          _selectedDate = null;
          _selectedManager = null;
          _noteCtrl.clear();
        });
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar("발주 전송 중 오류가 발생했습니다.", isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : LucideIcons.bellRing,
              color: pureWhite,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? warningRed : slate900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      ),
    );
  }
}
