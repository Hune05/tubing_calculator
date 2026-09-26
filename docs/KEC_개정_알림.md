# 전기 기준(KEC) — 새 개정 알림과 요약 올리기

현장 자료 → 전기 기준(KEC) 탭은 두 가지로 최신을 따라간다.

- **A. 새 개정 알림**: 서버 함수 `checkKecNotice`가 매일 아침 6시(한국 시간)에 법제처 Open API로
  한국전기설비규정의 현행 공고를 읽는다. 요약 기준 공고보다 새 공고면 KEC 탭 맨 위에 알리고,
  모든 폰에 한 번 푸시 알림을 보낸다(누르면 전기 기준 탭).
- **B. 요약을 서버에 두기**: 탭 글은 `kec_content.json`에 있다. 판 번호(`version`)를 올려 함수를
  배포하면 서버 문서 `reference_content/kec`에 올라가고, 앱을 다시 깔지 않아도 모든 폰에 보인다.
  통신이 없으면 폰에 남은 것을, 그것도 없으면 앱에 든 요약을 보인다.

KEC 개정은 해마다 정해져 있지 않다(한 해 0~5번 — 2023년 5번, 2024년 1번). KEC 본문은 법제처에
첨부 HWP·PDF로만 올라와서, 요약은 사람이 고쳐야 한다. 앱이 원문에서 수치를 스스로 뽑지 않는다.

## 처음 한 번 하는 일

1. **법제처 Open API 신청** — https://open.law.go.kr 회원가입 → OPEN API 사용 신청(행정규칙
   목록·본문) → 승인까지 1~2일. 승인되면 "API 인증값(OC)"을 확인한다.
2. **서버 비밀값 넣기** — 인증값은 공개 저장소에 두지 않는다.
   ```
   firebase functions:secrets:set LAW_OC
   ```
   인증값을 아직 못 받았으면 `none`을 넣는다. 그러면 요약 올리기(B)만 되고, 탭에
   "개정 확인을 못 했습니다: 법제처 API 인증값이 아직 없습니다"가 보인다.
3. **함수 배포** — `firebase deploy --only functions`
   (발주·채팅 함수 3개를 지울지 물으면 지운다 — 점검 30번).
4. 확인: 다음 날 아침 6시 뒤 KEC 탭에 "개정 확인: 날짜 · 새 공고 없음"이 보이면 된다. 바로 보려면
   Google Cloud 콘솔 → Cloud Scheduler → `checkKecNotice` 줄의 "강제 실행".

확인이 실패하면 탭에 이유가 나온다. "IP"·"미신청" 같은 말이 나오면 법제처가 부르는 곳의
IP 등록을 요구하는 것일 수 있다(2026-09-26 기준 확인 못 함) — 그때 고정 IP 방법을 찾는다.

## 새 공고가 났을 때 — 요약 고치기

1. 알림이나 탭의 "원문 보기"로 원문(법제처)을 연다.
2. `assets/reference/kec_content.json`을 고친다.
   - `basis`: 새 공고의 `serial`(행정규칙일련번호)·`noticeNo`(발령번호)·`issued`(발령일)·`checked`(확인한 날)
   - 바뀐 항목의 글
   - `version`을 1 올린다
3. 같은 내용을 `functions/kec_content.json`에 복사한다(`test/kec_content_test.dart`가 둘이 같은지 본다).
4. `firebase deploy --only functions` → 다음 날 아침(또는 강제 실행) 모든 폰에 보인다.
   앱을 새로 빌드해 깔면 앱에 든 요약도 새 판이 된다.

조문 번호·수치를 넣을 때는 법제처·소관 부처가 올린 원문 파일에서만 옮긴다(대한전기협회
핸드북·해설서 글은 저작권이 있다). 법제처 자료를 쓰므로 탭에 "출처: 법제처 국가법령정보센터"를 둔다.

## 코드 위치

- 서버: `functions/kec.js`(법제처 응답 읽기·새 공고 판단), `functions/index.js`의 `checkKecNotice`,
  시험 `functions/kec.test.js`(`npm test`)
- 앱: `lib/src/presentation/reference/kec_content.dart`(요약 고르기·새 공고 판단),
  `page/ref_kec_tab.dart`(화면), 알림 열기 `lib/main.dart` `routeForNotification`(`open: reference_kec`)
- 규칙: `firestore.rules`의 `reference_content` — 누구나 읽고, 앱에서는 못 쓴다(함수만)
