// 10-09 8차: 서버 사진을 크게 보면(폭 무한대) memCacheWidth 셈에서 예외가 나 화면이 깨졌다(오늘 회귀).
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/photo_store.dart';

void main() {
  testWidgets('폭·높이 무한대인 서버 사진도 예외 없이 그린다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PhotoImage(
            'https://example.com/a.jpg',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final img = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(img.memCacheWidth, isNull);
  });

  testWidgets('작은 칸은 그 크기로 줄여 메모리에 둔다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PhotoImage('https://example.com/a.jpg', width: 80, height: 80))),
    );
    final img = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(img.memCacheWidth, isNotNull);
  });
}
