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
async function sendMulticast(tokens, title, body, open = "work_logs") {
    if (tokens.length === 0) return false;
    try {
        const response = await admin.messaging().sendEachForMulticast({
            notification: { title, body },
            // 앱이 만든 "현장 중요 알림" 채널로 보내고(예전엔 FCM 기본 "기타" 채널),
            // 누르면 앱이 [open] 화면을 연다(main.dart routeForNotification) — 기본은 작업 일지.
            android: { notification: { channelId: "high_importance_channel" } },
            data: { open },
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
const { canUseAi, rejectedUids } = require("./access");
const { mergeFlags, flagRecorder } = require("./flag_merge");

async function loadRecipients() {
    const usersSnap = await admin.firestore().collection('users').get();
    // 10-09: 사용 승인에서 거절된 사람은 알림에서 뺀다. 못 읽으면 예전처럼 모두에게.
    let blocked = new Set();
    try {
        const members = await admin.firestore().collection('app_members').get();
        blocked = rejectedUids(members.docs.map((d) => ({ id: d.id, data: d.data() })));
    } catch (e) {
        console.error("❌ 사용 승인 목록 조회 실패(거절된 사람 빼기 건너뜀):", e);
    }
    return collectRecipients(
        usersSnap.docs.map((d) => ({ name: d.id, data: d.data() })),
        blocked,
    );
}

// 알림 보낸 표시를 최신 목록에 그 항목만 넣는다(flag_merge.js 설명).
async function saveFlags(ref, field, updates) {
    if (updates.size === 0) return;
    await admin.firestore().runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) return;
        const next = mergeFlags(snap.get(field), updates);
        if (next) tx.update(ref, { [field]: next });
    });
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
        const flags = flagRecorder();
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
                        flags.mark(schedule, { lastOverdueReminderDate: today });
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
                        flags.mark(schedule, { lastOverdueReminderDate: today });
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
                                flags.mark(schedule, { lastLeadReminderDate: today });
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
                            flags.mark(schedule, { reminderSent: true });
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

        if (flags.updates.size > 0) {
            try {
                await saveFlags(doc.ref, 'schedules', flags.updates);
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
        const flags = flagRecorder();

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
                    flags.mark(punch, { lastPunchReminderAt: admin.firestore.Timestamp.fromMillis(now) });
                }
            } catch (innerError) {
                console.error(
                    `❌ (이슈) 알림 실패 (프로젝트: ${doc.id}, 이슈: ${punch.id}):`,
                    innerError,
                );
            }
        }

        if (flags.updates.size > 0) {
            try {
                await saveFlags(doc.ref, 'punch_lists', flags.updates);
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


// ============================================================================
// 7. [신규 2026-09-26] 전기 기준(KEC) — 새 개정 공고 알림(A)과 요약 올리기(B)
// ============================================================================
// 매일 아침 6시(KST)에 한 번:
//   B. 요약(kec_content.json)의 판 번호가 서버 문서보다 높으면 reference_content/kec 에
//      올린다 — 앱을 다시 깔지 않아도 모든 폰이 새 요약을 본다.
//   A. 법제처 Open API로 KEC 현행 공고를 읽어 latest 에 적고, 요약 기준 공고보다 새 공고면
//      모든 폰에 한 번 알린다(누르면 현장 자료 → 전기 기준 탭).
// 법제처 인증값(OC)은 공개 저장소에 두지 않고 비밀값으로 받는다:
//   firebase functions:secrets:set LAW_OC   (값이 아직 없으면 none — 확인만 건너뜀)
const { defineSecret } = require("firebase-functions/params");
const kec = require("./kec");
const KEC_CONTENT = require("./kec_content.json");
const LAW_OC = defineSecret("LAW_OC");

exports.checkKecNotice = onSchedule(
    { schedule: "0 6 * * *", timeZone: "Asia/Seoul", secrets: [LAW_OC] },
    async (event) => {
        const ref = admin.firestore().collection("reference_content").doc("kec");
        const snap = await ref.get();
        const doc = snap.exists ? snap.data() : {};
        const now = admin.firestore.Timestamp.now();
        const update = {};

        if (kec.shouldPublishContent(doc, KEC_CONTENT)) {
            update.content = KEC_CONTENT;
            update.contentVersion = KEC_CONTENT.version;
        }
        const content = update.content || doc.content || KEC_CONTENT;

        const oc = kec.usableOc(LAW_OC.value());
        let latest = null;
        if (!oc) {
            update.check = { ok: false, at: now, message: "법제처 API 인증값이 아직 없습니다" };
        } else {
            try {
                latest = await kec.fetchCurrentKec(oc);
                update.latest = latest;
                update.check = { ok: true, at: now, message: "" };
            } catch (e) {
                console.error("❌ (KEC) 법제처 확인 실패:", e);
                update.check = { ok: false, at: now, message: String(e.message || e).slice(0, 200) };
            }
        }

        if (latest && kec.shouldNotify(latest, content.basis, doc.notifiedSerial)) {
            try {
                const recipients = await loadRecipients();
                const sent = await sendMulticast(
                    recipients.all,
                    "⚡ 전기 기준(KEC) 새 개정 공고",
                    `공고 제${latest.noticeNo}호(${latest.revision}, ${latest.issued} 발령). 현장 자료 → 전기 기준 탭에서 원문을 확인하십시오.`,
                    "reference_kec",
                );
                if (sent) update.notifiedSerial = latest.serial;
            } catch (e) {
                console.error("❌ (KEC) 알림 실패:", e);
            }
        }

        await ref.set(update, { merge: true });
    },
);

// ============================================================================
// AI 도우미(2026-09-30 시범): 작업 일지 "AI로 다듬기", 자재 요청 메모 사진 읽기
// ============================================================================
// 앱에는 키가 없다. 로그인한 사용자만 부를 수 있고, 기능별로 하루 횟수 상한이 있다.
// 키(ANTHROPIC_API_KEY)는 `firebase functions:secrets:set ANTHROPIC_API_KEY`로 넣는다.
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const aiPolish = require("./ai_polish");
const aiMaterial = require("./ai_material");
const aiAsk = require("./ai_ask");
const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");
const AI_OPTIONS = { secrets: [ANTHROPIC_API_KEY], region: "asia-northeast3", maxInstances: 5 };

// 하루 횟수 확인 + 증가를 한 번에(동시에 눌러도 상한을 못 넘게 트랜잭션).
async function takeDailyUse(collection, uid, limit) {
    const ref = admin.firestore().collection(collection).doc(uid);
    const usage = await admin.firestore().runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const u = aiPolish.nextUsage(snap.exists ? snap.data() : null, new Date(), limit);
        if (u.allowed) tx.set(ref, { day: u.day, count: u.count });
        return u;
    });
    if (!usage.allowed) {
        throw new HttpsError("resource-exhausted", `오늘 이 기능은 ${usage.limit}번까지입니다`);
    }
    return usage;
}

async function callAnthropic(payload) {
    try {
        const res = await fetch("https://api.anthropic.com/v1/messages", {
            method: "POST",
            headers: {
                "content-type": "application/json",
                "x-api-key": ANTHROPIC_API_KEY.value(),
                "anthropic-version": "2023-06-01",
            },
            body: JSON.stringify(payload),
        });
        if (!res.ok) {
            console.error("❌ (AI) 응답 오류:", res.status, (await res.text()).slice(0, 300));
            throw new Error(`status ${res.status}`);
        }
        return await res.json();
    } catch (e) {
        console.error("❌ (AI) 호출 실패:", e);
        throw new HttpsError("unavailable", "AI가 지금 응답하지 않습니다");
    }
}

// AI가 실패했을 때는 사용자가 아무것도 못 받았으니 횟수를 돌려준다(실패해도 상한만 줄어드는 일 방지).
async function refundDailyUse(collection, uid) {
    try {
        const ref = admin.firestore().collection(collection).doc(uid);
        await admin.firestore().runTransaction(async (tx) => {
            const snap = await tx.get(ref);
            const d = snap.exists ? snap.data() : null;
            if (d && Number.isFinite(d.count) && d.count > 0) tx.set(ref, { day: d.day, count: d.count - 1 });
        });
    } catch (e) {
        console.error("❌ (AI) 횟수 되돌리기 실패:", e);
    }
}

function requireUid(request) {
    const uid = request.auth && request.auth.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    return uid;
}

// 10-09 사용자 결정: 로그인만 확인하던 것을 승인된 사람·관리자만으로(access.js 설명).
async function requireApproved(request) {
    const uid = requireUid(request);
    const token = request.auth.token || {};
    let member = null;
    try {
        const snap = await admin.firestore().collection("app_members").doc(uid).get();
        member = snap.exists ? snap.data() : null;
    } catch (e) {
        console.error("❌ (AI) 사용 승인 확인 실패:", e);
        throw new HttpsError("unavailable", "사용 승인을 확인하지 못했습니다");
    }
    if (!canUseAi(token, member)) {
        throw new HttpsError("permission-denied", "사용 승인을 받은 사람만 쓸 수 있습니다");
    }
    return uid;
}

exports.polishDailyNote = onCall({ ...AI_OPTIONS, timeoutSeconds: 30 }, async (request) => {
    const uid = await requireApproved(request);
    const checked = aiPolish.validateInput(request.data && request.data.text);
    if (checked.error) throw new HttpsError("invalid-argument", checked.error);
    const usage = await takeDailyUse("ai_usage", uid, aiPolish.DAILY_LIMIT);

    let text;
    try {
        text = aiPolish.extractText(await callAnthropic(aiPolish.buildRequest(checked.text)));
        if (!text) throw new HttpsError("internal", "AI가 빈 답을 보냈습니다");
    } catch (e) {
        await refundDailyUse("ai_usage", uid);
        throw e;
    }
    return { text, remaining: usage.limit - usage.count };
});

// 자료 검색에서 앱 자료로 답을 못 찾았을 때 "AI에게 물어보기". 질문 글만 받고, 하루 횟수 상한이 있다.
exports.askFieldQuestion = onCall({ ...AI_OPTIONS, timeoutSeconds: 40 }, async (request) => {
    const uid = await requireApproved(request);
    const checked = aiAsk.validateQuestion(request.data && request.data.question);
    if (checked.error) throw new HttpsError("invalid-argument", checked.error);
    const usage = await takeDailyUse("ai_usage_ask", uid, aiAsk.DAILY_LIMIT);

    let text;
    try {
        text = aiAsk.extractText(await callAnthropic(aiAsk.buildRequest(checked.question)));
        if (!text) throw new HttpsError("internal", "AI가 빈 답을 보냈습니다");
    } catch (e) {
        await refundDailyUse("ai_usage_ask", uid);
        throw e;
    }
    return { text, remaining: usage.limit - usage.count };
});

exports.parseMaterialNote = onCall({ ...AI_OPTIONS, timeoutSeconds: 60, memory: "512MiB" }, async (request) => {
    const uid = await requireApproved(request);
    const d = request.data || {};
    const checked = aiMaterial.validateImage(d.image);
    if (checked.error) throw new HttpsError("invalid-argument", checked.error);
    const usage = await takeDailyUse("ai_usage_material", uid, aiMaterial.DAILY_LIMIT);

    let items;
    try {
        items = aiMaterial.extractItems(await callAnthropic(aiMaterial.buildRequest(checked.data, checked.mime)));
        if (!items) throw new HttpsError("internal", "AI가 목록을 만들지 못했습니다");
    } catch (e) {
        await refundDailyUse("ai_usage_material", uid);
        throw e;
    }
    return { items, remaining: usage.limit - usage.count };
});
