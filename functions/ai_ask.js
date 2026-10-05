// 자료 검색 "AI에게 물어보기" — 순수 함수만 모았다(테스트 가능). 호출·비밀값은 index.js에 있다.
// 앱 자료에서 답을 못 찾았을 때만 쓰는 보조 기능이다. AI가 원래 아는 지식으로 답하므로 틀릴 수 있고,
// 그래서 모르면 모른다고 하게 하고, 수치·설정값을 확실하지 않게 말하지 않게 한다.

const MODEL = "claude-haiku-4-5-20251001";
const MAX_QUESTION_CHARS = 300; // 질문 길이 상한(질문 글만 보낸다)
const DAILY_LIMIT = 20; // 사용자 한 명이 하루에 물을 수 있는 횟수

const SYSTEM_PROMPT = [
    "당신은 발전소 계측·배관·전기 현장 작업자를 돕는 도우미입니다.",
    "작업자가 현장에서 궁금한 것을 짧게 묻습니다. 아는 범위에서 쉽고 정확하게 답합니다.",
    "규칙:",
    "1. 확실하지 않으면 '정확히 모릅니다'라고 말하고 지어내지 않습니다.",
    "2. 장비 모델별 수치, 설정값, 규격, 법규 조문 번호는 확실하지 않으면 말하지 않고 '설명서나 절차서로 확인하십시오'라고 안내합니다.",
    "3. 압력, 전기, 가스, 고온 등 안전과 관계된 내용은 마지막 줄에 '※ 안전 관련 내용은 반드시 설명서·절차서·안전 담당자에게 확인하십시오'를 붙입니다.",
    "4. 출처나 문서 이름을 지어내지 않습니다. 모르는 출처는 말하지 않습니다.",
    "5. 존댓말로, 10줄 이내로, 필요하면 줄바꿈과 짧은 목록으로 답합니다. 인사말과 군더더기를 쓰지 않습니다.",
    "6. 질문에 개인 정보나 회사 기밀이 있어 보여도 그 내용을 되풀이하지 않습니다.",
    "7. 마크다운 기호(별표 두 개, 샵, 백틱)를 쓰지 않습니다. 강조 표시 없이 평범한 글로 쓰고, 목록은 숫자와 점 또는 하이픈만 씁니다.",
].join("\n");

// 질문 검사. 문제가 있으면 { error }, 괜찮으면 { question }.
function validateQuestion(raw) {
    if (typeof raw !== "string") return { error: "질문이 없습니다" };
    const question = raw.trim();
    if (question.length < 2) return { error: "질문이 너무 짧습니다" };
    if (question.length > MAX_QUESTION_CHARS) return { error: `질문이 너무 깁니다 (최대 ${MAX_QUESTION_CHARS}자)` };
    return { question };
}

function buildRequest(question) {
    return {
        model: MODEL,
        max_tokens: 700,
        temperature: 0.2,
        system: SYSTEM_PROMPT,
        messages: [{ role: "user", content: question }],
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

module.exports = { MODEL, MAX_QUESTION_CHARS, DAILY_LIMIT, SYSTEM_PROMPT, validateQuestion, buildRequest, extractText };
