import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
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

  // [bars]: 재단 계획의 새 원자재 본수(있으면). 차감 때 길이를 한 본 길이로 나누지 않고 본수를 쓴다.
  void addTube(String size, double mm, {int bars = 0}) {
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
      if (bars > 0) {
        materials[idx]['qty_bars'] = (materials[idx]['qty_bars'] as num? ?? 0) + bars;
        materials[idx]['qty_bars_mm'] = (materials[idx]['qty_bars_mm'] as num? ?? 0) + mm;
      }
    } else {
      materials.add({
        'db_name': name,
        'type': 'TUBE',
        'spec': size,
        'qty_mm': mm,
        if (bars > 0) 'qty_bars': bars,
        if (bars > 0) 'qty_bars_mm': mm,
      });
    }
  }

  if (tubeLengthBySize != null && tubeLengthBySize.isNotEmpty) {
    tubeLengthBySize.forEach(addTube);
  } else {
    addTube(tubeSize, tubeLengthMm);
  }

  for (final newFit in fittingsList) {
    // 재단 계획에서 빼지 않고 "나중에 목록에서 빼기"로 남긴 튜브(길이로 쌓는다).
    if (newFit['type'] == 'TUBE') {
      addTube(
        (newFit['spec'] ?? '').toString(),
        (newFit['qty_mm'] as num? ?? 0).toDouble(),
        bars: (newFit['qty_bars'] as num? ?? 0).toInt(),
      );
      continue;
    }
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

  void takeTube(String size, double mm, {int bars = 0}) {
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
      if (bars > 0) {
        final b = (materials[idx]['qty_bars'] as num? ?? 0) - bars;
        final bm = (materials[idx]['qty_bars_mm'] as num? ?? 0) - mm;
        if (b <= 0) {
          materials[idx].remove('qty_bars');
          materials[idx].remove('qty_bars_mm');
        } else {
          materials[idx]['qty_bars'] = b;
          materials[idx]['qty_bars_mm'] = bm < 0 ? 0 : bm;
        }
      }
    }
  }

  if (tubeLengthBySize != null && tubeLengthBySize.isNotEmpty) {
    tubeLengthBySize.forEach(takeTube);
  } else {
    takeTube(tubeSize, tubeLengthMm);
  }

  for (final fit in fittingsList) {
    if (fit['type'] == 'TUBE') {
      takeTube(
        (fit['spec'] ?? '').toString(),
        (fit['qty_mm'] as num? ?? 0).toDouble(),
        bars: (fit['qty_bars'] as num? ?? 0).toInt(),
      );
      continue;
    }
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

/// 재단 계획에서 아직 안 뺀 튜브(규격 이름 → 새 원자재 길이 합 mm)를 목록의
/// "출고 대기"에 남길 줄로 만든다. 저장할 때 부속과 같이 넘기면 [mergeMaterialsUsage]가
/// 튜브 길이로 쌓고, 목록의 "재고 차감"이 한 본 길이로 나눠 뺀다.
/// [mmBySpec]의 키는 재단 계획 규격 이름("튜브 1/2\"", 모르면 "").
/// [barsBySpec]: 규격별 새 원자재 본수(10-08: 길이 합만 남겨, 계획 기준 길이와 재고 한 본 길이가 다르면
/// 목록에서 뺄 때 본수가 틀렸다. 4000 3본 = 12000 → 6000 재고에서 2본만 빠졌다).
List<Map<String, dynamic>> pendingTubeEntries(
  Map<String, double> mmBySpec, {
  Map<String, int> barsBySpec = const {},
}) => [
  for (final e in mmBySpec.entries)
    if (e.value > 0)
      {
        if ((barsBySpec[e.key] ?? 0) > 0) 'qty_bars': barsBySpec[e.key],
        'type': 'TUBE',
        'spec': e.key.startsWith('튜브 ') ? e.key.substring(3) : e.key,
        'db_name': tubeMaterialName(
          e.key.startsWith('튜브 ') ? e.key.substring(3) : e.key,
        ),
        'qty_mm': e.value,
      },
];

/// 컷팅 기록에서 규격별 튜브 사용 길이(mm)를 모은다. 저장과 되돌리기가
/// 같은 값을 써야 자재 사용량이 제자리로 돌아온다.
/// 한 작업에 3/8"와 1/2"가 섞일 수 있어 규격별로 나눈다.
Map<String, double> tubeUsageBySize(List<CutRecord> cutRecords) {
  final bySize = <String, double>{};
  for (final r in cutRecords) {
    final size = r.tubeSize.trim();
    bySize[size] = (bySize[size] ?? 0) + r.cutLength * r.multiplier;
  }
  return bySize;
}

/// 저장 한 번에 "아직 재고에서 안 뺀 사용량"(materials)에 더할 것: 부속만.
/// 🚀 [고침] 예전에는 튜브도 길이 합으로 쌓았다가 목록의 "재고 차감"에서 한 본
/// 길이로 나눠 올림해 뺐다. 3500mm × 3개면 재단 계획은 3본인데 2본만 빠졌고,
/// 잔재에서 자른 것도 새 본으로 또 빠졌다. 튜브는 이제 형강처럼 재단 계획 창의
/// "재고에서 빼기"로 새 원자재 본수만큼 뺀다(잔재에서 자른 것은 안 빠진다).
/// 예전에 쌓인 튜브 길이는 그대로 두어 목록에서 전처럼 뺄 수 있다.
List<Map<String, dynamic>> materialsAfterSession(
  List<dynamic> existing,
  List<Map<String, dynamic>> fittingsList,
) => mergeMaterialsUsage(existing, 0, fittingsList);

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

  DocumentSnapshot<Map<String, dynamic>> snap;
  try {
    snap = await docRef.get().timeout(const Duration(seconds: 5));
  } catch (_) {
    snap = await docRef.get(const GetOptions(source: Source.cache));
  }
  final existingMaterials = (snap.data()?['materials'] as List?) ?? [];
  final mergedMaterials = materialsAfterSession(
    existingMaterials,
    fittingsList,
  );

  // 합계·사용량과 컷팅 기록을 한 묶음으로 쓴다. 예전엔 합계 쓰기가 서버 답을 기다린 뒤에야
  // 기록을 적어서, 통신 없이 앱을 닫으면 합계는 올라가고 기록은 없었다(지울 수도 없었다).
  final batch = FirebaseFirestore.instance.batch();
  // 누적 합계는 이번에 늘어난 만큼만 더한다(10-08: 화면이 들고 있던 값을 통째로 써서, 폰·태블릿이
  // 같은 작업을 저장하면 다른 기기가 더한 몫이 사라졌다).
  batch.update(docRef, {
    'totalTubeUsed': FieldValue.increment(totalTubeLength),
    'cutCount': FieldValue.increment(cutCountOf(cutRecords)),
    'lastCutAt': DateTime.now().toIso8601String(),
    'materials': mergedMaterials,
  });
  final recordsRef = docRef.collection(kCutRecordsSubcollection);
  for (final record in cutRecords) {
    batch.set(recordsRef.doc(), {...record.toMap(), 'tubeInMaterials': false});
  }
  await batch.commit();
}

