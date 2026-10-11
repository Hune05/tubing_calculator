// 형강 브라켓 → 다른 화면으로 넘기기(10-11, 상용 앱 비교 14·15번).
//  · 형강 컷팅: 자를 것을 새 작업(프로젝트) 하나로 만든다. 기존 작업은 건드리지 않는다. 같은 규격·길이는 한 줄로 합치고
//    메모에 품번을 적는다. 통신이 없어도 바로 돌아오게 서버 쓰기는 기다리지 않는다(앱의 저장 대기와 같이 나중에 올라감).
//  · 철판 가공: 베이스 판·벽 붙임 판을 레이저 절단 평판(가로·세로·두께·구멍)으로 넘긴다.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/models/steel_cutting_project_model.dart';
import '../../data/ownership.dart';
import 'bracket_calc.dart';

/// 형강 컷팅 작업 만들기: (작업 이름, 줄들, 원자재 길이) → 만든 작업(실패면 null).
typedef BracketProjectCreator =
    Future<SteelCuttingProject?> Function(
      String name,
      List<SteelCutItem> items,
      double stockLength,
    );

/// 규격 이름 → 형강 컷팅 종류(SteelCategory.id).
String bracketSteelCategory(String spec) {
  final sp = spec.indexOf(' ');
  final kind = sp > 0 ? spec.substring(0, sp) : spec;
  return switch (kind) {
    '앵글' => 'ANGLE',
    '찬넬' => 'CHANNEL',
    '평철' => 'FLAT',
    '각파이프' => 'SQUARE',
    'H형강' => 'BEAM',
    '스트럿' => 'STRUT',
    '립C형강' => 'LIPC',
    '부등변앵글' => 'UNEQUAL',
    '전산볼트' => 'ROD',
    _ => 'CUSTOM',
  };
}

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}

/// 자를 것 줄들: [plans] (브라켓 이름, 계산, 세트 수). 같은 규격·길이는 합친다.
List<SteelCutItem> bracketCutItems(List<(String, BracketPlan, int)> plans) {
  final byKey = <String, (String, double, int, List<String>)>{};
  for (final (name, plan, sets) in plans) {
    for (final p in plan.pieces) {
      if (p.kind != BracketPieceKind.member && p.kind != BracketPieceKind.rod) {
        continue;
      }
      if (p.length <= 0) continue;
      final key = '${p.spec}|${p.length.toStringAsFixed(1)}';
      final cur = byKey[key];
      final tag =
          '${name.isEmpty ? '' : '$name '}${p.title}${p.ends == '양 끝 직각' ? '' : ' (${p.ends.split(' (').first})'}';
      byKey[key] = (
        p.spec,
        p.length,
        (cur?.$3 ?? 0) + p.qty * sets,
        [...?cur?.$4, if (!(cur?.$4.contains(tag) ?? false)) tag],
      );
    }
  }
  final now = DateTime.now().millisecondsSinceEpoch;
  var k = 0;
  return [
    for (final (spec, len, qty, tags) in byKey.values)
      SteelCutItem(
        id: '${now}_${k++}',
        category: bracketSteelCategory(spec),
        shapeLabel: spec,
        length: double.parse(len.toStringAsFixed(1)),
        qty: qty,
        note: '브라켓 ${tags.join(', ')}',
      ),
  ];
}

/// 형강 컷팅 새 작업(서버). 쓰기 완료는 기다리지 않는다(통신 없는 현장에서도 바로 돌아옴).
Future<SteelCuttingProject?> createBracketSteelProject(
  String name,
  List<SteelCutItem> items,
  double stockLength,
) async {
  try {
    final ref = FirebaseFirestore.instance
        .collection(kSteelCuttingProjectsCollection)
        .doc();
    final now = DateTime.now();
    final project = SteelCuttingProject(
      id: ref.id,
      name: name,
      createdAt: now,
      stockLength: stockLength > 0 ? stockLength : 6000,
      items: items,
    );
    ref
        .set({
          ...project.toMap(),
          ...ownerFieldsFor(shared: false, uid: currentUid()),
        })
        .catchError((_) {});
    return project;
  } catch (_) {
    return null;
  }
}

/// 판 → 철판 가공(레이저 절단 평판) 처음 값. 구멍 자리는 판 왼쪽 아래 기준(철판 가공 약속)으로 옮긴다.
Map<String, Object?> bracketPlateToPlateInitial(
  BracketPlate pl, {
  required String job,
  required int qty,
  required String material,
}) => {
  'sh': 'flat',
  'mat': material == 'SUS304' ? 'stainless' : 'steel',
  'jn': job.trim().isEmpty ? '브라켓 ${pl.name}' : '${job.trim()} ${pl.name}',
  't': _f(pl.t),
  'len': _f(pl.w),
  'wid': _f(pl.l),
  'n': '$qty',
  'holes': [
    for (final q in pl.holes)
      {
        'f': 0,
        'u': q.dx,
        'v': pl.l - q.dy,
        'd': pl.holeDia,
        's': 0.0,
        'a': 0.0,
      },
  ],
};
