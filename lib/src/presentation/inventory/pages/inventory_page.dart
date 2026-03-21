// ignore_for_file: deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'inventory_constants.dart';

// 분리된 UI 탭과 다이얼로그 파일들을 한 라이브러리로 묶어줍니다.
part 'inventory_tabs.dart';
part 'inventory_dialogs.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  int _currentTabIndex = 0;
  bool _isSearching = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  int _stockFilterStatus = 0;

  String _selectedFilterCategory = "ALL";
  String _selectedFilterMaker = "ALL";

  String? _selectedDocId;
  Map<String, dynamic>? _selectedItemData;

  final List<String> _categories = [
    "ALL",
    "TUBE",
    "FITTING",
    "VALVE",
    "FLANGE",
    "기타",
  ];
  final List<String> _makers = ["ALL", "HY-LOK", "SWAGELOK", "PARKER", "기타"];

  final CollectionReference _inventoryDb = FirebaseFirestore.instance
      .collection('inventory');
  final CollectionReference _projectInventoryDb = FirebaseFirestore.instance
      .collection('project_inventory');
  final CollectionReference _logsDb = FirebaseFirestore.instance.collection(
    'inventory_logs',
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateItemStatus(String docId, String status) {
    bool isDead = (status != "정상");
    _inventoryDb.doc(docId).update({'status': status, 'is_dead_stock': isDead});
    if (_selectedDocId == docId) {
      setState(() {
        _selectedDocId = null;
        _selectedItemData = null;
      });
    }
  }

  void _toggleReorderStatus(String docId, bool currentStatus) {
    _inventoryDb.doc(docId).update({'is_reorder_needed': !currentStatus});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: slate50,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: pureWhite, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: '자재명, 규격 검색...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
              )
            : const Text(
                '자재 창고 관리',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
        backgroundColor: makitaTeal,
        foregroundColor: pureWhite,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : LucideIcons.search),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                _searchQuery = "";
              }
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            color: pureWhite,
            child: Row(
              children: [
                _buildTab("자재 창고", 0),
                const SizedBox(width: 4),
                _buildTab("현장 자재", 1),
                const SizedBox(width: 4),
                _buildTab("기록(Log)", 2),
                const SizedBox(width: 4),
                _buildTab("보관 가이드", 3),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                _buildMainInventoryTab(),
                _buildProjectInventoryTab(),
                _buildLogsTab(),
                _buildStorageGuideTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _currentTabIndex == 0 || _currentTabIndex == 1
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: const BoxDecoration(
                color: pureWhite,
                border: Border(top: BorderSide(color: slate200)),
              ),
              child: SafeArea(
                child: _currentTabIndex == 0
                    ? Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: makitaTeal,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              onPressed: _selectedDocId == null
                                  ? () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("입고할 자재를 먼저 선택해주세요."),
                                        ),
                                      );
                                    }
                                  : () => _showMainStockActionDialog(
                                      isDispatch: false,
                                      docId: _selectedDocId!,
                                      item: _selectedItemData!,
                                    ),
                              child: const Text(
                                "자재 입고 (+)",
                                style: TextStyle(
                                  color: pureWhite,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              onPressed: _selectedDocId == null
                                  ? () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("불출할 자재를 먼저 선택해주세요."),
                                        ),
                                      );
                                    }
                                  : () => _showMainStockActionDialog(
                                      isDispatch: true,
                                      docId: _selectedDocId!,
                                      item: _selectedItemData!,
                                    ),
                              child: const Text(
                                "자재 불출 (-)",
                                style: TextStyle(
                                  color: pureWhite,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: makitaDark,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              onPressed: _showAddMaterialSheet,
                              child: const Text(
                                "신규 자재 등록",
                                style: TextStyle(
                                  color: pureWhite,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: makitaTeal,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              onPressed: _selectedDocId == null
                                  ? () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "반납할 현장 자재를 먼저 선택해주세요.",
                                          ),
                                        ),
                                      );
                                    }
                                  : () => _showProjectReturnDialog(
                                      docId: _selectedDocId!,
                                      pItem: _selectedItemData!,
                                    ),
                              child: const Text(
                                "자재 반납",
                                style: TextStyle(
                                  color: pureWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            )
          : null,
    );
  }

  Widget _buildTab(String label, int index) {
    bool isSel = _currentTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          if (_currentTabIndex != index) {
            _currentTabIndex = index;
            _selectedDocId = null;
            _selectedItemData = null;
          }
        }),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isSel ? makitaTeal : slate100,
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
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        ),
      ),
    );
  }
}
