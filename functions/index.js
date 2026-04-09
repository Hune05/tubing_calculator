const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
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