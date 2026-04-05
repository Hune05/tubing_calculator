const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

// 파이어베이스 관리자 권한 초기화 (한 번만 호출하면 됨)
admin.initializeApp();

// ============================================================================
// 1. [기존] 자재 발주 알림 요정
// ============================================================================
exports.sendOrderNotification = onDocumentCreated("orders/{orderId}", async (event) => {
    const newOrder = event.data.data();
    if (!newOrder) return;

    const requester = newOrder.requester || "현장 작업자";
    const assignee = newOrder.assignee || "담당자";
    const items = newOrder.items || [];
    const itemsCount = items.length;

    const payload = {
        notification: {
            title: "🔔 신규 자재 발주 요청",
            body: `${requester}님이 ${itemsCount}건의 자재를 발주했습니다. (수신: ${assignee})`,
        },
        topic: "field_orders", 
    };

    try {
        const response = await admin.messaging().send(payload);
        console.log("✅ 발주 알림 자동 전송 성공:", response);
    } catch (error) {
        console.error("❌ 발주 알림 전송 에러:", error);
    }
});


// ============================================================================
// 2. [신규] 채팅 메시지 알림 요정
// ============================================================================
exports.sendChatPushNotification = onDocumentCreated("chat_rooms/{roomId}/messages/{messageId}", async (event) => {
    const msgData = event.data.data();
    if (!msgData) return;

    // 채팅방 ID와 누가 보냈는지 확인
    const roomId = event.params.roomId;
    const senderName = msgData.senderName || "알림";
    const text = msgData.text || "📷 사진을 보냈습니다.";

    const payload = {
        notification: {
            title: `💬 ${senderName}님의 메시지`,
            body: text,
        },
        // 🔥 일단 테스트를 위해 기존과 똑같은 'field_orders' 토픽으로 발송
        // 나중에는 'chat_roomId' 같은 개별 토픽으로 나눠서 알림을 보내는 것이 좋습니다.
        topic: "field_orders", 
    };

    try {
        const response = await admin.messaging().send(payload);
        console.log(`✅ 채팅 알림 자동 전송 성공 (방: ${roomId}):`, response);
    } catch (error) {
        console.error("❌ 채팅 알림 전송 에러:", error);
    }
});