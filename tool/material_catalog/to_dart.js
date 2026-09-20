// 긁어온 자료(vendor2.json)를 앱이 쓰는 자재 목록(Dart)으로 옮긴다.
const fs = require('fs');
const v = JSON.parse(fs.readFileSync('vendor2.json', 'utf8'));

// 상품 이름에서 규격 범위와 홍보 문구를 뺀다.
function cleanBase(title) {
  let t = ' ' + title + ' ';
  t = t.replace(/\[[^\]]*\]/g, ' '); // [KS인증품]
  // "16-300L~42-800L"처럼 길이까지 붙은 범위
  t = t.replace(
    /\d+\s*-\s*\d+[A-Za-z]*\s*[~〜]\s*\d+\s*-\s*\d+[A-Za-z]*/g,
    ' ',
  );
  // 규격 범위: "G16~104", "16 ~ 54", "E19~E75", "22*16~104*82", "100*100*50~"
  t = t.replace(
    /[A-Za-z]{0,3}\d+(?:\.\d+)?(?:\s*\*\s*\d+(?:\.\d+)?)*\s*[~〜]\s*[A-Za-z]{0,3}\d*(?:\.\d+)?(?:\s*\*\s*\d+(?:\.\d+)?)*[A-Za-z]{0,2}/g,
    ' ',
  );
  // 꼬리 문구
  t = t.replace(
    /(VAT[^]]*|KS\s*인증[^]]*|메이커[^]]*|.{0,20}있습니다.*|.{0,20}입니다.*|단종.*|한봉[^]]*|1봉[^]]*|판매중.*|\*.*|!.*)/g,
    ' ',
  );
  // 괄호 안 설명은 뺀다. 다만 (3.6M)처럼 길이가 적힌 것은 남긴다.
  t = t.replace(/\(([^)]*)\)/g, (m, inner) =>
    /\d\s*[Mm]\b/.test(inner) ? m : ' ',
  );
  // "일반/KS/스텐"처럼 갈래를 늘어놓은 토막은 뺀다(갈래는 따로 붙인다).
  const VAR = '일반|KS|스텐304|스텐|아연|용융|흑색|회색|주물';
  t = t.replace(
    new RegExp('(?:' + VAR + ')(?:\\s*/\\s*(?:' + VAR + '))+', 'g'),
    ' ',
  );
  t = t.replace(/\(\s*\)/g, ' ');
  t = t.replace(/\s+/g, ' ').trim();
  t = t.replace(/[-,/]+$/, '').trim();
  return t;
}

// 규격 글에서 숫자가 든 마지막 토막을 규격으로 본다.
function specOf(sizeText) {
  // 업체가 옵션 칸에 적어 둔 재고·품절 같은 메모는 규격이 아니다.
  if (/재고|품절|주문|문의|없습니다|단종/.test(sizeText)) return '';
  const toks = sizeText.split(/\s+/).filter(Boolean);
  for (let i = toks.length - 1; i >= 0; i--) {
    if (/\d/.test(toks[i])) return toks[i];
  }
  return '';
}

// 규격이 이름에 붙어 있는 낱개 상품: 뒤에 붙은 숫자를 규격으로 본다.
function specFromTitle(title) {
  const m = title.match(/(\d+(?:\.\d+)?)\s*$/) || title.match(/(\d+(?:\.\d+)?)/);
  return m ? m[1] : '';
}

function cleanVariant(variant, base) {
  let x = (variant || '').trim();
  if (!x) return '';
  if (x === '일반' || x === base) return '';
  if (base.includes(x)) return '';
  const m = x.match(/^(.*?)\((.*)\)$/);
  if (m) {
    const head = m[1].trim();
    if (head && (base.includes(head) || head.slice(0, 3) === base.slice(0, 3))) {
      x = m[2].trim();
    }
  }
  return x;
}

function slug(s) {
  return (s || '')
    .toLowerCase()
    .replace(/[^0-9a-z가-힣]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

const rows = [];
const ids = new Set();
function push(id, name, category, spec, kind, unit) {
  let key = id;
  let n = 2;
  while (ids.has(key)) key = id + '_' + n++;
  ids.add(key);
  rows.push([key, name, category, spec, kind, unit].join('|'));
}

// 전선관 칸에 들어 있어도 실제로는 부속인 것들(커넥터·카프링·새들 …)은
// 부속으로 옮긴다. 그래야 전선관 칸에 전선관만 남는다.
const ACC_WORDS =
  /커넥터|콘넥터|커플링|카프링|새들|클램프|크램프|밴드|벤더|부싱|로크너트|캡|카바|커버/;

for (const p of v) {
  const base = cleanBase(p.title);
  let category = p.category;
  let kind = p.kind;
  let unit = p.unit;
  if (category === 'CONDUIT' && ACC_WORDS.test(base)) {
    category = 'ACC';
    kind = '전선관 부속';
    unit = 'EA';
  }
  if (!base) continue;
  if (p.variants.length === 0) {
    const spec = specFromTitle(p.title);
    push(
      'kj_' + p.goid,
      p.title
        .replace(/\s*\([^)]*(개|단종|재고|없습니다|품절)[^)]*\)\s*/g, ' ')
        .replace(/\s+/g, ' ')
        .trim(),
      category,
      spec,
      kind,
      unit,
    );
    continue;
  }
  for (const vr of p.variants) {
    const tail = cleanVariant(vr.variant, base);
    for (const size of vr.sizes) {
      const spec = specOf(size);
      if (!spec) continue;
      const name = (base + ' ' + spec + (tail ? ' (' + tail + ')' : '')).replace(
        /\s+/g,
        ' ',
      );
      push(
        'kj_' + p.goid + (tail ? '_' + slug(tail) : '') + '_' + slug(spec),
        name,
        category,
        spec,
        kind,
        unit,
      );
    }
  }
}

const head = `// 경진전기(kjshop.kr) 자재 목록을 긁어와 옮긴 것이다(${new Date()
  .toISOString()
  .slice(0, 10)}).
// 업체 상품 이름·규격을 그대로 따랐다. 현장에서 부르는 말과 다르면 자재 목록
// 화면에서 길게 눌러 고칠 수 있다.
//
// 한 줄 = 아이디|이름|분류|규격|갈래|단위
// 자동으로 만든 파일이라 손으로 고치지 말고, 고칠 것이 있으면 앱 화면에서 고친다.

const List<String> kVendorCatalogRaw = <String>[
`;

const body = rows.map((r) => "  '" + r.replace(/'/g, "\\'") + "',").join('\n');
fs.writeFileSync(
  process.argv[2],
  head + body + '\n];\n',
  'utf8',
);
console.log('자재 ' + rows.length + '건');
console.log(rows.slice(0, 12).join('\n'));
