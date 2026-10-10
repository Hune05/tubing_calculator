const assert = require("assert");
const s = require("./ai_sketch");

const okData = "/9j/" + "A".repeat(200);
assert.ok(s.validateImage("abc").error);
assert.deepStrictEqual(s.validateImage(okData), { data: okData, mime: "image/jpeg" });

const req = s.buildRequest(okData, "image/jpeg");
assert.strictEqual(req.tool_choice.name, "record_plate");
assert.strictEqual(req.model, s.MODEL);
assert.strictEqual(req.messages[0].content[0].source.data, okData);

// 원점 맞추기·같은 점 빼기·끝 점이 첫 점과 같으면 빼기·귀 처리 다듬기
const c = s.cleanPlate({
    readable: true,
    reason: "",
    outline: [
        { x: 10, y: 20, corner: "round", size: 10 },
        { x: 210, y: 20, corner: "none", size: 5 }, // none이면 size 0
        { x: 210, y: 20, corner: "none", size: 0 }, // 같은 점
        { x: 210, y: 120, corner: "chamfer", size: -3 }, // 음수 → none
        { x: 10, y: 120, corner: "weird", size: 4 }, // 모르는 종류 → none
        { x: 10, y: 20, corner: "none", size: 0 }, // 첫 점 다시
        { x: "a", y: 1, corner: "none", size: 0 }, // 숫자 아님
    ],
    holes: [
        { x: 30, y: 40, dia: 13.5, slot: 0, angle: 45 }, // 둥근 구멍은 angle 0
        { x: 110, y: 70, dia: 13.5, slot: 40, angle: 270 }, // 270 → 90
        { x: 0, y: 0, dia: 0, slot: 0, angle: 0 }, // 지름 0 → 뺌
        { x: 50, y: 50, dia: 11, slot: 8, angle: 0 }, // 장공 길이 < 지름 → 둥근 구멍
    ],
    thickness: 3,
    unclear: ["  오른쪽 세로 변은 짐작했습니다 ", "", 5],
});
assert.strictEqual(c.readable, true);
assert.deepStrictEqual(c.outline, [
    { x: 0, y: 0, corner: "round", size: 10 },
    { x: 200, y: 0, corner: "none", size: 0 },
    { x: 200, y: 100, corner: "none", size: 0 },
    { x: 0, y: 100, corner: "none", size: 0 },
]);
assert.deepStrictEqual(c.holes, [
    { x: 20, y: 20, dia: 13.5, slot: 0, angle: 0 },
    { x: 100, y: 50, dia: 13.5, slot: 40, angle: 90 },
    { x: 40, y: 30, dia: 11, slot: 0, angle: 0 },
]);
assert.strictEqual(c.thickness, 3);
assert.deepStrictEqual(c.unclear, ["오른쪽 세로 변은 짐작했습니다"]);

// 못 읽음: 꼭짓점이 셋 안 되면 readable false, 이유가 없으면 기본 이유
const bad = s.cleanPlate({ readable: true, outline: [{ x: 0, y: 0 }], holes: [], thickness: 99, unclear: [] });
assert.strictEqual(bad.readable, false);
assert.strictEqual(bad.reason, "철판 모양을 읽지 못했습니다");
assert.strictEqual(bad.thickness, null); // 50mm 넘는 두께는 버림
const no = s.cleanPlate({ readable: false, reason: "사진이 흐립니다", outline: [], holes: [], thickness: null, unclear: [] });
assert.deepStrictEqual([no.readable, no.reason], [false, "사진이 흐립니다"]);
assert.strictEqual(s.cleanPlate(null), null);

// 개수 상한
const many = s.cleanPlate({
    readable: true,
    outline: Array.from({ length: 100 }, (_, i) => ({ x: Math.cos(i / 16) * 100, y: Math.sin(i / 16) * 100, corner: "none", size: 0 })),
    holes: Array.from({ length: 150 }, (_, i) => ({ x: i, y: 1, dia: 5, slot: 0, angle: 0 })),
    thickness: null,
    unclear: [],
});
assert.ok(many.outline.length <= s.MAX_POINTS);
assert.strictEqual(many.holes.length, s.MAX_HOLES);

// 응답에서 꺼내기
assert.strictEqual(s.extractPlate({ content: [{ type: "text", text: "hi" }] }), null);
const ex = s.extractPlate({
    content: [{
        type: "tool_use",
        name: "record_plate",
        input: {
            readable: true, reason: "",
            outline: [{ x: 0, y: 0, corner: "none", size: 0 }, { x: 50, y: 0, corner: "none", size: 0 }, { x: 0, y: 50, corner: "none", size: 0 }],
            holes: [], thickness: 4, unclear: [],
        },
    }],
});
assert.strictEqual(ex.outline.length, 3);
assert.strictEqual(ex.thickness, 4);

console.log("ai_sketch ok");
