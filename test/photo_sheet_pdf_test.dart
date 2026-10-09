// 사진대지 PDF(10-10): 작업 일지 사진을 날짜 순서로 모아, 한 쪽에 3장씩 일자·공종·구분·내용 표와 함께 넣는다.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/photo_sheet_pdf.dart';

// 1×1 PNG(사진 대신).
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

Map<String, dynamic> _log() => {
  'name': 'TEST 현장',
  'daily_reports': [
    {
      'date': '10/09',
      'dateISO': '2026-10-09',
      'work_type': ['신규 설치', '검사/시험'],
      'note': '1층 튜브 배관\n둘째 줄',
      'image_paths': ['/b1.jpg', '/b2.jpg'],
      'image_tags': {'/b1.jpg': '작업 전'},
      'image_captions': {'/b2.jpg': '서포트 설치'},
    },
    {
      'date': '10/08',
      'dateISO': '2026-10-08',
      'work_type': '라인 수정',
      'note': '특이사항 없음',
      'image_path': '/a1.jpg',
    },
    {
      'date': '10/10',
      'dateISO': '2026-10-10',
      'note': '사진 없음',
    },
    {
      'date': '09/01',
      'dateISO': '2026-09-01',
      'image_paths': ['/old.jpg'],
    },
  ],
};

int _pageCount(Uint8List pdf) =>
    RegExp(r'/Type\s*/Page[^s]').allMatches(latin1.decode(pdf)).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('기간 안 일지 사진을 날짜 순서로 모으고, 설명이 없으면 작업 내용 첫 줄을 쓴다', () {
    final items = photoSheetItems(
      _log(),
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 31),
    );
    expect(items.map((e) => e.path), ['/a1.jpg', '/b1.jpg', '/b2.jpg']);
    expect(items[0].workType, '라인 수정');
    expect(items[0].content, ''); // "특이사항 없음"은 넣지 않는다
    expect(items[1].workType, '신규 설치·검사/시험');
    expect(items[1].tag, '작업 전');
    expect(items[1].content, '1층 튜브 배관');
    expect(items[2].content, '서포트 설치');
    expect(items[2].date, DateTime(2026, 10, 9));
  });

  test('한 쪽에 3장: 4장이면 2쪽, 못 읽은 사진도 칸은 남긴다', () async {
    final items = [
      for (int i = 0; i < 4; i++)
        PhotoSheetItem(path: '/p$i.jpg', date: DateTime(2026, 10, 10)),
    ];
    var progress = 0;
    final pdf = await buildPhotoSheetPdf(
      project: 'TEST',
      period: '2026.10.10 ~ 2026.10.10',
      items: items,
      load: (p) async => p == '/p2.jpg' ? null : _png,
      onProgress: (n, _) => progress = n,
    );
    expect(progress, 4);
    expect(_pageCount(pdf), 2);
  });

  test('파일 이름: 하루면 날짜 하나, 기간이면 처음-끝, 이름에 못 쓰는 글자는 바꾼다', () {
    expect(
      photoSheetFileName('루마/2층', DateTime(2026, 10, 10), DateTime(2026, 10, 10)),
      '사진대지_루마_2층_20261010.pdf',
    );
    expect(
      photoSheetFileName('A', DateTime(2026, 10, 1), DateTime(2026, 10, 10)),
      '사진대지_A_20261001-20261010.pdf',
    );
  });
}
