import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/models/cutting_project_model.dart';
import 'cutting_theme.dart';

// 🚀 [신규] 모바일/데스크톱 컷팅 작업 목록 화면이 공통으로 쓰는 Firestore
// 저장/삭제/재고차감 로직을 한 곳에 모았다. 예전엔 이 로직이 두 화면에
// 각각 따로 있거나(모바일), 아예 없어서(데스크톱 '/cutting' 경로는
// 메모리에만 저장) 기능이 서로 어긋났었다.

/// 튜브(TUBE)/피팅(FITTING) 사용량을 프로젝트 문서의 `materials` 배열에
/// 누적한다. 데스크톱 ProjectManagementPage가 project['materials']에 쌓는
/// 방식과 완전히 동일한 구조(db_name 기준 병합)를 써서, 같은 재고 차감
/// 로직을 재사용할 수 있게 한다.
List<Map<String, dynamic>> mergeMaterialsUsage(
  List<dynamic> currentMaterials,
  double tubeLengthMm,
  List<Map<String, dynamic>> fittingsList,
) {
  final List<Map<String, dynamic>> materials = currentMaterials
      .map((m) => Map<String, dynamic>.from(m as Map))
      .toList();

  if (tubeLengthMm > 0) {
    final tubeIdx = materials.indexWhere((m) => m['type'] == 'TUBE');
    if (tubeIdx >= 0) {
      materials[tubeIdx]['qty_mm'] =
          (materials[tubeIdx]['qty_mm'] as num? ?? 0) + tubeLengthMm;
    } else {
      materials.add({
        'db_name': 'TUBE (기본)',
        'type': 'TUBE',
        'qty_mm': tubeLengthMm,
      });
    }
  }

  for (final newFit in fittingsList) {
    final fitIdx = materials.indexWhere(
      (m) => m['db_name'] == newFit['db_name'],
    );
    if (fitIdx >= 0) {
      materials[fitIdx]['qty_ea'] =
          (materials[fitIdx]['qty_ea'] as num? ?? 0) +
          (newFit['qty'] as num? ?? 0);
    } else {
      materials.add({
        'db_name': newFit['db_name'],
        'maker': newFit['maker'],
        'spec': newFit['spec'],
        'name': newFit['name'],
        'type': 'FITTING',
        'qty_ea': newFit['qty'],
      });
    }
  }

  return materials;
}

/// CuttingMainScreen의 onSaveCallback에서 호출한다. 프로젝트 누적치
/// (totalTubeUsed/cutCount/usedFittings/lastCutAt)를 갱신하고, 재고 차감에
/// 쓸 materials를 누적하고, 이번 "완료"로 생성된 CutRecord들을 서브컬렉션에
/// 함께 저장한다.
Future<void> saveCuttingSession({
  required String projectId,
  required CuttingProject project,
  required double totalTubeLength,
  required List<Map<String, dynamic>> fittingsList,
  required List<CutRecord> cutRecords,
}) async {
  final docRef = FirebaseFirestore.instance
      .collection(kCuttingProjectsCollection)
      .doc(projectId);

  final snap = await docRef.get();
  final existingMaterials = (snap.data()?['materials'] as List?) ?? [];
  final mergedMaterials = mergeMaterialsUsage(
    existingMaterials,
    totalTubeLength,
    fittingsList,
  );

  await docRef.update({
    'totalTubeUsed': project.totalTubeUsed,
    'cutCount': project.cutCount,
    'usedFittings': project.usedFittings,
    'lastCutAt': DateTime.now().toIso8601String(),
    'materials': mergedMaterials,
  });

  if (cutRecords.isNotEmpty) {
    final batch = FirebaseFirestore.instance.batch();
    final recordsRef = docRef.collection(kCutRecordsSubcollection);
    for (final record in cutRecords) {
      batch.set(recordsRef.doc(), record.toMap());
    }
    await batch.commit();
  }
}

/// 프로젝트 삭제 시 컷팅 기록(cut_records) 서브컬렉션도 함께 정리한다.
/// 예전엔 프로젝트 문서만 지우고 서브컬렉션은 그대로 남아 고아 데이터가 됐다.
Future<void> deleteCuttingProjectWithRecords(String projectId) async {
  final docRef = FirebaseFirestore.instance
      .collection(kCuttingProjectsCollection)
      .doc(projectId);
  final recordsSnap = await docRef.collection(kCutRecordsSubcollection).get();
  final batch = FirebaseFirestore.instance.batch();
  for (final d in recordsSnap.docs) {
    batch.delete(d.reference);
  }
  batch.delete(docRef);
  await batch.commit();
}

