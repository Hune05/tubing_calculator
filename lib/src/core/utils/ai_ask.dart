// 자료 검색 "AI에게 물어보기" 서버 호출. 앱 자료에서 답을 못 찾았을 때만 쓰는 보조 기능이다.
// 앱에는 키가 없고, 로그인한 사용자가 서버 함수(functions/index.js askFieldQuestion)를 부른다.
// 질문 글만 보낸다(프로젝트 이름·회사 자료는 보내지 않는다). AI가 원래 아는 지식으로 답하므로
// 틀릴 수 있다 — 화면에서 "AI 답변"임을 늘 표시하고, 안전 관련 질문에는 확인 경고를 더 붙인다.
import 'package:cloud_functions/cloud_functions.dart';

class AiAskResult {
  final String? text;
  final String? error;
  final int? remaining;
  const AiAskResult.ok(String this.text, {this.remaining}) : error = null;
  const AiAskResult.fail(String this.error) : text = null, remaining = null;
  bool get ok => text != null;
}

typedef AiAskCall = Future<AiAskResult> Function(String question);

/// 서버로 보낼 수 있는 질문 길이(서버와 같다).
const int kAiAskMaxChars = 300;

/// 실제 서버 호출.
Future<AiAskResult> callAiAsk(String question) async {
  try {
    final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
        .httpsCallable(
          'askFieldQuestion',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 40)),
        );
    final res = await callable.call<Map<Object?, Object?>>({'question': question});
    final out = res.data['text'];
    if (out is! String || out.trim().isEmpty) {
      return const AiAskResult.fail('AI가 빈 답을 보냈습니다');
    }
    final rem = res.data['remaining'];
    return AiAskResult.ok(cleanAiText(out), remaining: rem is int ? rem : null);
  } on FirebaseFunctionsException catch (e) {
    return AiAskResult.fail(aiAskErrorMessage(e.code, e.message));
  } catch (_) {
    return const AiAskResult.fail('통신이 되는지 확인해 주십시오. 앱 자료 검색은 통신 없이도 됩니다.');
  }
}

/// 서버 오류 코드를 사용자에게 보일 말로.
String aiAskErrorMessage(String code, String? serverMessage) {
  switch (code) {
    case 'permission-denied':
      // 10-09: 서버가 사용 승인을 받은 사람·관리자만 받는다.
      return '사용 승인을 받은 뒤에 쓸 수 있습니다(관리자에게 승인을 요청하십시오)';
    case 'unauthenticated':
      return '로그인한 뒤에 쓸 수 있습니다';
    case 'resource-exhausted':
      return serverMessage ?? '오늘 횟수를 다 썼습니다';
    case 'invalid-argument':
      return serverMessage ?? '질문을 확인해 주십시오';
    case 'unavailable':
    case 'deadline-exceeded':
      return 'AI가 지금 응답하지 않습니다. 통신을 확인하고 잠시 뒤에 다시 눌러 주십시오';
    default:
      return 'AI가 처리하지 못했습니다. 잠시 뒤에 다시 눌러 주십시오';
  }
}

const List<String> _safetyWords = [
  '압력', '고압', '내압', '누설', '가스', '수소', '산소', '질소', '가연', '폭발',
  '전기', '전압', '감전', '접지', '절연', '고온', '화상', '밸브', '안전',
  // 영어로 물어도 같다.
  'pressure', 'psi', 'gas', 'hydrogen', 'oxygen', 'nitrogen', 'leak',
  'explos', 'electric', 'voltage', 'ground', 'shock', 'valve', 'safety',
];

/// 안전과 관계된 질문인지(압력·가스·전기 …). 맞으면 확인 경고를 더 눈에 띄게 보인다.
bool isSafetySensitive(String question) {
  final q = question.toLowerCase();
  return _safetyWords.any(q.contains);
}

/// AI 답에 섞인 마크다운 기호(굵게 표시, # 제목, 백틱)를 걷어 평범한 글로 만든다(화면에 기호가 그대로 보이지 않게).
String cleanAiText(String raw) {
  var s = raw.replaceAll('**', '').replaceAll('__', '').replaceAll('`', '');
  s = s.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
  return s.trim();
}
