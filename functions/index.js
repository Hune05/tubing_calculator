const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

// 파이어베이스 관리자 권한 초기화 (한 번만 호출하면 됨)
admin.initializeApp();

// ============================================================================
// 1. [수정됨] 자재 발주 알림 요정 (토픽 전체 방송 -> 개별 타겟팅으로 변경)
// ============================================================================
// 신규 생성뿐만 아니라 상태 변경(업데이트)도 감지하기 위해 onDocumentWritten 사용
exports.sendOrderNotification = onDocumentWritten("orders/{orderId}", async (event) => {
    // 문서가 삭제된 경우는 무시
    if (!event.data.after.exists) return;

    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    let targetUserName = "";
    let title = "";
    let body = "";

    // 1️⃣ [신규 발주] 새로 생성되었을 때
    if (!beforeData) {
        targetUserName = afterData.assignee; // 수신자(담당자)에게 보냄
        
        // 혹시 자기가 자기한테 발주를 넣은 거라면 알림 생략!
        if (targetUserName === afterData.requester) {
            console.log("자신에게 보낸 발주이므로 알림 생략");
            return;
        }

        const itemsCount = afterData.items ? afterData.items.length : 0;
        title = "📦 신규 자재 발주 요청";
        body = `${afterData.requester}님이 ${itemsCount}건의 자재를 발주했습니다.`;
    } 
    // 2️⃣ [상태 변경] 관리자가 발주 상태를 바꿨을 때 (반려, 진행중, 완료 등)
    else if (beforeData.status !== afterData.status) {
        targetUserName = afterData.requester; // 원래 요청했던 사람에게 결과 전송
        
        // 내가 내 발주 상태를 바꾼 거면 알림 생략
        if (targetUserName === afterData.assignee) return;

        title = "📝 발주 상태 업데이트";
        body = `요청하신 발주 건이 [${afterData.status}](으)로 변경되었습니다.`;
        
        if (afterData.status === "반려됨") {
            title = "🚨 발주 반려 안내";
            body = `요청하신 발주가 반려되었습니다. 사유: ${afterData.rejectReason}`;
        }
    } 
    // 그 외의 단순 수정은 알림 안 보냄
    else {
        return;
    }

    try {
        // 🎯 타겟 유저(받을 사람)의 토큰을 DB에서 찾아서 알림 쏘기
        const userDoc = await admin.firestore().collection('users').doc(targetUserName).get();
        
        if (userDoc.exists) {
            const fcmToken = userDoc.data().fcmToken;
            
            if (fcmToken) {
                const payload = {
                    notification: {
                        title: title,
                        body: body,
                    },
                    token: fcmToken, // 토픽(topic) 대신 특정 기기 토큰(token) 사용!
                };

                await admin.messaging().send(payload);
                console.log(`✅ ${targetUserName}님에게 발주 알림 전송 성공!`);
            } else {
                console.log(`⚠️ ${targetUserName}님의 토큰이 없습니다.`);
            }
        }
    } catch (error) {
        console.error("❌ 발주 알림 전송 에러:", error);
    }
});


// ============================================================================
// 2. [기존] 채팅 메시지 알림 요정 (유지: 이미 완벽하게 짜여 있음)
// ============================================================================
exports.sendChatPushNotification = onDocumentCreated("chat_rooms/{roomId}/messages/{messageId}", async (event) => {
    const msgData = event.data.data();
    if (!msgData) return;

    const roomId = event.params.roomId;
    const senderName = msgData.senderName || "알림";
    const text = msgData.text || "📷 사진을 보냈습니다.";
    const isSystem = msgData.isSystem || false;

    // 시스템 메시지("누가 초대했습니다" 등)는 푸시 알림 안 울리게 막기
    if (isSystem) return;

    try {
        // 1. 해당 채팅방(chat_rooms) 정보 가져오기
        const roomDoc = await admin.firestore().collection('chat_rooms').doc(roomId).get();
        if (!roomDoc.exists) return;

        const participants = roomDoc.data().participants || [];

        // 🔥 2. 가장 중요한 부분: 참여자 목록에서 '나(보낸 사람)' 제외하기
        const receivers = participants.filter(user => user !== senderName);

        // 받을 사람이 없다면 종료
        if (receivers.length === 0) {
            console.log("알림을 받을 대상이 없습니다.");
            return;
        }

        // 3. 수신자들의 기기 고유 토큰(fcmToken) 가져오기
        const tokens = [];
        for (const user of receivers) {
            const userDoc = await admin.firestore().collection('users').doc(user).get();
            
            if (userDoc.exists) {
                const fcmToken = userDoc.data().fcmToken;
                if (fcmToken) {
                    tokens.push(fcmToken);
                }
            }
        }

        // 4. 수집된 토큰이 있다면 개별 전송 (나를 제외한 나머지에게만)
        if (tokens.length > 0) {
            const message = {
                notification: {
                    title: `💬 ${senderName}`,
                    body: text,
                },
                tokens: tokens, // 필터링된 토큰 배열
            };

            const response = await admin.messaging().sendEachForMulticast(message);
            console.log(`✅ 채팅 알림 전송 성공 (방: ${roomId}, 발송된 기기 수: ${response.successCount})`);
        } else {
            console.log("⚠️ 알림을 보낼 기기 토큰을 찾을 수 없습니다.");
        }

    } catch (error) {
        console.error("❌ 채팅 알림 전송 에러:", error);
    }
});


