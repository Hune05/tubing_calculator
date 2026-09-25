const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

// 파이어베이스 관리자 권한 초기화 (한 번만 호출하면 됨)
admin.initializeApp();

// ============================================================================
// 🚀 [정리 2026-09-25] 발주(orders)·채팅 기능은 앱에서 09-23에 지웠다. 서버에 남아 있던
// sendOrderNotification·sendChatPushNotification·checkUpcomingDeliveries(15분마다
// orders를 읽음)를 뺐다. 배포할 때 firebase가 이 세 함수를 지울지 물으면 지우면 된다.
// ============================================================================

const LEAD_MINUTES = 60; // 일정 시각보다 몇 분 전에 알릴지
const WINDOW_MINUTES = 15; // 알림 함수의 실행 주기(스케줄과 맞춰야 함)

// 한국 시간(UTC+9) 기준 "YYYY-MM-DD" 문자열. 하루 한 번 발송 여부를
// 이 문자열로 비교해서 판단한다.
function kstDateString(date) {
    const kst = new Date(date.getTime() + 9 * 60 * 60 * 1000);
    return kst.toISOString().slice(0, 10);
}

// ============================================================================
// 4. [신규] "내 프로젝트" 일정 알림 (자재 요청/입고일/납기일/검사일정 등)
// ============================================================================
// my_projects 컬렉션의 각 문서 안에 있는 schedules 배열(모바일
// ProjectSchedulePage에서 등록)을 훑어서 (A) 곧 다가오는 일정과 (B) 이미
// 지난 일정에 대해 알림을 보낸다. 배열 안의 날짜는 Firestore가 직접
// range 쿼리를 걸어줄 수 없어서, 문서를 전부 가져와 코드에서 훑는다 -
// 개인용 앱이라 프로젝트/일정 개수가 적어 문제없다. 받는 사람은 아래
// tokensFor(주인·담당자)로 고른다.
async function sendMulticast(tokens, title, body) {
    if (tokens.length === 0) return false;
    try {
        const response = await admin.messaging().sendEachForMulticast({
            notification: { title, body },
            // 앱이 만든 "현장 중요 알림" 채널로 보내고(예전엔 FCM 기본 "기타" 채널),
            // 누르면 앱이 작업 일지 화면을 연다(main.dart routeForNotification).
            android: { notification: { channelId: "high_importance_channel" } },
            data: { open: "work_logs" },
            tokens,
        });
        return response.successCount > 0;
    } catch (e) {
        console.error("❌ 멀티캐스트 알림 전송 실패:", e);
        return false;
    }
}

// ============================================================================
// 🚀 [고침 2026-09-25, 점검 27번] 예전에는 users에 등록된 모든 폰으로 보냈다. 남과 같이
// 쓰면 남의 현장 일정·이슈 알림이 내 폰으로 왔다. 이제 받을 사람을 고른다:
//   - 주인(ownerUid)이 있는 프로젝트: 주인 폰 + (이슈면) 담당자 폰
//   - 주인이 없거나 빈 글(예전 프로젝트, "공용으로 돌리기"): 예전처럼 모두(+담당자)
// ============================================================================
const { tokensFor, collectRecipients } = require("./recipients");

async function loadRecipients() {
    const usersSnap = await admin.firestore().collection('users').get();
    return collectRecipients(usersSnap.docs.map((d) => ({ name: d.id, data: d.data() })));
}

