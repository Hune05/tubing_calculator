// node access.test.js 로 돌린다.
const assert = require("assert");
const { ADMIN_EMAIL, isAdminToken, canUseAi, rejectedUids } = require("./access");
const { collectRecipients } = require("./recipients");

// 관리자: 이메일이 맞고 확인된 것만
assert.strictEqual(isAdminToken({ email: ADMIN_EMAIL, email_verified: true }), true);
assert.strictEqual(isAdminToken({ email: ADMIN_EMAIL, email_verified: false }), false);
assert.strictEqual(isAdminToken({ email: "other@gmail.com", email_verified: true }), false);
assert.strictEqual(isAdminToken(undefined), false);

// AI: 관리자나 승인된 사람만. 대기·거절·문서 없음(익명 포함)은 안 됨
assert.strictEqual(canUseAi({ email: ADMIN_EMAIL, email_verified: true }, null), true);
assert.strictEqual(canUseAi({}, { status: "approved" }), true);
assert.strictEqual(canUseAi({}, { status: "pending" }), false);
assert.strictEqual(canUseAi({}, { status: "rejected" }), false);
assert.strictEqual(canUseAi({}, null), false);
assert.strictEqual(canUseAi({ firebase: { sign_in_provider: "anonymous" } }, undefined), false);

// 알림: 거절된 사람만 뺀다(대기는 그대로)
const blocked = rejectedUids([
    { id: "ua", data: { status: "approved" } },
    { id: "ub", data: { status: "rejected" } },
    { id: "uc", data: { status: "pending" } },
    { id: "ud", data: null },
]);
assert.deepStrictEqual([...blocked], ["ub"]);
const r = collectRecipients([
    { name: "가", data: { uid: "ua", fcmToken: "tA" } },
    { name: "나", data: { uid: "ub", fcmToken: "tB" } },
    { name: "다", data: { uid: "uc", fcmToken: "tC" } },
    { name: "라", data: { fcmToken: "tD" } },
], blocked);
assert.deepStrictEqual(r.all.sort(), ["tA", "tC", "tD"]);
assert.strictEqual(r.byName.has("나"), false);
console.log("access: 모두 통과");
