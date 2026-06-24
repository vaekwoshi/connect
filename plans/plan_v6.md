# [구현 계획] 2단계: sqflite 로컬 DB 연동 및 오프라인 암호화 저장소 구현

특허 청구범위 **[120: 온디바이스 보안 저장부]** 및 **[124: 데이터 영구 파기 단계]**를 실소스코드로 구현하기 위한 로컬 데이터베이스 연동 및 암호화 아키텍처를 설계합니다.

오버엔지니어링 방지(Rule #3)를 위해 무거운 외부 패키지 추가를 배제하고, Dart 표준 라이브러리 기반의 경량 암호화 헬퍼와 `sqflite`를 결합하여 설계합니다.

---

## 1. 신규 컴포넌트 설계

### 1) 경량 암호화 헬퍼 생성
#### [NEW] [crypto_helper.dart](file:///c:/Users/vedja/.gemini/antigravity/scratch/세끌/lib/core/security/crypto_helper.dart)
*   **역할:** 민감한 트랜잭션 정보(결제 수단, 금액 등)를 DB에 적재하기 전 암호화 스트링으로 변환하고, 로드 시 복호화합니다.
*   **암호화 방식:** 로컬 고유 마스킹 키를 활용한 XOR 난독화 및 Base64 인코딩 레이어 구축 (향후 AES 고도화 분기가 가능하도록 인터페이스화).

### 2) 온디바이스 보안 DB 헬퍼 생성
#### [NEW] [db_helper.dart](file:///c:/Users/vedja/.gemini/antigravity/scratch/세끌/lib/core/data/db_helper.dart)
*   **역할:** `sqflite` 인스턴스 생명주기 관리 및 세무 프로필, 지출 트랜잭션 테이블을 초기화합니다.
*   **주요 기능:**
    1.  **암호화 적재:** `insertTransaction()` 시 금액과 결제 수단을 `CryptoHelper`로 암호화하여 텍스트로 저장.
    2.  **복호화 조회:** `getTransactions()` 시 암호화된 필드를 복호화하여 런타임 모델로 매핑.
    3.  **데이터 영구 파기 (특허 124단계):** `clearAllData()` 메소드 호출 시 DB 파일 자체를 파일 시스템에서 물리적으로 삭제하고 인스턴스를 즉각 무효화(Zeroing) 처리.

---

## 2. 세부 데이터베이스 테이블 스키마

### ① `user_profile` 테이블 (사용자 세무 프로필)
```sql
CREATE TABLE user_profile (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_type TEXT,           -- 직장인, 프리랜서, N잡러
    gross_income REAL,        -- 총급여액
    dependents INTEGER,       -- 부양가족 수
    is_monthly_rent INTEGER,  -- 월세 여부 (0/1)
    monthly_rent REAL,        -- 월세액
    decided_tax REAL,         -- 기납부세액
    yellow_umbrella REAL      -- 노란우산공제 납입액
)
```

### ② `transactions` 테이블 (지출 및 소득 내역 - 암호화 대상)
```sql
CREATE TABLE transactions (
    id TEXT PRIMARY KEY,
    date TEXT,
    payment_method TEXT,      -- 암호화 적재 (신용/체크/현금 등)
    amount TEXT,              -- 암호화 적재 (실지출액)
    category TEXT             -- 소비 카테고리
)
```

---

## 3. 검증 계획

### 1) 단위 테스트 코드 작성
#### [NEW] [database_test.dart](file:///c:/Users/vedja/.gemini/antigravity/scratch/세끌/test/database_test.dart)
*   `sqflite_common_ffi`를 활용하여 로컬 테스트 환경에서 DB 인스턴스를 구동합니다.
*   **테스트 시나리오:**
    1.  `CryptoHelper`를 통한 암호화 및 복호화 라운드트립 일치 여부 검증.
    2.  트랜잭션 저장 후 실제 DB raw 데이터를 열었을 때, 금액과 결제 수단이 평문으로 보이지 않고 암호화 스트링으로 보호되는지 확인.
    3.  영구 파기 API 호출 후 DB 파일 존재 여부 확인 및 조회 실패(Null/Exception) 검증.

### 2) 자동화 테스트 실행
*   `flutter test test/database_test.dart`를 실행하여 100% 통과 여부를 검증합니다.
