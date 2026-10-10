// 손으로 그린 철판 그림 사진 → 외곽 꼭짓점(mm)·귀 처리·구멍·두께. 순수 함수만(테스트 가능).
// 안전 원칙: 그림에 적힌 치수를 먼저 쓰고, 안 적힌 길이는 그림 비례로 짐작하되 짐작한 곳을 unclear로 꼭 알린다.
// 앱(철판 가공 › 손그림 읽어 만들기)이 결과를 그림으로 보여 주고 사람이 치수를 고친 뒤 레이저 절단 화면으로 옮긴다.

const { validateImage } = require("./ai_material");

const MODEL = "claude-sonnet-5-5";
const DAILY_LIMIT = 20;
const MAX_POINTS = 60;
const MAX_HOLES = 100;
const MAX_MM = 20000;

const SYSTEM_PROMPT = [
    "당신은 현장 작업자가 종이에 손으로 그린 철판(레이저 절단용 평판) 그림을 읽어 치수 있는 도면 자료로 옮기는 도우미입니다.",
    "사진 속 그림을 읽어 record_plate 도구로 답합니다.",
    "좌표 약속: 단위 mm, 원점은 판을 감싸는 사각형의 왼쪽 아래, x는 오른쪽이 +, y는 위가 +.",
    "규칙:",
    "1. 그림에 적힌 치수(치수선·숫자)를 먼저 씁니다. 숫자를 읽어 꼭짓점 좌표를 계산합니다.",
    "2. 적히지 않은 길이는 그림 비례로 짐작하고, 짐작한 곳을 unclear에 한 줄씩 적습니다. 예: \"오른쪽 세로 변 길이가 안 적혀 있어 그림 비례로 120으로 짐작했습니다\".",
    "3. 손그림이라 조금 비뚤어진 선은 바로잡습니다. 직각으로 보이는 곳은 직각, 수평·수직으로 보이는 선은 수평·수직으로 넣습니다.",
    "4. outline은 판 외곽 꼭짓점을 반시계 방향 차례로 넣습니다. 마지막 점은 첫 점과 이어지므로 첫 점을 다시 넣지 않습니다.",
    "5. 귀를 둥글게(R) 했거나 빗기게 잘랐으면(C) 그 꼭짓점의 corner를 round 또는 chamfer로, size에 R 또는 C 값을 넣습니다. 그 밖에는 corner는 none, size는 0입니다.",
    "6. 귀를 사각으로 따낸 곳(노치)은 따낸 모양 그대로 꼭짓점을 더 넣어 그립니다.",
    "7. 둥근 판(원판)은 지름 크기의 정사각형 네 꼭짓점에 모두 round, size = 반지름으로 넣습니다.",
    "8. holes는 구멍 가운데 좌표와 지름입니다. φ13, Ø13, 13Φ, 13파이는 지름 13입니다. 장공은 slot에 전체 길이(구멍 끝에서 끝), angle에 방향(가로 0, 세로 90), 둥근 구멍은 slot 0, angle 0입니다.",
    "9. 구멍 지름 대신 M12처럼 볼트만 적혀 있으면 지름을 볼트 굵기 + 1.5(M12 → 13.5)로 넣고 unclear에 적습니다. 같은 구멍이 여러 개라고 적혀 있으면(4-φ13 등) 그 수만큼 넣습니다.",
    "10. thickness는 3t, t3, t=4, 4T 같은 두께 표기를 읽은 값입니다. 없으면 null입니다.",
    "11. 꺾기(절곡) 표시가 있어도 펴진 판 모양만 넣고, unclear에 \"꺾기 표시는 옮기지 않았습니다\"라고 적습니다.",
    "12. 철판 그림이 아니거나 너무 흐려 읽을 수 없으면 readable을 false로, reason에 이유를 적고 outline과 holes는 빈 배열로 둡니다.",
    "13. unclear와 reason은 쉬운 한국어 습니다체로 짧게 씁니다.",
].join("\n");

const TOOL = {
    name: "record_plate",
    description: "손그림에서 읽은 철판 외곽·귀 처리·구멍·두께를 기록한다",
    input_schema: {
        type: "object",
        properties: {
            readable: { type: "boolean" },
            reason: { type: "string" },
            outline: {
                type: "array",
                items: {
                    type: "object",
                    properties: {
                        x: { type: "number" },
                        y: { type: "number" },
                        corner: { type: "string", enum: ["none", "round", "chamfer"] },
                        size: { type: "number" },
                    },
                    required: ["x", "y", "corner", "size"],
                },
            },
            holes: {
                type: "array",
                items: {
                    type: "object",
                    properties: {
                        x: { type: "number" },
                        y: { type: "number" },
                        dia: { type: "number" },
                        slot: { type: "number" },
                        angle: { type: "number" },
                    },
                    required: ["x", "y", "dia", "slot", "angle"],
                },
            },
            thickness: { type: ["number", "null"] },
            unclear: { type: "array", items: { type: "string" } },
        },
        required: ["readable", "reason", "outline", "holes", "thickness", "unclear"],
    },
};

