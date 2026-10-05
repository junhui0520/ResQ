-- ============================================================
-- ResQ 기본 데이터 (여러 번 실행해도 안전하도록 UPSERT 사용)
-- 대사관 데이터는 scripts/import-embassies.js 로 앱 assets 파일에서 가져옵니다.
-- ============================================================
SET NAMES utf8mb4;

-- ---------- 지역 (좌표는 기존 앱 settings_page.dart 의 기본 지역 목록 값 사용) ----------
INSERT INTO regions (code, name_en, name_ko, latitude, longitude, parent_code, sort_order) VALUES
 ('KR',        'Nationwide', '전국',            36.350000, 127.800000, NULL,       0),
 ('SEOUL',     'Seoul',      '서울특별시',      37.566500, 126.978000, NULL,       1),
 ('BUSAN',     'Busan',      '부산광역시',      35.179600, 129.075600, NULL,       2),
 ('DAEGU',     'Daegu',      '대구광역시',      35.871400, 128.601400, NULL,       3),
 ('INCHEON',   'Incheon',    '인천광역시',      37.456300, 126.705200, NULL,       4),
 ('GWANGJU',   'Gwangju',    '광주광역시',      35.159500, 126.852600, NULL,       5),
 ('DAEJEON',   'Daejeon',    '대전광역시',      36.350400, 127.384500, NULL,       6),
 ('ULSAN',     'Ulsan',      '울산광역시',      35.538400, 129.311400, NULL,       7),
 ('SEJONG',    'Sejong',     '세종특별자치시',  36.480000, 127.289000, NULL,       8),
 ('GYEONGGI',  'Gyeonggi',   '경기도',          37.413800, 127.518300, NULL,       9),
 ('GANGWON',   'Gangwon',    '강원특별자치도',  37.822800, 128.155500, NULL,      10),
 ('CHUNGBUK',  'Chungbuk',   '충청북도',        36.635700, 127.491700, NULL,      11),
 ('CHUNGNAM',  'Chungnam',   '충청남도',        36.518400, 126.800000, NULL,      12),
 ('CHEONAN',   'Cheonan',    '천안시',          36.815100, 127.113900, 'CHUNGNAM', 13),
 ('JEONBUK',   'Jeonbuk',    '전북특별자치도',  35.717500, 127.153000, NULL,      14),
 ('JEONNAM',   'Jeonnam',    '전라남도',        34.867900, 126.991000, NULL,      15),
 ('GYEONGBUK', 'Gyeongbuk',  '경상북도',        36.491900, 128.888900, NULL,      16),
 ('GYEONGNAM', 'Gyeongnam',  '경상남도',        35.460600, 128.213200, NULL,      17),
 ('JEJU',      'Jeju',       '제주특별자치도',  33.499600, 126.531200, NULL,      18)
ON DUPLICATE KEY UPDATE name_en=VALUES(name_en), name_ko=VALUES(name_ko),
  latitude=VALUES(latitude), longitude=VALUES(longitude),
  parent_code=VALUES(parent_code), sort_order=VALUES(sort_order);

-- ---------- 재난 유형 (색상은 기존 앱 alerts_page.dart 의 필터 색상 사용) ----------
INSERT INTO alert_categories (code, label_en, label_ko, color_hex, sort_order) VALUES
 ('RAIN',       'Rain / Typhoon', '호우·태풍', '#1565C0', 1),
 ('FLOOD',      'Flood',          '홍수·침수', '#0277BD', 2),
 ('EARTHQUAKE', 'Earthquake',     '지진·지진해일', '#BF360C', 3),
 ('FIRE',       'Fire',           '화재·산불', '#E53935', 4),
 ('SNOW',       'Snow',           '대설',      '#5C6BC0', 5),
 ('LANDSLIDE',  'Landslide',      '산사태',    '#6D4C41', 6),
 ('HEAT',       'Heat wave',      '폭염',      '#F57C00', 7),
 ('COLD',       'Cold wave',      '한파',      '#00838F', 8),
 ('OTHER',      'Other',          '기타',      '#546E7A', 9)
ON DUPLICATE KEY UPDATE label_en=VALUES(label_en), label_ko=VALUES(label_ko),
  color_hex=VALUES(color_hex), sort_order=VALUES(sort_order);

-- ---------- 심각도 (재난문자 3단계: 위급재난 / 긴급재난 / 안전안내) ----------
INSERT INTO severity_levels (code, label_en, label_ko, level) VALUES
 ('CRITICAL', 'Extreme alert',   '위급재난', 4),
 ('HIGH',     'Emergency alert', '긴급재난', 3),
 ('MEDIUM',   'Safety notice',   '안전안내', 2),
 ('LOW',      'Information',     '정보',     1)
ON DUPLICATE KEY UPDATE label_en=VALUES(label_en), label_ko=VALUES(label_ko), level=VALUES(level);

