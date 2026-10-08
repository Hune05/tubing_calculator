// 10-09 7차 점검: 화면에 영어 오류 원문이 그대로 나오던 것을 한국어 까닭으로.
import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/error_log.dart';
import 'package:tubing_calculator/src/core/utils/error_text.dart';

class SocketException implements Exception {
  @override
  String toString() => 'SocketException: Failed host lookup';
}

class _KoError implements Exception {
  final String message;
  _KoError(this.message);
  @override
  String toString() => message;
}

bool _hasLatinWord(String s) => RegExp(r'[A-Za-z]{4,}').hasMatch(s);

void main() {
  test('흔한 오류는 한국어 까닭으로 바뀌고 영어 원문이 안 나온다', () {
    final cases = <Object>[
      TimeoutException('t'),
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable', message: 'The service is currently unavailable.'),
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied', message: 'Missing or insufficient permissions.'),
      FirebaseException(plugin: 'firebase_storage', code: 'quota-exceeded'),
      SocketException(),
      const FormatException('Unexpected character'),
      PlatformException(code: 'error', message: 'Something failed in native code'),
      StateError('Bad things'),
      Exception('boom'),
    ];
    for (final e in cases) {
      final t = errorReasonText(e);
      expect(RegExp(r'[가-힣]').hasMatch(t), isTrue, reason: '$e → $t');
      expect(_hasLatinWord(t), isFalse, reason: '$e → $t');
    }
    expect(errorReasonText(TimeoutException('t')), contains('통신'));
    expect(
      errorReasonText(FirebaseException(plugin: 'x', code: 'permission-denied')),
      contains('권한'),
    );
  });

  test('앱이 낸 한국어 오류는 머리말만 떼고 그대로 보인다', () {
    expect(errorReasonText(_KoError('카카오 키가 없습니다.')), '카카오 키가 없습니다.');
    expect(errorReasonText(StateError('사진이 없습니다.')), '사진이 없습니다.');
    expect(errorReasonText(Exception('저장 공간이 모자랍니다.')), '저장 공간이 모자랍니다.');
  });

  test('모르는 서버 오류도 영어 원문 없이 짧게', () {
    expect(
      errorReasonText(FirebaseException(plugin: 'x', code: 'aborted', message: 'Transaction aborted')),
      '서버 오류입니다.',
    );
  });

  test('failText는 "무엇: 까닭"을 주고 원문은 오류 기록에 남긴다', () async {
    SharedPreferences.setMockInitialValues({});
    final t = failText('PDF를 만들지 못했습니다', Exception('Null check operator used on a null value'));
    expect(t, startsWith('PDF를 만들지 못했습니다: '));
    expect(t, isNot(contains('Null check')));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    final logged = await loadErrors();
    expect(logged.single.where, 'PDF를 만들지 못했습니다');
    expect(logged.single.message, contains('Null check'));
  });
}