/// [current] 사용량에서 이번에 재고에서 뺀 줄들([deducted], 뺄 때 읽은 값)만큼을 뺀다.
/// 그사이 늘어난 몫은 남는다. 다 빠진 줄은 지운다.
List<Map<String, dynamic>> materialsAfterDeduct(
  List<dynamic> current,
  List<dynamic> deducted,
) {
  String nameOf(Map m) => (m['db_name'] ?? m['name'] ?? '').toString().trim();
  final took = <String, Map>{
    for (final d in deducted)
      if (d is Map) nameOf(d): d,
  };
  final out = <Map<String, dynamic>>[];
  for (final raw in current) {
    if (raw is! Map) continue;
    final m = Map<String, dynamic>.from(raw);
    final t = took[nameOf(m)];
    if (t == null) {
      out.add(m);
      continue;
    }
    var left = false;
    for (final k in const ['qty_ea', 'qty_mm', 'qty_bars', 'qty_bars_mm']) {
      final now = (m[k] as num?) ?? 0;
      final v = now - ((t[k] as num?) ?? 0);
      if (m.containsKey(k)) {
        if (v > 1e-6) {
          m[k] = v;
          if (k == 'qty_ea' || k == 'qty_mm') left = true;
        } else {
          m.remove(k);
        }
      }
    }
    if (left) out.add(m);
  }
  return out;
}