exports.checkProjectSchedules = onSchedule("every 15 minutes", async (event) => {
    const now = Date.now();
    const today = kstDateString(new Date(now));

    let recipients;
    try {
        recipients = await loadRecipients();
    } catch (e) {
        console.error("❌ (일정) 사용자 토큰 조회 에러:", e);
        return;
    }
    if (recipients.all.length === 0) {
        console.log("일정 알림을 보낼 기기 토큰이 없습니다.");
        return;
    }

    let projectsSnap;
    try {
        projectsSnap = await admin.firestore().collection('my_projects').get();
    } catch (e) {
        console.error("❌ (일정) 내 프로젝트 조회 에러:", e);
        return;
    }

    for (const doc of projectsSnap.docs) {
        const data = doc.data();
        const schedules = Array.isArray(data.schedules) ? data.schedules : [];
        if (schedules.length === 0) continue;

        const projectName = data.name || '프로젝트';
        let mutated = false;
        const tokens = tokensFor(recipients, data, null);
        if (tokens.length === 0) continue;

        for (const schedule of schedules) {
            if (schedule.isCompleted) continue;

            const label = schedule.title || schedule.type || '일정';

            // 🚀 [추가] "자재 요청"인데 아직 입고일을 몰라서 dateTime이
            // 없는 경우 - 발주 후 입고 소식이 없으면 하루 1회씩 확인해
            // 보라고 반복 알림을 보낸다(자재 발주의 "발주한 지 며칠 지남"
            // 알림과 동일한 개념). 입고일을 받아 dateTime이 채워지면
            // 이 분기 대신 아래 (A)/(B) 로직이 적용된다.
            if (schedule.type === "자재 요청" && !schedule.dateTime) {
                if (schedule.lastOverdueReminderDate === today) continue;

                try {
                    const requestedAt = schedule.requestedAt && schedule.requestedAt.toDate
                        ? schedule.requestedAt.toDate()
                        : (schedule.requestedAt ? new Date(schedule.requestedAt) : null);
                    const daysSince = requestedAt
                        ? Math.max(0, Math.floor((now - requestedAt.getTime()) / (24 * 60 * 60 * 1000)))
                        : null;
                    const body = daysSince && daysSince > 0
                        ? `[${projectName}] "${label}" 요청한 지 ${daysSince}일 지났는데 아직 입고일 소식이 없습니다. 확인해보세요.`
                        : `[${projectName}] "${label}" 자재 요청을 확인해주세요.`;

                    const sent = await sendMulticast(tokens, "🚚 자재 요청 확인 필요", body);
                    if (sent) {
                        schedule.lastOverdueReminderDate = today;
                        mutated = true;
                    }
                } catch (innerError) {
                    console.error(
                        `❌ (일정) 자재 요청 알림 실패 (프로젝트: ${doc.id}, 일정: ${schedule.id}):`,
                        innerError,
                    );
                }
                continue;
            }

            if (!schedule.dateTime) continue;

            const scheduleDate = schedule.dateTime.toDate
                ? schedule.dateTime.toDate()
                : new Date(schedule.dateTime);
            const diffMs = scheduleDate.getTime() - now;

            try {
                // (B) 이미 지남 - 완료 처리 전까지 하루 1회 반복 (리드타임
                // 설정과 무관하게 항상 적용)
                if (diffMs < 0 && schedule.lastOverdueReminderDate !== today) {
                    const daysLate = Math.max(
                        1,
                        Math.floor(-diffMs / (24 * 60 * 60 * 1000)),
                    );
                    const sent = await sendMulticast(
                        tokens,
                        "⏰ 일정 초과",
                        `[${projectName}] ${label} 예정일이 ${daysLate}일 지났습니다.`,
                    );
                    if (sent) {
                        schedule.lastOverdueReminderDate = today;
                        mutated = true;
                    }
                } else if (diffMs >= 0) {
                    // 🚀 [추가] 며칠 전부터 미리 알림받도록 설정했으면(예:
                    // 검사일정 3일 전부터), 그 기간 동안 하루 1회씩 카운트
                    // 다운 알림을 보낸다. 설정 안 했으면(기본값 0) 기존처럼
                    // 60~75분 전에 딱 한 번만 알린다.
                    const leadDays = schedule.reminderLeadDays || 0;

                    if (leadDays > 0) {
                        const leadWindowMs = leadDays * 24 * 60 * 60 * 1000;
                        if (
                            diffMs <= leadWindowMs &&
                            schedule.lastLeadReminderDate !== today
                        ) {
                            const daysLeft = Math.ceil(diffMs / (24 * 60 * 60 * 1000));
                            const sent = await sendMulticast(
                                tokens,
                                "🗓️ 일정 임박",
                                `[${projectName}] ${label} - ${daysLeft > 0 ? `D-${daysLeft}` : "오늘"} 예정입니다.`,
                            );
                            if (sent) {
                                schedule.lastLeadReminderDate = today;
                                mutated = true;
                            }
                        }
                    } else if (
                        !schedule.reminderSent &&
                        diffMs >= LEAD_MINUTES * 60 * 1000 &&
                        diffMs < (LEAD_MINUTES + WINDOW_MINUTES) * 60 * 1000
                    ) {
                        const sent = await sendMulticast(
                            tokens,
                            "🗓️ 일정 알림",
                            `[${projectName}] ${label} 예정 시간이 다가옵니다.`,
                        );
                        if (sent) {
                            schedule.reminderSent = true;
                            mutated = true;
                        }
                    }
                }
            } catch (innerError) {
                console.error(
                    `❌ (일정) 알림 실패 (프로젝트: ${doc.id}, 일정: ${schedule.id}):`,
                    innerError,
                );
            }
        }

        if (mutated) {
            try {
                await doc.ref.update({ schedules });
            } catch (updateError) {
                console.error(`❌ (일정) 알림 플래그 저장 실패 (프로젝트: ${doc.id}):`, updateError);
            }
        }
    }
});


