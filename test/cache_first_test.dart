// 폰에 있는 것 먼저, 서버 것은 뒤에서(UI 디자인 제안 D-F).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_components.dart';
import 'package:tubing_calculator/src/core/theme/app_theme.dart';
import 'package:tubing_calculator/src/core/utils/cache_first.dart';

void main() {
  group('loadCacheFirst', () {
    test('폰 목록을 먼저 넘기고, 서버 목록이 오면 다시 넘긴다', () async {
      final got = <(List<int>, bool)>[];
      final server = Completer<List<int>>();
      final done = loadCacheFirst<List<int>>(
        cached: () async => [1, 2],
        fresh: () => server.future,
        isEmpty: (l) => l.isEmpty,
        onData: (d, {required fresh}) => got.add((d, fresh)),
      );
      await Future<void>.delayed(Duration.zero);
      // 서버가 아직 답하지 않아도 폰 목록은 이미 그려졌다.
      expect(got.length, 1);
      expect(got.single.$1, [1, 2]);
      expect(got.single.$2, isFalse);
      server.complete([1, 2, 3]);
      await done;
      expect(got.last.$1, [1, 2, 3]);
      expect(got.last.$2, isTrue);
    });

    test('폰에 없으면(빈 목록·실패) 서버 것만 넘긴다', () async {
      for (final cached in <Future<List<int>?> Function()>[
        () async => <int>[],
        () async => null,
        () async => throw StateError('캐시 없음'),
      ]) {
        final got = <bool>[];
        await loadCacheFirst<List<int>>(
          cached: cached,
          fresh: () async => [9],
          isEmpty: (l) => l.isEmpty,
          onData: (d, {required fresh}) => got.add(fresh),
        );
        expect(got, [true]);
      }
    });

    test('서버가 실패하면 먼저 보인 폰 목록은 그대로 두고 알린다', () async {
      final got = <List<int>>[];
      bool? sawCache;
      await loadCacheFirst<List<int>>(
        cached: () async => [5],
        fresh: () async => throw TimeoutException('통신 없음'),
        isEmpty: (l) => l.isEmpty,
        onData: (d, {required fresh}) => got.add(d),
        onError: (e, {required hadCache}) => sawCache = hadCache,
      );
      expect(got, [
        [5],
      ]);
      expect(sawCache, isTrue);
    });
  });

  testWidgets('받는 중이면 머리 아래 가는 줄, 아니면 자리 없음', (tester) async {
    Future<void> pump(bool on) => tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('내 프로젝트'),
            bottom: refreshingBar(on, key: const Key('bar')),
          ),
        ),
      ),
    );
    await pump(true);
    expect(find.byKey(const Key('bar')), findsOneWidget);
    await pump(false);
    expect(find.byKey(const Key('bar')), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
