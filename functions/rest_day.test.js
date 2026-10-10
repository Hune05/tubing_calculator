// node rest_day.test.js 로 돌린다.
// 쉬는 날(토·일·공휴일, 한국 시각) 판단과 쉬는 날 이슈 알림 규칙(10-10).
const assert = require("assert");
const { isRestDayKst, punchAllowedOnRestDay, kstDay } = require("./rest_day");

// 한국 시각 2026-10-10(토) 09:00 = UTC 00:00
assert.strictEqual(isRestDayKst(new Date("2026-10-10T00:00:00Z")), true);
// 일요일
assert.strictEqual(isRestDayKst(new Date("2026-10-11T03:00:00Z")), true);
// 월요일 근무일
assert.strictEqual(isRestDayKst(new Date("2026-10-12T00:00:00Z")), false);
// 한글날(금) 공휴일
assert.strictEqual(isRestDayKst(new Date("2026-10-09T01:00:00Z")), true);
// 대체공휴일(월) 2026-10-05
assert.strictEqual(isRestDayKst(new Date("2026-10-05T01:00:00Z")), true);
// UTC로는 금요일 밤이지만 한국 시각으로는 토요일 아침 → 쉬는 날
assert.strictEqual(isRestDayKst(new Date("2026-10-16T22:30:00Z")), true);
assert.strictEqual(kstDay(new Date("2026-10-16T22:30:00Z")).ymd, "2026-10-17");
// 한국 시각 금요일 저녁 6시(UTC 09:00) → 근무일
assert.strictEqual(isRestDayKst(new Date("2026-10-16T09:00:00Z")), false);

// 쉬는 날 이슈 알림: 긴급 또는 기한 임박만
assert.strictEqual(punchAllowedOnRestDay("긴급", false), true);
assert.strictEqual(punchAllowedOnRestDay("보통", true), true);
assert.strictEqual(punchAllowedOnRestDay("보통", false), false);
assert.strictEqual(punchAllowedOnRestDay("여유", false), false);
assert.strictEqual(punchAllowedOnRestDay(undefined, false), false);

console.log("rest_day: 통과");
