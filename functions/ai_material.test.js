const assert = require("assert");
const m = require("./ai_material");

const okData = "/9j/" + "A".repeat(200);
assert.ok(m.validateImage(undefined).error);
assert.ok(m.validateImage("abc").error);
assert.ok(m.validateImage("가".repeat(200)).error);
assert.ok(m.validateImage("R0lGOD" + "A".repeat(200)).error); // gif
assert.strictEqual(m.validateImage("iVBORw0KGgo" + "A".repeat(200)).mime, "image/png");
assert.strictEqual(m.validateImage("UklGR" + "A".repeat(200)).mime, "image/webp");
assert.ok(m.validateImage("/9j/" + "A".repeat(m.MAX_IMAGE_BASE64)).error);
assert.deepStrictEqual(m.validateImage(okData), { data: okData, mime: "image/jpeg" });

const req = m.buildRequest(okData, "image/jpeg");
assert.strictEqual(req.tool_choice.name, "record_items");
assert.strictEqual(req.messages[0].content[0].source.data, okData);

const cleaned = m.cleanItems([
    { name: " 튜브 ", spec: "6mm SS316", qty: 50, unit: "m", unsure: false },
    { name: "엘보", spec: "", qty: null, unit: "", unsure: false }, // 수량 없음 → 확인 대상
    { name: "", spec: "x", qty: 1, unit: "", unsure: false }, // 이름 없음 → 뺌
    { name: "볼트", spec: "M8", qty: -3, unit: "개", unsure: false }, // 음수 → null
    { name: "너트", spec: "M8", qty: 2.456, unit: "개", unsure: true },
    null,
]);
assert.strictEqual(cleaned.length, 4);
assert.strictEqual(cleaned[0].name, "튜브");
assert.strictEqual(cleaned[0].unsure, false);
assert.strictEqual(cleaned[1].unsure, true);
assert.strictEqual(cleaned[2].qty, null);
assert.strictEqual(cleaned[3].qty, 2.46);
assert.deepStrictEqual(m.cleanItems("x"), []);
assert.strictEqual(m.cleanItems(Array.from({ length: 200 }, () => ({ name: "a", qty: 1 }))).length, m.MAX_ITEMS);

const resp = { content: [{ type: "text", text: "..." }, { type: "tool_use", name: "record_items", input: { items: [{ name: "튜브", spec: "", qty: 3, unit: "m", unsure: false }] } }] };
assert.strictEqual(m.extractItems(resp)[0].qty, 3);
assert.strictEqual(m.extractItems({ content: [] }), null);
assert.strictEqual(m.extractItems(null), null);
console.log("ai_material OK");
