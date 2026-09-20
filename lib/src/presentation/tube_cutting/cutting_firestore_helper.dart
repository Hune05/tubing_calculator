import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/cutting_project_model.dart';
import 'cutting_stock_deduct.dart';
import 'cutting_theme.dart';

// 🚀 [신규] 모바일/데스크톱 컷팅 작업 목록 화면이 공통으로 쓰는 Firestore
// 저장/삭제/재고차감 로직을 한 곳에 모았다. 예전엔 이 로직이 두 화면에
// 각각 따로 있거나(모바일), 아예 없어서(데스크톱 '/cutting' 경로는
// 메모리에만 저장) 기능이 서로 어긋났었다.

/// 튜브(TUBE)/피팅(FITTING) 사용량을 프로젝트 문서의 `materials` 배열에
/// 누적한다. 데스크톱 ProjectManagementPage가 project['materials']에 쌓는
/// 방식과 완전히 동일한 구조(db_name 기준 병합)를 써서, 같은 재고 차감
/// 로직을 재사용할 수 있게 한다.
/// 튜브 자재를 재고에서 찾을 이름. 규격을 넣어야 3/8"와 1/2"가 따로 빠진다.
/// 🚀 [고침] 예전에는 규격과 상관없이 모두 'TUBE (기본)' 한 이름으로 쌓여서
/// 규격별 재고 관리가 아예 안 됐다.
String tubeMaterialName(String tubeSize) {
  final s = tubeSize.trim();
  if (s.isEmpty) return '튜브 (규격 미지정)';
  return '튜브 $s';
}

/// 예전에 쌓인 이름(재고를 찾을 때 옛 이름도 같이 본다).
const String kLegacyTubeMaterialName = 'TUBE (기본)';