-- ---------- 긴급전화 (출처 URL 함께 저장) ----------
DELETE FROM emergency_numbers;
INSERT INTO emergency_numbers (label, number, description_en, description_ko, hours, source_url, sort_order) VALUES
 ('Fire · Rescue · Ambulance', '119',
  'Fire, rescue and ambulance. 119 also gives first-aid guidance and medical consultation.',
  '화재·구조·구급. 응급처치 지도와 응급의료 상담도 119로 통합되어 있습니다.',
  '24/7', 'https://www.ajunews.com/view/20130620000692', 1),
 ('Police', '112',
  'Crime, accidents and threats to your safety.',
  '범죄·사고·신변 위협 신고.',
  '24/7', NULL, 2),
 ('Immigration Contact Center', '1345',
  'Help for foreign residents in 20 languages. Weekdays 09:00–22:00 (after 18:00: Korean, English, Chinese only). From abroad: +82-2-1345.',
  '외국인 생활·민원 상담(20개 언어). 평일 09:00~22:00 (18시 이후 한국어·영어·중국어만).',
  'Weekdays 09:00–22:00', 'https://www.immigration.go.kr/immigration/1530/subview.do', 3),
 ('KDCA Call Center', '1339',
  'Infectious disease consultation (e.g. fever after overseas travel). For a medical emergency call 119.',
  '질병관리청 콜센터: 감염병 상담·해외여행 감염병 안내. 응급 상황은 119.',
  '24/7', 'https://kdca.go.kr/kdca/2777/subview.do', 4),
 ('Korea Travel Hotline', '1330',
  'Tourist information and interpretation by the Korea Tourism Organization (8 languages incl. Korean).',
  '한국관광공사 관광안내(한국어 포함 8개 국어).',
  NULL, 'https://kdca.go.kr/kdca/2777/subview.do', 5);

-- ---------- 행동요령 (기존 앱 safetyguide.dart 의 영문 문구 그대로 + 한국어) ----------
DELETE FROM safety_manuals;
INSERT INTO safety_manuals (id, category_code, sort_order, image_path) VALUES
 (1,  'EARTHQUAKE', 1, 'assets/images/eq1.png'),
 (2,  'EARTHQUAKE', 2, 'assets/images/eq2.png'),
 (3,  'EARTHQUAKE', 3, 'assets/images/eq3.png'),
 (4,  'EARTHQUAKE', 4, 'assets/images/eq4.png'),
 (5,  'EARTHQUAKE', 5, NULL),
 (6,  'RAIN',       1, 'assets/images/flood1.png'),
 (7,  'RAIN',       2, 'assets/images/flood2.png'),
 (8,  'RAIN',       3, 'assets/images/flood3.png'),
 (9,  'RAIN',       4, 'assets/images/flood4.png'),
 (10, 'FIRE',       1, 'assets/images/firesaftey1.png'),
 (11, 'FIRE',       2, 'assets/images/firesafety2.png'),
 (12, 'FIRE',       3, 'assets/images/firesafety3.png'),
 (13, 'FIRE',       4, 'assets/images/firesafety4.png');

INSERT INTO safety_manual_translations (manual_id, language_code, title, content) VALUES
 (1,  'en', 'Drop & Stay Calm', 'When shaking starts, drop down and watch for falling objects'),
 (2,  'en', 'Cover & Hold On', 'Take cover under a sturdy piece of furniture and hold on until the shaking stops'),
 (3,  'en', 'Secure an exit', 'Once shaking stops, open a door and move calmly, protecting your head'),
 (4,  'en', 'Evacuate safely', 'Use the stairs, not elevators, and head to a safe assembly point'),
 (5,  'en', 'If you are outdoors', 'Move away from buildings, power lines, and signs to an open area, and protect your head'),
 (6,  'en', 'Pack emergency supplies', 'Gather water, food, and essentials in a bag before water rises'),
 (7,  'en', 'Call 119', 'Call 119 to report flooding and ask for help if you are in danger'),
 (8,  'en', 'Move to high ground', 'Move to higher floors or ground immediately and stay away from submerged cars'),
 (9,  'en', 'Go to a shelter', 'Head to a designated shelter and never cross flooded roads or bridges'),
 (10, 'en', 'Sound the alarm', 'If you see a fire, press the alarm and shout to alert others nearby'),
 (11, 'en', 'Call for help', 'Call 119 (fire department) and report the location clearly'),
 (12, 'en', 'Stay low, cover your nose', 'Cover your nose and mouth with a cloth and stay low to avoid smoke'),
 (13, 'en', 'Use the stairs', 'NEVER use elevators-take the stairs and evacuate to a safe place outside'),
 (1,  'ko', '자세를 낮추고 침착하게', '흔들림이 시작되면 자세를 낮추고 떨어지는 물건에 주의하세요'),
 (2,  'ko', '머리를 보호하고 붙잡기', '튼튼한 가구 아래로 들어가 흔들림이 멈출 때까지 붙잡고 있으세요'),
 (3,  'ko', '출구 확보', '흔들림이 멈추면 문을 열어 출구를 확보하고 머리를 보호하며 침착하게 이동하세요'),
 (4,  'ko', '안전하게 대피', '엘리베이터 대신 계단을 이용해 안전한 장소로 대피하세요'),
 (5,  'ko', '실외에 있다면', '건물·전선·간판에서 떨어져 넓은 공간으로 이동하고 머리를 보호하세요'),
 (6,  'ko', '비상용품 챙기기', '물이 차오르기 전에 물·식량·필수품을 가방에 챙기세요'),
 (7,  'ko', '119 신고', '위험하면 119에 침수 상황을 신고하고 도움을 요청하세요'),
 (8,  'ko', '높은 곳으로 이동', '즉시 높은 층이나 고지대로 이동하고 물에 잠긴 차량에서 멀리 떨어지세요'),
 (9,  'ko', '대피소로 이동', '지정 대피소로 이동하고 물에 잠긴 도로나 다리는 절대 건너지 마세요'),
 (10, 'ko', '화재 알리기', '불을 발견하면 비상벨을 누르고 큰 소리로 주변에 알리세요'),
 (11, 'ko', '도움 요청', '119(소방)에 신고하고 위치를 정확히 말하세요'),
 (12, 'ko', '낮은 자세, 코와 입 막기', '천으로 코와 입을 막고 자세를 낮춰 연기를 피하세요'),
 (13, 'ko', '계단 이용', '엘리베이터는 절대 타지 말고 계단으로 밖의 안전한 곳으로 대피하세요');
