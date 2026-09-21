part of 'mobile_inventory_page.dart';

// 상태 확장(extension)시 발생하는 setState 경고 무시
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: library_private_types_in_public_api

extension MobileInventorySyncExt on _MobileInventoryPageState {
  bool _validateSync() {
    if (_localEdits.isEmpty) {
      _showErrorSnackBar("고친 것이 없습니다.");
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

  // 서버로 보내기 전에 "무엇이 몇 개에서 몇 개로 바뀌는지" 한 줄씩 만든다.
  // 수량 단추(-, +)를 잘못 눌러 놓고 그대로 올려 버리는 사고를 막기 위한 것이다.
  Future<List<String>> _buildSyncPreview() async {
    final lines = <String>[];
    for (final entry in _localEdits.entries) {
      final docId = entry.key;
      final data = entry.value;

      if (docId.startsWith("NEW_")) {
        final name = _newLocalItems[docId]?['name'] ?? "이름 없는 새 자재";
        lines.add("새 자재 $name — ${data.qty}EA 등록");
        continue;
      }

      var name = "이름 없음";
      var unit = "EA";
      var before = -1;
      try {
        final snap = await _inventoryDb.doc(docId).get();
        final m = snap.data() as Map<String, dynamic>?;
        name = (m?['name'] as String?) ?? name;
        unit = (m?['unit'] as String?) ?? unit;
        before = (m?['qty'] as int?) ?? -1;
      } catch (_) {}

      if (before < 0) {
        lines.add("$name — ${data.qty}$unit로 맞춤");
      } else if (before == data.qty) {
        lines.add("$name — ${data.qty}$unit (수량 그대로)");
      } else {
        lines.add("$name — $before$unit → ${data.qty}$unit");
      }
    }
    return lines;
  }

  Future<bool> _confirmSync(List<String> lines) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.light(),
        child: AlertDialog(
          backgroundColor: pureWhite,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            "이대로 서버에 올리겠습니까?",
            style: TextStyle(
              color: slate900,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      line,
                      style: const TextStyle(
                        color: slate900,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                const Text(
                  "올리면 창고 재고가 이 수량으로 바뀝니다.",
                  style: TextStyle(
                    color: slate600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                "취소",
                style: TextStyle(color: slate600, fontWeight: FontWeight.w700),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: makitaTeal,
                foregroundColor: pureWhite,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                "올립니다",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _syncToServer() async {
    FocusScope.of(context).unfocus();
    if (!_validateSync()) return;

    final preview = await _buildSyncPreview();
    if (!mounted) return;
    if (!await _confirmSync(preview)) return;
    if (!mounted) return;

    HapticFeedback.heavyImpact();

    final newRecord = {
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "time":
          "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
      "category": _currentCategoryInfo['name'],
      "color": makitaTeal,
      "syncCount": _localEdits.length,
      "status": "syncing",
    };

    setState(() => _historyLogs.insert(0, newRecord));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "서버로 올리고 있습니다.",
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

          // 🚀 신규 자재: 필수로 들어가는 기본 데이터
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

          // 🚀 신규 자재: 상세 정보(옵션) 추가 (증발 문제 해결 지점)
          try {
            if (data.material.isNotEmpty) {
              newDocData['material'] = data.material;
            }
            if (data.heatNo.isNotEmpty) {
              newDocData['heatNo'] = data.heatNo;
            }
            if (data.maker.isNotEmpty) {
              newDocData['maker'] = data.maker;
            }
            if (data.location.isNotEmpty) {
              newDocData['location'] = data.location;
            }
            if (data.spec.isNotEmpty) {
              newDocData['spec'] = data.spec; // ★ 추가
            }
            if (data.projectName.isNotEmpty) {
              newDocData['projectName'] = data.projectName; // ★ 추가
            }
            if (data.department.isNotEmpty) {
              newDocData['department'] = data.department; // ★ 추가
            }
            newDocData['minQty'] = data.minQty; // ★ 추가 (기본값이 0이더라도 전송)
          } catch (_) {}

          batch.set(newDocRef, newDocData);

          batch.set(_logsDb.doc(), {
            'type': 'INIT',
            'project_name': '현장 자재 등록',
            'material_name': itemName,
            'qty': data.qty,
            'unit': 'EA',
            'worker_name': widget.workerName,
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

            // 🚀 기존 자재: 변경될 필수 데이터
            Map<String, dynamic> updates = {'qty': data.qty};

            // 🚀 기존 자재: 상세정보가 수정되었다면 전송 (증발 문제 해결 지점)
            try {
              if (data.material.isNotEmpty) {
                updates['material'] = data.material;
              }
              if (data.heatNo.isNotEmpty) {
                updates['heatNo'] = data.heatNo;
              }
              if (data.maker.isNotEmpty) {
                updates['maker'] = data.maker;
              }
              if (data.location.isNotEmpty) {
                updates['location'] = data.location;
              }
              if (data.spec.isNotEmpty) {
                updates['spec'] = data.spec; // ★ 추가
              }
              if (data.projectName.isNotEmpty) {
                updates['projectName'] = data.projectName; // ★ 추가
              }
              if (data.department.isNotEmpty) {
                updates['department'] = data.department; // ★ 추가
              }
              updates['minQty'] = data.minQty; // ★ 추가 (최소 수량 변경 사항 반영)
            } catch (_) {}

            batch.update(existingDocRef, updates);

            if (diff != 0) {
              batch.set(_logsDb.doc(), {
                'type': 'AUDIT',
                'project_name': '현장 재고조사',
                'material_name': dbData['name'],
                'qty': diff.abs(),
                'sign': diff > 0 ? '+' : '-',
                'unit': dbData['unit'] ?? 'EA',
                'worker_name': widget.workerName,
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
            "서버에 올렸습니다. PC에서도 바로 보입니다.",
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
      _showErrorSnackBar("올리지 못했습니다. 통신을 확인하십시오.");
    }
  }
}
