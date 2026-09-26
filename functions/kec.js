// 전기 기준(KEC) — 새 개정 공고 알아내기(A)와 요약 올리기(B).
//
// 한국전기설비규정(KEC)은 부처 "공고"라 법제처 Open API의 행정규칙(target=admrul)에 있다.
// 개정마다 행정규칙일련번호가 바뀐다(2026-09-26 확인: 현행 공고 제2025-227호, 일련번호
// 2100000270772, 2026-01-05 발령). 본문은 첨부 HWP·PDF뿐이라 요약은 사람이 고친다 —
// 여기서는 "새 공고가 났다"만 알아내고, 요약(kec_content.json)은 판 번호가 오를 때 올린다.
// 법제처 자료를 쓰면 출처(법제처 국가법령정보센터)를 밝혀야 한다 — 앱 KEC 탭에 적는다.

const KEC_NAME = "한국전기설비규정";
const SEARCH_URL = "https://www.law.go.kr/DRF/lawSearch.do";

/** "20260105" → "2026-01-05"(모르면 그대로). */
function isoDate(yyyymmdd) {
    const s = String(yyyymmdd || "");
    return /^\d{8}$/.test(s) ? `${s.slice(0, 4)}-${s.slice(4, 6)}-${s.slice(6, 8)}` : s;
}

/** 사람이 여는 원문 화면 주소. */
function noticeUrl(serial) {
    return `https://www.law.go.kr/LSW/admRulInfoP.do?admRulSeq=${serial}`;
}

/**
 * 법제처 행정규칙 검색 응답(JSON)에서 KEC 현행 공고 한 건을 고른다.
 * 결과가 하나면 목록이 아니라 한 덩어리로 온다.
 */
function pickCurrentKec(json) {
    const search = json && json.AdmRulSearch;
    if (!search) {
        const msg = (json && (json.result || json.msg || json.message)) || "API 응답을 읽지 못했습니다";
        throw new Error(String(msg));
    }
    if (search.resultCode && search.resultCode !== "00") {
        throw new Error(`API 오류 ${search.resultCode}: ${search.resultMsg || ""}`.trim());
    }
    const raw = search.admrul;
    const rows = Array.isArray(raw) ? raw : raw ? [raw] : [];
    const kec = rows.filter((r) => r && r["행정규칙명"] === KEC_NAME);
    const current = kec.filter((r) => r["현행연혁구분"] === "현행");
    const pool = current.length > 0 ? current : kec;
    if (pool.length === 0) throw new Error(`${KEC_NAME}을 찾지 못했습니다`);
    // 여러 건이면 발령일자가 가장 늦은 것(같으면 일련번호가 큰 것).
    pool.sort((a, b) =>
        String(b["발령일자"]).localeCompare(String(a["발령일자"])) ||
        String(b["행정규칙일련번호"]).localeCompare(String(a["행정규칙일련번호"])),
    );
    const r = pool[0];
    const serial = String(r["행정규칙일련번호"] || "");
    if (!serial) throw new Error("일련번호가 없습니다");
    return {
        serial,
        name: KEC_NAME,
        noticeNo: String(r["발령번호"] || ""),
        kind: String(r["행정규칙종류"] || ""),
        ministry: String(r["소관부처명"] || ""),
        revision: String(r["제개정구분명"] || ""),
        issued: isoDate(r["발령일자"]),
        effective: isoDate(r["시행일자"]),
        url: noticeUrl(serial),
    };
}

/** 법제처 API로 KEC 현행 공고를 읽는다. [oc]는 법제처에서 받은 API 인증값. */
async function fetchCurrentKec(oc, fetchImpl = fetch) {
    const url =
        `${SEARCH_URL}?OC=${encodeURIComponent(oc)}&target=admrul&type=JSON` +
        `&display=20&query=${encodeURIComponent(KEC_NAME)}`;
    const res = await fetchImpl(url, { signal: AbortSignal.timeout(15000) });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const text = await res.text();
    let json;
    try {
        json = JSON.parse(text);
    } catch (_) {
        // 인증값이 틀리거나 IP가 막히면 JSON 대신 안내 글(HTML)이 올 수 있다.
        throw new Error(`JSON이 아닌 응답: ${text.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim().slice(0, 120)}`);
    }
    return pickCurrentKec(json);
}

/**
 * [latest]가 요약 기준 공고([basis])보다 새 공고인가. 일련번호가 다르고 발령일이 같거나
 * 늦을 때만 새 것으로 본다(법제처 쪽이 늦게 올라와 옛 공고를 줄 때 잘못 알리지 않게).
 * 앱(kec_content.dart isNewerKecNotice)과 같은 규칙.
 */
function isNewerNotice(latest, basis) {
    if (!latest || !latest.serial) return false;
    if (!basis || !basis.serial) return true;
    if (latest.serial === basis.serial) return false;
    return String(latest.issued || "") >= String(basis.issued || "");
}

/** 알림을 보낼까 — 새 공고이고, 그 공고로 아직 안 보냈을 때만(한 공고에 한 번). */
function shouldNotify(latest, basis, notifiedSerial) {
    return isNewerNotice(latest, basis) && latest.serial !== notifiedSerial;
}

/** 서버 문서의 요약 판이 파일 판보다 낮으면(또는 없으면) 올린다. */
function shouldPublishContent(doc, content) {
    const v = doc && typeof doc.contentVersion === "number" ? doc.contentVersion : -1;
    return content && typeof content.version === "number" && content.version > v;
}

/** 법제처 인증값이 비었거나 "없음" 같은 자리 표시면 확인을 건너뛴다. */
function usableOc(oc) {
    const s = String(oc || "").trim();
    return s && !["none", "없음", "-", "test"].includes(s.toLowerCase()) ? s : "";
}

module.exports = {
    KEC_NAME,
    isoDate,
    noticeUrl,
    pickCurrentKec,
    fetchCurrentKec,
    isNewerNotice,
    shouldNotify,
    shouldPublishContent,
    usableOc,
};
