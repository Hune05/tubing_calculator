// 기록 한 줄이 어느 작업 것인지 가리는 셈.
// 'project_name' 한 칸을 작업 이름과 "왜 썼는지"에 같이 쓰고 있어서,
// 작업에서 뺀 기록만 골라내야 칩에 엉뚱한 것이 안 섞인다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_logs_page.dart';

void main() {
  group('작업 이름 가려내기', () {
    test('차감할 때 남긴 작업 이름을 그대로 쓴다', () {
      expect(
        jobNameOfLog({
          'job_name': '형강 컷팅 · 전선관',
          'project_name': '형강 컷팅 · 전선관',
          'action': '형강 재단',
        }),
        '형강 컷팅 · 전선관',
      );
    });

    test('튜브 컷팅도 형강과 같은 모양으로 남는다', () {
      expect(
        jobNameOfLog({
          'job_name': '튜브 컷팅 · 루마',
          'action': '컷팅 사용',
        }),
        '튜브 컷팅 · 루마',
      );
    });

    test('자재 목록에서 넣은 기록은 작업이 아니다', () {
      expect(
        jobNameOfLog({
          'action': '자재 등록',
          'project_name': '자재 목록에서 넣음',
        }),
        '',
      );
    });

    test('자재 화면에서 수량 고친 것도 작업이 아니다', () {
      expect(
        jobNameOfLog({
          'action': '재고 실사',
          'project_name': '자재 화면에서 수량 고침',
        }),
        '',
      );
    });

    test('불출에 적은 글도 작업이 아니다', () {
      expect(
        jobNameOfLog({'type': 'OUT', 'project_name': '테스트'}),
        '',
      );
    });

    test('작업 이름 칸이 없는 옛 차감 기록은 한 일로 가린다', () {
      expect(
        jobNameOfLog({'action': '컷팅 사용', 'project_name': '루마'}),
        '루마',
      );
      expect(
        jobNameOfLog({'action': '형강 재단', 'project_name': '전선관'}),
        '전선관',
      );
    });

    test('되돌린 기록도 그 작업 것으로 본다', () {
      expect(
        jobNameOfLog({'action': '차감 되돌림', 'project_name': '형강 컷팅 · 전선관'}),
        '형강 컷팅 · 전선관',
      );
    });

    test('칸이 비어 있으면 빈 글', () {
      expect(jobNameOfLog({}), '');
      expect(jobNameOfLog({'job_name': '   '}), '');
    });
  });
}
