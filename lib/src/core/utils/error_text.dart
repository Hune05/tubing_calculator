// 화면에 보일 오류 까닭을 한국어로 바꾼다.
// 10-09 7차 점검: "PDF를 만들지 못했습니다: PlatformException(...)"처럼 영어 원문이 화면에
// 그대로 나오던 곳을 이것으로 바꿨다. 원문은 앱 상태 화면의 오류 기록에 남긴다.
library;

import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/services.dart' show PlatformException;

import 'error_log.dart';

final RegExp _hangul = RegExp(r'[가-힣]');
final RegExp _typePrefix = RegExp(
  r'^(Exception|Bad state|Invalid argument\(s\)|[A-Za-z]*(Error|Exception)): ',
);

/// 오류 [e]를 사용자에게 보일 짧은 한국어 까닭으로 바꾼다(기록은 하지 않는다).
String errorReasonText(Object e) {
  if (e is TimeoutException) return '응답이 없습니다. 통신을 확인하십시오.';
  if (e is FirebaseException) {
    switch (e.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
      case 'retry-limit-exceeded':
        return '서버에 닿지 않습니다. 통신을 확인하십시오.';
      case 'permission-denied':
      case 'unauthorized':
        return '권한이 없습니다(사용 승인·로그인 확인).';
      case 'unauthenticated':
        return '로그인이 풀렸습니다. 다시 로그인하십시오.';
      case 'not-found':
      case 'object-not-found':
        return '서버에 자료가 없습니다.';
      case 'resource-exhausted':
      case 'quota-exceeded':
        return '서버 사용 한도를 넘었습니다. 잠시 뒤 다시 하십시오.';
      case 'cancelled':
      case 'canceled':
        return '취소되었습니다.';
    }
    return '서버 오류입니다.';
  }
  // dart:io 형식은 이름으로 가린다(웹·PC 빌드에서도 이 파일을 쓸 수 있게).
  final type = e.runtimeType.toString();
  if (const {
    'SocketException',
    'ClientException',
    'HttpException',
    'HandshakeException',
  }.contains(type)) {
    return '통신이 없습니다. 통신을 확인하십시오.';
  }
  if (const {
    'FileSystemException',
    'PathNotFoundException',
    'PathAccessException',
    'PathExistsException',
  }.contains(type)) {
    return '파일을 읽거나 쓰지 못했습니다(저장 공간·권한 확인).';
  }
  if (e is FormatException) return '파일이나 자료 형식이 맞지 않습니다.';
  if (e is PlatformException) {
    final m = e.message ?? '';
    if (_hangul.hasMatch(m)) return m;
    return '기기 기능 오류입니다.';
  }
  // 앱이 직접 낸 한국어 오류는 머리말만 떼고 그대로 보인다.
  final s = e.toString().replaceFirst(_typePrefix, '').trim();
  if (_hangul.hasMatch(s)) return s;
  return '알 수 없는 오류입니다(앱 상태 화면에 기록).';
}

/// 화면에 보일 "[what]: 까닭" 글을 만들고, 원문은 오류 기록에 남긴다.
String failText(String what, Object e) {
  unawaited(recordError(what, e));
  return '$what: ${errorReasonText(e)}';
}

/// 까닭만 돌려주고, 원문은 [where]라는 이름으로 오류 기록에 남긴다.
String loggedReason(String where, Object e) {
  unawaited(recordError(where, e));
  return errorReasonText(e);
}
