/**
 * 민방위 대피시설 가져오기 (재난안전데이터공유플랫폼 DSSP-IF-00195, 키 필요)
 *   npm run db:import-shelters
 */
const { importShelters } = require('../src/services/shelterImporter');

importShelters()
  .then((r) => { console.log(`대피소 저장 ${r.imported}건 (좌표 없음/범위 밖 ${r.skipped}건, 전체 ${r.total})`); process.exit(0); })
  .catch((e) => { console.error('대피소 가져오기 실패:', e.message); process.exit(1); });