List<Map<String, dynamic>> mergeMaterialsUsage(
  List<dynamic> currentMaterials,
  double tubeLengthMm,
  List<Map<String, dynamic>> fittingsList, {
  String tubeSize = '',
  // 규격이 섞인 작업이면 규격별 길이를 넘긴다(이쪽이 우선).
  Map<String, double>? tubeLengthBySize,
}) {
  final List<Map<String, dynamic>> materials = currentMaterials
      .map((m) => Map<String, dynamic>.from(m as Map))
      .toList();

  void addTube(String size, double mm) {
    if (mm <= 0) return;
    final name = tubeMaterialName(size);
    var idx = materials.indexWhere(
      (m) => m['type'] == 'TUBE' && (m['db_name'] ?? '') == name,
    );
    // 규격을 모르면 예전처럼 튜브 줄 하나에 쌓는다(옛 자료와 이어진다).
    if (idx < 0 && size.trim().isEmpty) {
      idx = materials.indexWhere((m) => m['type'] == 'TUBE');
    }
    if (idx >= 0) {
      materials[idx]['qty_mm'] = (materials[idx]['qty_mm'] as num? ?? 0) + mm;
    } else {
      materials.add({
        'db_name': name,
        'type': 'TUBE',
        'spec': size,
        'qty_mm': mm,
      });
    }
  }

  if (tubeLengthBySize != null && tubeLengthBySize.isNotEmpty) {
    tubeLengthBySize.forEach(addTube);
  } else {
    addTube(tubeSize, tubeLengthMm);
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

/// [mergeMaterialsUsage]로 더했던 사용량을 다시 뺀다("저장" 실행 취소용). 남은 값이 0 이하가 되면
/// 그 항목은 목록에서 지운다(그 사이 재고 차감으로 이미 비워졌다면 아무것도 하지 않는다).
List<Map<String, dynamic>> subtractMaterialsUsage(
  List<dynamic> currentMaterials,
  double tubeLengthMm,
  List<Map<String, dynamic>> fittingsList, {
  String tubeSize = '',
  Map<String, double>? tubeLengthBySize,
}) {
  final List<Map<String, dynamic>> materials = currentMaterials
      .map((m) => Map<String, dynamic>.from(m as Map))
      .toList();

  void takeTube(String size, double mm) {
    if (mm <= 0) return;
    final name = tubeMaterialName(size);
    var idx = materials.indexWhere(
      (m) => m['type'] == 'TUBE' && (m['db_name'] ?? '') == name,
    );
    // 옛 자료는 규격 없이 한 줄로 쌓여 있다.
    idx = idx >= 0 ? idx : materials.indexWhere((m) => m['type'] == 'TUBE');
    if (idx < 0) return;
    final left = (materials[idx]['qty_mm'] as num? ?? 0) - mm;
    if (left <= 1e-6) {
      materials.removeAt(idx);
    } else {
      materials[idx]['qty_mm'] = left;
    }
  }

  if (tubeLengthBySize != null && tubeLengthBySize.isNotEmpty) {
    tubeLengthBySize.forEach(takeTube);
  } else {
    takeTube(tubeSize, tubeLengthMm);
  }

  for (final fit in fittingsList) {
    final idx = materials.indexWhere((m) => m['db_name'] == fit['db_name']);
    if (idx < 0) continue;
    final left =
        (materials[idx]['qty_ea'] as num? ?? 0) - (fit['qty'] as num? ?? 0);
    if (left <= 0) {
      materials.removeAt(idx);
    } else {
      materials[idx]['qty_ea'] = left;
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
  // 기록에 적힌 규격별로 나눠서 쌓는다(한 작업에 3/8"와 1/2"가 섞일 수 있다).
  final bySize = <String, double>{};
  for (final r in cutRecords) {
    final size = r.tubeSize.trim();
    bySize[size] = (bySize[size] ?? 0) + r.cutLength * r.multiplier;
  }
  final mergedMaterials = mergeMaterialsUsage(
    existingMaterials,
    totalTubeLength,
    fittingsList,
    tubeLengthBySize: bySize.isEmpty ? null : bySize,
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

/// [saveCuttingSession]으로 저장한 것을 되돌린다("저장" 직후 실행 취소).
/// 호출하기 전에 [project]의 메모리 값(누적 길이·횟수)은 이미 뺀 상태여야 한다 — 저장할 때와
/// 똑같이 그 값을 문서에 그대로 쓴다. 자재 사용량(materials)에서는 이번에 더한 만큼을 빼고,
/// 이번 저장으로 만들어진 컷팅 기록(같은 저장 시각을 가진 것)을 지운다.
Future<void> undoCuttingSession({
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
  await docRef.update({
    'totalTubeUsed': project.totalTubeUsed,
    'cutCount': project.cutCount,
    'usedFittings': project.usedFittings,
    'materials': subtractMaterialsUsage(
      existingMaterials,
      totalTubeLength,
      fittingsList,
    ),
    // 되돌린 뒤 누적이 0이면 "마지막 작업" 날짜도 지운다(저장한 적이 없는 것으로 돌아간다).
    if (project.cutCount <= 0 && project.totalTubeUsed <= 1e-6)
      'lastCutAt': FieldValue.delete(),
  });

  if (cutRecords.isNotEmpty) {
    final savedAt = cutRecords.first.timestamp.toIso8601String();
    final recordsRef = docRef.collection(kCutRecordsSubcollection);
    final made = await recordsRef.where('timestamp', isEqualTo: savedAt).get();
    if (made.docs.isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      for (final d in made.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
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

/// 데스크톱(ProjectManagementPage)의 "재고 한꺼번에 차감"과 동일한 로직을
/// 모바일/데스크톱 컷팅 작업 목록에서도 쓸 수 있게 뺀 공용 함수. 프로젝트
/// 문서에 누적된 materials(아직 차감 안 한 사용량)를 인벤토리에서 빼고,
/// 성공하면 materials를 비워서 다음 차감 때 중복으로 빠지지 않게 한다.
Future<void> deductCuttingProjectInventory({
  required BuildContext context,
  required String projectId,
  required String projectName,
  String worker = '',
}) async {
  final db = FirebaseFirestore.instance;
  // 누가 차감했는지 기록에 남기려고, 안 넘겨 주면 폰에 적힌 이름을 쓴다.
  var who = worker.trim();
  if (who.isEmpty) {
    try {
      final p = await SharedPreferences.getInstance();
      who = p.getString('user_real_name') ?? '';
    } catch (_) {}
  }
  final docRef = db.collection(kCuttingProjectsCollection).doc(projectId);
  final snap = await docRef.get();
  final materials = (snap.data()?['materials'] as List?) ?? [];

  if (materials.isEmpty) {
    if (context.mounted) {
      showCuttingSnack(context, "차감할 자재가 없습니다.", isError: true);
    }
    return;
  }

  // 빼기 전에 불출로 이미 나가 있는 자재가 있으면 알려 준다(두 번 빼기 막기).
  final stock = await loadStockInfo();
  final takes = stockTakesFromMaterials(
    materials,
    barLengthByName: stock.barLengthByName,
    unitByName: stock.unitByName,
  );
  final warning = doubleDeductWarning(takes, await loadOpenCheckouts());

  if (!context.mounted) return;
  final confirmed = await showCuttingConfirmDialog(
    context,
    title: "재고에서 차감하겠습니까?",
    message: warning.isEmpty
        ? "'$projectName'에서 쓴 자재 ${materials.length}건을 창고 재고에서 뺍니다."
        : "'$projectName'에서 쓴 자재 ${materials.length}건을 창고 재고에서 뺍니다."
              "\n\n$warning",
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
    // 🚀 [고침] 예전에는 여기에 차감 셈이 따로 한 벌 더 있었다(자재 목록 화면과
    // 형강 화면까지 세 벌). 한 곳만 고치면 나머지가 어긋나므로 공용 함수
    // deductStockTakes 하나로 모았다. 재고에 없는 자재를 음수로 새로 만들지
    // 않고, 통신이 안 될 때 "재고에 없다"고 잘라 말하지 않는 것도 여기 들어 있다.
    final result = await deductStockTakes(
      takes,
      projectName: projectName,
      worker: who,
      projectId: projectId,
    );

    // 뺀 것만 지운다. 못 찾은 것은 남겨 둬서, 자재를 넣은 뒤 다시 뺄 수 있게 한다.
    final leftNames = {for (final m in result.missing) m.name};
    await docRef.update({
      'materials': [
        for (final raw in materials)
          if (raw is Map &&
              leftNames.contains(
                (raw['db_name'] ?? raw['name'] ?? '').toString().trim(),
              ))
            raw,
      ],
    }).timeout(const Duration(seconds: 8), onTimeout: () {});

    if (context.mounted) Navigator.pop(context);
    if (context.mounted) {
      showCuttingSnack(context, result.message, isError: !result.allDone);
    }
  } catch (e) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) {
      showCuttingSnack(context, "차감하지 못했습니다: $e", isError: true);
    }
  }
}
