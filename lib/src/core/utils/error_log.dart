import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🚀 앱에서 난 오류를 최근 20개까지 기기에 남긴다(앱 상태 화면에서 보고 복사해 보낼 수 있다).
// 오류가 나도 화면에 잠깐 뜨고 사라져서 나중에 원인을 알 수 없던 문제를 줄이려는 기록이다.

const String _kPrefErrorLog = 'app_error_log';
const int kMaxErrorLog = 20;
const String _sep = ''; // 시각·위치·내용을 나누는 표시(내용에 나올 일이 없는 문자)

class ErrorEntry {
  final DateTime at;
  final String where;
  final String message;
  const ErrorEntry(this.at, this.where, this.message);
}

String _oneLine(String s, int max) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length > max ? '${t.substring(0, max)}…' : t;
}

/// 기록 한 줄을 더한다. 최근 [max]개만 남긴다(오래된 것이 앞).
List<String> addErrorLog(
  List<String> raw,
  DateTime at,
  String where,
  String message, {
  int max = kMaxErrorLog,
}) {
  final out = [
    ...raw,
    [
      at.toIso8601String(),
      _oneLine(where, 40),
      _oneLine(message, 300),
    ].join(_sep),
  ];
  return out.length > max ? out.sublist(out.length - max) : out;
}

/// 저장된 줄들을 읽는다. 읽을 수 없는 줄은 건너뛴다.
List<ErrorEntry> parseErrorLog(List<String> raw) {
  final out = <ErrorEntry>[];
  for (final line in raw) {
    final p = line.split(_sep);
    if (p.length < 3) continue;
    final t = DateTime.tryParse(p[0]);
    if (t == null) continue;
    out.add(ErrorEntry(t, p[1], p.sublist(2).join(_sep)));
  }
  return out;
}

/// 보내기 쉬운 글로 만든다(최근 것이 위).
String errorsAsText(List<ErrorEntry> entries) {
  if (entries.isEmpty) return '기록된 오류가 없습니다.';
  String two(int n) => n.toString().padLeft(2, '0');
  return [
    for (final e in entries.reversed)
      '${e.at.month}/${e.at.day} ${two(e.at.hour)}:${two(e.at.minute)} [${e.where}] ${e.message}',
  ].join('\n');
}

/// 오류를 기록한다. 기록하다가 또 실패해도 앱은 그대로 둔다.
Future<void> recordError(String where, Object error, {DateTime? at}) async {
  try {
    debugPrint('오류 기록 [$where] $error');
    final p = await SharedPreferences.getInstance();
    final list = addErrorLog(
      p.getStringList(_kPrefErrorLog) ?? const <String>[],
      at ?? DateTime.now(),
      where,
      error.toString(),
    );
    await p.setStringList(_kPrefErrorLog, list);
  } catch (_) {}
}

Future<List<ErrorEntry>> loadErrors() async {
  final p = await SharedPreferences.getInstance();
  return parseErrorLog(p.getStringList(_kPrefErrorLog) ?? const <String>[]);
}

Future<void> clearErrors() async {
  final p = await SharedPreferences.getInstance();
  await p.remove(_kPrefErrorLog);
}
