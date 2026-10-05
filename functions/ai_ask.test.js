const assert = require("assert");
const a = require("./ai_ask");

assert.deepStrictEqual(a.validateQuestion(5), { error: "질문이 없습니다" });
assert.ok(a.validateQuestion("가").error);
assert.ok(a.validateQuestion("가".repeat(a.MAX_QUESTION_CHARS + 1)).error);
assert.strictEqual(a.validateQuestion("  영점이 안 잡힐 때  ").question, "영점이 안 잡힐 때");

const req = a.buildRequest("압력계 영점이 안 잡혀요");
assert.strictEqual(req.model, a.MODEL);
assert.strictEqual(req.messages[0].content, "압력계 영점이 안 잡혀요");
assert.ok(req.system.includes("모릅니다")); // 모르면 모른다고 하게 지시
assert.ok(req.system.includes("안전")); // 안전 관련 안내
assert.ok(req.system.includes("마크다운")); // 강조 기호를 쓰지 않게 지시

assert.strictEqual(a.extractText({ content: [{ type: "text", text: " 답변 " }] }), "답변");
assert.strictEqual(a.extractText({ content: [] }), null);
assert.strictEqual(a.extractText(null), null);
assert.ok(a.DAILY_LIMIT > 0);
console.log("ai_ask OK");
