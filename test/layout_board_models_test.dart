import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart'
    as mob;
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/tablet_layout_board_page.dart'
    as tab;

// 배치도(모바일/태블릿 두 화면)가 같이 쓰는 데이터 모양과 치수 계산을 지킨다.
// 두 화면이 같은 규칙을 쓰는지도 함께 확인한다(나중에 하나로 합쳐도 이 테스트가 그대로 통과해야 한다).
void main() {
  group('놓은 모듈 저장·불러오기', () {
    test('모든 값이 그대로 돌아온다', () {
      final a = mob.PlacedItem(
        id: 'm1',
        name: 'ABS덕트 40mm',
        position: const Offset(10.5, 20),
        width: 40,
        height: 200,
        isLocked: true,
      );
      final b = mob.PlacedItem.fromJson(a.toJson());
      expect(b.id, 'm1');
      expect(b.name, 'ABS덕트 40mm');
      expect(b.position, const Offset(10.5, 20));
      expect(b.width, 40);
      expect(b.height, 200);
      expect(b.isLocked, true);
      expect(b.isSelected, false);
      expect(b.center, const Offset(30.5, 120));
      expect(b.boundingBox, const Rect.fromLTWH(10.5, 20, 40, 200));
    });

    test('빠진 값은 기본값(이름 없음·80×80·잠금 해제)', () {
      final b = mob.PlacedItem.fromJson({'id': 'x', 'x': 1, 'y': 2});
      expect(b.name, '이름 없음');
      expect(b.width, 80.0);
      expect(b.height, 80.0);
      expect(b.isLocked, false);
    });

    test('벽 기준점 저장·불러오기', () {
      final w = mob.WallPoint(position: const Offset(5, 6));
      expect(w.id, 'wall_5.0_6.0');
      final j = w.toJson();
      expect(j['type'], 'wall');
      final r = mob.WallPoint.fromJson(j);
      expect(r.position, const Offset(5, 6));
      expect(r.boundingBox, const Rect.fromLTWH(5, 6, 0, 0));
    });
  });

  group('치수선 저장·불러오기', () {
    mob.PlacedDimension dim({
      mob.DimensionType type = mob.DimensionType.center,
      bool diagonal = false,
    }) => mob.PlacedDimension(
      id: 'd1',
      p1: mob.PlacedItem(id: 'a', name: 'A', position: Offset.zero),
      p2: mob.WallPoint(position: const Offset(300, 40)),
      type: type,
      note: '케이블 트레이 구간',
      minGapMm: 150,
      isDiagonal: diagonal,
      isSafetyCritical: true,
    );

    test('메모·최소 간격·대각선·안전 표시까지 그대로 돌아온다', () {
      final b = mob.PlacedDimension.fromJson(
        dim(type: mob.DimensionType.edge, diagonal: true).toJson(),
      );
      expect(b.id, 'd1');
      expect(b.type, mob.DimensionType.edge);
      expect(b.note, '케이블 트레이 구간');
      expect(b.minGapMm, 150);
      expect(b.isDiagonal, true);
      expect(b.isSafetyCritical, true);
      expect(b.p1, isA<mob.PlacedItem>());
      expect(b.p2, isA<mob.WallPoint>());
      expect(b.p2.center, const Offset(300, 40));
    });

    test('옛날에 저장한 치수선(새 필드 없음)도 읽는다', () {
      final j = dim().toJson()
        ..remove('note')
        ..remove('minGapMm')
        ..remove('isDiagonal')
        ..remove('isSafetyCritical');
      final b = mob.PlacedDimension.fromJson(j);
      expect(b.note, isNull);
      expect(b.minGapMm, isNull);
      expect(b.isDiagonal, false);
      expect(b.isSafetyCritical, false);
    });
  });

  group('치수 계산(센터·측면·대각선)', () {
    // A: (0,0)~(100,100), B: (300,20)~(400,120) → 가로로 떨어져 있다.
    mob.PlacedDimension pair(mob.DimensionType t, {bool diag = false}) =>
        mob.PlacedDimension(
          id: 'd',
          p1: mob.PlacedItem(
            id: 'a',
            name: 'A',
            position: Offset.zero,
            width: 100,
            height: 100,
          ),
          p2: mob.PlacedItem(
            id: 'b',
            name: 'B',
            position: const Offset(300, 20),
            width: 100,
            height: 100,
          ),
          type: t,
          isDiagonal: diag,
        );

    test('센터: 중심끼리, 가로로 정렬해서 잰다', () {
      final r = mob.computeDimensionEndpoints(pair(mob.DimensionType.center));
      expect(r.p1, const Offset(50, 50));
      expect(r.p2, const Offset(350, 50)); // 세로는 첫 점에 맞춘다
      expect(r.distance, 300);
    });

    test('측면: 마주 보는 옆면 사이 거리', () {
      final r = mob.computeDimensionEndpoints(pair(mob.DimensionType.edge));
      expect(r.p1.dx, 100); // A의 오른쪽 면
      expect(r.p2.dx, 300); // B의 왼쪽 면
      expect(r.distance, 200);
    });

    test('대각선: 두 중심 사이 직선거리', () {
      final r = mob.computeDimensionEndpoints(
        pair(mob.DimensionType.center, diag: true),
      );
      expect(r.p1, const Offset(50, 50));
      expect(r.p2, const Offset(350, 70));
      expect(r.distance, closeTo(300.665, 0.001));
    });

    test('세로로 떨어진 경우 측면은 위아래 면 사이', () {
      final d = mob.PlacedDimension(
        id: 'd',
        p1: mob.PlacedItem(
          id: 'a',
          name: 'A',
          position: Offset.zero,
          width: 100,
          height: 100,
        ),
        p2: mob.PlacedItem(
          id: 'b',
          name: 'B',
          position: const Offset(10, 400),
          width: 100,
          height: 100,
        ),
        type: mob.DimensionType.edge,
      );
      final r = mob.computeDimensionEndpoints(d);
      expect(r.p1.dy, 100);
      expect(r.p2.dy, 400);
      expect(r.distance, 300);
    });

    test('모바일과 태블릿 화면이 같은 답을 낸다', () {
      final m = mob.PlacedItem(
        id: 'a',
        name: 'A',
        position: const Offset(12, 34),
        width: 55,
        height: 77,
      );
      final n = mob.PlacedItem(
        id: 'b',
        name: 'B',
        position: const Offset(412, 134),
        width: 60,
        height: 90,
      );
      for (final t in [mob.DimensionType.center, mob.DimensionType.edge]) {
        for (final diag in [false, true]) {
          final a = mob.computeDimensionEndpoints(
            mob.PlacedDimension(
              id: 'd',
              p1: m,
              p2: n,
              type: t,
              isDiagonal: diag,
            ),
          );
          final tm = tab.PlacedItem.fromJson(m.toJson());
          final tn = tab.PlacedItem.fromJson(n.toJson());
          final b = tab.computeDimensionEndpoints(
            tab.PlacedDimension(
              id: 'd',
              p1: tm,
              p2: tn,
              type: tab.DimensionType.values.byName(t.name),
              isDiagonal: diag,
            ),
          );
          expect(b.p1, a.p1, reason: '$t diag=$diag');
          expect(b.p2, a.p2, reason: '$t diag=$diag');
          expect(b.distance, a.distance, reason: '$t diag=$diag');
        }
      }
    });
  });

  test('덕트 기본 크기 목록이 두 화면에서 같다', () {
    expect(
      [for (final p in mob.kDuctPresets) (p.name, p.width, p.height)],
      [for (final p in tab.kDuctPresets) (p.name, p.width, p.height)],
    );
  });
}
