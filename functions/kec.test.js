// node kec.test.js 로 돌린다.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const kec = require("./kec");

// 2026-09-26 법제처 API(공용 시험 키)로 받은 실제 응답 — 결과가 하나면 목록이 아니라 한 덩어리.
const single = {
    AdmRulSearch: {
        resultMsg: "success",
        resultCode: "00",
        target: "admrul",
        admrul: {
            현행연혁구분: "현행",
            행정규칙명: "한국전기설비규정",
            발령일자: "20260105",
            행정규칙종류: "공고",
            소관부처명: "기후에너지환경부",
            제개정구분명: "일부개정",
            행정규칙ID: "62165",
            시행일자: "20260105",
            발령번호: "2025-227",
            행정규칙일련번호: "2100000270772",
        },
        totalCnt: "1",
    },
};
const cur = kec.pickCurrentKec(single);
assert.strictEqual(cur.serial, "2100000270772");
assert.strictEqual(cur.noticeNo, "2025-227");
assert.strictEqual(cur.issued, "2026-01-05");
assert.strictEqual(cur.effective, "2026-01-05");
assert.strictEqual(cur.ministry, "기후에너지환경부");
assert.strictEqual(cur.revision, "일부개정");
assert.strictEqual(cur.url, "https://www.law.go.kr/LSW/admRulInfoP.do?admRulSeq=2100000270772");

// 여러 건: 이름이 다른 규칙·연혁은 빼고 현행을 고른다.
const many = {
    AdmRulSearch: {
        resultCode: "00",
        admrul: [
            { 행정규칙명: "한국전기설비규정 해설", 현행연혁구분: "현행", 발령일자: "20260301", 행정규칙일련번호: "9" },
            { 행정규칙명: "한국전기설비규정", 현행연혁구분: "연혁", 발령일자: "20251230", 행정규칙일련번호: "2100000269000" },
            { 행정규칙명: "한국전기설비규정", 현행연혁구분: "현행", 발령일자: "20260105", 행정규칙일련번호: "2100000270772", 발령번호: "2025-227" },
        ],
    },
};
assert.strictEqual(kec.pickCurrentKec(many).serial, "2100000270772");

// 못 찾거나 오류 응답이면 이유를 담아 던진다.
assert.throws(() => kec.pickCurrentKec({ AdmRulSearch: { resultCode: "00", admrul: [] } }), /찾지 못했습니다/);
assert.throws(() => kec.pickCurrentKec({ result: "사용자 정보 검증에 실패하였습니다." }), /검증에 실패/);
assert.throws(() => kec.pickCurrentKec({ AdmRulSearch: { resultCode: "99", resultMsg: "fail" } }), /API 오류 99/);

// 새 공고 판단: 일련번호가 다르고 발령일이 같거나 늦을 때만.
const basis = { serial: "2100000270772", issued: "2026-01-05" };
assert.strictEqual(kec.isNewerNotice(cur, basis), false);
const next = { serial: "2100000280000", issued: "2026-10-01" };
assert.strictEqual(kec.isNewerNotice(next, basis), true);
assert.strictEqual(kec.isNewerNotice({ serial: "2100000269000", issued: "2025-12-30" }, basis), false); // 옛 공고
assert.strictEqual(kec.isNewerNotice(null, basis), false);

// 알림은 한 공고에 한 번.
assert.strictEqual(kec.shouldNotify(next, basis, undefined), true);
assert.strictEqual(kec.shouldNotify(next, basis, "2100000280000"), false);
assert.strictEqual(kec.shouldNotify(cur, basis, undefined), false);

// 요약은 판 번호가 오를 때만 올린다.
assert.strictEqual(kec.shouldPublishContent({}, { version: 1 }), true);
assert.strictEqual(kec.shouldPublishContent({ contentVersion: 1 }, { version: 1 }), false);
assert.strictEqual(kec.shouldPublishContent({ contentVersion: 1 }, { version: 2 }), true);

// 인증값이 비었거나 자리 표시·공용 시험 키면 확인하지 않는다.
assert.strictEqual(kec.usableOc(""), "");
assert.strictEqual(kec.usableOc(" none "), "");
assert.strictEqual(kec.usableOc("없음"), "");
assert.strictEqual(kec.usableOc("test"), "");
assert.strictEqual(kec.usableOc("myid"), "myid");

// fetchCurrentKec: HTML 안내 글이 오면 읽을 수 있는 이유로 던진다.
(async () => {
    const htmlFetch = async () => ({ ok: true, status: 200, text: async () => "<html><body>미신청된 목록/본문에 대한 접근입니다.</body></html>" });
    await assert.rejects(() => kec.fetchCurrentKec("myid", htmlFetch), /JSON이 아닌 응답: 미신청된/);
    const okFetch = async (url) => {
        assert.ok(url.includes("OC=myid") && url.includes("target=admrul") && url.includes("type=JSON"));
        return { ok: true, status: 200, text: async () => JSON.stringify(single) };
    };
    assert.strictEqual((await kec.fetchCurrentKec("myid", okFetch)).noticeNo, "2025-227");

    // 요약 파일: 서버 함수 판과 앱 판이 같아야 한다(앱 시험에서도 본다).
    const fn = fs.readFileSync(path.join(__dirname, "kec_content.json"), "utf8");
    const content = JSON.parse(fn);
    assert.strictEqual(typeof content.version, "number");
    assert.strictEqual(content.basis.serial, cur.serial);
    console.log("kec.test.js ok");
})().catch((e) => {
    console.error(e);
    process.exit(1);
});