// ============================================================================
// 3. [신규] 자재 입고 관련 알림 3종 (캘린더 알람처럼 폰으로 미리/뒤늦게
//    알려준다)
// ============================================================================
// 15분마다 실행해서 세 가지를 확인한다:
//   (A) 입고 예정 시각이 곧 다가옴 (60~75분 전 미리 알림)
//   (B) 입고 예정일을 지정해뒀는데 그 시각이 이미 지나버림 (기한 초과)
//   (C) 입고 예정일 자체를 아직 안 정했는데, 발주한 지 며칠 지남
//       (보통 3~4일이면 들어온다고 가정하고, 그 기준을 넘기면 확인 알림)
// (B)/(C)는 하루에 한 번만 보내도록 "오늘 날짜(KST)"를 기록해둔다 - 15분마다
// 도는 함수라 그냥 불리언 플래그만 쓰면 한 번 보낸 뒤로 다신 안 울리기 때문.
const LEAD_MINUTES = 60; // (A) 입고 예정 시각보다 몇 분 전에 알릴지
const WINDOW_MINUTES = 15; // 이 함수의 실행 주기(스케줄과 맞춰야 함)
const ASSUMED_DELIVERY_DAYS = 4; // (C) "보통 3~4일" 가정 - 상한인 4일로 판단

// 한국 시간(UTC+9) 기준 "YYYY-MM-DD" 문자열. 하루 한 번 발송 여부를
// 이 문자열로 비교해서 판단한다.
function kstDateString(date) {
    const kst = new Date(date.getTime() + 9 * 60 * 60 * 1000);
    return kst.toISOString().slice(0, 10);
}

// 발주 건 하나를 대상으로 담당자(없으면 요청자)에게 푸시를 보내는 공통 로직.
async function sendPushForOrder(doc, title, body) {
    const data = doc.data();
    const targetUserName = data.assignee || data.requester;
    if (!targetUserName) return false;

    const userDoc = await admin.firestore().collection('users').doc(targetUserName).get();
    if (!userDoc.exists) return false;

    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) {
        console.log(`⚠️ ${targetUserName}님의 토큰이 없습니다.`);
        return false;
    }

    await admin.messaging().send({
        notification: { title, body },
        token: fcmToken,
    });
    console.log(`✅ ${targetUserName}님에게 알림 전송 성공! (주문: ${doc.id}) - ${title}`);
    return true;
}