// ============================================================================
// 5. [신규] "이슈 등록"(펀치 리스트) 알림 - 처리 완료 전까지 반복
// ============================================================================
// 일정과 달리 펀치는 목표 날짜가 없다 - 등록되는 순간부터 "처리해야 할 일"
// 이므로, 미리 알림(A) 없이 바로 완료될 때까지 반복해서 알려준다("까먹고
// 안 할 수가 없게"). 두 가지를 반영한다:
//   - 우선순위(긴급/보통/여유)에 따라 알림 주기를 다르게 한다.
//   - 이슈가 "일정 관리"의 검사일정(예: 파이널 검사)에 연결돼 있으면,
//     그 검사일이 24시간 이내로 다가오거나 이미 지났을 때는 우선순위와
//     무관하게 훨씬 자주(3시간 간격) 강하게 알린다.
// 15분마다 실행되는 함수라 하루 1회짜리 "날짜 문자열" 대신, 마지막으로
// 알림을 보낸 "정확한 시각(lastPunchReminderAt)"을 기록해두고 우선순위별
// 시간 간격이 지났는지로 판단한다.
const PUNCH_REMINDER_INTERVAL_HOURS = {
    "긴급": 8, // 하루 여러 번 (아침/점심/저녁 정도)
    "보통": 24, // 하루 1회
    "여유": 72, // 2~3일에 1회
};
const PUNCH_DEADLINE_URGENT_HOURS = 24; // 연결된 검사일정이 이 시간 안으로 다가오면 알림을 강하게(자주) 바꾼다
const PUNCH_DEADLINE_URGENT_INTERVAL_HOURS = 3;

function findLinkedSchedule(schedules, linkedScheduleId) {
    if (!linkedScheduleId) return null;
    return schedules.find((s) => s.id === linkedScheduleId) || null;
}

exports.checkPunchIssues = onSchedule("every 15 minutes", async (event) => {
    const now = Date.now();

    let recipients;
    try {
        recipients = await loadRecipients();
    } catch (e) {
        console.error("❌ (이슈) 사용자 토큰 조회 에러:", e);
        return;
    }
    if (recipients.all.length === 0) {
        console.log("이슈 알림을 보낼 기기 토큰이 없습니다.");
        return;
    }

    let projectsSnap;
    try {
        projectsSnap = await admin.firestore().collection('my_projects').get();
    } catch (e) {
        console.error("❌ (이슈) 내 프로젝트 조회 에러:", e);
        return;
    }

    for (const doc of projectsSnap.docs) {
        const data = doc.data();
        const punchLists = Array.isArray(data.punch_lists) ? data.punch_lists : [];
        if (punchLists.length === 0) continue;

        const schedules = Array.isArray(data.schedules) ? data.schedules : [];
        const projectName = data.name || '프로젝트';
        let mutated = false;

        for (const punch of punchLists) {
            if (punch.is_completed) continue;
            if (!punch.id) continue; // 식별자 없는(과거) 이슈는 대상에서 제외

            try {
                const linkedSchedule = findLinkedSchedule(schedules, punch.linkedScheduleId);
                let deadline = null;
                let deadlineLabel = null;
                if (linkedSchedule && linkedSchedule.dateTime) {
                    deadline = linkedSchedule.dateTime.toDate
                        ? linkedSchedule.dateTime.toDate()
                        : new Date(linkedSchedule.dateTime);
                    deadlineLabel = linkedSchedule.title || linkedSchedule.type || '검사일정';
                } else if (punch.dueDate) {
                    // 🚀 [추가] 검사일정에 연결 안 해도, 등록할 때 직접 정한
                    // 처리 기한(dueDate)이 있으면 그것도 동일하게 취급한다.
                    deadline = punch.dueDate.toDate
                        ? punch.dueDate.toDate()
                        : new Date(punch.dueDate);
                    deadlineLabel = '처리 기한';
                }
                const isDeadlineUrgent = deadline
                    ? (deadline.getTime() - now) < PUNCH_DEADLINE_URGENT_HOURS * 60 * 60 * 1000
                    : false;
                const intervalHours = isDeadlineUrgent
                    ? PUNCH_DEADLINE_URGENT_INTERVAL_HOURS
                    : (PUNCH_REMINDER_INTERVAL_HOURS[punch.priority] || PUNCH_REMINDER_INTERVAL_HOURS["보통"]);

                const lastReminderAt = punch.lastPunchReminderAt && punch.lastPunchReminderAt.toDate
                    ? punch.lastPunchReminderAt.toDate().getTime()
                    : (punch.lastPunchReminderAt ? new Date(punch.lastPunchReminderAt).getTime() : null);
                if (lastReminderAt !== null && (now - lastReminderAt) < intervalHours * 60 * 60 * 1000) {
                    continue;
                }

                const label = punch.content || punch.defect_type || '이슈';

                let title = "🚨 미처리 이슈 알림";
                let body;
                if (deadline && now >= deadline.getTime()) {
                    title = "🚨 기한 초과 이슈";
                    body = `[${projectName}] "${label}" 이슈가 ${deadlineLabel} 기한을 지났는데 아직 처리되지 않았습니다!`;
                } else if (deadline) {
                    const hoursLeft = Math.max(1, Math.round((deadline.getTime() - now) / (60 * 60 * 1000)));
                    title = isDeadlineUrgent ? "⏰ 기한 임박 - 이슈 처리 필요" : "🚨 미처리 이슈 알림";
                    body = `[${projectName}] "${label}" 이슈 - ${deadlineLabel}까지 ${hoursLeft}시간 남았습니다. 처리해주세요.`;
                } else {
                    const createdAt = punch.created_at && punch.created_at.toDate
                        ? punch.created_at.toDate()
                        : (punch.created_at ? new Date(punch.created_at) : null);
                    const daysOpen = createdAt
                        ? Math.max(0, Math.floor((now - createdAt.getTime()) / (24 * 60 * 60 * 1000)))
                        : null;
                    if (punch.priority === "긴급") title = "🚨 긴급 이슈 미처리";
                    body = daysOpen && daysOpen > 0
                        ? `[${projectName}] "${label}" 이슈가 ${daysOpen}일째 처리되지 않았습니다.`
                        : `[${projectName}] "${label}" 이슈를 확인해주세요.`;
                }

                const sent = await sendMulticast(
                    tokensFor(recipients, data, punch.assignee),
                    title,
                    body,
                );
                if (sent) {
                    punch.lastPunchReminderAt = admin.firestore.Timestamp.fromMillis(now);
                    mutated = true;
                }
            } catch (innerError) {
                console.error(
                    `❌ (이슈) 알림 실패 (프로젝트: ${doc.id}, 이슈: ${punch.id}):`,
                    innerError,
                );
            }
        }

        if (mutated) {
            try {
                await doc.ref.update({ punch_lists: punchLists });
            } catch (updateError) {
                console.error(`❌ (이슈) 알림 플래그 저장 실패 (프로젝트: ${doc.id}):`, updateError);
            }
        }
    }
});


