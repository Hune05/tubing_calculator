import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/data/models/cart_item_model.dart';
import 'package:tubing_calculator/src/data/models/steel_cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/mobile_my_schedule_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_phase.dart';

// 내 프로젝트 밖(형강 컷팅·자재 주문·내 일정)의 순수한 부분에 대한 기본 테스트.
// 화면 자체는 Firebase에 붙어 있어 여기서는 다루지 않고, 저장 형식과 합계·색·아이콘 규칙만 지킨다.
void main() {
  group('형강 컷팅 항목·프로젝트', () {
    SteelCutItem item(double len, int qty) => SteelCutItem(
      id: 'i',
      category: 'ANGLE',
      shapeLabel: 'L50',
      length: len,
      qty: qty,
    );

    test('항목 저장·불러오기가 그대로 돌아온다', () {
      final a = SteelCutItem(
        id: 'x1',
        category: 'CHANNEL',
        shapeLabel: 'C100',
        length: 1234.5,
        qty: 3,
        note: '메모',
      );
      final b = SteelCutItem.fromMap(a.toMap());
      expect(b.id, 'x1');
      expect(b.category, 'CHANNEL');
      expect(b.shapeLabel, 'C100');
      expect(b.length, 1234.5);
      expect(b.qty, 3);
      expect(b.note, '메모');
      expect(b.totalLength, 3703.5);
    });

    test('빠진 값은 기본값으로 채운다', () {
      final b = SteelCutItem.fromMap({});
      expect(b.category, 'CUSTOM');
      expect(b.shapeLabel, '규격 미지정');
      expect(b.length, 0.0);
      expect(b.qty, 1);
      expect(b.note, '');
    });

    test('정수로 저장된 길이·수량도 읽는다', () {
      final b = SteelCutItem.fromMap({'length': 1000, 'qty': 2});
      expect(b.length, 1000.0);
      expect(b.qty, 2);
    });

    test('총 개수·총 길이는 세트 배수를 곱한다', () {
      final p = SteelCuttingProject(
        id: 'p',
        name: 'P',
        createdAt: DateTime(2026, 9, 1),
        setMultiplier: 3,
        items: [item(1000, 2), item(500.5, 4)],
      );
      expect(p.totalPieces, (2 + 4) * 3);
      expect(p.totalLength, (2000 + 2002) * 3);
    });

    test('항목이 없으면 합계는 0', () {
      final p = SteelCuttingProject(
        id: 'p',
        name: 'P',
        createdAt: DateTime(2026, 9, 1),
      );
      expect(p.totalPieces, 0);
      expect(p.totalLength, 0.0);
    });

    test('프로젝트 저장·불러오기', () {
      final p = SteelCuttingProject(
        id: 'p',
        name: '현장A',
        createdAt: DateTime(2026, 9, 1, 8, 30),
        currentWorker: '홍길동',
        stockLength: 5500,
        setMultiplier: 2,
        items: [item(1200, 5)],
      );
      final q = SteelCuttingProject.fromMap('p2', p.toMap());
      expect(q.id, 'p2');
      expect(q.name, '현장A');
      expect(q.createdAt, DateTime(2026, 9, 1, 8, 30));
      expect(q.currentWorker, '홍길동');
      expect(q.stockLength, 5500);
      expect(q.setMultiplier, 2);
      expect(q.items.length, 1);
      expect(q.totalPieces, 10);
    });

    test('빈 프로젝트 문서도 죽지 않고 기본값을 쓴다', () {
      final q = SteelCuttingProject.fromMap('p', {});
      expect(q.name, '이름 없음');
      expect(q.stockLength, 6000.0);
      expect(q.setMultiplier, 1);
      expect(q.items, isEmpty);
    });
  });

  group('자재 주문 장바구니 항목', () {
    test('저장·불러오기(사진·규격 포함)', () {
      final a = CartItemModel(
        title: '엘보 1/2',
        qty: '10',
        type: '피팅',
        fabSpec: '90도',
        photos: ['a.jpg', 'b.jpg'],
      );
      final b = CartItemModel.fromMap(a.toMap());
      expect(b.title, '엘보 1/2');
      expect(b.qty, '10');
      expect(b.type, '피팅');
      expect(b.fabSpec, '90도');
      expect(b.photos, ['a.jpg', 'b.jpg']);
    });

    test('빠진 값은 기본값(일반 자재)', () {
      final b = CartItemModel.fromMap({});
      expect(b.title, '');
      expect(b.type, '일반 자재');
      expect(b.fabSpec, isNull);
      expect(b.photos, isNull);
    });
  });

  group('내 일정 색·아이콘', () {
    test('종류마다 색과 아이콘이 있고, 모르는 종류는 기타 모양', () {
      for (final k in kScheduleColors.keys) {
        expect(colorForCategory(k), kScheduleColors[k]);
        expect(iconForCategory(k), isA<IconData>());
      }
      expect(colorForCategory('없는종류'), kScheduleColors['기타']);
      expect(iconForCategory('없는종류'), Icons.event_note_outlined);
      expect(iconForCategory('개인'), Icons.person_outline_rounded);
      expect(iconForCategory('납기일'), Icons.event_available_outlined);
    });

    test('프로젝트 색은 같은 프로젝트면 늘 같다', () {
      expect(
        colorForProject('1789000000001'),
        colorForProject('1789000000001'),
      );
      expect(colorForProject(''), isA<Color>());
    });

    test('프로젝트 색은 목록에 있는 색만 쓴다', () {
      for (final id in [
        'a',
        'b',
        'c',
        '1789000000001',
        '1789000000002',
        '루마',
      ]) {
        expect(kProjectPalette.contains(colorForProject(id)), true);
      }
    });
  });
}
