// node flag_merge.test.js 로 돌린다.
const assert = require("assert");
const { itemKey, mergeFlags, flagRecorder } = require("./flag_merge");

// 함수가 읽은 목록에서 알림을 보내고 표시를 적는다.
const read = [
    { id: "s1", title: "검사", dateTime: "2026-10-10" },
    { id: "s2", title: "입고" },
    { title: "예전 일정", type: "자재 요청", requestedAt: "2026-10-01" },
];
const rec = flagRecorder();
rec.mark(read[0], { lastOverdueReminderDate: "2026-10-09" });
rec.mark(read[2], { lastOverdueReminderDate: "2026-10-09" });
rec.mark(read[0], { reminderSent: true });
// 같은 실행 안에서는 항목에 바로 적혀 있다.
assert.strictEqual(read[0].lastOverdueReminderDate, "2026-10-09");
assert.strictEqual(rec.updates.size, 2);

// 그 사이 앱에서: s1 제목을 고치고, s2는 완료, 새 일정 s3 추가.
const latest = [
    { id: "s1", title: "최종 검사", dateTime: "2026-10-10" },
    { id: "s2", title: "입고", isCompleted: true },
    { title: "예전 일정", type: "자재 요청", requestedAt: "2026-10-01" },
    { id: "s3", title: "새 일정" },
];
const next = mergeFlags(latest, rec.updates);
// 앱이 고친 것은 그대로 남고 표시만 들어간다.
assert.deepStrictEqual(next[0], {
    id: "s1", title: "최종 검사", dateTime: "2026-10-10",
    lastOverdueReminderDate: "2026-10-09", reminderSent: true,
});
assert.deepStrictEqual(next[1], latest[1]);
assert.strictEqual(next[2].lastOverdueReminderDate, "2026-10-09");
assert.deepStrictEqual(next[3], latest[3]);
assert.strictEqual(next.length, 4);
// 최신 목록을 바꾸지는 않는다(새 목록을 만든다).
assert.strictEqual(latest[0].reminderSent, undefined);

// 그 사이 지워진 항목에는 넣지 않고, 바뀐 것이 없으면 null.
assert.strictEqual(mergeFlags([{ id: "s9" }], rec.updates), null);
assert.strictEqual(mergeFlags(null, rec.updates), null);
assert.strictEqual(mergeFlags(latest, new Map()), null);

// Timestamp 같은 값(toMillis)도 열쇠로 쓴다.
const ts = { toMillis: () => 1700000000000 };
assert.strictEqual(itemKey({ title: "a", dateTime: ts }), "tt:a||1700000000000|");
assert.strictEqual(itemKey({ id: "x", title: "a" }), "id:x");
assert.strictEqual(itemKey(null), null);
console.log("flag_merge: 모두 통과");