exports.checkUpcomingDeliveries = onSchedule("every 15 minutes", async (event) => {
    const now = Date.now();
    const today = kstDateString(new Date(now));

    // ------------------------------------------------------------------
    // (A) 입고 예정 시각이 60~75분 후로 다가옴 - 1회성 미리 알림
    // ------------------------------------------------------------------
    try {
        const windowStart = admin.firestore.Timestamp.fromMillis(now + LEAD_MINUTES * 60 * 1000);
        const windowEnd = admin.firestore.Timestamp.fromMillis(now + (LEAD_MINUTES + WINDOW_MINUTES) * 60 * 1000);

        const snapshot = await admin.firestore()
            .collection('orders')
            .where('expectedDate', '>=', windowStart)
            .where('expectedDate', '<', windowEnd)
            .get();

        for (const doc of snapshot.docs) {
            const data = doc.data();
            if (data.deliveryReminderSent) continue;
            if (data.status === "처리 완료" || data.status === "반려됨") continue;

            try {
                const expectedDate = data.expectedDate.toDate();
                const hh = expectedDate.getHours().toString().padStart(2, '0');
                const mm = expectedDate.getMinutes().toString().padStart(2, '0');
                const itemsCount = data.items ? data.items.length : 0;

                const sent = await sendPushForOrder(
                    doc,
                    "🚚 자재 입고 예정 알림",
                    `${hh}:${mm}경 자재(${itemsCount}건) 입고 예정입니다.`,
                );
                if (sent) await doc.ref.update({ deliveryReminderSent: true });
            } catch (innerError) {
                console.error(`❌ (A) 입고 예정 알림 전송 실패 (주문: ${doc.id}):`, innerError);
            }
        }
    } catch (error) {
        console.error("❌ (A) 입고 예정 알림 조회 에러:", error);
    }

    // ------------------------------------------------------------------
    // (B) 입고 예정일이 지정돼 있는데 이미 그 시각이 지남 - 하루 1회 반복
    // ------------------------------------------------------------------
    try {
        const nowTs = admin.firestore.Timestamp.fromMillis(now);
        const snapshot = await admin.firestore()
            .collection('orders')
            .where('expectedDate', '<', nowTs)
            .get();

        for (const doc of snapshot.docs) {
            const data = doc.data();
            if (data.status === "처리 완료" || data.status === "반려됨") continue;
            if (!data.expectedDate) continue;
            // 오늘 이미 보냈으면 건너뛴다 (하루 1회).
            if (data.lastOverdueReminderDate === today) continue;

            try {
                const expectedDate = data.expectedDate.toDate();
                const daysLate = Math.max(
                    1,
                    Math.floor((now - expectedDate.getTime()) / (24 * 60 * 60 * 1000)),
                );
                const itemsCount = data.items ? data.items.length : 0;

                const sent = await sendPushForOrder(
                    doc,
                    "⏰ 자재 입고 기한 초과",
                    `입고 예정일이 ${daysLate}일 지났는데 아직 처리 완료되지 않았습니다 (${itemsCount}건). 확인해주세요.`,
                );
                if (sent) await doc.ref.update({ lastOverdueReminderDate: today });
            } catch (innerError) {
                console.error(`❌ (B) 입고 기한 초과 알림 실패 (주문: ${doc.id}):`, innerError);
            }
        }
    } catch (error) {
        console.error("❌ (B) 입고 기한 초과 조회 에러:", error);
    }

    // ------------------------------------------------------------------
    // (C) 입고 예정일 자체가 없는데 발주한 지 ASSUMED_DELIVERY_DAYS일 이상
    //     지남 - "보통 3~4일이면 온다"는 가정 기준 확인 알림, 하루 1회 반복
    // ------------------------------------------------------------------
    try {
        const snapshot = await admin.firestore()
            .collection('orders')
            .where('expectedDate', '==', null)
            .get();

        for (const doc of snapshot.docs) {
            const data = doc.data();
            if (data.status === "처리 완료" || data.status === "반려됨") continue;
            if (!data.requestDate) continue;
            if (data.lastCheckinReminderDate === today) continue;

            const requestDate = data.requestDate.toDate();
            const daysSinceRequest = Math.floor(
                (now - requestDate.getTime()) / (24 * 60 * 60 * 1000),
            );
            if (daysSinceRequest < ASSUMED_DELIVERY_DAYS) continue;

            try {
                const itemsCount = data.items ? data.items.length : 0;
                const sent = await sendPushForOrder(
                    doc,
                    "📋 자재 입고 확인 필요",
                    `발주한 지 ${daysSinceRequest}일 지났는데 입고 예정일이 아직 없습니다 (${itemsCount}건). 거래처에 확인해보세요.`,
                );
                if (sent) await doc.ref.update({ lastCheckinReminderDate: today });
            } catch (innerError) {
                console.error(`❌ (C) 입고 확인 알림 실패 (주문: ${doc.id}):`, innerError);
            }
        }
    } catch (error) {
        console.error("❌ (C) 입고 확인 조회 에러:", error);
    }
});