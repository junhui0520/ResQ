/**
 * 구조대원용 응급정보 페이지 (QR 스캔 시 표시)
 * - 한국어를 크게, 원문(외국어)을 작게 병기
 * - 외부 리소스 없이 단일 HTML (현장 모바일 데이터 환경 고려)
 */

const esc = (v) => String(v ?? '')
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;').replace(/'/g, '&#39;');

const LANG_KO = {
  en: '영어', ko: '한국어', zh: '중국어', vi: '베트남어', th: '태국어', uz: '우즈베크어', ru: '러시아어', ja: '일본어',
  ne: '네팔어', id: '인도네시아어', mn: '몽골어', km: '크메르어(캄보디아)', tl: '필리핀어(타갈로그)', my: '미얀마어', de: '독일어',
};
const GENDER_KO = { male: '남성', female: '여성' };

const telHref = (phone) => `tel:${String(phone).replace(/[^0-9+]/g, '')}`;

function bilingual(ko, original) {
  if (ko && original && ko.trim() !== original.trim()) {
    return `${esc(ko)} <span class="orig">(${esc(original)})</span>`;
  }
  return esc(original || ko || '-');
}

function chip(item, cls) {
  return `<span class="chip ${cls}">${bilingual(item.value_ko, item.value)}</span>`;
}

function renderResponderPage(p) {
  const head = `<!doctype html><html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>응급 정보 · Emergency Info — ResQ</title>
<style>
:root{--navy:#1B2F6E;--red:#C0392B;--bg:#F2F4F8;--card:#fff;--muted:#5B6478;--line:#E2E8F0}
*{box-sizing:border-box}body{margin:0;background:var(--bg);font-family:-apple-system,BlinkMacSystemFont,"Apple SD Gothic Neo","Malgun Gothic","Noto Sans KR",Roboto,sans-serif;color:#152A5C}
header{background:var(--navy);color:#fff;padding:18px 20px}
header h1{margin:0;font-size:22px}header p{margin:4px 0 0;font-size:13px;opacity:.8}
main{max-width:560px;margin:0 auto;padding:16px}
.card{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:16px;margin-bottom:12px}
.name{font-size:26px;font-weight:800;margin:0}
.sub{color:var(--muted);margin-top:4px;font-size:15px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:14px}
.box{background:#F6F7FC;border-radius:12px;padding:12px}
.label{font-size:12px;font-weight:800;color:#8A91CD;letter-spacing:.06em}
.value{font-size:20px;font-weight:800;margin-top:6px}
.blood{color:var(--red);font-size:30px}
h2{font-size:14px;color:#8A91CD;letter-spacing:.06em;margin:0 0 10px}
.chip{display:inline-block;border-radius:12px;padding:7px 11px;margin:0 6px 8px 0;font-weight:700;font-size:15px}
.allergy{background:#FFE5E5;color:#B03030}.condition{background:#E9E9FB;color:#4A52A3}
.orig{font-weight:500;opacity:.75;font-size:13px}
.contact{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:8px 0;border-top:1px solid var(--line)}
.contact:first-of-type{border-top:0}
.contact b{font-size:16px}.contact small{display:block;color:var(--muted);margin-top:2px}
.call{background:var(--navy);color:#fff;text-decoration:none;font-weight:800;border-radius:10px;padding:10px 14px;white-space:nowrap}
.warn{background:#FFF7E8;border:1px solid #FFD89C;color:#8A5300;border-radius:14px;padding:12px 14px;font-size:13px;line-height:1.5}
.lang{background:#EEF0FB;border-radius:14px;padding:12px 14px;font-size:15px;line-height:1.5}
.empty{text-align:center;padding:60px 20px;color:var(--muted)}
footer{text-align:center;color:var(--muted);font-size:12px;padding:8px 0 24px}
</style></head><body>
<header><h1>응급 정보 <span style="opacity:.7;font-weight:500">· Emergency Info</span></h1>
<p>ResQ — 외국인 응급정보 (본인 입력)</p></header><main>`;

  if (!p) {
    return `${head}<div class="card empty"><p><b>등록된 응급 정보가 없거나 삭제되었습니다.</b></p>
<p>No emergency information found.</p></div></main></body></html>`;
  }

  const allergies = p.medical_infos.filter((m) => m.category === 'allergy');
  const conditions = p.medical_infos.filter((m) => m.category === 'condition');
  const genderKo = GENDER_KO[p.gender] || p.gender || '-';
  const langKo = p.language_code ? (LANG_KO[p.language_code] || p.language_code) : null;

  const contacts = p.emergency_contacts.map((c) => `
    <div class="contact"><div><b>${esc(c.name)}</b>
      <small>${bilingual(c.relationship_ko, c.relationship)} · ${esc(c.phone)}</small></div>
      <a class="call" href="${esc(telHref(c.phone))}">전화 Call</a></div>`).join('');

  const updated = p.updated_at ? new Date(p.updated_at).toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' }) : '';

  return `${head}
<section class="card">
  <p class="name">${esc(p.name)}</p>
  <div class="sub">${bilingual(p.nationality_ko, p.nationality)} · ${esc(genderKo)} · ${p.age ? `${esc(p.age)}세` : '나이 미입력'}</div>
  <div class="grid">
    <div class="box"><div class="label">혈액형 BLOOD</div><div class="value blood">${esc(p.blood_type || '-')}</div></div>
    <div class="box"><div class="label">국적 NATIONALITY</div><div class="value">${bilingual(p.nationality_ko, p.nationality)}</div></div>
  </div>
</section>
${langKo ? `<section class="lang">🗣️ 이 사람은 <b>${esc(langKo)}</b> 사용자입니다. 통역이 필요하면
  <a href="tel:1345">외국인종합안내센터 1345</a>(평일 09~22시)를 이용할 수 있습니다.</section><br>` : ''}
<section class="card"><h2>알레르기 ALLERGIES</h2>
  ${allergies.length ? allergies.map((m) => chip(m, 'allergy')).join('') : '<span class="sub">없음 / None</span>'}
  <h2 style="margin-top:14px">질환 CONDITIONS</h2>
  ${conditions.length ? conditions.map((m) => chip(m, 'condition')).join('') : '<span class="sub">없음 / None</span>'}
</section>
<section class="card"><h2>긴급 연락처 EMERGENCY CONTACTS</h2>
  ${contacts || '<span class="sub">없음 / None</span>'}
</section>
<div class="warn">⚠️ 본인이 직접 입력한 정보로 의학적으로 확인되지 않았습니다. 한국어는 기계 번역이며 괄호 안이 원문입니다.<br>
Self-reported information, not medically verified. Korean text is machine translated.</div>
<footer>최종 수정 ${esc(updated)} · ResQ</footer>
</main></body></html>`;
}

module.exports = { renderResponderPage };
