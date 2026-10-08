// 누가 서버 기능(AI·알림)을 쓸 수 있는지. 서버 없이 시험할 수 있게 따로 둔다.
// 10-09 사용자 결정: AI 함수 3개가 로그인만 확인해서 거절된 사람·익명도 부를 수 있었다(요금).
// 앱의 승인제(app_members/{uid}.status)와 같은 기준으로, 승인된 사람과 관리자만 쓴다.

// 관리자 계정(앱 member_approval.dart kAdminEmail, firestore.rules isAdmin()과 같은 값).
const ADMIN_EMAIL = "a01020020271@gmail.com";

function isAdminToken(token) {
    return !!token && token.email === ADMIN_EMAIL && token.email_verified === true;
}

// AI를 써도 되는지: 관리자이거나 app_members 문서가 승인됨.
function canUseAi(token, memberData) {
    if (isAdminToken(token)) return true;
    return !!memberData && memberData.status === "approved";
}

// 알림에서 뺄 사람(거절된 uid). 대기는 승인제를 켜기 전 쓰는 사람일 수 있어 빼지 않는다.
function rejectedUids(memberDocs) {
    const out = new Set();
    for (const { id, data } of memberDocs) {
        if (data && data.status === "rejected") out.add(id);
    }
    return out;
}

module.exports = { ADMIN_EMAIL, isAdminToken, canUseAi, rejectedUids };
