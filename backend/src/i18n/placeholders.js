// 번역 시 {n} 같은 자리표시자가 깨지지 않도록 숫자 토큰으로 바꿨다가 복원
const TOKEN_BASE = 7771;
function protect(text) {
  const names = [];
  const out = text.replace(/\{(\w+)\}/g, (_, name) => {
    names.push(name);
    return String(TOKEN_BASE + names.length - 1);
  });
  return { out, names };
}
function restore(text, names) {
  let result = text;
  for (let i = 0; i < names.length; i += 1) {
    const token = String(TOKEN_BASE + i);
    if (!result.includes(token)) return null; // 복원 실패 → 영어 원문 사용
    result = result.replace(token, `{${names[i]}}`);
  }
  return result;
}

module.exports = { protect, restore };
