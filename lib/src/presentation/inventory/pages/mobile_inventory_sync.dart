part of 'mobile_inventory_page.dart';

// 상태 확장(extension)시 발생하는 setState 경고 무시
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: library_private_types_in_public_api

extension MobileInventorySyncExt on _MobileInventoryPageState {
  bool _validateSync() {
    if (_localEdits.isEmpty) {
      _showErrorSnackBar("변경된 데이터가 없습니다.");
      return false;
    }
    return true;
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.bold, color: pureWhite),
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
    HapticFeedback.lightImpact();
  }

  Future<void> _syncToServer() async {
    FocusScope.of(context).unfocus();
    if (!_validateSync()) return;

    HapticFeedback.heavyImpact();

    final newRecord = {
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "time":
          "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
      "category": _categories[_currentCategory]['name'],
      "color": _categories[_currentCategory]['color'],
      "syncCount": _localEdits.length,
      "status": "syncing",
    };

    setState(() => _historyLogs.insert(0, newRecord));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "서버로 실사 데이터를 전송 중입니다...",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: makitaTeal,
      ),
    );

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var entry in _localEdits.entries) {
        String docId = entry.key;
        ItemData data = entry.value;

        // 1. 모바일에서 새로 추가한 자재 (DB에 없는 것)
        if (docId.startsWith("NEW_")) {
          String itemName = _newLocalItems[docId]?['name'] ?? "알수없는 임시자재";
          String category = _newLocalItems[docId]?['category'] ?? "기타";

          DocumentReference newDocRef = _inventoryDb.doc();

          Map<String, dynamic> newDocData = {
            'name': itemName,
            'category': category,
            'qty': data.qty,
            'status': '정상',
            'is_dead_stock': false,
            'is_reorder_needed': false,
            'unit': 'EA',
            'createdAt': FieldValue.serverTimestamp(),
          };

          // 🚀 재질, 제조사, 히트넘버, 위치 추가 전송
          try {
            if (data.material.isNotEmpty)
              newDocData['material'] = data.material;
            if (data.heatNo.isNotEmpty) newDocData['heatNo'] = data.heatNo;
            if (data.maker.isNotEmpty) newDocData['maker'] = data.maker;
            if (data.location.isNotEmpty)
              newDocData['location'] = data.location;
          } catch (_) {}

          batch.set(newDocRef, newDocData);

          batch.set(_logsDb.doc(), {
            'type': 'IN',
            'project_name': '📱 모바일 현장 신규등록',
            'material_name': itemName,
            'qty': data.qty,
            'unit': 'EA',
            'worker_name': widget.workerName, // 🚀 로그인한 작업자 이름 로깅 (증거 확보)
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
        // 2. 이미 존재하는 자재 업데이트
        else {
          DocumentReference existingDocRef = _inventoryDb.doc(docId);

          var snapshot = await existingDocRef.get();
          if (snapshot.exists) {
            Map<String, dynamic> dbData =
                snapshot.data() as Map<String, dynamic>;
            int systemQty = dbData['qty'] ?? 0;
            int diff = data.qty - systemQty;

            Map<String, dynamic> updates = {'qty': data.qty};

            // 🚀 업데이트 시에도 재질 등 상세정보가 수정되었다면 전송
            try {
              if (data.material.isNotEmpty) updates['material'] = data.material;
              if (data.heatNo.isNotEmpty) updates['heatNo'] = data.heatNo;
              if (data.maker.isNotEmpty) updates['maker'] = data.maker;
              if (data.location.isNotEmpty) updates['location'] = data.location;
            } catch (_) {}

            batch.update(existingDocRef, updates);

            if (diff != 0) {
              batch.set(_logsDb.doc(), {
                'type': 'AUDIT',
                'project_name': '📱 모바일 현장 실사',
                'material_name': dbData['name'],
                'qty': diff.abs(),
                'sign': diff > 0 ? '+' : '-',
                'unit': dbData['unit'] ?? 'EA',
                'worker_name': widget.workerName, // 🚀 실사(수정)한 작업자 이름 로깅
                'timestamp': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      }

      await batch.commit();

      if (!mounted) return;
      setState(() {
        _historyLogs.firstWhere(
          (log) => log['id'] == newRecord['id'],
        )['status'] = "completed";

        _localEdits.clear();
        _newLocalItems.clear();
      });

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "서버 동기화 완료! PC에도 즉시 반영되었습니다.",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
      if (!mounted) return;
      setState(
        () => _historyLogs.firstWhere(
          (log) => log['id'] == newRecord['id'],
        )['status'] = "failed",
      );
      _showErrorSnackBar("전송 실패: 네트워크를 확인하세요.");
    }
  }
}
