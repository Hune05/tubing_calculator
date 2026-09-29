// 작업 일지 "AI로 다듬기" — 순수 함수만 모았다(테스트 가능). 호출·비밀값은 index.js에 있다.
// 안전 원칙: AI는 사용자가 적은 말을 문장으로 정리만 한다. 숫자·규격·이름을 새로 만들지 않는다.

const MODEL = "claude-haiku-4-5-20251001";
const MAX_INPUT_CHARS = 1500; // 한 번에 다듬을 글 길이 상한
const DAILY_LIMIT = 30; // 사용자 한 명이 하루에 부를 수 있는 횟수

const SYSTEM_PROMPT = [
    "당신은 발전소 계측·배관 현장 작업 일지를 정리하는 도우미입니다.",
    "사용자가 적은 짧은 메모를 일지에 쓸 수 있는 문장으로 다듬습니다.",
    "규칙:",
    "1. 메모에 없는 사실, 숫자, 규격, 장소, 사람 이름을 절대 새로 넣지 않습니다.",
    "2. 뜻이 바뀌면 안 됩니다. 애매한 부분은 원문 표현을 그대로 둡니다.",
    "3. 문체는 '~했음', '~완료' 같은 현장 일지체 또는 '~했습니다'로, 원문 분위기에 맞춥니다.",
    "4. 항목이 여러 개면 줄바꿈으로 나눕니다. 번호나 글머리 기호는 붙이지 않습니다.",
    "5. 음성 입력의 오탈자·띄어쓰기만 바로잡습니다.",
    "6. 설명·인사·따옴표 없이 다듬은 본문만 출력합니다.",
].join("\n");

// 한국 시간 기준 "YYYY-MM-DD"
function kstDay(date) {
    return new Date(date.getTime() + 9 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

// 입력 검사. 문제가 있으면 { error }, 괜찮으면 { text }.
function validateInput(raw) {
    if (typeof raw !== "string") return { error: "글이 없습니다" };
    const text = raw.trim();
    if (text.length < 2) return { error: "다듬을 글이 너무 짧습니다" };
    if (text.length > MAX_INPUT_CHARS) return { error: `글이 너무 깁니다 (최대 ${MAX_INPUT_CHARS}자)` };
    return { text };
}

// 오늘 사용량 문서(ai_usage/{uid})와 지금 시각으로 다음 상태를 계산한다.
// 한도를 넘었으면 { allowed:false }, 아니면 { allowed:true, next:{day,count} }.
function nextUsage(doc, now, limit = DAILY_LIMIT) {
    const day = kstDay(now);
    const count = doc && doc.day === day && Number.isFinite(doc.count) ? doc.count : 0;
    if (count >= limit) return { allowed: false, day, count, limit };
    return { allowed: true, day, count: count + 1, limit };
}

function buildRequest(text) {
    return {
        model: MODEL,
        max_tokens: 700,
        temperature: 0.2,
        system: SYSTEM_PROMPT,
        messages: [{ role: "user", content: text }],
    };
}

// Anthropic 응답에서 본문만 꺼낸다. 비었으면 null.
function extractText(resp) {
    if (!resp || !Array.isArray(resp.content)) return null;
    const out = resp.content
        .filter((b) => b && b.type === "text" && typeof b.text === "string")
        .map((b) => b.text)
        .join("")
        .trim();
    return out.length > 0 ? out : null;
}

module.exports = {
    MODEL, MAX_INPUT_CHARS, DAILY_LIMIT, SYSTEM_PROMPT,
    kstDay, validateInput, nextUsage, buildRequest, extractText,
};
