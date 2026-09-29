// 작업 일지 "AI로 다듬기" 서버 호출. 앱에는 키가 없고, 로그인한 사용자가 서버 함수
// (functions/index.js polishDailyNote)를 부른다. 실패하면 글은 그대로 두고 이유만 알려 준다.
import 'package:cloud_functions/cloud_functions.dart';

class AiPolishResult {
  final String? text;
  final String? error;
  final int? remaining;
  const AiPolishResult.ok(String this.text, {this.remaining}) : error = null;
  const AiPolishResult.fail(String this.error) : text = null, remaining = null;
  bool get ok => text != null;
}

typedef AiPolishCall = Future<AiPolishResult> Function(String text);

/// 실제 서버 호출.
Future<AiPolishResult> callAiPolish(String text) async {
  try {
    final callable = FirebaseFunctions.instanceFor(
      region: 'asia-northeast3',
    ).httpsCallable('polishDailyNote', options: HttpsCallableOptions(timeout: const Duration(seconds: 30)));
    final res = await callable.call<Map<Object?, Object?>>({'text': text});
    final out = res.data['text'];
    if (out is! String || out.trim().isEmpty) {
      return const AiPolishResult.fail('AI가 빈 답을 보냈습니다');
    }
    final rem = res.data['remaining'];
    return AiPolishResult.ok(out, remaining: rem is int ? rem : null);
  } on FirebaseFunctionsException catch (e) {
    return AiPolishResult.fail(aiPolishErrorMessage(e.code, e.message));
  } catch (_) {
    return const AiPolishResult.fail('인터넷이 연결되어 있는지 확인해 주십시오');
  }
}

/// 서버 오류 코드를 사용자에게 보일 말로.
String aiPolishErrorMessage(String code, String? serverMessage) {
  switch (code) {
    case 'unauthenticated':
      return '로그인한 뒤에 쓸 수 있습니다';
    case 'resource-exhausted':
      return serverMessage ?? '오늘 횟수를 다 썼습니다';
    case 'invalid-argument':
      return serverMessage ?? '글을 확인해 주십시오';
    case 'unavailable':
    case 'deadline-exceeded':
      return 'AI가 지금 응답하지 않습니다. 잠시 뒤에 다시 눌러 주십시오';
    default:
      return 'AI 다듬기에 실패했습니다';
  }
}