function buildRequest(data, mime) {
    return {
        model: MODEL,
        max_tokens: 4000,
        temperature: 0,
        system: SYSTEM_PROMPT,
        tools: [TOOL],
        tool_choice: { type: "tool", name: "record_plate" },
        messages: [
            {
                role: "user",
                content: [
                    { type: "image", source: { type: "base64", media_type: mime, data } },
                    { type: "text", text: "이 철판 그림을 치수 있는 외곽·구멍으로 옮겨 주세요." },
                ],
            },
        ],
    };
}

const r1 = (v) => Math.round(v * 10) / 10;
const num = (v) => (typeof v === "number" && Number.isFinite(v) ? v : null);

function cleanText(s, n) {
    return typeof s === "string" ? s.trim().slice(0, n) : "";
}

// 모델이 준 값을 앱이 믿고 쓸 수 있게 다듬는다: 숫자 범위, 개수 상한, 원점(왼쪽 아래)을 0으로.
function cleanPlate(raw) {
    if (!raw || typeof raw !== "object") return null;
    const unclear = Array.isArray(raw.unclear)
        ? raw.unclear.map((s) => cleanText(s, 120)).filter((s) => s).slice(0, 12)
        : [];
    const t = num(raw.thickness);
    const thickness = t !== null && t > 0 && t <= 50 ? r1(t) : null;
    const pts = [];
    for (const p of Array.isArray(raw.outline) ? raw.outline : []) {
        if (!p || typeof p !== "object") continue;
        const x = num(p.x), y = num(p.y);
        if (x === null || y === null || Math.abs(x) > MAX_MM || Math.abs(y) > MAX_MM) continue;
        const size = num(p.size);
        const corner = (p.corner === "round" || p.corner === "chamfer") && size !== null && size > 0
            ? p.corner : "none";
        pts.push({ x, y, corner, size: corner === "none" ? 0 : r1(Math.min(size, MAX_MM)) });
        if (pts.length >= MAX_POINTS) break;
    }
    // 같은 점이 이어 나오면 하나로, 끝 점이 첫 점과 같으면 뺀다.
    const outline = [];
    for (const p of pts) {
        const q = outline[outline.length - 1];
        if (q && Math.abs(q.x - p.x) < 0.05 && Math.abs(q.y - p.y) < 0.05) continue;
        outline.push(p);
    }
    if (outline.length > 1) {
        const a = outline[0], z = outline[outline.length - 1];
        if (Math.abs(a.x - z.x) < 0.05 && Math.abs(a.y - z.y) < 0.05) outline.pop();
    }
    const holes = [];
    for (const h of Array.isArray(raw.holes) ? raw.holes : []) {
        if (!h || typeof h !== "object") continue;
        const x = num(h.x), y = num(h.y), dia = num(h.dia);
        if (x === null || y === null || dia === null || dia <= 0 || dia > 500) continue;
        if (Math.abs(x) > MAX_MM || Math.abs(y) > MAX_MM) continue;
        const s = num(h.slot), a = num(h.angle);
        const slot = s !== null && s > dia && s < MAX_MM ? r1(s) : 0;
        const angle = slot > 0 && a !== null ? r1(((a % 180) + 180) % 180) : 0;
        holes.push({ x, y, dia: r1(dia), slot, angle });
        if (holes.length >= MAX_HOLES) break;
    }
    const readable = raw.readable !== false && outline.length >= 3;
    if (!readable) {
        return {
            readable: false,
            reason: cleanText(raw.reason, 200) || "철판 모양을 읽지 못했습니다",
            outline: [], holes: [], thickness, unclear,
        };
    }
    // 원점 맞추기: 외곽을 감싸는 사각형의 왼쪽 아래가 (0, 0)
    const minX = Math.min(...outline.map((p) => p.x));
    const minY = Math.min(...outline.map((p) => p.y));
    return {
        readable: true,
        reason: "",
        outline: outline.map((p) => ({ ...p, x: r1(p.x - minX), y: r1(p.y - minY) })),
        holes: holes.map((h) => ({ ...h, x: r1(h.x - minX), y: r1(h.y - minY) })),
        thickness,
        unclear,
    };
}

// Anthropic 응답에서 record_plate 호출을 꺼낸다. 없으면 null.
function extractPlate(resp) {
    if (!resp || !Array.isArray(resp.content)) return null;
    const block = resp.content.find((b) => b && b.type === "tool_use" && b.name === "record_plate");
    if (!block || !block.input) return null;
    return cleanPlate(block.input);
}

module.exports = {
    MODEL, DAILY_LIMIT, MAX_POINTS, MAX_HOLES, SYSTEM_PROMPT, TOOL,
    validateImage, buildRequest, cleanPlate, extractPlate,
};
