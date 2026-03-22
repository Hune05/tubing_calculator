part of 'inventory_page.dart';

// 상태 확장 시 발생하는 setState 경고 무시
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: library_private_types_in_public_api

extension InventoryTabsExt on _InventoryPageState {
  Widget _buildMainInventoryTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: pureWhite,
            border: Border(bottom: BorderSide(color: slate200)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSimpleDropdown(
                      "카테고리",
                      _selectedFilterCategory,
                      _categories,
                      (v) {
                        setState(() {
                          _selectedFilterCategory = v!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSimpleDropdown(
                      "제조사",
                      _selectedFilterMaker,
                      _makers,
                      (v) {
                        setState(() {
                          _selectedFilterMaker = v!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatusChip("가용 자재 목록", _stockFilterStatus == 0, () {
                    setState(() {
                      _stockFilterStatus = 0;
                      _selectedDocId = null;
                    });
                  }),
                  const SizedBox(width: 6),
                  _buildStatusChip("장기 보관 자재", _stockFilterStatus == 1, () {
                    setState(() {
                      _stockFilterStatus = 1;
                      _selectedDocId = null;
                    });
                  }),
                  const SizedBox(width: 6),
                  _buildStatusChip("발주 요청 목록", _stockFilterStatus == 2, () {
                    setState(() {
                      _stockFilterStatus = 2;
                      _selectedDocId = null;
                    });
                  }),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _inventoryDb
                .orderBy('createdAt', descending: true)
                .limit(300)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: makitaTeal),
                );
              }

              final docs = snapshot.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                bool catMatch =
                    _selectedFilterCategory == "ALL" ||
                    data['category'] == _selectedFilterCategory;
                bool makerMatch =
                    _selectedFilterMaker == "ALL" ||
                    data['maker'] == _selectedFilterMaker;
                bool isDead = data['is_dead_stock'] == true;
                bool isReorder = data['is_reorder_needed'] == true;

                bool statusMatch = false;
                if (_stockFilterStatus == 0) {
                  statusMatch = !isDead && !isReorder;
                } else if (_stockFilterStatus == 1) {
                  statusMatch = isDead;
                } else if (_stockFilterStatus == 2) {
                  statusMatch = !isDead && isReorder;
                }

                return catMatch &&
                    makerMatch &&
                    statusMatch &&
                    data['name'].toString().toLowerCase().contains(
                      _searchQuery,
                    );
              }).toList();

              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    "조건에 맞는 자재가 없습니다.",
                    style: TextStyle(
                      color: slate600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ).copyWith(bottom: 20),
                itemCount: docs.length,
                separatorBuilder: (context, index) {
                  return const SizedBox(height: 6);
                },
                itemBuilder: (context, idx) {
                  return _buildMaterialCard(
                    docs[idx].id,
                    docs[idx].data() as Map<String, dynamic>,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuRow(
    String value,
    String text, {
    Color color = slate800,
  }) {
    return PopupMenuItem(
      value: value,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildMaterialCard(String id, Map<String, dynamic> item) {
    String status = item['status'] ?? "정상";
    Color statusColor = slate600;

    if (status == "장기 보관") {
      statusColor = Colors.green.shade700;
    } else if (status == "악성 재고") {
      statusColor = Colors.red.shade600;
    }

    bool isDead = item['is_dead_stock'] ?? false;
    bool isReorder = item['is_reorder_needed'] ?? false;
    String heatNo = item['heatNo'] ?? "";
    String location = item['location'] ?? "";
    int currentQty = item['qty'] ?? 0;
    int minQty = item['min_qty'] ?? 10;

    bool isLowStock = !isDead && (currentQty <= minQty);
    bool isSelected = _selectedDocId == id;

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDocId = null;
            _selectedItemData = null;
          } else {
            _selectedDocId = id;
            _selectedItemData = item;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? makitaTeal.withValues(alpha: 0.05)
              : (isDead ? slate50 : pureWhite),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? makitaTeal
                : (isLowStock ? Colors.redAccent : slate300),
            width: isSelected || isLowStock ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  item['category'] ?? "기타",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: makitaTeal,
                  ),
                ),
                if (isDead) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: pureWhite,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (!isDead && isReorder) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "발주 요청됨",
                      style: TextStyle(
                        color: pureWhite,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (isLowStock && !isReorder) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          LucideIcons.alertTriangle,
                          size: 10,
                          color: Colors.red,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "재고 부족",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    item['name'],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: slate900,
                      height: 1.2,
                    ),
                  ),
                ),
                Text(
                  "$currentQty",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDead
                        ? statusColor
                        : (isLowStock ? Colors.red : makitaTeal),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "${item['unit']}",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDead ? slate400 : slate600,
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 28,
                  width: 28,
                  child: PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 24,
                      color: slate600,
                    ),
                    padding: EdgeInsets.zero,
                    color: pureWhite,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onSelected: (v) {
                      if (v == 'audit') {
                        _showAdjustmentDialog(docId: id, item: item);
                      } else if (v == 'reorder') {
                        _toggleReorderStatus(id, isReorder);
                      } else if (v == 'keep') {
                        _updateItemStatus(id, "장기 보관");
                      } else if (v == 'bad_stock') {
                        _updateItemStatus(id, "악성 재고");
                      } else if (v == 'normal') {
                        _updateItemStatus(id, "정상");
                        _inventoryDb.doc(id).update({
                          'is_reorder_needed': false,
                        });
                      } else if (v == 'delete') {
                        _showDeleteConfirmDialog(docId: id);
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (!isDead)
                        _buildMenuRow('reorder', isReorder ? "발주 완료" : "발주 요청"),
                      if (!isDead || (isDead && status != '장기 보관'))
                        _buildMenuRow('keep', "장기 보관"),
                      if (isDead && status != '악성 재고')
                        _buildMenuRow(
                          'bad_stock',
                          "악성 재고 처리",
                          color: Colors.orange.shade800,
                        ),
                      if (isDead) _buildMenuRow('normal', "정상 재고 복구"),
                      if (_isAdmin) ...[
                        const PopupMenuDivider(),
                        _buildMenuRow('audit', "재고 임의 수정"),
                        _buildMenuRow(
                          'delete',
                          "마스터 삭제",
                          color: Colors.red.shade700,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (location.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: slate100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: slate300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 12,
                          color: slate600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          location,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: slate700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (heatNo.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: slate100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: slate300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tag, size: 12, color: slate600),
                        const SizedBox(width: 4),
                        Text(
                          "Heat: $heatNo",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: slate700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectInventoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _projectInventoryDb
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: makitaTeal),
          );
        }
        final docs = snapshot.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['project_name'].toString().toLowerCase().contains(
                _searchQuery,
              ) ||
              data['material_name'].toString().toLowerCase().contains(
                _searchQuery,
              );
        }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "현장에 나가 있는 자재가 없습니다.",
              style: TextStyle(
                color: slate700,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12).copyWith(bottom: 20),
          itemCount: docs.length,
          separatorBuilder: (context, index) {
            return const SizedBox(height: 6);
          },
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            String heatNo = data['heatNo'] ?? "";
            bool isSelected = _selectedDocId == docs[index].id;

            return InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedDocId = null;
                    _selectedItemData = null;
                  } else {
                    _selectedDocId = docs[index].id;
                    _selectedItemData = data;
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? makitaTeal.withValues(alpha: 0.05)
                      : pureWhite,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected ? makitaTeal : slate300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: makitaTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: makitaTeal.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            "${data['project_name']}",
                            style: const TextStyle(
                              color: makitaDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (data['category'] != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            data['category'],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: makitaTeal,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            data['material_name'] ?? "이름 없음",
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: slate900,
                              height: 1.2,
                            ),
                          ),
                        ),
                        Text(
                          "${data['qty']}",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Colors.blueGrey.shade800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${data['unit']}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: slate600,
                          ),
                        ),
                      ],
                    ),
                    if (heatNo.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: slate100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: slate300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.tag, size: 12, color: slate600),
                              const SizedBox(width: 4),
                              Text(
                                "Heat: $heatNo",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: slate700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLogsTab() {
    return Column(
      children: [
        if (_isAdmin)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: pureWhite,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: slate100,
                foregroundColor: slate900,
                elevation: 0,
              ),
              icon: const Icon(LucideIcons.trash2, size: 16),
              label: const Text(
                "기록 정리",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _showDeleteLogsDialog,
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _logsDb
                .orderBy('timestamp', descending: true)
                .limit(300)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    "기록이 없습니다.",
                    style: TextStyle(
                      color: slate700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (context, index) {
                  return const Divider(height: 1);
                },
                itemBuilder: (context, index) {
                  final log = docs[index].data() as Map<String, dynamic>;
                  final Timestamp? ts = log['timestamp'] as Timestamp?;
                  final String dateStr = ts != null
                      ? "${ts.toDate().month}/${ts.toDate().day} ${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}"
                      : "방금 전";

                  String type = log['type'] ?? 'OUT';
                  Color iconColor;
                  IconData icon;
                  String sign = "";

                  if (type == 'IN') {
                    iconColor = makitaTeal;
                    icon = LucideIcons.packagePlus;
                    sign = "+";
                  } else if (type == 'OUT') {
                    iconColor = Colors.orange.shade800;
                    icon = LucideIcons.truck;
                    sign = "-";
                  } else if (type == 'AUDIT') {
                    iconColor = slate900;
                    icon = LucideIcons.scale;
                    sign = log['sign'] ?? "";
                  } else {
                    iconColor = Colors.blueAccent;
                    icon = LucideIcons.cornerDownLeft;
                    sign = "+";
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: iconColor.withValues(alpha: 0.1),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    title: Text(
                      log['material_name'] ?? '알 수 없는 자재',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: slate900,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${log['project_name']} • $dateStr",
                          style: const TextStyle(
                            fontSize: 13,
                            color: slate700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (log['reason'] != null &&
                            log['reason'].toString().isNotEmpty)
                          Text(
                            "사유: ${log['reason']}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    trailing: Text(
                      "$sign ${log['qty']} ${log['unit']}",
                      style: TextStyle(
                        color: iconColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStorageGuideTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: slate200, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "현장 랙(Rack) 및 자재 정리정돈 가이드",
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: slate900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "앱 데이터와 실제 현장의 물리적 일치를 위한 필수 준수 사항입니다.",
              style: TextStyle(
                fontSize: 14,
                color: slate700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildGuideSection(
              icon: LucideIcons.boxSelect,
              color: Colors.blue.shade700,
              title: "1. 소분 바구니(Bin) 및 라벨링 철저",
              points: [
                "박스째 뜯어서 선반에 굴리지 마세요. 자재가 섞이고 오염됩니다.",
                "피팅류는 규격별로 전용 소분 바구니에 담아 보관합니다.",
                "바구니 전면 라벨에 앱과 동일하게 [제조사 / 규격 / 품명 / 히트넘버]를 부착하세요.",
              ],
            ),
            _buildGuideSection(
              icon: LucideIcons.alertTriangle,
              color: Colors.purple.shade600,
              title: "2. A급 신품 / B급 잉여 분리",
              points: [
                "현장에서 반납된 '포장 개봉품'이나 '성적서 불가' 피팅을 새 박스에 섞지 마세요.",
                "선반 맨 아래 칸이나 '빨간색 바구니'를 잉여/B급 전용칸으로 지정하세요.",
              ],
            ),
            _buildGuideSection(
              icon: LucideIcons.pipette,
              color: Colors.orange.shade800,
              title: "3. 이종 금속 접촉 금지",
              points: [
                "카본(Carbon)과 서스(SUS) 배관재를 같은 선반에 혼합 보관하지 마세요.",
                "카본 분진이 스뎅에 묻으면 '갈바닉 부식'이 발생합니다.",
              ],
            ),
            _buildGuideSection(
              icon: LucideIcons.mapPin,
              color: makitaTeal,
              title: "4. 튜빙과 피팅의 분리 보관 및 위치 식별",
              points: [
                "길이가 긴 튜빙은 휨 방지를 위해 전용 수평 캔틸레버 랙에 별도 보관합니다.",
                "신규 자재 등록 시 반드시 앱 내 '보관 위치'를 입력해야 합니다.",
              ],
            ),
            _buildGuideSection(
              icon: LucideIcons.scale,
              color: slate900,
              title: "5. 정기 재고 조사(실사) 및 전산 보정",
              points: [
                "전산 수량과 실제 보관함 수량이 다를 경우 점 3개(⋮) 메뉴에서 [재고 임의 수정] 기능을 사용해 개수를 맞추세요.",
              ],
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideSection({
    required IconData icon,
    required Color color,
    required String title,
    required List<String> points,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: slate900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...points.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "• ",
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      p,
                      style: const TextStyle(
                        color: slate700,
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isLast) ...[
            const SizedBox(height: 16),
            const Divider(color: slate200, height: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: slate700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: pureWhite,
              style: const TextStyle(
                color: slate900,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
              items: items
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label, bool isSel, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: isSel ? makitaTeal : pureWhite,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSel ? makitaTeal : Colors.grey.shade300,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSel ? pureWhite : slate700,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
