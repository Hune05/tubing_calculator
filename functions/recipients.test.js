// node recipients.test.js 로 돌린다.
const assert = require("assert");
const { collectRecipients, tokensFor } = require("./recipients");

const r = collectRecipients([
    { name: "홍길동", data: { uid: "ua", fcmToken: "tA" } },
    { name: "김철수", data: { uid: "ub", fcmToken: "tB" } },
    { name: "이영희", data: { fcmToken: "tC" } },
    { name: "토큰없음", data: { uid: "ud" } },
]);
assert.deepStrictEqual(r.all.sort(), ["tA", "tB", "tC"]);
// 주인 있는 프로젝트: 주인 폰만
assert.deepStrictEqual(tokensFor(r, { ownerUid: "ua" }, null), ["tA"]);
// + 담당자
assert.deepStrictEqual(tokensFor(r, { ownerUid: "ua" }, "김철수").sort(), ["tA", "tB"]);
// 주인 없음·빈 글(공용): 모두
assert.deepStrictEqual(tokensFor(r, {}, null).sort(), ["tA", "tB", "tC"]);
assert.deepStrictEqual(tokensFor(r, { ownerUid: "" }, null).sort(), ["tA", "tB", "tC"]);
// 주인 폰에 토큰이 없으면 아무에게도 안 보낸다
assert.deepStrictEqual(tokensFor(r, { ownerUid: "ud" }, null), []);
console.log("recipients: 모두 통과");
