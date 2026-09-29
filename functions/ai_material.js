// 손으로 쓴 자재 요청 메모 사진 → 품명·규격·수량 표. 순수 함수만(테스트 가능).
// 안전 원칙: 종이에 적힌 것만 옮긴다. 안 보이거나 애매한 글자는 추측하지 말고 unsure로 표시한다.

const MODEL = "claude-haiku-4-5-20251001";
const MAX_IMAGE_BASE64 = 7 * 1024 * 1024; // 약 5MB 사진. 앱이 줄여서 보내므로 보통 훨씬 작다.
const MAX_ITEMS = 80;
const DAILY_LIMIT = 20;

const SYSTEM_PROMPT = [
    "당신은 발전소 계측·배관·전기 현장의 자재 요청 메모를 옮겨 적는 도우미입니다.",
    "사진 속 손글씨(또는 인쇄) 자재 목록을 항목별로 읽어 record_items 도구로 답합니다.",
    "규칙:",
    "1. 종이에 적힌 것만 옮깁니다. 없는 항목·규격·수량을 절대 만들지 않습니다.",
    "2. 글자가 흐리거나 숫자가 헷갈리면(1과 7, 0과 6 등) 가장 그럴듯한 값을 넣되 unsure를 true로 합니다.",
    "3. 수량이 안 적혀 있으면 qty는 null입니다. 1로 짐작하지 않습니다.",
    "4. name은 자재 이름(예: 튜브, 엘보, 전선관), spec은 규격(예: 6mm SS316, 3/8\", 16C). 규격이 안 적혀 있으면 빈 글.",
    "5. unit은 종이에 적힌 단위(m, 개, EA, 본, 롤 등). 없으면 빈 글.",
    "6. 목록이 아닌 글(날짜, 메모, 낙서)은 무시합니다. 목록이 안 보이면 items를 빈 배열로 답합니다.",
    "7. 종이 순서 그대로 옮깁니다.",
].join("\n");

const TOOL = {
    name: "record_items",
    description: "사진에서 읽은 자재 요청 목록을 기록한다",
    input_schema: {
        type: "object",
        properties: {
            items: {
                type: "array",
                items: {
                    type: "object",
                    properties: {
                        name: { type: "string" },
                        spec: { type: "string" },
                        qty: { type: ["number", "null"] },
                        unit: { type: "string" },
                        unsure: { type: "boolean" },
                    },
                    required: ["name", "spec", "qty", "unit", "unsure"],
                },
            },
        },
        required: ["items"],
    },
};


// 사진 앞부분(base64)으로 실제 형식을 알아낸다. 갤러리 사진은 PNG일 수 있는데 앱이 JPEG라고 적어
// 보내면 AI가 거절하므로, 앱이 보낸 형식 표시는 믿지 않는다.
function sniffMime(b64) {
    if (b64.startsWith("/9j/")) return "image/jpeg";
    if (b64.startsWith("iVBORw0KGgo")) return "image/png";
    if (b64.startsWith("UklGR")) return "image/webp";
    return null;
}

// 입력 검사. 문제가 있으면 { error }, 괜찮으면 { data, mime }.
function validateImage(data) {
    if (typeof data !== "string" || data.length < 100) return { error: "사진이 없습니다" };
    if (data.length > MAX_IMAGE_BASE64) return { error: "사진이 너무 큽니다" };
    if (!/^[A-Za-z0-9+/=]+$/.test(data)) return { error: "사진 형식이 맞지 않습니다" };
    const mime = sniffMime(data);
    if (!mime) return { error: "사진 형식이 맞지 않습니다" };
    return { data, mime };
}

function buildRequest(data, mime) {
    return {
        model: MODEL,
        max_tokens: 2000,
        temperature: 0,
        system: SYSTEM_PROMPT,
        tools: [TOOL],
        tool_choice: { type: "tool", name: "record_items" },
        messages: [
            {
                role: "user",
                content: [
                    { type: "image", source: { type: "base64", media_type: mime, data } },
                    { type: "text", text: "이 자재 요청 메모를 목록으로 옮겨 주세요." },
                ],
            },
        ],
    };
}

// 모델이 준 항목을 앱이 믿고 쓸 수 있게 다듬는다(글 길이 제한, 수량 검사, 빈 줄 제거).
function cleanItems(raw) {
    if (!Array.isArray(raw)) return [];
    const out = [];
    for (const it of raw) {
        if (!it || typeof it !== "object") continue;
        const name = typeof it.name === "string" ? it.name.trim().slice(0, 60) : "";
        if (!name) continue;
        const spec = typeof it.spec === "string" ? it.spec.trim().slice(0, 60) : "";
        const unit = typeof it.unit === "string" ? it.unit.trim().slice(0, 10) : "";
        let qty = null;
        if (typeof it.qty === "number" && Number.isFinite(it.qty) && it.qty > 0 && it.qty < 1000000) {
            qty = Math.round(it.qty * 100) / 100;
        }
        // 수량이 없으면 무조건 확인 대상
        const unsure = it.unsure === true || qty === null;
        out.push({ name, spec, qty, unit, unsure });
        if (out.length >= MAX_ITEMS) break;
    }
    return out;
}

// Anthropic 응답에서 record_items 호출의 items를 꺼낸다. 없으면 null.
function extractItems(resp) {
    if (!resp || !Array.isArray(resp.content)) return null;
    const block = resp.content.find((b) => b && b.type === "tool_use" && b.name === "record_items");
    if (!block || !block.input) return null;
    return cleanItems(block.input.items);
}

module.exports = {
    MODEL, MAX_IMAGE_BASE64, MAX_ITEMS, DAILY_LIMIT, SYSTEM_PROMPT, TOOL,
    sniffMime, validateImage, buildRequest, cleanItems, extractItems,
};
