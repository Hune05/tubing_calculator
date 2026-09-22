// 프로필 검사·연락처 모양·로그인 글.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/profile/profile_tools.dart';

void main() {
  group('이름 검사', () {
    test('보통 이름은 통과, 빈 것·긴 것·/·로그인 필요는 막는다', () {
      expect(userNameProblem('홍길동'), isNull);
      expect(userNameProblem(' 김반장 '), isNull);
      expect(userNameProblem(''), isNotNull);
      expect(userNameProblem('   '), isNotNull);
      expect(userNameProblem('로그인 필요'), isNotNull);
      expect(userNameProblem('홍/길동'), isNotNull);
      expect(userNameProblem('홍\\길동'), isNotNull);
      expect(userNameProblem('.'), isNotNull);
      expect(userNameProblem('__x__'), isNotNull);
      expect(userNameProblem('가' * 21), isNotNull);
      expect(userNameProblem('가' * 20), isNull);
    });
  });

  group('연락처', () {
    test('숫자만 남겨 010-1234-5678 모양으로', () {
      expect(normalizePhone('01012345678'), '010-1234-5678');
      expect(normalizePhone('010 1234 5678'), '010-1234-5678');
      expect(normalizePhone('010.1234.5678'), '010-1234-5678');
      expect(normalizePhone('0212345678'), '02-1234-5678');
      expect(normalizePhone('021234567'), '02-123-4567');
      expect(normalizePhone('0511234567'), '051-123-4567');
    });

    test('모양을 모르면 숫자·하이픈만 남긴다', () {
      expect(normalizePhone('+82 10 1234 5678'), '+821012345678');
      expect(normalizePhone('내선 1234'), '1234');
    });

    test('연락처로 볼 수 있는지', () {
      expect(isPhoneLike('010-1234-5678'), isTrue);
      expect(isPhoneLike('1234'), isFalse);
      expect(isPhoneLike('021234567'), isTrue);
    });
  });

  test('로그인 글', () {
    expect(loginMethodLabel(googleLinked: false), '이름만 넣음 (구글 계정 없음)');
    expect(loginMethodLabel(googleLinked: true), '구글 계정');
    expect(
      loginMethodLabel(googleLinked: true, email: 'a@b.com'),
      '구글 계정 · a@b.com',
    );
  });

  test('사용자 문서 읽기: 없는 칸은 빈 글, name 칸이 있으면 그것', () {
    final p = UserProfile.fromMap('홍길동', {'team': '2팀', 'phoneNumber': '010'});
    expect(p.name, '홍길동');
    expect(p.team, '2팀');
    expect(p.role, '');
    expect(p.phone, '010');
    expect(p.photoUrl, isNull);
    expect(UserProfile.fromMap('홍길동', {'name': '홍반장'}).name, '홍반장');
    expect(UserProfile.fromMap('홍길동', null).name, '홍길동');
  });
}
