const assert = require("assert");
const p = require("./ai_polish");

assert.deepStrictEqual(p.validateInput(5), { error: "글이 없습니다" });
assert.ok(p.validateInput("가").error);
assert.ok(p.validateInput("가".repeat(p.MAX_INPUT_CHARS + 1)).error);
assert.strictEqual(p.validateInput("  센서 결선  ").text, "센서 결선");

const now = new Date("2026-09-30T03:00:00Z"); // KST 12시
assert.strictEqual(p.kstDay(now), "2026-09-30");
assert.strictEqual(p.kstDay(new Date("2026-09-30T16:00:00Z")), "2026-10-01"); // KST 자정 넘김

assert.deepStrictEqual(p.nextUsage(undefined, now), { allowed: true, day: "2026-09-30", count: 1, limit: 30 });
assert.strictEqual(p.nextUsage({ day: "2026-09-30", count: 4 }, now).count, 5);
assert.strictEqual(p.nextUsage({ day: "2026-09-29", count: 30 }, now).count, 1); // 어제 것은 초기화
assert.strictEqual(p.nextUsage({ day: "2026-09-30", count: 30 }, now).allowed, false);
assert.strictEqual(p.nextUsage({ day: "2026-09-30", count: "x" }, now).count, 1);

const req = p.buildRequest("센서 3개소 결선");
assert.strictEqual(req.model, p.MODEL);
assert.strictEqual(req.messages[0].content, "센서 3개소 결선");

assert.strictEqual(p.extractText({ content: [{ type: "text", text: " 결선 완료 " }] }), "결선 완료");
assert.strictEqual(p.extractText({ content: [] }), null);
assert.strictEqual(p.extractText(null), null);
console.log("ai_polish OK");