/// 컷팅 기록(CutRecord) 하나를 지울 때 프로젝트 누적 합계(totalTubeUsed/
/// cutCount)에서도 그만큼 원자적으로 빼서, 개별 기록 삭제가 프로젝트 누적
/// 합계와 영구히 어긋나지 않게 한다.
Future<void> reconcileProjectAfterRecordDelete({
  required String projectId,
  required CutRecord deletedRecord,
}) async {
  final docRef = FirebaseFirestore.instance
      .collection(kCuttingProjectsCollection)
      .doc(projectId);
  await docRef.update({
    'totalTubeUsed': FieldValue.increment(
      -(deletedRecord.cutLength * deletedRecord.multiplier),
    ),
    'cutCount': FieldValue.increment(-deletedRecord.multiplier),
  });
}

/// 데스크톱(ProjectManagementPage)의 "재고 일괄 차감"과 동일한 로직을
/// 모바일/데스크톱 컷팅 작업 목록에서도 쓸 수 있게 뺀 공용 함수. 프로젝트
/// 문서에 누적된 materials(아직 차감 안 한 사용량)를 인벤토리에서 빼고,
/// 성공하면 materials를 비워서 다음 차감 때 중복으로 빠지지 않게 한다.
Future<void> deductCuttingProjectInventory({
  required BuildContext context,
  required String projectId,
  required String projectName,
}) async {
  final db = FirebaseFirestore.instance;
  final docRef = db.collection(kCuttingProjectsCollection).doc(projectId);
  final snap = await docRef.get();
  final materials = (snap.data()?['materials'] as List?) ?? [];

  if (materials.isEmpty) {
    if (context.mounted) {
      showCuttingSnack(context, "차감할 새 사용량이 없습니다.", isError: true);
    }
    return;
  }

  if (!context.mounted) return;
  final confirmed = await showCuttingConfirmDialog(
    context,
    title: "재고 차감",
    message: "'$projectName'에서 사용된 자재 ${materials.length}건을 창고 재고에서 차감하시겠습니까?",
    confirmLabel: "차감하기",
    icon: Icons.inventory_2_outlined,
  );
  if (!confirmed) return;

  if (!context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(
      child: CircularProgressIndicator(color: CuttingColors.primary),
    ),
  );

  try {
    final batch = db.batch();
    for (final mat in materials) {
      final m = mat as Map;
      final bool isTube = m['type'] == 'TUBE';
      final int requiredQty = isTube
          ? (((m['qty_mm'] as num? ?? 0)) / 6000).ceil()
          : ((m['qty_ea'] as num? ?? 0)).toInt();
      if (requiredQty <= 0) continue;

      final invSnap = await db
          .collection('inventory')
          .where('name', isEqualTo: m['db_name'])
          .limit(1)
          .get();
      if (invSnap.docs.isNotEmpty) {
        final doc = invSnap.docs.first;
        batch.update(db.collection('inventory').doc(doc.id), {
          'qty': (doc.data()['qty'] ?? 0) - requiredQty,
        });
      } else {
        batch.set(db.collection('inventory').doc(), {
          "name": m['db_name'],
          "size": m['spec'] ?? "규격 확인 필요",
          "category": m['type'],
          "qty": -requiredQty,
          "min_qty": 10,
          "is_dead_stock": false,
          "unit": isTube ? "본" : "EA",
          "createdAt": FieldValue.serverTimestamp(),
          "location": "임시 등록 (확인 필요)",
        });
      }
      batch.set(db.collection('inventory_logs').doc(), {
        "project_name": projectName,
        "material_name": m['db_name'],
        "deducted_qty": requiredQty,
        "unit": isTube ? "본" : "EA",
        "timestamp": FieldValue.serverTimestamp(),
      });
    }
    batch.update(docRef, {'materials': []});
    await batch.commit();

    if (context.mounted) Navigator.pop(context);
    if (context.mounted) {
      showCuttingSnack(context, "재고 차감 및 출고 기록 완료!");
    }
  } catch (e) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) {
      showCuttingSnack(context, "차감 실패: $e", isError: true);
    }
  }
}
