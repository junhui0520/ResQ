-- ============================================================
-- ResQ DB schema (MySQL 8.x / MariaDB 10.6+ 호환)
-- 기존 백엔드 컨트롤러의 SQL 쿼리에서 사용하던 테이블·컬럼을 그대로 재구성하고,
-- 새 기능에 필요한 컬럼/테이블을 추가했습니다. (추가분은 [NEW] 표시)
-- 실행: npm run db:init  (schema.sql → seed.sql 순서로 적용)
-- ============================================================

SET NAMES utf8mb4;

-- ---------- 코드 테이블 ----------
CREATE TABLE IF NOT EXISTS regions (
  code        VARCHAR(20)  NOT NULL PRIMARY KEY,
  name_en     VARCHAR(60)  NOT NULL,
  name_ko     VARCHAR(60)  NOT NULL,
  latitude    DECIMAL(9,6) NULL,
  longitude   DECIMAL(9,6) NULL,
  parent_code VARCHAR(20)  NULL,               -- [NEW] 예: CHEONAN → CHUNGNAM
  sort_order  INT          NOT NULL DEFAULT 0   -- [NEW]
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS alert_categories (
  code       VARCHAR(20) NOT NULL PRIMARY KEY,
  label_en   VARCHAR(60) NOT NULL,
  label_ko   VARCHAR(60) NOT NULL,
  color_hex  CHAR(7)     NOT NULL DEFAULT '#9AA5B4',
  sort_order INT         NOT NULL DEFAULT 0      -- [NEW]
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS severity_levels (
  code     VARCHAR(20) NOT NULL PRIMARY KEY,
  label_en VARCHAR(60) NOT NULL,
  label_ko VARCHAR(60) NOT NULL,
  level    TINYINT     NOT NULL                   -- [NEW] 4=CRITICAL … 1=LOW
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- 사용자 ----------
CREATE TABLE IF NOT EXISTS users (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  device_uuid   VARCHAR(64) NOT NULL UNIQUE,
  nationality   VARCHAR(60) NULL,
  language_code VARCHAR(10) NOT NULL DEFAULT 'en',
  created_at    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at  DATETIME    NULL                  -- [NEW]
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_settings (
  user_id              INT        NOT NULL PRIMARY KEY,
  alert_enabled        BOOLEAN    NOT NULL DEFAULT TRUE,
  sound_enabled        BOOLEAN    NOT NULL DEFAULT TRUE,
  location_enabled     BOOLEAN    NOT NULL DEFAULT FALSE,
  selected_region_code VARCHAR(20) NULL,
  updated_at           DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_settings_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- 재난 알림 ----------
CREATE TABLE IF NOT EXISTS alerts (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  source           VARCHAR(20)  NOT NULL DEFAULT 'SAFETYDATA', -- [NEW] SAFETYDATA | DEMO | MANUAL
  source_sn        VARCHAR(40)  NULL,          -- [NEW] 원천 API의 일련번호(SN) → 중복 방지
  region_code      VARCHAR(20)  NOT NULL,      -- 대표 지역(기존 컬럼 유지)
  category_code    VARCHAR(20)  NOT NULL,
  severity_code    VARCHAR(20)  NOT NULL,
  status           VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE',      -- ACTIVE | RESOLVED
  issued_at        DATETIME     NOT NULL,      -- KST
  resolved_at      DATETIME     NULL,
  original_message TEXT         NULL,          -- [NEW] 한국어 원문 (MSG_CN)
  region_text      VARCHAR(500) NULL,          -- [NEW] 수신지역 원문 (RCPTN_RGN_NM)
  emergency_step   VARCHAR(30)  NULL,          -- [NEW] 긴급단계명 (EMRG_STEP_NM)
  disaster_type    VARCHAR(50)  NULL,          -- [NEW] 재해구분명 (DST_SE_NM)
  created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_alerts_source_sn (source, source_sn),
  KEY idx_alerts_issued (issued_at),
  KEY idx_alerts_status (status, issued_at),
  CONSTRAINT fk_alerts_region   FOREIGN KEY (region_code)   REFERENCES regions(code),
  CONSTRAINT fk_alerts_category FOREIGN KEY (category_code) REFERENCES alert_categories(code),
  CONSTRAINT fk_alerts_severity FOREIGN KEY (severity_code) REFERENCES severity_levels(code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- [NEW] 한 문자가 여러 지역에 발송되는 경우를 위한 다대다 매핑
CREATE TABLE IF NOT EXISTS alert_regions (
  alert_id    INT         NOT NULL,
  region_code VARCHAR(20) NOT NULL,
  PRIMARY KEY (alert_id, region_code),
  KEY idx_alert_regions_region (region_code),
  CONSTRAINT fk_ar_alert  FOREIGN KEY (alert_id)    REFERENCES alerts(id) ON DELETE CASCADE,
  CONSTRAINT fk_ar_region FOREIGN KEY (region_code) REFERENCES regions(code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS alert_translations (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  alert_id      INT          NOT NULL,
  language_code VARCHAR(10)  NOT NULL,
  title         VARCHAR(255) NOT NULL DEFAULT '',
  content       TEXT         NOT NULL,
  action_guide  TEXT         NULL,
  provider      VARCHAR(20)  NOT NULL DEFAULT 'original', -- [NEW] original | google | none
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_alert_lang (alert_id, language_code),
  CONSTRAINT fk_at_alert FOREIGN KEY (alert_id) REFERENCES alerts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- 대사관 / 긴급전화 / 행동요령 ----------
CREATE TABLE IF NOT EXISTS embassies (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  country_code VARCHAR(10)  NULL,
  flag         VARCHAR(16)  NULL,              -- [NEW] 국기 이모지
  name_en      VARCHAR(200) NOT NULL,
  name_ko      VARCHAR(200) NULL,
  address_en   VARCHAR(300) NULL,
  address_ko   VARCHAR(300) NULL,
  phone        VARCHAR(100) NULL,              -- 원문 표기 그대로
  phone_dial   VARCHAR(30)  NULL,              -- [NEW] 바로 걸 수 있게 정규화한 대표번호 (예: 02-397-4114)
  email        VARCHAR(120) NULL,              -- [NEW]
  fax          VARCHAR(60)  NULL,              -- [NEW]
  zip_code     VARCHAR(10)  NULL,              -- [NEW]
  embassy_type VARCHAR(30)  NULL,              -- [NEW]
  latitude     DECIMAL(9,6) NULL,
  longitude    DECIMAL(9,6) NULL,
  UNIQUE KEY uq_embassy_name (name_en)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS emergency_numbers (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  label          VARCHAR(80)  NOT NULL,
  number         VARCHAR(20)  NOT NULL,
  description_en VARCHAR(300) NULL,
  description_ko VARCHAR(300) NULL,
  hours          VARCHAR(80)  NULL,            -- [NEW] 운영시간
  source_url     VARCHAR(300) NULL,            -- [NEW] 근거 출처
  sort_order     INT          NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS safety_manuals (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  category_code VARCHAR(20) NOT NULL,
  sort_order    INT         NOT NULL DEFAULT 0,
  image_path    VARCHAR(200) NULL,            -- [NEW] 앱 assets 경로
  CONSTRAINT fk_sm_category FOREIGN KEY (category_code) REFERENCES alert_categories(code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS safety_manual_translations (
  manual_id     INT          NOT NULL,
  language_code VARCHAR(10)  NOT NULL,
  title         VARCHAR(200) NOT NULL,
  content       TEXT         NOT NULL,
  PRIMARY KEY (manual_id, language_code),
  CONSTRAINT fk_smt_manual FOREIGN KEY (manual_id) REFERENCES safety_manuals(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- My Info (QR 응급정보) ----------
CREATE TABLE IF NOT EXISTS qr_profiles (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  user_id     INT          NOT NULL UNIQUE,
  qr_token    VARCHAR(64)  NOT NULL UNIQUE,
  name        VARCHAR(100) NOT NULL,
  gender      VARCHAR(10)  NULL,
  age         INT          NULL,
  blood_type  VARCHAR(5)   NULL,
  nationality VARCHAR(60)  NULL,
  language_code VARCHAR(10) NULL,              -- [NEW] 본인 사용 언어 (구조대원 안내용)
  is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
  updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_qr_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS emergency_contacts (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  user_id      INT          NOT NULL,
  name         VARCHAR(100) NOT NULL,
  relationship VARCHAR(60)  NULL,
  phone        VARCHAR(40)  NOT NULL,
  priority     INT          NOT NULL DEFAULT 1,
  KEY idx_ec_user (user_id),
  CONSTRAINT fk_ec_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS medical_infos (
  id       INT AUTO_INCREMENT PRIMARY KEY,
  user_id  INT          NOT NULL,
  category VARCHAR(20)  NOT NULL,              -- allergy | condition
  value    VARCHAR(200) NOT NULL,
  KEY idx_mi_user (user_id),
  CONSTRAINT fk_mi_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- [NEW] 번역 캐시 / 사용량 ----------
CREATE TABLE IF NOT EXISTS translation_cache (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  source_lang     VARCHAR(10) NOT NULL,
  target_lang     VARCHAR(10) NOT NULL,
  source_hash     CHAR(64)    NOT NULL,        -- sha256(source_text)
  source_text     TEXT        NOT NULL,
  translated_text TEXT        NOT NULL,
  provider        VARCHAR(20) NOT NULL,
  created_at      DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_tc (source_lang, target_lang, source_hash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS translation_usage (
  usage_date DATE NOT NULL PRIMARY KEY,        -- KST 기준 날짜
  chars      INT  NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- [NEW] 대피소 ----------
CREATE TABLE IF NOT EXISTS shelters (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  source      VARCHAR(30)  NOT NULL,           -- 예: CIVIL_DEFENSE (DSSP-IF-00195)
  source_id   VARCHAR(60)  NOT NULL,
  name        VARCHAR(255) NOT NULL,
  address     VARCHAR(300) NULL,
  shelter_type VARCHAR(60) NULL,
  latitude    DECIMAL(9,6) NOT NULL,
  longitude   DECIMAL(9,6) NOT NULL,
  updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_shelter_src (source, source_id),
  KEY idx_shelter_lat (latitude),
  KEY idx_shelter_lng (longitude)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- [NEW] 역지오코딩 캐시 (Nominatim 이용정책: 결과 캐시 필수) ----------
CREATE TABLE IF NOT EXISTS geocode_cache (
  lat_key     DECIMAL(7,4) NOT NULL,           -- 약 11m 격자
  lng_key     DECIMAL(7,4) NOT NULL,
  address_ko  VARCHAR(300) NULL,
  region_code VARCHAR(20)  NULL,
  provider    VARCHAR(20)  NOT NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (lat_key, lng_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
