// 알림을 받을 폰 고르기(점검 27번). 서버 없이 시험할 수 있게 따로 둔다.

// users 문서들(이름, 내용)에서 토큰 모음을 만든다.
function collectRecipients(userDocs) {
    const all = [];
    const byUid = new Map();
    const byName = new Map();
    for (const { name, data } of userDocs) {
        const t = data.fcmToken;
        if (!t) continue;
        all.push(t);
        if (data.uid) {
            if (!byUid.has(data.uid)) byUid.set(data.uid, []);
            byUid.get(data.uid).push(t);
        }
        byName.set(name, t); // 문서 이름 = 앱에서 쓰는 이름
    }
    return { all, byUid, byName };
}

// 이 프로젝트(와 담당자) 알림을 받을 토큰.
function tokensFor(recipients, project, assigneeName) {
    const owner = (project.ownerUid || '').toString().trim();
    const out = new Set(owner ? (recipients.byUid.get(owner) || []) : recipients.all);
    const who = (assigneeName || '').toString().trim();
    if (who && recipients.byName.has(who)) out.add(recipients.byName.get(who));
    return [...out];
}

module.exports = { collectRecipients, tokensFor };