// ============================================================================
// 6. [신규] "오늘 작업 일보 작성 확인" 알림 - 매일 저녁 한 번
// ============================================================================
// 진행중인 프로젝트에 "오늘 날짜(MM/DD)"로 작성된 작업 일보가 하나도
// 없으면, 저녁 6시(KST)에 한 번 알려준다. 하루에 한 번만 실행되는
// 스케줄이라 별도 "오늘 보냈는지" 플래그가 필요 없다.
exports.checkDailyReportReminder = onSchedule(
    { schedule: "0 18 * * *", timeZone: "Asia/Seoul" },
    async (event) => {
        const kstNow = new Date(Date.now() + 9 * 60 * 60 * 1000);
        const todayMmDd = `${(kstNow.getUTCMonth() + 1).toString().padStart(2, '0')}/${kstNow.getUTCDate().toString().padStart(2, '0')}`;

        let recipients;
        try {
            recipients = await loadRecipients();
        } catch (e) {
            console.error("❌ (일보) 사용자 토큰 조회 에러:", e);
            return;
        }
        if (recipients.all.length === 0) return;

        let projectsSnap;
        try {
            projectsSnap = await admin.firestore().collection('my_projects').get();
        } catch (e) {
            console.error("❌ (일보) 내 프로젝트 조회 에러:", e);
            return;
        }

        for (const doc of projectsSnap.docs) {
            const data = doc.data();
            if (data.status !== 'ONGOING') continue; // 진행중인 현장만 확인

            const reports = Array.isArray(data.daily_reports) ? data.daily_reports : [];
            const hasTodayReport = reports.some((r) => r.date === todayMmDd);
            if (hasTodayReport) continue;

            const projectName = data.name || '프로젝트';
            try {
                await sendMulticast(
                    tokensFor(recipients, data, null),
                    "📝 오늘 작업 일보를 작성해주세요",
                    `[${projectName}] 오늘(${todayMmDd}) 작업 일보가 아직 작성되지 않았습니다.`,
                );
            } catch (e) {
                console.error(`❌ (일보) 알림 실패 (프로젝트: ${doc.id}):`, e);
            }
        }
    },
);