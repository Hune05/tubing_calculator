// 알림을 보낸 표시(보낸 날짜·시각)를 서버의 최신 목록에 그 항목만 덮어 넣는다.
// 10-09: 알림 함수가 15분마다 프로젝트를 읽고, 알림을 보내는 동안(몇 초) 앱에서 고친 일정·이슈가
// 있어도 처음 읽은 목록 통째로 다시 써서 그 사이 고친 내용이 사라질 수 있었다.
// 이제 트랜잭션 안에서 최신 목록을 다시 읽고, 표시 칸만 그 항목에 넣는다.

function stamp(v) {
    if (v == null) return "";
    if (typeof v.toMillis === "function") return String(v.toMillis());
    if (v instanceof Date) return String(v.getTime());
    return String(v);
}

// 목록 항목을 가리키는 열쇠. id가 있으면 id, 없으면(예전 일정) 제목·종류·날짜.
function itemKey(item) {
    if (!item || typeof item !== "object") return null;
    if (item.id) return `id:${item.id}`;
    return `tt:${item.title || ""}|${item.type || ""}|${stamp(item.dateTime)}|${stamp(item.requestedAt)}`;
}

// [latest] 목록에 [updates](열쇠 → 덮어 넣을 칸)를 넣은 새 목록. 바뀐 것이 없으면 null.
// 그 사이 지워진 항목에는 넣지 않는다.
function mergeFlags(latest, updates) {
    if (!Array.isArray(latest) || !updates || updates.size === 0) return null;
    let changed = false;
    const next = latest.map((item) => {
        const k = itemKey(item);
        const u = k && updates.get(k);
        if (!u) return item;
        changed = true;
        return { ...item, ...u };
    });
    return changed ? next : null;
}

// 알림 함수 안에서 쓰는 기록장: 항목에 바로 적고(같은 실행 안에서 판단에 쓰임) 열쇠별로 모은다.
function flagRecorder() {
    const updates = new Map();
    return {
        updates,
        mark(item, fields) {
            const k = itemKey(item);
            Object.assign(item, fields);
            if (!k) return;
            updates.set(k, { ...(updates.get(k) || {}), ...fields });
        },
    };
}

module.exports = { itemKey, mergeFlags, flagRecorder };
