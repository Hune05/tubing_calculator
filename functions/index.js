const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

// 파이어베이스 관리자 권한 초기화
admin.initializeApp();

/**
 * [자동 알림 함수]
 * Firestore의 'orders' 컬렉션에 새 문서(발주)가 생기면 실행됨
 */
exports.sendOrderNotification = onDocumentCreated("orders/{orderId}", async (event) => {
    // 1. 새 발주 데이터 가져오기
    const newOrder = event.data.data();
    if (!newOrder) return;

    // 2. 알림에 띄울 정보 추출
    const requester = newOrder.requester || "현장 작업자";
    const assignee = newOrder.assignee || "담당자";
    const items = newOrder.items || [];
    const itemsCount = items.length;

    // 3. 푸시 알림 내용 구성
    const payload = {
        notification: {
            title: "🔔 신규 자재 발주 요청",
            body: `${requester}님이 ${itemsCount}건의 자재를 발주했습니다. (수신: ${assignee})`,
        },
        // 우리 앱에서 구독 중인 'field_orders' 그룹에 쏘기
        topic: "field_orders", 
    };

    try {
        // 4. FCM 알림 발송
        const response = await admin.messaging().send(payload);
        console.log("✅ 알림 자동 전송 성공:", response);
    } catch (error) {
        console.error("❌ 알림 전송 에러:", error);
    }
});