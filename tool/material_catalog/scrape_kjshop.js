// 경진전기(kjshop.kr) 자재 목록 긁어오기 - 2단 옵션(재질 → 규격)까지 읽는다.
const { execFileSync } = require('child_process');
const fs = require('fs');

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/128.0 Safari/537.36';

function get(url) {
  for (let i = 0; i < 2; i++) {
    try {
      return execFileSync('curl', ['-sL', '--max-time', '40', '-A', UA, url], {
        maxBuffer: 1 << 28,
        encoding: 'utf8',
      });
    } catch (e) {
      if (i === 1) throw e;
    }
  }
}

const CATS = JSON.parse(fs.readFileSync('cats.json', 'utf8'));

function products(html) {
  const out = [];
  const re =
    /m_mall_detail\.php\?ps_ctid=(\d+)&ps_goid=(\d+)[\s\S]{0,2000}?<div class="goodsName">([^<]{1,200})<\/div>/g;
  let m;
  const seen = new Set();
  while ((m = re.exec(html)) !== null) {
    if (seen.has(m[2])) continue;
    seen.add(m[2]);
    out.push({ goid: m[2], title: m[3].replace(/\s+/g, ' ').trim() });
  }
  return out;
}

function optionTexts(html) {
  return [...html.matchAll(/<option[^>]*>([^<]{1,80})<\/option>/g)]
    .map((m) => m[1].replace(/&nbsp;/g, ' ').trim())
    .filter((t) => t && !/선택|먼저|^-+$/.test(t));
}

function multiSelect(html) {
  const m = html.match(
    /<select name='goods_option\d+_multi'[\s\S]{0,4000}?<\/select>/,
  );
  if (!m) return null;
  const vals = [
    ...m[0].matchAll(/<option value='([^']*)'[^>]*>([^<]*)<\/option>/g),
  ]
    .filter((x) => x[1])
    .map((x) => ({ value: x[1], label: x[2].replace(/\s+/g, ' ').trim() }));
  return vals.length ? vals : null;
}

// "16 (한봉 100개) : 15,200 원" -> "16"
function sizeOf(opt) {
  let head = opt.split(':')[0].trim();
  head = head.replace(/\([^)]*\)/g, ' ').trim();
  head = head.replace(/\s+/g, ' ');
  if (!head || head.length > 20) return null;
  if (!/[0-9]/.test(head)) return null;
  return head;
}

const result = [];
for (const [ctid, category, kind, unit] of CATS) {
  let list;
  try {
    list = products(get(`https://kjshop.kr/mall/m_mall_list.php?ps_ctid=${ctid}`));
  } catch (e) {
    console.error('목록 실패 ' + ctid + ' ' + e.message);
    continue;
  }
  for (const p of list) {
    const variants = [];
    try {
      const d = get(
        `https://kjshop.kr/mall/m_mall_detail.php?ps_ctid=${ctid}&ps_goid=${p.goid}`,
      );
      const multi = multiSelect(d);
      if (multi) {
        for (const v of multi) {
          const sub = get(
            `https://kjshop.kr/mall/m_mall_detail_ok.php?amode=multi_option&ps_uid=${p.goid}&data=&ps_var=${v.value}`,
          );
          const sizes = Array.from(
            new Set(optionTexts(sub).map(sizeOf).filter(Boolean)),
          );
          if (sizes.length) variants.push({ variant: v.label, sizes });
        }
      } else {
        const sizes = Array.from(
          new Set(optionTexts(d).map(sizeOf).filter(Boolean)),
        );
        if (sizes.length) variants.push({ variant: '', sizes });
      }
    } catch (e) {
      console.error('상품 실패 ' + p.goid + ' ' + e.message);
    }
    result.push({ ctid, category, kind, unit, goid: p.goid, title: p.title, variants });
    const n = variants.reduce((a, b) => a + b.sizes.length, 0);
    console.error(`${kind} | ${p.title.slice(0, 40)} | ${variants.length}갈래 ${n}규격`);
  }
}

fs.writeFileSync(process.argv[2], JSON.stringify(result, null, 1), 'utf8');
console.error(
  '상품 ' +
    result.length +
    '건, 규격 ' +
    result.reduce((a, b) => a + b.variants.reduce((c, d) => c + d.sizes.length, 0), 0) +
    '개 저장',
);
