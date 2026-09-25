// 사진 정리: 새 주소로 바꾼 일지·이슈에 updatedAt을 찍는지(점검 6번).
// 안 찍으면 다른 폰이 옛 주소를 들고 저장할 때 합치기가 옛 주소를 다시 쓴다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/photo_store.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_merge.dart';

void main() {
  const oldUrl = 'https://x/old.jpg';
  const newUrl = 'https://x/new.jpg';

  Map<String, dynamic> log() => {
    'id': 'p1',
    'daily_reports': [
      {
        'id': 'r1',
        'updatedAt': '2026-09-01T00:00:00.000',
        'image_paths': [oldUrl],
        'image_captions': {oldUrl: '배관'},
        'image_tags': {oldUrl: '전'},
      },
      {
        'id': 'r2',
        'updatedAt': '2026-09-01T00:00:00.000',
        'image_paths': ['https://x/other.jpg'],
      },
    ],
    'punch_lists': [
      {
        'id': 'i1',
        'updatedAt': '2026-09-01T00:00:00.000',
        'resolution_images': [oldUrl],
      },
    ],
  };

  test('주소가 바뀐 일지·이슈만 새 시각을 찍고, 설명·태그도 새 주소로', () {
    final l = log();
    replacePhotoUrls(l, {oldUrl: newUrl});
    final r1 = (l['daily_reports'] as List)[0] as Map;
    final r2 = (l['daily_reports'] as List)[1] as Map;
    final i1 = (l['punch_lists'] as List)[0] as Map;
    expect(r1['image_paths'], [newUrl]);
    expect(r1['image_captions'], {newUrl: '배관'});
    expect(r1['image_tags'], {newUrl: '전'});
    expect(i1['resolution_images'], [newUrl]);
    expect(r1['updatedAt'], isNot('2026-09-01T00:00:00.000'));
    expect(i1['updatedAt'], isNot('2026-09-01T00:00:00.000'));
    expect(r2['updatedAt'], '2026-09-01T00:00:00.000');
  });

  test('다른 폰이 옛 주소를 들고 저장해도 새 주소가 이긴다', () {
    final server = log();
    replacePhotoUrls(server, {oldUrl: newUrl});
    final otherPhone = log(); // 사진 정리 전 것을 들고 있는 폰
    final merged = mergeProjectDocs(local: otherPhone, server: server);
    final r1 = (merged['daily_reports'] as List).firstWhere(
      (e) => e['id'] == 'r1',
    );
    // 예전: 시각이 같아 폰 것(옛 주소)이 이겨, 지운 파일을 가리켰다.
    expect(r1['image_paths'], [newUrl]);
  });
}