/// 한 번 저장으로 늘어나는 절단 횟수(구간 × 세트). 화면의 recordUsage와 같은 셈.
int cutCountOf(List<CutRecord> records) =>
    records.fold(0, (n, r) => n + r.multiplier);

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

  // 통신이 없어도 멈추지 않게 읽고(폰 사본), 합계 되돌리기와 기록 지우기를 한 묶음으로 쓴다
  // (10-08: 합계 쓰기를 기다리느라 기록 지우기가 실행되지 않아, 통신 전에 앱을 닫으면 기록만 남았다).
  DocumentSnapshot<Map<String, dynamic>> snap;
  try {
    snap = await docRef.get().timeout(const Duration(seconds: 5));
  } catch (_) {
    snap = await docRef.get(const GetOptions(source: Source.cache));
  }
  final existingMaterials = (snap.data()?['materials'] as List?) ?? [];
  final batch = FirebaseFirestore.instance.batch();
  // 저장할 때 부속만 더했으므로(튜브는 재단 계획에서 뺀다) 부속만 뺀다.
  batch.update(docRef, {
    'totalTubeUsed': FieldValue.increment(-totalTubeLength),
    'cutCount': FieldValue.increment(-cutCountOf(cutRecords)),
    'materials': subtractMaterialsUsage(existingMaterials, 0, fittingsList),
    // 되돌린 뒤 누적이 0이면 "마지막 작업" 날짜도 지운다(저장한 적이 없는 것으로 돌아간다).
    if (project.cutCount <= 0 && project.totalTubeUsed <= 1e-6)
      'lastCutAt': FieldValue.delete(),
  });

  if (cutRecords.isNotEmpty) {
    final savedAt = cutRecords.first.timestamp.toIso8601String();
    final q = docRef
        .collection(kCutRecordsSubcollection)
        .where('timestamp', isEqualTo: savedAt);
    // 방금 저장한 기록은 폰 사본에 있다. 없으면 서버를 5초까지.
    QuerySnapshot<Map<String, dynamic>>? made;
    try {
      made = await q.get(const GetOptions(source: Source.cache));
    } catch (_) {}
    if (made == null || made.docs.isEmpty) {
      try {
        made = await q.get().timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    for (final d in made?.docs ?? const []) {
      batch.delete(d.reference);
    }
  }
  // 폰에 먼저 쓰이므로 서버 답은 8초까지만 기다린다.
  await batch.commit().timeout(const Duration(seconds: 8), onTimeout: () {});
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
    'totalTubeUsed': FieldValue.increment(-deletedRecord.usedWithKerf),
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
      showCuttingSnack(context, "뺄 자재가 없습니다.", isError: true);
    }
    return;
  }

  // 빼기 전에 창고에 모자란 자재를 알려 준다.
  final stock = await loadStockInfo();
  final takes = stockTakesFromMaterials(
    materials,
    barLengthByName: stock.barLengthByName,
    unitByName: stock.unitByName,
  );
  // 🚀 [고침] 예전에는 불출로 이미 나가 있는지도 같이 봤다. 불출을 없애서
  // 겹칠 일이 없어졌다(재고 수량은 재고조사에서 맞춘다).
  final warning = shortStockWarning(takes, stock.qtyByName);

  if (!context.mounted) return;
  final confirmed = await showCuttingConfirmDialog(
    context,
    title: "재고에서 빼시겠습니까?",
    message: warning.isEmpty
        ? "'$projectName'에서 쓴 자재를 창고 재고에서 뺍니다.\n\n"
              "${stockTakeLines(takes, stock.qtyByName)}"
        : "'$projectName'에서 쓴 자재를 창고 재고에서 뺍니다.\n\n"
              "${stockTakeLines(takes, stock.qtyByName)}\n\n$warning",
    confirmLabel: "빼기",
    icon: AppGlyph.stockOut,
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
    // 🚀 [고침] 기록에 남는 작업 이름이 형강은 "형강 컷팅 · 전선관",
    // 튜브는 "루마"처럼 모양이 달랐다. 형강 쪽으로 맞춘다.
    final result = await deductStockTakes(
      takes,
      projectName: '라인 컷팅 · $projectName',
      worker: who,
      projectId: projectId,
    );

    // 뺀 것만 지운다. 못 찾은 것은 남겨 둬서, 자재를 넣은 뒤 다시 뺄 수 있게 한다.
    // 확인 창이 떠 있는 사이 다른 기기가 저장해 늘어난 사용량은 남기도록, 지금 서버 것을 다시 읽어
    // 이번에 뺀 만큼만 뺀다(10-08: 처음 읽은 목록으로 통째로 써서 그 몫이 사라졌다).
    final leftNames = {for (final m in result.missing) m.name};
    List<dynamic> fresh = materials;
    try {
      fresh = ((await docRef.get().timeout(const Duration(seconds: 5))).data()?['materials'] as List?) ?? materials;
    } catch (_) {}
    await docRef
        .update({
          'materials': materialsAfterDeduct(
            fresh,
            [
              for (final raw in materials)
                if (raw is Map &&
                    !leftNames.contains(
                      (raw['db_name'] ?? raw['name'] ?? '').toString().trim(),
                    ))
                  raw,
            ],
          ),
        })
        .timeout(const Duration(seconds: 8), onTimeout: () {});

    if (context.mounted) Navigator.pop(context);
    if (context.mounted) await showStockDeductResult(context, result);
  } catch (e) {
    debugPrint('재고 차감 실패: $e');
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) {
      // 예외 원문(영어)을 그대로 붙이지 않는다.
      showCuttingSnack(
        context,
        "재고에서 빼지 못했습니다. 통신을 확인하고 다시 해 보십시오.",
        isError: true,
      );
    }
  }
}
