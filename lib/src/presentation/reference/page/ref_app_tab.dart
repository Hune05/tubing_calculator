// 앱 사용법 탭: 화면마다 순서와 설정 넣는 법.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'reference_widgets.dart';

class RefAppTab extends StatelessWidget {
  const RefAppTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        refIntroBadge(
          "홈 메뉴 순서대로 적었습니다. 처음 쓰는 장비는 계산기 '설정'에 제원을 먼저 넣고, 그 다음 입력 → 마킹 순서로 갑니다.",
        ),
        const SizedBox(height: 16),

        refCard(
          title: "벤딩 마킹 계산기 (튜브)",
          subtitle: "설정 → 입력 → 마킹 가이드 → 마킹지·리모컨",
          icon: LucideIcons.ruler,
          iconColor: refTeal,
          children: [
            refSectionTitle("① 설정 탭"),
            refStep(1, "규격(외경)·재질·피팅 타입을 고른다. 피팅 삽입 깊이는 규격을 고르면 자료값이 들어간다."),
            refStep(
              2,
              "벤더 종류(수동·유압식·시카고식)를 고르고 반경 R·테이크업·게인을 확인한다. 기본값은 '튜브' 탭 표와 같다.",
            ),
            refStep(
              3,
              "스프링백·톱날 손실(커프)·기준선 오프셋을 내 장비 값으로 넣는다. 실측은 '장비 사용법' 7번.",
            ),
            refSectionTitle("② 입력 탭"),
            refStep(
              4,
              "구간마다 직관 길이와 각도를 넣는다. 90° 외 각도는 '직관+각도'. 180°는 한 번에 꺾기.",
            ),
            refStep(
              5,
              "단차·장애물은 '특수 벤딩 툴'(퀵 킥·오프셋·롤링 오프셋·새들)로 넣으면 벤드가 자동으로 들어간다.",
            ),
            refStep(6, "구간이 벤더 최소 직선보다 짧으면 경고가 뜬다. 마지막 구간은 피팅 최소 직선 이상."),
            refSectionTitle("③ 마킹 가이드"),
            refStep(7, "'마킹 위치(줄자 0점 기준)'가 관 끝에서 잰 자리다. 벤더 0점(R 마크)에 맞춘다."),
            refStep(8, "'총 절단 길이'는 게인·톱날 손실·삽입 깊이를 넣은 값. 다 꺾고 이 길이로 자른다."),
            refStep(9, "'마킹지(PDF)'로 인쇄하거나 '보관함에 저장'. 보관함 도면은 QR로 현장에서 다시 연다."),
            refStep(10, "'벤딩 리모컨'은 폰을 벤더 옆에 두고 태블릿·PC의 값을 넘겨 보는 화면이다."),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "전선관 벤딩 마킹 계산기",
          subtitle: "설정(제조사·재질·규격) → 입력 → 결과 → 현장 탭",
          icon: LucideIcons.zap,
          iconColor: Colors.orange,
          children: [
            refSectionTitle("① 설정"),
            refStep(
              1,
              "벤더 종류(수동·유압식·시카고식) → 제조사 → 전선관 재질 → 규격. 제원이 '전선관' 탭 표값으로 들어간다.",
            ),
            refStep(
              2,
              "처음 고른 규격은 스프링백·커플링 끝 여유 기본값이 들어간다. 고쳐 저장하면 그 규격에만 남는다.",
            ),
            refStep(
              3,
              "'실측 보정' 창: 한 번 꺾어 잰 두 값(마킹 자리·바깥면까지)을 넣으면 테이크업·게인을 셈해 준다.",
            ),
            refSectionTitle("② 입력·결과"),
            refStep(4, "직관·각도를 순서대로. 오프셋·새들은 특수 벤딩 툴."),
            refStep(
              5,
              "결과 탭의 마킹은 테이크업을 이미 뺀 '화살표 자리'. 커플링 '체결'을 고르면 끝 여유가 들어간다.",
            ),
            refStep(6, "'마킹 가이드'에서 3D(아이소) 방향을 고르면 관끼리 닿는지 본다."),
            refSectionTitle("③ 현장 탭"),
            refStep(7, "폰을 가로로 눕히면 줄자처럼 마킹 자리가 크게 나온다. 자이로 각도기로 꺾은 각을 확인."),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "튜브 컷팅 계산기",
          subtitle: "피팅 삽입 깊이를 빼서 자를 길이를 내고 자재로 기록",
          icon: LucideIcons.scissors,
          iconColor: Colors.teal,
          children: [
            refStep(
              1,
              "작업(프로젝트)을 만들고 제조사(Swagelok·Hy-Lok·Parker)와 톱날 손실을 넣는다.",
            ),
            refStep(2, "구간마다 센터-센터 길이와 양쪽 부속을 고른다. 없는 부속은 '직접 입력(삽입 깊이)'."),
            refStep(
              3,
              "'절단 길이' = 센터 길이 − 양쪽 공제(부속마다 '튜브' 탭 7번 값). 세트 수를 넣으면 곱한다.",
            ),
            refStep(4, "'재단 계획'으로 원자재 본수·잔재를 본다. 잔재는 규격별로 남겨 다음에 먼저 쓴다."),
            refStep(
              5,
              "'완료'로 저장하면 누적 사용량(톱날 손실 포함)과 기록이 남고, 자재 관리에서 '재고에서 빼기'를 할 수 있다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "형강 컷팅 (찬넬/앵글)",
          subtitle: "규격·길이만 넣고 재단 계획·지시서",
          icon: LucideIcons.columns,
          iconColor: Colors.blueGrey,
          children: [
            refStep(
              1,
              "규격을 고르고(없으면 '커스텀'에 '앵글 50x50x6'처럼 적으면 무게도 셈) 길이·수량을 넣는다.",
            ),
            refStep(
              2,
              "원자재 길이(6000 등)와 톱날 손실을 위 칸에 넣는다. 길이 섞어 쓰기를 켜면 여러 원자재 길이를 같이 본다.",
            ),
            refStep(
              3,
              "결과 탭: 규격별 총 길이·무게·'새 원자재 N본'(잔재·섞어 쓰기 반영). 다 자른 줄은 접을 수 있다.",
            ),
            refStep(4, "'재단 계획' 시트에서 본마다 어떤 조각을 자를지 보고 '지시서(PDF)'로 뽑는다."),
            refStep(5, "'재고에서 빼기'를 누르면 규격별 본수가 자재 관리에서 빠진다. 잔재는 잔재 목록에 올린다."),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "작업 배치도",
          subtitle: "캐비닛 중판·측판, 스키드 평면·정면·측면",
          icon: LucideIcons.layers,
          iconColor: Colors.deepPurple,
          children: [
            refStep(1, "새 배치도 → 캐비닛 또는 스키드. 캐비닛은 ⋮ → '좌·우 측판'을 켜면 탭이 생긴다."),
            refStep(2, "아래 단추에서 모듈을 끌어 놓는다. 스키드는 형강·경로·JB·부속(곤질레다·커플링)."),
            refStep(
              3,
              "스키드는 평면에 한 번 놓으면 정면·측면에서도 보인다. 옆에서 끌면 평면 자리가 움직인다. 부품 편집 칸의 '바닥에서 높이'·'뒤집기'.",
            ),
            refStep(4, "'고정 치수 측정'으로 두 점을 눌러 치수선. 센터·측면 기준을 바꿀 수 있다."),
            refStep(
              5,
              "카톡으로 받은 도면 사진·PDF를 앱으로 공유하면 배경에 깔고 '축척 맞추기'(모서리 두 곳 + 실제 mm).",
            ),
            refStep(
              6,
              "저장(구름)하면 서버에 올라가 다른 폰에서 열린다. 배경 사진도 같이 올라간다. PDF 공유의 QR로 바로 열 수 있다.",
            ),
            refStep(7, "⋮ → '자재 수량'은 모든 탭 부품을 합쳐 센다. '도면 전체 지우기'는 되돌리기로 돌아온다."),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "내 프로젝트 · 작업 일지 · 주간 보고",
          subtitle: "일지 → 달력 → 주간 보고 PDF",
          icon: LucideIcons.clipboardList,
          iconColor: Colors.indigo,
          children: [
            refStep(
              1,
              "프로젝트를 만들고 '작업 일지'에 날짜별 벤딩 포인트·결선·특이사항·사진을 남긴다. 배치도를 일지 사진으로 붙일 수 있다.",
            ),
            refStep(2, "'달력'에서 날짜를 누르면 그 날 일지. 같은 날 여러 개면 개수가 보이고 골라서 연다."),
            refStep(3, "'이슈'는 처리 전·후를 나눠 남긴다. 주간 보고에 자동으로 들어간다."),
            refStep(4, "금요일 알림을 누르면 주간 보고가 열린다. 설정에서 '자동 PDF'를 켜면 바로 공유창까지."),
            refStep(
              5,
              "'저장 공간 관리'에서 백업 파일을 만들고 클라우드에 올린다(이름별 폴더). 다른 폰에서 내려받아 복구.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "내 일정 관리",
          subtitle: "프로젝트 일정 + 개인 일정",
          icon: LucideIcons.calendar,
          iconColor: Colors.green.shade700,
          children: [
            refStep(1, "월 달력의 막대가 일정. 날짜를 누르면 그 날 목록, 길게 누르지 않아도 된다."),
            refStep(2, "개인 일정은 반복·알림을 둘 수 있다. 장소는 검색해서 넣는다(한글 지명)."),
            refStep(3, "완료 표시는 고쳐도 남는다. 홈의 '오늘 N건'은 안 끝낸 것만 센다."),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "자재 현황 · 자재 통합 관리",
          subtitle: "재고 보기 → 입출고 → 재고조사",
          icon: LucideIcons.package,
          iconColor: Colors.brown,
          children: [
            refStep(1, "'자재 현황'에서 규격·위치로 찾고 입고·출고를 누른다. 최소 수량 아래면 '자재 부족' 표시."),
            refStep(
              2,
              "'자재 통합 관리' → 재고조사: 센 수량을 치고 '올리기'. 통신이 없으면 폰에 두었다가 올라간다.",
            ),
            refStep(
              3,
              "새 자재 등록은 이름·규격(spec)·최소 수량. 곤질레다는 부속이고 제조사는 삼화기전처럼 따로.",
            ),
            refStep(4, "컷팅·형강에서 '재고에서 빼기'를 하면 여기 수량이 줄고 사용 기록이 남는다."),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "현장 도면 스캔 (QR) · 통신 없는 곳",
          subtitle: "발전소처럼 통신이 없는 현장",
          icon: LucideIcons.scan,
          iconColor: Colors.blueGrey,
          children: [
            refStep(
              1,
              "마킹지·지시서 PDF의 QR을 찍으면 그 도면이 앱에서 열린다(로그인 뒤 홈이 뜬 다음 열린다).",
            ),
            refStep(2, "통신이 없으면 저장은 폰에 먼저 되고 '저장 대기' 표시가 뜬다. 통신되면 올라간다."),
            refStep(
              3,
              "날씨·서버 확인은 몇 초 뒤 멈추고 폰에 있는 것으로 보여 준다. 멈춘 것 같아도 기다리지 말고 진행.",
            ),
            refStep(4, "앱을 껐다 켜도 임시 저장(배치도·컷팅 입력)은 남는다. '이어서'를 고르면 된다."),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
